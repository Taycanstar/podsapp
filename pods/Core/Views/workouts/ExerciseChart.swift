//
//  ExerciseChart.swift
//  pods
//
//  Created by Dimi Nunez on 8/20/25.
//

import SwiftUI
import Charts

enum ChartMetric: String, CaseIterable {
    case reps = "Reps"
    case weight = "Weight"
    case volume = "Volume"
    case estOneRepMax = "Est. 1 Rep Max"
}

enum TimePeriod: String, CaseIterable {
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .sixMonths: return "6 Months"
        case .year: return "Year"
        }
    }
}

struct ExerciseChart: View {
    let exercise: TodayWorkoutExercise
    let metric: ChartMetric
    
    @State private var selectedPeriod: TimePeriod = .month
    @State private var showingPersonalRecord = false
    @State private var showingYourAverage = false
    @State private var cachedChartData: [TimePeriod: [(Date, Double)]] = [:]
    @Environment(\.dismiss) private var dismiss
    
    // Theme colors for record and average lines
    private var recordLineColor: Color { .yellow }
    private var averageLineColor: Color { .green }
    
    // Sample data - in real implementation, this would come from database
    private var chartData: [(Date, Double)] {
        if let cached = cachedChartData[selectedPeriod] {
            return cached
        }
        
        let data: [(Date, Double)]
        switch selectedPeriod {
        case .week:
            data = generateWeekData()
        case .month:
            data = generateMonthData()
        case .sixMonths:
            data = generateSixMonthData()
        case .year:
            data = generateYearData()
        }
        
        // Cache the data so it doesn't regenerate on every render
        DispatchQueue.main.async {
            cachedChartData[selectedPeriod] = data
        }
        
        return data
    }
    
    private var personalRecord: Double {
        chartData.map { $0.1 }.max() ?? 0
    }
    
