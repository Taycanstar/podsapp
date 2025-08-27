//
//  DynamicParameterService.swift
//  pods
//
//  Created by Dimi Nunez on 8/26/25.
//

//
//  DynamicParameterService.swift
//  pods
//
//  Created by Dimi Nunez on 8/26/25.
//

import Foundation
import SwiftUI

// Import core model types from proper model files
// TodayWorkout, ExerciseData, WorkoutDuration etc. are now in WorkoutModels.swift
// FitnessGoal, ExperienceLevel are in UserProfile.swift
// Equipment is in Equipment.swift

/// Service for calculating dynamic workout parameters and intelligent rep ranges
@MainActor
class DynamicParameterService: ObservableObject {
    static let shared = DynamicParameterService()
    
    private let performanceFeedbackService = PerformanceFeedbackService.shared
    private let userProfileService = UserProfileService.shared
    
    private init() {}
    
    // MARK: - Dynamic Parameter Calculation
    
    /// Calculate dynamic parameters for next workout
    func calculateDynamicParameters(
        currentPhase: SessionPhase,
        lastFeedback: WorkoutSessionFeedback?
    ) async -> DynamicWorkoutParameters {
        
        let recoveryStatus = calculateRecoveryStatus()
        let performanceMetrics = await getPerformanceMetrics()
        let autoRegulationLevel = calculateAutoRegulationLevel(from: performanceMetrics)
        
        return DynamicWorkoutParameters(
            sessionPhase: determineNextPhase(currentPhase, feedback: lastFeedback),
            recoveryStatus: recoveryStatus,
            performanceHistory: performanceMetrics,
            autoRegulationLevel: autoRegulationLevel,
            lastWorkoutFeedback: lastFeedback
        )
    }
    
    /// Generate dynamic exercise with intelligent rep ranges
    func generateDynamicExercise(
        for exercise: ExerciseData,
        parameters: DynamicWorkoutParameters,
        fitnessGoal: FitnessGoal
    ) -> DynamicWorkoutExercise {
        
        let exerciseType = MovementType.classify(exercise)
        let baseIntensityZone = determineIntensityZone(
            sessionPhase: parameters.sessionPhase,
            exerciseType: exerciseType,
            fitnessGoal: fitnessGoal
        )
        
        let repRange = calculateDynamicRepRange(
            fitnessGoal: fitnessGoal,
            sessionPhase: parameters.sessionPhase,
            exerciseType: exerciseType,
            recoveryStatus: parameters.recoveryStatus[exercise.target] ?? .moderate,
            lastFeedback: parameters.lastWorkoutFeedback
        )
        
        let setCount = calculateDynamicSetCount(
            exerciseType: exerciseType,
            sessionPhase: parameters.sessionPhase,
            fitnessGoal: fitnessGoal
        )
        
        let restTime = calculateOptimalRestTime(
            intensityZone: baseIntensityZone,
            sessionPhase: parameters.sessionPhase,
            exerciseType: exerciseType
        )
        
        return DynamicWorkoutExercise(
            exercise: exercise,
            setCount: setCount,
            repRange: repRange,
            targetIntensity: baseIntensityZone,
            suggestedWeight: nil, // Let existing weight progression handle this
            restTime: restTime,
            sessionPhase: parameters.sessionPhase,
            recoveryStatus: parameters.recoveryStatus[exercise.target] ?? .moderate
        )
    }
    
    // MARK: - Rep Range Calculation (The Core Dynamic Algorithm)
    
