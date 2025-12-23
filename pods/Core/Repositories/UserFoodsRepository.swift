import Foundation
import Combine

struct UserFoodsSnapshot: Codable {
    var foods: [Food]
    var nextPage: Int
    var hasMore: Bool

    static let empty = UserFoodsSnapshot(foods: [], nextPage: 1, hasMore: true)
}

@MainActor
final class UserFoodsRepository: ObservableObject {
    static let shared = UserFoodsRepository()

    @Published private(set) var snapshot: UserFoodsSnapshot = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingNextPage = false

    private var currentEmail: String?
    private let network = NetworkManager()
    private let store = UserContextStore.shared

    /// Foods that were optimistically inserted and should be preserved across refreshes
    private var optimisticFoods: [Food] = []

    private init() {}

    func configure(email: String) {
        print("🍎 [UserFoodsRepo] configure called with email: \(email), currentEmail: \(currentEmail ?? "nil")")
        guard currentEmail != email else {
            print("🍎 [UserFoodsRepo] Same email, skipping configure")
            return
        }
        currentEmail = email
        optimisticFoods = [] // Clear optimistic foods when switching users

        if let cached: CachedEntry<UserFoodsSnapshot> = store.load(UserFoodsSnapshot.self,
                                                                   for: key(for: email)) {
            snapshot = cached.value
            print("🍎 [UserFoodsRepo] Loaded from cache: \(snapshot.foods.count) foods")
        } else {
            snapshot = .empty
            print("🍎 [UserFoodsRepo] No cache, starting empty")
        }
    }

    @discardableResult
    func refresh(force: Bool = false) async -> Bool {
        print("🍎 [UserFoodsRepo] refresh called, force: \(force), currentEmail: \(currentEmail ?? "nil")")
        guard let email = currentEmail else {
            print("🍎 [UserFoodsRepo] No email configured, returning false")
            return false
        }

        if !force,
           let cached: CachedEntry<UserFoodsSnapshot> = store.load(UserFoodsSnapshot.self,
                                                                   for: key(for: email)),
           cached.isFresh(ttl: RepositoryTTL.userFoods) {
            print("🍎 [UserFoodsRepo] Using fresh cache: \(cached.value.foods.count) foods")
            // Merge optimistic foods at the front when using cached data
            let cachedFdcIds = Set(cached.value.foods.map { $0.fdcId })
            let stillPendingOptimistic = optimisticFoods.filter { !cachedFdcIds.contains($0.fdcId) }
            let mergedFoods = stillPendingOptimistic + cached.value.foods
            print("🍎 [UserFoodsRepo] After cache merge: \(mergedFoods.count) foods (optimistic: \(stillPendingOptimistic.count))")
            optimisticFoods = stillPendingOptimistic

            snapshot = UserFoodsSnapshot(
                foods: mergedFoods,
                nextPage: cached.value.nextPage,
                hasMore: cached.value.hasMore
            )
            return true
        }

        if isRefreshing {
            print("🍎 [UserFoodsRepo] Already refreshing, returning false")
            return false
        }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            print("🍎 [UserFoodsRepo] Fetching from API...")
            let response = try await fetchPage(for: email, page: 1)
            print("🍎 [UserFoodsRepo] API returned \(response.foods.count) foods")
            // Merge optimistic foods at the front, removing any that now exist in the response
            let responseFdcIds = Set(response.foods.map { $0.fdcId })
            let stillPendingOptimistic = optimisticFoods.filter { !responseFdcIds.contains($0.fdcId) }
            let mergedFoods = stillPendingOptimistic + response.foods
            print("🍎 [UserFoodsRepo] After API merge: \(mergedFoods.count) foods (optimistic: \(stillPendingOptimistic.count))")

            // Clear optimistic foods that are now confirmed by the server
            optimisticFoods = stillPendingOptimistic

            snapshot = UserFoodsSnapshot(
                foods: mergedFoods,
                nextPage: response.hasMore ? 2 : 1,
                hasMore: response.hasMore
            )
            persist()
            return true
        } catch {
            print("🍎 [UserFoodsRepo] API error: \(error)")
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
            snapshot = UserFoodsSnapshot(
                foods: merge(existing: snapshot.foods, with: response.foods),
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
        optimisticFoods = []
        if let email = currentEmail {
            store.clear(for: key(for: email))
        }
    }

    /// Optimistically insert a newly created food at the top of the list
    func insertOptimistically(_ food: Food) {
        print("🍎 [UserFoodsRepo] insertOptimistically called")
        print("🍎 [UserFoodsRepo] Current snapshot.foods.count: \(snapshot.foods.count)")
        print("🍎 [UserFoodsRepo] Current optimisticFoods.count: \(optimisticFoods.count)")
        print("🍎 [UserFoodsRepo] currentEmail: \(currentEmail ?? "nil")")

        // Track in optimistic array to preserve across refreshes
        if !optimisticFoods.contains(where: { $0.fdcId == food.fdcId }) {
            optimisticFoods.insert(food, at: 0)
        }

        var foods = snapshot.foods
        // Avoid duplicates in snapshot
        if !foods.contains(where: { $0.fdcId == food.fdcId }) {
            foods.insert(food, at: 0)
        }
        print("🍎 [UserFoodsRepo] After insert, foods.count: \(foods.count)")
        snapshot = UserFoodsSnapshot(
            foods: foods,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    /// Optimistically remove a food from the list (for deletion)
    func removeOptimistically(fdcId: Int) {
        // Remove from optimistic array if present
        optimisticFoods.removeAll { $0.fdcId == fdcId }

        // Remove from snapshot
        var foods = snapshot.foods
        foods.removeAll { $0.fdcId == fdcId }
        snapshot = UserFoodsSnapshot(
            foods: foods,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    /// Optimistically update a food in the list (for edits)
    func updateOptimistically(_ food: Food) {
        print("🍎 [UserFoodsRepo] updateOptimistically called for fdcId: \(food.fdcId)")

        // Update in optimistic array if present
        if let index = optimisticFoods.firstIndex(where: { $0.fdcId == food.fdcId }) {
            optimisticFoods[index] = food
        }

        // Update in snapshot
        var foods = snapshot.foods
        if let index = foods.firstIndex(where: { $0.fdcId == food.fdcId }) {
            foods[index] = food
            print("🍎 [UserFoodsRepo] Updated food at index \(index)")
        }
        snapshot = UserFoodsSnapshot(
            foods: foods,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    private func merge(existing: [Food], with newFoods: [Food]) -> [Food] {
        var seen = Set(existing.map { $0.fdcId })
        var combined = existing
        for food in newFoods where !seen.contains(food.fdcId) {
            combined.append(food)
            seen.insert(food.fdcId)
        }
        return combined
    }

    private func fetchPage(for email: String, page: Int) async throws -> FoodResponse {
        try await withCheckedThrowingContinuation { continuation in
            network.getUserFoods(userEmail: email, page: page) { result in
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
        UserScopedKey(email: email, domain: .userFoods)
    }
}
