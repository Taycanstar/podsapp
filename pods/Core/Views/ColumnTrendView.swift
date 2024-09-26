//import SwiftUI
//import Charts
//
//struct ColumnTrendView: View {
//    let column: PodColumn
//    let activityLogs: [PodItemActivityLog]
//    @State private var chartData: [ChartDataPoint] = []
//
//    struct ChartDataPoint: Identifiable {
//        let id = UUID()
//        let date: Date
//        let value: Double
//    }
//
//    var body: some View {
//        ZStack {
//
//            ScrollView(.horizontal, showsIndicators: false) {
//
//                Chart(chartData) {datapoint in
//                    Plot {
//                        LineMark(x: .value("Date", datapoint.date),
//                                 y: .value("Value", datapoint.value))
//                        .foregroundStyle(by: .value("Value", column.name))
//                        .symbol(by: .value("Value", column.name))
//                    }
//                    .lineStyle(StrokeStyle(lineWidth:2))
//                    .interpolationMethod(.catmullRom)
//                    
//                }
//                .padding()
//                .aspectRatio(1, contentMode: .fit)
//                .chartForegroundStyleScale([column.name: Color.accentColor])
//            }
//            .padding()
//        }
//        .navigationBarTitle(column.name, displayMode: .inline)
//        
//        .padding()
//        .onAppear {
//            updateChartData()
//        }
//    }
//
//    private func updateChartData() {
//        let calendar = Calendar.current
//        
//        // Ensure we have data for every day in the range
//        guard let startDate = activityLogs.map({ $0.loggedAt }).min(),
//              let endDate = activityLogs.map({ $0.loggedAt }).max() else {
//            return
//        }
//        
//        var currentDate = calendar.startOfDay(for: startDate)
//        let endOfRange = calendar.startOfDay(for: endDate)
//        
//        while currentDate <= endOfRange {
//            let logsForDay = activityLogs.filter { calendar.isDate($0.loggedAt, inSameDayAs: currentDate) }
//            let averageValue = logsForDay.compactMap { numericValue(for: $0) }.reduce(0, +) / Double(logsForDay.count)
//            chartData.append(ChartDataPoint(date: currentDate, value: averageValue.isNaN ? 0 : averageValue))
//            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
//        }
//        
//        chartData.sort { $0.date < $1.date }
//    }
//
//    private func numericValue(for log: PodItemActivityLog) -> Double? {
//        guard let columnValue = log.columnValues[column.name] else { return nil }
//        
//        switch columnValue {
//        case .number(let value): return Double(value)
//        case .string(let value): return Double(value)
//        case .null: return nil
//        }
//    }
//}
import SwiftUI
import Charts

struct ColumnTrendView: View {
    let column: PodColumn
    let activityLogs: [PodItemActivityLog]
    @State private var chartData: [ChartDataPoint] = []
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(chartData) { datapoint in
                        LineMark(
                            x: .value("Date", datapoint.date),
                            y: .value("Value", datapoint.value)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(Color.accentColor)
                        
                        PointMark(
                            x: .value("Date", datapoint.date),
                            y: .value("Value", datapoint.value)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.day())
                            }
                            AxisGridLine()
                            AxisTick()
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXScale(domain: startDate...endDate)
                .chartXAxisLabel("Day", alignment: .center)
                .chartYAxisLabel(column.name)
                .frame(height: 300)
                .frame(width: max(UIScreen.main.bounds.width - 40, CGFloat(chartData.count * 30)))
                .padding()
            }
        }
        .padding()
        .navigationBarTitle(column.name, displayMode: .inline)
        .onAppear {
            updateChartData()
        }
    }

    private func updateChartData() {
        let calendar = Calendar.current
        let relevantLogs = activityLogs.filter { log in
            guard let value = numericValue(for: log) else { return false }
            return value > 0
        }.sorted { $0.loggedAt < $1.loggedAt }
        
        if let firstLog = relevantLogs.first, let lastLog = relevantLogs.last {
            startDate = calendar.startOfDay(for: firstLog.loggedAt)
            endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastLog.loggedAt))!
        }
        
        chartData = relevantLogs.compactMap { log in
            guard let value = numericValue(for: log) else { return nil }
            let alignedDate = calendar.startOfDay(for: log.loggedAt)
            return ChartDataPoint(date: alignedDate, value: value)
        }
        
        // Aggregate values for the same day
        let groupedData = Dictionary(grouping: chartData, by: { $0.date })
        chartData = groupedData.map { (date, points) in
            let averageValue = points.map { $0.value }.reduce(0, +) / Double(points.count)
            return ChartDataPoint(date: date, value: averageValue)
        }.sorted { $0.date < $1.date }
        
        print("Total logs: \(activityLogs.count)")
        print("Chart data points: \(chartData.count)")
        print("Date range: \(startDate) to \(endDate)")
        
        // Print each data point for debugging
        chartData.forEach { point in
            print("Date: \(point.date), Value: \(point.value)")
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
