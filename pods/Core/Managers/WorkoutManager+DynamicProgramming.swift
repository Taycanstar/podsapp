//
//  WorkoutManager+DynamicProgramming.swift
//  pods
//
//  Created by Dimi Nunez on 8/26/25.
//

import Foundation
import SwiftUI

// Import core model types from proper model files
// TodayWorkout and related types are now in WorkoutModels.swift
// Dynamic types are in DynamicWorkoutModels.swift
// WorkoutManager is defined in WorkoutManager.swift

// MARK: - WorkoutManager Dynamic Programming Extension

extension WorkoutManager {
    
    // MARK: - Dynamic Programming State
    // Properties moved to base WorkoutManager class
    
    // MARK: - Dynamic Workout Generation
    
    // generateDynamicWorkout() moved to base WorkoutManager class (as generateTodayWorkout)
    
    // adaptNextWorkout() moved to base WorkoutManager class
    
    // MARK: - Migration & Compatibility
    // Note: generateSmartWorkout() logic moved to base WorkoutManager class
    
    // No longer needed - errors handled directly in generateTodayWorkout()
    
    /// Opt user into dynamic programming
    func enableDynamicProgramming() {
        let userEmail = userProfileService.userEmail
        UserDefaults.standard.set(true, forKey: "dynamicProgrammingOptIn_\(userEmail)")
        print("✅ Dynamic programming enabled for user")
    }
    
    /// Opt user out of dynamic programming
    func disableDynamicProgramming() {
        let userEmail = userProfileService.userEmail
        UserDefaults.standard.set(false, forKey: "dynamicProgrammingOptIn_\(userEmail)")
        
        // Clear dynamic state
        dynamicParameters = nil
        sessionPhase = .volumeFocus
        
        print("❌ Dynamic programming disabled for user")
    }
    
    // MARK: - Private Dynamic Methods
    
    // Helper methods moved to base WorkoutManager class
    
    // MARK: - Dynamic State Management
    
    /// Get current dynamic workout if available
    var dynamicTodayWorkout: DynamicTodayWorkout? {
        guard let params = dynamicParameters,
              let baseWorkout = todayWorkout else {
            return nil
        }
        
        // Recreate dynamic workout from current state
        let dynamicExercises = baseWorkout.exercises.map { staticExercise in
            DynamicParameterService.shared.generateDynamicExercise(
                for: staticExercise.exercise,
                parameters: params,
                fitnessGoal: effectiveFitnessGoal,
                baseExercise: staticExercise
            )
        }
        
        return DynamicTodayWorkout(
            baseWorkout: baseWorkout,
            dynamicExercises: dynamicExercises,
            sessionPhase: sessionPhase,
            dynamicParameters: params
        )
    }
    
    /// Reset dynamic programming state
    func resetDynamicState() {
        dynamicParameters = nil
        sessionPhase = .volumeFocus
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "dynamicWorkoutParameters")
        UserDefaults.standard.removeObject(forKey: "currentSessionPhase")
        
        print("🔄 Reset dynamic programming state")
    }
}

// MARK: - Dynamic Programming Analytics

extension WorkoutManager {
    
    /// Get dynamic programming status for analytics
    var dynamicProgrammingStatus: String {
        if !shouldUseDynamicProgramming {
            let feedbackCount = PerformanceFeedbackService.shared.feedbackHistory.count
            return "Static (need \(3 - feedbackCount) more workouts)"
        }
        
        return "Dynamic (\(sessionPhase.displayName))"
    }
    
    /// Get performance summary for analytics
    var performanceSummary: String {
        let feedbackService = PerformanceFeedbackService.shared
        
        if feedbackService.feedbackHistory.isEmpty {
            return "No performance history"
        }
        
        return feedbackService.getFeedbackSummary()
    }
}

// MARK: - Setup Dynamic Programming Integration

extension WorkoutManager {
    
    /// Setup dynamic programming integration (called during init)
    func setupDynamicProgramming() {
        // Set up WorkoutManager reference for feedback service
        WorkoutManagerHolder.shared.workoutManager = self
        
        // Load existing dynamic state if available
        if let params = dynamicParameters {
            print("🧠 Loaded existing dynamic parameters: \(params.sessionPhase.displayName)")
        }
        
        print("🧠 Dynamic programming setup complete")
    }
}
