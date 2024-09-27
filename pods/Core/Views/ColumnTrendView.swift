
//import SwiftUI
//import Charts
//
//struct ColumnTrendView: View {
//    let column: PodColumn
//    let activityLogs: [PodItemActivityLog]
//    @State private var chartData: [ChartDataPoint] = []
//    @State private var startDate: Date = Date()
//    @State private var endDate: Date = Date()
//    @State private var currentMonth: String = ""
//
//    struct ChartDataPoint: Identifiable {
//        let id = UUID()
//        let date: Date
//        let value: Double
//    }
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            // Day label at the top
//            HStack {
//                Text("Day")
//                    .font(.headline)
//                    .padding(.horizontal)
//                Spacer()
//            }
//            .background(Color.gray.opacity(0.2))
//            .cornerRadius(8)
//            
//            ScrollView(.horizontal, showsIndicators: false) {
//                VStack {
//                    Chart {
//                        ForEach(chartData) { datapoint in
//                            LineMark(
//                                x: .value("Date", datapoint.date),
//                                y: .value("Value", datapoint.value)
//                            )
//                            .lineStyle(StrokeStyle(lineWidth: 2))
//                            .foregroundStyle(Color.accentColor)
//                            
//                            PointMark(
//                                x: .value("Date", datapoint.date),
//                                y: .value("Value", datapoint.value)
//                            )
//                            .foregroundStyle(Color.accentColor)
//                        }
//                    }
//                    .chartXAxis {
//                        AxisMarks(values: .stride(by: .day)) { value in
//                            if let date = value.as(Date.self) {
//                                AxisValueLabel {
//                                    Text(date, format: .dateTime.day())
//                                }
//                                AxisGridLine()
//                                AxisTick()
//                            }
//                        }
//                    }
//                    .chartYAxis {
//                        AxisMarks(position: .leading)
//                    }
//                    .chartXScale(domain: startDate...endDate)
//                    .chartYAxisLabel(column.name)
//                    .frame(height: 300)
//                    .frame(width: max(UIScreen.main.bounds.width - 40, CGFloat(chartData.count * 30)))
//                    
//                    // Dynamic month label
//                    Text(currentMonth)
//                        .font(.subheadline)
//                        .padding(.top, 5)
//                }
//            }
//            .padding()
//        }
//        .padding()
//        .navigationBarTitle(column.name, displayMode: .inline)
//        .onAppear {
//            updateChartData()
//        }
//    }
//
//    private func updateChartData() {
//        let calendar = Calendar.current
//        let relevantLogs = activityLogs.filter { log in
//            guard let value = numericValue(for: log) else { return false }
//            return value > 0
//        }.sorted { $0.loggedAt < $1.loggedAt }
//        
//        if let firstLog = relevantLogs.first, let lastLog = relevantLogs.last {
//            startDate = calendar.startOfDay(for: firstLog.loggedAt)
//            endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastLog.loggedAt))!
//            currentMonth = firstLog.loggedAt.formatted(.dateTime.month(.wide))
//        }
//        
//        chartData = relevantLogs.compactMap { log in
//            guard let value = numericValue(for: log) else { return nil }
//            let alignedDate = calendar.startOfDay(for: log.loggedAt)
//            return ChartDataPoint(date: alignedDate, value: value)
//        }
//        
//        // Aggregate values for the same day
//        let groupedData = Dictionary(grouping: chartData, by: { $0.date })
//        chartData = groupedData.map { (date, points) in
//            let averageValue = points.map { $0.value }.reduce(0, +) / Double(points.count)
//            return ChartDataPoint(date: date, value: averageValue)
//        }.sorted { $0.date < $1.date }
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
    @State private var dateRange: ClosedRange<Date> = Date()...Date()
    
    private let dayWidth: CGFloat = 40 // Increased width for each day
    private let minGapBetweenPoints: CGFloat = 20 // Minimum gap between points
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Day")
                .font(.headline)
                .padding(.horizontal)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
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
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(date, format: .dateTime.day())
                                    }
                                }
                                AxisGridLine()
                                AxisTick()
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .trailing)
                        }
                        .chartXScale(domain: dateRange)
                        .chartYAxisLabel(column.name, position: .trailing)
                        .frame(width: max(geometry.size.width, calculateChartWidth()))
                        .frame(height: 300)
                        .id("chart")
                    }
                    .frame(height: 320) // Fixed height for the scroll view
                    .onAppear {
                        // Scroll to the most recent data point
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                proxy.scrollTo("chart", anchor: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .navigationBarTitle(column.name, displayMode: .inline)
        .onAppear {
            updateChartData()
        }
    }
    
    private func updateChartData() {
        chartData = activityLogs.compactMap { log -> ChartDataPoint? in
            guard let value = numericValue(for: log), value > 0 else { return nil }
            return ChartDataPoint(date: log.loggedAt, value: value)
        }.sorted { $0.date < $1.date }
        
        if let firstLog = chartData.first, let lastLog = chartData.last {
            dateRange = firstLog.date...max(lastLog.date, Date())
        }
    }
    
    private func calculateChartWidth() -> CGFloat {
        let calendar = Calendar.current
        guard let startDate = dateRange.lowerBound.timeIntervalSince1970 as? Double,
              let endDate = dateRange.upperBound.timeIntervalSince1970 as? Double else {
            return CGFloat(chartData.count) * dayWidth
        }
        
        let numberOfDays = Int(ceil((endDate - startDate) / (24 * 60 * 60)))
        return max(CGFloat(numberOfDays) * dayWidth, CGFloat(chartData.count) * (dayWidth + minGapBetweenPoints))
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
