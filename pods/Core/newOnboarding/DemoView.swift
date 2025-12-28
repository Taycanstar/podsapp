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

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                // Show appropriate view based on demo step
                Group {
                    switch flow.step {
                    case .intro:
                        introView

                    case .chatSlipUp, .coachResponse1, .coachResponse2, .coachPromptFood, .foodTyping, .presentConfirmSheet, .logging:
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
                if flow.step == .intro {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip") {
                            skipDemo()
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .onAppear {
            // Wire up the demo food manager callback
            demoFoodManager.onFoodLogged = { food in
                // Food was "logged" in the sheet - the flow controller handles timing
            }
        }
    }

    // MARK: - Intro View

    private var introView: some View {
        VStack {
            Spacer()

            VStack(spacing: 24) {
                // Icon
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.primary)

                // Title
                VStack(spacing: 12) {
                    Text("See how it works")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text("Watch a quick demo of how to log food with your personal coach.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            // Start button
            VStack(spacing: 16) {
                Button {
                    flow.startDemo()
                } label: {
                    Text("Start Demo")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.primary)
                        .foregroundColor(Color(.systemBackground))
                        .cornerRadius(36)
                }

                Button("Skip demo") {
                    skipDemo()
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
