//
//  FitnessGoalMigrationService.swift
//  Pods
//
//  Handles one-time migration of legacy fitness goals in UserDefaults
//

import Foundation

class FitnessGoalMigrationService {
    static func migrateUserDefaults() {
        let defaults = UserDefaults.standard
        // Migrate UI key
        if let stored = defaults.string(forKey: "fitnessGoalType") {
            let migrated = mapLegacyGoal(stored)
            if migrated != stored {
                defaults.set(migrated, forKey: "fitnessGoalType")
                defaults.set(stored, forKey: "legacy_fitness_goal")
            }
        }
        // Migrate server compatibility key
        if let stored = defaults.string(forKey: "fitness_goal") {
            let migrated = mapLegacyGoal(stored)
            if migrated != stored {
                defaults.set(migrated, forKey: "fitness_goal")
                defaults.set(stored, forKey: "legacy_fitness_goal")
            }
        }
    }

    private static func mapLegacyGoal(_ goal: String) -> String {
        switch goal {
        case "tone", "endurance": return "circuit_training"
        case "sport": return "general"
        case "power": return "strength"
        default: return goal
        }
    }
}

