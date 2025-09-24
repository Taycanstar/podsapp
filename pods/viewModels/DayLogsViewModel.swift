//
//  DayLogsViewModel.swift
//  Pods
//
//  Created by Dimi Nunez on 5/11/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class DayLogsViewModel: ObservableObject {
      @Published var logs         : [CombinedLog] = [] {
    didSet { recalculateTotals() }
  }
  @Published var calorieGoal      : Double = 2_000
  @Published var proteinGoal      : Double = 150
  @Published var carbsGoal        : Double = 200
  @Published var fatGoal          : Double = 70
@Published var remainingCalories: Double = 2_000   // always ≥ 0

  private var pendingByDate: [Date: [CombinedLog]] = [:]
  @Published var error        : Error?
  @Published var isLoading    = false
  @Published var selectedDate = Date()

  private var lastEmail: String?
  private var lastLoadTimestamps: [Date: Date] = [:]
  private let logsRefreshInterval: TimeInterval = 60

  // Daily totals
  @Published var totalCalories: Double = 0
  @Published var totalProtein : Double = 0
  @Published var totalCarbs   : Double = 0
  @Published var totalFat     : Double = 0
  
  // Computed property for total calories burned (HealthKit + AI activities)
  var totalCaloriesBurned: Double {
      // Get HealthKit active energy
      let healthKitCalories = healthViewModel?.activeEnergy ?? 0
      
      // Add AI activity calories from today's logs
      let aiActivityCalories = logs.reduce(0.0) { sum, log in
          guard log.type == .activity else { return sum }
          // Only count AI activities (not HealthKit activities)
          if let activityId = log.activityId, !activityId.contains("-") {
              // This is an AI activity (integer ID format)
              return sum + log.calories
          }
          return sum
      }
      
      return healthKitCalories + aiActivityCalories
  }
  
  // User measurements from onboarding
  @Published var height: Double = 0 // Height in cm
  @Published var weight: Double = 0 // Weight in kg
  @Published var desiredWeightKg: Double = 0 // Desired weight in kg
  @Published var desiredWeightLbs: Double = 0 // Desired weight in lbs
  
  // Water logs for the current day
  @Published var waterLogs: [WaterLogResponse] = []
  
  // Navigation properties
  @Published var navigateToEditHeight: Bool = false
  @Published var navigateToEditWeight: Bool = false
  @Published var navigateToWeightData: Bool = false

  private let repository = DayLogsRepository.shared
  private let logNetwork = LogRepository()
  private(set) var email = ""
  private weak var healthViewModel: HealthKitViewModel?
  private var cancellables: Set<AnyCancellable> = []

  init(email: String = "", healthViewModel: HealthKitViewModel? = nil) {
    self.email = email
    self.healthViewModel = healthViewModel
    clearPendingCache()

    if !email.isEmpty {
      configureRepository(for: email)
      fetchNutritionGoals()
    }
  }

  func setEmail(_ newEmail: String) {
    email = newEmail
    lastEmail = newEmail
    fetchNutritionGoals()
    // Clear pending cache when switching users
    clearPendingCache()
    configureRepository(for: newEmail)
  }
  
  func preloadForStartup(email: String) {
    if lastEmail != email {
        setEmail(email)
    }

    let key = Calendar.current.startOfDay(for: selectedDate)
    if let lastLoad = lastLoadTimestamps[key], Date().timeIntervalSince(lastLoad) < logsRefreshInterval,
       !logs.isEmpty {
        return
    }

    loadLogs(for: selectedDate)
  }
  
  func setHealthViewModel(_ healthViewModel: HealthKitViewModel) {
    self.healthViewModel = healthViewModel
  }

  private func configureRepository(for email: String) {
    repository.configure(email: email)
    cancellables.removeAll()

    repository.$snapshots
      .receive(on: DispatchQueue.main)
      .sink { [weak self] snapshots in
        guard let self else { return }
        let key = Calendar.current.startOfDay(for: self.selectedDate)
        if let snapshot = snapshots[key] {
          self.applySnapshot(snapshot)
        }
      }
      .store(in: &cancellables)

    if let snapshot = repository.snapshot(for: selectedDate) {
      applySnapshot(snapshot)
    }
  }

  // MARK: - Public Methods
  
  /// Force refresh nutrition goals from UserDefaults
  /// This ensures the ViewModel has the most up-to-date values
  func refreshNutritionGoals() {
    fetchNutritionGoals()
  }


  // MARK: – Goal helpers ------------------------------------------------------
 func fetchCalorieGoal() {
    // 1) Highest priority: explicit dailyCalorieGoal if non-zero
    if let g = UserDefaults.standard.value(forKey: "dailyCalorieGoal") as? Double, g > 0 {
        calorieGoal = g
    }
    // 2) Next: nutritionGoalsData if non-zero
    else if let data = UserDefaults.standard.data(forKey: "nutritionGoalsData"),
              let goals = try? JSONDecoder().decode(NutritionGoals.self, from: data),
              goals.calories > 0 {
        calorieGoal = goals.calories
    }
    // 3) Next: UserGoalsManager (may have been saved earlier); ignore zeros
    else if UserGoalsManager.shared.dailyGoals.calories > 0 {
        calorieGoal = Double(UserGoalsManager.shared.dailyGoals.calories)
    }
    // 4) Fallback: sensible default
    else {
        calorieGoal = 2000
    }
    remainingCalories = max(0, calorieGoal - totalCalories)
}

 func fetchNutritionGoals() {
    // First try to fetch the calorie goal (keeps existing logic)
    fetchCalorieGoal()
    
    // Then fetch protein, carbs, and fat goals
    if let data = UserDefaults.standard.data(forKey: "nutritionGoalsData"),
       let goals = try? JSONDecoder().decode(NutritionGoals.self, from: data) {
        proteinGoal = goals.protein
        carbsGoal = goals.carbs
        fatGoal = goals.fat
        
        // Store desired weight if available
        if let desiredKg = goals.desiredWeightKg {
            desiredWeightKg = desiredKg
            // Convert kg to lbs if desiredWeightLbs is not available
            desiredWeightLbs = goals.desiredWeightLbs ?? (desiredKg * 2.20462)
        } else if let desiredLbs = goals.desiredWeightLbs {
            desiredWeightLbs = desiredLbs
            // Convert lbs to kg if desiredWeightKg is not available
            desiredWeightKg = desiredLbs / 2.20462
        }
    } else {
        // Use UserGoalsManager for defaults
        proteinGoal = Double(UserGoalsManager.shared.dailyGoals.protein)
        carbsGoal = Double(UserGoalsManager.shared.dailyGoals.carbs)
        fatGoal = Double(UserGoalsManager.shared.dailyGoals.fat)
    }
}



