//
//  TimelineService.swift
//  pods
//
//  Created by Dimi Nunez on 1/17/26.
//


import Foundation

/// Service responsible for building timeline events from logs and health data.
/// This keeps timeline computation out of the View layer to avoid SwiftUI re-render loops.
@MainActor
final class TimelineService {

    // MARK: - Date Formatters (reused for efficiency)

    private let iso8601WithFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let iso8601BasicFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private let iso8601DayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Public API

    /// Builds timeline events for a given date from logs and health data.
    /// - Parameters:
    ///   - date: The target date to build timeline for
    ///   - logs: Array of combined logs (food, meals, activities, workouts)
    ///   - healthMetricsSnapshot: Optional health metrics from backend/Oura
    ///   - sleepSummary: Optional sleep summary from HealthKit
    /// - Returns: Sorted array of timeline events for the date
    func buildTimelineEvents(
        for date: Date,
        logs: [CombinedLog],
        healthMetricsSnapshot: NetworkManagerTwo.HealthMetricsSnapshot?,
        sleepSummary: SleepSummary?
    ) -> [TimelineEvent] {
        var items: [TimelineEvent] = []

        if let wake = wakeTimelineEvent(
            for: date,
            sleepSummary: sleepSummary,
            healthMetricsSnapshot: healthMetricsSnapshot
        ) {
            items.append(wake)
        }

        items.append(contentsOf: timelineEventsFromLogs(logs, for: date))

        return items.sorted { $0.date < $1.date }
    }

    // MARK: - Wake Event Logic

    private func wakeTimelineEvent(
        for date: Date,
        sleepSummary: SleepSummary?,
        healthMetricsSnapshot: NetworkManagerTwo.HealthMetricsSnapshot?
    ) -> TimelineEvent? {
        let calendar = Calendar.current

        timelineDebug("wakeTimelineEvent date=\(date) summary=\(sleepSummary != nil) snapshot=\(healthMetricsSnapshot != nil)")

        // Try HealthKit sleep summary first
        if let summary = sleepSummary,
           let wakeDate = wakeDate(from: summary),
           isReasonableSleepDate(wakeDate, targetDate: date),
           calendar.isDate(wakeDate, inSameDayAs: date) {
            let readiness = computeReadinessScore(from: healthMetricsSnapshot)
            let sleepQuality = safeRoundedInt(healthMetricsSnapshot?.sleep, range: 0...100)
            timelineDebug("wakeTimelineEvent summaryBranch wakeDate=\(wakeDate) total=\(summary.totalSleepMinutes) onset=\(String(describing: summary.sleepOnset)) offset=\(String(describing: summary.sleepOffset)) readiness=\(String(describing: readiness)) sleepQuality=\(String(describing: sleepQuality))")
            return makeWakeEvent(
                date: wakeDate,
                durationMinutes: summary.totalSleepMinutes,
                readinessScore: readiness,
                sleepQuality: sleepQuality
            )
        }

        // Fall back to health metrics snapshot
        guard let snapshot = healthMetricsSnapshot,
              let raw = snapshot.rawMetrics else {
            timelineDebug("wakeTimelineEvent snapshotMissing")
            return nil
        }

        let readiness = readinessSignalsSatisfied(in: snapshot) ? computeReadinessScore(from: snapshot) : nil
        let sleepQuality = safeRoundedInt(snapshot.sleep, range: 0...100)
            ?? safeRoundedInt(raw.sleepScore, range: 0...100)
        let durationMinutes = timelineSleepDuration(from: raw)

        if let derivedWakeDate = wakeDateFromSnapshot(snapshot,
                                                      raw: raw,
                                                      durationMinutes: durationMinutes,
                                                      matching: date),
           isReasonableSleepDate(derivedWakeDate, targetDate: date) {
            timelineDebug("wakeTimelineEvent derivedBranch wakeDate=\(derivedWakeDate) duration=\(String(describing: durationMinutes)) midpoint=\(String(describing: raw.sleepMidpointMinutes)) readiness=\(String(describing: readiness)) sleepQuality=\(String(describing: sleepQuality))")
            return makeWakeEvent(
                date: derivedWakeDate,
                durationMinutes: durationMinutes,
                readinessScore: readiness,
                sleepQuality: sleepQuality
            )
        }

        if let fallbackDateString = raw.fallbackSleepDate,
           let fallbackDate = parseISODate(fallbackDateString),
           isReasonableSleepDate(fallbackDate, targetDate: date),
           calendar.isDate(fallbackDate, inSameDayAs: date) {
            timelineDebug("wakeTimelineEvent fallbackBranch wakeDate=\(fallbackDate) duration=\(String(describing: durationMinutes)) readiness=\(String(describing: readiness)) sleepQuality=\(String(describing: sleepQuality))")
            return makeWakeEvent(
                date: fallbackDate,
                durationMinutes: durationMinutes,
                readinessScore: readiness,
                sleepQuality: sleepQuality
            )
        }

        return nil
    }

