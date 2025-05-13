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
    @Published var isLoadingMoreLogs = false  // Added missing variable
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
    private var mealCurrentPage = 1  // Added missing variable
    private var hasMoreMeals = true
    private var mealsHasMore = true  // Added missing variable
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
    
    // Add a flag to track recent optimistic updates
    private var justPerformedOptimisticUpdate = false
    

 


// MARK: ––– Add a log to an arbitrary day (not “today” hard-coded)
func addLog(_ log: CombinedLog, for date: Date) {
    // ➊ Correct bucket key
    let dayKey = dateKey(date)

    // ➋ Make the optimistic copy *use the same scheduled date*
    var optimisticLog         = log
    optimisticLog.isOptimistic = true
    optimisticLog.scheduledAt  = date

    // ➌ Flag so other threads know not to recalc immediately
    justPerformedOptimisticUpdate = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.justPerformedOptimisticUpdate = false
    }

    // ➍ Push into global timeline
    combinedLogs.insert(optimisticLog, at: 0)

    // ➎ If the UI is showing this same day, update that list + nutrition
    if Calendar.current.isDate(selectedDate, inSameDayAs: date) {
        currentDateLogs.insert(optimisticLog, at: 0)
        caloriesConsumed += log.displayCalories
        if let f = log.food {
            proteinConsumed += f.protein ?? 0
            carbsConsumed   += f.carbs   ?? 0
            fatConsumed     += f.fat     ?? 0
        }
        remainingCalories = max(0, calorieGoal - caloriesConsumed)
    }

    // ➏ Update in-memory cache and persist to disk
    logsCache[dayKey, default: []].insert(optimisticLog, at: 0)
    persistDayCache(dayKey, logs: logsCache[dayKey]!)

    // ➐ Debug
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        print("\n📝 Cache after optimistic insert into \(dayKey):")
        self.debugDumpLogs()
    }
}




    private func persistDayCache(_ dateKey: String, logs: [CombinedLog]) {
    logsCache[dateKey] = logs           // keep it in RAM as usual

    guard let userEmail = userEmail,
          let data = try? JSONEncoder().encode(logs) else { return }

    UserDefaults.standard.set(data,
        forKey: "logs_by_date_\(userEmail)_\(dateKey)")
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

          for key in UserDefaults.standard.dictionaryRepresentation().keys
        where key.hasPrefix("logs_by_date_\(userEmail)_") {
        UserDefaults.standard.removeObject(forKey: key)
    }
        
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

    // MARK: - Optimistic-row helpers
private func optimisticLogs(for dayKey: String) -> [CombinedLog] {
    let cal = Calendar.current
    return currentDateLogs.filter {
        $0.isOptimistic &&
        cal.isDate($0.scheduledAt ?? .distantPast,
                   equalTo: keyToDate(dayKey),
                   toGranularity: .day)
    }
}

private func keyToDate(_ key: String) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone   = .current
    return f.date(from: key) ?? Date()
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
        
        // Prevent refresh if loading, analyzing food, etc.
        if isLoadingLogs || isLoadingMoreLogs || isLoadingMeals || isScanningFood || isAnalyzingFood || isGeneratingMeal || isGeneratingFood {
            print("⚠️ Skipping refresh because another operation is in progress")
            return
        }
        
        // If we're looking at today, use backgroundSyncWithServer instead to preserve optimistic updates
        if Calendar.current.isDateInToday(selectedDate) {
            print("📊 Redirecting refresh() to backgroundSyncWithServer() for today's data")
            backgroundSyncWithServer()
            return
        }
        
        // Reset pagination states
        currentPage = 1
        mealCurrentPage = 1
        hasMore = true
        mealsHasMore = true
        
        // Clear logs cache for all dates except today (preserve today's optimistic updates)
        let todayKey = dateKey(Date())
        let todayLogs = logsCache[todayKey]
        
        // Clear all cache except today
        logsCache.removeAll()
        
        // Restore today's logs if we had them
        if let logs = todayLogs {
            logsCache[todayKey] = logs
        }
        
        emptyDates.removeAll()
        loadingDates.removeAll()
        
        // Reset date logs loading state
        isLoadingDateLogs = false
        dateLogsError = nil
        
        // Fetch fresh logs for the selected date
        fetchLogsByDate(date: selectedDate)
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
    
    // First, mark this as the last logged food ID to update UI appearance
    self.lastLoggedFoodId = food.fdcId
    
    // REMOVED: Check for existing logs - no longer needed as we'll wait for server response
    
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
                    // scheduledAt: Date(),
                    scheduledAt: date,
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil
                )
                
                // Add the log to today's logs using the helper method for optimistic update
                // self.addLogToTodayAndUpdateDashboard(combinedLog)
                self.addLog(combinedLog, for: date)
                
                // Track the food in recently added - fdcId is non-optional
                self.lastLoggedFoodId = food.fdcId
                self.trackRecentlyAdded(foodId: food.fdcId)
                
                // Give backend time to index the new log before syncing
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.backgroundSyncWithServer()
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
// func logMeal(
//     meal: Meal,
//     mealTime: String,
//     date: Date = Date(),
//     notes: String? = nil,
//     calories: Double,
//     completion: ((Result<LoggedMeal, Error>) -> Void)? = nil,
//     statusCompletion: ((Bool) -> Void)? = nil
// ) {
//     guard let email = userEmail else { 
//         statusCompletion?(false)
//         return 
//     }
    
