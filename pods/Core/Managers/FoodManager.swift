import Foundation
import SwiftUI

class FoodManager: ObservableObject {
    @Published var loggedFoods: [LoggedFood] = []
    @Published var isLoading = false
    @Published var isLoadingLogs = false
    @Published var isLoadingFood = false
    @Published var isLoadingMeals = false
    @Published var isLoadingMeal = false
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
    @Published var isLoadingMealPage = false
    private var currentMealPage = 1
    private var hasMoreMeals = true
    @Published var combinedLogs: [CombinedLog] = []
    
    private var lastRefreshTime: Date?
    
    init() {
        self.networkManager = NetworkManager()
    }

    
    
    func initialize(userEmail: String) {
        print("🏁 FoodManager: Initializing with email \(userEmail)")
        self.userEmail = userEmail
        
        print("📋 FoodManager: Starting initialization sequence")
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
        print("🍔 FoodManager: Reset and fetch foods called")
        currentPage = 1
        hasMore = true
        
        // Store existing foods to allow smooth transitions
        let oldFoods = loggedFoods
        
        // Clear foods with animation if we had previous logs
        if !oldFoods.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) {
                loggedFoods = []
            }
        } else {
            loggedFoods = []
        }
        
        // Try loading from cache first
        loadCachedFoods()
        
        // Then fetch from server with animation
        loadMoreFoods(refresh: true)
        
        // Update refresh timestamp
        lastRefreshTime = Date()
    }

    private func resetAndFetchLogs() {
         
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
       let decodedResponse = try? {
           let decoder = JSONDecoder()
           decoder.keyDecodingStrategy = .convertFromSnakeCase
           decoder.dateDecodingStrategy = .iso8601
           return try decoder.decode(CombinedLogsResponse.self, from: cached)
       }() {
        
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
    guard !isLoadingFood else { return }
    
    let pageToLoad = refresh ? 1 : currentPage
    isLoadingFood = true
    error = nil

    networkManager.getFoodLogs(userEmail: email, page: pageToLoad) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            self.isLoadingFood = false
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
    guard !isLoadingLogs else {
        print("⏸️ FoodManager.loadMoreLogs() - Already loading, skipping request")
        return
    }
    
    let pageToLoad = refresh ? 1 : currentPage
    print("📥 FoodManager.loadMoreLogs() - Loading page \(pageToLoad) for user \(email)")
    isLoadingLogs = true
    error = nil

    networkManager.getCombinedLogs(userEmail: email, page: pageToLoad) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            self.isLoadingLogs = false
         
            switch result {
            case .success(let response):
                
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
        
        // Don't interrupt any active loading operations
        if isLoadingLogs || isLoadingFood || isLoadingMeals || isLoadingMeal {
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
    isLoadingFood = true
    
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
            self.isLoadingFood = false
            
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
                        mealTime: nil,
                        scheduledAt: nil
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
    image: String?,
    totalCalories: Double?,
    totalProtein: Double?,
    totalCarbs: Double?,
    totalFat: Double?
) {
    guard let email = userEmail else { return }
    
    // Use provided totals or calculate if not provided
    let calculatedCalories = totalCalories ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.calories ?? 0) * servings)
    }
    
    // Calculate macros if not provided
    let calculatedProtein = totalProtein ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.protein ?? 0) * servings)
    }
    
    let calculatedCarbs = totalCarbs ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.carbs ?? 0) * servings)
    }
    
    let calculatedFat = totalFat ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.fat ?? 0) * servings)
    }
    

    
    networkManager.createMeal(
        userEmail: email,
        title: title,
        description: description,
        directions: directions,
        privacy: privacy,
        servings: servings,
        foods: foods,
        image: image,
        totalCalories: calculatedCalories,
        totalProtein: calculatedProtein,
        totalCarbs: calculatedCarbs,
        totalFat: calculatedFat
    ) { [weak self] result in
        DispatchQueue.main.async {
            switch result {
            case .success(let meal):
                print("✅ Meal created successfully: \(meal.title)")
                print("📊 Returned meal calories: \(meal.calories)")
                print("📊 Meal has \(meal.mealItems.count) food items")
                
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
            case .failure(let error):
                print("❌ Error creating meal: \(error)")
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
    print("🍲 FoodManager: Reset and fetch meals called")
    currentMealPage = 1
    hasMoreMeals = true
    
    // Store existing meals to allow smooth transitions
    let oldMeals = meals
    
    // Clear meals with animation if we had previous meals
    if !oldMeals.isEmpty {
        withAnimation(.easeOut(duration: 0.2)) {
            meals = []
        }
    } else {
        meals = []
    }
    
    // Clear all meal caches
    clearMealCache()
    
    // Try loading from cache first
    loadCachedMeals()
    
    // Then fetch from server with animation
    loadMoreMeals(refresh: true) { [weak self] success in
        if success {
            print("✅ FoodManager: Successfully loaded meals from server")
            self?.prefetchMealImages()
        } else {
            print("❌ FoodManager: Failed to load meals from server")
        }
    }
    
    // Update refresh timestamp
    lastRefreshTime = Date()
}

// Load cached meals
private func loadCachedMeals() {
    guard let userEmail = userEmail else { return }
    if let cached = UserDefaults.standard.data(forKey: "meals_\(userEmail)_page_1"),
       let decodedResponse = try? {
           let decoder = JSONDecoder()
           decoder.keyDecodingStrategy = .convertFromSnakeCase
           decoder.dateDecodingStrategy = .iso8601
           return try decoder.decode(MealsResponse.self, from: cached)
       }() {
        self.meals = decodedResponse.meals
        self.hasMoreMeals = decodedResponse.hasMore
    }
}

// Cache meals
private func cacheMeals(_ response: MealsResponse, forPage page: Int) {
    print("💾 Caching \(response.meals.count) meals for page \(page)")
    
    for (index, meal) in response.meals.prefix(3).enumerated() {
        print("📝 Meal #\(index+1): \(meal.title) with \(meal.mealItems.count) items")
        
        // Debug first few items
        for (itemIndex, item) in meal.mealItems.prefix(3).enumerated() {
            print("   Item #\(itemIndex+1): \(item.name)")
            print("     - servings: \(item.servings)")
           
            print("     - calories: \(item.calories)")
        }
    }
    
    // Encode to JSON
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
                print("📥 Received \(response.meals.count) meals from server")
                
                // Log details for each meal
                for (index, meal) in response.meals.prefix(5).enumerated() {
                    print("📊 Meal #\(index+1): \(meal.title)")
                    print("  - Calories: \(meal.calories) (from totalCalories: \(String(describing: meal.totalCalories)))")
                    print("  - Protein: \(meal.protein)g, Carbs: \(meal.carbs)g, Fat: \(meal.fat)g")
                    print("  - Has \(meal.mealItems.count) food items")
                    
                    // Log the first couple of food items
                    for (itemIndex, item) in meal.mealItems.prefix(2).enumerated() {
                        print("    - Item #\(itemIndex+1): \(item.name)")
                        print("      * Calories: \(item.calories), Protein: \(item.protein)g, Carbs: \(item.carbs)g, Fat: \(item.fat)g")
                        print("      * Servings: \(item.servings)")
                        print("      * Serving text: \(item.servingText ?? "NIL")")
                    }
                }
                
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
    isLoadingMeal = true
    
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
            self.isLoadingMeal = false
            
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
                        calories: loggedMeal.calories > 0 ? loggedMeal.calories : meal.calories,
                        message: "\(loggedMeal.meal.title) - \(loggedMeal.mealTime)",
                        foodLogId: nil,
                        food: nil,
                        mealType: nil,
                        mealLogId: loggedMeal.mealLogId,
                        meal: loggedMeal.meal,
                        mealTime: loggedMeal.mealTime,
                        scheduledAt: loggedMeal.scheduledAt
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

func updateMeal(
    meal: Meal,
    completion: ((Result<Meal, Error>) -> Void)? = nil
) {
    guard let email = userEmail else { 
        completion?(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
        return 
    }
    
    // Use provided totals or calculate from meal items
    let calculatedCalories = meal.totalCalories ?? meal.mealItems.reduce(0) { sum, item in
        return sum + item.calories
    }
    
    let calculatedProtein = meal.totalProtein ?? meal.mealItems.reduce(0) { sum, item in
        return sum + (item.protein)
    }
    
    let calculatedCarbs = meal.totalCarbs ?? meal.mealItems.reduce(0) { sum, item in
        return sum + (item.carbs)
    }
    
    let calculatedFat = meal.totalFat ?? meal.mealItems.reduce(0) { sum, item in
        return sum + (item.fat)
    }
    
    networkManager.updateMeal(
        userEmail: email,
        mealId: meal.id,
        title: meal.title,
        description: meal.description ?? "",
        directions: meal.directions,
        privacy: meal.privacy,
        servings: meal.servings,
        image: meal.image,
        totalCalories: calculatedCalories,
        totalProtein: calculatedProtein,
        totalCarbs: calculatedCarbs,
        totalFat: calculatedFat,
        scheduledAt: meal.scheduledAt
    ) { [weak self] result in
        DispatchQueue.main.async {
            switch result {
            case .success(let updatedMeal):
                print("✅ Meal updated successfully: \(updatedMeal.title)")
                
                // Update the meals array if this meal exists in it
                if let index = self?.meals.firstIndex(where: { $0.id == meal.id }) {
                    self?.meals[index] = updatedMeal
                    self?.cacheMeals(MealsResponse(meals: self?.meals ?? [], hasMore: false, totalPages: 1, currentPage: 1), forPage: 1)
                }
                
                // Update combined logs if this meal exists there
                if let index = self?.combinedLogs.firstIndex(where: { 
                    $0.type == .meal && $0.meal?.mealId == meal.id 
                }), var log = self?.combinedLogs[index] {
                    // Create a new meal summary from the updated meal
                    // Note: This is a bit hacky since we can't directly modify the meal property
                    // A better approach would be to make CombinedLog struct mutable
                    if let newLogWithUpdatedMeal = try? self?.recreateLogWithUpdatedMeal(
                        originalLog: log, 
                        updatedMeal: MealSummary(
                            mealId: updatedMeal.id,
                            title: updatedMeal.title,
                            description: updatedMeal.description,
                            image: updatedMeal.image,
                            calories: updatedMeal.calories,
                            servings: updatedMeal.servings,
                            protein: updatedMeal.totalProtein,
                            carbs: updatedMeal.totalCarbs,
                            fat: updatedMeal.totalFat,
                            scheduledAt: updatedMeal.scheduledAt
                        )
                    ) {
                        self?.combinedLogs[index] = newLogWithUpdatedMeal
                    }
                }
                
                completion?(.success(updatedMeal))
                
            case .failure(let error):
                print("❌ Error updating meal: \(error)")
                completion?(.failure(error))
            }
        }
    }
}

// Helper method to recreate a CombinedLog with an updated meal
private func recreateLogWithUpdatedMeal(originalLog: CombinedLog, updatedMeal: MealSummary) throws -> CombinedLog {
    return CombinedLog(
        type: originalLog.type,
        status: originalLog.status,
        calories: updatedMeal.displayCalories,
        message: "\(updatedMeal.title) - \(originalLog.mealTime ?? "")",
        foodLogId: originalLog.foodLogId,
        food: originalLog.food,
        mealType: originalLog.mealType,
        mealLogId: originalLog.mealLogId,
        meal: updatedMeal,
        mealTime: originalLog.mealTime,
        scheduledAt: updatedMeal.scheduledAt
    )
}

}
