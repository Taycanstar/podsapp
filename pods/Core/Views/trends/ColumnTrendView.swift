
import SwiftUI
import Charts

struct ColumnTrendView: View {
    let column: PodColumn
    let activityLogs: [PodItemActivityLog]
    @State private var chartData: [ChartDataPoint] = []
    @State private var weeklyChartData: [WeeklyChartDataPoint] = []
    @State private var monthlyChartData: [MonthlyChartDataPoint] = []
    @State private var dateRange: ClosedRange<Date> = Date()...Date()
    @State private var selectedView: ChartView = .day
    @Environment(\.colorScheme) private var colorScheme
    
    private let dayWidth: CGFloat = 40 // Width for each day
    private let weekWidth: CGFloat = 40 // Width for each week
    private let monthWidth: CGFloat = 40 // Width for each month
    private let minGapBetweenPoints: CGFloat = 20 // Minimum gap between points
    private let rightPaddingWidth: CGFloat = 100 // Width of blank space to add on the right
    private let extraDays: Int = 3 // Number of days to add before and after the data range
    private let extraWeeks: Int = 3 // Number of weeks to add before and after the data range
    private let extraMonths: Int = 3 // Number of months to add before and after the data range
    
    enum ChartView: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
    }
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    struct WeeklyChartDataPoint: Identifiable {
        let id = UUID()
        let weekOfYear: Int
        let year: Int
        let date: Date
        let value: Double
    }
    
    struct MonthlyChartDataPoint: Identifiable {
        let id = UUID()
        let month: Int
        let year: Int
        let date: Date
        let value: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            timeRangeSelector
            
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        Group {
                            switch selectedView {
                            case .day:
                                dayChart
                            case .week:
                                weekChart
                            case .month:
                                monthChart
                            }
                        }
                        .padding()
                        .frame(width: calculateChartWidth())
                        .frame(height: 300)
                        .id("chart")
                    }
                    .frame(height: 320)
                    .onAppear {
                        scrollToMostRecent(proxy: proxy)
                    }
                    .onChange(of: selectedView) { _ in
                        scrollToMostRecent(proxy: proxy)
                    }
                }
            }
            .frame(height: 320)
        }
