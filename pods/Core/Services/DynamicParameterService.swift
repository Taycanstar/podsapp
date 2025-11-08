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
            sessionPhase: currentPhase,
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
        fitnessGoal: FitnessGoal,
        baseExercise: TodayWorkoutExercise? = nil
    ) -> DynamicWorkoutExercise {
        
        let exerciseType = MovementType.classify(exercise)
        let baseIntensityZone = determineIntensityZone(
            sessionPhase: parameters.sessionPhase,
            exerciseType: exerciseType,
            fitnessGoal: fitnessGoal
        )
        
        let movementPriority = determineMovementPriority(exercise: exercise, exerciseType: exerciseType)
        let scheme = SetSchemePlanner.shared.scheme(
            for: exercise,
            goal: fitnessGoal,
            experienceLevel: userProfileService.experienceLevel,
            sessionPhase: parameters.sessionPhase,
            isCompound: SetSchemePlanner.isCompoundExercise(exercise)
        )
        let baseSets = baseExercise?.sets ?? scheme.sets
        let setCount = regulateSetCount(
            baseSets: baseSets,
            recoveryStatus: parameters.recoveryStatus[exercise.target],
            performanceMetrics: parameters.performanceHistory,
            lastFeedback: parameters.lastWorkoutFeedback
        )
        
        let (targetReps, repRange) = calculateDynamicRepTarget(
            scheme: scheme,
            movementPriority: movementPriority,
            recoveryStatus: parameters.recoveryStatus[exercise.target] ?? .moderate,
            lastFeedback: parameters.lastWorkoutFeedback,
            intensityZone: baseIntensityZone
        )
        
        let restTime = baseExercise?.restTime ?? scheme.restSeconds
        
        let warmupPreferenceEnabled = UserProfileService.shared.warmupSetsEnabled
        let carriedWarmups = warmupPreferenceEnabled ? baseExercise?.warmupSets : nil
        let carriedNotes = baseExercise?.notes

        return DynamicWorkoutExercise(
            exercise: exercise,
            setCount: setCount,
            repRange: repRange,
            targetReps: targetReps,
            targetIntensity: baseIntensityZone,
            suggestedWeight: baseExercise?.weight,
            restTime: restTime,
            sessionPhase: parameters.sessionPhase,
            recoveryStatus: parameters.recoveryStatus[exercise.target] ?? .moderate,
            movementPriority: movementPriority,
            notes: carriedNotes,
            warmupSets: carriedWarmups
        )
    }
    
    // MARK: - Rep Range & Set Regulation (Planner-Aligned)
    
    private func calculateDynamicRepTarget(
        scheme: SetScheme,
        movementPriority: MovementPriority,
        recoveryStatus: RecoveryStatus,
        lastFeedback: WorkoutSessionFeedback?,
        intensityZone: IntensityZone
    ) -> (target: Int, range: ClosedRange<Int>) {
        var target = scheme.targetReps
        let range = scheme.repRange
        
        switch movementPriority {
        case .primary:
            target = max(range.lowerBound, target - 1)
        case .accessory, .cardio:
            target = min(range.upperBound, target + 1)
        case .secondary, .core:
            break
        }
        
        switch recoveryStatus {
        case .fresh:
            target = max(range.lowerBound, target - 1)
        case .fatigued:
            target = min(range.upperBound, target + 1)
        case .moderate:
            break
        }
        
        if let feedback = lastFeedback {
            if feedback.overallRPE > 8.5 {
                target = max(range.lowerBound, target - 1)
            } else if feedback.overallRPE < 6.0 {
                target = min(range.upperBound, target + 1)
            }
        }
        
        let clamped = clamp(target, within: range)
        let snapped = snapTargetReps(clamped, within: range, intensityZone: intensityZone)
        return (target: snapped, range: range)
    }
    
    private func regulateSetCount(
        baseSets: Int,
        recoveryStatus: RecoveryStatus?,
        performanceMetrics: PerformanceMetrics,
        lastFeedback: WorkoutSessionFeedback?
    ) -> Int {
        guard baseSets > 0 else { return 0 }
        var adjusted = Double(baseSets)
        
        if let recoveryStatus, recoveryStatus == .fatigued {
            adjusted *= 0.8
        }
        
        if performanceMetrics.averageRPE > 8.5 || performanceMetrics.trend == .declining {
            adjusted *= 0.85
        }
        
        if let feedback = lastFeedback, feedback.overallRPE > 8.5 || feedback.completionRate < 0.7 {
            adjusted *= 0.85
        }
        
        let clamped = min(Double(baseSets), adjusted)
        return max(1, Int(round(clamped)))
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
        case (_, .compound, .strength):
            return .strength
        case (_, .compound, .powerlifting):
            return .strength
        case (.volumeFocus, _, .endurance), (_, _, .endurance):
            return .endurance
        default:
            return .hypertrophy  // Safe default
        }
    }
    
    private func clamp(_ value: Int, within range: ClosedRange<Int>) -> Int {
        return min(range.upperBound, max(range.lowerBound, value))
    }
    
    private func snapTargetReps(_ target: Int, within range: ClosedRange<Int>, intensityZone: IntensityZone) -> Int {
        let cleanTargets: [Int]
        switch intensityZone {
        case .strength:
            cleanTargets = [3, 4, 5, 6]
        case .hypertrophy:
            cleanTargets = [6, 8, 10, 12, 15]
        case .endurance:
            cleanTargets = [12, 15, 20, 25, 30]
        }
        
        let candidates = cleanTargets.filter { range.contains($0) }
        guard !candidates.isEmpty else { return target }
        
        return candidates.min {
            let lhs = abs($0 - target)
            let rhs = abs($1 - target)
            return lhs == rhs ? $0 < $1 : lhs < rhs
        } ?? target
    }
    
    /// Determine next session phase
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
