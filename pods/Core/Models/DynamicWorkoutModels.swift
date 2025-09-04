//
//  DynamicWorkoutModels.swift
//  pods
//
//  Created by Dimi Nunez on 8/26/25.
//

//
//  DynamicWorkoutModels.swift
//  pods
//
//  Created by Dimi Nunez on 8/26/25.
//

import Foundation

// MARK: - Dynamic Programming Core Models

/// Dynamic workout parameters that control intelligent rep range variations
struct DynamicWorkoutParameters: Codable, Equatable {
    let sessionPhase: SessionPhase
    let recoveryStatus: [String: RecoveryStatus] // Muscle group -> recovery status
    let performanceHistory: PerformanceMetrics
    let autoRegulationLevel: Double // 0.0 - 1.0 (conservative to aggressive)
    let lastWorkoutFeedback: WorkoutSessionFeedback?
    let timestamp: Date
    
    init(
        sessionPhase: SessionPhase,
        recoveryStatus: [String: RecoveryStatus] = [:],
        performanceHistory: PerformanceMetrics = PerformanceMetrics.default,
        autoRegulationLevel: Double = 0.5,
        lastWorkoutFeedback: WorkoutSessionFeedback? = nil,
        timestamp: Date = Date()
    ) {
        self.sessionPhase = sessionPhase
        self.recoveryStatus = recoveryStatus
        self.performanceHistory = performanceHistory
        self.autoRegulationLevel = autoRegulationLevel
        self.lastWorkoutFeedback = lastWorkoutFeedback
        self.timestamp = timestamp
    }
    
    // Computed properties for algorithm decisions
    var shouldIncreaseDifficulty: Bool {
        guard let feedback = lastWorkoutFeedback else { return false }
        return feedback.overallRPE < 6.0 && feedback.completionRate > 0.9
    }
    
    var shouldDecreaseDifficulty: Bool {
        guard let feedback = lastWorkoutFeedback else { return false }
        return feedback.overallRPE > 8.0 || feedback.completionRate < 0.7
    }
}

/// Session phases for periodization cycling (Fitbod's A-B-C pattern)
enum SessionPhase: String, CaseIterable, Codable {
    case strengthFocus = "strength"         // Lower reps, higher intensity
    case volumeFocus = "volume"             // Higher reps, moderate intensity  
    case conditioningFocus = "conditioning" // Circuit-style, time-based
    
    var displayName: String {
        switch self {
        case .strengthFocus: return "Strength Focus"
        case .volumeFocus: return "Volume Focus" 
        case .conditioningFocus: return "Conditioning Focus"
        }
    }
    
    var description: String {
        switch self {
        case .strengthFocus: return "Building maximum strength with lower reps"
        case .volumeFocus: return "Muscle growth with higher volume"
        case .conditioningFocus: return "Endurance and conditioning work"
        }
    }
    
    var emoji: String {
        switch self {
        case .strengthFocus: return "💪"
        case .volumeFocus: return "📊"
        case .conditioningFocus: return "🏃‍♂️"
        }
    }
    
    /// Get next phase in A-B-C cycling pattern
    func nextPhase() -> SessionPhase {
        switch self {
        case .strengthFocus: return .volumeFocus
        case .volumeFocus: return .conditioningFocus
        case .conditioningFocus: return .strengthFocus
        }
    }
    
    /// Create phase that aligns with user's fitness goal
    static func alignedWith(fitnessGoal: FitnessGoal) -> SessionPhase {
        switch fitnessGoal {
        case .strength, .powerlifting, .power:
            return .strengthFocus
        case .hypertrophy, .general:
            return .volumeFocus  
        case .endurance, .tone, .sport:
            return .conditioningFocus
        }
    }
    
