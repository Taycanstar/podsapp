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
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared
    
    @Binding var path: NavigationPath
    
    // Basic food info
    @State private var title: String = ""
    @State private var servingSize: String = ""
    @State private var numberOfServings: Double = 1
    @State private var servingsInput: String = "1"
    @State private var calories: String = ""
    
    // Basic nutrition facts
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
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
    @State private var nutrientTargets: [String: NutrientTargetDetails] = [:]
    @State private var baseNutrientValues: [String: RawNutrientValue] = [:]

    // Meal + time selections
    @State private var selectedMealPeriod: MealPeriod = .lunch
    @State private var mealTime: Date = Date()
    
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
    @State private var expandedNegativeIndices: Set<Int> = []
    @State private var expandedPositiveIndices: Set<Int> = []
    @State private var aiInsight: String? = nil
    @State private var nutritionScore: Double? = nil
    
    private let showHealthInsights = false
    
    // This view is ONLY for logging scanned foods
    init(path: Binding<NavigationPath>, food: Food, foodLogId: Int? = nil) {
        print("🔍 DEBUG ConfirmLogView: Initializing with food: \(food.description), fdcId: \(food.fdcId)")
        print("🔍 DEBUG ConfirmLogView: foodLogId: \(String(describing: foodLogId))")
        self._path = path
        self._title = State(initialValue: food.description)
        self._aiInsight = State(initialValue: food.aiInsight)
        self._nutritionScore = State(initialValue: food.nutritionScore)
        
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
        // Prioritize householdServingFullText when available (more detailed format)
        if let servingText = food.householdServingFullText, !servingText.isEmpty {
        self._servingSize = State(initialValue: servingText)
        self._servingUnit = State(initialValue: food.servingSizeUnit ?? "serving")
    } else if let servingSize = food.servingSize, let unit = food.servingSizeUnit {
        // Format serving size to remove unnecessary decimal places (1.0 → 1, 1.5 → 1.5)
        let formattedSize = servingSize == floor(servingSize) ? String(Int(servingSize)) : String(servingSize)
            self._servingSize = State(initialValue: "\(formattedSize) \(unit)")
            self._servingUnit = State(initialValue: unit)
        }
        
        // Set number of servings (default to 1 if nil)
        let initialServings = food.numberOfServings ?? 1
        self._numberOfServings = State(initialValue: initialServings)
        self._servingsInput = State(initialValue: ConfirmLogView.formattedServings(initialServings))
        
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

        var nutrientDictionary: [String: RawNutrientValue] = [:]
        for nutrient in food.foodNutrients {
            if let value = nutrient.value {
                let key = ConfirmLogView.normalizedNutrientKey(nutrient.nutrientName)
                nutrientDictionary[key] = RawNutrientValue(value: value, unit: nutrient.unitName)
            }
        }
        self._baseNutrientValues = State(initialValue: nutrientDictionary)

        let nutrientTargets = NutritionGoalsStore.shared.currentTargets
        self._nutrientTargets = State(initialValue: nutrientTargets)
        
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

    private let proteinColor = Color("protein")
    private let fatColor = Color("fat")
    private let carbColor = Color("carbs")

    private var adjustedProtein: Double {
        calculateAdjustedValue(baseProtein, servings: numberOfServings)
    }

    private var adjustedCarbs: Double {
        calculateAdjustedValue(baseCarbs, servings: numberOfServings)
    }

    private var adjustedFat: Double {
        calculateAdjustedValue(baseFat, servings: numberOfServings)
    }

    private var adjustedFiber: Double {
        calculateAdjustedValue(baseFiber, servings: numberOfServings)
    }

    private var adjustedCalories: Double {
        calculateAdjustedValue(baseCalories, servings: numberOfServings)
    }

    private var macroSegments: [MacroSegment] {
        let proteinCalories = adjustedProtein * 4
        let carbCalories = adjustedCarbs * 4
        let fatCalories = adjustedFat * 9
        let total = max(proteinCalories + carbCalories + fatCalories, 1)
        return [
            MacroSegment(color: proteinColor, fraction: proteinCalories / total),
            MacroSegment(color: fatColor, fraction: fatCalories / total),
            MacroSegment(color: carbColor, fraction: carbCalories / total),
        ]
    }

    private var shouldShowGoalsLoader: Bool {
        nutrientTargets.isEmpty && goalsStore.isLoading
    }

    private var proteinGoalPercent: Double {
        guard dayLogsVM.proteinGoal > 0 else { return 0 }
        return (adjustedProtein / dayLogsVM.proteinGoal) * 100
    }

    private var fatGoalPercent: Double {
        guard dayLogsVM.fatGoal > 0 else { return 0 }
        return (adjustedFat / dayLogsVM.fatGoal) * 100
    }

    private var carbGoalPercent: Double {
        guard dayLogsVM.carbsGoal > 0 else { return 0 }
        return (adjustedCarbs / dayLogsVM.carbsGoal) * 100
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 0)
    
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    macroSummaryCard
                    portionDetailsCard
                    if let insight = aiInsight?.trimmingCharacters(in: .whitespacesAndNewlines), !insight.isEmpty {
                        aiInsightSection(insight: insight)
                    }
                    if showHealthInsights {
                        healthAnalysisCard
                    }
                    dailyGoalShareCard
                    if shouldShowGoalsLoader {
                        goalsLoadingView
                    } else if nutrientTargets.isEmpty {
                        missingTargetsCallout
                    } else {
                        totalCarbsSection
                        fatTotalsSection
                        proteinTotalsSection
                        vitaminSection
                        mineralSection
                        otherNutrientSection
                    }
                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            footerBar
        }
        .background(Color("iosbg").ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .onAppear {
            setupHealthAnalysis()
            goalsStore.ensureGoalsAvailable(email: viewModel.email, forceRefresh: false)
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
        .onReceive(dayLogsVM.$nutritionGoalsVersion) { _ in
            reloadStoredNutrientTargets()
        }
        .onReceive(goalsStore.$state) { _ in
            reloadStoredNutrientTargets()
        }
    }
    
    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)
            
            Button(action: logBarcodeFood) {
                Text(isCreating ? "Logging..." : "Log Food")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color("background"))
            )
            .foregroundColor(Color("text"))
            .disabled(isCreating)
            .opacity(isCreating ? 0.7 : 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
        .background(
            Color("iosbg")
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Card Views
    private var macroSummaryCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                macroStatRow(title: "Protein", value: adjustedProtein, unit: "g", color: proteinColor)
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Fat", value: adjustedFat, unit: "g", color: fatColor)
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Carbs", value: adjustedCarbs, unit: "g", color: carbColor)
            }
            
            Spacer()
            
            MacroRingView(calories: adjustedCalories, arcs: macroArcs)
                .frame(width: 100, height: 100)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(colors: [Color("iosnp"), Color("iosnp").opacity(0.8)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
        )
        .padding(.horizontal)
    }

    @ViewBuilder
    private func aiInsightSection(insight: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI Insight")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text(insight)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 22)

                if let score = nutritionScore {
                    insightScale(score: score)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color("iosnp"))
            )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func insightScale(score: Double) -> some View {
        let normalized = max(0, min(100, score))
        let labels = ["Limited", "Fair", "Good", "Nutritious"]

        VStack(spacing: 0) {
            GeometryReader { geo in
                HStack(spacing: 5) {
                    ForEach(0..<labels.count, id: \.self) { index in
                        Capsule()
                            .fill(indexForScore(normalized) == index ? segmentColor(for: index) : Color.primary.opacity(0.15))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
                .overlay(
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 18, height: 18)
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1.5)
                        )
                        .offset(x: sliderOffset(for: normalized, width: geo.size.width - 5 * CGFloat(labels.count - 1)), y: 0),
                    alignment: .leading
                )
            }
            .frame(height: 24)

            HStack {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func indexForScore(_ score: Double) -> Int {
        switch score {
        case ..<25: return 0
        case ..<50: return 1
        case ..<75: return 2
        default: return 3
        }
    }

    private func segmentColor(for index: Int) -> Color {
        switch index {
        case 0: return Color("limited")
        case 1: return Color("fair")
        case 2: return Color("good")
        default: return Color("nut")
        }
    }

    private func sliderOffset(for score: Double, width: CGFloat) -> CGFloat {
        let clamped = max(0, min(100, score)) / 100
        let availableWidth = max(0, width - 18)
        return CGFloat(clamped) * availableWidth
    }
    
    private var macroArcs: [MacroArc] {
        var running: Double = 0
        return macroSegments.map { segment in
            let arc = MacroArc(start: running, end: running + segment.fraction, color: segment.color)
            running += segment.fraction
            return arc
        }
    }

    private var headerBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                
                Text(title.isEmpty ? "Log Food" : title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                Button(action: logBarcodeFood) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .disabled(isCreating)
                .opacity(isCreating ? 0.5 : 1)
            }
            Divider()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, -16)
        }
    }
    
    private func macroStatRow(title: String, value: Double, unit: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            Text(title.capitalized)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            Text("\(value.cleanOneDecimal)\(unit)")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var portionDetailsCard: some View {
        VStack(spacing: 0) {
            labeledRow("Serving Size") {
                TextField("e.g., 1 cup, 2 tbsp", text: $servingSize)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            
            Divider().padding(.leading, 16)
            
            labeledRow("Servings") {
                TextField("Enter servings (e.g., 1.5 or 1/2)", text: $servingsInput)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .focused($isServingsFocused)
                    .onChange(of: servingsInput) { newValue in
                        guard let parsed = parseServingsInput(newValue) else { return }
                        if abs(parsed - numberOfServings) > 0.0001 {
                            numberOfServings = parsed
                            updateNutritionValues()
                        }
                    }
            }
            
            Divider().padding(.leading, 16)
            
            labeledRow("Time", verticalPadding: 6) {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(MealPeriod.allCases) { period in
                            Button(period.title) {
                                selectedMealPeriod = period
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedMealPeriod.title)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color("iosnp"))
                    .cornerRadius(12)
                    
                    capsulePill {
                        DatePicker("", selection: $mealTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(.primary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color("iosnp"))
        )
        .padding(.horizontal)
    }
    
    private func labeledRow<Content: View>(
        _ label: String,
        verticalPadding: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, verticalPadding)
    }
    
    private func capsulePill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .foregroundColor(.primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Color("iosnp"))
            .cornerRadius(12)
    }
    
    private var mealChips: some View {
        HStack(spacing: 8) {
            ForEach(MealPeriod.allCases) { period in
                let isSelected = selectedMealPeriod == period
                Text(period.title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .onTapGesture {
                        selectedMealPeriod = period
                    }
            }
        }
    }
    
private enum MealPeriod: String, CaseIterable, Identifiable {
        case breakfast, lunch, dinner, snack
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .breakfast: return "Breakfast"
            case .lunch: return "Lunch"
            case .dinner: return "Dinner"
            case .snack: return "Snack"
            }
        }
        
        var displayName: String { title }
    }
    
    private var mealTimeFormatted: String {
        mealTime.formatted(date: .omitted, time: .shortened)
    }

    private var dailyGoalShareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Goal Share")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                GoalShareBubble(title: "Protein",
                                percent: proteinGoalPercent,
                                grams: adjustedProtein,
                                goal: dayLogsVM.proteinGoal,
                                color: proteinColor)
                GoalShareBubble(title: "Fat",
                                percent: fatGoalPercent,
                                grams: adjustedFat,
                                goal: dayLogsVM.fatGoal,
                                color: fatColor)
                GoalShareBubble(title: "Carbs",
                                percent: carbGoalPercent,
                                grams: adjustedCarbs,
                                goal: dayLogsVM.carbsGoal,
                                color: carbColor)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color("iosnp"))
            )
        }
        .padding(.horizontal)
    }
    
    private var totalCarbsSection: some View {
        nutrientSection(title: "Total Carbs", rows: totalCarbRows)
    }

    private var fatTotalsSection: some View {
        nutrientSection(title: "Fat Totals", rows: fatRows)
    }

    private var proteinTotalsSection: some View {
        nutrientSection(title: "Protein Totals", rows: proteinRows)
    }

    private var vitaminSection: some View {
        nutrientSection(title: "Vitamins", rows: vitaminRows)
    }

    private var mineralSection: some View {
        nutrientSection(title: "Minerals", rows: mineralRows)
    }

    private var otherNutrientSection: some View {
        nutrientSection(title: "Other", rows: otherRows)
    }

    private var goalsLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView("Syncing your targets…")
                .progressViewStyle(CircularProgressViewStyle())
            Text("Hang tight while we fetch your personalized nutrient plan.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color("iosnp"))
        )
        .padding(.horizontal)
    }

    private var missingTargetsCallout: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finish goal setup to unlock detailed targets")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("We’ll automatically sync your nutrition plan and show daily percentages once it’s ready.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button(action: {
                dayLogsVM.refreshNutritionGoals(forceRefresh: true)
            }) {
                HStack {
                    if dayLogsVM.isRefreshingNutritionGoals {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                    Text(dayLogsVM.isRefreshingNutritionGoals ? "Syncing Targets" : "Sync Now")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(dayLogsVM.isRefreshingNutritionGoals ? 0.4 : 0.15))
                .foregroundColor(.accentColor)
                .cornerRadius(12)
            }
            .disabled(dayLogsVM.isRefreshingNutritionGoals)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color("iosnp"))
        )
        .padding(.horizontal)
    }

    private func nutrientSection(title: String, rows: [NutrientRowDescriptor]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                ForEach(rows) { descriptor in
                    nutrientRow(for: descriptor)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color("iosnp"))
            )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func nutrientRow(for descriptor: NutrientRowDescriptor) -> some View {
        let value = nutrientValue(for: descriptor)
        let goal = nutrientGoal(for: descriptor)
        let unit = nutrientUnit(for: descriptor)
        let percentage = nutrientPercentage(value: value, goal: goal)
        let ratio = nutrientRatioText(value: value, goal: goal, unit: unit)
        let progress = nutrientProgressValue(value: value, goal: goal)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(ratio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(percentage)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(descriptor.color)
            }

            ProgressView(value: progress)
                .tint(descriptor.color)
                .scaleEffect(x: 1, y: 1.2, anchor: .center)
        }
    }

    private func reloadStoredNutrientTargets() {
        nutrientTargets = goalsStore.currentTargets
    }

    private var totalCarbRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "Carbs", slug: "carbs", defaultUnit: "g", source: .macro(.carbs), color: carbColor),
            NutrientRowDescriptor(label: "Fiber", slug: "fiber", defaultUnit: "g", source: .nutrient(names: ["fiber, total dietary", "dietary fiber"]), color: carbColor),
            NutrientRowDescriptor(label: "Net (Non-fiber)", slug: "net_carbs", defaultUnit: "g", source: .computed(.netCarbs), color: carbColor),
            NutrientRowDescriptor(label: "Sugars", slug: "sugars", defaultUnit: "g", source: .nutrient(names: ["sugars, total including nlea", "sugars, total", "sugar"]), color: carbColor),
            NutrientRowDescriptor(label: "Sugars Added", slug: "added_sugars", defaultUnit: "g", source: .nutrient(names: ["sugars, added", "added sugars"]), color: carbColor)
        ]
    }

    private var fatRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "Fat", slug: "fat", defaultUnit: "g", source: .macro(.fat), color: fatColor),
            NutrientRowDescriptor(label: "Monounsaturated", slug: "monounsaturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total monounsaturated"]), color: fatColor),
            NutrientRowDescriptor(label: "Polyunsaturated", slug: "polyunsaturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total polyunsaturated"]), color: fatColor),
            NutrientRowDescriptor(label: "Omega-3", slug: "omega_3_total", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total n-3", "omega 3", "omega-3"]), color: fatColor),
            NutrientRowDescriptor(label: "Omega-3 ALA", slug: "omega_3_ala", defaultUnit: "g", source: .nutrient(names: ["18:3 n-3 c,c,c (ala)", "alpha-linolenic acid", "omega-3 ala", "omega 3 ala"]), color: fatColor),
            NutrientRowDescriptor(label: "Omega-3 EPA", slug: "omega_3_epa_dha", defaultUnit: "mg", source: .nutrient(names: ["20:5 n-3 (epa)", "22:6 n-3 (dha)", "epa", "dha", "eicosapentaenoic acid", "docosahexaenoic acid", "omega-3 epa + dha"], aggregation: .sum), color: fatColor),
            NutrientRowDescriptor(label: "Omega-6", slug: "omega_6", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total n-6", "omega 6", "omega-6"]), color: fatColor),
            NutrientRowDescriptor(label: "Saturated", slug: "saturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total saturated"]), color: fatColor),
            NutrientRowDescriptor(label: "Trans Fat", slug: "trans_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total trans"]), color: fatColor)
        ]
    }

    private var proteinRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "Protein", slug: "protein", defaultUnit: "g", source: .macro(.protein), color: proteinColor),
            NutrientRowDescriptor(label: "Cysteine", slug: "cysteine", defaultUnit: "mg", source: .nutrient(names: ["cysteine", "cystine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Histidine", slug: "histidine", defaultUnit: "mg", source: .nutrient(names: ["histidine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Isoleucine", slug: "isoleucine", defaultUnit: "mg", source: .nutrient(names: ["isoleucine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Leucine", slug: "leucine", defaultUnit: "mg", source: .nutrient(names: ["leucine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Lysine", slug: "lysine", defaultUnit: "mg", source: .nutrient(names: ["lysine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Methionine", slug: "methionine", defaultUnit: "mg", source: .nutrient(names: ["methionine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Phenylalanine", slug: "phenylalanine", defaultUnit: "mg", source: .nutrient(names: ["phenylalanine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Threonine", slug: "threonine", defaultUnit: "mg", source: .nutrient(names: ["threonine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Tryptophan", slug: "tryptophan", defaultUnit: "mg", source: .nutrient(names: ["tryptophan"]), color: proteinColor),
            NutrientRowDescriptor(label: "Tyrosine", slug: "tyrosine", defaultUnit: "mg", source: .nutrient(names: ["tyrosine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Valine", slug: "valine", defaultUnit: "mg", source: .nutrient(names: ["valine"]), color: proteinColor)
        ]
    }

    private var vitaminRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "B1, Thiamine", slug: "vitamin_b1_thiamin", defaultUnit: "mg", source: .nutrient(names: ["thiamin", "vitamin b-1"]), color: .orange),
            NutrientRowDescriptor(label: "B2, Riboflavin", slug: "vitamin_b2_riboflavin", defaultUnit: "mg", source: .nutrient(names: ["riboflavin", "vitamin b-2"]), color: .orange),
            NutrientRowDescriptor(label: "B3, Niacin", slug: "vitamin_b3_niacin", defaultUnit: "mg", source: .nutrient(names: ["niacin", "vitamin b-3"]), color: .orange),
            NutrientRowDescriptor(label: "B6, Pyridoxine", slug: "vitamin_b6_pyridoxine", defaultUnit: "mg", source: .nutrient(names: ["vitamin b-6", "pyridoxine", "vitamin b6"]), color: .orange),
            NutrientRowDescriptor(label: "B5, Pantothenic Acid", slug: "vitamin_b5_pantothenic_acid", defaultUnit: "mg", source: .nutrient(names: ["pantothenic acid"]), color: .orange),
            NutrientRowDescriptor(label: "B12, Cobalamin", slug: "vitamin_b12_cobalamin", defaultUnit: "mcg", source: .nutrient(names: ["vitamin b-12", "cobalamin"]), color: .orange),
            NutrientRowDescriptor(label: "Biotin", slug: "biotin", defaultUnit: "mcg", source: .nutrient(names: ["biotin"]), color: .orange),
            NutrientRowDescriptor(label: "Folate", slug: "folate", defaultUnit: "mcg", source: .nutrient(names: ["folate, total", "folic acid"]), color: .orange),
            NutrientRowDescriptor(label: "Vitamin A", slug: "vitamin_a", defaultUnit: "mcg", source: .nutrient(names: ["vitamin a, rae", "vitamin a"]), color: .orange),
            NutrientRowDescriptor(label: "Vitamin C", slug: "vitamin_c", defaultUnit: "mg", source: .nutrient(names: ["vitamin c, total ascorbic acid", "vitamin c"]), color: .orange),
            NutrientRowDescriptor(label: "Vitamin D", slug: "vitamin_d", defaultUnit: "IU", source: .nutrient(names: ["vitamin d (d2 + d3)", "vitamin d"]), color: .orange),
            NutrientRowDescriptor(label: "Vitamin E", slug: "vitamin_e", defaultUnit: "mg", source: .nutrient(names: ["vitamin e (alpha-tocopherol)", "vitamin e"]), color: .orange),
            NutrientRowDescriptor(label: "Vitamin K", slug: "vitamin_k", defaultUnit: "mcg", source: .nutrient(names: ["vitamin k (phylloquinone)", "vitamin k"]), color: .orange)
        ]
    }

    private var mineralRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "Calcium", slug: "calcium", defaultUnit: "mg", source: .nutrient(names: ["calcium, ca"]), color: .blue),
            NutrientRowDescriptor(label: "Copper", slug: "copper", defaultUnit: "mcg", source: .nutrient(names: ["copper, cu"]), color: .blue),
            NutrientRowDescriptor(label: "Iron", slug: "iron", defaultUnit: "mg", source: .nutrient(names: ["iron, fe"]), color: .blue),
            NutrientRowDescriptor(label: "Magnesium", slug: "magnesium", defaultUnit: "mg", source: .nutrient(names: ["magnesium, mg"]), color: .blue),
            NutrientRowDescriptor(label: "Manganese", slug: "manganese", defaultUnit: "mg", source: .nutrient(names: ["manganese, mn"]), color: .blue),
            NutrientRowDescriptor(label: "Phosphorus", slug: "phosphorus", defaultUnit: "mg", source: .nutrient(names: ["phosphorus, p"]), color: .blue),
            NutrientRowDescriptor(label: "Potassium", slug: "potassium", defaultUnit: "mg", source: .nutrient(names: ["potassium, k"]), color: .blue),
            NutrientRowDescriptor(label: "Selenium", slug: "selenium", defaultUnit: "mcg", source: .nutrient(names: ["selenium, se"]), color: .blue),
            NutrientRowDescriptor(label: "Sodium", slug: "sodium", defaultUnit: "mg", source: .nutrient(names: ["sodium, na"]), color: .blue),
            NutrientRowDescriptor(label: "Zinc", slug: "zinc", defaultUnit: "mg", source: .nutrient(names: ["zinc, zn"]), color: .blue)
        ]
    }

    private var otherRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "Calories", slug: "calories", defaultUnit: "kcal", source: .computed(.calories), color: .purple),
            NutrientRowDescriptor(label: "Alcohol", slug: "alcohol", defaultUnit: "g", source: .nutrient(names: ["alcohol, ethyl"]), color: .purple),
            NutrientRowDescriptor(label: "Caffeine", slug: "caffeine", defaultUnit: "mg", source: .nutrient(names: ["caffeine"]), color: .purple),
            NutrientRowDescriptor(label: "Cholesterol", slug: "cholesterol", defaultUnit: "mg", source: .nutrient(names: ["cholesterol"]), color: .purple),
            NutrientRowDescriptor(label: "Choline", slug: "choline", defaultUnit: "mg", source: .nutrient(names: ["choline, total"]), color: .purple),
            NutrientRowDescriptor(label: "Water", slug: "water", defaultUnit: "ml", source: .nutrient(names: ["water"]), color: .purple)
        ]
    }

    private func nutrientValue(for descriptor: NutrientRowDescriptor) -> Double {
        switch descriptor.source {
        case .macro(let macro):
            switch macro {
            case .protein: return adjustedProtein
            case .carbs: return adjustedCarbs
            case .fat: return adjustedFat
            }
        case .nutrient(let names, let aggregation):
            let matches = names.compactMap { baseNutrientValues[ConfirmLogView.normalizedNutrientKey($0)] }
            guard !matches.isEmpty else { return 0 }
            let perServing: Double
            switch aggregation {
            case .first:
                perServing = matches.first?.value ?? 0
            case .sum:
                perServing = matches.reduce(0) { $0 + $1.value }
            }
            let sourceUnit = matches.first?.unit
            let targetUnit = nutrientUnit(for: descriptor)
            let converted = convert(perServing, from: sourceUnit, to: targetUnit)
            return calculateAdjustedValue(converted, servings: numberOfServings)
        case .computed(let computation):
            switch computation {
            case .netCarbs:
                return max(adjustedCarbs - adjustedFiber, 0)
            case .calories:
                return adjustedCalories
            }
        }
    }

    private func nutrientGoal(for descriptor: NutrientRowDescriptor) -> Double? {
        var resolvedGoal: Double?
        if let slug = descriptor.slug,
           let details = nutrientTargets[slug] {
            if let target = details.target, target > 0 {
                resolvedGoal = target
            } else if let max = details.max, max > 0 {
                resolvedGoal = max
            } else if let idealMax = details.idealMax, idealMax > 0 {
                resolvedGoal = idealMax
            }
        }
        if let resolvedGoal {
            return convertGoal(resolvedGoal, for: descriptor)
        }

        switch descriptor.source {
        case .macro(let macro):
            switch macro {
            case .protein: return dayLogsVM.proteinGoal
            case .carbs: return dayLogsVM.carbsGoal
            case .fat: return dayLogsVM.fatGoal
            }
        case .computed(let computation):
            switch computation {
            case .calories:
                return dayLogsVM.calorieGoal
            case .netCarbs:
                if let target = nutrientTargets["net_carbs"]?.target {
                    return convertGoal(target, for: descriptor)
                }
                return nil
            }
        default:
            return nil
        }
    }

    private func convertGoal(_ goal: Double, for descriptor: NutrientRowDescriptor) -> Double {
        guard let slug = descriptor.slug else { return goal }
        switch slug {
        case "alcohol":
            // Convert drinks/week guidance to grams per day assuming 14g per standard drink
            return (goal / 7) * 14
        default:
            return goal
        }
    }

    private func nutrientUnit(for descriptor: NutrientRowDescriptor) -> String {
        if descriptor.defaultUnit.isEmpty,
           let slug = descriptor.slug,
           let unit = nutrientTargets[slug]?.unit,
           !unit.isEmpty {
            return unit
        }
        return descriptor.defaultUnit
    }

    private func nutrientPercentage(value: Double, goal: Double?) -> String {
        guard let goal, goal > 0 else { return "--" }
        let percent = (value / goal) * 100
        return "\(percent.cleanZeroDecimal)%"
    }

    private func nutrientProgressValue(value: Double, goal: Double?) -> Double {
        guard let goal, goal > 0 else { return 0 }
        return min(max(value / goal, 0), 1)
    }

    private func nutrientRatioText(value: Double, goal: Double?, unit: String) -> String {
        let valueText = value.goalShareFormatted
        let goalText = goal.map { $0.goalShareFormatted } ?? "--"
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUnit.isEmpty {
            return "\(valueText)/\(goalText)"
        } else {
            return "\(valueText)/\(goalText) \(trimmedUnit)"
        }
    }

    private func convert(_ value: Double, from sourceUnit: String?, to targetUnit: String?) -> Double {
        let from = normalizedUnit(sourceUnit)
        let to = normalizedUnit(targetUnit)
        guard !from.isEmpty, !to.isEmpty, from != to else { return value }

        switch (from, to) {
        case ("g", "mg"): return value * 1000
        case ("mg", "g"): return value / 1000
        case ("g", "mcg"): return value * 1_000_000
        case ("mcg", "g"): return value / 1_000_000
        case ("mg", "mcg"): return value * 1000
        case ("mcg", "mg"): return value / 1000
        case ("g", "ml"): return value * 1 // Approximate density of water
        case ("ml", "g"): return value * 1
        default: return value
        }
    }

    private func normalizedUnit(_ unit: String?) -> String {
        guard let unit = unit?.trimmingCharacters(in: .whitespacesAndNewlines), !unit.isEmpty else { return "" }
        let lower = unit.lowercased()
        if lower.contains("mcg") { return "mcg" }
        if lower.contains("mg") { return "mg" }
        if lower.contains("g") { return "g" }
        if lower.contains("ml") { return "ml" }
        if lower.contains("kcal") { return "kcal" }
        if lower.contains("iu") { return "iu" }
        return unit
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
                                // let negs: [HealthFacet] = health.negatives

                                // let poss: [HealthFacet] = health.positives
                                let negs: [HealthFacet] = showPerServing
                                    ? (health.servingFacets?.negatives ?? health.negatives)
                                    : health.negatives

                                let poss: [HealthFacet] = showPerServing
                                    ? (health.servingFacets?.positives ?? health.positives)
                                    : health.positives


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
                                                        // Don't show chevron for additives as there's no range to display
                                                        if facet.id != "risky_additives" {
                                                            Image(systemName: expandedNegativeIndices.contains(index) ? "chevron.up" : "chevron.down")
                                                                .font(.caption).foregroundColor(.secondary)
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal, 16).padding(.vertical, 12)
                                                .background(Color.clear)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    // Don't allow tap for additives as there's no range to show
                                                    if facet.id != "risky_additives" {
                                                        withAnimation(.easeInOut(duration: 0.3)) {
                                                            if expandedNegativeIndices.contains(index) {
                                                                expandedNegativeIndices.remove(index)
                                                            } else {
                                                                expandedNegativeIndices.insert(index)
                                                            }
                                                        }
                                                    }
                                                }

                                                // Don't show expanded content for additives as there's no range data
                                                if expandedNegativeIndices.contains(index) && facet.id != "risky_additives" {
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
                                                        Image(systemName: expandedPositiveIndices.contains(index) ? "chevron.up" : "chevron.down")
                                                            .font(.caption).foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.horizontal, 16).padding(.vertical, 12)
                                                .background(Color.clear)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    withAnimation(.easeInOut(duration: 0.3)) {
                                                        if expandedPositiveIndices.contains(index) {
                                                            expandedPositiveIndices.remove(index)
                                                        } else {
                                                            expandedPositiveIndices.insert(index)
                                                        }
                                                    }
                                                }

                                                if expandedPositiveIndices.contains(index) {
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
  case "some_protein", "high_protein":   return "fish"
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
    print("🔍 DEBUG ConfirmLogView: logBarcodeFood() called")
    print("🔍 DEBUG ConfirmLogView: barcodeFoodLogId = \(String(describing: barcodeFoodLogId))")
    print("🔍 DEBUG ConfirmLogView: This will log the food to database")
    
    // 1. Validate inputs
    guard !title.isEmpty, !calories.isEmpty else {
        errorMessage = "Title and calories are required"
        showErrorAlert = true
        return
    }
    guard Double(calories) != nil else {
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
    updatedFood.description = title  // Apply user's edited name
    updatedFood.numberOfServings = userServings

    let mealLabel = selectedMealPeriod.displayName
    
    // 3. Fire the real network call
    foodManager.logFood(
        email:    viewModel.email,
        food:     updatedFood,
        meal:     mealLabel,
        servings: userServings,
        date:     mealTime,
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
                    message:         "\(logged.food.displayName) - \(mealLabel)",
                    foodLogId:       logged.foodLogId,
                    food:            logged.food,
                    mealType:        mealLabel,
                    mealLogId:       nil,
                    meal:            nil,
                    mealTime:        mealLabel,
                    scheduledAt:     mealTime,
                    recipeLogId:     nil,
                    recipe:          nil,
                    servingsConsumed:nil
                )

                // Ensure all @Published property updates happen on main thread
                DispatchQueue.main.async {
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

    
    private static func formattedServings(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        var string = String(format: "%.2f", value)
        while string.last == "0" {
            string.removeLast()
        }
        if string.last == "." {
            string.removeLast()
        }
        return string
    }

    private func parseServingsInput(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let tokens = trimmed.split(whereSeparator: { $0 == " " }).map(String.init)
        if tokens.count == 2,
           let base = Double(tokens[0]),
           let fraction = parseFraction(tokens[1]) {
            return base + fraction
        }

        if let fraction = parseFraction(trimmed) {
            return fraction
        }

        return Double(trimmed)
    }

    private func parseFraction(_ component: String) -> Double? {
        let parts = component.split(separator: "/").map(String.init)
        guard parts.count == 2,
              let numerator = Double(parts[0]),
              let denominator = Double(parts[1]),
              denominator != 0 else { return nil }
        return numerator / denominator
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

        let formatted = ConfirmLogView.formattedServings(numberOfServings)
        if formatted != servingsInput {
            servingsInput = formatted
        }
    }
}

// MARK: - Supporting Views & Helpers
private struct GoalShareBubble: View {
    let title: String
    let percent: Double
    let grams: Double
    let goal: Double
    let color: Color
    
    private var progress: Double {
        min(max(percent / 100, 0), 1)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(percent.rounded()))%")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(width: 76, height: 76)
            Text("\(grams.goalShareFormatted) / \(goal.goalShareFormatted)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MacroRingView: View {
    let calories: Double
    let arcs: [MacroArc]
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 8)
            
            ForEach(arcs.indices, id: \.self) { index in
                let arc = arcs[index]
                Circle()
                    .trim(from: CGFloat(arc.start), to: CGFloat(arc.end))
                    .stroke(arc.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            
            VStack(spacing: -4) {
                Text(String(format: "%.1f", calories))
                    .font(.system(size: 20, weight: .medium))
                Text("cals")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct MacroArc {
    let start: Double
    let end: Double
    let color: Color
}

private struct MacroSegment {
    let color: Color
    let fraction: Double
}

private struct RawNutrientValue {
    let value: Double
    let unit: String?
}

private struct NutrientRowDescriptor: Identifiable {
    let id: String
    let label: String
    let slug: String?
    let defaultUnit: String
    let source: NutrientValueSource
    let color: Color

    init(id: String? = nil,
         label: String,
         slug: String?,
         defaultUnit: String,
         source: NutrientValueSource,
         color: Color) {
        self.id = id ?? slug ?? label
        self.label = label
        self.slug = slug
        self.defaultUnit = defaultUnit
        self.source = source
        self.color = color
    }
}

private enum NutrientValueSource {
    case macro(MacroType)
    case nutrient(names: [String], aggregation: NutrientAggregation = .first)
    case computed(NutrientComputation)
}

private enum MacroType {
    case protein
    case carbs
    case fat
}

private enum NutrientAggregation {
    case first
    case sum
}

private enum NutrientComputation {
    case netCarbs
    case calories
}

private extension Double {
    var cleanOneDecimal: String {
        if self.isNaN { return "0" }
        return String(format: "%.1f", self)
    }
    
    var cleanZeroDecimal: String {
        if self.isNaN { return "0" }
        if abs(self - rounded()) < 0.01 {
            return String(format: "%.0f", self)
        } else {
            return String(format: "%.1f", self)
        }
    }

    var goalShareFormatted: String {
        if self.isNaN || self.isInfinite { return "0" }
        let roundedValue = (self * 10).rounded() / 10
        if roundedValue.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(roundedValue))
        }
        return String(format: "%.1f", roundedValue)
    }
}

extension ConfirmLogView {
    static func normalizedNutrientKey(_ name: String) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        cleaned = cleaned.replacingOccurrences(of: "\\([^\\)]*\\)", with: " ", options: .regularExpression)
        let filtered = cleaned.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(filtered))
    }

    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
