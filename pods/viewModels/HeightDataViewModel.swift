//
//  HeightDataViewModel.swift
//  Pods
//
//  Created by Dimi Nunez on 5/17/25.
//

import Foundation
import Combine

@MainActor
class HeightDataViewModel: ObservableObject {
    @Published var logs: [HeightLogResponse] = []
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
    private lazy var dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func loadLogs() {
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else { 
            print("⚠️ HeightDataViewModel: No user email found in UserDefaults")
            return 
        }
        
        print("🔍 HeightDataViewModel: Fetching height logs for \(email)")
        
        api.fetchHeightLogs(userEmail: email, limit: 1000, offset: 0) { [weak self] result in
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    print("📊 HeightDataViewModel: Received \(response.logs.count) height logs")
                    
                    // Debug information
                    for log in response.logs {
                        print("📏 Log: \(log.id), height: \(log.heightCm) cm, date: \(log.dateLogged)")
                    }
                    
                    let cutoff = Calendar.current.date(byAdding: .day, value: -self.timeframe.days, to: Date()) ?? Date()
                    print("📅 HeightDataViewModel: Current date: \(Date()), Cutoff date: \(cutoff) for timeframe: \(self.timeframe.rawValue)")
                    
                    // Track which logs are filtered
                    var includedLogs: [HeightLogResponse] = []
                    var filteredOutLogs: [HeightLogResponse] = []
                    
                    for log in response.logs {
                        if let date = self.dateFormatter.date(from: log.dateLogged) {
                            if date >= cutoff {
                                includedLogs.append(log)
                                print("✅ Including log ID \(log.id): \(date) >= \(cutoff)")
                            } else {
                                filteredOutLogs.append(log)
                                print("❌ Filtering out log ID \(log.id): \(date) < \(cutoff)")
                            }
                        } else {
                            print("⚠️ Failed to parse date: \(log.dateLogged) for log ID \(log.id)")
                            // Include logs with parsing errors
                            includedLogs.append(log)
                        }
                    }
                    
                    // Sort included logs
                    includedLogs.sort { log1, log2 in
                        let date1 = self.dateFormatter.date(from: log1.dateLogged) ?? Date()
                        let date2 = self.dateFormatter.date(from: log2.dateLogged) ?? Date()
                        return date1 < date2
                    }
                    
                    print("📊 HeightDataViewModel: Kept \(includedLogs.count) logs, filtered out \(filteredOutLogs.count)")
                    
                    // Temporarily force logs to show for debugging
                    if includedLogs.isEmpty && !response.logs.isEmpty {
                        print("⚠️ HeightDataViewModel: All logs were filtered out! Using all logs instead.")
                        self.logs = response.logs
                    } else {
                        self.logs = includedLogs
                    }
                    
                    print("🔍 HeightDataViewModel.logs now contains \(self.logs.count) logs")
                }
            case .failure(let error):
                print("❌ HeightDataViewModel: Error fetching height logs: \(error)")
            }
        }
    }

    init() {
        loadLogs()
    }
} 