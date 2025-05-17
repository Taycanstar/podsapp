//
//  WeightDataViewModel.swift
//  Pods
//
//  Created by Dimi Nunez on 5/17/25.
//

import Foundation
import Combine

@MainActor
class WeightDataViewModel: ObservableObject {
    @Published var logs: [WeightLogResponse] = []
    @Published var timeframe: Timeframe = .week

    enum Timeframe: String, CaseIterable {
        case week = "W"
        case month = "M"
        case sixMonths = "6M"
        case year = "Y"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .sixMonths: return 182
            case .year: return 365
            }
        }
    }

    private let api = NetworkManagerTwo.shared
    private let dateFormatter = ISO8601DateFormatter()

    func loadLogs() {
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else { return }
        api.fetchWeightLogs(userEmail: email, limit: 1000, offset: 0) { [weak self] result in
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    let cutoff = Calendar.current.date(byAdding: .day, value: -self!.timeframe.days, to: Date()) ?? Date()
                    self?.logs = response.logs.filter { log in
                        if let date = self?.dateFormatter.date(from: log.dateLogged) {
                            return date >= cutoff
                        }
                        return false
                    }.sorted {
                        guard let d1 = self?.dateFormatter.date(from: $0.dateLogged),
                              let d2 = self?.dateFormatter.date(from: $1.dateLogged) else { return false }
                        return d1 < d2
                    }
                }
            case .failure(let error):
                print("Error fetching weight logs: \(error)")
            }
        }
    }

    init() {
        loadLogs()
    }
} 