//
//  HealthCoachResponseType.swift
//  pods
//
//  Created by Dimi Nunez on 12/16/25.
//


//
//  HealthCoachModels.swift
//  pods
//
//  Created by Claude on 12/16/24.
//

import Foundation

// MARK: - Response Types

enum HealthCoachResponseType: String, Codable {
    case text
    case foodLogged = "food_logged"
    case activityLogged = "activity_logged"
    case goalsUpdated = "goals_updated"
    case weightLogged = "weight_logged"
    case dataResponse = "data_response"
    case needsClarification = "needs_clarification"
    case error
    // Shame-spiral recovery response types
    case recoveryContext = "recovery_context"
    case recoveryMealSuggestion = "recovery_meal_suggestion"
    case gentleModeToggled = "gentle_mode_toggled"
    // Weekly check-in response types
    case weeklyCheckinPrompt = "weekly_checkin_prompt"
    case weeklyCheckinRecommendation = "weekly_checkin_recommendation"
    case weeklyCheckinConfirmation = "weekly_checkin_confirmation"
}

// MARK: - Updated Goals Payload

/// Payload returned when goals are updated via the agent
struct UpdatedGoalsPayload: Codable {
    let caloriesGoal: Int?
    let proteinGoal: Int?
    let carbsGoal: Int?
    let fatGoal: Int?
    let waterGoal: Int?
    let stepsGoal: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case caloriesGoal = "calories_goal"
        case proteinGoal = "protein_goal"
        case carbsGoal = "carbs_goal"
        case fatGoal = "fat_goal"
        case waterGoal = "water_goal"
        case stepsGoal = "steps_goal"
        case message
    }
}

// MARK: - Weight Logged Payload

/// Payload returned when weight is logged via the agent
struct HealthCoachWeightPayload: Codable {
    let id: Int
    let weightKg: Double
    let weightLbs: Double
    let dateLogged: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case weightKg = "weight_kg"
        case weightLbs = "weight_lbs"
        case dateLogged = "date_logged"
        case notes
    }
}

// MARK: - Citations

/// A citation reference from an AI response, linking to a source
struct HealthCoachCitation: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let url: String?
    let domain: String?
    let snippet: String?

    /// Display-friendly domain (falls back to extracting from URL)
    var displayDomain: String {
        domain ?? (url.flatMap { URL(string: $0)?.host } ?? "Source")
    }

    enum CodingKeys: String, CodingKey {
        case id, title, url, domain, snippet
    }
}

// MARK: - Main Response

struct HealthCoachResponse: Codable {
    let type: HealthCoachResponseType
    let message: String
    let food: HealthCoachFood?
    let mealItems: [HealthCoachMealItem]?
    let activity: HealthCoachActivity?
    let data: HealthCoachDataPayload?
    let goals: UpdatedGoalsPayload?
    let weight: HealthCoachWeightPayload?
    let options: [ClarificationOption]?
    let question: String?
    let error: String?
    let citations: [HealthCoachCitation]?
    let conversationId: String?

    // Coach intervention tracking for thumbs feedback
    let interventionId: String?

    // Shame-spiral recovery flags
    let repairModeActive: Bool?
    let gentleModeActive: Bool?
    let recoveryContext: RecoveryContextPayload?
    let recoveryMeal: RecoveryMealPayload?

    enum CodingKeys: String, CodingKey {
        case type, message, food, activity, data, goals, weight, options, question, error, citations
        case mealItems = "meal_items"
        case conversationId = "conversation_id"
        case interventionId = "intervention_id"
        case repairModeActive = "repair_mode_active"
        case gentleModeActive = "gentle_mode_active"
        case recoveryContext = "recovery_context"
        case recoveryMeal = "recovery_meal"
    }

