//
//  ActivityRingView.swift
//  pods
//
//  Created by Dimi Nunez on 12/10/25.
//

import SwiftUI

struct ActivityRingView: View {
    let initialSnapshot: NetworkManagerTwo.HealthMetricsSnapshot
    let initialDate: Date
    let userEmail: String

    @State private var selectedDate: Date
    @State private var snapshot: NetworkManagerTwo.HealthMetricsSnapshot?
    @State private var aiSummary: String?
    @State private var isLoadingSummary = true
    @State private var isLoadingSnapshot = false
    @State private var showDatePicker = false
    @EnvironmentObject private var healthViewModel: HealthKitViewModel
    private let ringScale: CGFloat = 0.75

    init(initialSnapshot: NetworkManagerTwo.HealthMetricsSnapshot, initialDate: Date, userEmail: String) {
        self.initialSnapshot = initialSnapshot
        self.initialDate = initialDate
        self.userEmail = userEmail
        _selectedDate = State(initialValue: initialDate)
        _snapshot = State(initialValue: initialSnapshot)
        print("[ActivityRingView] Initialized with snapshot from NewHomeView healthMetricsSnapshot for user \(userEmail) on \(initialDate)")
        logSnapshotData(initialSnapshot)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                activityCircleSection
                aiSummaryCard
                goalProgressCard
                vitalsSection
                driversSection
                weeklyZoneMinutesSection
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
        )
        .navigationTitle("Activity")
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
        .onAppear {
            if hasActivitySignal {
                loadAISummary()
            } else {
                isLoadingSummary = false
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            loadDataForDate(newDate)
        }
        .sheet(isPresented: $showDatePicker) {
            ActivityDatePickerSheet(selectedDate: $selectedDate, showSheet: $showDatePicker)
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

    // MARK: - Activity Circle

    private var activityCircleSection: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 12)
                .opacity(0.15)
                .foregroundColor(activityColor)

            Circle()
                .trim(from: 0, to: CGFloat(activityArcProgress))
                .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .foregroundColor(activityColor)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: activityDisplayScore)

