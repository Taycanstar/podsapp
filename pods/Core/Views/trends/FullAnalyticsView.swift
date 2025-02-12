
import SwiftUI
import Mixpanel

struct FullAnalyticsView: View {
    let column: PodColumn
    let activities: [Activity]
    let itemId: Int
    let getHighestValue: (Activity) -> Double?
    
    @State private var selectedTimeRange: TimeRange = .last30Days
    @State private var selectedTimeUnit: TimeUnit = .seconds
    @State private var selectedXAxisInterval: XAxisInterval = .day
    @State private var selectedMeasurement: MeasurementType = .unique
    @State private var processedData: [ProcessedDataPoint] = []
    @State private var currentStreak: Int = 0
    @State private var longestStreak: Int = 0
    @Environment(\.colorScheme) private var colorScheme
    @State private var chartProxy: ScrollViewProxy? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 22) {
                    // timeRangeDropdown
                    // xAxisIntervalDropdown
                    // measurementDropdown
                     VStack(alignment: .leading) {
                    Text("Date Range")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    timeRangeDropdown
                }
                
                VStack(alignment: .leading) {
                    Text("View By")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    xAxisIntervalDropdown
                }
                
                VStack(alignment: .leading) {
                    Text("Metric")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    measurementDropdown
                }
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
                    selectedXAxisInterval: selectedXAxisInterval,
                    proxy: $chartProxy
                )
                
                BoundsView(
                    column: column,
                    processedData: processedData,
                    selectedTimeRange: selectedTimeRange,
                    selectedTimeUnit: selectedTimeUnit
                )
                
                ConsistencyTrackerView(
                    column: column,
                    currentStreak: currentStreak,
                    longestStreak: longestStreak,
                    selectedTimeRange: selectedTimeRange
                )
                
                PerformanceVariabilityView(
                    column: column,
                    processedData: processedData,
                    selectedTimeRange: selectedTimeRange,
                    selectedTimeUnit: selectedTimeUnit
                )
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
        }
        .navigationBarTitle(column.name, displayMode: .inline)
        .onAppear {
            setDefaultsForTimeRange()
            updateProcessedData()
            Mixpanel.mainInstance().time(event: "Viewed Trends")
        }
        .onDisappear {
            Mixpanel.mainInstance().track(event: "Viewed Trends", properties: [
                "column_name": column.name,
                "time_range": selectedTimeRange.rawValue,
                "measurement_type": selectedMeasurement.rawValue
            ])
        }
        .onChange(of: selectedTimeRange) { _, _ in
            setDefaultsForTimeRange()
            updateProcessedData()
            scrollToRecentData()
        }
        .onChange(of: selectedXAxisInterval) { _, _ in
            scrollToRecentData()
        }
        .onChange(of: selectedMeasurement) { _, _ in
            updateProcessedData()
            scrollToRecentData()
        }
    }
    
    private func scrollToRecentData() {
        if let proxy = chartProxy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    proxy.scrollTo("chart", anchor: .trailing)
                }
            }
        }
    }
    
    private func setDefaultsForTimeRange() {
        switch selectedTimeRange {
        case .last7Days:
            selectedXAxisInterval = .day
            selectedMeasurement = .unique
        case .last30Days:
            selectedXAxisInterval = .day
            selectedMeasurement = .unique
        case .last3Months:
            selectedXAxisInterval = .week
            selectedMeasurement = .average
        case .last6Months:
            selectedXAxisInterval = .week
            selectedMeasurement = .average
        case .last12Months:
            selectedXAxisInterval = .month
            selectedMeasurement = .average
        default:
            selectedXAxisInterval = .day
            selectedMeasurement = .unique
        }
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
    
    private var measurementDropdown: some View {
        DropdownButton(
            label: "Measurement",
            options: MeasurementType.allCases,
            selectedOption: $selectedMeasurement
        )
    }

    private func updateProcessedData() {
        switch selectedMeasurement {
        case .unique:
            processedData = fetchUniqueData(for: selectedTimeRange)
        default:
            processedData = fetchAggregateData(for: selectedTimeRange, measurement: selectedMeasurement)
        }
        calculateStreaks()
    }
    
    private func fetchUniqueData(for timeRange: TimeRange) -> [ProcessedDataPoint] {
        let calendar = Calendar.current
        let startDate = timeRange.startDate(using: calendar)
        
        return activities
            .filter { $0.loggedAt >= startDate }
            .compactMap { activity in
                guard let value = getHighestValue(activity) else { return nil }
                return ProcessedDataPoint(date: activity.loggedAt, value: value)
            }
            .sorted(by: { $0.date < $1.date })
    }

    private func fetchAggregateData(for timeRange: TimeRange, measurement: MeasurementType) -> [ProcessedDataPoint] {
        let calendar = Calendar.current
        let startDate = timeRange.startDate(using: calendar)
        
        // Group activities by date interval
        var groupedData: [Date: [Double]] = [:]
        
        for activity in activities where activity.loggedAt >= startDate {
            guard let value = getHighestValue(activity) else { continue }
            let intervalStart = calendar.startOfDay(for: activity.loggedAt)
            groupedData[intervalStart, default: []].append(value)
        }

        return groupedData.map { (date, values) in
            let aggregatedValue: Double
            switch measurement {
            case .sum:
                aggregatedValue = values.reduce(0, +)
            case .average:
                aggregatedValue = values.reduce(0, +) / Double(values.count)
            case .max:
                aggregatedValue = values.max() ?? 0
            case .min:
                aggregatedValue = values.min() ?? 0
            case .unique:
                aggregatedValue = values.last ?? 0
            case .median:
                let sortedValues = values.sorted()
                if sortedValues.count % 2 == 0 {
                    aggregatedValue = (sortedValues[sortedValues.count / 2 - 1] + sortedValues[sortedValues.count / 2]) / 2
                } else {
                    aggregatedValue = sortedValues[sortedValues.count / 2]
                }
            }
            return ProcessedDataPoint(date: date, value: aggregatedValue)
        }
        .sorted { $0.date < $1.date }
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
// Enum to define measurement types
enum MeasurementType: String, CaseIterable {
    case unique = "Individual"
    case sum = "Sum"
    case average = "Average"
    case max = "Max"
    case min = "Min"
    case median = "Median"
}

// Struct for processed data points
struct ProcessedDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// Extension for time ranges
extension TimeRange {
    func startDate(using calendar: Calendar) -> Date {
        switch self {
        case .today:
            return calendar.startOfDay(for: Date())
        case .yesterday:
            return calendar.date(byAdding: .day, value: -1, to: Date())!
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: Date())!
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: Date())!
        case .last3Months:
            return calendar.date(byAdding: .month, value: -3, to: Date())!
        case .last6Months:
            return calendar.date(byAdding: .month, value: -6, to: Date())!
        case .last12Months:
            return calendar.date(byAdding: .year, value: -1, to: Date())!
        }
    }

    func intervalComponent() -> Calendar.Component {
        switch self {
        case .today, .yesterday, .last7Days, .last30Days:
            return .day
        case .last3Months, .last6Months, .last12Months:
            return .month
        }
    }
}

// Enums for time range and X-axis intervals remain unchanged
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
//    case hour = "Hour"
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    
    var calendarComponent: Calendar.Component {
        switch self {
//        case .hour: return .hour
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .quarter: return .month
        }
    }
}
