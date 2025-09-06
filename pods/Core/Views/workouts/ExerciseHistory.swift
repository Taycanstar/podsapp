//
//  ExerciseHistory.swift
//  pods
//
//  Created by Dimi Nunez on 8/18/25.
//

import SwiftUI
import UIKit

struct ExerciseHistory: View {
    let exercise: TodayWorkoutExercise
    @State private var selectedTab: HistoryTab = .trends
    @Environment(\.dismiss) private var dismiss
    
    enum HistoryTab: String, CaseIterable {
        case trends = "Trends"
        case results = "Results"
        case records = "Records"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Native iOS Segmented Picker
            Picker("", selection: $selectedTab) {
                ForEach(HistoryTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue)
                        .tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom)
            
            // Content
            switch selectedTab {
            case .trends:
                ExerciseTrendsView(exercise: exercise)
            case .results:
                ExerciseResultsView(exercise: exercise)
            case .records:
                ExerciseRecordsView(exercise: exercise)
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
    @State private var isLoading = true
    @State private var selectedPeriod: TimePeriod = .month
    @EnvironmentObject var onboarding: OnboardingViewModel
    
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
                    HistoryMetricCard(
                        title: "Reps",
                        currentValue: formatCurrentValue(Double(metrics?.maxReps ?? 0), unit: ""),
                        loggedAgo: getLastLoggedTime(),
                        data: repsData,
                        chartType: .line,
                        color: .red,
                        exercise: exercise
                    )
                    
                    HistoryMetricCard(
                        title: "Volume",
                        currentValue: formatCurrentValue(metrics?.totalVolume, unit: onboarding.unitsSystem == .imperial ? " lb" : " kg"),
                        loggedAgo: getLastLoggedTime(),
                        data: volumeData,
                        chartType: .bar,
                        color: .red,
                        exercise: exercise
                    )
                    
                    HistoryMetricCard(
                        title: "Weight",
                        currentValue: formatCurrentValue(metrics?.maxWeight, unit: onboarding.unitsSystem == .imperial ? " lb" : " kg"),
                        loggedAgo: getLastLoggedTime(),
                        data: weightData,
                        chartType: .line,
                        color: .blue,
                        exercise: exercise
                    )
                    
                    HistoryMetricCard(
                        title: "Est. 1 Rep Max",
                        currentValue: formatCurrentValue(metrics?.estimatedOneRepMax, unit: onboarding.unitsSystem == .imperial ? " lb" : " kg"),
                        loggedAgo: getLastLoggedTime(),
                        data: oneRepMaxData,
                        chartType: .line,
                        color: .orange,
                        exercise: exercise
                    )
                }
                .padding(.top, 20)
            }
        }
        .task {
            await loadExerciseData()
        }
        .refreshable {
            await loadExerciseData()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadExerciseData() async {
        print("🔄 ExerciseTrendsView: Starting to load data for exercise \(exercise.exercise.id)")
        isLoading = true
        
        do {
            // Load metrics and chart data concurrently
            async let metricsTask = dataService.getExerciseMetrics(exerciseId: exercise.exercise.id, period: selectedPeriod)
            async let repsTask = dataService.getChartData(exerciseId: exercise.exercise.id, metric: .reps, period: selectedPeriod)
            async let weightTask = dataService.getChartData(exerciseId: exercise.exercise.id, metric: .weight, period: selectedPeriod)
            async let volumeTask = dataService.getChartData(exerciseId: exercise.exercise.id, metric: .volume, period: selectedPeriod)
            async let oneRepMaxTask = dataService.getChartData(exerciseId: exercise.exercise.id, metric: .estOneRepMax, period: selectedPeriod)
            
            metrics = try await metricsTask
            repsData = try await repsTask
            weightData = try await weightTask
            volumeData = try await volumeTask
            oneRepMaxData = try await oneRepMaxTask
            
            print("✅ ExerciseTrendsView: Data loaded successfully")
            print("   - Metrics: maxReps=\(metrics?.maxReps ?? 0), maxWeight=\(metrics?.maxWeight ?? 0)")
            print("   - Chart data points: reps=\(repsData.count), weight=\(weightData.count)")
            
        } catch {
            print("❌ ExerciseTrendsView: Error loading data - \(error)")
            // Fallback to empty data
            metrics = nil
            repsData = []
            weightData = []
            volumeData = []
            oneRepMaxData = []
        }
        
        isLoading = false
    }
    
    private func formatCurrentValue(_ value: Double?, unit: String) -> String {
        guard let raw = value, raw > 0 else { return "--" }
        let isKg = unit.contains("kg")
        let display = isKg ? (raw / 2.20462) : raw
        if unit.contains("lb") {
            return String(format: "%.1f", display)
        } else if unit.contains("kg") {
            return String(format: "%.1f", display)
        } else {
            return String(format: "%.0f", display)
        }
    }
    
    private func getLastLoggedTime() -> String {
        // Get the most recent workout date
        let allData = [repsData, weightData, volumeData, oneRepMaxData].flatMap { $0 }
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
            await loadWorkoutHistory()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadWorkoutHistory() async {
        isLoading = true
        
        do {
            let historyData = try await dataService.getExerciseHistory(
                exerciseId: exercise.exercise.id,
                period: selectedPeriod
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
            HistoryWorkoutSet(reps: set.reps, weight: set.weight ?? 0.0)
        }
        
        // Calculate trend compared to previous session
        let trend: String?
        if let previousSession = previousSession {
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
        } else {
            trend = nil
        }
        
        return ExerciseHistoryItem(
            date: session.date,
            sets: sets,
            estimatedOneRepMax: session.estimatedOneRepMax,
            trend: trend
        )
    }
}

// MARK: - Supporting Models

struct ExerciseHistoryItem {
    let date: Date
    let sets: [HistoryWorkoutSet]
    let estimatedOneRepMax: Double
    let trend: String?
}

struct HistoryWorkoutSet {
    let reps: Int
    let weight: Double
}

// MARK: - Metric Card Component

struct HistoryMetricCard: View {
    let title: String
    let currentValue: String
    let loggedAgo: String
    let data: [(Date, Double)]
    let chartType: ChartType
    let color: Color
    let exercise: TodayWorkoutExercise
    @EnvironmentObject var onboarding: OnboardingViewModel
    
    enum ChartType {
        case line, bar
    }
    
    private var chartMetric: ChartMetric {
        switch title {
        case "Reps": return .reps
        case "Weight": return .weight
        case "Volume": return .volume
        case "Est. 1 Rep Max": return .estOneRepMax
        default: return .weight
        }
    }
    
    var body: some View {
        NavigationLink(destination: ExerciseChart(exercise: exercise, metric: chartMetric)) {
            VStack(alignment: .leading, spacing: 20) {
                // Header with title and chevron
                HStack {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            
            // Chart Card with integrated labels
            VStack(alignment: .leading, spacing: 0) {
                // Top section with value and description

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(currentValue)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        if title == "Reps" {
                            Text("reps in 1 set")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        } else if title == "Volume" {
                            Text(onboarding.unitsSystem == .imperial ? "lbs" : "kg")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        } else if title == "Weight" {
                            let unit = onboarding.unitsSystem == .imperial ? "lbs" : "kg"
                            Text("\(unit) in 1 set")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        } else if title == "Est. 1 Rep Max" {
                            let unit = onboarding.unitsSystem == .imperial ? "lbs" : "kg"
                            Text("\(unit) in 1 rep")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(loggedAgo)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Chart with Y-axis labels
                HStack(alignment: .top, spacing: 8) {
                    // Chart
                    ZStack {
                        // Horizontal gridlines
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
                        
                        // Chart content
                        if chartType == .line {
                            HistoryLineChart(data: data, color: color)
                                .frame(height: 100)
                        } else {
                            HistoryBarChart(data: data, color: color)
                                .frame(height: 100)
                        }
                    }
                    .padding(.leading, 16)
                    
                    // Y-axis labels on the right
                    VStack(alignment: .leading, spacing: 0) {
                        let maxValue = data.map { $0.1 }.max() ?? 1
                        let minValue = data.map { $0.1 }.min() ?? 0
                        
                        Text(formatAxisValue(maxValue))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatAxisValue((maxValue + minValue) / 2))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatAxisValue(minValue))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 30, height: 100)
                    .padding(.trailing, 8)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                // Bottom label
                Text("Most Recent Performances")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func formatAxisValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - History Card Component

struct ExerciseHistoryCard: View {
    let workout: ExerciseHistoryItem
    let isToday: Bool
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
                        
                        Text("\(set.reps) reps x \(Int(set.weight)) lb")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
            }
            
            // Est. 1 Rep Max
            VStack(alignment: .leading, spacing: 8) {
                Text("Est. 1 Rep Max")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Text("\(workout.estimatedOneRepMax, specifier: "%.1f") lb")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)
        
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
    
    var body: some View {
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
                    Image(systemName: "trophy")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
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
    
    // MARK: - Private Methods
    
    private func loadPersonalRecords() async {
        isLoading = true
        
        do {
            personalRecords = try await dataService.getPersonalRecords(exerciseId: exercise.exercise.id)
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
            // Trophy icon
            Image(systemName: "trophy.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)
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