            VStack(spacing: 8) {
                if isLoadingSnapshot {
                    ProgressView()
                } else {
                    Text(activityScoreText)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text(activityStatusText)
                        .font(.headline)
                        .foregroundColor(activityColor)
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
            } else if !hasActivitySignal {
                Text("Connect a wearable so we can give you personalized activity insights.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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

    // MARK: - Goal Progress

    private var goalProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Goal Progress")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Text(progressCurrentText)
                        .foregroundColor(activityColor)
                        .font(.headline)
                    Text("/ \(progressGoalText)")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 10)

                    Capsule()
                        .fill(activityColor)
                        .frame(width: geo.size.width * progressFraction, height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding()
        .background(Color("sheetcard"))
        .cornerRadius(16)
    }

    // MARK: - Vitals

    private var vitalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vitals")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ActivityVitalCard(
                    title: "Total Burn",
                    value: formatCalories(caloriesBurned)
                )
                ActivityVitalCard(
                    title: "Activity Time",
                    value: formatDuration(activityMinutes)
                )
                ActivityVitalCard(
                    title: "Steps",
                    value: formatSteps(steps)
                )
                ActivityVitalCard(
                    title: "Avg Heart Rate",
                    value: formatHeartRate(avgHeartRate)
                )
            }
        }
    }

    // MARK: - Drivers

    private var driversSection: some View {
        let drivers = activityDrivers

        return VStack(alignment: .leading, spacing: 12) {
            Text("Drivers")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(drivers.enumerated()), id: \.element.id) { index, driver in
                    ActivityDriverRow(driver: driver)
                    if index < drivers.count - 1 {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .background(Color("sheetcard"))
            .cornerRadius(16)
        }
    }

    // MARK: - Weekly Zone Minutes

    private var weeklyZoneMinutesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Training")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly Zone Minutes")
                    .font(.headline)

                if zoneMinutes.isEmpty {
                    Text("Zone minute data not available for this week.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(zoneMinutes) { zone in
                            HStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(zone.color)
                                        .frame(width: 8, height: 8)
                                    Text(zone.label)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 90, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(height: 18)

                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(zone.color)
                                            .frame(width: geo.size.width * zone.fillFraction, height: 18)
                                    }
                                }
                                .frame(height: 18)

                                Text(zone.minutesText)
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }

                    HStack {
                        Text("Total active time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDuration(activityMinutes))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
            .background(Color("sheetcard"))
            .cornerRadius(16)
        }
    }

    // MARK: - Computed Properties

    private var currentSnapshot: NetworkManagerTwo.HealthMetricsSnapshot? {
        snapshot
    }

    private var rawMetrics: NetworkManagerTwo.HealthMetricRawMetrics? {
        currentSnapshot?.rawMetrics
    }

    private var activityColor: Color { Color("activity") }

    private var activityDisplayScore: Double? {
        currentSnapshot?.activity
    }

    private var activityArcProgress: Double {
        guard let score = activityDisplayScore else { return 0 }
        return min(max(score / 100.0, 0), 1)
    }

    private var activityScoreText: String {
        activityDisplayScore.map { "\(Int($0))" } ?? "--"
    }

    private var activityStatusText: String {
        activityDisplayScore != nil ? activityLabel : "No Data"
    }

    private var activityLabel: String {
        guard let score = currentSnapshot?.activity else { return "No Data" }
        switch score {
        case 85...: return "Excellent"
        case 70..<85: return "Good"
        case 50..<70: return "Fair"
        default: return "Low"
        }
    }

    private var caloriesBurned: Double? {
        rawMetrics?.caloriesBurned
    }

    private var steps: Double? {
        rawMetrics?.steps
    }

    private var activityMinutes: Double? {
        // Not currently exposed in raw metrics; keep placeholder until available
        nil
    }

    private var avgHeartRate: Double? {
        // Placeholder: requires dedicated metric; fallback to resting HR if available
        rawMetrics?.restingHeartRate
    }

    private var hasActivitySignal: Bool {
        if let score = currentSnapshot?.activity, score > 0 { return true }
        if let steps, steps > 0 { return true }
        if let caloriesBurned, caloriesBurned > 0 { return true }
        return false
    }

    private var progressGoal: Double {
        // Placeholder goal; replace with user goal when available
        500
    }

    private var progressCurrent: Double {
        caloriesBurned ?? 0
    }

    private var progressFraction: CGFloat {
        guard progressGoal > 0 else { return 0 }
        return CGFloat(min(max(progressCurrent / progressGoal, 0), 1))
    }

    private var progressCurrentText: String {
        formatCalories(progressCurrent)
    }

    private var progressGoalText: String {
        formatCalories(progressGoal)
    }

    private var activityDrivers: [ActivityDriver] {
        let components = currentSnapshot?.components?.activity ?? [:]
        let volume = components["volume"]
        let balance = components["balance"]
        let caloriesComponent = components["calories"]

        var drivers: [ActivityDriver] = []

        drivers.append(ActivityDriver(
            name: "Training Frequency",
            displayValue: "--",
            progress: 0,
            color: activityColor
        ))

        if let volume {
            let label = qualitativeLabel(for: volume).text
            drivers.append(ActivityDriver(
                name: "Training Volume",
                displayValue: label,
                progress: volume / 100,
                color: activityColor
            ))
        } else {
            drivers.append(ActivityDriver(
                name: "Training Volume",
                displayValue: "--",
                progress: 0,
                color: activityColor
            ))
        }

        if let balance {
            let label = qualitativeLabel(for: balance).text
            drivers.append(ActivityDriver(
                name: "Recovery Time",
                displayValue: label,
                progress: balance / 100,
                color: activityColor
            ))
        } else {
            drivers.append(ActivityDriver(
                name: "Recovery Time",
                displayValue: "--",
                progress: 0,
                color: activityColor
            ))
        }

        drivers.append(ActivityDriver(
            name: "Active Calories",
            displayValue: formatCalories(caloriesBurned),
            progress: min(max((caloriesBurned ?? 0) / max(progressGoal, 1), 0), 1),
            color: activityColor
        ))

        drivers.append(ActivityDriver(
            name: "Steps",
            displayValue: formatSteps(steps),
            progress: min(max((steps ?? 0) / 10000.0, 0), 1),
            color: activityColor
        ))

        drivers.append(ActivityDriver(
            name: "Movement",
            displayValue: qualitativeLabel(for: activityDisplayScore ?? 0).text,
            progress: min(max((activityDisplayScore ?? 0) / 100, 0), 1),
            color: activityColor
        ))

        drivers.append(ActivityDriver(
            name: "Consistency",
            displayValue: balance.map { qualitativeLabel(for: $0).text } ?? "--",
            progress: balance.map { min(max($0 / 100, 0), 1) } ?? 0,
            color: activityColor
        ))

        return drivers
    }

    private var zoneMinutes: [ZoneRow] {
        // Placeholder until zone-minute data is available in raw metrics/components
        []
    }

    // MARK: - Helpers

    private func qualitativeLabel(for score: Double) -> (text: String, color: Color) {
        switch score {
        case 80...: return ("Optimal", activityColor)
        case 60..<80: return ("Good", activityColor)
        case 40..<60: return ("Fair", activityColor)
        default: return ("Pay attention", activityColor)
        }
    }

    private func formatCalories(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(round(value))) cals"
    }

    private func formatSteps(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(round(value)))"
    }

    private func formatHeartRate(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(round(value))) bpm"
    }

    private func formatDuration(_ minutes: Double?) -> String {
        guard let minutes else { return "--" }
        let hrs = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hrs == 0 {
            return "\(mins)m"
        }
        return "\(hrs)h \(mins)m"
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
                logSnapshotData(newSnapshot)
                if hasActivitySignal {
                    loadAISummary()
                } else {
                    aiSummary = nil
                    isLoadingSummary = false
                }
            case .failure:
                snapshot = nil
                aiSummary = "Unable to load activity data for this date."
                isLoadingSummary = false
            }
        }
    }

    private func loadAISummary() {
        isLoadingSummary = true

        NetworkManagerTwo.shared.fetchActivitySummary(
            userEmail: userEmail,
            targetDate: selectedDate
        ) { result in
            isLoadingSummary = false
            switch result {
            case .success(let response):
                aiSummary = response.summary
                print("[ActivityRingView] AI summary from API: \(response.summary)")
            case .failure:
                if let score = currentSnapshot?.activity {
                    if score >= 85 {
                        aiSummary = "Your activity levels are excellent. Intensity and volume are well-balanced for recovery and progress."
                    } else if score >= 70 {
                        aiSummary = "Good consistency this week. Keep balancing moderate and higher-intensity days to keep improving."
                    } else {
                        aiSummary = "Activity looks light. Gradually add movement and keep sessions consistent to build momentum."
                    }
                } else {
                    aiSummary = "Unable to generate summary. Please ensure your wearable is synced."
                }
                print("[ActivityRingView] AI summary fallback: \(aiSummary ?? "n/a")")
            }
        }
    }

    private func logSnapshotData(_ snapshot: NetworkManagerTwo.HealthMetricsSnapshot) {
        let activityText = snapshot.activity.map { String(format: "%.1f", $0) } ?? "n/a"
        print("[ActivityRingView] Snapshot date \(snapshot.date) — activity score: \(activityText)")

        if let raw = snapshot.rawMetrics {
            let cals = raw.caloriesBurned.map { "\(Int($0)) cals" } ?? "n/a"
            let steps = raw.steps.map { "\(Int($0))" } ?? "n/a"
            print("[ActivityRingView] Raw activity — calories: \(cals), steps: \(steps)")
        } else {
            print("[ActivityRingView] Raw metrics unavailable")
        }
    }
}

