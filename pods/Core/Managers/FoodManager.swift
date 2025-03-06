import Foundation
import SwiftUI

class FoodManager: ObservableObject {
    @Published var loggedFoods: [LoggedFood] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var error: Error?
    @Published var lastLoggedFoodId: Int? = nil
    @Published var showToast = false
    @Published var showMealToast = false
    @Published var showMealLoggedToast = false
    @Published var recentlyAddedFoodIds: Set<Int> = []

    @Published var lastLoggedMealId: Int? = nil
    private let networkManager: NetworkManager
    private var userEmail: String?
    private var currentPage = 1
    private let pageSize = 20

    // Add these properties
    @Published var meals: [Meal] = []
    @Published var isLoadingMeals = false
    private var currentMealPage = 1
    private var hasMoreMeals = true
    @Published var combinedLogs: [CombinedLog] = []
    
    private var lastRefreshTime: Date?
    
    init() {
        self.networkManager = NetworkManager()
    }

    
    
    func initialize(userEmail: String) {
        print("FoodManager: Initializing with email \(userEmail)")
        self.userEmail = userEmail
        resetAndFetchFoods()
           resetAndFetchMeals() 
           resetAndFetchLogs()
    }

    func trackRecentlyAdded(foodId: Int) {
    recentlyAddedFoodIds.insert(foodId)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        self.recentlyAddedFoodIds.remove(foodId)
    }
}
    
    private func resetAndFetchFoods() {
        currentPage = 1
        hasMore = true
        loggedFoods.removeAll()
        loadCachedFoods()
        loadMoreFoods(refresh: true)
    }

    private func resetAndFetchLogs() {
         print("📊 FoodManager: Reset and fetch logs called")
        // Reset state
        currentPage = 1
        hasMore = true
        
        // Store existing logs to allow smooth transitions
        let oldLogs = combinedLogs
        
        // Clear logs with animation if we had previous logs
        if !oldLogs.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) {
                combinedLogs = []
            }
        } else {
            combinedLogs = []
        }
        
        // Try loading from cache first
        let cacheLoaded = loadCachedLogs()
        
        // Then fetch from server with animation
        loadMoreLogs(refresh: true)
        
        // Update refresh timestamp
        lastRefreshTime = Date()
    }
    
    private func loadCachedFoods() {
    guard let userEmail = userEmail else { return }
    if let cached = UserDefaults.standard.data(forKey: "logged_foods_\(userEmail)_page_1"),
       let decodedResponse = try? JSONDecoder().decode(FoodLogsResponse.self, from: cached) {
        self.loggedFoods = uniqueLogs(from: decodedResponse.foodLogs)
        self.hasMore = decodedResponse.hasMore
    }
}

    
    private func cacheFoods(_ response: FoodLogsResponse, forPage page: Int) {
        guard let userEmail = userEmail else { return }
        if let encoded = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encoded, forKey: "logged_foods_\(userEmail)_page_\(page)")
        }
    }

    private func cacheLogs(_ response: CombinedLogsResponse, forPage page: Int) {
    guard let userEmail = userEmail else { return }
    if let encoded = try? JSONEncoder().encode(response) {
        UserDefaults.standard.set(encoded, forKey: "combined_logs_\(userEmail)_page_\(page)")
    }
}

private func loadCachedLogs() -> Bool {
    guard let userEmail = userEmail else { return false }
    
    if let cached = UserDefaults.standard.data(forKey: "combined_logs_\(userEmail)_page_1"),
       let decodedResponse = try? JSONDecoder().decode(CombinedLogsResponse.self, from: cached) {
        
        withAnimation(.easeOut(duration: 0.3)) {
            self.combinedLogs = decodedResponse.logs
        }
        self.hasMore = decodedResponse.hasMore
        return true
    }
    
    return false
}
    

private func removeDuplicates(from logs: [LoggedFood]) -> [LoggedFood] {
    var seen = Set<Int>()
    var uniqueLogs: [LoggedFood] = []
    for log in logs {
        if !seen.contains(log.id) {
            uniqueLogs.append(log)
            seen.insert(log.id)
        }
    }
    return uniqueLogs
}

