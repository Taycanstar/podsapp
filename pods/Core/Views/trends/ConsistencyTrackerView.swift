
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
    
    //    private var streakUnit: String {
    //        switch selectedTimeRange {
    //        case .day: return "days"
    //        case .week: return "weeks"
    //        case .month: return "months"
    //        }
    //    }
    private var streakUnit: String {
        switch selectedTimeRange {
        case .today, .yesterday, .last7Days, .last30Days:
            return "days"
        case .last3Months, .last6Months, .last12Months:
            return "months"
        }
    }

}
