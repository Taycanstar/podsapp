//
//  MultiFoodLogView.swift
//  pods
//
//  Created by Codex on 12/14/25.
//

import SwiftUI

struct MultiFoodLogView: View {
    let foods: [Food]
    var mealItems: [MealItem] = []
    // Pass existing PlateViewModel to preserve plate context when adding more items
    var plateViewModel: PlateViewModel? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel

    @State private var selectedFood: Food?
    @State private var selectedMealPeriod: MealPeriod = .lunch
    @State private var mealTime: Date = Date()
    @State private var showMealTimePicker = false
    @State private var isLogging = false
    @State private var nutrientTargets: [String: NutrientTargetDetails] = NutritionGoalsStore.shared.currentTargets
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared

    /// Editable serving state for each food item (keyed by food index)
    @State private var editableItems: [Int: EditableFoodItem] = [:]

    /// Track deleted food indices for swipe-to-delete
    @State private var deletedFoodIndices: Set<Int> = []

    private var plateBackground: Color {
        colorScheme == .dark ? Color("bg") : Color(UIColor.systemGroupedBackground)
    }
    private var cardColor: Color {
        colorScheme == .dark ? Color(UIColor.systemGroupedBackground) : Color("bg")
    }
    private var chipColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }
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

    // MARK: - Display Foods Logic
    /// All foods derived from input (before filtering deleted items)
    private var allDisplayFoods: [Food] {
        if foods.count > 1 {
            return foods
        }
        // PRIORITY: Use top-level mealItems if available (has full nutrients from fast_food_image)
        // Fall back to embedded food.mealItems only if top-level is empty
        if !mealItems.isEmpty {
            print("[MultiFoodLogView] Using top-level mealItems (\(mealItems.count) items)")
            return mealItems.map { item in
                print("[MultiFoodLogView] Item '\(item.name)': foodNutrients count = \(item.foodNutrients?.count ?? 0)")
                if let first = item.foodNutrients?.first {
                    print("[MultiFoodLogView] Sample nutrient: \(first.nutrientName) = \(first.value ?? 0) \(first.unitName)")
                }

                let unitLabel = item.servingUnit ?? "serving"
                let defaultMeasure = FoodMeasure(
                    disseminationText: unitLabel,
                    gramWeight: item.serving,
                    id: 0,
                    modifier: unitLabel,
                    measureUnitName: unitLabel,
                    rank: 0
                )
                let nutrients: [Nutrient]
                if let fullNutrients = item.foodNutrients, !fullNutrients.isEmpty {
                    print("[MultiFoodLogView] Using \(fullNutrients.count) full nutrients for '\(item.name)'")
                    nutrients = fullNutrients
                } else {
                    print("[MultiFoodLogView] Using 4 basic macros fallback for '\(item.name)'")
                    nutrients = [
                        Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                        Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                        Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                        Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
                    ]
                }
                return Food(
                    fdcId: item.id.hashValue,
                    description: item.name,
                    brandOwner: nil,
                    brandName: nil,
                    servingSize: item.serving,
                    numberOfServings: 1,
                    servingSizeUnit: item.servingUnit,
                    householdServingFullText: item.originalServing?.resolvedText ?? "\(Int(item.serving)) \(item.servingUnit ?? "serving")",
                    foodNutrients: nutrients,
                    foodMeasures: [defaultMeasure],
                    healthAnalysis: nil,
                    aiInsight: nil,
                    nutritionScore: nil,
                    mealItems: item.subitems
                )
            }
        }
        // Fallback: Use embedded mealItems from Food object (legacy path)
        if let first = foods.first, let items = first.mealItems, !items.isEmpty {
            print("[MultiFoodLogView] Using embedded food.mealItems (\(items.count) items)")
            return items.map { item in
                // Create a default measure with the item's serving unit
                let unitLabel = item.servingUnit ?? "serving"
                let defaultMeasure = FoodMeasure(
                    disseminationText: unitLabel,
                    gramWeight: item.serving,
                    id: 0,
                    modifier: unitLabel,
                    measureUnitName: unitLabel,
                    rank: 0
                )
                // Use full nutrients if available, otherwise fallback to basic macros
                let nutrients: [Nutrient]
                if let fullNutrients = item.foodNutrients, !fullNutrients.isEmpty {
                    nutrients = fullNutrients
                } else {
                    nutrients = [
                        Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                        Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                        Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                        Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
                    ]
                }
                return Food(
                    fdcId: item.id.hashValue,
                    description: item.name,
                    brandOwner: nil,
                    brandName: nil,
                    servingSize: item.serving,
                    numberOfServings: 1,
                    servingSizeUnit: item.servingUnit,
                    householdServingFullText: item.originalServing?.resolvedText ?? "\(Int(item.serving)) \(item.servingUnit ?? "serving")",
                    foodNutrients: nutrients,
                    foodMeasures: [defaultMeasure],
                    healthAnalysis: nil,
                    aiInsight: nil,
                    nutritionScore: nil,
                    mealItems: item.subitems
                )
            }
        }
        // Final fallback: return empty array
        return []
    }

    /// Filtered display foods excluding deleted items
    private var displayFoods: [Food] {
        allDisplayFoods
    }

    /// Foods with their original indices for display (excludes deleted)
    private var displayFoodsWithIndices: [(index: Int, food: Food)] {
        allDisplayFoods.enumerated()
            .filter { !deletedFoodIndices.contains($0.offset) }
            .map { (index: $0.offset, food: $0.element) }
    }

    /// Delete a food item at the given index
    private func deleteFood(at index: Int) {
        deletedFoodIndices.insert(index)
        editableItems.removeValue(forKey: index)
    }

    // MARK: - Computed Macros
    private var totalMacros: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        var cals: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0

        // Use editable items for scaling if available (excludes deleted items)
        for item in displayFoodsWithIndices {
            let scalingFactor = editableItems[item.index]?.scalingFactor ?? 1.0
            cals += (item.food.calories ?? 0) * scalingFactor
            protein += (item.food.protein ?? 0) * scalingFactor
            carbs += (item.food.carbs ?? 0) * scalingFactor
            fat += (item.food.fat ?? 0) * scalingFactor
        }

        return (cals, protein, carbs, fat)
    }

    private var macroArcs: [MultiFoodMacroArc] {
        let proteinCalories = totalMacros.protein * 4
        let carbCalories = totalMacros.carbs * 4
        let fatCalories = totalMacros.fat * 9
        let total = max(proteinCalories + carbCalories + fatCalories, 1)
        let segments = [
            (color: Color("protein"), fraction: proteinCalories / total),
            (color: Color("fat"), fraction: fatCalories / total),
            (color: Color("carbs"), fraction: carbCalories / total)
        ]
        var running: Double = 0
        return segments.map { segment in
            let arc = MultiFoodMacroArc(start: running, end: running + segment.fraction, color: segment.color)
            running += segment.fraction
            return arc
        }
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

    private var aggregatedNutrients: [String: MultiFoodRawNutrientValue] {
        var result: [String: MultiFoodRawNutrientValue] = [:]
        // Use displayFoodsWithIndices to exclude deleted items
        for item in displayFoodsWithIndices {
            let scalingFactor = editableItems[item.index]?.scalingFactor ?? 1.0
            for nutrient in item.food.foodNutrients {
                let key = normalizedNutrientKey(nutrient.nutrientName)
                let value = (nutrient.value ?? 0) * scalingFactor
                if let existing = result[key] {
                    result[key] = MultiFoodRawNutrientValue(value: existing.value + value, unit: existing.unit)
                } else {
                    result[key] = MultiFoodRawNutrientValue(value: value, unit: nutrient.unitName)
                }
            }
        }
        return result
    }

    // Uses global normalizedNutrientKey() from NutrientDescriptors.swift

    private var fiberValue: Double {
        let keys = ["fiber, total dietary", "dietary fiber", "fiber"]
        for key in keys {
            if let val = aggregatedNutrients[normalizedNutrientKey(key)]?.value, val > 0 {
                return val
            }
        }
        return 0
    }

    private var shouldShowGoalsLoader: Bool {
        if case .loading = goalsStore.state { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        mealItemsSection
                        macroSummaryCard
                        mealTimeSelector
                        dailyGoalShareCard
                        if !mealItems.isEmpty || !displayFoods.isEmpty {
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
                        Spacer(minLength: 20)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }

                footerBar
            }
            .background(plateBackground.ignoresSafeArea())
            .navigationTitle("My Meal")
            .navigationBarTitleDisplayMode(.inline)
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
            .navigationDestination(item: $selectedFood) { food in
                FoodDetails(food: food)
                    .environmentObject(dayLogsVM)
                    .environmentObject(foodManager)
            }
            .onAppear {
                selectedMealPeriod = suggestedMealPeriod(for: Date())
                reloadStoredNutrientTargets()
                initializeEditableItems()
            }
            .onReceive(dayLogsVM.$nutritionGoalsVersion) { _ in
                reloadStoredNutrientTargets()
            }
            .onReceive(goalsStore.$state) { _ in
                reloadStoredNutrientTargets()
            }
        }
    }

    private func reloadStoredNutrientTargets() {
        nutrientTargets = NutritionGoalsStore.shared.currentTargets
    }

    private func initializeEditableItems() {
        guard editableItems.isEmpty else { return }

        // Initialize editable state for each food item
        for (index, food) in displayFoods.enumerated() {
            // Check if this food came from a MealItem with measures
            if let mealItem = mealItems.first(where: { $0.name == food.displayName }) {
                editableItems[index] = EditableFoodItem(from: mealItem)
            } else if let mealItem = food.mealItems?.first {
                editableItems[index] = EditableFoodItem(from: mealItem)
            } else {
                editableItems[index] = EditableFoodItem(from: food, index: index)
            }
        }
    }

    // MARK: - Meal Items Section
    private var mealItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Items")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if displayFoodsWithIndices.isEmpty {
                Text("No meal items found")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                List {
                    ForEach(displayFoodsWithIndices, id: \.food.id) { item in
                        MultiFoodEditableItemRow(
                            food: item.food,
                            editableItem: editableItemBinding(for: item.index),
                            cardColor: cardColor,
                            chipColor: chipColor,
                            onTap: {
                                selectedFood = item.food
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteFood(at: item.index)
                            } label: {
                                Image(systemName: "trash.fill")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        // Convert display indices to original indices and delete
                        for displayIndex in indexSet {
                            if displayIndex < displayFoodsWithIndices.count {
                                let originalIndex = displayFoodsWithIndices[displayIndex].index
                                deleteFood(at: originalIndex)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(minHeight: CGFloat(displayFoodsWithIndices.count) * 100)
            }
        }
    }

    /// Create a binding for an editable item at a given index
    private func editableItemBinding(for index: Int) -> Binding<EditableFoodItem> {
        Binding(
            get: {
                editableItems[index] ?? EditableFoodItem(from: displayFoods[index], index: index)
            },
            set: { newValue in
                editableItems[index] = newValue
            }
        )
    }

    // MARK: - Macro Summary Card
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

            MultiFoodMacroRingView(calories: totalMacros.calories, arcs: macroArcs)
                .frame(width: 100, height: 100)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
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

    // MARK: - Meal Time Selector
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
                                    .fill(chipColor)
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
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    // MARK: - Daily Goal Share Card
    private var dailyGoalShareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Goal Share")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                MultiFoodGoalShareBubble(title: "Protein",
                                percent: proteinGoalPercent,
                                grams: totalMacros.protein,
                                goal: dayLogsVM.proteinGoal,
                                color: Color("protein"))
                MultiFoodGoalShareBubble(title: "Fat",
                                percent: fatGoalPercent,
                                grams: totalMacros.fat,
                                goal: dayLogsVM.fatGoal,
                                color: Color("fat"))
                MultiFoodGoalShareBubble(title: "Carbs",
                                percent: carbGoalPercent,
                                grams: totalMacros.carbs,
                                goal: dayLogsVM.carbsGoal,
                                color: Color("carbs"))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(cardColor)
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            HStack(spacing: 12) {
                Button(action: {
                    HapticFeedback.generateLigth()
                    logAllFoods()
                }) {
                    Text(isLogging ? "Logging..." : "Log Meal")
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
                .disabled(isLogging || displayFoodsWithIndices.isEmpty)
                .opacity(isLogging ? 0.7 : 1)

                Button(action: {
                    HapticFeedback.generateLigth()
                    addToPlate()
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
                .disabled(displayFoodsWithIndices.isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Helper Views
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
                    .fill(chipColor)
            )
    }

    private func relativeDayAndTimeString(for date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Today, \(timeString)"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(timeString)"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow, \(timeString)"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "MMM d"
            return "\(dayFormatter.string(from: date)), \(timeString)"
        }
    }

    private func suggestedMealPeriod(for date: Date) -> MealPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return .breakfast
        case 11..<15:
            return .lunch
        case 15..<21:
            return .dinner
        default:
            return .snack
        }
    }

    // MARK: - Data Helpers
    private var mealItemsFromFoodsOrFallback: [MultiFoodItemListDisplay] {
        if !mealItems.isEmpty {
            return mealItems.map {
                MultiFoodItemListDisplay(
                    id: $0.id.uuidString,
                    name: $0.name,
                    brand: nil,
                    servingText: servingDescription(for: $0),
                    calories: $0.calories ?? 0,
                    protein: $0.protein ?? 0,
                    carbs: $0.carbs ?? 0,
                    fat: $0.fat ?? 0
                )
            }
        }

        return displayFoods.map { food in
            MultiFoodItemListDisplay(
                id: String(food.id),
                name: food.displayName,
                brand: food.brandText,
                servingText: food.servingSizeText,
                calories: food.calories ?? 0,
                protein: food.protein ?? 0,
                carbs: food.carbs ?? 0,
                fat: food.fat ?? 0
            )
        }
    }

    private func servingDescription(for item: MealItem) -> String? {
        let amount = item.serving
        let unit = item.servingUnit ?? "serving"
        let amountText: String
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            amountText = String(Int(amount))
        } else {
            amountText = String(format: "%.2f", amount).replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
        }
        return "\(amountText) \(unit)"
    }

    private func foodForMealItem(_ item: MultiFoodItemListDisplay) -> Food? {
        if let match = displayFoods.first(where: { $0.displayName == item.name }) {
            return match
        }
        return displayFoods.first
    }

    // MARK: - Nutrient Sections

    private var totalCarbsSection: some View {
        nutrientSection(title: "Total Carbs", rows: MultiFoodNutrientDescriptors.totalCarbRows)
    }

    private var fatTotalsSection: some View {
        nutrientSection(title: "Total Fat", rows: MultiFoodNutrientDescriptors.fatRows)
    }

    private var proteinTotalsSection: some View {
        nutrientSection(title: "Total Protein", rows: MultiFoodNutrientDescriptors.proteinRows)
    }

    private var vitaminSection: some View {
        nutrientSection(title: "Vitamins", rows: MultiFoodNutrientDescriptors.vitaminRows)
    }

    private var mineralSection: some View {
        nutrientSection(title: "Minerals", rows: MultiFoodNutrientDescriptors.mineralRows)
    }

    private var otherNutrientSection: some View {
        nutrientSection(title: "Other", rows: MultiFoodNutrientDescriptors.otherRows)
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
            Text("We'll automatically sync your nutrition plan and show daily percentages once it's ready.")
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

    private func nutrientSection(title: String, rows: [MultiFoodNutrientRowDescriptor]) -> some View {
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
                    aggregatedNutrients[normalizedNutrientKey(name)] != nil
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
    private func nutrientRow(for descriptor: MultiFoodNutrientRowDescriptor) -> some View {
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

    private func nutrientValue(for descriptor: MultiFoodNutrientRowDescriptor) -> Double {
        switch descriptor.source {
        case .macro(let macro):
            switch macro {
            case .protein: return totalMacros.protein
            case .carbs: return totalMacros.carbs
            case .fat: return totalMacros.fat
            }
        case .nutrient(let names, let aggregation):
            let matches = names.compactMap { aggregatedNutrients[normalizedNutrientKey($0)] }
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
                return max(totalMacros.carbs - fiberValue, 0)
            case .calories:
                return totalMacros.calories
            }
        }
    }

    private func nutrientGoal(for descriptor: MultiFoodNutrientRowDescriptor) -> Double? {
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

    private func nutrientUnit(for descriptor: MultiFoodNutrientRowDescriptor) -> String {
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

    private func convert(_ value: Double, from sourceUnit: String?, to targetUnit: String) -> Double {
        guard let sourceUnit, !sourceUnit.isEmpty else { return value }
        let src = sourceUnit.lowercased()
        let dst = targetUnit.lowercased()
        if src == dst { return value }

        if src == "mg" && dst == "g" {
            return value / 1000
        }
        if src == "g" && dst == "mg" {
            return value * 1000
        }
        if src == "µg" || src == "mcg" {
            if dst == "mg" { return value / 1000 }
            if dst == "g" { return value / 1_000_000 }
        }
        if (src == "mg" || src == "g") && (dst == "µg" || dst == "mcg") {
            if src == "mg" { return value * 1000 }
            if src == "g" { return value * 1_000_000 }
        }
        return value
    }

    private func convertGoal(_ goal: Double, for descriptor: MultiFoodNutrientRowDescriptor) -> Double {
        guard let slug = descriptor.slug,
              let storedUnit = nutrientTargets[slug]?.unit,
              !storedUnit.isEmpty else { return goal }
        let src = storedUnit.lowercased()
        let dst = descriptor.defaultUnit.lowercased()
        if src == dst { return goal }

        if src == "mg" && dst == "g" { return goal / 1000 }
        if src == "g" && dst == "mg" { return goal * 1000 }
        if (src == "µg" || src == "mcg") && dst == "mg" { return goal / 1000 }
        if (src == "µg" || src == "mcg") && dst == "g" { return goal / 1_000_000 }
        if src == "mg" && (dst == "µg" || dst == "mcg") { return goal * 1000 }
        if src == "g" && (dst == "µg" || dst == "mcg") { return goal * 1_000_000 }

        return goal
    }

    // MARK: - Logging Functions (kept from original)

    private func logAllFoods() {
        let foodsToLog = displayFoodsWithIndices
        guard !foodsToLog.isEmpty else { return }
        isLogging = true

        let mealLabel = selectedMealPeriod.title
        let logDate = mealTime
        let batchContext = foodsToLog.count > 1 ? buildBatchContext() : nil

        let baseId = Int(Date().timeIntervalSince1970 * 1000)
        var optimisticIdentifiers: [Int: String] = [:]
        var totalMealCalories: Double = 0

        for (listIndex, item) in foodsToLog.enumerated() {
            let editableItem = editableItems[item.index]
            let loggingPayload = foodForLogging(item.food, editableItem: editableItem)
            let loggingFood = loggingPayload.food
            let servings = loggingPayload.servings

            let tempFoodLogId = -(baseId + listIndex + 1)
            let totalCalories = (loggingFood.calories ?? 0) * servings
            let servingText = loggingFood.householdServingFullText ?? "1 serving"
            totalMealCalories += totalCalories

            let loggedFood = LoggedFoodItem(
                foodLogId: tempFoodLogId,
                fdcId: loggingFood.fdcId,
                displayName: loggingFood.displayName,
                calories: totalCalories,
                servingSizeText: servingText,
                numberOfServings: servings,
                brandText: loggingFood.brandText,
                protein: loggingFood.protein,
                carbs: loggingFood.carbs,
                fat: loggingFood.fat,
                healthAnalysis: loggingFood.healthAnalysis,
                foodNutrients: loggingFood.foodNutrients,
                aiInsight: loggingFood.aiInsight,
                nutritionScore: loggingFood.nutritionScore,
                mealItems: loggingFood.mealItems,
                servingWeightGrams: loggingFood.servingWeightGrams,
                foodMeasures: loggingFood.foodMeasures
            )

            let logDateString = Self.isoDayFormatter.string(from: logDate)
            let dayName = Self.weekdayFormatter.string(from: logDate)

            var optimisticLog = CombinedLog(
                type: .food,
                status: "pending",
                calories: totalCalories,
                message: "\(loggingFood.displayName) - \(mealLabel)",
                foodLogId: tempFoodLogId,
                food: loggedFood,
                mealType: mealLabel,
                mealLogId: nil,
                meal: nil,
                mealTime: mealLabel,
                scheduledAt: logDate,
                recipeLogId: nil,
                recipe: nil,
                servingsConsumed: nil,
                logDate: logDateString,
                dayOfWeek: dayName,
                isOptimistic: true
            )
            optimisticLog.isOptimistic = true
            optimisticIdentifiers[listIndex] = optimisticLog.id
            dayLogsVM.addPending(optimisticLog)
            upsertCombinedLog(optimisticLog)
        }

        // Navigate to timeline immediately
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToTimeline"), object: nil)
        dismiss()

        let mealCalories = totalMealCalories
        var pendingResponses = foodsToLog.count
        var successCount = 0
        var didShowMealToast = false

        for (listIndex, item) in foodsToLog.enumerated() {
            let editableItem = editableItems[item.index]
            let loggingPayload = foodForLogging(item.food, editableItem: editableItem)
            let loggingFood = loggingPayload.food
            let servings = loggingPayload.servings
            let isLastFood = listIndex == foodsToLog.count - 1

            let skipCoach = !isLastFood
            let context: [String: Any]? = isLastFood ? batchContext : nil
            let placeholderId = optimisticIdentifiers[listIndex] ?? ""

            foodManager.logFood(
                email: onboardingViewModel.email,
                food: loggingFood,
                meal: mealLabel,
                servings: servings,
                date: logDate,
                notes: nil,
                skipCoach: skipCoach,
                skipToast: true,
                batchContext: context
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let logged):
                        successCount += 1
                        let combined = CombinedLog(
                            type: .food,
                            status: logged.status,
                            calories: Double(logged.food.calories),
                            message: "\(logged.food.displayName) - \(logged.mealType)",
                            foodLogId: logged.foodLogId,
                            food: logged.food,
                            mealType: logged.mealType,
                            mealLogId: nil,
                            meal: nil,
                            mealTime: logged.mealType,
                            scheduledAt: logDate,
                            recipeLogId: nil,
                            recipe: nil,
                            servingsConsumed: nil
                        )
                        if !placeholderId.isEmpty {
                            dayLogsVM.replaceOptimisticLog(identifier: placeholderId, with: combined)
                            upsertCombinedLog(combined, replacing: placeholderId)
                        } else {
                            dayLogsVM.addPending(combined)
                            upsertCombinedLog(combined)
                        }
                    case .failure:
                        if !placeholderId.isEmpty {
                            dayLogsVM.removeOptimisticLog(identifier: placeholderId)
                            removeCombinedLog(identifier: placeholderId)
                        }
                    }
                    pendingResponses -= 1
                    if pendingResponses == 0, successCount > 0, !didShowMealToast {
                        didShowMealToast = true
                        showMealLoggedToast(totalCalories: mealCalories)
                    }
                }
            }
        }

        isLogging = false
    }

    private func showMealLoggedToast(totalCalories: Double) {
        foodManager.lastLoggedItem = (name: "Meal", calories: totalCalories)
        foodManager.showLogSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            foodManager.showLogSuccess = false
        }
    }

    /// Build batch context for multi-food coach message
    private func buildBatchContext() -> [String: Any] {
        // Use scaled values from editable items (excludes deleted)
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0

        for item in displayFoodsWithIndices {
            let scalingFactor = editableItems[item.index]?.scalingFactor ?? 1.0
            totalCalories += (item.food.calories ?? 0) * scalingFactor
            totalProtein += (item.food.protein ?? 0) * scalingFactor
            totalCarbs += (item.food.carbs ?? 0) * scalingFactor
            totalFat += (item.food.fat ?? 0) * scalingFactor
        }

        let foodNames = displayFoodsWithIndices.map { $0.food.displayName }

        return [
            "total_calories": totalCalories,
            "total_protein": totalProtein,
            "total_carbs": totalCarbs,
            "total_fat": totalFat,
            "item_count": displayFoodsWithIndices.count,
            "food_names": foodNames
        ]
    }

    private func perServingScale(for editableItem: EditableFoodItem) -> Double {
        if let baselineWeight = editableItem.measures.first(where: { $0.id == editableItem.baselineMeasureId })?.gramWeight,
           baselineWeight > 0,
           let selectedWeight = editableItem.selectedMeasure?.gramWeight,
           selectedWeight > 0 {
            return selectedWeight / baselineWeight
        }
        return 1
    }

    private func servingText(for editableItem: EditableFoodItem) -> String {
        let amountText = EditableFoodItem.formatServing(editableItem.servingAmount)
        let unitLabel = servingUnitLabel(for: editableItem.selectedMeasure)
        if unitLabel.isEmpty {
            return amountText
        }
        return "\(amountText) \(unitLabel)"
    }

    private func servingUnitLabel(for measure: MealItemMeasure?) -> String {
        guard let measure else { return "serving" }
        let description = sanitizedServingDescription(measure.description)
        if !description.isEmpty {
            return description
        }
        return measure.unit.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizedServingDescription(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        if let range = trimmed.range(of: "(") {
            trimmed = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let numberPrefixPattern = "^[0-9]+(\\.[0-9]+)?([/][0-9]+)?\\s*(x|×)?\\s*"
        trimmed = trimmed.replacingOccurrences(of: numberPrefixPattern, with: "", options: .regularExpression)
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func foodForLogging(_ food: Food, editableItem: EditableFoodItem?) -> (food: Food, servings: Double) {
        guard let editableItem else {
            return (food, food.numberOfServings ?? 1)
        }
        let perServingScale = perServingScale(for: editableItem)
        let servings = max(editableItem.servingAmount, 0.0001)
        let totalScale = perServingScale * servings

        var updatedFood = food
        updatedFood.foodNutrients = scaledNutrients(food.foodNutrients, scale: perServingScale)
        updatedFood.numberOfServings = servings
        updatedFood.householdServingFullText = servingText(for: editableItem)
        updatedFood.servingSize = 1
        updatedFood.servingSizeUnit = editableItem.selectedMeasure?.unit ?? food.servingSizeUnit
        if let gramWeight = editableItem.selectedMeasure?.gramWeight, gramWeight > 0 {
            updatedFood.servingWeightGrams = gramWeight
        }
        if let mealItems = updatedFood.mealItems, !mealItems.isEmpty {
            updatedFood.mealItems = mealItems.map { $0.scaled(by: totalScale) }
        }
        return (updatedFood, servings)
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

    private func addToPlate() {
        // Add only non-deleted foods to plate and dismiss
        let remainingFoods = displayFoodsWithIndices.map { $0.food }

        // Build edited meal items with current serving amounts/units from editableItems
        var editedMealItems: [MealItem] = []
        for (originalIndex, mealItem) in mealItems.enumerated() {
            guard !deletedFoodIndices.contains(originalIndex) else { continue }

            var editedItem = mealItem
            if let editableState = editableItems[originalIndex] {
                // Apply the edited serving amount
                editedItem.serving = editableState.servingAmount
                // Apply selected measure if changed
                if let selectedId = editableState.selectedMeasureId {
                    editedItem.selectedMeasureId = selectedId
                    // Update servingUnit to match selected measure's description
                    if let selectedMeasure = editableState.measures.first(where: { $0.id == selectedId }) {
                        editedItem.servingUnit = selectedMeasure.description.isEmpty
                            ? selectedMeasure.unit
                            : selectedMeasure.description
                    }
                }
            }
            editedMealItems.append(editedItem)
        }

        NotificationCenter.default.post(
            name: NSNotification.Name("AddToPlate"),
            object: nil,
            userInfo: [
                "foods": remainingFoods,
                "mealItems": editedMealItems,
                "mealPeriod": selectedMealPeriod,
                "mealTime": mealTime,
                "plateViewModel": plateViewModel as Any
            ]
        )
        dismiss()
    }
}

// MARK: - Supporting Types

private struct MultiFoodRawNutrientValue {
    let value: Double
    let unit: String?
}

private struct MultiFoodItemListDisplay: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let servingText: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

private struct MultiFoodItemRow: View {
    let item: MultiFoodItemListDisplay
    let cardColor: Color
    let chipColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name.isEmpty ? "Meal Item" : item.name)
                        .font(.system(size: 15))
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                    if let brand = item.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 12)

                if let serving = item.servingText, !serving.isEmpty {
                    Text(serving)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(chipColor)
                        )
                        .fixedSize()
                }
            }

            HStack(spacing: 10) {
                Label("\(Int(item.calories.rounded()))cal", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(macroLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardColor)
        )
    }

    private var macroLine: String {
        let protein = Int(item.protein.rounded())
        let carbs = Int(item.carbs.rounded())
        let fat = Int(item.fat.rounded())
        return "P \(protein)g C \(carbs)g F \(fat)g"
    }
}

