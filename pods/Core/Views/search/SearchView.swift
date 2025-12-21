//
//  SearchView.swift
//  pods
//
//  Created by Dimi Nunez on 12/17/25.
//

import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @EnvironmentObject var proFeatureGate: ProFeatureGate
    @ObservedObject private var recentFoodsRepo = RecentFoodLogsRepository.shared
    @StateObject private var plateViewModel = PlateViewModel()
    @State private var showQuickAddSheet = false
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var showPlateView = false

    /// Recent food logs from the repository
    private var recentFoodLogs: [CombinedLog] {
        recentFoodsRepo.snapshot.logs
    }

    private var isSearchMode: Bool {
        isSearchFocused || !searchText.isEmpty
    }

    var body: some View {
        Group {
            if isSearchMode {
                // MARK: - Focused State: Plain list, no cards
                focusedListContent
            } else {
                // MARK: - Unfocused State: Grouped list with cards
                unfocusedListContent
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, isPresented: $isSearchFocused)
        .onSubmit(of: .search) {
            // Handle search submission
        }
        .sheet(isPresented: $showQuickAddSheet) {
            QuickAddSheet()
                .environmentObject(foodManager)
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
                .environmentObject(proFeatureGate)
            }
        }
        .task {
            if let email = foodManager.userEmail {
                recentFoodsRepo.configure(email: email)
                await recentFoodsRepo.refresh()
            }
        }
    }

    // MARK: - Unfocused List (with cards)
    private var unfocusedListContent: some View {
        List {
            // Categories Section
            Section {
                NavigationLink {
                    FoodsView()
                        .environmentObject(foodManager)
                        .environmentObject(viewModel)
                } label: {
                    SearchCategoryRow(icon: "carrot", title: "Foods", iconColor: .primary, showChevron: false)
                }

                NavigationLink {
                    RecipeView()
                        .environmentObject(foodManager)
                        .environmentObject(viewModel)
                } label: {
                    SearchCategoryRow(icon: "fork.knife", title: "Recipes", iconColor: .primary, showChevron: false)
                }
                SearchCategoryRow(icon: "bookmark", title: "Saved", iconColor: .primary)
                SearchCategoryRow(icon: "dumbbell", title: "Workouts", iconColor: .primary)

                QuickAddRow {
                    showQuickAddSheet = true
                }
            }
            .listRowBackground(Color("sheetcard"))

            // Recents Section
            if !recentFoodLogs.isEmpty {
                Section {
                    ForEach(recentFoodLogs) { log in
                        RecentFoodRow(
                            log: log,
                            onLogTapped: {
                                if let food = log.food?.asFood {
                                    logFoodDirectly(food)
                                }
                            },
                            onAddToPlateTapped: {
                                if let food = log.food?.asFood {
                                    addFoodToPlate(food)
                                }
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteLog(log)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Recents")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .textCase(nil)
                }
                .listRowBackground(Color("sheetcard"))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Focused List (plain, no cards)
    private var focusedListContent: some View {
        List {
            if !recentFoodLogs.isEmpty {
                Section {
                    ForEach(recentFoodLogs) { log in
                        RecentFoodRow(
                            log: log,
                            onLogTapped: {
                                if let food = log.food?.asFood {
                                    logFoodDirectly(food)
                                }
                            },
                            onAddToPlateTapped: {
                                if let food = log.food?.asFood {
                                    addFoodToPlate(food)
                                }
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteLog(log)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Recents")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .listRowSeparator(.visible)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
    }

    // MARK: - Delete Log
    private func deleteLog(_ log: CombinedLog) {
        guard let foodLogId = log.foodLogId else { return }
        foodManager.deleteFoodLog(id: foodLogId) { result in
            if case .success = result {
                Task {
                    await recentFoodsRepo.refresh(force: true)
                }
            }
        }
    }

    // MARK: - Log Food Directly
    private func logFoodDirectly(_ food: Food) {
        let mealPeriod = suggestedMealPeriod(for: Date())
        let mealLabel = mealPeriod.title
        let servings = food.numberOfServings ?? 1

        foodManager.logFood(
            email: viewModel.email,
            food: food,
            meal: mealLabel,
            servings: servings,
            date: Date(),
            notes: nil
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let logged):
                    foodManager.lastLoggedItem = (name: logged.food.displayName, calories: Double(logged.food.calories))
                    foodManager.showLogSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        foodManager.showLogSuccess = false
                    }
                    dayLogsVM.loadLogs(for: Date(), force: true)
                    Task {
                        await recentFoodsRepo.refresh(force: true)
                    }
                case .failure:
                    break
                }
            }
        }
    }

    // MARK: - Add Food to Plate
    private func addFoodToPlate(_ food: Food) {
        let entry = buildPlateEntry(from: food)
        plateViewModel.add(entry)
        showPlateView = true
    }

    private func buildPlateEntry(from food: Food) -> PlateEntry {
        let baseMacros = MacroTotals(
            calories: food.calories ?? 0,
            protein: food.protein ?? 0,
            carbs: food.carbs ?? 0,
            fat: food.fat ?? 0
        )

        var baseNutrients: [String: RawNutrientValue] = [:]
        for nutrient in food.foodNutrients {
            let key = nutrient.nutrientName.lowercased()
            baseNutrients[key] = RawNutrientValue(value: nutrient.value ?? 0, unit: nutrient.unitName)
        }

        let baselineGramWeight = food.foodMeasures.first?.gramWeight ?? food.servingSize ?? 100

        return PlateEntry(
            food: food,
            servings: food.numberOfServings ?? 1,
            selectedMeasureId: food.foodMeasures.first?.id,
            availableMeasures: food.foodMeasures,
            baselineGramWeight: baselineGramWeight,
            baseNutrientValues: baseNutrients,
            baseMacroTotals: baseMacros,
            servingDescription: food.servingSizeText ?? "1 serving",
            mealItems: food.mealItems ?? [],
            mealPeriod: suggestedMealPeriod(for: Date()),
            mealTime: Date()
        )
    }

    private func suggestedMealPeriod(for date: Date) -> MealPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
        }
    }
}

// MARK: - Search Category Row

struct SearchCategoryRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 20, alignment: .center)

            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.primary)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }
}

// MARK: - Quick Add Row

struct QuickAddRow: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 20, alignment: .center)

            Text("Quick Add")
                .font(.system(size: 15))
                .foregroundColor(.primary)

            Spacer()
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Recent Food Row

