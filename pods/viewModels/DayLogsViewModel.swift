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

  // Daily totals
  @Published var totalCalories: Double = 0
  @Published var totalProtein : Double = 0
  @Published var totalCarbs   : Double = 0
  @Published var totalFat     : Double = 0
  
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

  private let repo = LogRepository()
  private(set) var email = ""

  init(email: String = "") {
    self.email = email
  }

  func setEmail(_ newEmail: String) {
    email = newEmail
    fetchNutritionGoals()
  }


  // MARK: – Goal helpers ------------------------------------------------------
 func fetchCalorieGoal() {
    if let g = UserDefaults.standard.value(forKey: "dailyCalorieGoal") as? Double {
        calorieGoal = g
    } else if let data = UserDefaults.standard.data(forKey: "nutritionGoalsData"),
              let goals = try? JSONDecoder().decode(NutritionGoals.self, from: data) {
        calorieGoal = goals.calories
    } else {
        calorieGoal = Double(UserGoalsManager.shared.dailyGoals.calories)
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
            print("[DayLogsVM] logs.inserted \(log.id), logs now = \(logs.map { $0.id })")

    }
  }
}


func loadLogs(for date: Date) {
  selectedDate = date
  isLoading = true; error = nil

  repo.fetchLogs(email: email, for: date) { [weak self] result in
    guard let self = self else { return }
    self.isLoading = false

    switch result {
    case .success(let serverResponse):
      let serverLogs = serverResponse.logs
      let key = Calendar.current.startOfDay(for: date)
      let pending = self.pendingByDate[key] ?? []

      // ↓ new: drop any pending that the server also sent back
      let dedupedPending = pending.filter { p in
        !serverLogs.contains(where: { $0.id == p.id })
      }

      self.logs = dedupedPending + serverLogs
      
      // Update water logs from server response
      self.waterLogs = serverResponse.waterLogs
      
      // Update height and weight from onboarding data if available
      if let userData = serverResponse.userData {
          self.height = userData.height_cm
          self.weight = userData.weight_kg
      }
      
      // Update goals if available
      if let goals = serverResponse.goals {
          self.calorieGoal = goals.calories ?? self.calorieGoal
          self.proteinGoal = goals.protein ?? self.proteinGoal
          self.carbsGoal = goals.carbs ?? self.carbsGoal
          self.fatGoal = goals.fat ?? self.fatGoal
          
          // Store desired weight if available
          if let desiredKg = goals.desiredWeightKg {
              self.desiredWeightKg = desiredKg
              // Convert kg to lbs if desiredWeightLbs is not available
              self.desiredWeightLbs = goals.desiredWeightLbs ?? (desiredKg * 2.20462)
          } else if let desiredLbs = goals.desiredWeightLbs {
              self.desiredWeightLbs = desiredLbs
              // Convert lbs to kg if desiredWeightKg is not available
              self.desiredWeightKg = desiredLbs / 2.20462
          }
          
          // Recalculate remaining calories
          self.remainingCalories = max(0, self.calorieGoal - self.totalCalories)
      }

    case .failure(let err):
      self.error = err
    }
  }
}



    private func recalculateTotals() {
      totalCalories = logs.reduce(0.0) { $0 + $1.displayCalories }

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

    func removeLog(_ logToRemove: CombinedLog) {
        // Remove from the main logs array
        logs.removeAll { $0.id == logToRemove.id }

        // Remove from pendingByDate cache
        if let scheduledDate = logToRemove.scheduledAt {
            let key = Calendar.current.startOfDay(for: scheduledDate)
            if var pendingLogsForDate = pendingByDate[key] {
                pendingLogsForDate.removeAll { $0.id == logToRemove.id }
                if pendingLogsForDate.isEmpty {
                    pendingByDate.removeValue(forKey: key)
                } else {
                    pendingByDate[key] = pendingLogsForDate
                }
            }
        }
        // Recalculate totals after removal
        recalculateTotals()
    }

    func updateLog(log: CombinedLog, servings: Double, date: Date, mealType: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let foodLogId = log.foodLogId else {
            completion(.failure(NSError(domain: "DayLogsViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid log ID"])))
            return
        }

        // Call the repository to update the log
        repo.updateLog(userEmail: email, logId: foodLogId, servings: servings, date: date, mealType: mealType) { result in
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
                            updatedLog.calories = updatedFoodLog.calories
                            updatedLog.mealType = updatedFoodLog.meal_type
                            updatedLog.scheduledAt = updatedFoodLog.logDate
                            updatedLog.message = "\(updatedFoodLog.food.displayName) – \(updatedFoodLog.meal_type)"
                            
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
                            updatedLog.calories              = updatedFoodLog.calories
                            updatedLog.mealType              = updatedFoodLog.meal_type
                            updatedLog.scheduledAt           = updatedFoodLog.logDate
                            updatedLog.message               = "\(updatedFoodLog.food.displayName) – \(updatedFoodLog.meal_type)"

                            // 2️⃣ overwrite the slot – this changes the array instance, so @Published fires
                            self.logs[index] = updatedLog
                        }
                        
                        // Recalculate totals for current day
                        self.recalculateTotals()
                    }
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
