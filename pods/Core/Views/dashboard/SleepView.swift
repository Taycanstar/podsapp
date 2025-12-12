//
//  SleepView.swift
//  pods
//
//  Created by Dimi Nunez on 12/10/25.
//

import SwiftUI

struct SleepView: View {
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
        print("[SleepView] Initialized with snapshot from NewHomeView healthMetricsSnapshot for user \(userEmail) on \(initialDate)")
        logSnapshotData(initialSnapshot)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                sleepCircleSection
                aiSummaryCard
                vitalsSection
                sleepDebtCard
                driversSection
                timeAsleepSection
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
        )
        .navigationTitle("Sleep")
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
            if hasSleepSignal {
                loadAISummary()
            } else {
                isLoadingSummary = false
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            loadDataForDate(newDate)
        }
        .sheet(isPresented: $showDatePicker) {
            SleepDatePickerSheet(selectedDate: $selectedDate, showSheet: $showDatePicker)
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

    // MARK: - Sleep Circle

    private var sleepCircleSection: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 12)
                .opacity(0.15)
                .foregroundColor(sleepColor)

            Circle()
                .trim(from: 0, to: CGFloat(sleepArcProgress))
                .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .foregroundColor(sleepColor)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: sleepDisplayScore)

            VStack(spacing: 8) {
                if isLoadingSnapshot {
                    ProgressView()
                } else {
                    Text(sleepScoreText)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text(sleepStatusText)
                        .font(.headline)
                        .foregroundColor(sleepColor)
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
            } else if !hasSleepSignal {
                Text("Connect a wearable so we can give you personalized sleep insights.")
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

    // MARK: - Vitals

    private var vitalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vitals")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                SleepVitalCard(
                    title: "Total Sleep",
                    value: formatDuration(totalSleepMinutes)
                )
                SleepVitalCard(
                    title: "Time in Bed",
                    value: formatDuration(timeInBedMinutes)
                )
                SleepVitalCard(
                    title: "Sleep Efficiency",
                    value: formatEfficiency(sleepEfficiency)
                )
                SleepVitalCard(
                    title: "Resting Heart Rate",
                    value: formatRHR(restingHeartRateSource)
                )
            }
        }
    }

    // MARK: - Sleep Debt

    private var sleepDebtCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Debt")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(formatDuration(sleepDebtMinutes))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(sleepDebtLabel)
                        .font(.subheadline)
                        .foregroundColor(sleepDebtTint)
                        .textCase(.uppercase)
                }

                HStack(spacing: 8) {
                    ForEach(1...4, id: \.self) { level in
                        Capsule()
                            .fill(level == sleepDebtLevel ? sleepDebtTint : Color.gray.opacity(0.2))
                            .frame(height: 8)
                    }
                }

                HStack {
                    Text("None")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("High")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color("sheetcard"))
        .cornerRadius(16)
    }

    // MARK: - Drivers

    private var driversSection: some View {
        let drivers = sleepDrivers

        return VStack(alignment: .leading, spacing: 12) {
            Text("Drivers")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(drivers.enumerated()), id: \.element.id) { index, driver in
                    SleepDriverRow(driver: driver)
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

    // MARK: - Sleep Stages

    private var timeAsleepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stages")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 12) {
                // Time asleep header
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time asleep")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Total duration \(formatDuration(timeInBedMinutes))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                // 4-row hypnogram visualization
                if let hypnogramData = hypnogramEntries, !hypnogramData.isEmpty {
                    hypnogramView(entries: hypnogramData)
                } else if let segments = stageSegments, !segments.isEmpty {
                    // Fallback to simple bar if no hypnogram data
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.08))
                                .frame(height: 40)

                            HStack(spacing: 0) {
                                ForEach(segments) { segment in
                                    RoundedRectangle(cornerRadius: 0)
                                        .fill(segment.color)
                                        .frame(width: geo.size.width * segment.percentage, height: 40)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(height: 40)
                } else {
                    Text("Sleep stage data not available for this night.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 8) {
                    ForEach(stageRows) { row in
                        HStack {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(row.color)
                                    .frame(width: 28, height: 8)
                                Text(row.label)
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            Text(row.durationText)
                                .foregroundColor(.primary)
                            Text(row.percentText)
                                .foregroundColor(.secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color("sheetcard"))
            .cornerRadius(16)
        }
    }

    // MARK: - Hypnogram View

    @ViewBuilder
    private func hypnogramView(entries: [HypnogramEntry]) -> some View {
        VStack(spacing: 0) {
            // 4-row hypnogram using Canvas for efficiency (avoids creating hundreds of views)
            let rowHeight: CGFloat = 16
            let rowSpacing: CGFloat = 4
            let totalHeight = rowHeight * 4 + rowSpacing * 3

            Canvas { context, size in
                let entryCount = entries.count
                guard entryCount > 0 else { return }
                let unitWidth = size.width / CGFloat(entryCount)

                // Row configs: (stage, yOffset, color)
                let rows: [(Int, CGFloat, Color)] = [
                    (4, 0, Color.gray.opacity(0.5)),                    // Awake
                    (3, rowHeight + rowSpacing, Color("sleep").opacity(0.5)),  // REM
                    (2, (rowHeight + rowSpacing) * 2, Color("sleep").opacity(0.75)), // Light
                    (1, (rowHeight + rowSpacing) * 3, Color("sleep"))  // Deep
                ]

                for (stage, yOffset, color) in rows {
                    // Find consecutive runs of this stage and draw single rectangles
                    var runStart: Int? = nil
                    for i in 0..<entryCount {
                        let isThisStage = entries[i].stage == stage
                        if isThisStage && runStart == nil {
                            runStart = i
                        } else if !isThisStage && runStart != nil {
                            // End of run - draw rectangle
                            let x = CGFloat(runStart!) * unitWidth
                            let width = CGFloat(i - runStart!) * unitWidth
                            let rect = CGRect(x: x, y: yOffset, width: width, height: rowHeight)
                            let path = RoundedRectangle(cornerRadius: 4).path(in: rect)
                            context.fill(path, with: .color(color))
                            runStart = nil
                        }
                    }
                    // Handle run that extends to the end
                    if let start = runStart {
                        let x = CGFloat(start) * unitWidth
                        let width = CGFloat(entryCount - start) * unitWidth
                        let rect = CGRect(x: x, y: yOffset, width: width, height: rowHeight)
                        let path = RoundedRectangle(cornerRadius: 4).path(in: rect)
                        context.fill(path, with: .color(color))
                    }
                }
            }
            .frame(height: totalHeight)

            // X-axis with 4 time labels
            HStack {
                Text(sleepStartTimeLabel)
                Spacer()
                Text(sleepQuarter1TimeLabel)
                Spacer()
                Text(sleepQuarter2TimeLabel)
                Spacer()
                Text(sleepEndTimeLabel)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 8)
        }
    }

    // MARK: - Computed Properties

    private var currentSnapshot: NetworkManagerTwo.HealthMetricsSnapshot? {
        snapshot
    }

    private var rawMetrics: NetworkManagerTwo.HealthMetricRawMetrics? {
        currentSnapshot?.rawMetrics
    }

    private var sleepColor: Color { Color("sleep") }

    private var sleepDisplayScore: Double? {
        hasSleepSignal ? currentSnapshot?.sleep : nil
    }

    private var sleepArcProgress: Double {
        guard let score = sleepDisplayScore else { return 0 }
        return min(max(score / 100.0, 0), 1)
    }

    private var sleepScoreText: String {
        sleepDisplayScore.map { "\(Int($0))" } ?? "--"
    }

    private var sleepStatusText: String {
        sleepDisplayScore != nil ? sleepLabel : "No Data"
    }

    private var sleepLabel: String {
        guard let score = currentSnapshot?.sleep else { return "No Data" }
        switch score {
        case 85...: return "Excellent"
        case 70..<85: return "Good"
        case 50..<70: return "Fair"
        default: return "Low"
        }
    }

    private var totalSleepMinutes: Double? {
        if let total = rawMetrics?.totalSleepMinutes, total > 0 { return total }
        if let hours = rawMetrics?.sleepHours, hours > 0 { return hours * 60 }
        if let stages = rawMetrics?.sleepStageMinutes {
            let totals = [stages.deep, stages.rem, stages.core].compactMap { $0 }
            let sum = totals.reduce(0, +)
            return sum > 0 ? sum : nil
        }
        return nil
    }

    private var timeInBedMinutes: Double? {
        rawMetrics?.inBedMinutes
    }

    private var sleepEfficiency: Double? {
        rawMetrics?.sleepEfficiency
    }

    private var restingHeartRateSource: Double? {
        rawMetrics?.restingHeartRate ?? (healthViewModel.isAuthorized ? healthViewModel.restingHeartRate : nil)
    }

    private var sleepNeedHours: Double? {
        rawMetrics?.sleepNeedHours
    }

    private var sleepDebtMinutes: Double? {
        // Use cumulative sleep debt from backend if available (14-day weighted calculation)
        if let cumulativeDebt = rawMetrics?.cumulativeSleepDebtMinutes, cumulativeDebt > 0 {
            return cumulativeDebt
        }
        // Fallback to single-day calculation
        guard let need = sleepNeedHours else { return nil }
        let actualHours = totalSleepMinutes.map { $0 / 60 } ?? rawMetrics?.sleepHours
        guard let actualHours else { return nil }
        let debtHours = max(0, need - actualHours)
        return debtHours > 0 ? debtHours * 60 : 0
    }

    private var sleepDebtLabel: String {
        guard let debt = sleepDebtMinutes else { return "--" }
        let hours = debt / 60
        switch hours {
        case 0..<1: return "Low"
        case 1..<3: return "Moderate"
        case 3..<6: return "High"
        default: return "Very High"
        }
    }

    private var sleepDebtLevel: Int {
        guard let debt = sleepDebtMinutes else { return 0 }
        let hours = debt / 60
        switch hours {
        case 0..<1: return 1
        case 1..<3: return 2
        case 3..<6: return 3
        default: return 4
        }
    }

    private var sleepDebtTint: Color {
        sleepDebtLevel >= 3 ? .orange : sleepColor
    }

    private var hasSleepSignal: Bool {
        if let raw = rawMetrics {
            if let total = raw.totalSleepMinutes, total > 0 { return true }
            if let hours = raw.sleepHours, hours > 0 { return true }
            if let inBed = raw.inBedMinutes, inBed > 0 { return true }
            if let stages = raw.sleepStageMinutes {
                let totals = [stages.deep, stages.rem, stages.core, stages.awake].compactMap { $0 }
                if totals.contains(where: { $0 > 0 }) { return true }
            }
        }
        return false
    }

    private var sleepDrivers: [SleepDriver] {
        let totalMinutes = totalSleepMinutes ?? 0
        let efficiencyScore = normalizedEfficiencyPercent

        var drivers: [SleepDriver] = []

        drivers.append(SleepDriver(
            name: "Total Sleep",
            displayValue: formatDuration(totalSleepMinutes),
            progress: min(max(progressForTotalSleep(totalMinutes), 0), 1),
            color: sleepColor
        ))

        drivers.append(SleepDriver(
            name: "Efficiency",
            displayValue: formatEfficiency(sleepEfficiency),
            progress: efficiencyScore,
            color: sleepColor
        ))

        drivers.append(SleepDriver(
            name: "Restfulness",
            displayValue: restfulnessDisplay,
            progress: restfulnessProgress,
            color: sleepColor
        ))

        drivers.append(SleepDriver(
            name: "REM Sleep",
            displayValue: formatDuration(rawMetrics?.sleepStageMinutes?.rem),
            progress: percent(of: rawMetrics?.sleepStageMinutes?.rem, total: totalSleepMinutes),
            color: sleepColor
        ))

        drivers.append(SleepDriver(
            name: "Deep Sleep",
            displayValue: formatDuration(rawMetrics?.sleepStageMinutes?.deep),
            progress: percent(of: rawMetrics?.sleepStageMinutes?.deep, total: totalSleepMinutes),
            color: sleepColor
        ))

        drivers.append(SleepDriver(
            name: "Latency",
            displayValue: formatDuration(rawMetrics?.sleepLatencyMinutes),
            progress: latencyProgress,
            color: sleepColor
        ))

        drivers.append(SleepDriver(
            name: "Timing",
            displayValue: timingDisplay,
            progress: timingProgress,
            color: sleepColor
        ))

        return drivers
    }

    private var normalizedEfficiencyPercent: Double {
        guard let efficiency = sleepEfficiency else { return 0 }
        let percent = efficiency <= 1.5 ? efficiency * 100 : efficiency
        return min(max(percent / 100, 0), 1)
    }

    private var restfulnessDisplay: String {
        guard let continuityScore = componentsSleep?["continuity"] else { return "--" }
        return qualitativeLabel(for: continuityScore).text
    }

    private var restfulnessProgress: Double {
        guard let continuityScore = componentsSleep?["continuity"] else { return 0 }
        return min(max(continuityScore / 100, 0), 1)
    }

    private var latencyProgress: Double {
        guard let latency = rawMetrics?.sleepLatencyMinutes else { return 0 }
        let capped = max(min(latency, 30), 0)
        return 1 - (capped / 30)
    }

    private var timingProgress: Double {
        guard let timing = componentsSleep?["timing"] else { return 0 }
        return min(max(timing / 100, 0), 1)
    }

    private var timingDisplay: String {
        guard let timing = componentsSleep?["timing"] else { return "--" }
        return qualitativeLabel(for: timing).text
    }

    private var componentsSleep: [String: Double]? {
        currentSnapshot?.components?.sleep
    }

    private var stageSegments: [SleepStageSegment]? {
        guard let stages = rawMetrics?.sleepStageMinutes else { return nil }
        let total = totalSleepMinutes ?? 0
        guard total > 0 else { return nil }

        let segments: [(Double?, Color)] = [
            (stages.awake, Color.gray.opacity(0.4)),
            (stages.rem, Color("sleep").opacity(0.6)),
            (stages.core, Color("sleep").opacity(0.8)),
            (stages.deep, Color("sleep"))
        ]

        return segments.compactMap { minutes, color in
            guard let minutes, minutes > 0 else { return nil }
            return SleepStageSegment(
                id: UUID(),
                percentage: minutes / total,
                color: color
            )
        }
    }

    private var stageRows: [StageRow] {
        let total = totalSleepMinutes ?? 0
        guard total > 0 else { return [] }

        let stages = [
            ("Awake", rawMetrics?.sleepStageMinutes?.awake, Color.gray.opacity(0.4)),
            ("REM", rawMetrics?.sleepStageMinutes?.rem, Color("sleep").opacity(0.6)),
            ("Light", rawMetrics?.sleepStageMinutes?.core, Color("sleep").opacity(0.8)),
            ("Deep", rawMetrics?.sleepStageMinutes?.deep, Color("sleep"))
        ]

        return stages.compactMap { label, minutes, color in
            guard let minutes, minutes > 0 else { return nil }
            let percent = Int(round((minutes / total) * 100))
            return StageRow(
                id: UUID(),
                label: label,
                durationText: formatDuration(minutes),
                percentText: "\(percent)%",
                color: color
            )
        }
    }

    private var sleepWindowText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        guard let start = sleepStartDate, let end = sleepEndDate else { return "--" }
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private var sleepStartDate: Date? {
        // First try to use actual sleep onset time from Oura
        if let onsetString = rawMetrics?.sleepOnset,
           let onset = ISO8601DateFormatter().date(from: onsetString) {
            return onset
        }
        // Fallback to calculating from midpoint
        guard let midpoint = rawMetrics?.sleepMidpointMinutes,
              let duration = totalSleepMinutes else { return nil }
        let startMinutes = midpoint - (duration / 2.0)
        return timelineDate(for: selectedDate, minutesFromStart: startMinutes)
    }

    private var sleepEndDate: Date? {
        // First try to use actual sleep offset time from Oura
        if let offsetString = rawMetrics?.sleepOffset,
           let offset = ISO8601DateFormatter().date(from: offsetString) {
            return offset
        }
        // Fallback to calculating from midpoint
        guard let midpoint = rawMetrics?.sleepMidpointMinutes,
              let duration = totalSleepMinutes else { return nil }
        let endMinutes = midpoint + (duration / 2.0)
        return timelineDate(for: selectedDate, minutesFromStart: endMinutes)
    }

    private var sleepStartTimeLabel: String {
        guard let start = sleepStartDate else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: start)
    }

    private var sleepEndTimeLabel: String {
        guard let end = sleepEndDate else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: end)
    }

    private var sleepQuarter1TimeLabel: String {
        guard let start = sleepStartDate, let end = sleepEndDate else { return "" }
        let duration = end.timeIntervalSince(start)
        let quarter1 = start.addingTimeInterval(duration / 3)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: quarter1)
    }

    private var sleepQuarter2TimeLabel: String {
        guard let start = sleepStartDate, let end = sleepEndDate else { return "" }
        let duration = end.timeIntervalSince(start)
        let quarter2 = start.addingTimeInterval(duration * 2 / 3)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: quarter2)
    }

    /// Parse hypnogram string from Oura: each char = 5 min, 1=deep, 2=light, 3=REM, 4=awake
    private var hypnogramEntries: [HypnogramEntry]? {
        print("[SleepView] hypnogramEntries - rawMetrics: \(rawMetrics != nil), hypnogram: \(rawMetrics?.hypnogram ?? "nil")")
        guard let hypnogram = rawMetrics?.hypnogram, !hypnogram.isEmpty else { return nil }

        var entries: [HypnogramEntry] = []
        for (index, char) in hypnogram.enumerated() {
            guard let stage = Int(String(char)), stage >= 1 && stage <= 4 else { continue }
            entries.append(HypnogramEntry(index: index, stage: stage))
        }
        return entries.isEmpty ? nil : entries
    }

    // MARK: - Helpers

    private func qualitativeLabel(for score: Double) -> (text: String, color: Color) {
        switch score {
        case 80...: return ("Optimal", sleepColor)
        case 60..<80: return ("Good", sleepColor)
        case 40..<60: return ("Fair", sleepColor)
        default: return ("Pay attention", sleepColor)
        }
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

    private func formatEfficiency(_ efficiency: Double?) -> String {
        guard let efficiency else { return "--" }
        let percent = efficiency <= 1.5 ? efficiency * 100 : efficiency
        return "\(Int(round(percent)))%"
    }

    private func formatRHR(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value)) bpm"
    }

    private func percent(of minutes: Double?, total: Double?) -> Double {
        guard let minutes, let total, total > 0 else { return 0 }
        return min(max(minutes / total, 0), 1)
    }

    private func progressForTotalSleep(_ minutes: Double) -> Double {
        guard minutes > 0 else { return 0 }
        let targetMinutes: Double
        if let need = sleepNeedHours {
            targetMinutes = need * 60
        } else {
            targetMinutes = 8 * 60
        }
        return min(max(minutes / targetMinutes, 0), 1)
    }

    private func timelineDate(for baseDate: Date, minutesFromStart: Double) -> Date? {
        guard minutesFromStart.isFinite else { return nil }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: baseDate)
        let dayOffset = Int(floor(minutesFromStart / 1440.0))
        let normalizedMinutes = minutesFromStart - Double(dayOffset) * 1440.0
        guard let dayAdjusted = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) else { return nil }
        return calendar.date(byAdding: .minute, value: Int(round(normalizedMinutes)), to: dayAdjusted)
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
                if hasSleepSignal {
                    loadAISummary()
                } else {
                    aiSummary = nil
                    isLoadingSummary = false
                }
            case .failure:
                snapshot = nil
                aiSummary = "Unable to load sleep data for this date."
                isLoadingSummary = false
            }
        }
    }

    private func loadAISummary() {
        isLoadingSummary = true

        NetworkManagerTwo.shared.fetchSleepSummary(
            userEmail: userEmail,
            targetDate: selectedDate
        ) { result in
            isLoadingSummary = false
            switch result {
            case .success(let response):
                aiSummary = response.summary
                print("[SleepView] AI summary from API: \(response.summary)")
            case .failure:
                if let score = currentSnapshot?.sleep {
                    if score >= 85 {
                        aiSummary = "You achieved optimal sleep duration with excellent efficiency. Your deep sleep and REM distribution supported strong recovery."
                    } else if score >= 70 {
                        aiSummary = "Good night overall. Efficiency was solid—focus on consistent bedtimes to keep improving recovery."
                    } else {
                        aiSummary = "Sleep quality was limited. Prioritize an earlier bedtime and a calming wind-down to improve efficiency tonight."
                    }
                } else {
                    aiSummary = "Unable to generate summary. Please ensure your wearable is synced."
                }
                print("[SleepView] AI summary fallback: \(aiSummary ?? "n/a")")
            }
        }
    }

    private func logSnapshotData(_ snapshot: NetworkManagerTwo.HealthMetricsSnapshot) {
        let sleepText = snapshot.sleep.map { String(format: "%.1f", $0) } ?? "n/a"
        print("[SleepView] Snapshot date \(snapshot.date) — sleep score: \(sleepText)")

        if let raw = snapshot.rawMetrics {
            let total = raw.totalSleepMinutes.map { formatDuration($0) } ?? "n/a"
            let inBed = raw.inBedMinutes.map { formatDuration($0) } ?? "n/a"
            let efficiency = raw.sleepEfficiency.map { String(format: "%.2f", $0) } ?? "n/a"
            let hypno = raw.hypnogram ?? "nil"
            print("[SleepView] Raw sleep — Total: \(total), In bed: \(inBed), Efficiency: \(efficiency), Hypnogram: \(hypno)")
        } else {
            print("[SleepView] Raw metrics unavailable")
        }
    }
}

