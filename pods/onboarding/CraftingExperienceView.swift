//
//  CraftingExperienceView.swift
//  pods
//
//  Created by Dimi Nunez on 1/23/26.
//

import SwiftUI

/// Full-screen loading view shown during onboarding while setting up the user's experience
struct CraftingExperienceView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var completedSteps: Set<Int> = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var setupComplete = false

    private let steps: [(icon: String, title: String, subtitle: String)] = [
        ("person.fill.viewfinder", "Learning About You", "Analyzing your profile"),
        ("target", "Setting Your Goals", "Personalizing targets"),
        ("fork.knife", "Configuring Nutrition", "Calculating macros"),
        ("figure.run", "Building Your Plan", "Creating workouts"),
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
            startSetup()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 44))
                    .foregroundStyle(.linearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .symbolEffect(.pulse, options: .repeating)

                Text("Crafting Your Experience")
                    .font(.system(size: 28, weight: .bold))

                Text("Personalizing everything for you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 48)

            // Steps
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    CraftingStepRow(
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
                setupComplete = false
                startSetup()
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

    private func stepState(for index: Int) -> CraftingStepState {
        if completedSteps.contains(index) {
            return .completed
        } else if index == currentStep {
            return .inProgress
        } else {
            return .pending
        }
    }

    private func startSetup() {
        // Start the step animation
        startStepAnimation()

        // Run onboarding setup and program generation in parallel
        Task {
            await processOnboardingAndGenerateProgram()
        }
    }

    private func startStepAnimation() {
        // Fixed 4-second animation for consistent UX (backend finishes in ~3.4s, animation covers that)
        // 5 steps matching the steps array
        let stepDurations: [(start: Double, complete: Double)] = [
            (0.0, 0.8),    // Step 1: Learning About You
            (0.8, 1.6),    // Step 2: Setting Your Goals
            (1.6, 2.4),    // Step 3: Configuring Nutrition
            (2.4, 3.2),    // Step 4: Building Your Plan
            (3.2, 4.0)     // Step 5: Finalizing Experience
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

                // After last step completes, try to dismiss
                if index == steps.count - 1 {
                    tryDismiss()
                }
            }
        }
    }

    /// Try to dismiss - called when animation finishes or when setup completes
    private func tryDismiss() {
        // Small delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if setupComplete && completedSteps.count == steps.count {
                onComplete()
            }
        }
    }

    private func processOnboardingAndGenerateProgram() async {
        let networkManager = NetworkManagerTwo()

        // Get values from UserDefaults
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? viewModel.email

        guard !userEmail.isEmpty else {
            await MainActor.run {
                showError = true
                errorMessage = "User email is missing. Please try again."
            }
            return
        }

        let onboardingData = OnboardingData(
            email: userEmail,
            gender: UserDefaults.standard.string(forKey: "gender") ?? "",
            dateOfBirth: UserDefaults.standard.string(forKey: "dateOfBirth") ?? "",
            heightCm: UserDefaults.standard.double(forKey: "heightCentimeters"),
            weightKg: UserDefaults.standard.double(forKey: "weightKilograms"),
            desiredWeightKg: UserDefaults.standard.double(forKey: "desiredWeightKilograms"),
            dietGoal: UserDefaults.standard.string(forKey: "serverDietGoal") ?? "maintain",
            workoutFrequency: UserDefaults.standard.string(forKey: "workoutFrequency") ?? "",
            dietPreference: UserDefaults.standard.string(forKey: "dietPreference") ?? "",
            primaryWellnessGoal: UserDefaults.standard.string(forKey: "primaryWellnessGoal") ?? "",
            goalTimeframeWeeks: UserDefaults.standard.integer(forKey: "goalTimeframeWeeks"),
            weeklyWeightChange: UserDefaults.standard.double(forKey: "weeklyWeightChange"),
            obstacles: UserDefaults.standard.stringArray(forKey: "selectedObstacles"),
            addCaloriesBurned: UserDefaults.standard.bool(forKey: "addCaloriesBurned"),
            rolloverCalories: UserDefaults.standard.bool(forKey: "rolloverCalories"),
            fitnessLevel: UserDefaults.standard.string(forKey: "fitnessLevel"),
            fitnessGoal: UserDefaults.standard.string(forKey: "fitnessGoal"),
            sportType: UserDefaults.standard.string(forKey: "sportType")
        )

        print("📋 [CraftingExperienceView] Processing onboarding data...")

        // Process onboarding data first
        do {
            let nutritionGoals = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NutritionGoals, Error>) in
                networkManager.processOnboardingData(userData: onboardingData) { result in
                    switch result {
                    case .success(let goals):
                        continuation.resume(returning: goals)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }

            print("✅ [CraftingExperienceView] Onboarding data processed successfully")

            // Cache nutrition goals
            NutritionGoalsStore.shared.cache(goals: nutritionGoals)
            UserDefaults.standard.synchronize()

            // Now generate the training program
            await generateProgram()

        } catch {
            print("⚠️ [CraftingExperienceView] Failed to process onboarding: \(error.localizedDescription)")
            await MainActor.run {
                showError = true
                errorMessage = "Failed to set up your experience. Please try again."
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

        print("📋 [CraftingExperienceView] Generating program with:")
        print("   - fitnessGoal: '\(fitnessGoal)'")
        print("   - fitnessLevel: '\(fitnessLevel)'")
        print("   - workout_days_per_week: \(daysPerWeek)")
        print("   - trainingSplit: '\(trainingSplit)'")

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
            print("✅ [CraftingExperienceView] Successfully generated training program")

            await MainActor.run {
                setupComplete = true
                // Try to dismiss - if animation already finished, this will call onComplete
                tryDismiss()
            }
        } catch {
            print("⚠️ [CraftingExperienceView] Failed to generate program: \(error.localizedDescription)")
            await MainActor.run {
                showError = true
                errorMessage = "Failed to create your plan. Please try again."
            }
        }
    }
}

// MARK: - Crafting Step State

private enum CraftingStepState {
    case pending
    case inProgress
    case completed
}

// MARK: - Crafting Step Row

private struct CraftingStepRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let state: CraftingStepState
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
            return .purple
        case .inProgress:
            return .purple
        case .pending:
            return Color(UIColor.systemGray5)
        }
    }
}

#Preview {
    CraftingExperienceView(onComplete: {})
}
