import SwiftUI

struct FoodLogAgentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager

    @Binding var isPresented: Bool
    var onFoodReady: (Food) -> Void

    @State private var messages: [FoodLogMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatScroll
                inputBar
            }
            .navigationTitle("Food Log Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        switch message.sender {
                        case .user:
                            HStack {
                                Spacer()
                                Text(message.text)
                                    .padding(12)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                        case .system:
                            Text(message.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .foregroundColor(.primary)
                        case .status:
                            HStack(spacing: 10) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text(message.text)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        VStack {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Describe what you ate…", text: $inputText, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(1...4)
                    .padding(.vertical, 8)
                    .focused($isInputFocused)

                Button {
                    sendPrompt()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(isLoading || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color("chat"))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func sendPrompt() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        messages.append(FoodLogMessage(sender: .user, text: prompt))
        inputText = ""
        isLoading = true
        messages.append(FoodLogMessage(sender: .status, text: "Analyzing…"))

        foodManager.generateFoodWithAI(foodDescription: prompt, skipConfirmation: true) { result in
            DispatchQueue.main.async {
                isLoading = false
                messages.removeAll { $0.sender == .status }
                switch result {
                case .success(let food):
                    messages.append(FoodLogMessage(sender: .system, text: "Food ready! Opening summary…"))
                    onFoodReady(food)
                    isPresented = false
                case .failure(let error):
                    messages.append(FoodLogMessage(sender: .system, text: "Error: \(error.localizedDescription)"))
                }
            }
        }
    }
}

private struct FoodLogMessage: Identifiable {
    enum Sender {
        case user, system, status
    }
    let id = UUID()
    let sender: Sender
    let text: String
}
