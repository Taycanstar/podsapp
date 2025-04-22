//
//  GoalInfoView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/7/25.
//

import SwiftUI

struct GoalInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var navigateToNextStep = false
    
    private var goal: String {
        return UserDefaults.standard.string(forKey: "fitnessGoal") ?? "Maintain"
    }
    
    private var isImperial: Bool {
        return UserDefaults.standard.bool(forKey: "isImperial")
    }
    
    private var currentWeight: Double {
        if isImperial {
            return Double(UserDefaults.standard.integer(forKey: "weightPounds"))
        } else {
            return Double(UserDefaults.standard.integer(forKey: "weightKilograms"))
        }
    }
    
    private var targetWeight: Double {
        // Get the desired weight from DesiredWeightView
        return UserDefaults.standard.double(forKey: "desiredWeight")
    }
    
    private var weightUnit: String {
        return isImperial ? "lbs" : "kg"
    }
    
    private var weightDifference: Double {
        return abs(targetWeight - currentWeight)
    }
    
    // Save any needed data
    private func saveData() {
        // No additional data to save at this step
    }
    
    var body: some View {
        ZStack {
            // Background color - update to match other onboarding views
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button(action: {
                        HapticFeedback.generate()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding()
                    }
                    
                    Spacer()
                    
                    // Progress bar
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .goalInfo), height: 4)
                            .cornerRadius(2)
                    }
                    .padding(.horizontal)
                }
                
                ScrollView {
                    VStack(spacing: 64) {
                        Spacer(minLength: 40)
                        
                        // Main content with combined text
                        VStack(spacing: 30) {
                            // Title with weight goal information - using Text concatenation for natural flow
                            if goal != "Maintain" {
                                (Text("\(goal == "Lose weight" ? "Losing" : "Gaining") ")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.primary)
                                + Text("\(Int(weightDifference)) \(weightUnit)")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.accentColor)
                                + Text(" is achievable with your plan!")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.primary))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            } else {
                                Text("Maintaining your weight is achievable with your plan!")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            
                            // Motivational text
                            Text("85% of Humuli users report significant changes following their personalized plan and maintaining results long-term.")
                                .font(.system(size: 15))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 40)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .frame(minHeight: UIScreen.main.bounds.height - 150)
                }
                
                // Continue button - match other onboarding views
                VStack {
                    Button(action: {
                        HapticFeedback.generate()
                        saveData()
                        navigateToNextStep = true
                    }) {
                        Text("Continue")
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
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: GoalTimeView(),
                isActive: $navigateToNextStep,
                label: { EmptyView() }
            )
        )
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("GoalInfoView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(6, forKey: "onboardingFlowStep") // Raw value for this step
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 GoalInfoView appeared - saved current step")
        }
    }
}

#Preview {
    GoalInfoView()
}