// MARK: - Supporting Models

private struct SleepDriver: Identifiable {
    let id = UUID()
    let name: String
    let displayValue: String
    let progress: Double
    let color: Color
}

private struct SleepStageSegment: Identifiable {
    let id: UUID
    let percentage: Double
    let color: Color
}

private struct HypnogramEntry: Identifiable {
    let index: Int
    let stage: Int // 1=deep, 2=light, 3=REM, 4=awake

    var id: Int { index }
}

private struct StageRow: Identifiable {
    let id: UUID
    let label: String
    let durationText: String
    let percentText: String
    let color: Color
}

// MARK: - Supporting Views

private struct SleepDriverRow: View {
    let driver: SleepDriver

    var body: some View {
        Button {
            // Tappable placeholder for future detail
        } label: {
            VStack(spacing: 6) {
                HStack {
                    Text(driver.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(driver.displayValue)
                        .font(.body)
                        .foregroundColor(.primary)
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

private struct SleepVitalCard: View {
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

private struct SleepDatePickerSheet: View {
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
        restingHeartRate: 54,
        sleepHours: 7.5,
        sleepScore: 88,
        steps: nil,
        caloriesBurned: nil,
        respiratoryRate: 14,
        respiratoryRatePrevious: nil,
        skinTemperatureC: nil,
        skinTemperaturePrevious: nil,
        sleepLatencyMinutes: 8,
        sleepMidpointMinutes: 240,
        sleepNeedHours: 8.2,
        strainRatio: nil,
        totalSleepMinutes: 433,
        sleepStageMinutes: .init(deep: 110, rem: 85, core: 180, awake: 13),
        inBedMinutes: 504,
        sleepEfficiency: 0.94,
        sleepSource: "oura",
        fallbackSleepDate: nil,
        hypnogram: "42222111112342221111112223332221111122422322233334222222212122333224444",
        cumulativeSleepDebtMinutes: 420,  // 7 hours cumulative debt
        sleepOnset: "2025-12-09T23:15:00+00:00",
        sleepOffset: "2025-12-10T07:09:00+00:00"
    )

    let mockSnapshot = NetworkManagerTwo.HealthMetricsSnapshot(
        date: "2025-12-10",
        readiness: 86,
        sleep: 88,
        activity: 65,
        stress: 42,
        confidence: "high",
        isEmpty: false,
        scoreSource: "oura",
        sourceScores: nil,
        sleepSourceDate: nil,
        components: .init(readiness: nil, sleep: ["continuity": 82, "timing": 90], activity: nil, stress: nil),
        rawMetrics: mockRaw
    )

    NavigationStack {
        SleepView(
            initialSnapshot: mockSnapshot,
            initialDate: Date(),
            userEmail: "test@example.com"
        )
    }
    .environmentObject(HealthKitViewModel())
}
