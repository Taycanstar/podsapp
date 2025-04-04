//
//  QuickLogFood.swift
//  Pods
//
//  Created by Dimi Nunez on 4/3/25.
//

//
//  QuickPodView.swift
//  Podstack
//
//  Created by Dimi Nunez on 7/30/24.
//

import SwiftUI

struct QuickLogFood: View {
    @Binding var isPresented: Bool
    @State private var foodTitle: String = ""
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var foodManager: FoodManager
    @State private var errorMessage: String?
    @State private var isLogging = false
    @State private var selectedMeal: String = "Breakfast"
    @State private var selectedFoods: [Food] = []
    @State private var showAddIngredientsSheet = false
    @State private var path = NavigationPath()
    
    // For LogFood required parameters
    @State private var selectedLogTab: Int = 0
    
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
                        
                        // Ingredients
                        ingredientsSection
                        
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
                    .disabled(foodTitle.isEmpty || selectedFoods.isEmpty)
                    .foregroundColor(
                        (foodTitle.isEmpty || selectedFoods.isEmpty) ? .gray : .blue
                    )
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
                }
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
                    .padding(.top)
                
                // Divider that extends fully across
                Divider()
                .padding(.leading, 16)
                
                // Get the totals
                let totals = calculateTotalMacros(selectedFoods)
                
                // Create a unique identifier string based on the selectedFoods
                let foodsSignature = selectedFoods.map { "\($0.fdcId)-\($0.numberOfServings ?? 1)" }.joined(separator: ",")
                
                HStack(spacing: 40) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        // Draw the circle segments with actual percentages
                        Circle()
                            .trim(from: 0, to: CGFloat(totals.carbsPercentage) / 100)
                            .stroke(Color("teal"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        Circle()
                            .trim(from: CGFloat(totals.carbsPercentage) / 100,
                                  to: CGFloat(totals.carbsPercentage + totals.fatPercentage) / 100)
                            .stroke(Color("pinkRed"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        Circle()
                            .trim(from: CGFloat(totals.carbsPercentage + totals.fatPercentage) / 100,
                                  to: CGFloat(totals.carbsPercentage + totals.fatPercentage + totals.proteinPercentage) / 100)
                            .stroke(Color.purple, style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 0) {
                            Text("\(Int(totals.calories))").font(.system(size: 20, weight: .bold))
                            Text("Cal").font(.system(size: 14))
                        }
                    }
                    
                    Spacer()
                    
                    // Carbs
                    MacroView(
                        value: totals.carbs,
                        percentage: totals.carbsPercentage,
                        label: "Carbs",
                        percentageColor: Color("teal")
                    )
                    
                    // Fat
                    MacroView(
                        value: totals.fat,
                        percentage: totals.fatPercentage,
                        label: "Fat",
                        percentageColor: Color("pinkRed")
                    )
                    
                    // Protein
                    MacroView(
                        value: totals.protein,
                        percentage: totals.proteinPercentage,
                        label: "Protein",
                        percentageColor: Color.purple
                    )
                }
                .padding(.horizontal)
                .padding(.bottom)
                // Force redraw when foods change by using the foodsSignature as an id
                .id(foodsSignature)
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
                                
                                HStack {
                                    Text(food.servingSizeText)
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
        guard !foodTitle.isEmpty else {
            errorMessage = "Food title is required."
            return
        }
        
        guard !selectedFoods.isEmpty else {
            errorMessage = "Please add at least one ingredient."
            return
        }
        
        // Show loading state
        isLogging = true
        
        // Calculate nutritional totals
        let totals = calculateTotalMacros(selectedFoods)
        
        // Create a food item with the calculated nutritional info
        let quickLoggedFood = Food(
            fdcId: Int.random(in: 1000000...9999999), // Generate a random ID for the custom food
            description: foodTitle,
            brandOwner: nil,
            brandName: "Custom",
            servingSize: 1.0,
            numberOfServings: 1.0,
            servingSizeUnit: "serving",
            householdServingFullText: "1 serving",
            foodNutrients: [
                Nutrient(nutrientName: "Energy", value: totals.calories, unitName: "kcal"),
                Nutrient(nutrientName: "Protein", value: totals.protein, unitName: "g"),
                Nutrient(nutrientName: "Carbohydrate, by difference", value: totals.carbs, unitName: "g"),
                Nutrient(nutrientName: "Total lipid (fat)", value: totals.fat, unitName: "g")
            ],
            foodMeasures: []
        )
        
        // Log the food
        let email = viewModel.email
        
        foodManager.logFood(
            email: email,
            food: quickLoggedFood,
            meal: selectedMeal,
            servings: 1,
            date: Date()
        ) { result in
            DispatchQueue.main.async { [self] in
                isLogging = false
                
                switch result {
                case .success:
                    // Close the sheet
                    isPresented = false
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private struct MacroTotals {
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        
        var totalMacros: Double { protein + carbs + fat }
        
        var proteinPercentage: Double {
            guard totalMacros > 0 else { return 0 }
            return (protein / totalMacros) * 100
        }
        
        var carbsPercentage: Double {
            guard totalMacros > 0 else { return 0 }
            return (carbs / totalMacros) * 100
        }
        
        var fatPercentage: Double {
            guard totalMacros > 0 else { return 0 }
            return (fat / totalMacros) * 100
        }
    }
    
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


