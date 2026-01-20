//
//  RoleBasedEquipmentScoring.swift
//  pods
//
//  Created by Dimi Nunez on 1/19/26.
//


//
//  RoleBasedEquipmentScoring.swift
//  Pods
//
//  Created by Claude Code on 1/19/26.
//

import Foundation

/// Role-Based Equipment Scoring Service
///
/// Provides equipment scoring matrices that vary by fitness goal AND exercise role.
/// This enables intelligent exercise selection where:
/// - Primary compounds favor barbells for heavy loading (mechanical tension)
/// - Isolation exercises favor cables/dumbbells for metabolic stress
/// - Endurance training maintains heavy barbell compounds for strength preservation
///
/// Key insight: Equipment preferences are not static by goal - they depend on
/// what ROLE the exercise plays in the workout structure.
class RoleBasedEquipmentScoring {
    static let shared = RoleBasedEquipmentScoring()

    private init() {}

    // MARK: - Equipment Score Matrices

    /// Equipment scores by (goal, role) combinations.
    ///
    /// Structure: [FitnessGoal: [ExerciseRole: [Equipment: Score]]]
    ///
    /// Scoring rationale:
    /// - Strength: Barbells dominate for maximal loading across all roles
    /// - Hypertrophy: Compounds favor barbells, isolation favors dumbbells/cables
    /// - Endurance: Heavy compounds (barbells) + metabolic isolation (kettlebells/bodyweight)
    /// - Balanced: Blend of strength + hypertrophy patterns
    private let scores: [FitnessGoal: [ExerciseRole: [String: Int]]] = [
        // STRENGTH: Heavy loading priority across all exercises
        // Barbells allow maximal weight, critical for strength development
        .strength: [
            .primaryCompound: [
                "Barbell": 5,
                "Dumbbell": 3,
                "Leverage machine": 2,
                "Machine": 1,
                "Cable": 0,
                "Body weight": -2
            ],
            .secondaryCompound: [
                "Barbell": 4,
                "Dumbbell": 3,
                "Leverage machine": 2,
                "Machine": 2,
                "Cable": 1,
                "Body weight": 0
            ],
            .isolation: [
                "Dumbbell": 3,
                "Cable": 2,
                "Machine": 2,
                "Leverage machine": 2,
                "Barbell": 1,
                "Body weight": 1
            ]
        ],

        // HYPERTROPHY: Balanced mechanical tension + metabolic stress
        // Compounds: Barbells for tension; Isolation: Cables/dumbbells for constant tension
        .hypertrophy: [
            .primaryCompound: [
                "Barbell": 5,
                "Dumbbell": 4,
                "Leverage machine": 2,
                "Machine": 2,
                "Cable": 1,
                "Body weight": 0
            ],
            .secondaryCompound: [
                "Barbell": 4,
                "Dumbbell": 4,
                "Leverage machine": 3,
                "Machine": 3,
                "Cable": 2,
                "Body weight": 1
            ],
            .isolation: [
                "Dumbbell": 5,
                "Cable": 4,
                "Machine": 3,
                "Leverage machine": 3,
                "Body weight": 2,
                "Barbell": -2  // Barbells inefficient for isolation (awkward movement paths)
            ]
        ],

        // ENDURANCE: Heavy strength maintenance + metabolic conditioning
        //
        // CRITICAL: Endurance athletes NEED heavy compounds for:
        // - Injury prevention (structural integrity)
        // - Power maintenance (neuromuscular efficiency)
        // - Fatigue resistance (economy of movement)
        // - Movement quality under fatigue
        //
        // Primary/Secondary: Barbells favored for heavy loading
        // Isolation: Kettlebells, bodyweight, bands for metabolic work
        .endurance: [
            .primaryCompound: [
                "Barbell": 5,      // Heavy strength maintenance
                "Dumbbell": 4,
                "Leverage machine": 3,
                "Machine": 2,
                "Kettlebell": 2,
                "Body weight": 1,
                "Cable": 0
            ],
            .secondaryCompound: [
                "Barbell": 4,      // Moderate strength
                "Dumbbell": 4,
                "Kettlebell": 4,   // Good for power maintenance
                "Leverage machine": 3,
                "Body weight": 3,
                "Machine": 2,
                "Cable": 2
            ],
            .isolation: [
                "Kettlebell": 5,   // Metabolic conditioning
                "Body weight": 5,  // High-rep endurance work
                "Band": 4,         // Constant tension, metabolic stress
                "Dumbbell": 4,
                "Cable": 3,
                "Machine": 2,
                "Leverage machine": 2,
                "Barbell": 0       // Not efficient for high-rep metabolic work
            ]
        ],

        // BALANCED: Strength + Hypertrophy blend
        // 65% compounds maintains strength, 35% isolation maintains hypertrophy
        .balanced: [
            .primaryCompound: [
                "Barbell": 5,
                "Dumbbell": 4,
                "Leverage machine": 2,
                "Machine": 2,
                "Cable": 1,
                "Body weight": 0
            ],
            .secondaryCompound: [
                "Barbell": 4,
                "Dumbbell": 4,
                "Leverage machine": 3,
                "Machine": 3,
                "Cable": 2,
                "Body weight": 1
            ],
            .isolation: [
                "Dumbbell": 4,
                "Cable": 3,
                "Machine": 2,
                "Leverage machine": 2,
                "Body weight": 1,
                "Barbell": 0
            ]
        ]
    ]

