//
//  LogDetails.swift
//  pods
//
//  Created by Dimi Nunez on 12/24/25.
//

import SwiftUI

/// Unified log details view that routes to appropriate content based on log type.
/// Users navigate here after tapping a food/recipe log in the Timeline section.
struct LogDetails: View {
    let log: CombinedLog

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isTabBarVisible) private var isTabBarVisible
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @EnvironmentObject var foodManager: FoodManager

    var body: some View {
        Group {
            switch log.type {
            case .food:
                FoodLogDetailsContent(log: log)
            case .recipe:
                RecipeLogDetailsContent(log: log)
            case .meal:
                MealLogDetails(log: log)
            default:
                EmptyView()
            }
        }
        .onAppear {
            isTabBarVisible.wrappedValue = false
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
        }
    }
}

// MARK: - Food Log Details Content

private struct FoodLogDetailsContent: View {
    let log: CombinedLog

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @EnvironmentObject var foodManager: FoodManager
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared

    @State private var nutrientTargets: [String: NutrientTargetDetails] = NutritionGoalsStore.shared.currentTargets
    @State private var isSaved = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    private var food: Food {
        log.food?.asFood ?? Food(fdcId: 0, description: "Unknown", brandOwner: nil, brandName: nil, servingSize: nil, numberOfServings: nil, servingSizeUnit: nil, householdServingFullText: nil, foodNutrients: [], foodMeasures: [])
    }

