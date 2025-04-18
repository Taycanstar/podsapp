//
//  OnboardingGoal.swift
//  Pods
//
//  Created by Dimi Nunez on 6/7/25.
//

import SwiftUI

struct OnboardingGoal: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedGoal: Goal = .loseWeight
    @State private var navigateToNextStep = false
    
    // Enum for goal options
    enum Goal: String, CaseIterable {
        case loseWeight = "Lose weight"
        case maintain = "Maintain"
        case gainWeight = "Gain weight"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation and progress bar
            VStack(spacing: 16) {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // Progress bar - 5/5 completed (100%)
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: UIScreen.main.bounds.width * 0.9, height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("What's your goal?")
                    .font(.system(size: 32, weight: .bold))
                
                Text("This will be used to calibrate your custom plan.")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 40)
            
            Spacer()
            
            // Goal selection buttons
            VStack(spacing: 16) {
                ForEach(Goal.allCases, id: \.self) { goal in
                    Button(action: {
                        HapticFeedback.generate()
                        selectedGoal = goal
                    }) {
                        Text(goal.rawValue)
                            .font(.system(size: 18, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(selectedGoal == goal ? Color.accentColor : Color("iosbg"))
                            .foregroundColor(selectedGoal == goal ? .white : .primary)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue button
            VStack {
                NavigationLink(destination: DesiredWeightView(), isActive: $navigateToNextStep) {
                    Button(action: {
                        HapticFeedback.generate()
                        saveGoal()
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
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .padding(.bottom, 24)
            .background(Material.ultraThin)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
    }
    
    private func saveGoal() {
        // Save the selected goal to UserDefaults
        UserDefaults.standard.set(selectedGoal.rawValue, forKey: "fitnessGoal")
    }
}

#Preview {
    OnboardingGoal()
}

