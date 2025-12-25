//
//  RecipeDetails.swift
//  pods
//
//  Created by Dimi Nunez on 12/23/25.
//

import SwiftUI

struct RecipeDetails: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dayLogsVM: DayLogsViewModel
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var viewModel: OnboardingViewModel
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared
    @ObservedObject private var recipesRepo = RecipesRepository.shared

    @State private var nutrientTargets: [String: NutrientTargetDetails] = NutritionGoalsStore.shared.currentTargets
    @State private var displayRecipe: Recipe?

    // Toolbar action states
    @State private var isSaved = false
    @State private var showEditSheet = false
    @State private var showDuplicateSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDuplicating = false

    // Explode to PlateView
    @StateObject private var plateViewModel = PlateViewModel()
    @State private var showPlateView = false

    // Loading full nutrients for ingredients
    @State private var isLoadingNutrients = false
    @State private var enrichedRecipeItems: [RecipeFoodItem] = []

    /// The recipe to display - uses updated recipe if available
    private var activeRecipe: Recipe {
        displayRecipe ?? recipe
    }

    /// Recipe items with full nutrients if available
    private var activeRecipeItems: [RecipeFoodItem] {
        enrichedRecipeItems.isEmpty ? activeRecipe.recipeItems : enrichedRecipeItems
    }

    // MARK: - Colors
    private let proteinColor = Color("protein")
    private let fatColor = Color("fat")
    private let carbColor = Color("carbs")

    private var backgroundColor: Color {
        Color(UIColor.systemGroupedBackground)
    }

    private var cardColor: Color {
        Color("sheetcard")
    }

    private var chipColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }

    // MARK: - Computed Nutrition Values
    private var totalMacros: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        (
            activeRecipe.totalCalories ?? activeRecipe.calories,
            activeRecipe.totalProtein ?? activeRecipe.protein,
            activeRecipe.totalCarbs ?? activeRecipe.carbs,
            activeRecipe.totalFat ?? activeRecipe.fat
        )
    }

    // MARK: - Macro Arcs
    private var macroArcs: [RecipeDetailMacroArc] {
        let proteinCalories = totalMacros.protein * 4
        let carbCalories = totalMacros.carbs * 4
        let fatCalories = totalMacros.fat * 9
        let total = max(proteinCalories + carbCalories + fatCalories, 1)
        let segments = [
            (color: proteinColor, fraction: proteinCalories / total),
            (color: fatColor, fraction: fatCalories / total),
            (color: carbColor, fraction: carbCalories / total)
        ]
        var running: Double = 0
        return segments.map { segment in
            let arc = RecipeDetailMacroArc(start: running, end: running + segment.fraction, color: segment.color)
            running += segment.fraction
            return arc
        }
    }

    // MARK: - Goal Percentages
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
        if case .loading = goalsStore.state { return true }
        return false
    }

    // MARK: - Aggregated Nutrients
    private var aggregatedNutrients: [String: RecipeDetailNutrientValue] {
        var result: [String: RecipeDetailNutrientValue] = [:]
        for item in activeRecipeItems {
            guard let nutrients = item.foodNutrients else { continue }
            for nutrient in nutrients {
                let key = normalizedNutrientKey(nutrient.nutrientName)
                let value = nutrient.value ?? 0
                if let existing = result[key] {
                    result[key] = RecipeDetailNutrientValue(value: existing.value + value, unit: existing.unit)
                } else {
                    result[key] = RecipeDetailNutrientValue(value: value, unit: nutrient.unitName)
                }
            }
        }
        return result
    }

    private var fiberValue: Double {
        let keys = ["fiber, total dietary", "dietary fiber", "fiber"]
        for key in keys {
            if let val = aggregatedNutrients[normalizedNutrientKey(key)]?.value, val > 0 {
                return val
            }
        }
        return 0
    }

    // MARK: - Logging State
    @State private var isLogging = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    recipeInfoCard
                    macroSummaryCard
                    dailyGoalShareCard

                    if !activeRecipe.recipeItems.isEmpty {
                        ingredientsSection
                    }

                    if isLoadingNutrients {
                        nutrientsLoadingView
                    } else if shouldShowGoalsLoader {
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

                    Spacer(minLength: 20)
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }

            recipeFooterBar
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Recipe Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        toggleSave()
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    }

                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            duplicateRecipe()
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }

                        Button {
                            explodeToPlate()
                        } label: {
                            Label("Explode", systemImage: "arrow.up.right.and.arrow.down.left.rectangle")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .confirmationDialog("Delete Recipe?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteRecipe()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showPlateView) {
            NavigationStack {
                PlateView(
                    viewModel: plateViewModel,
                    selectedMealPeriod: suggestedMealPeriod(for: Date()),
                    mealTime: Date(),
                    onFinished: {
                        showPlateView = false
                        plateViewModel.clear()
                    }
                )
                .environmentObject(foodManager)
                .environmentObject(dayLogsVM)
                .environmentObject(viewModel)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditRecipeSheet(recipe: activeRecipe) { updatedRecipe in
                displayRecipe = updatedRecipe
                // Update the repository so RecipeView reflects the change
                RecipesRepository.shared.updateOptimistically(updatedRecipe)
            }
            .environmentObject(foodManager)
            .environmentObject(viewModel)
            .environmentObject(dayLogsVM)
        }
        .sheet(isPresented: $showDuplicateSheet) {
            if let duplicatedRecipe = displayRecipe {
                EditRecipeSheet(recipe: duplicatedRecipe) { updatedRecipe in
                    // The duplicated recipe was saved
                    RecipesRepository.shared.updateOptimistically(updatedRecipe)
                }
                .environmentObject(foodManager)
                .environmentObject(viewModel)
                .environmentObject(dayLogsVM)
            }
        }
        .overlay {
            if isDuplicating {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Duplicating recipe...")
                            .padding()
                            .background(Color("iosnp"))
                            .cornerRadius(12)
                    }
            }
        }
        .task {
            reloadStoredNutrientTargets()
            checkIfSaved()
            await loadFullNutrientsForIngredients()
        }
        .onReceive(dayLogsVM.$nutritionGoalsVersion) { _ in
            reloadStoredNutrientTargets()
        }
        .onReceive(goalsStore.$state) { _ in
            reloadStoredNutrientTargets()
        }
    }

    // MARK: - Nutrients Loading View
    private var nutrientsLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading nutrition data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Load Full Nutrients for Ingredients
    private func loadFullNutrientsForIngredients() async {
        // Check if any ingredient needs full nutrients (has <= 10 nutrients)
        let needsFullNutrients = activeRecipe.recipeItems.contains { item in
            (item.foodNutrients?.count ?? 0) <= 10
        }
        guard needsFullNutrients else { return }

        // Need user email for API call
        guard let email = foodManager.userEmail else { return }

        isLoadingNutrients = true
        defer { isLoadingNutrients = false }

        var enriched: [RecipeFoodItem] = []

        for item in activeRecipe.recipeItems {
            // Skip if already has full nutrients
            if (item.foodNutrients?.count ?? 0) > 10 {
                enriched.append(item)
                continue
            }

            do {
                // Try to fetch full nutrients using the food name
                let fullResult = try await FoodService.shared.fullFoodLookup(
                    nixItemId: nil,
                    foodName: item.name,
                    userEmail: email
                )
                let fullFood = fullResult.toFood()

                // Create enriched recipe item with full nutrients
                let enrichedItem = RecipeFoodItem(
                    foodId: item.foodId,
                    externalId: item.externalId,
                    name: item.name,
                    servings: item.servings,
                    servingText: item.servingText,
                    notes: item.notes,
                    calories: item.calories,
                    protein: item.protein,
                    carbs: item.carbs,
                    fat: item.fat,
                    foodNutrients: fullFood.foodNutrients
                )
                enriched.append(enrichedItem)
            } catch {
                print("[RecipeDetails] Failed to load full nutrients for \(item.name): \(error)")
                // Keep original item if fetch fails
                enriched.append(item)
            }
        }

        enrichedRecipeItems = enriched
    }

    private func reloadStoredNutrientTargets() {
        nutrientTargets = NutritionGoalsStore.shared.currentTargets
    }

    // MARK: - Toolbar Actions
    private func toggleSave() {
        if isSaved {
            // Unsave the recipe
            foodManager.unsaveRecipe(recipeId: activeRecipe.id) { result in
                if case .success = result {
                    isSaved = false
                    SavedRecipesRepository.shared.removeOptimistically(recipeId: activeRecipe.id)
                }
            }
        } else {
            // Save the recipe
            foodManager.saveRecipe(recipeId: activeRecipe.id) { result in
                switch result {
                case .success(let response):
                    isSaved = true
                    if let savedRecipe = response.savedRecipe {
                        SavedRecipesRepository.shared.insertOptimistically(savedRecipe)
                    }
                case .failure:
                    break
                }
            }
        }
    }

    private func checkIfSaved() {
        foodManager.isRecipeSaved(recipeId: activeRecipe.id) { saved in
            isSaved = saved
        }
    }

    private func deleteRecipe() {
        // Remove optimistically from repository
        RecipesRepository.shared.removeOptimistic(id: activeRecipe.id)

        foodManager.deleteRecipe(recipeId: activeRecipe.id) { result in
            switch result {
            case .success:
                dismiss()
            case .failure:
                Task {
                    await RecipesRepository.shared.refresh(force: true)
                }
            }
        }
    }

    private func duplicateRecipe() {
        isDuplicating = true

        foodManager.duplicateRecipe(recipe: activeRecipe) { result in
            isDuplicating = false

            switch result {
            case .success(let newRecipe):
                // Show the new recipe in edit sheet
                displayRecipe = newRecipe
                showDuplicateSheet = true
            case .failure(let error):
                print("Failed to duplicate recipe: \(error.localizedDescription)")
            }
        }
    }

    /// Explode recipe ingredients into PlateView for editing before logging
    private func explodeToPlate() {
        let items = activeRecipeItems
        guard !items.isEmpty else {
            print("No ingredients to explode")
            return
        }

        // Clear any existing entries and add each ingredient as a PlateEntry
        plateViewModel.clear()
        let mealPeriod = suggestedMealPeriod(for: Date())

        print("[RecipeDetails] Exploding \(items.count) items to PlateView (VM id: \(plateViewModel.instanceId))")
        for item in items {
            let entry = buildPlateEntry(from: item, mealPeriod: mealPeriod)
            plateViewModel.add(entry)
            print("[RecipeDetails] Added entry: \(item.name)")
        }
        print("[RecipeDetails] PlateViewModel \(plateViewModel.instanceId) now has \(plateViewModel.entries.count) entries")

        // Open PlateView immediately
        showPlateView = true
    }

    /// Build a PlateEntry from a RecipeFoodItem
    private func buildPlateEntry(from item: RecipeFoodItem, mealPeriod: MealPeriod) -> PlateEntry {
        let servings = Double(item.servings) ?? 1.0

        // Build base macro totals (per serving)
        let baseMacros = MacroTotals(
            calories: item.calories / servings,
            protein: item.protein / servings,
            carbs: item.carbs / servings,
            fat: item.fat / servings
        )

        // Build base nutrient values
        var baseNutrients: [String: RawNutrientValue] = [:]
        if let nutrients = item.foodNutrients {
            for nutrient in nutrients {
                let key = nutrient.nutrientName.lowercased()
                // Scale nutrients back to per-serving values
                let perServingValue = (nutrient.value ?? 0) / servings
                baseNutrients[key] = RawNutrientValue(value: perServingValue, unit: nutrient.unitName)
            }
        }

        // Create a Food object from the recipe item
        let food = Food(
            fdcId: item.foodId,
            description: item.name,
            brandOwner: nil,
            brandName: nil,
            servingSize: nil,
            numberOfServings: servings,
            servingSizeUnit: nil,
            householdServingFullText: item.servingText,
            foodNutrients: item.foodNutrients ?? [],
            foodMeasures: []
        )

        return PlateEntry(
            food: food,
            servings: servings,
            selectedMeasureId: nil,
            availableMeasures: [],
            baselineGramWeight: 100,
            baseNutrientValues: baseNutrients,
            baseMacroTotals: baseMacros,
            servingDescription: item.servingText ?? "1 serving",
            mealItems: [],
            mealPeriod: mealPeriod,
            mealTime: Date(),
            recipeItems: []
        )
    }

    /// Determine the suggested meal period based on time of day
    private func suggestedMealPeriod(for date: Date) -> MealPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .breakfast
        case 11..<14: return .lunch
        case 14..<17: return .snack
        default: return .dinner
        }
    }

    // MARK: - Footer Bar
    private var recipeFooterBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            HStack(spacing: 12) {
                Button(action: {
                    HapticFeedback.generateLigth()
                    logRecipeDirectly()
                }) {
                    Text(isLogging ? "Logging..." : "Log Recipe")
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
                .disabled(isLogging)
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
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func logRecipeDirectly() {
        isLogging = true
        let mealType = suggestedMealPeriod(for: Date()).title

        foodManager.logRecipe(
            recipe: activeRecipe,
            mealTime: mealType,
            date: Date(),
            notes: nil,
            calories: activeRecipe.calories
        ) { result in
            isLogging = false
            switch result {
            case .success:
                // Navigate to timeline
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToTimeline"), object: nil)
                dismiss()
            case .failure(let error):
                print("Failed to log recipe: \(error.localizedDescription)")
            }
        }
    }

    private func addToPlate() {
        let mealPeriod = suggestedMealPeriod(for: Date())

        // Build base macro totals
        let baseMacros = MacroTotals(
            calories: activeRecipe.calories,
            protein: activeRecipe.protein,
            carbs: activeRecipe.carbs,
            fat: activeRecipe.fat
        )

        // Aggregate nutrients from all recipe items
        var baseNutrients: [String: RawNutrientValue] = [:]
        for item in activeRecipe.recipeItems {
            if let nutrients = item.foodNutrients {
                for nutrient in nutrients {
                    let key = nutrient.nutrientName.lowercased()
                    let value = nutrient.value ?? 0
                    if let existing = baseNutrients[key] {
                        baseNutrients[key] = RawNutrientValue(value: existing.value + value, unit: existing.unit)
                    } else {
                        baseNutrients[key] = RawNutrientValue(value: value, unit: nutrient.unitName)
                    }
                }
            }
        }

        // Create a Food object representing the whole recipe
        let food = Food(
            fdcId: activeRecipe.id,
            description: activeRecipe.title,
            brandOwner: nil,
            brandName: nil,
            servingSize: nil,
            numberOfServings: 1.0,
            servingSizeUnit: nil,
            householdServingFullText: "1 serving",
            foodNutrients: [],
            foodMeasures: []
        )

        let entry = PlateEntry(
            food: food,
            servings: 1.0,
            selectedMeasureId: nil,
            availableMeasures: [],
            baselineGramWeight: 100,
            baseNutrientValues: baseNutrients,
            baseMacroTotals: baseMacros,
            servingDescription: "1 serving",
            mealItems: [],
            mealPeriod: mealPeriod,
            mealTime: Date(),
            recipeItems: activeRecipe.recipeItems
        )

        plateViewModel.add(entry)
        showPlateView = true
    }

    // MARK: - Recipe Info Card
    private var recipeInfoCard: some View {
        VStack(spacing: 0) {
            // Row 1: Name
            HStack {
                Text("Name")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                Spacer()
                Text(activeRecipe.title)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .padding(.vertical, 12)

            Divider()

            // Row 2: Servings
            HStack {
                Text("Servings")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(activeRecipe.servings)")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(chipColor))
            }
            .padding(.vertical, 12)

            if let prepTime = activeRecipe.prepTime, prepTime > 0 {
                Divider()
                HStack {
                    Text("Prep Time")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(prepTime) min")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
            }

            if let cookTime = activeRecipe.cookTime, cookTime > 0 {
                Divider()
                HStack {
                    Text("Cook Time")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(cookTime) min")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardColor)
        )
        .padding(.horizontal)
    }

    // MARK: - Macro Summary Card
    private var macroSummaryCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                macroStatRow(title: "Protein", value: totalMacros.protein, unit: "g", color: proteinColor)
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Fat", value: totalMacros.fat, unit: "g", color: fatColor)
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Carbs", value: totalMacros.carbs, unit: "g", color: carbColor)
            }

            Spacer()

            RecipeDetailMacroRingView(calories: totalMacros.calories, arcs: macroArcs)
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
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(value.recipeDetailFormatted)\(unit)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - Daily Goal Share Card
    private var dailyGoalShareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Goal Share")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                RecipeDetailGoalShareBubble(title: "Protein",
                                      percent: proteinGoalPercent,
                                      grams: totalMacros.protein,
                                      goal: dayLogsVM.proteinGoal,
                                      color: proteinColor)
                RecipeDetailGoalShareBubble(title: "Fat",
                                      percent: fatGoalPercent,
                                      grams: totalMacros.fat,
                                      goal: dayLogsVM.fatGoal,
                                      color: fatColor)
                RecipeDetailGoalShareBubble(title: "Carbs",
                                      percent: carbGoalPercent,
                                      grams: totalMacros.carbs,
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

    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                ForEach(Array(activeRecipe.recipeItems.enumerated()), id: \.offset) { index, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                Text(item.servingText ?? "1 serving")
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                if item.servings != "1" {
                                    Text("x\(item.servings)")
                                }
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        }
                        Spacer()

                        Text("\(Int(item.calories)) cal")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)

                    if index < activeRecipe.recipeItems.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(cardColor)
            )
        }
        .padding(.horizontal)
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

    private func nutrientSection(title: String, rows: [NutrientRowDescriptor]) -> some View {
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
        let value = nutrientValueFor(descriptor)
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

    // MARK: - Nutrient Value Helpers
    private func nutrientValueFor(_ descriptor: NutrientRowDescriptor) -> Double {
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
            switch aggregation {
            case .first:
                return matches.first?.value ?? 0
            case .sum:
                return matches.reduce(0) { $0 + $1.value }
            }
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
        if let slug = descriptor.slug,
           let details = nutrientTargets[slug] {
            if let target = details.target, target > 0 {
                return target
            } else if let max = details.max, max > 0 {
                return max
            } else if let idealMax = details.idealMax, idealMax > 0 {
                return idealMax
            }
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
                    return target
                }
                return nil
            }
        default:
            return nil
        }
    }

    private func nutrientUnit(for descriptor: NutrientRowDescriptor) -> String {
        switch descriptor.source {
        case .nutrient(let names, _):
            for name in names {
                if let raw = aggregatedNutrients[normalizedNutrientKey(name)],
                   let unit = raw.unit, !unit.isEmpty {
                    return unit
                }
            }
        default:
            break
        }
        return descriptor.defaultUnit
    }

    private func nutrientPercentage(value: Double, goal: Double?) -> String {
        guard let goal, goal > 0 else { return "--" }
        let percent = (value / goal) * 100
        return "\(Int(percent.rounded()))%"
    }

    private func nutrientRatioText(value: Double, goal: Double?, unit: String) -> String {
        let valueText = value.recipeDetailGoalShareFormatted
        let goalText = goal.map { $0.recipeDetailGoalShareFormatted } ?? "--"
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedUnit.isEmpty {
            return "\(valueText)/\(goalText)"
        } else {
            return "\(valueText)/\(goalText) \(trimmedUnit)"
        }
    }

    private func nutrientProgressValue(value: Double, goal: Double?) -> Double {
        guard let goal, goal > 0 else { return 0 }
        return min(max(value / goal, 0), 1)
    }

    // MARK: - Loading/Missing Views
    private var goalsLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView("Syncing your targets...")
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
}

// MARK: - Supporting Types

private struct RecipeDetailNutrientValue {
    let value: Double
    let unit: String?
}

private struct RecipeDetailMacroArc {
    let start: Double
    let end: Double
    let color: Color
}

private struct RecipeDetailMacroRingView: View {
    let calories: Double
    let arcs: [RecipeDetailMacroArc]

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

private struct RecipeDetailGoalShareBubble: View {
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
            Text("\(grams.recipeDetailGoalShareFormatted) / \(goal.recipeDetailGoalShareFormatted)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Double Extensions for RecipeDetails

private extension Double {
    var recipeDetailFormatted: String {
        if self.isNaN { return "0" }
        if abs(self - rounded()) < 0.01 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }

    var recipeDetailGoalShareFormatted: String {
        if self.isNaN || self.isInfinite { return "0" }
        let roundedValue = (self * 10).rounded() / 10
        if roundedValue.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(roundedValue))
        }
        return String(format: "%.1f", roundedValue)
    }
}
