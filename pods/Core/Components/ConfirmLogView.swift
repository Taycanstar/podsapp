//
//  ConfirmLogView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/17/25.
//

import SwiftUI
import AVFoundation

struct ConfirmLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var viewModel: OnboardingViewModel
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @Binding var path: NavigationPath
    private let existingPlateViewModel: PlateViewModel?
    
    // Basic food info
    @State private var title: String = ""
    @State private var servingSize: String = ""
    @State private var numberOfServings: Double = 1
    @State private var servingsInput: String = "1"
    @State private var servingAmount: Double = 1
    @State private var servingAmountInput: String = "1"
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
    @State private var hasAlignedMealTimeWithSelectedDate = false
    
    // Brand information
    @State private var brand: String = ""
    
    // UI states
    @State private var isCreating: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var showMealTimePicker = false
    
    // Focus state for auto-focusing the servings field
    @FocusState private var isServingsFocused: Bool
    
    // New properties for barcode flow
    @State private var isBarcodeFood: Bool = false
    @State private var originalFood: Food? = nil
    @State private var barcodeFoodLogId: Int? = nil

    // OCR scanned food (fdcId == -1 indicates locally scanned food)
    private let isScannedFood: Bool
    @State private var customFoodDraft: CustomFoodDraft?
    @State private var isSavingMeal = false
    @State private var servingUnit: String = "serving"
    private let saveNetworkManager = NetworkManager()
    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE"
        return formatter
    }()

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
    @State private var mealItems: [MealItem] = []
    @State private var mealItemNutrients: [UUID: [Nutrient]] = [:]
    @State private var expandedMealItemIDs: Set<UUID> = []
    @State private var availableMeasures: [FoodMeasure] = []
    @State private var selectedMeasureId: Int?
    private let referenceMacroTotals: MacroTotals
    private let baselineMeasureGramWeight: Double
    private let baselineServingAmount: Double  // The original serving amount (e.g., 8 wafers)
    @State private var plateBuilderViewModel: PlateViewModel?
    @State private var navigateToPlate = false

    @EnvironmentObject private var dayLogsVM: DayLogsViewModel
    @Environment(\.colorScheme) private var plateColorScheme
    
    // NEW: Add a flag to distinguish between creation and logging modes
    @State private var isCreationMode: Bool = false  // Always false for this view
    
    // Health analysis state
    @State private var healthAnalysis: HealthAnalysis? = nil
    @State private var showPerServing: Bool = true // true = per serving, false = per 100g/100ml
    @State private var isLiquid: Bool = false // Detect if it's a beverage
    @State private var expandedNegativeIndices: Set<Int> = []
    @State private var expandedPositiveIndices: Set<Int> = []
    
    private let showHealthInsights = false
    private let baselineNutrientValues: [String: RawNutrientValue]
    private var hasMealItems: Bool { !mealItems.isEmpty }
    private var shouldShowMealItemsEditor: Bool {
        !(originalFood?.mealItems?.isEmpty ?? true) || !mealItems.isEmpty
    }
    private var mealItemsListHeight: CGFloat {
        let baseRowHeight: CGFloat = 130
        return max(CGFloat(mealItems.count) * baseRowHeight, baseRowHeight + 40)
    }
    private var hasMeasureOptions: Bool { availableMeasures.count > 1 }
    private var selectedMeasure: FoodMeasure? {
        guard let id = selectedMeasureId else { return nil }
        return availableMeasures.first(where: { $0.id == id })
    }
    private var measureScalingFactor: Double {
        guard let measure = selectedMeasure,
              baselineMeasureGramWeight > 0,
              measure.gramWeight > 0 else { return 1 }
        return measure.gramWeight / baselineMeasureGramWeight
    }
    private var effectiveServings: Double { numberOfServings }
    private var backgroundColor: Color {
        colorScheme == .dark ? Color("bg") : Color(UIColor.systemGroupedBackground)
    }
    private var cardColor: Color {
        colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color("bg")
    }
    private var chipColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }

    private func scaledValue(_ value: Double) -> Double {
        // Scale by measure change and serving amount relative to baseline
        // e.g., if baseline is 8 wafers and user enters 16, scale is 16/8 = 2x
        let servingScale = baselineServingAmount > 0 ? (servingAmount / baselineServingAmount) : servingAmount
        return value * measureScalingFactor * servingScale
    }

    private var selectedMeasureLabel: String {
        if let measure = selectedMeasure {
            let text = measure.disseminationText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return text
            }
            if let modifier = measure.modifier?.trimmingCharacters(in: .whitespacesAndNewlines),
               !modifier.isEmpty {
                return modifier
            }
            return measure.measureUnitName
        }
        return servingSize.isEmpty ? "1 serving" : servingSize
    }

    private var perServingScaleFactor: Double {
        let servingScale = baselineServingAmount > 0 ? (servingAmount / baselineServingAmount) : servingAmount
        return measureScalingFactor * servingScale
    }

    private var servingUnitLabelForLogging: String {
        let label = sanitizedMeasureLabel(selectedMeasure)
        if !label.isEmpty {
            return label
        }
        if let measure = selectedMeasure {
            return measure.measureUnitName
        }
        return servingUnit.isEmpty ? "serving" : servingUnit
    }

    private var servingTextForLogging: String {
        let amountText = ConfirmLogView.formattedServings(servingAmount)
        let unitLabel = servingUnitLabelForLogging
        if unitLabel.isEmpty {
            return amountText
        }
        return "\(amountText) \(unitLabel)"
    }

    private func scaledNutrients(_ nutrients: [Nutrient], scale: Double) -> [Nutrient] {
        nutrients.map { nutrient in
            Nutrient(
                nutrientName: nutrient.nutrientName,
                value: (nutrient.value ?? 0) * scale,
                unitName: nutrient.unitName
            )
        }
    }

    private func scaledNutrientsForLogging(from food: Food, scale: Double) -> [Nutrient] {
        var scaled = scaledNutrients(food.foodNutrients, scale: scale)
        let macroOverrides: [(name: String, value: Double, unit: String)] = [
            ("Energy", baseCalories * scale, "kcal"),
            ("Protein", baseProtein * scale, "g"),
            ("Carbohydrate, by difference", baseCarbs * scale, "g"),
            ("Total lipid (fat)", baseFat * scale, "g"),
        ]
        for override in macroOverrides {
            if let index = scaled.firstIndex(where: { normalizedNutrientKey($0.nutrientName) == normalizedNutrientKey(override.name) }) {
                scaled[index] = Nutrient(nutrientName: override.name, value: override.value, unitName: override.unit)
            } else {
                scaled.append(Nutrient(nutrientName: override.name, value: override.value, unitName: override.unit))
            }
        }
        return scaled
    }

    private func scaledMealItemsForLogging(scale: Double) -> [MealItem] {
        guard !mealItems.isEmpty else { return mealItems }
        guard scale != 1 else { return mealItems }
        return mealItems.map { $0.scaled(by: scale) }
    }

    private func makeFoodForLogging(from food: Food) -> Food {
        let perServingScale = perServingScaleFactor
        let totalScale = perServingScale * numberOfServings
        let scaledMealItems = shouldShowMealItemsEditor
            ? scaledMealItemsForLogging(scale: totalScale)
            : (food.mealItems ?? [])

        var updatedFood = food
        updatedFood.description = title.isEmpty ? food.description : title
        updatedFood.servingSize = servingAmount
        updatedFood.servingSizeUnit = servingUnit.isEmpty ? (selectedMeasure?.measureUnitName ?? food.servingSizeUnit) : servingUnit
        updatedFood.householdServingFullText = servingTextForLogging
        updatedFood.numberOfServings = numberOfServings
        if let gramWeight = selectedMeasure?.gramWeight, gramWeight > 0 {
            updatedFood.servingWeightGrams = gramWeight * servingAmount
        }
        updatedFood.foodNutrients = scaledNutrientsForLogging(from: food, scale: perServingScale)
        updatedFood.mealItems = scaledMealItems.isEmpty ? nil : scaledMealItems
        return updatedFood
    }
    
    // This view is ONLY for logging scanned foods
    init(path: Binding<NavigationPath>, food: Food, foodLogId: Int? = nil, plateViewModel: PlateViewModel? = nil) {
        print("🔍 DEBUG ConfirmLogView: Initializing with food: \(food.description), fdcId: \(food.fdcId)")
        print("🔍 DEBUG ConfirmLogView: foodLogId: \(String(describing: foodLogId))")
        self._path = path
        self.existingPlateViewModel = plateViewModel
        // fdcId == -1 indicates a locally scanned food from OCR
        self.isScannedFood = food.fdcId == -1
        self._title = State(initialValue: food.description)
        self._brand = State(initialValue: food.brandText ?? "")
        let initialMealItems = food.mealItems ?? []
        self._mealItems = State(initialValue: initialMealItems)
        if !initialMealItems.isEmpty {
            print("🍽 [MealItemsDebug] Received \(initialMealItems.count) meal items")
            for item in initialMealItems {
                let label = item.originalServing?.resolvedText ?? "<none>"
                print("   • \(item.name): originalServing=\(label)")
                if let subs = item.subitems, !subs.isEmpty {
                    for sub in subs {
                        let subLabel = sub.originalServing?.resolvedText ?? "<none>"
                        print("      - sub \(sub.name): originalServing=\(subLabel)")
                    }
                }
            }
        } else {
            print("🍽 [MealItemsDebug] No meal items received")
        }
        
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
                print("    - Text: \(measure.disseminationText)")
                print("    - Modifier: \(measure.modifier ?? "N/A")")
                print("    - Unit: \(measure.measureUnitName)")
                print("    - Gram Weight: \(measure.gramWeight)")
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
        let resolvedServingText: String? = food.householdServingFullText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let servingText = resolvedServingText, !servingText.isEmpty {
            self._servingSize = State(initialValue: servingText)
            self._servingUnit = State(initialValue: food.servingSizeUnit ?? "serving")
        } else if let servingSize = food.servingSize, let unit = food.servingSizeUnit {
            let formattedSize = servingSize == floor(servingSize) ? String(Int(servingSize)) : String(servingSize)
            self._servingSize = State(initialValue: "\(formattedSize) \(unit)")
            self._servingUnit = State(initialValue: unit)
        } else {
            self._servingSize = State(initialValue: "1 serving")
            self._servingUnit = State(initialValue: "serving")
        }
        
        // Set serving amount from servingSize (e.g., 8 wafers)
        // This is the amount shown in the first input field
        let initialAmount = food.servingSize ?? 1
        self._servingAmount = State(initialValue: initialAmount)
        self._servingAmountInput = State(initialValue: ConfirmLogView.formattedServings(initialAmount))
        // Number of servings is a multiplier (default 1)
        self._numberOfServings = State(initialValue: 1)
        self._servingsInput = State(initialValue: "1")

        // Calculate nutrition value variables without modifying state directly
        var tmpCalories: Double = 0
        var tmpProtein: Double = 0
        var tmpCarbs: Double = 0
        var tmpFat: Double = 0
        var aggregatedMealItemTotals: MacroTotals? = nil
        
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
        if !initialMealItems.isEmpty {
            let totals = ConfirmLogView.macroTotals(for: initialMealItems)
            aggregatedMealItemTotals = totals
            tmpCalories = totals.calories
            tmpProtein = totals.protein
            tmpCarbs = totals.carbs
            tmpFat = totals.fat
        }
        
        let macroReference = MacroTotals(calories: tmpCalories, protein: tmpProtein, carbs: tmpCarbs, fat: tmpFat)
        self.referenceMacroTotals = macroReference

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
                let key = normalizedNutrientKey(nutrient.nutrientName)
                nutrientDictionary[key] = RawNutrientValue(value: value, unit: nutrient.unitName)
            }
        }
        if let totals = aggregatedMealItemTotals {
            nutrientDictionary[normalizedNutrientKey("Energy")] = RawNutrientValue(value: totals.calories, unit: "kcal")
            nutrientDictionary[normalizedNutrientKey("Protein")] = RawNutrientValue(value: totals.protein, unit: "g")
            nutrientDictionary[normalizedNutrientKey("Carbohydrate, by difference")] = RawNutrientValue(value: totals.carbs, unit: "g")
            nutrientDictionary[normalizedNutrientKey("Total lipid (fat)")] = RawNutrientValue(value: totals.fat, unit: "g")
        }
        self.baselineNutrientValues = nutrientDictionary
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

        var resolvedMeasures = food.foodMeasures.filter { $0.gramWeight > 0 }
        if resolvedMeasures.isEmpty, let fallback = ConfirmLogView.fallbackMeasure(for: food) {
            resolvedMeasures = [fallback]
        }
        self._availableMeasures = State(initialValue: resolvedMeasures)
        let measureDescriptions = resolvedMeasures.map { $0.disseminationText }
        print("🍽 [ServingMenu] Available measures (\(measureDescriptions.count)): \(measureDescriptions)")
        let baselineMeasure = ConfirmLogView.resolveBaselineMeasure(for: food, measures: resolvedMeasures)
        self._selectedMeasureId = State(initialValue: baselineMeasure?.id ?? resolvedMeasures.first?.id)
        self.baselineMeasureGramWeight = baselineMeasure?.gramWeight ?? resolvedMeasures.first?.gramWeight ?? max(food.servingSize ?? 1, 1)
        // Track the baseline serving amount for proper scaling (e.g., 8 wafers = 140 cal)
        self.baselineServingAmount = food.servingSize ?? 1
    }

    private let proteinColor = Color("protein")
    private let fatColor = Color("fat")
    private let carbColor = Color("carbs")

    private var adjustedProtein: Double {
        calculateAdjustedValue(scaledValue(baseProtein), servings: effectiveServings)
    }

    private var adjustedCarbs: Double {
        calculateAdjustedValue(scaledValue(baseCarbs), servings: effectiveServings)
    }

    private var adjustedFat: Double {
        calculateAdjustedValue(scaledValue(baseFat), servings: effectiveServings)
    }

    private var adjustedFiber: Double {
        calculateAdjustedValue(scaledValue(baseFiber), servings: effectiveServings)
    }

    private var adjustedCalories: Double {
        calculateAdjustedValue(scaledValue(baseCalories), servings: effectiveServings)
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

    @ViewBuilder
    private var plateBuilderDestination: some View {
        if let builder = plateBuilderViewModel {
            PlateView(viewModel: builder,
                      selectedMealPeriod: selectedMealPeriod,
                      mealTime: mealTime,
                      onFinished: {
                          // Dismiss the entire sheet directly without popping navigation first.
                          // Setting navigateToPlate = false would cause a visible pop animation
                          // back to ConfirmLogView before the sheet dismisses.
                          dismiss()
                      })
        } else {
            EmptyView()
        }
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
            NavigationLink(isActive: $navigateToPlate) {
                plateBuilderDestination
            } label: {
                EmptyView()
            }
            .hidden()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
            macroSummaryCard
            portionDetailsCard
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
        .background(backgroundColor.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(title.isEmpty ? (originalFood?.displayName ?? "Log Food") : title)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            alignMealTimeWithSelectedDateIfNeeded()
            setupHealthAnalysis()
            if shouldShowMealItemsEditor {
                recalculateMealItemNutrition()
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onReceive(dayLogsVM.$nutritionGoalsVersion) { _ in
            reloadStoredNutrientTargets()
        }
        .onReceive(goalsStore.$state) { _ in
            reloadStoredNutrientTargets()
        }
        .sheet(item: $customFoodDraft) { draft in
            CreateCustomFoodView(draft: draft) { updatedDraft, action in
                handleCustomFoodSubmission(draft: updatedDraft, action: action)
            }
        }
        .onChange(of: mealItems) { _ in
            if shouldShowMealItemsEditor {
                recalculateMealItemNutrition()
            }
        }
    }
    
    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            HStack(spacing: 12) {
                Button(action: {
                    HapticFeedback.generateLigth()
                    logBarcodeFood()
                }) {
                    Text(isCreating ? "Logging..." : "Log Food")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(Color("background"))
                )
                .foregroundColor(Color("text"))
                .disabled(isCreating)
                .opacity(isCreating ? 0.7 : 1)

                Button(action: {
                    HapticFeedback.generateLigth()
                    handleAddToPlate()
                }) {
                    Text("Add to Plate")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(Color("background"))
                )
                .foregroundColor(Color("text"))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Card Views
    private var mealItemsEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Meal Items")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if mealItems.isEmpty {
                Text("No items detected")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(mealItems.enumerated()), id: \.element.id) { index, _ in
                        mealItemCard(itemBinding: $mealItems[index])
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func mealItemCard(itemBinding: Binding<MealItem>) -> some View {
        let item = itemBinding.wrappedValue
        let totals = ConfirmLogView.macroTotals(for: item)
        let weightLabel = servingWeightLabel(for: item)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    if let servingLabel = item.preferredServingDescription {
                        Text(servingLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Menu {
                    Button("Create Custom Copy") {
                        presentCustomFoodEditor(for: item)
                    }
                    Button(role: .destructive) {
                        removeMealItem(item.id)
                    } label: {
                        Text("Delete Food")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(6)
                }
                .contentShape(Rectangle())
            }

            HStack(alignment: .center, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.primary)
                    Text("\(Int(totals.calories.rounded())) cal")
                }
                .font(.footnote)

                Text(macroSummary(for: totals, weightLabel: weightLabel))
                    .font(.caption)
                    .foregroundColor(.primary)

                Spacer()

                servingEditor(for: itemBinding)
            }

            if let subitems = item.subitems, !subitems.isEmpty {
                Divider()
                    .padding(.top, 4)

                DisclosureGroup(isExpanded: bindingForExpansion(item.id)) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(subitems.enumerated()), id: \.element.id) { subIndex, _ in
                            subitemCard(for: bindingForSubitem(parent: itemBinding, index: subIndex))
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text(expandedMealItemIDs.contains(item.id) ? "Collapse Ingredients" : "Expand Ingredients")
                        .font(.caption)
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardColor)
        )
    }

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
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    private func macroSummary(for totals: MacroTotals, weightLabel: String? = nil) -> String {
        let proteinText = "\(macroValueString(totals.protein))P"
        let fatText = "\(macroValueString(totals.fat))F"
        let carbText = "\(macroValueString(totals.carbs))C"
        let gramText = weightLabel ?? "\(macroValueString(totals.protein + totals.carbs + totals.fat))G"
        return "\(proteinText) \(fatText) \(carbText) • \(gramText)"
    }

    private func macroValueString(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.01 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    private func servingWeightLabel(for item: MealItem) -> String? {
        guard let grams = item.servingWeightInGrams, grams > 0 else { return nil }
        return "\(macroValueString(grams))g"
    }

    private func bindingForExpansion(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedMealItemIDs.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedMealItemIDs.insert(id)
                } else {
                    expandedMealItemIDs.remove(id)
                }
            }
        )
    }

    private func bindingForSubitem(parent: Binding<MealItem>, index: Int) -> Binding<MealItem> {
        Binding<MealItem>(
            get: {
                parent.wrappedValue.subitems?[index] ?? MealItem(name: "")
            },
            set: { newValue in
                var parentValue = parent.wrappedValue
                if parentValue.subitems != nil {
                    parentValue.subitems![index] = newValue
                }
                parent.wrappedValue = parentValue
                recalculateMealItemNutrition()
            }
        )
    }

    private func subitemCard(for binding: Binding<MealItem>) -> some View {
        let item = binding.wrappedValue
        let totals = ConfirmLogView.macroTotals(for: item)
        let weightLabel = servingWeightLabel(for: item)
        return VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                if let servingLabel = item.preferredServingDescription {
                    Text(servingLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            HStack {
                Text(macroSummary(for: totals, weightLabel: weightLabel))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                MealItemServingControls(item: binding) {
                    recalculateMealItemNutrition()
                }
            }
        }
        .padding(.vertical, 4)
    }

private struct MealItemServingControls: View {
    @Binding var item: MealItem
    var onChange: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            TextField("Qty", text: servingTextBinding)
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.done)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(10)
                .frame(width: 54)

            if item.hasMeasureOptions {
                measureMenu
            } else {
            TextField("Unit", text: servingUnitBinding)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                    .cornerRadius(10)
                    .frame(width: 110)
            }
        }
        .font(.subheadline)
    }

    private var measureMenu: some View {
        Menu {
            ForEach(item.measures) { measure in
                Button(action: { selectMeasure(measure) }) {
                    HStack {
                        Text(unitLabel(for: measure))
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                            Spacer()
                            if measure.id == item.selectedMeasureId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(unitLabel(for: item.selectedMeasure))
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(10)
            .frame(minWidth: 110, maxWidth: 140, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .frame(minWidth: 110, maxWidth: 140, alignment: .leading)
    }

    private var servingUnitBinding: Binding<String> {
        Binding<String>(
            get: { item.servingUnit ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                item.servingUnit = trimmed.isEmpty ? nil : trimmed
                updateOriginalServing()
                onChange()
            }
        )
    }

    private var servingTextBinding: Binding<String> {
        Binding<String>(
            get: { ConfirmLogView.formattedServings(item.serving) },
            set: { newValue in
                guard let parsed = ConfirmLogView.parseServingsInput(newValue) else { return }
                if abs(parsed - item.serving) > 0.0001 {
                    item.serving = parsed
                    updateOriginalServing()
                    onChange()
                }
            }
        )
    }

    private func selectMeasure(_ measure: MealItemMeasure) {
        guard item.selectedMeasureId != measure.id else { return }
        item.selectedMeasureId = measure.id
        item.servingUnit = measure.unit
        updateOriginalServing()
        onChange()
    }

    private func updateOriginalServing() {
        let unitText = item.servingUnit?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedUnit = (unitText?.isEmpty == false) ? unitText : nil
        let amountText = ConfirmLogView.formattedServings(item.serving)
        let text = cleanedUnit == nil ? amountText : "\(amountText) \(cleanedUnit ?? "")"
        item.originalServing = MealItemServingDescriptor(amount: item.serving, unit: cleanedUnit, text: text)
    }

    private func unitLabel(for measure: MealItemMeasure?) -> String {
        guard let measure else { return "Select" }
        let description = sanitizedDescription(measure.description)
        if !description.isEmpty {
            return description
        }
        return canonicalUnit(from: measure.unit)
    }

    private func sanitizedDescription(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        let lower = trimmed.lowercased()
        if ["g", "gram", "grams", "oz", "ounce", "ounces", "lb", "pound", "pounds"].contains(lower) {
            return ""
        }

        if let range = trimmed.range(of: "(") {
            trimmed = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let numberPrefixPattern = "^[0-9]+(\\.[0-9]+)?([/][0-9]+)?\\s*(x|×)?\\s*"
        trimmed = trimmed.replacingOccurrences(of: numberPrefixPattern, with: "", options: .regularExpression)

        trimmed = trimmed.replacingOccurrences(of: "portion", with: "serving", options: .caseInsensitive)
        trimmed = trimmed.replacingOccurrences(of: "as served", with: "", options: .caseInsensitive)
        trimmed = trimmed.replacingOccurrences(of: "as logged", with: "", options: .caseInsensitive)
        trimmed = trimmed.replacingOccurrences(of: "  ", with: " ")
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func canonicalUnit(from rawUnit: String) -> String {
        let lower = rawUnit.lowercased()
        let mapping: [(String, [String])] = [
            ("cup", ["cup", "cups"]),
            ("serving", ["serving", "portion", "tray", "plate", "meal", "container", "box", "pack", "package", "dip"]),
            ("piece", ["piece", "pieces", "roll", "rolls", "slice", "slices", "stick", "sticks", "item", "items", "ball", "balls"]),
            ("egg", ["egg", "eggs"]),
            ("tbsp", ["tbsp", "tablespoon", "tablespoons"]),
            ("tsp", ["tsp", "teaspoon", "teaspoons"]),
            ("g", ["g", "gram", "grams"]),
            ("oz", ["oz", "ounce", "ounces"]),
            ("lb", ["lb", "lbs", "pound", "pounds"]),
        ]

        for (canonical, tokens) in mapping {
            if tokens.contains(where: { lower.contains($0) }) {
                return canonical
            }
        }
        return rawUnit.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    }

    private func servingEditor(for itemBinding: Binding<MealItem>) -> some View {
        MealItemServingControls(item: itemBinding) {
            recalculateMealItemNutrition()
        }
    }

    private func handleMeasureSelection(_ measure: FoodMeasure) {
        selectedMeasureId = measure.id
        servingSize = measure.disseminationText
        servingUnit = measure.measureUnitName
        updateNutritionValues()
    }

    @ViewBuilder
    private var macroArcs: [MacroArc] {
        var running: Double = 0
        return macroSegments.map { segment in
            let arc = MacroArc(start: running, end: running + segment.fraction, color: segment.color)
            running += segment.fraction
            return arc
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
            // Show editable Name field for scanned foods (fdcId == -1)
            if isScannedFood {
                labeledRow("Name") {
                    TextField("Enter food name", text: $title)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.primary)
                }

                Divider().padding(.leading, 16)
            }

            labeledRow("Serving Size") {
                HStack(spacing: 8) {
                    TextField("1", text: $servingAmountInput)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.center)
                        .focused($isServingsFocused)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(chipColor)
                        )
                        .frame(width: 70)
                        .onChange(of: servingAmountInput) { newValue in
                            guard let parsed = ConfirmLogView.parseServingsInput(newValue) else { return }
                            if abs(parsed - servingAmount) > 0.0001 {
                                servingAmount = parsed
                                updateNutritionValues()
                            }
                        }

                    if hasMeasureOptions {
                        Menu {
                            ForEach(availableMeasures, id: \.id) { measure in
                                Button(sanitizedMeasureLabel(measure)) {
                                    handleMeasureSelection(measure)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(sanitizedMeasureLabel(selectedMeasure ?? availableMeasures.first))
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(
                                Capsule()
                                    .fill(chipColor)
                            )
                        }
                        .menuStyle(.borderlessButton)
                    } else {
                        Text(sanitizedMeasureLabel(selectedMeasure ?? availableMeasures.first))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(
                                Capsule()
                                    .fill(chipColor)
                            )
                    }
                }
            }

            Divider().padding(.leading, 16)

            labeledRow("Servings") {
                TextField("1", text: $servingsInput)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.center)
                    .focused($isServingsFocused)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(chipColor)
                    )
                    .frame(width: 70)
                    .onChange(of: servingsInput) { newValue in
                        guard let parsed = ConfirmLogView.parseServingsInput(newValue) else { return }
                        if abs(parsed - numberOfServings) > 0.0001 {
                            numberOfServings = parsed
                            updateNutritionValues()
                        }
                    }
            }
            
            Divider().padding(.leading, 16)
            
            labeledRow("Time", verticalPadding: 10) {
                HStack(spacing: 16) {
                    Menu {
                        ForEach(MealPeriod.allCases) { period in
                            Button(period.title) {
                                selectedMealPeriod = period
                            }
                        }
                    } label: {
                        capsulePill {
                            HStack(spacing: 4) {
                                Text(selectedMealPeriod.title)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showMealTimePicker.toggle()
                        }
                    } label: {
                        capsulePill {
                            Text(relativeDayAndTimeString(for: mealTime))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if showMealTimePicker {
                DatePicker("",
                           selection: $mealTime,
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    private func sanitizedMeasureLabel(_ measure: FoodMeasure?) -> String {
        guard let measure else { return "serving" }
        var label = measure.disseminationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = label.range(of: "(") {
            label = String(label[..<range.lowerBound])
        }
        let numberPrefixPattern = "^[0-9]+(\\.[0-9]+)?([/][0-9]+)?\\s*(x|×)?\\s*"
        label = label.replacingOccurrences(of: numberPrefixPattern, with: "", options: .regularExpression)
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? measure.measureUnitName : trimmed
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
            .background(chipColor)
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

    private static func resolveBaselineMeasure(for food: Food, measures: [FoodMeasure]) -> FoodMeasure? {
        guard !measures.isEmpty else { return nil }
        if let unit = food.servingSizeUnit?.lowercased() {
            if let match = measures.first(where: { $0.measureUnitName.lowercased() == unit }) {
                return match
            }
        }
        if let text = food.householdServingFullText?.lowercased() {
            if let match = measures.first(where: { $0.disseminationText.lowercased() == text }) {
                return match
            }
        }
        return measures.first
    }

    private static func fallbackMeasure(for food: Food) -> FoodMeasure? {
        let label = food.householdServingFullText?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? {
                guard let size = food.servingSize else { return nil }
                let formatted = size == floor(size) ? String(Int(size)) : String(size)
                return "\(formatted) \(food.servingSizeUnit ?? "serving")"
            }()
        guard let label else { return nil }
        let unit = food.servingSizeUnit ?? "serving"
        let measureWeight = food.servingSize ?? 0
        return FoodMeasure(
            disseminationText: label,
            gramWeight: measureWeight,
            id: food.fdcId,
            modifier: nil,
            measureUnitName: unit,
            rank: 0
        )
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
                    .fill(cardColor)
            )
        }
        .padding(.horizontal)
    }
    
    private var totalCarbsSection: some View {
        nutrientSection(title: "Total Carbs", rows: totalCarbRows)
    }

    private var fatTotalsSection: some View {
        nutrientSection(title: "Total Fat", rows: fatRows)
    }

    private var proteinTotalsSection: some View {
        nutrientSection(title: "Total Protein", rows: proteinRows)
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
                .fill(cardColor)
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
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    private func nutrientSection(title: String, rows: [NutrientRowDescriptor]) -> some View {
        // Filter rows to only show nutrients that exist in the data
        // Zero values ARE shown (e.g., 0g sugar means sugar-free)
        // Only nutrients completely absent from the response are hidden
        let filteredRows = rows.filter { descriptor in
            switch descriptor.source {
            case .macro, .computed:
                // Always show macros and computed values (e.g., net carbs, calories)
                return true
            case .nutrient(let names, _):
                // Show if the nutrient exists in the data (even if value is 0)
                return names.contains { name in
                    baseNutrientValues[normalizedNutrientKey(name)] != nil
                }
            }
        }

        // Don't render empty sections
        return Group {
            if !filteredRows.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(spacing: 16) {
                        ForEach(filteredRows) { descriptor in
                            nutrientRow(for: descriptor)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(cardColor)
                    )
                }
                .padding(.horizontal)
            }
        }
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

    private var totalCarbRows: [NutrientRowDescriptor] { NutrientDescriptors.totalCarbRows }

    private var fatRows: [NutrientRowDescriptor] { NutrientDescriptors.fatRows }

    private var proteinRows: [NutrientRowDescriptor] { NutrientDescriptors.proteinRows }

    private var vitaminRows: [NutrientRowDescriptor] { NutrientDescriptors.vitaminRows }

    private var mineralRows: [NutrientRowDescriptor] { NutrientDescriptors.mineralRows }

    private var otherRows: [NutrientRowDescriptor] { NutrientDescriptors.otherRows }

    private func nutrientValue(for descriptor: NutrientRowDescriptor) -> Double {
        switch descriptor.source {
        case .macro(let macro):
            switch macro {
            case .protein: return adjustedProtein
            case .carbs: return adjustedCarbs
            case .fat: return adjustedFat
            }
        case .nutrient(let names, let aggregation):
            let matches = names.compactMap { baseNutrientValues[normalizedNutrientKey($0)] }
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
            let converted = convert(perServing * measureScalingFactor, from: sourceUnit, to: targetUnit)
            return calculateAdjustedValue(converted, servings: effectiveServings)
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
                    .fill(cardColor)
                
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
        let adj = showPerServing ? (v * effectiveServings) : v
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

private func alignMealTimeWithSelectedDateIfNeeded() {
    guard !hasAlignedMealTimeWithSelectedDate else { return }
    hasAlignedMealTimeWithSelectedDate = true

    let calendar = Calendar.current
    var dateComponents = calendar.dateComponents([.year, .month, .day], from: dayLogsVM.selectedDate)
    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: mealTime)
    dateComponents.hour = timeComponents.hour
    dateComponents.minute = timeComponents.minute
    dateComponents.second = timeComponents.second

    if let alignedDate = calendar.date(from: dateComponents) {
        mealTime = alignedDate
    } else {
        mealTime = dayLogsVM.selectedDate
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

        "energy_kcal": scaledValue(baseCalories),
        "protein_g": scaledValue(baseProtein),
        "saturated_fat_g": scaledValue(baseSaturatedFat),
        "sugars_g": scaledValue(baseSugar),
        "sodium_mg": scaledValue(baseSodium),
        "fiber_g": scaledValue(baseFiber),

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

    return showPerServing ? raw * effectiveServings : raw
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

        let updatedFood = makeFoodForLogging(from: food)

        let mealLabel = selectedMealPeriod.displayName
        let placeholderId = generateTemporaryFoodLogID()
        let optimisticLog = makeOptimisticCombinedLog(from: updatedFood, placeholderId: placeholderId, mealLabel: mealLabel)
        let placeholderIdentifier = optimisticLog.id

        dayLogsVM.addPending(optimisticLog)
        upsertCombinedLog(optimisticLog)

        // Navigate to timeline immediately with optimistic log
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToTimeline"), object: nil)

        dismiss()

        foodManager.logFood(
            email:    viewModel.email,
            food:     updatedFood,
            meal:     mealLabel,
            servings: updatedFood.numberOfServings ?? effectiveServings,
            date:     mealTime,
            notes:    nil
        ) { result in
            DispatchQueue.main.async {
                self.isCreating = false
                switch result {
                case .success(let logged):
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

                    self.dayLogsVM.replaceOptimisticLog(identifier: placeholderIdentifier, with: combined)
                    self.upsertCombinedLog(combined, replacing: placeholderIdentifier)

                    foodManager.lastLoggedItem = (name: combined.food?.displayName ?? title,
                                                  calories: combined.displayCalories)
                    foodManager.showLogSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        foodManager.showLogSuccess = false
                    }
                    // NOTE: No loadLogs call needed - optimistic log was already replaced with
                    // server-confirmed data. Refetching would be redundant and can cause race conditions.
                    self.barcodeFoodLogId = logged.foodLogId
                case .failure:
                    self.dayLogsVM.removeOptimisticLog(identifier: placeholderIdentifier)
                    self.removeCombinedLog(identifier: placeholderIdentifier)
                }
            }
        }
    }

    private func makeOptimisticCombinedLog(from food: Food, placeholderId: Int, mealLabel: String) -> CombinedLog {
        let servingText = food.householdServingFullText ?? selectedMeasureLabel
        let servings = food.numberOfServings ?? effectiveServings
        let loggedItem = LoggedFoodItem(
            foodLogId: placeholderId,
            fdcId: food.fdcId,
            displayName: food.description,
            calories: perServingValue(adjustedCalories),
            servingSizeText: servingText,
            numberOfServings: servings,
            brandText: brand.isEmpty ? food.brandText : brand,
            protein: perServingValue(adjustedProtein),
            carbs: perServingValue(adjustedCarbs),
            fat: perServingValue(adjustedFat),
            healthAnalysis: food.healthAnalysis,
            foodNutrients: food.foodNutrients,
            aiInsight: food.aiInsight,
            nutritionScore: food.nutritionScore,
            mealItems: food.mealItems
        )

        let logDate = ConfirmLogView.isoDayFormatter.string(from: mealTime)
        let dayName = ConfirmLogView.weekdayFormatter.string(from: mealTime)

        return CombinedLog(
            type:            .food,
            status:          "pending",
            calories:        adjustedCalories,
            message:         "\(loggedItem.displayName) - \(mealLabel)",
            foodLogId:       placeholderId,
            food:            loggedItem,
            mealType:        mealLabel,
            mealLogId:       nil,
            meal:            nil,
            mealTime:        mealLabel,
            scheduledAt:     mealTime,
            recipeLogId:     nil,
            recipe:          nil,
            servingsConsumed:nil,
            activityId:      nil,
            activity:        nil,
            logDate:         logDate,
            dayOfWeek:       dayName,
            isOptimistic:    true
        )
    }

    private func perServingValue(_ total: Double) -> Double {
        let servings = max(effectiveServings, 0.0001)
        return total / servings
    }

    private func upsertCombinedLog(_ log: CombinedLog, replacing identifier: String? = nil) {
        if let identifier {
            foodManager.combinedLogs.removeAll { $0.id == identifier }
        }
        foodManager.combinedLogs.removeAll { $0.id == log.id }
        foodManager.combinedLogs.insert(log, at: 0)
    }

    private func removeCombinedLog(identifier: String) {
        foodManager.combinedLogs.removeAll { $0.id == identifier }
    }

    private func generateTemporaryFoodLogID() -> Int {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        return -abs(timestamp)
    }

    private func handleAddToPlate() {
        guard let entry = buildPlateEntry() else { return }
        if let viewModel = existingPlateViewModel {
            viewModel.add(entry)
            dismiss()
        } else {
            if plateBuilderViewModel == nil {
                plateBuilderViewModel = PlateViewModel()
            }
            plateBuilderViewModel?.add(entry)
            navigateToPlate = true
        }
    }

    private func buildPlateEntry() -> PlateEntry? {
        guard let food = originalFood else { return nil }
        var updatedFood = food
        updatedFood.description = title.isEmpty ? food.description : title
        updatedFood.householdServingFullText = selectedMeasureLabel
        updatedFood.numberOfServings = effectiveServings
        updatedFood.mealItems = mealItems
        let scaledNutrients = baseNutrientValues.reduce(into: [String: RawNutrientValue]()) { partialResult, item in
            let scaled = item.value.value * measureScalingFactor * servingAmount * numberOfServings
            partialResult[item.key] = RawNutrientValue(value: scaled, unit: item.value.unit)
        }
        let description = "\(servingAmountInput) x \(selectedMeasureLabel) x \(servingsInput)"
        return PlateEntry(
            food: updatedFood,
            servings: effectiveServings,
            selectedMeasureId: selectedMeasureId,
            availableMeasures: availableMeasures,
            baselineGramWeight: baselineMeasureGramWeight,
            baseNutrientValues: baseNutrientValues,
            baseMacroTotals: MacroTotals(
                calories: baseCalories,
                protein: baseProtein,
                carbs: baseCarbs,
                fat: baseFat
            ),
            servingDescription: description,
            mealItems: mealItems,
            mealPeriod: selectedMealPeriod,
            mealTime: mealTime,
            recipeItems: []
        )
    }

    
    static func formattedServings(_ value: Double) -> String {
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

    private func removeMealItem(_ id: UUID) {
        withAnimation {
            mealItems.removeAll { $0.id == id }
            expandedMealItemIDs.remove(id)
            mealItemNutrients[id] = nil
        }
    }

    private func deleteMealItems(at offsets: IndexSet) {
        let ids = offsets.map { mealItems[$0].id }
        mealItems.remove(atOffsets: offsets)
        ids.forEach { mealItemNutrients[$0] = nil }
    }

    private func presentCustomFoodEditor(for mealItem: MealItem? = nil) {
        guard let payload = buildCustomFoodPayload(for: mealItem) else {
            errorMessage = "Unable to prepare custom food data."
            showErrorAlert = true
            return
        }
        customFoodDraft = payload
    }

    private func buildCustomFoodPayload(for mealItem: MealItem? = nil) -> CustomFoodDraft? {
        guard let food = originalFood else { return nil }
        if let mealItem {
            let servingDescription = mealItem.preferredServingDescription ?? "\(mealItem.serving.cleanZeroDecimal) \(mealItem.servingUnit ?? "serving")"
            let nutrients = mealItemNutrients[mealItem.id] ?? buildNutrients(for: mealItem)
            return CustomFoodDraft(
                name: mealItem.name,
                brand: brand.isEmpty ? (food.brandText ?? "") : brand,
                servingText: servingDescription,
                servings: mealItem.serving,
                mealItems: [mealItem],
                nutrients: nutrients
            )
        }

        let mealItemsPayload = shouldShowMealItemsEditor ? mealItems : (food.mealItems ?? [])
        let nutrientsPayload = food.foodNutrients
        let displayName = title.isEmpty ? food.description : title
        let displayBrand = brand.isEmpty ? (food.brandText ?? "") : brand
        let servingDescription = servingSize.isEmpty ? (food.householdServingFullText ?? "") : servingSize
        return CustomFoodDraft(
            name: displayName,
            brand: displayBrand,
            servingText: servingDescription,
            servings: effectiveServings,
            mealItems: mealItemsPayload,
            nutrients: nutrientsPayload
        )
    }

    private func handleCustomFoodSubmission(draft: CustomFoodDraft, action: CustomFoodAction) {
        let foodPayload = foodFromDraft(draft)
        foodManager.createManualFood(food: foodPayload, showPreview: false) { result in
            switch result {
            case .success(_):
                if action == .createAndAdd {
                    appendCustomMealItem(from: draft)
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func foodFromDraft(_ draft: CustomFoodDraft) -> Food {
        let trimmedBrand = draft.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBrand = trimmedBrand.isEmpty ? nil : trimmedBrand
        let servingText = draft.servingText.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedServingText = servingText.isEmpty ? "1 serving" : servingText
        let servingUnit = parsedServingUnit(from: resolvedServingText)
        let measureId = Int.random(in: 100_000...999_999)
        let measure = FoodMeasure(
            disseminationText: resolvedServingText,
            gramWeight: 0,
            id: measureId,
            modifier: resolvedServingText,
            measureUnitName: servingUnit,
            rank: 1
        )

        return Food(
            fdcId: Int.random(in: 10_000_000...99_999_999),
            description: draft.name,
            brandOwner: resolvedBrand,
            brandName: resolvedBrand,
            servingSize: 1,
            numberOfServings: draft.servings,
            servingSizeUnit: servingUnit,
            householdServingFullText: resolvedServingText,
            foodNutrients: draft.nutrients,
            foodMeasures: [measure],
            healthAnalysis: nil,
            aiInsight: nil,
            nutritionScore: nil,
            mealItems: draft.mealItems.isEmpty ? nil : draft.mealItems
        )
    }

    private func appendCustomMealItem(from draft: CustomFoodDraft) {
        let newItem = mealItem(from: draft)
        withAnimation {
            mealItems.append(newItem)
        }
        mealItemNutrients[newItem.id] = draft.nutrients
        recalculateMealItemNutrition()
    }

    private func mealItem(from draft: CustomFoodDraft) -> MealItem {
        let servingsValue = draft.servings > 0 ? draft.servings : 1
        let calories = nutrientValue(names: ["Energy"], in: draft.nutrients) * servingsValue
        let protein = nutrientValue(names: ["Protein"], in: draft.nutrients) * servingsValue
        let carbs = nutrientValue(names: ["Carbohydrate, by difference"], in: draft.nutrients) * servingsValue
        let fat = nutrientValue(names: ["Total lipid (fat)"], in: draft.nutrients) * servingsValue
        let servingDescriptor = draft.servingText.isEmpty ? nil : MealItemServingDescriptor(amount: nil, unit: nil, text: draft.servingText)

        return MealItem(
            name: draft.name,
            serving: servingsValue,
            servingUnit: parsedServingUnit(from: draft.servingText),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            subitems: nil,
            baselineServing: servingsValue,
            measures: [],
            originalServing: servingDescriptor
        )
    }

    private func nutrientValue(names: [String], in nutrients: [Nutrient]) -> Double {
        for name in names {
            if let match = nutrients.first(where: { $0.nutrientName.caseInsensitiveCompare(name) == .orderedSame }) {
                return match.safeValue
            }
        }
        return 0
    }

    private func parsedServingUnit(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "serving" }
        let tokens = trimmed.split(whereSeparator: { $0 == " " || $0 == "\u{00A0}" })
        if tokens.count >= 2, Double(tokens[0].replacingOccurrences(of: ",", with: ".")) != nil {
            return canonicalUnitLabel(String(tokens[1]))
        }
        return canonicalUnitLabel(trimmed)
    }

    private func canonicalUnitLabel(_ rawUnit: String) -> String {
        let cleaned = rawUnit
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        let mapping: [String: [String]] = [
            "cup": ["cup", "cups"],
            "serving": ["serving", "servings", "portion"],
            "piece": ["piece", "pieces", "slice", "slices", "item", "items"],
            "tbsp": ["tbsp", "tablespoon", "tablespoons"],
            "tsp": ["tsp", "teaspoon", "teaspoons"],
            "g": ["g", "gram", "grams"],
            "oz": ["oz", "ounce", "ounces"],
            "ml": ["ml", "milliliter", "milliliters"],
            "lb": ["lb", "lbs", "pound", "pounds"],
            "can": ["can", "cans"],
            "bottle": ["bottle", "bottles"]
        ]

        for (canonical, matches) in mapping {
            if matches.contains(where: { cleaned.contains($0) }) {
                return canonical
            }
        }
        return cleaned.isEmpty ? "serving" : cleaned
    }

    private func buildNutrients(for mealItem: MealItem) -> [Nutrient] {
        [
            Nutrient(nutrientName: "Energy", value: mealItem.calories, unitName: "kcal"),
            Nutrient(nutrientName: "Protein", value: mealItem.protein, unitName: "g"),
            Nutrient(nutrientName: "Carbohydrate, by difference", value: mealItem.carbs, unitName: "g"),
            Nutrient(nutrientName: "Total lipid (fat)", value: mealItem.fat, unitName: "g")
        ]
    }


    private func recalculateMealItemNutrition() {
        guard shouldShowMealItemsEditor else { return }
        if mealItems.isEmpty {
            let emptyTotals = MacroTotals.zero
            baseCalories = 0
            baseProtein = 0
            baseCarbs = 0
            baseFat = 0
            rebuildBaseNutrientValues(with: emptyTotals)
            updateNutritionValues()
            return
        }
        let totals = ConfirmLogView.macroTotals(for: mealItems)
        baseCalories = totals.calories
        baseProtein = totals.protein
        baseCarbs = totals.carbs
        baseFat = totals.fat
        rebuildBaseNutrientValues(with: totals)
        updateNutritionValues()
    }

    private func rebuildBaseNutrientValues(with totals: MacroTotals) {
        var merged = baselineNutrientValues
        let energyKey = normalizedNutrientKey("Energy")
        let proteinKey = normalizedNutrientKey("Protein")
        let carbKey = normalizedNutrientKey("Carbohydrate, by difference")
        let fatKey = normalizedNutrientKey("Total lipid (fat)")

        merged[energyKey] = RawNutrientValue(value: totals.calories, unit: "kcal")
        merged[proteinKey] = RawNutrientValue(value: totals.protein, unit: "g")
        merged[carbKey] = RawNutrientValue(value: totals.carbs, unit: "g")
        merged[fatKey] = RawNutrientValue(value: totals.fat, unit: "g")

        applyCustomNutrientContributions(into: &merged)
        baseNutrientValues = merged
    }

    private func applyCustomNutrientContributions(into values: inout [String: RawNutrientValue]) {
        let macroKeys: Set<String> = [
            normalizedNutrientKey("Energy"),
            normalizedNutrientKey("Protein"),
            normalizedNutrientKey("Carbohydrate, by difference"),
            normalizedNutrientKey("Total lipid (fat)")
        ]

        for item in mealItems {
            guard let nutrients = mealItemNutrients[item.id], !nutrients.isEmpty else { continue }
            let baselineServing = item.baselineServing == 0 ? 1 : item.baselineServing
            let multiplier = item.serving / baselineServing

            for nutrient in nutrients {
                let key = normalizedNutrientKey(nutrient.nutrientName)
                if macroKeys.contains(key) { continue }
                let addition = nutrient.safeValue * multiplier
                if let existing = values[key] {
                    values[key] = RawNutrientValue(value: existing.value + addition, unit: existing.unit ?? nutrient.unitName)
                } else {
                    values[key] = RawNutrientValue(value: addition, unit: nutrient.unitName)
                }
            }
        }
    }

    private static func macroTotals(for items: [MealItem]) -> MacroTotals {
        items.reduce(into: MacroTotals.zero) { partialResult, item in
            partialResult.add(macroTotals(for: item))
        }
    }

    private static func macroTotals(for item: MealItem) -> MacroTotals {
        let scale = max(item.macroScalingFactor, 0)
        let parentTotals = MacroTotals(
            calories: item.calories * scale,
            protein: item.protein * scale,
            carbs: item.carbs * scale,
            fat: item.fat * scale
        )

        if let subitems = item.subitems, !subitems.isEmpty {
            let childTotals = macroTotals(for: subitems)
            if parentTotals.isZero && !childTotals.isZero {
                return MacroTotals(
                    calories: childTotals.calories * scale,
                    protein: childTotals.protein * scale,
                    carbs: childTotals.carbs * scale,
                    fat: childTotals.fat * scale
                )
            }
        }

        return parentTotals
    }

    static func parseServingsInput(_ text: String) -> Double? {
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

    private static func parseFraction(_ component: String) -> Double? {
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
        calories = String(format: "%.1f", scaledValue(baseCalories) * effectiveServings)
        protein = String(format: "%.1f", scaledValue(baseProtein) * effectiveServings)
        carbs = String(format: "%.1f", scaledValue(baseCarbs) * effectiveServings)
        fat = String(format: "%.1f", scaledValue(baseFat) * effectiveServings)
        
        // Update additional nutrients too with formatted strings
        saturatedFat = String(format: "%.1f", scaledValue(baseSaturatedFat) * effectiveServings)
        polyunsaturatedFat = String(format: "%.1f", scaledValue(basePolyunsaturatedFat) * effectiveServings)
        monounsaturatedFat = String(format: "%.1f", scaledValue(baseMonounsaturatedFat) * effectiveServings)
        transFat = String(format: "%.1f", scaledValue(baseTransFat) * effectiveServings)
        cholesterol = String(format: "%.1f", scaledValue(baseCholesterol) * effectiveServings)
        sodium = String(format: "%.1f", scaledValue(baseSodium) * effectiveServings)
        potassium = String(format: "%.1f", scaledValue(basePotassium) * effectiveServings)
        sugar = String(format: "%.1f", scaledValue(baseSugar) * effectiveServings)
        fiber = String(format: "%.1f", scaledValue(baseFiber) * effectiveServings)
        vitaminA = String(format: "%.1f", scaledValue(baseVitaminA) * effectiveServings)
        vitaminC = String(format: "%.1f", scaledValue(baseVitaminC) * effectiveServings)
        calcium = String(format: "%.1f", scaledValue(baseCalcium) * effectiveServings)
        iron = String(format: "%.1f", scaledValue(baseIron) * effectiveServings)

        let amountFormatted = ConfirmLogView.formattedServings(servingAmount)
        if amountFormatted != servingAmountInput {
            servingAmountInput = amountFormatted
        }

        let servingsFormatted = ConfirmLogView.formattedServings(numberOfServings)
        if servingsFormatted != servingsInput {
            servingsInput = servingsFormatted
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

private extension ConfirmLogView {
    static let servingFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.minimum = 0
        return formatter
    }()
}

struct CustomFoodDraft: Identifiable {
    let id = UUID()
    var name: String
    var brand: String
    var servingText: String
    var servings: Double
    var mealItems: [MealItem]
    var nutrients: [Nutrient]
}

struct PlateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel
    @EnvironmentObject private var onboardingViewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var plateColorScheme
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared

    @ObservedObject var viewModel: PlateViewModel
    @State private var selectedMealPeriod: MealPeriod
    @State private var mealTime: Date
    private let onFinished: (() -> Void)?
    private let onPlateLogged: (([Food]) -> Void)?
    @State private var isLoggingPlate = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showScanner = false
    @State private var showDescribeLog = false
    @State private var showQuickAdd = false
    @State private var pendingFood: Food?
    @State private var showConfirmFood = false
    @State private var showMealTimePicker = false
    @State private var nutrientTargets: [String: NutrientTargetDetails] = NutritionGoalsStore.shared.currentTargets
    @State private var pendingMealFood: Food?
    @State private var pendingMealItems: [MealItem] = []
    @State private var showMealPlateSummary = false
    private var totalMacros: MacroTotals { viewModel.totalMacros }
    private var plateNutrients: [String: RawNutrientValue] { viewModel.totalNutrients }
    private var plateBackground: Color {
        plateColorScheme == .dark ? Color("bg") : Color(UIColor.systemGroupedBackground)
    }
    private var plateCardColor: Color {
        plateColorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color("bg")
    }
    private var plateChipColor: Color {
        plateColorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }

    init(viewModel: PlateViewModel,
         selectedMealPeriod: MealPeriod,
         mealTime: Date,
         onFinished: (() -> Void)? = nil,
         onPlateLogged: (([Food]) -> Void)? = nil) {
        self.viewModel = viewModel
        _selectedMealPeriod = State(initialValue: selectedMealPeriod)
        _mealTime = State(initialValue: mealTime)
        self.onFinished = onFinished
        self.onPlateLogged = onPlateLogged
        print("[PlateView] init with VM id: \(viewModel.instanceId), entries: \(viewModel.entries.count)")
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                plateItemsSection
                plateListRow {
                    VStack(spacing: 20) {
                        macroSummaryCard
                        mealTimeSelector
                        if viewModel.hasEntries {
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
                        }
                        Color.clear.frame(height: 20)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden)
            .scrollContentBackground(.hidden)

            footerBar
        }
        .background(plateBackground.ignoresSafeArea())
        .navigationTitle("My Plate")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Call onFinished to dismiss the entire sheet stack
                    // instead of just popping back to ConfirmLogView
                    if let onFinished = onFinished {
                        onFinished()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            print("[PlateView] onAppear (VM id: \(viewModel.instanceId)) - entries count: \(viewModel.entries.count)")
            for entry in viewModel.entries {
                print("[PlateView] Entry: \(entry.title)")
            }
            reloadStoredNutrientTargets()
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showConfirmFood) {
            if let food = pendingFood {
                FoodSummaryView(
                    food: food,
                    plateViewModel: viewModel
                )
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            FoodScannerView(isPresented: $showScanner,
                            selectedMeal: selectedMealPeriod.title,
                            onFoodScanned: { food, _ in
                                DispatchQueue.main.async {
                                    showScanner = false
                                    pendingFood = food
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        showConfirmFood = true
                                    }
                                }
                            },
                            plateViewModel: viewModel)  // Pass PlateView's viewModel to preserve plate context
            .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showDescribeLog) {
            FoodLogAgentView(
                isPresented: $showDescribeLog,
                onFoodReady: { food in
                    pendingFood = food
                    showConfirmFood = true
                },
                onMealItemsReady: { food, items in
                    pendingMealFood = food
                    pendingMealItems = items
                    showMealPlateSummary = true
                }
            )
            .environmentObject(foodManager)
        }
        .sheet(isPresented: $showMealPlateSummary) {
            if let food = pendingMealFood {
                NavigationStack {
                    MealPlateSummaryView(
                        foods: [food],
                        mealItems: pendingMealItems,
                        onLogMeal: { _, items in
                            // Log all meal items to the plate
                            for item in items {
                                let entry = buildPlateEntry(from: item)
                                viewModel.add(entry)
                            }
                            showMealPlateSummary = false
                            pendingMealFood = nil
                            pendingMealItems = []
                        },
                        onAddToPlate: { _, items in
                            // Add all meal items to the plate
                            for item in items {
                                let entry = buildPlateEntry(from: item)
                                viewModel.add(entry)
                            }
                            showMealPlateSummary = false
                            pendingMealFood = nil
                            pendingMealItems = []
                        }
                    )
                    .environmentObject(dayLogsVM)
                }
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView(
                isPresented: $showQuickAdd,
                initialMeal: selectedMealPeriod,
                initialDate: mealTime
            ) { food in
                pendingFood = food
                showConfirmFood = true
            }
            .environmentObject(onboardingViewModel)
            .environmentObject(foodManager)
            .environmentObject(dayLogsVM)
        }
        .onReceive(dayLogsVM.$nutritionGoalsVersion) { _ in
            reloadStoredNutrientTargets()
        }
        .onReceive(goalsStore.$state) { _ in
            reloadStoredNutrientTargets()
        }
        .onDisappear {
            // If dismissed without logging (user tapped X), clear entries
            // so they don't persist next time PlateView is opened
            if !isLoggingPlate {
                viewModel.clear()
            }
        }
    }

    private var plateItemsSection: some View {
        Section {
            if viewModel.entries.isEmpty {
                plateListRow {
                    Text("Add foods to build your plate")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .onAppear {
                    print("[PlateView] Entries are EMPTY")
                }
            } else {
                ForEach(viewModel.entries) { entry in
                    plateListRow {
                        PlateEntryRow(
                            entry: entry,
                            onServingsChange: { servings in
                                viewModel.updateServings(for: entry.id, servings: servings)
                            },
                            onMeasureChange: { measureId in
                                viewModel.updateMeasure(for: entry.id, measureId: measureId)
                            },
                            plateCardColor: plateCardColor,
                            chipColor: plateChipColor
                        )
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.remove(entry)
                        } label: {
                            Image(systemName: "trash.fill")
                        }
                    }
                }
            }
        } header: {
            Text("Meal Items")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .textCase(nil)
        }
    }

    private func plateListRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private var mealTimeSelector: some View {
        VStack(spacing: 0) {
            labeledRow("Time", verticalPadding: 10) {
                HStack(spacing: 16) {
                Menu {
                    ForEach(MealPeriod.allCases) { period in
                        Button(period.title) {
                            selectedMealPeriod = period
                        }
                    }
                } label: {
                    capsulePill {
                        HStack(spacing: 4) {
                            Text(selectedMealPeriod.title)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                        .foregroundColor(.primary)
                    }
                }
                .menuIndicator(.hidden)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showMealTimePicker.toggle()
                        }
                    } label: {
                        Text(relativeDayAndTimeString(for: mealTime))
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(plateChipColor)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if showMealTimePicker {
                DatePicker("",
                           selection: $mealTime,
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(plateCardColor)
        )
        .padding(.horizontal)
    }

    private var macroSummaryCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                macroStatRow(title: "Protein", value: totalMacros.protein, unit: "g", color: Color("protein"))
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Fat", value: totalMacros.fat, unit: "g", color: Color("fat"))
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Carbs", value: totalMacros.carbs, unit: "g", color: Color("carbs"))
            }

            Spacer()

            MacroRingView(calories: totalMacros.calories, arcs: macroArcs)
                .frame(width: 100, height: 100)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(plateCardColor)
        )
        .padding(.horizontal)
    }

    private var proteinGoalPercent: Double {
        guard dayLogsVM.proteinGoal > 0 else { return 0 }
        return (totalMacros.protein / dayLogsVM.proteinGoal) * 100
    }

    private var fatGoalPercent: Double {
        guard dayLogsVM.fatGoal > 0 else { return 0 }
        return (totalMacros.fat / dayLogsVM.fatGoal) * 100
    }

    private var carbGoalPercent: Double {
        guard dayLogsVM.carbsGoal > 0 else { return 0 }
        return (totalMacros.carbs / dayLogsVM.carbsGoal) * 100
    }

    private var shouldShowGoalsLoader: Bool {
        nutrientTargets.isEmpty && goalsStore.isLoading
    }

    private var plateMacroSegments: [MacroSegment] {
        let proteinCalories = totalMacros.protein * 4
        let carbCalories = totalMacros.carbs * 4
        let fatCalories = totalMacros.fat * 9
        let total = max(proteinCalories + carbCalories + fatCalories, 1)
        return [
            MacroSegment(color: Color("protein"), fraction: proteinCalories / total),
            MacroSegment(color: Color("fat"), fraction: fatCalories / total),
            MacroSegment(color: Color("carbs"), fraction: carbCalories / total)
        ]
    }

    private var macroArcs: [MacroArc] {
        var running: Double = 0
        return plateMacroSegments.map { segment in
            let arc = MacroArc(start: running, end: running + segment.fraction, color: segment.color)
            running += segment.fraction
            return arc
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

    private var dailyGoalShareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Goal Share")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                GoalShareBubble(title: "Protein",
                                percent: proteinGoalPercent,
                                grams: totalMacros.protein,
                                goal: dayLogsVM.proteinGoal,
                                color: Color("protein"))
                GoalShareBubble(title: "Fat",
                                percent: fatGoalPercent,
                                grams: totalMacros.fat,
                                goal: dayLogsVM.fatGoal,
                                color: Color("fat"))
                GoalShareBubble(title: "Carbs",
                                percent: carbGoalPercent,
                                grams: totalMacros.carbs,
                                goal: dayLogsVM.carbsGoal,
                                color: Color("carbs"))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(plateCardColor)
            )
        }
        .padding(.horizontal)
    }

    private var totalCarbsSection: some View {
        nutrientSection(title: "Total Carbs", rows: NutrientDescriptors.totalCarbRows)
    }

    private var fatTotalsSection: some View {
        nutrientSection(title: "Total Fat", rows: NutrientDescriptors.fatRows)
    }

    private var proteinTotalsSection: some View {
        nutrientSection(title: "Total Protein", rows: NutrientDescriptors.proteinRows)
    }

    private var vitaminSection: some View {
        nutrientSection(title: "Vitamins", rows: NutrientDescriptors.vitaminRows)
    }

    private var mineralSection: some View {
        nutrientSection(title: "Minerals", rows: NutrientDescriptors.mineralRows)
    }

    private var otherNutrientSection: some View {
        nutrientSection(title: "Other", rows: NutrientDescriptors.otherRows)
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
                .fill(plateCardColor)
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
                .fill(plateCardColor)
        )
        .padding(.horizontal)
    }

    private func nutrientSection(title: String, rows: [NutrientRowDescriptor]) -> some View {
        // Filter rows to only show nutrients that exist in the data
        // Zero values ARE shown (e.g., 0g sugar means sugar-free)
        // Only nutrients completely absent from the response are hidden
        let filteredRows = rows.filter { descriptor in
            switch descriptor.source {
            case .macro, .computed:
                // Always show macros and computed values (e.g., net carbs, calories)
                return true
            case .nutrient(let names, _):
                // Show if the nutrient exists in the data (even if value is 0)
                return names.contains { name in
                    plateNutrients[normalizedNutrientKey(name)] != nil
                }
            }
        }

        // Don't render empty sections
        return Group {
            if !filteredRows.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)

                    VStack(spacing: 16) {
                        ForEach(filteredRows) { descriptor in
                            nutrientRow(for: descriptor)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(plateCardColor)
                    )
                }
                .padding(.horizontal)
            }
        }
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

    private func nutrientValue(for descriptor: NutrientRowDescriptor) -> Double {
        switch descriptor.source {
        case .macro(let macro):
            switch macro {
            case .protein: return totalMacros.protein
            case .carbs: return totalMacros.carbs
            case .fat: return totalMacros.fat
            }
        case .nutrient(let names, let aggregation):
            let matches = names.compactMap { plateNutrients[normalizedNutrientKey($0)] }
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
            return convert(perServing, from: sourceUnit, to: targetUnit)
        case .computed(let computation):
            switch computation {
            case .netCarbs:
                return max(totalMacros.carbs - plateFiberValue, 0)
            case .calories:
                return totalMacros.calories
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

    private func convertGoal(_ goal: Double, for descriptor: NutrientRowDescriptor) -> Double {
        guard let slug = descriptor.slug else { return goal }
        switch slug {
        case "alcohol":
            return (goal / 7) * 14
        default:
            return goal
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
        case ("kcal", "cal"): return value * 1000
        case ("cal", "kcal"): return value / 1000
        default: return value
        }
    }

    private func normalizedUnit(_ unit: String?) -> String {
        (unit ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func scaledNutrients(_ nutrients: [Nutrient], scale: Double) -> [Nutrient] {
        nutrients.map { nutrient in
            Nutrient(
                nutrientName: nutrient.nutrientName,
                value: (nutrient.value ?? 0) * scale,
                unitName: nutrient.unitName
            )
        }
    }

    private var plateFiberValue: Double {
        let keys = ["fiber, total dietary", "dietary fiber"]
        guard let match = keys.compactMap({ plateNutrients[normalizedNutrientKey($0)] }).first else {
            return 0
        }
        return convert(match.value, from: match.unit, to: "g")
    }

    private func reloadStoredNutrientTargets() {
        nutrientTargets = goalsStore.currentTargets
    }

    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            HStack(spacing: 12) {
                Button(action: {
                    HapticFeedback.generateLigth()
                    logPlate()
                }) {
                    Text(isLoggingPlate ? "Logging..." : "Log Plate")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(Color("background"))
                )
                .foregroundColor(Color("text"))
                .disabled(isLoggingPlate || viewModel.entries.isEmpty)
                .opacity(isLoggingPlate ? 0.7 : 1)

                Menu {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan Food", systemImage: "barcode.viewfinder")
                    }

                    Button {
                        showDescribeLog = true
                    } label: {
                        Label("Describe", systemImage: "waveform")
                    }

                    Button {
                        AnalyticsManager.shared.trackFoodInputStarted(method: "quick_add")
                        showQuickAdd = true
                    } label: {
                        Label("Quick Add", systemImage: "plus.circle")
                    }
                } label: {
                    Text("Add More")
                        .font(.headline)
                        .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(Color("background"))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(Color("text"))
                .simultaneousGesture(TapGesture().onEnded {
                    HapticFeedback.generateLigth()
                })
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func perServingScale(for entry: PlateEntry) -> Double {
        guard entry.baselineGramWeight > 0 else { return 1 }
        let selectedWeight = entry.selectedMeasureWeight
        guard selectedWeight > 0 else { return 1 }
        return selectedWeight / entry.baselineGramWeight
    }

    private func foodForLogging(from entry: PlateEntry) -> Food {
        let perServingScale = perServingScale(for: entry)
        let totalScale = perServingScale * entry.servings
        var food = entry.food
        food.foodNutrients = scaledNutrients(food.foodNutrients, scale: perServingScale)
        food.numberOfServings = entry.servings
        food.householdServingFullText = servingText(for: entry)
        if let measure = entry.selectedMeasure {
            food.servingSizeUnit = measure.measureUnitName
        }
        if entry.selectedMeasureWeight > 0 {
            food.servingWeightGrams = entry.selectedMeasureWeight
        }
        if !entry.mealItems.isEmpty {
            food.mealItems = entry.mealItems.map { $0.scaled(by: totalScale) }
        }
        return food
    }

    private func servingText(for entry: PlateEntry) -> String {
        let amountText = ConfirmLogView.formattedServings(entry.servings)
        let unitLabel = servingUnitLabel(for: entry.selectedMeasure ?? entry.availableMeasures.first)
        if unitLabel.isEmpty {
            return amountText
        }
        return "\(amountText) \(unitLabel)"
    }

    private func servingUnitLabel(for measure: FoodMeasure?) -> String {
        guard let measure else { return "serving" }
        var label = measure.disseminationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if label.isEmpty {
            label = measure.measureUnitName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let weightParenPattern = "\\s*\\([0-9.]+\\s*(g|oz|ml|mL|fl oz)\\)"
        label = label.replacingOccurrences(of: weightParenPattern, with: "", options: .regularExpression)
        let numberPrefixPattern = "^[0-9]+(\\.[0-9]+)?([/][0-9]+)?\\s*(x|×)?\\s*"
        label = label.replacingOccurrences(of: numberPrefixPattern, with: "", options: .regularExpression)
        return label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func logPlate() {
        let entriesToLog = viewModel.entries
        guard !entriesToLog.isEmpty else { return }
        isLoggingPlate = true

        // Capture foods being logged for the callback
        let foodsToLog = entriesToLog.map { $0.food }

        let mealLabel = selectedMealPeriod.title
        let logDate = mealTime
        let totalMealCalories = entriesToLog.reduce(0) { $0 + $1.macroTotals.calories }

        // Add optimistic logs IMMEDIATELY so timeline shows items instantly
        // Use unique negative IDs to ensure each optimistic log has a distinct id
        // (CombinedLog.id is computed as "food_\(foodLogId ?? 0)", so nil = "food_0" for ALL logs)
        var optimisticLogIds: [String] = []
        for (index, entry) in entriesToLog.enumerated() {
            let food = foodForLogging(from: entry)

            // Use a unique negative ID for each optimistic log
            // Negative IDs don't exist in the backend, making them safe as temporary placeholders
            let tempFoodLogId = -(index + 1)

            // Create optimistic LoggedFoodItem from Food
            let loggedFood = LoggedFoodItem(
                foodLogId: tempFoodLogId,
                fdcId: food.fdcId,
                displayName: food.displayName,
                calories: entry.macroTotals.calories,
                servingSizeText: food.householdServingFullText ?? "1 serving",
                numberOfServings: entry.servings,
                brandText: food.brandText,
                protein: entry.macroTotals.protein,
                carbs: entry.macroTotals.carbs,
                fat: entry.macroTotals.fat,
                healthAnalysis: food.healthAnalysis,
                foodNutrients: food.foodNutrients
            )

            var optimisticLog = CombinedLog(
                type: .food,
                status: "pending",
                calories: entry.macroTotals.calories,
                message: "\(food.displayName) - \(mealLabel)",
                foodLogId: tempFoodLogId,
                food: loggedFood,
                mealType: mealLabel,
                mealLogId: nil,
                meal: nil,
                mealTime: mealLabel,
                scheduledAt: logDate,
                recipeLogId: nil,
                recipe: nil,
                servingsConsumed: nil
            )
            optimisticLog.isOptimistic = true
            optimisticLogIds.append(optimisticLog.id)
            dayLogsVM.addPending(optimisticLog)
        }

        // Navigate to timeline immediately
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToTimeline"), object: nil)

        // Dismiss optimistically - don't wait for API calls
        // Use onFinished callback to properly close the sheet (dismiss() doesn't work reliably for sheets in NavigationStack)
        onFinished?()

        // Notify caller that foods are being logged (for toast/confirmation)
        onPlateLogged?(foodsToLog)

        let batchContext = entriesToLog.count > 1 ? buildBatchContext(from: entriesToLog) : nil
        let lastIndex = entriesToLog.count - 1

        let group = DispatchGroup()
        var pendingLogs: [(index: Int, log: CombinedLog)] = []
        var firstError: Error?

        for (index, entry) in entriesToLog.enumerated() {
            group.enter()

            let food = foodForLogging(from: entry)

            let skipCoach = index != lastIndex
            let context = index == lastIndex ? batchContext : nil

            foodManager.logFood(
                email: onboardingViewModel.email,
                food: food,
                meal: mealLabel,
                servings: entry.servings,
                date: logDate,
                notes: nil,
                skipCoach: skipCoach,
                skipToast: true,
                batchContext: context
            ) { result in
                // Dispatch to main queue to ensure thread-safe access to pendingLogs
                DispatchQueue.main.async {
                    switch result {
                    case .success(let logged):
                        let combined = CombinedLog(
                            type: .food,
                            status: logged.status,
                            calories: Double(logged.food.calories),
                            message: "\(logged.food.displayName) - \(mealLabel)",
                            foodLogId: logged.foodLogId,
                            food: logged.food,
                            mealType: mealLabel,
                            mealLogId: nil,
                            meal: nil,
                            mealTime: mealLabel,
                            scheduledAt: logDate,
                            recipeLogId: nil,
                            recipe: nil,
                            servingsConsumed: nil
                        )
                        pendingLogs.append((index: index, log: combined))
                    case .failure(let error):
                        if firstError == nil {
                            firstError = error
                        }
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            // Remove optimistic logs - they'll be replaced by server-confirmed ones
            for optimisticId in optimisticLogIds {
                dayLogsVM.removeOptimisticLog(identifier: optimisticId)
            }

            let orderedLogs = pendingLogs.sorted { $0.index < $1.index }
            for item in orderedLogs {
                dayLogsVM.addPending(item.log)
            }

            if let error = firstError, pendingLogs.isEmpty {
                isLoggingPlate = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
                return
            }

            if !pendingLogs.isEmpty {
                showMealLoggedToast(totalCalories: totalMealCalories)
            }

            // View is already dismissed optimistically, just reset the flag
            // viewModel.clear() is called by onFinished callback in MainContentView
            isLoggingPlate = false
        }
    }

    private func showMealLoggedToast(totalCalories: Double) {
        foodManager.lastLoggedItem = (name: "Meal", calories: totalCalories)
        foodManager.showLogSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            foodManager.showLogSuccess = false
        }
    }

    private func buildBatchContext(from entries: [PlateEntry]) -> [String: Any] {
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0

        for entry in entries {
            let totals = entry.macroTotals
            totalCalories += totals.calories
            totalProtein += totals.protein
            totalCarbs += totals.carbs
            totalFat += totals.fat
        }

        let foodNames = entries.map { $0.title }
        return [
            "total_calories": totalCalories,
            "total_protein": totalProtein,
            "total_carbs": totalCarbs,
            "total_fat": totalFat,
            "item_count": entries.count,
            "food_names": foodNames
        ]
    }

    private func labeledRow(_ title: String,
                            verticalPadding: CGFloat = 10,
                            @ViewBuilder content: () -> some View) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            content()
        }
        .padding(.vertical, verticalPadding)
    }

    private func capsulePill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(plateChipColor)
            )
    }

    private func buildPlateEntry(from food: Food) -> PlateEntry {
        let baseGramWeight = food.servingSize ?? 100
        let baseMacros = MacroTotals(
            calories: food.calories ?? 0,
            protein: food.protein ?? 0,
            carbs: food.carbs ?? 0,
            fat: food.fat ?? 0
        )
        return PlateEntry(
            food: food,
            servings: 1.0,
            selectedMeasureId: nil,
            availableMeasures: food.foodMeasures,
            baselineGramWeight: baseGramWeight,
            baseNutrientValues: [:],
            baseMacroTotals: baseMacros,
            servingDescription: food.servingSizeText,
            mealItems: food.mealItems ?? [],
            mealPeriod: selectedMealPeriod,
            mealTime: mealTime,
            recipeItems: []
        )
    }

    private func buildPlateEntry(from item: MealItem) -> PlateEntry {
        // Create nutrients array from MealItem macros
        let nutrients: [Nutrient] = [
            Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
            Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
            Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
            Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
        ]

        // Convert MealItemMeasures to FoodMeasures
        // If no measures exist, create a default one using the item's servingUnit
        let foodMeasures: [FoodMeasure]
        if item.measures.isEmpty {
            // Create a default measure from the item's serving unit
            let unitLabel = item.servingUnit ?? "serving"
            foodMeasures = [
                FoodMeasure(
                    disseminationText: unitLabel,
                    gramWeight: item.serving,
                    id: 0,
                    modifier: unitLabel,
                    measureUnitName: unitLabel,
                    rank: 0
                )
            ]
        } else {
            foodMeasures = item.measures.enumerated().map { index, measure in
                FoodMeasure(
                    disseminationText: measure.description,
                    gramWeight: measure.gramWeight,
                    id: index,
                    modifier: measure.description,
                    measureUnitName: measure.unit,
                    rank: index
                )
            }
        }

        // Format serving text - show integer if whole number, decimal otherwise
        let servingText: String
        if item.serving.truncatingRemainder(dividingBy: 1) == 0 {
            servingText = "\(Int(item.serving)) \(item.servingUnit ?? "serving")"
        } else {
            servingText = String(format: "%.1f", item.serving) + " \(item.servingUnit ?? "serving")"
        }

        // Create a Food object from MealItem data
        let food = Food(
            fdcId: item.id.hashValue,
            description: item.name,
            brandOwner: nil,
            brandName: nil,
            servingSize: 1, // Base serving size is 1 unit
            numberOfServings: item.serving, // Use actual serving amount
            servingSizeUnit: item.servingUnit,
            householdServingFullText: servingText,
            foodNutrients: nutrients,
            foodMeasures: foodMeasures
        )

        let baseGramWeight = item.serving
        let baseMacros = MacroTotals(
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat
        )

        return PlateEntry(
            food: food,
            servings: item.serving, // Use actual serving amount
            selectedMeasureId: nil,
            availableMeasures: foodMeasures,
            baselineGramWeight: baseGramWeight,
            baseNutrientValues: [:],
            baseMacroTotals: baseMacros,
            servingDescription: servingText,
            mealItems: [],
            mealPeriod: selectedMealPeriod,
            mealTime: mealTime,
            recipeItems: []
        )
    }
}

private struct PlateEntryRow: View {
    let entry: PlateEntry
    let onServingsChange: (Double) -> Void
    let onMeasureChange: (Int?) -> Void
    let plateCardColor: Color
    let chipColor: Color

    @State private var servingsInput: String
    @State private var isIngredientsExpanded = false

    init(entry: PlateEntry,
         onServingsChange: @escaping (Double) -> Void,
         onMeasureChange: @escaping (Int?) -> Void,
         plateCardColor: Color,
         chipColor: Color) {
        self.entry = entry
        self.onServingsChange = onServingsChange
        self.onMeasureChange = onMeasureChange
        self.plateCardColor = plateCardColor
        self.chipColor = chipColor
        _servingsInput = State(initialValue: ConfirmLogView.formattedServings(entry.servings))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 14))
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    if !entry.brand.isEmpty {
                        Text(entry.brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                servingControl
            }

            HStack(spacing: 10) {
                Label("\(Int(entry.macroTotals.calories.rounded()))cal", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(macroLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }

            // Expand Ingredients disclosure for recipes
            if !entry.recipeItems.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isIngredientsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isIngredientsExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Expand Ingredients (\(entry.recipeItems.count))")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                if isIngredientsExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(entry.recipeItems.enumerated()), id: \.offset) { _, item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                    Text(item.servingText ?? "\(item.servings) serving")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(Int(item.calories.rounded())) cal")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(plateCardColor)
        )
        .onChange(of: entry.servings) { newValue in
            let formatted = ConfirmLogView.formattedServings(newValue)
            if formatted != servingsInput {
                servingsInput = formatted
            }
        }
    }

    private var servingControl: some View {
        HStack(spacing: 6) {
            TextField("1", text: $servingsInput)
                .font(.system(size: 14))
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.done)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(height: 32)
                .frame(minWidth: 40)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    Capsule().fill(chipColor)
                )
                .onChange(of: servingsInput) { newValue in
                    if let parsed = ConfirmLogView.parseServingsInput(newValue) {
                        onServingsChange(parsed)
                    }
                }

            if entry.availableMeasures.count > 1 {
                Menu {
                    ForEach(entry.availableMeasures, id: \.id) { measure in
                        Button(action: { onMeasureChange(measure.id) }) {
                            HStack {
                                Text(shortMeasureLabel(for: measure))
                                Spacer()
                                if measure.id == entry.selectedMeasureId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(shortMeasureLabel(for: entry.selectedMeasure ?? entry.availableMeasures.first))
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: true, vertical: false)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .frame(height: 32)
                    .background(
                        Capsule().fill(chipColor)
                    )
                }
                .menuStyle(.borderlessButton)
            } else {
                Text(shortMeasureLabel(for: entry.selectedMeasure ?? entry.availableMeasures.first))
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .frame(height: 32)
                    .background(
                        Capsule().fill(chipColor)
                    )
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var macroLine: String {
        let totals = entry.macroTotals
        let protein = Int(totals.protein.rounded())
        let carbs = Int(totals.carbs.rounded())
        let fat = Int(totals.fat.rounded())
        return "P \(protein)g C \(carbs)g F \(fat)g • \(weightLabel(for: entry))"
    }

    private func measureLabel(for measure: FoodMeasure?) -> String {
        guard let measure else { return "serving" }
        let trimmed = measure.disseminationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return measure.measureUnitName
    }

    private func shortMeasureLabel(for measure: FoodMeasure?) -> String {
        guard let measure else { return "serving" }
        var label = measureLabel(for: measure)

        // Only strip parenthetical if it contains weight info like "(150g)" or "(5 oz)"
        // Keep descriptive info like "(8 pieces)"
        let weightParenPattern = "\\s*\\([0-9.]+\\s*(g|oz|ml|mL|fl oz)\\)"
        label = label.replacingOccurrences(of: weightParenPattern, with: "", options: .regularExpression)

        // Remove leading numeric prefix like "1 " or "2.5 "
        let numberPrefixPattern = "^[0-9]+(\\.[0-9]+)?([/][0-9]+)?\\s*(x|×)?\\s*"
        label = label.replacingOccurrences(of: numberPrefixPattern, with: "", options: .regularExpression)
        return label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func weightLabel(for entry: PlateEntry) -> String {
        guard let measure = entry.selectedMeasure ?? entry.availableMeasures.first else {
            return "\(entry.totalGramWeight.cleanZeroDecimal)g"
        }
        if let parsed = parsedWeight(from: measure.disseminationText, servings: entry.servings) {
            return parsed
        }
        let unitHint = measure.measureUnitName.lowercased()
        let weight = entry.selectedMeasureWeight * entry.servings
        if unitHint.contains("ml") || measure.disseminationText.lowercased().contains("ml") {
            return "\(weight.cleanZeroDecimal)mL"
        }
        if unitHint.contains("fl") {
            return "\(weight.cleanZeroDecimal)fl oz"
        }
        return "\(weight.cleanZeroDecimal)g"
    }

    private func parsedWeight(from text: String, servings: Double) -> String? {
        let pattern = #"([0-9]*\.?[0-9]+)\s*(ml|mL|fl oz|oz|g)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(location: 0, length: text.utf16.count)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 3,
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let baseValue = Double(text[valueRange]) else { return nil }
        let unitRaw = String(text[unitRange]).lowercased()
        let total = baseValue * servings
        let unitLabel: String
        switch unitRaw {
        case "ml":
            unitLabel = "mL"
        case "fl oz":
            unitLabel = "fl oz"
        case "oz":
            unitLabel = "oz"
        default:
            unitLabel = "g"
        }
        return "\(total.cleanZeroDecimal)\(unitLabel)"
    }
}

struct FoodSummaryView: View {
    let food: Food
    var foodLogId: Int? = nil
    var plateViewModel: PlateViewModel? = nil

    var body: some View {
        NavigationView {
            ConfirmLogView(
                path: .constant(NavigationPath()),
                food: food,
                foodLogId: foodLogId,
                plateViewModel: plateViewModel
            )
        }
    }
}

struct TextLogSheet: View {
    @Binding var isPresented: Bool
    var onFoodReady: (Food) -> Void

    @EnvironmentObject private var foodManager: FoodManager
    @State private var descriptionText: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Describe what you ate", text: $descriptionText, axis: .vertical)
                    .lineLimit(5, reservesSpace: true)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(.systemBackground))
                    .cornerRadius(28)

                if isSubmitting {
                    ProgressView("Analyzing…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Text Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Text Log")
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: submit) {
                        Image(systemName: "checkmark")
                    }
                    .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
            .alert(isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Alert(title: Text("Text Log"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func submit() {
        let prompt = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        isSubmitting = true
        foodManager.generateFoodWithAI(foodDescription: prompt, skipConfirmation: true) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success(let response):
                    switch response.resolvedFoodResult {
                    case .success(let food):
                        onFoodReady(food)
                        isPresented = false
                    case .failure(let genError):
                        errorMessage = genError.localizedDescription
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct QuickAddView: View {
    @Binding var isPresented: Bool
    let initialMeal: MealPeriod
    let initialDate: Date
    var onFoodReady: (Food) -> Void

    @EnvironmentObject private var onboarding: OnboardingViewModel
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel

    @State private var title: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var mealPeriod: MealPeriod
    @State private var mealTime: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(isPresented: Binding<Bool>, initialMeal: MealPeriod, initialDate: Date, onFoodReady: @escaping (Food) -> Void) {
        _isPresented = isPresented
        self.initialMeal = initialMeal
        self.initialDate = initialDate
        self.onFoodReady = onFoodReady
        _mealPeriod = State(initialValue: initialMeal)
        _mealTime = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $title)
                        .autocapitalization(.words)

                    TextField("Calories", text: $calories)
                        .keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $protein)
                        .keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbs)
                        .keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Picker("Meal", selection: $mealPeriod) {
                        ForEach(MealPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }

                    DatePicker("Time", selection: $mealTime)
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Quick Add").font(.headline)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addToPlate) {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!canSave)
                }
            }
            .alert(isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Alert(title: Text("Quick Add"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var canSave: Bool {
        guard let cal = Double(calories), cal > 0 else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addToPlate() {
        guard let food = makeFood() else { return }
        onFoodReady(food)
        isPresented = false
    }

    private func makeFood() -> Food? {
        guard canSave else { return nil }
        let caloriesValue = Double(calories) ?? 0
        let proteinValue = Double(protein) ?? 0
        let carbValue = Double(carbs) ?? 0
        let fatValue = Double(fat) ?? 0

        let nutrients = [
            Nutrient(nutrientName: "Energy", value: caloriesValue, unitName: "kcal"),
            Nutrient(nutrientName: "Protein", value: proteinValue, unitName: "g"),
            Nutrient(nutrientName: "Carbohydrate, by difference", value: carbValue, unitName: "g"),
            Nutrient(nutrientName: "Total lipid (fat)", value: fatValue, unitName: "g")
        ]

        return Food(
            fdcId: Int(Date().timeIntervalSince1970 * 1000),
            description: title.trimmingCharacters(in: .whitespacesAndNewlines),
            brandOwner: nil,
            brandName: nil,
            servingSize: 1,
            numberOfServings: 1,
            servingSizeUnit: "serving",
            householdServingFullText: "1 serving",
            foodNutrients: nutrients,
            foodMeasures: [],
            mealItems: nil
        )
    }
}

struct AddToPlateWithVoice: View {
    @Binding var isPresented: Bool
    let selectedMeal: String
    var onFoodReady: (Food) -> Void

    @EnvironmentObject private var foodManager: FoodManager
    @StateObject private var audioRecorder = CreateFoodAudioRecorder()
    @State private var isGeneratingFood = false
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color("primarybg"), Color("chat").opacity(0.25)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()

                    VStack(spacing: 24) {
                        VoiceFluidView(
                            level: audioRecorder.audioLevel,
                            samples: audioRecorder.audioSamples,
                            isActive: audioRecorder.isRecording || audioRecorder.isProcessing || isGeneratingFood
                        )
                        .frame(width: min(geometry.size.width * 0.7, 260),
                               height: min(geometry.size.width * 0.7, 260))

                        if audioRecorder.isProcessing || isGeneratingFood {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                                .scaleEffect(1.2)
                        }

                        if !audioRecorder.transcribedText.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Preview")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(UIColor.secondaryLabel))

                                ScrollView {
                                    Text(audioRecorder.transcribedText)
                                        .font(.system(size: 17, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 140)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 28)

                    Spacer()

                    HStack {
                        Button(action: {
                            cancelRecording()
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                                .frame(width: 60, height: 60)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(.systemGray3), lineWidth: 1))
                        }

                        Spacer()

                        Button(action: handleConfirmTap) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 24))
                                .foregroundColor(.primary)
                                .frame(width: 60, height: 60)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(.systemGray3), lineWidth: 1))
                                .opacity(isGeneratingFood ? 0.5 : 1)
                        }
                        .disabled(isGeneratingFood)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 24 : 40)
                }
            }
        }
        .onAppear {
            AudioSessionManager.shared.activateSession()
            checkMicrophonePermission()
        }
        .onDisappear {
            cancelRecording()
            AudioSessionManager.shared.deactivateSession()
        }
        .alert(isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Alert(title: Text("Voice Logging"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    private func handleConfirmTap() {
        guard !isGeneratingFood else { return }

        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            waitForTranscriptionThenGenerate()
        } else {
            waitForTranscriptionThenGenerate()
        }
    }

    private func waitForTranscriptionThenGenerate() {
        if !audioRecorder.transcribedText.isEmpty {
            generateFoodFromTranscription()
            return
        }

        guard audioRecorder.isProcessing else {
            errorMessage = "We couldn't capture that. Try again."
            return
        }

        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { timer in
            if !audioRecorder.transcribedText.isEmpty {
                timer.invalidate()
                generateFoodFromTranscription()
            } else if !audioRecorder.isProcessing {
                timer.invalidate()
                errorMessage = "Transcription failed. Please try again."
            }
        }
    }

    private func generateFoodFromTranscription() {
        guard !audioRecorder.transcribedText.isEmpty else {
            errorMessage = "Please describe the meal first."
            return
        }

        isGeneratingFood = true
        foodManager.generateFoodWithAI(foodDescription: audioRecorder.transcribedText, skipConfirmation: true) { result in
            DispatchQueue.main.async {
                isGeneratingFood = false
                switch result {
                case .success(let response):
                    switch response.resolvedFoodResult {
                    case .success(let food):
                        onFoodReady(food)
                        isPresented = false
                    case .failure(let genError):
                        errorMessage = genError.localizedDescription
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func checkMicrophonePermission() {
        let audioSession = AVAudioSession.sharedInstance()

        switch audioSession.recordPermission {
        case .granted:
            audioRecorder.startRecording()
        case .denied:
            errorMessage = "Microphone access is required to capture your meal."
        case .undetermined:
            audioSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        audioRecorder.startRecording()
                    } else {
                        errorMessage = "Microphone access is required to capture your meal."
                    }
                }
            }
        @unknown default:
            errorMessage = "Microphone access is required to capture your meal."
        }
    }

    private func cancelRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording(cancel: true)
        }
    }
}

enum CustomFoodAction {
    case createOnly
    case createAndAdd
}

// MARK: - Uses shared NutrientDescriptors from NutrientDescriptors.swift

private let relativeDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "E MMM d"
    return formatter
}()

private let relativeTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
}()

private func relativeDayAndTimeString(for date: Date) -> String {
    let time = relativeTimeFormatter.string(from: date)
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return "Today, \(time)"
    }
    if calendar.isDateInYesterday(date) {
        return "Yesterday, \(time)"
    }
    return "\(relativeDayFormatter.string(from: date)), \(time)"
}

#if DEBUG
private struct MealItemServingControlsPreview: View {
    @State private var item = MealItem(
        name: "Greek Yogurt",
        serving: 1,
        servingUnit: "cup",
        calories: 120,
        protein: 20,
        carbs: 9,
        fat: 0,
        subitems: nil,
        baselineServing: 1,
        measures: [
            MealItemMeasure(unit: "cup", description: "1 cup (227 g)", gramWeight: 227),
            MealItemMeasure(unit: "tbsp", description: "1 tbsp (15 g)", gramWeight: 15),
            MealItemMeasure(unit: "oz", description: "1 oz (28 g)", gramWeight: 28)
        ]
    )

    var body: some View {
        MealItemServingControls(item: $item)
            .padding()
            .background(Color("bg"))
            .previewLayout(.sizeThatFits)
    }
}

#Preview("Meal Item Measure Picker") {
    MealItemServingControlsPreview()
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .preferredColorScheme(.dark)
}
#endif

// Source enums now defined in NutrientDescriptors.swift

extension Double {
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
    // Uses global normalizedNutrientKey() from NutrientDescriptors.swift

    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
