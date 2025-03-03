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
        foodNutrients.first { $0.nutrientName == "Energy" }?.value
    }
    var protein: Double? {
    foodNutrients.first { $0.nutrientName.lowercased() == "protein" }?.value
}

    var carbs: Double? {
        foodNutrients.first { 
            $0.nutrientName.lowercased().contains("carbohydrate") 
        }?.value
    }

    var fat: Double? {
        foodNutrients.first { 
            $0.nutrientName.lowercased().contains("fat") || 
            $0.nutrientName.lowercased().contains("lipid")
        }?.value
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
    let value: Double
    let unitName: String
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
    let meal: String
    
    var id: Int { foodLogId }
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
}


// Add this struct for meal food items
struct MealFoodItem: Codable {
    let foodId: Int
    let externalId: String
    let name: String
    let servings: String
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
    let createdAt: Date
    let mealItems: [MealFoodItem]  // Changed from foods: [Food]
    let image: String?
    let totalCalories: Double?  // Made optional
    let totalProtein: Double?   // Made optional
    let totalCarbs: Double?     // Made optional
    let totalFat: Double?       // Made optional
    
    // Add computed properties to provide default values when the fields are nil
    var calories: Double { totalCalories ?? 0 }
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
    let mealTime: String
    
    var id: Int { mealLogId }
}

struct MealSummary: Codable {
    let mealId: Int
    let title: String
    let description: String?
    let image: String?
    let calories: Double
    let servings: Int
}