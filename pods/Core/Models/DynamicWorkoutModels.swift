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
    
    // DYNAMIC: Rep ranges instead of fixed numbers
    let setCount: Int
    let repRange: ClosedRange<Int>  // e.g., 8...12 instead of fixed 10
    let targetIntensity: IntensityZone
    let suggestedWeight: Double?
    let restTime: Int
    
    // Additional dynamic properties
    let sessionPhase: SessionPhase
    let recoveryStatus: RecoveryStatus
    let notes: String?
    let warmupSets: [WarmupSetData]?
    
    init(
        id: UUID = UUID(),
        exercise: ExerciseData,
        setCount: Int,
        repRange: ClosedRange<Int>,
        targetIntensity: IntensityZone,
        suggestedWeight: Double? = nil,
        restTime: Int,
        sessionPhase: SessionPhase = .volumeFocus,
        recoveryStatus: RecoveryStatus = .moderate,
        notes: String? = nil,
        warmupSets: [WarmupSetData]? = nil
    ) {
        self.id = id
        self.exercise = exercise
        self.setCount = setCount
        self.repRange = repRange
        self.targetIntensity = targetIntensity
        self.suggestedWeight = suggestedWeight
        self.restTime = restTime
        self.sessionPhase = sessionPhase
        self.recoveryStatus = recoveryStatus
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
        let legacyExercises = dynamicExercises.map(\.legacyExercise)
        
        return TodayWorkout(
            id: baseWorkout.id,
            date: baseWorkout.date,
            title: "\(sessionPhase.emoji) \(sessionPhase.displayName): \(baseWorkout.title)",
            exercises: legacyExercises,
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