//
//  QuickLogFood.swift
//  Pods
//
//  Created by Dimi Nunez on 4/3/25.
//

import SwiftUI

struct QuickLogFood: View {
    @Binding var isPresented: Bool
    @State private var foodTitle: String = ""
    @State private var foodBrand: String = ""
    @State private var foodCalories: String = ""
    @State private var foodProtein: String = ""
    @State private var foodCarbs: String = ""
    @State private var foodFats: String = ""
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @State private var errorMessage: String?
    @State private var isLogging = false
    @State private var selectedMeal: String = "Breakfast"
    @State private var selectedFoods: [Food] = []
    @State private var showAddIngredientsSheet = false
    @State private var path = NavigationPath()
    
    // For LogFood required parameters
    @State private var selectedLogTab: Int = 0
    var onFoodCreated: ((Food) -> Void)? = nil
    
    // Meal type options
    let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("iosbg").edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Title and Macros
                        titleSection
                        
                        // // Ingredients
                        // ingredientsSection
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                if isLogging {
                    Color.black.opacity(0.2)
                        .edgesIgnoringSafeArea(.all)
                    
                    ProgressView()
                        .scaleEffect(1.5)
                }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Quick Log")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .foregroundColor(.blue)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            quickLogFood()
                        }
                        .fontWeight(.semibold)
                    .disabled(foodCalories.isEmpty)
                    .foregroundColor(
                        foodCalories.isEmpty ? .gray : .blue
                    )
                    }
                    
                    // Add keyboard toolbar with Done button
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                
            }
        }
        .accentColor(.blue)
        .sheet(isPresented: $showAddIngredientsSheet) {
            LogFood(
                selectedTab: $selectedLogTab,
                selectedMeal: $selectedMeal,
                path: $path,
                mode: .addToMeal,
                selectedFoods: $selectedFoods,
                onItemAdded: { food in
                    if !selectedFoods.contains(where: { $0.fdcId == food.fdcId }) {
                        selectedFoods.append(food)
                    }
                },
                initialTab: nil
            )
        }
        .alert(isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var titleSection: some View {
        ZStack(alignment: .top) {
            // Background with rounded corners
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("iosnp"))
            
            // Content
            VStack(spacing: 16) {
                // Title
                TextField("Title", text: $foodTitle)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                // Divider that extends fully across
                Divider()
                .padding(.leading, 16)
                
                // Brand
                TextField("Brand (optional)", text: $foodBrand)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                 
                
                // Divider that extends fully across
                Divider()
                .padding(.leading, 16)
                TextField("Calories*", text: $foodCalories)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                  
                
                // Divider that extends fully across
                Divider()
                .padding(.leading, 16)
                TextField("Protein(g)", text: $foodProtein)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                   
                
                // Divider that extends fully across
                Divider()
                .padding(.leading, 16)
                TextField("Carbs(g)", text: $foodCarbs)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                   
                
                // Divider that extends fully across
                Divider()
                .padding(.leading, 16)
                TextField("Fat(g)", text: $foodFats)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                
            }
        }
    }
    
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title2)
                .fontWeight(.bold)
            
            if !selectedFoods.isEmpty {
                // Group foods by fdcId to avoid duplicates
                let aggregatedFoods = aggregateFoodsByFdcId(selectedFoods)
                
                VStack(spacing: 0) {
                    ForEach(Array(aggregatedFoods.enumerated()), id: \.element.id) { index, food in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(food.displayName)
                                    .font(.headline)
                                
                                HStack(spacing: 4) {
                                    Text(food.servingSizeText)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    if let servings = food.numberOfServings,
                                       servings > 1 {
                                        Text("×\(Int(servings))")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            if let calories = food.calories {
                                Text("\(Int(calories * (food.numberOfServings ?? 1)))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color("iosnp"))
                        
                        if index < aggregatedFoods.count - 1 {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.2))
                        }
                    }
                }
                .background(Color("iosnp"))
                .cornerRadius(12)
            }
            
            Button {
                showAddIngredientsSheet = true
            } label: {
                Text("Add ingredient")
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color("iosnp"))
                    .cornerRadius(12)
            }
        }
    }

    private func quickLogFood() {
        guard !foodCalories.isEmpty else {
            errorMessage = "Calories are required."
            return
        }
        
        // Show loading state
        isLogging = true

        // Get food details from text fields
        let title = foodTitle.isEmpty ? "Unnamed Food" : foodTitle
        let calories = Double(foodCalories) ?? 0
        let protein = Double(foodProtein) ?? 0
        let carbs = Double(foodCarbs) ?? 0
        let fat = Double(foodFats) ?? 0
        
        // Create a food item with the entered nutritional info
        let brandText = foodBrand.isEmpty ? nil : foodBrand
        let quickLoggedFood = Food(
            fdcId: Int.random(in: 1000000...9999999), // Generate a random ID for the custom food
            description: title,
            brandOwner: brandText,
            brandName: brandText,
            servingSize: 1.0,
            numberOfServings: nil,
            servingSizeUnit: nil,
            householdServingFullText: nil,
            foodNutrients: [
                Nutrient(nutrientName: "Energy", value: calories, unitName: "kcal"),
                Nutrient(nutrientName: "Protein", value: protein, unitName: "g"),
                Nutrient(nutrientName: "Carbohydrate, by difference", value: carbs, unitName: "g"),
                Nutrient(nutrientName: "Total lipid (fat)", value: fat, unitName: "g")
            ],
            foodMeasures: []
        )

        if let onFoodCreated {
            isLogging = false
            isPresented = false
            onFoodCreated(quickLoggedFood)
            return
        }

        // First immediately close the sheet to return to the main view
        isPresented = false
        
        // Also set viewModel.isShowingFoodContainer to false to ensure we return to DashboardView
        viewModel.isShowingFoodContainer = false

        // Log the food
        let email = viewModel.email
        
        foodManager.logFood(
            email: email,
            food: quickLoggedFood,
            meal: selectedMeal,
            servings: 1,
            date: Date(),
            notes: nil
        ) { result in
            DispatchQueue.main.async { [self] in
                isLogging = false
                
                switch result {
                case .success(let loggedFood):
                    // Create CombinedLog and add to DayLogsVM
                    let combinedLog = CombinedLog(
                        type: .food,
                        status: loggedFood.status,
                        calories: Double(loggedFood.food.calories),
                        message: "\(loggedFood.food.displayName) – \(loggedFood.mealType)",
                        foodLogId: loggedFood.foodLogId,
                        food: loggedFood.food,
                        mealType: loggedFood.mealType,
                        mealLogId: nil,
                        meal: nil,
                        mealTime: nil,
                        scheduledAt: Date(),
                        recipeLogId: nil,
                        recipe: nil,
                        servingsConsumed: nil,
                        isOptimistic: true
                    )
                    
                    // Ensure all @Published property updates happen on main thread
                    DispatchQueue.main.async {
                        // Add to DayLogsViewModel to update dashboard
                        dayLogsVM.addPending(combinedLog)
                        print("After addPending from QuickLogFood, logs contains food? \(dayLogsVM.logs.contains(where: { $0.id == combinedLog.id }))")
                        
                        // Update foodManager.combinedLogs
                        if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                            foodManager.combinedLogs.remove(at: idx)
                        }
                        foodManager.combinedLogs.insert(combinedLog, at: 0)
                    }
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateTotalMacros(_ foods: [Food]) -> MacroTotals {
        var totals = MacroTotals()
        
        for food in foods {
            let servings = food.numberOfServings ?? 1
            
            // Sum up calories - safeguard against nil calories
            if let calories = food.calories {
                totals.calories += calories * servings
            }
            
            // Get protein, carbs, and fat from foodNutrients array
            for nutrient in food.foodNutrients {
                // Apply the servings multiplier to get the total contribution
                let value = (nutrient.value ?? 0) * servings
                
                if nutrient.nutrientName == "Protein" {
                    totals.protein += value
                } else if nutrient.nutrientName == "Carbohydrate, by difference" {
                    totals.carbs += value
                } else if nutrient.nutrientName == "Total lipid (fat)" {
                    totals.fat += value
                }
            }
        }
        
        return totals
    }
    
    private func aggregateFoodsByFdcId(_ allFoods: [Food]) -> [Food] {
        // Dictionary to store the combined foods
        var grouped: [Int: Food] = [:]
        
        // Process foods in order
        for food in allFoods {
            if var existing = grouped[food.fdcId] {
                // Update existing entry by adding servings
                let existingServings = existing.numberOfServings ?? 1
                let additionalServings = food.numberOfServings ?? 1
                let newServings = existingServings + additionalServings
                
                // Create a mutable copy of the existing food to update
                existing.numberOfServings = newServings
                
                grouped[food.fdcId] = existing
            } else {
                // Add new entry
                grouped[food.fdcId] = food
            }
        }
        
        // Create an ordered array of unique foods
        var result: [Food] = []
        
        // First, keep track of which fdcIds we've seen
        var seenIds = Set<Int>()
        
        // Process foods in original order to maintain order
        for food in allFoods {
            if !seenIds.contains(food.fdcId), let groupedFood = grouped[food.fdcId] {
                result.append(groupedFood)
                seenIds.insert(food.fdcId)
                grouped.removeValue(forKey: food.fdcId)
            }
        }
        
        // Add any remaining grouped foods (shouldn't be any, but just in case)
        result.append(contentsOf: grouped.values)
        
        return result
    }
}