    init(
        type: HealthCoachResponseType,
        message: String,
        food: HealthCoachFood? = nil,
        mealItems: [HealthCoachMealItem]? = nil,
        activity: HealthCoachActivity? = nil,
        data: HealthCoachDataPayload? = nil,
        goals: UpdatedGoalsPayload? = nil,
        weight: HealthCoachWeightPayload? = nil,
        options: [ClarificationOption]? = nil,
        question: String? = nil,
        error: String? = nil,
        citations: [HealthCoachCitation]? = nil,
        conversationId: String? = nil,
        interventionId: String? = nil,
        repairModeActive: Bool? = nil,
        gentleModeActive: Bool? = nil,
        recoveryContext: RecoveryContextPayload? = nil,
        recoveryMeal: RecoveryMealPayload? = nil
    ) {
        self.type = type
        self.message = message
        self.food = food
        self.mealItems = mealItems
        self.activity = activity
        self.data = data
        self.goals = goals
        self.weight = weight
        self.options = options
        self.question = question
        self.error = error
        self.citations = citations
        self.conversationId = conversationId
        self.interventionId = interventionId
        self.repairModeActive = repairModeActive
        self.gentleModeActive = gentleModeActive
        self.recoveryContext = recoveryContext
        self.recoveryMeal = recoveryMeal
    }
}

// MARK: - Shame-Spiral Recovery Payloads

/// Payload for recovery context - explains why a slip-up may have occurred
struct RecoveryContextPayload: Codable {
    let factors: [RecoveryFactor]?
    let summary: String?
}

/// Individual recovery factor with context about why overeating occurred
struct RecoveryFactor: Codable {
    let factor: String
    let message: String
    let severity: String?
}

/// Payload for recovery meal suggestions
struct RecoveryMealPayload: Codable {
    let mealType: String?
    let suggestions: [RecoveryMealSuggestion]?

    enum CodingKeys: String, CodingKey {
        case mealType = "meal_type"
        case suggestions
    }
}

/// Individual meal suggestion for recovery
struct RecoveryMealSuggestion: Codable {
    let name: String
    let proteinG: Int?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case name
        case proteinG = "protein_g"
        case note
    }
}

// MARK: - Food Models (compatible with FoodChatFood)

struct HealthCoachFood: Codable {
    let id: Int?
    let name: String?
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let servingSizeText: String?
    let foodNutrients: [HealthCoachNutrient]?

    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, carbs, fat, foodNutrients
        case servingSizeText = "serving_size_text"
    }
}

/// Nutrient data from health coach food response
struct HealthCoachNutrient: Codable {
    let nutrientName: String
    let value: Double?
    let unitName: String?
}

struct HealthCoachMealItem: Codable {
    let name: String?
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let serving: Double?
    let servingUnit: String?

    enum CodingKeys: String, CodingKey {
        case name, calories, protein, carbs, fat, serving
        case servingUnit = "serving_unit"
    }
}

// MARK: - Activity Models

struct HealthCoachActivity: Codable {
    let id: Int?
    let activityName: String
    let activityType: String?
    let durationMinutes: Int
    let caloriesBurned: Int?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case activityName = "activity_name"
        case activityType = "activity_type"
        case durationMinutes = "duration_minutes"
        case caloriesBurned = "calories_burned"
        case notes
    }
}

// MARK: - Data Query Response

struct HealthCoachDataPayload: Codable {
    let queryType: String
    let summary: String?
    let nutrition: NutritionDataPayload?
    let workout: WorkoutDataPayload?
    let healthMetrics: HealthMetricsDataPayload?
    let goals: GoalsDataPayload?

    enum CodingKeys: String, CodingKey {
        case queryType = "query_type"
        case summary, nutrition, workout, goals
        case healthMetrics = "health_metrics"
    }
}

struct NutritionDataPayload: Codable {
    let caloriesConsumed: Double?
    let caloriesRemaining: Double?
    let caloriesGoal: Double?
    let protein: Double?
    let proteinGoal: Double?
    let carbs: Double?
    let carbsGoal: Double?
    let fat: Double?
    let fatGoal: Double?
    let water: Double?
    let waterGoal: Double?
    let meals: [MealBreakdown]?

