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



struct Food: Codable, Identifiable, Hashable{
    let fdcId: Int
    let description: String
    let brandOwner: String?
    let brandName: String?
    let servingSize: Double?
    var numberOfServings: Double?
    let servingSizeUnit: String?
    let householdServingFullText: String?
    let foodNutrients: [Nutrient]
    let foodMeasures: [FoodMeasure]
    
    var id: Int { fdcId }
    
    var calories: Double? {
        foodNutrients.first { $0.nutrientName == "Energy" }?.value ?? 0
    }
    var protein: Double? {
        foodNutrients.first { $0.nutrientName.lowercased() == "protein" }?.value ?? 0
    }

    var carbs: Double? {
        foodNutrients.first { 
            $0.nutrientName.lowercased().contains("carbohydrate") 
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


// For logged foods from our database
struct LoggedFoodItem: Codable {
    let fdcId: Int 
    let displayName: String
    let calories: Double
    let servingSizeText: String
    var numberOfServings: Double
    let brandText: String?
    let protein: Double?  // Make optional
    let carbs: Double?    // Make optional
    let fat: Double? 
}

struct LoggedFood: Codable, Identifiable {
    let status: String
    let foodLogId: Int
    let calories: Double
    let message: String
    let food: LoggedFoodItem  // Changed from Food to LoggedFoodItem
    let mealType: String      // Changed from 'meal' to 'mealType'
    
    var id: Int { foodLogId }
    
    // enum CodingKeys: String, CodingKey {
    //     case status
    //     case foodLogId = "food_log_id"  // Map camelCase to snake_case
    //     case calories
    //     case message
    //     case food
    //     case mealType = "meal_type" // Map from backend field
    // }
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
            foodNutrients: [
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
            foodMeasures: []
        )
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
    let servings: Int
    // let createdAt: Date? = Date()  // Default to current date
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
    let mealId: Int
    let title: String
    let description: String?
    let image: String?
    let calories: Double
    let servings: Int
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let scheduledAt: Date?   // Optional precise time for the meal
    
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
}

struct CombinedLog: Codable, Identifiable {
    let type: LogType
    let status: String
    let calories: Double
    let message: String
    
    // Food-specific properties
    let foodLogId: Int?
    let food: LoggedFoodItem?
    let mealType: String?     // Breakfast, Lunch, Dinner, etc.
    
    // Meal-specific properties
    let mealLogId: Int?
    let meal: MealSummary?
    let mealTime: String?     // Keep mealTime for meal category
    let scheduledAt: Date?    // Add scheduledAt for the precise time
    
    // Recipe-specific properties
    let recipeLogId: Int?
    let recipe: RecipeSummary?
    let servingsConsumed: Int?
    
    // Add a computed property to handle zero calories
    var displayCalories: Double {
        if calories > 0 {
            return calories
        }
        
        // If calories is zero but we have a meal with displayCalories, use that
        if let meal = meal, type == .meal {
            return meal.displayCalories
        }
        
        // If calories is zero but we have a recipe with displayCalories, use that
        if let recipe = recipe, type == .recipe {
            return recipe.displayCalories * Double(servingsConsumed ?? 1)
        }
        
        // If it's a food item, try to calculate from the food
        if let food = food, type == .food {
            return food.calories * (food.numberOfServings)
        }
        
        return calories // fallback to original value
    }
    
    var id: Int {
        switch type {
        case .food: return foodLogId ?? 0
        case .meal: return mealLogId ?? 0
        case .recipe: return recipeLogId ?? 0
        }
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
    let servingsConsumed: Int
    let notes: String?
    let loggedAt: Date
    
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