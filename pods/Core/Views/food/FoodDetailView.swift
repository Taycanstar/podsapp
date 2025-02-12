//
//  FoodDetailView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/11/25.
//

import SwiftUI

struct FoodDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let food: Food
    @Binding var selectedMeal: String 
    
    @State private var servingSize: String
    @State private var numberOfServings: Int = 1
    @State private var selectedDate = Date()
    @State private var showServingSizePicker = false

    private let foodService = FoodService.shared
    
    init(food: Food, selectedMeal: Binding<String>) {
        print("Initializing FoodDetailsView")
        print("Food:", food)
        print("Food Measures:", food.foodMeasures)
        print("Selected Meal:", selectedMeal)
        self.food = food
        // self.selectedMeal = selectedMeal
        _selectedMeal = selectedMeal 
        _servingSize = State(initialValue: food.servingSizeText)
    }
    
    private var macroPercentages: (protein: Double, carbs: Double, fat: Double) {
        let protein = food.foodNutrients.first { $0.nutrientName == "Protein" }?.value ?? 0
        let carbs = food.foodNutrients.first { $0.nutrientName == "Carbohydrate, by difference" }?.value ?? 0
        let fat = food.foodNutrients.first { $0.nutrientName == "Total lipid (fat)" }?.value ?? 0
        
        let total = protein + carbs + fat
        guard total > 0 else { return (0, 0, 0) }
        
        return (
            protein: (protein / total) * 100,
            carbs: (carbs / total) * 100,
            fat: (fat / total) * 100
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Basic Info Section
                VStack(alignment: .leading, spacing: 12) {
                
                  HStack {
                        Text("Serving Size")
                        Spacer()
                        TextField("Enter serving", text: $servingSize)
                            // .multilineTextAlignment(.trailing)
                            // .frame(maxWidth: 120)
                            .multilineTextAlignment(.center)
                            .fixedSize() 
                            .padding(8)
                            .background(Color(.tertiarySystemFill))
                            .cornerRadius(8)
                    }

                   HStack {
                        Text("Number of Servings")
                        Spacer()
                        
                            
                        Stepper("", value: $numberOfServings, in: 1...10)
                       Text("\(numberOfServings)")
                           .frame(minWidth: 40)
                           .padding(8)
                           .background(Color(.tertiarySystemFill))
                           .cornerRadius(8)
                    }
                  
                    
                    // Time Row
                    HStack {
                        Text("Time")
                        Spacer()
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                    
                    // Meal Row
                    HStack {
                        Text("Meal")
                        Spacer()
                        Menu {
                            Button("Breakfast") { selectedMeal = "Breakfast" }
                            Button("Lunch") { selectedMeal = "Lunch" }
                            Button("Dinner") { selectedMeal = "Dinner" }
                        } label: {
                            HStack {
                                Text(selectedMeal)
                                .foregroundColor(.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(8)
                        .background(Color(.tertiarySystemFill))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                
                // Macros Overview
                VStack(spacing: 15) {
                    let calories = food.calories ?? 0
                    Text("\(Int(calories)) Cal")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 25) {
                        MacroView(
                            name: "Carbs",
                            value: food.foodNutrients.first { $0.nutrientName == "Carbohydrate, by difference" }?.value ?? 0,
                            unit: "g",
                            percentage: macroPercentages.carbs
                        )
                        
                        MacroView(
                            name: "Fat",
                            value: food.foodNutrients.first { $0.nutrientName == "Total lipid (fat)" }?.value ?? 0,
                            unit: "g",
                            percentage: macroPercentages.fat
                        )
                        
                        MacroView(
                            name: "Protein",
                            value: food.foodNutrients.first { $0.nutrientName == "Protein" }?.value ?? 0,
                            unit: "g",
                            percentage: macroPercentages.protein
                        )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                
                // Daily Goals Section
                DailyGoalsSection(food: food)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                
                // Nutrition Facts
                NutritionFactsSection(nutrients: food.foodNutrients)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            }
            .padding()
        }
       
        .navigationTitle(food.displayName)
        .navigationBarTitleDisplayMode(.inline)

    }

    
}

struct MacroView: View {
    let name: String
    let value: Double
    let unit: String
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(Int(value))\(unit)")
                .font(.headline)
            Text(String(format: "%.0f%%", percentage))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// Replace the existing DailyGoalsSection with:
struct DailyGoalsSection: View {
    let food: Food
    
    private var goals: DailyGoals {
        UserGoalsManager.shared.dailyGoals
    }
    
    private var percentages: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let calories = (food.calories ?? 0) / Double(goals.calories) * 100
        let protein = (food.foodNutrients.first { $0.nutrientName == "Protein" }?.value ?? 0) / Double(goals.protein) * 100
        let carbs = (food.foodNutrients.first { $0.nutrientName == "Carbohydrate, by difference" }?.value ?? 0) / Double(goals.carbs) * 100
        let fat = (food.foodNutrients.first { $0.nutrientName == "Total lipid (fat)" }?.value ?? 0) / Double(goals.fat) * 100
        
        return (calories, protein, carbs, fat)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Daily Goals")
                .font(.headline)
            
            GoalProgressBar(
                label: "Calories",
                value: food.calories ?? 0,
                goal: Double(goals.calories),
                unit: "cal",
                color: .orange,
                percentage: percentages.calories
            )
            
            GoalProgressBar(
                label: "Protein",
                value: food.foodNutrients.first { $0.nutrientName == "Protein" }?.value ?? 0,
                goal: Double(goals.protein),
                unit: "g",
                color: .purple,
                percentage: percentages.protein
            )
            
            GoalProgressBar(
                label: "Carbs",
                value: food.foodNutrients.first { $0.nutrientName == "Carbohydrate, by difference" }?.value ?? 0,
                goal: Double(goals.carbs),
                unit: "g",
                color: .blue,
                percentage: percentages.carbs
            )
            
            GoalProgressBar(
                label: "Fat",
                value: food.foodNutrients.first { $0.nutrientName == "Total lipid (fat)" }?.value ?? 0,
                goal: Double(goals.fat),
                unit: "g",
                color: .red,
                percentage: percentages.fat
            )
        }
    }
}

struct NutritionFactsSection: View {
    let nutrients: [Nutrient]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nutrition Facts")
                .font(.headline)
            
            Divider()
            
            ForEach(nutrients, id: \.nutrientName) { nutrient in
                HStack {
                    Text(nutrient.nutrientName)
                    Spacer()
                    Text("\(Int(nutrient.value))\(nutrient.unitName)")
                }
                Divider()
            }
        }
    }
}
