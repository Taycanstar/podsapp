import SwiftUI
import UIKit

struct AgentChatView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AgentChatViewModel
    @State private var inputText: String = ""
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var thinkingMessageIndex = 0
    @State private var shimmerPhase: CGFloat = 0
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool

    init(viewModel: AgentChatViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pendingActionsSection
                Divider()
                ZStack(alignment: .bottomTrailing) {
                    chatScrollView
                    scrollToBottomButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
                inputBar
            }
            .navigationTitle("Humuli")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: startNewChat) {
                        Image(systemName: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Share", action: shareConversation)
                        Button(role: .destructive, action: startNewChat) {
                            Text("Delete Chat")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .onReceive(thinkingTimer) { _ in
            if viewModel.isLoading {
                thinkingMessageIndex = (thinkingMessageIndex + 1) % thinkingPhrases.count
            } else {
                thinkingMessageIndex = 0
            }
        }
        .onAppear {
            viewModel.bootstrapIfNeeded()
        }
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastMessage)
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 40)
            }
        }
    }

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }
                    if viewModel.isLoading {
                        thinkingIndicator
                    }
                }
                .padding()
            }
            .onAppear {
                scrollProxy = proxy
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 10) {
            thinkingPulseCircle
            shimmeringThinkingText
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func messageRow(_ message: AgentChatMessage) -> some View {
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
        case .agent:
            Text(message.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        case .system:
            Text(message.text)
                .font(.footnote)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var pendingActionsSection: some View {
        Group {
            if viewModel.pendingActions.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pending Agent Actions")
                        .font(.headline)
                    ForEach(viewModel.pendingActions) { action in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(action.actionType.capitalized)
                                .font(.subheadline)
                                .bold()
                            if let rationale = action.rationale {
                                Text(rationale)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Button("Decline") {
                                    viewModel.decide(action: action, approved: false)
                                }
                                .buttonStyle(.bordered)
                                Button("Approve") {
                                    viewModel.decide(action: action, approved: true)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
    }

    private var inputBar: some View {
        VStack {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Ask or log anything…", text: $inputText, axis: .vertical)
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
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.send(message: trimmed)
        inputText = ""
        isInputFocused = false
    }

    private func startNewChat() {
        viewModel.resetConversation()
        viewModel.refreshContext()
        inputText = ""
    }

    private func shareConversation() {
        let transcript = viewModel.transcriptText()
        guard !transcript.isEmpty else { return }
        UIPasteboard.general.string = transcript
        showToast(with: "Conversation copied")
    }

    private func showToast(with message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }

    private var scrollToBottomButton: some View {
        Group {
            if !viewModel.messages.isEmpty {
                Button {
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            scrollProxy?.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                        .background(
                            Circle()
                                .fill(.thinMaterial)
                                .frame(width: 44, height: 44)
                        )
                }
            }
        }
    }

    private var thinkingPhrases: [String] {
        [
            "Humuli is thinking…",
            "Checking your recent trends…",
            "Balancing recovery and strain…",
            "Reviewing your sleep + HRV…"
        ]
    }

    private var thinkingPulseCircle: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let normalized = (sin(t * 2 * .pi / 1.5) + 1) / 2
            Circle()
                .fill(Color.primary)
                .frame(width: 10, height: 10)
                .scaleEffect(0.85 + 0.25 * normalized)
                .opacity(0.6 + 0.4 * normalized)
        }
    }

    private var shimmeringThinkingText: some View {
        let text = thinkingPhrases[thinkingMessageIndex]
        return Text(text)
            .font(.footnote)
            .foregroundColor(.secondary)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, Color.white.opacity(0.6), .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: shimmerPhase)
                .mask(
                    Text(text)
                        .font(.footnote)
                )
            )
            .onAppear {
                shimmerPhase = -60
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    shimmerPhase = 60
                }
            }
    }

    private var thinkingTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
}
