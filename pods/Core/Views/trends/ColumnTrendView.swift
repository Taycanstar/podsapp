//
//
//import SwiftUI
//import Charts
//
//
//
//struct ColumnTrendView: View {
//    let column: PodColumn
//    let processedData: [ProcessedDataPoint]
//    let selectedTimeRange: TimeRange
//    @Environment(\.colorScheme) private var colorScheme
//    
//    private let dayWidth: CGFloat = 40
//    private let weekWidth: CGFloat = 40
//    private let monthWidth: CGFloat = 40
//    private let minGapBetweenPoints: CGFloat = 30
//    private let rightPaddingWidth: CGFloat = 100
//    private let extraDays: Int = 1
//    private let extraWeeks: Int = 1
//    private let extraMonths: Int = 1
//    let selectedTimeUnit: TimeUnit
//    
//    @State private var selectedX: Date?
//    @State private var selectedY: Double?
//    @State private var isDragging = false
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//
//            GeometryReader { geometry in
//                ScrollViewReader { proxy in
//                    ScrollView(.horizontal, showsIndicators: false) {
//                        chart
//                            .padding()
//                            .frame(width: calculateChartWidth())
//                            .frame(height: 300)
//                            .id("chart")
//                            .chartOverlay { proxy in
//                                GeometryReader { geometry in
//                                    Rectangle()
//                                        .fill(.clear)
//                                        .contentShape(Rectangle())
//                                        .simultaneousGesture( // Change from .gesture to .simultaneousGesture
//                                            DragGesture(minimumDistance: 0)
//                                                .onChanged { value in
//                                                    let origin = geometry[proxy.plotAreaFrame].origin
//                                                    let location = CGPoint(
//                                                        x: value.location.x - origin.x,
//                                                        y: value.location.y - origin.y
//                                                    )
//                                                    
//                                                    // Convert location to chart coordinates
//                                                    if let date: Date = proxy.value(atX: location.x),
//                                                       let value: Double = proxy.value(atY: location.y) {
//                                                        
//                                                        // Find closest data point
//                                                        if let closestPoint = findClosestDataPoint(to: date) {
//                                                            selectedX = closestPoint.date
//                                                            selectedY = column.type == "time" ?
//                                                                selectedTimeUnit.convert(closestPoint.value) :
//                                                                closestPoint.value
//                                                            isDragging = true
//                                                        }
//                                                    }
//                                                }
//                                                .onEnded { _ in
//                                                    isDragging = false
//                                                }
//                                        )
//                                }
//                            }
//                    }
//                    .frame(height: 320)
//                    .onAppear {
//                        scrollToMostRecent(proxy: proxy)
//                    }
//                }
//            }
//            .frame(height: 320)
//        }
//    }
//    
//    private func findClosestDataPoint(to date: Date) -> ProcessedDataPoint? {
//         return processedData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
//     }
//     
//    
//    private var chart: some View {
//        Chart(processedData) { datapoint in
//            LineMark(
//                x: .value("Date", datapoint.date),
////                y: .value("Value", datapoint.value)
//                y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
//            )
//            .interpolationMethod(.catmullRom)
//            .lineStyle(StrokeStyle(lineWidth: 2))
//            .foregroundStyle(Color.accentColor)
//            
//            PointMark(
//                x: .value("Date", datapoint.date),
//                y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
//            )
//            .foregroundStyle(Color.accentColor)
//            // Add rule marks for selection indicator
//                 if let selectedX = selectedX, datapoint.date == selectedX {
//                     RuleMark(
//                         x: .value("Selected", selectedX)
//                     )
//                     .foregroundStyle(Color.gray.opacity(0.3))
//                     
//                     PointMark(
//                         x: .value("Selected", selectedX),
//                         y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
//                     )
//                     .foregroundStyle(Color.accentColor)
//                     .annotation {
//                         VStack {
//                             Text(datapoint.value, format: .number.precision(.fractionLength(2)))
//                                 .font(.caption)
//                                 .foregroundColor(.secondary)
//                         }
//                     }
//                 }
//             
//        }
//        .chartXAxis {
//            AxisMarks(values: .stride(by: strideBy)) { value in
//                if let date = value.as(Date.self), date <= extendedDateRange.upperBound {
//                    AxisValueLabel {
//                        VStack(alignment: .leading) {
//                            switch selectedTimeRange {
//                            case .day:
//                                Text(date, format: .dateTime.day())
//                                if date.day == 1 || value.index == 0 {
//                                    Text(date, format: .dateTime.month(.abbreviated))
//                                        .font(.caption)
//                                }
//                            case .week:
//                                let weekOfYear = Calendar.current.component(.weekOfYear, from: date)
//                                Text("\(weekOfYear)")
//                                if weekOfYear == 1 || value.index == 0 {
//                                    Text(date, format: .dateTime.year())
//                                        .font(.caption)
//                                }
//                            case .month:
//                                Text(date, format: .dateTime.month(.abbreviated))
//                                if date.month == 1 || value.index == 0 {
//                                    Text(date, format: .dateTime.year())
//                                        .font(.caption)
//                                }
//                            }
//                        }
//                    }
//                    AxisGridLine()
//                    AxisTick()
//                }
//            }
//        }
//        .chartYAxis {
//                  AxisMarks(position: .trailing) { value in
//                      AxisValueLabel {
//                          if let doubleValue = value.as(Double.self) {
//                              if column.type == "time" {
//                                  Text("\(doubleValue.formatted(.number.precision(.fractionLength(1)))) \(selectedTimeUnit.abbreviation)")
//                              } else {
//                                  Text(doubleValue.formatted())
//                              }
//                          }
//                      }
//                      AxisGridLine()
//                      AxisTick()
//                  }
//              }
//              .chartXScale(domain: extendedDateRange)
////              .chartYAxisLabel("\(column.name) (\(selectedTimeUnit.rawValue))", position: .trailing)
//              .chartYAxisLabel(column.type == "time" ? "\(column.name) (\(selectedTimeUnit.rawValue))" : column.name, position: .trailing)
//
//              .chartXAxisLabel(selectedTimeRange.rawValue, position: .bottomTrailing)
//    }
//
//
//    
//    private var strideBy: Calendar.Component {
//        switch selectedTimeRange {
//        case .day: return .day
//        case .week: return .weekOfYear
//        case .month: return .month
//        }
//    }
//    
//    private var extendedDateRange: ClosedRange<Date> {
//        guard let firstDate = processedData.first?.date else {
//            return Date()...Date()
//        }
//        
//        let calendar = Calendar.current
//        let startDate: Date
//        let endDate = Date() // Use current date as the upper bound
//        
//        switch selectedTimeRange {
//        case .day:
//            startDate = calendar.date(byAdding: .day, value: -extraDays, to: firstDate) ?? firstDate
//        case .week:
//            startDate = calendar.date(byAdding: .weekOfYear, value: -extraWeeks, to: firstDate) ?? firstDate
//        case .month:
//            startDate = calendar.date(byAdding: .month, value: -extraMonths, to: firstDate) ?? firstDate
//        }
//        
//        return startDate...endDate
//    }
//    
//    private func calculateChartWidth() -> CGFloat {
//        let calendar = Calendar.current
//        let now = Date()
//        
//        switch selectedTimeRange {
//        case .day:
//            guard let startDate = extendedDateRange.lowerBound.timeIntervalSince1970 as? Double,
//                  let endDate = now.timeIntervalSince1970 as? Double else {
//                return CGFloat(processedData.count + extraDays) * dayWidth + rightPaddingWidth
//            }
//            
//            let numberOfDays = Int(ceil((endDate - startDate) / (24 * 60 * 60))) + 1 // Add 1 to include the current day
//            return max(CGFloat(numberOfDays) * dayWidth, CGFloat(processedData.count + extraDays) * (dayWidth + minGapBetweenPoints)) + rightPaddingWidth
//        case .week:
//            let numberOfWeeks = calendar.dateComponents([.weekOfYear], from: extendedDateRange.lowerBound, to: now).weekOfYear ?? 0
//            return max(CGFloat(numberOfWeeks + 1) * weekWidth, CGFloat(processedData.count + extraWeeks) * (weekWidth + minGapBetweenPoints)) + rightPaddingWidth
//        case .month:
//            let numberOfMonths = calendar.dateComponents([.month], from: extendedDateRange.lowerBound, to: now).month ?? 0
//            return max(CGFloat(numberOfMonths + 1) * monthWidth, CGFloat(processedData.count + extraMonths) * (monthWidth + minGapBetweenPoints)) + rightPaddingWidth
//        }
//    }
//    
//    private func scrollToMostRecent(proxy: ScrollViewProxy) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            withAnimation {
//                proxy.scrollTo("chart", anchor: .trailing)
//            }
//        }
//    }
//}

