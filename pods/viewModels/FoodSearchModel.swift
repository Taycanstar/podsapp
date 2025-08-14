//
//  USDAFoodSearch.swift
//  Pods
//
//  Created by Dimi Nunez on 2/10/25.
//
import Foundation


struct FoodSearchResponse: Codable {
    let foods: [Food]
}

// New struct to handle barcode lookup responses
struct BarcodeLookupResponse: Codable {
    let food: Food
    let foodLogId: Int?  // Optional for preview mode
    
    // Custom init to handle the nested food object from backend
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Extract foodLogId directly from top level (optional for preview mode)
        foodLogId = try container.decodeIfPresent(Int.self, forKey: .foodLogId)
        
        // Decode the food object from the nested "food" key
        food = try container.decode(Food.self, forKey: .food)
    }
    
    private enum CodingKeys: String, CodingKey {
        case foodLogId
        case food
    }
}

struct Food: Codable, Identifiable, Hashable{
    let fdcId: Int
    var description: String
    let brandOwner: String?
    let brandName: String?
    var servingSize: Double?
    var numberOfServings: Double?
    let servingSizeUnit: String?
    var householdServingFullText: String?
    var foodNutrients: [Nutrient]
    let foodMeasures: [FoodMeasure]
    var healthAnalysis: HealthAnalysis?
    
    var id: Int { fdcId }
    
    enum CodingKeys: String, CodingKey {
        case fdcId, description, brandOwner, brandName, servingSize, numberOfServings
        case servingSizeUnit, householdServingFullText, foodNutrients, foodMeasures
        case healthAnalysis = "health_analysis"
    }
    
    var calories: Double? {
        foodNutrients.first { $0.nutrientName == "Energy" }?.value ?? 0
    }
    var protein: Double? {
        foodNutrients.first { $0.nutrientName.lowercased() == "protein" }?.value ?? 0
    }

    var carbs: Double? {
        // First try exact match for "Carbohydrate, by difference"
        if let carbNutrient = foodNutrients.first(where: { $0.nutrientName == "Carbohydrate, by difference" }) {
            return carbNutrient.value
        }
        
        // Then try more general pattern matching
        return foodNutrients.first { 
            $0.nutrientName.lowercased().contains("carbohydrate") ||
            $0.nutrientName.lowercased().contains("carbs")
        }?.value ?? 0
    }

    var fat: Double? {
        foodNutrients.first { 
            $0.nutrientName.lowercased().contains("fat") || 
            $0.nutrientName.lowercased().contains("lipid")
        }?.value ?? 0
    }
    
    var displayName: String {
        description.capitalized
    }
    
    var servingSizeText: String {
        householdServingFullText ?? "\(servingSize ?? 0) \(servingSizeUnit ?? "")"
    }
    
    var brandText: String? {
        brandName ?? brandOwner
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(fdcId)
    }
    
    static func == (lhs: Food, rhs: Food) -> Bool {
        lhs.fdcId == rhs.fdcId
    }
}

  struct FoodResponse: Codable {
        let foods: [Food]
        let hasMore: Bool
        let totalPages: Int
        let currentPage: Int
    }

struct Nutrient: Codable {
    let nutrientName: String
    let value: Double?
    let unitName: String
    
    // Add a computed property that always returns a non-optional Double
    var safeValue: Double {
        return value ?? 0.0
    }
}

struct FoodMeasure: Codable, Hashable {
    let disseminationText: String // This contains the human-readable measure (e.g., "1 cup", "2 eggs")
    let gramWeight: Double
    let id: Int
    let modifier: String?
    let measureUnitName: String
    let rank: Int
    
}

class FoodService {
    static let shared = FoodService()
    
    private init() {}
    
    func searchFoods(query: String) async throws -> FoodSearchResponse {
        guard let apiKey = ConfigurationManager.shared.getValue(forKey: "USDA_FOOD_KEY"),
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=\(apiKey)&query=\(encodedQuery)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(FoodSearchResponse.self, from: data)
    }


}

struct FacetSet: Codable {
  let positives: [HealthFacet]
  let negatives: [HealthFacet]
}

struct NutrientValues: Codable {
  let energy_kcal: Double
  let sugars_g: Double
  let sodium_mg: Double
  let saturated_fat_g: Double
  let protein_g: Double
  let fiber_g: Double
}

struct Thresholds: Codable {
  struct Per100G: Codable {
    let energy_kj: [Double]
    let sugars_g: [Double]
    let sodium_mg: [Double]
    let sat_fat_g: [Double]
    let protein_g: [Double]
    let fiber_g: [Double]
    let fv_pct: [Double]
  }
  struct Per100ML: Codable {
    let energy_kcal: [Double]
    let sugars_g: [Double]
    let sodium_mg: [Double]
  }
  struct PerServing: Codable {
    let sodium_mg: [Double]
    let sugars_g: [Double]
    let energy_kcal: [Double]
    let sat_fat_g: [Double]
  }
  let per100_g: Per100G
  let per100_ml: Per100ML
  let per_serving: PerServing
}

