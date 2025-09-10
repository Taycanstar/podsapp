// FILE: Models/UserProfile.swift
import Foundation
import SwiftData

@Model
class UserProfile {
    var id: UUID
    var email: String
    var fitnessGoal: FitnessGoal
    var experienceLevel: ExperienceLevel
    var gender: Gender
    var createdAt: Date
    var updatedAt: Date
    
    init(email: String, fitnessGoal: FitnessGoal = .strength, experienceLevel: ExperienceLevel = .beginner, gender: Gender = .male) {
        self.id = UUID()
        self.email = email
        self.fitnessGoal = fitnessGoal
        self.experienceLevel = experienceLevel
        self.gender = gender
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum Gender: String, CaseIterable, Codable {
    case male = "Male"
    case female = "Female"
    case other = "Other"
    
    var displayName: String {
        return self.rawValue
    }
}

enum FitnessGoal: String, CaseIterable, Codable {
    // New canonical goals
    case strength = "strength"
    case hypertrophy = "hypertrophy"
    case circuitTraining = "circuit_training"
    case general = "general"
    case powerlifting = "powerlifting"
    case olympicWeightlifting = "olympic_weightlifting"

    // Legacy (deprecated) goals kept for backward compatibility
    case tone = "tone"            // maps to circuitTraining
    case endurance = "endurance"  // maps to circuitTraining
    case power = "power"          // maps to strength
    case sport = "sport"          // maps to general

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .circuitTraining: return "Circuit Training"
        case .general: return "General Fitness"
        case .powerlifting: return "Powerlifting"
        case .olympicWeightlifting: return "Olympic Weightlifting"
        case .tone: return "Tone" // legacy
        case .endurance: return "Endurance" // legacy
        case .power: return "Power" // legacy
        case .sport: return "Sports Performance" // legacy
        }
    }

    // Normalized target for app logic
    var normalized: FitnessGoal {
        switch self {
        case .tone, .endurance: return .circuitTraining
        case .sport: return .general
        case .power: return .strength
        default: return self
        }
    }

    // Convert from string value (accept both new and legacy)
    static func from(string: String) -> FitnessGoal {
        let key = string.lowercased()
        switch key {
        case "strength": return .strength
        case "hypertrophy": return .hypertrophy
        case "general": return .general
        case "powerlifting": return .powerlifting
        case "circuit_training": return .circuitTraining
        case "olympic_weightlifting": return .olympicWeightlifting
        // Legacy
        case "tone": return .tone
        case "endurance": return .endurance
        case "power": return .power
        case "sport", "sportsperformance": return .sport
        default: return .strength // safe fallback
        }
    }
}

enum ExperienceLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
    
    var description: String {
        switch self {
        case .beginner:
            return "New to fitness (0-12 months)"
        case .intermediate:
            return "Some experience (1-3 years)"
        case .advanced:
            return "Experienced (3+ years)"
        }
    }
    
    var workoutComplexity: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        }
    }
} 