private func uniqueLogs(from logs: [LoggedFood]) -> [LoggedFood] {
    // First, sort the logs by their logged food id descending (assuming higher id is more recent)
    let sortedLogs = logs.sorted { $0.foodLogId > $1.foodLogId }
    var seen = Set<Int>()
    var unique: [LoggedFood] = []
    for log in sortedLogs {
        let foodId = log.food.fdcId
        if !seen.contains(foodId) {
            unique.append(log)
            seen.insert(foodId)
        }
    }
    return unique
}

func loadMoreFoods(refresh: Bool = false) {
    guard let email = userEmail else { return }
    guard !isLoading else { return }
    
    let pageToLoad = refresh ? 1 : currentPage
    isLoading = true
    error = nil

    networkManager.getFoodLogs(userEmail: email, page: pageToLoad) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .success(let response):
                if refresh {
                    // Filter the backend response to only the unique (most recent) logs
                    let uniqueResponseLogs = self.uniqueLogs(from: response.foodLogs)
                    self.loggedFoods = uniqueResponseLogs
                    self.currentPage = 2
                } else {
                    let newUniqueLogs = self.uniqueLogs(from: response.foodLogs)
                    self.loggedFoods.append(contentsOf: newUniqueLogs)
                    self.loggedFoods = self.uniqueLogs(from: self.loggedFoods)
                    self.currentPage += 1
                }
                self.hasMore = response.hasMore
                self.cacheFoods(response, forPage: pageToLoad)
            case .failure(let error):
                self.error = error
                self.hasMore = false
            }
        }
    }
}

private func loadMoreLogs(refresh: Bool = false) {
    guard let email = userEmail else {
        print("❌ FoodManager.loadMoreLogs() - No user email available")
        return
    }
    guard !isLoading else {
        print("⏸️ FoodManager.loadMoreLogs() - Already loading, skipping request")
        return
    }
    
    let pageToLoad = refresh ? 1 : currentPage
    print("📥 FoodManager.loadMoreLogs() - Loading page \(pageToLoad) for user \(email)")
    isLoading = true
    error = nil

    networkManager.getCombinedLogs(userEmail: email, page: pageToLoad) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            self.isLoading = false
         
            switch result {
            case .success(let response):
                print("📊 FoodManager: Successfully received combined logs with \(response.logs.count) logs")
                if refresh {
                    // When refreshing, replace all logs with the new ones
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.combinedLogs = response.logs
                    }
                    self.currentPage = 2
                } else {
                    // For pagination, append new logs at the end
                    let startCount = self.combinedLogs.count
                    let newLogs = response.logs.filter { newLog in
                        // Only add logs that don't exist yet (by ID)
                        !self.combinedLogs.contains { existingLog in
                            switch (existingLog.type, newLog.type) {
                            case (.food, .food):
                                return existingLog.foodLogId == newLog.foodLogId
                            case (.meal, .meal):
                                return existingLog.mealLogId == newLog.mealLogId
                            default:
                                return false
                            }
                        }
                    }
                    
                    if !newLogs.isEmpty {
                        withAnimation(.easeOut(duration: 0.3)) {
                            self.combinedLogs.append(contentsOf: newLogs)
                        }
                        print("📈 Added \(newLogs.count) new logs (from page \(pageToLoad))")
                    }
                    
                    self.currentPage += 1
                }
                
                self.hasMore = response.hasMore
                self.cacheLogs(response, forPage: pageToLoad)
                
            case .failure(let error):
                print("❌ FoodManager.loadMoreLogs() - Error: \(error)")
                self.error = error
                self.hasMore = false
            }
        }
    }
}

    
    // New refresh function that ensures logs are loaded
    func refresh() {
        print("🔄 FoodManager.refresh() called")
        
        // Don't interrupt any active logging operations
        guard !isLoading else {
            print("⏸️ FoodManager.refresh() - Skipping refresh - another operation is in progress")
            return
        }
        
        // Always fetch when explicitly asked
        print("🔄 FoodManager.refresh() - Fetching fresh logs from server")
        
        // Start from page 1
        currentPage = 1
        
        // Fetch logs without clearing existing ones first (they'll be replaced once we get response)
        loadMoreLogs(refresh: true)
        
        // Update refresh timestamp
        lastRefreshTime = Date()
    }
    

    func logFood(
    email: String,
    food: Food,
    meal: String,
    servings: Int,
    date: Date,
    notes: String? = nil,
    completion: @escaping (Result<LoggedFood, Error>) -> Void
) {
    print("⏳ Starting logFood operation...")
    isLoading = true
    
    // First, mark this as the last logged food ID to immediately update UI
    self.lastLoggedFoodId = food.fdcId
    
    // Check if this food already exists in our combinedLogs
    let existingIndex = self.combinedLogs.firstIndex(where: { 
        ($0.type == .food && $0.food?.fdcId == food.fdcId)
    })
    
    networkManager.logFood(
        userEmail: email,
        food: food,
        mealType: meal,
        servings: servings,
        date: date,
        notes: notes
    ) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let loggedFood):
                print("✅ Successfully logged food with foodLogId: \(loggedFood.foodLogId)")
                
                // If the food already exists in our list, just update and move it to the top
                if let index = existingIndex {
                    // Remove it from its current position
                    let updatedLog = self.combinedLogs.remove(at: index)
                    // Insert at the top
                    withAnimation(.spring()) {
                        self.combinedLogs.insert(updatedLog, at: 0)
                    }
                } else {
                    // Create a new CombinedLog from the logged food
                    let newCombinedLog = CombinedLog(
                        type: .food,
                        status: "success",
                        calories: Double(loggedFood.food.calories),
                        message: "\(loggedFood.food.displayName) - \(loggedFood.mealType)",
                        foodLogId: loggedFood.foodLogId,
                        food: loggedFood.food,
                        mealType: loggedFood.mealType,
                        mealLogId: nil,
                        meal: nil,
                        mealTime: nil
                    )
                    
                    // Insert at the top with animation
                    withAnimation(.spring()) {
                        self.combinedLogs.insert(newCombinedLog, at: 0)
                    }
                }
                
                // Show toast notification
                withAnimation {
                    self.showToast = true
                }
                
                // Clear the toast after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.showToast = false
                    }
                }
                
                // Clear the lastLoggedFoodId after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.lastLoggedFoodId = nil
                    }
                }
                
                // Update the cache with our new array
                self.updateCombinedLogsCache()
                
                completion(.success(loggedFood))
                
            case .failure(let error):
                print("❌ Failed to log food: \(error)")
                self.error = error
                
                // Clear the lastLoggedFoodId immediately on error
                self.lastLoggedFoodId = nil
                
                completion(.failure(error))
            }
        }
    }
}

