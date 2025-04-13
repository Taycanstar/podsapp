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
    @Published var showRecipeLoggedToast = false
    @Published var recentlyAddedFoodIds: Set<Int> = []

    @Published var lastLoggedMealId: Int? = nil
    @Published var lastLoggedRecipeId: Int? = nil
    
    // Add properties for user-created foods
    @Published var userFoods: [Food] = []
    @Published var isLoadingUserFoods = false
    private var hasMoreUserFoods = true
    private var currentUserFoodsPage = 1
    
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
    
    // Recipe-related properties
    @Published var recipes: [Recipe] = []
    @Published var isLoadingRecipePage = false
    private var currentRecipePage = 1
    private var hasMoreRecipes = true
    private var totalRecipesPages = 1
    private var currentRecipesPage = 1
    
    // Add this property to the FoodManager class
    @Published var isAnalyzingFood = false
    @Published var analysisStage = 0
    @Published var showAIGenerationSuccess = false
    @Published var aiGeneratedFood: LoggedFoodItem?
    @Published var showLogSuccess = false
    @Published var lastLoggedItem: (name: String, calories: Double)?
    
    // Add these properties for meal generation with AI
    @Published var isGeneratingMeal = false
    @Published var mealGenerationStage = 0
    @Published var lastGeneratedMeal: Meal? = nil
    
    // Add this property for meal generation success
    @Published var showMealGenerationSuccess = false
    
    // Add state for food generation
    @Published var isGeneratingFood = false
    @Published var foodGenerationStage = 0
    @Published var showFoodGenerationSuccess = false
    @Published var lastGeneratedFood: Food? = nil
    
    // Add these properties for food image analysis
    @Published var loadingMessage: String = ""
    
    // Food Scanning
    @Published var isScanningFood = false
    @Published var scanningFoodError: String? = nil
    
    init() {
        self.networkManager = NetworkManager()
        
    }

    
    
    func initialize(userEmail: String) {
        print("🏁 FoodManager: Initializing with email \(userEmail)")
        self.userEmail = userEmail
        
        print("📋 FoodManager: Starting initialization sequence")
        resetAndFetchFoods()
        resetAndFetchMeals()
        resetAndFetchRecipes()
        resetAndFetchLogs()
        resetAndFetchUserFoods()
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

 func loadMoreLogs(refresh: Bool = false) {
    guard let email = userEmail else {
        print("❌ FoodManager.loadMoreLogs() - No user email available")
        return
    }
    guard !isLoadingLogs else {
        print("⏸️ FoodManager.loadMoreLogs() - Already loading, skipping request")
        return
    }
    
    let pageToLoad = refresh ? 1 : currentPage
    print("📥 FoodManager.loadMoreLogs() - Loading page \(pageToLoad) for user \(email), currentPage: \(currentPage)")
    isLoadingLogs = true
    error = nil

    networkManager.getCombinedLogs(userEmail: email, page: pageToLoad) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            self.isLoadingLogs = false
         
            switch result {
            case .success(let response):
                print("✅ FoodManager.loadMoreLogs() - Received response for page \(pageToLoad): \(response.logs.count) logs, hasMore: \(response.hasMore), totalPages: \(response.totalPages)")
                
                if refresh {
                    // When refreshing, replace all logs with the new ones
                    print("🔄 FoodManager.loadMoreLogs() - Refresh mode: replacing \(self.combinedLogs.count) logs with \(response.logs.count) new logs")
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.combinedLogs = response.logs
                    }
                    self.currentPage = 2
                    print("⏭️ FoodManager.loadMoreLogs() - Set currentPage to 2 after refresh")
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
                    
                    print("🔍 FoodManager.loadMoreLogs() - Filtered \(response.logs.count) logs to \(newLogs.count) new unique logs")
                    
                    if !newLogs.isEmpty {
                        withAnimation(.easeOut(duration: 0.3)) {
                            self.combinedLogs.append(contentsOf: newLogs)
                        }
                        print("📈 FoodManager.loadMoreLogs() - Added \(newLogs.count) new logs, total now: \(self.combinedLogs.count)")
                    } else {
                        print("ℹ️ FoodManager.loadMoreLogs() - No new unique logs to add")
                    }
                    
                    print("⏭️ FoodManager.loadMoreLogs() - Incrementing currentPage from \(self.currentPage) to \(self.currentPage + 1)")
                    self.currentPage += 1
                }
                
                print("🚩 FoodManager.loadMoreLogs() - Setting hasMore to \(response.hasMore)")
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
        if isLoadingLogs || isLoadingFood || isLoadingMeals || isLoadingMeal || isLoadingUserFoods {
            print("⏸️ FoodManager.refresh() - Skipping refresh - another operation is in progress")
            return
        }
        
        // Reset the pagination state
        currentPage = 1
        hasMore = true
        
        // Reset user foods pagination
        currentUserFoodsPage = 1
        hasMoreUserFoods = true
        
        // Clear the logs cache to ensure we get fresh data
        print("🧹 FoodManager.refresh() - Clearing logs cache")
        clearLogsCache()
        clearUserFoodsCache()
        
        // Force UI update before fetching new data
        objectWillChange.send()
        
        print("🔄 FoodManager.refresh() - Fetching fresh logs from server")
        // Fetch logs with refresh flag to replace existing ones
        loadMoreLogs(refresh: true)
        
        // Fetch user-created foods
        loadUserFoods(refresh: true)
        
        // Force another UI update after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.objectWillChange.send()
        }
        
        // Update refresh timestamp
        lastRefreshTime = Date()
    }
    
    // MARK: - User Foods Methods
    
    private func clearUserFoodsCache() {
        guard let userEmail = userEmail else { return }
        
        // Clear all pages of user foods cache
        for page in 1...10 { // Assuming we won't have more than 10 pages
            let cacheKey = "user_foods_\(userEmail)_page_\(page)"
            UserDefaults.standard.removeObject(forKey: cacheKey)
        }
    }
    
    // Helper method to clear all logs cache
    private func clearLogsCache() {
        guard let userEmail = userEmail else { return }
        
        // Clear all pages of logs cache
        for page in 1...10 { // Assuming we won't have more than 10 pages
            let cacheKey = "combined_logs_\(userEmail)_page_\(page)"
            UserDefaults.standard.removeObject(forKey: cacheKey)
        }
    }
    
    // Load cached user foods
    private func loadCachedUserFoods() {
        guard let userEmail = userEmail else { return }
        if let cached = UserDefaults.standard.data(forKey: "user_foods_\(userEmail)_page_1") {
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let decodedResponse = try decoder.decode(FoodResponse.self, from: cached)
                self.userFoods = decodedResponse.foods
                self.hasMoreUserFoods = decodedResponse.hasMore
            } catch {
                print("Error decoding cached user foods: \(error)")
            }
        }
    }
    
    // Cache user foods
    private func cacheUserFoods(_ response: FoodResponse, forPage page: Int) {
        guard let userEmail = userEmail else { return }
        if let encoded = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encoded, forKey: "user_foods_\(userEmail)_page_\(page)")
        }
    }
    
    // Load user foods with pagination
    func loadUserFoods(refresh: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard let email = userEmail else {
            completion?(false)
            return
        }
        
        guard !isLoadingUserFoods else {
            completion?(false)
            return
        }
        
        let pageToLoad = refresh ? 1 : currentUserFoodsPage
        isLoadingUserFoods = true
        
        networkManager.getUserFoods(userEmail: email, page: pageToLoad) { [weak self] result in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion?(false)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.isLoadingUserFoods = false
                
                switch result {
                case .success(let response):
                    if refresh {
                        withAnimation {
                            self.userFoods = response.foods
                        }
                        self.currentUserFoodsPage = 2
                    } else {
                        // Append new foods to existing list
                        withAnimation {
                            self.userFoods.append(contentsOf: response.foods)
                        }
                        self.currentUserFoodsPage += 1
                    }
                    
                    self.hasMoreUserFoods = response.hasMore
                    self.cacheUserFoods(response, forPage: pageToLoad)
                    completion?(true)
                    
                case .failure(let error):
                    print("❌ Failed to load user foods: \(error)")
                    completion?(false)
                }
            }
        }
    }
    
    // Method to reset user foods and fetch fresh
    func resetAndFetchUserFoods() {
        print("🍎 FoodManager: Reset and fetch user foods called")
        currentUserFoodsPage = 1
        hasMoreUserFoods = true
        
        // Store existing foods to allow smooth transitions
        let oldFoods = userFoods
        
        // Clear foods with animation if we had previous foods
        if !oldFoods.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) {
                userFoods = []
            }
        } else {
            userFoods = []
        }
        
        // Try loading from cache first
        loadCachedUserFoods()
        
        // Then fetch from server with animation
        loadUserFoods(refresh: true)
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
                        scheduledAt: nil,
                        recipeLogId: nil,
                        recipe: nil,
                        servingsConsumed: nil
                    )
                    
                    // Insert at the top with animation
                    withAnimation(.spring()) {
                        self.combinedLogs.insert(newCombinedLog, at: 0)
                    }
                }
                
                // Set data for success toast in dashboard
                self.lastLoggedItem = (name: food.displayName, calories: Double(loggedFood.food.calories))
                self.showLogSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showLogSuccess = false
                }
                
                // Show the local toast if the food was added manually (not AI generated)
                if !self.isAnalyzingFood {
                    self.showToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showToast = false
                    }
                }
                
                // Clear the lastLoggedFoodId after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        // Only clear if it still matches the food we logged
                        if self.lastLoggedFoodId == food.fdcId {
                            self.lastLoggedFoodId = nil
                        }
                    }
                }
                
                // Update the cache with our new array
                self.updateCombinedLogsCache()
                
                completion(.success(loggedFood))
                
            case .failure(let error):
                print("❌ Failed to log food: \(error)")
                self.error = error
                
                // Clear the lastLoggedFoodId immediately on error
                withAnimation {
                    // Only clear if it still matches the food we tried to log
                    if self.lastLoggedFoodId == food.fdcId {
                        self.lastLoggedFoodId = nil
                    }
                }
                
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
    // Try to find the log's index
    let index = combinedLogs.firstIndex(where: { $0.id == log.id })
    
    // Debug output to track why loadMoreIfNeeded might not be triggering
    if let idx = index {
        // The problem with just checking if index is >= count - 10 is that
        // we might trigger loading on logs in the middle of the list if logs
        // are added/removed. We should check both:
        // 1. If this is a high-numbered index (near the end)
        // 2. If there are few logs after this one
        let isNearEndByNumber = idx >= combinedLogs.count - 10
        let isNearEndByPosition = (combinedLogs.count - idx) <= 10
        let shouldLoadMore = isNearEndByNumber || isNearEndByPosition
        
        print("🔍 FoodManager.loadMoreIfNeeded - Log at index \(idx) of \(combinedLogs.count)")
        print("  - Near end by number: \(isNearEndByNumber)")
        print("  - Near end by position: \(isNearEndByPosition)")
        print("  - Should load more: \(shouldLoadMore)")
        print("  - hasMore: \(hasMore)")
        
        // Check if we're near the end AND there are more logs to load
        if shouldLoadMore && hasMore && !isLoadingLogs {
            print("🎯 FoodManager.loadMoreIfNeeded - Triggering loadMoreLogs() at index \(idx)")
            loadMoreLogs()
        } else if !hasMore {
            print("⚠️ FoodManager.loadMoreIfNeeded - Not loading more because hasMore is false")
        } else if isLoadingLogs {
            print("⏳ FoodManager.loadMoreIfNeeded - Not loading more because already loading")
        } else {
            print("⏱️ FoodManager.loadMoreIfNeeded - Not near end yet (\(combinedLogs.count - idx) items remaining)")
        }
    } else {
        print("❓ FoodManager.loadMoreIfNeeded - Log not found in combinedLogs (id: \(log.id))")
    }
    
    // Add a fallback check - if we're at least 2/3 through the list,
    // check if we should load more regardless of exact index
    if combinedLogs.count >= 9 && hasMore && !isLoadingLogs {
        // As a safety measure, trigger loading more logs if we're getting near the end
        // even if the specific index check didn't pass
        print("🔄 FoodManager.loadMoreIfNeeded - Safety check: ensuring we have enough logs")
        loadMoreLogs()
    }
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
  
    
    for (index, meal) in response.meals.prefix(3).enumerated() {
        
        
        // Debug first few items
        for (itemIndex, item) in meal.mealItems.prefix(3).enumerated() {
       
        }
    }
    
    // Encode to JSON
    guard let userEmail = userEmail else { return }
    if let encoded = try? JSONEncoder().encode(response) {
        UserDefaults.standard.set(encoded, forKey: "meals_\(userEmail)_page_\(page)")
    }
}

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
               
                
                // Log details for each meal
                for (index, meal) in response.meals.prefix(5).enumerated() {
                  
                    
                    // Log the first couple of food items
                    for (itemIndex, item) in meal.mealItems.prefix(2).enumerated() {
                    
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

func refreshMeals() {
    
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

// Log a meal (from meal history)
func logMeal(
    meal: Meal,
    mealTime: String,
    date: Date = Date(),
    notes: String? = nil,
    calories: Double,
    completion: ((Result<LoggedMeal, Error>) -> Void)? = nil,
    statusCompletion: ((Bool) -> Void)? = nil
) {
    guard let email = userEmail else { 
        statusCompletion?(false)
        return 
    }
    
    // Show loading state
    isLoadingMeal = true
    
    // Immediately mark as recently logged for UI feedback
    self.lastLoggedMealId = meal.id
    
    // Check if this meal already exists in our combinedLogs
    let existingIndex = self.combinedLogs.firstIndex(where: { 
        ($0.type == .meal && $0.meal?.mealId == meal.id)
    })

    
    networkManager.logMeal(
        userEmail: email,
        mealId: meal.id,
        mealTime: mealTime,
        date: date,
        notes: notes,
        calories: calories
    ) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { 
                statusCompletion?(false)
                return 
            }
            self.isLoadingMeal = false
            
            switch result {
            case .success(let loggedMeal):
                print("✅ Successfully logged meal with ID: \(loggedMeal.mealLogId)")
                
                // If the meal already exists in our list, just move it to the top
                if let index = existingIndex {
                    // Remove it from its current position
                    var updatedLog = self.combinedLogs.remove(at: index)
                    
                    // Update log with new values from the response
                    updatedLog.calories = loggedMeal.calories
                    updatedLog.meal = loggedMeal.meal
                    updatedLog.mealTime = loggedMeal.mealTime
                    
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
                        scheduledAt: loggedMeal.scheduledAt,
                        recipeLogId: nil,
                        recipe: nil,
                        servingsConsumed: nil
                    )
                    
                    // Insert at the top with animation
                    withAnimation(.spring()) {
                        self.combinedLogs.insert(newCombinedLog, at: 0)
                    }
                }
                
                // Set data for success toast in dashboard
                self.lastLoggedItem = (name: meal.title, calories: calories)
                self.showLogSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showLogSuccess = false
                }
                
                // Show the local toast
                self.showToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showToast = false
                }
                
                // Clear the flag and toast after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        // Only clear if it still matches the meal we logged
                        if self.lastLoggedMealId == meal.id {
                            self.lastLoggedMealId = nil
                        }
                        self.showMealLoggedToast = false
                    }
                }
                
                // Update the cache with our new array
                self.updateCombinedLogsCache()
                
                statusCompletion?(true)
                completion?(.success(loggedMeal))
                
            case .failure(let error):
                print("❌ Failed to log meal: \(error)")
                self.error = error
                
                // Clear the lastLoggedMealId immediately on error
                withAnimation {
                    // Only clear if it still matches the meal we tried to log
                    if self.lastLoggedMealId == meal.id {
                        self.lastLoggedMealId = nil
                    }
                }
                
                statusCompletion?(false)
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
    var seenRecipeLogIds = Set<Int>()
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
        case .recipe:
            if let recipeLogId = log.recipeLogId, !seenRecipeLogIds.contains(recipeLogId) {
                seenRecipeLogIds.insert(recipeLogId)
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
    foods: [Food] = [],
    completion: ((Result<Meal, Error>) -> Void)? = nil
) {
    guard let email = userEmail else { 
        completion?(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
        return 
    }
    
    print("🔄 updateMeal called with meal ID: \(meal.id), title: \(meal.title), foods count: \(foods.count)")
    
    // If foods array is not empty, use it to calculate macros
    // Otherwise use the meal's existing values
    let calculatedCalories: Double
    let calculatedProtein: Double
    let calculatedCarbs: Double
    let calculatedFat: Double
    
    if !foods.isEmpty {
        // Calculate totals from foods (matching createMeal logic)
        calculatedCalories = meal.totalCalories ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.calories ?? 0) * servings)
        }
        
        calculatedProtein = meal.totalProtein ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.protein ?? 0) * servings)
        }
        
        calculatedCarbs = meal.totalCarbs ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.carbs ?? 0) * servings)
        }
        
        calculatedFat = meal.totalFat ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.fat ?? 0) * servings)
        }
        
    
        networkManager.updateMealWithFoods(
            userEmail: email,
            mealId: meal.id,
            title: meal.title,
            description: meal.description ?? "",
            directions: meal.directions,
            privacy: meal.privacy,
            servings: meal.servings,
            foods: foods,
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
                    print("✅ Meal updated successfully: \(updatedMeal.title) (ID: \(updatedMeal.id))")
                    
                    // Update the meals array if this meal exists in it
                    if let index = self?.meals.firstIndex(where: { $0.id == meal.id }) {
                       
                        self?.meals[index] = updatedMeal
                        self?.cacheMeals(MealsResponse(meals: self?.meals ?? [], hasMore: false, totalPages: 1, currentPage: 1), forPage: 1)
                    } else {
                        print("ℹ️ Meal not found in meals array")
                    }
                    
                    // Update combined logs if this meal exists there
                    if let index = self?.combinedLogs.firstIndex(where: { 
                        $0.type == .meal && $0.meal?.mealId == meal.id 
                    }) {
                
                        if var log = self?.combinedLogs[index] {
                            // Create a new meal summary from the updated meal
                            do {
                                if let newLogWithUpdatedMeal = try self?.recreateLogWithUpdatedMeal(
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
                                    print("✅ Successfully updated meal in combined logs")
                                } else {
                                    print("⚠️ Failed to create updated log entry")
                                }
                            } catch {
                                print("❌ Error recreating log with updated meal: \(error)")
                            }
                        }
                    } else {
                        print("ℹ️ Meal not found in combined logs")
                    }
                    
                    completion?(.success(updatedMeal))
                    
                case .failure(let error):
                    print("❌ Error updating meal with foods: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }
    } else {
        // Use the original updateMeal if no food items are provided
        // Use provided totals or calculate from meal items
        calculatedCalories = meal.totalCalories ?? meal.mealItems.reduce(0) { sum, item in
            return sum + item.calories
        }
        
        calculatedProtein = meal.totalProtein ?? meal.mealItems.reduce(0) { sum, item in
            return sum + (item.protein)
        }
        
        calculatedCarbs = meal.totalCarbs ?? meal.mealItems.reduce(0) { sum, item in
            return sum + (item.carbs)
        }
        
        calculatedFat = meal.totalFat ?? meal.mealItems.reduce(0) { sum, item in
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
        scheduledAt: updatedMeal.scheduledAt,
        recipeLogId: originalLog.recipeLogId,
        recipe: originalLog.recipe,
        servingsConsumed: originalLog.servingsConsumed
    )
}

// After the resetAndFetchRecipes method
private func resetAndFetchRecipes() {
    print("🍛 FoodManager: Reset and fetch recipes called")
    currentRecipePage = 1
    hasMoreRecipes = true    
    // Store existing recipes to allow smooth transitions
    let oldRecipes = recipes
    
    // Clear recipes with animation if we had previous recipes
    if !oldRecipes.isEmpty {
        withAnimation(.easeOut(duration: 0.2)) {
            recipes = []
        }
    } else {
        recipes = []
    }
    
    // Try loading from cache first
    loadCachedRecipes()
    
    // Then fetch from server with animation
    loadMoreRecipes(refresh: true)
    
    // Update refresh timestamp
    lastRefreshTime = Date()
}

private func loadCachedRecipes() {
    guard let userEmail = userEmail else { return }
    
    if let cached = UserDefaults.standard.data(forKey: "recipes_\(userEmail)_page_1") {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Use custom date formatting strategy to handle both string dates and numeric timestamps
            decoder.dateDecodingStrategy = .custom { decoder -> Date in
                let container = try decoder.singleValueContainer()
                
                // Try to decode as a timestamp (number) first
                do {
                    let timestamp = try container.decode(Double.self)
                    return Date(timeIntervalSince1970: timestamp)
                } catch {
                    // If not a number, try as a string
                    let dateString = try container.decode(String.self)
                    
                    // If string is empty or null, return current date
                    if dateString.isEmpty {
                        print("⚠️ Empty date string found in cache, using current date")
                        return Date()
                    }
                    
                    // Try ISO8601 first with various options
                    let iso8601 = ISO8601DateFormatter()
                    if let date = iso8601.date(from: dateString) {
                        return date
                    }
                    
                    // Try with fractional seconds
                    iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = iso8601.date(from: dateString) {
                        return date
                    }
                    
                    // Try each of our custom formats
                    let formats = [
                        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",  // With 6 fractional digits, no timezone
                        "yyyy-MM-dd'T'HH:mm:ss.SSS",     // With 3 fractional digits, no timezone
                        "yyyy-MM-dd'T'HH:mm:ss",         // No fractional digits, no timezone
                        "yyyy-MM-dd"                     // Just date
                    ]
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    for format in formats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            return date
                        }
                    }
                    
                    // Last resort: just return current date
                    print("⚠️ Could not decode date string: \(dateString)")
                    return Date()
                }
            }
            
            let decodedResponse = try decoder.decode(RecipesResponse.self, from: cached)
            print("✅ Successfully loaded \(decodedResponse.recipes.count) cached recipes")
            
            self.recipes = decodedResponse.recipes
            self.hasMoreRecipes = decodedResponse.hasMore
            self.totalRecipesPages = decodedResponse.totalPages
            self.currentRecipesPage = decodedResponse.currentPage
            
        } catch {
            print("❌ Error decoding cached recipes: \(error)")
        }
    } else {
        print("ℹ️ No cached recipes found for user \(userEmail)")
    }
}

