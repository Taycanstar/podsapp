//
//  SavedView.swift
//  pods
//
//  Created by Dimi Nunez on 12/23/25.
//

import SwiftUI

struct SavedView: View {
    enum SavedTab: String, CaseIterable {
        case foods = "Foods"
        case recipes = "Recipes"
    }

    @State private var selectedTab: SavedTab = .foods
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @ObservedObject private var savedFoodsRepo = SavedFoodsRepository.shared
    @ObservedObject private var savedRecipesRepo = SavedRecipesRepository.shared
    @State private var selectedFoodForDetails: Food?
    @State private var selectedRecipeForDetails: Recipe?

    var body: some View {
        List {
            // Segmented control as first section
            Section {
                Picker("", selection: $selectedTab) {
                    ForEach(SavedTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
            }
            .listRowBackground(Color.clear)
            .listSectionSeparator(.hidden)

            // Content based on selected tab
            switch selectedTab {
            case .foods:
                savedFoodsSection
            case .recipes:
                savedRecipesSection
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedFoodForDetails) { food in
            FoodDetails(food: food)
                .environmentObject(dayLogsVM)
                .environmentObject(foodManager)
        }
        .navigationDestination(item: $selectedRecipeForDetails) { recipe in
            RecipeDetails(recipe: recipe)
                .environmentObject(foodManager)
                .environmentObject(viewModel)
                .environmentObject(dayLogsVM)
        }
        .refreshable {
            switch selectedTab {
            case .foods:
                await savedFoodsRepo.refresh(force: true)
            case .recipes:
                await savedRecipesRepo.refresh(force: true)
            }
        }
        .task {
            if let email = foodManager.userEmail {
                savedFoodsRepo.configure(email: email)
                savedRecipesRepo.configure(email: email)
                await savedFoodsRepo.refresh()
                await savedRecipesRepo.refresh()
            }
        }
    }

    // MARK: - Saved Foods Section

    @ViewBuilder
    private var savedFoodsSection: some View {
        if savedFoodsRepo.isRefreshing && savedFoodsRepo.snapshot.savedFoods.isEmpty {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 40)
            }
            .listRowBackground(Color.clear)
        } else if savedFoodsRepo.snapshot.savedFoods.isEmpty {
            Section {
                emptyStateContent(
                    icon: "bookmark",
                    title: "No Saved Foods",
                    message: "Tap the bookmark icon on any food to save it for quick access."
                )
            }
            .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(savedFoodsRepo.snapshot.savedFoods) { savedFood in
                    SavedFoodRow(savedFood: savedFood)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFoodForDetails = savedFood.food
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                unsaveFood(savedFood)
                            } label: {
                                Label("Remove", systemImage: "bookmark.slash")
                            }
                        }
                }
            }
            .listRowBackground(Color("sheetcard"))
        }
    }

    // MARK: - Saved Recipes Section

    @ViewBuilder
    private var savedRecipesSection: some View {
        if savedRecipesRepo.isRefreshing && savedRecipesRepo.snapshot.savedRecipes.isEmpty {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 40)
            }
            .listRowBackground(Color.clear)
        } else if savedRecipesRepo.snapshot.savedRecipes.isEmpty {
            Section {
                emptyStateContent(
                    icon: "fork.knife",
                    title: "No Saved Recipes",
                    message: "Tap the bookmark icon on any recipe to save it for quick access."
                )
            }
            .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(savedRecipesRepo.snapshot.savedRecipes) { savedRecipe in
                    SavedRecipeRow(savedRecipe: savedRecipe)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRecipeForDetails = savedRecipe.recipe
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                unsaveRecipe(savedRecipe)
                            } label: {
                                Label("Remove", systemImage: "bookmark.slash")
                            }
                        }
                }
            }
            .listRowBackground(Color("sheetcard"))
        }
    }

    // MARK: - Helper Views

    private func emptyStateContent(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    private func unsaveFood(_ savedFood: SavedFood) {
        // Optimistically remove immediately for smooth UI
        savedFoodsRepo.removeOptimistically(foodId: savedFood.food.fdcId)

        foodManager.unsaveFoodByFoodId(foodId: savedFood.food.fdcId) { result in
            if case .failure = result {
                // On failure, refresh to restore the item
                Task {
                    await savedFoodsRepo.refresh(force: true)
                }
            }
        }
    }

    private func unsaveRecipe(_ savedRecipe: SavedRecipe) {
        // Optimistically remove immediately for smooth UI
        savedRecipesRepo.removeOptimistically(recipeId: savedRecipe.recipe.id)

        foodManager.unsaveRecipe(recipeId: savedRecipe.recipe.id) { result in
            if case .failure = result {
                // On failure, refresh to restore the item
                Task {
                    await savedRecipesRepo.refresh(force: true)
                }
            }
        }
    }
}

// MARK: - Saved Food Row

private struct SavedFoodRow: View {
    let savedFood: SavedFood

    private var proteinValue: Int {
        Int(savedFood.food.protein ?? 0)
    }

    private var fatValue: Int {
        Int(savedFood.food.fat ?? 0)
    }

    private var carbsValue: Int {
        Int(savedFood.food.carbs ?? 0)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(savedFood.displayName)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // Calories with flame icon
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("\(Int(savedFood.calories)) cal")
                    }

                    // Macros: P F C
                    Text("P \(proteinValue)g")
                    Text("F \(fatValue)g")
                    Text("C \(carbsValue)g")
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
    }
}

// MARK: - Saved Recipe Row

private struct SavedRecipeRow: View {
    let savedRecipe: SavedRecipe

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(savedRecipe.recipe.title)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // Calories with flame icon
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("\(Int(savedRecipe.recipe.calories)) cal")
                    }

                    // Macros: P F C
                    Text("P \(Int(savedRecipe.recipe.protein))g")
                    Text("F \(Int(savedRecipe.recipe.fat))g")
                    Text("C \(Int(savedRecipe.recipe.carbs))g")
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
    }
}

#Preview {
    NavigationStack {
        SavedView()
            .environmentObject(FoodManager())
            .environmentObject(OnboardingViewModel())
            .environmentObject(DayLogsViewModel())
    }
}
