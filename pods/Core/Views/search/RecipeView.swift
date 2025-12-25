//
//  RecipeView 2.swift
//  pods
//
//  Created by Dimi Nunez on 12/18/25.
//


//
//  RecipeView.swift
//  pods
//
//  Created by Dimi Nunez on 12/18/25.
//

import SwiftUI

struct RecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissSearch) private var dismissSearch
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @StateObject private var recipesRepo = RecipesRepository.shared

    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var showImportSheet = false
    @State private var showCreateRecipeSheet = false

    // For logging via RecipeSummaryView (plus button)
    @State private var selectedRecipeForLogging: Recipe?

    // For viewing details (row tap)
    @State private var selectedRecipeForDetails: Recipe?

    // Plate functionality
    @StateObject private var plateViewModel = PlateViewModel()
    @State private var showPlateView = false

    // Filtered recipes based on search
    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return recipesRepo.snapshot.recipes
        }
        return recipesRepo.snapshot.recipes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func closeSearchIfNeeded() {
        dismissSearch()
        isSearchPresented = false
    }

    var body: some View {
        List {
            // Action Buttons Section
            Section {
                HStack(spacing: 12) {
                    // Create Recipe button
                    Button {
                        closeSearchIfNeeded()
                        showCreateRecipeSheet = true
                    } label: {
                        Text("Create")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listSectionSeparator(.hidden)

            // Recipes List Section
            if filteredRecipes.isEmpty {
                // Empty state
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 48))
                            .foregroundColor(.primary)
                        Text("No recipes yet")
                            .font(.headline)
                        Text("Create your first recipe to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(filteredRecipes) { recipe in
                        RecipeRow(
                            recipe: recipe,
                            onLogTapped: {
                                closeSearchIfNeeded()
                                logRecipeDirectly(recipe)
                            },
                            onAddToPlateTapped: {
                                closeSearchIfNeeded()
                                addRecipeToPlate(recipe)
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            closeSearchIfNeeded()
                            selectedRecipeForDetails = recipe
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecipe(recipe)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, isPresented: $isSearchPresented)
        .sheet(isPresented: $showCreateRecipeSheet) {
            NewRecipeView()
                .environmentObject(foodManager)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showImportSheet) {
            ImportRecipeSheet()
                .environmentObject(foodManager)
        }
        .sheet(item: $selectedRecipeForLogging) { recipe in
            RecipeSummaryView(recipe: recipe)
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
            }
        }
        .navigationDestination(item: $selectedRecipeForDetails) { recipe in
            RecipeDetails(recipe: recipe)
                .environmentObject(foodManager)
                .environmentObject(viewModel)
                .environmentObject(dayLogsVM)
        }
        .onAppear {
            if !viewModel.email.isEmpty {
                recipesRepo.configure(email: viewModel.email)
            }
            Task {
                await recipesRepo.refresh()
            }
        }
    }

    // MARK: - Suggested Meal Period
    private func suggestedMealPeriod(for date: Date) -> MealPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .breakfast
        case 11..<14: return .lunch
        case 14..<17: return .snack
        default: return .dinner
        }
    }

    // MARK: - Log Recipe Directly
    private func logRecipeDirectly(_ recipe: Recipe) {
        let mealType = suggestedMealPeriod(for: Date()).title

        foodManager.logRecipe(
            recipe: recipe,
            mealTime: mealType,
            date: Date(),
            notes: nil,
            calories: recipe.calories
        ) { result in
            switch result {
            case .success:
                // Navigate to timeline
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToTimeline"), object: nil)
            case .failure(let error):
                print("Failed to log recipe: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Add Recipe to Plate
    private func addRecipeToPlate(_ recipe: Recipe) {
        let mealPeriod = suggestedMealPeriod(for: Date())

        // Create a single PlateEntry for the entire recipe (not exploded)
        let entry = buildPlateEntry(from: recipe, mealPeriod: mealPeriod)
        plateViewModel.add(entry)
        showPlateView = true
    }

    /// Build a PlateEntry from a Recipe (the whole recipe as one item)
    private func buildPlateEntry(from recipe: Recipe, mealPeriod: MealPeriod) -> PlateEntry {
        // Build base macro totals
        let baseMacros = MacroTotals(
            calories: recipe.calories,
            protein: recipe.protein,
            carbs: recipe.carbs,
            fat: recipe.fat
        )

        // Aggregate nutrients from all recipe items
        var baseNutrients: [String: RawNutrientValue] = [:]
        for item in recipe.recipeItems {
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
            fdcId: recipe.id,
            description: recipe.title,
            brandOwner: nil,
            brandName: nil,
            servingSize: nil,
            numberOfServings: 1.0,
            servingSizeUnit: nil,
            householdServingFullText: "1 serving",
            foodNutrients: [],
            foodMeasures: []
        )

        return PlateEntry(
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
            recipeItems: recipe.recipeItems
        )
    }

    // MARK: - Delete Recipe
    private func deleteRecipe(_ recipe: Recipe) {
        // Remove optimistically FIRST for smooth UI
        recipesRepo.removeOptimistic(id: recipe.id)

        foodManager.deleteRecipe(recipeId: recipe.id) { result in
            if case .failure = result {
                // On failure, refresh to restore the item
                Task {
                    await recipesRepo.refresh(force: true)
                }
            }
            // On success, no need to refresh - already removed optimistically
        }
    }
}

// MARK: - Recipe Row

struct RecipeRow: View {
    let recipe: Recipe
    var onLogTapped: (() -> Void)?
    var onAddToPlateTapped: (() -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("\(Int(recipe.calories)) cal")
                    }

                    Text("P \(Int(recipe.protein))g")
                    Text("F \(Int(recipe.fat))g")
                    Text("C \(Int(recipe.carbs))g")
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }

            Spacer()

            // Menu with Log and Add to Plate options
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
    }
}

#Preview {
    NavigationStack {
        RecipeView()
            .environmentObject(FoodManager())
            .environmentObject(OnboardingViewModel())
    }
}
