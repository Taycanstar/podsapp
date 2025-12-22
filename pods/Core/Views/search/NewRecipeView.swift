//
//  NewRecipeView.swift
//  pods
//
//  Created by Dimi Nunez on 12/18/25.
//

import SwiftUI

struct NewRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel

    // Basic Info
    @State private var name = ""
    @State private var servings = 1

    // Ingredients
    @State private var ingredients: [Food] = []
    @State private var showAddIngredients = false

    // Create state
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Nutrition goals
    @State private var nutrientTargets: [String: NutrientTargetDetails] = NutritionGoalsStore.shared.currentTargets
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared

    private var chipColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }

    private var cardColor: Color { Color(UIColor.secondarySystemGroupedBackground) }

    private var backgroundColor: Color { Color(UIColor.systemGroupedBackground) }

    // MARK: - Computed Macros

    private var totalMacros: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        var cals: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0

        for food in ingredients {
            cals += food.calories ?? 0
            protein += food.protein ?? 0
            carbs += food.carbs ?? 0
            fat += food.fat ?? 0
        }

        return (cals, protein, carbs, fat)
    }

    private var macroArcs: [RecipeMacroArc] {
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
            let arc = RecipeMacroArc(start: running, end: running + segment.fraction, color: segment.color)
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

    private var aggregatedNutrients: [String: RecipeRawNutrientValue] {
        var result: [String: RecipeRawNutrientValue] = [:]
        for food in ingredients {
            for nutrient in food.foodNutrients {
                let key = normalizedNutrientKey(nutrient.nutrientName)
                let value = nutrient.value ?? 0
                if let existing = result[key] {
                    result[key] = RecipeRawNutrientValue(value: existing.value + value, unit: existing.unit)
                } else {
                    result[key] = RecipeRawNutrientValue(value: value, unit: nutrient.unitName)
                }
            }
        }
        return result
    }

    // Uses global normalizedNutrientKey() from NutrientDescriptors.swift

    private var fiberValue: Double {
        let keys = ["fiber, total dietary", "dietary fiber", "fiber"]
        for key in keys {
            if let val = aggregatedNutrients[key]?.value, val > 0 {
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
                List {
                    // Basic Info Section
                    Section {
                        HStack {
                            Text("Name")
                            Spacer()
                            TextField("Required", text: $name)
                                .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Text("Servings")
                            Spacer()
                            HStack(spacing: 12) {
                                Button {
                                    if servings > 1 {
                                        servings -= 1
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(servings > 1 ? .primary : .secondary.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                                .disabled(servings <= 1)

                                Text("\(servings)")
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(minWidth: 30)

                                Button {
                                    if servings < 99 {
                                        servings += 1
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(servings < 99 ? .primary : .secondary.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                                .disabled(servings >= 99)
                            }
                        }
                    }

                    // Ingredients Section
                    Section {
                        // Use indices for unique IDs - same food can be added multiple times
                        ForEach(ingredients.indices, id: \.self) { index in
                            HStack {
                                IngredientRow(food: ingredients[index])
                                Spacer()
                                Button {
                                    deleteIngredient(at: IndexSet(integer: index))
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 18))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        addIngredientRow
                    } header: {
                        Text("Ingredients")
                    }

                    // Nutrition breakdown sections (only show if we have ingredients)
                    if !ingredients.isEmpty {
                        // Macro Summary Section
                        Section {
                            macroSummaryContent
                        }
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))

                        // Daily Goal Share Section
                        Section {
                            dailyGoalShareContent
                        } header: {
                            Text("Daily Goal Share")
                        }
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))

                        if shouldShowGoalsLoader {
                            Section {
                                goalsLoadingContent
                            }
                        } else if nutrientTargets.isEmpty {
                            Section {
                                missingTargetsContent
                            }
                        } else {
                            totalCarbsListSection
                            fatTotalsListSection
                            proteinTotalsListSection
                            vitaminListSection
                            mineralListSection
                            otherNutrientListSection
                        }
                    }
                }
                .listStyle(.insetGrouped)

                footerBar
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showAddIngredients) {
                AddIngredients(onIngredientAdded: { food in
                    ingredients.append(food)
                })
                .environmentObject(foodManager)
                .environmentObject(viewModel)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                reloadStoredNutrientTargets()
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

    // MARK: - Add Ingredient Row

    private var addIngredientRow: some View {
        Button {
            showAddIngredients = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                Text("Add Ingredient")
                    .foregroundColor(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Macro Summary Content (for List section)

    private var macroSummaryContent: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                macroStatRow(title: "Protein", value: totalMacros.protein, unit: "g", color: Color("protein"))
                Divider()
                macroStatRow(title: "Fat", value: totalMacros.fat, unit: "g", color: Color("fat"))
                Divider()
                macroStatRow(title: "Carbs", value: totalMacros.carbs, unit: "g", color: Color("carbs"))
            }

            Spacer()

            RecipeMacroRingView(calories: totalMacros.calories, arcs: macroArcs)
                .frame(width: 100, height: 100)
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

    // MARK: - Daily Goal Share Content (for List section)

    private var dailyGoalShareContent: some View {
        HStack(spacing: 12) {
            RecipeGoalShareBubble(title: "Protein",
                            percent: proteinGoalPercent,
                            grams: totalMacros.protein,
                            goal: dayLogsVM.proteinGoal,
                            color: Color("protein"))
            RecipeGoalShareBubble(title: "Fat",
                            percent: fatGoalPercent,
                            grams: totalMacros.fat,
                            goal: dayLogsVM.fatGoal,
                            color: Color("fat"))
            RecipeGoalShareBubble(title: "Carbs",
                            percent: carbGoalPercent,
                            grams: totalMacros.carbs,
                            goal: dayLogsVM.carbsGoal,
                            color: Color("carbs"))
        }
    }

    // MARK: - Goals Loading Content

    private var goalsLoadingContent: some View {
        VStack(spacing: 12) {
            ProgressView("Syncing your targets…")
                .progressViewStyle(CircularProgressViewStyle())
            Text("Hang tight while we fetch your personalized nutrient plan.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Missing Targets Content

    private var missingTargetsContent: some View {
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
    }

    // MARK: - Nutrient List Sections

    private var totalCarbsListSection: some View {
        nutrientListSection(title: "Total Carbs", rows: NutrientDescriptors.totalCarbRows)
    }

    private var fatTotalsListSection: some View {
        nutrientListSection(title: "Total Fat", rows: NutrientDescriptors.fatRows)
    }

    private var proteinTotalsListSection: some View {
        nutrientListSection(title: "Total Protein", rows: NutrientDescriptors.proteinRows)
    }

    private var vitaminListSection: some View {
        nutrientListSection(title: "Vitamins", rows: NutrientDescriptors.vitaminRows)
    }

    private var mineralListSection: some View {
        nutrientListSection(title: "Minerals", rows: NutrientDescriptors.mineralRows)
    }

    private var otherNutrientListSection: some View {
        nutrientListSection(title: "Other", rows: NutrientDescriptors.otherRows)
    }

    @ViewBuilder
    private func nutrientListSection(title: String, rows: [NutrientRowDescriptor]) -> some View {
        let filteredRows = rows.filter { descriptor in
            switch descriptor.source {
            case .macro, .computed:
                return true
            case .nutrient(let names, _):
                return names.contains { name in
                    aggregatedNutrients[normalizedNutrientKey(name)] != nil
                }
            }
        }

        if !filteredRows.isEmpty {
            Section {
                ForEach(filteredRows) { descriptor in
                    nutrientRow(for: descriptor)
                }
            } header: {
                Text(title)
            }
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            Button(action: createRecipe) {
                Text(isCreating ? "Creating..." : "Create")
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
            .disabled(name.isEmpty || ingredients.isEmpty || isCreating)
            .opacity((name.isEmpty || ingredients.isEmpty || isCreating) ? 0.5 : 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            backgroundColor
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Actions

    private func deleteIngredient(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }

    private func createRecipe() {
        guard !name.isEmpty, !ingredients.isEmpty else { return }

        isCreating = true
        HapticFeedback.generateLigth()

        // Build RecipeFoodItem array from ingredients
        let recipeItems = ingredients.map { food -> RecipeFoodItem in
            RecipeFoodItem(
                foodId: food.fdcId,
                externalId: String(food.fdcId),
                name: food.description,
                servings: String(food.numberOfServings ?? 1),
                servingText: food.householdServingFullText,
                notes: nil,
                calories: food.calories ?? 0,
                protein: food.protein ?? 0,
                carbs: food.carbs ?? 0,
                fat: food.fat ?? 0
            )
        }

        // Build optimistic recipe with temporary negative ID
        let tempId = -Int(Date().timeIntervalSince1970)
        let optimisticRecipe = Recipe(
            id: tempId,
            title: name,
            description: nil,
            instructions: nil,
            link: nil,
            privacy: "private",
            servings: servings,
            createdAt: Date(),
            updatedAt: nil,
            recipeItems: recipeItems,
            image: nil,
            prepTime: nil,
            cookTime: nil,
            totalCalories: totalMacros.calories,
            totalProtein: totalMacros.protein,
            totalCarbs: totalMacros.carbs,
            totalFat: totalMacros.fat,
            scheduledAt: nil
        )

        // Insert optimistically into repository
        RecipesRepository.shared.insertOptimistically(optimisticRecipe)

        // Make API call
        foodManager.createRecipe(
            title: name,
            privacy: "private",
            servings: servings,
            foods: ingredients,
            totalCalories: totalMacros.calories,
            totalProtein: totalMacros.protein,
            totalCarbs: totalMacros.carbs,
            totalFat: totalMacros.fat
        ) { result in
            isCreating = false
            switch result {
            case .success:
                // Recipe created successfully, dismiss
                dismiss()
            case .failure(let error):
                // Remove optimistic recipe on failure
                RecipesRepository.shared.removeOptimistic(id: tempId)
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - Nutrient Row

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

// MARK: - Ingredient Row

struct IngredientRow: View {
    let food: Food

    private var caloriesValue: Int {
        Int((food.calories ?? 0).rounded())
    }

    private var proteinValue: Int {
        Int((food.protein ?? 0).rounded())
    }

    private var fatValue: Int {
        Int((food.fat ?? 0).rounded())
    }

    private var carbsValue: Int {
        Int((food.carbs ?? 0).rounded())
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.description)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // Calories with flame icon
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("\(caloriesValue) cal")
                    }

                    // Macros: P F C
                    macroLabel(prefix: "P", value: proteinValue)
                    macroLabel(prefix: "F", value: fatValue)
                    macroLabel(prefix: "C", value: carbsValue)
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }
}

// MARK: - Supporting Types

private struct RecipeRawNutrientValue {
    let value: Double
    let unit: String?
}

private struct RecipeMacroArc {
    let start: Double
    let end: Double
    let color: Color
}

private struct RecipeMacroRingView: View {
    let calories: Double
    let arcs: [RecipeMacroArc]

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

private struct RecipeGoalShareBubble: View {
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

#Preview {
    NewRecipeView()
        .environmentObject(FoodManager())
        .environmentObject(OnboardingViewModel())
        .environmentObject(DayLogsViewModel())
}