    /// Display name that matches fitness goal context
    func contextualDisplayName(for goal: FitnessGoal) -> String {
        switch (self, goal) {
        case (.strengthFocus, .strength), (.strengthFocus, .powerlifting), (.strengthFocus, .power):
            return "Strength Training"
        case (.volumeFocus, .hypertrophy):
            return "Muscle Building"  
        case (.volumeFocus, .general):
            return "General Fitness"
        case (.conditioningFocus, .endurance):
            return "Endurance Training"
        case (.conditioningFocus, .tone):
            return "Toning & Conditioning"
        case (.conditioningFocus, .sport):
            return "Sport Performance"
        default:
            return displayName  // Fallback to original
        }
    }
}

/// Movement priority determines exercise-specific parameters
enum MovementPriority: String, CaseIterable, Codable {
    case primary = "primary"         // Main compound movements (squat, deadlift, bench)
    case secondary = "secondary"     // Supporting compounds (rows, overhead press)
    case accessory = "accessory"     // Isolation movements (bicep curls, lateral raises)
    case core = "core"              // Core-specific movements
    case cardio = "cardio"          // Cardio-strength movements
    
    var displayName: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        case .accessory: return "Accessory"
        case .core: return "Core"
        case .cardio: return "Cardio"
        }
    }
}

/// Recovery status affects rep ranges and intensity
enum RecoveryStatus: String, CaseIterable, Codable {
    case fresh = "fresh"           // 0-24 hours since last workout
    case moderate = "moderate"     // 24-48 hours
    case fatigued = "fatigued"     // 48+ hours but high training load
    
    var displayName: String {
        switch self {
        case .fresh: return "Fresh"
        case .moderate: return "Moderate"
        case .fatigued: return "Fatigued"
        }
    }
    
    var intensityMultiplier: Double {
        switch self {
        case .fresh: return 1.0      // Can handle full intensity
        case .moderate: return 0.9   // Slight reduction
        case .fatigued: return 0.8   // Significant reduction
        }
    }
    
    var repAdjustment: Int {
        switch self {
        case .fresh: return -1       // Lower reps, higher intensity
        case .moderate: return 0     // No adjustment
        case .fatigued: return +2    // Higher reps, lower intensity
        }
    }
}

/// Post-workout feedback for auto-regulation
struct WorkoutSessionFeedback: Codable, Identifiable, Equatable {
    let id: UUID
    let workoutId: UUID
    let overallRPE: Double           // 1-10 scale (Rate of Perceived Exertion)
    let difficultyRating: DifficultyRating
    let completionRate: Double       // 0.0-1.0 (percentage completed)
    let exerciseFeedback: [String: ExerciseFeedback] // Exercise name -> feedback
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        workoutId: UUID,
        overallRPE: Double,
        difficultyRating: DifficultyRating,
        completionRate: Double = 1.0,
        exerciseFeedback: [String: ExerciseFeedback] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.workoutId = workoutId
        self.overallRPE = overallRPE
        self.difficultyRating = difficultyRating
        self.completionRate = completionRate
        self.exerciseFeedback = exerciseFeedback
        self.timestamp = timestamp
    }
    
    enum DifficultyRating: String, CaseIterable, Codable {
        case tooEasy = "too_easy"
        case justRight = "just_right"  
        case challenging = "challenging"
        case tooHard = "too_hard"
        
        var rpeRange: ClosedRange<Double> {
            switch self {
            case .tooEasy: return 1.0...4.0
            case .justRight: return 5.0...7.0
            case .challenging: return 7.0...8.5
            case .tooHard: return 8.5...10.0
            }
        }
        
        var displayName: String {
            switch self {
            case .tooEasy: return "Too Easy"
            case .justRight: return "Just Right"
            case .challenging: return "Challenging"
            case .tooHard: return "Too Hard"
            }
        }
        
        var emoji: String {
            switch self {
            case .tooEasy: return "😴"
            case .justRight: return "👍"
            case .challenging: return "🔥"
            case .tooHard: return "🥵"
            }
        }
    }
}

/// Individual exercise feedback
struct ExerciseFeedback: Codable, Equatable {
    let exerciseId: Int
    let exerciseName: String
    let completedSets: Int
    let completedReps: [Int]  // Actual reps per set
    let usedWeight: Double?
    let perceivedDifficulty: Double // 1-10 scale
    let wasSkipped: Bool
    
