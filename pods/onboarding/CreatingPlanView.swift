//
//  CreatingPlanView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/19/25.
//

import SwiftUI

struct CreatingPlanView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var progress: CGFloat = 0.0
    @State private var percentage: Int = 0
    @State private var currentTask: String = "Customizing health plan..."
    @State private var nutritionGoals: NutritionGoals?
    @State private var loadingProgress: CGFloat = 0.0
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var navigateToOverview: Bool = false
    
    var body: some View {
        ZStack {
        VStack(spacing: 25) {
            Spacer()
            
            // Percentage display
            Text("\(Int(loadingProgress * 100))%")
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(.primary)
            
            // Status message
                Text(showError ? "Error Occurred" : "We're setting everything\nup for you")
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
            
            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                        .fill(showError ? Color.red : Color.accentColor)
                    .frame(width: UIScreen.main.bounds.width * 0.8 * loadingProgress, height: 8)
            }
            .frame(width: UIScreen.main.bounds.width * 0.8)
            .padding(.bottom, 30)
            
            // Current task text
            Text(currentTask)
                .font(.system(size: 18))
                    .foregroundColor(showError ? .red : .secondary)
                    .padding(.bottom, 20)
            
                // Error message when error occurs
                if showError {
                    Text(errorMessage)
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20)
                    
                    Button(action: {
                        // Reset error state and try again
                        self.showError = false
                        self.errorMessage = ""
                        self.currentTask = "Customizing health plan..."
                        self.loadingProgress = 0.0
                        self.startLoadingSequence()
                    }) {
                        Text("Try Again")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 150)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.bottom, 20)
                }
                
                Spacer()
            }
            
            NavigationLink(destination: OnboardingPlanOverview(), isActive: $navigateToOverview) {
                EmptyView()
            }
        }
        .onAppear {
            print("📱 CreatingPlanView appeared - starting loading sequence")
            UserDefaults.standard.set("CreatingPlanView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(15, forKey: "onboardingFlowStep") 
            UserDefaults.standard.synchronize()
            startLoadingSequence()
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
    
    private func startLoadingSequence() {
        print("⏲️ Starting loading animation sequence in CreatingPlanView")
        
        // Start the loading animation immediately - reach 95% in ~5s to match backend generation time
        loadingProgress = 0.0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.loadingProgress < 0.95 { // Only go up to 95% until we get the response
                self.loadingProgress += 0.02  // 0.02 per 0.1s = 95% in ~4.75s
            }
        }
        
        // First, send the onboarding data to the server
        let networkManager = NetworkManagerTwo()
        
        // Get values from UserDefaults
        let dietPreference = UserDefaults.standard.string(forKey: "dietPreference") ?? ""
        let primaryWellnessGoal = UserDefaults.standard.string(forKey: "primaryWellnessGoal") ?? ""
        
        print("📊 Sending onboarding data to server:")
        print("Diet Preference: \(dietPreference)")
        print("Primary Wellness Goal: \(primaryWellnessGoal)")
        
        let onboardingData = OnboardingData(
            email: UserDefaults.standard.string(forKey: "userEmail") ?? "",
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
        
        // Guard against missing email
        if onboardingData.email.isEmpty {
            print("❌ Cannot proceed: user email is missing. Please log in again.")
            // Optionally show a user-facing error here
            return
        }
        
        // Debug print the full data being sent with precise values
        print("⬆️ Sending full onboarding data: \(onboardingData)")
        print("📊 Data precision check - Height: \(onboardingData.heightCm)cm, Weight: \(onboardingData.weightKg)kg, Desired: \(onboardingData.desiredWeightKg)kg")
        
        networkManager.processOnboardingData(userData: onboardingData) { result in
            DispatchQueue.main.async {
                timer.invalidate() // Stop the timer
                
                switch result {
                case .success(let response):
                    print("✅ Successfully processed onboarding data with server")
                    // Complete the loading animation
                    self.loadingProgress = 1.0
                    self.nutritionGoals = response

                    // Save nutrition goals via the shared store so every surface stays in sync
                    if let nutritionGoals = self.nutritionGoals {
                        NutritionGoalsStore.shared.cache(goals: nutritionGoals)
                        UserDefaults.standard.synchronize()
                        print("📝 DEBUG: Cached nutrition goals: Calories=\(nutritionGoals.calories), Protein=\(nutritionGoals.protein)g, Carbs=\(nutritionGoals.carbs)g, Fat=\(nutritionGoals.fat)g")
                    } else {
                        print("⚠️ ERROR: No nutritionGoals available to save to UserDefaults")
                    }

                    // Generate training program and THEN navigate
                    Task {
                        await self.generateInitialProgram()

                        // Navigate after program generation completes
                        await MainActor.run {
                            print("⏲️ Program generation complete - navigating to OnboardingPlanOverview")
                            self.navigateToOverview = true
                        }
                    }
                case .failure(let error):
                    print("⚠️ Failed to process onboarding data with server: \(error)")
                    
                    // Handle specific error cases
                    if let networkError = error as? NetworkManagerTwo.NetworkError {
                        print("❌ Network error details: \(networkError.localizedDescription)")
                        self.errorMessage = "Error: \(networkError.localizedDescription)"
                    } else {
                        self.errorMessage = "Failed to process your data. Please try again."
                    }
                    
                    self.showError = true
                    self.currentTask = "Error processing your data. Please try again."
                    }
                }
        }
    }

    private func generateInitialProgram() async {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        let fitnessGoal = UserDefaults.standard.string(forKey: "fitnessGoal") ?? "balanced"
        let fitnessLevel = UserDefaults.standard.string(forKey: "fitnessLevel") ?? "intermediate"
        let daysPerWeek = UserDefaults.standard.integer(forKey: "workout_days_per_week")
        let trainingSplit = UserDefaults.standard.string(forKey: "trainingSplit") ?? "full_body"
        let sessionDuration = UserDefaults.standard.integer(forKey: "sessionDurationMinutes")
        let totalWeeks = UserDefaults.standard.integer(forKey: "programTotalWeeks")
        let isEndurance = fitnessGoal == "endurance"

        print("📋 Raw UserDefaults values for program generation:")
        print("   - userEmail: \(userEmail)")
        print("   - fitnessGoal (raw): '\(UserDefaults.standard.string(forKey: "fitnessGoal") ?? "nil")'")
        print("   - fitnessLevel (raw): '\(UserDefaults.standard.string(forKey: "fitnessLevel") ?? "nil")'")
        print("   - workout_days_per_week (raw): \(daysPerWeek)")
        print("   - trainingSplit (raw): '\(UserDefaults.standard.string(forKey: "trainingSplit") ?? "nil")'")
        print("   - sessionDurationMinutes (raw): \(sessionDuration)")
        print("   - programTotalWeeks (raw): \(totalWeeks)")

        guard !userEmail.isEmpty else {
            print("⚠️ Cannot generate program: user email is missing")
            return
        }

        // Map split to ProgramType
        let programType: ProgramType
        switch trainingSplit {
        case "push_pull_lower":
            programType = .ppl
        case "upper_lower":
            programType = .upperLower
        default:
            programType = .fullBody
        }

        // Map fitness goal
        let goal: ProgramFitnessGoal
        switch fitnessGoal {
        case "strength":
            goal = .strength
        case "hypertrophy":
            goal = .hypertrophy
        case "endurance":
            goal = .balanced  // Use balanced with cardio flag for endurance
        default:
            goal = .balanced
        }

        // Map experience level
        let experience: ProgramExperienceLevel
        switch fitnessLevel {
        case "beginner":
            experience = .beginner
        case "advanced":
            experience = .advanced
        default:
            experience = .intermediate
        }

        let effectiveDays = max(2, daysPerWeek > 0 ? daysPerWeek : 4)
        let effectiveDuration = sessionDuration > 0 ? sessionDuration : 60
        let effectiveWeeks = totalWeeks > 0 ? totalWeeks : 6

        print("🏋️ Generating initial training program:")
        print("   - Program Type: \(programType.rawValue)")
        print("   - Fitness Goal: \(goal.rawValue)")
        print("   - Experience: \(experience.rawValue)")
        print("   - Days/Week: \(effectiveDays)")
        print("   - Duration: \(effectiveDuration) min")
        print("   - Total Weeks: \(effectiveWeeks)")
        print("   - Include Cardio: \(isEndurance)")

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
            print("✅ Auto-generated training program after onboarding")
        } catch {
            print("⚠️ Failed to generate program: \(error.localizedDescription)")
            // Non-fatal - user can create program manually later
        }
    }
}

#Preview {
    CreatingPlanView()
}
