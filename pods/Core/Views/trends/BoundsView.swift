//
//  BoundsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//

import SwiftUI

//struct BoundsView: View {
//    let column: PodColumn
//    let activityLogs: [PodItemActivityLog]
//
//    
//    var body: some View {
//        HStack(spacing: 16) {
//            MetricCard(
//                title: "Maximum value",
//                value: maxValue,
//                unit: column.name,
//                action: { navigateToBoundDetail(title: "Maximum value", value: maxValue) }
//            )
//            MetricCard(
//                title: "Minimum value",
//                value: minValue,
//                unit: column.name,
//                action: { navigateToBoundDetail(title: "Minimum value", value: minValue) }
//            )
//        }
//    }
//    
//    private var maxValue: Double {
//        activityLogs.compactMap { numericValue(for: $0) }.max() ?? 0
//    }
//    
//    private var minValue: Double {
//        activityLogs.compactMap { numericValue(for: $0) }.min() ?? 0
//    }
//    
//    private func numericValue(for log: PodItemActivityLog) -> Double? {
//        guard let columnValue = log.columnValues[column.name] else { return nil }
//        switch columnValue {
//        case .number(let value): return Double(value)
//        case .string(let value): return Double(value)
//        case .null: return nil
//        }
//    }
//    
//    private func navigateToBoundDetail(title: String, value: Double) {
//        // Handle navigation here. For example:
//        // self.navigationController?.pushViewController(BoundDetailView(title: title, value: value, unit: column.name), animated: true)
//        print("Navigate to \(title) detail view with value: \(value) \(column.name)")
//    }
//}
struct BoundsView: View {
    let column: PodColumn
    let processedData: [ProcessedDataPoint]
    let selectedTimeRange: TimeRange
    
    var body: some View {
        HStack(spacing: 16) {
            MetricCard(
                title: "Maximum value",
                value: maxValue,
                unit: column.name,
                action: { navigateToBoundDetail(title: "Maximum value", value: maxValue) }
            )
            MetricCard(
                title: "Minimum value",
                value: minValue,
                unit: column.name,
                action: { navigateToBoundDetail(title: "Minimum value", value: minValue) }
            )
        }
    }
    
    private var maxValue: Double {
        processedData.map { $0.value }.max() ?? 0
    }
    
    private var minValue: Double {
        processedData.map { $0.value }.min() ?? 0
    }
    
    private func navigateToBoundDetail(title: String, value: Double) {
        print("Navigate to \(title) detail view with value: \(value) \(column.name)")
    }
}

struct BoundDetailView: View {
    let title: String
    let value: Double
    let column: PodColumn
    
    var body: some View {
        Text("Details for \(title): \(value) \(column.name)")
            .padding()
            .navigationTitle(title)
    }
}