    init(
        exerciseId: Int,
        exerciseName: String,
        completedSets: Int,
        completedReps: [Int],
        usedWeight: Double? = nil,
        perceivedDifficulty: Double = 5.0,
        wasSkipped: Bool = false
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.completedSets = completedSets
        self.completedReps = completedReps
        self.usedWeight = usedWeight
        self.perceivedDifficulty = perceivedDifficulty
        self.wasSkipped = wasSkipped
    }
}

/// Performance metrics for auto-regulation decisions
struct PerformanceMetrics: Codable, Equatable {
    let averageRPE: Double
    let averageCompletionRate: Double
    let recentFeedbackCount: Int
    let trend: PerformanceTrend
    let plateauRisk: Double // 0.0-1.0
    
    static let `default` = PerformanceMetrics(
        averageRPE: 6.5,
        averageCompletionRate: 1.0,
        recentFeedbackCount: 0,
        trend: .stable,
        plateauRisk: 0.0
    )
    
    init(
        averageRPE: Double,
        averageCompletionRate: Double,
        recentFeedbackCount: Int,
        trend: PerformanceTrend,
        plateauRisk: Double = 0.0
    ) {
        self.averageRPE = averageRPE
        self.averageCompletionRate = averageCompletionRate
        self.recentFeedbackCount = recentFeedbackCount
        self.trend = trend
        self.plateauRisk = plateauRisk
    }
}

enum PerformanceTrend: String, Codable {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"
}

// MARK: - Dynamic Exercise Models

/// Enhanced exercise with dynamic rep ranges instead of fixed numbers
struct DynamicWorkoutExercise: Codable, Hashable, Identifiable {
    let id: UUID
    let exercise: ExerciseData
    
    // DYNAMIC: Rep ranges AND specific daily targets
    let setCount: Int
    let repRange: ClosedRange<Int>  // e.g., 8...12 for flexibility
    let targetReps: Int             // e.g., 10 - the specific daily target
    let targetIntensity: IntensityZone
    let suggestedWeight: Double?
    let restTime: Int
    
    // Additional dynamic properties
    let sessionPhase: SessionPhase
    let recoveryStatus: RecoveryStatus
    let movementPriority: MovementPriority
    let notes: String?
    let warmupSets: [WarmupSetData]?
    
    init(
        id: UUID = UUID(),
        exercise: ExerciseData,
        setCount: Int,
        repRange: ClosedRange<Int>,
        targetReps: Int,
        targetIntensity: IntensityZone,
        suggestedWeight: Double? = nil,
        restTime: Int,
        sessionPhase: SessionPhase = .volumeFocus,
        recoveryStatus: RecoveryStatus = .moderate,
        movementPriority: MovementPriority = .secondary,
        notes: String? = nil,
        warmupSets: [WarmupSetData]? = nil
    ) {
        self.id = id
        self.exercise = exercise
        self.setCount = setCount
        self.repRange = repRange
        self.targetReps = targetReps
        self.targetIntensity = targetIntensity
        self.suggestedWeight = suggestedWeight
        self.restTime = restTime
        self.sessionPhase = sessionPhase
        self.recoveryStatus = recoveryStatus
        self.movementPriority = movementPriority
        self.notes = notes
        self.warmupSets = warmupSets
    }
    
    // Computed properties for UI display
    var repRangeDisplay: String {
        if repRange.lowerBound == repRange.upperBound {
            return "\(repRange.lowerBound)"  // "10" for fixed reps
        } else {
            return "\(repRange.lowerBound)-\(repRange.upperBound)"  // "8-12" for ranges
        }
    }
    
    /// Daily target display in "3 sets • 10 reps" format
    var dailyTargetDisplay: String {
        let setsText = setCount == 1 ? "set" : "sets"
        return "\(setCount) \(setsText) • \(targetReps) reps"
    }
    
    var setsAndRepsDisplay: String {
        return "\(setCount) × \(repRangeDisplay)"
    }
    
