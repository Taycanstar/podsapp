//
//  WorkoutHistoryService.swift
//  pods
//
//  Created by Dimi Nunez on 7/11/25.
//

//
//  WorkoutHistoryService.swift
//  Pods
//
//  Created by Dimi Nunez on 7/10/25.
//

import Foundation

class WorkoutHistoryService {
    static let shared = WorkoutHistoryService()
    
    private init() {}
    
    // MARK: - Workout Completion Tracking
    
    func completeWorkout(_ workout: WorkoutExercise, duration: TimeInterval, notes: String? = nil) {
        let userProfile = UserProfileService.shared
        
        // Convert WorkoutExercise to CompletedExercise
        let completedSets = workout.sets.map { set in
            CompletedSet(
                reps: set.reps ?? 0,
                weight: set.weight ?? 0,
                restTime: set.restTime.map { TimeInterval($0) },
                completed: true
            )
        }
        
        let completedExercise = CompletedExercise(
            exerciseId: workout.exercise.id,
            exerciseName: workout.exercise.name,
            sets: completedSets
        )
        
        // Create workout history entry
        let historyEntry = WorkoutHistoryEntry(
            exercises: [completedExercise],
            duration: duration,
            notes: notes
        )
        
        // Add to history
        userProfile.addWorkoutToHistory(historyEntry)
        
        // Update exercise performance tracking
        updateExercisePerformance(completedExercise)
        
        // Clear workout session duration since workout is completed
        LogWorkoutView.clearWorkoutSessionDuration()
        
        // Invalidate exercise history cache for real-time updates
        Task {
            await ExerciseHistoryDataService.shared.invalidateCache(for: workout.exercise.id)
        }
        
        // Log completion
        print("✅ Workout completed: \(completedExercise.exerciseName)")
    }
    
    func completeFullWorkout(_ exercises: [WorkoutExercise], duration: TimeInterval, notes: String? = nil) {
        let userProfile = UserProfileService.shared
        let recoveryService = MuscleRecoveryService.shared
        
        // Convert all exercises to completed exercises
        let completedExercises = exercises.map { workout in
            let completedSets = workout.sets.map { set in
                CompletedSet(
                    reps: set.reps ?? 0,
                    weight: set.weight ?? 0,
                    restTime: set.restTime.map { TimeInterval($0) },
                    completed: true
                )
            }
            
            return CompletedExercise(
                exerciseId: workout.exercise.id,
                exerciseName: workout.exercise.name,
                sets: completedSets
            )
        }
        
        // Create workout history entry
        let historyEntry = WorkoutHistoryEntry(
            exercises: completedExercises,
            duration: duration,
            notes: notes
        )
        
        // Add to history
        userProfile.addWorkoutToHistory(historyEntry)
        
        // Update performance tracking for all exercises
        completedExercises.forEach { updateExercisePerformance($0) }
        
        // Record muscle recovery data for future workout optimization
        recoveryService.recordWorkout(completedExercises)
        
        // Clear workout session duration since workout is completed
        LogWorkoutView.clearWorkoutSessionDuration()
        
        // Invalidate exercise history cache for all exercises in the workout
        Task {
            for exercise in completedExercises {
                await ExerciseHistoryDataService.shared.invalidateCache(for: exercise.exerciseId)
            }
        }
        
        // Log completion
        print("✅ Full workout completed with \(completedExercises.count) exercises")
        print("💪 Muscle recovery data recorded for workout optimization")
    }
    
    private func updateExercisePerformance(_ exercise: CompletedExercise) {
        let userProfile = UserProfileService.shared
        
        // Calculate totals from all sets
        let totalSets = exercise.sets.count
        let totalReps = exercise.sets.reduce(0) { $0 + $1.reps }
        let averageWeight = exercise.sets.compactMap { $0.weight > 0 ? $0.weight : nil }.average() ?? 0
        
        // Update performance tracking
        userProfile.updateExercisePerformance(
            exerciseId: exercise.exerciseId,
            sets: totalSets,
            reps: totalReps,
            weight: averageWeight
        )
    }
    
