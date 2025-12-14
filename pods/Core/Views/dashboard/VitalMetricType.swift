//
//  VitalMetricType.swift
//  pods
//
//  Created by Dimi Nunez on 12/12/25.
//


//
//  KeyMetricView.swift
//  pods
//
//  Created by Dimi Nunez on 12/12/25.
//

import SwiftUI
import Charts

// MARK: - Vital Metric Types

enum VitalMetricType: String, CaseIterable {
    case restingHeartRate = "rhr"
    case hrv = "hrv"
    case bodyTemperature = "temperature"
    case respiratoryRate = "respiratory_rate"

    var displayName: String {
        switch self {
        case .restingHeartRate: return "Resting Heart Rate"
        case .hrv: return "HRV"
        case .bodyTemperature: return "Body Temperature"
        case .respiratoryRate: return "Respiratory Rate"
        }
    }

    var unit: String {
        switch self {
        case .restingHeartRate: return "bpm"
        case .hrv: return "ms"
        case .bodyTemperature: return "°F"
        case .respiratoryRate: return "/min"
        }
    }

    var chartColor: Color {
        switch self {
        case .restingHeartRate: return .red
        case .hrv: return .purple
        case .bodyTemperature: return .orange
        case .respiratoryRate: return .blue
        }
    }
}

enum VitalTimePeriod: String, CaseIterable {
    case day = "D"
    case week = "W"
    case month = "M"
    case year = "Y"

    var days: Int {
        switch self {
        case .day: return 7
        case .week: return 28
        case .month: return 30
        case .year: return 365
        }
    }

    var displayName: String {
        switch self {
        case .day: return "7 Days"
        case .week: return "4 Weeks"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

// MARK: - KeyMetricView

struct KeyMetricView: View {
    let metricType: VitalMetricType
    let currentValue: Double?
    let userEmail: String

    @State private var selectedPeriod: VitalTimePeriod = .month
    @State private var historyData: [NetworkManagerTwo.VitalHistoryDataPoint] = []
    @State private var average: Double?
    @State private var minValue: Double?
    @State private var maxValue: Double?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    private var chartColor: Color { metricType.chartColor }

    // MARK: - Computed Properties

    private var headlineValue: String {
        guard let value = currentValue else { return "--" }
        return formatValue(value)
    }

    private var dateRangeString: String {
        let validDates = historyData.compactMap { $0.dateValue }
        guard let firstDate = validDates.first,
              let lastDate = validDates.last else {
            return ""
        }

        let formatter = DateFormatter()

        switch selectedPeriod {
        case .day, .week, .month:
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        case .year:
            formatter.dateFormat = "MMM yyyy"
            return "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        }
    }

    private var chartData: [(Date, Double)] {
        historyData.compactMap { point -> (Date, Double)? in
            guard let date = point.dateValue, let value = point.value else { return nil }
            return (date, value)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control Picker
            Picker("Time Period", selection: $selectedPeriod) {
                ForEach(VitalTimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .onChange(of: selectedPeriod) { _, _ in
                Task { await loadData() }
            }

            if isLoading {
                KeyMetricSkeleton()
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                chartContent
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(metricType.displayName)
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
        .onAppear {
            Task { await loadData() }
        }
    }

    // MARK: - Chart Content

    private var chartContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with title, value, and date range
                VStack(alignment: .leading, spacing: 12) {
                    Text(metricType.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(headlineValue)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text(metricType.unit)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    if !dateRangeString.isEmpty {
                        Text(dateRangeString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)

                // Chart
                chartSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)

                // Stats Section
                statsSection
                    .padding(.horizontal, 16)

                Spacer()
            }
        }
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(spacing: 0) {
            if chartData.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No data for this period")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(chartData, id: \.0) { item in
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
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Average", value: average.map { formatValue($0) } ?? "--", color: chartColor)
            StatCard(title: "Min", value: minValue.map { formatValue($0) } ?? "--", color: .green)
            StatCard(title: "Max", value: maxValue.map { formatValue($0) } ?? "--", color: .red)
        }
    }

    // MARK: - Helpers

    private func formatValue(_ value: Double) -> String {
        switch metricType {
        case .restingHeartRate:
            return "\(Int(value))"
        case .hrv:
            return "\(Int(value))"
        case .bodyTemperature:
            // Convert Celsius deviation to Fahrenheit deviation
            let fahrenheitDeviation = value * 1.8
            return String(format: "%+.1f", fahrenheitDeviation)
        case .respiratoryRate:
            return String(format: "%.1f", value)
        }
    }

    private func xAxisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedPeriod {
        case .day:
            formatter.dateFormat = "E"
            return formatter.string(from: date)
        case .week, .month:
            formatter.dateFormat = "d"
            return formatter.string(from: date)
        case .year:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }
    }

    private func yAxisLabel(for value: Double) -> String {
        switch metricType {
        case .restingHeartRate, .hrv:
            return "\(Int(value))"
        case .bodyTemperature:
            let fahrenheitDeviation = value * 1.8
            return String(format: "%+.1f", fahrenheitDeviation)
        case .respiratoryRate:
            return String(format: "%.1f", value)
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true

        NetworkManagerTwo.shared.fetchVitalMetricHistory(
            userEmail: userEmail,
            metric: metricType.rawValue,
            days: selectedPeriod.days
        ) { result in
            isLoading = false
            switch result {
            case .success(let response):
                historyData = response.days
                average = response.average
                minValue = response.min
                maxValue = response.max
                print("[KeyMetricView] Loaded \(response.count) data points for \(metricType.displayName)")
            case .failure(let error):
                print("[KeyMetricView] Error loading data: \(error)")
                historyData = []
                average = nil
                minValue = nil
                maxValue = nil
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color("sheetcard"))
        .cornerRadius(12)
    }
}

// MARK: - Skeleton

private struct KeyMetricSkeleton: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        VStack(spacing: 0) {
            // Header skeleton
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 160, height: 22)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 100, height: 40)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 16)
                        .opacity(0.7)
                }
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 140, height: 14)
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 32)

            // Chart skeleton
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .padding(.bottom, 32)

            // Stats skeleton
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 80)
                }
            }

            Spacer()
        }
        .shimmer(phase: phase)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

private extension View {
    func shimmer(phase: CGFloat) -> some View {
        self.overlay(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.35),
                    Color.white.opacity(0.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .rotationEffect(.degrees(10))
            .offset(x: phase * 200)
            .blendMode(.plusLighter)
            .mask(self)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        KeyMetricView(
            metricType: .hrv,
            currentValue: 45,
            userEmail: "test@example.com"
        )
    }
}
