//
//  FullAnalyticsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//

import SwiftUI

enum TimeRange: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}


struct FullAnalyticsView: View {
    let column: PodColumn
    let activityLogs: [PodItemActivityLog]
    @State private var selectedTimeRange: TimeRange = .day
    @State private var processedData: [ProcessedDataPoint] = []
    @State private var currentStreak: Int = 0
        @State private var longestStreak: Int = 0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                timeRangeSelector

                ColumnTrendView(column: column, processedData: processedData, selectedTimeRange: selectedTimeRange)
                BoundsView(column: column, processedData: processedData, selectedTimeRange: selectedTimeRange)
//                ConsistencyTrackerView(column: column, processedData: processedData, selectedTimeRange: selectedTimeRange)
                ConsistencyTrackerView(column: column, currentStreak: currentStreak, longestStreak: longestStreak, selectedTimeRange: selectedTimeRange)
                PerformanceVariabilityView(column: column, processedData: processedData, selectedTimeRange: selectedTimeRange)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
        }
        .navigationBarTitle(column.name, displayMode: .inline)
        .onAppear {
                   updateProcessedData()
               }
        .onChange(of: selectedTimeRange) { _, _ in
                 updateProcessedData()
             }
    }
    
    private var timeRangeSelector: some View {
         HStack(spacing: 0) {
             ForEach(TimeRange.allCases, id: \.self) { range in
                 Button(action: {
                     selectedTimeRange = range
                     updateProcessedData()
                 }) {
                     Text(range.rawValue)
                         .font(.headline)
                         .padding(.vertical, 8)
                         .padding(.horizontal, 16)
                         .background(selectedTimeRange == range ? (colorScheme == .dark ? .white : .black) : Color("ltBg"))
                         .foregroundColor(selectedTimeRange == range ? (colorScheme == .dark ? .black : .white) : .primary)
                 }
             }
         }
         .background(Color("dkBg"))
         .cornerRadius(8)
     }
    
    private func updateProcessedData() {
        switch selectedTimeRange {
        case .day:
            processedData = processDailyData()
        case .week:
            processedData = processWeeklyData()
        case .month:
            processedData = processMonthlyData()
        }
        calculateStreaks()
    }
    private func calculateStreaks() {
            let sortedData = processedData.sorted { $0.date < $1.date }
            var current = 0
            var longest = 0
            var lastDate: Date?
            let calendar = Calendar.current
            let today = Date()
            
            for point in sortedData {
                if let last = lastDate {
                    switch selectedTimeRange {
                    case .day:
                        let dayDifference = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: point.date)).day ?? 0
                        if dayDifference == 1 {
                            current += 1
                        } else if dayDifference > 1 {
                            longest = max(longest, current)
                            current = 1
                        }
                    case .week:
                        let weekDifference = calendar.dateComponents([.weekOfYear], from: last, to: point.date).weekOfYear ?? 0
                        if weekDifference == 1 {
                            current += 1
                        } else if weekDifference > 1 {
                            longest = max(longest, current)
                            current = 1
                        }
                    case .month:
                        let monthDifference = calendar.dateComponents([.month], from: last, to: point.date).month ?? 0
                        if monthDifference == 1 {
                            current += 1
                        } else if monthDifference > 1 {
                            longest = max(longest, current)
                            current = 1
                        }
                    }
                } else {
                    current = 1
                }
                lastDate = point.date
            }
            
            // Check if the current streak is still valid
            if let lastLogDate = lastDate {
                switch selectedTimeRange {
                case .day:
                    let daysSinceLastLog = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastLogDate), to: calendar.startOfDay(for: today)).day ?? 0
                    if daysSinceLastLog > 1 {
                        current = 0
                    }
                case .week:
                    if !calendar.isDate(lastLogDate, equalTo: today, toGranularity: .weekOfYear) {
                        let weeksSinceLastLog = calendar.dateComponents([.weekOfYear], from: lastLogDate, to: today).weekOfYear ?? 0
                        if weeksSinceLastLog > 1 {
                            current = 0
                        }
                    }
                case .month:
                    if !calendar.isDate(lastLogDate, equalTo: today, toGranularity: .month) {
                        let monthsSinceLastLog = calendar.dateComponents([.month], from: lastLogDate, to: today).month ?? 0
                        if monthsSinceLastLog > 1 {
                            current = 0
                        }
                    }
                }
            } else {
                current = 0  // No logs at all
            }
            
            longest = max(longest, current)
            
            currentStreak = current
            longestStreak = longest
            
            print("Time Range: \(selectedTimeRange), Current Streak: \(currentStreak), Longest Streak: \(longestStreak)")
            print("Last log date: \(lastDate?.description ?? "N/A"), Today: \(today.description)")
        }
    
    private func processDailyData() -> [ProcessedDataPoint] {
        // Process daily data
        return activityLogs.compactMap { log in
            guard let value = numericValue(for: log) else { return nil }
            return ProcessedDataPoint(date: log.loggedAt, value: value)
        }.sorted { $0.date < $1.date }
    }
    
    private func processWeeklyData() -> [ProcessedDataPoint] {
        // Process weekly data
        let calendar = Calendar.current
        var weeklyData: [Date: [Double]] = [:]
        
        for log in activityLogs {
            guard let value = numericValue(for: log) else { continue }
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: log.loggedAt))!
            weeklyData[weekStart, default: []].append(value)
        }
        
        return weeklyData.map { (date, values) in
            ProcessedDataPoint(date: date, value: values.reduce(0, +) / Double(values.count))
        }.sorted { $0.date < $1.date }
    }
    
    private func processMonthlyData() -> [ProcessedDataPoint] {
        // Process monthly data
        let calendar = Calendar.current
        var monthlyData: [Date: [Double]] = [:]
        
        for log in activityLogs {
            guard let value = numericValue(for: log) else { continue }
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: log.loggedAt))!
            monthlyData[monthStart, default: []].append(value)
        }
        
        return monthlyData.map { (date, values) in
            ProcessedDataPoint(date: date, value: values.reduce(0, +) / Double(values.count))
        }.sorted { $0.date < $1.date }
    }
    
    private func numericValue(for log: PodItemActivityLog) -> Double? {
        guard let columnValue = log.columnValues[column.name] else { return nil }
        switch columnValue {
        case .number(let value): return Double(value)
        case .string(let value): return Double(value)
        case .null: return nil
        }
    }
}


struct ProcessedDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
