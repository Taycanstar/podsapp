import Foundation
import Combine

struct RecipesSnapshot: Codable {
    var recipes: [Recipe]
    var nextPage: Int
    var hasMore: Bool

    static let empty = RecipesSnapshot(recipes: [], nextPage: 1, hasMore: true)
}

@MainActor
final class RecipesRepository: ObservableObject {
    static let shared = RecipesRepository()

    @Published private(set) var snapshot: RecipesSnapshot = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingNextPage = false

    private var currentEmail: String?
    private let network = NetworkManager()
    private let store = UserContextStore.shared

    /// Recipes that were optimistically inserted and should be preserved across refreshes
    private var optimisticRecipes: [Recipe] = []

    private init() {}

    func configure(email: String) {
        guard currentEmail != email else { return }
        currentEmail = email
        optimisticRecipes = [] // Clear optimistic recipes when switching users

        if let cached: CachedEntry<RecipesSnapshot> = store.load(RecipesSnapshot.self,
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
           let cached: CachedEntry<RecipesSnapshot> = store.load(RecipesSnapshot.self,
                                                                 for: key(for: email)),
           cached.isFresh(ttl: RepositoryTTL.recipes) {
            // Merge optimistic recipes at the front when using cached data
            let cachedIds = Set(cached.value.recipes.map { $0.id })
            let stillPendingOptimistic = optimisticRecipes.filter { !cachedIds.contains($0.id) }
            let mergedRecipes = stillPendingOptimistic + cached.value.recipes
            optimisticRecipes = stillPendingOptimistic

            snapshot = RecipesSnapshot(
                recipes: mergedRecipes,
                nextPage: cached.value.nextPage,
                hasMore: cached.value.hasMore
            )
            return true
        }

        if isRefreshing { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let response = try await fetchPage(for: email, page: 1)
            // Merge optimistic recipes at the front, removing any that now exist in the response
            let responseIds = Set(response.recipes.map { $0.id })
            let stillPendingOptimistic = optimisticRecipes.filter { !responseIds.contains($0.id) }
            let mergedRecipes = stillPendingOptimistic + response.recipes

            // Clear optimistic recipes that are now confirmed by the server
            optimisticRecipes = stillPendingOptimistic

            snapshot = RecipesSnapshot(
                recipes: mergedRecipes,
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
            snapshot = RecipesSnapshot(
                recipes: merge(existing: snapshot.recipes, with: response.recipes),
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
        optimisticRecipes = []
        if let email = currentEmail {
            store.clear(for: key(for: email))
        }
    }

    /// Optimistically insert a newly created recipe at the top of the list
    func insertOptimistically(_ recipe: Recipe) {
        // Track in optimistic array to preserve across refreshes
        if !optimisticRecipes.contains(where: { $0.id == recipe.id }) {
            optimisticRecipes.insert(recipe, at: 0)
        }

        var recipes = snapshot.recipes
        // Avoid duplicates in snapshot
        if !recipes.contains(where: { $0.id == recipe.id }) {
            recipes.insert(recipe, at: 0)
        }
        snapshot = RecipesSnapshot(
            recipes: recipes,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    /// Remove an optimistic recipe (on failure)
    func removeOptimistic(id: Int) {
        optimisticRecipes.removeAll { $0.id == id }
        var recipes = snapshot.recipes
        recipes.removeAll { $0.id == id }
        snapshot = RecipesSnapshot(
            recipes: recipes,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    /// Optimistically update an existing recipe in place
    func updateOptimistically(_ recipe: Recipe) {
        // Update in optimistic array if present
        if let index = optimisticRecipes.firstIndex(where: { $0.id == recipe.id }) {
            optimisticRecipes[index] = recipe
        }
        // Update in snapshot
        if let index = snapshot.recipes.firstIndex(where: { $0.id == recipe.id }) {
            var recipes = snapshot.recipes
            recipes[index] = recipe
            snapshot = RecipesSnapshot(
                recipes: recipes,
                nextPage: snapshot.nextPage,
                hasMore: snapshot.hasMore
            )
        }
        persist()
    }

    private func merge(existing: [Recipe], with newRecipes: [Recipe]) -> [Recipe] {
        var seen = Set(existing.map { $0.id })
        var combined = existing
        for recipe in newRecipes where !seen.contains(recipe.id) {
            combined.append(recipe)
            seen.insert(recipe.id)
        }
        return combined
    }

    private func fetchPage(for email: String, page: Int) async throws -> RecipesResponse {
        try await withCheckedThrowingContinuation { continuation in
            network.getRecipes(userEmail: email, page: page) { result in
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
        UserScopedKey(email: email, domain: .recipes)
    }
}
