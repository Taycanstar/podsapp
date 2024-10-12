//
//  BoundsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/11/24.
//

//import SwiftUI
//

//struct BoundsView: View {
//    let column: PodColumn
//    let processedData: [ProcessedDataPoint]
//    let selectedTimeRange: TimeRange
//    @State private var isShowingDetailedView = false
////    @State private var detailedViewData: (title: String, value: Double, unit: String) = ("", 0, "")
//    @State private var selectedMetric: (title: String, value: Double, unit: String)?
//    
//    var body: some View {
////        HStack(spacing: 10) {
////            MetricCard(
////                title: "Maximum value",
////                value: maxValue,
////                unit: column.name,
////                action: { navigateToBoundDetail(title: "Maximum value", value: maxValue) }
////            )
////            MetricCard(
////                title: "Minimum value",
////                value: minValue,
////                unit: column.name,
////                action: { navigateToBoundDetail(title: "Minimum value", value: minValue) }
////            )
////        }
////        .sheet(isPresented: $isShowingDetailedView) {
////                DetailedMetricView(
////                    title: detailedViewData.title,
////                    value: detailedViewData.value,
////                    unit: detailedViewData.unit,
////                    description: getDescription(for: detailedViewData.title),
////                    analysis: getAnalysis(for: detailedViewData.title, value: detailedViewData.value)
////                )
////            }
//        HStack(spacing: 10) {
//            NavigationLink(
//                destination: DetailedMetricView(
//                    title: selectedMetric?.title ?? "",
//                    value: selectedMetric?.value ?? 0,
//                    unit: selectedMetric?.unit ?? "",
//                    description: getDescription(for: selectedMetric?.title ?? ""),
//                    analysis: getAnalysis(for: selectedMetric?.title ?? "", value: selectedMetric?.value ?? 0)
//                ),
//                tag: "Maximum value",
//                selection: Binding(
//                    get: { selectedMetric?.title },
//                    set: { _ in selectedMetric = nil }
//                )
//            ) {
//                MetricCard(
//                    title: "Maximum value",
//                    value: maxValue,
//                    unit: column.name,
//                    action: { navigateToBoundDetail(title: "Maximum value", value: maxValue) }
//                )
//            }
//            
//            NavigationLink(
//                destination: DetailedMetricView(
//                    title: selectedMetric?.title ?? "",
//                    value: selectedMetric?.value ?? 0,
//                    unit: selectedMetric?.unit ?? "",
//                    description: getDescription(for: selectedMetric?.title ?? ""),
//                    analysis: getAnalysis(for: selectedMetric?.title ?? "", value: selectedMetric?.value ?? 0)
//                ),
//                tag: "Minimum value",
//                selection: Binding(
//                    get: { selectedMetric?.title },
//                    set: { _ in selectedMetric = nil }
//                )
//            ) {
//                MetricCard(
//                    title: "Minimum value",
//                    value: minValue,
//                    unit: column.name,
//                    action: { navigateToBoundDetail(title: "Minimum value", value: minValue) }
//                )
//            }
//        }
//    }
//    
//    private var maxValue: Double {
//        processedData.map { $0.value }.max() ?? 0
//    }
//    
//    private var minValue: Double {
//        processedData.map { $0.value }.min() ?? 0
//    }
//    
//    private func navigateToBoundDetail(title: String, value: Double) {
////          detailedViewData = (title: title, value: value, unit: column.name)
////          isShowingDetailedView = true
//        selectedMetric = (title: title, value: value, unit: column.name)
//      }
//      
//      private func getDescription(for title: String) -> String {
//          switch title {
//          case "Maximum value":
//              return "The maximum value represents the highest recorded value for \(column.name) in the selected time period."
//          case "Minimum value":
//              return "The minimum value represents the lowest recorded value for \(column.name) in the selected time period."
//          default:
//              return ""
//          }
//      }
//      
//      private func getAnalysis(for title: String, value: Double) -> String {
//          // This is where you would implement or call your AI analysis function
//          // For now, we'll return a placeholder analysis
//          return "Your \(title.lowercased()) of \(Int(round(value))) \(column.name) for the \(selectedTimeRange.rawValue.lowercased()) period indicates... [AI-generated analysis would go here]"
//      }
//}
//
//struct BoundDetailView: View {
//    let title: String
//    let value: Double
//    let column: PodColumn
//    
//    var body: some View {
//        Text("Details for \(title): \(value) \(column.name)")
//            .padding()
//            .navigationTitle(title)
//    }
//}

import SwiftUI

struct BoundsView: View {
    let column: PodColumn
    let processedData: [ProcessedDataPoint]
    let selectedTimeRange: TimeRange
    
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
            unit: column.name,
            action: { navigateToBoundDetail(title: title, value: value) }
        )
    }
    
    private var maxValue: Double {
        processedData.map { $0.value }.max() ?? 0
    }
    
    private var minValue: Double {
        processedData.map { $0.value }.min() ?? 0
    }
    
    private func navigateToBoundDetail(title: String, value: Double) {
        selectedMetric = (title: title, value: value, unit: column.name)
    }
    
    private func getDescription(for title: String) -> String {
        switch title {
        case "Maximum value":
            return "The maximum value represents the highest recorded value for \(column.name) in the selected time period."
        case "Minimum value":
            return "The minimum value represents the lowest recorded value for \(column.name) in the selected time period."
        default:
            return ""
        }
    }
    
    private func getAnalysis(for title: String, value: Double) -> String {
        return "Your \(title.lowercased()) of \(Int(round(value))) \(column.name) for the \(selectedTimeRange.rawValue.lowercased()) period indicates... [AI-generated analysis would go here]"
    }
}
