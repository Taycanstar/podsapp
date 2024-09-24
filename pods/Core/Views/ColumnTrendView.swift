import SwiftUI
import Charts

struct ColumnTrendView: View {
    let column: PodColumn
    let activityLogs: [PodItemActivityLog]
    @State private var selectedTimeframe: Timeframe = .day
    @State private var selectedDate: Date = Date()
    @State private var activePointIndex: Int = 0
    @State private var currentValue: String = "N/A"
    @State private var chartData: [ChartDataPoint] = []
    @State private var dragOffset: CGFloat = 0
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    enum Timeframe: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            timeframeSelector
            currentValueDisplay
            scrollableTrendChart
            recentActivitiesSection
        }
        .padding()
        .navigationTitle(column.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("dkBg"))
        .onAppear {
            updateChartData()
            updateCurrentValue()
        }
    }
    
    private var timeframeSelector: some View {
        Picker("Timeframe", selection: $selectedTimeframe) {
            ForEach(Timeframe.allCases, id: \.self) { timeframe in
                Text(timeframe.rawValue).tag(timeframe)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: selectedTimeframe) { _ in
            updateChartData()
            activePointIndex = chartData.count - 1
            dragOffset = 0
            updateCurrentValue()
        }
    }
    
    private var currentValueDisplay: some View {
        VStack {
            Text(currentValue)
                .font(.system(size: 48, weight: .bold))
            Text("Current Value")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var scrollableTrendChart: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                chartView
                
                if !chartData.isEmpty {
                    floatingPoint
                        .position(
                            x: pointPosition(for: activePointIndex, in: geometry),
                            y: valueToYPosition(chartData[safe: activePointIndex]?.value ?? 0, in: geometry)
                        )
                }
            }
            .frame(width: max(geometry.size.width, CGFloat(chartData.count) * 50), height: 300)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                        updateActivePoint(geometry: geometry)
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                            updateActivePoint(geometry: geometry)
                        }
                    }
            )
        }
        .frame(height: 300)
    }
    
    private var chartView: some View {
        Chart(chartData) { dataPoint in
            LineMark(
                x: .value("Date", dataPoint.date),
                y: .value("Value", dataPoint.value)
            )
            .foregroundStyle(Color.blue)
            
            PointMark(
                x: .value("Date", dataPoint.date),
                y: .value("Value", dataPoint.value)
            )
            .foregroundStyle(Color.blue)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: strideBy)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: dateFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
    
    private var floatingPoint: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 20, height: 20)
            .shadow(radius: 3)
    }
    
    private var recentActivitiesSection: some View {
        VStack(alignment: .leading) {
            Text("Recent Activities")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(filteredLogs.prefix(5), id: \.id) { log in
                        VStack(alignment: .leading) {
                            Text(log.itemLabel)
                                .font(.subheadline)
                            Text(log.userName)
                                .font(.caption)
                            if let value = numericValue(for: log) {
                                Text(String(format: "%.1f", value))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                    }
                }
            }
        }
    }
    
    private var filteredLogs: [PodItemActivityLog] {
        activityLogs.filter { log in
            numericValue(for: log) != nil && isLogWithinSelectedTimeframe(log)
        }.sorted(by: { $0.loggedAt < $1.loggedAt })
    }
    
    private func updateChartData() {
        let periods = timeframePeriods
        chartData = periods.compactMap { period in
            if let value = averageValue(for: period) {
                return ChartDataPoint(date: period.start, value: value)
            }
            return nil
        }
    }
    
    private var timeframePeriods: [DateInterval] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate: Date
        
        switch selectedTimeframe {
        case .day:
            startDate = calendar.date(byAdding: .day, value: -30, to: endDate)!
        case .week:
            startDate = calendar.date(byAdding: .weekOfYear, value: -12, to: endDate)!
        case .month:
            startDate = calendar.date(byAdding: .month, value: -12, to: endDate)!
        case .year:
            startDate = calendar.date(byAdding: .year, value: -5, to: endDate)!
        }
        
        return calendar.generateDateIntervals(from: startDate, to: endDate, for: selectedTimeframe)
    }
    
    private func averageValue(for period: DateInterval) -> Double? {
        let relevantLogs = activityLogs.filter { period.contains($0.loggedAt) }
        let values = relevantLogs.compactMap { numericValue(for: $0) }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
    
    private var strideBy: Calendar.Component {
        switch selectedTimeframe {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
    
    private var dateFormat: Date.FormatStyle {
        switch selectedTimeframe {
        case .day: return .dateTime.day().month()
        case .week: return .dateTime.month().day()
        case .month: return .dateTime.month().year()
        case .year: return .dateTime.year()
        }
    }
    
    private func isLogWithinSelectedTimeframe(_ log: PodItemActivityLog) -> Bool {
        switch selectedTimeframe {
        case .day:
            return Calendar.current.isDate(log.loggedAt, inSameDayAs: selectedDate)
        case .week:
            return log.loggedAt >= Calendar.current.date(byAdding: .day, value: -7, to: selectedDate)!
        case .month:
            return log.loggedAt >= Calendar.current.date(byAdding: .month, value: -1, to: selectedDate)!
        case .year:
            return log.loggedAt >= Calendar.current.date(byAdding: .year, value: -1, to: selectedDate)!
        }
    }

    private func numericValue(for log: PodItemActivityLog) -> Double? {
        guard let columnValue = log.columnValues[column.name] else {
            return nil
        }
        
        switch columnValue {
        case .number(let value):
            return Double(value)
        case .string(let value):
            return Double(value)
        case .null:
            return nil
        }
    }
    
    private func updateCurrentValue() {
        if let dataPoint = chartData[safe: activePointIndex] {
            currentValue = String(format: "%.1f", dataPoint.value)
        } else {
            currentValue = "N/A"
        }
    }
    
    private func updateActivePoint(geometry: GeometryProxy) {
        guard !chartData.isEmpty else { return }
        let pointWidth: CGFloat = geometry.size.width / CGFloat(chartData.count - 1)
        var newIndex = Int(round(-dragOffset / pointWidth)) + activePointIndex
        newIndex = min(max(newIndex, 0), chartData.count - 1)
        
        if newIndex != activePointIndex {
            activePointIndex = newIndex
            updateCurrentValue()
        }
    }
    
    private func pointPosition(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        guard !chartData.isEmpty else { return 0 }
        let pointWidth = geometry.size.width / CGFloat(chartData.count - 1)
        return CGFloat(index) * pointWidth + dragOffset
    }
    
    private func valueToYPosition(_ value: Double, in geometry: GeometryProxy) -> CGFloat {
        guard !chartData.isEmpty else { return geometry.size.height / 2 }
        let minValue = chartData.map { $0.value }.min() ?? 0
        let maxValue = chartData.map { $0.value }.max() ?? 1
        let range = maxValue - minValue
        let normalizedValue = (value - minValue) / range
        return geometry.size.height - (normalizedValue * geometry.size.height)
    }
}

extension Calendar {
    func generateDateIntervals(from start: Date, to end: Date, for timeframe: ColumnTrendView.Timeframe) -> [DateInterval] {
        var intervals: [DateInterval] = []
        var currentDate = start
        
        while currentDate <= end {
            let nextDate: Date
            switch timeframe {
            case .day:
                nextDate = self.date(byAdding: .day, value: 1, to: currentDate)!
            case .week:
                nextDate = self.date(byAdding: .weekOfYear, value: 1, to: currentDate)!
            case .month:
                nextDate = self.date(byAdding: .month, value: 1, to: currentDate)!
            case .year:
                nextDate = self.date(byAdding: .year, value: 1, to: currentDate)!
            }
            intervals.append(DateInterval(start: currentDate, end: nextDate))
            currentDate = nextDate
        }
        
        return intervals
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
