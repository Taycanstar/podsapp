//
//  NutritionGoalsStore.swift
//  Pods
//
//  Created by Codex on 6/18/25.
//

import Foundation
import Combine

@MainActor
final class NutritionGoalsStore: ObservableObject {
    enum State {
        case idle
        case loading
        case ready(NutritionGoals)
        case error(String)
    }
    
    static let shared = NutritionGoalsStore()
    
    @Published private(set) var state: State
    
    private let defaults: UserDefaults
    private let goalsKey = "nutritionGoalsData"
    private let lastSyncKey = "nutritionGoalsLastSync"
    private let refreshInterval: TimeInterval = 60 * 60 * 24
    
    private var currentGoals: NutritionGoals?
    private var isRefreshing = false
    
    var cachedGoals: NutritionGoals? {
        currentGoals
    }
    
    var currentTargets: [String: NutrientTargetDetails] {
        currentGoals?.nutrients ?? [:]
    }
    
    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let cached = NutritionGoalsStore.loadCached(from: defaults, key: goalsKey) {
            currentGoals = cached
            state = .ready(cached)
        } else {
            state = .idle
        }
    }
    
    func ensureGoalsAvailable(email: String, forceRefresh: Bool = false) {
        guard !email.isEmpty else { return }
        
        if !forceRefresh,
           let cached = currentGoals,
           !(cached.nutrients?.isEmpty ?? true),
           let lastSync = defaults.object(forKey: lastSyncKey) as? Date,
           Date().timeIntervalSince(lastSync) < refreshInterval {
            if case .ready = state {
                return
            } else {
                state = .ready(cached)
                return
            }
        }
        
        guard !isRefreshing else { return }
        isRefreshing = true
        state = .loading

        // Use updateNutritionGoals instead of generateNutritionGoals
        // generate-goals/ endpoint clears user overrides, which breaks agent goal updates
        // update-nutrition-goals/ respects existing overrides in the database
        NetworkManagerTwo.shared.updateNutritionGoals(userEmail: email) { [weak self] result in
            guard let self else { return }
            self.isRefreshing = false
            switch result {
            case .success(let response):
                self.cache(goals: response.goals)
            case .failure(let error):
                print("⚠️ NutritionGoalsStore fetch failed: \(error.localizedDescription)")
                if let cached = self.currentGoals {
                    self.state = .ready(cached)
                } else {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    func cache(goals: NutritionGoals) {
        currentGoals = goals
        state = .ready(goals)
        saveToDefaults(goals)
    }
    
    private func saveToDefaults(_ goals: NutritionGoals) {
        if let data = try? JSONEncoder().encode(goals) {
            defaults.set(data, forKey: goalsKey)
        }
        defaults.set(Date(), forKey: lastSyncKey)
    }
    
    private static func loadCached(from defaults: UserDefaults, key: String) -> NutritionGoals? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NutritionGoals.self, from: data)
    }
}
