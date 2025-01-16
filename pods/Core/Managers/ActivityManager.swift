//
//  ActivityManager.swift
//  Pods
//
//  Created by Dimi Nunez on 12/29/24.
//
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
    private let pageSize = 50
    
    init() {
        self.networkManager = NetworkManager()
    }
    
    func initialize(podId: Int, userEmail: String) {
        self.podId = podId
        self.userEmail = userEmail
        resetAndFetchActivities()
    }
    
    private func resetAndFetchActivities() {
        currentPage = 1
        hasMore = true
        activities.removeAll()
        loadCachedActivities()
        loadMoreActivities(refresh: true)
    }
    
    private func loadCachedActivities() {
        guard let podId = podId else { return }
        if let cached = UserDefaults.standard.data(forKey: "activities_\(podId)_page_1"),
           let decodedResponse = try? JSONDecoder().decode(ActivityResponse.self, from: cached) {
            self.activities = decodedResponse.activities
            self.hasMore = decodedResponse.hasMore
        }
    }
    
    private func cacheActivities(_ response: ActivityResponse, forPage page: Int) {
        guard let podId = podId else { return }
        if let encoded = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encoded, forKey: "activities_\(podId)_page_\(page)")
        }
    }
    
    func loadMoreActivities(refresh: Bool = false) {
        guard let podId = podId, let userEmail = userEmail else { return }
        guard !isLoading else { return }
        
        let pageToLoad = refresh ? 1 : currentPage
        isLoading = true
        
        networkManager.fetchUserActivities(podId: podId, userEmail: userEmail, page: pageToLoad) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let (newActivities, hasMore)):
                    if refresh {
                        self.activities = newActivities
                        self.currentPage = 2
                    } else {
                        // Filter out any duplicates before appending
                        let uniqueNewActivities = newActivities.filter { newActivity in
                            !self.activities.contains { $0.id == newActivity.id }
                        }
                        self.activities.append(contentsOf: uniqueNewActivities)
                        self.currentPage += 1
                    }
                    self.hasMore = hasMore
                    
                    // Cache the current page
                    let response = ActivityResponse(
                        activities: newActivities,
                        hasMore: hasMore,
                        totalPages: (self.activities.count + self.pageSize - 1) / self.pageSize,
                        currentPage: pageToLoad
                    )
                    self.cacheActivities(response, forPage: pageToLoad)
                    
                case .failure(let error):
                    self.error = error
                    self.hasMore = false
                }
            }
        }
    }
    

//    func createActivity(
//            duration: Int,
//            notes: String?,
//            items: [(id: Int, notes: String?, columnValues: [String: Any])],
//            completion: @escaping (Result<Activity, Error>) -> Void
//        ) {
//            guard let podId = podId, let userEmail = userEmail else {
//                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not initialized"])))
//                return
//            }
//            
//            networkManager.createActivity(
//                podId: podId,
//                userEmail: userEmail,
//                duration: duration,
//                notes: notes,
//                items: items
//            ) { [weak self] result in
//                DispatchQueue.main.async {
//                    guard let self = self else { return }
//                    switch result {
//                    case .success(let activity):
//                        if !activity.isSingleItem {
//                            self.activities.insert(activity, at: 0)
//                        }
//                        completion(.success(activity))
//                        
//                    case .failure(let error):
//                        self.error = error
//                        completion(.failure(error))
//                    }
//                }
//            }
//        }
    func createActivity(
        duration: Int,
        notes: String?,
        items: [(id: Int, notes: String?, columnValues: [String: Any])],
        tempId: Int? = nil, // Optional tempId
        completion: @escaping (Result<Activity, Error>) -> Void
    ) {
        guard let podId = podId, let userEmail = userEmail else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not initialized"])))
            return
        }

        networkManager.createActivity(
            podId: podId,
            userEmail: userEmail,
            duration: duration,
            notes: notes,
            items: items
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let activity):
                    if let tempId = tempId,
                       let index = self.activities.firstIndex(where: { $0.id == tempId }) {
                        // Replace temporary activity with actual activity
                        self.activities[index] = activity
                    } else {
                        // Insert actual activity normally
                        self.activities.insert(activity, at: 0)
                    }
                    completion(.success(activity))

                case .failure(let error):
                    self.error = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    func deleteActivity(_ activity: Activity) {
        networkManager.deleteActivity(activityId: activity.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.activities.removeAll { $0.id == activity.id }
                    
                    // Update cache for first page
                    let firstPageActivities = Array(self.activities.prefix(self.pageSize))
                    let response = ActivityResponse(
                        activities: firstPageActivities,
                        hasMore: self.activities.count > self.pageSize,
                        totalPages: (self.activities.count + self.pageSize - 1) / self.pageSize,
                        currentPage: 1
                    )
                    self.cacheActivities(response, forPage: 1)
                    
                case .failure(let error):
                    self.error = error
                }
            }
        }
    }
    
    func updateActivity(
        activityId: Int,
        notes: String?,
        items: [(id: Int, notes: String?, columnValues: [String: Any])],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // 1) Make sure we have the needed info
        guard let userEmail = userEmail else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "ActivityManager not initialized"])
            completion(.failure(error))
            return
        }

        // 2) Call networkManager’s update endpoint
        networkManager.updateActivity(
            activityId: activityId,
            userEmail: userEmail,
            notes: notes,
            items: items
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let updatedActivity):
                    // 3) Update local array so UI sees the changes
                    if let index = self.activities.firstIndex(where: { $0.id == updatedActivity.id }) {
                        self.activities[index] = updatedActivity
                    }
                    completion(.success(()))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

}
