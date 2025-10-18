//
//  ExerciseHistory.swift
//  pods
//
//  Created by Dimi Nunez on 8/18/25.
//

import SwiftUI
import UIKit
import SwiftData

struct ExerciseHistory: View {
    let exercise: TodayWorkoutExercise
    @State private var selectedTab: HistoryTab = .trends
    @Environment(\.dismiss) private var dismiss
    
    enum HistoryTab: String, CaseIterable {
        case trends = "Trends"
        case results = "Results"
        case records = "Records"
    }
    
    private var isDurationBasedExercise: Bool {
        guard let tracking = exercise.trackingType else { return false }
        switch tracking {
        case .timeOnly, .holdTime, .timeDistance, .rounds:
            return true
        default:
            return false
        }
    }
    
    private var availableTabs: [HistoryTab] {
        isDurationBasedExercise ? [.trends, .results] : HistoryTab.allCases
    }
    
    var body: some View {
        let tabs = availableTabs
        
        VStack(spacing: 0) {
            // Native iOS Segmented Picker
            Picker("", selection: $selectedTab) {
                ForEach(tabs, id: \.self) { tab in
                    Text(tab.rawValue)
                        .tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .onAppear { ensureValidSelection() }
            .onChange(of: exercise.trackingType) { _ in ensureValidSelection() }
            
            // Content
            switch selectedTab {
            case .trends:
                ExerciseTrendsView(exercise: exercise)
            case .results:
                ExerciseResultsView(exercise: exercise)
            case .records:
                if tabs.contains(.records) {
                    ExerciseRecordsView(exercise: exercise)
                } else {
                    EmptyView()
                }
            }
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
    
    private func ensureValidSelection() {
        let tabs = availableTabs
        if !tabs.contains(selectedTab) {
            selectedTab = tabs.first ?? .trends
        }
    }
}

// MARK: - Trends View

struct ExerciseTrendsView: View {
    let exercise: TodayWorkoutExercise
    
    @StateObject private var dataService = ExerciseHistoryDataService.shared
    @State private var metrics: ExerciseMetrics?
    @State private var repsData: [(Date, Double)] = []
    @State private var weightData: [(Date, Double)] = []
    @State private var volumeData: [(Date, Double)] = []
    @State private var oneRepMaxData: [(Date, Double)] = []
    @State private var durationData: [(Date, Double)] = []
    @State private var totalDurationData: [(Date, Double)] = []
    @State private var distanceData: [(Date, Double)] = []
    @State private var isLoading = true
    @State private var selectedPeriod: TimePeriod = .month
    @EnvironmentObject var onboarding: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    ProgressView("Loading exercise data...")
                        .padding()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVStack(spacing: 24) {
                    if hasDurationMetricsAvailable {
                        HistoryMetricCard(
                            title: "Time (Best Set)",
                            currentValue: formatDurationValue(metrics?.maxDurationSeconds),
                            loggedAgo: getLastLoggedTime(),
                            data: durationData,
                            chartType: .line,
                            color: .orange,
                            metric: .duration,
                            unitLabel: nil,
                            axisFormatter: durationAxisFormatter,
                            exercise: exercise
                        )
                        
                        HistoryMetricCard(
                            title: "Total Time",
                            currentValue: formatDurationValue(metrics?.totalDurationSeconds),
                            loggedAgo: getLastLoggedTime(),
                            data: totalDurationData,
                            chartType: .bar,
                            color: .red,
                            metric: .totalDuration,
                            unitLabel: nil,
                            axisFormatter: durationAxisFormatter,
                            exercise: exercise
                        )
                        
                        if hasDistanceMetricsAvailable {
                            HistoryMetricCard(
                                title: "Distance",
                                currentValue: formatDistanceValue(metrics?.totalDistanceMeters),
                                loggedAgo: getLastLoggedTime(),
                                data: distanceData,
                                chartType: .line,
                                color: .blue,
                                metric: .distance,
                                unitLabel: distanceUnitSymbol,
                                axisFormatter: distanceAxisFormatter,
                                exercise: exercise
                            )
                        }
                    } else {
                        HistoryMetricCard(
                            title: "Reps",
                            currentValue: formatRepsValue(metrics?.maxReps),
                            loggedAgo: getLastLoggedTime(),
                            data: repsData,
                            chartType: .line,
                            color: .red,
                            metric: .reps,
                            unitLabel: nil,
                            axisFormatter: numberAxisFormatter,
                            exercise: exercise
                        )
                   
                        HistoryMetricCard(
                            title: "Volume",
                            currentValue: formatVolumeValue(metrics?.totalVolume),
                            loggedAgo: getLastLoggedTime(),
                            data: volumeData,
                            chartType: .bar,
                            color: .red,
                            metric: .volume,
                            unitLabel: onboarding.unitsSystem == .imperial ? "lbs" : "kg",
                            axisFormatter: weightAxisFormatter,
                            exercise: exercise
                        )
                        
                        HistoryMetricCard(
                            title: "Weight",
                            currentValue: formatWeightValue(metrics?.maxWeight),
                            loggedAgo: getLastLoggedTime(),
                            data: weightData,
                            chartType: .line,
                            color: .blue,
                            metric: .weight,
                            unitLabel: weightUnitSymbol,
                            axisFormatter: weightAxisFormatter,
                            exercise: exercise
                        )
                        
                        HistoryMetricCard(
                            title: "Est. 1 Rep Max",
                            currentValue: formatWeightValue(metrics?.estimatedOneRepMax),
                            loggedAgo: getLastLoggedTime(),
                            data: oneRepMaxData,
                            chartType: .line,
                            color: .orange,
                            metric: .estOneRepMax,
                            unitLabel: weightUnitSymbol,
                            axisFormatter: weightAxisFormatter,
                            exercise: exercise
                        )
                    }
                }
                .padding(.top, 20)
            }
        }
        .task {
            await loadExerciseData()
        }
        .refreshable {
            await dataService.invalidateCache(for: exercise.exercise.id)
            await loadExerciseData()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadExerciseData() async {
        print("🔄 ExerciseTrendsView: Starting to load data for exercise \(exercise.exercise.id)")
        isLoading = true
        defer { isLoading = false }
        
        durationData = []
        totalDurationData = []
        distanceData = []
        
        do {
            let fetchedMetrics = try await dataService.getExerciseMetrics(
                exerciseId: exercise.exercise.id,
                period: selectedPeriod,
                context: modelContext
            )
            metrics = fetchedMetrics
            
            let hasDuration = (fetchedMetrics.maxDurationSeconds > 0) || (fetchedMetrics.totalDurationSeconds > 0)
            let hasDistance = fetchedMetrics.totalDistanceMeters > 0
            
            if hasDuration {
                let durationSeries = try await dataService.getChartData(
                    exerciseId: exercise.exercise.id,
                    metric: .duration,
                    period: selectedPeriod,
                    context: modelContext
                )
                durationData = trimToRecent(durationSeries)
                let totalDurationSeries = try await dataService.getChartData(
                    exerciseId: exercise.exercise.id,
                    metric: .totalDuration,
                    period: selectedPeriod,
                    context: modelContext
                )
                totalDurationData = trimToRecent(totalDurationSeries)
                if hasDistance {
                    let rawDistance = try await dataService.getChartData(
                        exerciseId: exercise.exercise.id,
                        metric: .distance,
                        period: selectedPeriod,
                        context: modelContext
                    )
                    distanceData = trimToRecent(rawDistance).map { ($0.0, convertDistanceToDisplay($0.1)) }
                } else {
                    distanceData = []
                }
                
                // Clear weight-based datasets for duration-focused exercises
                repsData = []
                weightData = []
                volumeData = []
                oneRepMaxData = []
            } else {
                async let repsTask = dataService.getChartData(exerciseId: exercise.exercise.id, metric: .reps, period: selectedPeriod, context: modelContext)
                async let weightTask = dataService.getChartData(exerciseId: exercise.exercise.id, metric: .weight, period: selectedPeriod, context: modelContext)
                async let volumeTask = dataService.getChartData(exerciseId: exercise.exercise.id, metric: .volume, period: selectedPeriod, context: modelContext)
                async let oneRepMaxTask = dataService.getChartData(exerciseId: exercise.exercise.id, metric: .estOneRepMax, period: selectedPeriod, context: modelContext)
                
                let repsSeries = try await repsTask
                let weightSeries = try await weightTask
                let volumeSeries = try await volumeTask
                let oneRmSeries = try await oneRepMaxTask
                
                repsData = trimToRecent(repsSeries)
                weightData = trimToRecent(weightSeries)
                volumeData = trimToRecent(volumeSeries)
                oneRepMaxData = trimToRecent(oneRmSeries)
            }
            
            print("✅ ExerciseTrendsView: Data loaded successfully")
            print("   - Metrics: maxReps=\(metrics?.maxReps ?? 0), maxWeight=\(metrics?.maxWeight ?? 0), maxDuration=\(metrics?.maxDurationSeconds ?? 0)")
            
        } catch {
            print("❌ ExerciseTrendsView: Error loading data - \(error)")
            metrics = nil
            repsData = []
            weightData = []
            volumeData = []
            oneRepMaxData = []
            durationData = []
            totalDurationData = []
            distanceData = []
        }
    }
    
    private var hasDurationMetricsAvailable: Bool {
        guard let metrics else { return false }
        return metrics.maxDurationSeconds > 0 || metrics.totalDurationSeconds > 0
    }
    
    private var hasDistanceMetricsAvailable: Bool {
        guard let metrics else { return false }
        return metrics.totalDistanceMeters > 0
    }
    
    private var weightUnitSymbol: String {
        onboarding.unitsSystem == .imperial ? "lbs" : "kg"
    }
    
    private var distanceUnitSymbol: String {
        onboarding.unitsSystem == .imperial ? "mi" : "km"
    }
    
    private func weightDisplayValue(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        if onboarding.unitsSystem == .imperial {
            return value
        } else {
            return value / 2.20462
        }
    }
    
    private func formatWeightValue(_ value: Double?) -> String {
        guard let display = weightDisplayValue(value) else { return "--" }
        return String(format: "%.1f %@", display, weightUnitSymbol)
    }
    
    private func formatVolumeValue(_ value: Double?) -> String {
        guard let display = weightDisplayValue(value) else { return "--" }
        return String(format: "%.0f %@", display, weightUnitSymbol)
    }
    
    private func formatRepsValue(_ value: Int?) -> String {
        guard let value, value > 0 else { return "--" }
        return "\(value)"
    }
    
    private func formatDurationValue(_ value: Double?) -> String {
        guard let value, value > 0 else { return "--" }
        let totalSeconds = Int(value.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func convertDistanceToDisplay(_ meters: Double) -> Double {
        if onboarding.unitsSystem == .imperial {
            return meters * 0.000621371
        } else {
            return meters / 1000.0
        }
    }
    
    private func formatDistanceValue(_ meters: Double?) -> String {
        guard let meters, meters > 0 else { return "--" }
        let display = convertDistanceToDisplay(meters)
        if display >= 10 {
            return String(format: "%.1f %@", display, distanceUnitSymbol)
        } else {
            return String(format: "%.2f %@", display, distanceUnitSymbol)
        }
    }
    
    private func numberAxisFormatter(_ value: Double) -> String {
        let display = value
        if display >= 1000 {
            return String(format: "%.1fk", display / 1000)
        } else if display.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", display)
        } else {
            return String(format: "%.1f", display)
        }
    }
    
    private func weightAxisFormatter(_ value: Double) -> String {
        guard let converted = weightDisplayValue(value) else { return "0" }
        return numberAxisFormatter(converted)
    }
    
    private func durationAxisFormatter(_ value: Double) -> String {
        let totalSeconds = max(0, Int(value.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func distanceAxisFormatter(_ value: Double) -> String {
        if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    private func trimToRecent(_ data: [(Date, Double)]) -> [(Date, Double)] {
        let trimmed = Array(data.suffix(5))
        return trimmed
    }
    
    private func getLastLoggedTime() -> String {
        // Get the most recent workout date
        let allData = [repsData, weightData, volumeData, oneRepMaxData, durationData, totalDurationData, distanceData].flatMap { $0 }
        guard let latestDate = allData.map({ $0.0 }).max() else {
            return "No recent data"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Logged \(formatter.localizedString(for: latestDate, relativeTo: Date()))"
    }
}

// MARK: - Results View

struct ExerciseResultsView: View {
    let exercise: TodayWorkoutExercise
    
    @StateObject private var dataService = ExerciseHistoryDataService.shared
    @State private var workoutSessions: [WorkoutSessionSummary] = []
    @State private var isLoading = true
    @State private var selectedPeriod: TimePeriod = .month
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    ProgressView("Loading workout history...")
                        .padding()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if workoutSessions.isEmpty {
                VStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No workout history found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Start logging workouts to see your progress here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                LazyVStack(spacing: 24) {
                    ForEach(Array(workoutSessions.enumerated()), id: \.offset) { index, session in
                        ExerciseHistoryCard(
                            workout: convertToHistoryItem(session, previousSession: index > 0 ? workoutSessions[index - 1] : nil),
                            isToday: Calendar.current.isDateInToday(session.date)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .task {
            await loadWorkoutHistory()
        }
        .refreshable {
            await dataService.invalidateCache(for: exercise.exercise.id)
            await loadWorkoutHistory()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadWorkoutHistory() async {
        isLoading = true
        
        do {
            let historyData = try await dataService.getExerciseHistory(
                exerciseId: exercise.exercise.id,
                period: selectedPeriod,
                context: modelContext
            )
            workoutSessions = historyData.workoutSessions.sorted { $0.date > $1.date } // Most recent first
        } catch {
            print("❌ ExerciseResultsView: Error loading history - \(error)")
            workoutSessions = []
        }
        
        isLoading = false
    }
    
    private func convertToHistoryItem(_ session: WorkoutSessionSummary, previousSession: WorkoutSessionSummary?) -> ExerciseHistoryItem {
        let sets = session.sets.map { set in
            HistoryWorkoutSet(
                reps: set.reps,
                weight: set.weight,
                durationSeconds: set.durationSeconds,
                distanceMeters: set.distanceMeters,
                trackingType: set.trackingType ?? session.trackingType
            )
        }
        
        // Calculate trend compared to previous session
        let trend: String?
        if let previousSession = previousSession {
            if isDurationBased(session.trackingType) {
                let currentDuration = session.maxDurationSeconds
                let previousDuration = previousSession.maxDurationSeconds
                let diff = currentDuration - previousDuration
                if diff > 1 {
                    trend = "+\(formattedDurationDifference(diff)) longer"
                } else if diff < -1 {
                    trend = "-\(formattedDurationDifference(abs(diff))) shorter"
                } else {
                    trend = nil
                }
            } else {
                let currentMaxReps = session.maxReps
                let previousMaxReps = previousSession.maxReps
                
                if currentMaxReps > previousMaxReps {
                    let diff = currentMaxReps - previousMaxReps
                    trend = "+\(diff) more rep\(diff == 1 ? "" : "s")"
                } else if currentMaxReps < previousMaxReps {
                    let diff = previousMaxReps - currentMaxReps
                    trend = "-\(diff) rep\(diff == 1 ? "" : "s")"
                } else {
                    trend = nil
                }
            }
        } else {
            trend = nil
        }
        
        return ExerciseHistoryItem(
            date: session.date,
            sets: sets,
            estimatedOneRepMax: session.estimatedOneRepMax,
            trend: trend,
            trackingType: session.trackingType
        )
    }
    
    private func isDurationBased(_ trackingType: ExerciseTrackingType?) -> Bool {
        guard let trackingType else { return false }
        switch trackingType {
        case .timeOnly, .holdTime, .timeDistance, .rounds:
            return true
        default:
            return false
        }
    }
    
    private func formattedDurationDifference(_ diff: Double) -> String {
        let totalSeconds = Int(abs(diff).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Models

struct ExerciseHistoryItem {
    let date: Date
    let sets: [HistoryWorkoutSet]
    let estimatedOneRepMax: Double
    let trend: String?
    let trackingType: ExerciseTrackingType?
}

struct HistoryWorkoutSet {
    let reps: Int?
    let weight: Double?
    let durationSeconds: Int?
    let distanceMeters: Double?
    let trackingType: ExerciseTrackingType?
}

// MARK: - Metric Card Component

struct HistoryMetricCard: View {
    let title: String
    let currentValue: String
    let loggedAgo: String
    let data: [(Date, Double)]
    let chartType: ChartType
    let color: Color
    let metric: ChartMetric
    let unitLabel: String?
    let axisFormatter: (Double) -> String
    let exercise: TodayWorkoutExercise
    @EnvironmentObject var onboarding: OnboardingViewModel
    @EnvironmentObject var proFeatureGate: ProFeatureGate
    @State private var navigateToChart = false
    
    enum ChartType {
        case line, bar
    }
    
    var body: some View {
        ZStack {
            NavigationLink(destination: ExerciseChart(exercise: exercise, metric: metric), isActive: $navigateToChart) {
                EmptyView()
            }
            .hidden()
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding()
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(currentValue)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            supplementaryLabel
                        }
                        Text(loggedAgo)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    chartContent
                }
                Text("Most Recent Performances")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .onTapGesture { attemptNavigation() }
    }
  
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var supplementaryLabel: some View {
        switch metric {
        case .reps:
            Text("reps in 1 set")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        case .volume:
            if let unitLabel {
                Text("\(unitLabel) total")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                EmptyView()
            }
        case .weight:
            let label = unitLabel.map { "\($0) in 1 set" } ?? ""
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        case .estOneRepMax:
            let label = unitLabel.map { "\($0) in 1 rep" } ?? ""
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        case .duration:
            Text("per set")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        case .totalDuration:
            Text("total time")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        case .distance:
            if let unitLabel {
                Text("\(unitLabel) total")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                EmptyView()
            }
        }
    }
    
    private var chartContent: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                GeometryReader { geometry in
                    Path { path in
                        let positions = [0.0, 0.5, 1.0]
                        for position in positions {
                            let y = geometry.size.height * CGFloat(position)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                }
                if data.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("Not enough data")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } else {
                    if chartType == .line {
                        HistoryLineChart(data: data, color: color)
                            .frame(height: 100)
                    } else {
                        HistoryBarChart(data: data, color: color)
                            .frame(height: 100)
                    }
                }
            }
            .padding(.leading, 16)
            VStack(alignment: .leading, spacing: 0) {
                let maxValue = data.map { $0.1 }.max() ?? 1
                let minValue = data.map { $0.1 }.min() ?? 0
                Text(axisFormatter(maxValue))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Text(axisFormatter((maxValue + minValue) / 2))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Text(axisFormatter(minValue))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 30, height: 100)
            .padding(.trailing, 8)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private func attemptNavigation() {
        if let email = UserDefaults.standard.string(forKey: "userEmail"), !email.isEmpty {
            proFeatureGate.requirePro(for: .analytics, userEmail: email) {
                navigateToChart = true
            }
        } else {
            navigateToChart = true
        }
    }
}

// MARK: - History Card Component

struct ExerciseHistoryCard: View {
    let workout: ExerciseHistoryItem
    let isToday: Bool
    @EnvironmentObject var onboarding: OnboardingViewModel
    @State private var showingRIRSheet = false
    @State private var rirValue: Double = 0 // Store RIR rating
    @State private var hasRatedRIR = false // Track if RIR has been set
    
    private var dateString: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(workout.date) {
            return "Today"
        } else if calendar.isDateInYesterday(workout.date) {
            return "Yesterday"
        } else if let daysDiff = calendar.dateComponents([.day], from: workout.date, to: now).day,
                  daysDiff < 7 {
            // Within last week, show day name
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: workout.date)
        } else {
            // Show full date
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: workout.date)
        }
    }
    
    private var weightUnitSymbol: String {
        onboarding.unitsSystem == .imperial ? "lb" : "kg"
    }
    
    private var distanceUnitSymbol: String {
        onboarding.unitsSystem == .imperial ? "mi" : "km"
    }
    
    private func weightDisplayValue(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        if onboarding.unitsSystem == .imperial {
            return value
        } else {
            return value / 2.20462
        }
    }
    
    private func formatWeightValue(_ value: Double?) -> String? {
        guard let display = weightDisplayValue(value) else { return nil }
        return String(format: "%.1f %@", display, weightUnitSymbol)
    }
    
    private func formatWeightValue(_ value: Double) -> String {
        formatWeightValue(Optional(value)) ?? "--"
    }
    
    private func formatDuration(_ seconds: Int?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
    
    private func formatDistance(_ meters: Double?) -> String? {
        guard let meters, meters > 0 else { return nil }
        let display: Double
        if onboarding.unitsSystem == .imperial {
            display = meters * 0.000621371
        } else {
            display = meters / 1000.0
        }
        if display >= 10 {
            return String(format: "%.1f %@", display, distanceUnitSymbol)
        } else {
            return String(format: "%.2f %@", display, distanceUnitSymbol)
        }
    }
    
    private func setSummaryText(for set: HistoryWorkoutSet) -> String {
        if isDurationBased(set.trackingType) {
            let durationString = formatDuration(set.durationSeconds) ?? "0:00"
            switch set.trackingType {
            case .timeDistance:
                if let distanceString = formatDistance(set.distanceMeters) {
                    return "\(durationString) @ \(distanceString)"
                } else {
                    return durationString
                }
            case .rounds:
                let rounds = set.reps ?? 0
                if rounds > 0, let duration = formatDuration(set.durationSeconds) {
                    return "\(rounds) round\(rounds == 1 ? "" : "s") in \(duration)"
                } else if rounds > 0 {
                    return "\(rounds) round\(rounds == 1 ? "" : "s")"
                } else {
                    return durationString
                }
            default:
                return durationString
            }
        } else {
            let repsPart = set.reps.map { "\($0) reps" }
            let weightPart = formatWeightValue(set.weight)
            
            switch (repsPart, weightPart) {
            case let (reps?, weight?):
                return "\(reps) × \(weight)"
            case let (reps?, nil):
                return reps
            case let (nil, weight?):
                return weight
            default:
                return "Logged set"
            }
        }
    }
    
    private func isDurationBased(_ trackingType: ExerciseTrackingType?) -> Bool {
        guard let trackingType else { return false }
        switch trackingType {
        case .timeOnly, .holdTime, .timeDistance, .rounds:
            return true
        default:
            return false
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text(dateString)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Rate Exertion button for all results
                if hasRatedRIR {
                    Text("\(Int(rirValue)) more rep\(Int(rirValue) == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.accentColor)
                        )
                        .onTapGesture {
                            showingRIRSheet = true
                        }
                } else {
                    Button(action: {
                        showingRIRSheet = true
                    }) {
                        Text("Rate Exertion")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(.systemGray3), lineWidth: 1)
                            )
                    }
                }
            }
            
            
            // Working Sets
            VStack(alignment: .leading, spacing: 12) {
                Text("Working sets")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                ForEach(Array(workout.sets.enumerated()), id: \.offset) { index, set in
                    HStack(spacing: 12) {
                        // Set number badge with hexagon shape
                        ZStack {
                            // Image(systemName: "hexagon.fill")
                            //     .font(.system(size: 28))
                            //     .foregroundColor(Color(.systemGray5))
                            
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 32, height: 32)
                        
                        Text(setSummaryText(for: set))
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
            }
            
            // Est. 1 Rep Max
            if workout.estimatedOneRepMax > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Est. 1 Rep Max")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        Text(formatWeightValue(workout.estimatedOneRepMax))
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
            
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingRIRSheet) {
            RIRRatingSheet(
                rirValue: $rirValue,
                hasRatedRIR: $hasRatedRIR,
                isPresented: $showingRIRSheet
            )
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Chart Components

struct HistoryLineChart: View {
    let data: [(Date, Double)]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.map { $0.1 }.max() ?? 1
            let minValue = data.map { $0.1 }.min() ?? 0
            let range = maxValue - minValue > 0 ? maxValue - minValue : 1
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Background gradient
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
                                y: height - ((point.1 - minValue) / range) * height
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
                            y: height - ((point.1 - minValue) / range) * height
                        )
                    }
                    
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                
                // Data points
                ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle()
                                .stroke(color, lineWidth: 2)
                        )
                        .position(
                            x: CGFloat(index) * (width / CGFloat(max(data.count - 1, 1))),
                            y: height - ((point.1 - minValue) / range) * height
                        )
                }
            }
        }
    }
}

struct HistoryBarChart: View {
    let data: [(Date, Double)]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.map { $0.1 }.max() ?? 1
            let barWidth = geometry.size.width / CGFloat(data.count * 2)
            let spacing = barWidth
            
            HStack(alignment: .bottom, spacing: spacing) {
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
                            width: barWidth,
                            height: max((point.1 / maxValue) * geometry.size.height, 5)
                        )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Records View

struct ExerciseRecordsView: View {
    let exercise: TodayWorkoutExercise
    
    @StateObject private var dataService = ExerciseHistoryDataService.shared
    @State private var personalRecords: PersonalRecords?
    @State private var isLoading = true
    @EnvironmentObject var onboarding: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        if isDurationBasedExercise {
            VStack(spacing: 16) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Personal records are coming soon for time-based exercises.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
        ScrollView {
            if isLoading {
                VStack {
                    ProgressView("Loading personal records...")
                        .padding()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let records = personalRecords {
                LazyVStack(spacing: 16) {
                    let unit = onboarding.unitsSystem == .imperial ? "lb" : "kg"
                    let weight = onboarding.unitsSystem == .imperial ? records.maxWeight.value : (records.maxWeight.value / 2.20462)
                    let volume = onboarding.unitsSystem == .imperial ? records.maxVolume.value : (records.maxVolume.value / 2.20462)
                    let oneRm = onboarding.unitsSystem == .imperial ? records.maxEstimatedOneRepMax.value : (records.maxEstimatedOneRepMax.value / 2.20462)

                    RecordRow(record: RecordItem(
                        label: "Weight",
                        value: String(format: "%.1f %@", weight, unit),
                        date: records.maxWeight.date
                    ))
                    
                    RecordRow(record: RecordItem(
                        label: "Volume",
                        value: String(format: "%.0f %@", volume, unit),
                        date: records.maxVolume.date
                    ))
                    
                    RecordRow(record: RecordItem(
                        label: "Est. 1 Rep Max",
                        value: String(format: "%.1f %@", oneRm, unit),
                        date: records.maxEstimatedOneRepMax.date
                    ))
                    
                    RecordRow(record: RecordItem(
                        label: "Reps",
                        value: "\(records.maxReps.value) reps",
                        date: records.maxReps.date
                    ))
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            } else {
                VStack {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.primary)
                    Text("No records found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Complete more workouts to set personal records")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .task {
            await loadPersonalRecords()
        }
        .refreshable {
            await loadPersonalRecords()
        }
        }
    }
    
    // MARK: - Private Methods
    
    private var isDurationBasedExercise: Bool {
        guard let tracking = exercise.trackingType else { return false }
        switch tracking {
        case .timeOnly, .holdTime, .timeDistance, .rounds:
            return true
        default:
            return false
        }
    }
    
    private func loadPersonalRecords() async {
        isLoading = true
        
        do {
            personalRecords = try await dataService.getPersonalRecords(exerciseId: exercise.exercise.id, context: modelContext)
        } catch {
            print("❌ ExerciseRecordsView: Error loading records - \(error)")
            personalRecords = nil
        }
        
        isLoading = false
    }
}

struct RecordItem {
    let label: String
    let value: String
    let date: Date
}

struct RecordRow: View {
    let record: RecordItem
    
    private var dateString: String {
        let minimumValidTimestamp: TimeInterval = 60
        guard record.date.timeIntervalSince1970 >= minimumValidTimestamp else {
            return "—"
        }

        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(record.date) {
            return "Today"
        } else if calendar.isDateInYesterday(record.date) {
            return "Yesterday"
        } else if let daysDiff = calendar.dateComponents([.day], from: record.date, to: now).day,
                  daysDiff < 7 {
            // Within last week, show day name
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: record.date)
        } else {
            // Show full date
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: record.date)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Highlight the record with a medal icon to match empty state styling
            Image(systemName: "medal.fill")
                .font(.system(size: 24))
                .foregroundColor(.primary)
                .frame(width: 32)
            
            // Label and value
            VStack(alignment: .leading, spacing: 4) {
                Text(record.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(record.value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Date
            Text(dateString)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - RIR Rating Sheet

struct RIRRatingSheet: View {
    @Binding var rirValue: Double
    @Binding var hasRatedRIR: Bool
    @Binding var isPresented: Bool
    @State private var tempRirValue: Double = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Rate Your Workout")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("How many more reps could you do?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // RIR Slider
                RIRSlider(value: $tempRirValue)
                    .frame(height: 80)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Rate Exertion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Reset to no value
                        hasRatedRIR = false
                        rirValue = 0
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Save the value
                        rirValue = tempRirValue
                        hasRatedRIR = true
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Initialize temp value with current value
            tempRirValue = rirValue
        }
    }
}

// Note: RIRSlider and RIRTriangleBar components are imported from ExerciseLoggingView.swift

#Preview {
    NavigationView {
        ExerciseHistory(
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
            )
        )
    }
}