    private func wakeDateFromSnapshot(
        _ snapshot: NetworkManagerTwo.HealthMetricsSnapshot,
        raw: NetworkManagerTwo.HealthMetricRawMetrics,
        durationMinutes: Double?,
        matching date: Date
    ) -> Date? {
        guard snapshotSleepSourceMatches(snapshot, date: date),
              let midpoint = safeMinutes(raw.sleepMidpointMinutes, allowZero: true),
              let duration = safeMinutes(durationMinutes) else {
            return nil
        }

        let wakeMinutes = midpoint + (duration / 2.0)
        return timelineDate(for: date, minutesFromStart: wakeMinutes)
    }

    private func wakeDate(from summary: SleepSummary) -> Date? {
        if let offset = summary.sleepOffset {
            return safeDate(offset)
        }
        if let onset = summary.sleepOnset {
            guard let totalMinutes = safeMinutes(summary.totalSleepMinutes) else { return nil }
            return safeDate(onset.addingTimeInterval(totalMinutes * 60.0))
        }
        return nil
    }

    private func snapshotSleepSourceMatches(_ snapshot: NetworkManagerTwo.HealthMetricsSnapshot, date: Date) -> Bool {
        let sourceString = snapshot.sleepSourceDate ?? snapshot.date
        let selectedString = iso8601DayFormatter.string(from: date)
        return sourceString == selectedString
    }

    private func timelineSleepDuration(from raw: NetworkManagerTwo.HealthMetricRawMetrics) -> Double? {
        if let total = safeMinutes(raw.totalSleepMinutes) { return total }
        if let hours = safeMinutes(raw.sleepHours).map({ $0 * 60.0 }) { return hours }
        if let stageTotal = sleepStageDuration(from: raw.sleepStageMinutes) { return stageTotal }
        if let inBed = safeMinutes(raw.inBedMinutes) { return inBed }
        return nil
    }

    private func sleepStageDuration(from stages: NetworkManagerTwo.HealthMetricRawMetrics.SleepStageMinutes?) -> Double? {
        guard let stages else { return nil }
        let totals = [stages.core, stages.deep, stages.rem].compactMap { safeMinutes($0) }
        let sum = totals.reduce(0, +)
        return sum > 0 ? sum : nil
    }