struct HealthAnalysis: Codable {
  let score: Int
  let color: String
  let positives: [HealthFacet]            // per-100
  let negatives: [HealthFacet]            // per-100
  let positivesText: [String]?            // Backend includes these arrays
  let negativesText: [String]?            // Backend includes these arrays
  let additives: [Additive]?
  let nutriScore: NutriScore
  let nutritionalQualityScore: Double?
  let additivePenalty: Int?
  let organicBonus: Int?
  let ultraProcessedPenalty: Int?
  let isBeverage: Bool?
  let per100Unit: String?                 // "g" or "ml"
  let servingFacets: FacetSet?            // NEW
  let per100Values: NutrientValues?       // NEW
  let perServingValues: NutrientValues?   // NEW
  let thresholds: Thresholds?             // NEW

  enum CodingKeys: String, CodingKey {
    case score, color, positives, negatives, additives
    case positivesText = "positives_text"
    case negativesText = "negatives_text"
    case nutriScore = "nutri_score"
    case nutritionalQualityScore = "nutritional_quality_score"
    case additivePenalty = "additive_penalty"
    case organicBonus = "organic_bonus"
    case ultraProcessedPenalty = "ultra_processed_penalty"
    case isBeverage = "is_beverage"
    case per100Unit = "per100_unit"
    case servingFacets = "serving_facets"
    case per100Values = "per100_values"
    case perServingValues = "per_serving_values"
    case thresholds
  }
}


struct HealthFacet: Codable {
  let id: String
  let title: String
  let subtitle: String
}

struct NutriScore: Codable {
  let points: Int
  let letter: String
}

struct Additive: Codable {
  let code: String?
  let risk: String
}


typealias HealthAdditive = Additive
typealias HealthNutriScore = NutriScore


// For logged foods from our database
struct LoggedFoodItem: Codable {
    let foodLogId: Int?   // Add food log ID
    let fdcId: Int 
    let displayName: String
    let calories: Double
    let servingSizeText: String
    var numberOfServings: Double
    let brandText: String?
    let protein: Double?  // Make optional
    let carbs: Double?    // Make optional
    let fat: Double?
    let healthAnalysis: HealthAnalysis?  // Add health analysis field
    let foodNutrients: [Nutrient]?  // Add complete nutrients array from backend
    
    enum CodingKeys: String, CodingKey {
        case foodLogId, fdcId, displayName, calories, servingSizeText, numberOfServings, brandText, protein, carbs, fat
        case healthAnalysis = "health_analysis"
        case foodNutrients
    }
}

struct LoggedFood: Codable, Identifiable {
    let status: String
    let foodLogId: Int
    let calories: Double
    let message: String
    let food: LoggedFoodItem  // Changed from Food to LoggedFoodItem
    let mealType: String      // Changed from 'meal' to 'mealType'
    
    var id: Int { foodLogId }
}

// Models for updating food logs
struct UpdatedFoodLog: Codable, Identifiable {
    let id: Int
    var servings: Double
    var date: String  // ISO format date string
    var meal_type: String
    var notes: String
    var calories: Double
    var food: LoggedFoodItem
    
    // Convert date string to Date object
    var logDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: date)
    }
}

struct UpdateFoodLogResponse: Codable {
    let success: Bool
    let food_log: UpdatedFoodLog
}

struct UpdatedMealLog: Codable, Identifiable {
    let id: Int
    var servings_consumed: Double
    var date: String  // ISO format date string
    var meal_type: String
    var notes: String
    var calories: Double
    var meal: MealSummary
    
    // Convert date string to Date object
    var logDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: date)
    }
}

struct UpdateMealLogResponse: Codable {
    let success: Bool
    var meal_log: UpdatedMealLog
}

// Add this struct to your models
struct FoodLogsResponse: Codable {
    let foodLogs: [LoggedFood]
    let hasMore: Bool
    let totalPages: Int
    let currentPage: Int
}

extension LoggedFoodItem {
    var asFood: Food {
        Food(
            fdcId: self.fdcId,
            description: displayName,
            brandOwner: nil,
            brandName: brandText,
            servingSize: nil,
            numberOfServings: numberOfServings,
            servingSizeUnit: nil,
            householdServingFullText: servingSizeText,
            foodNutrients: foodNutrients ?? [
                Nutrient(
                    nutrientName: "Energy",
                    value: calories,
                    unitName: "kcal"
                ),
                Nutrient(
                    nutrientName: "Protein",
                    value: protein ?? 0,
                    unitName: "g"
                ),
                Nutrient(
                    nutrientName: "Carbohydrate, by difference",
                    value: carbs ?? 0,
                    unitName: "g"
                ),
                Nutrient(
                    nutrientName: "Total lipid (fat)",
                    value: fat ?? 0,
                    unitName: "g"
                )
            ],
            foodMeasures: [],
            healthAnalysis: self.healthAnalysis  // Preserve health analysis
        )
    }
    
