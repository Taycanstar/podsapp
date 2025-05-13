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

  private let repo = LogRepository()
  private(set) var email = ""

  init(email: String = "") {
    self.email = email
  }

  func setEmail(_ newEmail: String) {
    email = newEmail
    fetchCalorieGoal()
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



func addPending(_ log: CombinedLog) {
  let key = Calendar.current.startOfDay(for: log.scheduledAt!)
    print("[DayLogsVM] addPending( id:\(log.id), dateKey:\(key) )")

  var arr = pendingByDate[key] ?? []

  // don’t double-insert the same ID
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
    case .success(let serverLogs):
      let key = Calendar.current.startOfDay(for: date)
      let pending = self.pendingByDate[key] ?? []

      // ↓ new: drop any pending that the server also sent back
      let dedupedPending = pending.filter { p in
        !serverLogs.contains(where: { $0.id == p.id })
      }

      self.logs = dedupedPending + serverLogs

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




}
