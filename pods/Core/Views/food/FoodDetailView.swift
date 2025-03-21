//
//  FoodDetailView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/11/25.
//

import SwiftUI

struct FoodDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    let food: Food
    @Binding var selectedMeal: String 
    
    @State private var servingSize: String
    @State private var numberOfServings: Int = 1
    @State private var selectedDate = Date()
    @State private var showServingSizePicker = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isLoading = false

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
                // Basic Info Section with Macros
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Serving Size")
                            Spacer()
                            TextField("Enter serving", text: $servingSize)
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
                        
                        // Macros section with the circular progress
                        HStack(spacing: 40) {
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
                            
                            // Macros (Carbs, Fat, Protein)
                            MacroView(
                                value: food.foodNutrients.first { $0.nutrientName == "Carbohydrate, by difference" }?.value ?? 0,
                                percentage: macroPercentages.carbs,
                                label: "Carbs",
                                percentageColor: Color("teal")
                            )
                            
                            MacroView(
                                value: food.foodNutrients.first { $0.nutrientName == "Total lipid (fat)" }?.value ?? 0,
                                percentage: macroPercentages.fat,
                                label: "Fat",
                                percentageColor: Color("pinkRed")
                            )
                            
                            MacroView(
                                value: food.foodNutrients.first { $0.nutrientName == "Protein" }?.value ?? 0,
                                percentage: macroPercentages.protein,
                                label: "Protein",
                                percentageColor: .purple
                            )
                        }
                    }
                }
                .padding()
                .background(Color("iosnp"))
                .cornerRadius(10)
                
                // Daily Goals Section
                Text("Daily Goals")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, -5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack {
                    DailyGoalsSection(food: food)
                }
                .padding()
                .background(Color("iosnp"))
                .cornerRadius(10)
                
                // Nutrition Facts Section
                Text("Nutrition Facts")
                 .padding(.bottom, -5)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack {
                    NutritionFactsSection(nutrients: food.foodNutrients)
                }
                  .padding()
                .background(Color("iosnp"))
                .cornerRadius(10)
            }
            .padding()
        }
                              .safeAreaInset(edge: .bottom) {
    Color.clear.frame(height: 60)
}
        .background(Color("iosbg"))
        .navigationTitle(food.displayName)
        .navigationBarTitleDisplayMode(.inline)
             .toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button {
            isLoading = true
            foodManager.logFood(
                email: viewModel.email,
                food: food,
                meal: selectedMeal,
                servings: numberOfServings,
                date: selectedDate,
                notes: nil
            ) { result in
                isLoading = false
                switch result {
                case .success(let loggedFood):
                    print("Food logged successfully: \(loggedFood)")
                    dismiss()
                case .failure(let error):
                    print("Error logging food: \(error)")
                    errorMessage = "An error occurred while logging"
                    showErrorAlert = true
                }
            }
        } label: {
            if isLoading {
                ProgressView()
                    .tint(.accentColor)
                    .frame(width: 45, height: 20)  // Match "Done" text size
                    .contentShape(Rectangle())
            } else {
                Text("Done")
            }
        }
        .fontWeight(.semibold)
        .foregroundColor(.accentColor)
        .disabled(isLoading)
    }
}
        .alert("Unable to Log Food", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
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
    
            
            GoalProgressBar(
                label: "Calories",
                value: food.calories ?? 0,
                goal: Double(goals.calories),
                unit: "cal",
                color: .red,
                percentage: percentages.calories
            )

            GoalProgressBar(
                label: "Carbs",
                value: food.foodNutrients.first { $0.nutrientName == "Carbohydrate, by difference" }?.value ?? 0,
                goal: Double(goals.carbs),
                unit: "g",
                color: Color("teal"),
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
            
            GoalProgressBar(
                label: "Protein",
                value: food.foodNutrients.first { $0.nutrientName == "Protein" }?.value ?? 0,
                goal: Double(goals.protein),
                unit: "g",
                color: .purple,
                percentage: percentages.protein
            )    
            
        }
    }
}

struct NutritionFactsSection: View {
    let nutrients: [Nutrient]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(nutrients.enumerated()), id: \.element.nutrientName) { index, nutrient in
                HStack {
                    Text(nutrient.nutrientName)
                    Spacer()
                    Text("\(Int(nutrient.safeValue))\(nutrient.unitName.lowercased())")
                }
                if index < nutrients.count - 1 {  // Only add Divider if it's not the last item
                    Divider()
                }
            }
        }
    }
}