    private var averageValue: Double {
        let values = chartData.map { $0.1 }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
    
    // Computed properties for new header design
    private var minPeriodValue: Double {
        chartData.map { $0.1 }.min() ?? 0
    }
    
    private var maxPeriodValue: Double {
        chartData.map { $0.1 }.max() ?? 0
    }
    
    private var totalPeriodVolume: Double {
        chartData.map { $0.1 }.reduce(0, +)
    }
    
    private var periodName: String {
        selectedPeriod.displayName
    }
    
    private var headlinePrimary: String {
        guard !chartData.isEmpty && chartData.map({ $0.1 }).max() != nil else {
            return "—"
        }
        
        switch metric {
        case .reps:
            // Max reps in a single set
            return String(format: "%.0f", maxPeriodValue)
        case .weight:
            // Heaviest set weight
            return formatValue(maxPeriodValue)
        case .volume:
            // Total volume
            return formatValue(totalPeriodVolume)
        case .estOneRepMax:
            // Peak estimated 1RM
            return formatValue(maxPeriodValue)
        }
    }
    
    private var metricTitle: String {
        switch metric {
        case .reps: return "Reps"
        case .weight: return "Weight"
        case .volume: return "Volume"
        case .estOneRepMax: return "Est. 1 Rep Max"
        }
    }
    
    private var valueLabel: String {
        switch metric {
        case .reps:
            return "Max reps in 1 set"
        case .weight:
            return "Heaviest set"
        case .volume:
            return "Total volume"
        case .estOneRepMax:
            return "Est. 1 rep max"
        }
    }
    
    private var dateRangeString: String {
        guard let firstDate = chartData.first?.0,
              let lastDate = chartData.last?.0 else {
            return ""
        }
        
        let formatter = DateFormatter()
        
        switch selectedPeriod {
        case .week:
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: firstDate))-\(formatter.string(from: lastDate))"
        case .month:
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: firstDate))-\(formatter.string(from: lastDate))"
        case .sixMonths:
            formatter.dateFormat = "MMM"
            let startMonth = formatter.string(from: firstDate)
            let endMonth = formatter.string(from: lastDate)
            return "\(startMonth)-\(endMonth)"
        case .year:
            formatter.dateFormat = "MMM yyyy"
            let startMonth = formatter.string(from: firstDate)
            let endMonth = formatter.string(from: lastDate)
            return "\(startMonth)-\(endMonth)"
        }
    }
    
    private var chartColor: Color {
        switch metric {
        case .reps: return .red
        case .weight: return .blue
        case .volume: return .red
        case .estOneRepMax: return .orange
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control Picker
            Picker("Time Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .onChange(of: selectedPeriod) { _ in
                // Reset overlay states when period changes
                showingPersonalRecord = false
                showingYourAverage = false
            }
            
            // Header with title, value, and date range
            VStack(alignment: .leading, spacing: 12) {
                // Title (Reps, Weight, Volume, etc.)
                Text(metricTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Value and label
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(headlinePrimary)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if !chartData.isEmpty && chartData.map({ $0.1 }).max() != nil {
                        Text(valueLabel)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Date range
                if !dateRangeString.isEmpty {
                    Text(dateRangeString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            
            // Chart with axis
            chartSection
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            
            // Record and Average buttons
            VStack(spacing: 12) {
                // Personal Record button
                Button(action: {
                    showingPersonalRecord.toggle()
                }) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "trophy")
                                .font(.system(size: 16))
                            Text("Personal Record")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(showingPersonalRecord ? .white : .primary)
                        
                        Spacer()
                        
                        Text(formatValue(personalRecord))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(showingPersonalRecord ? .white : .primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(showingPersonalRecord ? recordLineColor : Color(.systemGray6))
                    )
                }
                
                // Your Average button
                Button(action: {
                    showingYourAverage.toggle()
                }) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 16))
                            Text("Your Average")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(showingYourAverage ? .white : .primary)
                        
                        Spacer()
                        
                        Text(formatValue(averageValue))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(showingYourAverage ? .white : .primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(showingYourAverage ? averageLineColor : Color(.systemGray6))
                    )
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .navigationTitle(exercise.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private var chartSection: some View {
        VStack(spacing: 0) {
            if #available(iOS 16.0, *) {
                // Use native Charts framework for iOS 16+
                Chart {
                    ForEach(chartData, id: \.0) { item in
                        if metric == .volume {
                            BarMark(
                                x: .value("Date", item.0),
                                y: .value("Value", item.1)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [chartColor, chartColor.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(4)
                        } else {
                            LineMark(
                                x: .value("Date", item.0),
                                y: .value("Value", item.1)
                            )
                            .foregroundStyle(chartColor)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            AreaMark(
                                x: .value("Date", item.0),
                                y: .value("Value", item.1)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [chartColor.opacity(0.2), chartColor.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            
                            PointMark(
                                x: .value("Date", item.0),
                                y: .value("Value", item.1)
                            )
                            .foregroundStyle(Color(.systemBackground))
                            .symbolSize(50)
                            
                            PointMark(
                                x: .value("Date", item.0),
                                y: .value("Value", item.1)
                            )
                            .foregroundStyle(.clear)
                            .symbolSize(50)
                            .annotation(position: .overlay) {
                                Circle()
                                    .stroke(chartColor, lineWidth: 2)
                                    .frame(width: 8, height: 8)
                                    .background(Circle().fill(Color(.systemBackground)))
                            }
                        }
                    }
                    
                    // Add horizontal lines for record/average - moved outside the data loop
                    if showingPersonalRecord {
                        RuleMark(y: .value("Personal Record", personalRecord))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .foregroundStyle(recordLineColor)
                            .accessibilityLabel("Personal record line")
                    }
                    
                    if showingYourAverage {
                        RuleMark(y: .value("Average", averageValue))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .foregroundStyle(averageLineColor)
                            .accessibilityLabel("Average line")
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(preset: .aligned) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(xAxisLabel(for: date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            AxisGridLine()
                                .foregroundStyle(Color(.systemGray5))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(yAxisLabel(for: doubleValue))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        AxisGridLine()
                            .foregroundStyle(Color(.systemGray5))
                    }
                }
            } else {
                // Fallback for iOS 15 and below
                CustomChartView(
                    data: chartData,
                    color: chartColor,
                    isBarChart: metric == .volume,
                    showingPersonalRecord: showingPersonalRecord,
                    showingYourAverage: showingYourAverage,
                    personalRecord: personalRecord,
                    averageValue: averageValue,
                    recordLineColor: recordLineColor,
                    averageLineColor: averageLineColor
                )
                .frame(height: 200)
            }
        }
    }
    
    private var currentValueString: String {
        guard let latestValue = chartData.last?.1 else { return "0" }
        return formatValue(latestValue)
    }
    
    private func formatValue(_ value: Double) -> String {
        switch metric {
        case .reps:
            return String(format: "%.0f", value)
        case .weight:
            return String(format: "%.1f lb", value)
        case .volume:
            return String(format: "%.0f lb", value)
        case .estOneRepMax:
            return String(format: "%.1f lb", value)
        }
    }
    
    private var unitString: String {
        switch metric {
        case .reps:
            return "reps in 1 set"
        case .weight:
            return "lbs in 1 set"
        case .volume:
            return "lbs"
        case .estOneRepMax:
            return "lbs in 1 rep"
        }
    }
    
    private func xAxisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedPeriod {
        case .week:
            formatter.dateFormat = "E"
            return formatter.string(from: date)
        case .month:
            formatter.dateFormat = "d"
            return formatter.string(from: date)
        case .sixMonths:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        case .year:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }
    }
    
    private func yAxisLabel(for value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    // MARK: - Data Generation Methods
    
    private func generateWeekData() -> [(Date, Double)] {
        let baseValue = getBaseValue()
        return (0..<7).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let variation = Double.random(in: -0.2...0.2)
            let value = max(baseValue * (1 + variation), 0)
            return (date, value)
        }.reversed()
    }
    
    private func generateMonthData() -> [(Date, Double)] {
        let baseValue = getBaseValue()
        let dataPoints = stride(from: 0, to: 30, by: 3).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let variation = Double.random(in: -0.3...0.3)
            let value = max(baseValue * (1 + variation), 0)
            return (date, value)
        }
        return dataPoints.reversed()
    }
    
    private func generateSixMonthData() -> [(Date, Double)] {
        let baseValue = getBaseValue()
        return (0..<26).map { weekOffset in
            let date = Calendar.current.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) ?? Date()
            let variation = Double.random(in: -0.4...0.4)
            let value = max(baseValue * (1 + variation), 0)
            return (date, value)
        }.reversed()
    }
    
    private func generateYearData() -> [(Date, Double)] {
        let baseValue = getBaseValue()
        return (0..<12).map { monthOffset in
            let date = Calendar.current.date(byAdding: .month, value: -monthOffset, to: Date()) ?? Date()
            let variation = Double.random(in: -0.5...0.5)
            let value = max(baseValue * (1 + variation), 0)
            return (date, value)
        }.reversed()
    }
    
    private func getBaseValue() -> Double {
        switch metric {
        case .reps: return 15.0
        case .weight: return 52.5
        case .volume: return 2025.0
        case .estOneRepMax: return 85.3
        }
    }
}

// MARK: - Custom Chart View for iOS 15 and below

struct CustomChartView: View {
    let data: [(Date, Double)]
    let color: Color
    let isBarChart: Bool
    let showingPersonalRecord: Bool
    let showingYourAverage: Bool
    let personalRecord: Double
    let averageValue: Double
    let recordLineColor: Color
    let averageLineColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = (data.map { $0.1 }.max() ?? 1) * 1.1 // Add 10% padding
            let minValue = 0.0
            let range = maxValue - minValue
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Grid lines
                VStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 0.5)
                        if i < 4 {
                            Spacer()
                        }
                    }
                }
                
                HStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 0.5)
                        if i < 4 {
                            Spacer()
                        }
                    }
                }
                
                // Chart content
                if isBarChart {
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(Array(data.enumerated()), id: \.offset) { _, point in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [color, color.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(
                                    width: (width / CGFloat(data.count)) - 2,
                                    height: max((point.1 / maxValue) * height, 5)
                                )
                        }
                    }
                } else {
                    // Line chart with gradient
                    LinearGradient(
                        colors: [color.opacity(0.2), color.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .mask(
                        Path { path in
                            guard !data.isEmpty else { return }
                            
                            let points = data.enumerated().map { index, point in
                                CGPoint(
                                    x: CGFloat(index) * (width / CGFloat(max(data.count - 1, 1))),
                                    y: height - (point.1 / maxValue) * height
                                )
                            }
                            
                            path.move(to: CGPoint(x: points[0].x, y: height))
                            path.addLine(to: points[0])
                            
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                            
                            path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: height))
                            path.closeSubpath()
                        }
                    )
                    
                    // Line
                    Path { path in
                        guard !data.isEmpty else { return }
                        
                        let points = data.enumerated().map { index, point in
                            CGPoint(
                                x: CGFloat(index) * (width / CGFloat(max(data.count - 1, 1))),
                                y: height - (point.1 / maxValue) * height
                            )
                        }
                        
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    
                    // Data points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(color, lineWidth: 2)
                            )
                            .position(
                                x: CGFloat(index) * (width / CGFloat(max(data.count - 1, 1))),
                                y: height - (point.1 / maxValue) * height
                            )
                    }
                }
                
                // Horizontal dotted lines for record/average
                if showingPersonalRecord {
                    Path { path in
                        let y = height - (personalRecord / maxValue) * height
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(recordLineColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
                
                if showingYourAverage {
                    Path { path in
                        let y = height - (averageValue / maxValue) * height
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(averageLineColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ExerciseChart(
            exercise: TodayWorkoutExercise(
                exercise: ExerciseData(
                    id: 1,
                    name: "Barbell Curl",
                    exerciseType: "Strength",
                    bodyPart: "Arms",
                    equipment: "Barbell",
                    gender: "Both",
                    target: "Biceps",
                    synergist: "Forearms"
                ),
                sets: 3,
                reps: 10,
                weight: nil,
                restTime: 90
            ),
            metric: .weight
        )
    }
}