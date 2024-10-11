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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                timeRangeSelector
//                ColumnTrendView(column: column, activityLogs: activityLogs)
//                BoundsView(column: column, activityLogs: activityLogs)
                ColumnTrendView(column: column, processedData: processedData, selectedTimeRange: selectedTimeRange)
                BoundsView(column: column, processedData: processedData, selectedTimeRange: selectedTimeRange)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
        }
        .navigationBarTitle(column.name, displayMode: .inline)
        .onAppear {
                   updateProcessedData()
               }
        .onChange(of: selectedTimeRange) { _ in
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
