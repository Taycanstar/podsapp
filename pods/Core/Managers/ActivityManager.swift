//
//  ActivityManager.swift
//  Pods
//
//  Created by Dimi Nunez on 12/29/24.
//

import Foundation

class ActivityManager: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var error: Error?
    
    private var currentPage = 1
    private var podId: Int?
    private var userEmail: String?
    
    private let networkManager: NetworkManager
    
    init() {
        self.networkManager = NetworkManager()
    }
    
    func initialize(podId: Int, userEmail: String) {
        self.podId = podId
        self.userEmail = userEmail
        loadMoreActivities(refresh: true)
    }
    
    private func loadCachedActivities() {
        guard let podId = podId else { return }
        if let cached = UserDefaults.standard.data(forKey: "activities_\(podId)"),
           let decodedActivities = try? JSONDecoder().decode([Activity].self, from: cached) {
            self.activities = decodedActivities
        }
    }
    
    private func cacheActivities() {
        guard let podId = podId else { return }
        if let encoded = try? JSONEncoder().encode(activities) {
            UserDefaults.standard.set(encoded, forKey: "activities_\(podId)")
        }
    }
    
    func loadMoreActivities(refresh: Bool = false) {
        // Your existing loadMoreActivities implementation
    }
    
    func createActivity(
        duration: Int,
        notes: String?,
        items: [(id: Int, notes: String?, columnValues: [String: Any])]
    ) {
        guard let podId = podId,
              let userEmail = userEmail else {
            print("Cannot create activity: missing podId or userEmail")
            return
        }
        
        print("Starting activity creation with \(items.count) items")
        
        networkManager.createActivity(
            podId: podId,
            userEmail: userEmail,
            duration: duration,
            notes: notes,
            items: items
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let activity):
                    print("Successfully created activity, adding to list")
                    self?.activities.insert(activity, at: 0)
                    self?.cacheActivities()
                case .failure(let error):
                    print("Failed to create activity:", error)
                    self?.error = error
                }
            }
        }
    }
}