func addPending(_ log: CombinedLog) {
  let key = Calendar.current.startOfDay(for: log.scheduledAt!)
    print("[DayLogsVM] addPending( id:\(log.id), dateKey:\(key) )")

  var arr = pendingByDate[key] ?? []

  // don't double-insert the same ID
  guard !arr.contains(where: { $0.id == log.id }) else { return }

  arr.insert(log, at: 0)
  pendingByDate[key] = arr

  if Calendar.current.isDate(log.scheduledAt!, inSameDayAs: selectedDate) {
    // again, guard against duplicates in the live `logs` array
    if !logs.contains(where: { $0.id == log.id }) {
      logs.insert(log, at: 0)
      
      // Re-sort logs to maintain chronological order (most recent first)
      logs.sort { log1, log2 in
        let date1 = log1.scheduledAt ?? Date.distantPast
        let date2 = log2.scheduledAt ?? Date.distantPast
        return date1 > date2  // Most recent first
      }
      
      print("[DayLogsVM] logs.inserted \(log.id), logs now = \(logs.map { $0.id })")
    }
  }
  
  // Trigger profile data refresh since logs changed
  triggerProfileDataRefresh()
  
  // Update streak when any activity is logged
  StreakManager.shared.updateStreak(activityDate: log.scheduledAt ?? Date())
}

