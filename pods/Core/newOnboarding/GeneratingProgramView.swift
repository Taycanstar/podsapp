import SwiftUI

struct GeneratingProgramView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var completedSteps: Set<Int> = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var generationComplete = false

    private let steps: [(icon: String, title: String, subtitle: String)] = [
        ("person.fill.viewfinder", "Analyzing Profile", "Understanding your goals"),
        ("dumbbell.fill", "Selecting Exercises", "Matching your equipment"),
        ("chart.line.uptrend.xyaxis", "Building Progression", "Optimizing your gains"),
        ("calendar", "Scheduling Workouts", "Creating your calendar"),
        ("sparkles", "Finalizing Experience", "Almost ready...")
    ]

    var body: some View {
        ZStack {
            if showError {
                errorView
            } else {
                loadingView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            startGeneration()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 44))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .symbolEffect(.pulse, options: .repeating)

                Text("Crafting Your Plan")
                    .font(.system(size: 28, weight: .bold))

                Text("Setting everything up for you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 48)

            // Steps
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    GenerationStepRow(
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
    }

    private var errorView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(.red)

            Text("Something Went Wrong")
                .font(.system(size: 24, weight: .bold))

            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                showError = false
                errorMessage = ""
                currentStep = 0
                completedSteps.removeAll()
                generationComplete = false
                startGeneration()
            }) {
                Text("Try Again")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(width: 200)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            Spacer()
        }
    }

    private func stepState(for index: Int) -> GenerationStepState {
        if completedSteps.contains(index) {
            return .completed
        } else if index == currentStep {
            return .inProgress
        } else {
            return .pending
        }
    }

    private func startGeneration() {
        // Start the step animation
        startStepAnimation()

        // Generate the program in parallel
        Task {
            await generateProgram()
        }
    }

    private func startStepAnimation() {
        // Animate through steps with nice timing
        let stepDurations: [(start: Double, complete: Double)] = [
            (0.3, 1.8),    // Step 1: Analyzing Profile (1.5s)
            (2.0, 3.8),    // Step 2: Selecting Exercises (1.8s)
            (4.0, 5.8),    // Step 3: Building Progression (1.8s)
            (6.0, 7.6),    // Step 4: Scheduling Workouts (1.6s)
            (7.8, -1)      // Step 5: Finalizing (stays in progress until API returns)
        ]

        for (index, timing) in stepDurations.enumerated() {
            // Start step
            DispatchQueue.main.asyncAfter(deadline: .now() + timing.start) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = index
                }
            }

            // Complete step (except the last one which stays in progress)
            if timing.complete > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + timing.complete) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        _ = completedSteps.insert(index)
                    }
                }
            }
        }
    }

    private func generateProgram() async {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? viewModel.email
        let fitnessGoal = UserDefaults.standard.string(forKey: "fitnessGoal") ?? "balanced"
        let fitnessLevel = UserDefaults.standard.string(forKey: "fitnessLevel") ?? "intermediate"
        let daysPerWeek = UserDefaults.standard.integer(forKey: "workout_days_per_week")
        let trainingSplit = UserDefaults.standard.string(forKey: "trainingSplit") ?? "full_body"
        let sessionDuration = UserDefaults.standard.integer(forKey: "sessionDurationMinutes")
        let totalWeeks = UserDefaults.standard.integer(forKey: "programTotalWeeks")
        let isEndurance = fitnessGoal == "endurance"

        print("📋 [GeneratingProgramView] Generating program with:")
        print("   - userEmail: \(userEmail)")
        print("   - fitnessGoal: '\(fitnessGoal)'")
        print("   - fitnessLevel: '\(fitnessLevel)'")
        print("   - workout_days_per_week: \(daysPerWeek)")
        print("   - trainingSplit: '\(trainingSplit)'")
        print("   - sessionDurationMinutes: \(sessionDuration)")
        print("   - programTotalWeeks: \(totalWeeks)")

        guard !userEmail.isEmpty else {
            await MainActor.run {
                showError = true
                errorMessage = "User email is missing. Please try again."
            }
            return
        }

        let programType: ProgramType
        switch trainingSplit {
        case "push_pull_lower": programType = .ppl
        case "upper_lower": programType = .upperLower
        default: programType = .fullBody
        }

        let goal: ProgramFitnessGoal
        switch fitnessGoal {
        case "strength": goal = .strength
        case "hypertrophy": goal = .hypertrophy
        default: goal = .balanced
        }

        let experience: ProgramExperienceLevel
        switch fitnessLevel {
        case "beginner": experience = .beginner
        case "advanced": experience = .advanced
        default: experience = .intermediate
        }

        let effectiveDays = max(2, daysPerWeek > 0 ? daysPerWeek : 4)
        let effectiveDuration = sessionDuration > 0 ? sessionDuration : 60
        let effectiveWeeks = totalWeeks > 0 ? totalWeeks : 6

        print("🏋️ [GeneratingProgramView] Calling ProgramService.generateProgram")

        do {
            _ = try await ProgramService.shared.generateProgram(
                userEmail: userEmail,
                programType: programType,
                fitnessGoal: goal,
                experienceLevel: experience,
                daysPerWeek: effectiveDays,
                sessionDurationMinutes: effectiveDuration,
                totalWeeks: effectiveWeeks,
                includeDeload: true,
                includeCardio: isEndurance
            )
            print("✅ [GeneratingProgramView] Successfully generated training program")

            await MainActor.run {
                generationComplete = true
                // Complete the last step
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    _ = completedSteps.insert(steps.count - 1)
                }

                // Small delay after all steps complete, then finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onComplete()
                }
            }
        } catch {
            print("⚠️ [GeneratingProgramView] Failed to generate program: \(error.localizedDescription)")
            await MainActor.run {
                showError = true
                errorMessage = "Failed to create your plan. Please try again."
            }
        }
    }
}

// MARK: - Generation Step State

private enum GenerationStepState {
    case pending
    case inProgress
    case completed
}

// MARK: - Generation Step Row

private struct GenerationStepRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let state: GenerationStepState
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
            return .blue
        case .inProgress:
            return .blue
        case .pending:
            return Color(UIColor.systemGray5)
        }
    }
}
