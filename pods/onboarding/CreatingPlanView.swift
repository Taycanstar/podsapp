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
        
        // Start the loading animation immediately
        loadingProgress = 0.0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.loadingProgress < 0.95 { // Only go up to 95% until we get the response
                self.loadingProgress += 0.01
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
                    
                    // Save nutrition goals to UserDefaults for OnboardingPlanOverview
                    if let nutritionGoals = self.nutritionGoals {
                        let encoder = JSONEncoder()
                        if let encoded = try? encoder.encode(nutritionGoals) {
                            UserDefaults.standard.set(encoded, forKey: "nutritionGoalsData")
                    UserDefaults.standard.synchronize()
                        }
                    }
                    
                    // Wait a brief moment to show 100% completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("⏲️ Loading animation complete - navigating to OnboardingPlanOverview")
                        self.navigateToOverview = true
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
}

#Preview {
    CreatingPlanView()
}