    // Helper to create LoggedFoodItem without foodLogId (for backward compatibility)
    init(fdcId: Int, displayName: String, calories: Double, servingSizeText: String, numberOfServings: Double, brandText: String?, protein: Double?, carbs: Double?, fat: Double?, healthAnalysis: HealthAnalysis? = nil) {
        self.foodLogId = nil
        self.fdcId = fdcId
        self.displayName = displayName
        self.calories = calories
        self.servingSizeText = servingSizeText
        self.numberOfServings = numberOfServings
        self.brandText = brandText
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.healthAnalysis = healthAnalysis
        self.foodNutrients = nil
    }
}



enum LogFoodMode {
    case logFood       
    case addToMeal
    case addToRecipe
}


// Add this struct for meal food items
struct MealFoodItem: Codable {
    let foodId: Int
    let externalId: String
    let name: String
    let servings: String
    let servingText: String?  // Reverted back to snake_case to match the JSON from the server
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

// Then in your Meal struct
struct Meal: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let directions: String?
    let privacy: String
    let servings: Double
    let mealItems: [MealFoodItem]
    let image: String?
    let totalCalories: Double?
    let totalProtein: Double?
    let totalCarbs: Double?
    let totalFat: Double?
    let scheduledAt: Date?

    // Add computed properties to provide default values when the fields are nil
    var calories: Double {
        // If totalCalories has a valid value > 0, use it
        if let total = totalCalories, total > 0 {
            return total
        }
        
        // If we have meal items, sum their calories
        if !mealItems.isEmpty {
            let itemCalories = mealItems.reduce(0) { sum, item in
                sum + item.calories
            }
            if itemCalories > 0 {
                return itemCalories
            }
        }
        
        // If we have macros, calculate from them
        let calculatedProtein = protein
        let calculatedCarbs = carbs
        let calculatedFat = fat
        
        if (calculatedProtein + calculatedCarbs + calculatedFat) > 0 {
            // Rough estimate: protein and carbs = 4 cal/g, fat = 9 cal/g
            return (calculatedProtein * 4) + (calculatedCarbs * 4) + (calculatedFat * 9)
        }
        
        return totalCalories ?? 0 // fallback to original value
    }
    var protein: Double { totalProtein ?? 0 }
    var carbs: Double { totalCarbs ?? 0 }
    var fat: Double { totalFat ?? 0 }
}

struct MealsResponse: Codable {
    let meals: [Meal]
    let hasMore: Bool
    let totalPages: Int
    let currentPage: Int
    
    // Keep this initializer for creating a MealsResponse from existing data
    init(meals: [Meal], hasMore: Bool, totalPages: Int, currentPage: Int) {
        self.meals = meals
        self.hasMore = hasMore
        self.totalPages = totalPages
        self.currentPage = currentPage
    }
}

struct LoggedMeal: Codable, Identifiable {
    let status: String
    let mealLogId: Int
    let calories: Double
    let message: String
    let meal: MealSummary
    let mealTime: String      // Keep mealTime for the meal type (breakfast, lunch, dinner)
    let scheduledAt: Date?    // Add scheduledAt for the precise time
    
    var id: Int { mealLogId }
}

struct MealSummary: Codable {
    let mealLogId: Int?   // Add meal log ID
    let mealId: Int
    let title: String
    let description: String?
    let image: String?
    let calories: Double
    let servings: Double
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let scheduledAt: Date?   
    
    // Computed property to ensure we display a reasonable calorie count
    // This is a safety measure in case the server returns 0 calories
    var displayCalories: Double {
        if calories > 0 {
            return calories
        }
        
        // Fallback: estimate based on macros if available
        if let protein = protein, let carbs = carbs, let fat = fat,
           (protein + carbs + fat) > 0 {
            // Rough estimate: protein and carbs = 4 cal/g, fat = 9 cal/g
            return (protein * 4) + (carbs * 4) + (fat * 9)
        }
        
        // If all else fails, return the original value
        return calories
    }
}

// In FoodSearchModel.swift
enum LogType: String, Codable {
    case food
    case meal
    case recipe
    case activity
}

// MARK: - Activity Data Structures
struct ActivitySummary: Codable, Identifiable {
    let id: String
    let workoutActivityType: String
    let displayName: String
    let duration: TimeInterval // in seconds
    let totalEnergyBurned: Double? // in kcal
    let totalDistance: Double? // in meters
    let startDate: Date
    let endDate: Date
    
