//
//  TimelineEvent.swift
//  pods
//
//  Created by Dimi Nunez on 1/17/26.
//


import Foundation

struct TimelineEvent: Identifiable, Equatable {
    enum EventType: Equatable {
        case wake
        case food
        case workout
        case cardio
        case water
    }

    struct Details: Equatable {
        var calories: Int?
        var protein: Int?
        var carbs: Int?
        var fat: Int?
        var durationMinutes: Int?
        var exercises: Int?
        var distanceMiles: Double?
        var amountText: String?
        var milestoneText: String?
        var sleepDurationText: String?
        var sleepQuality: Int?
        var readinessScore: Int?

        init(
            calories: Int? = nil,
            protein: Int? = nil,
            carbs: Int? = nil,
            fat: Int? = nil,
            durationMinutes: Int? = nil,
            exercises: Int? = nil,
            distanceMiles: Double? = nil,
            amountText: String? = nil,
            milestoneText: String? = nil,
            sleepDurationText: String? = nil,
            sleepQuality: Int? = nil,
            readinessScore: Int? = nil
        ) {
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.durationMinutes = durationMinutes
            self.exercises = exercises
            self.distanceMiles = distanceMiles
            self.amountText = amountText
            self.milestoneText = milestoneText
            self.sleepDurationText = sleepDurationText
            self.sleepQuality = sleepQuality
            self.readinessScore = readinessScore
        }
    }

    let id: String
    let date: Date
    let type: EventType
    let title: String
    let details: Details
    let log: CombinedLog?
    let logs: [CombinedLog]

    init(date: Date, type: EventType, title: String, details: Details, log: CombinedLog?) {
        let resolvedLogs = log.map { [$0] } ?? []
        self.date = date
        self.type = type
        self.title = title
        self.details = details
        self.log = log
        self.logs = resolvedLogs
        self.id = TimelineEvent.makeId(type: type, date: date, log: log, logs: resolvedLogs)
    }

    init(date: Date, type: EventType, title: String, details: Details, logs: [CombinedLog]) {
        let resolvedLog = logs.first
        self.date = date
        self.type = type
        self.title = title
        self.details = details
        self.log = resolvedLog
        self.logs = logs
        self.id = TimelineEvent.makeId(type: type, date: date, log: resolvedLog, logs: logs)
    }

    private static func makeId(type: EventType, date: Date, log: CombinedLog?, logs: [CombinedLog]) -> String {
        if logs.count > 1 {
            let combined = logs.map(\.id).sorted().joined(separator: "|")
            return "group-\(type)-\(combined)"
        }
        if let log {
            return "log-\(log.id)"
        }
        let stamp = Int(date.timeIntervalSince1970)
        return "event-\(type)-\(stamp)"
    }

    var iconName: String {
        switch type {
        case .wake:
            return "sun.max.fill"
        case .food:
            return "fork.knife"
        case .workout, .cardio:
            return "flame.fill"
        case .water:
            return "drop.fill"
        }
    }

    var isGroupedFood: Bool {
        type == .food && logs.count > 1
    }

    static func == (lhs: TimelineEvent, rhs: TimelineEvent) -> Bool {
        lhs.id == rhs.id
    }
}

typealias TimelineEventDetails = TimelineEvent.Details