private func cacheRecipes(_ response: RecipesResponse, forPage page: Int) {
    guard let userEmail = userEmail else { return }
    if let encoded = try? JSONEncoder().encode(response) {
        UserDefaults.standard.set(encoded, forKey: "recipes_\(userEmail)_page_\(page)")
        }
    }

func loadMoreRecipes(refresh: Bool = false) {
    guard let email = userEmail else { return }
    guard !isLoadingRecipePage else { return }
    
    let pageToLoad = refresh ? 1 : currentRecipePage
    isLoadingRecipePage = true
    error = nil
    
    networkManager.getRecipes(userEmail: email, page: pageToLoad) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            self.isLoadingRecipePage = false
            
            switch result {
            case .success(let response):
                if refresh {
                    self.recipes = response.recipes
                    self.currentRecipePage = 2
                } else {
                    self.recipes.append(contentsOf: response.recipes)
                    self.currentRecipePage += 1
                }
                self.hasMoreRecipes = response.hasMore
                self.cacheRecipes(response, forPage: pageToLoad)
            case .failure(let error):
                self.error = error
                self.hasMoreRecipes = false
            }
        }
    }
}

// Add this function after createMeal
func createRecipe(
    title: String,
    description: String? = nil,
    instructions: String? = nil,
    privacy: String,
    servings: Int,
    foods: [Food],
    image: String? = nil,
    prepTime: Int? = nil,
    cookTime: Int? = nil,
    totalCalories: Double? = nil,
    totalProtein: Double? = nil,
    totalCarbs: Double? = nil,
    totalFat: Double? = nil,
    completion: ((Result<Recipe, Error>) -> Void)? = nil
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
    
    networkManager.createRecipe(
        userEmail: email,
        title: title,
        description: description,
        instructions: instructions,
        privacy: privacy,
        servings: servings,
        foods: foods,
        image: image,
        prepTime: prepTime,
        cookTime: cookTime,
        totalCalories: calculatedCalories,
        totalProtein: calculatedProtein,
        totalCarbs: calculatedCarbs,
        totalFat: calculatedFat
    ) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            
            switch result {
            case .success(let recipe):
                // Add the new recipe to our list
                withAnimation {
                    self.recipes.insert(recipe, at: 0)
                }
                
                // Invalidate cache for page 1
                UserDefaults.standard.removeObject(forKey: "recipes_\(email)_page_1")
                
                // Notify success
                completion?(.success(recipe))
                
            case .failure(let error):
                print("❌ Error creating recipe: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }
    }
}

// Add this function after logMeal
func logRecipe(
    recipe: Recipe,
    mealTime: String,
    date: Date,
    notes: String? = nil,
    calories: Double,
    completion: ((Result<LoggedRecipe, Error>) -> Void)? = nil,
    statusCompletion: ((Bool) -> Void)? = nil
) {
    guard let email = userEmail else { return }
    
    networkManager.logRecipe(
        userEmail: email,
        recipeId: recipe.id,
        mealTime: mealTime,
        date: date,
        notes: notes,
        calories: calories
    ) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            
            switch result {
            case .success(let recipeLog):
                // Create a new CombinedLog for the UI
                let newLog = CombinedLog(
                    type: .recipe,
                    status: recipeLog.status,
                    calories: recipeLog.recipe.calories,
                    message: "\(recipe.title) - \(mealTime)",
                    foodLogId: nil,
                    food: nil,
                    mealType: nil,
                    mealLogId: nil,
                    meal: nil,
                    mealTime: mealTime,
                    scheduledAt: date,
                    recipeLogId: recipeLog.recipeLogId,
                    recipe: recipeLog.recipe,
                    servingsConsumed: nil
                )
                
                // Add to combined logs
                withAnimation {
                    self.combinedLogs.insert(newLog, at: 0)
                }
                
                // Invalidate cache
                for page in 1...9 {
                    UserDefaults.standard.removeObject(forKey: "recipes_\(email)_page_\(page)")
                    UserDefaults.standard.removeObject(forKey: "combined_logs_\(email)_page_\(page)")
                }
                
                // Update last logged recipe ID for UI feedback
                self.lastLoggedRecipeId = recipe.id
                
                // Set data for success toast in dashboard
                self.lastLoggedItem = (name: recipe.title, calories: calories)
                self.showLogSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showLogSuccess = false
                }

                self.updateCombinedLogsCache()
                
                // Call completion handlers
                completion?(.success(recipeLog))
                statusCompletion?(true)
                
            case .failure(let error):
                print("❌ Error logging recipe: \(error.localizedDescription)")
                completion?(.failure(error))
                statusCompletion?(false)
            }
        }
    }
}