    // Helper computed properties
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "< 1 min"
        }
    }
    
    var formattedDistance: String? {
        guard let totalDistance = totalDistance, totalDistance > 0 else { return nil }
        
        // Convert meters to miles
        let miles = totalDistance * 0.000621371
        return String(format: "%.2f mi", miles)
    }
    
    var isDistanceActivity: Bool {
        let distanceActivities = ["Running", "Walking", "Cycling", "Hiking", "Swimming"]
        return distanceActivities.contains(workoutActivityType)
    }
    
    var activityIcon: String {
        switch workoutActivityType {
        case "Running":
            return "figure.run"
        case "Walking":
            return "figure.walk"
        case "Cycling":
            return "bicycle"
        case "Swimming":
            return "figure.pool.swim"
        case "Hiking":
            return "figure.hiking"
        case "Yoga":
            return "figure.yoga"
        case "FunctionalStrengthTraining", "StrengthTraining":
            return "figure.strengthtraining.traditional"
        case "Tennis":
            return "figure.tennis"
        case "Basketball":
            return "figure.basketball"
        case "Soccer":
            return "figure.soccer"
        case "Rowing":
            return "figure.rowing"
        case "Elliptical":
            return "figure.elliptical"
        case "StairClimbing":
            return "figure.stairs"
        default:
            return "figure.mixed.cardio"
        }
    }
}

struct CombinedLog: Codable, Identifiable, Equatable {
    // MARK: - Common Properties
    let type: LogType
    let status: String
    var calories: Double
    var message: String
    var isOptimistic: Bool = false   // NEW flag for optimistic updates
    
    // MARK: - Food-specific properties
    let foodLogId: Int?
    var food: LoggedFoodItem?
    var mealType: String?     // Breakfast, Lunch, Dinner, etc.
    
    // MARK: - Meal-specific properties
    let mealLogId: Int?
    var meal: MealSummary?
    var mealTime: String?     // Keep mealTime for meal category
    var scheduledAt: Date?    // Add scheduledAt for the precise time
    
    // MARK: - Recipe-specific properties
    let recipeLogId: Int?
    var recipe: RecipeSummary?
    var servingsConsumed: Int?
    
    // MARK: - Activity-specific properties
    let activityId: String?
    var activity: ActivitySummary?
    
    // MARK: - Date properties for date-based views
    var logDate: String?      // The date of the log in YYYY-MM-DD format
    var dayOfWeek: String?    // The day of the week (Monday, Tuesday, etc.)
    
    // MARK: - Computed Properties
    
    // Add a computed property to handle zero calories
    var displayCalories: Double {
        // If the log has explicitly set calories > 0, always use that as first priority
        if calories > 0 {
            return calories
        }
        
        // For meal logs, use meal's calories multiplied by servings
        if let meal = meal, type == .meal {
            // If meal has its own displayCalories, use that
            let baseMealCalories = meal.displayCalories
            // Return the base calories, as servings are already factored in at log time
            return baseMealCalories
        }
        
        // For recipe logs, use recipe's calories multiplied by servingsConsumed
        if let recipe = recipe, type == .recipe {
            return recipe.displayCalories * Double(servingsConsumed ?? 1)
        }
        
        // For food logs, use food's calories multiplied by numberOfServings
        if let food = food, type == .food {
            return food.calories * (food.numberOfServings)
        }
        
        // If all else fails, return the original calories value
        return calories
    }
    
    // For Identifiable protocol - create unique ID based on type and specific ID
    var id: String {
        switch type {
        case .food:
            return "food_\(foodLogId ?? 0)"
        case .meal:
            return "meal_\(mealLogId ?? 0)"
        case .recipe:
            return "recipe_\(recipeLogId ?? 0)"
        case .activity:
            return "activity_\(activityId ?? "unknown")"
        }
    }
    
    // Custom coding keys to handle the 'id' field from the backend
    enum CodingKeys: String, CodingKey {
        case type, status, calories, message, isOptimistic
        case foodLogId, food, mealType
        case mealLogId, meal, mealTime, scheduledAt
        case recipeLogId, recipe, servingsConsumed
        case activityId, activity
        case logDate, dayOfWeek
        // This field exists in the JSON but we don't want to use it directly
        case backendId = "id" 
    }
    
    // Custom init to handle the backend ID field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all standard properties
        type = try container.decode(LogType.self, forKey: .type)
        status = try container.decode(String.self, forKey: .status)
        calories = try container.decode(Double.self, forKey: .calories)
        message = try container.decode(String.self, forKey: .message)
        isOptimistic = try container.decodeIfPresent(Bool.self, forKey: .isOptimistic) ?? false
        
        // Food-specific properties
        foodLogId = try container.decodeIfPresent(Int.self, forKey: .foodLogId)
        food = try container.decodeIfPresent(LoggedFoodItem.self, forKey: .food)
        mealType = try container.decodeIfPresent(String.self, forKey: .mealType)
        
        // Meal-specific properties
        mealLogId = try container.decodeIfPresent(Int.self, forKey: .mealLogId)
        meal = try container.decodeIfPresent(MealSummary.self, forKey: .meal)
        mealTime = try container.decodeIfPresent(String.self, forKey: .mealTime)
        scheduledAt = try container.decodeIfPresent(Date.self, forKey: .scheduledAt)
        