// MARK: - Supporting Models

private struct ActivityDriver: Identifiable {
    let id = UUID()
    let name: String
    let displayValue: String
    let progress: Double
    let color: Color
}

private struct ZoneRow: Identifiable {
    let id = UUID()
    let label: String
    let minutes: Double
    let color: Color
    let fillFraction: CGFloat

    var minutesText: String {
        "\(Int(round(minutes)))m"
    }
}

// MARK: - Supporting Views

private struct ActivityDriverRow: View {
    let driver: ActivityDriver

    var body: some View {
        Button {
            // Placeholder for future detail
        } label: {
            VStack(spacing: 6) {
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
                .padding(.horizontal, 16)
                .padding(.top, 12)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(driver.color.opacity(0.2))
                            .frame(height: 6)

                        Capsule()
                            .fill(driver.color)
                            .frame(width: geo.size.width * driver.progress, height: 6)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ActivityVitalCard: View {
    let title: String
    let value: String

    var body: some View {
        Button {
            // Placeholder for navigation
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

                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(Color("sheetcard"))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ActivityDatePickerSheet: View {
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
    let mockRaw = NetworkManagerTwo.HealthMetricRawMetrics(
        hrv: nil,
        hrvShortTerm: nil,
        hrvBaseline: nil,
        restingHeartRate: 58,
        sleepHours: nil,
        sleepScore: nil,
        steps: 8342,
        caloriesBurned: 2151,
        respiratoryRate: nil,
        respiratoryRatePrevious: nil,
        skinTemperatureC: nil,
        skinTemperaturePrevious: nil,
        sleepLatencyMinutes: nil,
        sleepMidpointMinutes: nil,
        sleepNeedHours: nil,
        strainRatio: nil,
        totalSleepMinutes: nil,
        sleepStageMinutes: nil,
        inBedMinutes: nil,
        sleepEfficiency: nil,
        sleepSource: nil,
        fallbackSleepDate: nil,
        hypnogram: nil,
        cumulativeSleepDebtMinutes: nil,
        sleepOnset: nil,
        sleepOffset: nil
    )

    let mockSnapshot = NetworkManagerTwo.HealthMetricsSnapshot(
        date: "2025-12-10",
        readiness: 86,
        sleep: 78,
        activity: 82,
        stress: 42,
        confidence: "high",
        isEmpty: false,
        scoreSource: "oura",
        sourceScores: nil,
        sleepSourceDate: nil,
        components: .init(readiness: nil, sleep: nil, activity: ["volume": 78, "balance": 85, "calories": 72], stress: nil),
        rawMetrics: mockRaw
    )

    NavigationStack {
        ActivityRingView(
            initialSnapshot: mockSnapshot,
            initialDate: Date(),
            userEmail: "test@example.com"
        )
    }
    .environmentObject(HealthKitViewModel())
}
