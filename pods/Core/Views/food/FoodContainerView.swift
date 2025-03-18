//
//  FoodContainerView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/10/25.
//

import Foundation
import SwiftUI

enum FoodNavigationDestination: Hashable {
    case logFood
    case foodDetails(Food, Binding<String>) // Food and selected meal
    case createMeal 
    case addMealItems
    case editMeal(Meal)  // Added case for editing a meal
    case createRecipe    // Added case for creating a recipe
    case addRecipeIngredients // Added case for adding ingredients to a recipe
    case editRecipe(Recipe)   // Added case for editing a recipe

    
    static func == (lhs: FoodNavigationDestination, rhs: FoodNavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.logFood, .logFood):
            return true
        case let (.foodDetails(food1, meal1), .foodDetails(food2, meal2)):
            return food1.id == food2.id && meal1.wrappedValue == meal2.wrappedValue
        case (.createMeal, .createMeal):
            return true
        case (.addMealItems, .addMealItems):
            return true
        case let (.editMeal(meal1), .editMeal(meal2)):
            return meal1.id == meal2.id
        case (.createRecipe, .createRecipe):
            return true
        case (.addRecipeIngredients, .addRecipeIngredients):
            return true
        case let (.editRecipe(recipe1), .editRecipe(recipe2)):
            return recipe1.id == recipe2.id
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .logFood:
            hasher.combine(0)
        case .foodDetails(let food, let meal):   
            hasher.combine(1)
            hasher.combine(food.id)
            hasher.combine(meal.wrappedValue)
        case .createMeal:
            hasher.combine(2)
        case .addMealItems:
            hasher.combine(3)
        case .editMeal(let meal):
            hasher.combine(4)
            hasher.combine(meal.id)
        case .createRecipe:
            hasher.combine(5)
        case .addRecipeIngredients:
            hasher.combine(6)
        case .editRecipe(let recipe):
            hasher.combine(7)
            hasher.combine(recipe.id)
        }
    }
}


struct FoodContainerView: View {
    @State private var path = NavigationPath()
    @Binding var selectedTab: Int
    @State private var selectedMeal: String
    
    // Separate state arrays for different contexts to prevent state bleeding
    @State private var logFoodSelectedFoods: [Food] = []
    @State private var createMealSelectedFoods: [Food] = []
    
    // Replace editMealSelectedFoods with a dictionary to store foods per meal ID
    @State private var editMealSelectedFoodsByMealId: [Int: [Food]] = [:]
    @State private var currentlyEditingMealId: Int? = nil
    
    @State private var createRecipeSelectedFoods: [Food] = []
    @State private var editRecipeSelectedFoods: [Food] = []
    
    init(selectedTab: Binding<Int>) {
        _selectedTab = selectedTab
        // Set initial meal based on time of day
        let hour = Calendar.current.component(.hour, from: Date())
        let defaultMeal: String
        
        switch hour {
        case 4...11:  // 4:00 AM to 11:00 AM
            defaultMeal = "Breakfast"
        case 12...16:  // 11:01 AM to 4:00 PM
            defaultMeal = "Lunch"
        default:  // 4:01 PM to 3:59 AM
            defaultMeal = "Dinner"
        }
        _selectedMeal = State(initialValue: defaultMeal)
    }
    
