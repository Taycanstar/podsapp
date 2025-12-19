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

    // MARK: - Private Properties

    private var conversationHistory: [[String: String]] = []
    private let healthCoachService = HealthCoachService.shared

    // Context providers (optional - set by view)
    var contextProvider: HealthCoachContextProvider?

    // MARK: - Callbacks

    var onFoodReady: ((Food) -> Void)?
    var onMealItemsReady: ((Food, [MealItem]) -> Void)?
    var onActivityLogged: ((HealthCoachActivity) -> Void)?
    var onGoalsUpdated: ((UpdatedGoalsPayload) -> Void)?
    var onWeightLogged: ((HealthCoachWeightPayload) -> Void)?

    // MARK: - Initialization

    init() {}

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

        // Call the health coach service
        healthCoachService.chatStream(
            message: trimmed,
            history: conversationHistory,
            context: context,
            targetDate: Date(),
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
                self.messages.removeAll { $0.id == statusMessageId }

                let completedMessageId = self.streamingMessageId
                self.streamingMessageId = nil
                self.streamingText = ""

                switch result {
                case .success(let response):
                    self.handleResponse(response, existingMessageId: completedMessageId)
                case .failure(let error):
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

    /// Clear conversation and reset state
    func clearConversation() {
        messages.removeAll()
        conversationHistory.removeAll()
        streamingText = ""
        streamingMessageId = nil
        pendingOptions = nil
        pendingClarificationQuestion = nil
        isLoading = false
    }

    // MARK: - Response Handling

    private func handleResponse(_ response: HealthCoachResponse, existingMessageId: UUID?) {
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
