//
//  OnboardingProgress.swift
//  Pods
//
//  Created by Dimi Nunez on 6/8/25.
//

import SwiftUI


// Simple struct for calculating onboarding progress
struct OnboardingProgress {
    // Which screen we're on
    enum Screen {
        case gender
        case workoutDays
        case heightWeight
        case dob
        case desiredWeight
        case goalInfo
        case goalTime
        case twoX
        case obstacles
        case specificDiet
        case accomplish
        case connectHealth
        case creatingPlan
    }
    
    // Get progress ratio (0.0 to 1.0) for the given screen
    static func progressFor(screen: Screen) -> Double {
        switch screen {
        case .gender:
            return 0.0833 // 1/12
        case .workoutDays:
            return 0.1667 // 2/12
        case .heightWeight:
            return 0.2500 // 3/12
        case .dob:
            return 0.3333 // 4/12
        case .desiredWeight:
            return 0.4167 // 5/12
        case .goalInfo:
            return 0.5000 // 6/12
        case .goalTime:
            return 0.5833 // 7/12
        case .twoX:
            return 0.6667 // 8/12
        case .obstacles:
            return 0.7500 // 9/12
        case .specificDiet:
            return 0.8333 // 10/12
        case .accomplish:
            return 0.9167 // 11/12
        case .connectHealth:
            return 0.9583 // 11.5/12
        case .creatingPlan:
            return 1.0
        }
    }
}

/// Helper for calculating accurate onboarding progress based on the actual navigation flow
enum OnboardingProgressEnum: Int, CaseIterable {
    // The correct onboarding flow in EXACT order from navigation links
    case gender = 0
    case workoutDays = 1
    case heightWeight = 2
    case dob = 3
    case desiredWeight = 4
    case goalInfo = 5
    case goalTime = 6
    case twoX = 7
    case obstacles = 8
    case specificDiet = 9
    case accomplish = 10
    case connectHealth = 11
    case creatingPlan = 12
    
    /// Total screens in the onboarding flow
    static var totalScreens: Int {
        return OnboardingProgressEnum.allCases.count - 1 // Subtract 1 so we reach 100% on the last screen
    }
    
    /// Convert this enum to the corresponding Screen type
    var asScreen: OnboardingProgress.Screen {
        switch self {
        case .gender:       return .gender
        case .workoutDays:  return .workoutDays
        case .heightWeight: return .heightWeight
        case .dob:          return .dob
        case .desiredWeight: return .desiredWeight
        case .goalInfo:     return .goalInfo
        case .goalTime:     return .goalTime
        case .twoX:         return .twoX
        case .obstacles:    return .obstacles
        case .specificDiet: return .specificDiet
        case .accomplish:   return .accomplish
        case .connectHealth: return .connectHealth
        case .creatingPlan: return .creatingPlan
        }
    }
    
    /// Calculate progress percentage (0.0 to 1.0) for a screen
    var progressPercentage: CGFloat {
        // Use the new progressFor function to get the right percentage
        return CGFloat(OnboardingProgress.progressFor(screen: self.asScreen))
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