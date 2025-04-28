//
//  OnboardingPlanOverview.swift
//  Pods
//
//  Created by Dimi Nunez on 4/27/25.
//

import SwiftUI

struct OnboardingPlanOverview: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var nutritionGoals: NutritionGoals?
    @State private var completionDate: String = ""
    @State private var weightDifferenceFormatted: String = ""
    @State private var weightUnit: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Plan Overview")
                .font(.system(size: 32, weight: .bold))
                .padding(.top, 40)
                .padding(.bottom, 20)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Goals
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Goals")
                            .font(.system(size: 20, weight: .bold))
                        
                        // Weight goal with date
                        let goal = UserDefaults.standard.string(forKey: "fitnessGoal") ?? "maintain"
                        if goal != "maintain" && !completionDate.isEmpty {
                            Text("\(weightDifferenceFormatted) \(weightUnit) by \(completionDate)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Nutrition cards
                        VStack(spacing: 12) {
                            // Calories card
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Calories")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("\(Int(nutritionGoals?.calories ?? 0))")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                            
                            // Protein card
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "figure.walk")
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Protein")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("\(Int(nutritionGoals?.protein ?? 0))g")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                            
                            // Carbs card
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "chart.bar.fill")
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Carbs")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("\(Int(nutritionGoals?.carbs ?? 0))g")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                            
                            // Fats card
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "drop.fill")
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fats")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("\(Int(nutritionGoals?.fat ?? 0))g")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Recommendations
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendations")
                            .font(.system(size: 20, weight: .bold))
                        
                        // Log food daily card
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "fork.knife")
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Log Food Daily")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Use AI to describe, scan, upload, or speak your meal")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        
                        // Meet goals card
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Meet Goals")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Unlock trends and insights by hitting your daily targets")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        
                        // Track trends card
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Track Trends")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("Visualize your logging history to spot patterns and fine-tune your nutrition and fitness")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Insights sections
                    if let insights = nutritionGoals?.metabolismInsights, !insights.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Metabolic Insights")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            // Primary Analysis
                            if let primaryAnalysis = insights.primaryAnalysis {
                                Text("Overview")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.top, 8)
                                
                                Text(primaryAnalysis)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)
                            }
                            
                            // Practical Implications
                            if let practicalImplications = insights.practicalImplications {
                                Text("Key Takeaways")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.top, 8)
                                
                                Text(practicalImplications)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)
                            }
                            
                            // Optimization Strategies
                            if let optimizationStrategies = insights.optimizationStrategies {
                                Text("Action Plan")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.top, 8)
                                
                                // Split into bullet points
                                let strategies = optimizationStrategies.components(separatedBy: ". ")
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(strategies, id: \.self) { strategy in
                                        if !strategy.isEmpty {
                                            HStack(alignment: .top, spacing: 8) {
                                                Text("•")
                                                    .foregroundColor(.primary)
                                                Text(strategy)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Research Backing
                            if let researchBacking = insights.researchBacking, !researchBacking.isEmpty {
                                Text("Research Sources")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.top, 8)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(researchBacking.enumerated()), id: \.element.insight) { index, research in
                                        if let insight = research.insight {
                                            HStack(alignment: .top, spacing: 8) {
                                                Text("[\(index + 1)]")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.accentColor)
                                                    .frame(width: 30, height: 30)
                                                    .background(Color.accentColor.opacity(0.1))
                                                    .cornerRadius(15)
                                                    .onTapGesture {
                                                        if let url = URL(string: research.citation ?? "") {
                                                            UIApplication.shared.open(url)
                                                        }
                                                    }
                                                
                                                Text(insight)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    if let insights = nutritionGoals?.nutritionInsights, !insights.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nutrition Insights")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            // Primary Analysis
                            if let primaryAnalysis = insights.primaryAnalysis {
                                Text("Overview")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.top, 8)
                                
                                Text(primaryAnalysis)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)
                            }
                            
                            // Practical Implications
                            if let practicalImplications = insights.practicalImplications {
                                Text("Key Takeaways")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.top, 8)
                                
                                Text(practicalImplications)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)
                            }
                            
                            // Optimization Strategies
                            if let optimizationStrategies = insights.optimizationStrategies {
                                Text("Action Plan")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.top, 8)
                                
                                // Split into bullet points
                                let strategies = optimizationStrategies.components(separatedBy: ". ")
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(strategies, id: \.self) { strategy in
                                        if !strategy.isEmpty {
                                            HStack(alignment: .top, spacing: 8) {
                                                Text("•")
                                                    .foregroundColor(.primary)
                                                Text(strategy)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Research Backing
                            if let researchBacking = insights.researchBacking, !researchBacking.isEmpty {
                                Text("Research Sources")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.top, 8)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(researchBacking.enumerated()), id: \.element.insight) { index, research in
                                        if let insight = research.insight {
                                            HStack(alignment: .top, spacing: 8) {
                                                Text("[\(index + 1)]")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.accentColor)
                                                    .frame(width: 30, height: 30)
                                                    .background(Color.accentColor.opacity(0.1))
                                                    .cornerRadius(15)
                                                    .onTapGesture {
                                                        if let url = URL(string: research.citation ?? "") {
                                                            UIApplication.shared.open(url)
                                                        }
                                                    }
                                                
                                                Text(insight)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Get Started Button
            VStack {
                Button(action: {
                    HapticFeedback.generate()
                    completeOnboarding()
                }) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .padding(.bottom, 24)
            .background(Material.ultraThin)
        }
        .background(Color(UIColor.systemBackground))
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("OnboardingPlanOverview", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(16, forKey: "onboardingFlowStep") // Set as final step
            UserDefaults.standard.synchronize()
            
            // Get nutrition goals from previous view
            if let data = UserDefaults.standard.data(forKey: "nutritionGoalsData") {
                let decoder = JSONDecoder()
                self.nutritionGoals = try? decoder.decode(NutritionGoals.self, from: data)
            }
            
            // Calculate weight difference and format
            let weightDifference = abs(
                UserDefaults.standard.double(forKey: "desiredWeightKilograms") - 
                UserDefaults.standard.double(forKey: "weightKilograms")
            ) * (UserDefaults.standard.bool(forKey: "isImperial") ? 2.20462 : 1)
            self.weightDifferenceFormatted = "\(Int(weightDifference))"
            self.weightUnit = UserDefaults.standard.bool(forKey: "isImperial") ? "lbs" : "kg"
            
            // Calculate completion date
            if let dateString = UserDefaults.standard.string(forKey: "goalCompletionDate") {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: dateString) {
                    formatter.dateFormat = "MMMM d"
                    self.completionDate = formatter.string(from: date)
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
        if currentStep != "OnboardingPlanOverview" {
            print("⚠️ WARNING: Trying to mark onboarding as complete when currentStep=\(currentStep ?? "nil")!")
            print("⚠️ Setting currentStep=OnboardingPlanOverview to fix inconsistency")
            UserDefaults.standard.set("OnboardingPlanOverview", forKey: "currentOnboardingStep")
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
    OnboardingPlanOverview()
        .environmentObject(OnboardingViewModel())
}