    private var servings: Double {
        log.food?.numberOfServings ?? 1.0
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

    // MARK: - Computed Nutrition Values (scaled by servings)
    private var calories: Double {
        (log.food?.calories ?? 0) * servings
    }

    private var protein: Double {
        (log.food?.protein ?? 0) * servings
    }

    private var carbs: Double {
        (log.food?.carbs ?? 0) * servings
    }

    private var fat: Double {
        (log.food?.fat ?? 0) * servings
    }

    // MARK: - Macro Arcs
    private var macroArcs: [LogDetailMacroArc] {
        let proteinCalories = protein * 4
        let carbCalories = carbs * 4
        let fatCalories = fat * 9
        let total = max(proteinCalories + carbCalories + fatCalories, 1)
        let segments = [
            (color: proteinColor, fraction: proteinCalories / total),
            (color: fatColor, fraction: fatCalories / total),
            (color: carbColor, fraction: carbCalories / total)
        ]
        var running: Double = 0
        return segments.map { segment in
            let arc = LogDetailMacroArc(start: running, end: running + segment.fraction, color: segment.color)
            running += segment.fraction
            return arc
        }
    }

    // MARK: - Goal Percentages
    private var proteinGoalPercent: Double {
        guard dayLogsVM.proteinGoal > 0 else { return 0 }
        return (protein / dayLogsVM.proteinGoal) * 100
    }

    private var fatGoalPercent: Double {
        guard dayLogsVM.fatGoal > 0 else { return 0 }
        return (fat / dayLogsVM.fatGoal) * 100
    }

    private var carbGoalPercent: Double {
        guard dayLogsVM.carbsGoal > 0 else { return 0 }
        return (carbs / dayLogsVM.carbsGoal) * 100
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                foodInfoCard
                macroSummaryCard
                dailyGoalShareCard
                Spacer(minLength: 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Log Details")
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
        .confirmationDialog("Delete Log?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteLog()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove this entry from your timeline.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditLogSheet(log: log) {
            }
            .environmentObject(dayLogsVM)
            .environmentObject(foodManager)
        }
        .overlay {
            if isDeleting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Deleting...")
                            .padding()
                            .background(Color("iosnp"))
                            .cornerRadius(12)
                    }
            }
        }
        .task {
            reloadStoredNutrientTargets()
            checkIfSaved()
        }
        .onReceive(goalsStore.$state) { _ in
            reloadStoredNutrientTargets()
        }
    }

    // MARK: - Food Info Card
    private var foodInfoCard: some View {
        VStack(spacing: 0) {
            // Row 1: Name
            HStack {
                Text("Name")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                Spacer()
                Text(food.displayName)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .padding(.vertical, 12)

            Divider()

            // Row 2: Serving Size
            HStack {
                Text("Serving Size")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                Spacer()
                Text(food.householdServingFullText ?? "-")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)

            Divider()

            // Row 3: Number of Servings
            HStack {
                Text("Number of Servings")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.1f", servings))
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(chipColor))
            }
            .padding(.vertical, 12)

            if let mealType = log.mealType {
                Divider()
                HStack {
                    Text("Meal")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(mealType)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
            }

            if let scheduledAt = log.scheduledAt {
                Divider()
                HStack {
                    Text("Logged")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(scheduledAt, style: .date)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    Text("at")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    Text(scheduledAt, style: .time)
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
                macroStatRow(title: "Protein", value: protein, unit: "g", color: proteinColor)
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Fat", value: fat, unit: "g", color: fatColor)
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Carbs", value: carbs, unit: "g", color: carbColor)
            }

            Spacer()

            LogDetailMacroRingView(calories: calories, arcs: macroArcs)
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
            Text("\(value.logDetailFormatted)\(unit)")
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
                LogDetailGoalShareBubble(title: "Protein",
                                         percent: proteinGoalPercent,
                                         grams: protein,
                                         goal: dayLogsVM.proteinGoal,
                                         color: proteinColor)
                LogDetailGoalShareBubble(title: "Fat",
                                         percent: fatGoalPercent,
                                         grams: fat,
                                         goal: dayLogsVM.fatGoal,
                                         color: fatColor)
                LogDetailGoalShareBubble(title: "Carbs",
                                         percent: carbGoalPercent,
                                         grams: carbs,
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

    // MARK: - Actions
    private func reloadStoredNutrientTargets() {
        nutrientTargets = NutritionGoalsStore.shared.currentTargets
    }

    private func toggleSave() {
        guard let fdcId = log.food?.fdcId else { return }

        if isSaved {
            foodManager.unsaveFoodByFoodId(foodId: fdcId) { result in
                if case .success = result {
                    isSaved = false
                }
            }
        } else {
            foodManager.saveFood(foodId: fdcId) { result in
                if case .success = result {
                    isSaved = true
                }
            }
        }
    }

    private func checkIfSaved() {
        guard let fdcId = log.food?.fdcId else { return }
        isSaved = foodManager.isFoodSaved(foodId: fdcId)
    }

    private func deleteLog() {
        isDeleting = true
        Task {
            await dayLogsVM.removeLog(log)
            await MainActor.run {
                isDeleting = false
                dismiss()
            }
        }
    }
}

// MARK: - Recipe Log Details Content

private struct RecipeLogDetailsContent: View {
    let log: CombinedLog

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @EnvironmentObject var foodManager: FoodManager
    @ObservedObject private var goalsStore = NutritionGoalsStore.shared

    @State private var nutrientTargets: [String: NutrientTargetDetails] = NutritionGoalsStore.shared.currentTargets
    @State private var fullRecipe: Recipe?
    @State private var isLoadingRecipe = false
    @State private var isSaved = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showExplodeConfirmation = false
    @State private var isDeleting = false
    @State private var isExploding = false
    @State private var isDuplicating = false

    private var recipe: RecipeSummary? {
        log.recipe
    }

    private var servings: Double {
        Double(log.servingsConsumed ?? 1)
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

    // MARK: - Computed Nutrition Values (scaled by servings)
    private var calories: Double {
        (recipe?.calories ?? 0) * servings
    }

    private var protein: Double {
        (recipe?.protein ?? 0) * servings
    }

    private var carbs: Double {
        (recipe?.carbs ?? 0) * servings
    }

    private var fat: Double {
        (recipe?.fat ?? 0) * servings
    }

    // MARK: - Macro Arcs
    private var macroArcs: [LogDetailMacroArc] {
        let proteinCalories = protein * 4
        let carbCalories = carbs * 4
        let fatCalories = fat * 9
        let total = max(proteinCalories + carbCalories + fatCalories, 1)
        let segments = [
            (color: proteinColor, fraction: proteinCalories / total),
            (color: fatColor, fraction: fatCalories / total),
            (color: carbColor, fraction: carbCalories / total)
        ]
        var running: Double = 0
        return segments.map { segment in
            let arc = LogDetailMacroArc(start: running, end: running + segment.fraction, color: segment.color)
            running += segment.fraction
            return arc
        }
    }

    // MARK: - Goal Percentages
    private var proteinGoalPercent: Double {
        guard dayLogsVM.proteinGoal > 0 else { return 0 }
        return (protein / dayLogsVM.proteinGoal) * 100
    }

    private var fatGoalPercent: Double {
        guard dayLogsVM.fatGoal > 0 else { return 0 }
        return (fat / dayLogsVM.fatGoal) * 100
    }

    private var carbGoalPercent: Double {
        guard dayLogsVM.carbsGoal > 0 else { return 0 }
        return (carbs / dayLogsVM.carbsGoal) * 100
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                recipeInfoCard
                macroSummaryCard
                dailyGoalShareCard

                if isLoadingRecipe {
                    ingredientsLoadingView
                } else if let fullRecipe = fullRecipe, !fullRecipe.recipeItems.isEmpty {
                    ingredientsSection(items: fullRecipe.recipeItems)
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Recipe Log")
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
                            showExplodeConfirmation = true
                        } label: {
                            Label("Explode into Ingredients", systemImage: "arrow.up.right.and.arrow.down.left.rectangle")
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
        .confirmationDialog("Delete Log?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteLog()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove this entry from your timeline.")
        }
        .confirmationDialog("Explode Recipe?", isPresented: $showExplodeConfirmation) {
            Button("Explode") {
                explodeRecipe()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace this recipe with individual entries for each ingredient. The original recipe in your library will not be affected.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditLogSheet(log: log) {
            }
            .environmentObject(dayLogsVM)
            .environmentObject(foodManager)
        }
        .overlay {
            if isDeleting || isExploding || isDuplicating {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView(isExploding ? "Exploding recipe..." : (isDuplicating ? "Duplicating..." : "Deleting..."))
                            .padding()
                            .background(Color("iosnp"))
                            .cornerRadius(12)
                    }
            }
        }
        .task {
            reloadStoredNutrientTargets()
            checkIfSaved()
            await loadFullRecipe()
        }
        .onReceive(goalsStore.$state) { _ in
            reloadStoredNutrientTargets()
        }
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
                Text(recipe?.title ?? "Recipe")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .padding(.vertical, 12)

            Divider()

            // Row 2: Servings Consumed
            HStack {
                Text("Servings")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.1f", servings))
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(chipColor))
            }
            .padding(.vertical, 12)

            if let prepTime = recipe?.prepTime, prepTime > 0 {
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

            if let cookTime = recipe?.cookTime, cookTime > 0 {
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

            if let mealType = log.mealType {
                Divider()
                HStack {
                    Text("Meal")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(mealType)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
            }

            if let scheduledAt = log.scheduledAt {
                Divider()
                HStack {
                    Text("Logged")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(scheduledAt, style: .date)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    Text("at")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    Text(scheduledAt, style: .time)
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
                macroStatRow(title: "Protein", value: protein, unit: "g", color: proteinColor)
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Fat", value: fat, unit: "g", color: fatColor)
                Divider().background(Color.white.opacity(0.2))
                macroStatRow(title: "Carbs", value: carbs, unit: "g", color: carbColor)
            }

            Spacer()

            LogDetailMacroRingView(calories: calories, arcs: macroArcs)
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
            Text("\(value.logDetailFormatted)\(unit)")
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
                LogDetailGoalShareBubble(title: "Protein",
                                         percent: proteinGoalPercent,
                                         grams: protein,
                                         goal: dayLogsVM.proteinGoal,
                                         color: proteinColor)
                LogDetailGoalShareBubble(title: "Fat",
                                         percent: fatGoalPercent,
                                         grams: fat,
                                         goal: dayLogsVM.fatGoal,
                                         color: fatColor)
                LogDetailGoalShareBubble(title: "Carbs",
                                         percent: carbGoalPercent,
                                         grams: carbs,
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
    private var ingredientsLoadingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title3)
                .fontWeight(.semibold)

            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading ingredients...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(cardColor)
            )
        }
        .padding(.horizontal)
    }

    private func ingredientsSection(items: [RecipeFoodItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
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

                    if index < items.count - 1 {
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

    // MARK: - Actions
    private func reloadStoredNutrientTargets() {
        nutrientTargets = NutritionGoalsStore.shared.currentTargets
    }

    private func loadFullRecipe() async {
        guard let recipeId = recipe?.recipeId else { return }

        isLoadingRecipe = true
        defer { isLoadingRecipe = false }

        // Fetch full recipe from repository or server
        if let cached = RecipesRepository.shared.snapshot.recipes.first(where: { $0.id == recipeId }) {
            fullRecipe = cached
        }
        // If not in cache, could fetch from server here
    }

    private func toggleSave() {
        guard let recipeId = recipe?.recipeId else { return }

        if isSaved {
            foodManager.unsaveRecipe(recipeId: recipeId) { result in
                if case .success = result {
                    isSaved = false
                    SavedRecipesRepository.shared.removeOptimistically(recipeId: recipeId)
                }
            }
        } else {
            foodManager.saveRecipe(recipeId: recipeId) { result in
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
        guard let recipeId = recipe?.recipeId else { return }
        foodManager.isRecipeSaved(recipeId: recipeId) { saved in
            isSaved = saved
        }
    }

    private func deleteLog() {
        isDeleting = true
        Task {
            await dayLogsVM.removeLog(log)
            await MainActor.run {
                isDeleting = false
                dismiss()
            }
        }
    }

    private func duplicateRecipe() {
        guard let recipeId = recipe?.recipeId else { return }
        guard let recipeToClone = fullRecipe ?? RecipesRepository.shared.snapshot.recipes.first(where: { $0.id == recipeId }) else {
            print("Cannot duplicate: recipe not found")
            return
        }

        isDuplicating = true

        foodManager.duplicateRecipe(recipe: recipeToClone) { result in
            isDuplicating = false

            switch result {
            case .success(let newRecipe):
                // Add to repository
                RecipesRepository.shared.insertOptimistically(newRecipe)
                print("Recipe duplicated successfully: \(newRecipe.title)")
            case .failure(let error):
                print("Failed to duplicate recipe: \(error.localizedDescription)")
            }
        }
    }

    private func explodeRecipe() {
        guard let recipeLogId = log.recipeLogId else { return }

        isExploding = true

        dayLogsVM.explodeRecipeLog(recipeLogId: recipeLogId) { result in
            isExploding = false

            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                print("Failed to explode recipe: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Supporting Types

private struct LogDetailMacroArc {
    let start: Double
    let end: Double
    let color: Color
}

private struct LogDetailMacroRingView: View {
    let calories: Double
    let arcs: [LogDetailMacroArc]

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

private struct LogDetailGoalShareBubble: View {
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
            Text("\(grams.logDetailGoalShareFormatted) / \(goal.logDetailGoalShareFormatted)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Double Extensions for LogDetails

private extension Double {
    var logDetailFormatted: String {
        if self.isNaN { return "0" }
        if abs(self - rounded()) < 0.01 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }

    var logDetailGoalShareFormatted: String {
        if self.isNaN || self.isInfinite { return "0" }
        let roundedValue = (self * 10).rounded() / 10
        if roundedValue.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(roundedValue))
        }
        return String(format: "%.1f", roundedValue)
    }
}