// Add this function after updateMeal
func updateRecipe(
    recipe: Recipe,
    foods: [Food] = [],
    completion: ((Result<Recipe, Error>) -> Void)? = nil
) {
    guard let email = userEmail else { 
        completion?(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
        return 
    }
    
    print("🔄 updateRecipe called with recipe ID: \(recipe.id), title: \(recipe.title), foods count: \(foods.count)")
    
    // If foods array is not empty, use it to calculate macros
    // Otherwise use the recipe's existing values
    let calculatedCalories: Double
    let calculatedProtein: Double
    let calculatedCarbs: Double
    let calculatedFat: Double
    
    if !foods.isEmpty {
        // Calculate totals from foods
        calculatedCalories = recipe.totalCalories ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.calories ?? 0) * servings)
        }
        
        calculatedProtein = recipe.totalProtein ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.protein ?? 0) * servings)
        }
        
        calculatedCarbs = recipe.totalCarbs ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.carbs ?? 0) * servings)
        }
        
        calculatedFat = recipe.totalFat ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.fat ?? 0) * servings)
        }
        
        // Use updateRecipeWithFoods if we're changing the ingredients
        networkManager.updateRecipeWithFoods(
            userEmail: email,
            recipeId: recipe.id,
            title: recipe.title,
            description: recipe.description ?? "",
            instructions: recipe.instructions ?? "",
            privacy: recipe.privacy,
            servings: recipe.servings,
            foods: foods,
            image: recipe.image,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            totalCalories: calculatedCalories,
            totalProtein: calculatedProtein,
            totalCarbs: calculatedCarbs,
            totalFat: calculatedFat
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let updatedRecipe):
                    // Update the recipe in our list
                    if let index = self.recipes.firstIndex(where: { $0.id == updatedRecipe.id }) {
                        self.recipes[index] = updatedRecipe
                    }
                    
                    // Invalidate cache for recipe pages
                    for page in 1...9 {
                        UserDefaults.standard.removeObject(forKey: "recipes_\(email)_page_\(page)")
                    }
                    
                    // Notify success
                    completion?(.success(updatedRecipe))
                    
                case .failure(let error):
                    print("❌ Error updating recipe with foods: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }
    } else {
        // Use the original updateRecipe if no food items are provided
        // Use provided totals or calculate from recipe items
        calculatedCalories = recipe.totalCalories ?? recipe.recipeItems.reduce(0) { sum, item in
            return sum + item.calories
        }
        
        calculatedProtein = recipe.totalProtein ?? recipe.recipeItems.reduce(0) { sum, item in
            return sum + (item.protein)
        }
        
        calculatedCarbs = recipe.totalCarbs ?? recipe.recipeItems.reduce(0) { sum, item in
            return sum + (item.carbs)
        }
        
        calculatedFat = recipe.totalFat ?? recipe.recipeItems.reduce(0) { sum, item in
            return sum + (item.fat)
        }
        
        networkManager.updateRecipe(
            userEmail: email,
            recipeId: recipe.id,
            title: recipe.title,
            description: recipe.description ?? "",
            instructions: recipe.instructions ?? "",
            privacy: recipe.privacy,
            servings: recipe.servings,
            image: recipe.image,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            totalCalories: calculatedCalories,
            totalProtein: calculatedProtein,
            totalCarbs: calculatedCarbs,
            totalFat: calculatedFat
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let updatedRecipe):
                    // Update the recipe in our list
                    if let index = self.recipes.firstIndex(where: { $0.id == updatedRecipe.id }) {
                        self.recipes[index] = updatedRecipe
                    }
                    
                    // Invalidate cache for recipe pages
                    for page in 1...9 {
                        UserDefaults.standard.removeObject(forKey: "recipes_\(email)_page_\(page)")
                    }
                    
                    // Notify success
                    completion?(.success(updatedRecipe))
                    
                case .failure(let error):
                    print("❌ Error updating recipe: \(error)")
                    completion?(.failure(error))
                }
            }
        }
    }
}

