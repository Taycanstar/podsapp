
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
    case chatSlipUp         // User message appears with typing animation
    case coachResponse1     // First coach bubble
    case coachResponse2     // Second coach bubble
    case coachPromptFood    // Third coach bubble asking for food
    case foodTyping         // "chipotle chicken bowl" types into search
    case presentConfirmSheet
    case logging            // Simulate the log button tap
    case showTimeline       // Navigate to timeline with logged entry
    case done
}

// MARK: - Demo Flow Controller

@MainActor
final class DemoFlowController: ObservableObject {
    // MARK: - Published State

    @Published var step: DemoStep = .chatSlipUp
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
        step = .chatSlipUp
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

        // Step 1: Type user slip-up message
        step = .chatSlipUp
        await typeUserMessage(DemoScript.userSlipUpMessage)

        guard !Task.isCancelled else { return }

        // Add the completed user message to chat
        let userMessage = HealthCoachMessage(
            sender: .user,
            text: DemoScript.userSlipUpMessage
        )
        demoChatMessages.append(userMessage)
        currentTypingText = ""
        isTyping = false

        await delay(seconds: DemoTiming.afterUserMessageDelay)

        guard !Task.isCancelled else { return }

        // Step 2: Show coach response 1
        step = .coachResponse1
        showTypingIndicator = true
        await delay(seconds: 0.8)
        showTypingIndicator = false

        guard !Task.isCancelled else { return }

        let coach1 = HealthCoachMessage(
            sender: .coach,
            text: DemoScript.coachResponses[0]
        )
        demoChatMessages.append(coach1)

        await delay(seconds: DemoTiming.afterCoachResponseDelay)

        guard !Task.isCancelled else { return }

        // Step 3: Show coach response 2
        step = .coachResponse2
        showTypingIndicator = true
        await delay(seconds: 0.6)
        showTypingIndicator = false

        guard !Task.isCancelled else { return }

        let coach2 = HealthCoachMessage(
            sender: .coach,
            text: DemoScript.coachResponses[1]
        )
        demoChatMessages.append(coach2)

        await delay(seconds: DemoTiming.afterCoachResponseDelay)

        guard !Task.isCancelled else { return }

        // Step 4: Show coach response 3 (prompts for food)
        step = .coachPromptFood
        showTypingIndicator = true
        await delay(seconds: 0.6)
        showTypingIndicator = false

        guard !Task.isCancelled else { return }

        let coach3 = HealthCoachMessage(
            sender: .coach,
            text: DemoScript.coachResponses[2]
        )
        demoChatMessages.append(coach3)

        await delay(seconds: DemoTiming.afterCoachResponseDelay)

        guard !Task.isCancelled else { return }

        // Step 5: Type food search query
        step = .foodTyping
        await typeFoodQuery(DemoScript.foodSearchQuery)

        await delay(seconds: DemoTiming.afterFoodTypingDelay)

        guard !Task.isCancelled else { return }

        // Step 6: Present confirm sheet
        step = .presentConfirmSheet
        demoPendingFood = DemoFoodData.createChipotleBowl()
        isConfirmSheetPresented = true

        await delay(seconds: DemoTiming.confirmSheetDisplayDuration)

        guard !Task.isCancelled else { return }

        // Step 7: Auto-log (dismiss sheet)
        step = .logging
        isConfirmSheetPresented = false
        demoLoggedFood = demoPendingFood

        await delay(seconds: DemoTiming.afterLoggingDelay)

        guard !Task.isCancelled else { return }

        // Step 8: Show timeline with logged item and coach follow-up
        step = .showTimeline
        demoCoachFollowUpMessage = DemoScript.postLogCoachMessage

        await delay(seconds: 1.5)

        guard !Task.isCancelled else { return }

        // Step 9: Demo complete
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
