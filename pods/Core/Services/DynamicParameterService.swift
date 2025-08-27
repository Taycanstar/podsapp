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
    
    /// Generate dynamic exercise with intelligent rep ranges and daily targets
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
        
        // Determine movement priority for per-exercise variability
        let movementPriority = determineMovementPriority(exercise: exercise, exerciseType: exerciseType)
        
        // Calculate daily target and range using new method
        let (targetReps, repRange) = calculateDynamicRepTarget(
            fitnessGoal: fitnessGoal,
            sessionPhase: parameters.sessionPhase,
            exerciseType: exerciseType,
            recoveryStatus: parameters.recoveryStatus[exercise.target] ?? .moderate,
            lastFeedback: parameters.lastWorkoutFeedback,
            exercisePriority: movementPriority
        )
        
        let setCount = calculateDynamicSetCount(
            exerciseType: exerciseType,
            movementPriority: movementPriority,
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
            targetReps: targetReps,
            targetIntensity: baseIntensityZone,
            suggestedWeight: nil, // Let existing weight progression handle this
            restTime: restTime,
            sessionPhase: parameters.sessionPhase,
            recoveryStatus: parameters.recoveryStatus[exercise.target] ?? .moderate,
            movementPriority: movementPriority
        )
    }
    
    // MARK: - Rep Range Calculation (The Core Dynamic Algorithm)
    
    /// Calculate daily target rep with clean science-based lookup table
    private func calculateDynamicRepTarget(
        fitnessGoal: FitnessGoal,
        sessionPhase: SessionPhase,
        exerciseType: MovementType,
        recoveryStatus: RecoveryStatus,
        lastFeedback: WorkoutSessionFeedback?,
        exercisePriority: MovementPriority = .secondary
    ) -> (target: Int, range: ClosedRange<Int>) {
        
        print("🧮 === Clean Rep Target Calculation ===")
        print("🧮 Goal: \(fitnessGoal) | Phase: \(sessionPhase.displayName) | Type: \(exerciseType.displayName) | Priority: \(exercisePriority.displayName)")
        
        // Get optimal range from science-based lookup table (NO compounding adjustments)
        let optimalRange = getOptimalRepRange(
            goal: fitnessGoal,
            priority: exercisePriority,
            exerciseType: exerciseType
        )
        
        // Select clean daily target (no arbitrary percentiles)
        let cleanTarget = selectCleanTarget(
            from: optimalRange,
            sessionPhase: sessionPhase,
            recoveryStatus: recoveryStatus,
            feedback: lastFeedback
        )
        
        print("🧮 Optimal range: \(optimalRange.lowerBound)-\(optimalRange.upperBound) | Clean target: \(cleanTarget)")
        print("🧮 === End Clean Calculation ===")
        
        return (target: cleanTarget, range: optimalRange)
    }
    
    /// Science-based lookup table for optimal rep ranges (replaces compounding adjustments)
    private func getOptimalRepRange(
        goal: FitnessGoal,
        priority: MovementPriority,
        exerciseType: MovementType
    ) -> ClosedRange<Int> {
        
        // Clean lookup table based on exercise science principles
        switch (goal, priority, exerciseType) {
        // STRENGTH GOAL
        case (.strength, .primary, .compound):    return 3...6   // Heavy compounds
        case (.strength, .secondary, .compound):  return 4...8   // Supporting compounds  
        case (.strength, .accessory, .isolation): return 6...10  // Strength accessories
        case (.strength, _, .core):               return 8...15  // Core strength
        case (.strength, _, .cardio):             return 10...20 // Strength conditioning
        
        // POWERLIFTING GOAL (similar to strength but more specific)
        case (.powerlifting, .primary, .compound):    return 1...5   // Competition lifts
        case (.powerlifting, .secondary, .compound):  return 3...6   // Supporting lifts
        case (.powerlifting, .accessory, .isolation): return 6...10  // Powerlifting accessories
        case (.powerlifting, _, .core):               return 8...15  // Core stability
        case (.powerlifting, _, .cardio):             return 10...20 // Recovery work
        
        // HYPERTROPHY GOAL
        case (.hypertrophy, .primary, .compound):    return 6...10  // Compound muscle builders
        case (.hypertrophy, .secondary, .compound):  return 8...12  // Secondary compounds
        case (.hypertrophy, .accessory, .isolation): return 10...15 // Isolation work
        case (.hypertrophy, _, .core):               return 12...20 // Core hypertrophy
        case (.hypertrophy, _, .cardio):             return 15...25 // Hypertrophy conditioning
        
        // ENDURANCE GOAL
        case (.endurance, .primary, .compound):    return 12...20 // Endurance compounds
        case (.endurance, .secondary, .compound):  return 15...25 // Endurance supporting
        case (.endurance, .accessory, .isolation): return 15...30 // Endurance isolation
        case (.endurance, _, .core):               return 20...40 // Core endurance
        case (.endurance, _, .cardio):             return 25...50 // Cardio endurance
        
        // TONE GOAL (similar to endurance but moderate)
        case (.tone, .primary, .compound):    return 10...15 // Toning compounds
        case (.tone, .secondary, .compound):  return 12...18 // Toning supporting
        case (.tone, .accessory, .isolation): return 12...20 // Toning isolation
        case (.tone, _, .core):               return 15...25 // Core toning
        case (.tone, _, .cardio):             return 20...30 // Cardio toning
        
        // GENERAL FITNESS (balanced approach)
        case (.general, .primary, .compound):    return 8...12  // General compounds
        case (.general, .secondary, .compound):  return 10...15 // General supporting
        case (.general, .accessory, .isolation): return 10...15 // General isolation
        case (.general, _, .core):               return 12...20 // General core
        case (.general, _, .cardio):             return 15...25 // General cardio
        
        // FALLBACK for any unhandled cases
        default: return 8...12 // Safe default
        }
    }
    
    /// Select clean, user-friendly target from range (no arbitrary percentiles)
    private func selectCleanTarget(
        from range: ClosedRange<Int>,
        sessionPhase: SessionPhase,
        recoveryStatus: RecoveryStatus,
        feedback: WorkoutSessionFeedback?
    ) -> Int {
        
        // Clean target numbers that users expect (no 7, 11, 13, 17, etc.)
        let cleanNumbers = [1, 3, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50]
        let validTargets = cleanNumbers.filter { range.contains($0) }
        
        guard !validTargets.isEmpty else { 
            return range.lowerBound // Fallback
        }
        
        // Select based on session phase preference
        let baseIndex: Int
        switch sessionPhase {
        case .strengthFocus:
            baseIndex = 0 // Lower end for strength
        case .volumeFocus:
            baseIndex = validTargets.count / 2 // Middle for volume
        case .conditioningFocus:
            baseIndex = validTargets.count - 1 // Upper end for conditioning
        }
        
        var targetIndex = baseIndex
        
        // Adjust for recovery status
        switch recoveryStatus {
        case .fresh:
            targetIndex = max(0, targetIndex - 1) // Can handle slightly lower reps (higher intensity)
        case .moderate:
            break // Use base selection
        case .fatigued:
            targetIndex = min(validTargets.count - 1, targetIndex + 1) // Higher reps for recovery
        }
        
        // Adjust for feedback
        if let feedback = feedback {
            switch feedback.difficultyRating {
            case .tooEasy:
                targetIndex = max(0, targetIndex - 1) // Lower reps = higher intensity
            case .tooHard:
                targetIndex = min(validTargets.count - 1, targetIndex + 1) // Higher reps = lower intensity  
            case .justRight, .challenging:
                break // Keep current selection
            }
        }
        
        return validTargets[targetIndex]
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
    
    /// Adjust rep range based on movement priority (primary vs accessory)
    private func adjustRangeForMovementPriority(_ range: ClosedRange<Int>, priority: MovementPriority, goal: FitnessGoal) -> ClosedRange<Int> {
        switch priority {
        case .primary:
            // Primary movements: Lower reps for strength/power focus
            let reduction = goal == .strength || goal == .powerlifting ? 2 : 1
            return max(1, range.lowerBound - reduction)...max(range.lowerBound, range.upperBound - reduction)
            
        case .secondary:
            // Secondary movements: Use base range
            return range
            
        case .accessory:
            // Accessory movements: Higher reps for volume
            return (range.lowerBound + 2)...(range.upperBound + 4)
            
        case .core:
            // Core exercises: Higher reps for endurance
            return max(10, range.lowerBound + 5)...(range.upperBound + 10)
            
        case .cardio:
            // Cardio-strength: Even higher reps
            return max(12, range.lowerBound + 8)...(range.upperBound + 15)
        }
    }
    
    /// Calculate specific daily target from range using percentile-based selection
    private func calculateDailyTargetFromRange(_ range: ClosedRange<Int>, sessionPhase: SessionPhase, feedback: WorkoutSessionFeedback?) -> Int {
        let rangeSize = range.upperBound - range.lowerBound
        
        // If range is single value, return that value
        if rangeSize == 0 {
            return range.lowerBound
        }
        
        // Percentile selection based on session phase (Fitbod approach)
        let percentile: Double
        switch sessionPhase {
        case .strengthFocus:
            percentile = 0.25  // Lower end for strength (higher intensity)
        case .volumeFocus:
            percentile = 0.70  // Higher end for volume
        case .conditioningFocus:
            percentile = 0.85  // Upper end for conditioning
        }
        
        // Auto-regulation based on feedback
        let adjustedPercentile: Double
        if let feedback = feedback {
            switch feedback.difficultyRating {
            case .tooEasy:
                adjustedPercentile = max(0.0, percentile - 0.2)  // Lower reps = higher intensity
            case .justRight:
                adjustedPercentile = percentile
            case .challenging:
                adjustedPercentile = min(1.0, percentile + 0.1)  // Slight increase
            case .tooHard:
                adjustedPercentile = min(1.0, percentile + 0.3)  // More reps = lower intensity
            }
        } else {
            adjustedPercentile = percentile
        }
        
        // Calculate target rep within range
        let targetOffset = Int(Double(rangeSize) * adjustedPercentile)
        return range.lowerBound + targetOffset
    }
    
    // MARK: - Set Count Calculation
    
    /// Calculate dynamic set count with per-exercise variability
    private func calculateDynamicSetCount(
        exerciseType: MovementType,
        movementPriority: MovementPriority,
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
        var adjustedSets: Int
        switch sessionPhase {
        case .strengthFocus:
            adjustedSets = min(baseSets + 1, 5)  // More sets for strength focus
        case .volumeFocus:
            adjustedSets = baseSets               // Standard sets for volume
        case .conditioningFocus:
            adjustedSets = max(baseSets - 1, 2)   // Fewer sets for conditioning
        }
        
        // Apply movement priority adjustments for per-exercise variability
        switch movementPriority {
        case .primary:
            // Primary movements get more sets (they're the focus)
            adjustedSets = min(adjustedSets + 1, 5)
            
        case .secondary:
            // Secondary movements get standard sets
            break  // No adjustment
            
        case .accessory:
            // Accessory movements may get fewer sets
            adjustedSets = max(adjustedSets - 1, 2)
            
        case .core:
            // Core exercises often use higher sets with bodyweight
            adjustedSets = min(adjustedSets + 1, 4)
            
        case .cardio:
            // Cardio exercises typically use fewer "sets" (more like intervals)
            adjustedSets = max(adjustedSets - 1, 2)
        }
        
        return max(adjustedSets, 2)  // Ensure minimum of 2 sets
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
    
    /// Determine movement priority for per-exercise variability
    private func determineMovementPriority(exercise: ExerciseData, exerciseType: MovementType) -> MovementPriority {
        // Primary movements (major compound exercises that should be prioritized)
        let primaryMovementNames = [
            "squat", "deadlift", "bench press", "overhead press", "barbell row", 
            "pull-up", "chin-up", "dip", "clean", "snatch", "front squat"
        ]
        
        // Core/accessory patterns
        let corePatterns = ["plank", "crunch", "sit-up", "russian twist", "mountain climber", "leg raise"]
        let cardioPatterns = ["burpee", "jumping jack", "high knees", "butt kicks", "jump rope"]
        
        let exerciseName = exercise.name.lowercased()
        
        // Check for primary movements first
        if primaryMovementNames.contains(where: { exerciseName.contains($0) }) {
            return .primary
        }
        
        // Check for core exercises
        if corePatterns.contains(where: { exerciseName.contains($0) }) {
            return .core
        }
        
        // Check for cardio exercises
        if cardioPatterns.contains(where: { exerciseName.contains($0) }) {
            return .cardio
        }
        
        // Use exercise type to determine priority
        switch exerciseType {
        case .compound:
            // Compound movements not in primary list are secondary
            return .secondary
        case .isolation:
            // Isolation movements are typically accessory
            return .accessory  
        case .core:
            return .core
        case .cardio:
            return .cardio
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