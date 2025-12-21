//
//  AddIngedientsSearch.swift
//  pods
//
//  Created by Dimi Nunez on 12/20/25.
//

import SwiftUI

/// A search view for adding ingredients to recipes or meals
/// Uses the same multi-tier search as SearchView but with ingredient-specific actions
struct AddIngredientsSearch: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager

    /// Callback when an ingredient is selected
    var onIngredientAdded: (Food) -> Void

    // MARK: - State
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var searchResults: InstantFoodSearchResponse?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var addedItemIds: Set<String> = []

    @ObservedObject private var recentFoodsRepo = RecentFoodLogsRepository.shared

    /// Debounce time for search (250ms recommended by MacroFactor)
    private let searchDebounceNanoseconds: UInt64 = 250_000_000

    /// Recent food logs from the repository
    private var recentFoodLogs: [CombinedLog] {
        recentFoodsRepo.snapshot.logs
    }

    var body: some View {
        List {
            if isSearching {
                // Loading state
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 20)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
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
                                FoodSearchResultIngredientRow(
                                    item: item,
                                    isAdded: addedItemIds.contains(item.id)
                                ) {
                                    addIngredient(item)
                                }
                            }
                        } header: {
                            sectionHeader("History")
                        }
                    }

                    // Tier 2: My Foods (Custom)
                    if !results.custom.isEmpty {
                        Section {
                            ForEach(results.custom) { item in
                                FoodSearchResultIngredientRow(
                                    item: item,
                                    isAdded: addedItemIds.contains(item.id)
                                ) {
                                    addIngredient(item)
                                }
                            }
                        } header: {
                            sectionHeader("My Foods")
                        }
                    }

                    // Tier 3: Common Foods
                    if !results.common.isEmpty {
                        Section {
                            ForEach(results.common) { item in
                                FoodSearchResultIngredientRow(
                                    item: item,
                                    isAdded: addedItemIds.contains(item.id)
                                ) {
                                    addIngredient(item)
                                }
                            }
                        } header: {
                            sectionHeader("Common")
                        }
                    }

                    // Tier 4: Branded Foods
                    if !results.branded.isEmpty {
                        Section {
                            ForEach(results.branded) { item in
                                FoodSearchResultIngredientRow(
                                    item: item,
                                    isAdded: addedItemIds.contains(item.id)
                                ) {
                                    addIngredient(item)
                                }
                            }
                        } header: {
                            sectionHeader("Branded")
                        }
                    }
                }
            } else {
                // Default: Show recents when no search query
                if !recentFoodLogs.isEmpty {
                    Section {
                        ForEach(recentFoodLogs) { log in
                            if let food = log.food {
                                RecentIngredientRow(log: log) {
                                    onIngredientAdded(food.asFood)
                                }
                            }
                        }
                    } header: {
                        sectionHeader("Recents")
                    }
                }
            }
        }
        .listStyle(.plain)
        .listRowSeparator(.visible)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .navigationTitle("Add Ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search foods")
        .onChange(of: searchText) { _, newValue in
            handleSearchChange(newValue)
        }
        .task {
            if let email = foodManager.userEmail {
                recentFoodsRepo.configure(email: email)
                await recentFoodsRepo.refresh()
            }
        }
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
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
            searchResults = try await FoodService.shared.instantSearch(
                query: query,
                userEmail: email
            )
        } catch {
            print("[AddIngredientsSearch] Search error: \(error)")
            searchResults = nil
        }
    }

    // MARK: - Add Ingredient
    private func addIngredient(_ item: FoodSearchResult) {
        addedItemIds.insert(item.id)
        let food = item.toFood()
        onIngredientAdded(food)
    }
}

// MARK: - Food Search Result Ingredient Row

struct FoodSearchResultIngredientRow: View {
    let item: FoodSearchResult
    let isAdded: Bool
    var onTapped: (() -> Void)?

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

    var body: some View {
        Button(action: { onTapped?() }) {
            HStack {
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

                        // Macros: P F C
                        macroLabel(prefix: "P", value: proteinValue)
                        macroLabel(prefix: "F", value: fatValue)
                        macroLabel(prefix: "C", value: carbsValue)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Add button or checkmark
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }
}

// MARK: - Recent Ingredient Row

struct RecentIngredientRow: View {
    let log: CombinedLog
    var onTapped: (() -> Void)?

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
        return 0
    }

    private var fatValue: Int {
        if let food = log.food, let fat = food.fat {
            let servings = food.numberOfServings > 0 ? food.numberOfServings : 1
            return Int((fat * servings).rounded())
        }
        return 0
    }

    private var carbsValue: Int {
        if let food = log.food, let carbs = food.carbs {
            let servings = food.numberOfServings > 0 ? food.numberOfServings : 1
            return Int((carbs * servings).rounded())
        }
        return 0
    }

    var body: some View {
        Button(action: { onTapped?() }) {
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

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        AddIngredientsSearch { food in
            print("Added ingredient: \(food.description)")
        }
        .environmentObject(FoodManager())
    }
}