// Update the generateMacrosWithAI method
func generateMacrosWithAI(foodDescription: String, mealType: String, completion: @escaping (Result<LoggedFood, Error>) -> Void) {
    // Set analyzing flag
    isAnalyzingFood = true
    analysisStage = 0
    showAIGenerationSuccess = false
    
    // Create a timer to cycle through analysis stages for UI feedback
    let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
        guard let self = self else { 
            timer.invalidate()
            return 
        }
        
        // Cycle through stages 0-3
        self.analysisStage = (self.analysisStage + 1) % 4
    }
    
    networkManager.generateMacrosWithAI(foodDescription: foodDescription, mealType: mealType) { [weak self] result in
        guard let self = self else {
            timer.invalidate()
            return
        }
        
        // Stop the analysis animation timer
        timer.invalidate()
        
        switch result {
        case .success(let loggedFood):
            // Add to the beginning of the list
            let combinedLog = CombinedLog(
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
                scheduledAt: nil,
                recipeLogId: nil,
                recipe: nil,
                servingsConsumed: nil
            )
            
            if self.combinedLogs.isEmpty {
                self.combinedLogs = [combinedLog]
            } else {
                self.combinedLogs.insert(combinedLog, at: 0)
            }
            
            // Track the recently added food
            self.lastLoggedFoodId = loggedFood.food.fdcId
            self.trackRecentlyAdded(foodId: loggedFood.food.fdcId)
            
            // Save the generated food for the toast
            self.aiGeneratedFood = loggedFood.food
            
            // Reset analysis state and show success toast in dashboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isAnalyzingFood = false
                self.analysisStage = 0
                
                // Show success toast
                self.showAIGenerationSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showAIGenerationSuccess = false
                }
            }
            
            // Clear the lastLoggedFoodId after 2 seconds, similar to logFood()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    // Only clear if it still matches the food we logged
                    if self.lastLoggedFoodId == loggedFood.food.fdcId {
                        self.lastLoggedFoodId = nil
                    }
                }
            }
            
            // Call completion handler with success
            completion(.success(loggedFood))
            
        case .failure(let error):
            // Reset analysis state
            self.isAnalyzingFood = false
            self.analysisStage = 0
            
            // Handle error and pass it along
            completion(.failure(error))
        }
    }
}