        // Recipe-specific properties
        recipeLogId = try container.decodeIfPresent(Int.self, forKey: .recipeLogId)
        recipe = try container.decodeIfPresent(RecipeSummary.self, forKey: .recipe)
        servingsConsumed = try container.decodeIfPresent(Int.self, forKey: .servingsConsumed)
        
        // Activity-specific properties
        activityId = try container.decodeIfPresent(String.self, forKey: .activityId)
        activity = try container.decodeIfPresent(ActivitySummary.self, forKey: .activity)
        
        // Date properties
        logDate = try container.decodeIfPresent(String.self, forKey: .logDate)
        dayOfWeek = try container.decodeIfPresent(String.self, forKey: .dayOfWeek)
        
        // We explicitly ignore the "id" field from the backend
        // by using a special coding key (backendId) that we don't store
    }
    
    // We need to encode all fields including the backend ID
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode all standard properties
        try container.encode(type, forKey: .type)
        try container.encode(status, forKey: .status)
        try container.encode(calories, forKey: .calories)
        try container.encode(message, forKey: .message)
        try container.encode(isOptimistic, forKey: .isOptimistic)
        
        // Food-specific properties
        try container.encodeIfPresent(foodLogId, forKey: .foodLogId)
        try container.encodeIfPresent(food, forKey: .food)
        try container.encodeIfPresent(mealType, forKey: .mealType)
        
        // Meal-specific properties
        try container.encodeIfPresent(mealLogId, forKey: .mealLogId)
        try container.encodeIfPresent(meal, forKey: .meal)
        try container.encodeIfPresent(mealTime, forKey: .mealTime)
        try container.encodeIfPresent(scheduledAt, forKey: .scheduledAt)
        
        // Recipe-specific properties
        try container.encodeIfPresent(recipeLogId, forKey: .recipeLogId)
        try container.encodeIfPresent(recipe, forKey: .recipe)
        try container.encodeIfPresent(servingsConsumed, forKey: .servingsConsumed)
        
        // Activity-specific properties
        try container.encodeIfPresent(activityId, forKey: .activityId)
        try container.encodeIfPresent(activity, forKey: .activity)
        
        // Date properties
        try container.encodeIfPresent(logDate, forKey: .logDate)
        try container.encodeIfPresent(dayOfWeek, forKey: .dayOfWeek)
        
        // For the backend ID, use the appropriate ID based on type
        switch type {
        case .food:
            try container.encode(foodLogId, forKey: .backendId)
        case .meal:
            try container.encode(mealLogId, forKey: .backendId)
        case .recipe:
            try container.encode(recipeLogId, forKey: .backendId)
        case .activity:
            try container.encode(activityId, forKey: .backendId)
        }
    }
}

// Provide a standard init for creating CombinedLog instances in code
extension CombinedLog {
    // This init is used for creating new logs in the app
    init(type: LogType, status: String, calories: Double, message: String,
         foodLogId: Int? = nil, food: LoggedFoodItem? = nil, mealType: String? = nil,
         mealLogId: Int? = nil, meal: MealSummary? = nil, mealTime: String? = nil, scheduledAt: Date? = nil,
         recipeLogId: Int? = nil, recipe: RecipeSummary? = nil, servingsConsumed: Int? = nil,
         activityId: String? = nil, activity: ActivitySummary? = nil,
         logDate: String? = nil, dayOfWeek: String? = nil, isOptimistic: Bool = false) {
        
        self.type = type
        self.status = status
        self.calories = calories
        self.message = message
        self.isOptimistic = isOptimistic
        
        self.foodLogId = foodLogId
        self.food = food
        self.mealType = mealType
        
        self.mealLogId = mealLogId
        self.meal = meal
        self.mealTime = mealTime
        self.scheduledAt = scheduledAt
        
        self.recipeLogId = recipeLogId
        self.recipe = recipe
        self.servingsConsumed = servingsConsumed
        
        self.activityId = activityId
        self.activity = activity
        
        self.logDate = logDate
        self.dayOfWeek = dayOfWeek
    }
}

// Implement == operator for Equatable conformance
extension CombinedLog {
    static func == (lhs: CombinedLog, rhs: CombinedLog) -> Bool {
        lhs.id == rhs.id &&
        lhs.scheduledAt == rhs.scheduledAt &&   // time matters!
        lhs.calories     == rhs.calories &&
        lhs.food?.numberOfServings == rhs.food?.numberOfServings &&
        lhs.mealType     == rhs.mealType
    }
}

struct CombinedLogsResponse: Codable {
    let logs: [CombinedLog]
    let hasMore: Bool
    let totalPages: Int
    let currentPage: Int
}


protocol MealDisplayable {
    var id: Int { get }
    var title: String { get }
    var image: String? { get }
    var calories: Double { get }
}