// MARK: - Editable Item Row with Serving Controls

private struct MultiFoodEditableItemRow: View {
    let food: Food
    @Binding var editableItem: EditableFoodItem
    let cardColor: Color
    let chipColor: Color
    var onTap: () -> Void = {}

    /// Scaled calories based on serving adjustments
    private var scaledCalories: Double {
        (food.calories ?? 0) * editableItem.scalingFactor
    }

    /// Scaled protein based on serving adjustments
    private var scaledProtein: Double {
        (food.protein ?? 0) * editableItem.scalingFactor
    }

    /// Scaled carbs based on serving adjustments
    private var scaledCarbs: Double {
        (food.carbs ?? 0) * editableItem.scalingFactor
    }

    /// Scaled fat based on serving adjustments
    private var scaledFat: Double {
        (food.fat ?? 0) * editableItem.scalingFactor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name + serving controls on same row
            HStack(alignment: .top, spacing: 12) {
                // Food name and brand
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.displayName.isEmpty ? "Meal Item" : food.displayName)
                        .font(.system(size: 15))
                        .fontWeight(.regular)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    if let brand = food.brandText, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 8)

                // Serving controls on the right
                servingControls
            }

            // Macro summary row
            HStack(spacing: 10) {
                Label("\(Int(scaledCalories.rounded()))cal", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(macroLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardColor)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private var servingControls: some View {
        HStack(spacing: 6) {
            // Amount input field
            TextField("1", text: servingAmountBinding)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.center)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .frame(width: 50)
                .background(
                    Capsule().fill(chipColor)
                )
                .font(.system(size: 15))

            // Unit picker or static label
            if editableItem.hasMeasureOptions {
                measureMenu
            } else {
                // Show static unit label
                Text(unitLabel(for: editableItem.selectedMeasure))
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule().fill(chipColor)
                    )
            }
        }
        .fixedSize()
    }

    private var measureMenu: some View {
        Menu {
            ForEach(editableItem.measures) { measure in
                Button(action: { selectMeasure(measure) }) {
                    HStack {
                        Text(unitLabel(for: measure))
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        Spacer()
                        if measure.id == editableItem.selectedMeasureId {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(unitLabel(for: editableItem.selectedMeasure))
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule().fill(chipColor)
            )
        }
        .menuStyle(.borderlessButton)
    }

    private var servingAmountBinding: Binding<String> {
        Binding(
            get: { editableItem.servingAmountInput },
            set: { newValue in
                editableItem.servingAmountInput = newValue
                if let parsed = EditableFoodItem.parseServing(newValue),
                   abs(parsed - editableItem.servingAmount) > 0.0001 {
                    editableItem.servingAmount = parsed
                }
            }
        )
    }

    private func selectMeasure(_ measure: MealItemMeasure) {
        guard editableItem.selectedMeasureId != measure.id else { return }
        editableItem.selectedMeasureId = measure.id
    }

    private func unitLabel(for measure: MealItemMeasure?) -> String {
        guard let measure else { return "serving" }
        let description = sanitizedDescription(measure.description)
        if !description.isEmpty {
            return description
        }
        return canonicalUnit(from: measure.unit)
    }

    private func sanitizedDescription(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        // Remove leading numeric portion like "1 " or "1.0 "
        let pattern = #"^\d+(?:\.\d+)?\s+"#
        if let range = trimmed.range(of: pattern, options: .regularExpression) {
            trimmed = String(trimmed[range.upperBound...])
        }
        return trimmed
    }

    private func canonicalUnit(from rawUnit: String) -> String {
        let lower = rawUnit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let mapping: [(String, [String])] = [
            ("cup", ["cup", "cups"]),
            ("serving", ["serving", "servings", "portion"]),
            ("piece", ["piece", "pieces", "pcs"]),
            ("oz", ["oz", "ounce", "ounces"]),
            ("g", ["g", "gram", "grams"]),
            ("tbsp", ["tbsp", "tablespoon", "tablespoons"]),
            ("tsp", ["tsp", "teaspoon", "teaspoons"]),
        ]
        for (canonical, tokens) in mapping {
            if tokens.contains(where: { lower.contains($0) }) {
                return canonical
            }
        }
        return rawUnit.isEmpty ? "serving" : rawUnit
    }

    private var macroLine: String {
        let p = Int(scaledProtein.rounded())
        let c = Int(scaledCarbs.rounded())
        let f = Int(scaledFat.rounded())
        return "P \(p)g C \(c)g F \(f)g"
    }
}

private struct MultiFoodMacroRingView: View {
    let calories: Double
    let arcs: [MultiFoodMacroArc]

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
                Text(String(format: "%.0f", calories))
                    .font(.system(size: 20, weight: .medium))
                Text("cals")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct MultiFoodMacroArc {
    let start: Double
    let end: Double
    let color: Color
}

private struct MultiFoodGoalShareBubble: View {
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

// MARK: - Nutrient Row Descriptor

private enum MultiFoodMacroType {
    case protein, carbs, fat
}

private enum MultiFoodNutrientAggregation {
    case first, sum
}

private enum MultiFoodNutrientComputation {
    case netCarbs, calories
}

private enum MultiFoodNutrientSource {
    case macro(MultiFoodMacroType)
    case nutrient(names: [String], aggregation: MultiFoodNutrientAggregation = .first)
    case computed(MultiFoodNutrientComputation)
}

private struct MultiFoodNutrientRowDescriptor: Identifiable {
    let id = UUID()
    let label: String
    let slug: String?
    let defaultUnit: String
    let source: MultiFoodNutrientSource
    let color: Color
}

private enum MultiFoodNutrientDescriptors {
    static let proteinColor = Color("protein")
    static let fatColor = Color("fat")
    static let carbColor = Color("carbs")

    static var totalCarbRows: [MultiFoodNutrientRowDescriptor] {
        [
            MultiFoodNutrientRowDescriptor(label: "Carbs", slug: "carbs", defaultUnit: "g", source: .macro(.carbs), color: carbColor),
            MultiFoodNutrientRowDescriptor(label: "Fiber", slug: "fiber", defaultUnit: "g", source: .nutrient(names: ["Fiber, total dietary", "fiber, total dietary", "dietary fiber", "fiber"]), color: carbColor),
            MultiFoodNutrientRowDescriptor(label: "Net (Non-fiber)", slug: "net_carbs", defaultUnit: "g", source: .computed(.netCarbs), color: carbColor),
            MultiFoodNutrientRowDescriptor(label: "Sugars", slug: "sugars", defaultUnit: "g", source: .nutrient(names: ["Sugars, total including NLEA", "sugars, total including nlea", "sugars, total", "sugar", "sugars"]), color: carbColor),
            MultiFoodNutrientRowDescriptor(label: "Sugars Added", slug: "added_sugars", defaultUnit: "g", source: .nutrient(names: ["Sugars, added", "sugars, added", "added sugars", "added_sugars"]), color: carbColor)
        ]
    }

    static var fatRows: [MultiFoodNutrientRowDescriptor] {
        [
            MultiFoodNutrientRowDescriptor(label: "Fat", slug: "fat", defaultUnit: "g", source: .macro(.fat), color: fatColor),
            MultiFoodNutrientRowDescriptor(label: "Monounsaturated", slug: "monounsaturated_fat", defaultUnit: "g", source: .nutrient(names: ["Fatty acids, total monounsaturated", "fatty acids, total monounsaturated", "monounsaturated_fat", "monounsaturated fat"]), color: fatColor),
            MultiFoodNutrientRowDescriptor(label: "Polyunsaturated", slug: "polyunsaturated_fat", defaultUnit: "g", source: .nutrient(names: ["Fatty acids, total polyunsaturated", "fatty acids, total polyunsaturated", "polyunsaturated_fat", "polyunsaturated fat"]), color: fatColor),
            MultiFoodNutrientRowDescriptor(label: "Omega-3", slug: "omega_3_total", defaultUnit: "g", source: .nutrient(names: ["Fatty acids, total n-3", "fatty acids, total n-3", "omega 3", "omega-3"]), color: fatColor),
            MultiFoodNutrientRowDescriptor(label: "Omega-3 ALA", slug: "omega_3_ala", defaultUnit: "g", source: .nutrient(names: ["18:3 n-3 c,c,c (ALA)", "18:3 n-3 c,c,c (ala)", "alpha-linolenic acid", "omega-3 ala", "omega 3 ala", "omega_3_ala"]), color: fatColor),
            MultiFoodNutrientRowDescriptor(label: "Omega-3 EPA+DHA", slug: "omega_3_epa_dha", defaultUnit: "mg", source: .nutrient(names: ["20:5 n-3 (EPA)", "22:6 n-3 (DHA)", "20:5 n-3 (epa)", "22:6 n-3 (dha)", "epa", "dha", "eicosapentaenoic acid", "docosahexaenoic acid", "omega-3 epa + dha", "omega_3_dha", "omega_3_epa"], aggregation: .sum), color: fatColor),
            MultiFoodNutrientRowDescriptor(label: "Omega-6", slug: "omega_6", defaultUnit: "g", source: .nutrient(names: ["Fatty acids, total n-6", "fatty acids, total n-6", "omega 6", "omega-6"]), color: fatColor),
            MultiFoodNutrientRowDescriptor(label: "Saturated", slug: "saturated_fat", defaultUnit: "g", source: .nutrient(names: ["Fatty acids, total saturated", "fatty acids, total saturated", "saturated_fat", "saturated fat"]), color: fatColor),
            MultiFoodNutrientRowDescriptor(label: "Trans Fat", slug: "trans_fat", defaultUnit: "g", source: .nutrient(names: ["Fatty acids, total trans", "fatty acids, total trans", "trans_fat", "trans fat"]), color: fatColor)
        ]
    }

    static var proteinRows: [MultiFoodNutrientRowDescriptor] {
        [
            MultiFoodNutrientRowDescriptor(label: "Protein", slug: "protein", defaultUnit: "g", source: .macro(.protein), color: proteinColor),
            MultiFoodNutrientRowDescriptor(label: "Cysteine", slug: "cysteine", defaultUnit: "mg", source: .nutrient(names: ["Cysteine", "cysteine", "Cystine", "cystine"]), color: proteinColor),
            MultiFoodNutrientRowDescriptor(label: "Histidine", slug: "histidine", defaultUnit: "mg", source: .nutrient(names: ["Histidine", "histidine"]), color: proteinColor),
            MultiFoodNutrientRowDescriptor(label: "Isoleucine", slug: "isoleucine", defaultUnit: "mg", source: .nutrient(names: ["Isoleucine", "isoleucine"]), color: proteinColor),
            MultiFoodNutrientRowDescriptor(label: "Leucine", slug: "leucine", defaultUnit: "mg", source: .nutrient(names: ["Leucine", "leucine"]), color: proteinColor),
            MultiFoodNutrientRowDescriptor(label: "Lysine", slug: "lysine", defaultUnit: "mg", source: .nutrient(names: ["Lysine", "lysine"]), color: proteinColor),
            MultiFoodNutrientRowDescriptor(label: "Methionine", slug: "methionine", defaultUnit: "mg", source: .nutrient(names: ["Methionine", "methionine"]), color: proteinColor),
            MultiFoodNutrientRowDescriptor(label: "Phenylalanine", slug: "phenylalanine", defaultUnit: "mg", source: .nutrient(names: ["Phenylalanine", "phenylalanine"]), color: proteinColor),
            MultiFoodNutrientRowDescriptor(label: "Threonine", slug: "threonine", defaultUnit: "mg", source: .nutrient(names: ["Threonine", "threonine"]), color: proteinColor),
            MultiFoodNutrientRowDescriptor(label: "Tryptophan", slug: "tryptophan", defaultUnit: "mg", source: .nutrient(names: ["Tryptophan", "tryptophan"]), color: proteinColor),
            MultiFoodNutrientRowDescriptor(label: "Tyrosine", slug: "tyrosine", defaultUnit: "mg", source: .nutrient(names: ["Tyrosine", "tyrosine"]), color: proteinColor),
            MultiFoodNutrientRowDescriptor(label: "Valine", slug: "valine", defaultUnit: "mg", source: .nutrient(names: ["Valine", "valine"]), color: proteinColor)
        ]
    }

    static var vitaminRows: [MultiFoodNutrientRowDescriptor] {
        [
            MultiFoodNutrientRowDescriptor(label: "B1, Thiamine", slug: "vitamin_b1_thiamin", defaultUnit: "mg", source: .nutrient(names: ["Thiamin", "thiamin", "vitamin b-1", "vitamin_b1_thiamin"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "B2, Riboflavin", slug: "vitamin_b2_riboflavin", defaultUnit: "mg", source: .nutrient(names: ["Riboflavin", "riboflavin", "vitamin b-2", "vitamin_b2_riboflavin"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "B3, Niacin", slug: "vitamin_b3_niacin", defaultUnit: "mg", source: .nutrient(names: ["Niacin", "niacin", "vitamin b-3", "vitamin_b3_niacin"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "B6, Pyridoxine", slug: "vitamin_b6_pyridoxine", defaultUnit: "mg", source: .nutrient(names: ["Vitamin B-6", "vitamin b-6", "pyridoxine", "vitamin b6", "vitamin_b6_pyridoxine"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "B5, Pantothenic Acid", slug: "vitamin_b5_pantothenic_acid", defaultUnit: "mg", source: .nutrient(names: ["Pantothenic acid", "pantothenic acid", "vitamin_b5_pantothenic_acid"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "B12, Cobalamin", slug: "vitamin_b12_cobalamin", defaultUnit: "mcg", source: .nutrient(names: ["Vitamin B-12", "vitamin b-12", "cobalamin", "vitamin_b12_cobalamin"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "Biotin", slug: "biotin", defaultUnit: "mcg", source: .nutrient(names: ["Biotin", "biotin"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "Folate", slug: "folate", defaultUnit: "mcg", source: .nutrient(names: ["Folate, total", "folate, total", "folic acid", "folate"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "Vitamin A", slug: "vitamin_a", defaultUnit: "mcg", source: .nutrient(names: ["Vitamin A, RAE", "vitamin a, rae", "vitamin a", "vitamin_a"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "Vitamin C", slug: "vitamin_c", defaultUnit: "mg", source: .nutrient(names: ["Vitamin C, total ascorbic acid", "vitamin c, total ascorbic acid", "vitamin c", "vitamin_c"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "Vitamin D", slug: "vitamin_d", defaultUnit: "IU", source: .nutrient(names: ["Vitamin D", "vitamin d (d2 + d3)", "vitamin d", "vitamin_d"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "Vitamin E", slug: "vitamin_e", defaultUnit: "mg", source: .nutrient(names: ["Vitamin E (alpha-tocopherol)", "vitamin e (alpha-tocopherol)", "vitamin e", "vitamin_e"]), color: .orange),
            MultiFoodNutrientRowDescriptor(label: "Vitamin K", slug: "vitamin_k", defaultUnit: "mcg", source: .nutrient(names: ["Vitamin K (phylloquinone)", "vitamin k (phylloquinone)", "vitamin k", "vitamin_k"]), color: .orange)
        ]
    }

    static var mineralRows: [MultiFoodNutrientRowDescriptor] {
        [
            MultiFoodNutrientRowDescriptor(label: "Calcium", slug: "calcium", defaultUnit: "mg", source: .nutrient(names: ["Calcium, Ca", "calcium, ca", "calcium"]), color: .blue),
            MultiFoodNutrientRowDescriptor(label: "Copper", slug: "copper", defaultUnit: "mcg", source: .nutrient(names: ["Copper, Cu", "copper, cu", "copper"]), color: .blue),
            MultiFoodNutrientRowDescriptor(label: "Iron", slug: "iron", defaultUnit: "mg", source: .nutrient(names: ["Iron, Fe", "iron, fe", "iron"]), color: .blue),
            MultiFoodNutrientRowDescriptor(label: "Magnesium", slug: "magnesium", defaultUnit: "mg", source: .nutrient(names: ["Magnesium, Mg", "magnesium, mg", "magnesium"]), color: .blue),
            MultiFoodNutrientRowDescriptor(label: "Manganese", slug: "manganese", defaultUnit: "mg", source: .nutrient(names: ["Manganese, Mn", "manganese, mn", "manganese"]), color: .blue),
            MultiFoodNutrientRowDescriptor(label: "Phosphorus", slug: "phosphorus", defaultUnit: "mg", source: .nutrient(names: ["Phosphorus, P", "phosphorus, p", "phosphorus"]), color: .blue),
            MultiFoodNutrientRowDescriptor(label: "Potassium", slug: "potassium", defaultUnit: "mg", source: .nutrient(names: ["Potassium, K", "potassium, k", "potassium"]), color: .blue),
            MultiFoodNutrientRowDescriptor(label: "Selenium", slug: "selenium", defaultUnit: "mcg", source: .nutrient(names: ["Selenium, Se", "selenium, se", "selenium"]), color: .blue),
            MultiFoodNutrientRowDescriptor(label: "Sodium", slug: "sodium", defaultUnit: "mg", source: .nutrient(names: ["Sodium, Na", "sodium, na", "sodium"]), color: .blue),
            MultiFoodNutrientRowDescriptor(label: "Zinc", slug: "zinc", defaultUnit: "mg", source: .nutrient(names: ["Zinc, Zn", "zinc, zn", "zinc"]), color: .blue)
        ]
    }

    static var otherRows: [MultiFoodNutrientRowDescriptor] {
        [
            MultiFoodNutrientRowDescriptor(label: "Calories", slug: "calories", defaultUnit: "kcal", source: .computed(.calories), color: .purple),
            MultiFoodNutrientRowDescriptor(label: "Alcohol", slug: "alcohol", defaultUnit: "g", source: .nutrient(names: ["Alcohol, ethyl", "alcohol, ethyl", "alcohol"]), color: .purple),
            MultiFoodNutrientRowDescriptor(label: "Caffeine", slug: "caffeine", defaultUnit: "mg", source: .nutrient(names: ["Caffeine", "caffeine"]), color: .purple),
            MultiFoodNutrientRowDescriptor(label: "Cholesterol", slug: "cholesterol", defaultUnit: "mg", source: .nutrient(names: ["Cholesterol", "cholesterol"]), color: .purple),
            MultiFoodNutrientRowDescriptor(label: "Choline", slug: "choline", defaultUnit: "mg", source: .nutrient(names: ["Choline, total", "choline, total", "choline"]), color: .purple),
            MultiFoodNutrientRowDescriptor(label: "Water", slug: "water", defaultUnit: "ml", source: .nutrient(names: ["Water", "water"]), color: .purple)
        ]
    }
}

// MARK: - Editable Food Item State

/// Tracks editable serving state for a food item in the multi-food view
private struct EditableFoodItem {
    var servingAmount: Double
    var servingAmountInput: String
    var selectedMeasureId: UUID?
    let measures: [MealItemMeasure]
    let baselineServing: Double
    let baselineMeasureId: UUID?

    /// The currently selected measure
    var selectedMeasure: MealItemMeasure? {
        if let id = selectedMeasureId,
           let match = measures.first(where: { $0.id == id }) {
            return match
        }
        if let baselineId = baselineMeasureId,
           let match = measures.first(where: { $0.id == baselineId }) {
            return match
        }
        return measures.first
    }

    /// Whether there are multiple measure options to choose from
    var hasMeasureOptions: Bool {
        measures.count > 1
    }

    /// Scaling factor based on serving amount and measure change
    var scalingFactor: Double {
        guard baselineServing > 0 else { return servingAmount }
        if let baselineWeight = measures.first(where: { $0.id == baselineMeasureId })?.gramWeight,
           baselineWeight > 0,
           let selectedWeight = selectedMeasure?.gramWeight,
           selectedWeight > 0 {
            return (servingAmount * selectedWeight) / (baselineServing * baselineWeight)
        }
        return servingAmount / baselineServing
    }

    /// Initialize from a Food object
    init(from food: Food, index: Int) {
        // Convert FoodMeasures to MealItemMeasures for consistency
        let convertedMeasures: [MealItemMeasure] = food.foodMeasures.map { fm in
            MealItemMeasure(
                unit: fm.measureUnitName,
                description: fm.disseminationText,
                gramWeight: fm.gramWeight
            )
        }

        // Use existing numberOfServings or default to 1
        let initialServing = food.numberOfServings ?? 1.0
        self.servingAmount = initialServing
        self.servingAmountInput = EditableFoodItem.formatServing(initialServing)
        self.measures = convertedMeasures
        self.baselineServing = initialServing
        self.baselineMeasureId = convertedMeasures.first?.id
        self.selectedMeasureId = convertedMeasures.first?.id
    }

    /// Initialize from a MealItem object
    init(from mealItem: MealItem) {
        self.servingAmount = mealItem.serving
        self.servingAmountInput = EditableFoodItem.formatServing(mealItem.serving)
        self.measures = mealItem.measures
        self.baselineServing = mealItem.baselineServing
        self.baselineMeasureId = mealItem.measures.first?.id
        self.selectedMeasureId = mealItem.selectedMeasureId ?? mealItem.measures.first?.id
    }

    /// Format serving amount for display
    static func formatServing(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.2f", value)
                .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
        }
    }

    /// Parse serving input string to Double
    static func parseServing(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Handle fractions like "1/2"
        if let slashIndex = trimmed.firstIndex(of: "/") {
            let numeratorStr = String(trimmed[..<slashIndex])
            let denominatorStr = String(trimmed[trimmed.index(after: slashIndex)...])
            if let num = Double(numeratorStr.trimmingCharacters(in: .whitespaces)),
               let denom = Double(denominatorStr.trimmingCharacters(in: .whitespaces)),
               denom != 0 {
                return num / denom
            }
        }

        return Double(trimmed)
    }
}