    var targetRepSuggestion: String {
        let target = repRange.lowerBound + (repRange.upperBound - repRange.lowerBound) * 2 / 3
        if target > repRange.lowerBound {
            return "aim for \(target)+"
        } else {
            return "aim for \(repRange.upperBound)"
        }
    }
    
    // Backward compatibility with existing TodayWorkoutExercise
    var legacyExercise: TodayWorkoutExercise {
        TodayWorkoutExercise(
            exercise: exercise,
            sets: setCount,
            reps: repRange.upperBound, // Use upper bound as default for compatibility
            weight: suggestedWeight,
            restTime: restTime,
            notes: notes,
            warmupSets: warmupSets
        )
    }
}

/// Intensity zones for periodization
enum IntensityZone: String, CaseIterable, Codable {
    case strength = "strength"        // 1-6 reps, 80-95% 1RM
    case hypertrophy = "hypertrophy"  // 6-15 reps, 65-80% 1RM
    case endurance = "endurance"      // 15+ reps, 50-65% 1RM
    
    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .endurance: return "Endurance"
        }
    }
    
    var baseRepRange: ClosedRange<Int> {
        switch self {
        case .strength: return 3...6
        case .hypertrophy: return 8...15
        case .endurance: return 15...25
        }
    }
    
    var restTime: Int {
        switch self {
        case .strength: return 180  // 3 minutes
        case .hypertrophy: return 90   // 90 seconds
        case .endurance: return 60     // 1 minute
        }
    }
    
    var emoji: String {
        switch self {
        case .strength: return "💪"
        case .hypertrophy: return "🏋️"
        case .endurance: return "🏃"
        }
    }
}

/// Movement type classification for dynamic programming
enum MovementType: String, CaseIterable, Codable {
    case compound = "compound"      // Multi-joint movements
    case isolation = "isolation"    // Single-joint movements
    case cardio = "cardio"          // Cardio exercises
    case core = "core"              // Core-specific exercises
    
    var displayName: String {
        switch self {
        case .compound: return "Compound"
        case .isolation: return "Isolation"
        case .cardio: return "Cardio"
        case .core: return "Core"
        }
    }
    
    /// Classify exercise based on ExerciseData
    static func classify(_ exercise: ExerciseData) -> MovementType {
        let exerciseName = exercise.name.lowercased()
        let bodyPart = exercise.bodyPart.lowercased()
        
        // Core exercises
        if bodyPart == "waist" || bodyPart.contains("abs") || 
           exerciseName.contains("crunch") || exerciseName.contains("plank") {
            return .core
        }
        
        // Cardio exercises
        if exercise.exerciseType.lowercased() == "aerobic" || 
           bodyPart == "cardio" || exerciseName.contains("treadmill") {
            return .cardio
        }
        
        // Compound movements (multi-joint)
        let compoundKeywords = ["squat", "deadlift", "bench press", "press", "row", 
                               "pull-up", "pullup", "chin-up", "chinup", "dip", 
                               "lunge", "clean", "snatch", "thrust", "burpee", 
                               "push-up", "pushup"]
        
        for keyword in compoundKeywords {
            if exerciseName.contains(keyword) {
                return .compound
            }
        }
        
        // Check for multi-muscle targeting
        let muscleCount = exercise.target.components(separatedBy: ",").count
        if muscleCount > 1 {
            return .compound
        }
        
        // Default to isolation
        return .isolation
    }
}

// MARK: - Dynamic Workout Container

