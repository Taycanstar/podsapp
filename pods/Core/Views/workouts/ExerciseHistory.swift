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
            .padding(.top, 16)
            
            // Content
            if selectedTab == .trends {
                ExerciseTrendsView(exercise: exercise)
            } else {
                ExerciseResultsView(exercise: exercise)
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
    
    // Sample data - in real implementation, this would come from database
    private let sampleWeightData = [(Date.now.addingTimeInterval(-86400 * 4), 45.0),
                                   (Date.now.addingTimeInterval(-86400 * 3), 47.5),
                                   (Date.now.addingTimeInterval(-86400 * 2), 45.0),
                                   (Date.now.addingTimeInterval(-86400 * 1), 50.0),
                                   (Date.now, 52.5)]
    
    private let sampleRepsData = [(Date.now.addingTimeInterval(-86400 * 4), 12.0),
                                 (Date.now.addingTimeInterval(-86400 * 3), 15.0),
                                 (Date.now.addingTimeInterval(-86400 * 2), 13.0),
                                 (Date.now.addingTimeInterval(-86400 * 1), 15.0),
                                 (Date.now, 17.0)]
    
    private let sampleVolumeData = [(Date.now.addingTimeInterval(-86400 * 4), 1350.0),
                                   (Date.now.addingTimeInterval(-86400 * 3), 1425.0),
                                   (Date.now.addingTimeInterval(-86400 * 2), 1170.0),
                                   (Date.now.addingTimeInterval(-86400 * 1), 1500.0),
                                   (Date.now, 1785.0)]
    
    private let sampleOneRepMaxData = [(Date.now.addingTimeInterval(-86400 * 4), 71.6),
                                      (Date.now.addingTimeInterval(-86400 * 3), 76.2),
                                      (Date.now.addingTimeInterval(-86400 * 2), 72.8),
                                      (Date.now.addingTimeInterval(-86400 * 1), 80.5),
                                      (Date.now, 85.3)]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                HistoryMetricCard(
                    title: "Reps",
                    currentValue: "15",
                    loggedAgo: "Logged 47 seconds ago",
                    data: sampleRepsData,
                    chartType: .line,
                    color: .red
                )
                
                HistoryMetricCard(
                    title: "Volume",
                    currentValue: "2,025",
                    loggedAgo: "Logged 47 seconds ago",
                    data: sampleVolumeData,
                    chartType: .bar,
                    color: .red
                )
                
                HistoryMetricCard(
                    title: "Weight",
                    currentValue: "52.5",
                    loggedAgo: "Logged 47 seconds ago",
                    data: sampleWeightData,
                    chartType: .line,
                    color: .blue
                )
                
                HistoryMetricCard(
                    title: "Est. 1 Rep Max",
                    currentValue: "85.3",
                    loggedAgo: "Logged 47 seconds ago",
                    data: sampleOneRepMaxData,
                    chartType: .line,
                    color: .orange
                )
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - Results View

struct ExerciseResultsView: View {
    let exercise: TodayWorkoutExercise
    
    // Sample workout history data
    private let sampleWorkouts = [
        ExerciseHistoryItem(
            date: Date.now,
            sets: [
                HistoryWorkoutSet(reps: 10, weight: 45),
                HistoryWorkoutSet(reps: 10, weight: 45),
                HistoryWorkoutSet(reps: 10, weight: 45)
            ],
            estimatedOneRepMax: 63.9,
            trend: "+2 more reps"
        ),
        ExerciseHistoryItem(
            date: Date.now.addingTimeInterval(-86400),
            sets: [
                HistoryWorkoutSet(reps: 15, weight: 45),
                HistoryWorkoutSet(reps: 15, weight: 45),
                HistoryWorkoutSet(reps: 15, weight: 45)
            ],
            estimatedOneRepMax: 71.6,
            trend: nil
        ),
        ExerciseHistoryItem(
            date: Date.now.addingTimeInterval(-86400 * 3),
            sets: [
                HistoryWorkoutSet(reps: 12, weight: 40),
                HistoryWorkoutSet(reps: 12, weight: 40),
                HistoryWorkoutSet(reps: 10, weight: 40)
            ],
            estimatedOneRepMax: 58.2,
            trend: nil
        )
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(Array(sampleWorkouts.enumerated()), id: \.offset) { index, workout in
                    ExerciseHistoryCard(workout: workout, isToday: index == 0)
                }
                
                // Show records button
                Button(action: {
                    // Handle show records action
                }) {
                    HStack {
                        Text("Show records")
                            .font(.system(size: 16, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
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
    
    enum ChartType {
        case line, bar
    }
    
    var body: some View {
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
                            Text("lbs")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        } else if title == "Weight" {
                            Text("lbs in 1 set")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        } else if title == "Est. 1 Rep Max" {
                            Text("lbs in 1 rep")
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
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text(isToday ? "Today" : dateFormatter.string(from: workout.date))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Rate Exertion button moved to the right side of header
                if isToday {
                    if hasRatedRIR {
                        Text("\(Int(rirValue)) more rep\(Int(rirValue) == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor)
                            .cornerRadius(12)
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
                } else if let trend = workout.trend {
                    Text(trend)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red)
                        .cornerRadius(12)
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
                    
                    Text("in 1 Rep")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary)
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

// MARK: - RIR Rating Sheet

struct RIRRatingSheet: View {
    @Binding var rirValue: Double
    @Binding var hasRatedRIR: Bool
    @Binding var isPresented: Bool
    
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
                RIRSlider(value: $rirValue)
                    .frame(height: 80)
                
                Spacer()
                
                // Done button
                Button(action: {
                    hasRatedRIR = true
                    isPresented = false
                }) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 16)
            }
            .padding()
            .navigationTitle("Rate Exertion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
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