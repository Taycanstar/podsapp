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

    private init() {}

    func configure(email: String) {
        guard currentEmail != email else { return }
        currentEmail = email

        if let cached: CachedEntry<UserFoodsSnapshot> = store.load(UserFoodsSnapshot.self,
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
           let cached: CachedEntry<UserFoodsSnapshot> = store.load(UserFoodsSnapshot.self,
                                                                   for: key(for: email)),
           cached.isFresh(ttl: RepositoryTTL.userFoods) {
            snapshot = cached.value
            return true
        }

        if isRefreshing { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let response = try await fetchPage(for: email, page: 1)
            snapshot = UserFoodsSnapshot(
                foods: response.foods,
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
        if let email = currentEmail {
            store.clear(for: key(for: email))
        }
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
