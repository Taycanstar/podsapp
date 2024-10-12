//
//  PerformanceVariabilityView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//

//import SwiftUI
//
//struct PerformanceVariabilityView: View {
//    let column: PodColumn
//    let processedData: [ProcessedDataPoint]
//    let selectedTimeRange: TimeRange
//    
//    var body: some View {
//        MetricCard(
//            title: "Performance variability",
//            value: standardDeviation,
//            unit: column.name,
//            valueFontSize: 22,
//            unitFontSize: 16,
//            action: { navigateAction()}
//            
//            
//        )
//    }
//    
//    private func navigateAction() {
//        print("tapped on performance variability")
//    }
//    
//    private var standardDeviation: Double {
//        let values = processedData.map { $0.value }
//        guard !values.isEmpty else { return 0 }
//        
//        let mean = values.reduce(0, +) / Double(values.count)
//        let sumOfSquaredAvgDiff = values.map { pow($0 - mean, 2) }.reduce(0, +)
//        return sqrt(sumOfSquaredAvgDiff / Double(values.count))
//    }
//
//}
import SwiftUI

struct PerformanceVariabilityView: View {
    let column: PodColumn
    let processedData: [ProcessedDataPoint]
    let selectedTimeRange: TimeRange
    @State private var selectedMetric: (title: String, value: Double, unit: String)?
    
    var body: some View {
        metricCardWithNavigation(title: "Performance variability", value: standardDeviation)
            .background(
                NavigationLink(
                    destination: DetailedMetricView(
                        title: selectedMetric?.title ?? "",
                        value: selectedMetric?.value ?? 0,
                        unit: selectedMetric?.unit ?? "",
                        description: getDescription(),
                        analysis: getAnalysis()
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
            unit: variabilityUnit,
            valueFontSize: 22,
            unitFontSize: 16,
            action: { navigateAction(title: title, value: value) }
        )
    }
    
    private func navigateAction(title: String, value: Double) {
        selectedMetric = (title: title, value: value, unit: variabilityUnit)
    }
    
    private var standardDeviation: Double {
        let values = processedData.map { $0.value }
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let sumOfSquaredAvgDiff = values.map { pow($0 - mean, 2) }.reduce(0, +)
        return sqrt(sumOfSquaredAvgDiff / Double(values.count))
    }
    
    private var variabilityUnit: String {
        switch selectedTimeRange {
        case .day:
            return "\(column.name)/day"
        case .week:
            return "\(column.name)/week"
        case .month:
            return "\(column.name)/month"
        }
    }
    
    private func getDescription() -> String {
        return "Performance variability measures how much your \(column.name) fluctuates over time. A lower value indicates more consistent performance, while a higher value suggests greater variation in your results."
    }
    
    private func getAnalysis() -> String {
        let variabilityLevel: String
        if standardDeviation < 5 {
            variabilityLevel = "low"
        } else if standardDeviation < 15 {
            variabilityLevel = "moderate"
        } else {
            variabilityLevel = "high"
        }
        
        return "Your performance variability for \(column.name) is \(String(format: "%.2f", standardDeviation)) \(variabilityUnit), which is considered \(variabilityLevel). This means your performance is \(variabilityLevel == "low" ? "very consistent" : variabilityLevel == "moderate" ? "somewhat variable" : "highly variable") over the selected \(selectedTimeRange.rawValue.lowercased()) period. \(getVariabilityAdvice(level: variabilityLevel))"
    }
    
    private func getVariabilityAdvice(level: String) -> String {
        switch level {
        case "low":
            return "Keep up the good work! Consistent performance is key to long-term progress."
        case "moderate":
            return "Consider identifying factors that might be causing variations in your performance and try to stabilize them for more consistent results."
        case "high":
            return "High variability suggests there might be significant external factors affecting your performance. Try to identify and address these factors to achieve more consistent results."
        default:
            return ""
        }
    }
}
