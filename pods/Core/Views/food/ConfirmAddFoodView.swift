//
//  ConfirmAddFoodView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/28/25.
//

import SwiftUI

struct ConfirmAddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager
    
    // Completion closure to pass the food back to parent
    var onFoodAdded: (Food) -> Void
    
    // Basic food info
    @State private var title: String = ""
    @State private var servingSize: String = ""
    @State private var numberOfServings: Double = 1
    @State private var calories: String = ""
    
    // Basic nutrition facts
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    // Brand information
    @State private var brand: String = ""
    
    // UI states
    @State private var isAdding: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // Base nutrition values (per single serving) for dynamic calculation
    @State private var baseCalories: Double = 0
    @State private var baseProtein: Double = 0
    @State private var baseCarbs: Double = 0
    @State private var baseFat: Double = 0
    
    // Store the original food for reference
    @State private var originalFood: Food
    
    // Initializer for confirming a scanned/analyzed food for adding to recipe
    init(food: Food, onFoodAdded: @escaping (Food) -> Void) {
        self.onFoodAdded = onFoodAdded
        self._originalFood = State(initialValue: food)
        
        // Populate fields with the food data
        self._title = State(initialValue: food.description)
        self._servingSize = State(initialValue: food.servingSizeText)
        self._numberOfServings = State(initialValue: food.numberOfServings ?? 1.0)
        self._brand = State(initialValue: food.brandName ?? "")
        
        // Extract nutrition values from foodNutrients and store both base values and display strings
        var caloriesBase: Double = 0
        var proteinBase: Double = 0
        var carbsBase: Double = 0
        var fatBase: Double = 0
        
        for nutrient in food.foodNutrients {
            let name = nutrient.nutrientName.lowercased()
            guard let value = nutrient.value else { continue }
            
            if name.contains("energy") || name.contains("calorie") {
                caloriesBase = value
            } else if name.contains("protein") {
                proteinBase = value
            } else if name.contains("carbohydrate") {
                carbsBase = value
            } else if name.contains("total lipid") || name.contains("fat") && !name.contains("saturated") && !name.contains("trans") {
                fatBase = value
            }
        }
        
        // Set base values for dynamic calculation
        self._baseCalories = State(initialValue: caloriesBase)
        self._baseProtein = State(initialValue: proteinBase)
        self._baseCarbs = State(initialValue: carbsBase)
        self._baseFat = State(initialValue: fatBase)
        
        // Set display values (will be updated by numberOfServings)
        let servings = food.numberOfServings ?? 1.0
        self._calories = State(initialValue: String(format: "%.1f", caloriesBase * servings))
        self._protein = State(initialValue: String(format: "%.1f", proteinBase * servings))
        self._carbs = State(initialValue: String(format: "%.1f", carbsBase * servings))
        self._fat = State(initialValue: String(format: "%.1f", fatBase * servings))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Basic food info card
                    basicInfoCard
                    
                    // Nutrition facts section
                    nutritionFactsCard
                    
                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
            .background(Color("iosbg"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Confirm Food")
                        .font(.headline)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        addFoodToRecipe()
                    }) {
                        if isAdding {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Add")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isAdding || title.isEmpty)
                    .foregroundColor(.accentColor)
                }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: numberOfServings) { _, _ in
            updateNutritionValues()
        }
    }
    
    // MARK: - Subviews
    
    private var basicInfoCard: some View {
        ZStack(alignment: .top) {
            // Background with rounded corners
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("iosnp"))
            
            // Content
            VStack(spacing: 0) {
                // Food name
                TextField("Enter food name", text: $title)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                
                // Divider
                Divider()
                    .padding(.leading, 16)
                
                // Brand (only show if not empty)
                if !brand.isEmpty {
                    HStack {
                        Text("Brand")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("Brand", text: $brand)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 200)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                }
                
                // Serving Size
                HStack {
                    Text("Serving Size")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    TextField("e.g., 1 cup, 2 tbsp", text: $servingSize)
                        .keyboardType(.asciiCapable)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 200)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                
                // Divider
                Divider()
                    .padding(.leading, 16)
                
                // Number of Servings
                servingsRowView
            }
        }
        .padding(.horizontal)
    }
    
    private var servingsRowView: some View {
        HStack {
            Text("Number of Servings")
                .foregroundColor(.primary)
            Spacer()
            TextField("Servings", value: $numberOfServings, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .onChange(of: numberOfServings) { _ in
                    updateNutritionValues()
                }
        }
        .padding()
    }
    
    private var nutritionFactsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Facts")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ZStack(alignment: .top) {
                // Background with rounded corners
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("iosnp"))
                
                // Content
                VStack(spacing: 0) {
                    // Calories
                    HStack {
                        Text("Calories")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("0", text: $calories)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Protein
                    HStack {
                        Text("Protein (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Carbs
                    HStack {
                        Text("Carbs (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Fat
                    HStack {
                        Text("Total Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    
    private func addFoodToRecipe() {
        guard !title.isEmpty else {
            errorMessage = "Food name is required"
            showErrorAlert = true
            return
        }
        
        isAdding = true
        
        // Create updated nutrients array
        var nutrients: [Nutrient] = []
        
        if let caloriesValue = Double(calories), caloriesValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Energy", value: caloriesValue, unitName: "kcal"))
        }
        
        if let proteinValue = Double(protein), proteinValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Protein", value: proteinValue, unitName: "g"))
        }
        
        if let carbsValue = Double(carbs), carbsValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Carbohydrate, by difference", value: carbsValue, unitName: "g"))
        }
        
        if let fatValue = Double(fat), fatValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Total lipid (fat)", value: fatValue, unitName: "g"))
        }
        
        // Create the updated food object
        let updatedFood = Food(
            fdcId: originalFood.fdcId,
            description: title,
            brandOwner: originalFood.brandOwner,
            brandName: brand.isEmpty ? originalFood.brandName : brand,
            servingSize: originalFood.servingSize,
            numberOfServings: numberOfServings,
            servingSizeUnit: originalFood.servingSizeUnit,
            householdServingFullText: servingSize.isEmpty ? originalFood.householdServingFullText : servingSize,
            foodNutrients: nutrients,
            foodMeasures: originalFood.foodMeasures
        )
        
        // Pass the food to the parent and dismiss
        onFoodAdded(updatedFood)
        
        isAdding = false
        dismiss()
    }
    
    // Update all nutrition values when number of servings changes
    private func updateNutritionValues() {
        // Update main nutrition values
        calories = String(format: "%.1f", baseCalories * numberOfServings)
        protein = String(format: "%.1f", baseProtein * numberOfServings)
        carbs = String(format: "%.1f", baseCarbs * numberOfServings)
        fat = String(format: "%.1f", baseFat * numberOfServings)
    }
}

#Preview {
    ConfirmAddFoodView(food: Food(
        fdcId: 123456,
        description: "Sample Food",
        brandOwner: "Sample Brand",
        brandName: "Sample Brand",
        servingSize: 100.0,
        numberOfServings: 1.0,
        servingSizeUnit: "g",
        householdServingFullText: "1 serving",
        foodNutrients: [
            Nutrient(nutrientName: "Energy", value: 250.0, unitName: "kcal"),
            Nutrient(nutrientName: "Protein", value: 10.0, unitName: "g"),
            Nutrient(nutrientName: "Carbohydrate, by difference", value: 30.0, unitName: "g"),
            Nutrient(nutrientName: "Total lipid (fat)", value: 8.0, unitName: "g")
        ],
        foodMeasures: []
    )) { food in
        print("Food added: \(food.displayName)")
    }
}
