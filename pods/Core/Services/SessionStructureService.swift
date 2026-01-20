//
//  ExerciseSlot.swift
//  pods
//
//  Created by Dimi Nunez on 1/19/26.
//


//
//  SessionStructureService.swift
//  Pods
//
//  Created by Claude Code on 1/19/26.
//

import Foundation

/// A single exercise slot with role and rep range assignment.
struct ExerciseSlot {
    let role: ExerciseRole
    let repRange: String
}

/// Session Structure Service
///
/// Defines goal-based session structure templates that determine how many exercises
/// of each role (primary compound, secondary compound, isolation) should be in a workout.
///
/// The session structure ensures workouts follow evidence-based programming:
/// - Strength: Heavy compounds dominate (50% primary, 30% secondary, 20% isolation)
/// - Hypertrophy: Balanced approach (35% primary, 30% secondary, 35% isolation)
/// - Endurance: High-rep metabolic focus (25% primary, 25% secondary, 50% isolation)
/// - Balanced: Strength + hypertrophy blend (40% primary, 30% secondary, 30% isolation)
class SessionStructureService {
    static let shared = SessionStructureService()

    private init() {}

    // MARK: - Session Structures

    /// Role distribution by fitness goal
    /// Each entry: (role, percentage of workout, rep range)
    ///
    /// Key principles:
    /// - Strength: Heavy compounds dominate (50% primary, 30% secondary, 20% isolation)
    /// - Hypertrophy: Balanced approach (35% primary, 30% secondary, 35% isolation)
    /// - Endurance: Heavy strength MAINTENANCE + metabolic conditioning (35% primary heavy, 15% secondary, 50% isolation high-rep)
    /// - Balanced: Strength + hypertrophy blend (35% primary, 30% secondary, 35% isolation)
    private let structures: [FitnessGoal: [(role: ExerciseRole, percentage: Double, repRange: String)]] = [
        .strength: [
            (.primaryCompound, 0.50, "4-6"),
            (.secondaryCompound, 0.30, "6-8"),
            (.isolation, 0.20, "8-12")
        ],
        .hypertrophy: [
            (.primaryCompound, 0.35, "6-8"),
            (.secondaryCompound, 0.30, "8-10"),
            (.isolation, 0.35, "10-15")
        ],
        // Endurance: Heavy strength maintenance + metabolic conditioning
        // Endurance athletes NEED heavy compounds for injury prevention, power maintenance,
        // fatigue resistance, and movement quality. Pure high-rep is scientifically wrong.
        .endurance: [
            (.primaryCompound, 0.35, "5-8"),    // Heavy strength maintenance
            (.secondaryCompound, 0.15, "6-10"), // Moderate strength
            (.isolation, 0.50, "15-25")         // Metabolic conditioning
        ],
        // Balanced: True balanced weights compounds for strength but maintains isolation for hypertrophy
        // 65% compounds maintains strength stimulus, 35% isolation maintains hypertrophy stimulus
        .balanced: [
            (.primaryCompound, 0.35, "5-8"),    // Strength emphasis
            (.secondaryCompound, 0.30, "8-10"), // Both goals
            (.isolation, 0.35, "10-12")         // Hypertrophy emphasis
        ]
    ]

    // MARK: - Public Methods

    /// Generate exercise slots with roles and rep ranges for a workout.
    ///
    /// This function converts percentage-based distributions into concrete slots.
    /// For example, with hypertrophy and 6 exercises:
    /// - 35% primary (2.1 → 2 exercises) with 6-8 reps
    /// - 30% secondary (1.8 → 2 exercises) with 8-10 reps
    /// - 35% isolation (2.1 → 2 exercises) with 10-15 reps
    ///
    /// - Parameters:
    ///   - goal: Fitness goal
    ///   - totalExercises: Total number of exercises in the workout
    /// - Returns: Array of ExerciseSlot with role and repRange
    func getExerciseSlots(goal: FitnessGoal, totalExercises: Int) -> [ExerciseSlot] {
        let distribution = structures[goal] ?? structures[.balanced]!
        var slots: [ExerciseSlot] = []

        // First pass: allocate based on percentages
        for (role, percentage, repRange) in distribution {
            let count = max(1, Int(round(Double(totalExercises) * percentage)))
            for _ in 0..<count where slots.count < totalExercises {
                slots.append(ExerciseSlot(role: role, repRange: repRange))
            }
        }

        // Fill remaining slots with isolation (safest fallback)
        let lastRepRange = distribution.last?.repRange ?? "10-12"
        while slots.count < totalExercises {
            slots.append(ExerciseSlot(role: .isolation, repRange: lastRepRange))
        }

        // Truncate if we went over (due to rounding)
        return Array(slots.prefix(totalExercises))
    }

