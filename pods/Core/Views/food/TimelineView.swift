//
//  TimelineView.swift
//  pods
//
//  Created by Dimi Nunez on 12/14/25.
//

import SwiftUI

struct AppTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dayLogsVM: DayLogsViewModel

    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df
    }()

    private let isoFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .autoupdatingCurrent
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    var body: some View {
        NavigationStack {
            VStack {
                if dayLogsVM.isLoading && filteredLogs.isEmpty {
                    ProgressView("Loading timeline...")
                        .padding()
                } else if filteredLogs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("No events for this date")
                            .font(.headline)
                        Text("Log a meal, workout, or activity to see it appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        Section {
                            ForEach(filteredLogs) { log in
                                TimelineLogRow(
                                    log: log,
                                    time: timeString(for: log),
                                    accentColor: accentColor(for: log.type)
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(dateFormatter.string(from: selectedDate))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showDatePicker.toggle() }) {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "Select Date",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding()
                        Spacer()
                    }
                    .navigationTitle("Jump to date")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showDatePicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                selectedDate = dayLogsVM.selectedDate
                dayLogsVM.loadLogs(for: selectedDate, force: true)
            }
            .onChange(of: selectedDate) { _, newValue in
                dayLogsVM.loadLogs(for: newValue, force: true)
            }
        }
    }

    private var filteredLogs: [CombinedLog] {
        let calendar = Calendar.current
        return dayLogsVM.logs
            .filter { calendar.isDate(logDate(for: $0), inSameDayAs: selectedDate) }
            .sorted { logDate(for: $0) > logDate(for: $1) }
    }

    private func logDate(for log: CombinedLog) -> Date {
        if let scheduledAt = log.scheduledAt {
            return scheduledAt
        }
        if let raw = log.logDate, let parsed = isoFormatter.date(from: raw) {
            return parsed
        }
        return selectedDate
    }

    private func timeString(for log: CombinedLog) -> String {
        timeFormatter.string(from: logDate(for: log))
    }

    private func accentColor(for type: LogType) -> Color {
        switch type {
        case .food: return .orange
        case .meal: return .blue
        case .recipe: return .purple
        case .activity: return .green
        case .workout: return .pink
        }
    }
}

private struct TimelineLogRow: View {
    let log: CombinedLog
    let time: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: iconName(for: log.type))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title(for: log))
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let subtitle = subtitle(for: log) {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 10) {
                    if let calories = caloriesText(for: log) {
                        chip(text: calories, systemImage: "flame.fill", color: .orange)
                    }
                    if let protein = macroText(for: log.food?.protein ?? log.meal?.protein, label: "P") {
                        chip(text: protein, systemImage: "bolt.fill", color: .blue)
                    }
                    if let carbs = macroText(for: log.food?.carbs ?? log.meal?.carbs, label: "C") {
                        chip(text: carbs, systemImage: "leaf", color: .green)
                    }
                    if let fat = macroText(for: log.food?.fat ?? log.meal?.fat, label: "F") {
                        chip(text: fat, systemImage: "drop", color: .pink)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func iconName(for type: LogType) -> String {
        switch type {
        case .food: return "fork.knife"
        case .meal: return "takeoutbag.and.cup.and.straw"
        case .recipe: return "book.closed"
        case .activity: return "figure.walk"
        case .workout: return "dumbbell"
        }
    }

    private func title(for log: CombinedLog) -> String {
        switch log.type {
        case .food:
            return log.food?.displayName ?? log.message
        case .meal:
            return log.meal?.title ?? log.message
        case .recipe:
            return log.recipe?.title ?? log.message
        case .activity:
            return log.activity?.displayName ?? log.message
        case .workout:
            return log.workout?.title ?? log.message
        }
    }

    private func subtitle(for log: CombinedLog) -> String? {
        switch log.type {
        case .food:
            return log.mealType
        case .meal:
            return log.mealType
        case .recipe:
            return log.mealType
        case .activity:
            var parts: [String] = []
            if let duration = log.activity?.formattedDuration, !duration.isEmpty {
                parts.append(duration)
            }
            if let distance = log.activity?.formattedDistance {
                parts.append(distance)
            }
            if let calories = log.activity?.totalEnergyBurned, calories > 0 {
                parts.append("\(Int(calories)) kcal")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case .workout:
            var parts: [String] = []
            if let minutes = log.workout?.durationMinutes {
                parts.append("\(minutes) min")
            } else if let seconds = log.workout?.durationSeconds, seconds > 0 {
                parts.append("\(seconds)s")
            }
            if let exercises = log.workout?.exercisesCount, exercises > 0 {
                parts.append("\(exercises) exercises")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
    }

    private func caloriesText(for log: CombinedLog) -> String? {
        let calories = log.food?.calories ??
        log.meal?.calories ??
        log.recipe?.calories ??
        (log.type == .activity ? log.activity?.totalEnergyBurned : log.calories)
        guard let calories else { return nil }
        return "\(Int(calories)) kcal"
    }

    private func macroText(for value: Double?, label: String) -> String? {
        guard let value, value > 0 else { return nil }
        return "\(label) \(Int(value))g"
    }

    @ViewBuilder
    private func chip(text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)))
            .foregroundColor(color)
    }
}
