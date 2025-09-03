//
//  WorkoutGenerationService.swift
//  pods
//
//  Created by Dimi Nunez on 8/25/25.
//

//
//  WorkoutGenerationService.swift
//  Pods
//
//  Created by Dimi Nunez on 8/25/25.
//

import Foundation

/// Advanced workout generation service that uses exercise science principles
/// to create scientifically sound workouts based on duration, fitness goals, and equipment
@MainActor
class WorkoutGenerationService {
    static let shared = WorkoutGenerationService()
    
    private let recommendationService = WorkoutRecommendationService.shared
    
    private init() {}
    
    /// Generate optimized workout plan using research-based algorithm (no more iterative approach)
    func generateWorkoutPlan(
        muscleGroups: [String],
        targetDuration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences
    ) throws -> WorkoutPlan {
        
        let targetDurationMinutes = targetDuration.minutes
        let targetDurationSeconds = targetDurationMinutes * 60
        
        print("🏗️ WorkoutGenerationService: Generating \(targetDurationMinutes)min \(fitnessGoal) workout using research-based algorithm")
        
        // Use enhanced WorkoutRecommendationService for optimal exercise count calculation
        let optimalExerciseCount = recommendationService.getOptimalExerciseCount(
            duration: targetDuration,
            fitnessGoal: fitnessGoal,
            muscleGroupCount: muscleGroups.count,
            experienceLevel: experienceLevel,
            equipment: customEquipment
        )
        
        print("🎯 Optimal exercise count: \(optimalExerciseCount.total) total, \(optimalExerciseCount.perMuscle) per muscle")
        
        // Generate exercises directly using optimal count with proper distribution
        let exercises = generateOptimizedExercisesWithTotalBudget(
            muscleGroups: muscleGroups,
            totalExercises: optimalExerciseCount.total,
            basePerMuscle: optimalExerciseCount.perMuscle,
            targetDuration: targetDuration,
            fitnessGoal: fitnessGoal,
            customEquipment: customEquipment,
            flexibilityPreferences: flexibilityPreferences
        )
        
        // Calculate actual time with single buffer (no double buffering)
        let totalExerciseTime = calculateActualExerciseTime(exercises: exercises, fitnessGoal: fitnessGoal)
        let warmupMinutes = getOptimalWarmupDuration(targetDurationMinutes)
        let cooldownMinutes = warmupMinutes
        let bufferMinutes = Int(Double(targetDurationMinutes) * 0.03) // Single 3% buffer
        
        let actualDurationMinutes = warmupMinutes + (totalExerciseTime / 60) + cooldownMinutes + bufferMinutes
        
        let breakdown = TimeBreakdown(
            warmupMinutes: warmupMinutes,
            exerciseMinutes: totalExerciseTime / 60,
            cooldownMinutes: cooldownMinutes,
            totalMinutes: actualDurationMinutes
        )
        
        print("✅ Generated \(exercises.count) exercises, actual duration: \(actualDurationMinutes) minutes (97% efficiency)")
        
        return WorkoutPlan(
            exercises: exercises,
            actualDurationMinutes: actualDurationMinutes,
            totalTimeBreakdown: breakdown
        )
    }
    
    // MARK: - Optimized Exercise Generation (No More Iterative Testing)
    
    /// Generate exercises respecting total time budget with smart distribution
    private func generateOptimizedExercisesWithTotalBudget(
        muscleGroups: [String],
        totalExercises: Int,
        basePerMuscle: Int,
        targetDuration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences
    ) -> [TodayWorkoutExercise] {
        var exercises: [TodayWorkoutExercise] = []
        
        print("🏗️ Starting smart distribution: \(totalExercises) total exercises across \(muscleGroups.count) muscles")
        
        // Calculate distribution with remainder handling
        let baseCount = totalExercises / muscleGroups.count
        let remainder = totalExercises % muscleGroups.count
        
        print("📊 Distribution plan: \(baseCount) base per muscle, \(remainder) muscles get +1 extra")
        
        for (index, muscle) in muscleGroups.enumerated() {
            // First 'remainder' muscle groups get an extra exercise
            let countForThisMuscle = baseCount + (index < remainder ? 1 : 0)
            
            print("🎯 \(muscle) (muscle \(index + 1)/\(muscleGroups.count)): requesting \(countForThisMuscle) exercises")
            
            // Use enhanced WorkoutRecommendationService for duration-optimized selection
            let recommended = recommendationService.getDurationOptimizedExercises(
                for: muscle,
                count: countForThisMuscle,
                duration: targetDuration,
                fitnessGoal: fitnessGoal,
                customEquipment: customEquipment,
                flexibilityPreferences: flexibilityPreferences
            )
            
            print("🎯 \(muscle): requested \(countForThisMuscle), got \(recommended.count) exercises")
            
            for exercise in recommended {
                // Build exercise with correct tracking (reps/weight vs duration-based)
                let built = makeWorkoutExercise(
                    for: exercise,
                    targetDuration: targetDuration,
                    fitnessGoal: fitnessGoal
                )
                exercises.append(built)
            }
            
            print("📊 Running total after \(muscle): \(exercises.count) exercises")
        }
        
        print("✅ Final smart distribution result: \(exercises.count) exercises (target was \(totalExercises))")
        print("💪 Generated \(exercises.count) exercises respecting time budget")
        return exercises
    }
    