extension MealSummary: MealDisplayable {
    var id: Int { mealId }  // Map mealId to id for the protocol
    
    // Helper to create MealSummary without mealLogId (for backward compatibility)
    init(mealId: Int, title: String, description: String?, image: String?, calories: Double, servings: Double, protein: Double?, carbs: Double?, fat: Double?, scheduledAt: Date?) {
        self.mealLogId = nil
        self.mealId = mealId
        self.title = title
        self.description = description
        self.image = image
        self.calories = calories
        self.servings = servings
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.scheduledAt = scheduledAt
    }
}

// MARK: - Recipe Structs

// Recipe food items (similar to MealFoodItem)
struct RecipeFoodItem: Codable {
    let foodId: Int
    let externalId: String
    let name: String
    let servings: String
    let servingText: String?
    let notes: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

// Full Recipe struct (similar to Meal)
struct Recipe: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let instructions: String?
    let privacy: String
    let servings: Int
    let createdAt: Date
    let updatedAt: Date?  // Make this optional since it might not always be provided
    let recipeItems: [RecipeFoodItem]
    let image: String?
    let prepTime: Int?
    let cookTime: Int?
    let totalCalories: Double?
    let totalProtein: Double?
    let totalCarbs: Double?
    let totalFat: Double?
    let scheduledAt: Date?
    
    // Add computed properties to provide default values when the fields are nil
    var calories: Double {
        // If totalCalories has a valid value > 0, use it
        if let total = totalCalories, total > 0 {
            return total
        }
        
        // If we have recipe items, sum their calories
        if !recipeItems.isEmpty {
            let itemCalories = recipeItems.reduce(0) { sum, item in
                sum + item.calories
            }
            if itemCalories > 0 {
                return itemCalories
            }
        }
        
        // If we have macros, calculate from them
        let calculatedProtein = protein
        let calculatedCarbs = carbs
        let calculatedFat = fat
        
        if (calculatedProtein + calculatedCarbs + calculatedFat) > 0 {
            // Rough estimate: protein and carbs = 4 cal/g, fat = 9 cal/g
            return (calculatedProtein * 4) + (calculatedCarbs * 4) + (calculatedFat * 9)
        }
        
        return totalCalories ?? 0 // fallback to original value
    }
    var protein: Double { totalProtein ?? 0 }
    var carbs: Double { totalCarbs ?? 0 }
    var fat: Double { totalFat ?? 0 }
    
    // Total time in minutes
    var totalTime: Int {
        (prepTime ?? 0) + (cookTime ?? 0)
    }
}

// Recipe summary for display in lists (similar to MealSummary)
struct RecipeSummary: Codable {
    let recipeId: Int
    let title: String
    let description: String?
    let image: String?
    let calories: Double
    let servings: Int
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let prepTime: Int?
    let cookTime: Int?
    
    // Computed property to ensure we display a reasonable calorie count
    var displayCalories: Double {
        if calories > 0 {
            return calories
        }
        
        // Fallback: estimate based on macros if available
        if let protein = protein, let carbs = carbs, let fat = fat,
           (protein + carbs + fat) > 0 {
            // Rough estimate: protein and carbs = 4 cal/g, fat = 9 cal/g
            return (protein * 4) + (carbs * 4) + (fat * 9)
        }
        
        // If all else fails, return the original value
        return calories
    }
    
    // Total time in minutes
    var totalTime: Int {
        (prepTime ?? 0) + (cookTime ?? 0)
    }
}

// Logged Recipe (similar to LoggedMeal)
struct LoggedRecipe: Codable, Identifiable {
    let status: String
    let recipeLogId: Int
    let calories: Double
    let message: String
    let recipe: RecipeSummary
    let mealTime: String
    let notes: String?
    
    var id: Int { recipeLogId }
}

// Response for recipes (similar to MealsResponse)
struct RecipesResponse: Codable {
    let recipes: [Recipe]
    let hasMore: Bool
    let totalPages: Int
    let currentPage: Int
    
    // Initializer for creating a RecipesResponse from existing data
    init(recipes: [Recipe], hasMore: Bool, totalPages: Int, currentPage: Int) {
        self.recipes = recipes
        self.hasMore = hasMore
        self.totalPages = totalPages
        self.currentPage = currentPage
    }
}

// Make RecipeSummary conform to MealDisplayable for reuse in UI components
extension RecipeSummary: MealDisplayable {
    var id: Int { recipeId }  // Map recipeId to id for the protocol
}


