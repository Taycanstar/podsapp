//
//  FoodContainerView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/10/25.
//

import Foundation
import SwiftUI

// This class will maintain state between views
class FoodNavigationState: ObservableObject {
    @Published var createMealSelectedFoods: [Food] = []
    @Published var createRecipeSelectedFoods: [Food] = []
    
    // Add state for CreateMealView
    @Published var createMealName: String = ""
    @Published var createMealShareWith: String = "Everyone"
    @Published var createMealInstructions: String = ""
    @Published var createMealImageURL: URL? = nil
    @Published var createMealUIImage: UIImage? = nil
    @Published var createMealImage: Image? = nil
    
    // Add state for CreateRecipeView
    @Published var createRecipeName: String = ""
    @Published var createRecipeShareWith: String = "Everyone"
    @Published var createRecipeInstructions: String = ""
    @Published var createRecipePrepTime: String = ""
    @Published var createRecipeCookTime: String = ""
    @Published var createRecipeServings: String = "1"
    @Published var createRecipeImageURL: URL? = nil
    @Published var createRecipeUIImage: UIImage? = nil
    @Published var createRecipeImage: Image? = nil
    
    // Method to reset all create meal state
    func resetCreateMealState() {
        createMealSelectedFoods = []
        createMealName = ""
        createMealShareWith = "Everyone"
        createMealInstructions = ""
        createMealImageURL = nil
        createMealUIImage = nil
        createMealImage = nil
    }
    
    // Method to reset all create recipe state
    func resetCreateRecipeState() {
        createRecipeSelectedFoods = []
        createRecipeName = ""
        createRecipeShareWith = "Everyone"
        createRecipeInstructions = ""
        createRecipePrepTime = ""
        createRecipeCookTime = ""
        createRecipeServings = "1"
        createRecipeImageURL = nil
        createRecipeUIImage = nil
        createRecipeImage = nil
    }
}

enum FoodNavigationDestination: Hashable {
    case logFood
    case foodDetails(Food, Binding<String>) // Food and selected meal
    case foodLogDetails(CombinedLog) // For viewing/editing logged food details
    case createMeal 
    case addMealItems
    case editMeal(Meal)  // Added case for editing a meal
    case createRecipe    // Added case for creating a recipe
    case addRecipeIngredients // Added case for adding ingredients to a recipe
    case editRecipe(Recipe)   // Added case for editing a recipe
    case mealDetails(Meal)    // Added case for viewing a meal      
    case recipeDetails(Recipe) // Added case for viewing a recipe
    case addFoodToMeal   // Added case for using the AddFoodView for meals
    case addFoodToRecipe // Added case for using the AddFoodView for recipes
    case createFood      // Added case for manually creating a food item

    
    static func == (lhs: FoodNavigationDestination, rhs: FoodNavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.logFood, .logFood):
            return true
        case let (.foodDetails(food1, meal1), .foodDetails(food2, meal2)):
            return food1.id == food2.id && meal1.wrappedValue == meal2.wrappedValue
        case let (.foodLogDetails(log1), .foodLogDetails(log2)):
            return log1.id == log2.id
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
        case let (.mealDetails(meal1), .mealDetails(meal2)):
            return meal1.id == meal2.id
        case let (.recipeDetails(recipe1), .recipeDetails(recipe2)):
            return recipe1.id == recipe2.id
        case (.addFoodToMeal, .addFoodToMeal):
            return true
        case (.addFoodToRecipe, .addFoodToRecipe):
            return true
        case (.createFood, .createFood):
            return true
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
        case .foodLogDetails(let log):
            hasher.combine(13)
            hasher.combine(log.id)
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
        case .mealDetails(let meal):
            hasher.combine(8)
            hasher.combine(meal.id)
        case .recipeDetails(let recipe):
            hasher.combine(9)
            hasher.combine(recipe.id)
        case .addFoodToMeal:
            hasher.combine(10)
        case .addFoodToRecipe:
            hasher.combine(11)
        case .createFood:
            hasher.combine(12)
        }
    }
}


