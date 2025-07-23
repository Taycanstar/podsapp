//
//  FitnessGoalView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/30/25.
//

import SwiftUI

struct FitnessGoalView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedGoal: FitnessGoalType = .strength
    @State private var navigateToNextStep = false
    @State private var navigateToSportSelection = false
    
    // Enum for fitness goal options
    enum FitnessGoalType: String, Identifiable, CaseIterable {
        case strength
        case hypertrophy
        case tone
        case endurance
        case powerlifting
        case sportsPerformance = "sport"
        case general
        
        var id: Self { self }
        
        var title: String {
            switch self {
            case .strength: return "Strength"
            case .hypertrophy: return "Hypertrophy"
            case .tone: return "Tone"
            case .endurance: return "Endurance"
            case .powerlifting: return "Powerlifting"
            case .sportsPerformance: return "Sports Performance"
            case .general: return "Genera Fitness"
            }
        }
        
        var description: String {
            switch self {
            case .strength: return "Build functional strength for everyday activities"
            case .hypertrophy: return "Maximize muscle size and definition"
            case .tone: return "Achieve lean, defined muscles without bulk"
            case .endurance: return "Improve stamina and cardiovascular fitness"
            case .powerlifting: return "Focus on maximal strength in major lifts"
            case .sportsPerformance: return "Optimize performance for specific sports"
            case .general: return "General fitness and health"
            }
        }
        
        var icon: String {
            switch self {
            case .strength: return "figure.strengthtraining.traditional"
            case .hypertrophy: return "figure.strengthtraining.functional"
            case .tone: return "figure.mixed.cardio"
            case .endurance: return "figure.run"
            case .powerlifting: return "dumbbell"
            case .sportsPerformance: return "figure.handball"
            case .general: return "figure.run"
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
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .fitnessGoal), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("What's your fitness goal?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("We'll use this to personalize your plan.")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 20)
            
            // Fitness goal selection
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(FitnessGoalType.allCases) { goal in
                        Button(action: {
                            HapticFeedback.generate()
                            selectedGoal = goal
                        }) {
                            HStack {
                                Image(systemName: goal.icon)
                                    .font(.system(size: 22))
                                    .foregroundColor(selectedGoal == goal ? .white : .primary)
                                    .frame(width: 30)
                                    .padding(.leading, 16)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(goal.title)
                                        .font(.system(size: 18, weight: .medium))
                                    
                                    Text(goal.description)
                                        .font(.system(size: 14))
                                        .opacity(0.8)
                                }
                                .padding(.leading, 8)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(
                                selectedGoal == goal ? 
                                    Color.accentColor : 
                                    (colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemGray6))
                            )
                            .foregroundColor(selectedGoal == goal ? .white : .primary)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Continue button
            VStack {
                Button(action: {
                    HapticFeedback.generate()
                    UserDefaults.standard.set(selectedGoal.rawValue, forKey: "fitnessGoalType")
                    
                    // Also save the same value for backward compatibility with server
                    UserDefaults.standard.set(selectedGoal.rawValue, forKey: "fitness_goal")
                    
                    // If Sports Performance is selected, navigate to sport selection
                    // Otherwise, navigate to Apple Health
                    if selectedGoal == .sportsPerformance {
                        navigateToSportSelection = true
                    } else {
                        navigateToNextStep = true
                    }
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
            Group {
                // Conditional navigation based on selected goal
                NavigationLink(
                    destination: ConnectToAppleHealth(),
                    isActive: $navigateToNextStep
                ) {
                    EmptyView()
                }
                
                NavigationLink(
                    destination: SportSelectionView(),
                    isActive: $navigateToSportSelection
                ) {
                    EmptyView()
                }
            }
        )
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("FitnessGoalView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(12, forKey: "onboardingFlowStep") // Adjust based on flow position
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 FitnessGoalView appeared - saved current step")
        }
    }
}

#Preview {
    FitnessGoalView()
}