/// Container for dynamic workout that maintains backward compatibility
struct DynamicTodayWorkout: Codable, Identifiable {
    let id: UUID
    let baseWorkout: TodayWorkout
    let dynamicExercises: [DynamicWorkoutExercise]
    let sessionPhase: SessionPhase
    let dynamicParameters: DynamicWorkoutParameters
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        baseWorkout: TodayWorkout,
        dynamicExercises: [DynamicWorkoutExercise],
        sessionPhase: SessionPhase,
        dynamicParameters: DynamicWorkoutParameters,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.baseWorkout = baseWorkout
        self.dynamicExercises = dynamicExercises
        self.sessionPhase = sessionPhase
        self.dynamicParameters = dynamicParameters
        self.timestamp = timestamp
    }
    
    /// Backward compatibility with existing UI
    var legacyWorkout: TodayWorkout {
        // Merge dynamic reps-based guidance with base workout while preserving
        // duration-based tracking (flexibleSets/trackingType) from the base.
        let mergedExercises: [TodayWorkoutExercise] = {
            let base = baseWorkout.exercises
            // Build a lookup of dynamic exercises by exercise.id to avoid index mismatches
            // Use last-wins to safely handle duplicate ids (can occur when the same exercise appears twice)
            let dynById: [Int: DynamicWorkoutExercise] = dynamicExercises.reduce(into: [:]) { acc, ex in
                acc[ex.exercise.id] = ex
            }
            var result: [TodayWorkoutExercise] = []
            result.reserveCapacity(base.count)
            for baseEx in base {
                let tracking = baseEx.trackingType ?? ExerciseClassificationService.determineTrackingType(for: baseEx.exercise)
                switch tracking {
                case .timeOnly, .timeDistance, .holdTime, .rounds:
                    // Keep base (preserve flexibleSets/trackingType)
                    result.append(baseEx)
                default:
                    if let dynEx = dynById[baseEx.exercise.id] {
                        result.append(dynEx.legacyExercise)
                    } else {
                        result.append(baseEx)
                    }
                }
            }
            return result
        }()

        return TodayWorkout(
            id: baseWorkout.id,
            date: baseWorkout.date,
            title: "\(sessionPhase.emoji) \(sessionPhase.displayName): \(baseWorkout.title)",
            exercises: mergedExercises,
            estimatedDuration: baseWorkout.estimatedDuration,
            fitnessGoal: baseWorkout.fitnessGoal,
            difficulty: baseWorkout.difficulty,
            warmUpExercises: baseWorkout.warmUpExercises,
            coolDownExercises: baseWorkout.coolDownExercises
        )
    }
}

// MARK: - Helper Extensions

extension DynamicWorkoutParameters {
    /// Create default parameters for new users
    static func createDefault(sessionPhase: SessionPhase = .volumeFocus) -> DynamicWorkoutParameters {
        return DynamicWorkoutParameters(
            sessionPhase: sessionPhase,
            recoveryStatus: [:],
            performanceHistory: .default,
            autoRegulationLevel: 0.5,
            lastWorkoutFeedback: nil
        )
    }
}

extension WorkoutSessionFeedback.DifficultyRating {
    /// Convert difficulty rating to RPE estimate
    var estimatedRPE: Double {
        switch self {
        case .tooEasy: return 3.0
        case .justRight: return 6.5
        case .challenging: return 8.0
        case .tooHard: return 9.0
        }
    }
}

// MARK: - Core Workout Models (moved from WorkoutModels.swift)

import SwiftUI

/// Core exercise data structure used throughout the app
struct ExerciseData: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let exerciseType: String
    let bodyPart: String
    let equipment: String
    let gender: String
    let target: String
    let synergist: String
    let complexityRating: Int? // 1-5 scale: 1=Beginner, 5=Expert (optional for backward compatibility)
    
    // Initializer with optional complexity rating for backward compatibility
    init(id: Int, name: String, exerciseType: String, bodyPart: String, equipment: String, gender: String, target: String, synergist: String, complexityRating: Int? = nil) {
        self.id = id
        self.name = name
        self.exerciseType = exerciseType
        self.bodyPart = bodyPart
        self.equipment = equipment
        self.gender = gender
        self.target = target
        self.synergist = synergist
        self.complexityRating = complexityRating
    }
    
    // Computed properties for compatibility
    var muscle: String { bodyPart }
    var category: String { equipment }
    var instructions: String? { target.isEmpty ? nil : target }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ExerciseData, rhs: ExerciseData) -> Bool {
        lhs.id == rhs.id
    }
}

