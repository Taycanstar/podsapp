//
//  ExerciseComplexityService.swift
//  pods
//
//  Created by Dimi Nunez on 8/27/25.
//

import Foundation

/// Service for managing exercise complexity ratings and filtering based on user experience level
class ExerciseComplexityService {
    static let shared = ExerciseComplexityService()
    
    private init() {}
    
    // MARK: - Complexity Levels
    enum ComplexityLevel: Int {
        case foundation = 1     // Wall push-ups, assisted movements
        case basic = 2         // Regular push-ups, bodyweight squats
        case intermediate = 3  // Pull-ups, barbell exercises
        case advanced = 4      // Handstands, single-arm work
        case expert = 5        // Olympic lifts, one-arm pull-ups
        
        var description: String {
            switch self {
            case .foundation: return "Foundation"
            case .basic: return "Basic"
            case .intermediate: return "Intermediate"
            case .advanced: return "Advanced"
            case .expert: return "Expert"
            }
        }
    }
    
    // MARK: - Experience Level Filtering
    
    /// Get maximum allowed complexity for a given experience level
    func getMaxComplexityForExperience(_ experience: ExperienceLevel) -> Int {
        switch experience {
        case .beginner:
            return ComplexityLevel.basic.rawValue // Level 1-2 exercises only
        case .intermediate:
            return ComplexityLevel.intermediate.rawValue // Level 1-3 exercises
        case .advanced:
            return ComplexityLevel.expert.rawValue // All levels (1-5)
        }
    }
    
    /// Check if an exercise is appropriate for the user's experience level
    func isExerciseAppropriateForUser(_ exercise: ExerciseData, userProfile: UserProfileService? = nil) -> Bool {
        let profile = userProfile ?? UserProfileService.shared
        let userExperience = profile.experienceLevel
        let maxComplexity = getMaxComplexityForExperience(userExperience)
        
        // Get exercise complexity (use rating or estimate)
        let exerciseComplexity = getExerciseComplexity(exercise)
        
        return exerciseComplexity <= maxComplexity
    }
    
    /// Get complexity rating for an exercise
    func getExerciseComplexity(_ exercise: ExerciseData) -> Int {
        // For now, always use estimation since complexityRating field isn't available
        // TODO: Uncomment when ExerciseData struct is updated with complexityRating field
        // if let rating = exercise.complexityRating {
        //     return rating
        // }
        
        // Estimate based on exercise name and characteristics
        return estimateComplexity(for: exercise)
    }
    
    // MARK: - Complexity Estimation
    
    /// Estimate complexity based on exercise name and characteristics
    private func estimateComplexity(for exercise: ExerciseData) -> Int {
        let name = exercise.name.lowercased()
        
        // Level 5 - Expert exercises
        if containsAny(name, ["olympic", "snatch", "clean and jerk", "muscle-up", "one-arm", "one arm", "planche"]) {
            return 5
        }
        
        // Level 4 - Advanced exercises (including handstands!)
        if containsAny(name, ["handstand", "hand stand", "human flag", "front lever", "back lever", "pistol squat", 
                              "single-arm", "single arm", "deficit", "dragon flag", "kipping"]) {
            return 4
        }
        
        // Level 4 - Complex unilateral work
        if containsAny(name, ["bulgarian split", "single-leg", "single leg", "unilateral"]) &&
           !containsAny(name, ["assisted", "machine", "smith"]) {
            return 4
        }
        
        // Level 3 - Intermediate exercises
        if containsAny(name, ["pull-up", "chin-up", "dip", "barbell", "deadlift", "squat", "bench press", 
                              "overhead press", "row", "shrug"]) &&
           !containsAny(name, ["assisted", "machine", "smith", "wall", "knee"]) {
            return 3
        }
        
        // Level 3 - Weighted compound movements
        if exercise.equipment.lowercased().contains("barbell") ||
           exercise.equipment.lowercased().contains("dumbbell") &&
           containsAny(name, ["press", "squat", "deadlift", "row", "curl", "extension"]) {
            return 3
        }
        
        // Level 1 - Foundation/Assisted exercises
        if containsAny(name, ["wall", "assisted", "machine", "smith", "knee push-up", "incline push-up"]) {
            return 1
        }
        
        // Level 1 - Stretching and mobility
        if exercise.exerciseType.lowercased() == "stretching" ||
           containsAny(name, ["stretch", "mobility", "foam roll"]) {
            return 1
        }
        
        // Level 2 - Basic bodyweight and simple movements (default)
        if exercise.equipment.lowercased() == "body weight" ||
           exercise.equipment.lowercased() == "bodyweight" {
            return 2
        }
        
        // Default to level 2 for unclassified exercises
        return 2
    }
    
    /// Helper function to check if string contains any of the keywords
    private func containsAny(_ string: String, _ keywords: [String]) -> Bool {
        for keyword in keywords {
            if string.contains(keyword) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Recovery Rate Modifiers
    
    /// Get recovery time modifier based on experience level
    func getRecoveryModifier(for experience: ExperienceLevel) -> Double {
        switch experience {
        case .beginner:
            return 1.5  // 50% longer recovery (e.g., 48hrs → 72hrs)
        case .intermediate:
            return 1.0  // Standard recovery time
        case .advanced:
            return 0.75 // 25% faster recovery (e.g., 48hrs → 36hrs)
        }
    }
    
    // MARK: - Exercise Filtering
    
    /// Filter exercises by user's experience level
    func filterExercisesByExperience(_ exercises: [ExerciseData], userProfile: UserProfileService? = nil) -> [ExerciseData] {
        return exercises.filter { exercise in
            isExerciseAppropriateForUser(exercise, userProfile: userProfile)
        }
    }
    
    // MARK: - Debug Helpers
    
    /// Get complexity info for debugging
    func getComplexityInfo(for exercise: ExerciseData) -> String {
        let complexity = getExerciseComplexity(exercise)
        // For now, all ratings are estimated since complexityRating field isn't available
        let isEstimated = true // exercise.complexityRating == nil
        let complexityLevel = ComplexityLevel(rawValue: complexity) ?? .basic
        
        return "\(exercise.name): Level \(complexity) (\(complexityLevel.description))\(isEstimated ? " [Estimated]" : "")"
    }
    
    /// Check which experience levels can access an exercise
    func getAllowedExperienceLevels(for exercise: ExerciseData) -> [ExperienceLevel] {
        let complexity = getExerciseComplexity(exercise)
        var allowedLevels: [ExperienceLevel] = []
        
        if complexity <= getMaxComplexityForExperience(.beginner) {
            allowedLevels.append(.beginner)
        }
        if complexity <= getMaxComplexityForExperience(.intermediate) {
            allowedLevels.append(.intermediate)
        }
        if complexity <= getMaxComplexityForExperience(.advanced) {
            allowedLevels.append(.advanced)
        }
        
        return allowedLevels
    }
}