// Helper method to update the cache with the current combinedLogs array
private func updateCombinedLogsCache() {
    guard let userEmail = userEmail else { return }
    
    // Create a response object with our current logs
    let response = CombinedLogsResponse(
        logs: Array(combinedLogs.prefix(pageSize)),
        hasMore: combinedLogs.count > pageSize,
        totalPages: (combinedLogs.count + pageSize - 1) / pageSize,
        currentPage: 1
    )
    
    // Cache the first page
    cacheLogs(response, forPage: 1)
}

    
    func loadMoreIfNeeded(food: LoggedFood) {
        guard let index = loggedFoods.firstIndex(where: { $0.id == food.id }),
              index == loggedFoods.count - 5,
              hasMore else {
            return
        }
        loadMoreFoods()
    }
    // Update the existing function to handle CombinedLog
func loadMoreIfNeeded(log: CombinedLog) {
    guard let index = combinedLogs.firstIndex(where: { $0.id == log.id }),
          index == combinedLogs.count - 5,
          hasMore else {
        return
    }
    loadMoreLogs()
}
func createMeal(
    title: String,
    description: String?,
    directions: String?,
    privacy: String,
    servings: Int,
    foods: [Food],
    image: String? = nil  // Added image parameter with default nil
) {
    guard let email = userEmail else { return }
    
    networkManager.createMeal(
        userEmail: email,
        title: title,
        description: description,
        directions: directions,
        privacy: privacy,
        servings: servings,
        foods: foods,
        image: image  // Pass the image parameter
    ) { [weak self] result in
        DispatchQueue.main.async {
            switch result {
            case .success(let meal):
                self?.meals.insert(meal, at: 0)

                self?.cacheMeals(MealsResponse(meals: self?.meals ?? [], hasMore: false, totalPages: 1, currentPage: 1), forPage: 1)
                // Show toast notification
                withAnimation {
                    self?.showMealToast = true
                }
                
                // Hide toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        self?.showMealToast = false
                    }
                }

                print("Meal created: \(meal)")
            case .failure(let error):
                print("Error creating meal: \(error)")
            }
        }
    }
}