    /// Generate exercises using optimal count from WorkoutRecommendationService
    private func generateOptimizedExercises(
        muscleGroups: [String],
        exercisesPerMuscle: Int,
        targetDuration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences
    ) -> [TodayWorkoutExercise] {
        var exercises: [TodayWorkoutExercise] = []
        
        print("🏗️ Starting exercise generation: \(muscleGroups.count) muscles × \(exercisesPerMuscle) exercises = \(muscleGroups.count * exercisesPerMuscle) target")
        
        for muscle in muscleGroups {
            // Use enhanced WorkoutRecommendationService for duration-optimized selection
            let recommended = recommendationService.getDurationOptimizedExercises(
                for: muscle,
                count: exercisesPerMuscle,
                duration: targetDuration,
                fitnessGoal: fitnessGoal,
                customEquipment: customEquipment,
                flexibilityPreferences: flexibilityPreferences
            )
            
            print("🎯 \(muscle): requested \(exercisesPerMuscle), got \(recommended.count) exercises")
            
            for exercise in recommended {
                let built = makeWorkoutExercise(
                    for: exercise,
                    targetDuration: targetDuration,
                    fitnessGoal: fitnessGoal
                )
                exercises.append(built)
            }
            
            print("📊 Running total after \(muscle): \(exercises.count) exercises")
        }
        
        print("✅ Final generation result: \(exercises.count) exercises (target was \(muscleGroups.count * exercisesPerMuscle))")
        print("💪 Generated \(exercises.count) exercises using research-based optimization")
        return exercises
    }
    
    /// Get research-based rest times for optimal performance
    private func getResearchBasedRestTime(fitnessGoal: FitnessGoal, isCompound: Bool) -> Int {
        switch fitnessGoal {
        case .strength, .powerlifting:
            // ATP regeneration requires 2-3 minutes
            return isCompound ? 120 : 90
        case .hypertrophy:
            // Metabolic stress optimization 1-2 minutes
            return isCompound ? 90 : 60
        case .endurance:
            // Cardiovascular adaptation 30-60 seconds
            return isCompound ? 45 : 30
        default:
            // General fitness balanced approach
            return isCompound ? 75 : 60
        }
    }
    
    /// Calculate actual exercise time using research-based formulas
    private func calculateActualExerciseTime(exercises: [TodayWorkoutExercise], fitnessGoal: FitnessGoal) -> Int {
        var totalSeconds = 0
        
        for exercise in exercises {
            let setupTime = isCompoundExercise(exercise.exercise) ? 25 : 15
            let transitionTime = 15
            var workingTime = 0
            var restTime = 0

            if let flex = exercise.flexibleSets, !flex.isEmpty, let type = exercise.trackingType {
                switch type {
                case .timeOnly, .timeDistance, .holdTime:
                    // Sum durations across sets
                    let totalDur = flex.compactMap { $0.duration }.reduce(0, +)
                    workingTime = Int(totalDur)
                    // Rest between sets (use exercise.restTime)
                    restTime = max(0, (flex.count - 1) * exercise.restTime)
                case .rounds:
                    // rounds × duration
                    if let rounds = flex.first?.rounds {
                        let perRound = Int(flex.first?.duration ?? 180)
                        workingTime = rounds * perRound
                        restTime = max(0, (rounds - 1) * exercise.restTime)
                    } else {
                        workingTime = Int(flex.first?.duration ?? 180)
                    }
                default:
                    // Fall back to reps calc below
                    break
                }
            }
            
            if workingTime == 0 {
                // Reps-based fallback using research-based rep duration
                let repDuration = getRepDurationForGoal(fitnessGoal)
                workingTime = exercise.sets * exercise.reps * repDuration
                restTime = max(0, (exercise.sets - 1) * exercise.restTime)
            }
            
            totalSeconds += workingTime + restTime + setupTime + transitionTime
        }
        
        return totalSeconds
    }
    
    /// Get rep duration based on fitness goal research
    private func getRepDurationForGoal(_ goal: FitnessGoal) -> Int {
        switch goal {
        case .strength, .powerlifting:
            return 3  // Controlled movement
        case .hypertrophy:
            return 4  // Time under tension
        case .endurance:
            return 2  // Faster tempo
        default:
            return 3  // General fitness
        }
    }
    