func removeLog(_ log: CombinedLog) async {
    print("[DayLogsVM] removeLog( id:\(log.id), type:\(log.type) ) – optimistic remove + server sync")

    // Keep backups for rollback on failure
    let previousLogs = logs
    let previousPending = pendingByDate

    // 1) Optimistic local removal for immediate UI feedback
    logs.removeAll { $0.id == log.id }

    if let scheduledAt = log.scheduledAt {
        let key = Calendar.current.startOfDay(for: scheduledAt)
        if var pendingLogs = pendingByDate[key] {
            pendingLogs.removeAll { $0.id == log.id }
            pendingByDate[key] = pendingLogs
        }
    }

    print("[DayLogsVM] Optimistically removed log \(log.id); remaining = \(logs.map { $0.id })")
    triggerProfileDataRefresh()

    // 2) Attempt server deletion
    do {
        try await deleteOnServer(log)
        print("[DayLogsVM] ✅ Server deletion succeeded for log \(log.id)")
        // Success – nothing else to do
    } catch {
        // 3) Rollback on failure and surface error to UI
        print("[DayLogsVM] ❌ Server deletion failed for log \(log.id): \(error.localizedDescription). Rolling back…")
        logs = previousLogs
        pendingByDate = previousPending
        self.error = error
        triggerProfileDataRefresh()
    }
}

