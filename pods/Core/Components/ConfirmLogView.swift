//
//  ConfirmLogView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/17/25.
//

import SwiftUI

struct ConfirmLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var viewModel: OnboardingViewModel
    
    @Binding var path: NavigationPath
    
    // Basic food info
    @State private var title: String = ""
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
    
    // Brand information
    @State private var brand: String = ""
    
    // UI states
    @State private var isCreating: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // Focus state for auto-focusing the servings field
    @FocusState private var isServingsFocused: Bool
    
    // New properties for barcode flow
    @State private var isBarcodeFood: Bool = false
    @State private var originalFood: Food? = nil
    @State private var barcodeFoodLogId: Int? = nil
    @State private var servingUnit: String = "serving"

    // NEW: Base nutrition values (per single serving)
    @State private var baseCalories: Double = 0
    @State private var baseProtein: Double = 0
    @State private var baseCarbs: Double = 0
    @State private var baseFat: Double = 0
    @State private var baseSaturatedFat: Double = 0
    @State private var basePolyunsaturatedFat: Double = 0
    @State private var baseMonounsaturatedFat: Double = 0
    @State private var baseTransFat: Double = 0
    @State private var baseCholesterol: Double = 0
    @State private var baseSodium: Double = 0
    @State private var basePotassium: Double = 0
    @State private var baseSugar: Double = 0
    @State private var baseFiber: Double = 0
    @State private var baseVitaminA: Double = 0
    @State private var baseVitaminC: Double = 0
    @State private var baseCalcium: Double = 0
    @State private var baseIron: Double = 0

    @EnvironmentObject private var dayLogsVM: DayLogsViewModel
    
    // NEW: Add a flag to distinguish between creation and logging modes
    @State private var isCreationMode: Bool = false  // Always false for this view
    
    // This view is ONLY for logging scanned foods
    init(path: Binding<NavigationPath>, food: Food, foodLogId: Int? = nil) {
        print("🔍 DEBUG ConfirmLogView: Initializing with food: \(food.description), fdcId: \(food.fdcId)")
        print("🔍 DEBUG ConfirmLogView: foodLogId: \(String(describing: foodLogId))")
        self._path = path
        self._title = State(initialValue: food.description)
        
        // Debug print full barcode food response
        print("====== BARCODE FOOD API RESPONSE ======")
        print("Food ID: \(food.fdcId)")
        print("Description: \(food.description)")
        print("Brand: \(food.brandName ?? "N/A")")
        print("Serving Size: \(food.servingSize ?? 0)")
        print("Serving Size Unit: \(food.servingSizeUnit ?? "N/A")")
        print("Household Serving Text: \(food.householdServingFullText ?? "N/A")")
        print("Number of Servings: \(food.numberOfServings ?? 1)")
        
        // Print food measures for more details about serving options
        print("\nFood Measures:")
        if !food.foodMeasures.isEmpty {
            for (index, measure) in food.foodMeasures.enumerated() {
                print("  Measure \(index + 1):")
                print("    - Text: \(measure.disseminationText ?? "N/A")")
                print("    - Modifier: \(measure.modifier ?? "N/A")")
                print("    - Unit: \(measure.measureUnitName ?? "N/A")")
                print("    - Gram Weight: \(measure.gramWeight ?? 0)")
            }
        } else {
            print("  No measures available")
        }
        
        // Print all nutrients for debugging
        print("\nAll Nutrients:")
        for nutrient in food.foodNutrients {
            print("  \(nutrient.nutrientName): \(nutrient.value ?? 0) \(nutrient.unitName ?? "")")
        }
        
        print("\nRaw Food Object:")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(food), 
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        } else {
            print("Could not encode food object to JSON")
        }
        
        
        // Set serving size information
        if let servingSize = food.servingSize, let unit = food.servingSizeUnit {
            self._servingSize = State(initialValue: "\(servingSize) \(unit)")
            self._servingUnit = State(initialValue: unit)
        } else if let servingText = food.householdServingFullText {
            self._servingSize = State(initialValue: servingText)
        }
        
        // Set number of servings (default to 1 if nil)
        self._numberOfServings = State(initialValue: food.numberOfServings ?? 1)
        
        // Calculate nutrition value variables without modifying state directly
        var tmpCalories: Double = 0
        var tmpProtein: Double = 0
        var tmpCarbs: Double = 0
        var tmpFat: Double = 0
        
        // Extract nutrient values directly from food.foodNutrients
        for nutrient in food.foodNutrients {
            if nutrient.nutrientName == "Energy" {
                tmpCalories = nutrient.value ?? 0
            }
            if nutrient.nutrientName == "Protein" {
                tmpProtein = nutrient.value ?? 0
            }
            if nutrient.nutrientName == "Carbohydrate, by difference" {
                tmpCarbs = nutrient.value ?? 0
            }
            if nutrient.nutrientName == "Total lipid (fat)" {
                tmpFat = nutrient.value ?? 0
            }
        }
        
        // Now set the base values and string display values
        self._baseCalories = State(initialValue: tmpCalories)
        self._baseProtein = State(initialValue: tmpProtein)
        self._baseCarbs = State(initialValue: tmpCarbs)
        self._baseFat = State(initialValue: tmpFat)
        
        // Set the string values for display
        self._calories = State(initialValue: String(format: "%.1f", tmpCalories))
        self._protein = State(initialValue: String(format: "%.1f", tmpProtein))
        self._carbs = State(initialValue: String(format: "%.1f", tmpCarbs))
        self._fat = State(initialValue: String(format: "%.1f", tmpFat))
        
        // Set additional nutrients
        for nutrient in food.foodNutrients {
            switch nutrient.nutrientName {
            case "Fatty acids, total saturated":
                self._baseSaturatedFat = State(initialValue: nutrient.value ?? 0)
                self._saturatedFat = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Fatty acids, total polyunsaturated":
                self._basePolyunsaturatedFat = State(initialValue: nutrient.value ?? 0)
                self._polyunsaturatedFat = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Fatty acids, total monounsaturated":
                self._baseMonounsaturatedFat = State(initialValue: nutrient.value ?? 0)
                self._monounsaturatedFat = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Fatty acids, total trans":
                self._baseTransFat = State(initialValue: nutrient.value ?? 0)
                self._transFat = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Cholesterol":
                self._baseCholesterol = State(initialValue: nutrient.value ?? 0)
                self._cholesterol = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Sodium, Na":
                self._baseSodium = State(initialValue: nutrient.value ?? 0)
                self._sodium = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Potassium, K":
                self._basePotassium = State(initialValue: nutrient.value ?? 0)
                self._potassium = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Sugars, total including NLEA":
                self._baseSugar = State(initialValue: nutrient.value ?? 0)
                self._sugar = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Fiber, total dietary":
                self._baseFiber = State(initialValue: nutrient.value ?? 0)
                self._fiber = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Vitamin A, RAE":
                self._baseVitaminA = State(initialValue: nutrient.value ?? 0)
                self._vitaminA = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Vitamin C, total ascorbic acid":
                self._baseVitaminC = State(initialValue: nutrient.value ?? 0)
                self._vitaminC = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Calcium, Ca":
                self._baseCalcium = State(initialValue: nutrient.value ?? 0)
                self._calcium = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            case "Iron, Fe":
                self._baseIron = State(initialValue: nutrient.value ?? 0)
                self._iron = State(initialValue: String(format: "%.1f", nutrient.value ?? 0))
            default:
                break
            }
        }
        
        // Set flags for barcode food
        self.isBarcodeFood = true
        self.isCreationMode = false // This is for logging
        self._originalFood = State(initialValue: food)
        self._barcodeFoodLogId = State(initialValue: foodLogId)
    }
    
    var body: some View {
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
                Text("Log Food")
                    .font(.headline)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: logBarcodeFood) {
                    Text("Log")
                        .fontWeight(.semibold)
                }
                .disabled(isCreating)
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.accentColor)
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
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
        .onAppear {
            // Auto-focus the servings field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isServingsFocused = true
            }
        }

    }
    
    // MARK: - Card Views
    private var basicInfoCard: some View {
        ZStack(alignment: .top) {
            // Background with rounded corners
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("iosnp"))
            
            // Content
            VStack(spacing: 0) {
                // Title
                TextField("Title", text: $title)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                
                // Divider
                Divider()
                    .padding(.leading, 16)
                
                // Serving Size Row - with label on left and input on right
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
                .focused($isServingsFocused)
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
                    // Calories (read-only)
                    HStack {
                        Text("Calories")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(calories.isEmpty ? "0" : calories)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Protein (read-only)
                    HStack {
                        Text("Protein (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(protein.isEmpty ? "0" : protein)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Carbs (read-only)
                    HStack {
                        Text("Carbs (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(carbs.isEmpty ? "0" : carbs)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Fat (read-only)
                    HStack {
                        Text("Total Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(fat.isEmpty ? "0" : fat)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal)
            
            // Show More Nutrients button
            Button(action: {
                withAnimation {
                    showMoreNutrients.toggle()
                }
            }) {
                HStack {
                    Text(showMoreNutrients ? "Hide Additional Nutrients" : "Show More Nutrients")
                        .foregroundColor(.accentColor)
                    
                    Image(systemName: showMoreNutrients ? "chevron.up" : "chevron.down")
                        .foregroundColor(.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 14)
                .background(Color("iosnp"))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    private var additionalNutrientsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .top) {
                // Background with rounded corners
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("iosnp"))
                
                // Content
                VStack(spacing: 0) {
                    // Saturated Fat
                    HStack {
                        Text("Saturated Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(saturatedFat.isEmpty ? "0" : saturatedFat)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Polyunsaturated Fat
                    HStack {
                        Text("Polyunsaturated Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(polyunsaturatedFat.isEmpty ? "0" : polyunsaturatedFat)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Monounsaturated Fat
                    HStack {
                        Text("Monounsaturated Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(monounsaturatedFat.isEmpty ? "0" : monounsaturatedFat)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Trans Fat
                    HStack {
                        Text("Trans Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(transFat.isEmpty ? "0" : transFat)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Cholesterol
                    HStack {
                        Text("Cholesterol (mg)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(cholesterol.isEmpty ? "0" : cholesterol)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Sodium
                    HStack {
                        Text("Sodium (mg)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(sodium.isEmpty ? "0" : sodium)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Potassium
                    HStack {
                        Text("Potassium (mg)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(potassium.isEmpty ? "0" : potassium)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Sugar
                    HStack {
                        Text("Sugar (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(sugar.isEmpty ? "0" : sugar)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Fiber
                    HStack {
                        Text("Fiber (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(fiber.isEmpty ? "0" : fiber)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Vitamin A
                    HStack {
                        Text("Vitamin A (%)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(vitaminA.isEmpty ? "0" : vitaminA)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Vitamin C
                    HStack {
                        Text("Vitamin C (%)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(vitaminC.isEmpty ? "0" : vitaminC)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Calcium
                    HStack {
                        Text("Calcium (%)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(calcium.isEmpty ? "0" : calcium)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Iron
                    HStack {
                        Text("Iron (%)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(iron.isEmpty ? "0" : iron)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal)
        }
        .transition(.opacity)
    }
    

    private func logBarcodeFood() {
    // 1. Validate inputs
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

    guard let food = originalFood else {
        errorMessage = "Original food data not found"
        showErrorAlert = true
        return
    }

    isCreating = true

    // 2. Compute adjusted food with user servings
    let originalServings = food.numberOfServings ?? 1
    let userServings     = numberOfServings
    var updatedFood      = food
    updatedFood.numberOfServings = userServings

    // 3. Fire the real network call
    foodManager.logFood(
        email:    viewModel.email,
        food:     updatedFood,
        meal:     "Lunch",                     // or pass in a variable
        servings: userServings,
        date:     Date(),
        notes:    nil
    ) { result in
        DispatchQueue.main.async {
            self.isCreating = false
            switch result {
            case .success(let logged):
                // 4. Build your CombinedLog from the server response
                let combined = CombinedLog(
                    type:            .food,
                    status:          logged.status,
                    calories:        Double(logged.food.calories),
                    message:         "\(logged.food.displayName) - \(logged.mealType)",
                    foodLogId:       logged.foodLogId,
                    food:            logged.food,
                    mealType:        logged.mealType,
                    mealLogId:       nil,
                    meal:            nil,
                    mealTime:        nil,
                    scheduledAt:     Date(),
                    recipeLogId:     nil,
                    recipe:          nil,
                    servingsConsumed:nil
                )

                // 5. Optimistically insert into today's view
                dayLogsVM.addPending(combined)

                // 6. Also insert into the global timeline, de-duplicating first
                if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combined.foodLogId }) {
                    foodManager.combinedLogs.remove(at: idx)
                }
                foodManager.combinedLogs.insert(combined, at: 0)

                // 7. Show the success toast
                foodManager.lastLoggedItem = (name: combined.food?.displayName ?? title,
                                              calories: combined.displayCalories)
                foodManager.showLogSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    foodManager.showLogSuccess = false
                }

                // 8. Finally dismiss
                dismiss()

            case .failure(let error):
                // 9. Show error to the user
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}

    
    // Helper method to calculate adjusted values based on number of servings
    private func calculateAdjustedValue(_ baseValue: Double, servings: Double) -> Double {
        return (baseValue * servings).rounded(toPlaces: 1)
    }
    
    // Update all nutrition values when number of servings changes
    private func updateNutritionValues() {
        // Update with formatted strings
        calories = String(format: "%.1f", baseCalories * numberOfServings)
        protein = String(format: "%.1f", baseProtein * numberOfServings)
        carbs = String(format: "%.1f", baseCarbs * numberOfServings)
        fat = String(format: "%.1f", baseFat * numberOfServings)
        
        // Update additional nutrients too with formatted strings
        saturatedFat = String(format: "%.1f", baseSaturatedFat * numberOfServings)
        polyunsaturatedFat = String(format: "%.1f", basePolyunsaturatedFat * numberOfServings)
        monounsaturatedFat = String(format: "%.1f", baseMonounsaturatedFat * numberOfServings)
        transFat = String(format: "%.1f", baseTransFat * numberOfServings)
        cholesterol = String(format: "%.1f", baseCholesterol * numberOfServings)
        sodium = String(format: "%.1f", baseSodium * numberOfServings)
        potassium = String(format: "%.1f", basePotassium * numberOfServings)
        sugar = String(format: "%.1f", baseSugar * numberOfServings)
        fiber = String(format: "%.1f", baseFiber * numberOfServings)
        vitaminA = String(format: "%.1f", baseVitaminA * numberOfServings)
        vitaminC = String(format: "%.1f", baseVitaminC * numberOfServings)
        calcium = String(format: "%.1f", baseCalcium * numberOfServings)
        iron = String(format: "%.1f", baseIron * numberOfServings)
    }
}


extension ConfirmLogView {
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