func generateMealWithAI(mealDescription: String, mealType: String, completion: @escaping (Result<Meal, Error>) -> Void) {
    guard let email = userEmail else {
        completion(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
        return
    }
    
    // Set generating meal flag and reset stage
    isGeneratingMeal = true
    mealGenerationStage = 0
    
    // Create a timer to cycle through stages for UI feedback
    let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
        guard let self = self else { 
            timer.invalidate()
            return 
        }
        
        // Cycle through stages 0-3
        self.mealGenerationStage = (self.mealGenerationStage + 1) % 4
    }
    
    // Make the API request
    networkManager.generateMealWithAI(mealDescription: mealDescription, mealType: mealType) { [weak self] result in
        guard let self = self else {
            timer.invalidate()
            return
        }
        
        // Stop the stage cycling timer
        timer.invalidate()
        
        // Reset generating meal flag
        DispatchQueue.main.async {
            self.isGeneratingMeal = false
            
            switch result {
            case .success(let meal):
                // Store the generated meal
                self.lastGeneratedMeal = meal
                
                // Add the meal to the meals list
                if self.meals.isEmpty {
                    self.meals = [meal]
                } else {
                    self.meals.insert(meal, at: 0)
                }
                
                // Show success toast immediately
                self.showMealGenerationSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showMealGenerationSuccess = false
                }
                
                // Call the completion handler
                completion(.success(meal))
                
            case .failure(let error):
                // Just forward the error
                completion(.failure(error))
            }
        }
    }
}

