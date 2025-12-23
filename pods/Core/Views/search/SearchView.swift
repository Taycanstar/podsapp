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

    // MARK: - Search State
    @State private var searchResults: InstantFoodSearchResponse?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var loadingItemId: String?
    @State private var selectedFoodForDetails: Food?

    /// Debounce time for search (250ms recommended by MacroFactor)
    private let searchDebounceNanoseconds: UInt64 = 250_000_000

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
        .onChange(of: searchText) { _, newValue in
            handleSearchChange(newValue)
        }
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
        .navigationDestination(item: $selectedFoodForDetails) { food in
            FoodDetails(food: food)
                .environmentObject(dayLogsVM)
                .environmentObject(foodManager)
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
                        .environmentObject(dayLogsVM)
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
                NavigationLink {
                    SavedView()
                        .environmentObject(foodManager)
                        .environmentObject(dayLogsVM)
                } label: {
                    SearchCategoryRow(icon: "bookmark", title: "Saved", iconColor: .primary, showChevron: false)
                }
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
                            },
                            onViewDetailsTapped: {
                                if let food = log.food?.asFood {
                                    selectedFoodForDetails = food
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

    // MARK: - Focused List (plain, no cards) with search results
    private var focusedListContent: some View {
        List {
            if isSearching {
                // Loading state with shimmer placeholders
                Section {
                    ForEach(0..<5, id: \.self) { _ in
                        FoodSearchShimmerRow()
                    }
                } header: {
                    searchSectionHeader("Searching...")
                }
            } else if let results = searchResults, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Multi-tier search results
                if results.isEmpty {
                    // No results found
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("No results found")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    // Tier 1: History
                    if !results.history.isEmpty {
                        Section {
                            ForEach(results.history) { item in
                                FoodSearchResultRow(
                                    item: item,
                                    isLoading: loadingItemId == item.id
                                ) {
                                    handleFoodSearchResultTapped(item)
                                } onAddToPlate: {
                                    handleAddToPlate(item)
                                } onViewDetails: {
                                    handleViewDetails(item)
                                }
                            }
                        } header: {
                            searchSectionHeader("History")
                        }
                    }

                    // Tier 2: My Foods (Custom)
                    if !results.custom.isEmpty {
                        Section {
                            ForEach(results.custom) { item in
                                FoodSearchResultRow(
                                    item: item,
                                    isLoading: loadingItemId == item.id
                                ) {
                                    handleFoodSearchResultTapped(item)
                                } onAddToPlate: {
                                    handleAddToPlate(item)
                                } onViewDetails: {
                                    handleViewDetails(item)
                                }
                            }
                        } header: {
                            searchSectionHeader("My Foods")
                        }
                    }

                    // Tier 3: Common Foods
                    if !results.common.isEmpty {
                        Section {
                            ForEach(results.common) { item in
                                FoodSearchResultRow(
                                    item: item,
                                    isLoading: loadingItemId == item.id
                                ) {
                                    handleFoodSearchResultTapped(item)
                                } onAddToPlate: {
                                    handleAddToPlate(item)
                                } onViewDetails: {
                                    handleViewDetails(item)
                                }
                            }
                        } header: {
                            searchSectionHeader("Common")
                        }
                    }

                    // Tier 4: Branded Foods
                    if !results.branded.isEmpty {
                        Section {
                            ForEach(results.branded) { item in
                                FoodSearchResultRow(
                                    item: item,
                                    isLoading: loadingItemId == item.id
                                ) {
                                    handleFoodSearchResultTapped(item)
                                } onAddToPlate: {
                                    handleAddToPlate(item)
                                } onViewDetails: {
                                    handleViewDetails(item)
                                }
                            }
                        } header: {
                            searchSectionHeader("Branded")
                        }
                    }
                }
            } else {
                // Default: Show recents when no search query
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
                                },
                                onViewDetailsTapped: {
                                    if let food = log.food?.asFood {
                                        selectedFoodForDetails = food
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
                        searchSectionHeader("Recents")
                    }
                }
            }
        }
        .listStyle(.plain)
        .listRowSeparator(.visible)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
    }

    // MARK: - Search Section Header
    private func searchSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.primary)
            .textCase(nil)
    }

    // MARK: - Handle Search Change
    private func handleSearchChange(_ newValue: String) {
        // Cancel previous search task
        searchTask?.cancel()

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = nil
            isSearching = false
            return
        }

        // Start new debounced search
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: searchDebounceNanoseconds)
            } catch {
                return // Task was cancelled
            }

            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed)
        }
    }

    // MARK: - Perform Search
    @MainActor
    private func performSearch(query: String) async {
        guard let email = foodManager.userEmail else { return }

        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await FoodService.shared.instantSearch(
                query: query,
                userEmail: email
            )
            searchResults = results

            // Debug logging
            print("🔍 [SearchView] Search for '\(query)' returned:")
            print("🔍   History: \(results.history.count) items")
            for item in results.history {
                print("🔍     - \(item.displayName) | cal: \(item.calories) | P:\(item.protein) F:\(item.fat) C:\(item.carbs)")
            }
            print("🔍   Custom (My Foods): \(results.custom.count) items")
            for item in results.custom {
                print("🔍     - \(item.displayName) | cal: \(item.calories) | P:\(item.protein) F:\(item.fat) C:\(item.carbs)")
            }
            print("🔍   Common: \(results.common.count) items")
            for item in results.common {
                print("🔍     - \(item.displayName) | cal: \(item.calories) | P:\(item.protein) F:\(item.fat) C:\(item.carbs)")
            }
            print("🔍   Branded: \(results.branded.count) items")
            for item in results.branded {
                print("🔍     - \(item.displayName) | brand: \(item.brandName ?? "n/a") | cal: \(item.calories)")
            }
        } catch {
            print("🔍 [SearchView] Search error: \(error)")
            searchResults = nil
        }
    }

    // MARK: - Handle Food Search Result Tapped
    private func handleFoodSearchResultTapped(_ item: FoodSearchResult) {
        // Check if item already has full nutrients (history/custom items)
        if let nutrients = item.foodNutrients, nutrients.count > 10 {
            let food = item.toFood()
            logFoodDirectly(food)
            return
        }

        // For common/branded, fetch full nutrients from Nutritionix
        guard let email = foodManager.userEmail else {
            let food = item.toFood()
            logFoodDirectly(food)
            return
        }

        loadingItemId = item.id
        Task {
            do {
                let fullResult = try await FoodService.shared.fullFoodLookup(
                    nixItemId: item.nixItemId,
                    foodName: item.nixItemId == nil ? item.name : nil,
                    userEmail: email
                )
                await MainActor.run {
                    loadingItemId = nil
                    let food = fullResult.toFood()
                    logFoodDirectly(food)
                }
            } catch {
                print("[SearchView] Full lookup failed: \(error), using instant search data")
                await MainActor.run {
                    loadingItemId = nil
                    let food = item.toFood()
                    logFoodDirectly(food)
                }
            }
        }
    }

    // MARK: - Handle Add to Plate
    private func handleAddToPlate(_ item: FoodSearchResult) {
        // Check if item already has full nutrients (history/custom items)
        if let nutrients = item.foodNutrients, nutrients.count > 10 {
            let food = item.toFood()
            addFoodToPlate(food)
            return
        }

        // For common/branded, fetch full nutrients from Nutritionix
        guard let email = foodManager.userEmail else {
            let food = item.toFood()
            addFoodToPlate(food)
            return
        }

        loadingItemId = item.id
        Task {
            do {
                let fullResult = try await FoodService.shared.fullFoodLookup(
                    nixItemId: item.nixItemId,
                    foodName: item.nixItemId == nil ? item.name : nil,
                    userEmail: email
                )
                await MainActor.run {
                    loadingItemId = nil
                    let food = fullResult.toFood()
                    addFoodToPlate(food)
                }
            } catch {
                print("[SearchView] Full lookup failed: \(error), using instant search data")
                await MainActor.run {
                    loadingItemId = nil
                    let food = item.toFood()
                    addFoodToPlate(food)
                }
            }
        }
    }

    // MARK: - Handle View Details
    private func handleViewDetails(_ item: FoodSearchResult) {
        // Check if item already has full nutrients (history/custom items)
        if let nutrients = item.foodNutrients, nutrients.count > 10 {
            let food = item.toFood()
            selectedFoodForDetails = food
            return
        }

        // For common/branded, fetch full nutrients from Nutritionix
        guard let email = foodManager.userEmail else {
            let food = item.toFood()
            selectedFoodForDetails = food
            return
        }

        loadingItemId = item.id
        Task {
            do {
                let fullResult = try await FoodService.shared.fullFoodLookup(
                    nixItemId: item.nixItemId,
                    foodName: item.nixItemId == nil ? item.name : nil,
                    userEmail: email
                )
                await MainActor.run {
                    loadingItemId = nil
                    let food = fullResult.toFood()
                    selectedFoodForDetails = food
                }
            } catch {
                print("[SearchView] Full lookup failed: \(error), using instant search data")
                await MainActor.run {
                    loadingItemId = nil
                    let food = item.toFood()
                    selectedFoodForDetails = food
                }
            }
        }
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
                    // Optimistically insert the logged food into recents
                    recentFoodsRepo.insertOptimistically(logged)
                    // Also refresh in background to get canonical data
                    Task {
                        await recentFoodsRepo.refresh(force: true)
                    }
                    // Go back to TimelineView after successful log
                    dismiss()
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
    var onViewDetailsTapped: (() -> Void)?

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
            // Food info
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
            .frame(maxWidth: .infinity, alignment: .leading)

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
        .contentShape(Rectangle())
        .onTapGesture {
            onViewDetailsTapped?()
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }
}

