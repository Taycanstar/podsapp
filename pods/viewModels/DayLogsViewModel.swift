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

    // // ── published state
    // @Published var logs      : [CombinedLog] = []


    // @Published var error     : Error?        = nil
    // @Published var isLoading : Bool          = false
    // @Published var selectedDate : Date = Date()

    // // ── private
    // private let repo = LogRepository()
    // private(set) var email  : String         // <- can change later

    // /// you may start with an empty string and set it afterwards
    // init(email: String = "") { self.email = email }



    // /// call this once you learn the user’s e-mail
    // func setEmail(_ newEmail: String) { email = newEmail }
      @Published var logs         : [CombinedLog] = [] {
    didSet { recalculateTotals() }
  }
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
  }

  func loadLogs(for date: Date) {
    guard !email.isEmpty else { return }
    isLoading = true
    error     = nil

    repo.fetchLogs(email: email, for: date) { [weak self] result in
      guard let self = self else { return }
      self.isLoading = false
      switch result {
      case .success(let serverLogs):
        self.logs = serverLogs   // ← triggers didSet → recalc
      case .failure(let e):
        self.error = e
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
    }




}