    /// Calculate intelligent rep ranges that replace static numbers for ALL fitness goals
    private func calculateDynamicRepRange(
        fitnessGoal: FitnessGoal,
        sessionPhase: SessionPhase,
        exerciseType: MovementType,
        recoveryStatus: RecoveryStatus,
        lastFeedback: WorkoutSessionFeedback?
    ) -> ClosedRange<Int> {
        
        print("🧮 === Dynamic Rep Range Calculation ===")
        print("🧮 Fitness Goal: \(fitnessGoal)")
        print("🧮 Session Phase: \(sessionPhase.displayName)")
        print("🧮 Exercise Type: \(exerciseType.displayName)")
        print("🧮 Recovery Status: \(recoveryStatus.displayName)")
        
        // Step 1: Get base rep range for fitness goal (replaces static numbers)
        let baseRange = getBaseRepRangeForGoal(fitnessGoal)
        print("🧮 Base range for \(fitnessGoal): \(baseRange.lowerBound)-\(baseRange.upperBound)")
        
        // Step 2: Adjust range based on session phase (Fitbod's A-B-C cycling)
        let phaseAdjustedRange = adjustRangeForSessionPhase(baseRange, sessionPhase: sessionPhase)
        print("🧮 Phase adjusted (\(sessionPhase.displayName)): \(phaseAdjustedRange.lowerBound)-\(phaseAdjustedRange.upperBound)")
        
        // Step 3: Adjust for exercise type (compound vs isolation)
        let typeAdjustedRange = adjustRangeForExerciseType(phaseAdjustedRange, exerciseType: exerciseType)
        print("🧮 Exercise type adjusted (\(exerciseType.displayName)): \(typeAdjustedRange.lowerBound)-\(typeAdjustedRange.upperBound)")
        
        // Step 4: Adjust for recovery status
        let recoveryAdjustedRange = adjustRangeForRecovery(typeAdjustedRange, recoveryStatus: recoveryStatus)
        print("🧮 Recovery adjusted (\(recoveryStatus.displayName)): \(recoveryAdjustedRange.lowerBound)-\(recoveryAdjustedRange.upperBound)")
        
        // Step 5: Auto-regulation based on last workout feedback
        let finalRange = adjustRangeForFeedback(recoveryAdjustedRange, feedback: lastFeedback)
        print("🧮 Final dynamic range: \(finalRange.lowerBound)-\(finalRange.upperBound)")
        print("🧮 === End Dynamic Calculation ===")
        
        return finalRange
    }
    
    /// Base rep ranges for each fitness goal (replaces static 3x8, 3x10, etc.)
    private func getBaseRepRangeForGoal(_ goal: FitnessGoal) -> ClosedRange<Int> {
        switch goal {
        case .strength:
            return 3...6        // Instead of static "3"
        case .powerlifting:
            return 1...5        // Instead of static "1" 
        case .hypertrophy:
            return 6...15       // Instead of static "8"
        case .endurance:
            return 15...25      // Instead of static "20"
        case .general:
            return 8...15       // Instead of static "10"
        case .tone:
            return 10...18      // Instead of static "12"
        default:
            return 8...12       // Safe default range
        }
    }
    
    /// Adjust rep range based on session phase (Fitbod's cycling approach)
    private func adjustRangeForSessionPhase(_ baseRange: ClosedRange<Int>, sessionPhase: SessionPhase) -> ClosedRange<Int> {
        switch sessionPhase {
        case .strengthFocus:
            // Lower end of range for strength focus
            let newUpper = baseRange.lowerBound + (baseRange.upperBound - baseRange.lowerBound) / 2
            return baseRange.lowerBound...max(baseRange.lowerBound + 1, newUpper)
            
        case .volumeFocus:
            // Middle to upper range for volume focus
            let rangeMid = baseRange.lowerBound + (baseRange.upperBound - baseRange.lowerBound) / 3
            return rangeMid...baseRange.upperBound
            
        case .conditioningFocus:
            // Upper range for conditioning focus
            let newLower = baseRange.lowerBound + (baseRange.upperBound - baseRange.lowerBound) * 2 / 3
            return newLower...baseRange.upperBound
        }
    }
    