private func clearMealCache() {
    guard let userEmail = userEmail else { return }
    
    // Clear all pages of meal cache
    for page in 1...10 { // Assuming we won't have more than 10 pages
        let cacheKey = "meals_\(userEmail)_page_\(page)"
        let hadCache = UserDefaults.standard.object(forKey: cacheKey) != nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}

private func resetAndFetchMeals() {
    currentMealPage = 1
    hasMoreMeals = true
    meals.removeAll()
    
    // Clear all meal caches
    clearMealCache()
    
    loadCachedMeals()
    // loadMoreMeals(refresh: true)
    loadMoreMeals(refresh: true) { [weak self] success in
        if success {
            self?.prefetchMealImages()
        }
    }
}

// Load cached meals
private func loadCachedMeals() {
    guard let userEmail = userEmail else { return }
    if let cached = UserDefaults.standard.data(forKey: "meals_\(userEmail)_page_1"),
       let decodedResponse = try? JSONDecoder().decode(MealsResponse.self, from: cached) {
        self.meals = decodedResponse.meals
        self.hasMoreMeals = decodedResponse.hasMore
    }
}

// Cache meals
private func cacheMeals(_ response: MealsResponse, forPage page: Int) {
    guard let userEmail = userEmail else { return }
    if let encoded = try? JSONEncoder().encode(response) {
        UserDefaults.standard.set(encoded, forKey: "meals_\(userEmail)_page_\(page)")
    }
}

// Load more meals
// func loadMoreMeals(refresh: Bool = false) {
//     guard let email = userEmail else { return }
//     guard !isLoadingMeals else { return }
    
//     let pageToLoad = refresh ? 1 : currentMealPage
//     isLoadingMeals = true
//     error = nil

//     networkManager.getMeals(userEmail: email, page: pageToLoad) { [weak self] result in
//         DispatchQueue.main.async {
//             guard let self = self else { return }
//             self.isLoadingMeals = false
//             switch result {
//             case .success(let response):
//                 if refresh {
//                     self.meals = response.meals
//                     self.currentMealPage = 2
//                 } else {
//                     self.meals.append(contentsOf: response.meals)
//                     self.currentMealPage += 1
//                 }
//                 // Add this debug print after updating self.meals
//                 self.hasMoreMeals = response.hasMore
//                 self.cacheMeals(response, forPage: pageToLoad)
//             case .failure(let error):
//                 self.error = error
//                 self.hasMoreMeals = false
//             }
//         }
//     }
// }
// Update loadMoreMeals to include a completion handler
func loadMoreMeals(refresh: Bool = false, completion: ((Bool) -> Void)? = nil) {
    guard let email = userEmail else { 
        completion?(false)
        return 
    }
    guard !isLoadingMeals else { 
        completion?(false)
        return 
    }
    
    let pageToLoad = refresh ? 1 : currentMealPage
    isLoadingMeals = true
    error = nil

    networkManager.getMeals(userEmail: email, page: pageToLoad) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { 
                completion?(false)
                return 
            }
            self.isLoadingMeals = false
            switch result {
            case .success(let response):
                if refresh {
                    self.meals = response.meals
                    self.currentMealPage = 2
                } else {
                    self.meals.append(contentsOf: response.meals)
                    self.currentMealPage += 1
                }
                self.hasMoreMeals = response.hasMore
                self.cacheMeals(response, forPage: pageToLoad)
                completion?(true)
            case .failure(let error):
                self.error = error
                self.hasMoreMeals = false
                completion?(false)
            }
        }
    }
}

// Load more meals if needed
func loadMoreMealsIfNeeded(meal: Meal) {
    guard let index = meals.firstIndex(where: { $0.id == meal.id }),
          index == meals.count - 5,
          hasMoreMeals else {
        return
    }
    loadMoreMeals()
}

// Refresh meals
// func refreshMeals() {
//     print("🔄 Starting meal refresh...")
//     clearMealCache()
//     loadMoreMeals(refresh: true)
// }

