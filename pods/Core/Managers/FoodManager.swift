import Foundation
import SwiftUI
// Extension to convert Food to LoggedFoodItem
extension Food {
    var asLoggedFoodItem: LoggedFoodItem {
        return LoggedFoodItem(
            fdcId: self.fdcId,
            displayName: self.displayName,
            calories: self.calories ?? 0,
            servingSizeText: self.servingSizeText,
            numberOfServings: self.numberOfServings ?? 1,
            brandText: self.brandText,
            protein: self.protein,
            carbs: self.carbs,
            fat: self.fat
        )
    }
}


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
    @Published var scannedImage: UIImage? = nil
    @Published var uploadProgress: Double = 0.0
    
    // MARK: - Date-specific logs management
    
    /// Current selected date in dashboard view
    @Published var selectedDate = Date()
    
    /// Cache of logs by date
    private var logsCache: [String: [CombinedLog]] = [:]
    
    /// Flag to track which dates we've preloaded or are currently loading
    private var loadingDates: Set<String> = []
    
    /// Dates for which we've attempted to load but found no logs
    private var emptyDates: Set<String> = []
    
    // MARK: - Helper methods for consistent food log updates
    /// Helper method to ensure a new food log appears in today's logs immediately
    /// - Parameter log: The CombinedLog object to add to today's logs
    private func addLogToTodayAndUpdateDashboard(_ log: CombinedLog) {
        // Add to the beginning of the main logs list
        if self.combinedLogs.isEmpty {
            self.combinedLogs = [log]
        } else {
            self.combinedLogs.insert(log, at: 0)
        }
        
        // Update currentDateLogs if the user is viewing today
        if Calendar.current.isDateInToday(self.selectedDate) {
            // Format today's date for cache key
            let dateKey = self.dateKey(Date())
            
            // Add the log to today's logs in cache
            if self.logsCache[dateKey] == nil {
                self.logsCache[dateKey] = []
            }
            self.logsCache[dateKey]?.append(log)
            
            // Update the displayed logs
            self.currentDateLogs = self.logsCache[dateKey] ?? []
            
            // Remove from empty dates if it was there
            self.emptyDates.remove(dateKey)
            
            // NEW CODE: Immediately update nutrition totals locally
            // Update calories consumed and remaining
            self.caloriesConsumed += log.displayCalories
            self.remainingCalories = max(0, self.calorieGoal - self.caloriesConsumed)
            
            // Update macros if available
            if let food = log.food {
                self.proteinConsumed += food.protein ?? 0
                self.carbsConsumed += food.carbs ?? 0
                self.fatConsumed += food.fat ?? 0
            } else if let meal = log.meal {
                self.proteinConsumed += meal.protein ?? 0
                self.carbsConsumed += meal.carbs ?? 0
                self.fatConsumed += meal.fat ?? 0
            } else if let recipe = log.recipe {
                self.proteinConsumed += recipe.protein ?? 0
                self.carbsConsumed += recipe.carbs ?? 0
                self.fatConsumed += recipe.fat ?? 0
            }
            
            print("📊 Updated goals after logging: Calories=\(self.caloriesConsumed), Protein=\(self.proteinConsumed)g, Carbs=\(self.carbsConsumed)g, Fat=\(self.fatConsumed)g, Remaining=\(self.remainingCalories)")
        }
        
        // Persist logs to UserDefaults so they don't disappear after app restart
        guard let userEmail = userEmail else { return }
        
        // Create a new CombinedLogsResponse with our updated combinedLogs
        let response = CombinedLogsResponse(
            logs: self.combinedLogs,
            hasMore: self.hasMore,
            totalPages: 1,
            currentPage: 1
        )
        
        // Use the existing cacheLogs function to persist to UserDefaults
        cacheLogs(response, forPage: 1)
        print("✅ Updated logs cache in UserDefaults")
    }
    /// Format a date as a string for cache keys
    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    /// Format a date as a string for cache keys (alternative signature)
    private func dateKey(for date: Date) -> String {
        return dateKey(date)
    }
    
    /// Loading state for date-specific logs
    @Published var isLoadingDateLogs = false
    
    /// Error state for date-specific logs
    @Published var dateLogsError: Error? = nil
    
    /// Logs for the currently selected date
    @Published var currentDateLogs: [CombinedLog] = []
    
    /// Flag indicating if adjacent days are being preloaded
    @Published var isPreloadingAdjacent = false
    
    // Add the new property
    @Published var isLoggingFood = false
    
    // Add errorMessage property after other published properties, around line 85
    @Published var errorMessage: String? = nil
    
    // Add the new published properties for nutrition tracking
    @Published var caloriesConsumed: Double = 0
    @Published var proteinConsumed: Double = 0
    @Published var carbsConsumed: Double = 0
    @Published var fatConsumed: Double = 0
    @Published var calorieGoal: Double = 2000 // Default value, should be fetched from user settings
    @Published var remainingCalories: Double = 2000 // Default equals goal
    
    init() {
        self.networkManager = NetworkManager()
        fetchCalorieGoal()
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
        
        // If we're viewing today, clear today's cache to force a refresh
        if Calendar.current.isDateInToday(selectedDate) {
            let todayKey = dateKey(Date())
            logsCache.removeValue(forKey: todayKey)
            emptyDates.remove(todayKey)
            loadingDates.remove(todayKey)
            
            // Force reload of today's logs specifically
            fetchLogsByDate(date: Date(), preloadAdjacent: false)
        }
        
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
                
                // Create a new CombinedLog from the logged food
                let combinedLog = CombinedLog(
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
                    scheduledAt: Date(), // Set to current date to make it appear in today's logs
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil
                )
                
                // Add the log to today's logs using the helper method
                self.addLogToTodayAndUpdateDashboard(combinedLog)
                
                // Track the food in recently added - fdcId is non-optional
                self.lastLoggedFoodId = food.fdcId
                self.trackRecentlyAdded(foodId: food.fdcId)
                
                // Still refresh for completeness
                self.refresh()
                
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
    // Set analyzing flag AND isLoading flag to show card in DashboardView
    isAnalyzingFood = true
    isLoading = true  // THIS was missing - needed to show the loading card!
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
    
    // Call the network manager to generate macros
    networkManager.generateMacrosWithAI(foodDescription: foodDescription, mealType: mealType) { [weak self] result in
        guard let self = self else { 
            timer.invalidate()
            return 
        }
        
        // Stop the timer
        timer.invalidate()
        
        switch result {
        case .success(let loggedFood):
            print("✅ AI macros generated successfully: \(loggedFood.food.displayName)")
            self.aiGeneratedFood = loggedFood.food
            self.lastLoggedItem = (name: loggedFood.food.displayName, calories: loggedFood.food.calories ?? 0)
            
            // Create a CombinedLog object for the new food
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
                scheduledAt: Date(), // Set to current date to make it appear in today's logs
                recipeLogId: nil,
                recipe: nil,
                servingsConsumed: nil
            )
            
            // Add the log to today's logs using the helper method
            self.addLogToTodayAndUpdateDashboard(combinedLog)
            
            // Track the food in recently added - fdcId is non-optional
            self.lastLoggedFoodId = loggedFood.food.fdcId
            self.trackRecentlyAdded(foodId: loggedFood.food.fdcId)
            
            // NEW: Start background sync with server instead of immediate refresh
            self.backgroundSyncWithServer()
            
            // Reset analysis state and show success toast in dashboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isAnalyzingFood = false
                self.isLoading = false  // Clear the loading flag
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
            self.isLoading = false  // Clear the loading flag
            self.analysisStage = 0
            
            // Handle error and pass it along
            completion(.failure(error))
        }
    }
}