//        .padding()
//        .navigationBarTitle(column.name, displayMode: .inline)
        .onAppear {
            updateChartData()
        }
    }
    
    private func scrollToMostRecent(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                proxy.scrollTo("chart", anchor: .trailing)
            }
        }
    }
    
    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ChartView.allCases, id: \.self) { view in
                Button(action: {
                    selectedView = view
                }) {
                    Text(view.rawValue)
                        .font(.headline)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(selectedView == view ? (colorScheme == .dark ? .white : .black) : Color("ltBg"))
                        .foregroundColor(selectedView == view ? (colorScheme == .dark ? .black : .white) : .primary)
                }
            }
        }
        .background(Color("dkBg"))
        .cornerRadius(8)
    }
    
    private var dayChart: some View {
        Chart(chartData) { datapoint in
            LineMark(
                x: .value("Day", datapoint.date),
                y: .value("Value", datapoint.value)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(Color.accentColor)
            
            PointMark(
                x: .value("Day", datapoint.date),
                y: .value("Value", datapoint.value)
            )
            .foregroundStyle(Color.accentColor)
        }
    
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self), date <= extendedDateRange.upperBound {
                    AxisValueLabel {
                        VStack(alignment: .leading) {
                            Text(date, format: .dateTime.day())
                            if date.day == 1 || value.index == 0 {
                                Text(date, format: .dateTime.month(.abbreviated))
                                    .font(.caption)
                            }
                        }
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
        .chartXScale(domain: extendedDateRange)
        .chartYAxisLabel(column.name, position: .trailing)
        .chartXAxisLabel("Day", position: .bottomTrailing)
    }
    
    private var weekChart: some View {
        let yearFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .none
            return formatter
        }()
        
        return Chart(weeklyChartData) { datapoint in
            LineMark(
                x: .value("Week", Calendar.current.dateInterval(of: .weekOfYear, for: datapoint.date)?.start ?? datapoint.date),
                y: .value("Value", datapoint.value)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(Color.accentColor)
            
            PointMark(
                x: .value("Week", Calendar.current.dateInterval(of: .weekOfYear, for: datapoint.date)?.start ?? datapoint.date),
                y: .value("Value", datapoint.value)
            )
            .foregroundStyle(Color.accentColor)
        }
  
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { value in
                if let date = value.as(Date.self) {
                    let weekOfYear = Calendar.current.component(.weekOfYear, from: date)
                    let year = Calendar.current.component(.year, from: date)
                    AxisValueLabel {
                        VStack(alignment: .leading) {
                            Text("\(weekOfYear)")
                            if weekOfYear == 1 || value.index == 0 {
                                Text(yearFormatter.string(from: NSNumber(value: year)) ?? "\(year)")
                                    .font(.caption)
                            }
                        }
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
        .chartXScale(domain: extendedWeeklyDateRange)
        .chartXAxisLabel("Week", position: .bottomTrailing)
        .chartYAxisLabel(column.name, position: .trailing)
    }
    
    private var monthChart: some View {
        let yearFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .none
            return formatter
        }()
        
        return Chart(monthlyChartData) { datapoint in
            LineMark(
                x: .value("Month", Calendar.current.dateInterval(of: .month, for: datapoint.date)?.start ?? datapoint.date),
                y: .value("Value", datapoint.value)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(Color.accentColor)
            
            PointMark(
                x: .value("Month", Calendar.current.dateInterval(of: .month, for: datapoint.date)?.start ?? datapoint.date),
                y: .value("Value", datapoint.value)
            )
            .foregroundStyle(Color.accentColor)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                if let date = value.as(Date.self) {
                    let month = Calendar.current.component(.month, from: date)
                    let year = Calendar.current.component(.year, from: date)
                    AxisValueLabel {
                        VStack(alignment: .leading) {
                            Text(date, format: .dateTime.month(.abbreviated))
                            if month == 1 || value.index == 0 {
                                Text("\(year)")
                                    .font(.caption)
                            }
                        }
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
        .chartXScale(domain: extendedMonthlyDateRange)
        .chartXAxisLabel("Month", position: .bottomTrailing)
        .chartYAxisLabel(column.name, position: .trailing)
    }
    
    private var extendedDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -extraDays, to: dateRange.lowerBound) ?? dateRange.lowerBound
        let endDate = calendar.date(byAdding: .day, value: extraDays, to: dateRange.upperBound) ?? dateRange.upperBound
        return startDate...endDate
    }
    
    private var extendedWeeklyDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        if let firstDate = weeklyChartData.first?.date,
           let lastDate = weeklyChartData.last?.date {
            let startDate = calendar.date(byAdding: .weekOfYear, value: -extraWeeks, to: firstDate) ?? firstDate
            let endDate = calendar.date(byAdding: .weekOfYear, value: extraWeeks, to: lastDate) ?? lastDate
            return startDate...endDate
        } else {
            let today = Date()
            return today...today
        }
    }
    
    private var extendedMonthlyDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        if let firstDate = monthlyChartData.first?.date,
           let lastDate = monthlyChartData.last?.date {
            let startDate = calendar.date(byAdding: .month, value: -extraMonths, to: firstDate) ?? firstDate
            let endDate = calendar.date(byAdding: .month, value: extraMonths, to: lastDate) ?? lastDate
            return startDate...endDate
        } else {
            let today = Date()
            return today...today
        }
    }
    
    private func updateWeeklyChartData() {
        let calendar = Calendar.current
        var weeklyData: [Int: (sum: Double, count: Int, date: Date)] = [:]
        
        for log in activityLogs {
            guard let value = numericValue(for: log) else { continue }
            let weekOfYear = calendar.component(.weekOfYear, from: log.loggedAt)
            let year = calendar.component(.year, from: log.loggedAt)
            let weekYear = year * 100 + weekOfYear // Unique identifier for each week
            
            if let (sum, count, _) = weeklyData[weekYear] {
                weeklyData[weekYear] = (sum + value, count + 1, log.loggedAt)
            } else {
                weeklyData[weekYear] = (value, 1, log.loggedAt)
            }
        }
        
        weeklyChartData = weeklyData.map { (weekYear, data) in
            let year = weekYear / 100
            let weekOfYear = weekYear % 100
            let averageValue = data.sum / Double(data.count)
            return WeeklyChartDataPoint(weekOfYear: weekOfYear, year: year, date: data.date, value: averageValue)
        }.sorted { $0.date < $1.date }
    }
    
    private func updateChartData() {
        chartData = activityLogs.compactMap { log -> ChartDataPoint? in
            guard let value = numericValue(for: log), value > 0 else { return nil }
            return ChartDataPoint(date: log.loggedAt, value: value)
        }.sorted { $0.date < $1.date }
        
        if let firstLog = chartData.first, let lastLog = chartData.last {
            dateRange = firstLog.date...max(lastLog.date, Date())
        }
        
        updateWeeklyChartData()
        updateMonthlyChartData()
    }
    
    private func updateMonthlyChartData() {
        let calendar = Calendar.current
        var monthlyData: [Int: (sum: Double, count: Int, date: Date)] = [:]
        
        for log in activityLogs {
            guard let value = numericValue(for: log) else { continue }
            let month = calendar.component(.month, from: log.loggedAt)
            let year = calendar.component(.year, from: log.loggedAt)
            let monthYear = year * 100 + month // Unique identifier for each month
            
            if let (sum, count, _) = monthlyData[monthYear] {
                monthlyData[monthYear] = (sum + value, count + 1, log.loggedAt)
            } else {
                monthlyData[monthYear] = (value, 1, log.loggedAt)
            }
        }
        
        monthlyChartData = monthlyData.map { (monthYear, data) in
            let year = monthYear / 100
            let month = monthYear % 100
            let averageValue = data.sum / Double(data.count)
            return MonthlyChartDataPoint(month: month, year: year, date: data.date, value: averageValue)
        }.sorted { $0.date < $1.date }
    }
    
    private func calculateChartWidth() -> CGFloat {
        switch selectedView {
        case .day:
            let calendar = Calendar.current
            guard let startDate = extendedDateRange.lowerBound.timeIntervalSince1970 as? Double,
                  let endDate = extendedDateRange.upperBound.timeIntervalSince1970 as? Double else {
                return CGFloat(chartData.count + 2 * extraDays) * dayWidth + rightPaddingWidth
            }
            
            let numberOfDays = Int(ceil((endDate - startDate) / (24 * 60 * 60)))
            return max(CGFloat(numberOfDays) * dayWidth, CGFloat(chartData.count + 2 * extraDays) * (dayWidth + minGapBetweenPoints)) + rightPaddingWidth
        case .week:
            let numberOfWeeks = weeklyChartData.count + 2 * extraWeeks
            return max(CGFloat(numberOfWeeks) * weekWidth, CGFloat(numberOfWeeks) * (weekWidth + minGapBetweenPoints)) + rightPaddingWidth
        case .month:
            let numberOfMonths = monthlyChartData.count + 2 * extraMonths
            return max(CGFloat(numberOfMonths) * monthWidth, CGFloat(numberOfMonths) * (monthWidth + minGapBetweenPoints)) + rightPaddingWidth
        }
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

extension Date {
    var day: Int {
        Calendar.current.component(.day, from: self)
    }
}
