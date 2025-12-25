//
//  HealthCoachChatViewModel.swift
//  pods
//
//  Created by Dimi Nunez on 12/16/25.
//


//
//  HealthCoachChatViewModel.swift
//  pods
//
//  Created by Claude on 12/16/24.
//

import Foundation
import SwiftUI

/// ViewModel for the Health Coach Chat interface
/// Manages streaming conversations with the health coach orchestrator
@MainActor
final class HealthCoachChatViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var messages: [HealthCoachMessage] = []
    @Published var isLoading = false
    @Published var streamingText: String = ""
    @Published var streamingMessageId: UUID?
    @Published var statusHint: HealthCoachStatusHint = .thinking
    @Published var pendingOptions: [ClarificationOption]?
    @Published var pendingClarificationQuestion: String?
    @Published var currentConversationId: String?

    // MARK: - Private Properties

    private var conversationHistory: [[String: String]] = []
    private let healthCoachService = HealthCoachService.shared
    private let networkManager = NetworkManager()
    private var currentStreamTask: URLSessionDataTask?

    // Context providers (optional - set by view)
    var contextProvider: HealthCoachContextProvider?

    // MARK: - Callbacks

    var onFoodReady: ((Food) -> Void)?
    var onMealItemsReady: ((Food, [MealItem]) -> Void)?
    var onActivityLogged: ((HealthCoachActivity) -> Void)?
    var onGoalsUpdated: ((UpdatedGoalsPayload) -> Void)?
    var onWeightLogged: ((HealthCoachWeightPayload) -> Void)?
    var onConversationIdUpdated: ((String) -> Void)?

    // MARK: - Initialization

    init() {}

    init(conversationId: String?) {
        self.currentConversationId = conversationId
    }

    // MARK: - Public Methods

    /// Send a message to the health coach
    /// - Parameter message: The user's message
    func send(message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("🤖 HealthCoachChatViewModel.send: Empty message, ignoring")
            return
        }

        print("🤖 HealthCoachChatViewModel.send: Sending message: \(trimmed)")

        // Add user message
        let userMessage = HealthCoachMessage(
            sender: .user,
            text: trimmed
        )
        messages.append(userMessage)
        conversationHistory.append(["role": "user", "content": trimmed])

        // Start loading state
        isLoading = true
        statusHint = .thinking

        // Add status message
        let statusMessageId = UUID()
        messages.append(HealthCoachMessage(
            id: statusMessageId,
            sender: .status,
            text: ""
        ))

        // Clear streaming state
        streamingMessageId = nil
        streamingText = ""

        // Build context if provider is available
        let context = contextProvider?.buildContext()

        // Call the health coach service with conversation ID for persistence
        currentStreamTask = healthCoachService.chatStream(
            message: trimmed,
            history: conversationHistory,
            context: context,
            targetDate: Date(),
            conversationId: currentConversationId,
            onDelta: { [weak self] delta in
                guard let self = self else { return }

                // On first delta, create streaming message and remove status
                if self.streamingMessageId == nil {
                    let newId = UUID()
                    self.streamingMessageId = newId
                    self.messages.removeAll { $0.id == statusMessageId }
                    self.messages.append(HealthCoachMessage(
                        id: newId,
                        sender: .coach,
                        text: delta
                    ))
                } else if let currentId = self.streamingMessageId,
                          let index = self.messages.firstIndex(where: { $0.id == currentId }) {
                    self.messages[index].text += delta
                }
                self.streamingText += delta
            },
            onComplete: { [weak self] result in
                guard let self = self else { return }

                self.isLoading = false
                self.currentStreamTask = nil
                self.messages.removeAll { $0.id == statusMessageId }

                let completedMessageId = self.streamingMessageId
                self.streamingMessageId = nil
                self.streamingText = ""

                switch result {
                case .success(let response):
                    self.handleResponse(response, existingMessageId: completedMessageId)
                case .failure(let error):
                    // Check if this was a cancellation - if so, silently ignore
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                        // User cancelled - no error message needed
                        if let msgId = completedMessageId {
                            self.messages.removeAll { $0.id == msgId }
                        }
                        return
                    }

                    self.pendingClarificationQuestion = nil
                    if let msgId = completedMessageId {
                        self.messages.removeAll { $0.id == msgId }
                    }
                    self.messages.append(HealthCoachMessage(
                        sender: .system,
                        text: "Error: \(error.localizedDescription)"
                    ))
                }
            }
        )
    }

    /// Select a clarification option
    /// - Parameter option: The selected option
    func selectOption(_ option: ClarificationOption) {
        let responseText = option.label ?? option.name ?? "Selected"
        send(message: responseText)
        pendingOptions = nil
        pendingClarificationQuestion = nil
    }

    /// Cancel the current streaming request
    func cancelStream() {
        print("🤖 HealthCoachChatViewModel.cancelStream: Cancelling stream")
        currentStreamTask?.cancel()
        currentStreamTask = nil
        isLoading = false
        streamingMessageId = nil
        streamingText = ""
        // Remove any status messages that might be showing
        messages.removeAll { $0.sender == .status }
    }

    /// Clear conversation and reset state
    func clearConversation() {
        messages.removeAll()
        conversationHistory.removeAll()
        streamingText = ""
        streamingMessageId = nil
        pendingOptions = nil
        pendingClarificationQuestion = nil
        isLoading = false
        currentConversationId = nil
    }

    /// Load an existing conversation from the server
    /// - Parameters:
    ///   - conversationId: The conversation ID to load
    ///   - messagesResponse: The messages from the server
    func loadConversation(id: String, messages messagesResponse: [AgentMessageResponse]) {
        currentConversationId = id

        // Convert AgentMessageResponse to HealthCoachMessage
        messages = messagesResponse.map { msg in
            let sender: HealthCoachMessage.Sender = msg.role == "user" ? .user : .coach
            let responseType = msg.responseType.flatMap { HealthCoachResponseType(rawValue: $0) }

            return HealthCoachMessage(
                id: UUID(uuidString: msg.id) ?? UUID(),
                sender: sender,
                text: msg.content,
                timestamp: msg.createdAt,
                responseType: responseType,
                food: msg.responseData?.food,
                mealItems: msg.responseData?.mealItems,
                activity: msg.responseData?.activity,
                citations: msg.responseData?.citations
            )
        }

        // Rebuild conversation history for API calls
        conversationHistory = messagesResponse.map { msg in
            ["role": msg.role, "content": msg.content]
        }
    }

    // MARK: - Response Handling

    private func handleResponse(_ response: HealthCoachResponse, existingMessageId: UUID?) {
        // Update conversation ID from response (server creates/uses conversation)
        print("🤖 HealthCoachChatViewModel.handleResponse - response.conversationId: \(response.conversationId ?? "nil"), currentConversationId: \(currentConversationId ?? "nil")")
        if let newConversationId = response.conversationId {
            if currentConversationId == nil || currentConversationId != newConversationId {
                print("🤖 HealthCoachChatViewModel.handleResponse - Updating conversationId to: \(newConversationId)")
                currentConversationId = newConversationId
                onConversationIdUpdated?(newConversationId)
            }
        }

        // Only add message if it wasn't already streamed
        if existingMessageId == nil {
            messages.append(HealthCoachMessage(
                sender: .coach,
                text: response.message,
                responseType: response.type,
                food: response.food,
                mealItems: response.mealItems,
                activity: response.activity,
                data: response.data,
                options: response.options,
                citations: response.citations
            ))
        } else if let existingId = existingMessageId,
                  let index = messages.firstIndex(where: { $0.id == existingId }) {
            // Update existing message with response data (including citations)
            messages[index] = HealthCoachMessage(
                id: existingId,
                sender: .coach,
                text: messages[index].text,
                timestamp: messages[index].timestamp,
                responseType: response.type,
                food: response.food,
                mealItems: response.mealItems,
                activity: response.activity,
                data: response.data,
                options: response.options,
                citations: response.citations
            )
        }

        // Always add to conversation history
        conversationHistory.append(["role": "assistant", "content": response.message])

        // Handle response type
        switch response.type {
        case .text:
            pendingClarificationQuestion = nil
            pendingOptions = nil

        case .foodLogged:
            pendingClarificationQuestion = nil
            pendingOptions = nil

            if let mealItems = response.mealItems, mealItems.count > 1, let food = response.food {
                // Multi-food meal
                let convertedFood = healthCoachService.convertToFood(food)
                let convertedItems = mealItems.map { healthCoachService.convertToMealItem($0) }
                onMealItemsReady?(convertedFood, convertedItems)
            } else if let food = response.food {
                // Single food
                let convertedFood = healthCoachService.convertToFood(food)
                onFoodReady?(convertedFood)
            }

        case .activityLogged:
            pendingClarificationQuestion = nil
            pendingOptions = nil

            if let activity = response.activity {
                onActivityLogged?(activity)
            }

        case .dataResponse:
            pendingClarificationQuestion = nil
            pendingOptions = nil
            // Data is displayed in the message UI

        case .goalsUpdated:
            pendingClarificationQuestion = nil
            pendingOptions = nil

            if let goals = response.goals {
                onGoalsUpdated?(goals)
                // Post notification to refresh nutrition goals across the app
                NotificationCenter.default.post(
                    name: Notification.Name("NutritionGoalsUpdatedNotification"),
                    object: nil
                )
            }

        case .weightLogged:
            pendingClarificationQuestion = nil
            pendingOptions = nil

            if let weight = response.weight {
                onWeightLogged?(weight)
                // Post notification to refresh weight data across the app
                NotificationCenter.default.post(
                    name: Notification.Name("WeightLoggedNotification"),
                    object: nil
                )
            }

        case .needsClarification:
            if let options = response.options {
                pendingOptions = options
                pendingClarificationQuestion = response.message
            }

        case .error:
            pendingClarificationQuestion = nil
            pendingOptions = nil
        }
    }

    // MARK: - Serialization

    /// Get serialized conversation history for API calls
    func serializedHistory(limit: Int = 10) -> [[String: String]] {
        let startIndex = max(0, conversationHistory.count - limit)
        return Array(conversationHistory[startIndex...])
    }
}

// MARK: - Context Provider Protocol

/// Protocol for providing context to the health coach
protocol HealthCoachContextProvider {
    func buildContext() -> HealthCoachContextPayload?
}

// MARK: - Message Extension for UI

extension HealthCoachMessage {
    /// Whether this message is currently streaming
    var isStreaming: Bool {
        false // Will be set by comparing with viewModel.streamingMessageId
    }

    /// Whether this message has associated data to display
    var hasAssociatedData: Bool {
        food != nil || activity != nil || data != nil || (options != nil && !options!.isEmpty)
    }
}
