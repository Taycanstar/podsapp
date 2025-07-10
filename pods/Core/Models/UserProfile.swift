// FILE: Models/UserProfile.swift
import Foundation
import SwiftData

@Model
class UserProfile {
    var id: UUID
    var email: String
    var fitnessGoal: FitnessGoal
    var experienceLevel: ExperienceLevel
    var createdAt: Date
    var updatedAt: Date
    
    init(email: String, fitnessGoal: FitnessGoal = .strength, experienceLevel: ExperienceLevel = .beginner) {
        self.id = UUID()
        self.email = email
        self.fitnessGoal = fitnessGoal
        self.experienceLevel = experienceLevel
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum FitnessGoal: String, CaseIterable, Codable {
    case strength = "strength"
    case hypertrophy = "hypertrophy"
    case endurance = "endurance"
    case power = "power"
    case general = "general"
    case tone = "tone"
    case powerlifting = "powerlifting"
    case sport = "sport"
    
    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .hypertrophy: return "Muscle Building"
        case .endurance: return "Endurance"
        case .power: return "Power"
        case .general: return "General Fitness"
        case .tone: return "Muscle Tone"
        case .powerlifting: return "Powerlifting"
        case .sport: return "Sports Performance"
        }
    }
    
    // Convert from string value (for UserDefaults compatibility)
    static func from(string: String) -> FitnessGoal {
        switch string.lowercased() {
        case "strength": return .strength
        case "hypertrophy": return .hypertrophy
        case "endurance": return .endurance
        case "power": return .power
        case "tone": return .tone
        case "powerlifting": return .powerlifting
        case "sport", "sportsperformance": return .sport
        default: return .strength // Default fallback
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
} 