    enum CodingKeys: String, CodingKey {
        case caloriesConsumed = "calories_consumed"
        case caloriesRemaining = "calories_remaining"
        case caloriesGoal = "calories_goal"
        case protein
        case proteinGoal = "protein_goal"
        case carbs
        case carbsGoal = "carbs_goal"
        case fat
        case fatGoal = "fat_goal"
        case water
        case waterGoal = "water_goal"
        case meals
    }
}

struct MealBreakdown: Codable {
    let mealType: String
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?

    enum CodingKeys: String, CodingKey {
        case mealType = "meal_type"
        case calories, protein, carbs, fat
    }
}

struct WorkoutDataPayload: Codable {
    let hasWorkoutToday: Bool?
    let workoutName: String?
    let status: String?
    let exercises: [WorkoutExerciseInfo]?
    let durationMinutes: Int?
    let estimatedCalories: Int?

    enum CodingKeys: String, CodingKey {
        case hasWorkoutToday = "has_workout_today"
        case workoutName = "workout_name"
        case status, exercises
        case durationMinutes = "duration_minutes"
        case estimatedCalories = "estimated_calories"
    }
}

struct WorkoutExerciseInfo: Codable {
    let name: String
    let sets: Int?
    let reps: String?
    let muscleGroup: String?

    enum CodingKeys: String, CodingKey {
        case name, sets, reps
        case muscleGroup = "muscle_group"
    }
}

struct HealthMetricsDataPayload: Codable {
    let steps: Int?
    let stepsGoal: Int?
    let sleepHours: Double?
    let sleepScore: Int?
    let restingHeartRate: Double?
    let hrv: Double?
    let weight: Double?
    let waterOz: Double?
    let caloriesBurned: Double?

    enum CodingKeys: String, CodingKey {
        case steps
        case stepsGoal = "steps_goal"
        case sleepHours = "sleep_hours"
        case sleepScore = "sleep_score"
        case restingHeartRate = "resting_heart_rate"
        case hrv, weight
        case waterOz = "water_oz"
        case caloriesBurned = "calories_burned"
    }
}

/// Progress data for goals (different from GoalProgress View)
struct GoalProgressData: Codable {
    let caloriesConsumed: Double?
    let proteinConsumed: Double?
    let carbsConsumed: Double?
    let fatConsumed: Double?
    let stepsToday: Int?
    let waterToday: Double?
    let workoutsThisWeek: Int?

    enum CodingKeys: String, CodingKey {
        case caloriesConsumed = "calories_consumed"
        case proteinConsumed = "protein_consumed"
        case carbsConsumed = "carbs_consumed"
        case fatConsumed = "fat_consumed"
        case stepsToday = "steps_today"
        case waterToday = "water_today"
        case workoutsThisWeek = "workouts_this_week"
    }
}

struct GoalsDataPayload: Codable {
    let fitnessGoal: String?
    let caloriesGoal: Double?
    let proteinGoal: Double?
    let carbsGoal: Double?
    let fatGoal: Double?
    let stepsGoal: Int?
    let waterGoal: Double?
    let workoutFrequency: Int?
    let currentProgress: GoalProgressData?

    enum CodingKeys: String, CodingKey {
        case fitnessGoal = "fitness_goal"
        case caloriesGoal = "calories_goal"
        case proteinGoal = "protein_goal"
        case carbsGoal = "carbs_goal"
        case fatGoal = "fat_goal"
        case stepsGoal = "steps_goal"
        case waterGoal = "water_goal"
        case workoutFrequency = "workout_frequency"
        case currentProgress = "current_progress"
    }
}



// MARK: - Context Payload (sent with request)

