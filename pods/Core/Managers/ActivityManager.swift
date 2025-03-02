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

func createActivity(
    duration: Int,
    notes: String?,
    items: [(id: Int, notes: String?, columnValues: [String: Any])],
    isSingleItem: Bool = false,
    tempId: Int? = nil,
    completion: @escaping (Result<Activity, Error>) -> Void
) {
    // Verify that the manager is properly initialized.
    guard let podId = podId, let userEmail = userEmail else {
        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not initialized"])))
        return
    }
    
    // If a temporary ID is provided, create and insert a temporary activity.
    if let tempId = tempId {
        let tempItems = items.map { item in
            ActivityItem(
                id: Int.random(in: Int.min ... -1),
                activityId: tempId,
                itemId: item.id,
                itemLabel: "Temporary Item",
                loggedAt: Date(),
                notes: item.notes,
                columnValues: item.columnValues.mapValues { value in
                    if let array = value as? [Any] {
                        return .array(array.map { val in
                            if let number = val as? Double {
                                return .number(number)
                            } else if let string = val as? String, let timeValue = TimeValue.fromString(string) {
                                return .time(timeValue)
                            } else if let string = val as? String {
                                return .string(string)
                            }
                            return .null
                        })
                    } else if let number = value as? Double {
                        return .number(number)
                    } else if let string = value as? String, let timeValue = TimeValue.fromString(string) {
                        return .time(timeValue)
                    } else if let string = value as? String {
                        return .string(string)
                    }
                    return .null
                }
            )
        }
        
        let tempActivity = Activity(
            id: tempId,
            podId: podId,
            podTitle: "", // Adjust as needed.
            userEmail: userEmail,
            userName: "",
            duration: duration,
            loggedAt: Date(),
            notes: notes,
            isSingleItem: isSingleItem,
            items: tempItems
        )
        
        self.activities.insert(tempActivity, at: 0)
        print("Inserted temporary activity with ID: \(tempId)")
    }
    
    // Perform the network request to create the activity.
    networkManager.createActivity(
        podId: podId,
        userEmail: userEmail,
        duration: duration,
        notes: notes,
        items: items,
        isSingleItem: isSingleItem
    ) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            switch result {
            case .success(let activity):
                print("Activity received from server: \(activity)")
                if let tempId = tempId,
                   let index = self.activities.firstIndex(where: { $0.id == tempId }) {
                    var updatedActivity = activity
                    // Rebuild ActivityItems using the input items (with updated column values)
                    updatedActivity.items = items.map { inputItem in
                        // Convert the provided columnValues into the proper [String: ColumnValue] representation.
                        let convertedCV: [String: ColumnValue] = inputItem.columnValues.mapValues { value in
                            if let array = value as? [Any] {
                                return .array(array.map { val in
                                    if let num = val as? Double {
                                        return .number(num)
                                    } else if let str = val as? String, let timeValue = TimeValue.fromString(str) {
                                        return .time(timeValue)
                                    } else if let str = val as? String {
                                        return .string(str)
                                    }
                                    return .null
                                })
                            } else if let num = value as? Double {
                                return .number(num)
                            } else if let str = value as? String, let timeValue = TimeValue.fromString(str) {
                                return .time(timeValue)
                            } else if let str = value as? String {
                                return .string(str)
                            }
                            return .null
                        }
                        
                        // Check if the server returned an item for this input item.
                        if let serverItem = activity.items.first(where: { $0.itemId == inputItem.id }) {
                            var mergedItem = serverItem
                            // If updated column values exist, merge them in.
                            if !convertedCV.isEmpty {
                                mergedItem.columnValues = convertedCV
                            }
                            return mergedItem
                        } else {
                            // Otherwise, manually create an ActivityItem.
                            return ActivityItem(
                                id: Int.random(in: Int.min ... -1),
                                activityId: activity.id,
                                itemId: inputItem.id,
                                itemLabel: "Item", // Adjust the label if needed.
                                loggedAt: activity.loggedAt,
                                notes: inputItem.notes,
                                columnValues: convertedCV
                            )
                        }
                    }
                    self.activities[index] = updatedActivity
                    print("Updated activity at index \(index): \(updatedActivity)")
                } else {
                    self.activities.insert(activity, at: 0)
                    print("Inserted activity from server at index 0: \(activity)")
                }
                completion(.success(activity))
                
            case .failure(let error):
                if let tempId = tempId {
                    self.activities.removeAll { $0.id == tempId }
                    print("Removed temporary activity with ID: \(tempId) due to error: \(error)")
                }
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
        completion: @escaping (Result<Activity, Error>) -> Void  // Change to return Activity
    ) {
        guard let userEmail = userEmail else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "ActivityManager not initialized"])
            completion(.failure(error))
            return
        }

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
                    // Update local array with fresh data from server
                    if let index = self.activities.firstIndex(where: { $0.id == updatedActivity.id }) {
                        self.activities[index] = updatedActivity
                    }
                    completion(.success(updatedActivity))  // Pass back the fresh data
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

}