/// Structure to hold all the user's onboarding data
struct OnboardingData: Codable {
    let email: String
    let gender: String // "male", "female", or "other"
    let dateOfBirth: String // YYYY-MM-DD format
    let heightCm: Double
    let weightKg: Double
    let desiredWeightKg: Double // This will be populated from desiredWeightKilograms
    let dietGoal: String // "loseWeight", "maintain", or "gainWeight" (renamed from fitnessGoal)
    let workoutFrequency: String // "low", "medium", or "high"
    let dietPreference: String // "balanced", "vegan", "keto", etc.
    let primaryWellnessGoal: String
    let goalTimeframeWeeks: Int?
    let weeklyWeightChange: Double? // New field for weekly weight change
    let obstacles: [String]?
    let addCaloriesBurned: Bool
    let rolloverCalories: Bool
    let fitnessLevel: String? // "beginner", "intermediate", or "advanced"
    let fitnessGoal: String? // "strength", "hypertrophy", "tone", "endurance", "powerlifting", "sportsPerformance"
    let sportType: String? // Only populated if fitnessGoal is "sportsPerformance"
}

// Make OnboardingData printable for debugging
extension OnboardingData: CustomStringConvertible {
    var description: String {
        return """
        OnboardingData {
            email: \(email)
            gender: \(gender)
            dateOfBirth: \(dateOfBirth)
            heightCm: \(heightCm)
            weightKg: \(weightKg)
            desiredWeightKg: \(desiredWeightKg)
            dietGoal: \(dietGoal)
            workoutFrequency: \(workoutFrequency)
            dietPreference: \(dietPreference)
            primaryWellnessGoal: \(primaryWellnessGoal)
            goalTimeframeWeeks: \(goalTimeframeWeeks ?? 0)
            weeklyWeightChange: \(weeklyWeightChange ?? 0.0)
            obstacles: \(obstacles?.joined(separator: ", ") ?? "none")
            addCaloriesBurned: \(addCaloriesBurned)
            rolloverCalories: \(rolloverCalories)
            fitnessLevel: \(fitnessLevel ?? "none")
            fitnessGoal: \(fitnessGoal ?? "none")
            sportType: \(sportType ?? "none")
        }
        """
    }
}

/// Structure to hold the calculated nutrition goals
struct ResearchBacking: Codable {
    let insight: String?
    let citation: String?
    let relevance: String?
}

struct InsightDetails: Codable {
    let primaryAnalysis: String?
    let researchBacking: [ResearchBacking]?
    let practicalImplications: String?
    let optimizationStrategies: String?
    let macronutrientBreakdown: String?
    let micronutrientFocus: String?
    let mealTiming: String?
    let supplementation: String?
    
    enum CodingKeys: String, CodingKey {
        case primaryAnalysis = "primary_analysis"
        case researchBacking = "research_backing"
        case practicalImplications = "practical_implications"
        case optimizationStrategies = "optimization_strategies"
        case macronutrientBreakdown = "macronutrient_breakdown"
        case micronutrientFocus = "micronutrient_focus"
        case mealTiming = "meal_timing"
        case supplementation
    }
}

// Add this extension to allow .isEmpty checks
extension InsightDetails {
    var isEmpty: Bool {
        return (primaryAnalysis?.isEmpty ?? true)
            && (researchBacking?.isEmpty ?? true)
            && (practicalImplications?.isEmpty ?? true)
            && (optimizationStrategies?.isEmpty ?? true)
            && (macronutrientBreakdown?.isEmpty ?? true)
            && (micronutrientFocus?.isEmpty ?? true)
            && (mealTiming?.isEmpty ?? true)
            && (supplementation?.isEmpty ?? true)
    }
}

extension InsightDetails {
    var summary: String {
        var parts: [String] = []
        if let primaryAnalysis = primaryAnalysis, !primaryAnalysis.isEmpty {
            parts.append("Primary Analysis: \(primaryAnalysis)")
        }
        if let practicalImplications = practicalImplications, !practicalImplications.isEmpty {
            parts.append("Practical Implications: \(practicalImplications)")
        }
        if let optimizationStrategies = optimizationStrategies, !optimizationStrategies.isEmpty {
            parts.append("Optimization Strategies: \(optimizationStrategies)")
        }
        if let macronutrientBreakdown = macronutrientBreakdown, !macronutrientBreakdown.isEmpty {
            parts.append("Macronutrient Breakdown: \(macronutrientBreakdown)")
        }
        if let micronutrientFocus = micronutrientFocus, !micronutrientFocus.isEmpty {
            parts.append("Micronutrient Focus: \(micronutrientFocus)")
        }
        if let mealTiming = mealTiming, !mealTiming.isEmpty {
            parts.append("Meal Timing: \(mealTiming)")
        }
        if let supplementation = supplementation, !supplementation.isEmpty {
            parts.append("Supplementation: \(supplementation)")
        }
        // Research backing (array)
        if let researchBacking = researchBacking, !researchBacking.isEmpty {
            let researchText = researchBacking.compactMap { rb in
                guard let insight = rb.insight, !insight.isEmpty else { return nil }
                var text = "- \(insight)"
                if let citation = rb.citation, !citation.isEmpty {
                    text += " (\(citation))"
                }
                if let relevance = rb.relevance, !relevance.isEmpty {
                    text += "\n  Relevance: \(relevance)"
                }
                return text
            }.joined(separator: "\n")
            if !researchText.isEmpty {
                parts.append("Research Backing:\n\(researchText)")
            }
        }
        return parts.joined(separator: "\n\n")
    }
}

