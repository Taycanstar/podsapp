
//
//  SavedRecipesSnapshot.swift
//  pods
//
//  Created by Dimi Nunez on 12/23/25.
//


//
//  SavedRecipesRepository.swift
//  pods
//
//  Created by Dimi Nunez on 12/23/25.
//

import Foundation
import Combine

struct SavedRecipesSnapshot: Codable {
    var savedRecipes: [SavedRecipe]
    var nextPage: Int
    var hasMore: Bool

    static let empty = SavedRecipesSnapshot(savedRecipes: [], nextPage: 1, hasMore: true)
}

@MainActor
final class SavedRecipesRepository: ObservableObject {
    static let shared = SavedRecipesRepository()

    @Published private(set) var snapshot: SavedRecipesSnapshot = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingNextPage = false

    private var currentEmail: String?
    private let network = NetworkManagerTwo.shared
    private let store = UserContextStore.shared

    private init() {}

    func configure(email: String) {
        guard currentEmail != email else { return }
        currentEmail = email

        if let cached: CachedEntry<SavedRecipesSnapshot> = store.load(SavedRecipesSnapshot.self,
                                                                       for: key(for: email)) {
            snapshot = cached.value
        } else {
            snapshot = .empty
        }
    }

    @discardableResult
    func refresh(force: Bool = false) async -> Bool {
        guard let email = currentEmail else { return false }

        if !force,
           let cached: CachedEntry<SavedRecipesSnapshot> = store.load(SavedRecipesSnapshot.self,
                                                                       for: key(for: email)),
           cached.isFresh(ttl: RepositoryTTL.savedRecipes) {
            snapshot = cached.value
            return true
        }

        if isRefreshing { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let response = try await fetchPage(for: email, page: 1)
            snapshot = SavedRecipesSnapshot(
                savedRecipes: response.savedRecipes,
                nextPage: response.hasMore ? 2 : 1,
                hasMore: response.hasMore
            )
            persist()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func loadNextPage() async -> Bool {
        guard let email = currentEmail, snapshot.hasMore else { return false }
        if isLoadingNextPage { return false }
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        let page = snapshot.nextPage
        do {
            let response = try await fetchPage(for: email, page: page)
            snapshot = SavedRecipesSnapshot(
                savedRecipes: merge(existing: snapshot.savedRecipes, with: response.savedRecipes),
                nextPage: response.hasMore ? page + 1 : page,
                hasMore: response.hasMore
            )
            persist()
            return true
        } catch {
            return false
        }
    }

    func clear() {
        snapshot = .empty
        if let email = currentEmail {
            store.clear(for: key(for: email))
        }
    }

    /// Optimistically insert a newly saved recipe at the top of the list
    func insertOptimistically(_ savedRecipe: SavedRecipe) {
        var recipes = snapshot.savedRecipes
        // Avoid duplicates
        if !recipes.contains(where: { $0.id == savedRecipe.id || $0.recipe.id == savedRecipe.recipe.id }) {
            recipes.insert(savedRecipe, at: 0)
        }
        snapshot = SavedRecipesSnapshot(
            savedRecipes: recipes,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    /// Optimistically remove a saved recipe from the list
    func removeOptimistically(recipeId: Int) {
        var recipes = snapshot.savedRecipes
        recipes.removeAll { $0.recipe.id == recipeId }
        snapshot = SavedRecipesSnapshot(
            savedRecipes: recipes,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    /// Check if a recipe is saved
    func isSaved(recipeId: Int) -> Bool {
        snapshot.savedRecipes.contains { $0.recipe.id == recipeId }
    }

    private func merge(existing: [SavedRecipe], with newRecipes: [SavedRecipe]) -> [SavedRecipe] {
        var seen = Set(existing.map { $0.id })
        var combined = existing
        for recipe in newRecipes where !seen.contains(recipe.id) {
            combined.append(recipe)
            seen.insert(recipe.id)
        }
        return combined
    }

    private func fetchPage(for email: String, page: Int) async throws -> SavedRecipesResponse {
        try await withCheckedThrowingContinuation { continuation in
            network.getSavedRecipes(userEmail: email, page: page) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func persist() {
        guard let email = currentEmail else { return }
        store.save(CachedEntry(value: snapshot, updatedAt: Date()),
                   for: key(for: email))
    }

    private func key(for email: String) -> UserScopedKey {
        UserScopedKey(email: email, domain: .savedRecipes)
    }
}