    // Helper method to initialize meal items outside of the View body
    private func initializeMealItems(for meal: Meal) {
        // Initialize the meal's food items if this is the first time we're viewing it
        if editMealSelectedFoodsByMealId[meal.id] == nil {
            print("📦 FoodContainerView: Initializing foods for the first time - meal: \(meal.title) (ID: \(meal.id))")
            var initialFoods: [Food] = []
            for item in meal.mealItems {
                let food = Food(
                    fdcId: Int(item.externalId) ?? item.foodId,
                    description: item.name,
                    brandOwner: nil,
                    brandName: nil,
                    servingSize: 1.0,
                    numberOfServings: Double(item.servings) != 0 ? Double(item.servings) : 1.0,
                    servingSizeUnit: item.servingText,
                    householdServingFullText: item.servingText,
                    foodNutrients: [
                        Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                        Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                        Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                        Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
                    ],
                    foodMeasures: []
                )
                initialFoods.append(food)
            }
            editMealSelectedFoodsByMealId[meal.id] = initialFoods
        } else {
            print("📦 FoodContainerView: Using existing foods for meal: \(meal.title) (ID: \(meal.id)) - \(editMealSelectedFoodsByMealId[meal.id]?.count ?? 0) items")
        }
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            LogFood(
                selectedTab: $selectedTab,
                selectedMeal: $selectedMeal,
                path: $path,
                mode: .logFood, 
                selectedFoods: $logFoodSelectedFoods
            )
            .navigationDestination(for: FoodNavigationDestination.self) { destination in
                switch destination {
                case .logFood:
                    LogFood(
                        selectedTab: $selectedTab,
                        selectedMeal: $selectedMeal,
                        path: $path,
                        mode: .logFood,
                        selectedFoods: $logFoodSelectedFoods
                    )
                case .foodDetails(let food, _):
                    FoodDetailsView(food: food, selectedMeal: $selectedMeal)
                case .createMeal:
                    // Clear previous selections when creating a new meal
                    CreateMealView(path: $path, selectedFoods: $createMealSelectedFoods)
                        .onAppear {
                            // Reset this context's selectedFoods when view appears
                            createMealSelectedFoods = []
                        }
                case .addMealItems:
                    // Create a binding that will edit the correct meal's food items
                    let binding = Binding<[Food]>(
                        get: {
                            guard let mealId = currentlyEditingMealId else { return [] }
                            return editMealSelectedFoodsByMealId[mealId] ?? []
                        },
                        set: { newValue in
                            guard let mealId = currentlyEditingMealId else { return }
                            editMealSelectedFoodsByMealId[mealId] = newValue
                        }
                    )
                    
                    LogFood(
                        selectedTab: $selectedTab,
                        selectedMeal: $selectedMeal,
                        path: $path,
                        mode: .addToMeal,
                        selectedFoods: binding
                    )
                case .editMeal(let meal):
                    // We must return a view directly, so we'll create the view first
                    // and then handle state setup in onAppear
                    EditMealView(
                        meal: meal, 
                        path: $path, 
                        selectedFoods: Binding(
                            get: { editMealSelectedFoodsByMealId[meal.id] ?? [] },
                            set: { editMealSelectedFoodsByMealId[meal.id] = $0 }
                        )
                    )
                    .id("edit-meal-\(meal.id)")
                    .onAppear {
                        // Set the currently editing meal ID when this view appears
                        currentlyEditingMealId = meal.id
                        
                        // Initialize the meal's food items if needed
                        initializeMealItems(for: meal)
                    }
                case .createRecipe:
                    CreateRecipeView(path: $path, selectedFoods: $createRecipeSelectedFoods)
                        .onAppear {
                            // Reset this context's selectedFoods when view appears
                            createRecipeSelectedFoods = []
                        }
                case .addRecipeIngredients:
                    LogFood(
                        selectedTab: $selectedTab,
                        selectedMeal: $selectedMeal,
                        path: $path,
                        mode: .addToRecipe,
                        selectedFoods: $editRecipeSelectedFoods
                    )
                case .editRecipe(let recipe):
                    EditRecipeView(recipe: recipe, path: $path, selectedFoods: $editRecipeSelectedFoods)
                        .onAppear {
                            // Don't reset if we're returning from adding recipe ingredients
                            // We know we're returning if the array already has items
                            if editRecipeSelectedFoods.isEmpty {
                                // First time viewing this recipe - populate from recipe's original items
                                // EditRecipeView will do this in its initializer
                            }
                            // Otherwise we're returning from adding items, so keep the existing selectedFoods array
                        }
                }
            }
        }
    }
}