//     // Show loading state
//     isLoadingMeal = true
    
//     // Immediately mark as recently logged for UI feedback
//     self.lastLoggedMealId = meal.id
    
//     // Create an optimistic log entry before server response
//     let combinedLog = CombinedLog(
//         type: .meal,
//         status: "completed",
//         calories: calories,
//         message: "\(meal.title) - \(mealTime)",
//         foodLogId: nil,
//         food: nil,
//         mealType: nil,
//         mealLogId: -Int.random(in: 10000...99999), // Temp negative ID until server responds
//         meal: MealSummary(
//             mealId: meal.id, 
//             title: meal.title, 
//             description: meal.description ?? "",
//             image: meal.image,
//             calories: calories,
//             servings: meal.servings,
//             protein: meal.totalProtein,
//             carbs: meal.totalCarbs,
//             fat: meal.totalFat,
//             scheduledAt: date
//         ),
//         mealTime: mealTime,
//         scheduledAt: date,
//         recipeLogId: nil,
//         recipe: nil,
//         servingsConsumed: nil,
//         isOptimistic: true
//     )
    
//     // Add optimistic log to UI immediately
//     // self.addLogToTodayAndUpdateDashboard(combinedLog)
//     self.addLog(combinedLog, for: date)
    
//     // REMOVED: Check for existing meal logs - we'll wait for server response
    
//     networkManager.logMeal(
//         userEmail: email,
//         mealId: meal.id,
//         mealTime: mealTime,
//         date: date,
//         notes: notes,
//         calories: calories
//     ) { [weak self] result in
//         DispatchQueue.main.async {
//             guard let self = self else { 
//                 statusCompletion?(false)
//                 return 
//             }
//             self.isLoadingMeal = false
            
//             switch result {
//             case .success(let loggedMeal):
//                 print("✅ Successfully logged meal with ID: \(loggedMeal.mealLogId)")
                
//                 // Clear cache for the current date
//                 let dateStr = self.dateKey(date)
//                 self.clearCache(for: dateStr)
                
//                 // Give backend time to index the new log before syncing
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                     self.backgroundSyncWithServer()
//                 }
                
//                 // Set data for success toast in dashboard
//                 self.lastLoggedItem = (name: meal.title, calories: calories)
//                 self.showLogSuccess = true
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                     self.showLogSuccess = false
//                 }
                
//                 // Show the local toast
//                 self.showToast = true
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                     self.showToast = false
//                 }
                
