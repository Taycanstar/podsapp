//
//  WorkoutProfile.swift
//  pods
//
//  Created by Dimi Nunez on 7/11/25.
//

//
//  WorkoutProfile.swift
//  Pods
//
//  Created by Dimi Nunez on 7/11/25.
//

import Foundation

// MARK: - Server Response Models
struct ProfileDataResponse: Codable {
    let email: String
    var name: String
    var username: String
    var profilePhoto: String  // URL or "pfp" for asset
    let profileInitial: String
    let profileColor: String
    var heightCm: Double?
    var heightFeet: Int?
    var heightInches: Int?
    var currentWeightKg: Double?
    var currentWeightLbs: Double?
    var weightDate: String?
    var calorieTrend3Weeks: [CalorieTrendDay]
    var macroData3Weeks: [MacroDataDay]?  // Optional macro breakdown data
    var averageDailyCalories: Double
    var averageCaloriesActiveDays: Double
    var daysLogged: Int
    var totalDays: Int
    var calorieGoal: Double
    var proteinGoal: Double
    var carbsGoal: Double
    var fatGoal: Double
    let workoutProfile: WorkoutProfile?
    
    // Streaks data (optional for backward compatibility)
    var currentStreak: Int?
    var longestStreak: Int?
    var streakAsset: String?
    var lastActivityDate: String?
    var streakStartDate: String?
    
    enum CodingKeys: String, CodingKey {
        case email, name, username
        case profilePhoto = "profile_photo"
        case profileInitial = "profile_initial"
        case profileColor = "profile_color"
        case heightCm = "height_cm"
        case heightFeet = "height_feet"
        case heightInches = "height_inches"
        case currentWeightKg = "current_weight_kg"
        case currentWeightLbs = "current_weight_lbs"
        case weightDate = "weight_date"
        case calorieTrend3Weeks = "calorie_trend_3_weeks"
        case macroData3Weeks = "macro_data_3_weeks"
        case averageDailyCalories = "average_daily_calories"
        case averageCaloriesActiveDays = "average_calories_active_days"
        case daysLogged = "days_logged"
        case totalDays = "total_days"
        case calorieGoal = "calorie_goal"
        case proteinGoal = "protein_goal"
        case carbsGoal = "carbs_goal"
        case fatGoal = "fat_goal"
        case workoutProfile = "workout_profile"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case streakAsset = "streak_asset"
        case lastActivityDate = "last_activity_date"
        case streakStartDate = "streak_start_date"
    }
}

// MARK: - Supporting Types (moved from UserDataModel.swift)
struct CalorieTrendDay: Codable {
    let date: String
    let calories: Double
}

struct MacroDataDay: Codable {
    let date: String
    let calories: Double
    let proteinCals: Double
    let carbCals: Double
    let fatCals: Double
    let proteinGrams: Double
    let carbGrams: Double
    let fatGrams: Double
    
    enum CodingKeys: String, CodingKey {
        case date, calories
        case proteinCals = "protein_cals"
        case carbCals = "carb_cals"
        case fatCals = "fat_cals"
        case proteinGrams = "protein_grams"
        case carbGrams = "carb_grams"
        case fatGrams = "fat_grams"
    }
}

// Update documentation for workoutLocation to match Fitbod's options
// large_gym, small_gym, garage_gym, home, bodyweight, custom
struct WorkoutProfile: Codable {
    let fitnessGoal: String
    let fitnessLevel: String
    let workoutFrequency: String
    let sport: String
    let availableEquipment: [String]
    let workoutLocation: String // large_gym, small_gym, garage_gym, home, bodyweight, custom
    let preferredWorkoutDuration: Int
    let workoutDaysPerWeek: Int
    let restDays: [String]
    let currentWeightKg: Double?
    
    enum CodingKeys: String, CodingKey {
        case fitnessGoal = "fitness_goal"
        case fitnessLevel = "fitness_level"
        case workoutFrequency = "workout_frequency"
        case sport
        case availableEquipment = "available_equipment"
        case workoutLocation = "workout_location"
        case preferredWorkoutDuration = "preferred_workout_duration"
        case workoutDaysPerWeek = "workout_days_per_week"
        case restDays = "rest_days"
        case currentWeightKg = "current_weight_kg"
    }
} 