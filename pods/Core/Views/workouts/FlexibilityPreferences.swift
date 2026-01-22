//
//  FlexibilityPreferences.swift
//  Pods
//
//  Created by Claude on 8/24/25.
//

import Foundation

// MARK: - Flexibility Preferences Model
struct FlexibilityPreferences: Codable, Equatable {
    let warmUpEnabled: Bool
    let coolDownEnabled: Bool
    let includeFoamRolling: Bool
    let includeCardio: Bool

    init(warmUpEnabled: Bool = false, coolDownEnabled: Bool = false, includeFoamRolling: Bool = true, includeCardio: Bool = false) {
        self.warmUpEnabled = warmUpEnabled
        self.coolDownEnabled = coolDownEnabled
        self.includeFoamRolling = includeFoamRolling
        self.includeCardio = includeCardio
    }

    // CodingKeys to handle optional fields for backwards compatibility
    enum CodingKeys: String, CodingKey {
        case warmUpEnabled
        case coolDownEnabled
        case includeFoamRolling
        case includeCardio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        warmUpEnabled = try container.decode(Bool.self, forKey: .warmUpEnabled)
        coolDownEnabled = try container.decode(Bool.self, forKey: .coolDownEnabled)
        // Default to true if not present (backwards compatibility)
        includeFoamRolling = try container.decodeIfPresent(Bool.self, forKey: .includeFoamRolling) ?? true
        // Default to false if not present (backwards compatibility)
        includeCardio = try container.decodeIfPresent(Bool.self, forKey: .includeCardio) ?? false
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
    
    // Check if any flexibility option is enabled
    var isEnabled: Bool {
        return warmUpEnabled || coolDownEnabled
    }
}

// MARK: - Exercise Type Enum for Flexibility
enum FlexibilityExerciseType: String, CaseIterable {
    case warmUp = "warmUp"
    case coolDown = "coolDown"
    
    var displayName: String {
        switch self {
        case .warmUp:
            return "Warm-Up"
        case .coolDown:
            return "Cool-Down"
        }
    }
}