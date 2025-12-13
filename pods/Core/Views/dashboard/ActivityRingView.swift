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
    @State private var weeklyActivityData: [NetworkManagerTwo.WeeklyActivityDay] = []
    @State private var isLoadingWeeklyData = true
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
                weeklyActivityChartSection
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
            loadWeeklyActivityData()
        }
        .onChange(of: selectedDate) { _, newDate in
            loadDataForDate(newDate)
            loadWeeklyActivityData()
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
                    value: formatCalories(totalCalories ?? caloriesBurned)
                )
                ActivityVitalCard(
                    title: "Activity Time",
                    value: formatActivityTime(activityMinutes)
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

    // MARK: - Weekly Activity Chart

    private var weeklyActivityChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Activity")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 12) {
                Text("Active Minutes")
                    .font(.headline)

                if isLoadingWeeklyData {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 160)
                } else if weeklyActivityData.isEmpty {
                    Text("No weekly data available.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 160)
                } else {
                    WeeklyActivityBarChart(days: weeklyActivityData, accentColor: activityColor)
                        .frame(height: 160)
                }
            }
            .padding()
            .background(Color("sheetcard"))
            .cornerRadius(16)
        }
    }

    // MARK: - Activity Intensity Zones (Weekly)

    private var weeklyZoneMinutesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Zones")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly Zone Breakdown")
                    .font(.headline)

                if isLoadingWeeklyData {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                } else if !hasWeeklyZoneData {
                    Text("No activity HR data this week")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(weeklyZoneMinutes) { zone in
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
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                    }

                    HStack {
                        Text("7-day total active time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatWeeklyZoneTotal())
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

    private var totalCalories: Double? {
        // Total daily calories (active + BMR) from Oura
        rawMetrics?.totalCalories
    }

    private var caloriesBurned: Double? {
        rawMetrics?.caloriesBurned
    }

    private var steps: Double? {
        rawMetrics?.steps
    }

    private var activityMinutes: Double? {
        // Sum of MET zone minutes (zones 1-5, excluding zone 0 which is rest/non-wear)
        guard let raw = rawMetrics else { return nil }

        // Prefer MET zone minutes if available
        if let zones = raw.metZoneMinutes {
            let zone1 = Double(zones.zone1 ?? 0)
            let zone2 = Double(zones.zone2 ?? 0)
            let zone3 = Double(zones.zone3 ?? 0)
            let zone4 = Double(zones.zone4 ?? 0)
            let zone5 = Double(zones.zone5 ?? 0)
            return zone1 + zone2 + zone3 + zone4 + zone5
        }

        // Fallback to high/medium/low if MET zones not available
        let high = raw.highActivityMinutes ?? 0
        let medium = raw.mediumActivityMinutes ?? 0
        let low = raw.lowActivityMinutes ?? 0
        if raw.highActivityMinutes == nil && raw.mediumActivityMinutes == nil && raw.lowActivityMinutes == nil {
            return nil
        }
        return high + medium + low
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
        // Use Oura's 6 activity contributors from rawMetrics
        let contributors = rawMetrics?.activityContributors
        var drivers: [ActivityDriver] = []

        // 1. Stay Active (Still Time)
        let stayActive = contributors?.stayActive
        drivers.append(ActivityDriver(
            name: "Stay Active",
            displayValue: stayActive.map { qualitativeLabel(for: $0).text } ?? "--",
            progress: (stayActive ?? 0) / 100,
            color: activityColor
        ))

        // 2. Move Every Hour (Stillness Alerts)
        let moveEveryHour = contributors?.moveEveryHour
        drivers.append(ActivityDriver(
            name: "Move Every Hour",
            displayValue: moveEveryHour.map { qualitativeLabel(for: $0).text } ?? "--",
            progress: (moveEveryHour ?? 0) / 100,
            color: activityColor
        ))

        // 3. Meet Daily Targets
        let meetDailyTargets = contributors?.meetDailyTargets
        drivers.append(ActivityDriver(
            name: "Meet Daily Targets",
            displayValue: meetDailyTargets.map { qualitativeLabel(for: $0).text } ?? "--",
            progress: (meetDailyTargets ?? 0) / 100,
            color: activityColor
        ))

        // 4. Training Frequency
        let trainingFrequency = contributors?.trainingFrequency
        drivers.append(ActivityDriver(
            name: "Training Frequency",
            displayValue: trainingFrequency.map { qualitativeLabel(for: $0).text } ?? "--",
            progress: (trainingFrequency ?? 0) / 100,
            color: activityColor
        ))

        // 5. Training Volume
        let trainingVolume = contributors?.trainingVolume
        drivers.append(ActivityDriver(
            name: "Training Volume",
            displayValue: trainingVolume.map { qualitativeLabel(for: $0).text } ?? "--",
            progress: (trainingVolume ?? 0) / 100,
            color: activityColor
        ))

        // 6. Recovery Time
        let recoveryTime = contributors?.recoveryTime
        drivers.append(ActivityDriver(
            name: "Recovery Time",
            displayValue: recoveryTime.map { qualitativeLabel(for: $0).text } ?? "--",
            progress: (recoveryTime ?? 0) / 100,
            color: activityColor
        ))

        return drivers
    }

    private var hasZoneData: Bool {
        guard let raw = rawMetrics else { return false }
        // We have zone data if MET zone minutes exists
        return raw.metZoneMinutes != nil
    }

    private var zoneMinutes: [ZoneRow] {
        guard let zones = rawMetrics?.metZoneMinutes else {
            return []
        }

        let zone0 = Double(zones.zone0 ?? 0)
        let zone1 = Double(zones.zone1 ?? 0)
        let zone2 = Double(zones.zone2 ?? 0)
        let zone3 = Double(zones.zone3 ?? 0)
        let zone4 = Double(zones.zone4 ?? 0)
        let zone5 = Double(zones.zone5 ?? 0)

        // Find max for relative bar sizing across all zones for consistent scaling
        let maxMinutes = max(zone0, zone1, zone2, zone3, zone4, zone5, 1)

        // Oura-matching zone colors for MET activity classification
        // Zone 0: Rest/Non-wear - systemGray5
        // Zone 1: Sedentary - light blue
        // Zone 2: Low activity - blue
        // Zone 3: Medium activity - mint
        // Zone 4: High activity - yellow
        // Zone 5: Very high activity - orange
        let lightBlue = Color(red: 0.6, green: 0.8, blue: 1.0)

        return [
            ZoneRow(label: "Zone 0", minutes: zone0, color: Color(UIColor.systemGray5), fillFraction: CGFloat(zone0 / maxMinutes)),
            ZoneRow(label: "Zone 1", minutes: zone1, color: lightBlue, fillFraction: CGFloat(zone1 / maxMinutes)),
            ZoneRow(label: "Zone 2", minutes: zone2, color: .blue, fillFraction: CGFloat(zone2 / maxMinutes)),
            ZoneRow(label: "Zone 3", minutes: zone3, color: .mint, fillFraction: CGFloat(zone3 / maxMinutes)),
            ZoneRow(label: "Zone 4", minutes: zone4, color: .yellow, fillFraction: CGFloat(zone4 / maxMinutes)),
            ZoneRow(label: "Zone 5", minutes: zone5, color: .orange, fillFraction: CGFloat(zone5 / maxMinutes)),
        ]
    }

    // MARK: - Weekly Zone Data

    private var hasWeeklyZoneData: Bool {
        // Check for activity HR zone data (from "awake" HR samples - any activity time)
        // NOT MET zones which are activity intensity classification, not heart rate zones
        for day in weeklyActivityData {
            if let zones = day.hrZoneMinutes {
                // Check if there are any non-zero active zones (zones 1-5)
                let z1: Int = zones.zone1 ?? 0
                let z2: Int = zones.zone2 ?? 0
                let z3: Int = zones.zone3 ?? 0
                let z4: Int = zones.zone4 ?? 0
                let z5: Int = zones.zone5 ?? 0
                if z1 + z2 + z3 + z4 + z5 > 0 {
                    return true
                }
            }
        }
        return false
    }

    private var weeklyZoneMinutes: [ZoneRow] {
        // Aggregate HR zone minutes from activity time across all 7 days
        // Uses hrZoneMinutes (calculated from "awake" HR samples - any activity time)
        // NOT metZoneMinutes which is activity intensity classification, not heart rate
        var zone0Total = 0
        var zone1Total = 0
        var zone2Total = 0
        var zone3Total = 0
        var zone4Total = 0
        var zone5Total = 0

        for day in weeklyActivityData {
            // Use activity HR zones (calculated from "awake" HR samples)
            if let zones = day.hrZoneMinutes {
                zone0Total += zones.zone0 ?? 0
                zone1Total += zones.zone1 ?? 0
                zone2Total += zones.zone2 ?? 0
                zone3Total += zones.zone3 ?? 0
                zone4Total += zones.zone4 ?? 0
                zone5Total += zones.zone5 ?? 0
            }
            // NOTE: Do NOT fall back to metZoneMinutes - those are all-day activity
            // classifications (MET values), not workout heart rate zones
        }

        let zone0 = Double(zone0Total)
        let zone1 = Double(zone1Total)
        let zone2 = Double(zone2Total)
        let zone3 = Double(zone3Total)
        let zone4 = Double(zone4Total)
        let zone5 = Double(zone5Total)

        // Find max for relative bar sizing across all zones
        let maxMinutes = max(zone0, zone1, zone2, zone3, zone4, zone5, 1)

        // Zone colors (matching Oura's zone display)
        // Zone 0: Non-wear/rest - gray
        // Zone 1: Light - light blue
        // Zone 2: Moderate - blue
        // Zone 3: Hard - mint/green
        // Zone 4: Very Hard - yellow
        // Zone 5: Max effort - orange/red
        let lightBlue = Color(red: 0.6, green: 0.8, blue: 1.0)

        return [
            ZoneRow(label: "Zone 0", minutes: zone0, color: Color(UIColor.systemGray5), fillFraction: CGFloat(zone0 / maxMinutes)),
            ZoneRow(label: "Zone 1", minutes: zone1, color: lightBlue, fillFraction: CGFloat(zone1 / maxMinutes)),
            ZoneRow(label: "Zone 2", minutes: zone2, color: .blue, fillFraction: CGFloat(zone2 / maxMinutes)),
            ZoneRow(label: "Zone 3", minutes: zone3, color: .mint, fillFraction: CGFloat(zone3 / maxMinutes)),
            ZoneRow(label: "Zone 4", minutes: zone4, color: .yellow, fillFraction: CGFloat(zone4 / maxMinutes)),
            ZoneRow(label: "Zone 5", minutes: zone5, color: .orange, fillFraction: CGFloat(zone5 / maxMinutes)),
        ]
    }

    private func formatWeeklyZoneTotal() -> String {
        // Sum all active zones (1-5, excluding zone 0 rest/non-wear)
        // From activity HR zones (awake time), not MET zones (intensity classification)
        var totalMinutes = 0
        for day in weeklyActivityData {
            // Use activity HR zones from awake time
            if let zones = day.hrZoneMinutes {
                totalMinutes += zones.zone1 ?? 0
                totalMinutes += zones.zone2 ?? 0
                totalMinutes += zones.zone3 ?? 0
                totalMinutes += zones.zone4 ?? 0
                totalMinutes += zones.zone5 ?? 0
            }
            // NOTE: Do NOT use metZoneMinutes - those are intensity classification, not HR zones
        }

        let hrs = totalMinutes / 60
        let mins = totalMinutes % 60
        if hrs == 0 {
            return "\(mins)m"
        }
        return "\(hrs)h \(mins)m"
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
        let totalMinutes = Int(minutes)
        let hrs = totalMinutes / 60
        let mins = totalMinutes % 60
        if hrs == 0 {
            return "\(mins)m"
        }
        return "\(hrs)h \(mins)m"
    }

    private func formatActivityTime(_ minutes: Double?) -> String {
        // Show "0m" instead of "--" when activity data exists but is 0
        let value = minutes ?? 0
        let totalMinutes = Int(value)
        let hrs = totalMinutes / 60
        let mins = totalMinutes % 60
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

    private func loadWeeklyActivityData() {
        isLoadingWeeklyData = true

        NetworkManagerTwo.shared.fetchWeeklyActivity(
            userEmail: userEmail,
            timezoneOffsetMinutes: TimeZone.current.secondsFromGMT() / 60,
            targetDate: selectedDate
        ) { result in
            isLoadingWeeklyData = false
            switch result {
            case .success(let days):
                weeklyActivityData = days
                print("[ActivityRingView] Loaded \(days.count) days of weekly activity data")
            case .failure(let error):
                weeklyActivityData = []
                print("[ActivityRingView] Failed to load weekly activity: \(error.localizedDescription)")
            }
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

private struct WeeklyActivityBarChart: View {
    let days: [NetworkManagerTwo.WeeklyActivityDay]
    let accentColor: Color

    private var maxMinutes: Int {
        let maxVal = days.compactMap { $0.totalActiveMinutes }.max() ?? 0
        return max(maxVal, 1) // Avoid division by zero
    }

    var body: some View {
        VStack(spacing: 8) {
            // Bar chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days, id: \.date) { day in
                    VStack(spacing: 4) {
                        // Bar
                        let minutes = day.totalActiveMinutes ?? 0
                        let barHeight = CGFloat(minutes) / CGFloat(maxMinutes) * 100

                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor)
                            .frame(width: 28, height: max(barHeight, 2))

                        // Day label
                        Text(String(day.dayOfWeek.prefix(1)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120, alignment: .bottom)

            // Summary row
            HStack {
                Text("7-day total")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                let totalMinutes = days.compactMap { $0.totalActiveMinutes }.reduce(0, +)
                Text(formatWeeklyTotal(totalMinutes))
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
    }

    private func formatWeeklyTotal(_ minutes: Int) -> String {
        let hrs = minutes / 60
        let mins = minutes % 60
        if hrs == 0 {
            return "\(mins)m"
        }
        return "\(hrs)h \(mins)m"
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
        caloriesBurned: 425,
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
        sleepOffset: nil,
        highActivityMinutes: 15,
        mediumActivityMinutes: 45,
        lowActivityMinutes: 120,
        sedentaryMinutes: 480,
        totalCalories: 2081,
        activityContributors: .init(
            stayActive: 85,
            moveEveryHour: 72,
            meetDailyTargets: 90,
            trainingFrequency: 78,
            trainingVolume: 65,
            recoveryTime: 88
        ),
        metZoneMinutes: .init(
            zone0: 0,
            zone1: 45,
            zone2: 134,
            zone3: 78,
            zone4: 22,
            zone5: 0
        ),
        hrZoneMinutes: .init(
            zone0: 960,
            zone1: 180,
            zone2: 120,
            zone3: 45,
            zone4: 15,
            zone5: 0
        )
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