    /// Get the count of each role for a workout.
    /// Useful for logging and validation.
    ///
    /// - Parameters:
    ///   - goal: Fitness goal
    ///   - totalExercises: Total number of exercises
    /// - Returns: Dictionary mapping role to count
    func getRoleCounts(goal: FitnessGoal, totalExercises: Int) -> [ExerciseRole: Int] {
        let slots = getExerciseSlots(goal: goal, totalExercises: totalExercises)
        var counts: [ExerciseRole: Int] = [
            .primaryCompound: 0,
            .secondaryCompound: 0,
            .isolation: 0
        ]
        for slot in slots {
            counts[slot.role, default: 0] += 1
        }
        return counts
    }

    /// Parse a rep range string into (min, max) tuple.
    ///
    /// - Parameter repRange: String like "6-8" or "10-15"
    /// - Returns: Tuple of (minReps, maxReps)
    func parseRepRange(_ repRange: String) -> (min: Int, max: Int) {
        let parts = repRange.split(separator: "-").map { String($0) }
        if parts.count == 2,
           let min = Int(parts[0]),
           let max = Int(parts[1]) {
            return (min, max)
        } else if let single = Int(repRange) {
            return (single, single)
        }
        return (8, 12) // Default fallback
    }

    /// Get a target rep count from a rep range.
    /// Uses the midpoint of the range.
    ///
    /// - Parameter repRange: String like "6-8" or "10-15"
    /// - Returns: Target rep count (midpoint of range)
    func getTargetReps(from repRange: String) -> Int {
        let (min, max) = parseRepRange(repRange)
        return (min + max) / 2
    }

    /// Get the structure description for a goal.
    ///
    /// - Parameter goal: Fitness goal
    /// - Returns: Description string
    func getDescription(for goal: FitnessGoal) -> String {
        switch goal {
        case .strength:
            return "Heavy compounds dominate for maximal strength development"
        case .hypertrophy:
            return "Balanced compounds + isolation for muscle growth"
        case .endurance:
            return "Heavy strength maintenance + metabolic conditioning for endurance athletes"
        case .balanced:
            return "Strength + hypertrophy blend for general fitness"
        default:
            return "General fitness training"
        }
    }

    /// Get the default rep range for a given goal and exercise role.
    /// Used as a fallback when role-based selection is not available.
    ///
    /// - Parameters:
    ///   - goal: Fitness goal
    ///   - role: Exercise role
    /// - Returns: Rep range string (e.g., "6-8")
    func getDefaultRepRange(for goal: FitnessGoal, role: ExerciseRole) -> String {
        let distribution = structures[goal] ?? structures[.balanced]!

        // Find the matching role in the distribution
        for (structRole, _, repRange) in distribution {
            if structRole == role {
                return repRange
            }
        }

        // Fallback if role not found (shouldn't happen)
        return "8-12"
    }
}

// MARK: - Rep Range Descriptions

extension SessionStructureService {
    /// Human-readable descriptions for rep ranges
    static let repRangeDescriptions: [String: String] = [
        "4-6": "Strength (4-6 reps)",
        "5-8": "Strength-Hypertrophy (5-8 reps)",
        "6-8": "Hypertrophy (6-8 reps)",
        "8-10": "Hypertrophy (8-10 reps)",
        "8-12": "Hypertrophy-Endurance (8-12 reps)",
        "10-12": "Hypertrophy (10-12 reps)",
        "10-15": "Metabolic (10-15 reps)",
        "12-15": "Endurance (12-15 reps)",
        "15-20": "High Endurance (15-20 reps)",
        "15-25": "Muscular Endurance (15-25 reps)"
    ]

    func getRepRangeDescription(_ repRange: String) -> String {
        return SessionStructureService.repRangeDescriptions[repRange] ?? repRange
    }
}
