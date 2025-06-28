//
//  CreateAddFoodView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/17/25.
//

import SwiftUI

struct CreateAddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager
    
    // Completion closure to pass created food back to parent
    var onFoodAdded: (Food) -> Void
    
    // Basic food info
    @State private var title: String = ""
    @State private var brand: String = ""
    @State private var servingSize: String = ""
    @State private var numberOfServings: Double = 1
    @State private var calories: String = ""
    
    // Basic nutrition facts
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    // Flag to show additional nutrients
    @State private var showMoreNutrients: Bool = false
    
    // Additional nutrients
    @State private var saturatedFat: String = ""
    @State private var polyunsaturatedFat: String = ""
    @State private var monounsaturatedFat: String = ""
    @State private var transFat: String = ""
    @State private var cholesterol: String = ""
    @State private var sodium: String = ""
    @State private var potassium: String = ""
    @State private var sugar: String = ""
    @State private var fiber: String = ""
    @State private var vitaminA: String = ""
    @State private var vitaminC: String = ""
    @State private var calcium: String = ""
    @State private var iron: String = ""
    
    // UI states
    @State private var isCreating: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // AI generation section
    @State private var aiSearchText: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Basic food info card
                    basicInfoCard
                    
                    // Nutrition facts section
                    nutritionFactsCard
                    
                    // Additional nutrients section (collapsible)
                    if showMoreNutrients {
                        additionalNutrientsCard
                    }
                    
                    Spacer().frame(height: 40) // extra bottom space
                }
                .padding(.top, 16)
            }
            .background(Color("iosbg"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Food")
                        .font(.headline)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createFood) {
                        Text("Add")
                            .fontWeight(.semibold)
                    }
                    .disabled(title.isEmpty || calories.isEmpty || isCreating)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(
                Group {
                    if isCreating {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                }
            )
        }
    }
    
    // MARK: - AI Generation Card
    private var aiGenerationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Generate")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("iosnp"))
                
                VStack(spacing: 0) {
                    TextField("Describe your food (e.g., 'grilled chicken breast')", text: $aiSearchText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    Button(action: generateFoodWithAI) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.accentColor)
                            Text("Generate Food with AI")
                                .foregroundColor(.accentColor)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                    .disabled(aiSearchText.isEmpty || isCreating)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Card Views (reusing from CreateFoodView)
    private var basicInfoCard: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("iosnp"))
            
            VStack(spacing: 0) {
                TextField("Title", text: $title)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                
                Divider()
                    .padding(.leading, 16)
                
                TextField("Brand (optional)", text: $brand)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                
                Divider()
                    .padding(.leading, 16)
                
                TextField("Serving Size (e.g., 1 cup, 2 tbsp)", text: $servingSize)
                    .keyboardType(.asciiCapable)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                
                Divider()
                    .padding(.leading, 16)
                
                numberOfServingsRow
            }
        }
        .padding(.horizontal)
    }
    
    private var nutritionFactsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Facts")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("iosnp"))
                
                VStack(spacing: 0) {
                    TextField("Calories*", text: $calories)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Protein (g)", text: $protein)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Carbs (g)", text: $carbs)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Fat (g)", text: $fat)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showMoreNutrients.toggle()
                        }
                    }) {
                        HStack {
                            Text(showMoreNutrients ? "Show Less" : "Show More")
                                .foregroundColor(.accentColor)
                            
                            Spacer()
                            
                            Image(systemName: showMoreNutrients ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var additionalNutrientsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Nutrients")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("iosnp"))
                
                VStack(spacing: 0) {
                    TextField("Saturated Fat (g)", text: $saturatedFat)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Polyunsaturated Fat (g)", text: $polyunsaturatedFat)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Monounsaturated Fat (g)", text: $monounsaturatedFat)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Trans Fat (g)", text: $transFat)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Cholesterol (mg)", text: $cholesterol)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Sodium (mg)", text: $sodium)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Potassium (mg)", text: $potassium)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Sugar (g)", text: $sugar)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Fiber (g)", text: $fiber)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Vitamin A (%)", text: $vitaminA)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Vitamin C (%)", text: $vitaminC)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Calcium (%)", text: $calcium)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    TextField("Iron (%)", text: $iron)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal)
        }
        .transition(.opacity)
    }
    
    private var numberOfServingsRow: some View {
        HStack {
            Text("Number of Servings")
                .foregroundColor(.primary)
            Spacer()
            TextField("Servings", value: $numberOfServings, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
    
    // MARK: - Functions
    private func generateFoodWithAI() {
        guard !aiSearchText.isEmpty else { return }
        
        isCreating = true
        
        // Clear lastGeneratedFood BEFORE calling generateFoodWithAI to prevent triggering ConfirmFoodView sheet
        foodManager.lastGeneratedFood = nil
        
        foodManager.generateFoodWithAI(foodDescription: aiSearchText) { result in
            DispatchQueue.main.async {
                isCreating = false
                
                switch result {
                case .success(let food):
                    print("✅ Successfully generated food with AI for recipe: \(food.displayName)")
                    
                    // Clear lastGeneratedFood to prevent triggering other sheets
                    foodManager.lastGeneratedFood = nil
                    
                    // Clear the AI search text
                    aiSearchText = ""
                    
                    // Pass the food to parent and dismiss
                    onFoodAdded(food)
                    dismiss()
                    
                case .failure(let error):
                    // Clear lastGeneratedFood on error too
                    foodManager.lastGeneratedFood = nil
                    errorMessage = "Failed to generate food: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
    
    private func createFood() {
        guard !title.isEmpty, !calories.isEmpty else {
            errorMessage = "Title and calories are required"
            showErrorAlert = true
            return
        }
        
        guard let caloriesValue = Double(calories) else {
            errorMessage = "Calories must be a valid number"
            showErrorAlert = true
            return
        }
        
        isCreating = true
        
        let servingText = servingSize.isEmpty ? "1 serving" : servingSize
        
        var nutrients: [Nutrient] = [
            Nutrient(nutrientName: "Energy", value: caloriesValue, unitName: "kcal")
        ]
        
        // Add optional nutrients if provided
        if let proteinValue = Double(protein) {
            nutrients.append(Nutrient(nutrientName: "Protein", value: proteinValue, unitName: "g"))
        }
        
        if let carbsValue = Double(carbs) {
            nutrients.append(Nutrient(nutrientName: "Carbohydrate, by difference", value: carbsValue, unitName: "g"))
        }
        
        if let fatValue = Double(fat) {
            nutrients.append(Nutrient(nutrientName: "Total lipid (fat)", value: fatValue, unitName: "g"))
        }
        
        // Add all other nutrients if provided
        addNutrientIfPresent(name: "Saturated Fatty Acids", value: saturatedFat, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Polyunsaturated Fatty Acids", value: polyunsaturatedFat, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Monounsaturated Fatty Acids", value: monounsaturatedFat, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Trans Fatty Acids", value: transFat, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Cholesterol", value: cholesterol, unit: "mg", to: &nutrients)
        addNutrientIfPresent(name: "Sodium", value: sodium, unit: "mg", to: &nutrients)
        addNutrientIfPresent(name: "Potassium", value: potassium, unit: "mg", to: &nutrients)
        addNutrientIfPresent(name: "Sugar", value: sugar, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Fiber", value: fiber, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Vitamin A", value: vitaminA, unit: "%", to: &nutrients)
        addNutrientIfPresent(name: "Vitamin C", value: vitaminC, unit: "%", to: &nutrients)
        addNutrientIfPresent(name: "Calcium", value: calcium, unit: "%", to: &nutrients)
        addNutrientIfPresent(name: "Iron", value: iron, unit: "%", to: &nutrients)
        
        let servingUnit = "serving"
        
        let foodMeasure = FoodMeasure(
            disseminationText: servingText,
            gramWeight: 100.0,
            id: 1,
            modifier: servingText,
            measureUnitName: servingUnit,
            rank: 1
        )
        
        let brandText = brand.isEmpty ? nil : brand
        let food = Food(
            fdcId: Int.random(in: 1000000..<9999999),
            description: title,
            brandOwner: brandText,
            brandName: brandText,
            servingSize: 1.0,
            numberOfServings: numberOfServings,
            servingSizeUnit: servingUnit,
            householdServingFullText: servingText,
            foodNutrients: nutrients,
            foodMeasures: [foodMeasure]
        )
        
        // Clear lastGeneratedFood BEFORE calling createManualFood to prevent triggering ConfirmFoodView sheet
        foodManager.lastGeneratedFood = nil
        
        foodManager.createManualFood(food: food) { result in
            DispatchQueue.main.async {
                isCreating = false
                
                switch result {
                case .success(let createdFood):
                    // Clear lastGeneratedFood to prevent triggering other sheets
                    foodManager.lastGeneratedFood = nil
                    
                    print("✅ Food created successfully for recipe: \(createdFood.displayName)")
                    
                    onFoodAdded(createdFood)
                    dismiss()
                    
                case .failure(let error):
                    errorMessage = "Failed to create food: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
    
    private func addNutrientIfPresent(name: String, value: String, unit: String, to nutrients: inout [Nutrient]) {
        if let doubleValue = Double(value), doubleValue > 0 {
            nutrients.append(Nutrient(nutrientName: name, value: doubleValue, unitName: unit))
        }
    }
}

#Preview {
    CreateAddFoodView { food in
        print("Food added: \(food.displayName)")
    }
}
