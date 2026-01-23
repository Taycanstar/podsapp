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
    case fullBody = "full_body"
    case ppl = "ppl"
    case upperLower = "upper_lower"

    var displayName: String {
        switch self {
        case .fullBody: return "Full Body"
        case .ppl: return "Push/Pull/Legs"
        case .upperLower: return "Upper/Lower"
        }
    }

    var shortName: String {
        switch self {
        case .fullBody: return "FB"
        case .ppl: return "PPL"
        case .upperLower: return "UL"
        }
    }

    /// Default days per week for this program type
    var daysPerWeek: Int {
        switch self {
        case .fullBody: return 3
        case .ppl: return 3  // Default to 3 (one push, one pull, one legs)
        case .upperLower: return 4
        }
    }

    /// Minimum days per week allowed for this program type
    var minDaysPerWeek: Int {
        switch self {
        case .fullBody: return 2
        case .ppl: return 3  // PPL needs at least Push, Pull, Legs
        case .upperLower: return 2
        }
    }

    /// Maximum days per week allowed for this program type
    var maxDaysPerWeek: Int {
        switch self {
        case .fullBody: return 7
        case .ppl: return 7
        case .upperLower: return 7
        }
    }

    /// Range of valid days per week for this program type
    var daysPerWeekRange: ClosedRange<Int> {
        minDaysPerWeek...maxDaysPerWeek
    }

    var description: String {
        switch self {
        case .fullBody: return "3 days/week • Great for beginners"
        case .ppl: return "3-6 days/week • Push, Pull, Legs split"
        case .upperLower: return "4 days/week • Balanced approach"
        }
    }
}

// MARK: - Fitness Goal

enum ProgramFitnessGoal: String, Codable, CaseIterable {
    case hypertrophy = "hypertrophy"
    case strength = "strength"
    case balanced = "balanced"
    case endurance = "endurance"

    var displayName: String {
        switch self {
        case .hypertrophy: return "Hypertrophy"
        case .strength: return "Strength"
        case .balanced: return "Both"
        case .endurance: return "Endurance"
        }
    }

    var subtitle: String {
        switch self {
        case .hypertrophy: return "Hypertrophy"
        case .strength: return "Strength"
        case .balanced: return "Balanced"
        case .endurance: return "Endurance"
        }
    }

    var description: String {
        switch self {
        case .hypertrophy: return "Maximize muscle growth with moderate weights and higher volume"
        case .strength: return "Build maximal strength with heavier weights and lower reps"
        case .balanced: return "Equal focus on strength and muscle size"
        case .endurance: return "Build work capacity and stamina with higher reps and shorter rest"
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
    // MacroFactor-style cycle position for "next incomplete" lookup
    // Workout days have position 1, 2, 3, etc. Rest days are nil.
    let cyclePosition: Int?

    var dateValue: Date? {
        parseProgramDate(date)
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
    let periodizationEnabled: Bool?
    let defaultWarmupEnabled: Bool?
    let defaultCooldownEnabled: Bool?
    let includeFoamRolling: Bool?
    let includeCardio: Bool?
    let isActive: Bool
    let createdAt: String
    let syncVersion: Int
    let weeks: [ProgramWeek]?

    var startDateValue: Date? {
        parseProgramDate(startDate)
    }

    var endDateValue: Date? {
        parseProgramDate(endDate)
    }

    var totalCalendarWeeks: Int {
        if let weeks = weeks, !weeks.isEmpty {
            return weeks.count
        }
        if let start = startDateValue, let end = endDateValue {
            let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
            return max(1, (days / 7) + 1)
        }
        return totalWeeks + (includeDeload ? 1 : 0)
    }

    var currentWeekNumber: Int? {
        guard let start = startDateValue else { return nil }
        let today = Date()
        let daysSinceStart = Calendar.current.dateComponents([.day], from: start, to: today).day ?? 0
        if daysSinceStart < 0 { return nil }
        return (daysSinceStart / 7) + 1
    }

    /// Active week number based on completion status (sequence-based, Mode B).
    /// Returns the first week that has incomplete days, or the last week if all complete.
    /// Used by PlanView to auto-advance week display when all days in a week are done.
    var activeWeekNumber: Int {
        guard let programWeeks = weeks, !programWeeks.isEmpty else { return 1 }

        // Sort weeks by week_number
        let sortedWeeks = programWeeks.sorted { $0.weekNumber < $1.weekNumber }

        // Find first week with at least one incomplete day
        for week in sortedWeeks {
            guard let days = week.days else { continue }
            let hasIncomplete = days.contains { !$0.isCompleted }
            if hasIncomplete {
                return week.weekNumber
            }
        }

        // All weeks complete - show the last week
        return sortedWeeks.last?.weekNumber ?? 1
    }

    /// Today's weekday in backend format (1=Monday, 7=Sunday)
    /// Swift's Calendar returns 1=Sunday, 2=Monday, ..., 7=Saturday
    /// Backend uses 1=Monday, 2=Tuesday, ..., 7=Sunday
    static var todayWeekdayNumber: Int {
        let swiftWeekday = Calendar.current.component(.weekday, from: Date())
        // Conversion: (swiftWeekday + 5) % 7 + 1
        // Sun(1) -> 7, Mon(2) -> 1, Tue(3) -> 2, etc.
        return (swiftWeekday + 5) % 7 + 1
    }

    var programTypeEnum: ProgramType? {
        ProgramType(rawValue: programType)
    }

    var fitnessGoalEnum: ProgramFitnessGoal? {
        ProgramFitnessGoal(rawValue: fitnessGoal)
    }

    var experienceLevelEnum: ProgramExperienceLevel? {
        ProgramExperienceLevel(rawValue: experienceLevel)
    }
}

private func parseProgramDate(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    if let date = formatter.date(from: value) {
        return date
    }

    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoFormatter.date(from: value) {
        return Calendar.current.startOfDay(for: date)
    }

    isoFormatter.formatOptions = [.withInternetDateTime]
    if let date = isoFormatter.date(from: value) {
        return Calendar.current.startOfDay(for: date)
    }

    return nil
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

struct DeactivateProgramResponse: Codable {
    let success: Bool
    let deactivatedProgram: TrainingProgram
    let newActiveProgram: TrainingProgram?
}

struct ProgramDayResponse: Codable {
    let success: Bool?
    let day: ProgramDay?
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
    let defaultWarmupEnabled: Bool
    let defaultCooldownEnabled: Bool
    let includeCardio: Bool
}