/// Core workout structure used throughout the app
struct TodayWorkout: Codable, Hashable, Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let exercises: [TodayWorkoutExercise]
    let estimatedDuration: Int
    let fitnessGoal: FitnessGoal
    let difficulty: Int
    let warmUpExercises: [TodayWorkoutExercise]?
    let coolDownExercises: [TodayWorkoutExercise]?
    
    // Convenience initializer for backward compatibility
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String,
        exercises: [TodayWorkoutExercise],
        estimatedDuration: Int,
        fitnessGoal: FitnessGoal,
        difficulty: Int,
        warmUpExercises: [TodayWorkoutExercise]? = nil,
        coolDownExercises: [TodayWorkoutExercise]? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.exercises = exercises
        self.estimatedDuration = estimatedDuration
        self.fitnessGoal = fitnessGoal
        self.difficulty = difficulty
        self.warmUpExercises = warmUpExercises
        self.coolDownExercises = coolDownExercises
    }
}

/// Exercise within a workout with sets, reps, and weight
struct TodayWorkoutExercise: Codable, Hashable {
    let exercise: ExerciseData
    let sets: Int
    let reps: Int
    let weight: Double?
    let restTime: Int // in seconds
    let notes: String? // Exercise-specific notes
    let warmupSets: [WarmupSetData]? // Warm-up sets data for persistence
    let flexibleSets: [FlexibleSetData]? // Duration and flexible tracking data for persistence
    let trackingType: ExerciseTrackingType? // Exercise tracking type for persistence
    
    // Convenience initializer for backward compatibility
    init(
        exercise: ExerciseData,
        sets: Int,
        reps: Int,
        weight: Double?,
        restTime: Int,
        notes: String? = nil,
        warmupSets: [WarmupSetData]? = nil,
        flexibleSets: [FlexibleSetData]? = nil,
        trackingType: ExerciseTrackingType? = nil
    ) {
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.restTime = restTime
        self.notes = notes
        self.warmupSets = warmupSets
        self.flexibleSets = flexibleSets
        self.trackingType = trackingType
    }
}

/// Warmup set data for exercise preparation
struct WarmupSetData: Codable, Hashable {
    let reps: String
    let weight: String
    
    init(reps: String, weight: String) {
        self.reps = reps
        self.weight = weight
    }
}

/// Different tracking types based on exercise science principles
enum ExerciseTrackingType: String, Codable, CaseIterable {
    case repsWeight = "reps_weight"           // Traditional strength: 3×8 @ 150lbs
    case repsOnly = "reps_only"               // Bodyweight: 3×12 push-ups
    case timeDistance = "time_distance"       // Cardio: 30min @ 5km
    case timeOnly = "time_only"               // Intervals: 45s work, 15s rest  
    case holdTime = "hold_time"               // Stretching: 30s hold × 3
    case rounds = "rounds"                    // Circuit: 5 rounds × 3min
    
    var displayName: String {
        switch self {
        case .repsWeight:
            return "Reps & Weight"
        case .repsOnly:
            return "Reps Only"
        case .timeDistance:
            return "Time & Distance"
        case .timeOnly:
            return "Time Only"
        case .holdTime:
            return "Hold Time"
        case .rounds:
            return "Rounds"
        }
    }
    
    /// Description for users to understand each type
    var description: String {
        switch self {
        case .repsWeight:
            return "Track sets, reps, and weight - perfect for traditional strength training"
        case .repsOnly:
            return "Track sets and reps without weight - ideal for bodyweight exercises"
        case .timeDistance:
            return "Track duration and distance - great for running, cycling, rowing"
        case .timeOnly:
            return "Track time-based activities - perfect for intervals, holds, cardio"
        case .holdTime:
            return "Track hold duration - designed for stretching and isometric exercises"
        case .rounds:
            return "Track rounds and time - ideal for circuit training and boxing"
        }
    }
}

/// Distance units for cardio tracking
enum DistanceUnit: String, CaseIterable, Codable {
    case kilometers = "km"
    case miles = "mi" 
    case meters = "m"
    
