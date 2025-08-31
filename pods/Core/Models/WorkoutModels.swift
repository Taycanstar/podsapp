//
//  WorkoutModels.swift
//  pods
//
//  Created by Dimi Nunez on 8/26/25.
//

import Foundation
import SwiftUI

// MARK: - Exercise Data Model

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

// MARK: - Flexibility Preferences

/// Flexibility and warm-up/cool-down preferences
struct FlexibilityPreferences: Codable, Equatable {
    let warmUpEnabled: Bool
    let coolDownEnabled: Bool
    
    init(warmUpEnabled: Bool = false, coolDownEnabled: Bool = false) {
        self.warmUpEnabled = warmUpEnabled
        self.coolDownEnabled = coolDownEnabled
    }
    
    // Display text for the button
    var displayText: String {
        switch (warmUpEnabled, coolDownEnabled) {
        case (true, true):
            return "Both Enabled"
        case (true, false):
            return "Warm-Up Only"
        case (false, true):
            return "Cool-Down Only"
        case (false, false):
            return "None Selected"
        }
    }
    
    // Short text for compact display
    var shortText: String {
        switch (warmUpEnabled, coolDownEnabled) {
        case (true, true):
            return "Warm-Up & Cool-Down"
        case (true, false):
            return "Warm-Up"
        case (false, true):
            return "Cool-Down"
        case (false, false):
            return "Warm-Up/Cool-Down"
        }
    }
    
    // Check if we should show plus icon (when nothing is selected)
    var showPlusIcon: Bool {
        return !warmUpEnabled && !coolDownEnabled
    }
}

// MARK: - Core Workout Models

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
    
    // Convenience initializer for backward compatibility
    init(
        exercise: ExerciseData,
        sets: Int,
        reps: Int,
        weight: Double?,
        restTime: Int,
        notes: String? = nil,
        warmupSets: [WarmupSetData]? = nil
    ) {
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.restTime = restTime
        self.notes = notes
        self.warmupSets = warmupSets
    }
}

// MARK: - Workout Planning Models

struct LogWorkoutPlan {
    let exercises: [TodayWorkoutExercise]
    let actualDurationMinutes: Int
    let totalTimeBreakdown: WorkoutTimeBreakdown
}

struct WorkoutTimeBreakdown {
    let warmupSeconds: Int
    let exerciseTimeSeconds: Int
    let cooldownSeconds: Int
    let bufferSeconds: Int
    let totalSeconds: Int
}

// MARK: - Supporting Models

/// Warmup set data for exercise preparation
struct WarmupSetData: Codable, Hashable {
    let reps: String
    let weight: String
    
