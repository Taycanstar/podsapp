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
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @StateObject private var recipesRepo = RecipesRepository.shared

    @State private var searchText = ""
    @State private var showImportSheet = false
    @State private var navigationPath = NavigationPath()
    @State private var selectedRecipe: Recipe?
    @State private var selectedFoods: [Food] = []

    // Filtered recipes based on search
    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return recipesRepo.snapshot.recipes
        }
        return recipesRepo.snapshot.recipes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Action Buttons
                HStack(spacing: 12) {
                    // Create Recipe button
                    NavigationLink {
                        CreateRecipeView(path: $navigationPath, selectedFoods: $selectedFoods)
                            .environmentObject(foodManager)
                            .environmentObject(viewModel)
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

                    // Import button
                    Button {
                        showImportSheet = true
                    } label: {
                        Text("Import")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                // Recipes List
                if filteredRecipes.isEmpty {
                    // Empty state
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
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredRecipes) { recipe in
                            RecipeRow(recipe: recipe, onPlusTapped: {
                                selectedRecipe = recipe
                            })
                            if recipe.id != filteredRecipes.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .padding(.top, 16)
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText)
        .sheet(isPresented: $showImportSheet) {
            ImportRecipeSheet()
                .environmentObject(foodManager)
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeSummaryView(recipe: recipe)
                .environmentObject(foodManager)
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
}

// MARK: - Recipe Row

struct RecipeRow: View {
    let recipe: Recipe
    var onPlusTapped: (() -> Void)?

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

            // Plus button
            Button {
                onPlusTapped?()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        RecipeView()
            .environmentObject(FoodManager())
            .environmentObject(OnboardingViewModel())
    }
}
