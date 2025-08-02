import Foundation
import SwiftUI
import Mixpanel
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
    @Published var showSavedMealToast = false
    @Published var showUnsavedMealToast = false
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

    // New specific loading states for different functionalities
    @Published var isGeneratingMacros = false
    @Published var macroGenerationStage = 0
    @Published var macroLoadingMessage: String = ""
    @Published var macroLoadingTitle: String = "Generating Macros with AI"
    
    @Published var isScanningBarcode = false
    @Published var barcodeLoadingMessage: String = ""
    
    @Published var isAnalyzingImage = false
    @Published var imageAnalysisMessage: String = ""

    
    // Add the new property
    @Published var isLoggingFood = false
    
    // Add errorMessage property after other published properties, around line 85
    @Published var errorMessage: String? = nil
    
    // Saved meals properties
    @Published var savedMeals: [SavedMeal] = []
    @Published var isLoadingSavedMeals = false
    private var currentSavedMealsPage = 1
    private var hasMoreSavedMeals = true
    @Published var savedLogIds: Set<Int> = [] // Track which log IDs are saved

    // Reference to DayLogsViewModel for updating UI after voice logging
    weak var dayLogsViewModel: DayLogsViewModel?
    
    // Nutrition label name input state
    @Published var showNutritionNameInput = false
    @Published var pendingNutritionData: [String: Any] = [:]
    @Published var pendingMealType = "Lunch"

    
    init() {
        self.networkManager = NetworkManager()
   
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
        resetAndFetchSavedMeals()
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
        
        // Prevent refresh if loading, analyzing food, etc.
        if isLoadingLogs || isLoadingMoreLogs || isLoadingMeals || isScanningFood || isAnalyzingFood || isGeneratingMeal || isGeneratingFood {
            print("⚠️ Skipping refresh because another operation is in progress")
            return
        }
        
        
        // Reset pagination states
        currentPage = 1
        mealCurrentPage = 1
        hasMore = true
        mealsHasMore = true
        
        
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
    func updateFoodLog(
        logId: Int,
        servings: Double? = nil,
        date: Date? = nil,
        mealType: String? = nil,
        notes: String? = nil,
        completion: @escaping (Result<UpdatedFoodLog, Error>) -> Void
    ) {
        guard let email = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        
        networkManager.updateFoodLog(
            userEmail: email,
            logId: logId,
            servings: servings,
            date: date,
            mealType: mealType,
            notes: notes
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let updatedLog):
                    print("✅ Successfully updated food log with ID: \(logId)")
                    
                    // Update the existing log in combinedLogs
                    if let index = self.combinedLogs.firstIndex(where: { $0.foodLogId == logId }) {
                        var updatedCombinedLog = self.combinedLogs[index]
                        
                        // Update the properties with new values
                        updatedCombinedLog.calories = updatedLog.calories
                        updatedCombinedLog.food?.numberOfServings = updatedLog.servings
                        
                        // Update message if meal type changed
                        if let newMealType = mealType {
                            updatedCombinedLog.message = "\(updatedLog.food.displayName) – \(newMealType)"
                            updatedCombinedLog.mealType = newMealType
                        }
                        
                        // Update scheduled date if changed
                        if let newDate = date {
                            updatedCombinedLog.scheduledAt = newDate
                        }
                        
                        self.combinedLogs[index] = updatedCombinedLog
                    }
                    
                    completion(.success(updatedLog))
                    
                case .failure(let error):
                    print("❌ Failed to update food log: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func logFood(
    email: String,
    food: Food,
    meal: String,
    servings: Double,
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
                
                // Track food logging in Mixpanel
                Mixpanel.mainInstance().track(event: "Log Food", properties: [
                    "food_name": loggedFood.food.displayName,
                    "meal_type": loggedFood.mealType,
                    "calories": loggedFood.food.calories,
                    "servings": servings,
                    "log_method": "manual",
                    "user_email": email
                ])
                
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
                
           
                
                // Track the food in recently added - fdcId is non-optional
                self.lastLoggedFoodId = food.fdcId
                self.trackRecentlyAdded(foodId: food.fdcId)
                
               
                
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
        case .activity:
            // Activity logs are always unique since they come from Apple Health
            isUnique = true
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
    // Set macro generation flags to show MacroGenerationCard in DashboardView
    isGeneratingMacros = true
    isLoading = true  // THIS was missing - needed to show the loading card!
    macroGenerationStage = 0
    macroLoadingMessage = "Analyzing food description..."
    showAIGenerationSuccess = false
    
    // Create a timer to cycle through analysis stages for UI feedback
    let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
        guard let self = self else { 
            timer.invalidate()
            return 
        }
        
        // Cycle through macro generation stages 0-3
        self.macroGenerationStage = (self.macroGenerationStage + 1) % 4
        
        // Update loading message based on current stage
        self.macroLoadingMessage = [
            "Analyzing food description...",
            "Generating nutritional data...",
            "Calculating macros...",
            "Finalizing food creation..."
        ][self.macroGenerationStage]
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
            
            // Track AI macro generation in Mixpanel
            Mixpanel.mainInstance().track(event: "AI Text Food Log", properties: [
                "food_name": loggedFood.food.displayName,
                "meal_type": loggedFood.mealType,
                "calories": loggedFood.food.calories ?? 0,
                "food_description": foodDescription,
                "user_email": self.userEmail ?? "unknown"
            ])
            
            // Track universal food logging
            Mixpanel.mainInstance().track(event: "Log Food", properties: [
                "food_name": loggedFood.food.displayName,
                "meal_type": loggedFood.mealType,
                "calories": loggedFood.food.calories ?? 0,
                "servings": 1,
                "log_method": "ai_text",
                "user_email": self.userEmail ?? "unknown"
            ])
            
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
            
      
  
            // Reset macro generation state and show success toast in dashboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isGeneratingMacros = false
                self.isLoading = false  // Clear the loading flag
                self.macroGenerationStage = 0
                self.macroLoadingMessage = ""
                
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
            // Reset macro generation state
            self.isGeneratingMacros = false
            self.isLoading = false  // Clear the loading flag
            self.macroGenerationStage = 0
            self.macroLoadingMessage = ""
            
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
                
                // Add the food to userFoods so it appears in MyFoods tab immediately
                if !self.userFoods.contains(where: { $0.fdcId == food.fdcId }) {
                    self.userFoods.insert(food, at: 0) // Add to beginning of list
                }
                
                // Clear the userFoods cache to force refresh from server next time
                self.clearUserFoodsCache()
                
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
// Add these functions to the FoodManager class to handle deletion
    // Delete a food log
    func deleteFoodLog(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        let repo = LogRepository()
        repo.deleteLogItem(email: email, logId: id, logType: "food") { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.combinedLogs.removeAll { $0.foodLogId == id }
                    self.loggedFoods.removeAll { $0.foodLogId == id } // If still used
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
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
    func deleteMealLog(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        let repo = LogRepository() // Create an instance of LogRepository
        repo.deleteLogItem(email: email, logId: id, logType: "meal") { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Remove from local combinedLogs as well
                    self.combinedLogs.removeAll { $0.mealLogId == id }
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    // Delete a meal template
    func deleteMeal(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        
        // Use networkManager.deleteMeal to delete the meal template
        networkManager.deleteMeal(mealId: id, userEmail: email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Remove from local meals array
                    self.meals.removeAll { $0.id == id }
                    // Also remove any combined logs that might be showing this meal if it was logged
                    // (though this function is for deleting the template, not specific logs of it)
                    self.combinedLogs.removeAll { $0.meal?.id == id }
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func deleteRecipeLog(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        let repo = LogRepository() // Create an instance of LogRepository
        repo.deleteLogItem(email: email, logId: id, logType: "recipe") { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Remove from local combinedLogs as well
                    self.combinedLogs.removeAll { $0.recipeLogId == id }
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    // Function to delete a user-created food
    func deleteUserFood(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let email = userEmail else {
            print("⚠️ Cannot delete user food: User email not set")
            completion(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }

        if let index = userFoods.firstIndex(where: { $0.fdcId == id }) {
            let removedFood = userFoods.remove(at: index)
            networkManager.deleteFood(foodId: id, userEmail: email) { [weak self] result in // Uses networkManager.deleteFood
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Successfully deleted user food with ID: \(id)")
                        completion(.success(()))
                    case .failure(let error):
                        print("❌ Failed to delete user food: \(error)")
                        self.userFoods.insert(removedFood, at: index) // Add back on failure
                        completion(.failure(error))
                    }
                }
            }
        } else {
            print("⚠️ User food with ID \(id) not found in userFoods")
            completion(.failure(NSError(domain: "FoodManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "User food not found"])))
        }
    }
 

// MARK: - Scan-an-image → CombinedLog
@MainActor
func analyzeFoodImage(
  image: UIImage,
  userEmail: String,
  mealType: String = "Lunch",
  completion: @escaping (Result<CombinedLog, Error>) -> Void
) {
  // ─── 1) UI state ─────────────────────────────
  isAnalyzingImage = true
  isLoading        = true
  imageAnalysisMessage = "Analyzing image…"
  uploadProgress   = 0

  // ─── 2) Fake progress ticker ─────────────────


  uploadProgress = 0
let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
  guard let self = self else { t.invalidate(); return }
  // bump progress up to, say, 90%
  self.uploadProgress = min(0.9, self.uploadProgress + 0.1)
}

  // ─── 3) Call backend ─────────────────────────
  networkManager.analyzeFoodImage(image: image, userEmail: userEmail, mealType: mealType) { [weak self] success, payload, errMsg in
    guard let self = self else { return }
    DispatchQueue.main.async {
      // stop ticker + UI
      progressTimer.invalidate()

     withAnimation {
        self.uploadProgress = 1.0
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.isAnalyzingImage = false
        self.isLoading        = false
        self.imageAnalysisMessage = ""

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
        
        // Set success data and show toast - MUST be on main thread
        DispatchQueue.main.async {
           self.lastLoggedItem = (
             name:     loggedFood.food.displayName,
             calories: loggedFood.calories
           )
           self.showLogSuccess = true
           
           DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
             self.showLogSuccess = false
           }
        }
   
        // Track image scanning in Mixpanel
        Mixpanel.mainInstance().track(event: "Image Scan", properties: [
            "food_name": loggedFood.food.displayName,
            "meal_type": loggedFood.mealType,
            "calories": loggedFood.calories,
            "user_email": userEmail
        ])
        
        // Track universal food logging
        Mixpanel.mainInstance().track(event: "Log Food", properties: [
            "food_name": loggedFood.food.displayName,
            "meal_type": loggedFood.mealType,
            "calories": loggedFood.calories,
            "servings": 1,
            "log_method": "image_scan",
            "user_email": userEmail
        ])
        
      } catch {
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

// MARK: - Scan nutrition label → CombinedLog
@MainActor
func analyzeNutritionLabel(
  image: UIImage,
  userEmail: String,
  mealType: String = "Lunch",
  completion: @escaping (Result<CombinedLog, Error>) -> Void
) {
  // ─── 1) UI state ─────────────────────────────
  isAnalyzingImage = true
  isLoading        = true
  imageAnalysisMessage = "Reading nutrition label…"
  uploadProgress   = 0

  // ─── 2) Fake progress ticker ─────────────────
  uploadProgress = 0
  var progressTimer: Timer?
  progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
    guard let self = self else { 
      progressTimer?.invalidate()
      return 
    }
    // bump progress up to, say, 90%
    self.uploadProgress = min(0.9, self.uploadProgress + 0.1)
  }

  // ─── 3) Call backend ─────────────────────────
  networkManager.analyzeNutritionLabel(image: image, userEmail: userEmail, mealType: mealType) { [weak self] success, payload, errMsg in
    guard let self = self else { return }
    
    DispatchQueue.main.async {
      // stop ticker + UI
      progressTimer?.invalidate()

      withAnimation {
        self.uploadProgress = 1.0
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.isAnalyzingImage = false
        self.isLoading        = false
        self.imageAnalysisMessage = ""

        // reset for next time
        self.uploadProgress = 0
      }
    }

    // failure path
    guard success, let payload = payload else {
      let msg = errMsg ?? "Unknown error"
      print("🔴 [analyzeNutritionLabel] error: \(msg)")
      completion(.failure(NSError(
        domain: "FoodManager",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: msg]
      )))
      return
    }

    // ─── 4) Check if name input is required ─────────────────
    if let status = payload["status"] as? String, status == "name_required" {
      // Product name not found - we need user input
      print("🏷️ [analyzeNutritionLabel] Product name not found, user input required")
      
      // Store nutrition data for later use with user-provided name
      if let nutritionData = payload["nutrition_data"] as? [String: Any] {
        // TODO: Show name input dialog and create food with user-provided name
        // For now, return an error to indicate name is needed
        completion(.failure(NSError(
          domain: "FoodManager",
          code: 1001, // Custom code for name required
          userInfo: [
            NSLocalizedDescriptionKey: "Product name not found on label",
            "nutrition_data": nutritionData,
            "meal_type": payload["meal_type"] as? String ?? "Lunch"
          ]
        )))
      } else {
        completion(.failure(NSError(
          domain: "FoodManager",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Invalid nutrition data format"]
        )))
      }
      return
    }

    // ─── 5) Use the SAME parsing as analyzeFoodImage ───────────
    do {
      if let rawJSON = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
         let str     = String(data: rawJSON, encoding: .utf8) {
        print("🔍 [analyzeNutritionLabel] raw payload:\n\(str)")
      }

      // Decode directly into LoggedFood (same as analyzeFoodImage)
      let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
      let decoder  = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase

      let loggedFood = try decoder.decode(LoggedFood.self, from: jsonData)

             // Wrap it in a CombinedLog (same as analyzeFoodImage)
       let combinedLog = CombinedLog(
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

       completion(.success(combinedLog))
       
       // Set success data and show toast (same as analyzeFoodImage) - MUST be on main thread
       DispatchQueue.main.async {
         self.lastLoggedItem = (
           name:     loggedFood.food.displayName,
           calories: loggedFood.calories
         )
         self.showLogSuccess = true
         
         DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
           self.showLogSuccess = false
         }
       }
       
       // Track nutrition label scanning in Mixpanel
       Mixpanel.mainInstance().track(event: "Nutrition Label Scan", properties: [
           "food_name": loggedFood.food.displayName,
           "meal_type": loggedFood.mealType,
           "calories": loggedFood.calories,
           "user_email": userEmail
       ])
       
       // Track universal food logging
       Mixpanel.mainInstance().track(event: "Log Food", properties: [
           "food_name": loggedFood.food.displayName,
           "meal_type": loggedFood.mealType,
           "calories": loggedFood.calories,
           "servings": 1,
           "log_method": "nutrition_label_scan",
           "user_email": userEmail
       ])

    } catch {
      //── 7) On decode error, print the bad JSON + error
      print("❌ [analyzeNutritionLabel] decoding error:", error)
      if let rawJSON = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
         let str     = String(data: rawJSON, encoding: .utf8) {
        print("❌ [analyzeNutritionLabel] payload was:\n\(str)")
      }
      completion(.failure(error))
    }
  }
}

    // // Add this function to handle the barcode scanning logic
    // func lookupFoodByBarcode(barcode: String, image: UIImage? = nil, userEmail: String, completion: @escaping (Bool, String?) -> Void) {
    //     // Set barcode scanning state for UI feedback
    //     isScanningBarcode = true
    //     isLoading = true
    //     barcodeLoadingMessage = "Looking up barcode..."
    //     uploadProgress = 0.3
        
    //     // Convert image to base64 if available
    //     var imageBase64: String? = nil
    //     if let image = image {
    //         if let imageData = image.jpegData(compressionQuality: 0.7) {
    //             imageBase64 = imageData.base64EncodedString()
    //         }
    //     }
        
    //     // Call NetworkManagerTwo to look up the barcode
    //     NetworkManagerTwo.shared.lookupFoodByBarcode(
    //         barcode: barcode,
    //         userEmail: userEmail,
    //         imageData: imageBase64,
    //         mealType: "Lunch", // Default meal type since this method doesn't have mealType parameter
    //         shouldLog: false
    //     ) { [weak self] result in
    //         guard let self = self else { return }
            
    //         // Update progress for UI
    //         self.uploadProgress = 1.0
            
    //         switch result {
    //         case .success(let response):
    //             // Reset barcode scanning state since we'll show the confirmation screen
    //             self.isScanningBarcode = false
    //             self.isLoading = false
    //             self.barcodeLoadingMessage = ""
    //             self.scannedImage = nil
                
    //             // Show the ConfirmFoodView with the barcode data using notification system
    //             DispatchQueue.main.async {
    //                 // Use notification system instead of navigationPath
    //                 NotificationCenter.default.post(
    //                     name: NSNotification.Name("ShowFoodConfirmation"),
    //                     object: nil,
    //                     userInfo: [
    //                         "food": response.food,
    //                         "foodLogId": response.foodLogId
    //                     ]
    //                 )
    //                 completion(true, nil)
    //             }
                
    //         case .failure(let error):
    //             // Update barcode scanner state on failure
    //             self.isScanningBarcode = false
    //             self.isLoading = false
    //             self.barcodeLoadingMessage = ""
    //             self.scannedImage = nil
                
    //             // Set error message for display
    //             let errorMsg: String
    //             if let networkError = error as? NetworkManagerTwo.NetworkError,
    //                case .serverError(let message) = networkError {
    //                 // Use server error message
    //                 errorMsg = message
    //             } else {
    //                 // General error message
    //                 errorMsg = "Could not find food for barcode"
    //             }
                
    //             print("Barcode scan error: \(errorMsg)")
    //             self.scanningFoodError = errorMsg
    //             completion(false, errorMsg)
    //         }
    //     }
    // }
    
    // Original method for backwards compatibility (calls the new method)
    func lookupFoodByBarcode(barcode: String, image: UIImage? = nil, userEmail: String, completion: @escaping (Bool, String?) -> Void) {
        // If we don't have a navigation path, we can't show the confirmation screen
        // This is just a placeholder for backward compatibility
        print("Warning: Using deprecated barcode lookup method without navigation path")
        
        // Set barcode scanning state for UI feedback
        isScanningBarcode = true
        isLoading = true
        barcodeLoadingMessage = "Looking up barcode..."
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
            mealType: "Lunch", // Default meal type since this method doesn't have mealType parameter
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
                
                // Update barcode scanner state
                self.isScanningBarcode = false
                self.isLoading = false
                self.barcodeLoadingMessage = ""
                self.scannedImage = nil
                
                // Return success so the scanner can close
                completion(true, nil)
                
            case .failure(let error):
                // Update barcode scanner state on failure
                self.isScanningBarcode = false
                self.isLoading = false
                self.barcodeLoadingMessage = ""
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
    // MARK: - Direct Barcode Logging (no preview)
    func lookupFoodByBarcodeDirect(barcode: String, userEmail: String, mealType: String = "Lunch", completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Starting direct barcode lookup for: \(barcode)")
        
        // Set barcode scanning states for UI feedback
        isScanningBarcode = true
        isLoading = true
        barcodeLoadingMessage = "Looking up barcode..."
        uploadProgress = 0.2
        
        // Create a timer to cycle through analysis stages for UI feedback
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            // Update barcode loading message
            self.barcodeLoadingMessage = [
                "Looking up barcode...",
                "Searching nutrition databases...",
                "Enhancing with web search...",
                "Finalizing food data..."
            ].randomElement() ?? "Processing barcode..."
            
            // Gradually increase progress
            self.uploadProgress = min(self.uploadProgress + 0.1, 0.9)
        }
        
        // Call the enhanced barcode lookup endpoint with shouldLog = true
        NetworkManagerTwo.shared.lookupFoodByBarcode(
            barcode: barcode,
            userEmail: userEmail,
            imageData: nil,
            mealType: mealType,
            shouldLog: true  // Log directly, no preview
        ) { [weak self] result in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Stop the timer and update progress
            timer.invalidate()
            self.uploadProgress = 1.0
            
            switch result {
            case .success(let payload):
                let food = payload.food
                
                print("✅ Direct barcode lookup successful: \(food.displayName)")
                
                // Track barcode scanning in Mixpanel
                Mixpanel.mainInstance().track(event: "Barcode Scan", properties: [
                    "food_name": food.displayName,
                    "barcode": barcode,
                    "calories": food.calories ?? 0,
                    "user_email": userEmail
                ])
                
                // Create combined log for UI update
                let combinedLog = CombinedLog(
                    type: .food,
                    status: "success",
                    calories: food.calories ?? 0,
                    message: "Barcode scan: \(barcode) - \(food.displayName)",
                    foodLogId: payload.foodLogId,
                    food: food.asLoggedFoodItem,
                    mealType: mealType,
                    mealLogId: nil,
                    meal: nil,
                    mealTime: nil,
                    scheduledAt: Date(),
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil
                )
                
                // Add to logs
                DispatchQueue.main.async {
                    self.dayLogsViewModel?.addPending(combinedLog)
                    
                    if let idx = self.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                        self.combinedLogs.remove(at: idx)
                    }
                    self.combinedLogs.insert(combinedLog, at: 0)
                    
                    // Show success message
                    self.lastLoggedItem = (name: food.displayName, calories: food.calories ?? 0)
                    self.showLogSuccess = true
                    
                    // Reset barcode scanning states
                    self.isScanningBarcode = false
                    self.isLoading = false
                    self.barcodeLoadingMessage = ""
                    
                    // Auto-hide success message after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showLogSuccess = false
                    }
                    
                    completion(true, nil)
                }
                
            case .failure(let error):
                print("❌ Direct barcode lookup failed: \(error)")
                
                DispatchQueue.main.async {
                    // Reset barcode scanning states
                    self.isScanningBarcode = false
                    self.isLoading = false
                    self.barcodeLoadingMessage = ""
                    
                    // Set error message
                    let errorMsg: String
                    if let networkError = error as? NetworkManagerTwo.NetworkError,
                       case .serverError(let message) = networkError {
                        errorMsg = message
                    } else {
                        errorMsg = "Could not find food for barcode"
                    }
                    
                    self.scanningFoodError = errorMsg
                    completion(false, errorMsg)
                }
            }
        }
    }
    
    // MARK: - Enhanced Barcode Lookup
    func lookupFoodByBarcodeEnhanced(barcode: String, userEmail: String, mealType: String = "Lunch", completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Starting enhanced barcode lookup for: \(barcode)")
        
        // Set barcode scanning states for UI feedback
        isScanningBarcode = true  // This triggers BarcodeAnalysisCard in DashboardView
        isLoading = true
        barcodeLoadingMessage = "Looking up barcode..."
        uploadProgress = 0.2
        
        // Create a timer to cycle through analysis stages for UI feedback
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            // Update barcode loading message
            self.barcodeLoadingMessage = [
                "Looking up barcode...",
                "Searching nutrition databases...",
                "Enhancing with web search...",
                "Finalizing food data..."
            ].randomElement() ?? "Processing barcode..."
            
            // Gradually increase progress
            self.uploadProgress = min(self.uploadProgress + 0.1, 0.9)
        }
        
        // Call the enhanced barcode lookup endpoint
        NetworkManagerTwo.shared.lookupFoodByBarcode(
            barcode: barcode,
            userEmail: userEmail,
            imageData: nil,  // No image for barcode-only lookup
            mealType: mealType,
            shouldLog: false  // Don't log automatically, let user confirm first
        ) { [weak self] result in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Stop the timer and update progress
            timer.invalidate()
            self.uploadProgress = 1.0
            
            switch result {
            case .success(let payload):
                let food = payload.food
                
                print("✅ Enhanced barcode lookup successful: \(food.displayName)")
                
                // Track barcode scanning in Mixpanel
                Mixpanel.mainInstance().track(event: "Barcode Scan", properties: [
                    "food_name": food.displayName,
                    "barcode": barcode,
                    "calories": food.calories ?? 0,
                    "user_email": userEmail
                ])
                
                // Track universal food logging (for barcode identification, not actual logging)
                Mixpanel.mainInstance().track(event: "Barcode Food Identified", properties: [
                    "food_name": food.displayName,
                    "barcode": barcode,
                    "calories": food.calories ?? 0,
                    "user_email": userEmail
                ])
                
                // Store the food for confirmation
                self.aiGeneratedFood = food.asLoggedFoodItem
                self.lastLoggedFoodId = food.fdcId
                
                // Reset barcode scanning states
                self.isScanningBarcode = false
                self.isLoading = false
                self.barcodeLoadingMessage = ""
                
                // Create a CombinedLog for optimistic UI update (but don't add to logs yet)
                let combinedLog = CombinedLog(
                    type: .food,
                    status: "success",
                    calories: food.calories ?? 0,
                    message: "Barcode scan: \(barcode) - \(food.displayName)",
                    foodLogId: nil,  // No log ID yet since not confirmed
                    food: food.asLoggedFoodItem,
                    mealType: mealType,
                    mealLogId: nil,
                    meal: nil,
                    mealTime: nil,
                    scheduledAt: Date(),
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil
                )
                
                // Show success message briefly
                self.lastLoggedItem = (name: food.displayName, calories: food.calories ?? 0)
                self.showLogSuccess = true
                
                // Auto-hide success message after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showLogSuccess = false
                }
                
                // Trigger navigation to confirmation view
                // This will be handled by the DashboardView or ContentView
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowFoodConfirmation"),
                    object: nil,
                    userInfo: [
                        "food": food,
                        "barcode": barcode
                    ]
                )
                
                completion(true, nil)
                
            case .failure(let error):
                print("❌ Enhanced barcode lookup failed: \(error)")
                
                // Reset barcode scanning states
                self.isScanningBarcode = false
                self.isLoading = false
                self.barcodeLoadingMessage = ""
                
                // Set error message
                let errorMsg: String
                if let networkError = error as? NetworkManagerTwo.NetworkError,
                   case .serverError(let message) = networkError {
                    errorMsg = message
                } else {
                    errorMsg = "Could not find food for barcode"
                }
                
                self.scanningFoodError = errorMsg
                completion(false, errorMsg)
            }
        }
    }

    // MARK: - Voice Input Processing
    func processVoiceInput(audioData: Data) {
        // Set macro generation flag - same as when generating macros with AI
        isGeneratingMacros = true
        macroGenerationStage = 0
        showAIGenerationSuccess = false
        
        // Create a timer to cycle through analysis stages for UI feedback
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            // Cycle through macro generation stages 0-3
            self.macroGenerationStage = (self.macroGenerationStage + 1) % 4
            self.macroLoadingMessage = [
                "Transcribing your voice...",
                "Analyzing food description...",
                "Generating nutritional data...",
                "Finalizing your food log..."
            ][self.macroGenerationStage]
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
                    
                    // Reset macro generation flags
                    self.isGeneratingMacros = false
                    
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
                        
                 
                        
                    case .failure(let error):
                        print("Failed to generate AI macros: \(error.localizedDescription)")
                        self.error = error
                    }
                }
                
            case .failure(let error):
                // Stop the timer and reset flags if transcription fails
                timer.invalidate()
                self.isGeneratingMacros = false
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
    func processVoiceRecording(audioData: Data, mealType: String = "Lunch") {
        print("🍽️ FoodManager.processVoiceRecording called with mealType: \(mealType)")
        
        // Set macro generation flags for proper UI display (on main thread)
        DispatchQueue.main.async {
            self.isGeneratingMacros = true  // This triggers MacroGenerationCard
            self.isLoading = true  // This is what makes the loading card visible in DashboardView
            self.macroGenerationStage = 0
            self.showAIGenerationSuccess = false
            self.macroLoadingMessage = "Transcribing your voice…"  // Initial stage message
        }
        
        // Create a timer to cycle through analysis stages for UI feedback
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            // Cycle through macro generation stages (on main thread)
            DispatchQueue.main.async {
                self.macroGenerationStage = (self.macroGenerationStage + 1) % 4
                
                // Update loading message based on current stage
                self.macroLoadingMessage = [
                    "Transcribing your voice…",
                    "Analyzing food description…",
                    "Generating nutritional data…",
                    "Finalizing your food log…"
                ][self.macroGenerationStage]
            }
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
                print("🍽️ Calling generateMacrosWithAI with mealType: \(mealType)")
                self.generateMacrosWithAI(foodDescription: text, mealType: mealType) { result in
                    // Use defer to ensure flags are always reset
                    defer {
                        // Stop the analysis animation timer
                        timer.invalidate()
                        
                        // Reset macro generation flags (on main thread)
                        DispatchQueue.main.async {
                            self.isGeneratingMacros = false
                            self.isLoading = false
                            self.macroGenerationStage = 0
                            self.macroLoadingMessage = ""
                        }
                    }
                    
                    switch result {
                    case .success(let loggedFood):
                        print("✅ Voice log successfully processed: \(loggedFood.food.displayName)")
                               // Track voice logging in Mixpanel
                        Mixpanel.mainInstance().track(event: "Voice Log", properties: [
                            "food_name": loggedFood.food.displayName,
                            "meal_type": loggedFood.mealType,
                            "calories": loggedFood.calories,
                            "user_email": self.userEmail ?? "unknown"
                        ])
                        
                        // Track universal food logging
                        Mixpanel.mainInstance().track(event: "Log Food", properties: [
                            "food_name": loggedFood.food.displayName,
                            "meal_type": loggedFood.mealType,
                            "calories": loggedFood.calories,
                            "servings": 1,
                            "log_method": "voice",
                            "user_email": self.userEmail ?? "unknown"
                        ])
                        // Check if this is an "Unknown food" with no nutritional value
                        // This happens when the server couldn't identify a food from the transcription
                        if loggedFood.food.displayName.lowercased().contains("unknown food") || 
                           (loggedFood.food.calories == 0 && loggedFood.food.protein == 0 && 
                            loggedFood.food.carbs == 0 && loggedFood.food.fat == 0) {
                            
                            // Set error for user notification (on main thread)
                            DispatchQueue.main.async {
                                self.scanningFoodError = "Food not identified. Please try again."
                            }
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
                        
                        // Add to DayLogsViewModel to update the UI (must be on main thread)
                        DispatchQueue.main.async {
                            self.dayLogsViewModel?.addPending(combinedLog)
                            
                            // Also add to the global timeline, de-duplicating first
                            if let idx = self.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                                self.combinedLogs.remove(at: idx)
                            }
                            self.combinedLogs.insert(combinedLog, at: 0)
                        }
                        
                        // Track the food in recently added (on main thread)
                        DispatchQueue.main.async {
                            self.lastLoggedFoodId = loggedFood.food.fdcId
                            self.trackRecentlyAdded(foodId: loggedFood.food.fdcId)
                            
                            // Save the generated food for the toast
                            self.aiGeneratedFood = loggedFood.food
                            
                            // Show success toast
                            self.showAIGenerationSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                self.showAIGenerationSuccess = false
                            }
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
                        // Set error message for user notification in DashboardView (on main thread)
                        DispatchQueue.main.async {
                            if let networkError = error as? NetworkError, case .serverError(let message) = networkError {
                                self.scanningFoodError = message
                            } else {
                                self.scanningFoodError = "Failed to process voice input: \(error.localizedDescription)"
                            }
                        }
                        
                        print("❌ Failed to generate macros from voice input: \(error.localizedDescription)")
                    }
                }
                
            case .failure(let error):
                // Stop the timer and reset macro generation state (on main thread)
                timer.invalidate()
                DispatchQueue.main.async {
                    self.isGeneratingMacros = false
                    self.isLoading = false
                    self.macroGenerationStage = 0
                    self.macroLoadingMessage = ""
                    
                    // Set error message for user notification in DashboardView
                    if let networkError = error as? NetworkError, case .serverError(let message) = networkError {
                        self.scanningFoodError = message
                    } else {
                        self.scanningFoodError = "Failed to transcribe voice input: \(error.localizedDescription)"
                    }
                }
                
                print("❌ Voice transcription failed: \(error.localizedDescription)")
            }
        }
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
                    
                    // Track food logging in Mixpanel
                    Mixpanel.mainInstance().track(event: "Log Food", properties: [
                        "food_name": loggedFood.food.displayName,
                        "meal_type": loggedFood.mealType,
                        "calories": loggedFood.food.calories,
                        "servings": 1,
                        "log_method": "confirmation",
                        "user_email": email
                    ])
                    
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
                
                    
                    // Track the food in recently added - fdcId is non-optional
                    self.lastLoggedFoodId = food.fdcId
                    self.trackRecentlyAdded(foodId: food.fdcId)
                    
            
                    
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
    
    
 


   
   
    // Helper method to get the device's timezone offset in minutes
    private func getTimezoneOffsetInMinutes() -> Int {
        return TimeZone.current.secondsFromGMT() / 60
    }
    
    // MARK: - Saved Meals Functions
    
    private func resetAndFetchSavedMeals() {
        print("💾 FoodManager: Reset and fetch saved meals called")
        currentSavedMealsPage = 1
        hasMoreSavedMeals = true
        savedMeals = []
        loadSavedMeals(refresh: true)
    }
    
    func refreshSavedMeals() {
        print("🔄 FoodManager: Refreshing saved meals")
        currentSavedMealsPage = 1
        hasMoreSavedMeals = true
        loadSavedMeals(refresh: true)
    }
    
    private func loadSavedMeals(refresh: Bool = false) {
        guard let email = userEmail else { return }
        guard !isLoadingSavedMeals else { return }
        
        isLoadingSavedMeals = true
        let pageToLoad = refresh ? 1 : currentSavedMealsPage
        
        NetworkManagerTwo.shared.getSavedMeals(
            userEmail: email,
            page: pageToLoad
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingSavedMeals = false
                
                switch result {
                case .success(let response):
                    if refresh {
                        self.savedMeals = response.savedMeals
                        self.currentSavedMealsPage = 2
                        // Reset and rebuild saved log IDs
                        self.savedLogIds.removeAll()
                    } else {
                        self.savedMeals.append(contentsOf: response.savedMeals)
                        self.currentSavedMealsPage += 1
                    }
                    
                    // Update saved log IDs
                    for savedMeal in response.savedMeals {
                        if savedMeal.itemType == .foodLog, let foodLog = savedMeal.foodLog, let foodLogId = foodLog.foodLogId {
                            self.savedLogIds.insert(foodLogId)
                            print("💾 Added foodLogId \(foodLogId) to savedLogIds")
                        } else if savedMeal.itemType == .mealLog, let mealLog = savedMeal.mealLog, let mealLogId = mealLog.mealLogId {
                            self.savedLogIds.insert(mealLogId)
                            print("💾 Added mealLogId \(mealLogId) to savedLogIds")
                        }
                    }
                    
                    self.hasMoreSavedMeals = response.hasMore

                    
                case .failure(let error):
                    print("❌ Failed to load saved meals: \(error)")
                    self.errorMessage = "Failed to load saved meals: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func saveMeal(itemType: SavedItemType, itemId: Int, customName: String? = nil, notes: String? = nil, completion: @escaping (Result<SaveMealResponse, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NetworkManagerTwo.NetworkError.serverError(message: "User email not available")))
            return
        }
        
        let itemTypeString = itemType == .foodLog ? "food_log" : "meal_log"
        
        NetworkManagerTwo.shared.saveMeal(
            userEmail: email,
            itemType: itemTypeString,
            itemId: itemId,
            customName: customName,
            notes: notes
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Successfully saved meal: \(response.message)")
                    // Refresh the saved meals list to include the new item
                    self?.refreshSavedMeals()
                    
                    // Add to saved log IDs
                    self?.savedLogIds.insert(itemId)
                    
                    // Show saved meal toast
                    self?.showSavedMealToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.showSavedMealToast = false
                    }
                    
                    completion(.success(response))
                    
                case .failure(let error):
                    print("❌ Failed to save meal: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func unsaveMeal(savedMealId: Int, completion: @escaping (Result<UnsaveMealResponse, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NetworkManagerTwo.NetworkError.serverError(message: "User email not available")))
            return
        }
        
        NetworkManagerTwo.shared.unsaveMeal(
            userEmail: email,
            savedMealId: savedMealId
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Successfully unsaved meal: \(response.message)")
                    // Remove the item from the local array and update saved log IDs
                    if let removedMeal = self?.savedMeals.first(where: { $0.id == savedMealId }) {
                        if removedMeal.itemType == .foodLog, let foodLog = removedMeal.foodLog, let foodLogId = foodLog.foodLogId {
                            self?.savedLogIds.remove(foodLogId)
                        } else if removedMeal.itemType == .mealLog, let mealLog = removedMeal.mealLog, let mealLogId = mealLog.mealLogId {
                            self?.savedLogIds.remove(mealLogId)
                        }
                    }
                    self?.savedMeals.removeAll { $0.id == savedMealId }
                    
                    // Show unsaved meal toast
                    self?.showUnsavedMealToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.showUnsavedMealToast = false
                    }
                    
                    completion(.success(response))
                    
                case .failure(let error):
                    print("❌ Failed to unsave meal: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Helper function to check if a log is saved
    func isLogSaved(foodLogId: Int? = nil, mealLogId: Int? = nil) -> Bool {
        if let foodLogId = foodLogId {
            return savedLogIds.contains(foodLogId)
        } else if let mealLogId = mealLogId {
            return savedLogIds.contains(mealLogId)
        }
        return false
    }
    
    // Helper function to find saved meal by log ID and unsave it
    func unsaveByLogId(foodLogId: Int? = nil, mealLogId: Int? = nil, completion: @escaping (Result<UnsaveMealResponse, Error>) -> Void) {
        var targetSavedMeal: SavedMeal?
        
        if let foodLogId = foodLogId {
            targetSavedMeal = savedMeals.first { savedMeal in
                savedMeal.itemType == .foodLog && savedMeal.foodLog?.foodLogId == foodLogId
            }
        } else if let mealLogId = mealLogId {
            targetSavedMeal = savedMeals.first { savedMeal in
                savedMeal.itemType == .mealLog && savedMeal.mealLog?.mealLogId == mealLogId
            }
        }
        
        guard let savedMeal = targetSavedMeal else {
            completion(.failure(NetworkManagerTwo.NetworkError.serverError(message: "Saved meal not found")))
            return
        }
    }
    
    // MARK: - Nutrition Label Name Input
    func createNutritionLabelFoodWithName(_ productName: String, completion: @escaping (Result<CombinedLog, Error>) -> Void) {
        guard !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let userEmail = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid product name or user email"])))
            return
        }
        
        print("🏷️ Creating nutrition label food with user-provided name: \(productName)")
        
        // Call the backend API to create food with the user-provided name and stored nutrition data
        let parameters: [String: Any] = [
            "user_email": userEmail,
            "name": productName.trimmingCharacters(in: .whitespacesAndNewlines),
            "nutrition_data": pendingNutritionData,
            "meal_type": pendingMealType
        ]
        
        // Create the food using NetworkManager
        guard let url = URL(string: "\(networkManager.baseUrl)/create_nutrition_label_food/") else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Network error creating nutrition label food: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    if let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Parse as LoggedFood and create CombinedLog (same as successful nutrition label scan)
                        let jsonData = try JSONSerialization.data(withJSONObject: payload)
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        
                        let loggedFood = try decoder.decode(LoggedFood.self, from: jsonData)
                        
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
                            scheduledAt: Date(),
                            recipeLogId: nil,
                            recipe: nil,
                            servingsConsumed: nil
                        )
                        
                        // Check if we should show the sheet based on user preference
                        let shouldShowSheet = UserDefaults.standard.bool(forKey: "scanPreview_foodLabel")
                        
                        if shouldShowSheet {
                                // Show confirmation sheet for food label (similar to barcode)
                                let food = loggedFood.food.asFood
                            print("📊 Food label preview enabled - showing confirmation sheet")
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ShowFoodConfirmation"),
                                object: nil,
                                userInfo: [
                                    "food": food,
                                    "foodLogId": loggedFood.foodLogId ?? NSNull()
                                ]
                            )
                        } else {
                            // Add to logs directly (same as successful scan)
                            print("📊 Food label preview disabled - logging directly")
                            self.dayLogsViewModel?.addPending(combinedLog)
                            
                            if let idx = self.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                                self.combinedLogs.remove(at: idx)
                            }
                            self.combinedLogs.insert(combinedLog, at: 0)
                        }
                        
                        // Clear the pending state
                        self.showNutritionNameInput = false
                        self.pendingNutritionData = [:]
                        self.pendingMealType = "Lunch"
                        
                        completion(.success(combinedLog))
                        print("✅ Successfully created nutrition label food with user-provided name")
                    }
                } catch {
                    print("❌ Failed to parse response: \(error)")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func cancelNutritionNameInput() {
        showNutritionNameInput = false
        pendingNutritionData = [:]
        pendingMealType = "Lunch"
    }
}

