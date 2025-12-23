//
//  IngredientPlateSummaryView.swift
//  pods
//
//  Created by Dimi Nunez on 12/20/25.
//

import SwiftUI

struct IngredientPlateSummaryView: View {
    let foods: [Food]
    let mealItems: [MealItem]
    var onAddToRecipe: ([Food], [MealItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel

    @State private var selectedFood: Food?
    @State private var isAdding = false
    @State private var nutrientTargets: [String: NutrientTargetDetails] = NutritionGoalsStore.shared.currentTargets
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared

    /// Editable serving state for each food item (keyed by food index)
    @State private var editableItems: [Int: IngredientEditableFoodItem] = [:]

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

    // MARK: - Display Foods Logic
    /// All foods derived from input (before filtering deleted items)
    private var allDisplayFoods: [Food] {
        if foods.count > 1 {
            return foods
        }
        // PRIORITY: Use top-level mealItems if available (has actual serving amounts from backend)
        if !mealItems.isEmpty {
            return mealItems.map { item in
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
                    numberOfServings: item.serving, // Use actual serving amount from MealItem
                    servingSizeUnit: item.servingUnit,
                    householdServingFullText: item.originalServing?.resolvedText ?? "\(formatServing(item.serving)) \(item.servingUnit ?? "serving")",
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
                    numberOfServings: item.serving, // Use actual serving amount from MealItem
                    servingSizeUnit: item.servingUnit,
                    householdServingFullText: item.originalServing?.resolvedText ?? "\(formatServing(item.serving)) \(item.servingUnit ?? "serving")",
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

    /// Format serving amount for display (removes unnecessary decimals)
    private func formatServing(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.1f", value)
        }
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

    private var macroArcs: [IngredientMacroArc] {
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
            let arc = IngredientMacroArc(start: running, end: running + segment.fraction, color: segment.color)
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

    private var aggregatedNutrients: [String: IngredientRawNutrientValue] {
        var result: [String: IngredientRawNutrientValue] = [:]
        // Use displayFoodsWithIndices to exclude deleted items
        for item in displayFoodsWithIndices {
            let scalingFactor = editableItems[item.index]?.scalingFactor ?? 1.0
            for nutrient in item.food.foodNutrients {
                let key = normalizedNutrientKey(nutrient.nutrientName)
                let value = (nutrient.value ?? 0) * scalingFactor
                if let existing = result[key] {
                    result[key] = IngredientRawNutrientValue(value: existing.value + value, unit: existing.unit)
                } else {
                    result[key] = IngredientRawNutrientValue(value: value, unit: nutrient.unitName)
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
            .navigationTitle("Add Ingredients")
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
            }
            .onAppear {
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
                editableItems[index] = IngredientEditableFoodItem(from: mealItem)
            } else if let mealItem = food.mealItems?.first {
                editableItems[index] = IngredientEditableFoodItem(from: mealItem)
            } else {
                editableItems[index] = IngredientEditableFoodItem(from: food, index: index)
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
                        IngredientEditableItemRow(
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
    private func editableItemBinding(for index: Int) -> Binding<IngredientEditableFoodItem> {
        Binding(
            get: {
                editableItems[index] ?? IngredientEditableFoodItem(from: displayFoods[index], index: index)
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

            IngredientMacroRingView(calories: totalMacros.calories, arcs: macroArcs)
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

    // MARK: - Daily Goal Share Card
    private var dailyGoalShareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Goal Share")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                IngredientGoalShareBubble(title: "Protein",
                                percent: proteinGoalPercent,
                                grams: totalMacros.protein,
                                goal: dayLogsVM.proteinGoal,
                                color: Color("protein"))
                IngredientGoalShareBubble(title: "Fat",
                                percent: fatGoalPercent,
                                grams: totalMacros.fat,
                                goal: dayLogsVM.fatGoal,
                                color: Color("fat"))
                IngredientGoalShareBubble(title: "Carbs",
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

            Button(action: {
                HapticFeedback.generateLigth()
                isAdding = true
                addToRecipe()
            }) {
                Text(isAdding ? "Adding..." : "Add to Recipe")
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
            .disabled(isAdding || displayFoodsWithIndices.isEmpty)
            .opacity(isAdding ? 0.7 : 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func addToRecipe() {
        // Add only non-deleted foods to recipe and dismiss
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

        onAddToRecipe(remainingFoods, editedMealItems)
        dismiss()
    }

    // MARK: - Nutrient Sections

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

    private func convertGoal(_ goal: Double, for descriptor: NutrientRowDescriptor) -> Double {
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
}

// MARK: - Supporting Types

private struct IngredientRawNutrientValue {
    let value: Double
    let unit: String?
}

// MARK: - Editable Item Row with Serving Controls

private struct IngredientEditableItemRow: View {
    let food: Food
    @Binding var editableItem: IngredientEditableFoodItem
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
                // Food name and brand (tappable)
                Button(action: onTap) {
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
                }
                .buttonStyle(.plain)

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
                if let parsed = IngredientEditableFoodItem.parseServing(newValue),
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

private struct IngredientMacroRingView: View {
    let calories: Double
    let arcs: [IngredientMacroArc]

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

private struct IngredientMacroArc {
    let start: Double
    let end: Double
    let color: Color
}

private struct IngredientGoalShareBubble: View {
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

// MARK: - Uses shared NutrientDescriptors from NutrientDescriptors.swift

// MARK: - Editable Food Item State

/// Tracks editable serving state for a food item in the ingredient plate view
private struct IngredientEditableFoodItem {
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
        self.servingAmountInput = IngredientEditableFoodItem.formatServing(initialServing)
        self.measures = convertedMeasures
        self.baselineServing = initialServing
        self.baselineMeasureId = convertedMeasures.first?.id
        self.selectedMeasureId = convertedMeasures.first?.id
    }

    /// Initialize from a MealItem object
    init(from mealItem: MealItem) {
        self.servingAmount = mealItem.serving
        self.servingAmountInput = IngredientEditableFoodItem.formatServing(mealItem.serving)
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

#Preview {
    IngredientPlateSummaryView(
        foods: [],
        mealItems: [],
        onAddToRecipe: { _, _ in }
    )
    .environmentObject(DayLogsViewModel())
}