//                 // Clear the flag and toast after 2 seconds
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                     withAnimation {
//                         // Only clear if it still matches the meal we logged
//                         if self.lastLoggedMealId == meal.id {
//                             self.lastLoggedMealId = nil
//                         }
//                         self.showMealLoggedToast = false
//                     }
//                 }
                
//                 statusCompletion?(true)
//                 completion?(.success(loggedMeal))
                
//             case .failure(let error):
//                 print("❌ Failed to log meal: \(error)")
//                 self.error = error
                
//                 // Clear the lastLoggedMealId immediately on error
//                 withAnimation {
//                     // Only clear if it still matches the meal we tried to log
//                     if self.lastLoggedMealId == meal.id {
//                         self.lastLoggedMealId = nil
//                     }
//                 }
                
//                 statusCompletion?(false)
//                 completion?(.failure(error))
//             }
//         }
//     }
// }

//  FoodManager.swift
//  Replace the whole old version with this one
//  --------------------------------------------------------

 func logMeal(
        meal: Meal,
        mealTime: String,
        date: Date = Date(),
        notes: String? = nil,
        calories: Double,
        completion: ((Result<LoggedMeal, Error>) -> Void)? = nil,
        statusCompletion: ((Bool) -> Void)? = nil
    ) {
         guard let email = userEmail else { return }

        // basic UI flags so the plus button flashes green
        lastLoggedMealId   = meal.id
        isLoadingMeal      = true
        showMealLoggedToast = true

        networkManager.logMeal(
            userEmail: email,
            mealId:    meal.id,
            mealTime:  mealTime,
            date:      date,
            notes:     notes,
            calories:  calories
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                // reset simple loading flags
                self.isLoadingMeal = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showMealLoggedToast = false
                    self.lastLoggedMealId = nil
                }



                switch result {
                case .success(let logged):
                    // caller will build CombinedLog & update DayLogsVM
                    completion?(.success(logged))

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

                    // Give backend time to index the new log before syncing
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.backgroundSyncWithServer()
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
                    statusCompletion?(true)

                case .failure(let error):
                    self.error = error
                    completion?(.failure(error))
                    statusCompletion?(false)
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
                // Instead of optimistically updating UI, fetch fresh logs from server
                self.fetchLogsByDate(date: Date())
                
                // Update last logged recipe ID for UI feedback
                self.lastLoggedRecipeId = recipe.id
                
                // Set data for success toast in dashboard
                self.lastLoggedItem = (name: recipe.title, calories: calories)
                self.showLogSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showLogSuccess = false
                }
                
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
            
            // Track the food in recently added - fdcId is non-optional
            self.lastLoggedFoodId = loggedFood.food.fdcId
            self.trackRecentlyAdded(foodId: loggedFood.food.fdcId)
            
            // Clear cache for the current date to ensure fresh data
            let currentDateStr = self.dateKey(Date())
            self.logsCache.removeValue(forKey: currentDateStr)
            self.emptyDates.remove(currentDateStr)
            
            // // Give backend time to index the new log before syncing
            // DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            //     self.backgroundSyncWithServer()
            // }
            
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
// func backgroundSyncWithServer() {
//     guard let email = userEmail else { return }
    
//     // Debug log
//     print("🔄 Starting background sync with server")
    
//     // Get date string for current date
//     let currentDateStr = self.dateKey(self.selectedDate)
    
//     // Save optimistic logs from the current day
//     let optimisticLogs = self.currentDateLogs.filter(\.isOptimistic)
//     print("📝 Found \(optimisticLogs.count) optimistic logs that need to be preserved during sync")
    
//     // Fetch fresh data from server without invalidating optimistic logs
//     NetworkManagerTwo.shared.getLogsByDate(
//         userEmail: email,
//         date: self.selectedDate,
//         includeAdjacent: false,
//         timezoneOffset: getTimezoneOffsetInMinutes()
//     ) { [weak self] result in
//         guard let self = self else { return }
        
//         DispatchQueue.main.async {
//             switch result {
//             case .success(let response):
//                 // Get server logs for current date
//                 let serverLogs = response.logs
//                 print("📥 Received \(serverLogs.count) logs from server for \(currentDateStr)")
                
//                 // Merge any optimistic logs with server logs
//                 let combinedLogs = self.deduplicateLogs(serverLogs + optimisticLogs)
                
//                 // Update cache with merged logs
//                 self.logsCache[currentDateStr] = combinedLogs
                
//                 // Update current logs if we're still on the same date
//                 if self.dateKey(self.selectedDate) == currentDateStr {
//                     self.currentDateLogs = combinedLogs
                    
//                     // Recalculate nutrition values
//                     self.calculateDailyNutrition()
//                 }
                
//                 print("🔄 Background sync complete: \(serverLogs.count) server logs merged with \(optimisticLogs.count) optimistic logs")
                
//                 // Debug the logs after sync
//                 self.debugDumpLogs()
                
//             case .failure(let error):
//                 print("❌ Background sync failed: \(error.localizedDescription)")
//                 // On failure, keep optimistic logs
//                 if !optimisticLogs.isEmpty {
//                     print("📝 Keeping \(optimisticLogs.count) optimistic logs after failed sync")
//                 }
//             }
//         }
//     }
// }
/// Re-fetch the logs for the currently selected day without letting
/// anything that’s already on-screen vanish if the backend hasn’t
/// indexed it yet.
func backgroundSyncWithServer() {
    guard let email = userEmail else { return }

    print("🔄 Starting background sync with server")

    let dayKey      = dateKey(selectedDate)
    let uiLogs      = currentDateLogs          // <-- keep *all* rows the UI shows now

    NetworkManagerTwo.shared.getLogsByDate(
        userEmail:       email,
        date:            selectedDate,
        includeAdjacent: false,
        timezoneOffset:  getTimezoneOffsetInMinutes()
    ) { [weak self] result in
        guard let self = self else { return }

        DispatchQueue.main.async {
            switch result {

            // ----------------------- SUCCESS ----------------------------
            case .success(let response):
                let serverLogs = response.logs
                print("📥 Received \(serverLogs.count) logs from server for \(dayKey)")

                // Merge what the server sent with *everything* we were already
                // displaying.  deduplicateLogs() prefers the non-optimistic
                // (server) copy when IDs collide.
                var merged = self.deduplicateLogs(serverLogs + uiLogs)

                // Optional: if the server copy for a given ID is present,
                // clear the optimistic flag so the row stops pulsing, etc.
                for i in merged.indices {
                    if merged[i].isOptimistic,
                       serverLogs.contains(where:{ $0.id == merged[i].id }) {
                        merged[i].isOptimistic = false
                    }
                }

                // Cache & push to UI
                self.logsCache[dayKey]   = merged
                self.persistDayCache(dayKey, logs: merged)

                if self.dateKey(self.selectedDate) == dayKey {
                    self.currentDateLogs = merged
                    self.calculateDailyNutrition()
                }

                print("✅ Background sync complete – "
                      + "\(serverLogs.count) server rows + "
                      + "\(uiLogs.count) UI rows → \(merged.count) merged")

            // ----------------------- FAILURE ----------------------------
            case .failure(let error):
                print("❌ Background sync failed: \(error.localizedDescription)")
                // Nothing to do; we simply keep whatever is already on screen.
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
                
                // Sync with server in the background without UI interruption
                self.backgroundSyncWithServer()
                
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
            if let index = combinedLogs.firstIndex(where: { $0.id == "food_\(id)" && $0.type == .food }) {
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
            if let index = combinedLogs.firstIndex(where: { $0.id == "meal_\(id)" && $0.type == .meal }) {
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
 

// MARK: - Scan-an-image → CombinedLog
@MainActor
func analyzeFoodImage(
  image: UIImage,
  userEmail: String,
  completion: @escaping (Result<CombinedLog, Error>) -> Void
) {
  // ─── 1) UI state ─────────────────────────────
  isScanningFood = true
  isLoading      = true
  analysisStage  = 0
  loadingMessage = "Analyzing image…"
  uploadProgress = 0

  // ─── 2) Fake progress ticker ─────────────────


  uploadProgress = 0
let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
  guard let self = self else { t.invalidate(); return }
  // bump progress up to, say, 90%
  self.uploadProgress = min(0.9, self.uploadProgress + 0.1)
}

  // ─── 3) Call backend ─────────────────────────
  networkManager.analyzeFoodImage(image: image, userEmail: userEmail) { [weak self] success, payload, errMsg in
    guard let self = self else { return }
    DispatchQueue.main.async {
      // stop ticker + UI
      progressTimer.invalidate()

     withAnimation {
      self.uploadProgress = 1.0
    }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.isScanningFood = false
        self.isLoading      = false

        // reset for next time
        self.uploadProgress = 0
      }

      // failure path
      guard success, let payload = payload else {
        let msg = errMsg ?? "Unknown error"
        print("🔴 [analyzeFoodImage] error: \(msg)")
        completion(.failure(NSError(
          domain: "FoodScan", code: -1,
          userInfo: [NSLocalizedDescriptionKey: msg])))
        return
      }

      //── 4) Dump raw payload for debugging
      if let rawJSON = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
         let str     = String(data: rawJSON, encoding: .utf8) {
        print("🔍 [analyzeFoodImage] raw payload:\n\(str)")
      }

      do {
        //── 5) Decode directly into your LoggedFood
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        let decoder  = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let loggedFood = try decoder.decode(LoggedFood.self, from: jsonData)

        //── 6) Wrap it in a CombinedLog
        let combined = CombinedLog(
          type:        .food,
          status:      loggedFood.status,
          calories:    loggedFood.calories,
          message:     loggedFood.message,
          foodLogId:   loggedFood.foodLogId,
          food:        loggedFood.food,
          mealType:    loggedFood.mealType,
          mealLogId:   nil,
          meal:        nil,
          mealTime:    nil,
          scheduledAt: Date(),
          recipeLogId: nil,
          recipe:      nil,
          servingsConsumed: nil
        )

        completion(.success(combined))
           self.lastLoggedItem = (
     name:     loggedFood.food.displayName,
     calories: loggedFood.calories
   )
   self.showLogSuccess = true
   DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
     self.showLogSuccess = false
 
        

   }
      }
      catch {
        //── 7) On decode error, print the bad JSON + error
        print("❌ [analyzeFoodImage] decoding LoggedFood failed:", error)
        if let rawJSON = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let str     = String(data: rawJSON, encoding: .utf8) {
          print("❌ [analyzeFoodImage] payload was:\n\(str)")
        }
        completion(.failure(error))
      }
    }
  }
}








    // Add this function to handle the barcode scanning logic
    func lookupFoodByBarcode(barcode: String, image: UIImage? = nil, userEmail: String, navigationPath: Binding<NavigationPath>, completion: @escaping (Bool, String?) -> Void) {
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
            mealType: "Lunch",
            shouldLog: false
        ) { [weak self] result in
            guard let self = self else { return }
            
            // Update progress for UI
            self.uploadProgress = 1.0
            
            switch result {
            case .success(let response):
                // Reset scanning state since we'll show the confirmation screen
                self.isScanningFood = false
                self.scannedImage = nil
                
                // Show the ConfirmFoodView with the barcode data
                DispatchQueue.main.async {
                    // Add the ConfirmFoodView to the navigation path using BarcodeFood
                    navigationPath.wrappedValue.append(BarcodeFood(food: response.food, foodLogId: response.foodLogId))
                    completion(true, nil)
                }
                
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
    
    // Original method for backwards compatibility (calls the new method)
    func lookupFoodByBarcode(barcode: String, image: UIImage? = nil, userEmail: String, completion: @escaping (Bool, String?) -> Void) {
        // If we don't have a navigation path, we can't show the confirmation screen
        // This is just a placeholder for backward compatibility
        print("Warning: Using deprecated barcode lookup method without navigation path")
        
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
            mealType: "Lunch",
            shouldLog: false
        ) { [weak self] result in
            guard let self = self else { return }
            
            // Update progress for UI
            self.uploadProgress = 1.0
            
            switch result {
            case .success(let payload):
                let food = payload.food
                let serverLogId = payload.foodLogId
                
                // Store the food for confirmation, but DON'T add it to the logs yet
                self.aiGeneratedFood = food.asLoggedFoodItem
                
                // Track ID for later use when confirmed
                self.lastLoggedFoodId = food.fdcId
                
                // Update scanner state
                self.isScanningFood = false
                self.scannedImage = nil
                
                // Return success so the scanner can close
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
                        
                        // Sync with server in the background without UI interruption
                        self.backgroundSyncWithServer()
                        
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
        loadingMessage = "Transcribing your voice…"  // Initial stage message
        
        // Create a timer to cycle through analysis stages for UI feedback
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            // Cycle through stages 0-3
            self.analysisStage = (self.analysisStage + 1) % 4
            
            // Update loading message based on current stage
            self.loadingMessage = [
                "Transcribing your voice…",
                "Analyzing food description…",
                "Generating nutritional data…",
                "Finalizing your food log…"
            ][self.analysisStage]
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
                    // Use defer to ensure flags are always reset
                    defer {
                        // Stop the analysis animation timer
                        timer.invalidate()
                        
                        // Reset state flags
                        self.isAnalyzingFood = false
                        self.isLoading = false
                        self.analysisStage = 0
                        self.loadingMessage = ""
                    }
                    
                    switch result {
                    case .success(let loggedFood):
                        print("✅ Voice log successfully processed: \(loggedFood.food.displayName)")
                        
                        // Check if this is an "Unknown food" with no nutritional value
                        // This happens when the server couldn't identify a food from the transcription
                        if loggedFood.food.displayName.lowercased().contains("unknown food") || 
                           (loggedFood.food.calories == 0 && loggedFood.food.protein == 0 && 
                            loggedFood.food.carbs == 0 && loggedFood.food.fat == 0) {
                            
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
                        // self.addLogToTodayAndUpdateDashboard(combinedLog)
                        self.addLog(combinedLog, for: Date())
                        
                        // Track the food in recently added
                        self.lastLoggedFoodId = loggedFood.food.fdcId
                        self.trackRecentlyAdded(foodId: loggedFood.food.fdcId)
                        
                        // NEW: Use background sync instead of immediate refresh
                        self.backgroundSyncWithServer()
                        
                        // Save the generated food for the toast
                        self.aiGeneratedFood = loggedFood.food
                        
                        // Show success toast
                        self.showAIGenerationSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.showAIGenerationSuccess = false
                        }
                        
                        // Clear the lastLoggedFoodId after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                // Only clear if it still matches the food we logged
                                if self.lastLoggedFoodId == loggedFood.food.fdcId {
                                    self.lastLoggedFoodId = nil
                                }
                            }
                        }
                        
                    case .failure(let error):
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
                self.loadingMessage = ""
                
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
        
        // wipe summaries so UI doesn't display stale numbers
        resetDailyNutrition()
        
        // Update the selected date right away for UI
        selectedDate = date
        
        // Get date string for cache key
        let dateString = dateKey(date)
        
        // Always fetch fresh data for today to ensure we have the latest logs
        let isToday = Calendar.current.isDateInToday(date)
        let forceRefresh = isToday  // Always refresh today's data
        
        // Keep optimistic logs visible even during a forced refresh of today
        if forceRefresh,
           let optimistic = logsCache[dateString]?.filter(\.isOptimistic),
           !optimistic.isEmpty {
            currentDateLogs = optimistic
            calculateDailyNutrition()
        }
        
        // When navigating to today, always clear the cache first
        if isToday {
            logsCache.removeValue(forKey: dateString)
            emptyDates.remove(dateString)
        }
        
        // Check if we already have this date in cache and we're not forcing a refresh
        if !forceRefresh, let cachedLogs = logsCache[dateString] {
            // If we have logs in cache, use them immediately
            print("📅 Using cached logs for \(dateString): \(cachedLogs.count) logs")
            
            // Always update currentDateLogs and recalculate nutrition
            currentDateLogs = cachedLogs
            calculateDailyNutrition()
            
            // Still preload adjacent days in the background if requested
            if preloadAdjacent {
                preloadAdjacentDays(silently: true)
            }
            
            return
        }
        
        // Check if this is a known empty date and we're not forcing a refresh
        if !forceRefresh, emptyDates.contains(dateString) {
            currentDateLogs = []
            print("📅 Known empty date: \(dateString), showing empty state")
            
            // Still preload adjacent days in the background if requested
            if preloadAdjacent {
                preloadAdjacentDays(silently: true)
            }
            
            // Reset nutrition values when no logs exist
            resetDailyNutrition()
            
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
        
        // Log whether we're fetching fresh data
        if forceRefresh {
            print("📅 Fetching fresh data for \(dateString) (today)")
        } else {
            print("📅 Fetching data for \(dateString)")
        }
        
        // Load from server
        NetworkManagerTwo.shared.getLogsByDate(
            userEmail: email,
            date: date,
            includeAdjacent: preloadAdjacent,
            daysBefore: 1,
            daysAfter: 1,
            timezoneOffset: getTimezoneOffsetInMinutes()
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
      // ─── Update cache with all logs by their date ─────────────────────────────
// ─── Update cache with all logs by their date ─────────────────────────────
for (logDate, serverLogs) in logsByDate {
    guard !logDate.isEmpty else { continue }

    // merge server rows with JUST the optimistic rows that belong to *this* day
    let merged = self.deduplicateLogs(serverLogs + self.optimisticLogs(for: logDate))
    self.logsCache[logDate] = merged

    // refresh the list if we’re currently looking at this date
    if logDate == self.dateKey(self.selectedDate) {
        self.currentDateLogs = merged
    }

    // keep empty-date bookkeeping in sync
    if merged.isEmpty {
        self.emptyDates.insert(logDate)
    } else {
        self.emptyDates.remove(logDate)
    }
}
// ──────────────────────────────────────────────────────────────────────────

// ──────────────────────────────────────────────────────────────────────────


                    
                    // Update current date logs
                    if let targetLogs = self.logsCache[dateString] {
                        // Get any pending optimistic logs that haven't been saved yet
                        let pendingOptimisticLogs = self.currentDateLogs.filter(\.isOptimistic)
                        
                        // Merge server logs with any optimistic ones that haven't returned yet
                        let merged = self.deduplicateLogs(targetLogs + pendingOptimisticLogs)
                        self.currentDateLogs = merged
                        self.logsCache[dateString]    = merged 
                        print("📅 Loaded \(merged.count) logs for \(dateString) (including \(pendingOptimisticLogs.count) optimistic logs)")
                        
                        // Calculate nutrition totals after logs are loaded
                        self.calculateDailyNutrition()
                    } else {
                        // Save any optimistic logs from the current display
                        let pendingOptimisticLogs = self.currentDateLogs.filter(\.isOptimistic)
                        
                        if pendingOptimisticLogs.isEmpty {
                            self.currentDateLogs = []
                            self.emptyDates.insert(dateString)
                            print("📅 No logs found for \(dateString)")
                            
                            // Reset nutrition values when no logs exist
                            self.resetDailyNutrition()
                        } else {
                            // Keep the optimistic logs even if server returned none
                            self.currentDateLogs = pendingOptimisticLogs
                            self.logsCache[dateString] = pendingOptimisticLogs
                            print("📅 No server logs found for \(dateString), but keeping \(pendingOptimisticLogs.count) optimistic logs")
                            
                            // Calculate nutrition from optimistic logs
                            self.calculateDailyNutrition()
                        }
                    }
                    
                case .failure(let error):
                    // Don't clear optimistic logs on error - keep them visible
                    let pendingOptimisticLogs = self.currentDateLogs.filter(\.isOptimistic)
                    
                    if pendingOptimisticLogs.isEmpty {
                        self.dateLogsError = error
                        self.currentDateLogs = []
                        print("❌ Error loading logs for \(dateString): \(error.localizedDescription)")
                    } else {
                        print("❌ Error loading logs for \(dateString): \(error.localizedDescription), but keeping \(pendingOptimisticLogs.count) optimistic logs")
                        // Keep optimistic logs visible on error
                        self.currentDateLogs = pendingOptimisticLogs
                    }
                }
            }
        }
    }
    
    /// Navigate to the previous day
    func goToPreviousDay() {
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let previousDayString = dateKey(previousDay)
        
        print("\n🔄 Navigating to previous day: \(previousDayString)")
        // Check if we have the previous day in cache or it's a known empty date
        let isCached = logsCache[previousDayString] != nil || emptyDates.contains(previousDayString)
        
        // Fetch logs with or without loading indicator based on cache status
        fetchLogsByDate(date: previousDay)
        
        // Debug what logs look like after navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.debugDumpLogs()
        }
    }
    
    /// Navigate to the next day
    func goToNextDay() {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        let nextDayString = dateKey(nextDay)
        
        print("\n🔄 Navigating to next day: \(nextDayString)")
        // Check if we have the next day in cache or it's a known empty date
        let isCached = logsCache[nextDayString] != nil || emptyDates.contains(nextDayString)
        
        // Fetch logs with or without loading indicator based on cache status
        fetchLogsByDate(date: nextDay)
        
        // Debug what logs look like after navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.debugDumpLogs()
        }
    }
    
    /// Navigate to "today" without dropping optimistic logs
    func goToToday(forceRefresh: Bool = false) {
        let today = Date()
        selectedDate = today                 // update toolbar

        if forceRefresh {
            clearCache(for: dateKey(today))  // caller-requested hard reload
        }

        // 1. show cached/optimistic logs instantly
        if let cached = logsCache[dateKey(today)] {
            currentDateLogs = cached
            calculateDailyNutrition()
        }

        // 2. silently fetch fresh data and merge on arrival
        fetchLogsByDate(date: today, preloadAdjacent: true)

        // 3. let server eventually reconcile
        backgroundSyncWithServer()
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
        
        // Today should always be fetched fresh
        let todayString = dateKey(Date())
        let isPreviousDayToday = Calendar.current.isDateInToday(previousDay)
        let isNextDayToday = Calendar.current.isDateInToday(nextDay)
        
        // Skip if we already have both adjacent days or are loading them
        // But always fetch today to ensure we have the latest data
        if (!isPreviousDayToday && (logsCache[previousDayString] != nil || emptyDates.contains(previousDayString) || loadingDates.contains(previousDayString))) &&
           (!isNextDayToday && (logsCache[nextDayString] != nil || emptyDates.contains(nextDayString) || loadingDates.contains(nextDayString))) {
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
            daysAfter: 1,
            timezoneOffset: getTimezoneOffsetInMinutes()
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
             // --- BEGIN PATCH ---
                        for (logDate, dateLogs) in logsByDate {
                            guard !logDate.isEmpty else { continue }

                            // pull forward optimistic rows we cached earlier for this day
                            let optimistic = self.logsCache[logDate]?.filter(\.isOptimistic) ?? []

                            // ALWAYS merge + dedupe
                            let merged = self.deduplicateLogs(dateLogs + optimistic)
                            self.logsCache[logDate] = merged      // ✅ keeps Coke row alive

                            // if the user is *currently* looking at this date, refresh the list
                            if self.dateKey(self.selectedDate) == logDate {
                                self.currentDateLogs = merged
                            }

                            // maintain emptyDates bookkeeping
                            if merged.isEmpty {
                                self.emptyDates.insert(logDate)
                            } else {
                                self.emptyDates.remove(logDate)
                            }
                        }
                        // --- END PATCH ---

                    
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
                    // self.addLogToTodayAndUpdateDashboard(combinedLog)
                    self.addLog(combinedLog, for: Date())
                    
                    // Track the food in recently added - fdcId is non-optional
                    self.lastLoggedFoodId = food.fdcId
                    self.trackRecentlyAdded(foodId: food.fdcId)
                    
                    // Reload the current date logs to ensure the UI is up to date
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.reloadCurrentDateLogs()
                    }
                    
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
                    
                    // No need to recalculate - already done in addLogToTodayAndUpdateDashboard
                    
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
        // Skip recalculation if we just performed an optimistic update
        if justPerformedOptimisticUpdate && Calendar.current.isDateInToday(selectedDate) {
            print("📊 Skipping calculateDailyNutrition() - just performed optimistic update")
            return
        }
        
        let isToday = Calendar.current.isDateInToday(selectedDate)
        print("📊 Calculating nutrition for \(isToday ? "today" : "selected date")")
        
        // Reset values before calculation
        caloriesConsumed = 0
        proteinConsumed = 0
        carbsConsumed = 0
        fatConsumed = 0
        
        // Sum up values from all logs for the selected date
        for log in currentDateLogs {
            caloriesConsumed += log.displayCalories
            
            // Add nutrition values based on log type
            switch log.type {
            case .food:
                if let food = log.food {
                    proteinConsumed += food.protein ?? 0
                    carbsConsumed += food.carbs ?? 0
                    fatConsumed += food.fat ?? 0
                }
            case .meal:
                if let meal = log.meal {
                    proteinConsumed += meal.protein ?? 0
                    carbsConsumed += meal.carbs ?? 0
                    fatConsumed += meal.fat ?? 0
                }
            case .recipe:
                if let recipe = log.recipe {
                    proteinConsumed += recipe.protein ?? 0
                    carbsConsumed += recipe.carbs ?? 0
                    fatConsumed += recipe.fat ?? 0
                }
            }
        }
        
        // Update remaining calories
        remainingCalories = max(0, calorieGoal - caloriesConsumed)
        
        print("📊 Calculated nutrition: Calories=\(caloriesConsumed), Protein=\(proteinConsumed)g, Carbs=\(carbsConsumed)g, Fat=\(fatConsumed)g, Remaining=\(remainingCalories)")
    }
    
    private func resetDailyNutrition() {
        caloriesConsumed   = 0
        proteinConsumed    = 0
        carbsConsumed      = 0
        fatConsumed        = 0
        remainingCalories  = calorieGoal      // show full goal until fresh data arrives
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

    /// Helper function to deduplicate logs by their ID
    /// This version prioritizes non-optimistic (server) logs over optimistic logs
    private func deduplicateLogs(_ logs: [CombinedLog]) -> [CombinedLog] {
        var uniqueLogs: [CombinedLog] = []
        var seenIds = Set<String>()
        var optimisticLogIds = Set<String>()
        
        // First pass: add all non-optimistic logs and track optimistic log IDs
        for log in logs {
            if log.isOptimistic {
                // Just track optimistic log IDs for now
                optimisticLogIds.insert(log.id)
            } else if !seenIds.contains(log.id) {
                // Add non-optimistic logs immediately
                uniqueLogs.append(log)
                seenIds.insert(log.id)
                print("✅ Adding server log with ID: \(log.id), type: \(log.type)")
            } else {
                print("🚫 Removing duplicate server log with ID: \(log.id), type: \(log.type)")
            }
        }
        
        // Second pass: add optimistic logs only if no server log with the same ID exists
        for log in logs {
            if log.isOptimistic && !seenIds.contains(log.id) {
                uniqueLogs.append(log)
                seenIds.insert(log.id)
                print("✅ Adding optimistic log with ID: \(log.id), type: \(log.type)")
            }
        }
        
        if uniqueLogs.count < logs.count {
            print("🧹 Deduplication removed \(logs.count - uniqueLogs.count) logs. Original: \(logs.count), Now: \(uniqueLogs.count)")
        }
        
        // Sort logs by scheduledAt date (most recent first)
        uniqueLogs.sort { (log1, log2) -> Bool in
            guard let date1 = log1.scheduledAt, let date2 = log2.scheduledAt else {
                // If dates not available, keep optimistic logs first
                return log1.isOptimistic && !log2.isOptimistic
            }
            return date1 > date2 // Most recent first
        }
        
        print("🔄 Logs sorted by date (newest first)")
        return uniqueLogs
    }

    /// Reloads logs for the currently selected date from the server
    /// This ensures the UI is in sync with the latest data
    func reloadCurrentDateLogs() {
        print("🔄 Explicitly reloading logs for current date: \(selectedDate)")
        
        // Invalidate the cache for the selected date to force a fresh fetch
        let dateStr = dateKey(selectedDate)
        logsCache.removeValue(forKey: dateStr)
        emptyDates.remove(dateStr)
        
        // Force the UI to update by sending objectWillChange
        objectWillChange.send()
        
        // Fetch fresh logs from the server
        fetchLogsByDate(date: selectedDate)
        
        // Force UI update after a short delay to ensure changes are reflected
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.objectWillChange.send()
        }
        
        // Debug what logs look like after reload
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("\n🔄 Cache state after reloading logs:")
            self.debugDumpLogs()
        }
    }

    /// Helper method to clear cache for a specific date
    func clearCache(for dateString: String) {
        // Remove from logs cache
        logsCache.removeValue(forKey: dateString)
        // Remove from known empty dates
        emptyDates.remove(dateString)
        print("🧹 Cleared cache for date: \(dateString)")
    }
    
    /// Debug function to print the contents of logs cache for a specific date
    func debugPrintLogsForDate(date: Date) {
        let dateStr = dateKey(date)
        print("\n🐞 DEBUG: Logs for date \(dateStr)")
        print("------------------------------------")
        
        if let logs = logsCache[dateStr] {
            print("📋 Found \(logs.count) logs in cache for \(dateStr)")
            
            for (index, log) in logs.enumerated() {
                var logDetails = "[\(index)] "
                
                switch log.type {
                case .food:
                    logDetails += "FOOD: \(log.food?.displayName ?? "Unknown") - \(log.mealType ?? "No meal type")"
                case .meal:
                    logDetails += "MEAL: \(log.meal?.title ?? "Unknown") - \(log.mealTime ?? "No meal time")"
                case .recipe:
                    logDetails += "RECIPE: \(log.recipe?.title ?? "Unknown")"
                }
                
                logDetails += " | Calories: \(log.displayCalories)"
                
                if let scheduledAt = log.scheduledAt {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    logDetails += " | Scheduled: \(formatter.string(from: scheduledAt))"
                }
                
                logDetails += " | Optimistic: \(log.isOptimistic)"
                
                print(logDetails)
            }
        } else {
            print("❌ No logs found in cache for \(dateStr)")
        }
        
        if emptyDates.contains(dateStr) {
            print("⚠️ Date \(dateStr) is marked as empty in emptyDates")
        }
        
        if loadingDates.contains(dateStr) {
            print("⏳ Date \(dateStr) is currently loading")
        }
        
        print("------------------------------------\n")
    }
    
    /// Dumps the cache + currentDateLogs so you can see what the UI will show
    func debugDumpLogs() {
        print("──────── DEBUG DUMP ────────")
        let sorted = logsCache.sorted { $0.key < $1.key }
        for (dateKey, logs) in sorted {
            print("🗓  \(dateKey)  →  \(logs.count) logs")
            for log in logs {
                let name = log.food?.displayName ??
                           log.meal?.title ??
                           log.recipe?.title ?? "–"
                let opt  = log.isOptimistic ? "🟡" : "  "
                print("   \(opt) \(name)  (\(log.type))")
            }
        }
        print("➡️  currently selected: \(dateKey(selectedDate))  →  \(currentDateLogs.count) logs")
        print("────────────────────────────")
    }

    // Helper method to get the device's timezone offset in minutes
    private func getTimezoneOffsetInMinutes() -> Int {
        return TimeZone.current.secondsFromGMT() / 60
    }
}
