//
//  ConsistencyTrackerView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//

import SwiftUI


struct ConsistencyTrackerView: View {
    let column: PodColumn
    let processedData: [ProcessedDataPoint]
    let selectedTimeRange: TimeRange
    
    var body: some View {
        HStack(spacing: 10) {
            MetricCard(
                title: "Current streak",
                value: Double(currentStreak),
                unit: streakUnit,
                action: { navigateAction() }
            )
            MetricCard(
                title: "Longest streak",
                value: Double(longestStreak),
                unit: streakUnit,
                action: { navigateAction() }
            )
        }
    }
    
    private func navigateAction() {
        print("Navigate tapped")
    }
    
    private var currentStreak: Int {
        calculateStreak(from: processedData.last?.date ?? Date())
    }
    
    private var longestStreak: Int {
        processedData.map { calculateStreak(from: $0.date) }.max() ?? 0
    }
    
    private var streakUnit: String {
        switch selectedTimeRange {
        case .day: return "days"
        case .week: return "weeks"
        case .month: return "months"
        }
    }
    
    private func calculateStreak(from date: Date) -> Int {
        var streak = 0
        var currentDate = date
        let calendar = Calendar.current
        
        for dataPoint in processedData.reversed() {
            let component: Calendar.Component
            switch selectedTimeRange {
            case .day: component = .day
            case .week: component = .weekOfYear
            case .month: component = .month
            }
            
            if calendar.isDate(dataPoint.date, equalTo: currentDate, toGranularity: component) {
                streak += 1
                currentDate = calendar.date(byAdding: component, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        
        return streak
    }
}
