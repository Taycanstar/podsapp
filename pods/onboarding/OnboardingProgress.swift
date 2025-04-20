//
//  OnboardingProgress.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI


// Simple struct for calculating onboarding progress
struct OnboardingProgress {
    // Static method to get the progress percentage for a specific screen
    static func progressFor(screen: Screen) -> CGFloat {
        switch screen {
        case .gender:        return 0.07
        case .workoutDays:   return 0.14
        case .heightWeight:  return 0.21
        case .dob:           return 0.28
        case .onboardingGoal: return 0.35
        case .desiredWeight: return 0.42
        case .goalInfo:      return 0.49
        case .goalTime:      return 0.50
        case .twoX:          return 0.53
        case .obstacles:     return 0.55
        case .specificDiet:  return 0.60
        case .accomplish:    return 0.65
        case .connectHealth: return 0.70
        case .caloriesBurned: return 0.75
        case .rollover:      return 0.80
        }
    }

    // Enum for screen identification
    enum Screen {
        case gender
        case workoutDays
        case heightWeight
        case dob
        case onboardingGoal
        case desiredWeight
        case goalInfo
        case goalTime
        case twoX
        case obstacles
        case specificDiet
        case accomplish
        case connectHealth
        case caloriesBurned
        case rollover
    }
}

/// Helper for calculating accurate onboarding progress based on the actual navigation flow
enum OnboardingProgressEnum: Int, CaseIterable {
    // The correct onboarding flow in EXACT order from navigation links
    case welcome = 0
    case gender = 1
    case workoutDays = 2
    case heightWeight = 3
    case dob = 4
    case fitnessGoal = 5
    case desiredWeight = 6
    case goalInfo = 7
    case goalTime = 8
    case twoX = 9
    case obstacles = 10
    case specificDiet = 11
    case accomplish = 12
    case connectHealth = 13
    case caloriesBurned = 14
    case rollover = 15
    
    /// Total screens in the onboarding flow
    static var totalScreens: Int {
        return OnboardingProgressEnum.allCases.count - 1 // Subtract 1 so we reach 100% on the last screen
    }
    
    /// Convert this enum to the corresponding Screen type
    var asScreen: OnboardingProgress.Screen {
        switch self {
        case .welcome:       return .gender // Default to first real screen
        case .gender:        return .gender
        case .workoutDays:   return .workoutDays
        case .heightWeight:  return .heightWeight
        case .dob:           return .dob
        case .fitnessGoal:   return .onboardingGoal
        case .desiredWeight: return .desiredWeight
        case .goalInfo:      return .goalInfo
        case .goalTime:      return .goalTime
        case .twoX:          return .twoX
        case .obstacles:     return .obstacles
        case .specificDiet:  return .specificDiet
        case .accomplish:    return .accomplish
        case .connectHealth: return .connectHealth
        case .caloriesBurned: return .caloriesBurned
        case .rollover:      return .rollover
        }
    }
    
    /// Calculate progress percentage (0.0 to 1.0) for a screen
    var progressPercentage: CGFloat {
        // Use the new progressFor function to get the right percentage
        return OnboardingProgress.progressFor(screen: self.asScreen)
    }
    
    /// Get width for progress bar for a specific screen
    func progressBarWidth(totalWidth: CGFloat) -> CGFloat {
        return totalWidth * progressPercentage
    }
}

/// Extension to provide a more convenient way to get progress for a view
extension View {
    /// Apply the correct progress bar for an onboarding screen
    func withOnboardingProgress(_ screen: OnboardingProgressEnum) -> some View {
        self.overlay(
            GeometryReader { geometry in
                VStack {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: screen.progressBarWidth(totalWidth: geometry.size.width), height: 4)
                            .cornerRadius(2)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    Spacer()
                }
            }
        )
    }
} 