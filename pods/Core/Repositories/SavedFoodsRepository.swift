
//
//  SavedFoodsSnapshot.swift
//  pods
//
//  Created by Dimi Nunez on 12/23/25.
//


import Foundation
import Combine

struct SavedFoodsSnapshot: Codable {
    var savedFoods: [SavedFood]
    var nextPage: Int
    var hasMore: Bool

    static let empty = SavedFoodsSnapshot(savedFoods: [], nextPage: 1, hasMore: true)
}

@MainActor
final class SavedFoodsRepository: ObservableObject {
    static let shared = SavedFoodsRepository()

    @Published private(set) var snapshot: SavedFoodsSnapshot = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingNextPage = false

    private var currentEmail: String?
    private let network = NetworkManagerTwo.shared
    private let store = UserContextStore.shared

    private init() {}

    func configure(email: String) {
        guard currentEmail != email else { return }
        currentEmail = email

        if let cached: CachedEntry<SavedFoodsSnapshot> = store.load(SavedFoodsSnapshot.self,
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
           let cached: CachedEntry<SavedFoodsSnapshot> = store.load(SavedFoodsSnapshot.self,
                                                                    for: key(for: email)),
           cached.isFresh(ttl: RepositoryTTL.savedFoods) {
            snapshot = cached.value
            return true
        }

        if isRefreshing { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let response = try await fetchPage(for: email, page: 1)
            snapshot = SavedFoodsSnapshot(
                savedFoods: response.savedFoods,
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
            snapshot = SavedFoodsSnapshot(
                savedFoods: merge(existing: snapshot.savedFoods, with: response.savedFoods),
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

    /// Optimistically insert a newly saved food at the top of the list
    func insertOptimistically(_ savedFood: SavedFood) {
        var foods = snapshot.savedFoods
        // Avoid duplicates
        if !foods.contains(where: { $0.id == savedFood.id || $0.food.fdcId == savedFood.food.fdcId }) {
            foods.insert(savedFood, at: 0)
        }
        snapshot = SavedFoodsSnapshot(
            savedFoods: foods,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    /// Optimistically remove a saved food from the list
    func removeOptimistically(foodId: Int) {
        var foods = snapshot.savedFoods
        foods.removeAll { $0.food.fdcId == foodId }
        snapshot = SavedFoodsSnapshot(
            savedFoods: foods,
            nextPage: snapshot.nextPage,
            hasMore: snapshot.hasMore
        )
        persist()
    }

    private func merge(existing: [SavedFood], with newFoods: [SavedFood]) -> [SavedFood] {
        var seen = Set(existing.map { $0.id })
        var combined = existing
        for food in newFoods where !seen.contains(food.id) {
            combined.append(food)
            seen.insert(food.id)
        }
        return combined
    }

    private func fetchPage(for email: String, page: Int) async throws -> SavedFoodsResponse {
        try await withCheckedThrowingContinuation { continuation in
            network.getSavedFoods(userEmail: email, page: page) { result in
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
        UserScopedKey(email: email, domain: .savedFoods)
    }
}
