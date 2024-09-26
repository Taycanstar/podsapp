import SwiftUI
import Charts

struct ColumnTrendView: View {
    let column: PodColumn
    let activityLogs: [PodItemActivityLog]
    @State private var chartData: [ChartDataPoint] = []

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    var body: some View {
        ZStack {
  
            ScrollView(.horizontal, showsIndicators: false) {

                Chart(chartData) {datapoint in
                    Plot {
                        LineMark(x: .value("Date", datapoint.date),
                                 y: .value("Value", datapoint.value))
                        .foregroundStyle(by: .value("Value", column.name))
                        .symbol(by: .value("Value", column.name))
                    }
                    .lineStyle(StrokeStyle(lineWidth:2))
                    .interpolationMethod(.catmullRom)
                    
                }
                .padding()
                .aspectRatio(1, contentMode: .fit)
                .chartForegroundStyleScale([column.name: Color.accentColor])
            }
            .padding()
        }
        .navigationBarTitle(column.name, displayMode: .inline)
        
        .padding()
        .onAppear {
            updateChartData()
        }
    }

    private func updateChartData() {
        let calendar = Calendar.current
        
        // Ensure we have data for every day in the range
        guard let startDate = activityLogs.map({ $0.loggedAt }).min(),
              let endDate = activityLogs.map({ $0.loggedAt }).max() else {
            return
        }
        
        var currentDate = calendar.startOfDay(for: startDate)
        let endOfRange = calendar.startOfDay(for: endDate)
        
        while currentDate <= endOfRange {
            let logsForDay = activityLogs.filter { calendar.isDate($0.loggedAt, inSameDayAs: currentDate) }
            let averageValue = logsForDay.compactMap { numericValue(for: $0) }.reduce(0, +) / Double(logsForDay.count)
            chartData.append(ChartDataPoint(date: currentDate, value: averageValue.isNaN ? 0 : averageValue))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        chartData.sort { $0.date < $1.date }
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
