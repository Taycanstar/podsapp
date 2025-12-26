import Foundation

@MainActor
final class AgentChatViewModel: ObservableObject {
    @Published var messages: [AgentChatMessage] = []
    @Published var pendingActions: [AgentPendingAction] = []
    @Published var isLoading = false
    @Published var contextSnapshot: AgentContextSnapshot?
    @Published var confirmingMessageID: UUID?
    @Published var currentStatusHint: AgentResponseHint = .chat

    private let agentService = AgentService.shared
    private var userEmail: String
    private var hasBootstrapped = false
    private var targetDate = Date()
    private var mealTypeHint = "Lunch"

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
        currentStatusHint = .chat

        let historyPayload = serializedHistory()
        agentService.sendChat(
            userEmail: userEmail,
            message: message,
            history: historyPayload,
            targetDate: targetDate,
            mealTypeHint: mealTypeHint
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let reply):
                    self.currentStatusHint = reply.statusHint
                    if let preview = reply.pendingLog {
                        self.replacePendingLogMessages()
                        let message = AgentChatMessage(
                            sender: .pendingLog,
                            text: "",
                            timestamp: Date(),
                            pendingLog: preview
                        )
                        self.messages.append(message)
                    } else {
                        let message = AgentChatMessage(sender: .agent, text: reply.text, timestamp: Date())
                        self.messages.append(message)
                    }
                    self.refreshPendingActions()
                    self.isLoading = false
                case .failure(let error):
                    self.currentStatusHint = .chat
                    let message = AgentChatMessage(sender: .system, text: "Agent error: \(error.localizedDescription)", timestamp: Date())
                    self.messages.append(message)
                    self.isLoading = false
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

    func updateTargetDate(_ date: Date) {
        targetDate = date
    }

    func updateMealTypeHint(_ mealType: String) {
        mealTypeHint = mealType
    }

    func confirmPendingLog(messageId: UUID, mealType: String, completion: @escaping (Result<AgentLogCommitResult, Error>) -> Void) {
        guard let pendingLog = pendingLog(for: messageId) else { return }
        confirmingMessageID = messageId
        agentService.confirmPendingLog(
            userEmail: userEmail,
            pendingLogId: pendingLog.id,
            mealType: mealType,
            targetDate: targetDate
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.confirmingMessageID = nil
                switch result {
                case .success(let commitResult):
                    self.removeMessage(with: messageId)
                    NotificationCenter.default.post(
                        name: NSNotification.Name("LogsChangedNotification"),
                        object: nil,
                        userInfo: ["localOnly": false, "source": "AgentChat"]
                    )
                    completion(.success(commitResult))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func dismissPendingLog(messageId: UUID) {
        removeMessage(with: messageId)
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
                case .system, .pendingLog:
                    return nil
                }
            }
    }

    func resetConversation() {
        messages.removeAll()
        pendingActions.removeAll()
    }

    func appendSystemMessage(_ text: String) {
        let message = AgentChatMessage(sender: .system, text: text, timestamp: Date())
        messages.append(message)
    }

    private func replacePendingLogMessages() {
        messages.removeAll { $0.isPendingLog }
    }

    private func pendingLog(for messageId: UUID) -> AgentPendingLog? {
        messages.first(where: { $0.id == messageId })?.pendingLog
    }

    private func removeMessage(with id: UUID) {
        messages.removeAll { $0.id == id }
    }

    func transcriptText() -> String {
        messages
            .map { "\($0.sender == .user ? "You" : "Metryc"): \($0.text)" }
            .joined(separator: "\n")
    }

    /// Seeds a new conversation with a coach message (for edit-to-chat flow)
    /// - Parameters:
    ///   - coachMessage: The coach message to seed as the first assistant message
    ///   - hiddenContext: Optional hidden context to include in the system prompt
    func seedFromCoachMessage(_ coachMessage: CoachMessage) {
        resetConversation()
        hasBootstrapped = true  // Skip bootstrap since we're seeding

        // Add the coach message as the first agent message
        let agentMessage = AgentChatMessage(
            sender: .agent,
            text: coachMessage.fullText,
            timestamp: Date()
        )
        messages.append(agentMessage)

        // Refresh context for subsequent messages
        refreshContext()
    }
}
