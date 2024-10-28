

import SwiftUI
import Charts



struct ColumnTrendView: View {
    let column: PodColumn
    let processedData: [ProcessedDataPoint]
    let selectedTimeRange: TimeRange
    @Environment(\.colorScheme) private var colorScheme
    
    private let dayWidth: CGFloat = 40
    private let weekWidth: CGFloat = 40
    private let monthWidth: CGFloat = 40
    private let minGapBetweenPoints: CGFloat = 30
    private let rightPaddingWidth: CGFloat = 100
    private let extraDays: Int = 1
    private let extraWeeks: Int = 1
    private let extraMonths: Int = 1
    let selectedTimeUnit: TimeUnit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        chart
                            .padding()
                            .frame(width: calculateChartWidth())
                            .frame(height: 300)
                            .id("chart")
                    }
                    .frame(height: 320)
                    .onAppear {
                        scrollToMostRecent(proxy: proxy)
                    }
                }
            }
            .frame(height: 320)
        }
    }
    
    private var chart: some View {
        Chart(processedData) { datapoint in
            LineMark(
                x: .value("Date", datapoint.date),
//                y: .value("Value", datapoint.value)
                y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(Color.accentColor)
            
            PointMark(
                x: .value("Date", datapoint.date),
//                y: .value("Value", datapoint.value)
                y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
            )
            .foregroundStyle(Color.accentColor)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: strideBy)) { value in
                if let date = value.as(Date.self), date <= extendedDateRange.upperBound {
                    AxisValueLabel {
                        VStack(alignment: .leading) {
                            switch selectedTimeRange {
                            case .day:
                                Text(date, format: .dateTime.day())
                                if date.day == 1 || value.index == 0 {
                                    Text(date, format: .dateTime.month(.abbreviated))
                                        .font(.caption)
                                }
                            case .week:
                                let weekOfYear = Calendar.current.component(.weekOfYear, from: date)
                                Text("\(weekOfYear)")
                                if weekOfYear == 1 || value.index == 0 {
                                    Text(date, format: .dateTime.year())
                                        .font(.caption)
                                }
                            case .month:
                                Text(date, format: .dateTime.month(.abbreviated))
                                if date.month == 1 || value.index == 0 {
                                    Text(date, format: .dateTime.year())
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
//        .chartYAxis {
//            AxisMarks(position: .trailing)
//        }
//        .chartXScale(domain: extendedDateRange)
//        .chartYAxisLabel(column.name, position: .trailing)
//        .chartXAxisLabel(selectedTimeRange.rawValue, position: .bottomTrailing)
        .chartYAxis {
                  AxisMarks(position: .trailing) { value in
                      AxisValueLabel {
                          if let doubleValue = value.as(Double.self) {
                              if column.type == "time" {
                                  Text("\(doubleValue.formatted(.number.precision(.fractionLength(1)))) \(selectedTimeUnit.abbreviation)")
                              } else {
                                  Text(doubleValue.formatted())
                              }
                          }
                      }
                      AxisGridLine()
                      AxisTick()
                  }
              }
              .chartXScale(domain: extendedDateRange)
              .chartYAxisLabel("\(column.name) (\(selectedTimeUnit.rawValue))", position: .trailing)
              .chartXAxisLabel(selectedTimeRange.rawValue, position: .bottomTrailing)
    }


    
    private var strideBy: Calendar.Component {
        switch selectedTimeRange {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }
    
    private var extendedDateRange: ClosedRange<Date> {
        guard let firstDate = processedData.first?.date else {
            return Date()...Date()
        }
        
        let calendar = Calendar.current
        let startDate: Date
        let endDate = Date() // Use current date as the upper bound
        
        switch selectedTimeRange {
        case .day:
            startDate = calendar.date(byAdding: .day, value: -extraDays, to: firstDate) ?? firstDate
        case .week:
            startDate = calendar.date(byAdding: .weekOfYear, value: -extraWeeks, to: firstDate) ?? firstDate
        case .month:
            startDate = calendar.date(byAdding: .month, value: -extraMonths, to: firstDate) ?? firstDate
        }
        
        return startDate...endDate
    }
    
    private func calculateChartWidth() -> CGFloat {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .day:
            guard let startDate = extendedDateRange.lowerBound.timeIntervalSince1970 as? Double,
                  let endDate = now.timeIntervalSince1970 as? Double else {
                return CGFloat(processedData.count + extraDays) * dayWidth + rightPaddingWidth
            }
            
            let numberOfDays = Int(ceil((endDate - startDate) / (24 * 60 * 60))) + 1 // Add 1 to include the current day
            return max(CGFloat(numberOfDays) * dayWidth, CGFloat(processedData.count + extraDays) * (dayWidth + minGapBetweenPoints)) + rightPaddingWidth
        case .week:
            let numberOfWeeks = calendar.dateComponents([.weekOfYear], from: extendedDateRange.lowerBound, to: now).weekOfYear ?? 0
            return max(CGFloat(numberOfWeeks + 1) * weekWidth, CGFloat(processedData.count + extraWeeks) * (weekWidth + minGapBetweenPoints)) + rightPaddingWidth
        case .month:
            let numberOfMonths = calendar.dateComponents([.month], from: extendedDateRange.lowerBound, to: now).month ?? 0
            return max(CGFloat(numberOfMonths + 1) * monthWidth, CGFloat(processedData.count + extraMonths) * (monthWidth + minGapBetweenPoints)) + rightPaddingWidth
        }
    }
    
    private func scrollToMostRecent(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                proxy.scrollTo("chart", anchor: .trailing)
            }
        }
    }
}

extension Date {
    var day: Int {
        Calendar.current.component(.day, from: self)
    }
    
    var month: Int {
        Calendar.current.component(.month, from: self)
    }
}

enum TimeUnit: String, CaseIterable {
    case seconds = "Seconds"
    case minutes = "Minutes"
    case hours = "Hours"
    
    func convert(_ seconds: Double) -> Double {
        switch self {
        case .seconds: return seconds
        case .minutes: return seconds / 60
        case .hours: return seconds / 3600
        }
    }
    
    var abbreviation: String {
        switch self {
        case .seconds: return "s"
        case .minutes: return "min"
        case .hours: return "hr"
        }
    }
}
