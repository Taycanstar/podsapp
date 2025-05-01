//
//  AccomplishView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI

struct AccomplishView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var navigateToNextStep = false
    @State private var selectedGoal: Accomplishment?
    @State private var showAlert = false
    
    // Enum for accomplishment options
    enum Accomplishment: String, Identifiable, CaseIterable {
        case healthyHabits = "healthyHabits"
        case boost = "boost"
        case consistent = "consistent"
        case aesthetics = "aesthetics"
        
        var id: Self { self }
        
        var displayText: String {
            switch self {
            case .healthyHabits: return "Live a healthier lifestyle"
            case .boost: return "Boost my energy and vitality"
            case .consistent: return "Be consistent"
            case .aesthetics: return "Physical aesthetic"
            }
        }
        
        var icon: String {
            switch self {
            case .healthyHabits: return "leaf"
            case .boost: return "figure.run"
            case .consistent: return "water.waves"
            case .aesthetics: return "figure.dance"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress bar
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
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .accomplish), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("What's your primary wellness goal?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 30)
            
            Spacer()
            
            // Goal selection options
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Accomplishment.allCases) { goal in
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
                                
                                Text(goal.displayText)
                                    .font(.system(size: 15, weight: .medium))
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
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
                    
                    // Validate selection
                    if selectedGoal != nil {
                        saveUserGoal()
                        navigateToNextStep = true
                    } else {
                        showAlert = true
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
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Selection Required"),
                message: Text("Please select your primary wellness goal to continue."),
                dismissButton: .default(Text("OK"))
            )
        }
        .background(
            NavigationLink(
                destination: FitnessLevelView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("AccomplishView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(11, forKey: "onboardingFlowStep") // Raw value for this step
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 AccomplishView appeared - saved current step")
        }
    }
    
    // Save selected goal to UserDefaults
    private func saveUserGoal() {
        if let goal = selectedGoal {
            print("📝 Saving wellness goal: \(goal.rawValue)")
            UserDefaults.standard.set(goal.rawValue, forKey: "primaryWellnessGoal")
        }
    }
}

#Preview {
    AccomplishView()
}
