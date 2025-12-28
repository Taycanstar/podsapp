//
//  DemoTimelineView.swift
//  pods
//
//  Created by Dimi Nunez on 12/27/25.
//


//
//  DemoTimelineView.swift
//  pods
//
//  Timeline view for the onboarding demo.
//  Shows the logged food item with a supportive coach message.
//

import SwiftUI

struct DemoTimelineView: View {
    @ObservedObject var flow: DemoFlowController
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let backgroundColor = Color.onboardingBackground

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 40)

                // "Logged" header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("Logged")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.bottom, 32)

                // Logged food card
                if let food = flow.demoLoggedFood {
                    loggedFoodCard(food)
                        .padding(.horizontal, 24)
                }

                Spacer()
                    .frame(height: 24)

                // Coach follow-up message
                if !flow.demoCoachFollowUpMessage.isEmpty {
                    coachMessageCard
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Action buttons
                actionButtons
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Timeline")
                    .font(.headline)
            }
        }
    }

    // MARK: - Logged Food Card

    private func loggedFoodCard(_ food: Food) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Food title
            Text(food.description)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)

            // Brand if available
            if let brand = food.brandText, !brand.isEmpty {
                Text(brand)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Macro summary
            HStack(spacing: 16) {
                macroItem(value: food.calories ?? 0, label: "cal", color: .orange)
                macroItem(value: food.protein ?? 0, label: "protein", color: .blue)
                macroItem(value: food.carbs ?? 0, label: "carbs", color: .green)
                macroItem(value: food.fat ?? 0, label: "fat", color: .purple)
            }

            // Serving info
            Text(food.servingSizeText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private func macroItem(value: Double, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(value))")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Coach Message Card

    private var coachMessageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("Coach")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            Text(flow.demoCoachFollowUpMessage)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Replay demo button
            if flow.showReplayButton {
                Button {
                    flow.replayDemo()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Replay demo")
                    }
                    .font(.body)
                    .foregroundColor(.primary)
                }
            }

            // Continue button
            Button {
                // Navigate to next onboarding step (allowHealth)
                onboardingViewModel.currentStep = .allowHealth
            } label: {
                Text("Continue")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary)
                    .foregroundColor(Color(.systemBackground))
                    .cornerRadius(36)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DemoTimelineView(flow: {
            let controller = DemoFlowController()
            controller.demoLoggedFood = DemoFoodData.createChipotleBowl()
            controller.demoCoachFollowUpMessage = DemoScript.postLogCoachMessage
            controller.showReplayButton = true
            controller.step = .done
            return controller
        }())
        .environmentObject(OnboardingViewModel())
    }
}
