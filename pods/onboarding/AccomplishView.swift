//
//  AccomplishView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI

struct AccomplishView: View {
    @Environment(\.dismiss) var dismiss
    @State private var navigateToNextStep = false
    @State private var selectedGoal: UserGoal = .consistent
    
    // Enum for goal options
    enum UserGoal: String, Identifiable, CaseIterable {
        case healthier = "Improve my nutrition habits"
        case energy = "Enhance my vitality and wellbeing"
        case consistent = "Stay consistent and inspired"
        case confidence = "Develop a positive body image"
        
        var id: Self { self }
        
        var icon: String {
            switch self {
            case .healthier: return "carrot"
            case .energy: return "sun.max"
            case .consistent: return "figure.walk"
            case .confidence: return "person.fill"
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
                        .frame(width: UIScreen.main.bounds.width, height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("What's your primary wellness goal?")
                    .font(.system(size: 32, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 30)
            
            Spacer()
            
            // Goal selection options
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(UserGoal.allCases) { goal in
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
                                
                                Text(goal.rawValue)
                                    .font(.system(size: 15, weight: .medium))
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .background(selectedGoal == goal ? Color.accentColor : Color("iosbg"))
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
                    saveUserGoal()
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
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: ConnectToAppleHealth(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
    }
    
    // Save selected goal to UserDefaults
    private func saveUserGoal() {
        UserDefaults.standard.set(selectedGoal.rawValue, forKey: "primaryWellnessGoal")
    }
}

#Preview {
    AccomplishView()
}
