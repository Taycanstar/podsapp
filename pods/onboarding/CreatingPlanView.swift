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
    
    var body: some View {
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
            
            // Only show recommendations card if no error
            if !showError {
                // Recommendations card
                VStack(alignment: .leading, spacing: 20) {
                    Text("Daily recommendation for")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.bottom, 5)
                       .foregroundColor(Color("bg"))
                    
                    Group {
                        HStack {
                            Text("•")
                                .font(.system(size: 15, weight: .bold))
                            Text("Calories: \(nutritionGoals != nil ? "\(Int(nutritionGoals!.calories)) kcal" : "Calculating...")")
                                .font(.system(size: 15))
                        }
                    .foregroundColor(Color("bg"))
                        
                        HStack {
                            Text("•")
                                .font(.system(size: 15, weight: .bold))
                            Text("Carbs: \(nutritionGoals != nil ? "\(Int(nutritionGoals!.carbs))g" : "Calculating...")")
                                .font(.system(size: 15))
                        }
                   .foregroundColor(Color("bg"))
                        
                        HStack {
                            Text("•")
                                .font(.system(size: 15, weight: .bold))
                            Text("Protein: \(nutritionGoals != nil ? "\(Int(nutritionGoals!.protein))g" : "Calculating...")")
                                        .font(.system(size: 15))
                        }
                     .foregroundColor(Color("bg"))
                        
                        HStack {
                            Text("•")
                                .font(.system(size: 15, weight: .bold))
                            Text("Fats: \(nutritionGoals != nil ? "\(Int(nutritionGoals!.fat))g" : "Calculating...")")
                                .font(.system(size: 15))
                        }
                      .foregroundColor(Color("bg"))
                    }
                }
                .padding(30)
                .background(Color.primary)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .onAppear {
            print("📱 CreatingPlanView appeared - starting loading sequence")
            UserDefaults.standard.set("CreatingPlanView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(15, forKey: "onboardingFlowStep") // Set as final step
            UserDefaults.standard.synchronize()
            startLoadingSequence()
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
    
    private func startLoadingSequence() {
        print("⏲️ Starting loading animation sequence in CreatingPlanView")
        
        // Start the loading animation immediately
        loadingProgress = 0.0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.loadingProgress < 0.95 { // Only go up to 95% until we get the response
                self.loadingProgress += 0.01
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        
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
            fitnessGoal: UserDefaults.standard.string(forKey: "fitnessGoal") ?? "",
            workoutFrequency: UserDefaults.standard.string(forKey: "workoutFrequency") ?? "",
            dietPreference: dietPreference,
            primaryWellnessGoal: primaryWellnessGoal,
            goalTimeframeWeeks: UserDefaults.standard.integer(forKey: "goalTimeframeWeeks"),
            weeklyWeightChange: UserDefaults.standard.double(forKey: "weeklyWeightChange"),
            obstacles: UserDefaults.standard.stringArray(forKey: "selectedObstacles"),
            addCaloriesBurned: UserDefaults.standard.bool(forKey: "addCaloriesBurned"),
            rolloverCalories: UserDefaults.standard.bool(forKey: "rolloverCalories")
        )
        
        // Debug print the full data being sent with precise values
        print("⬆️ Sending full onboarding data: \(onboardingData)")
        print("📊 Data precision check - Height: \(onboardingData.heightCm)cm, Weight: \(onboardingData.weightKg)kg, Desired: \(onboardingData.desiredWeightKg)kg")
        
        networkManager.processOnboardingData(userData: onboardingData) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Successfully processed onboarding data with server")
                    // Complete the loading animation
                    self.loadingProgress = 1.0
                    
                    // Now mark as completed locally
                    self.viewModel.onboardingCompleted = true
                    self.viewModel.saveOnboardingState()
                    
                    // Mark that onboarding is no longer in progress
                    UserDefaults.standard.set(false, forKey: "onboardingInProgress")
                    
                    // Ensure all state is synchronized
                    UserDefaults.standard.synchronize()
                    
                    // Wait a brief moment to show 100% completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("⏲️ Loading animation complete - calling completeOnboarding()")
                        self.completeOnboarding()
                    }
                case .failure(let error):
                    print("⚠️ Failed to process onboarding data with server: \(error)")
                    // Stop the loading animation
                    timer.invalidate()
                    
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
    
    /// Complete the onboarding process by marking it as complete on the server
    private func completeOnboarding() {
        // CRITICAL FIX: First check if onboarding is actually complete
        // We want to avoid corrupting the flag
        print("🚀 About to mark onboarding as complete - validating state")
        
        // Double check if we should actually mark as complete
        let currentStep = UserDefaults.standard.string(forKey: "currentOnboardingStep")
        if currentStep != "CreatingPlanView" {
            print("⚠️ WARNING: Trying to mark onboarding as complete when currentStep=\(currentStep ?? "nil")!")
            print("⚠️ Setting currentStep=CreatingPlanView to fix inconsistency")
            UserDefaults.standard.set("CreatingPlanView", forKey: "currentOnboardingStep")
        }
        
        // Make sure user is authenticated in UserDefaults
        UserDefaults.standard.set(true, forKey: "isAuthenticated")
        
        // Get the user's email for updating the server
        if let email = UserDefaults.standard.string(forKey: "userEmail") {
            // Save the email of the user who completed onboarding
            UserDefaults.standard.set(email, forKey: "emailWithCompletedOnboarding")
            print("✅ Saved email \(email) as the one who completed onboarding")
            
            NetworkManagerTwo.shared.markOnboardingCompleted(email: email) { result in
                switch result {
                case .success(let successful):
                    if successful {
                        print("✅ Server confirmed onboarding completion successfully")
                        
                        // Make sure to update all relevant state in the main thread
                        DispatchQueue.main.async {
                            // ONLY set serverOnboardingCompleted to true AFTER server confirms success
                            UserDefaults.standard.set(true, forKey: "serverOnboardingCompleted")
                            // Set all onboarding flags for this user
                            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                            UserDefaults.standard.set(false, forKey: "onboardingInProgress")
                            UserDefaults.standard.synchronize()
                            
                            // Mark onboarding as complete in the viewModel - this updates the UI
                            self.viewModel.onboardingCompleted = true
                            
                            // Mark completion in the viewModel and let it handle saving to UserDefaults
                            self.viewModel.completeOnboarding()
                            
                            // Post notification that authentication is complete
                            NotificationCenter.default.post(name: Notification.Name("AuthenticationCompleted"), object: nil)
                            
                            // Wait briefly then close the onboarding container (fixes dismissal glitch)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.viewModel.isShowingOnboarding = false
                            }
                        }
                    } else {
                        print("⚠️ Server returned failure when marking onboarding as completed")
                        // If the server call failed, we should not mark onboarding as completed
                        DispatchQueue.main.async {
                            print("⚠️ Resetting onboarding completion status due to server error")
                            UserDefaults.standard.set(false, forKey: "serverOnboardingCompleted")
                            UserDefaults.standard.set(false, forKey: "onboardingCompleted")
                            UserDefaults.standard.synchronize()
                            
                            // Still dismiss the view to avoid getting stuck
                            self.viewModel.isShowingOnboarding = false
                        }
                    }
                case .failure(let error):
                    print("⚠️ Failed to update server with onboarding completion: \(error)")
                    // If the server call failed, we should not mark onboarding as completed
                    DispatchQueue.main.async {
                        print("⚠️ Resetting onboarding completion status due to network error")
                        UserDefaults.standard.set(false, forKey: "serverOnboardingCompleted")
                        UserDefaults.standard.set(false, forKey: "onboardingCompleted")
                        UserDefaults.standard.synchronize()
                        
                        // Still dismiss the view to avoid getting stuck
                        self.viewModel.isShowingOnboarding = false
                    }
                }
            }
        } else {
            print("⚠️ Could not find email to update server onboarding status")
            // If no email, still dismiss the view to avoid getting stuck
            viewModel.isShowingOnboarding = false
        }
    }
}

#Preview {
    CreatingPlanView()
}