    var symbol: String {
        return rawValue
    }
    
    var displayName: String {
        switch self {
        case .kilometers:
            return "Kilometers"
        case .miles:
            return "Miles"
        case .meters:
            return "Meters"
        }
    }
}

/// Flexible set data that adapts to different exercise tracking types
struct FlexibleSetData: Identifiable, Codable, Hashable {
    let id: UUID
    var trackingType: ExerciseTrackingType
    
    // Traditional strength training fields
    var reps: String?
    var weight: String?
    
    // Time-based tracking fields
    var duration: TimeInterval?        // Duration in seconds
    var durationString: String?        // Formatted duration for UI display (e.g. "2:30")
    
    // Distance tracking fields
    var distance: Double?              // Distance value
    var distanceUnit: DistanceUnit?    // km, miles, meters
    
    // Additional tracking metrics
    var intensity: Int?                // 1-10 intensity scale for cardio
    var rounds: Int?                   // Number of rounds for circuit training
    var restTime: Int?                 // Custom rest time for this set (seconds)
    
    // Set completion tracking
    var isCompleted: Bool
    var isWarmupSet: Bool
    var notes: String?
    
    /// Computed property to determine if set is actually completed based on entered data
    var isActuallyCompleted: Bool {
        switch trackingType {
        case .repsWeight:
            // Both reps and weight must be filled and valid
            guard let repsStr = reps, !repsStr.isEmpty,
                  let weightStr = weight, !weightStr.isEmpty else { return false }
            return Int(repsStr) != nil && Int(repsStr)! > 0 &&
                   Double(weightStr) != nil && Double(weightStr)! > 0
        case .timeDistance:
            // Both duration and distance must be set
            return duration != nil && duration! > 0 && distance != nil && distance! > 0
        case .timeOnly:
            // Duration must be set
            return duration != nil && duration! > 0
        // Handle legacy types that might still exist
        case .repsOnly:
            guard let repsStr = reps, !repsStr.isEmpty else { return false }
            return Int(repsStr) != nil && Int(repsStr)! > 0
        case .holdTime:
            return duration != nil && duration! > 0
        case .rounds:
            return rounds != nil && rounds! > 0
        }
    }
    
    init(trackingType: ExerciseTrackingType) {
        self.id = UUID()
        self.trackingType = trackingType
        self.isCompleted = false
        self.isWarmupSet = false
        
        // Initialize appropriate default values based on tracking type
        switch trackingType {
        case .repsWeight:
            self.reps = ""
            self.weight = ""
        case .repsOnly:
            self.reps = ""
        case .timeDistance:
            self.duration = nil
            self.distance = nil
            self.distanceUnit = .kilometers
        case .timeOnly:
            self.duration = nil
            self.intensity = 5 // Default moderate intensity
        case .holdTime:
            self.duration = nil
        case .rounds:
            self.rounds = nil
            self.duration = nil
        }
    }
    
    /// Returns a user-friendly display string for this set
    var displayValue: String {
        switch trackingType {
        case .repsWeight:
            let repsText = reps ?? "0"
            let weightText = weight ?? "0"
            return "\(repsText) reps @ \(weightText) lbs"
        case .repsOnly:
            let repsText = reps ?? "0"
            return "\(repsText) reps"
        case .timeDistance:
            let timeText = durationString ?? formatDuration(duration ?? 0)
            let distanceText = distance ?? 0
            let unitText = distanceUnit?.symbol ?? "km"
            return "\(timeText) @ \(String(format: "%.1f", distanceText))\(unitText)"
        case .timeOnly:
            let timeText = durationString ?? formatDuration(duration ?? 0)
            let intensityText = intensity != nil ? " @ Zone \(intensity!)" : ""
            return "\(timeText)\(intensityText)"
        case .holdTime:
            let timeText = durationString ?? formatDuration(duration ?? 0)
            return "Hold \(timeText)"
        case .rounds:
            let roundsText = rounds ?? 0
            let timeText = duration != nil ? " @ \(formatDuration(duration!))" : ""
            return "\(roundsText) rounds\(timeText)"
        }
    }
    
