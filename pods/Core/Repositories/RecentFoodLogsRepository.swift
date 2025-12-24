//
//  RecentFoodLogsSnapshot.swift
//  pods
//
//  Created by Dimi Nunez on 12/19/25.
//


//
//  RecentFoodLogsRepository.swift
//  pods
//
//  Created by Dimi Nunez on 12/19/25.
//

import Foundation
import Combine

struct RecentFoodLogsSnapshot: Codable {
    var logs: [CombinedLog]
    var nextPage: Int
    var hasMore: Bool

    static let empty = RecentFoodLogsSnapshot(logs: [], nextPage: 1, hasMore: true)
}

@MainActor
final class RecentFoodLogsRepository: ObservableObject {
    static let shared = RecentFoodLogsRepository()

    @Published private(set) var snapshot: RecentFoodLogsSnapshot = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingNextPage = false

    private var currentEmail: String?
    private let network = NetworkManager()
    private let store = UserContextStore.shared
    private let pageSize = 20

    private init() {}

    func configure(email: String) {
        guard currentEmail != email else { return }
        currentEmail = email

        if let cached: CachedEntry<RecentFoodLogsSnapshot> = store.load(RecentFoodLogsSnapshot.self,
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
           let cached: CachedEntry<RecentFoodLogsSnapshot> = store.load(RecentFoodLogsSnapshot.self,
                                                                        for: key(for: email)),
           cached.isFresh(ttl: RepositoryTTL.recentFoodLogs) {
            snapshot = cached.value
            return true
        }

        if isRefreshing { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let response = try await fetchPage(for: email, page: 1)
            snapshot = RecentFoodLogsSnapshot(
                logs: response.logs,
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
            snapshot = RecentFoodLogsSnapshot(
                logs: merge(existing: snapshot.logs, with: response.logs),
                nextPage: response.hasMore ? page + 1 : page,
                hasMore: response.hasMore
            )
            persist()
            return true
        } catch {
            print("RecentFoodLogsRepository loadNextPage error: \(error)")
            return false
        }
    }

    func clear() {
        snapshot = .empty
        if let email = currentEmail {
            store.clear(for: key(for: email))
        }
    }

    /// Optimistically insert a newly logged food at the top of the list
    func insertOptimistically(_ loggedFood: LoggedFood) {
        let combinedLog = makeCombinedLog(from: loggedFood, isOptimistic: true)

        var logs = snapshot.logs
        // Avoid duplicates by foodLogId
        if !logs.contains(where: { $0.foodLogId == loggedFood.foodLogId }) {
            logs.insert(combinedLog, at: 0)
        }
        snapshot = RecentFoodLogsSnapshot(
            logs: logs,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    /// Replace an optimistic placeholder (by its temporary `foodLogId`) with the canonical server log
    func replaceOptimisticLog(placeholderId: Int, with loggedFood: LoggedFood) {
        var logs = snapshot.logs
        logs.removeAll { $0.foodLogId == placeholderId }

        let combinedLog = makeCombinedLog(from: loggedFood, isOptimistic: false)
        logs.insert(combinedLog, at: 0)

        snapshot = RecentFoodLogsSnapshot(
            logs: logs,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    /// Remove an optimistic placeholder if the server rejects the log
    func removeOptimisticLog(placeholderId: Int) {
        var logs = snapshot.logs
        let originalCount = logs.count
        logs.removeAll { $0.foodLogId == placeholderId }
        guard logs.count != originalCount else { return }

        snapshot = RecentFoodLogsSnapshot(
            logs: logs,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    private func makeCombinedLog(from loggedFood: LoggedFood, isOptimistic: Bool) -> CombinedLog {
        CombinedLog(
            type: .food,
            status: loggedFood.status,
            calories: loggedFood.calories,
            message: loggedFood.message,
            foodLogId: loggedFood.foodLogId,
            food: loggedFood.food,
            mealType: loggedFood.mealType,
            mealLogId: nil,
            meal: nil,
            mealTime: nil,
            scheduledAt: Date(),
            recipeLogId: nil,
            recipe: nil,
            servingsConsumed: nil,
            activityId: nil,
            activity: nil,
            workoutLogId: nil,
            workout: nil,
            logDate: nil,
            dayOfWeek: nil,
            isOptimistic: isOptimistic
        )
    }

    private func merge(existing: [CombinedLog], with newLogs: [CombinedLog]) -> [CombinedLog] {
        var seen = Set(existing.map { $0.id })
        var combined = existing
        for log in newLogs where !seen.contains(log.id) {
            combined.append(log)
            seen.insert(log.id)
        }
        return combined
    }

    private func fetchPage(for email: String, page: Int) async throws -> RecentFoodLogsResponse {
        try await withCheckedThrowingContinuation { continuation in
            network.getRecentFoodLogs(userEmail: email, page: page, pageSize: pageSize) { result in
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
        UserScopedKey(email: email, domain: .recentFoodLogs)
    }
}
