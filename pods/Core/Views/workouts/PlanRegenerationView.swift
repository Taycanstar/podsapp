//
//  PlanRegenerationView.swift
//  pods
//
//  Created by Dimi Nunez on 1/22/26.
//

import SwiftUI

// MARK: - Plan Regeneration View

/// Full-screen loading view shown while regenerating a training plan
struct PlanRegenerationView: View {
    let experienceLevel: String
    let splitName: String
    let weeks: Int
    @Binding var isComplete: Bool
    let onDismiss: () -> Void

    @State private var currentStep = 0
    @State private var completedSteps: Set<Int> = []

    private let steps: [(icon: String, title: String, subtitle: String)] = [
        ("arrow.triangle.2.circlepath", "Preserving Progress", "Keeping completed workouts"),
        ("dumbbell.fill", "Updating Exercises", "Applying new preferences"),
        ("figure.strengthtraining.traditional", "Rebuilding Structure", "Adjusting periodization"),
        ("chart.line.uptrend.xyaxis", "Recalculating Progression", "Optimizing volume curves"),
        ("calendar", "Rescheduling Workouts", "Updating your calendar"),
        ("checkmark.seal.fill", "Finalizing Changes", "Almost ready...")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 44))
                    .foregroundStyle(.linearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .symbolEffect(.pulse, options: .repeating)

                Text("Regenerating Plan")
                    .font(.system(size: 28, weight: .bold))

                Text("\(experienceLevel) \(splitName) \u{2022} \(weeks) weeks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 48)

            // Steps
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    RegenerationStepRow(
                        icon: step.icon,
                        title: step.title,
                        subtitle: step.subtitle,
                        state: stepState(for: index),
                        isLast: index == steps.count - 1
                    )
                }
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            startAnimation()
        }
    }

    private func stepState(for index: Int) -> RegenerationStepState {
        if completedSteps.contains(index) {
            return .completed
        } else if index == currentStep {
            return .inProgress
        } else {
            return .pending
        }
    }

    private func startAnimation() {
        // Fixed 5-second animation for consistent UX (backend finishes in ~2s, well before animation ends)
        // 6 steps = ~0.83s each
        let stepDurations: [(start: Double, complete: Double)] = [
     (0.0, 0.7),   
            (0.7, 1.3),    
            (1.3, 2.0),    
            (2.0, 3.0),    
            (3.0, 3.5),
            (3.5, 4.0)  
        ]

        for (index, timing) in stepDurations.enumerated() {
            // Start step
            DispatchQueue.main.asyncAfter(deadline: .now() + timing.start) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = index
                }
            }

            // Complete step
            DispatchQueue.main.asyncAfter(deadline: .now() + timing.complete) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    _ = completedSteps.insert(index)
                }

                // After last step completes, call onDismiss if regeneration is done
                if index == steps.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if isComplete {
                            onDismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Regeneration Step State

private enum RegenerationStepState {
    case pending
    case inProgress
    case completed
}

// MARK: - Regeneration Step Row

private struct RegenerationStepRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let state: RegenerationStepState
    let isLast: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Icon/Status indicator
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 44, height: 44)

                if state == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                } else if state == .inProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: state == .inProgress ? .semibold : .medium))
                    .foregroundColor(state == .pending ? .secondary : .primary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .opacity(state == .pending ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: state)
    }

    private var backgroundColor: Color {
        switch state {
        case .completed:
            return .orange
        case .inProgress:
            return .orange
        case .pending:
            return Color(UIColor.systemGray5)
        }
    }
}

#Preview {
    PlanRegenerationView(
        experienceLevel: "Intermediate",
        splitName: "Full Body",
        weeks: 8,
        isComplete: .constant(false),
        onDismiss: {}
    )
}