// 2. Add a new backgroundSyncWithServer method
/// Sync with server in the background without blocking UI
private func backgroundSyncWithServer() {
    // Create a background task
    DispatchQueue.global(qos: .utility).async { [weak self] in
        guard let self = self else { return }
        
        // Fetch latest data from server without blocking UI
        guard let email = self.userEmail else { return }
        
        // Only sync if we're looking at today
        guard Calendar.current.isDateInToday(self.selectedDate) else { return }
        
        // Wait a short delay to allow server to process the log we just sent
        Thread.sleep(forTimeInterval: 1.0)
        
        NetworkManagerTwo.shared.getLogsByDate(
            userEmail: email,
            date: self.selectedDate,
            includeAdjacent: false) { [weak self] result in
                
            guard let self = self else { return }
                
            switch result {
            case .success(let response):
                // If goals are present in the response, update calorieGoal and related properties
                if let goals = response.goals {
                    let serverCalories = response.logs.reduce(0) { $0 + $1.displayCalories }
                    
                    // Check if server values differ significantly from our calculated values
                    let difference = abs(serverCalories - self.caloriesConsumed)
                    if difference > 1.0 { // 1 calorie threshold for floating point precision
                        DispatchQueue.main.async {
                            // Silently update values if needed
                            self.recalculateNutrition(from: response.logs)
                            
                            // Update goal from backend if available
                            self.calorieGoal = goals.calories
                            self.remainingCalories = max(0, goals.calories - self.caloriesConsumed)
                            print("📊 Background sync updated nutrition values and goals")
                        }
                    }
                }
                
            case .failure:
                // Ignore error - we already have local data
                break
            }
        }
    }
}