    // MARK: - Builders for Correct Tracking Types
    
    /// Build a TodayWorkoutExercise with appropriate tracking and defaults
    private func makeWorkoutExercise(
        for exercise: ExerciseData,
        targetDuration: WorkoutDuration,
        fitnessGoal: FitnessGoal
    ) -> TodayWorkoutExercise {
        let trackingType = ExerciseClassificationService.determineTrackingType(for: exercise)
        
        // Common rest time based on goal and movement type
        let optimalRest = getResearchBasedRestTime(
            fitnessGoal: fitnessGoal,
            isCompound: isCompoundExercise(exercise)
        )
        
        switch trackingType {
        case .repsWeight, .repsOnly:
            let rec = recommendationService.getSmartRecommendation(for: exercise, fitnessGoal: fitnessGoal)
            return TodayWorkoutExercise(
                exercise: exercise,
                sets: rec.sets,
                reps: rec.reps,
                weight: rec.weight,
                restTime: optimalRest,
                notes: nil,
                warmupSets: nil,
                flexibleSets: nil,
                trackingType: .repsWeight
            )
        case .timeDistance:
            // One session with recommended duration and default distance
            let durationSeconds = defaultDuration(for: .timeDistance, goal: fitnessGoal)
            var set = FlexibleSetData(trackingType: .timeDistance)
            set.duration = durationSeconds
            set.durationString = formatDuration(durationSeconds)
            set.distance = 1.0
            set.distanceUnit = .miles
            let flexible = [set]
            return TodayWorkoutExercise(
                exercise: exercise,
                sets: flexible.count,
                reps: 1,
                weight: nil,
                restTime: 45,
                notes: nil,
                warmupSets: nil,
                flexibleSets: flexible,
                trackingType: .timeDistance
            )
        case .timeOnly:
            // Interval-style or hold-based – use 3 intervals by default
            let perInterval = defaultDuration(for: .timeOnly, goal: fitnessGoal)
            let intervals = 3
            let flexible: [FlexibleSetData] = (0..<intervals).map { _ in
                var set = FlexibleSetData(trackingType: .timeOnly)
                set.duration = perInterval
                set.durationString = formatDuration(perInterval)
                return set
            }
            return TodayWorkoutExercise(
                exercise: exercise,
                sets: intervals,
                reps: 1,
                weight: nil,
                restTime: 30,
                notes: nil,
                warmupSets: nil,
                flexibleSets: flexible,
                trackingType: .timeOnly
            )
        case .holdTime:
            // Holds for stretching/core: 3 × 30–45s
            let hold = defaultDuration(for: .holdTime, goal: fitnessGoal)
            let flexible: [FlexibleSetData] = (0..<3).map { _ in
                var set = FlexibleSetData(trackingType: .holdTime)
                set.duration = hold
                set.durationString = formatDuration(hold)
                return set
            }
            return TodayWorkoutExercise(
                exercise: exercise,
                sets: 3,
                reps: 1,
                weight: nil,
                restTime: 30,
                notes: nil,
                warmupSets: nil,
                flexibleSets: flexible,
                trackingType: .holdTime
            )
        case .rounds:
            // Rounds with default 3 × 3:00
            let roundDuration = defaultDuration(for: .rounds, goal: fitnessGoal)
            let rounds = 3
            var set = FlexibleSetData(trackingType: .rounds)
            set.rounds = rounds
            set.duration = roundDuration
            set.durationString = formatDuration(roundDuration)
            let flexible = [set]
            return TodayWorkoutExercise(
                exercise: exercise,
                sets: rounds,
                reps: 1,
                weight: nil,
                restTime: 45,
                notes: nil,
                warmupSets: nil,
                flexibleSets: flexible,
                trackingType: .rounds
            )
        }
    }
    
