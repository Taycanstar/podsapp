import SwiftUI

struct AgentChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AgentChatViewModel
    @State private var inputText: String = ""
    private let initialPrompt: String?

    init(initialPrompt: String?) {
        self.initialPrompt = initialPrompt
        let email = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        _viewModel = StateObject(wrappedValue: AgentChatViewModel(userEmail: email))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                pendingActionsSection
                Divider()
                chatScrollView
                inputBar
            }
            .navigationTitle("Humuli Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.bootstrap(initialPrompt: initialPrompt)
        }
    }

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            }
        }
    }

    private func messageBubble(_ message: AgentChatMessage) -> some View {
        HStack {
            if message.sender == .agent {
                Spacer().frame(width: 32)
            }
            Text(message.text)
                .padding(12)
                .background(messageBackground(for: message.sender))
                .foregroundColor(message.sender == .user ? .white : .primary)
                .cornerRadius(16)
            if message.sender == .user {
                Spacer().frame(width: 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.sender == .user ? .trailing : .leading)
    }

    private func messageBackground(for sender: AgentChatMessage.Sender) -> Color {
        switch sender {
        case .user: return .accentColor
        case .agent: return Color(uiColor: .secondarySystemBackground)
        case .system: return Color.orange.opacity(0.3)
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
        HStack(spacing: 12) {
            TextField("Ask the coach anything", text: $inputText)
                .textFieldStyle(.roundedBorder)
            Button {
                let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                viewModel.send(message: trimmed)
                inputText = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}
