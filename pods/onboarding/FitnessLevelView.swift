//
//  FitnessLevelView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/30/25.
//

import SwiftUI

struct FitnessLevelView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedLevel: FitnessLevel = .beginner
    @State private var navigateToNextStep = false
    
    // Enum for fitness level options
    enum FitnessLevel: String, Identifiable, CaseIterable {
        case beginner
        case intermediate
        case advanced
        
        var id: Self { self }
        
        var title: String {
            switch self {
            case .beginner: return "Beginner"
            case .intermediate: return "Intermediate"
            case .advanced: return "Advanced"
            }
        }
        
        var description: String {
            switch self {
            case .beginner: return "0-12 months"
            case .intermediate: return "1-3 years"
            case .advanced: return "3+ years"
            }
        }
        
        var icon: String {
            switch self {
            case .beginner: return "figure.walk"
            case .intermediate: return "figure.run"
            case .advanced: return "figure.strengthtraining.traditional"
            }
        }
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
                
                // Progress bar
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .fitnessLevel), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("What's your fitness level?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("We'll use this to personalize your experience.")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 40)
            
            Spacer()
            
            // Fitness level selection buttons
            VStack(spacing: 16) {
                ForEach(FitnessLevel.allCases) { level in
                    Button(action: {
                        HapticFeedback.generate()
                        selectedLevel = level
                    }) {
                        HStack {
                            Image(systemName: level.icon)
                                .font(.system(size: 22))
                                .foregroundColor(selectedLevel == level ? .white : .primary)
                                .frame(width: 30)
                                .padding(.leading, 16)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.title)
                                    .font(.system(size: 18, weight: .medium))
                                
                                Text(level.description)
                                    .font(.system(size: 14))
                                    .opacity(0.8)
                            }
                            .padding(.leading, 8)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(
                            selectedLevel == level ? 
                                Color.accentColor : 
                                (colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemGray6))
                        )
                        .foregroundColor(selectedLevel == level ? .white : .primary)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue button
            VStack {
                Button(action: {
                    HapticFeedback.generate()
                    UserDefaults.standard.set(selectedLevel.rawValue, forKey: "fitnessLevel")
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
        .background(Color(UIColor.systemBackground))
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: FitnessGoalView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("FitnessLevelView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(7, forKey: "onboardingFlowStep") // Adjust based on flow position
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 FitnessLevelView appeared - saved current step")
        }
    }
}

#Preview {
    FitnessLevelView()
}
