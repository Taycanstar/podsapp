//
//  FullAnalyticsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//
//
//import SwiftUI
//import Mixpanel
//
////enum TimeRange: String, CaseIterable {
////    case day = "Day"
////    case week = "Week"
////    case month = "Month"
////}
//
//
//struct FullAnalyticsView: View {
//    let column: PodColumn
//    let activityLogs: [PodItemActivityLog]
////    @State private var selectedTimeRange: TimeRange = .day
//    @State private var selectedTimeRange: TimeRange = .last7Days
//    @State private var selectedTimeUnit: TimeUnit = .seconds
//    @State private var processedData: [ProcessedDataPoint] = []
//    @State private var currentStreak: Int = 0
//        @State private var longestStreak: Int = 0
//    @Environment(\.colorScheme) private var colorScheme
//    
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 10) {
//                HStack(spacing: 16) {
//                    timeRangeDropdown
//    
//                    if column.type == "time" {
//                        DropdownButton(
//                            label: "Time Unit",
//                            options: TimeUnit.allCases,
//                            selectedOption: $selectedTimeUnit
//                        )
//                    }
//                }
//
//                ColumnTrendView(column: column, processedData: processedData, selectedTimeRange: selectedTimeRange, selectedTimeUnit: selectedTimeUnit)
//                BoundsView(column: column, processedData: processedData, selectedTimeRange: selectedTimeRange, selectedTimeUnit: selectedTimeUnit)
//                ConsistencyTrackerView(column: column, currentStreak: currentStreak, longestStreak: longestStreak, selectedTimeRange: selectedTimeRange)
//                PerformanceVariabilityView(column: column, processedData: processedData, selectedTimeRange: selectedTimeRange, selectedTimeUnit: selectedTimeUnit)
//                Spacer()
//            }
//            .frame(maxWidth: .infinity, alignment: .topLeading)
//            .padding()
//        }
//        .navigationBarTitle(column.name, displayMode: .inline)
//        .onAppear {
//                   updateProcessedData()
//            Mixpanel.mainInstance().time(event: "Viewed Trends")
//               }
//        .onDisappear {
//            Mixpanel.mainInstance().track(event: "Viewed Trends", properties: [
//                "column_name": column.name,
//                "time_range": selectedTimeRange.rawValue
//            ])
//        }
//        .onChange(of: selectedTimeRange) { _, _ in
//                 updateProcessedData()
//             }
//    }
//    
////    private var timeRangeSelector: some View {
////         HStack(spacing: 0) {
////             ForEach(TimeRange.allCases, id: \.self) { range in
////                 Button(action: {
////                     selectedTimeRange = range
////                     updateProcessedData()
////                 }) {
////                     Text(range.rawValue)
////                         .font(.headline)
////                         .padding(.vertical, 8)
////                         .padding(.horizontal, 16)
////                         .background(selectedTimeRange == range ? (colorScheme == .dark ? .white : .black) : Color("ltBg"))
////                         .foregroundColor(selectedTimeRange == range ? (colorScheme == .dark ? .black : .white) : .primary)
////                 }
////             }
////         }
////         .background(Color("dkBg"))
////         .cornerRadius(8)
////     }
////    
////    private func updateProcessedData() {
////        switch selectedTimeRange {
////        case .day:
////            processedData = processDailyData()
////        case .week:
////            processedData = processWeeklyData()
////        case .month:
////            processedData = processMonthlyData()
////        }
////        calculateStreaks()
////    }
//    
//    private var timeRangeDropdown: some View {
//        DropdownButton(
//            label: "Time Range",
//            options: TimeRange.allCases,
//            selectedOption: $selectedTimeRange
//        )
//    }
//
//     
//        private func updateProcessedData() {
//            // Update processed data based on the selected time range
//            switch selectedTimeRange {
//            case .today:
//                processedData = filterData(forDays: 1)
//            case .yesterday:
//                processedData = filterData(forDays: 1, offset: -1)
//            case .last7Days:
//                processedData = filterData(forDays: 7)
//            case .last30Days:
//                processedData = filterData(forDays: 30)
//            case .last3Months:
//                processedData = filterData(forMonths: 3)
//            case .last6Months:
//                processedData = filterData(forMonths: 6)
//            case .last12Months:
//                processedData = filterData(forMonths: 12)
//            }
//            
//            calculateStreaks()
//        }
//    
//    private func filterData(forDays days: Int, offset: Int = 0) -> [ProcessedDataPoint] {
//           let calendar = Calendar.current
//           let startDate = calendar.date(byAdding: .day, value: -days + offset, to: Date())!
//           return activityLogs
//               .compactMap { log in
//                   guard let value = numericValue(for: log), log.loggedAt >= startDate else { return nil }
//                   return ProcessedDataPoint(date: log.loggedAt, value: value)
//               }
//               .sorted { $0.date < $1.date }
//       }
//
//       private func filterData(forMonths months: Int) -> [ProcessedDataPoint] {
//           let calendar = Calendar.current
//           let startDate = calendar.date(byAdding: .month, value: -months, to: Date())!
//           return activityLogs
//               .compactMap { log in
//                   guard let value = numericValue(for: log), log.loggedAt >= startDate else { return nil }
//                   return ProcessedDataPoint(date: log.loggedAt, value: value)
//               }
//               .sorted { $0.date < $1.date }
//       }
//    
////    private func calculateStreaks() {
////            let sortedData = processedData.sorted { $0.date < $1.date }
////            var current = 0
////            var longest = 0
////            var lastDate: Date?
////            let calendar = Calendar.current
////            let today = Date()
////            
////            for point in sortedData {
////                if let last = lastDate {
////                    switch selectedTimeRange {
////                    case .day:
////                        let dayDifference = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: point.date)).day ?? 0
////                        if dayDifference == 1 {
////                            current += 1
////                        } else if dayDifference > 1 {
////                            longest = max(longest, current)
////                            current = 1
////                        }
////                    case .week:
////                        let weekDifference = calendar.dateComponents([.weekOfYear], from: last, to: point.date).weekOfYear ?? 0
////                        if weekDifference == 1 {
////                            current += 1
////                        } else if weekDifference > 1 {
////                            longest = max(longest, current)
////                            current = 1
////                        }
////                    case .month:
////                        let monthDifference = calendar.dateComponents([.month], from: last, to: point.date).month ?? 0
////                        if monthDifference == 1 {
////                            current += 1
////                        } else if monthDifference > 1 {
////                            longest = max(longest, current)
////                            current = 1
////                        }
////                    }
////                } else {
////                    current = 1
////                }
////                lastDate = point.date
////            }
////            
////            // Check if the current streak is still valid
////            if let lastLogDate = lastDate {
////                switch selectedTimeRange {
////                case .day:
////                    let daysSinceLastLog = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastLogDate), to: calendar.startOfDay(for: today)).day ?? 0
////                    if daysSinceLastLog > 1 {
////                        current = 0
////                    }
////                case .week:
////                    if !calendar.isDate(lastLogDate, equalTo: today, toGranularity: .weekOfYear) {
////                        let weeksSinceLastLog = calendar.dateComponents([.weekOfYear], from: lastLogDate, to: today).weekOfYear ?? 0
////                        if weeksSinceLastLog > 1 {
////                            current = 0
////                        }
////                    }
////                case .month:
////                    if !calendar.isDate(lastLogDate, equalTo: today, toGranularity: .month) {
////                        let monthsSinceLastLog = calendar.dateComponents([.month], from: lastLogDate, to: today).month ?? 0
////                        if monthsSinceLastLog > 1 {
////                            current = 0
////                        }
////                    }
////                }
////            } else {
////                current = 0  // No logs at all
////            }
////            
////            longest = max(longest, current)
////            
////            currentStreak = current
////            longestStreak = longest
////            
////            print("Time Range: \(selectedTimeRange), Current Streak: \(currentStreak), Longest Streak: \(longestStreak)")
////            print("Last log date: \(lastDate?.description ?? "N/A"), Today: \(today.description)")
////        }
//    
//    private func calculateStreaks() {
//          // Calculate streaks based on processed data
//          let sortedData = processedData.sorted { $0.date < $1.date }
//          var current = 0
//          var longest = 0
//          var lastDate: Date?
//          let calendar = Calendar.current
//          let today = Date()
//          
//          for point in sortedData {
//              if let last = lastDate {
//                  let dayDifference = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: point.date)).day ?? 0
//                  if dayDifference == 1 {
//                      current += 1
//                  } else if dayDifference > 1 {
//                      longest = max(longest, current)
//                      current = 1
//                  }
//              } else {
//                  current = 1
//              }
//              lastDate = point.date
//          }
//          
//          if let lastLogDate = lastDate {
//              let daysSinceLastLog = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastLogDate), to: calendar.startOfDay(for: today)).day ?? 0
//              if daysSinceLastLog > 1 {
//                  current = 0
//              }
//          } else {
//              current = 0
//          }
//          
//          longest = max(longest, current)
//          currentStreak = current
//          longestStreak = longest
//      }
//      
//      private func numericValue(for log: PodItemActivityLog) -> Double? {
//          guard let columnValue = log.columnValues[column.name] else { return nil }
//          switch columnValue {
//          case .number(let value): return Double(value)
//          case .string(let value): return Double(value)
//          case .time(let timeValue): return Double(timeValue.totalSeconds)
//          case .null: return nil
//          }
//      }
//  
//    
//    private func processDailyData() -> [ProcessedDataPoint] {
//        // Process daily data
//        return activityLogs.compactMap { log in
//            guard let value = numericValue(for: log) else { return nil }
//            return ProcessedDataPoint(date: log.loggedAt, value: value)
//        }.sorted { $0.date < $1.date }
//    }
//    
//    private func processWeeklyData() -> [ProcessedDataPoint] {
//        // Process weekly data
//        let calendar = Calendar.current
//        var weeklyData: [Date: [Double]] = [:]
//        
//        for log in activityLogs {
//            guard let value = numericValue(for: log) else { continue }
//            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: log.loggedAt))!
//            weeklyData[weekStart, default: []].append(value)
//        }
//        
//        return weeklyData.map { (date, values) in
//            ProcessedDataPoint(date: date, value: values.reduce(0, +) / Double(values.count))
//        }.sorted { $0.date < $1.date }
//    }
//    
//    private func processMonthlyData() -> [ProcessedDataPoint] {
//        // Process monthly data
//        let calendar = Calendar.current
//        var monthlyData: [Date: [Double]] = [:]
//        
//        for log in activityLogs {
//            guard let value = numericValue(for: log) else { continue }
//            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: log.loggedAt))!
//            monthlyData[monthStart, default: []].append(value)
//        }
//        
//        return monthlyData.map { (date, values) in
//            ProcessedDataPoint(date: date, value: values.reduce(0, +) / Double(values.count))
//        }.sorted { $0.date < $1.date }
//    }
//    
////    private func numericValue(for log: PodItemActivityLog) -> Double? {
////        guard let columnValue = log.columnValues[column.name] else { return nil }
////        switch columnValue {
////        case .number(let value): return Double(value)
////        case .string(let value): return Double(value)
////        case .time(let timeValue):
////                // Convert time to total seconds as a Double
////                return Double(timeValue.totalSeconds)
////        case .null: return nil
////        }
////    }
//}


import SwiftUI
import Mixpanel

struct FullAnalyticsView: View {
    let column: PodColumn
    let activityLogs: [PodItemActivityLog]
    @State private var selectedTimeRange: TimeRange = .last7Days
    @State private var selectedTimeUnit: TimeUnit = .seconds
    @State private var selectedXAxisInterval: XAxisInterval = .day
    @State private var processedData: [ProcessedDataPoint] = []
    @State private var currentStreak: Int = 0
    @State private var longestStreak: Int = 0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    timeRangeDropdown
                    xAxisIntervalDropdown
                    if column.type == "time" {
                        DropdownButton(
                            label: "Time Unit",
                            options: TimeUnit.allCases,
                            selectedOption: $selectedTimeUnit
                        )
                    }
                }

                ColumnTrendView(
                    column: column,
                    processedData: processedData,
                    selectedTimeRange: selectedTimeRange,
                    selectedTimeUnit: selectedTimeUnit,
                    selectedXAxisInterval: selectedXAxisInterval
                )
                BoundsView(column: column, processedData: processedData, selectedTimeRange: selectedTimeRange, selectedTimeUnit: selectedTimeUnit)
                ConsistencyTrackerView(column: column, currentStreak: currentStreak, longestStreak: longestStreak, selectedTimeRange: selectedTimeRange)
                PerformanceVariabilityView(column: column, processedData: processedData, selectedTimeRange: selectedTimeRange, selectedTimeUnit: selectedTimeUnit)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
        }
        .navigationBarTitle(column.name, displayMode: .inline)
        .onAppear {
            updateProcessedData()
            Mixpanel.mainInstance().time(event: "Viewed Trends")
        }
        .onDisappear {
            Mixpanel.mainInstance().track(event: "Viewed Trends", properties: [
                "column_name": column.name,
                "time_range": selectedTimeRange.rawValue
            ])
        }
        .onChange(of: selectedTimeRange) { _, _ in updateProcessedData() }
    }
    
    private var timeRangeDropdown: some View {
        DropdownButton(
            label: "Time Range",
            options: TimeRange.allCases,
            selectedOption: $selectedTimeRange
        )
    }

    private var xAxisIntervalDropdown: some View {
        DropdownButton(
            label: "X-Axis Interval",
            options: XAxisInterval.allCases,
            selectedOption: $selectedXAxisInterval
        )
    }

    private func updateProcessedData() {
        switch selectedTimeRange {
        case .today:
            processedData = filterData(forDays: 1)
        case .yesterday:
            processedData = filterData(forDays: 1, offset: -1)
        case .last7Days:
            processedData = filterData(forDays: 7)
        case .last30Days:
            processedData = filterData(forDays: 30)
        case .last3Months:
            processedData = filterData(forMonths: 3)
        case .last6Months:
            processedData = filterData(forMonths: 6)
        case .last12Months:
            processedData = filterData(forMonths: 12)
        }
        calculateStreaks()
    }
    
    private func filterData(forDays days: Int, offset: Int = 0) -> [ProcessedDataPoint] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days + offset, to: Date())!
        return activityLogs
            .compactMap { log in
                guard let value = numericValue(for: log), log.loggedAt >= startDate else { return nil }
                return ProcessedDataPoint(date: log.loggedAt, value: value)
            }
            .sorted { $0.date < $1.date }
    }

    private func filterData(forMonths months: Int) -> [ProcessedDataPoint] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .month, value: -months, to: Date())!
        return activityLogs
            .compactMap { log in
                guard let value = numericValue(for: log), log.loggedAt >= startDate else { return nil }
                return ProcessedDataPoint(date: log.loggedAt, value: value)
            }
            .sorted { $0.date < $1.date }
    }
    
    private func numericValue(for log: PodItemActivityLog) -> Double? {
        guard let columnValue = log.columnValues[column.name] else { return nil }
        switch columnValue {
        case .number(let value): return Double(value)
        case .string(let value): return Double(value)
        case .time(let timeValue): return Double(timeValue.totalSeconds)
        case .null: return nil
        }
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
                let dayDifference = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: point.date)).day ?? 0
                if dayDifference == 1 {
                    current += 1
                } else if dayDifference > 1 {
                    longest = max(longest, current)
                    current = 1
                }
            } else {
                current = 1
            }
            lastDate = point.date
        }
        
        if let lastLogDate = lastDate {
            let daysSinceLastLog = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastLogDate), to: calendar.startOfDay(for: today)).day ?? 0
            if daysSinceLastLog > 1 {
                current = 0
            }
        } else {
            current = 0
        }
        
        longest = max(longest, current)
        currentStreak = current
        longestStreak = longest
    }
}




struct ProcessedDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}


enum TimeRange: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case last7Days = "7D"
    case last30Days = "30D"
    case last3Months = "3M"
    case last6Months = "6M"
    case last12Months = "12M"
}

enum XAxisInterval: String, CaseIterable {
    case hour = "Hour"
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    
    var calendarComponent: Calendar.Component {
        switch self {
        case .hour: return .hour
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .quarter: return .month // No direct quarter component, so using month
        }
    }
}