    /// Adjust rep range for exercise type
    private func adjustRangeForExerciseType(_ range: ClosedRange<Int>, exerciseType: MovementType) -> ClosedRange<Int> {
        switch exerciseType {
        case .compound:
            // Compound movements: slightly lower reps for strength/complexity
            return max(1, range.lowerBound - 1)...max(range.lowerBound, range.upperBound - 2)
            
        case .isolation:
            // Isolation movements: slightly higher reps for muscle focus
            return (range.lowerBound + 1)...(range.upperBound + 2)
            
        case .core:
            // Core exercises: higher reps for endurance
            return max(10, range.lowerBound + 3)...(range.upperBound + 5)
            
        case .cardio:
            // Cardio-strength: higher reps for conditioning
            return max(12, range.lowerBound + 5)...(range.upperBound + 8)
        }
    }
    
    /// Adjust rep range for recovery status
    private func adjustRangeForRecovery(_ range: ClosedRange<Int>, recoveryStatus: RecoveryStatus) -> ClosedRange<Int> {
        switch recoveryStatus {
        case .fresh:
            // Fresh muscles: can handle lower reps/higher intensity
            return max(1, range.lowerBound - 1)...range.upperBound
            
        case .moderate:
            // Moderate recovery: use base range
            return range
            
        case .fatigued:
            // Fatigued muscles: higher reps/lower intensity
            return (range.lowerBound + 2)...(range.upperBound + 3)
        }
    }
    
    /// Auto-regulation based on workout feedback
    private func adjustRangeForFeedback(_ range: ClosedRange<Int>, feedback: WorkoutSessionFeedback?) -> ClosedRange<Int> {
        guard let feedback = feedback else { return range }
        
        switch feedback.difficultyRating {
        case .tooEasy:
            // Last workout too easy: reduce reps for higher intensity
            return max(1, range.lowerBound - 2)...max(range.lowerBound, range.upperBound - 2)
            
        case .justRight:
            // Perfect: keep current range
            return range
            
        case .challenging:
            // Good challenge: maintain or slight increase
            return range.lowerBound...(range.upperBound + 1)
            
        case .tooHard:
            // Too difficult: increase reps for lower intensity
            return (range.lowerBound + 2)...(range.upperBound + 3)
        }
    }
    
    // MARK: - Set Count Calculation
    
    /// Calculate dynamic set count (can also vary from static 3 sets)
    private func calculateDynamicSetCount(
        exerciseType: MovementType,
        sessionPhase: SessionPhase,
        fitnessGoal: FitnessGoal
    ) -> Int {
        
        // Base set count by fitness goal
        let baseSets: Int
        switch fitnessGoal {
        case .strength, .powerlifting:
            baseSets = 4  // Higher sets for strength
        case .hypertrophy:
            baseSets = 3  // Standard hypertrophy
        case .endurance, .general, .tone:
            baseSets = 3  // Moderate volume
        default:
            baseSets = 3
        }
        
        // Adjust based on session phase
        switch sessionPhase {
        case .strengthFocus:
            return min(baseSets + 1, 5)  // More sets for strength focus
        case .volumeFocus:
            return baseSets              // Standard sets for volume
        case .conditioningFocus:
            return max(baseSets - 1, 2)  // Fewer sets for conditioning
        }
    }
    
    // MARK: - Supporting Methods
    
    /// Determine intensity zone based on goal and phase
    private func determineIntensityZone(
        sessionPhase: SessionPhase,
        exerciseType: MovementType,
        fitnessGoal: FitnessGoal
    ) -> IntensityZone {
        switch (sessionPhase, exerciseType, fitnessGoal) {
        case (.strengthFocus, .compound, _):
            return .strength
        case (.volumeFocus, _, .hypertrophy):
            return .hypertrophy
        case (.conditioningFocus, _, _):
            return .endurance
        case (_, .compound, .strength):
            return .strength
        case (_, .compound, .powerlifting):
            return .strength
        case (_, _, .endurance):
            return .endurance
        default:
            return .hypertrophy  // Safe default
        }
    }
    