    // MARK: - Analytics & Insights
    
    func getWorkoutAnalytics(for days: Int = 30) -> WorkoutAnalytics {
        let userProfile = UserProfileService.shared
        let history = userProfile.getWorkoutHistory()
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentWorkouts = history.filter { $0.date >= cutoffDate }
        
        let totalWorkouts = recentWorkouts.count
        let totalDuration = recentWorkouts.reduce(0) { $0 + $1.duration }
        let averageDuration = totalWorkouts > 0 ? totalDuration / Double(totalWorkouts) : 0
        
        // Calculate frequency (workouts per week)
        let weeksPassed = max(1, Double(days) / 7.0)
        let workoutsPerWeek = Double(totalWorkouts) / weeksPassed
        
        // Most trained muscle groups
        let muscleGroupCounts = getMuscleGroupFrequency(from: recentWorkouts)
        
        // Progress indicators
        let progressData = getProgressIndicators(from: recentWorkouts)
        
        return WorkoutAnalytics(
            totalWorkouts: totalWorkouts,
            averageDuration: averageDuration,
            workoutsPerWeek: workoutsPerWeek,
            topMuscleGroups: muscleGroupCounts,
            progressData: progressData,
            periodDays: days
        )
    }
    
    private func getMuscleGroupFrequency(from workouts: [WorkoutHistoryEntry]) -> [String: Int] {
        var muscleGroupCounts: [String: Int] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises {
                // Get exercise data to determine muscle group
                let allExercises = ExerciseDatabase.getAllExercises()
                if let exerciseData = allExercises.first(where: { $0.id == exercise.exerciseId }) {
                    let muscleGroup = exerciseData.bodyPart
                    muscleGroupCounts[muscleGroup, default: 0] += 1
                }
            }
        }
        