//import SwiftUI
//import Charts
//
//struct ColumnTrendView: View {
//    let column: PodColumn
//    let processedData: [ProcessedDataPoint]
//    let selectedTimeRange: TimeRange
//    @Environment(\.colorScheme) private var colorScheme
//    
//    private let dayWidth: CGFloat = 40
//    private let weekWidth: CGFloat = 40
//    private let monthWidth: CGFloat = 40
//    private let minGapBetweenPoints: CGFloat = 30
//    private let rightPaddingWidth: CGFloat = 100
//    private let extraDays: Int = 1
//    private let extraWeeks: Int = 1
//    private let extraMonths: Int = 1
//    let selectedTimeUnit: TimeUnit
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            GeometryReader { geometry in
//                ScrollViewReader { proxy in
//                    ScrollView(.horizontal, showsIndicators: false) {
//                        chart
//                            .padding()
//                            .frame(width: calculateChartWidth())
//                            .frame(height: 300)
//                            .id("chart")
//                    }
//                    .frame(height: 320)
//                    .onAppear {
//                        scrollToMostRecent(proxy: proxy)
//                    }
//                }
//            }
//            .frame(height: 320)
//        }
//    }
//    
//    private func calculateChartWidth() -> CGFloat {
//        let calendar = Calendar.current
//        let now = Date()
//        
//        switch selectedTimeRange {
//        case .today, .yesterday, .last7Days:
//            // Calculate width for daily intervals (e.g., today, yesterday, last 7 days)
//            let startDate = extendedDateRange.lowerBound
//            let endDate = now
//            let numberOfDays = Int(ceil(endDate.timeIntervalSince(startDate) / (24 * 60 * 60))) + 1
//            return max(CGFloat(numberOfDays) * dayWidth, CGFloat(processedData.count + extraDays) * (dayWidth + minGapBetweenPoints)) + rightPaddingWidth
//            
//        case .last30Days:
//            // Calculate width for weekly intervals within the last 30 days
//            let numberOfWeeks = calendar.dateComponents([.weekOfYear], from: extendedDateRange.lowerBound, to: now).weekOfYear ?? 0
//            return max(CGFloat(numberOfWeeks + 1) * weekWidth, CGFloat(processedData.count + extraWeeks) * (weekWidth + minGapBetweenPoints)) + rightPaddingWidth
//            
//        case .last3Months, .last6Months, .last12Months:
//            // Calculate width for monthly intervals
//            let numberOfMonths = calendar.dateComponents([.month], from: extendedDateRange.lowerBound, to: now).month ?? 0
//            return max(CGFloat(numberOfMonths + 1) * monthWidth, CGFloat(processedData.count + extraMonths) * (monthWidth + minGapBetweenPoints)) + rightPaddingWidth
//        }
//    }
//
//    
//    private var chart: some View {
//        Chart(processedData) { datapoint in
//            LineMark(
//                x: .value("Date", datapoint.date),
//                y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
//            )
//            .interpolationMethod(.catmullRom)
//            .lineStyle(StrokeStyle(lineWidth: 2))
//            .foregroundStyle(Color.accentColor)
//        }
//        .chartXAxis {
//            AxisMarks(values: .stride(by: strideBy)) { value in
//                if let date = value.as(Date.self), date <= extendedDateRange.upperBound {
//                    AxisValueLabel {
//                        Text(date, format: .dateTime.day())
//                    }
//                }
//            }
//        }
//        .chartYAxis {
//            AxisMarks(position: .trailing) { value in
//                AxisValueLabel {
//                    if let doubleValue = value.as(Double.self) {
//                        Text("\(doubleValue.formatted(.number.precision(.fractionLength(1))))")
//                    }
//                }
//            }
//        }
//        .chartXScale(domain: extendedDateRange)
//        .chartYAxisLabel(column.type == "time" ? "\(column.name) (\(selectedTimeUnit.rawValue))" : column.name, position: .trailing)
//    }
//    
//    private var strideBy: Calendar.Component {
//        switch selectedTimeRange {
//        case .today, .yesterday, .last7Days:
//            return .day
//        case .last30Days:
//            return .weekOfYear
//        case .last3Months, .last6Months, .last12Months:
//            return .month
//        }
//    }
//
//    private var extendedDateRange: ClosedRange<Date> {
//        guard let firstDate = processedData.first?.date else {
//            return Date()...Date()
//        }
//        
//        let calendar = Calendar.current
//        let startDate: Date
//        let endDate = Date()
//        
//        switch selectedTimeRange {
//        case .today, .yesterday, .last7Days:
//            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
//        case .last30Days:
//            startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
//        case .last3Months:
//            startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
//        case .last6Months:
//            startDate = calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
//        case .last12Months:
//            startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
//        }
//        
//        return startDate...endDate
//    }
//
//    private func scrollToMostRecent(proxy: ScrollViewProxy) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            withAnimation {
//                proxy.scrollTo("chart", anchor: .trailing)
//            }
//        }
//    }
//}
//
//
//extension Date {
//    var day: Int {
//        Calendar.current.component(.day, from: self)
//    }
//    
//    var month: Int {
//        Calendar.current.component(.month, from: self)
//    }
//}
//
//enum TimeUnit: String, CaseIterable {
//    case seconds = "Seconds"
//    case minutes = "Minutes"
//    case hours = "Hours"
//    
//    func convert(_ seconds: Double) -> Double {
//        switch self {
//        case .seconds: return seconds
//        case .minutes: return seconds / 60
//        case .hours: return seconds / 3600
//        }
//    }
//    
//    var abbreviation: String {
//        switch self {
//        case .seconds: return "s"
//        case .minutes: return "min"
//        case .hours: return "hr"
//        }
//    }
//}
//
//
//import SwiftUI
//import Charts
//
//struct ColumnTrendView: View {
//    let column: PodColumn
//    let processedData: [ProcessedDataPoint]
//    let selectedTimeRange: TimeRange
//    let selectedTimeUnit: TimeUnit
//    @Environment(\.colorScheme) private var colorScheme
//    
//    private let dayWidth: CGFloat = 40
//    private let weekWidth: CGFloat = 40
//    private let monthWidth: CGFloat = 40
//    private let minGapBetweenPoints: CGFloat = 30
//    private let rightPaddingWidth: CGFloat = 100
//    private let extraDays: Int = 1
//    private let extraWeeks: Int = 1
//    private let extraMonths: Int = 1
//    
//    @State private var selectedX: Date?
//    @State private var selectedY: Double?
//    @State private var isDragging = false
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            GeometryReader { geometry in
//                ScrollViewReader { proxy in
//                    ScrollView(.horizontal, showsIndicators: false) {
//                        chart
//                            .padding()
//                            .frame(width: calculateChartWidth())
//                            .frame(height: 300)
//                            .id("chart")
//                            .chartOverlay { proxy in
//                                GeometryReader { geometry in
//                                    Rectangle()
//                                        .fill(.clear)
//                                        .contentShape(Rectangle())
//                                        .simultaneousGesture(
//                                            DragGesture(minimumDistance: 0)
//                                                .onChanged { value in
//                                                    let origin = geometry[proxy.plotAreaFrame].origin
//                                                    let location = CGPoint(
//                                                        x: value.location.x - origin.x,
//                                                        y: value.location.y - origin.y
//                                                    )
//                                                    if let date: Date = proxy.value(atX: location.x),
//                                                       let value: Double = proxy.value(atY: location.y) {
//                                                        if let closestPoint = findClosestDataPoint(to: date) {
//                                                            selectedX = closestPoint.date
//                                                            selectedY = column.type == "time" ?
//                                                                selectedTimeUnit.convert(closestPoint.value) :
//                                                                closestPoint.value
//                                                            isDragging = true
//                                                        }
//                                                    }
//                                                }
//                                                .onEnded { _ in
//                                                    isDragging = false
//                                                }
//                                        )
//                                }
//                            }
//                    }
//                    .frame(height: 320)
//                    .onAppear {
//                        scrollToMostRecent(proxy: proxy)
//                    }
//                }
//            }
//            .frame(height: 320)
//        }
//    }
//    
//    private func findClosestDataPoint(to date: Date) -> ProcessedDataPoint? {
//        return processedData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
//    }
//    
//    private var chart: some View {
//        Chart(processedData) { datapoint in
//            LineMark(
//                x: .value("Date", datapoint.date),
//                y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
//            )
//            .interpolationMethod(.catmullRom)
//            .lineStyle(StrokeStyle(lineWidth: 2))
//            .foregroundStyle(Color.accentColor)
//            
//            PointMark(
//                x: .value("Date", datapoint.date),
//                y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
//            )
//            .foregroundStyle(Color.accentColor)
//            
//            if let selectedX = selectedX, datapoint.date == selectedX {
//                RuleMark(x: .value("Selected", selectedX))
//                    .foregroundStyle(Color.gray.opacity(0.3))
//                
//                PointMark(
//                    x: .value("Selected", selectedX),
//                    y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
//                )
//                .foregroundStyle(Color.accentColor)
//                .annotation {
//                    VStack {
//                        Text(datapoint.value, format: .number.precision(.fractionLength(2)))
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                }
//            }
//        }
//        .chartXAxis {
//            AxisMarks(values: .stride(by: strideBy)) { value in
//                if let date = value.as(Date.self), date <= extendedDateRange.upperBound {
//                    AxisValueLabel {
//                        VStack(alignment: .leading) {
//                            switch selectedTimeRange {
//                            case .today, .yesterday, .last7Days, .last30Days:
//                                Text(date, format: .dateTime.day())
//                                if Calendar.current.component(.day, from: date) == 1 {
//                                    Text(date, format: .dateTime.month(.abbreviated))
//                                        .font(.caption)
//                                }
//                            case .last3Months, .last6Months, .last12Months:
//                                Text(date, format: .dateTime.month(.abbreviated))
//                                if Calendar.current.component(.month, from: date) == 1 {
//                                    Text(date, format: .dateTime.year())
//                                        .font(.caption)
//                                }
//                            }
//                        }
//                    }
//                    AxisGridLine()
//                    AxisTick()
//                }
//            }
//        }
//        .chartYAxis {
//            AxisMarks(position: .trailing) { value in
//                AxisValueLabel {
//                    if let doubleValue = value.as(Double.self) {
//                        if column.type == "time" {
//                            Text("\(doubleValue.formatted(.number.precision(.fractionLength(1)))) \(selectedTimeUnit.abbreviation)")
//                        } else {
//                            Text(doubleValue.formatted())
//                        }
//                    }
//                }
//                AxisGridLine()
//                AxisTick()
//            }
//        }
//        .chartXScale(domain: extendedDateRange)
//        .chartYAxisLabel(column.type == "time" ? "\(column.name) (\(selectedTimeUnit.rawValue))" : column.name, position: .trailing)
//        .chartXAxisLabel(selectedTimeRange.rawValue, position: .bottomTrailing)
//    }
//    
//    private var strideBy: Calendar.Component {
//        switch selectedTimeRange {
//        case .today, .yesterday, .last7Days, .last30Days:
//            return .day
//        case .last3Months, .last6Months, .last12Months:
//            return .month
//        }
//    }
//
//    private var extendedDateRange: ClosedRange<Date> {
//        guard let firstDate = processedData.first?.date else {
//            return Date()...Date()
//        }
//        
//        let calendar = Calendar.current
//        let startDate: Date
//        let endDate = Date()
//        
//        switch selectedTimeRange {
//        case .today:
//            startDate = calendar.date(byAdding: .day, value: 0, to: endDate) ?? endDate
//        case .yesterday:
//            startDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
//        case .last7Days:
//            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
//        case .last30Days:
//            startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
//        case .last3Months:
//            startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
//        case .last6Months:
//            startDate = calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
//        case .last12Months:
//            startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
//        }
//        
//        return startDate...endDate
//    }
//
//    
//    private func calculateChartWidth() -> CGFloat {
//        let calendar = Calendar.current
//        let now = Date()
//        
//        switch selectedTimeRange {
//        case .today, .yesterday, .last7Days, .last30Days:
//            // For day-based intervals (today, yesterday, last 7 days, last 30 days)
//            let startDate = extendedDateRange.lowerBound
//            let numberOfDays = Int(ceil(now.timeIntervalSince(startDate) / (24 * 60 * 60))) + 1
//            return max(CGFloat(numberOfDays) * dayWidth, CGFloat(processedData.count + extraDays) * (dayWidth + minGapBetweenPoints)) + rightPaddingWidth
//            
//        case .last3Months, .last6Months, .last12Months:
//            // For month-based intervals (last 3, 6, 12 months)
//            let numberOfMonths = calendar.dateComponents([.month], from: extendedDateRange.lowerBound, to: now).month ?? 0
//            return max(CGFloat(numberOfMonths + 1) * monthWidth, CGFloat(processedData.count + extraMonths) * (monthWidth + minGapBetweenPoints)) + rightPaddingWidth
//        }
//    }
//
//    
//    private func scrollToMostRecent(proxy: ScrollViewProxy) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            withAnimation {
//                proxy.scrollTo("chart", anchor: .trailing)
//            }
//        }
//    }
//}
import SwiftUI
import Charts

struct ColumnTrendView: View {
    let column: PodColumn
    let processedData: [ProcessedDataPoint]
    let selectedTimeRange: TimeRange
    let selectedTimeUnit: TimeUnit
    let selectedXAxisInterval: XAxisInterval
    @Environment(\.colorScheme) private var colorScheme

    private let dayWidth: CGFloat = 40
    private let weekWidth: CGFloat = 40
    private let monthWidth: CGFloat = 40
    private let minGapBetweenPoints: CGFloat = 30
    private let rightPaddingWidth: CGFloat = 100
    private let extraDays: Int = 1
    private let extraWeeks: Int = 1
    private let extraMonths: Int = 1

    @State private var selectedX: Date?
    @State private var selectedY: Double?
    @State private var isDragging = false

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
                            .chartOverlay { proxy in
                                GeometryReader { geometry in
                                    Rectangle()
                                        .fill(.clear)
                                        .contentShape(Rectangle())
                                        .simultaneousGesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    let origin = geometry[proxy.plotAreaFrame].origin
                                                    let location = CGPoint(
                                                        x: value.location.x - origin.x,
                                                        y: value.location.y - origin.y
                                                    )
                                                    if let date: Date = proxy.value(atX: location.x),
                                                       let value: Double = proxy.value(atY: location.y) {
                                                        if let closestPoint = findClosestDataPoint(to: date) {
                                                            selectedX = closestPoint.date
                                                            selectedY = column.type == "time" ?
                                                                selectedTimeUnit.convert(closestPoint.value) :
                                                                closestPoint.value
                                                            isDragging = true
                                                        }
                                                    }
                                                }
                                                .onEnded { _ in
                                                    isDragging = false
                                                }
                                        )
                                }
                            }
                    }
                    .frame(height: 320)
                    .onAppear { scrollToMostRecent(proxy: proxy) }
                }
            }
            .frame(height: 320)
        }
    }

    private func findClosestDataPoint(to date: Date) -> ProcessedDataPoint? {
        return processedData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private var chart: some View {
        Chart(processedData) { datapoint in
            LineMark(
                x: .value("Date", datapoint.date),
                y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(Color.accentColor)
            
            PointMark(
                x: .value("Date", datapoint.date),
                y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
            )
            .foregroundStyle(Color.accentColor)
            
            if let selectedX = selectedX, datapoint.date == selectedX {
                RuleMark(x: .value("Selected", selectedX))
                    .foregroundStyle(Color.gray.opacity(0.3))
                
                PointMark(
                    x: .value("Selected", selectedX),
                    y: .value("Value", column.type == "time" ? selectedTimeUnit.convert(datapoint.value) : datapoint.value)
                )
                .foregroundStyle(Color.accentColor)
                .annotation {
                    VStack {
                        Text(datapoint.value, format: .number.precision(.fractionLength(2)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: selectedXAxisInterval.calendarComponent)) { value in
                if let date = value.as(Date.self), date <= extendedDateRange.upperBound {
                    AxisValueLabel {
                        VStack(alignment: .leading) {
                            switch selectedXAxisInterval {
                            case .hour: Text(date, format: .dateTime.hour())
                            case .day: Text(date, format: .dateTime.day())
                            case .week: Text("W\(Calendar.current.component(.weekOfYear, from: date))")
                            case .month: Text(date, format: .dateTime.month(.abbreviated))
                            case .quarter: Text("Q\(Calendar.current.component(.quarter, from: date))")
                            }
                        }
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
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
        .chartYAxisLabel(column.type == "time" ? "\(column.name) (\(selectedTimeUnit.rawValue))" : column.name, position: .trailing)
    }

    private var extendedDateRange: ClosedRange<Date> {
        guard let firstDate = processedData.first?.date else {
            return Date()...Date()
        }
        
        let calendar = Calendar.current
        let startDate: Date
        let endDate = Date()
        
        switch selectedTimeRange {
        case .today:
            startDate = calendar.date(byAdding: .day, value: 0, to: endDate) ?? endDate
        case .yesterday:
            startDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        case .last7Days:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        case .last3Months:
            startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .last6Months:
            startDate = calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        case .last12Months:
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        }
        
        return startDate...endDate
    }

    private func calculateChartWidth() -> CGFloat {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .today, .yesterday, .last7Days, .last30Days:
            let startDate = extendedDateRange.lowerBound
            let numberOfDays = Int(ceil(now.timeIntervalSince(startDate) / (24 * 60 * 60))) + 1
            return max(CGFloat(numberOfDays) * dayWidth, CGFloat(processedData.count + extraDays) * (dayWidth + minGapBetweenPoints)) + rightPaddingWidth
            
        case .last3Months, .last6Months, .last12Months:
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