    /// Calculate optimal rest time based on intensity and phase
    private func calculateOptimalRestTime(
        intensityZone: IntensityZone,
        sessionPhase: SessionPhase,
        exerciseType: MovementType
    ) -> Int {
        let baseRestTime = intensityZone.restTime
        
        // Adjust for session phase
        let phaseMultiplier: Double
        switch sessionPhase {
        case .strengthFocus:
            phaseMultiplier = 1.2  // Longer rest for strength
        case .volumeFocus:
            phaseMultiplier = 1.0  // Standard rest
        case .conditioningFocus:
            phaseMultiplier = 0.7  // Shorter rest for conditioning
        }
        
        // Adjust for exercise type
        let typeMultiplier: Double
        switch exerciseType {
        case .compound:
            typeMultiplier = 1.1  // Slightly longer for compound
        case .isolation:
            typeMultiplier = 0.9  // Slightly shorter for isolation
        case .core, .cardio:
            typeMultiplier = 0.8  // Shorter for cardio/core
        }
        
        return Int(Double(baseRestTime) * phaseMultiplier * typeMultiplier)
    }
    
    /// Determine next session phase
    private func determineNextPhase(_ currentPhase: SessionPhase, feedback: WorkoutSessionFeedback?) -> SessionPhase {
        // Simple A-B-C cycling for now
        // Could be enhanced with feedback analysis later
        return currentPhase.nextPhase()
    }
    
    /// Calculate recovery status for muscle groups
    private func calculateRecoveryStatus() -> [String: RecoveryStatus] {
        // Simplified recovery calculation
        // In a real implementation, this would track last workout dates per muscle group
        return [:]  // Default to moderate recovery
    }
    
    /// Get performance metrics from feedback service
    private func getPerformanceMetrics() async -> PerformanceMetrics {
        return await performanceFeedbackService.getPerformanceTrends()
    }
    
    /// Calculate auto-regulation aggressiveness level
    private func calculateAutoRegulationLevel(from metrics: PerformanceMetrics) -> Double {
        if metrics.recentFeedbackCount < 3 {
            return 0.3  // Conservative for new users
        }
        
        switch metrics.trend {
        case .improving:
            return 0.7  // More aggressive when improving
        case .stable:
            return 0.5  // Moderate approach
        case .declining:
            return 0.3  // Conservative when struggling
        }
    }
}

// MARK: - Extension for Backward Compatibility

extension DynamicParameterService {
    
    /// Convert static workout to dynamic workout (migration helper)
    func migrateLegacyWorkout(
        _ legacyWorkout: TodayWorkout,
        sessionPhase: SessionPhase = .volumeFocus
    ) async -> DynamicTodayWorkout {
        
        let parameters = await calculateDynamicParameters(
            currentPhase: sessionPhase,
            lastFeedback: nil
        )
        
        let dynamicExercises = legacyWorkout.exercises.map { legacyExercise in
            generateDynamicExercise(
                for: legacyExercise.exercise,
                parameters: parameters,
                fitnessGoal: legacyWorkout.fitnessGoal
            )
        }
        
        return DynamicTodayWorkout(
            baseWorkout: legacyWorkout,
            dynamicExercises: dynamicExercises,
            sessionPhase: sessionPhase,
            dynamicParameters: parameters
        )
    }
    
    /// Check if user should use dynamic programming (gradual rollout)
    func shouldUseDynamicProgramming(for userEmail: String) -> Bool {
        let workoutCount = performanceFeedbackService.feedbackHistory.count
        let hasOptedIn = UserDefaults.standard.bool(forKey: "dynamicProgrammingOptIn_\(userEmail)")
        let isInTestGroup = userEmail.hashValue % 2 == 0  // 50% rollout
        
        // Enable dynamic programming after user has completed 3+ workouts
        return workoutCount >= 3 && (hasOptedIn || isInTestGroup)
    }
}