// MARK: - Food Search Result Row

struct FoodSearchResultRow: View {
    let item: FoodSearchResult
    var isLoading: Bool = false
    var onTapped: (() -> Void)?
    var onAddToPlate: (() -> Void)?
    var onViewDetails: (() -> Void)?

    private var caloriesValue: Int {
        Int(item.calories.rounded())
    }

    private var proteinValue: Int {
        Int(item.protein.rounded())
    }

    private var fatValue: Int {
        Int(item.fat.rounded())
    }

    private var carbsValue: Int {
        Int(item.carbs.rounded())
    }

    /// True when all macros are zero (common foods from instant search only have calories)
    private var hasMacros: Bool {
        proteinValue > 0 || fatValue > 0 || carbsValue > 0
    }

    var body: some View {
        HStack {
            // Food info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let brand = item.brandName, !brand.isEmpty {
                    Text(brand)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    // Calories with flame icon
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("\(caloriesValue) cal")
                    }

                    // Macros: P F C (only show if we have macro data)
                    // Common foods from instant search only have calories
                    if hasMacros {
                        macroLabel(prefix: "P", value: proteinValue)
                        macroLabel(prefix: "F", value: fatValue)
                        macroLabel(prefix: "C", value: carbsValue)
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Loading, or dropdown menu button
            if isLoading {
                ProgressView()
                    .frame(width: 22, height: 22)
            } else {
                Menu {
                    Button {
                        onTapped?()
                    } label: {
                        Label("Log", systemImage: "plus.circle")
                    }

                    Button {
                        onAddToPlate?()
                    } label: {
                        Label("Add to Plate", systemImage: "fork.knife")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onViewDetails?()
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }
}

// MARK: - Shimmer Placeholder Row

struct FoodSearchShimmerRow: View {
    @Environment(\.colorScheme) private var colorScheme

    private var placeholderColor: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray5)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Food name placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(placeholderColor)
                    .frame(width: 140, height: 14)
                    .overlay(ShimmerView())
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Macros placeholder
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(placeholderColor)
                        .frame(width: 60, height: 12)
                        .overlay(ShimmerView())
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(placeholderColor)
                        .frame(width: 80, height: 12)
                        .overlay(ShimmerView())
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Spacer()

            // Plus button placeholder
            Circle()
                .fill(placeholderColor)
                .frame(width: 22, height: 22)
                .overlay(ShimmerView())
                .clipShape(Circle())
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
