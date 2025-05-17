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
    var targetDate: String
    var adjacentDaysIncluded: Bool
    var goals: NutritionGoals?
    var userData: UserData?
    
    enum CodingKeys: String, CodingKey {
        case logs
        case targetDate = "target_date"
        case adjacentDaysIncluded = "adjacent_days_included"
        case goals
        case userData = "user_data"
    }
}

// MARK: - Height and Weight Log Responses

/// Response from logging a height measurement
struct HeightLogResponse: Codable {
    let id: Int
    let heightCm: Double
    let dateLogged: String
    let notes: String
}

/// Response from logging a weight measurement
struct WeightLogResponse: Codable {
    let id: Int
    let weightKg: Double
    let dateLogged: String
    let notes: String
}

/// Response containing a user's height log history
struct HeightLogsResponse: Codable {
    let logs: [HeightLogResponse]
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case logs
        case totalCount = "total_count"
    }
}

/// Response containing a user's weight log history
struct WeightLogsResponse: Codable {
    let logs: [WeightLogResponse]
    let totalCount: Int
    
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

