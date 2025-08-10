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
    
    // Health analysis state
    @State private var healthAnalysis: HealthAnalysis? = nil
    @State private var showPerServing: Bool = true // true = per serving, false = per 100g/100ml
    @State private var isLiquid: Bool = false // Detect if it's a beverage
    @State private var expandedNegativeIndex: Int? = nil
    @State private var expandedPositiveIndex: Int? = nil
    
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
        
        // Detect if it's a liquid based on name or serving unit
        let name = food.description.lowercased()
        let unit = (food.servingSizeUnit ?? "").lowercased()
        self._isLiquid = State(initialValue: 
            name.contains("cola") || name.contains("pepsi") || name.contains("soda") || 
            name.contains("juice") || name.contains("drink") || name.contains("beverage") ||
            name.contains("milk") || name.contains("water") || name.contains("coffee") ||
            name.contains("tea") || name.contains("can") || name.contains("bottle") ||
            unit.contains("ml") || unit.contains("fl") || unit.contains("oz")
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Basic food info card
                basicInfoCard
                
                // Health analysis section (moved above nutrition facts)
                healthAnalysisCard
                
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
        .onAppear {
            setupHealthAnalysis()
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
        // .onAppear {
        //     // Auto-focus the servings field when the view appears
        //     DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //         isServingsFocused = true
        //     }
        // }

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
                
                // Divider
                Divider()
                    .padding(.leading, 16)
                
                // Calories Row
                caloriesRowView
                
                // Divider 
                Divider()
                    .padding(.leading, 16)
                
                // Health Score Row
                healthScoreRowView
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
    
    private var caloriesRowView: some View {
        HStack {
            Text("Calories")
                .foregroundColor(.primary)
            Spacer()
            Text(calories.isEmpty ? "0" : calories)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding()
    }
    
    private var healthScoreRowView: some View {
        HStack {
            Text("Health Score")
                .foregroundColor(.primary)
            Spacer()
            if let health = healthAnalysis {
                Text("\(health.score)/100")
                    .foregroundColor(healthColor(for: health.color))
                    .fontWeight(.medium)
            } else {
                Text("Not available")
                    .foregroundColor(.secondary)
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
    
    // MARK: - Health Analysis Card
    private var healthAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("iosnp"))
                
                VStack(spacing: 0) {
                    if let health = healthAnalysis {
                                // Compute which facets to show for the current toggle
                                let negs: [HealthFacet] = health.negatives

                                let poss: [HealthFacet] = health.positives

                                // Negatives section
                                if !negs.isEmpty {
                                    VStack(spacing: 0) {
                                        // Header
                                        HStack {
                                            Text("Negatives")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                            Spacer()
                                            Button(action: {
                                                showPerServing.toggle()
                                            }) {
                                                HStack(spacing: 4) {
                                                    Text(showPerServing ?
                                                        "per serving (\(servingSize))" :
                                                        (isLiquid ? "per 100ml" : "per 100g"))
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Image(systemName: "arrow.left.arrow.right")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                        .padding(.bottom, 12)

                                        ForEach(Array(negs.enumerated()), id: \.offset) { index, facet in
                                            VStack(spacing: 0) {
                                                HStack(alignment: .center, spacing: 12) {
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(Color.gray.opacity(0.1))
                                                            .frame(width: 40, height: 40)
                                                        Image(systemName: iconForNegative(facet))
                                                            .font(.system(size: 20))
                                                            .foregroundColor(.primary)
                                                    }
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(facet.title).font(.body).fontWeight(.medium)
                                                        Text(facet.subtitle).font(.caption).foregroundColor(.secondary)
                                                    }
                                                    Spacer()
                                                    HStack(spacing: 8) {
                                                        Text(valueForFacet(facet))
                                                            .font(.body).fontWeight(.medium)
                                                        Circle().fill(Color.red).frame(width: 12, height: 12)
                                                        Image(systemName: expandedNegativeIndex == index ? "chevron.up" : "chevron.down")
                                                            .font(.caption).foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.horizontal, 16).padding(.vertical, 12)
                                                .background(Color.clear)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    withAnimation(.easeInOut(duration: 0.3)) {
                                                        expandedNegativeIndex = (expandedNegativeIndex == index) ? nil : index
                                                    }
                                                }

                                                if expandedNegativeIndex == index {
                                                    VStack(spacing: 8) {
                                                        negativeRangeView(for: facet)
                                                    }
                                                    .padding(.horizontal, 16).padding(.bottom, 12)
                                                    .transition(.opacity.combined(with: .slide))
                                                }

                                                if index < negs.count - 1 {
                                                    Divider().padding(.leading, 68)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Divider only if both sections exist
                                if !poss.isEmpty && !negs.isEmpty {
                                    Divider().padding(.vertical, 8)
                                }

                                // Positives section
                                if !poss.isEmpty {
                                    VStack(spacing: 0) {
                                        // Header
                                        HStack {
                                            Text("Positives")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                            Spacer()
                                            Button(action: {
                                                showPerServing.toggle()
                                            }) {
                                                HStack(spacing: 4) {
                                                    Text(showPerServing ?
                                                        "per serving (\(servingSize))" :
                                                        (isLiquid ? "per 100ml" : "per 100g"))
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Image(systemName: "arrow.left.arrow.right")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, negs.isEmpty ? 16 : 8)
                                        .padding(.bottom, 12)

                                        ForEach(Array(poss.enumerated()), id: \.offset) { index, facet in
                                            VStack(spacing: 0) {
                                                HStack(alignment: .center, spacing: 12) {
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(Color.gray.opacity(0.1))
                                                            .frame(width: 40, height: 40)
                                                        Image(systemName: iconForPositive(facet))
                                                            .font(.system(size: 20))
                                                            .foregroundColor(.primary)
                                                    }
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(facet.title).font(.body).fontWeight(.medium)
                                                        Text(facet.subtitle).font(.caption).foregroundColor(.secondary)
                                                    }
                                                    Spacer()
                                                    HStack(spacing: 8) {
                                                        Text(valueForFacet(facet))
                                                            .font(.body).fontWeight(.medium)
                                                        Circle().fill(Color.green).frame(width: 12, height: 12)
                                                        Image(systemName: expandedPositiveIndex == index ? "chevron.up" : "chevron.down")
                                                            .font(.caption).foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.horizontal, 16).padding(.vertical, 12)
                                                .background(Color.clear)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    withAnimation(.easeInOut(duration: 0.3)) {
                                                        expandedPositiveIndex = (expandedPositiveIndex == index) ? nil : index
                                                    }
                                                }

                                                if expandedPositiveIndex == index {
                                                    VStack(spacing: 8) {
                                                        positiveRangeView(for: facet)
                                                    }
                                                    .padding(.horizontal, 16).padding(.bottom, 12)
                                                    .transition(.opacity.combined(with: .slide))
                                                }

                                                if index < poss.count - 1 {
                                                    Divider().padding(.leading, 68)
                                                }
                                            }
                                        }
                                        .padding(.bottom, 16)
                                    }
                                }
                            } else {
                                Text("Health analysis unavailable")
                                    .foregroundColor(.secondary)
                                    .padding()
                            }

                }
            }
        }
        .padding(.horizontal)
    }
    

private func setupHealthAnalysis() {
    guard let food = originalFood else { return }
    self.healthAnalysis = food.healthAnalysis
    self.isLiquid = food.healthAnalysis?.isBeverage ?? false
}


    
    private func healthColor(for colorName: String) -> Color {
        switch colorName.lowercased() {
        case "dark_green":
            return Color.green
        case "light_green":
            return Color.mint
        case "orange":
            return Color.orange
        case "red":
            return Color.red
        default:
            return Color.gray
        }
    }
    
    private func healthColorDisplayName(for colorName: String) -> String {
        switch colorName.lowercased() {
        case "dark_green":
            return "Excellent"
        case "light_green":
            return "Good"
        case "orange":
            return "Fair"
        case "red":
            return "Poor"
        default:
            return "Unknown"
        }
    }
    
    private func additiveRiskColor(for risk: String) -> Color {
        switch risk.lowercased() {
        case "limited":
            return Color.green
        case "moderate":
            return Color.orange
        case "high":
            return Color.red
        default:
            return Color.gray
        }
    }


    // MARK: - Facet helpers

private func valueForFacet(_ facet: HealthFacet) -> String {
    guard let health = healthAnalysis else { return "—" }
    let vals = showPerServing ? health.perServingValues : health.per100Values

    func fmt(_ v: Double, _ unit: String) -> String {
        let adj = showPerServing ? (v * numberOfServings) : v
        return "\(Int(round(adj)))\(unit)"
    }

    switch facet.id {
    // sugar
    case "too_sugary", "a_bit_sugary", "low_sugar", "no_sugar":
        return fmt(vals?.sugars_g ?? 0, "g")
    // sodium
    case "too_salty", "a_bit_salty", "low_sodium", "no_sodium":
        return fmt(vals?.sodium_mg ?? 0, "mg")
    // saturated fat
    case "too_much_sat_fat", "high_sat_fat", "low_sat_fat", "no_sat_fat":
        return fmt(vals?.saturated_fat_g ?? 0, "g")
    // calories
    case "too_caloric", "a_bit_caloric", "high_cal_density", "low_calories", "low_impact_cal":
        return fmt(vals?.energy_kcal ?? 0, " Cal")
    // fiber / protein
    case "some_fiber", "high_fiber":
        return fmt(vals?.fiber_g ?? 0, "g")
    case "some_protein", "high_protein":
        return fmt(vals?.protein_g ?? 0, "g")
    // additives
    case "ultra_processed", "risky_additives", "no_additives":
        return "\(health.additives?.count ?? 0)"
    default:
        return "—"
    }
}



private func iconForNegative(_ facet: HealthFacet) -> String {
  switch facet.id {
  case "too_sugary", "a_bit_sugary": return "cube"
  case "too_salty", "a_bit_salty":   return "aqi.low"
  case "too_much_sat_fat", "high_sat_fat": return "drop"
  case "too_caloric", "a_bit_caloric", "high_cal_density": return "flame"
  case "ultra_processed", "risky_additives": return "flask"
  default: return "exclamationmark.circle"
  }
}

private func iconForPositive(_ facet: HealthFacet) -> String {
  switch facet.id {
  case "no_sat_fat", "low_sat_fat":      return "drop"
  case "low_sodium", "no_sodium":        return "aqi.low"
  case "low_sugar", "no_sugar":          return "cube"
  case "some_fiber", "high_fiber":       return "leaf"
  case "some_protein", "high_protein":   return "bolt"
  case "low_calories", "low_impact_cal": return "flame"
  case "organic":                        return "leaf.circle"
  case "no_additives":                   return "checkmark.seal"
  default:                               return "checkmark.circle"
  }
}




// MARK: - Build health-analysis payload from Food
private func buildHealthPayload(from food: Food) -> [String: Any] {
    func bestGramWeight(_ food: Food) -> Double? {
        // try the USDA measure’s gram weight first
        food.foodMeasures.first?.gramWeight
    }
    func bestMlVolume(_ food: Food) -> Double? {
        // very rough fallback: if serving unit is fl oz, convert to ml
        if let unit = food.servingSizeUnit?.lowercased(),
           let size = food.servingSize {
            if unit.contains("ml") { return size }
            if unit.contains("fl") || unit.contains("oz") { return size * 29.5735 }
        }
        return nil
    }

    let name = food.description.lowercased()
    let unit = (food.servingSizeUnit ?? "").lowercased()
    let isBeverage =
        name.contains("water") || name.contains("sparkling") || name.contains("soda") ||
        name.contains("cola")  || name.contains("juice")     || name.contains("drink") ||
        name.contains("beverage") || name.contains("tea")    || name.contains("coffee") ||
        unit.contains("ml") || unit.contains("fl") || unit.contains("oz")

    // your “base” values are already per serving
    let perServing: [String: Any?] = [
        "per_basis": "per_serving",
        "serving_g": isBeverage ? nil : (food.servingSizeUnit?.lowercased().contains("g") == true
                                         ? food.servingSize : bestGramWeight(food)),
        "serving_ml": isBeverage ? (food.servingSizeUnit?.lowercased().contains("ml") == true
                                    ? food.servingSize : bestMlVolume(food)) : nil,
        "product_name": food.description,

        "energy_kcal": baseCalories,
        "protein_g": baseProtein,
        "saturated_fat_g": baseSaturatedFat,
        "sugars_g": baseSugar,
        "sodium_mg": baseSodium,
        "fiber_g": baseFiber,

        "is_beverage": isBeverage,
        // mark as snack for chips/puffs/strips/bars
        "is_snack": name.contains("chip") || name.contains("puff") ||
                    name.contains("straw") || name.contains("bar")
    ]
    // strip nils
    return perServing.compactMapValues { $0 }
}





    
    private func getNegativeTitle(_ negative: String) -> String {
        if negative.lowercased().contains("additive") {
            return "Additives"
        } else if negative.lowercased().contains("calor") {
            return "Calories"
        } else if negative.lowercased().contains("sugar") || negative.lowercased().contains("sweet") {
            return "Sugar"
        } else if negative.lowercased().contains("sodium") || negative.lowercased().contains("salt") {
            return "Sodium"
        } else if negative.lowercased().contains("fat") {
            return "Saturated fat"
        } else {
            // Try to extract the nutrient name from the negative text
            return negative.components(separatedBy: " ").first ?? "Nutrient"
        }
    }
    
    private func getNegativeSubtitle(_ negative: String) -> String {
        if negative.lowercased().contains("additive") {
            return "Contains additives to avoid"
        } else if negative.lowercased().contains("calor") {
            return "Too caloric"
        } else if negative.lowercased().contains("sugar") || negative.lowercased().contains("sweet") {
            return "Too sweet"
        } else if negative.lowercased().contains("sodium") || negative.lowercased().contains("salt") {
            return "Too much sodium"
        } else if negative.lowercased().contains("fat") {
            return "High saturated fat"
        } else {
            return negative // Use the full negative text as subtitle
        }
    }
    
    private func getNegativeValue(_ negative: String) -> String {
        // Try to extract numeric value from the negative text
        if negative.lowercased().contains("additive") {
            // Count number of additives mentioned
            if let additives = healthAnalysis?.additives {
                return "\(additives.count)"
            }
            return "2"
        } else if negative.lowercased().contains("calor") {
            return "\(Int(baseCalories)) Cal"
        } else if negative.lowercased().contains("sugar") {
            return "\(Int(baseSugar))g"
        } else if negative.lowercased().contains("sodium") {
            return "\(Int(baseSodium))mg"
        } else if negative.lowercased().contains("fat") {
            return "\(Int(baseSaturatedFat))g"
        } else {
            // Try to extract any number from the text
            let numbers = negative.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if let firstNumber = numbers.first {
                return "\(firstNumber)"
            }
            return "—"
        }
    }
    
    private func getPositiveTitle(_ positive: String) -> String {
        if positive.lowercased().contains("fat") {
            return "Saturated fat"
        } else if positive.lowercased().contains("sodium") {
            return "Sodium"
        } else {
            return "Good"
        }
    }
    
    private func getPositiveSubtitle(_ positive: String) -> String {
        if positive.lowercased().contains("fat") {
            return "No saturated fat"
        } else if positive.lowercased().contains("sodium") {
            return "Low sodium"
        } else {
            return "Positive aspect"
        }
    }
    
    private func getPositiveValue(_ positive: String) -> String {
        if positive.lowercased().contains("fat") {
            return "\(Int(baseSaturatedFat))g"
        } else if positive.lowercased().contains("sodium") {
            return "\(Int(baseSodium))mg"
        } else if positive.lowercased().contains("fiber") {
            return "\(Int(baseFiber))g"
        } else if positive.lowercased().contains("protein") {
            return "\(Int(baseProtein))g"
        } else {
            // Try to extract any number from the text
            let numbers = positive.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if let firstNumber = numbers.first {
                return "\(firstNumber)"
            }
            return "—"
        }
    }
    
    // MARK: - Range Visualization Functions
    // MARK: - Range Visualization (driven by backend thresholds)

private enum NutrientKey: String {
    case energy_kcal, sugars_g, sodium_mg, sat_fat_g, fiber_g, protein_g
}

private func nutrientKey(for facet: HealthFacet) -> NutrientKey? {
    switch facet.id {
    case "too_sugary", "a_bit_sugary", "low_sugar", "no_sugar":
        return .sugars_g
    case "too_salty", "a_bit_salty", "low_sodium", "no_sodium":
        return .sodium_mg
    case "too_much_sat_fat", "high_sat_fat", "low_sat_fat", "no_sat_fat":
        return .sat_fat_g
    case "too_caloric", "a_bit_caloric", "low_calories", "low_impact_cal", "high_cal_density":
        return .energy_kcal
    case "some_fiber", "high_fiber":
        return .fiber_g
    case "some_protein", "high_protein":
        return .protein_g
    default:
        return nil
    }
}

private func currentValue(for key: NutrientKey) -> Double {
    guard let health = healthAnalysis else { return 0 }
    let vals = showPerServing ? health.perServingValues : health.per100Values

    let raw: Double = {
        switch key {
        case .energy_kcal: return vals?.energy_kcal ?? 0
        case .sugars_g:    return vals?.sugars_g ?? 0
        case .sodium_mg:   return vals?.sodium_mg ?? 0
        case .sat_fat_g:   return vals?.saturated_fat_g ?? 0
        case .fiber_g:     return vals?.fiber_g ?? 0
        case .protein_g:   return vals?.protein_g ?? 0
        }
    }()

    return showPerServing ? raw * numberOfServings : raw
}

private func activeThresholds(for key: NutrientKey) -> [Double] {
    guard let health = healthAnalysis else { return [] }
    if showPerServing {
        switch key {
        case .sugars_g:    return health.thresholds?.per_serving.sugars_g ?? []
        case .sodium_mg:   return health.thresholds?.per_serving.sodium_mg ?? []
        case .energy_kcal: return health.thresholds?.per_serving.energy_kcal ?? []
        case .sat_fat_g:   return health.thresholds?.per_serving.sat_fat_g ?? []
        case .fiber_g:     return health.thresholds?.per100_g.fiber_g ?? []   // no per-serving fiber scale; per-100 shown for context
        case .protein_g:   return health.thresholds?.per100_g.protein_g ?? [] // same
        }
    } else {
        // per 100 basis
        if isLiquid {
            switch key {
            case .sugars_g:    return health.thresholds?.per100_ml.sugars_g ?? []
            case .sodium_mg:   return health.thresholds?.per100_ml.sodium_mg ?? []
            case .energy_kcal: return health.thresholds?.per100_ml.energy_kcal ?? []
            case .sat_fat_g:   return health.thresholds?.per100_g.sat_fat_g ?? []
            case .fiber_g:     return health.thresholds?.per100_g.fiber_g ?? []
            case .protein_g:   return health.thresholds?.per100_g.protein_g ?? []
            }
        } else {
            switch key {
            case .sugars_g:    return health.thresholds?.per100_g.sugars_g ?? []
            case .sodium_mg:   return health.thresholds?.per100_g.sodium_mg ?? []
            case .energy_kcal:
                // backend sends energy_kj for foods; convert to kcal
                let kj = health.thresholds?.per100_g.energy_kj ?? []
                return kj.map { $0 / 4.184 }
            case .sat_fat_g:   return health.thresholds?.per100_g.sat_fat_g ?? []
            case .fiber_g:     return health.thresholds?.per100_g.fiber_g ?? []
            case .protein_g:   return health.thresholds?.per100_g.protein_g ?? []
            }
        }
    }
}

private func unit(for key: NutrientKey) -> String {
    switch key {
    case .sodium_mg:   return "mg"
    case .energy_kcal: return "Cal"
    default:           return "g"
    }
}
@ViewBuilder
private func negativeRangeView(for facet: HealthFacet) -> some View {
    if let key = nutrientKey(for: facet) {
        dynamicRange(for: key)
    } else {
        Text("Range visualization unavailable")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

@ViewBuilder
private func positiveRangeView(for facet: HealthFacet) -> some View {
    if let key = nutrientKey(for: facet) {
        dynamicRange(for: key)
    } else {
        Text("Range visualization unavailable")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}


@ViewBuilder
private func dynamicRange(for key: NutrientKey) -> some View {
    let value = currentValue(for: key)
    let th    = activeThresholds(for: key)
    let unit  = unit(for: key)

    if th.isEmpty {
        Text("Range unavailable").font(.caption).foregroundColor(.secondary)
    } else {
        let segments = buildSegments(from: th)
        rangeBarView(currentValue: value, segments: segments, unit: unit)
    }
}

/// Build color stops from threshold arrays:
/// - 11-point scales (per-100 negative nutrients): [0..2]=greens, [3..5]=orange, [6..]=red
/// - 4-point serving scales: [g, mint, orange, red]
/// - 3-point serving scales: [mint, orange, red]
private func buildSegments(from thresholds: [Double]) -> [(threshold: Double, color: Color)] {
    // 11-point arrays have 10 bounds
    if thresholds.count >= 10 {
        let last = thresholds.last!
        return [
            (thresholds[1], .green),
            (thresholds[2], .mint),
            (thresholds[5], .orange),
            (last,         .red)
        ]
    }
    // 4-point serving scales
    if thresholds.count == 4 {
        return [
            (thresholds[0], .green),
            (thresholds[1], .mint),
            (thresholds[2], .orange),
            (thresholds[3], .red),
        ]
    }
    // 3-point serving scales
    if thresholds.count == 3 {
        return [
            (thresholds[0], .mint),
            (thresholds[1], .orange),
            (thresholds[2], .red),
        ]
    }
    // Fallback: single stop -> red
    return [(thresholds.last ?? 1, .red)]
}

private func rangeBarView(currentValue: Double,
                          segments: [(threshold: Double, color: Color)],
                          unit: String) -> some View {
    let maxValue = max(segments.last?.threshold ?? 1, currentValue)
    let stops: [Gradient.Stop] = {
        var arr: [Gradient.Stop] = [.init(color: .green, location: 0.0)]
        for s in segments {
            let loc = CGFloat(min(max(s.threshold / maxValue, 0), 1))
            arr.append(.init(color: s.color, location: loc))
        }
        return arr
    }()

    return VStack(spacing: 8) {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                LinearGradient(gradient: Gradient(stops: stops),
                               startPoint: .leading,
                               endPoint: .trailing)
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                let pos = min(currentValue / maxValue, 1.0) * geometry.size.width
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                    .offset(x: pos - 5, y: -4)
            }
        }
        .frame(height: 8)

        HStack {
            Text("0").font(.caption2).foregroundColor(.secondary)
            Spacer()
           ForEach(Array(segments.dropLast().enumerated()), id: \.offset) { _, s in
    Text(String(format: s.threshold < 10 ? "%.1f" : "%.0f", s.threshold))
        .font(.caption2)
        .foregroundColor(.secondary)
    Spacer()
}

Text("\(String(format: maxValue < 10 ? "%.1f" : "%.0f", maxValue)) \(unit)")


                .font(.caption2).foregroundColor(.secondary)
        }
    }
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