    // MARK: - Public Methods

    /// Get equipment score for a specific goal, role, and equipment combination.
    ///
    /// - Parameters:
    ///   - goal: Fitness goal
    ///   - role: Exercise role (primary compound, secondary compound, isolation)
    ///   - equipment: Equipment string from exercise data
    /// - Returns: Score (higher = better match for this goal/role combination)
    func getScore(goal: FitnessGoal, role: ExerciseRole, equipment: String) -> Int {
        // Normalize equipment name (handle "Barbell/Flat Bench" → "Barbell")
        let equipmentNormalized = equipment
            .components(separatedBy: "/")
            .first?
            .trimmingCharacters(in: .whitespaces) ?? equipment

        // Look up score in matrix
        guard let goalScores = scores[goal],
              let roleScores = goalScores[role] else {
            return 0 // Default if goal/role not found
        }

        return roleScores[equipmentNormalized] ?? 0
    }

    /// Get all equipment scores for a goal/role combination.
    /// Useful for debugging and logging.
    ///
    /// - Parameters:
    ///   - goal: Fitness goal
    ///   - role: Exercise role
    /// - Returns: Dictionary of equipment to scores
    func getAllScores(goal: FitnessGoal, role: ExerciseRole) -> [String: Int] {
        return scores[goal]?[role] ?? [:]
    }

    /// Get the best equipment types for a goal/role combination.
    ///
    /// - Parameters:
    ///   - goal: Fitness goal
    ///   - role: Exercise role
    ///   - count: Number of top equipment types to return
    /// - Returns: Array of equipment names sorted by score (highest first)
    func getTopEquipment(goal: FitnessGoal, role: ExerciseRole, count: Int = 3) -> [String] {
        guard let roleScores = scores[goal]?[role] else { return [] }

        return roleScores
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map { $0.key }
    }
}

// MARK: - Equipment Tier (General Quality)

extension RoleBasedEquipmentScoring {
    /// Equipment tier scoring (general quality, independent of goal/role).
    /// Used as a secondary factor when role-based scores are equal.
    ///
    /// Tier 1 (highest): Gym staples with best force curves
    /// Tier 2: Good equipment, versatile
    /// Tier 3: Specialized or limited equipment
    static let equipmentTiers: [String: Int] = [
        // Tier 1: Premium gym equipment
        "Barbell": 10,
        "Dumbbell": 9,
        "Cable": 8,

        // Tier 2: Good equipment
        "Leverage machine": 7,
        "Machine": 6,
        "Kettlebell": 6,
        "Body weight": 5,

        // Tier 3: Specialized
        "Band": 4,
        "Smith machine": 4,
        "EZ bar": 5,
        "Trap bar": 6,

        // Tier 4: Basic/Home gym
        "Suspension": 3,
        "Medicine ball": 3,
        "Stability ball": 2,
    ]

    /// Get general equipment tier score.
    ///
    /// - Parameter equipment: Equipment string
    /// - Returns: Tier score (higher = better general quality)
    func getEquipmentTier(_ equipment: String) -> Int {
        let normalized = equipment
            .components(separatedBy: "/")
            .first?
            .trimmingCharacters(in: .whitespaces) ?? equipment

        return RoleBasedEquipmentScoring.equipmentTiers[normalized] ?? 5
    }
}
