import Foundation
import Combine

struct FoodFeedSnapshot: Codable {
    var loggedFoods: [LoggedFood]
    var nextPage: Int
    var hasMoreFoods: Bool

    static let empty = FoodFeedSnapshot(loggedFoods: [], nextPage: 1, hasMoreFoods: true)
}

@MainActor
final class FoodFeedRepository: ObservableObject {
    static let shared = FoodFeedRepository()

    @Published private(set) var snapshot: FoodFeedSnapshot = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingNextPage = false

    private var currentEmail: String?
    private let network = NetworkManager()
    private let store = UserContextStore.shared

    private init() {}

    func configure(email: String) {
        guard currentEmail != email else { return }
        currentEmail = email

        if let cached: CachedEntry<FoodFeedSnapshot> = store.load(FoodFeedSnapshot.self,
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
           let cached: CachedEntry<FoodFeedSnapshot> = store.load(FoodFeedSnapshot.self,
                                                                  for: key(for: email)),
           cached.isFresh(ttl: RepositoryTTL.foodFeed) {
            snapshot = cached.value
            return true
        }

        if isRefreshing { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let response = try await fetchPage(for: email, page: 1)
            snapshot = FoodFeedSnapshot(
                loggedFoods: response.foodLogs,
                nextPage: response.hasMore ? 2 : 1,
                hasMoreFoods: response.hasMore
            )
            persist()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func loadNextPage() async -> Bool {
        guard let email = currentEmail, snapshot.hasMoreFoods else { return false }
        if isLoadingNextPage { return false }
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        let page = snapshot.nextPage
        do {
            let response = try await fetchPage(for: email, page: page)
            snapshot = FoodFeedSnapshot(
                loggedFoods: merge(existing: snapshot.loggedFoods, with: response.foodLogs),
                nextPage: response.hasMore ? page + 1 : page,
                hasMoreFoods: response.hasMore
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

    private func merge(existing: [LoggedFood], with newLogs: [LoggedFood]) -> [LoggedFood] {
        var seen = Set(existing.map { $0.foodLogId })
        var combined = existing
        for log in newLogs {
            let id = log.foodLogId
            guard !seen.contains(id) else { continue }
            combined.append(log)
            seen.insert(id)
        }
        return combined
    }

    private func fetchPage(for email: String, page: Int) async throws -> FoodLogsResponse {
        try await withCheckedThrowingContinuation { continuation in
            network.getFoodLogs(userEmail: email, page: page) { result in
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
        UserScopedKey(email: email, domain: .foodFeed)
    }
}
