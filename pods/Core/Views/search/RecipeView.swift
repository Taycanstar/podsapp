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
    @StateObject private var recipesRepo = RecipesRepository.shared

    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var showImportSheet = false
    @State private var showCreateRecipeSheet = false
    @State private var selectedRecipe: Recipe?

    // Edit/Duplicate state
    @State private var recipeToEdit: Recipe?
    @State private var recipeToEditAfterDuplicate: Recipe?
    @State private var isDuplicating = false

    // Delete state
    @State private var recipeToDelete: Recipe?
    @State private var showDeleteConfirmation = false

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
                            onPlusTapped: {
                                closeSearchIfNeeded()
                                selectedRecipe = recipe
                            },
                            onEditTapped: {
                                closeSearchIfNeeded()
                                recipeToEdit = recipe
                            },
                            onDuplicateTapped: {
                                closeSearchIfNeeded()
                                duplicateRecipe(recipe)
                            },
                            onDeleteTapped: {
                                closeSearchIfNeeded()
                                recipeToDelete = recipe
                                showDeleteConfirmation = true
                            }
                        )
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
        .sheet(item: $selectedRecipe) { recipe in
            RecipeSummaryView(recipe: recipe)
                .environmentObject(foodManager)
        }
        .sheet(item: $recipeToEdit) { recipe in
            RecipeDetailSheet(recipe: recipe)
                .environmentObject(foodManager)
                .environmentObject(viewModel)
        }
        .sheet(item: $recipeToEditAfterDuplicate) { recipe in
            RecipeDetailSheet(recipe: recipe)
                .environmentObject(foodManager)
                .environmentObject(viewModel)
        }
        .confirmationDialog(
            "Delete Recipe?",
            isPresented: $showDeleteConfirmation,
            presenting: recipeToDelete
        ) { recipe in
            Button("Delete", role: .destructive) {
                deleteRecipe(recipe)
            }
            Button("Cancel", role: .cancel) {}
        } message: { recipe in
            Text("Are you sure you want to delete \"\(recipe.title)\"? This action cannot be undone.")
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
        .onAppear {
            if !viewModel.email.isEmpty {
                recipesRepo.configure(email: viewModel.email)
            }
            Task {
                await recipesRepo.refresh()
            }
        }
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

    // MARK: - Duplicate Recipe
    private func duplicateRecipe(_ recipe: Recipe) {
        isDuplicating = true

        foodManager.duplicateRecipe(recipe: recipe) { result in
            isDuplicating = false

            switch result {
            case .success(let newRecipe):
                // Open the duplicated recipe for editing
                recipeToEditAfterDuplicate = newRecipe

            case .failure(let error):
                print("❌ Failed to duplicate recipe: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Recipe Detail Sheet Wrapper
// Wraps RecipeDetailView in a NavigationStack for sheet presentation
struct RecipeDetailSheet: View {
    let recipe: Recipe
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            RecipeDetailView(recipe: recipe, path: $path)
        }
    }
}

// MARK: - Recipe Row

struct RecipeRow: View {
    let recipe: Recipe
    var onPlusTapped: (() -> Void)?
    var onEditTapped: (() -> Void)?
    var onDuplicateTapped: (() -> Void)?
    var onDeleteTapped: (() -> Void)?

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

            HStack(spacing: 16) {
                // Bookmark button
                Button {
                    // TODO: Implement bookmark/save functionality
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                // Ellipsis menu
                Menu {
                    Button {
                        onEditTapped?()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        onDuplicateTapped?()
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        onDeleteTapped?()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                }

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
        }
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