func generateFoodWithAI(
    foodDescription: String,
    completion: @escaping (Result<Food, Error>) -> Void
) {
    // Set generating food flag and reset stage
    isGeneratingFood = true
    foodGenerationStage = 0
    showFoodGenerationSuccess = false
    
    // Create a timer to cycle through stages for UI feedback
    let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
        guard let self = self else { 
            timer.invalidate()
            return 
        }
        
        // Cycle through stages 0-3
        self.foodGenerationStage = (self.foodGenerationStage + 1) % 4
    }
    
    // Make the API request
    networkManager.generateFoodWithAI(foodDescription: foodDescription) { [weak self] result in
        guard let self = self else {
            timer.invalidate()
            return
        }
        
        // Stop the stage cycling timer
        timer.invalidate()
        
        // Reset generating food flag
        DispatchQueue.main.async {
            self.isGeneratingFood = false
            
            switch result {
            case .success(let food):
                // Store the generated food
                self.lastGeneratedFood = food
                
                // Show success toast
                self.showFoodGenerationSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showFoodGenerationSuccess = false
                }
                
                // Call the completion handler
                completion(.success(food))
                
            case .failure(let error):
                // Forward the error
                completion(.failure(error))
            }
        }
    }
}

// Add the createManualFood function after the generateFoodWithAI function
// This is around line 1879 after the last function in the file

