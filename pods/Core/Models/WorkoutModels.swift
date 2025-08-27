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