func refreshMeals() {
    print("🔄 Starting meal refresh...")
    
    // Clear the meal cache
    clearMealCache()
    
    // Reset state
    currentMealPage = 1
    hasMoreMeals = true
    
    // Force UI update before fetching new data
    objectWillChange.send()
    
    // Fetch fresh data
    loadMoreMeals(refresh: true)
    
    // Force another UI update after a short delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.objectWillChange.send()
    }
}

func logMeal(
    meal: Meal,
    mealTime: String,
    date: Date = Date(),
    notes: String? = nil,
    completion: ((Result<LoggedMeal, Error>) -> Void)? = nil
) {
    guard let email = userEmail else { return }
    
    // Show loading state
    isLoading = true
    
    // Immediately mark as recently logged for UI feedback
    self.lastLoggedMealId = meal.id
    
    // Check if this meal already exists in our combinedLogs
    let existingIndex = self.combinedLogs.firstIndex(where: { 
        ($0.type == .meal && $0.meal?.mealId == meal.id)
    })
    
    // Debug print
    print("🍽️ Logging meal with title: \(meal.title)")
    
    networkManager.logMeal(
        userEmail: email,
        mealId: meal.id,
        mealTime: mealTime,
        date: date,
        notes: notes
    ) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let loggedMeal):
                print("✅ Successfully logged meal with ID: \(loggedMeal.mealLogId)")
                
                // If the meal already exists in our list, just move it to the top
                if let index = existingIndex {
                    // Remove it from its current position
                    let updatedLog = self.combinedLogs.remove(at: index)
                    // Insert at the top
                    withAnimation(.spring()) {
                        self.combinedLogs.insert(updatedLog, at: 0)
                    }
                } else {
                    // Create a new CombinedLog from the logged meal
                    let newCombinedLog = CombinedLog(
                        type: .meal,
                        status: "success",
                        calories: loggedMeal.calories,
                        message: "\(loggedMeal.meal.title) - \(loggedMeal.mealTime)",
                        foodLogId: nil,
                        food: nil,
                        mealType: nil,
                        mealLogId: loggedMeal.mealLogId,
                        meal: loggedMeal.meal,
                        mealTime: loggedMeal.mealTime
                    )
                    
                    // Insert at the top with animation
                    withAnimation(.spring()) {
                        self.combinedLogs.insert(newCombinedLog, at: 0)
                    }
                }
                
                // Show toast notification
                withAnimation {
                    self.showMealLoggedToast = true
                }
                
                // Clear the flag and toast after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.lastLoggedMealId = nil
                        self.showMealLoggedToast = false
                    }
                }
                
                // Update the cache with our new array
                self.updateCombinedLogsCache()
                
                completion?(.success(loggedMeal))
                
            case .failure(let error):
                print("❌ Failed to log meal: \(error)")
                self.error = error
                
                // Clear the lastLoggedMealId immediately on error
                self.lastLoggedMealId = nil
                
                completion?(.failure(error))
            }
        }
    }
}

func prefetchMealImages() {
    for meal in meals {
        if let imageUrlString = meal.image, let imageUrl = URL(string: imageUrlString) {
            // Create a URLSession task to prefetch the image
            let task = URLSession.shared.dataTask(with: imageUrl) { _, _, _ in
                // Image is now cached by the system
            }
            task.resume()
        }
    }
}

// Simple helper to ensure no duplicate log IDs
private func uniqueCombinedLogs(from logs: [CombinedLog]) -> [CombinedLog] {
    var seenFoodLogIds = Set<Int>()
    var seenMealLogIds = Set<Int>()
    var uniqueLogs: [CombinedLog] = []
    
    for log in logs {
        var isUnique = false
        
        switch log.type {
        case .food:
            if let foodLogId = log.foodLogId, !seenFoodLogIds.contains(foodLogId) {
                seenFoodLogIds.insert(foodLogId)
                isUnique = true
            }
        case .meal:
            if let mealLogId = log.mealLogId, !seenMealLogIds.contains(mealLogId) {
                seenMealLogIds.insert(mealLogId)
                isUnique = true
            }
        }
        
        if isUnique {
            uniqueLogs.append(log)
        }
    }
    
    return uniqueLogs
}


}