    private func defaultDuration(for type: ExerciseTrackingType, goal: FitnessGoal) -> TimeInterval {
        switch type {
        case .timeDistance:
            // Endurance favors longer steady-state
            return goal == .endurance ? 900 : 600 // 15m else 10m
        case .timeOnly:
            // Work-interval length; adjust slightly for endurance
            return goal == .endurance ? 60 : 45
        case .holdTime:
            return 30
        case .rounds:
            return 180
        default:
            return 60
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remaining = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
    
    /// Determine if exercise is a compound movement
    private func isCompoundExercise(_ exercise: ExerciseData) -> Bool {
        let compoundKeywords = ["squat", "deadlift", "press", "row", "pull", "lunge", "clean", "snatch"]
        let exerciseName = exercise.name.lowercased()
        return compoundKeywords.contains { exerciseName.contains($0) }
    }
    
    /// Get optimal warmup duration based on research
    private func getOptimalWarmupDuration(_ workoutMinutes: Int) -> Int {
        switch workoutMinutes {
        case 0..<30:   return 3  // 3 minutes for short workouts
        case 30..<60:  return 5  // 5 minutes for medium workouts
        case 60..<90:  return 7  // 7 minutes for longer workouts
        case 90..<120: return 10 // 10 minutes for very long workouts
        default:       return 12 // 12 minutes for extended workouts
        }
    }
    
    // MARK: - Workout Parameters by Fitness Goal
    
    private func getWorkoutParameters(for goal: FitnessGoal, experienceLevel: ExperienceLevel) -> WorkoutParameters {
        let baseParams: WorkoutParameters
        
        switch goal {
        case .strength:
            baseParams = WorkoutParameters(
                percentageOneRM: 80...90,
                repRange: 1...6,
                repDurationSeconds: 4...6,
                setsPerExercise: 4...6,
                restBetweenSetsSeconds: 90...120,
                compoundSetupSeconds: 20,
                isolationSetupSeconds: 7,
                transitionSeconds: 20
            )
            
        case .hypertrophy:
            baseParams = WorkoutParameters(
                percentageOneRM: 60...80,
                repRange: 6...12,
                repDurationSeconds: 2...8,
                setsPerExercise: 3...5,
                restBetweenSetsSeconds: 30...90,
                compoundSetupSeconds: 20,
                isolationSetupSeconds: 7,
                transitionSeconds: 15
            )
            
        case .endurance:
            baseParams = WorkoutParameters(
                percentageOneRM: 40...60,
                repRange: 15...25,
                repDurationSeconds: 2...4,
                setsPerExercise: 2...4,
                restBetweenSetsSeconds: 20...45,
                compoundSetupSeconds: 15,
                isolationSetupSeconds: 7,
                transitionSeconds: 10
            )
            
        case .powerlifting:
            baseParams = WorkoutParameters(
                percentageOneRM: 85...100,
                repRange: 1...3,
                repDurationSeconds: 4...6,
                setsPerExercise: 3...6,
                restBetweenSetsSeconds: 120...180,
                compoundSetupSeconds: 25,
                isolationSetupSeconds: 7,
                transitionSeconds: 25
            )
            
        default:
            // General fitness fallback
            baseParams = WorkoutParameters(
                percentageOneRM: 60...75,
                repRange: 8...12,
                repDurationSeconds: 2...4,
                setsPerExercise: 3...4,
                restBetweenSetsSeconds: 60...90,
                compoundSetupSeconds: 20,
                isolationSetupSeconds: 7,
                transitionSeconds: 15
            )
        }
        
        return adjustParametersForExperienceLevel(baseParams, experienceLevel: experienceLevel)
    }
    
    private func adjustParametersForExperienceLevel(_ params: WorkoutParameters, experienceLevel: ExperienceLevel) -> WorkoutParameters {
        switch experienceLevel {
        case .beginner:
            return WorkoutParameters(
                percentageOneRM: params.percentageOneRM,
                repRange: params.repRange,
                repDurationSeconds: params.repDurationSeconds,
                setsPerExercise: max(1, params.setsPerExercise.lowerBound)...max(1, params.setsPerExercise.upperBound - 1),
                restBetweenSetsSeconds: params.restBetweenSetsSeconds,
                compoundSetupSeconds: params.compoundSetupSeconds + 15,
                isolationSetupSeconds: params.isolationSetupSeconds + 10,
                transitionSeconds: params.transitionSeconds + 10
            )
        case .advanced:
            return WorkoutParameters(
                percentageOneRM: params.percentageOneRM,
                repRange: params.repRange,
                repDurationSeconds: params.repDurationSeconds,
                setsPerExercise: params.setsPerExercise.lowerBound...(params.setsPerExercise.upperBound + 1),
                restBetweenSetsSeconds: params.restBetweenSetsSeconds,
                compoundSetupSeconds: max(5, params.compoundSetupSeconds - 5),
                isolationSetupSeconds: max(3, params.isolationSetupSeconds - 2),
                transitionSeconds: max(5, params.transitionSeconds - 5)
            )
        default:
            return params
        }
    }
    
    
}

// MARK: - Supporting Data Structures

struct WorkoutPlan {
    let exercises: [TodayWorkoutExercise]
    let actualDurationMinutes: Int
    let totalTimeBreakdown: TimeBreakdown
}

struct TimeBreakdown {
    let warmupMinutes: Int
    let exerciseMinutes: Int
    let cooldownMinutes: Int
    let totalMinutes: Int
}

struct WorkoutParameters {
    let percentageOneRM: ClosedRange<Int>
    let repRange: ClosedRange<Int>
    let repDurationSeconds: ClosedRange<Int>
    let setsPerExercise: ClosedRange<Int>
    let restBetweenSetsSeconds: ClosedRange<Int>
    let compoundSetupSeconds: Int
    let isolationSetupSeconds: Int
    let transitionSeconds: Int
}
