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
    
    init() {
        self.networkManager = NetworkManager()
    }

    
    
    func initialize(userEmail: String) {
        print("FoodManager: Initializing with email \(userEmail)")
        self.userEmail = userEmail
        resetAndFetchFoods()
           resetAndFetchMeals() // Add this line
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
    currentPage = 1
    hasMore = true
    combinedLogs.removeAll()
    loadCachedLogs()
    loadMoreLogs(refresh: true)
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

private func loadCachedLogs() {
    guard let userEmail = userEmail else { return }
    if let cached = UserDefaults.standard.data(forKey: "combined_logs_\(userEmail)_page_1"),
       let decodedResponse = try? JSONDecoder().decode(CombinedLogsResponse.self, from: cached) {
        self.combinedLogs = decodedResponse.logs
        self.hasMore = decodedResponse.hasMore
    }
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
    guard let email = userEmail else { return }
    guard !isLoading else { return }
    
    let pageToLoad = refresh ? 1 : currentPage
    isLoading = true
    error = nil

    networkManager.getCombinedLogs(userEmail: email, page: pageToLoad) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let response):
                if refresh {
                    self.combinedLogs = response.logs
                    self.currentPage = 2
                } else {
                    self.combinedLogs.append(contentsOf: response.logs)
                    self.currentPage += 1
                }
                self.hasMore = response.hasMore
                self.cacheLogs(response, forPage: pageToLoad)
            case .failure(let error):
                self.error = error
                self.hasMore = false
            }
        }
    }
}

    
    // New refresh function replaces any old refreshLoggedFoods implementation
    func refresh() {
        print("🔄 Starting refresh...")
        resetAndFetchLogs()
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
                print("📊 Logged foods count before insert: \(self.loggedFoods.count)")
                print("🔍 First few IDs before insert: \(self.loggedFoods.prefix(3).map { $0.foodLogId })")
                
                // Remove an existing log for the same food (using the unique USDA id)
                if let existingIndex = self.loggedFoods.firstIndex(where: {
                    $0.food.fdcId == food.fdcId
                }) {
                    self.loggedFoods.removeAll(where: { $0.food.fdcId == food.fdcId })
                }
                
                // Insert the newly logged food at the top.
                self.loggedFoods.insert(loggedFood, at: 0)

                // Mark this food as recently logged.
                self.lastLoggedFoodId = food.fdcId
                
                // Clear the flag after 2 seconds.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.lastLoggedFoodId = nil
                    }
                }
                
                // Update the cached first page with the new ordering.
                let firstPageFoods = Array(self.loggedFoods.prefix(self.pageSize))
                let response = FoodLogsResponse(
                    foodLogs: firstPageFoods,
                    hasMore: self.loggedFoods.count > self.pageSize,
                    totalPages: (self.loggedFoods.count + self.pageSize - 1) / self.pageSize,
                    currentPage: 1
                )
                self.cacheFoods(response, forPage: 1)
                print("💾 Cached first page with IDs: \(firstPageFoods.map { $0.foodLogId })")
                
                // Refresh combined logs
                self.resetAndFetchLogs()
                
                withAnimation {
                    self.showToast = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        self.showToast = false
                    }
                }
                
                completion(.success(loggedFood))
                
            case .failure(let error):
                print("❌ Failed to log food: \(error)")
                self.error = error
                completion(.failure(error))
            }
        }
    }
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
                
                // Mark this meal as recently logged
                self.lastLoggedMealId = meal.id
                
                // Refresh the combined logs
                self.resetAndFetchLogs()
                
                // Show toast notification
                withAnimation {
                    self.showMealLoggedToast = true
                }
                
                // Clear the flag after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.lastLoggedMealId = nil
                        self.showMealLoggedToast = false
                    }
                }
                
                completion?(.success(loggedMeal))
                
            case .failure(let error):
                print("❌ Failed to log meal: \(error)")
                self.error = error
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

}