struct FoodContainerView: View {
    @State private var path = NavigationPath()
    @State private var selectedMeal: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    // Add the observable state object
    @StateObject private var navState = FoodNavigationState()
    
    // Separate state arrays for different contexts to prevent state bleeding
    @State private var logFoodSelectedFoods: [Food] = []
    
    // Replace editMealSelectedFoods with a dictionary to store foods per meal ID
    @State private var editMealSelectedFoodsByMealId: [Int: [Food]] = [:]
    // Keep track of the original foods for each meal to restore when canceling
    @State private var originalMealFoodsByMealId: [Int: [Food]] = [:]
    @State private var currentlyEditingMealId: Int? = nil
    
    @State private var editRecipeSelectedFoods: [Food] = []
    
    // Add a state variable to track the currently editing recipe ID, similar to currentlyEditingMealId
    @State private var currentlyEditingRecipeId: Int? = nil
    
    // For compatibility with views that expect selectedTab
    private var selectedTabBinding: Binding<Int> {
        Binding<Int>(
            get: { 0 }, // Default to dashboard tab
            set: { _ in 
                // When a view tries to change the tab, dismiss this view instead
                viewModel.hideFoodContainer()
            }
        )
    }
    
    init() {
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
    
    // Helper method to dismiss container and navigate to dashboard
    func dismissAndNavigateToDashboard() {
        // Reset state
        path = NavigationPath()
        
        // Dismiss the container view directly
        viewModel.isShowingFoodContainer = false
    }
    
    // Helper method to initialize meal items outside of the View body
    private func initializeMealItems(for meal: Meal) {
        // If we don't have original foods for this meal yet, create them
        if originalMealFoodsByMealId[meal.id] == nil {
            print("📦 FoodContainerView: Saving original foods for meal: \(meal.title) (ID: \(meal.id))")
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
            // Save the original foods
            originalMealFoodsByMealId[meal.id] = initialFoods
        }
        
        // Initialize the meal's food items if this is the first time we're viewing it
        if editMealSelectedFoodsByMealId[meal.id] == nil {
            print("📦 FoodContainerView: Initializing foods for the first time - meal: \(meal.title) (ID: \(meal.id))")
            // Use the original foods we saved
            editMealSelectedFoodsByMealId[meal.id] = originalMealFoodsByMealId[meal.id] ?? []
        } else {
            print("📦 FoodContainerView: Using existing foods for meal: \(meal.title) (ID: \(meal.id)) - \(editMealSelectedFoodsByMealId[meal.id]?.count ?? 0) items")
        }
    }
    
    // Helper method to clear cached meal items for a specific meal
    private func clearCachedMealItems(for mealId: Int) {
        editMealSelectedFoodsByMealId.removeValue(forKey: mealId)
        print("🗑️ FoodContainerView: Cleared cached foods for meal ID: \(mealId)")
    }
    
    // Helper method to restore original foods for a meal (used when canceling)
    private func restoreOriginalFoods(for mealId: Int) {
        if let originalFoods = originalMealFoodsByMealId[mealId] {
            print("🔄 FoodContainerView: Restoring original foods for meal ID: \(mealId)")
            editMealSelectedFoodsByMealId[mealId] = originalFoods
        }
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            LogFood(
                selectedTab: selectedTabBinding,
                selectedMeal: $selectedMeal,
                path: $path,
                mode: .logFood, 
                selectedFoods: $logFoodSelectedFoods
            )
            .navigationDestination(for: FoodNavigationDestination.self) { destination in
                switch destination {
                case .logFood:
                    LogFood(
                        selectedTab: selectedTabBinding,
                        selectedMeal: $selectedMeal,
                        path: $path,
                        mode: .logFood,
                        selectedFoods: $logFoodSelectedFoods
                    )
                case .foodDetails(let food, let selectedMeal):
                    FoodDetailsView(food: food, selectedMeal: selectedMeal)
                case .foodLogDetails(let log):
                    FoodLogDetails(log: log)
                case .createMeal:
                    CreateMealView(
                        path: $path,
                        selectedFoods: Binding(
                            get: { self.navState.createMealSelectedFoods },
                            set: { self.navState.createMealSelectedFoods = $0 }
                        )
                    )
                    .id("create-meal-\(navState.createMealSelectedFoods.count)")
                case .addMealItems:
                    // Create a binding that will use the correct array of selected foods
                    // If we're editing a meal, use the meal-specific array
                    // If we're creating a meal, use the createMealSelectedFoods array
                    let binding = Binding<[Food]>(
                        get: {
                            if let mealId = currentlyEditingMealId {
                                // Editing an existing meal
                                print("📋 DEBUG: Getting foods for existing meal ID: \(mealId), count: \(editMealSelectedFoodsByMealId[mealId]?.count ?? 0)")
                                return editMealSelectedFoodsByMealId[mealId] ?? []
                            } else {
                                // Creating a new meal
                                print("📋 DEBUG: Getting foods for new meal, count: \(navState.createMealSelectedFoods.count)")
                                return navState.createMealSelectedFoods
                            }
                        },
                        set: { newValue in
                            if let mealId = currentlyEditingMealId {
                                // Editing an existing meal
                                print("📋 DEBUG: Setting foods for existing meal ID: \(mealId), new count: \(newValue.count)")
                                // Create new array reference
                                editMealSelectedFoodsByMealId[mealId] = Array(newValue)
                            } else {
                                // Creating a new meal
                                print("📋 DEBUG: Setting foods for new meal, new count: \(newValue.count)")
                                // Create new array reference
                                navState.createMealSelectedFoods = Array(newValue)
                            }
                        }
                    )
                    
                    LogFood(
                        selectedTab: selectedTabBinding,
                        selectedMeal: $selectedMeal,
                        path: $path,
                        mode: .addToMeal,
                        selectedFoods: binding,
                        onItemAdded: { food in
                            // Save the updated foods
                            print("📦 FoodContainerView: Item added callback triggered with food: \(food.displayName)")
                            
                            // Check current counts
                            if let mealId = currentlyEditingMealId {
                                let mealFoods = editMealSelectedFoodsByMealId[mealId] ?? []
                                print("📊 FoodContainerView: Meal \(mealId) now has \(mealFoods.count) foods")
                                // Print each food in the array
                                for (index, food) in mealFoods.enumerated() {
                                    print("  \(index+1). \(food.displayName)")
                                }
                            } else {
                                print("📊 FoodContainerView: CreateMeal now has \(navState.createMealSelectedFoods.count) foods")
                                // Print each food in the array
                                for (index, food) in navState.createMealSelectedFoods.enumerated() {
                                    print("  \(index+1). \(food.displayName)")
                                }
                            }
                            
                            // Navigate back 
                            path.removeLast()
                        }
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
                case .mealDetails(let meal):
                    MealDetailView(meal: meal, path: $path)
                case .recipeDetails(let recipe):
                    RecipeDetailView(recipe: recipe, path: $path)
                case .createRecipe:
                    CreateRecipeView(
                        path: $path, 
                        selectedFoods: Binding(
                            get: { self.navState.createRecipeSelectedFoods },
                            set: { self.navState.createRecipeSelectedFoods = $0 }
                        )
                    )
                    .id("create-recipe-\(navState.createRecipeSelectedFoods.count)")
                    .onAppear {
                        print("🛑 RECIPE DEBUG - CreateRecipeView.onAppear with path.count = \(path.count)")
                        print("🛑 RECIPE DEBUG - createRecipeSelectedFoods has \(navState.createRecipeSelectedFoods.count) items")
                        
                        // Print the current items without clearing them
                        let _ = {
                            for (i, f) in navState.createRecipeSelectedFoods.enumerated() {
                                print("🛑   \(i+1). \(f.displayName) (ID: \(f.fdcId))")
                            }
                            return 0
                        }()
                    }
                case .addRecipeIngredients:
                    // Create a binding that will use the correct array of selected foods
                    // If we're editing a recipe, use editRecipeSelectedFoods
                    // If we're creating a new recipe, use createRecipeSelectedFoods
                    let _ = {
                        print("🛑 RECIPE DEBUG - Entering addRecipeIngredients case")
                        print("🛑 RECIPE DEBUG - createRecipeSelectedFoods has \(navState.createRecipeSelectedFoods.count) items:")
                        for (i, f) in navState.createRecipeSelectedFoods.enumerated() {
                            print("🛑   \(i+1). \(f.displayName) (ID: \(f.fdcId))")
                        }
                        return 0
                    }()
                    
                    let recipeBinding = Binding<[Food]>(
                        get: {
                            if currentlyEditingRecipeId != nil {
                                // Editing an existing recipe
                                print("🛑 RECIPE DEBUG - GET for existing recipe, count: \(editRecipeSelectedFoods.count)")
                                return editRecipeSelectedFoods
                            } else {
                                // Creating a new recipe
                                print("🛑 RECIPE DEBUG - GET for new recipe, count: \(navState.createRecipeSelectedFoods.count)")
                                return navState.createRecipeSelectedFoods
                            }
                        },
                        set: { newValue in
                            if currentlyEditingRecipeId != nil {
                                // Editing an existing recipe
                                print("🛑 RECIPE DEBUG - SET for existing recipe, new count: \(newValue.count)")
                                // Create new array reference
                                editRecipeSelectedFoods = Array(newValue)
                            } else {
                                // Creating a new recipe
                                print("🛑 RECIPE DEBUG - SET for new recipe, new count: \(newValue.count)")
                                print("🛑 RECIPE DEBUG - New foods:")
                                let _ = {
                                    for (i, f) in newValue.enumerated() {
                                        print("🛑   \(i+1). \(f.displayName) (ID: \(f.fdcId))")
                                    }
                                    return 0
                                }()
                                // Create new array reference
                                navState.createRecipeSelectedFoods = Array(newValue)
                            }
                        }
                    )
                    
                    LogFood(
                        selectedTab: selectedTabBinding,
                        selectedMeal: $selectedMeal,
                        path: $path,
                        mode: .addToRecipe,
                        selectedFoods: recipeBinding,
                        onItemAdded: { food in
                            // Save the updated foods
                            print("📦 FoodContainerView: Recipe ingredient added: \(food.displayName)")
                            
                            // Check current counts
                            if currentlyEditingRecipeId != nil {
                                print("📊 FoodContainerView: EditRecipe now has \(editRecipeSelectedFoods.count) foods")
                                // Print each food in the array
                                for (index, food) in editRecipeSelectedFoods.enumerated() {
                                    print("  \(index+1). \(food.displayName)")
                                }
                            } else {
                                print("📊 FoodContainerView: CreateRecipe now has \(navState.createRecipeSelectedFoods.count) foods")
                                // Print each food in the array
                                for (index, food) in navState.createRecipeSelectedFoods.enumerated() {
                                    print("  \(index+1). \(food.displayName)")
                                }
                            }
                            
                            // Navigate back
                            path.removeLast()
                        }
                    )
                case .editRecipe(let recipe):
                    EditRecipeView(recipe: recipe, path: $path, selectedFoods: $editRecipeSelectedFoods)
                        .onAppear {
                            // Set the currently editing recipe ID
                            currentlyEditingRecipeId = recipe.id
                            
                            // Don't reset if we're returning from adding recipe ingredients
                            // We know we're returning if the array already has items
                            if editRecipeSelectedFoods.isEmpty {
                                // First time viewing this recipe - populate from recipe's original items
                                // EditRecipeView will do this in its initializer
                            }
                            // Otherwise we're returning from adding items, so keep the existing selectedFoods array
                        }
                case .addFoodToMeal:
                    // Use the same binding approach as for the addMealItems case
                    let binding = Binding<[Food]>(
                        get: {
                            if let mealId = currentlyEditingMealId {
                                return editMealSelectedFoodsByMealId[mealId] ?? []
                            } else {
                                return navState.createMealSelectedFoods
                            }
                        },
                        set: { newValue in
                            if let mealId = currentlyEditingMealId {
                                editMealSelectedFoodsByMealId[mealId] = Array(newValue)
                            } else {
                                navState.createMealSelectedFoods = Array(newValue)
                            }
                        }
                    )
                    
                    AddFoodView(
                        path: $path,
                        selectedFoods: binding,
                        mode: .addToMeal
                    )
                
                case .addFoodToRecipe:
                    // Use the same binding approach as for the addRecipeIngredients case
                    let recipeBinding = Binding<[Food]>(
                        get: {
                            if currentlyEditingRecipeId != nil {
                                return editRecipeSelectedFoods
                            } else {
                                return navState.createRecipeSelectedFoods
                            }
                        },
                        set: { newValue in
                            if currentlyEditingRecipeId != nil {
                                editRecipeSelectedFoods = Array(newValue)
                            } else {
                                navState.createRecipeSelectedFoods = Array(newValue)
                            }
                        }
                    )
                    
                    AddFoodView(
                        path: $path,
                        selectedFoods: recipeBinding,
                        mode: .addToRecipe
                    )
                case .createFood:
                    // Implementation for creating a food item
                    CreateFoodView(path: $path)
                }
            }
        }
        .environmentObject(navState)
        .edgesIgnoringSafeArea(.all)  // Ignore all safe areas
        .transition(.move(edge: .bottom))
        .background(Color("iosbg"))  // Add background color to entire container
        .onChange(of: path) { newPath in
            // Check if we were editing a meal before and now we're no longer in that flow
            if newPath.isEmpty && currentlyEditingMealId != nil {
                print("ℹ️ FoodContainerView: Navigation path changed, currentlyEditingMealId: \(currentlyEditingMealId!)")
                currentlyEditingMealId = nil
            }
            
            // Reset recipe editing state if we're no longer in that flow
            if newPath.isEmpty && currentlyEditingRecipeId != nil {
                print("ℹ️ FoodContainerView: Navigation path changed, currentlyEditingRecipeId: \(currentlyEditingRecipeId!)")
                currentlyEditingRecipeId = nil
            }
            
            // If the navigation path is empty, we've exited all flows
            // Reset the createMealSelectedFoods array so next time we start fresh
            if newPath.isEmpty {
                print("🧹 FoodContainerView: Navigation stack empty, resetting state")
                
                // Reset meal-related state
                print("📊 Before reset: \(navState.createMealSelectedFoods.count) meal foods")
                navState.resetCreateMealState()
                print("📊 After reset: \(navState.createMealSelectedFoods.count) meal foods")
                
                // Reset recipe-related state
                print("📊 Before reset: \(navState.createRecipeSelectedFoods.count) recipe foods")
                navState.resetCreateRecipeState()
                editRecipeSelectedFoods = []
                print("📊 After reset: Recipe foods arrays cleared")
            }
        }
        .onAppear {
            // Set up notification listener for the "cancel edit" action
            NotificationCenter.default.addObserver(
                forName: Notification.Name("RestoreOriginalMealItemsNotification"),
                object: nil,
                queue: .main
            ) { [self] notification in
                if let mealId = notification.userInfo?["mealId"] as? Int {
                    restoreOriginalFoods(for: mealId)
                }
            }
            
            // Set up notification listener for successful saves
            NotificationCenter.default.addObserver(
                forName: Notification.Name("MealSuccessfullySavedNotification"),
                object: nil,
                queue: .main
            ) { [self] notification in
                if let mealId = notification.userInfo?["mealId"] as? Int,
                   let foods = notification.userInfo?["foods"] as? [Food] {
                    print("📢 FoodContainerView: Updating original foods for successfully saved meal ID: \(mealId)")
                    // Update the original foods to match the saved state
                    originalMealFoodsByMealId[mealId] = foods
                }
            }
            
            // Handle DismissFoodContainer notification for legacy compatibility
            NotificationCenter.default.addObserver(
                forName: Notification.Name("DismissFoodContainer"),
                object: nil,
                queue: .main
            ) { _ in
                dismissAndNavigateToDashboard()
            }
        }
    }
}
