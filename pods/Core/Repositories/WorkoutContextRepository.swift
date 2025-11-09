//
//  WorkoutContextRepository.swift
//  pods
//
//  Created by Dimi Nunez on 11/4/25.
//


//
//  WorkoutContextRepository.swift
//  Pods
//
//  Created by Codex on 2/9/26.
//

import Foundation

/// Lightweight facade around `UserContextStore` dedicated to persisting the last
/// known workout context snapshot. This lets us hydrate GPT prompts instantly
/// on cold start while still respecting TTL windows.
@MainActor
final class WorkoutContextRepository {
    static let shared = WorkoutContextRepository()

    private let store = UserContextStore.shared

    private init() {}

    func loadContext(for email: String) -> WorkoutContextV1? {
        guard !email.isEmpty else { return nil }
        let key = UserScopedKey(email: email, domain: .workoutContext)
        guard let cached: CachedEntry<WorkoutContextV1> = store.load(WorkoutContextV1.self, for: key) else {
            return nil
        }
        let age = Date().timeIntervalSince(cached.updatedAt)
        guard age < RepositoryTTL.workoutContext else {
            store.clear(for: key)
            return nil
        }
        return cached.value
    }

    func saveContext(_ context: WorkoutContextV1, for email: String) {
        guard !email.isEmpty else { return }
        let entry = CachedEntry(value: context, updatedAt: Date())
        let key = UserScopedKey(email: email, domain: .workoutContext)
        store.save(entry, for: key)
    }

    func clear(for email: String) {
        guard !email.isEmpty else { return }
        store.clear(for: UserScopedKey(email: email, domain: .workoutContext))
    }
}
