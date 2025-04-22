//
//  ObstaclesView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI

struct ObstaclesView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var navigateToNextStep = false
    @State private var selectedObstacles: Set<Obstacle> = []
    
    // Enum for obstacle options
    enum Obstacle: String, Identifiable, CaseIterable {
        case inconsistency = "Inconsistency"
        case nutrition = "Poor nutrition habits"
        case support = "Limited support network"
        case time = "Time constraints"
        case inspiration = "Meal planning challenges"
        
        var id: Self { self }
        
        var icon: String {
            switch self {
            case .inconsistency: return "chart.bar"
            case .nutrition: return "takeoutbag.and.cup.and.straw"
            case .support: return "hand.raised"
            case .time: return "calendar"
            case .inspiration: return "fork.knife"
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
                        .frame(width: UIScreen.main.bounds.width * OnboardingProgress.progressFor(screen: .obstacles), height: 4)
                        .cornerRadius(2)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Title and instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("What's holding you back from reaching your goals?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Select all that apply.")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 30)

            Spacer()
            
            // Obstacle selection options
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Obstacle.allCases) { obstacle in
                        Button(action: {
                            toggleObstacle(obstacle)
                        }) {
                            HStack {
                                Image(systemName: obstacle.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(isSelected(obstacle) ? .white : .primary)
                                    .frame(width: 30)
                                    .padding(.leading, 16)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(obstacle.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    
                                }
                                .padding(.leading, 8)
                                
                                Spacer()
                                
                                if isSelected(obstacle) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .padding(.trailing, 16)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .background(isSelected(obstacle) ? Color.accentColor : (colorScheme == .dark ? Color(UIColor.systemGray6) : Color(UIColor.systemGray6)))
                            .foregroundColor(isSelected(obstacle) ? .white : .primary)
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
                    saveObstacles()
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
                destination: SpecificDietView(),
                isActive: $navigateToNextStep
            ) {
                EmptyView()
            }
        )
        .onAppear {
            // Save current step to UserDefaults when this view appears
            UserDefaults.standard.set("ObstaclesView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(9, forKey: "onboardingFlowStep") // Raw value for this step
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            print("📱 ObstaclesView appeared - saved current step")
        }
    }
    
    // Helper function to toggle obstacle selection
    private func toggleObstacle(_ obstacle: Obstacle) {
        HapticFeedback.generate()
        if isSelected(obstacle) {
            selectedObstacles.remove(obstacle)
        } else {
            selectedObstacles.insert(obstacle)
        }
    }
    
    // Helper function to check if obstacle is selected
    private func isSelected(_ obstacle: Obstacle) -> Bool {
        return selectedObstacles.contains(obstacle)
    }
    
    // Save selected obstacles to UserDefaults
    private func saveObstacles() {
        let selectedObstacleNames = selectedObstacles.map { $0.rawValue }
        UserDefaults.standard.set(selectedObstacleNames, forKey: "selectedObstacles")
    }
}

#Preview {
    ObstaclesView()
}
