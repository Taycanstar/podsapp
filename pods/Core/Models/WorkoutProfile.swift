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
    var weightLogsRecent: [WeightLogResponse]?
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

    var workoutProfiles: [WorkoutProfile]
    var activeWorkoutProfileId: Int?
    var supportsMultipleWorkoutProfiles: Bool
    private var legacyWorkoutProfile: WorkoutProfile?

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
        case weightLogsRecent = "weight_logs_recent"
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
        case workoutProfiles = "workout_profiles"
        case activeWorkoutProfileId = "active_workout_profile_id"
        case supportsMultipleWorkoutProfiles = "supports_multiple_workout_profiles"
        case legacyWorkoutProfile = "workout_profile"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case streakAsset = "streak_asset"
        case lastActivityDate = "last_activity_date"
        case streakStartDate = "streak_start_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        email = try container.decode(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        profilePhoto = try container.decodeIfPresent(String.self, forKey: .profilePhoto) ?? "pfp"
        profileInitial = try container.decodeIfPresent(String.self, forKey: .profileInitial) ?? "P"
        profileColor = try container.decodeIfPresent(String.self, forKey: .profileColor) ?? "#007AFF"

        heightCm = try container.decodeIfPresent(Double.self, forKey: .heightCm)
        heightFeet = try container.decodeIfPresent(Int.self, forKey: .heightFeet)
        heightInches = try container.decodeIfPresent(Int.self, forKey: .heightInches)
        currentWeightKg = try container.decodeIfPresent(Double.self, forKey: .currentWeightKg)
        currentWeightLbs = try container.decodeIfPresent(Double.self, forKey: .currentWeightLbs)
        weightDate = try container.decodeIfPresent(String.self, forKey: .weightDate)
        weightLogsRecent = try container.decodeIfPresent([WeightLogResponse].self, forKey: .weightLogsRecent)

        calorieTrend3Weeks = try container.decodeIfPresent([CalorieTrendDay].self, forKey: .calorieTrend3Weeks) ?? []
        macroData3Weeks = try container.decodeIfPresent([MacroDataDay].self, forKey: .macroData3Weeks)
        averageDailyCalories = try container.decodeIfPresent(Double.self, forKey: .averageDailyCalories) ?? 0
        averageCaloriesActiveDays = try container.decodeIfPresent(Double.self, forKey: .averageCaloriesActiveDays) ?? 0
        daysLogged = try container.decodeIfPresent(Int.self, forKey: .daysLogged) ?? 0
        totalDays = try container.decodeIfPresent(Int.self, forKey: .totalDays) ?? 0
        calorieGoal = try container.decodeIfPresent(Double.self, forKey: .calorieGoal) ?? 2000
        proteinGoal = try container.decodeIfPresent(Double.self, forKey: .proteinGoal) ?? 150
        carbsGoal = try container.decodeIfPresent(Double.self, forKey: .carbsGoal) ?? 250
        fatGoal = try container.decodeIfPresent(Double.self, forKey: .fatGoal) ?? 67

        workoutProfiles = try container.decodeIfPresent([WorkoutProfile].self, forKey: .workoutProfiles) ?? []
        legacyWorkoutProfile = try container.decodeIfPresent(WorkoutProfile.self, forKey: .legacyWorkoutProfile)
        if workoutProfiles.isEmpty, let legacy = legacyWorkoutProfile {
            workoutProfiles = [legacy]
        }

        activeWorkoutProfileId = try container.decodeIfPresent(Int.self, forKey: .activeWorkoutProfileId) ?? workoutProfiles.first?.id
        supportsMultipleWorkoutProfiles = try container.decodeIfPresent(Bool.self, forKey: .supportsMultipleWorkoutProfiles) ?? (workoutProfiles.count > 1)

        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak)
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak)
        streakAsset = try container.decodeIfPresent(String.self, forKey: .streakAsset)
        lastActivityDate = try container.decodeIfPresent(String.self, forKey: .lastActivityDate)
        streakStartDate = try container.decodeIfPresent(String.self, forKey: .streakStartDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encode(name, forKey: .name)
        try container.encode(username, forKey: .username)
        try container.encode(profilePhoto, forKey: .profilePhoto)
        try container.encode(profileInitial, forKey: .profileInitial)
        try container.encode(profileColor, forKey: .profileColor)

        try container.encodeIfPresent(heightCm, forKey: .heightCm)
        try container.encodeIfPresent(heightFeet, forKey: .heightFeet)
        try container.encodeIfPresent(heightInches, forKey: .heightInches)
        try container.encodeIfPresent(currentWeightKg, forKey: .currentWeightKg)
        try container.encodeIfPresent(currentWeightLbs, forKey: .currentWeightLbs)
        try container.encodeIfPresent(weightDate, forKey: .weightDate)
        try container.encodeIfPresent(weightLogsRecent, forKey: .weightLogsRecent)

        try container.encode(calorieTrend3Weeks, forKey: .calorieTrend3Weeks)
        try container.encodeIfPresent(macroData3Weeks, forKey: .macroData3Weeks)
        try container.encode(averageDailyCalories, forKey: .averageDailyCalories)
        try container.encode(averageCaloriesActiveDays, forKey: .averageCaloriesActiveDays)
        try container.encode(daysLogged, forKey: .daysLogged)
        try container.encode(totalDays, forKey: .totalDays)
        try container.encode(calorieGoal, forKey: .calorieGoal)
        try container.encode(proteinGoal, forKey: .proteinGoal)
        try container.encode(carbsGoal, forKey: .carbsGoal)
        try container.encode(fatGoal, forKey: .fatGoal)

        try container.encode(workoutProfiles, forKey: .workoutProfiles)
        try container.encodeIfPresent(activeWorkoutProfileId, forKey: .activeWorkoutProfileId)
        try container.encode(supportsMultipleWorkoutProfiles, forKey: .supportsMultipleWorkoutProfiles)
        if let firstProfile = workoutProfiles.first {
            try container.encode(firstProfile, forKey: .legacyWorkoutProfile)
        }

        try container.encodeIfPresent(currentStreak, forKey: .currentStreak)
        try container.encodeIfPresent(longestStreak, forKey: .longestStreak)
        try container.encodeIfPresent(streakAsset, forKey: .streakAsset)
        try container.encodeIfPresent(lastActivityDate, forKey: .lastActivityDate)
        try container.encodeIfPresent(streakStartDate, forKey: .streakStartDate)
    }

    var activeWorkoutProfile: WorkoutProfile? {
        if let activeId = activeWorkoutProfileId, let match = workoutProfiles.first(where: { $0.id == activeId }) {
            return match
        }
        return workoutProfiles.first
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

// MARK: - Workout Profiles
struct WorkoutProfile: Codable, Identifiable, Equatable {
    let id: Int?
    var name: String
    var isActive: Bool
    var isDefault: Bool
    var createdAt: String?
    var updatedAt: String?
    var lastUsed: String?
    var fitnessGoal: String
    var fitnessLevel: String
    var workoutFrequency: String
    var sport: String
    var availableEquipment: [String]
    var bodyweightOnlyWorkout: Bool
    var workoutLocation: String
    var preferredWorkoutDuration: Int
    var workoutDaysPerWeek: Int
    var restDays: [String]
    var exerciseVariability: String?
    var trainingSplit: String?
    var enableCircuitsAndSupersets: Bool
    var enableTimedIntervals: Bool
    var enableWarmupSets: Bool
    var defaultWarmupEnabled: Bool
    var defaultCooldownEnabled: Bool
    var defaultWarmupDuration: Int
    var defaultCooldownDuration: Int
    var muscleRecoveryOverrides: [String: Double]
    var muscleRecoveryTargetPercent: Int?
    var currentWeightKg: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isActive = "is_active"
        case isDefault = "is_default"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastUsed = "last_used"
        case fitnessGoal = "fitness_goal"
        case fitnessLevel = "fitness_level"
        case workoutFrequency = "workout_frequency"
        case sport
        case availableEquipment = "available_equipment"
        case bodyweightOnlyWorkout = "bodyweight_only_workout"
        case workoutLocation = "workout_location"
        case preferredWorkoutDuration = "preferred_workout_duration"
        case workoutDaysPerWeek = "workout_days_per_week"
        case restDays = "rest_days"
        case exerciseVariability = "exercise_variability"
        case trainingSplit = "training_split"
        case enableCircuitsAndSupersets = "enable_circuits_and_supersets"
        case enableTimedIntervals = "enable_timed_intervals"
        case enableWarmupSets = "enable_warmup_sets"
        case defaultWarmupEnabled = "default_warmup_enabled"
        case defaultCooldownEnabled = "default_cooldown_enabled"
        case defaultWarmupDuration = "default_warmup_duration"
        case defaultCooldownDuration = "default_cooldown_duration"
        case muscleRecoveryOverrides = "muscle_recovery_overrides"
        case muscleRecoveryTargetPercent = "muscle_recovery_target_percent"
        case currentWeightKg = "current_weight_kg"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Gym Profile"
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        lastUsed = try container.decodeIfPresent(String.self, forKey: .lastUsed)

        fitnessGoal = try container.decodeIfPresent(String.self, forKey: .fitnessGoal) ?? "strength"
        fitnessLevel = try container.decodeIfPresent(String.self, forKey: .fitnessLevel) ?? "beginner"
        workoutFrequency = try container.decodeIfPresent(String.self, forKey: .workoutFrequency) ?? "medium"
        sport = try container.decodeIfPresent(String.self, forKey: .sport) ?? ""
        availableEquipment = try container.decodeIfPresent([String].self, forKey: .availableEquipment) ?? []
        bodyweightOnlyWorkout = try container.decodeIfPresent(Bool.self, forKey: .bodyweightOnlyWorkout) ?? false
        workoutLocation = try container.decodeIfPresent(String.self, forKey: .workoutLocation) ?? "large_gym"
        preferredWorkoutDuration = try container.decodeIfPresent(Int.self, forKey: .preferredWorkoutDuration) ?? 60
        workoutDaysPerWeek = try container.decodeIfPresent(Int.self, forKey: .workoutDaysPerWeek) ?? 3
        restDays = try container.decodeIfPresent([String].self, forKey: .restDays) ?? []
        exerciseVariability = try container.decodeIfPresent(String.self, forKey: .exerciseVariability)
        trainingSplit = try container.decodeIfPresent(String.self, forKey: .trainingSplit)
        enableCircuitsAndSupersets = try container.decodeIfPresent(Bool.self, forKey: .enableCircuitsAndSupersets) ?? false
        enableTimedIntervals = try container.decodeIfPresent(Bool.self, forKey: .enableTimedIntervals) ?? false
        enableWarmupSets = try container.decodeIfPresent(Bool.self, forKey: .enableWarmupSets) ?? true
        defaultWarmupEnabled = try container.decodeIfPresent(Bool.self, forKey: .defaultWarmupEnabled) ?? true
        defaultCooldownEnabled = try container.decodeIfPresent(Bool.self, forKey: .defaultCooldownEnabled) ?? true
        defaultWarmupDuration = try container.decodeIfPresent(Int.self, forKey: .defaultWarmupDuration) ?? 5
        defaultCooldownDuration = try container.decodeIfPresent(Int.self, forKey: .defaultCooldownDuration) ?? 5
        muscleRecoveryOverrides = try container.decodeIfPresent([String: Double].self, forKey: .muscleRecoveryOverrides) ?? [:]
        muscleRecoveryTargetPercent = try container.decodeIfPresent(Int.self, forKey: .muscleRecoveryTargetPercent)
        currentWeightKg = try container.decodeIfPresent(Double.self, forKey: .currentWeightKg)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(lastUsed, forKey: .lastUsed)
        try container.encode(fitnessGoal, forKey: .fitnessGoal)
        try container.encode(fitnessLevel, forKey: .fitnessLevel)
        try container.encode(workoutFrequency, forKey: .workoutFrequency)
        try container.encode(sport, forKey: .sport)
        try container.encode(availableEquipment, forKey: .availableEquipment)
        try container.encode(bodyweightOnlyWorkout, forKey: .bodyweightOnlyWorkout)
        try container.encode(workoutLocation, forKey: .workoutLocation)
        try container.encode(preferredWorkoutDuration, forKey: .preferredWorkoutDuration)
        try container.encode(workoutDaysPerWeek, forKey: .workoutDaysPerWeek)
        try container.encode(restDays, forKey: .restDays)
        try container.encodeIfPresent(exerciseVariability, forKey: .exerciseVariability)
        try container.encodeIfPresent(trainingSplit, forKey: .trainingSplit)
        try container.encode(enableCircuitsAndSupersets, forKey: .enableCircuitsAndSupersets)
        try container.encode(enableTimedIntervals, forKey: .enableTimedIntervals)
        try container.encode(enableWarmupSets, forKey: .enableWarmupSets)
        try container.encode(defaultWarmupEnabled, forKey: .defaultWarmupEnabled)
        try container.encode(defaultCooldownEnabled, forKey: .defaultCooldownEnabled)
        try container.encode(defaultWarmupDuration, forKey: .defaultWarmupDuration)
        try container.encode(defaultCooldownDuration, forKey: .defaultCooldownDuration)
        try container.encode(muscleRecoveryOverrides, forKey: .muscleRecoveryOverrides)
        try container.encodeIfPresent(muscleRecoveryTargetPercent, forKey: .muscleRecoveryTargetPercent)
        try container.encodeIfPresent(currentWeightKg, forKey: .currentWeightKg)
    }
}

extension WorkoutProfile {
    var displayName: String { name.isEmpty ? "Gym Profile" : name }
    var durationInMinutes: Int { max(15, preferredWorkoutDuration) }
}

extension ProfileDataResponse {
    func toDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }
}