    init(reps: String, weight: String) {
        self.reps = reps
        self.weight = weight
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

// MARK: - Enhanced Exercise Tracking Models

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

/// Enhanced workout exercise that supports multiple tracking types
struct EnhancedTodayWorkoutExercise: Codable, Hashable, Identifiable {
    let id: UUID
    let exercise: ExerciseData
    let trackingType: ExerciseTrackingType
    let sets: Int
    let restTime: Int // in seconds
    let notes: String?
    
    // Tracking-specific default values for new sets
    let defaultReps: Int?
    let defaultWeight: Double?
    let defaultDuration: TimeInterval?
    let defaultDistance: Double?
    let defaultDistanceUnit: DistanceUnit?
    let defaultIntensity: Int?
    
    init(exercise: ExerciseData, trackingType: ExerciseTrackingType? = nil) {
        self.id = UUID()
        self.exercise = exercise
        
        // Auto-determine tracking type if not provided
        if let providedType = trackingType {
            self.trackingType = providedType
        } else {
            self.trackingType = ExerciseClassificationService.determineTrackingType(for: exercise)
        }
        
        self.sets = 3 // Default number of sets
        self.restTime = self.determineDefaultRestTime()
        self.notes = nil
        
        // Set appropriate defaults based on tracking type
        switch self.trackingType {
        case .repsWeight:
            self.defaultReps = 8
            self.defaultWeight = exercise.equipment == "Body weight" ? nil : 50.0
            self.defaultDuration = nil
            self.defaultDistance = nil
            self.defaultDistanceUnit = nil
            self.defaultIntensity = nil
        case .repsOnly:
            self.defaultReps = 12
            self.defaultWeight = nil
            self.defaultDuration = nil
            self.defaultDistance = nil
            self.defaultDistanceUnit = nil
            self.defaultIntensity = nil
        case .timeOnly:
            self.defaultReps = nil
            self.defaultWeight = nil
            self.defaultDuration = 120 // 2 minutes
            self.defaultDistance = nil
            self.defaultDistanceUnit = nil
            self.defaultIntensity = 5 // Moderate intensity
        case .timeDistance:
            self.defaultReps = nil
            self.defaultWeight = nil
            self.defaultDuration = 600 // 10 minutes
            self.defaultDistance = 2.0 // 2km
            self.defaultDistanceUnit = .kilometers
            self.defaultIntensity = 5
        case .holdTime:
            self.defaultReps = nil
            self.defaultWeight = nil
            self.defaultDuration = 30 // 30 seconds
            self.defaultDistance = nil
            self.defaultDistanceUnit = nil
            self.defaultIntensity = nil
        case .rounds:
            self.defaultReps = 3 // 3 rounds
            self.defaultWeight = nil
            self.defaultDuration = 180 // 3 minutes per round
            self.defaultDistance = nil
            self.defaultDistanceUnit = nil
            self.defaultIntensity = nil
        }
    }
    
    /// Determine default rest time based on exercise and tracking type
    private func determineDefaultRestTime() -> Int {
        switch trackingType {
        case .repsWeight:
            // Compound exercises need more rest than isolation
            let synergistCount = exercise.synergist.components(separatedBy: ",").count
            return synergistCount > 2 ? 120 : 90 // 2 minutes vs 1.5 minutes
        case .repsOnly:
            return 60 // 1 minute for bodyweight
        case .holdTime:
            return 30 // 30 seconds between holds
        case .timeOnly, .timeDistance:
            return 120 // 2 minutes for cardio
        case .rounds:
            return 180 // 3 minutes between rounds
        }
    }
}

/// Service to automatically determine the appropriate tracking type for exercises
struct ExerciseClassificationService {
    /// Determines the most appropriate tracking type for an exercise
    static func determineTrackingType(for exercise: ExerciseData) -> ExerciseTrackingType {
        let name = exercise.name.lowercased()
        let exerciseType = exercise.exerciseType.lowercased()
        let equipment = exercise.equipment.lowercased()
        
        // Handle aerobic exercises
        if exerciseType.contains("aerobic") {
            return determineCardioType(for: exercise)
        }
        
        // Handle stretching exercises
        if exerciseType.contains("stretching") {
            return .holdTime
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
        
        // Distance-based exercises
        if name.contains("run") || name.contains("cycle") || name.contains("row") || 
           name.contains("walk") || name.contains("jog") || name.contains("sprint") {
            return .timeDistance
        }
        
        // Time-based exercises
        return .timeOnly
    }
    
    /// Determine bodyweight exercise type
    private static func determineBodyweightType(for exercise: ExerciseData) -> ExerciseTrackingType {
        let name = exercise.name.lowercased()
        
        // Hold-based exercises
        if name.contains("plank") || name.contains("hold") || name.contains("wall sit") {
            return .holdTime
        }
        
        // Most bodyweight exercises are reps-only
        return .repsOnly
    }
    
    /// Infer tracking type from exercise name when type/equipment is unclear
    private static func inferFromExerciseName(_ exercise: ExerciseData) -> ExerciseTrackingType {
        let name = exercise.name.lowercased()
        
        // Time-based patterns
        if name.contains("plank") || name.contains("hold") {
            return .holdTime
        }
        
        // Cardio patterns
        if name.contains("run") || name.contains("bike") || name.contains("elliptical") {
            return .timeDistance
        }
        
        // Circuit/rounds patterns
        if name.contains("circuit") || name.contains("hiit") || name.contains("interval") {
            return .rounds
        }
        
        // Default to reps + weight for strength exercises
        return .repsWeight
    }
}

// MARK: - Backward Compatibility Extensions

extension EnhancedTodayWorkoutExercise {
    /// Convert enhanced model to legacy model for existing systems
    var legacyWorkoutExercise: TodayWorkoutExercise {
        TodayWorkoutExercise(
            exercise: exercise,
            sets: sets,
            reps: defaultReps ?? 1,
            weight: defaultWeight,
            restTime: restTime,
            notes: notes,
            warmupSets: nil // Will be handled separately
        )
    }
}

extension TodayWorkoutExercise {
    /// Convert legacy model to enhanced model
    var enhancedWorkoutExercise: EnhancedTodayWorkoutExercise {
        EnhancedTodayWorkoutExercise(exercise: exercise)
    }
}