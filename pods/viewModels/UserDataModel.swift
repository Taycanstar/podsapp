//
//  UserDataModel.swift
//  Pods
//
//  Created by Dimi Nunez on 5/17/25.
//

import Foundation
import Combine

struct UserData: Codable {
    let height_cm: Double
    let weight_kg: Double
    let height_feet: Int?
    let height_inches: Int?
    let weight_lbs: Double?
    
    enum CodingKeys: String, CodingKey {
        case height_cm, weight_kg, height_feet, height_inches, weight_lbs
    }
}

struct LogsByDateResponse: Codable {
    var logs: [CombinedLog]
    var waterLogs: [WaterLogResponse] = []
    var targetDate: String
    var adjacentDaysIncluded: Bool
    var goals: NutritionGoals?
    var userData: UserData?
    var scheduledLogs: [ScheduledLogPreview] = []
    
    enum CodingKeys: String, CodingKey {
        case logs
        case waterLogs = "water_logs"
        case targetDate = "target_date"
        case adjacentDaysIncluded = "adjacent_days_included"
        case goals
        case userData = "user_data"
        case scheduledLogs = "scheduled_logs"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logs = try container.decodeIfPresent([CombinedLog].self, forKey: .logs) ?? []
        // Some responses omit water_logs/scheduled_logs when empty; default to [] instead of failing
        waterLogs = try container.decodeIfPresent([WaterLogResponse].self, forKey: .waterLogs) ?? []
        targetDate = try container.decodeIfPresent(String.self, forKey: .targetDate) ?? ""
        adjacentDaysIncluded = try container.decodeIfPresent(Bool.self, forKey: .adjacentDaysIncluded) ?? false
        goals = try container.decodeIfPresent(NutritionGoals.self, forKey: .goals)
        userData = try container.decodeIfPresent(UserData.self, forKey: .userData)
        scheduledLogs = try container.decodeIfPresent([ScheduledLogPreview].self, forKey: .scheduledLogs) ?? []
    }

    init(logs: [CombinedLog],
         waterLogs: [WaterLogResponse] = [],
         targetDate: String,
         adjacentDaysIncluded: Bool,
         goals: NutritionGoals? = nil,
         userData: UserData? = nil,
         scheduledLogs: [ScheduledLogPreview] = []) {
        self.logs = logs
        self.waterLogs = waterLogs
        self.targetDate = targetDate
        self.adjacentDaysIncluded = adjacentDaysIncluded
        self.goals = goals
        self.userData = userData
        self.scheduledLogs = scheduledLogs
    }
}

struct ScheduledLogSummary: Codable {
    let title: String
    let calories: Double?
    let servings: Double?
    let mealType: String?
    let image: String?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let aiInsight: String?
    let nutritionScore: Double?

    enum CodingKeys: String, CodingKey {
        case title
        case calories
        case servings
        case mealType = "meal_type"
        case image
        case protein
        case carbs
        case fat
        case aiInsight = "ai_insight"
        case nutritionScore = "nutrition_score"
    }
}

struct ScheduledLogPreview: Codable, Identifiable {
    let id: Int
    let scheduleType: String
    let targetDate: Date
    let targetTime: String?
    let mealType: String?
    let sourceType: String
    let logId: Int
    let summary: ScheduledLogSummary

    enum CodingKeys: String, CodingKey {
        case id
        case scheduleType = "schedule_type"
        case targetDate = "target_date"
        case targetTime = "target_time"
        case mealType = "meal_type"
        case sourceType = "source_type"
        case logId = "log_id"
        case summary
    }

    var displayMealType: String {
        mealType ?? summary.mealType ?? "Meal"
    }

    var displayTime: String? {
        guard let targetTime else { return nil }
        var components = targetTime.split(separator: ":").map { String($0) }
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else { return nil }

        var calendar = Calendar.current
        calendar.locale = Locale.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = hour
        dateComponents.minute = minute

        if let date = calendar.date(from: dateComponents) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return nil
    }

    /// Returns the scheduled date normalized to the user's current time zone (start of day).
    var normalizedTargetDate: Date {
        let utcTimeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(abbreviation: "UTC")!
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = utcTimeZone
        let components = utcCalendar.dateComponents([.year, .month, .day], from: targetDate)

        var localCalendar = Calendar.current
        localCalendar.timeZone = TimeZone.current
        return localCalendar.date(from: components) ?? localCalendar.startOfDay(for: targetDate)
    }
}

// MARK: - Height and Weight Log Responses

/// Response from logging a height measurement
struct HeightLogResponse: Codable, Identifiable {
    let id: Int
    let heightCm: Double
    let dateLogged: String
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case heightCm = "height_cm"
        case dateLogged = "date_logged"
        case notes
    }
}

/// Response from logging a weight measurement
struct WeightLogResponse: Codable, Identifiable {
    let id: Int
    let weightKg: Double
    let dateLogged: String
    let notes: String?
    let photo: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case weightKg = "weight_kg"
        case dateLogged = "date_logged"
        case notes
        case photo
    }
}

/// Response from logging a water intake measurement
struct WaterLogResponse: Codable {
    let id: Int
    let waterOz: Double
    let waterLiters: Double
    let dateLogged: String
    let notes: String
    let waterUnit: String?
    let waterValue: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case waterOz = "water_oz"
        case waterLiters = "water_liters"
        case dateLogged = "date_logged"
        case notes
        case waterUnit = "water_unit"
        case waterValue = "water_value"
    }
}

/// Response containing a user's height log history
struct HeightLogsResponse: Codable {
    var logs: [HeightLogResponse] = []
    var totalCount: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case logs
        case totalCount = "total_count"
    }
}

/// Response containing a user's weight log history
struct WeightLogsResponse: Codable {
    var logs: [WeightLogResponse] = []
    var totalCount: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case logs
        case totalCount = "total_count"
    }
}

// MARK: - Health Data View Models

enum HealthTimeframe: String, CaseIterable {
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .sixMonths: return 182
        case .year: return 365
        }
    }
}

// MARK: - Profile Data Models
// NOTE: ProfileDataResponse, CalorieTrendDay, and MacroDataDay have been moved to WorkoutProfile.swift
// to consolidate all profile-related data structures and avoid duplicate definitions.
