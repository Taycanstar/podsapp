//
//  BoundsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//

import SwiftUI

struct BoundsView: View {
    let column: PodColumn
    let processedData: [ProcessedDataPoint]
    let selectedTimeRange: TimeRange
    let selectedTimeUnit: TimeUnit
    
    @State private var selectedMetric: (title: String, value: Double, unit: String)?
    
    var body: some View {
        HStack(spacing: 10) {
            metricCardWithNavigation(title: "Maximum value", value: maxValue)
            metricCardWithNavigation(title: "Minimum value", value: minValue)
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
//            unit: column.name,
            unit: column.type == "time" ? selectedTimeUnit.abbreviation : column.name,
            action: { navigateToBoundDetail(title: title, value: value) }
        )
    }
    
    private func formatValue(_ value: Double) -> String {
         if value.truncatingRemainder(dividingBy: 1) == 0 {
             return "\(Int(value))"
         } else {
             return String(format: "%.1f", value)
         }
     }
    

    private var maxValue: Double {
         let value = processedData.map { $0.value }.max() ?? 0
         return column.type == "time" ? selectedTimeUnit.convert(value) : value
     }
     
     private var minValue: Double {
         let value = processedData.map { $0.value }.min() ?? 0
         return column.type == "time" ? selectedTimeUnit.convert(value) : value
     }
    
    private func navigateToBoundDetail(title: String, value: Double) {
        selectedMetric = (title: title,
                          value: value,
//                          unit: column.name
                          unit: column.type == "time" ? selectedTimeUnit.abbreviation : column.name
        )
    }
    
    private func getDescription(for title: String) -> String {
        switch title {
        case "Maximum value":
            return "The maximum value reflects your peak performance for \(column.name) during the selected period. Tracking your highest achievements helps you identify strengths, set benchmarks, and push your limits over time."

        case "Minimum value":
            return "The minimum value shows the lowest recorded performance for \(column.name) within the selected period. Monitoring these lows can help you identify patterns, address weaknesses, and maintain consistency in your progress."

        default:
            return ""
        }
    }

    
    private func getAnalysis(for title: String, value: Double) -> String {
        return "Your \(title.lowercased()) of \(Int(round(value))) \(column.name) for the \(selectedTimeRange.rawValue.lowercased()) period indicates... [AI-generated analysis would go here]"
    }
}
