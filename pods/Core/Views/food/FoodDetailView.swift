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
                

                HStack(spacing: 15) {
    // Calories with circular progress
                  // In your FoodDetailsView
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                // Carbs segment
                Circle()
                    .trim(from: 0, to: CGFloat(macroPercentages.carbs) / 100)
                    .stroke(Color("teal"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                // Fat segment (starts where carbs ends)
                Circle()
                    .trim(from: CGFloat(macroPercentages.carbs) / 100, 
                        to: CGFloat(macroPercentages.carbs + macroPercentages.fat) / 100)
                    .stroke(Color("pinkRed"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                // Protein segment (starts where fat ends)
                Circle()
                    .trim(from: CGFloat(macroPercentages.carbs + macroPercentages.fat) / 100,
                        to: CGFloat(macroPercentages.carbs + macroPercentages.fat + macroPercentages.protein) / 100)
                    .stroke(Color("purple"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                // Calories value in center
                VStack(spacing: 0) {
                    Text("\(Int(food.calories ?? 0))")
                        .font(.system(size: 20, weight: .bold))
                    Text("Cal")
                        .font(.system(size: 14))
                }
            }
                    Spacer()
                    
                    // Macros row
                    HStack(spacing: 40) {
                        // Carbs
                        MacroView(
                            value: food.foodNutrients.first { $0.nutrientName == "Carbohydrate, by difference" }?.value ?? 0,
                            percentage: macroPercentages.carbs,
                                    label: "Carbs",
                            percentageColor: Color("teal")
                        )
                        
                        // Fat
                        MacroView(
                            value: food.foodNutrients.first { $0.nutrientName == "Total lipid (fat)" }?.value ?? 0,
                            percentage: macroPercentages.fat,
                            label: "Fat",
                            percentageColor: Color("pinkRed")
                        )
                        
                        // Protein
                        MacroView(
                            value: food.foodNutrients.first { $0.nutrientName == "Protein" }?.value ?? 0,
                            percentage: macroPercentages.protein,
                            label: "Protein",
                            percentageColor: Color("purple")
                        )
                    }
                }
                  .padding()
                // .background(Color(.systemBackground))
                
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
    let value: Double
    let percentage: Double
    let label: String
    let percentageColor: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(percentage))%")
                .foregroundColor(percentageColor)
                .font(.caption)
            Text("\(Int(value))g")
                .font(.body)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
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