    private func timelineDate(for baseDate: Date, minutesFromStart: Double) -> Date? {
        guard minutesFromStart.isFinite, abs(minutesFromStart) < 100_000 else { return nil }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: baseDate)
        let dayOffset = Int(floor(minutesFromStart / 1440.0))
        let normalizedMinutes = minutesFromStart - Double(dayOffset) * 1440.0
        guard let dayAdjusted = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) else { return nil }
        guard let result = calendar.date(byAdding: .minute, value: Int(round(normalizedMinutes)), to: dayAdjusted) else {
            return nil
        }
        return safeDate(result)
    }

    private func makeWakeEvent(date: Date, durationMinutes: Double?, readinessScore: Int?, sleepQuality: Int?) -> TimelineEvent? {
        guard let safeDate = safeDate(date) else { return nil }
        let durationText = safeMinutes(durationMinutes).map { formatSleepDuration(minutes: $0) }
        let details = TimelineEvent.Details(
            sleepDurationText: durationText,
            sleepQuality: sleepQuality,
            readinessScore: readinessScore
        )
        timelineDebug("makeWakeEvent date=\(safeDate) duration=\(String(describing: durationMinutes)) readiness=\(String(describing: readinessScore)) sleepQuality=\(String(describing: sleepQuality))")
        return TimelineEvent(date: safeDate, type: .wake, title: "Woke up", details: details, log: nil)
    }

    // MARK: - Readiness Logic

    private func computeReadinessScore(from snapshot: NetworkManagerTwo.HealthMetricsSnapshot?) -> Int? {
        guard let snapshot, readinessSignalsSatisfied(in: snapshot) else { return nil }
        return safeRoundedInt(snapshot.readiness, range: 0...100)
    }

    private func readinessSignalsSatisfied(in snapshot: NetworkManagerTwo.HealthMetricsSnapshot) -> Bool {
        guard let raw = snapshot.rawMetrics else { return false }
        return hasSleepSignal(raw)
            && raw.hrv != nil
            && raw.restingHeartRate != nil
            && raw.skinTemperatureC != nil
            && raw.respiratoryRate != nil
    }

    private func hasSleepSignal(_ raw: NetworkManagerTwo.HealthMetricRawMetrics) -> Bool {
        if let total = raw.totalSleepMinutes, total > 0 { return true }
        if let hours = raw.sleepHours, hours > 0 { return true }
        if let inBed = raw.inBedMinutes, inBed > 0 { return true }
        if let stages = raw.sleepStageMinutes {
            let totals = [stages.deep, stages.rem, stages.core, stages.awake].compactMap { $0 }
            if totals.contains(where: { $0 > 0 }) { return true }
        }
        return false
    }

    // MARK: - Log Events Logic

    private func timelineEventsFromLogs(_ logs: [CombinedLog], for date: Date) -> [TimelineEvent] {
        let calendar = Calendar.current

        var foodLogsByTime: [Date: [CombinedLog]] = [:]
        var otherEvents: [TimelineEvent] = []

        for log in logs {
            guard let eventDate = timelineDate(for: log),
                  calendar.isDate(eventDate, inSameDayAs: date) else {
                continue
            }

            switch log.type {
            case .food, .meal, .recipe:
                // Group food logs by minute (ignore seconds for grouping)
                let roundedDate = calendar.date(
                    from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: eventDate)
                ) ?? eventDate
                foodLogsByTime[roundedDate, default: []].append(log)
            case .activity, .workout:
                if let event = timelineEvent(from: log, at: eventDate) {
                    otherEvents.append(event)
                }
            }
        }

        // Convert grouped food logs to timeline events
        var foodEvents: [TimelineEvent] = []
        for (eventDate, logs) in foodLogsByTime {
            if logs.count == 1, let log = logs.first {
                if let event = timelineEvent(from: log, at: eventDate) {
                    foodEvents.append(event)
                }
            } else {
                // Multiple food logs at same time - create grouped event
                let totalCalories = logs.reduce(0) { sum, log in
                    sum + (safeRoundedInt(log.displayCalories) ?? 0)
                }
                let totalProtein = logs.reduce(0) { sum, log in
                    sum + (macroDetails(for: log).protein ?? 0)
                }
                let totalCarbs = logs.reduce(0) { sum, log in
                    sum + (macroDetails(for: log).carbs ?? 0)
                }
                let totalFat = logs.reduce(0) { sum, log in
                    sum + (macroDetails(for: log).fat ?? 0)
                }

                let title = logs.count == 1 ? timelineTitle(for: logs[0]) : "\(logs.count) items"
                let details = TimelineEvent.Details(
                    calories: totalCalories,
                    protein: totalProtein,
                    carbs: totalCarbs,
                    fat: totalFat
                )
                foodEvents.append(TimelineEvent(date: eventDate, type: .food, title: title, details: details, logs: logs))
            }
        }

        return (foodEvents + otherEvents).sorted { $0.date < $1.date }
    }

    private func timelineEvent(from log: CombinedLog, at date: Date) -> TimelineEvent? {
        switch log.type {
        case .food, .meal, .recipe:
            let macros = macroDetails(for: log)
            let details = TimelineEvent.Details(
                calories: safeRoundedInt(log.displayCalories),
                protein: macros.protein,
                carbs: macros.carbs,
                fat: macros.fat
            )
            return TimelineEvent(date: date, type: .food, title: timelineTitle(for: log), details: details, log: log)
        case .activity:
            guard let activity = log.activity else { return nil }
            let durationMinutes = safeRoundedInt(activity.duration / 60)
            let distanceMiles = activity.totalDistance.map { $0 * 0.000621371 }
            let calories = safeRoundedInt(activity.totalEnergyBurned ?? log.calories)
            let details = TimelineEvent.Details(
                calories: calories,
                durationMinutes: durationMinutes,
                distanceMiles: distanceMiles
            )
            let eventType: TimelineEvent.EventType = activity.isDistanceActivity ? .cardio : .workout
            return TimelineEvent(date: date, type: eventType, title: activity.displayName, details: details, log: log)
        case .workout:
            guard let workout = log.workout else { return nil }
            let duration = workout.durationMinutes
                ?? workout.durationSeconds.map { max(1, Int(round(Double($0) / 60.0))) }
            let details = TimelineEvent.Details(
                calories: safeRoundedInt(log.calories),
                durationMinutes: duration,
                exercises: workout.exercisesCount
            )
            return TimelineEvent(date: date, type: .workout, title: workout.title, details: details, log: log)
        }
    }

    private func timelineDate(for log: CombinedLog) -> Date? {
        if let scheduled = log.scheduledAt, let safe = safeDate(scheduled) { return safe }
        if let mealDate = log.meal?.scheduledAt, let safe = safeDate(mealDate) { return safe }
        if let recipeDate = log.recipe?.scheduledAt, let safe = safeDate(recipeDate) { return safe }
        if let activityDate = log.activity?.startDate, let safe = safeDate(activityDate) { return safe }
        if let workoutDate = log.workout?.scheduledAt, let safe = safeDate(workoutDate) { return safe }
        return nil
    }

    private func timelineTitle(for log: CombinedLog) -> String {
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

    private func macroDetails(for log: CombinedLog) -> (protein: Int?, carbs: Int?, fat: Int?) {
        func normalized(_ value: Double?) -> Int? {
            guard let value = value, value.isFinite, value > 0 else { return nil }
            return Int(value.rounded())
        }

        let protein = log.food?.protein ?? log.meal?.protein ?? log.recipe?.protein
        let carbs = log.food?.carbs ?? log.meal?.carbs ?? log.recipe?.carbs
        let fat = log.food?.fat ?? log.meal?.fat ?? log.recipe?.fat
        return (
            normalized(protein),
            normalized(carbs),
            normalized(fat)
        )
    }

    // MARK: - Utility Functions

    private func parseISODate(_ string: String) -> Date? {
        if let value = iso8601WithFractionalFormatter.date(from: string) {
            return value
        }
        if let value = iso8601BasicFormatter.date(from: string) {
            return value
        }
        return iso8601DayFormatter.date(from: string)
    }

    private func formatSleepDuration(minutes: Double) -> String {
        guard minutes.isFinite, minutes > 0 else { return "0m" }
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    private func safeRoundedInt(_ value: Double?, range: ClosedRange<Double>? = nil) -> Int? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        if let range, !range.contains(value) {
            return nil
        }
        return Int(value.rounded())
    }

    private func safeMinutes(_ value: Double?, allowZero: Bool = false) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        if !allowZero && value == 0 { return nil }
        return min(value, 2_880)
    }

    private func safeDate(_ date: Date) -> Date? {
        date.timeIntervalSinceReferenceDate.isFinite ? date : nil
    }

    private func isReasonableSleepDate(_ date: Date, targetDate: Date) -> Bool {
        guard date.timeIntervalSinceReferenceDate.isFinite else { return false }
        return abs(date.timeIntervalSince(targetDate)) <= 60 * 60 * 36
    }

    private func timelineDebug(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("⏱️ [Timeline] \(message())")
        #endif
    }
}