struct HealthCoachContextPayload: Encodable {
    let todayMacros: TodayMacrosContext?
    let todayWorkout: TodayWorkoutContext?
    let healthMetrics: HealthMetricsContext?

    enum CodingKeys: String, CodingKey {
        case todayMacros = "today_macros"
        case todayWorkout = "today_workout"
        case healthMetrics = "health_metrics"
    }
}

struct TodayMacrosContext: Encodable {
    let caloriesConsumed: Double
    let caloriesGoal: Double
    let protein: Double
    let proteinGoal: Double
    let carbs: Double
    let carbsGoal: Double
    let fat: Double
    let fatGoal: Double
    let water: Double
    let waterGoal: Double

    enum CodingKeys: String, CodingKey {
        case caloriesConsumed = "calories_consumed"
        case caloriesGoal = "calories_goal"
        case protein
        case proteinGoal = "protein_goal"
        case carbs
        case carbsGoal = "carbs_goal"
        case fat
        case fatGoal = "fat_goal"
        case water
        case waterGoal = "water_goal"
    }
}

struct TodayWorkoutContext: Encodable {
    let hasWorkoutToday: Bool
    let workoutName: String?
    let exerciseCount: Int?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case hasWorkoutToday = "has_workout_today"
        case workoutName = "workout_name"
        case exerciseCount = "exercise_count"
        case status
    }
}

struct HealthMetricsContext: Encodable {
    let steps: Int?
    let sleepHours: Double?
    let restingHeartRate: Double?
    let hrv: Double?
    let weight: Double?

    enum CodingKeys: String, CodingKey {
        case steps
        case sleepHours = "sleep_hours"
        case restingHeartRate = "resting_heart_rate"
        case hrv, weight
    }
}

// MARK: - Message Model for Chat UI

struct HealthCoachMessage: Identifiable, Equatable {
    enum Sender: Equatable {
        case user
        case coach
        case system
        case status
    }

    let id: UUID
    let sender: Sender
    var text: String
    let timestamp: Date
    let responseType: HealthCoachResponseType?
    let food: HealthCoachFood?
    let mealItems: [HealthCoachMealItem]?
    let activity: HealthCoachActivity?
    let data: HealthCoachDataPayload?
    let options: [ClarificationOption]?
    let citations: [HealthCoachCitation]?

    // Coach intervention tracking for thumbs feedback
    var interventionId: String?
    var userRating: Int?  // +1 for thumbs up, -1 for thumbs down, nil for no rating

    init(
        id: UUID = UUID(),
        sender: Sender,
        text: String,
        timestamp: Date = Date(),
        responseType: HealthCoachResponseType? = nil,
        food: HealthCoachFood? = nil,
        mealItems: [HealthCoachMealItem]? = nil,
        activity: HealthCoachActivity? = nil,
        data: HealthCoachDataPayload? = nil,
        options: [ClarificationOption]? = nil,
        citations: [HealthCoachCitation]? = nil,
        interventionId: String? = nil,
        userRating: Int? = nil
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.responseType = responseType
        self.food = food
        self.mealItems = mealItems
        self.activity = activity
        self.data = data
        self.options = options
        self.citations = citations
        self.interventionId = interventionId
        self.userRating = userRating
    }

    static func == (lhs: HealthCoachMessage, rhs: HealthCoachMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Status Hints

enum HealthCoachStatusHint: String, CaseIterable {
    case thinking
    case analyzingData
    case loggingFood
    case loggingActivity
    case queryingHealth
    case queryingNutrition
    case queryingWorkout

    var displayText: String {
        switch self {
        case .thinking: return "Thinking..."
        case .analyzingData: return "Analyzing your data..."
        case .loggingFood: return "Logging food..."
        case .loggingActivity: return "Logging activity..."
        case .queryingHealth: return "Checking your health metrics..."
        case .queryingNutrition: return "Looking at your nutrition..."
        case .queryingWorkout: return "Checking your workout..."
        }
    }
}
