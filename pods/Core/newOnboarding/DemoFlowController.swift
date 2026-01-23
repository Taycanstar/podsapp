
//
//  DemoStep.swift
//  pods
//
//  Created by Dimi Nunez on 12/27/25.
//


//
//  DemoFlowController.swift
//  pods
//
//  State machine controller for the onboarding demo flow.
//  Manages timed transitions, message animations, and demo data.
//

import Foundation
import SwiftUI

// MARK: - Demo Step Enum

enum DemoStep: Equatable {
    case userFoodMessage      // User says what they ate (typed)
    case autoLogFood          // Food auto-detected and logged
    case coachDataSummary     // Coach responds with data
    case coachPatternAlert    // Coach notices pattern
    case userFollowUp         // User responds positively (typed)
    case coachSuggestion      // Coach gives specific suggestion
    case showTimeline         // Navigate to timeline
    case done
}

// MARK: - Demo Flow Controller

@MainActor
final class DemoFlowController: ObservableObject {
    // MARK: - Published State

    @Published var step: DemoStep = .userFoodMessage
    @Published var demoChatMessages: [HealthCoachMessage] = []
    @Published var currentTypingText: String = ""
    @Published var isTyping: Bool = false
    @Published var showTypingIndicator: Bool = false
    @Published var demoSearchQuery: String = ""
    @Published var demoPendingFood: Food?
    @Published var isConfirmSheetPresented: Bool = false
    @Published var demoLoggedFood: Food?
    @Published var demoCoachFollowUpMessage: String = ""
    @Published var showReplayButton: Bool = false

    // MARK: - Private State

    private var demoTask: Task<Void, Never>?

    // MARK: - Public Methods

    /// Start the demo flow from the beginning
    func startDemo() {
        // Cancel any existing demo task
        demoTask?.cancel()

        // Reset all state
        resetState()

        // Start the demo sequence
        demoTask = Task {
            await runDemoSequence()
        }
    }

    /// Replay the demo from the beginning
    func replayDemo() {
        startDemo()
    }

    /// Called when user taps "Continue" after demo completes
    /// The parent view should handle navigation to the next onboarding step
    func onContinue() {
        demoTask?.cancel()
    }

    // MARK: - Private Methods

    private func resetState() {
        step = .userFoodMessage
        demoChatMessages = []
        currentTypingText = ""
        isTyping = false
        showTypingIndicator = false
        demoSearchQuery = ""
        demoPendingFood = nil
        isConfirmSheetPresented = false
        demoLoggedFood = nil
        demoCoachFollowUpMessage = ""
        showReplayButton = false
    }

    private func runDemoSequence() async {
        // Small initial delay before typing starts
        await delay(seconds: 0.5)

        guard !Task.isCancelled else { return }

        // Step 1: Type user food message
        step = .userFoodMessage
        await typeUserMessage(DemoScript.userFoodMessage)

        guard !Task.isCancelled else { return }

        // Add the completed user message to chat
        let userMessage = HealthCoachMessage(
            sender: .user,
            text: DemoScript.userFoodMessage
        )
        demoChatMessages.append(userMessage)
        currentTypingText = ""
        isTyping = false

        await delay(seconds: DemoTiming.afterUserMessageDelay)

        guard !Task.isCancelled else { return }

        // Step 2: Auto-log food (brief animation)
        step = .autoLogFood
        demoLoggedFood = DemoFoodData.createChipotleBowl()

        await delay(seconds: 0.5)

        guard !Task.isCancelled else { return }

        // Step 3: Coach data summary
        step = .coachDataSummary
        showTypingIndicator = true
        await delay(seconds: 0.8)
        showTypingIndicator = false

        guard !Task.isCancelled else { return }

        let coachData = HealthCoachMessage(
            sender: .coach,
            text: DemoScript.coachResponses[0]
        )
        demoChatMessages.append(coachData)

        await delay(seconds: DemoTiming.afterCoachResponseDelay)

        guard !Task.isCancelled else { return }

        // Step 4: Coach pattern alert
        step = .coachPatternAlert
        showTypingIndicator = true
        await delay(seconds: 0.6)
        showTypingIndicator = false

        guard !Task.isCancelled else { return }

        let coachPattern = HealthCoachMessage(
            sender: .coach,
            text: DemoScript.coachResponses[1]
        )
        demoChatMessages.append(coachPattern)

        await delay(seconds: DemoTiming.afterCoachResponseDelay)

        guard !Task.isCancelled else { return }

        // Step 5: Type user follow-up response
        step = .userFollowUp
        await typeUserMessage(DemoScript.userFollowUpMessage)

        guard !Task.isCancelled else { return }

        // Add the completed user follow-up message to chat
        let userFollowUp = HealthCoachMessage(
            sender: .user,
            text: DemoScript.userFollowUpMessage
        )
        demoChatMessages.append(userFollowUp)
        currentTypingText = ""
        isTyping = false

        await delay(seconds: DemoTiming.afterUserMessageDelay)

        guard !Task.isCancelled else { return }

        // Step 6: Coach suggestion
        step = .coachSuggestion
        showTypingIndicator = true
        await delay(seconds: 0.8)
        showTypingIndicator = false

        guard !Task.isCancelled else { return }

        let coachSuggestion = HealthCoachMessage(
            sender: .coach,
            text: DemoScript.coachFinalResponse
        )
        demoChatMessages.append(coachSuggestion)

        await delay(seconds: DemoTiming.afterCoachResponseDelay)

        guard !Task.isCancelled else { return }

        // Step 7: Show timeline with logged item and coach summary
        step = .showTimeline
        demoCoachFollowUpMessage = DemoScript.postLogCoachMessage

        await delay(seconds: 1.5)

        guard !Task.isCancelled else { return }

        // Step 8: Demo complete
        step = .done
        showReplayButton = true
    }

    // MARK: - Typing Animations

    private func typeUserMessage(_ text: String) async {
        isTyping = true
        currentTypingText = ""

        for char in text {
            guard !Task.isCancelled else { return }
            currentTypingText.append(char)
            await delay(milliseconds: DemoTiming.typingCharDelayMs)
        }
    }

    private func typeFoodQuery(_ text: String) async {
        demoSearchQuery = ""

        for char in text {
            guard !Task.isCancelled else { return }
            demoSearchQuery.append(char)
            await delay(milliseconds: DemoTiming.typingCharDelayMs)
        }
    }

    // MARK: - Timing Helpers

    private func delay(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func delay(milliseconds: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(milliseconds * 1_000_000))
    }
}