struct NutritionGoals: Codable {
    let bmr: Double?
    let tdee: Double?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let metabolismInsights: InsightDetails?
    let nutritionInsights: InsightDetails?
    let desiredWeightKg: Double?
    let desiredWeightLbs: Double?
    
    // Add initializer with default values for optional fields
    init(bmr: Double? = nil, 
         tdee: Double? = nil, 
         calories: Double, 
         protein: Double, 
         carbs: Double, 
         fat: Double, 
         metabolismInsights: InsightDetails? = nil, 
         nutritionInsights: InsightDetails? = nil,
         desiredWeightKg: Double? = nil,
         desiredWeightLbs: Double? = nil) {
        self.bmr = bmr
        self.tdee = tdee
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.metabolismInsights = metabolismInsights
        self.nutritionInsights = nutritionInsights
        self.desiredWeightKg = desiredWeightKg
        self.desiredWeightLbs = desiredWeightLbs
    }
    
    // Implement custom decoding to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        calories = try container.decode(Double.self, forKey: .calories)
        protein = try container.decode(Double.self, forKey: .protein)
        carbs = try container.decode(Double.self, forKey: .carbs)
        fat = try container.decode(Double.self, forKey: .fat)
        
        // Optional fields - decode if present, use nil if missing
        bmr = try container.decodeIfPresent(Double.self, forKey: .bmr)
        tdee = try container.decodeIfPresent(Double.self, forKey: .tdee)
        metabolismInsights = try container.decodeIfPresent(InsightDetails.self, forKey: .metabolismInsights)
        nutritionInsights = try container.decodeIfPresent(InsightDetails.self, forKey: .nutritionInsights)
        desiredWeightKg = try container.decodeIfPresent(Double.self, forKey: .desiredWeightKg)
        desiredWeightLbs = try container.decodeIfPresent(Double.self, forKey: .desiredWeightLbs)
    }
    
    enum CodingKeys: String, CodingKey {
        case bmr, tdee, calories, protein, carbs, fat
        case metabolismInsights = "metabolism_insights"
        case nutritionInsights = "nutrition_insights"
        case desiredWeightKg = "desired_weight_kg"
        case desiredWeightLbs = "desired_weight_lbs"
    }
}

struct NutritionGoalsResponse: Codable {
    let success: Bool
    let goals: NutritionGoals
}

// MARK: - Saved Meals

enum SavedItemType: String, Codable, CaseIterable {
    case foodLog = "food_log"
    case mealLog = "meal_log"
    
    var displayName: String {
        switch self {
        case .foodLog: return "Food"
        case .mealLog: return "Meal"
        }
    }
}

struct SavedMeal: Codable, Identifiable {
    let id: Int
    let itemType: SavedItemType
    let customName: String?
    let savedAt: String  // Keep as string to avoid date-parsing issues
    let notes: String?
    
    // The actual food or meal log data
    let foodLog: LoggedFoodItem?
    let mealLog: MealSummary?
    
    // Computed properties for display
    var displayName: String {
        if let customName = customName, !customName.isEmpty {
            return customName
        } else if let foodLog = foodLog {
            return foodLog.displayName
        } else if let mealLog = mealLog {
            return mealLog.title
        }
        return "Unknown item"
    }
    
    var calories: Double {
        if let foodLog = foodLog {
            return foodLog.calories
        } else if let mealLog = mealLog {
            return mealLog.displayCalories
        }
        return 0
    }
    
    var mealType: String {
        if let foodLog = foodLog {
            // For food logs, we don't have direct meal type, so we'll use a generic description
            return "Food Item"
        } else if let mealLog = mealLog {
            return "Recipe"
        }
        return ""
    }
    
    // Custom coding keys to match the backend
    enum CodingKeys: String, CodingKey {
        case id
        case itemType = "item_type"
        case customName = "custom_name"
        case savedAt = "saved_at"
        case notes
        case foodLog = "food_log"
        case mealLog = "meal_log"
    }
}

struct SavedMealsResponse: Codable {
    let savedMeals: [SavedMeal]
    let hasMore: Bool
    let totalPages: Int
    let currentPage: Int
    
    enum CodingKeys: String, CodingKey {
        case savedMeals = "saved_meals"
        case hasMore = "has_more"
        case totalPages = "total_pages"
        case currentPage = "current_page"
    }
}

// Response for save/unsave operations
struct SaveMealResponse: Codable {
    let success: Bool
    let message: String
    let savedMeal: SavedMeal?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case savedMeal = "saved_meal"
    }
}

struct UnsaveMealResponse: Codable {
    let success: Bool
    let message: String
}