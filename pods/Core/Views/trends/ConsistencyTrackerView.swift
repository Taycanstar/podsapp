//
//  ConsistencyTrackerView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//

//import SwiftUI


//struct ConsistencyTrackerView: View {
//    let column: PodColumn
//    let processedData: [ProcessedDataPoint]
//    let selectedTimeRange: TimeRange
//    @State private var selectedMetric: (title: String, value: Double, unit: String)?
//    
//    var body: some View {
//        HStack(spacing: 10) {
//
//            metricCardWithNavigation(title: "Current streak", value: Double(currentStreak))
//            metricCardWithNavigation(title: "Longest streak", value: Double(longestStreak))
//        }
//        .background(
//            NavigationLink(
//                destination: DetailedMetricView(
//                    title: selectedMetric?.title ?? "",
//                    value: selectedMetric?.value ?? 0,
//                    unit: selectedMetric?.unit ?? "",
//                    description: getDescription(for: selectedMetric?.title ?? ""),
//                    analysis: getAnalysis(for: selectedMetric?.title ?? "", value: selectedMetric?.value ?? 0)
//                ),
//                isActive: Binding(
//                    get: { selectedMetric != nil },
//                    set: { if !$0 { selectedMetric = nil } }
//                )
//            ) {
//                EmptyView()
//            }
//        )
//    }
//    
//    private func metricCardWithNavigation(title: String, value: Double) -> some View {
//        MetricCard(
//            title: title,
//            value: value,
//            unit: column.name,
//            action: { navigateAction(title: title, value: value) }
//        )
//    }
//    
//  
//        private func navigateAction(title: String, value: Double) {
//            selectedMetric = (title: title, value: value, unit: column.name)
//        }
//    
//    private func getDescription(for title: String) -> String {
//        switch title {
//        case "Current streak":
//            return "The current streak shows how many consecutive days you've engaged in this activity. Maintaining a streak can help you build consistency and momentum, which are key to long-term performance."
//            
//        case "Longest streak":
//            return "The longest streak represents the highest number of consecutive days you’ve maintained this activity. It reflects your ability to stay committed over time, serving as a benchmark for future goals."
//
//        default:
//            return ""
//        }
//    }
//
//    
//    
//    private func getAnalysis(for title: String, value: Double) -> String {
//        return "Your \(title.lowercased()) of \(Int(round(value))) \(column.name) for the \(selectedTimeRange.rawValue.lowercased()) period indicates... [AI-generated analysis would go here]"
//    }
//    
//    
//    private var currentStreak: Int {
//        calculateStreak(from: processedData.last?.date ?? Date())
//    }
//    
//    private var longestStreak: Int {
//        processedData.map { calculateStreak(from: $0.date) }.max() ?? 0
//    }
//    
//    private var streakUnit: String {
//        switch selectedTimeRange {
//        case .day: return "days"
//        case .week: return "weeks"
//        case .month: return "months"
//        }
//    }
//    
//    private func calculateStreak(from date: Date) -> Int {
//        var streak = 0
//        var currentDate = date
//        let calendar = Calendar.current
//        
//        for dataPoint in processedData.reversed() {
//            let component: Calendar.Component
//            switch selectedTimeRange {
//            case .day: component = .day
//            case .week: component = .weekOfYear
//            case .month: component = .month
//            }
//            
//            if calendar.isDate(dataPoint.date, equalTo: currentDate, toGranularity: component) {
//                streak += 1
//                currentDate = calendar.date(byAdding: component, value: -1, to: currentDate)!
//            } else {
//                break
//            }
//        }
//        
//        return streak
//    }
//}

import SwiftUI

struct ConsistencyTrackerView: View {
    let column: PodColumn
    let currentStreak: Int
    let longestStreak: Int
    let selectedTimeRange: TimeRange
    @State private var selectedMetric: (title: String, value: Double, unit: String)?
    
    var body: some View {
        HStack(spacing: 10) {
            metricCardWithNavigation(title: "Current streak", value: Double(currentStreak))
            metricCardWithNavigation(title: "Longest streak", value: Double(longestStreak))
        }
        .background(
            NavigationLink(
                destination: DetailedMetricView(
                    title: selectedMetric?.title ?? "",
                    value: selectedMetric?.value ?? 0,
                    unit: selectedMetric?.unit ?? "",
                    description: getDescription(for: selectedMetric?.title ?? ""),
                    analysis: getAnalysis(for: selectedMetric?.title ?? "", value: selectedMetric?.value ?? 0)
                ),
                isActive: Binding(
                    get: { selectedMetric != nil },
                    set: { if !$0 { selectedMetric = nil } }
                )
            ) {
                EmptyView()
            }
        )
    }
    
    private func metricCardWithNavigation(title: String, value: Double) -> some View {
        MetricCard(
            title: title,
            value: value,
            unit: streakUnit,
            action: { navigateAction(title: title, value: value) }
        )
    }
    
    private func navigateAction(title: String, value: Double) {
        selectedMetric = (title: title, value: value, unit: streakUnit)
    }
    
    private func getDescription(for title: String) -> String {
        switch title {
        case "Current streak":
            return "The current streak shows how many consecutive \(streakUnit) you've engaged in this activity. Maintaining a streak can help you build consistency and momentum, which are key to long-term performance."
            
        case "Longest streak":
            return "The longest streak represents the highest number of consecutive \(streakUnit) you've maintained this activity. It reflects your ability to stay committed over time, serving as a benchmark for future goals."

        default:
            return ""
        }
    }
    
    private func getAnalysis(for title: String, value: Double) -> String {
        return "Your \(title.lowercased()) of \(Int(round(value))) \(streakUnit) for the \(selectedTimeRange.rawValue.lowercased()) period indicates... [AI-generated analysis would go here]"
    }
    
    private var streakUnit: String {
        switch selectedTimeRange {
        case .day: return "days"
        case .week: return "weeks"
        case .month: return "months"
        }
    }
}
