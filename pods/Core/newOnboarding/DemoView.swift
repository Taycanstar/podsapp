//
//  DemoView.swift
//  pods
//
//  Main container view for the onboarding demo.
//  Orchestrates the demo flow through chat, food confirmation, and timeline views.
//

import SwiftUI

struct DemoView: View {
    @StateObject private var flow = DemoFlowController()
    @StateObject private var demoFoodManager = DemoFoodManager()
    @StateObject private var demoDayLogsVM = DayLogsViewModel()
    @StateObject private var demoOnboardingVM = DemoOnboardingViewModel()
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel

    private let backgroundColor = Color.onboardingBackground

    /// Whether the demo is actively playing (not yet at timeline/done)
    private var isDemoPlaying: Bool {
        switch flow.step {
        case .userFoodMessage, .autoLogFood, .coachDataSummary, .coachPatternAlert, .userFollowUp, .coachSuggestion:
            return true
        default:
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                // Show appropriate view based on demo step
                Group {
                    switch flow.step {
                    case .userFoodMessage, .autoLogFood, .coachDataSummary, .coachPatternAlert, .userFollowUp, .coachSuggestion:
                        DemoChatView(flow: flow)

                    case .showTimeline, .done:
                        DemoTimelineView(flow: flow)
                            .environmentObject(onboardingViewModel)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: flow.step)
            }
            .sheet(isPresented: $flow.isConfirmSheetPresented) {
                // Dismiss callback - when sheet is dismissed, advance the demo
                // (This handles both auto-dismiss from flow and manual swipe-down)
            } content: {
                if let food = flow.demoPendingFood {
                    FoodSummaryView(food: food)
                        .environmentObject(demoFoodManager as FoodManager)
                        .environmentObject(demoOnboardingVM as OnboardingViewModel)
                        .environmentObject(demoDayLogsVM)
                        .interactiveDismissDisabled(true) // Prevent swipe-down during demo
                }
            }
            .toolbar {
                // Show skip button while demo is playing
                if isDemoPlaying {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip") {
                            skipDemo()
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            // Wire up the demo food manager callback
            demoFoodManager.onFoodLogged = { food in
                // Food was "logged" in the sheet - the flow controller handles timing
            }

            // Auto-start the demo immediately
            flow.startDemo()
        }
    }

    // MARK: - Skip Demo

    private func skipDemo() {
        // Cancel any running demo
        flow.onContinue()
        // Navigate to next onboarding step (allowHealth)
        onboardingViewModel.currentStep = .allowHealth
    }
}

// MARK: - Preview

#Preview {
    DemoView()
        .environmentObject(OnboardingViewModel())
}