// 3. Add helper method to recalculate nutrition from logs
private func recalculateNutrition(from logs: [CombinedLog]) {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    
    for log in logs {
        calories += log.displayCalories
        
        if let food = log.food {
            protein += food.protein ?? 0
            carbs += food.carbs ?? 0
            fat += food.fat ?? 0
        } else if let meal = log.meal {
            protein += meal.protein ?? 0
            carbs += meal.carbs ?? 0
            fat += meal.fat ?? 0
        } else if let recipe = log.recipe {
            protein += recipe.protein ?? 0
            carbs += recipe.carbs ?? 0
            fat += recipe.fat ?? 0
        }
    }
    
    // Update our local values
    self.caloriesConsumed = calories
    self.proteinConsumed = protein
    self.carbsConsumed = carbs
    self.fatConsumed = fat
    self.remainingCalories = max(0, self.calorieGoal - calories)
    
    print("📊 Background sync updated nutrition: Calories=\(calories), Protein=\(protein)g, Carbs=\(carbs)g, Fat=\(fat)g, Remaining=\(self.remainingCalories)")
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
        scannedImage = image
        uploadProgress = 0.0
        loadingMessage = "Analyzing Scan"
        analysisStage = 0
        isLoading = true
        
        // Start time to calculate elapsed time
        let startTime = Date()
        
        // Estimated typical response time (in seconds)
        // This is used to calibrate the progress curve
        let expectedDuration: TimeInterval = 8.0
        
        // Use a smooth continuous animation with frequent updates
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Calculate current progress as a function of elapsed time
            let elapsedTime = Date().timeIntervalSince(startTime)
            
            // Non-linear curve that approaches but never reaches 1.0 until complete
            // f(x) = 1 - e^(-k*x) where k controls the rate
            // This creates a realistic loading curve that starts fast and slows down
            let k = 3.0 / expectedDuration  // Tuning parameter
            let calculatedProgress = 1.0 - exp(-k * elapsedTime)
            
            // Cap at 95% until we get actual server response
            self.uploadProgress = min(0.95, calculatedProgress)
            
            // Update loading messages based on progress thresholds
            if calculatedProgress > 0.25 && self.analysisStage < 1 {
                self.analysisStage = 1
                self.loadingMessage = "Identifying Food Items"
            } else if calculatedProgress > 0.5 && self.analysisStage < 2 {
                self.analysisStage = 2
                self.loadingMessage = "Calculating Nutrition"
            } else if calculatedProgress > 0.75 && self.analysisStage < 3 {
                self.analysisStage = 3
                self.loadingMessage = "Finalizing Results"
            }
            
            // Safety stop if taking too long (3x expected duration)
            if elapsedTime > expectedDuration * 3 {
                timer.invalidate()
            }
        }
        
        // Call the API to analyze the image
        networkManager.analyzeFoodImage(
            image: image, 
            userEmail: userEmail
        ) { [weak self] success, data, errorMessage in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Calculate actual response time for data collection
                // This could be stored to adjust future expectedDuration values
                let actualDuration = Date().timeIntervalSince(startTime)
                print("📊 Food scan analysis took \(String(format: "%.2f", actualDuration)) seconds")
                
                // Stop the progress timer
                progressTimer.invalidate()
                
                // Reset loading state
                self.isScanningFood = false
                self.isLoading = false
                
                if success, let responseData = data, 
                   let food = responseData["food"] as? [String: Any],
                   let displayName = food["displayName"] as? String,
                   !displayName.isEmpty,
                   let calories = food["calories"] as? Double {
                    
                    // Only in case of successful food identification:
                    // 1. Set progress to 100%
                    self.uploadProgress = 1.0
                    
                    // 2. Set success data for toast
                    self.lastLoggedItem = (name: displayName, calories: calories)
                    self.showLogSuccess = true
                    
                    // 3. Auto-hide the success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showLogSuccess = false
                        self.scannedImage = nil
                    }
                    
                    // Create a CombinedLog for the scanned food
                    if let loggedFood = responseData["loggedFood"] as? [String: Any],
                       let status = loggedFood["status"] as? String,
                       let loggedCalories = loggedFood["calories"] as? Double,
                       let message = loggedFood["message"] as? String,
                       let foodLogId = loggedFood["foodLogId"] as? Int {
                        
                        // Create a Food object from the food data
                        if let foodData = try? JSONSerialization.data(withJSONObject: food),
                           let foodObj = try? JSONDecoder().decode(Food.self, from: foodData) {
                           
                            // Create a combined log and add it to today's logs
                            let combinedLog = CombinedLog(
                                type: .food,
                                status: status,
                                calories: loggedCalories,
                                message: message,
                                foodLogId: foodLogId,
                                food: foodObj.asLoggedFoodItem,
                                mealType: loggedFood["mealType"] as? String ?? "Lunch",
                                mealLogId: nil,
                                meal: nil,
                                mealTime: nil,
                                scheduledAt: Date(), // Set to current date to make it appear in today's logs
                                recipeLogId: nil,
                                recipe: nil,
                                servingsConsumed: nil
                            )
                            
                            // Add the log to today's logs using the helper method
                            self.addLogToTodayAndUpdateDashboard(combinedLog)
                            
                            // Track the food in recently added
                            self.lastLoggedFoodId = foodObj.fdcId
                            self.trackRecentlyAdded(foodId: foodObj.fdcId)
                        }
                    }
                    
                    // 4. Refresh logs to show the new food
                    self.refresh()
                    
                    completion(true, nil)
                } else {
                    // For any failure case (including "No food identified"):
                    // Clear the scanned image
                    self.scannedImage = nil
                    
                    // Set error message - do NOT set showLogSuccess
                    let errorMsg: String
                    if let error = errorMessage {
                        // Check if the error is about no food identified
                        if error.contains("No food identified") || error.contains("Could not determine nutritional information") {
                            errorMsg = "Food not indentified."
                        } else if error.starts(with: "Server error: HTTP") {
                            // Handle HTTP errors, especially 400 which might be "no food identified"
                            errorMsg = "Food not indentified."
                        } else {
                            // Other network or server error
                            errorMsg = error
                        }
                    } else {
                        // Fallback for when no error message is provided
                        errorMsg = "Failed to analyze food image"
                    }
                    
                    print("Food scan error: \(errorMsg)")
                    self.scanningFoodError = errorMsg
                    completion(false, errorMsg)
                }
            }
        }
    }
    // Add this function to handle the barcode scanning logic
    func lookupFoodByBarcode(barcode: String, image: UIImage? = nil, userEmail: String, completion: @escaping (Bool, String?) -> Void) {
        // Set scanning state for UI feedback
        isScanningFood = true
        loadingMessage = "Looking up barcode..."
        uploadProgress = 0.3
        
        // Convert image to base64 if available
        var imageBase64: String? = nil
        if let image = image {
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                imageBase64 = imageData.base64EncodedString()
            }
        }
        
        // Call NetworkManagerTwo to look up the barcode
        NetworkManagerTwo.shared.lookupFoodByBarcode(
            barcode: barcode,
            userEmail: userEmail,
            imageData: imageBase64,
            mealType: "Lunch"
        ) { [weak self] result in
            guard let self = self else { return }
            
            // Update progress for UI
            self.uploadProgress = 1.0
            
            switch result {
            case .success(let food):
                // Success - show success toast
                self.aiGeneratedFood = food.asLoggedFoodItem
                self.lastLoggedItem = (name: food.displayName, calories: food.calories ?? 0)
                self.showLogSuccess = true
                
                // Update scanner state
                self.isScanningFood = false
                self.scannedImage = nil
                
                // Auto-hide the success message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showLogSuccess = false
                }
                
                // Create a CombinedLog for the barcode-scanned food
                let combinedLog = CombinedLog(
                    type: .food,
                    status: "active",  // Default status for logged foods
                    calories: food.calories ?? 0,
                    message: "\(food.displayName) - Lunch",
                    foodLogId: Int.random(in: 10000...999999),  // Temporary ID until refresh fetches the real one
                    food: food.asLoggedFoodItem,
                    mealType: "Lunch",  // Default meal type used in the barcode API call
                    mealLogId: nil,
                    meal: nil,
                    mealTime: nil,
                    scheduledAt: Date(), // Set to current date to make it appear in today's logs
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil
                )
                
                // Add the log to today's logs using the helper method
                self.addLogToTodayAndUpdateDashboard(combinedLog)
                
                // Track the food in recently added
                self.lastLoggedFoodId = food.fdcId
                self.trackRecentlyAdded(foodId: food.fdcId)
                
                
                
                // Still refresh for completeness
                self.refresh()
                
                completion(true, nil)
            case .failure(let error):
                // Update scanner state on failure
                self.isScanningFood = false
                self.scannedImage = nil
                
                // Set error message for display
                let errorMsg: String
                if let networkError = error as? NetworkManagerTwo.NetworkError,
                   case .serverError(let message) = networkError {
                    // Use server error message
                    errorMsg = message
                } else {
                    // General error message
                    errorMsg = "Could not find food for barcode"
                }
                
                print("Barcode scan error: \(errorMsg)")
                self.scanningFoodError = errorMsg
                completion(false, errorMsg)
            }
        }
    }
    // MARK: - Voice Input Processing
    func processVoiceInput(audioData: Data) {
        // Set analyzing flag - same as when generating macros with AI
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
            self.loadingMessage = [
                "Transcribing your voice...",
                "Analyzing food description...",
                "Generating nutritional data...",
                "Finalizing your food log..."
            ][self.analysisStage]
        }
        
        // First step: Transcribe the audio using the backend
        transcribeAudio(audioData: audioData) { [weak self] result in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            switch result {
            case .success(let transcribedText):
                print("Voice transcription successful: \(transcribedText)")
                
                // Now use the transcribed text to generate macros, same as the text input flow
                self.generateMacrosWithAI(foodDescription: transcribedText, mealType: "Lunch") { macroResult in
                    // Stop the analysis animation timer
                    timer.invalidate()
                    
                    // Reset analysis flags
                    self.isAnalyzingFood = false
                    
                    switch macroResult {
                    case .success(let loggedFood):
                        print("AI macros generated successfully from voice input")
                        self.aiGeneratedFood = loggedFood.food
                        self.lastLoggedItem = (name: loggedFood.food.displayName, calories: loggedFood.food.calories ?? 0)
                        self.showAIGenerationSuccess = true
                        
                        // Automatically dismiss the success indicator after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.showAIGenerationSuccess = false
                        }
                        
                        // Refresh food data to include the new logged item
                        self.refresh()
                        
                    case .failure(let error):
                        print("Failed to generate AI macros: \(error.localizedDescription)")
                        self.error = error
                    }
                }
                
            case .failure(let error):
                // Stop the timer and reset flags if transcription fails
                timer.invalidate()
                self.isAnalyzingFood = false
                self.error = error
                print("Voice transcription failed: \(error.localizedDescription)")
            }
        }
    }
    // Helper method to transcribe audio using the NetworkManager
    private func transcribeAudio(audioData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        // Use the enhanced transcription endpoint for more accurate food logging
        NetworkManagerTwo.shared.transcribeAudioForFoodLogging(from: audioData) { result in
            completion(result)
        }
    }
    // Add a new method to process voice recordings directly in FoodManager
    // This ensures the processing continues even if the view disappears
    func processVoiceRecording(audioData: Data) {
        // Set EXACTLY the same flags as generateMacrosWithAI for proper UI display
        isAnalyzingFood = true  // This is the critical flag used by FoodAnalysisCard
        isLoading = true  // This is what makes the loading card visible in DashboardView
        analysisStage = 0
        showAIGenerationSuccess = false
        
        // Do NOT set isScanningFood - that's for image scanning only!
        // isScanningFood = true  <- REMOVE this, it's for a different card
        
        // Create a timer to cycle through analysis stages for UI feedback
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            // Cycle through stages 0-3
            self.analysisStage = (self.analysisStage + 1) % 4
        }
        
        // First step: Transcribe the audio
        NetworkManagerTwo.shared.transcribeAudioForFoodLogging(from: audioData) { [weak self] result in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            switch result {
            case .success(let text):
                print("✅ Voice transcription successful: \(text)")
                
                // Second step: Generate AI macros from the transcribed text
                self.generateMacrosWithAI(foodDescription: text, mealType: "Lunch") { result in
                    // Stop the analysis animation timer no matter what
                    timer.invalidate()
                    
                    switch result {
                    case .success(let loggedFood):
                        print("✅ Voice log successfully processed: \(loggedFood.food.displayName)")
                        
                        // Check if this is an "Unknown food" with no nutritional value
                        // This happens when the server couldn't identify a food from the transcription
                        if loggedFood.food.displayName.lowercased().contains("unknown food") || 
                           (loggedFood.food.calories == 0 && loggedFood.food.protein == 0 && 
                            loggedFood.food.carbs == 0 && loggedFood.food.fat == 0) {
                            
                            // Handle as error even though server returned success
                            self.isAnalyzingFood = false
                            self.isLoading = false
                            self.analysisStage = 0
                            
                            // Set error for user notification
                            self.scanningFoodError = "Food not identified. Please try again."
                            print("⚠️ Voice log returned Unknown food with no nutrition data")
                            return
                        }
                        
                        // Create a CombinedLog for the voice-recorded food
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
                            scheduledAt: Date(), // Set to current date to make it appear in today's logs
                            recipeLogId: nil,
                            recipe: nil,
                            servingsConsumed: nil
                        )
                        
                        // Add the log to today's logs using the helper method
                        self.addLogToTodayAndUpdateDashboard(combinedLog)
                        
                        // Track the food in recently added
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
                        
                    case .failure(let error):
                        // Reset analysis state
                        self.isScanningFood = false
                        self.isAnalyzingFood = false
                        self.isLoading = false
                        self.analysisStage = 0
                        
                        // Set error message for user notification in DashboardView
                        if let networkError = error as? NetworkError, case .serverError(let message) = networkError {
                            self.scanningFoodError = message
                        } else {
                            self.scanningFoodError = "Failed to process voice input: \(error.localizedDescription)"
                        }
                        
                        print("❌ Failed to generate macros from voice input: \(error.localizedDescription)")
                    }
                }
                
            case .failure(let error):
                // Stop the timer and reset loading state
                timer.invalidate()
                self.isAnalyzingFood = false
                self.isLoading = false
                self.analysisStage = 0
                
                // Set error message for user notification in DashboardView
                if let networkError = error as? NetworkError, case .serverError(let message) = networkError {
                    self.scanningFoodError = message
                } else {
                    self.scanningFoodError = "Failed to transcribe voice input: \(error.localizedDescription)"
                }
                
                print("❌ Voice transcription failed: \(error.localizedDescription)")
            }
        }
    }
    // MARK: - Date-specific logs management
    
    /// Fetch logs for a specific date, with option to preload adjacent days
    /// - Parameters:
    ///   - date: Target date to fetch logs for
    ///   - preloadAdjacent: Whether to preload logs for adjacent days
    func fetchLogsByDate(date: Date, preloadAdjacent: Bool = true) {
        guard let email = userEmail else { return }
        
        // Update the selected date right away for UI
        selectedDate = date
        
        // Remove fetchCalorieGoal() here, as we'll use backend goals if present
        // fetchCalorieGoal()
        
        // Get date string for cache key
        let dateString = dateKey(date)
        
        // Check if we already have this date in cache
        if let cachedLogs = logsCache[dateString] {
            // If we have logs in cache, use them immediately
            currentDateLogs = cachedLogs
            print("📅 Using cached logs for \(dateString): \(cachedLogs.count) logs")
            
            // Still preload adjacent days in the background if requested
            if preloadAdjacent {
                preloadAdjacentDays(silently: true)
            }
            
            // Calculate nutrition totals after logs are loaded
            self.calculateDailyNutrition()
            
            return
        }
        
        // Check if this is a known empty date
        if emptyDates.contains(dateString) {
            currentDateLogs = []
            print("📅 Known empty date: \(dateString), showing empty state")
            
            // Still preload adjacent days in the background if requested
            if preloadAdjacent {
                preloadAdjacentDays(silently: true)
            }
            
            // Reset nutrition values when no logs exist
            self.caloriesConsumed = 0
            self.proteinConsumed = 0 
            self.carbsConsumed = 0
            self.fatConsumed = 0
            self.remainingCalories = self.calorieGoal
            
            return
        }
        
        // If we're already loading this date, don't start another request
        if loadingDates.contains(dateString) {
            print("📅 Already loading logs for \(dateString), waiting for completion")
            return
        }
        
        // Track that we're loading this date
        loadingDates.insert(dateString)
        
        // Only show the loading indicator if this isn't an adjacent date
        // or we don't already have the adjacent day preloaded
        let showLoading = !isAdjacentToSelectedDate(date) || logsCache[dateString] == nil
        
        if showLoading {
            isLoadingDateLogs = true
            dateLogsError = nil
        }
        
        // Load from server
        NetworkManagerTwo.shared.getLogsByDate(
            userEmail: email,
            date: date,
            includeAdjacent: preloadAdjacent,
            daysBefore: 1,
            daysAfter: 1
        ) { [weak self] result in
            guard let self = self else { return }
            
            // Mark this date as no longer loading
            self.loadingDates.remove(dateString)
            
            DispatchQueue.main.async {
                // Always hide the loader when we get a response
                self.isLoadingDateLogs = false
                
                switch result {
                case .success(let response):
                    // If goals are present in the response, update calorieGoal and related properties
                    if let goals = response.goals {
                        self.calorieGoal = goals.calories
                        self.remainingCalories = max(0, goals.calories - self.caloriesConsumed)
                        // Optionally update other macro goals if you have UI for them
                        print("📊 Loaded calorie goal from backend: \(goals.calories)")
                    } else {
                        // Fallback to local fetch if backend goals are missing
                        self.fetchCalorieGoal()
                    }
                    // Process logs for all dates
                    let logs = response.logs
                    
                    // Group logs by date
                    let logsByDate = Dictionary(grouping: logs) { log in
                        if let scheduledAt = log.scheduledAt {
                            let localDate = Calendar.current.startOfDay(for: scheduledAt)
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            formatter.timeZone = .current
                            return formatter.string(from: localDate)
                        }
                        // Fallback to logDate if scheduledAt is missing
                        if let logDate = log.logDate, logDate.count >= 10 {
                            return String(logDate.prefix(10))
                        }
                        return ""
                    }
                    
                    // Update cache with all logs by their date
                    for (logDate, dateLogs) in logsByDate {
                        if !logDate.isEmpty {
                            self.logsCache[logDate] = dateLogs
                            
                            // If a date has no logs, add it to emptyDates
                            if dateLogs.isEmpty {
                                self.emptyDates.insert(logDate)
                            } else {
                                self.emptyDates.remove(logDate)
                            }
                        }
                    }
                    
                    // Update current date logs
                    if let targetLogs = self.logsCache[dateString] {
                        self.currentDateLogs = targetLogs
                        print("📅 Loaded \(targetLogs.count) logs for \(dateString)")
                        
                        // Calculate nutrition totals after logs are loaded
                        self.calculateDailyNutrition()
                    } else {
                        self.currentDateLogs = []
                        self.emptyDates.insert(dateString)
                        print("📅 No logs found for \(dateString)")
                        
                        // Reset nutrition values when no logs exist
                        self.caloriesConsumed = 0
                        self.proteinConsumed = 0 
                        self.carbsConsumed = 0
                        self.fatConsumed = 0
                        self.remainingCalories = self.calorieGoal
                    }
                    
                case .failure(let error):
                    self.dateLogsError = error
                    self.currentDateLogs = []
                    print("❌ Error loading logs for \(dateString): \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Navigate to the previous day
    func goToPreviousDay() {
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let previousDayString = dateKey(previousDay)
        
        // Check if we have the previous day in cache or it's a known empty date
        let isCached = logsCache[previousDayString] != nil || emptyDates.contains(previousDayString)
        
        // Fetch logs with or without loading indicator based on cache status
        fetchLogsByDate(date: previousDay)
    }
    
    /// Navigate to the next day
    func goToNextDay() {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        let nextDayString = dateKey(nextDay)
        
        // Check if we have the next day in cache or it's a known empty date
        let isCached = logsCache[nextDayString] != nil || emptyDates.contains(nextDayString)
        
        // Fetch logs with or without loading indicator based on cache status
        fetchLogsByDate(date: nextDay)
    }
    
    /// Navigate to today
    func goToToday() {
        fetchLogsByDate(date: Date())
    }
    
    /// Preload logs for adjacent days (one day before and after the selected date)
    func preloadAdjacentDays(silently: Bool = false) {
        // If already preloading, don't start another request
        if isPreloadingAdjacent && silently {
            return
        }
        
        isPreloadingAdjacent = true
        
        // Set a flag to avoid duplicate preloading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isPreloadingAdjacent = false
        }
        
        guard let email = userEmail else { return }
        
        // Calculate dates to preload
        let calendar = Calendar.current
        let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        let previousDayString = dateKey(previousDay)
        let nextDayString = dateKey(nextDay)
        
        // Skip if we already have both adjacent days or are loading them
        if (logsCache[previousDayString] != nil || emptyDates.contains(previousDayString) || loadingDates.contains(previousDayString)) &&
           (logsCache[nextDayString] != nil || emptyDates.contains(nextDayString) || loadingDates.contains(nextDayString)) {
            print("📅 Adjacent days already cached or loading, skipping preload")
            return
        }
        
        print("📅 Preloading adjacent days silently: \(silently)")
        
        // Track that we're loading these dates
        loadingDates.insert(previousDayString)
        loadingDates.insert(nextDayString)
        
        NetworkManagerTwo.shared.getLogsByDate(
            userEmail: email,
            date: selectedDate,
            includeAdjacent: true,
            daysBefore: 1,
            daysAfter: 1
        ) { [weak self] result in
            guard let self = self else { return }
            
            // Mark these dates as no longer loading
            self.loadingDates.remove(previousDayString)
            self.loadingDates.remove(nextDayString)
            
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    // Group logs by date
                    let logsByDate = Dictionary(grouping: response.logs) { log in
                        if let scheduledAt = log.scheduledAt {
                            let localDate = Calendar.current.startOfDay(for: scheduledAt)
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            formatter.timeZone = .current
                            return formatter.string(from: localDate)
                        }
                        // Fallback to logDate if scheduledAt is missing
                        if let logDate = log.logDate, logDate.count >= 10 {
                            return String(logDate.prefix(10))
                        }
                        return ""
                    }
                    
                    // Update cache with all logs by their date
                    for (logDate, dateLogs) in logsByDate {
                        if !logDate.isEmpty {
                            self.logsCache[logDate] = dateLogs
                            
                            // If a date has no logs, add it to emptyDates
                            if dateLogs.isEmpty {
                                self.emptyDates.insert(logDate)
                            } else {
                                self.emptyDates.remove(logDate)
                            }
                        }
                    }
                    
                    print("📅 Preloaded logs for adjacent days: prev=\(self.logsCache[previousDayString]?.count ?? 0), next=\(self.logsCache[nextDayString]?.count ?? 0)")
                    
                case .failure(let error):
                    print("❌ Error preloading adjacent days: \(error.localizedDescription)")
                }
            }
        }
    }
    /// Check if a date is adjacent to the currently selected date
    private func isAdjacentToSelectedDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: selectedDate, to: date)
        guard let dayDifference = components.day else { return false }
        return abs(dayDifference) <= 1
    }
    func finishLogging(food: Food, mealType: String, completion: @escaping () -> Void = {}) {
        print("🍽️ Finalizing food logging for \(food.displayName) as \(mealType)")
        
        guard let email = userEmail else { 
            completion()
            return 
        }
        
        self.isLoggingFood = true
        self.lastLoggedFoodId = food.fdcId
        
        print("📡 Sending log request to server for \(food.displayName)")
        // Call the correct NetworkManager logFood method with the required parameters
        networkManager.logFood(
            userEmail: email,
            food: food,
            mealType: mealType,
            servings: 1,
            date: Date()
        ) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoggingFood = false
                
                // Check if this food already exists in our logs
                let existingIndex = self.combinedLogs.firstIndex(where: {
                    ($0.type == .food && $0.food?.fdcId == food.fdcId)
                })
                
                switch result {
                case .success(let loggedFood):
                    print("✅ Successfully logged food with foodLogId: \(loggedFood.foodLogId)")
                    
                    // Create a new CombinedLog from the logged food
                    let combinedLog = CombinedLog(
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
                        scheduledAt: Date(), // Set to current date to make it appear in today's logs
                        recipeLogId: nil,
                        recipe: nil,
                        servingsConsumed: nil
                    )
                    
                    // Add the log to today's logs using the helper method
                    self.addLogToTodayAndUpdateDashboard(combinedLog)
                    
                    // Track the food in recently added - fdcId is non-optional
                    self.lastLoggedFoodId = food.fdcId
                    self.trackRecentlyAdded(foodId: food.fdcId)
                    
                    // Still refresh for completeness
                    self.refresh()
                    
                    // Set data for success toast in dashboard
                    self.lastLoggedItem = (name: food.displayName, calories: Double(loggedFood.food.calories))
                    self.showLogSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showLogSuccess = false
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
                    
                    // Recalculate nutrition totals with the new log
                    self.calculateDailyNutrition()
                    
                case .failure(let error):
                    print("❌ Failed to log food: \(error.localizedDescription)")
                    
                    // Display error message
                    self.errorMessage = "Failed to log food: \(error.localizedDescription)"
                   
                    
                    // Clear the lastLoggedFoodId immediately on error
                    self.lastLoggedFoodId = nil
                }
                
                // Call the completion handler
                completion()
            }
        }
    }
    
    // Add method to calculate nutrition totals after logs are loaded or modified
    private func calculateDailyNutrition() {
        // Reset all values
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0
        
        // Sum up values from all logs for the selected date
        for log in currentDateLogs {
            totalCalories += log.displayCalories
            
            // Add nutrition values based on log type
            switch log.type {
            case .food:
                if let food = log.food {
                    totalProtein += food.protein ?? 0
                    totalCarbs += food.carbs ?? 0
                    totalFat += food.fat ?? 0
                }
            case .meal:
                if let meal = log.meal {
                    totalProtein += meal.protein ?? 0
                    totalCarbs += meal.carbs ?? 0
                    totalFat += meal.fat ?? 0
                }
            case .recipe:
                if let recipe = log.recipe {
                    totalProtein += recipe.protein ?? 0
                    totalCarbs += recipe.carbs ?? 0
                    totalFat += recipe.fat ?? 0
                }
            }
        }
        
        // Update the published properties
        DispatchQueue.main.async {
            self.caloriesConsumed = totalCalories
            self.proteinConsumed = totalProtein
            self.carbsConsumed = totalCarbs
            self.fatConsumed = totalFat
            self.remainingCalories = max(0, self.calorieGoal - totalCalories)
            
            print("📊 Calculated daily nutrition: Calories=\(totalCalories), Protein=\(totalProtein)g, Carbs=\(totalCarbs)g, Fat=\(totalFat)g, Remaining=\(self.remainingCalories)")
        }
    }
    
    // Add method to fetch calorie goal from user settings/preferences
    private func fetchCalorieGoal() {
        // For now, we'll use UserDefaults as a simple solution
        // In a production app, this should come from user settings or backend
        if let goal = UserDefaults.standard.value(forKey: "dailyCalorieGoal") as? Double {
            self.calorieGoal = goal
            self.remainingCalories = max(0, goal - self.caloriesConsumed)
            print("📊 Loaded calorie goal from dailyCalorieGoal: \(goal)")
        } else if let onboardingData = UserDefaults.standard.data(forKey: "nutritionGoalsData") {
            // Try to get it from onboarding data if available
            let decoder = JSONDecoder()
            if let goals = try? decoder.decode(NutritionGoals.self, from: onboardingData) {
                self.calorieGoal = goals.calories
                self.remainingCalories = max(0, goals.calories - self.caloriesConsumed)
                print("📊 Loaded calorie goal from nutritionGoalsData: \(goals.calories)")
            } else {
                // Fallback to UserGoalsManager
                loadDefaultGoals()
            }
        } else {
            // Use UserGoalsManager as fallback
            loadDefaultGoals()
        }
    }

    // Add a helper method for loading default goals
    private func loadDefaultGoals() {
        let userGoals = UserGoalsManager.shared.dailyGoals
        self.calorieGoal = Double(userGoals.calories)
        self.remainingCalories = max(0, Double(userGoals.calories) - self.caloriesConsumed)
        print("📊 Loaded calorie goal from UserGoalsManager: \(userGoals.calories)")
    }
}
