//
//  ReadinessView.swift
//  pods
//
//  Created by Dimi Nunez on 12/10/25.
//

import SwiftUI

struct ReadinessView: View {
    let initialSnapshot: NetworkManagerTwo.HealthMetricsSnapshot
    let initialDate: Date
    let userEmail: String

    @State private var selectedDate: Date
    @State private var snapshot: NetworkManagerTwo.HealthMetricsSnapshot?
    @State private var aiSummary: String?
    @State private var isLoadingSummary = true
    @State private var isLoadingSnapshot = false
    @State private var showDatePicker = false
    @Environment(\.colorScheme) private var colorScheme
    private let ringScale: CGFloat = 0.75

    init(initialSnapshot: NetworkManagerTwo.HealthMetricsSnapshot, initialDate: Date, userEmail: String) {
        self.initialSnapshot = initialSnapshot
        self.initialDate = initialDate
        self.userEmail = userEmail
        _selectedDate = State(initialValue: initialDate)
        _snapshot = State(initialValue: initialSnapshot)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                readinessCircleSection
                aiSummaryCard
                vitalsSection
                driversSection
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
        )
        .navigationTitle("Readiness")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .medium))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { loadAISummary() }
        .onChange(of: selectedDate) { _, newDate in
            loadDataForDate(newDate)
        }
        .sheet(isPresented: $showDatePicker) {
            ReadinessDatePickerSheet(selectedDate: $selectedDate, showSheet: $showDatePicker)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedDate, format: .dateTime.weekday(.wide).month().day())
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Readiness Circle

    private var readinessCircleSection: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 12)
                .opacity(0.15)
                .foregroundColor(readinessColor)

            Circle()
                .trim(from: 0, to: CGFloat((currentSnapshot?.readiness ?? 0) / 100))
                .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .foregroundColor(readinessColor)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: currentSnapshot?.readiness)

            VStack(spacing: 8) {
                if isLoadingSnapshot {
                    ProgressView()
                } else {
                    Text("\(Int(currentSnapshot?.readiness ?? 0))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text(readinessLabel)
                        .font(.headline)
                        .foregroundColor(readinessColor)
                }
            }
        }
        .frame(width: 200 * ringScale, height: 200 * ringScale)
        .padding(.vertical, 20)
    }

    // MARK: - AI Summary Card

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Summary")
                .font(.headline)

            if isLoadingSummary {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating summary...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(aiSummary ?? "Unable to generate summary")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color("sheetcard"))
        .cornerRadius(16)
    }

    // MARK: - Vitals Section

    private var vitalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vitals")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                VitalCard(
                    title: "Resting Heart Rate",
                    value: formatRHR(currentSnapshot?.rawMetrics?.restingHeartRate),
                    trend: calculateRHRTrend()
                )
                VitalCard(
                    title: "Heart Rate Variability",
                    value: formatHRV(currentSnapshot?.rawMetrics?.hrv),
                    trend: calculateHRVTrend()
                )
                VitalCard(
                    title: "Body Temperature",
                    value: formatTemperatureDeviation(currentSnapshot?.rawMetrics?.skinTemperatureC),
                    trend: calculateTempTrend()
                )
                VitalCard(
                    title: "Respiratory Rate",
                    value: formatRespiratoryRate(currentSnapshot?.rawMetrics?.respiratoryRate),
                    trend: calculateRRTrend()
                )
            }
        }
    }

    // MARK: - Drivers Section

    private var driversSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drivers")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(readinessDrivers) { driver in
                    DriverRow(driver: driver)
                    if driver.id != readinessDrivers.last?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .background(Color("sheetcard"))
            .cornerRadius(16)
        }
    }

    // MARK: - Computed Properties

    private var currentSnapshot: NetworkManagerTwo.HealthMetricsSnapshot? {
        snapshot
    }

    private var readinessColor: Color {
        .mint
    }

    private var readinessLabel: String {
        guard let score = currentSnapshot?.readiness else { return "No Data" }
        switch score {
        case 85...: return "Excellent"
        case 70..<85: return "Good"
        case 50..<70: return "Fair"
        default: return "Low"
        }
    }

    private var readinessDrivers: [DriverItem] {
        guard let components = currentSnapshot?.components?.readiness else {
            return []
        }

        let driverMappings: [(key: String, name: String)] = [
            ("rhr", "Resting heart rate"),
            ("hrv_balance", "HRV balance"),
            ("temperature", "Body temperature"),
            ("sleep_duration", "Recovery index"),
            ("sleep_quality", "Sleep"),
            ("activity", "Sleep balance"),
            ("respiratory_rate", "Sleep regularity"),
            ("hrv", "Previous day activity"),
        ]

        var drivers: [DriverItem] = []
        for mapping in driverMappings {
            if let score = components[mapping.key] {
                drivers.append(DriverItem(
                    name: mapping.name,
                    score: score,
                    displayValue: qualitativeLabel(for: score).text,
                    color: .mint
                ))
            }
        }

        // Add activity balance from activity components if available
        if let activityComponents = currentSnapshot?.components?.activity,
           let activityBalance = activityComponents["balance"] {
            drivers.append(DriverItem(
                name: "Activity balance",
                score: activityBalance,
                displayValue: qualitativeLabel(for: activityBalance).text,
                color: .mint
            ))
        }

        return drivers
    }

    // MARK: - Helper Functions

    private func qualitativeLabel(for score: Double) -> (text: String, color: Color) {
        switch score {
        case 80...: return ("Optimal", .mint)
        case 60..<80: return ("Good", .mint)
        case 40..<60: return ("Fair", .mint)
        default: return ("Pay attention", .mint)
        }
    }

    private func formatRHR(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value)) bpm"
    }

    private func formatHRV(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value))ms"
    }

    private func formatTemperatureDeviation(_ value: Double?) -> String {
        guard let value else { return "--" }
        // Convert C deviation to F deviation (multiply by 1.8)
        let fahrenheitDeviation = value * 1.8
        return String(format: "%+.1fF", fahrenheitDeviation)
    }

    private func formatRespiratoryRate(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f/min", value)
    }

    private func calculateRHRTrend() -> TrendInfo? {
        guard let current = currentSnapshot?.rawMetrics?.restingHeartRate else { return nil }
        // For RHR, we'd need previous day data - using baseline comparison as fallback
        // Lower is generally better for RHR
        return nil  // Will implement when we have previous day comparison
    }

    private func calculateHRVTrend() -> TrendInfo? {
        guard let current = currentSnapshot?.rawMetrics?.hrv,
              let baseline = currentSnapshot?.rawMetrics?.hrvBaseline else { return nil }

        let diff = current - baseline
        let percentChange = (diff / baseline) * 100

        if abs(percentChange) < 5 {
            return TrendInfo(direction: .stable, value: nil)
        } else if diff > 0 {
            return TrendInfo(direction: .up, value: Int(diff))
        } else {
            return TrendInfo(direction: .down, value: Int(abs(diff)))
        }
    }

    private func calculateTempTrend() -> TrendInfo? {
        guard let current = currentSnapshot?.rawMetrics?.skinTemperatureC,
              let previous = currentSnapshot?.rawMetrics?.skinTemperaturePrevious else { return nil }

        let diff = (current - previous) * 1.8  // Convert to F
        if abs(diff) < 0.1 {
            return TrendInfo(direction: .stable, value: nil)
        } else if diff > 0 {
            return TrendInfo(direction: .up, value: nil)
        } else {
            return TrendInfo(direction: .down, value: nil)
        }
    }

    private func calculateRRTrend() -> TrendInfo? {
        guard let current = currentSnapshot?.rawMetrics?.respiratoryRate,
              let previous = currentSnapshot?.rawMetrics?.respiratoryRatePrevious else { return nil }

        let diff = current - previous
        if abs(diff) < 0.5 {
            return TrendInfo(direction: .stable, value: nil)
        } else if diff > 0 {
            return TrendInfo(direction: .up, value: nil)
        } else {
            return TrendInfo(direction: .down, value: nil)
        }
    }

    // MARK: - Data Loading

    private func loadDataForDate(_ date: Date) {
        isLoadingSnapshot = true
        isLoadingSummary = true

        NetworkManagerTwo.shared.fetchHealthMetrics(
            userEmail: userEmail,
            timezoneOffsetMinutes: TimeZone.current.secondsFromGMT() / 60,
            targetDate: date
        ) { result in
            isLoadingSnapshot = false
            switch result {
            case .success(let newSnapshot):
                snapshot = newSnapshot
                loadAISummary()
            case .failure:
                snapshot = nil
                aiSummary = "Unable to load health data for this date."
                isLoadingSummary = false
            }
        }
    }

    private func loadAISummary() {
        isLoadingSummary = true

        NetworkManagerTwo.shared.fetchReadinessSummary(
            userEmail: userEmail,
            targetDate: selectedDate
        ) { result in
            isLoadingSummary = false
            switch result {
            case .success(let response):
                aiSummary = response.summary
            case .failure:
                // Fallback based on score
                if let score = currentSnapshot?.readiness {
                    if score >= 75 {
                        aiSummary = "Your body has recovered well. You're in great shape to tackle challenging workouts today."
                    } else if score >= 50 {
                        aiSummary = "Your recovery is moderate today. Consider a balanced workout and pay attention to how you feel."
                    } else {
                        aiSummary = "Your body may need extra recovery time. Consider lighter activity or rest to support your recovery."
                    }
                } else {
                    aiSummary = "Unable to generate summary. Please ensure your wearable is synced."
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct TrendInfo {
    enum Direction {
        case up, down, stable
    }
    let direction: Direction
    let value: Int?
}

struct DriverItem: Identifiable {
    let id = UUID()
    let name: String
    let score: Double
    let displayValue: String
    let color: Color
}

// MARK: - Supporting Views

struct VitalCard: View {
    let title: String
    let value: String
    let trend: TrendInfo?

    var body: some View {
        Button {
            // Tappable but no navigation yet
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .bottom) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    if let trend {
                        TrendBadge(trend: trend)
                    }
                }
            }
            .padding()
            .background(Color("sheetcard"))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TrendBadge: View {
    let trend: TrendInfo

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .font(.caption)
            if let value = trend.value {
                Text("\(value)")
                    .font(.caption)
            }
        }
        .foregroundColor(trendColor)
    }

    private var iconName: String {
        switch trend.direction {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }

    private var trendColor: Color {
        switch trend.direction {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}

struct DriverRow: View {
    let driver: DriverItem

    var body: some View {
        Button {
            // Tappable but no navigation yet
        } label: {
            VStack(spacing: 0) {
                HStack {
                    Text(driver.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(driver.displayValue)
                        .font(.body)
                        .foregroundColor(driver.color)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                .padding()

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(driver.color.opacity(0.2))
                            .frame(height: 6)

                        Capsule()
                            .fill(driver.color)
                            .frame(width: geo.size.width * (driver.score / 100), height: 6)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ReadinessDatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var showSheet: Bool

    var body: some View {
        NavigationView {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Today") {
                        selectedDate = Date()
                        showSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showSheet = false
                    }
                }
            }
        }
    }
}

#Preview {
    let mockSnapshot = NetworkManagerTwo.HealthMetricsSnapshot(
        date: "2025-12-10",
        readiness: 86,
        sleep: 78,
        activity: 65,
        stress: 42,
        confidence: "high",
        isEmpty: false,
        scoreSource: "oura",
        sourceScores: nil,
        sleepSourceDate: nil,
        components: nil,
        rawMetrics: nil
    )

    return NavigationStack {
        ReadinessView(
            initialSnapshot: mockSnapshot,
            initialDate: Date(),
            userEmail: "test@example.com"
        )
    }
}