    /// Helper function to format duration in seconds to MM:SS format
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

/// Weight unit for display
enum WeightUnit: String, CaseIterable {
    case kg = "kg"
    case lbs = "lbs"
    
    var displayName: String {
        return rawValue
    }
}
struct ExerciseClassificationService {
    /// Determines the most appropriate tracking type for an exercise
    static func determineTrackingType(for exercise: ExerciseData) -> ExerciseTrackingType {
        let name = exercise.name.lowercased()
        let exerciseType = exercise.exerciseType.lowercased()
        let equipment = exercise.equipment.lowercased()
        
        // PRIORITY 1: Check exercise name patterns first (overrides everything)
        if name.contains("plank") || name.contains("wall sit") ||
           (name.contains("isometric") || (name.contains("hold") && exerciseType == "stretching")) {
            // Only classify generic "hold" as duration when it's explicitly stretching or isometric
            return .timeOnly
        }
        
        // Handle aerobic exercises
        if exerciseType.contains("aerobic") {
            return determineCardioType(for: exercise)
        }
        
        // Handle stretching exercises (duration-based holds)
        if exerciseType.contains("stretching") {
            return .timeOnly  // Use timeOnly for stretching (duration-only tracking)
        }
        
        // Handle bodyweight exercises
        if equipment.contains("body weight") {
            return determineBodyweightType(for: exercise)
        }
        
        // Handle strength exercises with equipment
        if exerciseType.contains("strength") {
            return .repsWeight
        }
        
        // Default fallback based on exercise name patterns
        return inferFromExerciseName(exercise)
    }
    
    /// Determine specific cardio tracking type
    private static func determineCardioType(for exercise: ExerciseData) -> ExerciseTrackingType {
        let name = exercise.name.lowercased()
        // Exclude strength patterns that contain walking but are not cardio (e.g. walking lunge/step)
        let isWalkingStrengthPattern = (name.contains("walk") && (name.contains("lunge") || name.contains("step")))

        // Distance-based exercises
        if (name.contains("run") || name.contains("cycle") || name.contains("row") ||
            name.contains("walk") || name.contains("jog") || name.contains("sprint")) && !isWalkingStrengthPattern {
            return .timeDistance
        }
        
        // Time-based exercises
        return .timeOnly
    }
    
    /// Determine bodyweight exercise type - ALL should have weight tracking capability
    private static func determineBodyweightType(for exercise: ExerciseData) -> ExerciseTrackingType {
        let name = exercise.name.lowercased()
        
        // Hold-based exercises should be duration-only
        if name.contains("plank") || name.contains("wall sit") || name.contains("isometric") {
            return .timeOnly
        }
        
        // ALL other bodyweight exercises should have reps+weight (user can add weight later)
        return .repsWeight
    }
    
    /// Infer tracking type from exercise name when type/equipment is unclear
    private static func inferFromExerciseName(_ exercise: ExerciseData) -> ExerciseTrackingType {
        let name = exercise.name.lowercased()
        
        // Time-based patterns (duration only)
        if name.contains("plank") || name.contains("wall sit") || name.contains("isometric") {
            return .timeOnly
        }
        
        // Cardio patterns (duration + distance)
        let isWalkingStrengthPattern = (name.contains("walk") && (name.contains("lunge") || name.contains("step")))
        if (name.contains("run") || name.contains("bike") || name.contains("elliptical") ||
            name.contains("row") || name.contains("jog") || name.contains("sprint") ||
            (name.contains("walk") && !isWalkingStrengthPattern) ||
            name.contains("farmer") || name.contains("suitcase") || name.contains("carry")) {
            return .timeDistance
        }
        
        // Circuit/interval patterns should be duration-only
        if name.contains("circuit") || name.contains("hiit") || name.contains("interval") || name.contains("emom") || name.contains("tabata") {
            return .timeOnly
        }
        
        // Default to reps + weight for strength exercises
        return .repsWeight
    }
}