func createManualFood(food: Food, completion: @escaping (Result<Food, Error>) -> Void) {
    // Set generating food flag
    isGeneratingFood = true
    showFoodGenerationSuccess = false
    
    guard let email = userEmail else {
        completion(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
        return
    }
    
    // Make the API request
    networkManager.createManualFood(userEmail: email, food: food) { [weak self] result in
        guard let self = self else {
            return
        }
        
        // Reset generating food flag
        DispatchQueue.main.async {
            self.isGeneratingFood = false
            
            switch result {
            case .success(let food):
                // Store the created food
                self.lastGeneratedFood = food
                
                // Show success toast
                self.showFoodGenerationSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showFoodGenerationSuccess = false
                }
                
                // Refresh food data
                self.refresh()
                
                // Call the completion handler
                completion(.success(food))
                
            case .failure(let error):
                // Forward the error
                completion(.failure(error))
            }
        }
    }
}

// Add these functions to the FoodManager class to handle deletion

    // Delete a food log
    func deleteFoodLog(id: Int, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        guard let email = userEmail else {
            print("⚠️ Cannot delete food log: User email not set")
            completion(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        
        // Log all food logs in combinedLogs for debugging
        print("📋 All food logs in combinedLogs:")
        for (index, log) in combinedLogs.enumerated() {
            if log.type == .food {
                print("  \(index): ID=\(log.id), foodLogId=\(log.foodLogId ?? -1), food.fdcId=\(log.food?.fdcId ?? -1)")
            }
        }
        
        // Find the log in combinedLogs
        if let index = combinedLogs.firstIndex(where: { $0.foodLogId == id }) {
            // Remove from local array first for immediate UI update
            let removedLog = combinedLogs.remove(at: index)
            print("✅ Found food log with ID \(id) in combinedLogs at index \(index)")
            
            // Call network manager to delete from server
            networkManager.deleteFoodLog(logId: id, userEmail: email) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success:
                    print("✅ Successfully deleted food log with ID: \(id)")
                    
                    // Nothing more to do as we've already removed it locally
                    completion(.success(()))
                    
                case .failure(let error):
                    print("❌ Failed to delete food log: \(error)")
                    
                    // Add the log back to the array since deletion failed
                    self.combinedLogs.insert(removedLog, at: index)
                    completion(.failure(error))
                }
            }
        } else {
            print("⚠️ Food log with ID \(id) not found in combinedLogs")
            
            // Check if this is potentially a log being mislabeled
            if let index = combinedLogs.firstIndex(where: { $0.id == id && $0.type == .food }) {
                print("🔍 Found potential food log with ID \(id) by general ID match")
                let log = combinedLogs[index]
                print("  - Log details: type=\(log.type), foodLogId=\(log.foodLogId ?? -1), food.fdcId=\(log.food?.fdcId ?? -1)")
                
                // Try to delete using the correct ID
                if let actualFoodLogId = log.foodLogId {
                    print("🔄 Retrying deletion with actual foodLogId: \(actualFoodLogId)")
                    deleteFoodLog(id: actualFoodLogId, completion: completion)
                    return
                }
            }
            
            completion(.failure(NSError(domain: "FoodManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Food log not found"])))
        }
    }
    
    // Delete a meal
    func deleteMeal(id: Int, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        guard let email = userEmail else {
            print("⚠️ Cannot delete meal: User email not set")
            completion(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        
        // Find the meal in the meals array
        if let index = meals.firstIndex(where: { $0.id == id }) {
            // Remove from local array first for immediate UI update
            let removedMeal = meals.remove(at: index)
            
            // Also remove any associated logs in combinedLogs
            let mealLogIndices = combinedLogs.indices.filter { combinedLogs[$0].meal?.id == id }
            let removedLogs = mealLogIndices.map { combinedLogs[$0] }
            
            for index in mealLogIndices.sorted(by: >) {
                combinedLogs.remove(at: index)
            }
            
            // Call network manager to delete from server
            networkManager.deleteMeal(mealId: id, userEmail: email) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success:
                    print("✅ Successfully deleted meal with ID: \(id)")
                    
                    // Nothing more to do as we've already removed it locally
                    completion(.success(()))
                    
                case .failure(let error):
                    print("❌ Failed to delete meal: \(error)")
                    
                    // Add the meal back to the array since deletion failed
                    self.meals.insert(removedMeal, at: index)
                    
                    // Add the logs back to combinedLogs
                    for log in removedLogs {
                        if let originalIndex = mealLogIndices.first {
                            self.combinedLogs.insert(log, at: min(originalIndex, self.combinedLogs.count))
                        } else {
                            self.combinedLogs.append(log)
                        }
                    }
                    
                    completion(.failure(error))
                }
            }
        } else {
            print("⚠️ Meal with ID \(id) not found in meals")
            completion(.failure(NSError(domain: "FoodManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Meal not found"])))
        }
    }
    
    // Delete a food
    func deleteFood(id: Int, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        guard let email = userEmail else {
            print("⚠️ Cannot delete food: User email not set")
            completion(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        
        // Find the food in userFoods
        if let index = userFoods.firstIndex(where: { $0.fdcId == id }) {
            // Remove from local array first for immediate UI update
            let removedFood = userFoods.remove(at: index)
            
            // Call network manager to delete from server
            networkManager.deleteFood(foodId: id, userEmail: email) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success:
                    print("✅ Successfully deleted food with ID: \(id)")
                    
                    // Nothing more to do as we've already removed it locally
                    completion(.success(()))
                    
                case .failure(let error):
                    print("❌ Failed to delete food: \(error)")
                    
                    // Add the food back to the array since deletion failed
                    self.userFoods.insert(removedFood, at: index)
                    completion(.failure(error))
                }
            }
        } else {
            print("⚠️ Food with ID \(id) not found in userFoods")
            completion(.failure(NSError(domain: "FoodManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Food not found"])))
        }
    }

    // Delete a meal log
    func deleteMealLog(id: Int, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        guard let email = userEmail else {
            print("⚠️ Cannot delete meal log: User email not set")
            completion(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        
        // Log all meal logs in combinedLogs for debugging
        print("📋 All meal logs in combinedLogs:")
        for (index, log) in combinedLogs.enumerated() {
            if log.type == .meal {
                print("  \(index): ID=\(log.id), mealLogId=\(log.mealLogId ?? -1), meal.id=\(log.meal?.id ?? -1)")
            }
        }
        
        // Find the log in combinedLogs
        if let index = combinedLogs.firstIndex(where: { $0.mealLogId == id }) {
            // Remove from local array first for immediate UI update
            let removedLog = combinedLogs.remove(at: index)
            print("✅ Found meal log with ID \(id) in combinedLogs at index \(index)")
            
            // Call network manager to delete from server
            networkManager.deleteMealLog(logId: id, userEmail: email) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success:
                    print("✅ Successfully deleted meal log with ID: \(id)")
                    
                    // Nothing more to do as we've already removed it locally
                    completion(.success(()))
                    
                case .failure(let error):
                    print("❌ Failed to delete meal log: \(error)")
                    
                    // Add the log back to the array since deletion failed
                    self.combinedLogs.insert(removedLog, at: index)
                    completion(.failure(error))
                }
            }
        } else {
            print("⚠️ Meal log with ID \(id) not found in combinedLogs")
            
            // Check if this is potentially a food log being mislabeled as a meal log
            if let index = combinedLogs.firstIndex(where: { $0.id == id && $0.type == .meal }) {
                print("🔍 Found potential meal log with ID \(id) by general ID match")
                let log = combinedLogs[index]
                print("  - Log details: type=\(log.type), mealLogId=\(log.mealLogId ?? -1), meal.id=\(log.meal?.id ?? -1)")
                
                // Try to delete using the correct ID
                if let actualMealLogId = log.mealLogId {
                    print("🔄 Retrying deletion with actual mealLogId: \(actualMealLogId)")
                    deleteMealLog(id: actualMealLogId, completion: completion)
                    return
                }
            }
            
            completion(.failure(NSError(domain: "FoodManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Meal log not found"])))
        }
    }

    // Function to analyze food image and log it
    func analyzeFoodImage(image: UIImage, userEmail: String, completion: @escaping (Bool, String?) -> Void) {
        // Update state to show loading in dashboard
        isScanningFood = true
        loadingMessage = "Analyzing food image..."
        analysisStage = 0
        isLoading = true
        
        // Call the API to analyze the image
        networkManager.analyzeFoodImage(
            image: image, 
            userEmail: userEmail
        ) { [weak self] success, data, errorMessage in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isScanningFood = false
                self.isLoading = false
                
                if success, let responseData = data {
                    // Food was successfully logged
                    if let food = responseData["food"] as? [String: Any],
                       let displayName = food["displayName"] as? String,
                       let calories = food["calories"] as? Double {
                        
                        // Use the correct tuple format: (name: String, calories: Double)
                        self.lastLoggedItem = (name: displayName, calories: calories)
                        self.showLogSuccess = true
                        
                        // Auto-hide the success message after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.showLogSuccess = false
                        }
                        
                        // Refresh logs to show the new food
                        self.refresh()
                        
                        completion(true, nil)
                    } else {
                        // Could not extract food details
                        self.scanningFoodError = "Failed to process food details"
                        completion(false, "Failed to process food details")
                    }
                } else {
                    // Show error in dashboard
                    print("Food scan error: \(errorMessage ?? "Unknown error")")
                    self.scanningFoodError = errorMessage ?? "Failed to analyze food image"
                    completion(false, errorMessage)
                }
            }
        }
    }
}
