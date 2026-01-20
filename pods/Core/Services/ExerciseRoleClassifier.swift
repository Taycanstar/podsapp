//
//  ExerciseRole.swift
//  pods
//
//  Created by Dimi Nunez on 1/19/26.
//


//
//  ExerciseRoleClassifier.swift
//  Pods
//
//  Created by Claude Code on 1/19/26.
//

import Foundation

/// Exercise role classification for structured workout programming.
/// Mirrors the backend ExerciseClassifier for consistent behavior between
/// program generation and workout refresh.
enum ExerciseRole: String, CaseIterable {
    case primaryCompound = "primary_compound"      // Multi-joint, major muscle groups
    case secondaryCompound = "secondary_compound"  // Multi-joint, assistance movements
    case isolation = "isolation"                   // Single-joint, targeted muscles

    var displayName: String {
        switch self {
        case .primaryCompound: return "Primary Compound"
        case .secondaryCompound: return "Secondary Compound"
        case .isolation: return "Isolation"
        }
    }
}

/// Classifies exercises into roles using pattern matching and synergist analysis.
/// This enables role-based exercise selection where:
/// - Primary compounds: Heavy multi-joint movements (squats, deadlifts, bench press)
/// - Secondary compounds: Assistance multi-joint movements (lunges, lat pulldowns)
/// - Isolation: Single-joint movements targeting specific muscles (curls, raises)
class ExerciseRoleClassifier {
    static let shared = ExerciseRoleClassifier()

    private init() {}

    // MARK: - Pattern Sets

    /// Primary compound movements - foundation of strength/hypertrophy training
    private let primaryCompoundPatterns: Set<String> = [
        // Pressing movements
        "bench press", "flat press", "overhead press", "military press",
        "shoulder press", "push press",

        // Pulling movements
        "barbell row", "bent over row", "pendlay row",
        "pull-up", "pull up", "chin-up", "chin up",

        // Lower body
        "squat", "back squat", "front squat", "goblet squat",
        "deadlift", "conventional deadlift", "sumo deadlift",
        "romanian deadlift", "rdl", "stiff leg deadlift",
        "hip thrust", "barbell hip thrust",
        "leg press",

        // Full body
        "clean", "snatch", "clean and jerk", "power clean",

        // Bodyweight compounds
        "dip", "chest dip", "tricep dip"
    ]

    /// Secondary compound movements - assistance exercises
    private let secondaryCompoundPatterns: Set<String> = [
        // Pressing variations
        "incline press", "incline bench", "decline press", "decline bench",
        "dumbbell press", "close grip bench",
        "arnold press", "push-up", "push up", "pushup",

        // Pulling variations
        "cable row", "seated row", "machine row",
        "lat pulldown", "pulldown", "pull down",
        "t-bar row", "t bar row", "one arm row", "single arm row",
        "face pull", "upright row",

        // Lower body variations
        "lunge", "walking lunge", "reverse lunge", "split lunge",
        "split squat", "bulgarian split squat",
        "step-up", "step up",
        "hack squat", "hack machine",
        "leg curl", "leg extension",
        "glute bridge",

        // Core compounds
        "plank", "side plank", "ab wheel", "hanging leg raise"
    ]

    /// Explicit isolation patterns (overrides synergist-based classification)
    private let isolationPatterns: Set<String> = [
        // Arms
        "curl", "bicep curl", "hammer curl", "preacher curl",
        "tricep extension", "tricep pushdown", "skull crusher",
        "kickback", "overhead extension",

        // Shoulders
        "lateral raise", "side raise", "front raise",
        "rear delt", "reverse fly", "face pull",
        "shrug",

        // Chest
        "fly", "flye", "chest fly", "cable crossover", "pec deck",

        // Back
        "pullover", "straight arm pulldown",

        // Lower body isolation
        "calf raise", "calf press",
        "leg curl", "hamstring curl",
        "leg extension", "quad extension",
        "hip abduction", "hip adduction",
        "glute kickback",

        // Core isolation
        "crunch", "sit-up", "situp",
        "russian twist", "cable twist",
        "leg raise", "knee raise"
    ]

    // MARK: - Classification Methods

    /// Classify an exercise into its role based on CSV data or pattern matching.
    ///
    /// Priority:
    /// 1. CSV pre-computed role (highest accuracy - manually curated)
    /// 2. Primary compound patterns
    /// 3. Secondary compound patterns
    /// 4. Isolation patterns (explicit)
    /// 5. Synergist count fallback (2+ synergists = secondary compound)
    /// 6. Default to isolation
    ///
    /// - Parameter exercise: ExerciseData from exercisesdb.csv
    /// - Returns: ExerciseRole enum value
    func classify(_ exercise: ExerciseData) -> ExerciseRole {
        // NEW: Check for pre-computed role from CSV first (most accurate)
        if let roleString = exercise.exerciseRole,
           let role = ExerciseRole(rawValue: roleString) {
            return role
        }

        // FALLBACK: Pattern-based classification
        let nameLower = exercise.name.lowercased()

        // Check primary compound patterns first (highest priority)
        for pattern in primaryCompoundPatterns {
            if nameLower.contains(pattern) {
                return .primaryCompound
            }
        }

        // Check secondary compound patterns
        for pattern in secondaryCompoundPatterns {
            if nameLower.contains(pattern) {
                return .secondaryCompound
            }
        }

        // Check explicit isolation patterns
        for pattern in isolationPatterns {
            if nameLower.contains(pattern) {
                return .isolation
            }
        }

        // Fallback: Use synergist count to determine compound vs isolation
        // Compound movements typically involve 2+ synergist muscle groups
        let synergistCount = exercise.synergist
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .count

        if synergistCount >= 2 {
            return .secondaryCompound
        }

        // Default to isolation
        return .isolation
    }

    /// Classify an exercise by name and synergist string directly.
    /// Useful when you don't have a full ExerciseData object.
    ///
    /// - Parameters:
    ///   - name: Exercise name
    ///   - synergist: Comma-separated synergist muscles
    /// - Returns: ExerciseRole enum value
    func classify(name: String, synergist: String = "") -> ExerciseRole {
        // Create a mock exercise for classification
        // This avoids duplicating the classification logic
        let nameLower = name.lowercased()

        // Check primary compound patterns
        for pattern in primaryCompoundPatterns {
            if nameLower.contains(pattern) {
                return .primaryCompound
            }
        }

        // Check secondary compound patterns
        for pattern in secondaryCompoundPatterns {
            if nameLower.contains(pattern) {
                return .secondaryCompound
            }
        }

        // Check isolation patterns
        for pattern in isolationPatterns {
            if nameLower.contains(pattern) {
                return .isolation
            }
        }

        // Synergist count fallback
        let synergistCount = synergist
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .count

        if synergistCount >= 2 {
            return .secondaryCompound
        }

        return .isolation
    }
}
