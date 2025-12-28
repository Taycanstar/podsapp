//
//  DemoTimelineView.swift
//  pods
//
//  Timeline view for the onboarding demo.
//  Matches the actual TimelineView structure with spine, connectors, and cards.
//

import SwiftUI

struct DemoTimelineView: View {
    @ObservedObject var flow: DemoFlowController
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var dateSubtitle: String {
        let monthDayFormatter = DateFormatter()
        monthDayFormatter.dateFormat = "MMMM d"
        let monthDay = monthDayFormatter.string(from: Date())
        return "Today, \(monthDay)"
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Date subtitle above the timeline section
                        Text(dateSubtitle)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 16)

                        ZStack(alignment: .leading) {
                            // Timeline spine
                            DemoTimelineSpine()

                            VStack(spacing: 20) {
                                // Quick actions row
                                DemoQuickActionsRow()

                                // Logged food entry
                                if let food = flow.demoLoggedFood {
                                    demoFoodLogRow(food)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }

                Spacer()

                // Action buttons at bottom
                actionButtons
            }
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Demo Food Log Row

    private func demoFoodLogRow(_ food: Food) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top: Connector + time label
            HStack(alignment: .center, spacing: 12) {
                DemoTimelineConnector(iconName: "fork.knife")
                    .frame(height: DemoTimelineConnector.iconSize)

                Text(timeLabel)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            // Food card
            HStack(alignment: .top, spacing: 12) {
                DemoTimelineConnectorSpacer()
                demoFoodCard(food)
            }

            // Coach message (if available)
            if !flow.demoCoachFollowUpMessage.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    DemoTimelineConnectorSpacer()
                    demoCoachMessageCard
                        .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Food Card (matching TimelineLogCard)

    private func demoFoodCard(_ food: Food) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(food.description)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            // Macro details
            HStack(spacing: 12) {
                demoLabel(icon: "flame.fill", text: "\(Int(food.calories ?? 0)) cal", color: Color("brightOrange"))
                demoMacroLabel(prefix: "P", value: Int(food.protein ?? 0))
                demoMacroLabel(prefix: "F", value: Int(food.fat ?? 0))
                demoMacroLabel(prefix: "C", value: Int(food.carbs ?? 0))
            }
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("sheetcard"))
        )
    }

    private func demoLabel(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
        }
    }

    private func demoMacroLabel(prefix: String, value: Int) -> some View {
        Text("\(prefix) \(value)g")
    }

    // MARK: - Coach Message Card

    private var demoCoachMessageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Coach")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Text(flow.demoCoachFollowUpMessage)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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

// MARK: - Demo Timeline Spine

private struct DemoTimelineSpine: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let color = colorScheme == .dark ? Color(.systemGray3) : Color(.systemGray4)
            ZStack(alignment: .center) {
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: geometry.size.height)
                    .position(x: DemoTimelineConnector.iconSize / 2, y: geometry.size.height / 2)

                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .position(x: DemoTimelineConnector.iconSize / 2, y: geometry.size.height - 4)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Demo Timeline Connector

private struct DemoTimelineConnector: View {
    @Environment(\.colorScheme) private var colorScheme
    let iconName: String
    var overrideColor: Color? = nil

    static let iconSize: CGFloat = 34

    var body: some View {
        let circleColor = overrideColor ?? (colorScheme == .dark ? Color(.systemGray2) : Color.black.opacity(0.9))

        ZStack {
            Circle()
                .fill(circleColor)
                .frame(width: Self.iconSize, height: Self.iconSize)
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: Self.iconSize, height: Self.iconSize)
    }
}

// MARK: - Demo Timeline Connector Spacer

private struct DemoTimelineConnectorSpacer: View {
    var body: some View {
        Color.clear
            .frame(width: DemoTimelineConnector.iconSize)
    }
}

// MARK: - Demo Quick Actions Row

private struct DemoQuickActionsRow: View {
    @Environment(\.colorScheme) private var colorScheme

    private let foregroundColor = Color("text")

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DemoTimelineConnector(
                iconName: "plus",
                overrideColor: plusColor
            )

            HStack(spacing: 12) {
                quickActionChip(title: "Add Activity", systemImage: "flame.fill")
                quickActionChip(title: "Scan Meal", systemImage: "fork.knife")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quickActionChip(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .regular))
            Text(title)
                .font(.system(size: 13, weight: .regular))
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color("background"))
        .clipShape(Capsule())
        .opacity(0.5) // Disabled appearance for demo
    }

    private var plusColor: Color {
        colorScheme == .dark ? Color(.systemGray2) : Color.black.opacity(0.9)
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