// Bridge deletion endpoints behind a single async function
private func deleteOnServer(_ log: CombinedLog) async throws {
    switch log.type {
    case .food:
        guard let foodLogId = log.foodLogId else {
            throw NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing food log ID"])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            logNetwork.deleteLogItem(email: email, logId: foodLogId, logType: "food") { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        }

    case .meal:
        guard let mealLogId = log.mealLogId else {
            throw NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing meal log ID"])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            logNetwork.deleteLogItem(email: email, logId: mealLogId, logType: "meal") { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        }

    case .recipe:
        guard let recipeLogId = log.recipeLogId else {
            throw NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing recipe log ID"])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            logNetwork.deleteLogItem(email: email, logId: recipeLogId, logType: "recipe") { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        }

    case .activity:
        // HealthKit activities (UUID-style) cannot be deleted from server – ignore server sync
        guard let activityId = log.activityId else {
            throw NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing activity ID"])
        }
        let isHealthKit = activityId.count > 10 && activityId.contains("-")
        if isHealthKit {
            // No server-side deletion for HealthKit entries; keep local removal
            print("[DayLogsVM] Skipping server deletion for HealthKit activity: \(activityId)")
            return
        }
        guard let aiActivityLogId = Int(activityId) else {
            throw NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid AI activity ID"])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NetworkManagerTwo.shared.deleteActivityLog(activityLogId: aiActivityLogId) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        }
    }
}

func loadLogs(for date: Date, force: Bool = false) {
  selectedDate = date

  let key = Calendar.current.startOfDay(for: date)
  if !force,
     let lastLoad = lastLoadTimestamps[key], Date().timeIntervalSince(lastLoad) < logsRefreshInterval,
     !logs.isEmpty {
    return
  }

  isLoading = true
  error = nil

  Task {
    await repository.refresh(date: date, force: force)
    if let snapshot = repository.snapshot(for: date) {
      applySnapshot(snapshot)
    } else {
      await MainActor.run {
        self.isLoading = false
      }
    }
  }
}

private func applySnapshot(_ snapshot: DayLogsSnapshot) {
  let key = Calendar.current.startOfDay(for: snapshot.date)
  let serverLogs = snapshot.combined
  let pending = pendingByDate[key] ?? []
  let dedupedPending = pending.filter { item in
    !serverLogs.contains(where: { $0.id == item.id })
  }
  pendingByDate[key] = dedupedPending

  let activityLogs = getActivityLogsFromHealth(for: snapshot.date)
  let combinedLogs = dedupedPending + serverLogs + activityLogs

  logs = combinedLogs.sorted { log1, log2 in
    let date1 = log1.scheduledAt ?? Date.distantPast
    let date2 = log2.scheduledAt ?? Date.distantPast
    return date1 > date2
  }

  lastLoadTimestamps[key] = Date()
  isLoading = false
  error = nil

  waterLogs = snapshot.water

  if let userData = snapshot.userData {
    height = userData.height_cm
    weight = userData.weight_kg

    if let encoded = try? JSONEncoder().encode(userData) {
      UserDefaults.standard.set(encoded, forKey: "userData")
    }
  }

  if let goals = snapshot.goals {
    let serverCal = goals.calories
    if serverCal > 0 {
      calorieGoal = serverCal
    }
    proteinGoal = goals.protein
    carbsGoal = goals.carbs
    fatGoal = goals.fat

    if let desiredKg = goals.desiredWeightKg {
      desiredWeightKg = desiredKg
      desiredWeightLbs = goals.desiredWeightLbs ?? (desiredKg * 2.20462)
    } else if let desiredLbs = goals.desiredWeightLbs {
      desiredWeightLbs = desiredLbs
      desiredWeightKg = desiredLbs / 2.20462
    }

    if let encoded = try? JSONEncoder().encode(goals) {
      UserDefaults.standard.set(encoded, forKey: "nutritionGoalsData")
    }
  }

  remainingCalories = max(0, calorieGoal - totalCalories)
  triggerProfileDataRefresh()
}




    private func recalculateTotals() {
      // Only count food/meal/recipe calories for intake (exclude activities)
      totalCalories = logs.reduce(0.0) { sum, log in
        // Activities burn calories, they don't contribute to calorie intake
        guard log.type != .activity else { return sum }
        return sum + log.displayCalories
      }

      totalProtein = logs.reduce(0.0) { sum, log in
        let p1 = log.food?.protein  ?? 0
        let p2 = log.meal?.protein  ?? 0
        let p3 = log.recipe?.protein ?? 0
        return sum + p1 + p2 + p3
      }

      totalCarbs = logs.reduce(0.0) { sum, log in
        let c1 = log.food?.carbs  ?? 0
        let c2 = log.meal?.carbs  ?? 0
        let c3 = log.recipe?.carbs ?? 0
        return sum + c1 + c2 + c3
      }

      totalFat = logs.reduce(0.0) { sum, log in
        let f1 = log.food?.fat  ?? 0
        let f2 = log.meal?.fat  ?? 0
        let f3 = log.recipe?.fat ?? 0
        return sum + f1 + f2 + f3
      }

      remainingCalories = max(0, calorieGoal - totalCalories)
    }

    // MARK: - Profile Data Refresh
    
    /// Trigger refresh of preloaded profile data whenever logs change
    private func triggerProfileDataRefresh() {
        NotificationCenter.default.post(name: NSNotification.Name("LogsChangedNotification"), object: nil)
    }

    func updateLog(log: CombinedLog, servings: Double, date: Date, mealType: String, calories: Double? = nil, protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let foodLogId = log.foodLogId else {
            completion(.failure(NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid log ID"])))
            return
        }

        // Call the repository to update the log
        logNetwork.updateLog(userEmail: email, logId: foodLogId, servings: servings, date: date, mealType: mealType, calories: calories, protein: protein, carbs: carbs, fat: fat) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedFoodLog):
                    // Find the log in the local array
                    if let index = self.logs.firstIndex(where: { $0.id == log.id }) {
                        
                        let oldLogDate = self.logs[index].scheduledAt ?? Date()
                        let dateChanged = !Calendar.current.isDate(oldLogDate, inSameDayAs: date)
                        
                        if dateChanged {
                            // Log was moved to a different date
                            print("📅 Log moved from \(oldLogDate) to \(date)")
                            
                            // Remove from current day's logs
                            self.logs.remove(at: index)
                            
                            // Remove from current day's pending cache
                            let oldKey = Calendar.current.startOfDay(for: oldLogDate)
                            if var oldPending = self.pendingByDate[oldKey] {
                                oldPending.removeAll { $0.id == log.id }
                                if oldPending.isEmpty {
                                    self.pendingByDate.removeValue(forKey: oldKey)
                                } else {
                                    self.pendingByDate[oldKey] = oldPending
                                }
                            }
                            
                            // Add to new date's pending cache (so it shows up when user navigates there)
                            let newKey = Calendar.current.startOfDay(for: date)
                            var newPending = self.pendingByDate[newKey] ?? []
                            
                            // Create updated log for the new date
                            var updatedLog = log
                            updatedLog.food?.numberOfServings = updatedFoodLog.servings
                            updatedLog.mealType = updatedFoodLog.meal_type
                            updatedLog.scheduledAt = updatedFoodLog.logDate
                            updatedLog.message = "\(updatedFoodLog.food.displayName) – \(updatedFoodLog.meal_type)"
                            
                            // IMPORTANT: Use our edited calories value, not the backend's!
                            if let editedCalories = calories {
                                updatedLog.calories = editedCalories
                            } else {
                                updatedLog.calories = updatedFoodLog.calories
                            }
                            
                            // Update individual nutrient values if they were provided
                            if let calories = calories, let protein = protein, let carbs = carbs, let fat = fat, let food = updatedLog.food {
                                print("🔄 Updating food log (date change) with: calories=\(calories), protein=\(protein), carbs=\(carbs), fat=\(fat), servings=\(updatedFoodLog.servings)")
                                
                                // Avoid division by zero
                                let servingsCount = max(updatedFoodLog.servings, 0.1)
                                
                                updatedLog.food = LoggedFoodItem(
                                    foodLogId: food.foodLogId,
                                    fdcId: food.fdcId,
                                    displayName: food.displayName,
                                    calories: calories / servingsCount, // Store per-serving value
                                    servingSizeText: food.servingSizeText,
                                    numberOfServings: updatedFoodLog.servings,
                                    brandText: food.brandText,
                                    protein: protein / servingsCount,
                                    carbs: carbs / servingsCount,
                                    fat: fat / servingsCount,
                                    healthAnalysis: food.healthAnalysis,
                                    foodNutrients: food.foodNutrients
                                )
                                
                                print("✅ Updated food log locally (date change) with per-serving values: cal=\(calories / servingsCount), prot=\(protein / servingsCount), carbs=\(carbs / servingsCount), fat=\(fat / servingsCount)")
                            }
                            
                            // Don't add duplicate to pending
                            if !newPending.contains(where: { $0.id == updatedLog.id }) {
                                newPending.insert(updatedLog, at: 0)
                                self.pendingByDate[newKey] = newPending
                            }
                            
                            print("✅ Log removed from current day and added to target date's cache")
                            // DO NOT navigate automatically - let user stay on current date
                        } else {
                            // Same date – update in place **and** force Combine to emit
                            var updatedLog = self.logs[index]              // 1️⃣ copy the element (value-type struct)
                            updatedLog.food?.numberOfServings = updatedFoodLog.servings
                            updatedLog.mealType              = updatedFoodLog.meal_type
                            updatedLog.scheduledAt           = updatedFoodLog.logDate
                            updatedLog.message               = "\(updatedFoodLog.food.displayName) – \(updatedFoodLog.meal_type)"
                            
                            // IMPORTANT: Use our edited calories value, not the backend's!
                            if let editedCalories = calories {
                                updatedLog.calories = editedCalories
                            } else {
                                updatedLog.calories = updatedFoodLog.calories
                            }
                            
                            // Update individual nutrient values if they were provided
                            if let calories = calories, let protein = protein, let carbs = carbs, let fat = fat, let food = updatedLog.food {
                                print("🔄 Updating food log (same date) with: calories=\(calories), protein=\(protein), carbs=\(carbs), fat=\(fat), servings=\(updatedFoodLog.servings)")
                                
                                // Avoid division by zero
                                let servingsCount = max(updatedFoodLog.servings, 0.1)
                                
                                updatedLog.food = LoggedFoodItem(
                                    foodLogId: food.foodLogId,
                                    fdcId: food.fdcId,
                                    displayName: food.displayName,
                                    calories: calories / servingsCount, // Store per-serving value
                                    servingSizeText: food.servingSizeText,
                                    numberOfServings: updatedFoodLog.servings,
                                    brandText: food.brandText,
                                    protein: protein / servingsCount,
                                    carbs: carbs / servingsCount,
                                    fat: fat / servingsCount,
                                    healthAnalysis: food.healthAnalysis,
                                    foodNutrients: food.foodNutrients
                                )
                                
                                print("✅ Updated food log locally (same date) with per-serving values: cal=\(calories / servingsCount), prot=\(protein / servingsCount), carbs=\(carbs / servingsCount), fat=\(fat / servingsCount)")
                            }

                            // 2️⃣ Force SwiftUI to detect the change by replacing the entire array
                            var newLogs = self.logs
                            newLogs[index] = updatedLog
                            self.logs = newLogs
                            
                            print("📱 Force UI refresh for food log - replaced logs array")
                        }
                        
                        // Recalculate totals for current day
                        self.recalculateTotals()
                    }
                    
                    // Trigger profile data refresh since logs changed
                    self.triggerProfileDataRefresh()
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func updateMealLog(log: CombinedLog, servings: Double, date: Date, mealType: String, calories: Double? = nil, protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🍽️ DayLogsViewModel: updateMealLog called")
        
        guard let mealLogId = log.mealLogId else {
            print("❌ DayLogsViewModel: No mealLogId found")
            completion(.failure(NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid meal log ID"])))
            return
        }

        print("🔄 DayLogsViewModel: Calling logNetwork.updateMealLog with ID: \(mealLogId)")
        // Call the repository to update the meal log
        logNetwork.updateMealLog(userEmail: email, logId: mealLogId, servings: servings, date: date, mealType: mealType, calories: calories, protein: protein, carbs: carbs, fat: fat) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedMealLog):
                    // Find the log in the local array
                    if let index = self.logs.firstIndex(where: { $0.id == log.id }) {
                        
                        let oldLogDate = self.logs[index].scheduledAt ?? Date()
                        let dateChanged = !Calendar.current.isDate(oldLogDate, inSameDayAs: date)
                        
                        if dateChanged {
                            // Log was moved to a different date
                            print("📅 Meal log moved from \(oldLogDate) to \(date)")
                            
                            // Remove from current day's logs
                            self.logs.remove(at: index)
                            
                            // Remove from current day's pending cache
                            let oldKey = Calendar.current.startOfDay(for: oldLogDate)
                            if var oldPending = self.pendingByDate[oldKey] {
                                oldPending.removeAll { $0.id == log.id }
                                if oldPending.isEmpty {
                                    self.pendingByDate.removeValue(forKey: oldKey)
                                } else {
                                    self.pendingByDate[oldKey] = oldPending
                                }
                            }
                            
                            // Add to new date's pending cache (so it shows up when user navigates there)
                            let newKey = Calendar.current.startOfDay(for: date)
                            var newPending = self.pendingByDate[newKey] ?? []
                            
                            // Create updated log for the new date
                            var updatedLog = log
                            if let existingMeal = updatedLog.meal {
                                // Update nutrient values if they were provided, otherwise keep original per-serving values
                                let servingsCount = max(updatedMealLog.servings_consumed, 0.1)
                                let perServingCalories = calories.map { $0 / servingsCount } ?? existingMeal.calories
                                let perServingProtein = protein.map { $0 / servingsCount } ?? existingMeal.protein
                                let perServingCarbs = carbs.map { $0 / servingsCount } ?? existingMeal.carbs
                                let perServingFat = fat.map { $0 / servingsCount } ?? existingMeal.fat
                                
                                if let calories = calories, let protein = protein, let carbs = carbs, let fat = fat {
                                    print("🔄 Updating meal log (date change) with: calories=\(calories), protein=\(protein), carbs=\(carbs), fat=\(fat), servings=\(servingsCount)")
                                    print("✅ Per-serving values: cal=\(perServingCalories), prot=\(perServingProtein ?? 0), carbs=\(perServingCarbs ?? 0), fat=\(perServingFat ?? 0)")
                                }
                                
                                updatedLog.meal = MealSummary(
                                    mealLogId: existingMeal.mealLogId,
                                    mealId: existingMeal.mealId,
                                    title: existingMeal.title,
                                    description: existingMeal.description,
                                    image: existingMeal.image,
                                    calories: perServingCalories,
                                    servings: updatedMealLog.servings_consumed,
                                    protein: perServingProtein,
                                    carbs: perServingCarbs,
                                    fat: perServingFat,
                                    scheduledAt: existingMeal.scheduledAt
                                )
                            }
                            
                            // IMPORTANT: Use our edited calories value, not the backend's!
                            if let editedCalories = calories {
                                updatedLog.calories = editedCalories
                            } else {
                                updatedLog.calories = updatedMealLog.calories
                            }
                            
                            updatedLog.mealType = updatedMealLog.meal_type
                            updatedLog.scheduledAt = ISO8601DateFormatter().date(from: updatedMealLog.date)
                            updatedLog.message = "\(updatedMealLog.meal.title) – \(updatedMealLog.meal_type)"
                            
                            // Don't add duplicate to pending
                            if !newPending.contains(where: { $0.id == updatedLog.id }) {
                                newPending.insert(updatedLog, at: 0)
                                self.pendingByDate[newKey] = newPending
                            }
                            
                            print("✅ Meal log removed from current day and added to target date's cache")
                            // DO NOT navigate automatically - let user stay on current date
                        } else {
                            // Same date – update in place **and** force Combine to emit
                            var updatedLog = self.logs[index]              // 1️⃣ copy the element (value-type struct)
                            if let existingMeal = updatedLog.meal {
                                // Update nutrient values if they were provided, otherwise keep original per-serving values
                                let servingsCount = max(updatedMealLog.servings_consumed, 0.1)
                                let perServingCalories = calories.map { $0 / servingsCount } ?? existingMeal.calories
                                let perServingProtein = protein.map { $0 / servingsCount } ?? existingMeal.protein
                                let perServingCarbs = carbs.map { $0 / servingsCount } ?? existingMeal.carbs
                                let perServingFat = fat.map { $0 / servingsCount } ?? existingMeal.fat
                                
                                if let calories = calories, let protein = protein, let carbs = carbs, let fat = fat {
                                    print("🔄 Updating meal log (same date) with: calories=\(calories), protein=\(protein), carbs=\(carbs), fat=\(fat), servings=\(servingsCount)")
                                    print("✅ Per-serving values: cal=\(perServingCalories), prot=\(perServingProtein ?? 0), carbs=\(perServingCarbs ?? 0), fat=\(perServingFat ?? 0)")
                                }
                                
                                updatedLog.meal = MealSummary(
                                    mealLogId: existingMeal.mealLogId,
                                    mealId: existingMeal.mealId,
                                    title: existingMeal.title,
                                    description: existingMeal.description,
                                    image: existingMeal.image,
                                    calories: perServingCalories,
                                    servings: updatedMealLog.servings_consumed,
                                    protein: perServingProtein,
                                    carbs: perServingCarbs,
                                    fat: perServingFat,
                                    scheduledAt: existingMeal.scheduledAt
                                )
                            }
                            
                            // IMPORTANT: Use our edited calories value, not the backend's!
                            if let editedCalories = calories {
                                updatedLog.calories = editedCalories
                            } else {
                                updatedLog.calories = updatedMealLog.calories
                            }
                            
                            updatedLog.mealType = updatedMealLog.meal_type
                            updatedLog.scheduledAt = ISO8601DateFormatter().date(from: updatedMealLog.date)
                            updatedLog.message = "\(updatedMealLog.meal.title) – \(updatedMealLog.meal_type)"

                            // 2️⃣ Force SwiftUI to detect the change by replacing the entire array
                            var newLogs = self.logs
                            newLogs[index] = updatedLog
                            self.logs = newLogs
                            
                            print("📱 Force UI refresh for meal log - replaced logs array")
                        }
                        
                        // Recalculate totals for current day
                        self.recalculateTotals()
                    }
                    
                    // Trigger profile data refresh since logs changed
                    self.triggerProfileDataRefresh()
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

  // MARK: - Cache Management
  
  /// Clear the pending logs cache to prevent showing stale data
  private func clearPendingCache() {
      pendingByDate.removeAll()
      print("[DayLogsVM] Cleared pending cache")
  }
  
  // MARK: - Activity Log Helpers
  
  private func getActivityLogsFromHealth(for date: Date) -> [CombinedLog] {
      // Get the shared HealthKitViewModel instance
      guard let healthViewModel = getHealthKitViewModel() else {
          print("[DayLogsVM] No HealthKitViewModel available")
          return []
      }
      
      let activities = healthViewModel.getActivityLogs(for: date)
      
      return activities.map { activity in
          CombinedLog(
              type: .activity,
              status: "success",
              calories: activity.totalEnergyBurned ?? 0,
              message: activity.displayName,
              scheduledAt: activity.startDate,
              activityId: activity.id,
              activity: activity,
              logDate: formatDateForLog(activity.startDate),
              dayOfWeek: formatDayOfWeek(activity.startDate)
          )
      }
  }
  
  private func getHealthKitViewModel() -> HealthKitViewModel? {
      // Try to get the HealthKitViewModel from the app's environment
      // This is a simplified approach - in a real app, you'd inject this dependency
      return healthViewModel ?? HealthKitViewModel.shared
  }
  
  private func formatDateForLog(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      return formatter.string(from: date)
  }
  
  private func formatDayOfWeek(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEEE"
      return formatter.string(from: date)
  }
}
