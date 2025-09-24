import Foundation
import Combine

struct SavedMealsSnapshot: Codable {
    var savedMeals: [SavedMeal]
    var nextPage: Int
    var hasMore: Bool

    static let empty = SavedMealsSnapshot(savedMeals: [], nextPage: 1, hasMore: true)
}

@MainActor
final class SavedMealsRepository: ObservableObject {
    static let shared = SavedMealsRepository()

    @Published private(set) var snapshot: SavedMealsSnapshot = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingNextPage = false

    private var currentEmail: String?
    private let network = NetworkManagerTwo.shared
    private let store = UserContextStore.shared

    private init() {}

    func configure(email: String) {
        guard currentEmail != email else { return }
        currentEmail = email

        if let cached: CachedEntry<SavedMealsSnapshot> = store.load(SavedMealsSnapshot.self,
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
           let cached: CachedEntry<SavedMealsSnapshot> = store.load(SavedMealsSnapshot.self,
                                                                    for: key(for: email)),
           cached.isFresh(ttl: RepositoryTTL.savedMeals) {
            snapshot = cached.value
            return true
        }

        if isRefreshing { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let response = try await fetchPage(for: email, page: 1)
            snapshot = SavedMealsSnapshot(
                savedMeals: response.savedMeals,
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
            snapshot = SavedMealsSnapshot(
                savedMeals: merge(existing: snapshot.savedMeals, with: response.savedMeals),
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

    private func merge(existing: [SavedMeal], with newMeals: [SavedMeal]) -> [SavedMeal] {
        var seen = Set(existing.map { $0.id })
        var combined = existing
        for meal in newMeals where !seen.contains(meal.id) {
            combined.append(meal)
            seen.insert(meal.id)
        }
        return combined
    }

    private func fetchPage(for email: String, page: Int) async throws -> SavedMealsResponse {
        try await withCheckedThrowingContinuation { continuation in
            network.getSavedMeals(userEmail: email, page: page) { result in
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
        UserScopedKey(email: email, domain: .savedMeals)
    }
}
