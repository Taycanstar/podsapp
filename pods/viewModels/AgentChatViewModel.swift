import Foundation

@MainActor
final class AgentChatViewModel: ObservableObject {
    @Published var messages: [AgentChatMessage] = []
    @Published var pendingActions: [AgentPendingAction] = []
    @Published var isLoading = false
    @Published var contextSnapshot: AgentContextSnapshot?

    private let agentService = AgentService.shared
    private var userEmail: String
    private var hasBootstrapped = false

    init(userEmail: String) {
        self.userEmail = userEmail
    }

    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        refreshContext()
        refreshPendingActions()
    }

    func refreshContext() {
        agentService.fetchContext(userEmail: userEmail) { [weak self] result in
            DispatchQueue.main.async {
                if case let .success(snapshot) = result {
                    self?.contextSnapshot = snapshot
                }
            }
        }
    }

    func refreshPendingActions() {
        agentService.fetchPendingActions(userEmail: userEmail) { [weak self] result in
            DispatchQueue.main.async {
                if case let .success(actions) = result {
                    self?.pendingActions = actions
                }
            }
        }
    }

    func send(message: String) {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let outgoing = AgentChatMessage(sender: .user, text: message, timestamp: Date())
        messages.append(outgoing)
        isLoading = true

        let historyPayload = serializedHistory()
        agentService.sendChat(userEmail: userEmail, message: message, history: historyPayload) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .success(let reply):
                    let message = AgentChatMessage(sender: .agent, text: reply, timestamp: Date())
                    self.messages.append(message)
                    self.refreshPendingActions()
                case .failure(let error):
                    let message = AgentChatMessage(sender: .system, text: "Agent error: \(error.localizedDescription)", timestamp: Date())
                    self.messages.append(message)
                }
            }
        }
    }

    func decide(action: AgentPendingAction, approved: Bool) {
        agentService.decide(actionId: action.id, approved: approved) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.pendingActions.removeAll { $0.id == action.id }
                case .failure(let error):
                    let message = AgentChatMessage(sender: .system, text: "Action decision failed: \(error.localizedDescription)", timestamp: Date())
                    self?.messages.append(message)
                }
            }
        }
    }

    func updateUserEmail(_ email: String) {
        guard email != userEmail else { return }
        userEmail = email
        resetConversation()
        hasBootstrapped = false
    }

    private func serializedHistory(limit: Int = 8) -> [[String: String]] {
        messages
            .suffix(limit)
            .compactMap { message in
                switch message.sender {
                case .user:
                    return ["role": "user", "content": message.text]
                case .agent:
                    return ["role": "assistant", "content": message.text]
                case .system:
                    return nil
                }
            }
    }

    func resetConversation() {
        messages.removeAll()
        pendingActions.removeAll()
    }

    func transcriptText() -> String {
        messages
            .map { "\($0.sender == .user ? "You" : "Humuli"): \($0.text)" }
            .joined(separator: "\n")
    }
}
