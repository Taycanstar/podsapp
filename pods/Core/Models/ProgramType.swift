//
//  ProgramType.swift
//  pods
//
//  Created by Dimi Nunez on 1/13/26.
//


//
//  ProgramModels.swift
//  pods
//
//  Models for MacroFactor-style multi-week training programs.
//
//  NOTE: These models use automatic snake_case conversion via
//  decoder.keyDecodingStrategy = .convertFromSnakeCase
//  Do NOT add CodingKeys with explicit snake_case mappings!
//

import Foundation

// MARK: - Program Type

enum ProgramType: String, Codable, CaseIterable {
    case ppl = "ppl"
    case upperLower = "upper_lower"
    case fullBody = "full_body"
    case upperLower5 = "upper_lower_5"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .ppl: return "Push/Pull/Legs"
        case .upperLower: return "Upper/Lower"
        case .fullBody: return "Full Body"
        case .upperLower5: return "Upper/Lower (5 day)"
        case .custom: return "Custom"
        }
    }

    var daysPerWeek: Int {
        switch self {
        case .ppl: return 6
        case .upperLower: return 4
        case .fullBody: return 3
        case .upperLower5: return 5
        case .custom: return 4
        }
    }
}

// MARK: - Fitness Goal

enum ProgramFitnessGoal: String, Codable, CaseIterable {
    case strength = "strength"
    case hypertrophy = "hypertrophy"
    case balanced = "balanced"

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .balanced: return "Balanced"
        }
    }

    var description: String {
        switch self {
        case .strength: return "Build maximal strength with heavy weights and low reps"
        case .hypertrophy: return "Maximize muscle growth with moderate weights and volume"
        case .balanced: return "Balance strength and size gains"
        }
    }
}

// MARK: - Experience Level

enum ProgramExperienceLevel: String, Codable, CaseIterable {
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

// MARK: - Day Type

enum ProgramDayType: String, Codable {
    case workout = "workout"
    case rest = "rest"
}

// MARK: - Program Exercise (Summary)

struct ProgramExercise: Codable, Identifiable {
    let id: Int
    let exerciseId: Int
    let exerciseName: String
    let order: Int
    let targetSets: Int?
    let targetReps: Int?
    let isCompleted: Bool
}

// MARK: - Workout Session (Embedded)

struct ProgramWorkoutSession: Codable, Identifiable {
    let id: Int
    let title: String
    let status: String
    let scheduledDate: String
    let estimatedDurationMinutes: Int
    let actualDurationMinutes: Int?
    let completedExerciseCount: Int?
    let exercises: [ProgramExercise]?
}

// MARK: - Program Day

struct ProgramDay: Codable, Identifiable {
    let id: Int
    let dayNumber: Int
    let dayType: ProgramDayType
    let workoutLabel: String
    let targetMuscles: [String]
    let date: String
    let isCompleted: Bool
    let completedAt: String?
    let workoutSessionId: Int?
    let workout: ProgramWorkoutSession?

    var dateValue: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: date)
    }

    var isToday: Bool {
        guard let dayDate = dateValue else { return false }
        return Calendar.current.isDateInToday(dayDate)
    }

    var weekdayShort: String {
        guard let dayDate = dateValue else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: dayDate)
    }

    var dayOfMonth: String {
        guard let dayDate = dateValue else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: dayDate)
    }
}

// MARK: - Program Week

struct ProgramWeek: Codable, Identifiable {
    let id: Int
    let weekNumber: Int
    let isDeload: Bool
    let volumeModifier: Double
    let days: [ProgramDay]?
}

// MARK: - Training Program

struct TrainingProgram: Codable, Identifiable {
    let id: Int
    let name: String
    let programType: String
    let fitnessGoal: String
    let experienceLevel: String
    let daysPerWeek: Int
    let sessionDurationMinutes: Int
    let startDate: String
    let endDate: String
    let totalWeeks: Int
    let includeDeload: Bool
    let isActive: Bool
    let createdAt: String
    let syncVersion: Int
    let weeks: [ProgramWeek]?

    var startDateValue: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: startDate)
    }

    var endDateValue: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: endDate)
    }

    var currentWeekNumber: Int? {
        guard let start = startDateValue else { return nil }
        let today = Date()
        let daysSinceStart = Calendar.current.dateComponents([.day], from: start, to: today).day ?? 0
        if daysSinceStart < 0 { return nil }
        return (daysSinceStart / 7) + 1
    }

    var programTypeEnum: ProgramType? {
        ProgramType(rawValue: programType)
    }

    var fitnessGoalEnum: ProgramFitnessGoal? {
        ProgramFitnessGoal(rawValue: fitnessGoal)
    }
}

// MARK: - API Response Models

struct ProgramTypesResponse: Codable {
    let programTypes: [ProgramTypeInfo]
}

struct ProgramTypeInfo: Codable, Identifiable {
    let type: String
    let name: String
    let shortName: String
    let daysPerWeek: Int
    let description: String

    var id: String { type }
}

struct ProgramRecommendation: Codable {
    let programType: String
    let programName: String
    let description: String
    let recommendedDaysPerWeek: Int
    let fitnessGoal: String
    let experienceLevel: String
    let totalWeeks: Int
    let includeDeload: Bool
}

struct ProgramRecommendationResponse: Codable {
    let recommendation: ProgramRecommendation
}

struct ProgramResponse: Codable {
    let program: TrainingProgram?
}

struct ProgramsListResponse: Codable {
    let programs: [TrainingProgram]
}

struct TodayWorkoutResponse: Codable {
    let hasProgram: Bool
    let today: ProgramDay?
    let weekNumber: Int?
    let dayNumber: Int?
    let message: String?
    let programStartDate: String?
    let programEndDate: String?
}

struct MarkDayCompleteResponse: Codable {
    let success: Bool
    let day: ProgramDay
}

// MARK: - Program Generation Request

struct GenerateProgramRequest: Codable {
    let programType: String
    let fitnessGoal: String
    let experienceLevel: String
    let daysPerWeek: Int
    let sessionDurationMinutes: Int
    let startDate: String?
    let totalWeeks: Int
    let includeDeload: Bool
    let availableEquipment: [String]?
    let excludedExercises: [Int]?
}