struct RecentFoodRow: View {
    let log: CombinedLog
    var onLogTapped: (() -> Void)?
    var onAddToPlateTapped: (() -> Void)?

    private var displayName: String {
        log.food?.displayName ?? log.message
    }

    private var caloriesValue: Int {
        Int(log.displayCalories.rounded())
    }

    private var proteinValue: Int {
        if let food = log.food, let protein = food.protein {
            let servings = food.numberOfServings > 0 ? food.numberOfServings : 1
            return Int((protein * servings).rounded())
        }
        if let protein = log.meal?.protein ?? log.recipe?.protein {
            return Int(protein.rounded())
        }
        return 0
    }

    private var fatValue: Int {
        if let food = log.food, let fat = food.fat {
            let servings = food.numberOfServings > 0 ? food.numberOfServings : 1
            return Int((fat * servings).rounded())
        }
        if let fat = log.meal?.fat ?? log.recipe?.fat {
            return Int(fat.rounded())
        }
        return 0
    }

    private var carbsValue: Int {
        if let food = log.food, let carbs = food.carbs {
            let servings = food.numberOfServings > 0 ? food.numberOfServings : 1
            return Int((carbs * servings).rounded())
        }
        if let carbs = log.meal?.carbs ?? log.recipe?.carbs {
            return Int(carbs.rounded())
        }
        return 0
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
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

            // Dropdown menu button
            Menu {
                Button {
                    onLogTapped?()
                } label: {
                    Label("Log", systemImage: "plus.circle")
                }

                Button {
                    onAddToPlateTapped?()
                } label: {
                    Label("Add to Plate", systemImage: "fork.knife")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .contentShape(Rectangle())
    }

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
            .environmentObject(FoodManager())
            .environmentObject(OnboardingViewModel())
            .environmentObject(DayLogsViewModel())
            .environmentObject(ProFeatureGate())
    }
}