        return muscleGroupCounts
    }
    
    private func getProgressIndicators(from workouts: [WorkoutHistoryEntry]) -> [ExerciseProgressData] {
        var progressData: [ExerciseProgressData] = []
        var exerciseData: [Int: [PerformanceSnapshot]] = [:]
        
        // Collect performance data for each exercise
        for workout in workouts {
            for exercise in workout.exercises {
                if exerciseData[exercise.exerciseId] == nil {
                    exerciseData[exercise.exerciseId] = []
                }
                
                let totalVolume = exercise.sets.reduce(0) { total, set in
                    total + (Double(set.reps) * set.weight)
                }
                
                let maxWeight = exercise.sets.compactMap { $0.weight > 0 ? $0.weight : nil }.max() ?? 0
                
                let snapshot = PerformanceSnapshot(
                    date: workout.date,
                    volume: totalVolume,
                    maxWeight: maxWeight,
                    totalReps: exercise.sets.reduce(0) { $0 + $1.reps }
                )
                
                exerciseData[exercise.exerciseId]?.append(snapshot)
            }
        }
        
        // Calculate progress for each exercise
        for (exerciseId, snapshots) in exerciseData {
            let sortedSnapshots = snapshots.sorted { $0.date < $1.date }
            
            if sortedSnapshots.count >= 2 {
                let first = sortedSnapshots.first!
                let last = sortedSnapshots.last!
                
                let volumeProgress = ((last.volume - first.volume) / first.volume) * 100
                let weightProgress = first.maxWeight > 0 ? ((last.maxWeight - first.maxWeight) / first.maxWeight) * 100 : 0
                
                let exerciseName = ExerciseDatabase.getAllExercises().first { $0.id == exerciseId }?.name ?? "Unknown"
                
                progressData.append(ExerciseProgressData(
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    volumeProgressPercent: volumeProgress,
                    weightProgressPercent: weightProgress,
                    workoutCount: sortedSnapshots.count
                ))
            }
        }
        
        return progressData.sorted { $0.volumeProgressPercent > $1.volumeProgressPercent }
    }
    
    // MARK: - Recommendations Based on History
    
    func getRecoveryRecommendations() -> [RecoveryRecommendation] {
        let userProfile = UserProfileService.shared
        let history = userProfile.getWorkoutHistory()
        
        var recommendations: [RecoveryRecommendation] = []
        
        // Check workout frequency
        let recentWorkouts = history.filter { workout in
            Calendar.current.isDate(workout.date, inSameDayAs: Date()) ||
            Calendar.current.isDate(workout.date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        }
        
        if recentWorkouts.count >= 2 {
            recommendations.append(RecoveryRecommendation(
                type: .rest,
                message: "Consider taking a rest day - you've worked out \(recentWorkouts.count) times in the last 2 days",
                priority: .medium
            ))
        }
        
        // Check for muscle group overtraining
        let muscleGroupFrequency = getMuscleGroupFrequency(from: Array(history.prefix(7))) // Last 7 workouts
        for (muscleGroup, count) in muscleGroupFrequency {
            if count >= 4 {
                recommendations.append(RecoveryRecommendation(
                    type: .muscleRest,
                    message: "Consider giving your \(muscleGroup) muscles a break - trained \(count) times recently",
                    priority: .high
                ))
            }
        }
        
        return recommendations
    }
    
    func getProgressiveOverloadSuggestions() -> [OverloadSuggestion] {
        let userProfile = UserProfileService.shared
        var suggestions: [OverloadSuggestion] = []
        
        // Get recent exercise performance
        let history = userProfile.getWorkoutHistory()
        let recentWorkouts = Array(history.prefix(5)) // Last 5 workouts
        
        var exercisePerformance: [Int: [CompletedExercise]] = [:]
        
        // Group exercises by ID
        for workout in recentWorkouts {
            for exercise in workout.exercises {
                if exercisePerformance[exercise.exerciseId] == nil {
                    exercisePerformance[exercise.exerciseId] = []
                }
                exercisePerformance[exercise.exerciseId]?.append(exercise)
            }
        }
        
        // Analyze each exercise for progression opportunities
        for (exerciseId, exercises) in exercisePerformance {
            if exercises.count >= 3 { // Need at least 3 data points
                let sortedExercises = exercises.sorted { workout1, workout2 in
                    // Sort by date (we don't have direct access to date here, so use array order)
                    return true
                }
                
                let recent = Array(sortedExercises.suffix(3))
                let exerciseName = recent.first?.exerciseName ?? "Unknown"
                
                // Check for weight stagnation
                let weights = recent.compactMap { exercise in
                    exercise.sets.compactMap { $0.weight > 0 ? $0.weight : nil }.max()
                }
                
                if weights.count >= 3 && weights.allSatisfy({ $0 == weights.first }) {
                    suggestions.append(OverloadSuggestion(
                        exerciseId: exerciseId,
                        exerciseName: exerciseName,
                        currentWeight: weights.first ?? 0,
                        suggestedWeight: (weights.first ?? 0) * 1.025, // 2.5% increase
                        reason: "Weight has been the same for 3+ workouts"
                    ))
                }
            }
        }
        
        return suggestions
    }
}

// MARK: - Data Models

struct WorkoutAnalytics {
    let totalWorkouts: Int
    let averageDuration: TimeInterval
    let workoutsPerWeek: Double
    let topMuscleGroups: [String: Int]
    let progressData: [ExerciseProgressData]
    let periodDays: Int
}

struct ExerciseProgressData {
    let exerciseId: Int
    let exerciseName: String
    let volumeProgressPercent: Double
    let weightProgressPercent: Double
    let workoutCount: Int
}

struct PerformanceSnapshot {
    let date: Date
    let volume: Double
    let maxWeight: Double
    let totalReps: Int
}

struct RecoveryRecommendation {
    enum RecommendationType {
        case rest
        case muscleRest
        case deload
    }
    
    enum Priority {
        case low
        case medium
        case high
    }
    
    let type: RecommendationType
    let message: String
    let priority: Priority
}

struct OverloadSuggestion {
    let exerciseId: Int
    let exerciseName: String
    let currentWeight: Double
    let suggestedWeight: Double
    let reason: String
} 