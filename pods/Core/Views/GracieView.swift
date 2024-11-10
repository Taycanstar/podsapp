import SwiftUI
import Foundation

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

struct GracieView: View {
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var messageCount = 0
    @State private var activityLogs: [PodItemActivityLog] = []
    @EnvironmentObject var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool
    let networkManager = NetworkManager()
    let podId: Int
    @State private var isLoading = false
    @State private var isTyping = false
    @State private var showScrollButton = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                        if isTyping {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 15)
                    .id("messagesEnd")
                }
                .onChange(of: messageCount) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: isTyping) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        showScrollButton = true
                    }
                )
                
                // Scroll button overlay within ScrollViewReader
                .overlay(
                    VStack {
                        Spacer()
                        if showScrollButton {
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation {
                                        scrollToBottom(proxy: proxy)
                                        showScrollButton = false
                                    }
                                }) {
                                    Image(systemName: "chevron.down.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.blue)
                                        .background(Color.white.opacity(0.9))
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 6)
                                }
                                .padding(.trailing, 20)
                                .padding(.bottom, 80)
                            }
                        }
                    }
                )
            }
            
            // Message input area
            HStack(spacing: 12) {
                TextField("Message", text: $newMessage)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .focused($isFocused)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
           
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.systemGray5)),
                alignment: .top
            )
        }
        .navigationTitle("Gracie Pod Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupInitialMessages()
            fetchActivityLogs()
        }
    }
     private func scrollToBottom(proxy: ScrollViewProxy) {
         withAnimation {
             proxy.scrollTo("messagesEnd", anchor: .bottom)
         }
     }
    private func setupInitialMessages() {
         messages = [
             Message(content: "Hi! I'm Gracie, you can ask me anything about your progress and insights.", isFromUser: false, timestamp: Date())
         ]
         messageCount = messages.count
     }
     
    
    private func sendMessage() {
         let trimmedMessage = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
         guard !trimmedMessage.isEmpty else { return }
         
         let userMessage = Message(content: trimmedMessage, isFromUser: true, timestamp: Date())
         messages.append(userMessage)
         messageCount += 1
         newMessage = ""
         isLoading = true
        isTyping = true
         
         // Send message to Gracie with activity logs
         networkManager.sendMessageToGracie(message: trimmedMessage, activityLogs: activityLogs) { result in
             DispatchQueue.main.async {
                 isLoading = false
                 isTyping = false
                 switch result {
                 case .success(let response):
                     let gracieMessage = Message(content: response, isFromUser: false, timestamp: Date())
                     messages.append(gracieMessage)
                     messageCount += 1
                     
                 case .failure(let error):
                     let errorMessage = Message(content: "I apologize, but I'm having trouble processing your request at the moment. Please try again.", isFromUser: false, timestamp: Date())
                     messages.append(errorMessage)
                     messageCount += 1
                     print("Gracie chat error: \(error)")
                 }
             }
         }
     }
    
    private func fetchActivityLogs() {
        networkManager.fetchUserActivityLogs(podId: podId, userEmail: viewModel.email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let logs):
                    self.activityLogs = logs
                    
                case .failure(let error):
                    print("Failed to fetch activity logs: \(error)")
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromUser { Spacer() }
            
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    message.isFromUser ?
                    Color.blue :
                    Color(.systemGray5)
                )
                .foregroundColor(
                    message.isFromUser ?
                    .white :
                    .primary
                )
                .clipShape(BubbleShape(isFromUser: message.isFromUser))
            
            if !message.isFromUser { Spacer() }
        }
    }
}

struct BubbleShape: Shape {
    let isFromUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [
                .topLeft,
                .topRight,
                isFromUser ? .bottomLeft : .bottomRight
            ],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        return Path(path.cgPath)
    }
}


struct TypingIndicator: View {
    @State private var numberOfDots = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 8, height: 8)
                    .opacity(numberOfDots >= index + 1 ? 1 : 0.3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.6).repeatForever()) {
                numberOfDots = 3
            }
        }
    }
}



extension UIView {
    func findScrollView() -> UIScrollView? {
        if let scrollView = self as? UIScrollView {
            return scrollView
        }
        
        for subview in subviews {
            if let scrollView = subview.findScrollView() {
                return scrollView
            }
        }
        return nil
    }
}

extension UIScrollView {
    var isScrolledToBottom: Bool {
        let contentHeight = self.contentSize.height
        let boundsHeight = self.bounds.height
        let contentOffsetY = self.contentOffset.y
        return contentOffsetY >= contentHeight - boundsHeight
    }
}

extension GracieView {
    private var scrollView: UIScrollView? {
        UIApplication.shared.windows.first?.rootViewController?.view.findScrollView()
    }
    
    private var isScrolledToBottom: Bool {
        guard let scrollView = scrollView else { return false }
        return scrollView.isScrolledToBottom
    }
}
