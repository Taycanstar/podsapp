//
//  ExerciseHistoryDataService.swift
//  pods
//
//  Created by Dimi Nunez on 8/21/25.
//

//
//  ExerciseHistoryDataService.swift
//  pods
//
//  Created by Dimi Nunez on 8/21/25.
//

import Foundation
import SwiftData

// MARK: - Data Models

struct ExerciseHistoryData: Codable {
    let exerciseId: Int
    let exerciseName: String
    let workoutSessions: [WorkoutSessionSummary]
    let period: TimePeriod
    let dateRange: DateRangeCodable
    
    init(exerciseId: Int, exerciseName: String, workoutSessions: [WorkoutSessionSummary], period: TimePeriod, dateRange: (start: Date, end: Date)) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.workoutSessions = workoutSessions
        self.period = period
        self.dateRange = DateRangeCodable(start: dateRange.start, end: dateRange.end)
    }
}

struct ExerciseMetrics: Codable {
    let maxReps: Int
    let maxWeight: Double
    let totalVolume: Double
    let estimatedOneRepMax: Double
    let averageReps: Double
    let averageWeight: Double
    let averageVolume: Double
    let maxDurationSeconds: Double
    let totalDurationSeconds: Double
    let averageDurationSeconds: Double
    let maxDistanceMeters: Double
    let totalDistanceMeters: Double
    let averageDistanceMeters: Double
    let period: TimePeriod
    let dateRange: DateRangeCodable
    
    init(maxReps: Int,
         maxWeight: Double,
         totalVolume: Double,
         estimatedOneRepMax: Double,
         averageReps: Double,
         averageWeight: Double,
         averageVolume: Double,
         maxDurationSeconds: Double,
         totalDurationSeconds: Double,
         averageDurationSeconds: Double,
         maxDistanceMeters: Double,
         totalDistanceMeters: Double,
         averageDistanceMeters: Double,
         period: TimePeriod,
         dateRange: (start: Date, end: Date)) {
        self.maxReps = maxReps
        self.maxWeight = maxWeight
        self.totalVolume = totalVolume
        self.estimatedOneRepMax = estimatedOneRepMax
        self.averageReps = averageReps
        self.averageWeight = averageWeight
        self.averageVolume = averageVolume
        self.maxDurationSeconds = maxDurationSeconds
        self.totalDurationSeconds = totalDurationSeconds
        self.averageDurationSeconds = averageDurationSeconds
        self.maxDistanceMeters = maxDistanceMeters
        self.totalDistanceMeters = totalDistanceMeters
        self.averageDistanceMeters = averageDistanceMeters
        self.period = period
        self.dateRange = DateRangeCodable(start: dateRange.start, end: dateRange.end)
    }
}

struct WorkoutSessionSummary: Codable {
    let id: UUID
    let date: Date
    let sets: [SetSummary]
    let estimatedOneRepMax: Double
    let totalVolume: Double
    let maxWeight: Double
    let maxReps: Int
    let maxDurationSeconds: Double
    let totalDurationSeconds: Double
    let maxDistanceMeters: Double
    let totalDistanceMeters: Double
    let trackingType: ExerciseTrackingType?
}

struct SetSummary: Codable {
    let id: UUID
    let reps: Int?
    let weight: Double?
    let durationSeconds: Int?
    let distanceMeters: Double?
    let trackingType: ExerciseTrackingType?
    let isCompleted: Bool
    let completedAt: Date?
}

struct PersonalRecords: Codable {
    let exerciseId: Int
    let exerciseName: String
    let maxWeight: RecordValue
    let maxReps: RecordValueInt
    let maxVolume: RecordValue
    let maxEstimatedOneRepMax: RecordValue
    
    init(exerciseId: Int, exerciseName: String, maxWeight: (value: Double, date: Date), maxReps: (value: Int, date: Date), maxVolume: (value: Double, date: Date), maxEstimatedOneRepMax: (value: Double, date: Date)) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.maxWeight = RecordValue(value: maxWeight.value, date: maxWeight.date)
        self.maxReps = RecordValueInt(value: maxReps.value, date: maxReps.date)
        self.maxVolume = RecordValue(value: maxVolume.value, date: maxVolume.date)
        self.maxEstimatedOneRepMax = RecordValue(value: maxEstimatedOneRepMax.value, date: maxEstimatedOneRepMax.date)
    }
}

// Helper structs for Codable conformance
struct DateRangeCodable: Codable {
    let start: Date
    let end: Date
}

struct RecordValue: Codable {
    let value: Double
    let date: Date
}

struct RecordValueInt: Codable {
    let value: Int
    let date: Date
}

// Lightweight usage summary for variability algorithms
struct RecentExerciseUsage: Hashable {
    let exercise: ExerciseData
    let lastPerformed: Date
    let sessionCount: Int
}

enum ExerciseHistoryDataError: LocalizedError {
    case missingModelContext

    var errorDescription: String? {
        switch self {
        case .missingModelContext:
            return "Missing SwiftData context for exercise history operations."
        }
    }
}

// MARK: - Exercise History Data Service

@MainActor
class ExerciseHistoryDataService: ObservableObject {
    static let shared = ExerciseHistoryDataService()
    
    @Published var isLoading = false
    @Published var error: Error?
    
    // Simple in-memory cache
    private var historyCache: [String: ExerciseHistoryData] = [:]
    private var metricsCache: [String: ExerciseMetrics] = [:]
    private var recordsCache: [Int: PersonalRecords] = [:]
    private var chartDataCache: [String: [(Date, Double)]] = [:]
    private var lastKnownContext: ModelContext?
    private var lastRemoteHistoryFetch: [String: Date] = [:]
    private let remoteRefreshInterval: TimeInterval = 300
   
    private init() {}

    // MARK: - Cache Accessors (non-blocking)

    func getCachedExerciseHistory(exerciseId: Int, period: TimePeriod) -> ExerciseHistoryData? {
        let key = "exercise_history_\(exerciseId)_\(period.rawValue)"
        return historyCache[key]
    }

    func getCachedMetrics(exerciseId: Int, period: TimePeriod) -> ExerciseMetrics? {
        let key = "metrics_\(exerciseId)_\(period.rawValue)"
        return metricsCache[key]
    }

    func getCachedChartData(exerciseId: Int, metric: ChartMetric, period: TimePeriod) -> [(Date, Double)]? {
        let key = "chart_\(exerciseId)_\(metric.rawValue)_\(period.rawValue)"
        return chartDataCache[key]
    }

    func getCachedPersonalRecords(exerciseId: Int) -> PersonalRecords? {
        return recordsCache[exerciseId]
    }

    func setModelContext(_ context: ModelContext) {
        lastKnownContext = context
    }

    private func resolveContext(_ context: ModelContext?) throws -> ModelContext {
        if let context {
            lastKnownContext = context
            return context
        }
        if let cached = lastKnownContext {
            return cached
        }
        throw ExerciseHistoryDataError.missingModelContext
    }

    // MARK: - Lightweight recent history helpers

    /// Returns recent exercise usage for a muscle group within a time window.
    /// The method is `nonisolated` so recommendation pipelines can call it without
    /// hopping onto the main actor (it only reads immutable snapshots).
    nonisolated static func getRecentExercises(
        for muscleGroup: String,
        days: Int
    ) -> [RecentExerciseUsage] {
        let history = UserProfileService.shared.getWorkoutHistory()
        guard !history.isEmpty else { return [] }

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let allExercises = ExerciseDatabase.getAllExercises()
        let exerciseMap = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        let recommender = WorkoutRecommendationService.shared

        struct UsageAccumulator {
            var exercise: ExerciseData
            var lastPerformed: Date
            var sessionCount: Int
        }

        var usage: [Int: UsageAccumulator] = [:]

        for entry in history where entry.date >= cutoff {
            for completed in entry.exercises {
                guard let exerciseData = exerciseMap[completed.exerciseId] else { continue }
                guard recommender.exerciseMatchesMuscle(exerciseData, muscleGroup: muscleGroup) else { continue }

                var accumulator = usage[exerciseData.id] ?? UsageAccumulator(
                    exercise: exerciseData,
                    lastPerformed: entry.date,
                    sessionCount: 0
                )
                accumulator.sessionCount += 1
                if entry.date > accumulator.lastPerformed {
                    accumulator.lastPerformed = entry.date
                }
                usage[exerciseData.id] = accumulator
            }
        }

        guard !usage.isEmpty else { return [] }

        let sorted = usage.values.sorted { lhs, rhs in
            if lhs.sessionCount != rhs.sessionCount {
                return lhs.sessionCount > rhs.sessionCount
            }
            return lhs.lastPerformed > rhs.lastPerformed
        }

        return sorted.map { RecentExerciseUsage(exercise: $0.exercise, lastPerformed: $0.lastPerformed, sessionCount: $0.sessionCount) }
    }
    
    // MARK: - Public Methods
    
    /// Get exercise history for a specific exercise and time period
    func getExerciseHistory(exerciseId: Int, period: TimePeriod, context: ModelContext? = nil) async throws -> ExerciseHistoryData {
        print("📊 ExerciseHistoryDataService: Fetching history for exercise \(exerciseId), period: \(period.displayName)")

        isLoading = true
        defer { isLoading = false }

        do {
            let resolvedContext = try resolveContext(context)
            let cacheKey = "exercise_history_\(exerciseId)_\(period.rawValue)"
            let needsRemoteRefresh = shouldRefreshRemoteHistory(exerciseId: exerciseId, period: period)

            if let cached = historyCache[cacheKey], !needsRemoteRefresh {
                print("✅ ExerciseHistoryDataService: Found cached data for exercise \(exerciseId)")
                return cached
            }

            let workoutSessions = try await fetchWorkoutSessions(
                exerciseId: exerciseId,
                period: period,
                context: resolvedContext,
                forceRemote: needsRemoteRefresh
            )
            let (startDate, endDate) = getDateRange(for: period)
            
            let exerciseName = getExerciseName(exerciseId: exerciseId)
            
            let historyData = ExerciseHistoryData(
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                workoutSessions: workoutSessions,
                period: period,
                dateRange: (start: startDate, end: endDate)
            )
            
            // Cache the result
            historyCache[cacheKey] = historyData
            
            print("✅ ExerciseHistoryDataService: Created history data with \(workoutSessions.count) sessions")
            return historyData
            
        } catch {
            print("❌ ExerciseHistoryDataService: Error fetching history - \(error)")
            self.error = error
            throw error
        }
    }
    
    private func remoteHistoryKey(exerciseId: Int, period: TimePeriod) -> String {
        return "\(exerciseId)_\(period.rawValue)"
    }

    private func shouldRefreshRemoteHistory(exerciseId: Int, period: TimePeriod) -> Bool {
        let key = remoteHistoryKey(exerciseId: exerciseId, period: period)
        guard let lastFetch = lastRemoteHistoryFetch[key] else { return true }
        return Date().timeIntervalSince(lastFetch) >= remoteRefreshInterval
    }

    private func fetchWorkoutSessions(
        exerciseId: Int,
        period: TimePeriod,
        context: ModelContext,
        forceRemote: Bool
    ) async throws -> [WorkoutSessionSummary] {
        if forceRemote {
            do {
                if let remoteSessions = try await fetchWorkoutSessionsFromRemote(
                    exerciseId: exerciseId,
                    period: period
                ) {
                    return remoteSessions
                }
            } catch {
                print("⚠️ ExerciseHistoryDataService: Remote refresh failed - \(error)")
            }
        }

        return try await fetchWorkoutSessionsFromLocal(
            exerciseId: exerciseId,
            period: period,
            context: context
        )
    }

    private func fetchWorkoutSessionsFromRemote(
        exerciseId: Int,
        period: TimePeriod
    ) async throws -> [WorkoutSessionSummary]? {
        guard let currentUserEmail = UserDefaults.standard.string(forKey: "userEmail"), !currentUserEmail.isEmpty else {
            return nil
        }

        let fetchKey = remoteHistoryKey(exerciseId: exerciseId, period: period)

        do {
            let response = try await NetworkManagerTwo.shared.fetchExerciseHistory(
                userEmail: currentUserEmail,
                exerciseId: exerciseId,
                daysBack: period.approximateDays
            )

            let summaries: [WorkoutSessionSummary] = response.sessions.map { session in
                let setSummaries: [SetSummary] = session.sets
                    .filter { !$0.isWarmup }
                    .map { set in
                        let weightInPounds: Double? = {
                            guard let kg = set.weightKg else { return nil }
                            return kg * 2.20462
                        }()

                        let resolvedTrackingType = set.trackingType.flatMap(ExerciseTrackingType.init(rawValue:))
                        let treatedAsCompleted = set.isCompleted
                            || (set.durationSeconds ?? 0) > 0
                            || (set.reps ?? 0) > 0
                            || (weightInPounds ?? 0) > 0

                        return SetSummary(
                            id: UUID(),
                            reps: set.reps,
                            weight: weightInPounds,
                            durationSeconds: set.durationSeconds,
                            distanceMeters: set.distanceMeters,
                            trackingType: resolvedTrackingType,
                            isCompleted: treatedAsCompleted,
                            completedAt: set.completedAt
                        )
                    }

                let date = session.completedAt ?? session.startedAt ?? session.scheduledDate ?? Date()
                let trackingType = session.trackingType.flatMap(ExerciseTrackingType.init(rawValue:))

                print("📥 Remote history session \(session.workoutSessionId) started=\(session.startedAt?.description ?? "nil") completed=\(session.completedAt?.description ?? "nil") scheduled=\(session.scheduledDate?.description ?? "nil")")

                return makeWorkoutSessionSummary(
                    id: UUID(),
                    date: date,
                    setSummaries: setSummaries,
                    trackingType: trackingType
                )
            }

            summaries.forEach { summary in
                print("🧮 Summary session \(summary.id) date=\(summary.date) maxReps=\(summary.maxReps) maxWeight=\(summary.maxWeight)")
            }

            lastRemoteHistoryFetch[fetchKey] = Date()

            // Clear cached data for this exercise & period to reflect fresh remote data
            let historyKey = "exercise_history_\(exerciseId)_\(period.rawValue)"
            historyCache.removeValue(forKey: historyKey)
            let metricsKey = "metrics_\(exerciseId)_\(period.rawValue)"
            metricsCache.removeValue(forKey: metricsKey)
            ChartMetric.allCases.forEach { metric in
                let chartKey = "chart_\(exerciseId)_\(metric.rawValue)_\(period.rawValue)"
                chartDataCache.removeValue(forKey: chartKey)
            }

            return summaries
        } catch {
            print("⚠️ ExerciseHistoryDataService: Remote history fetch failed - \(error)")
            return nil
        }
    }

    private func makeWorkoutSessionSummary(
        id: UUID,
        date: Date,
        setSummaries: [SetSummary],
        trackingType: ExerciseTrackingType?
    ) -> WorkoutSessionSummary {
        let completedSets = setSummaries.filter { $0.isCompleted }

        let maxReps = completedSets.compactMap { $0.reps }.max() ?? 0
        let maxWeight = completedSets.compactMap { $0.weight }.max() ?? 0.0
        let maxDurationSeconds = completedSets.compactMap { set -> Double? in
            guard let duration = set.durationSeconds else { return nil }
            return Double(duration)
        }.max() ?? 0.0
        let totalDurationSeconds = completedSets.reduce(0.0) { total, set in
            total + Double(set.durationSeconds ?? 0)
        }
        let maxDistanceMeters = completedSets.compactMap { $0.distanceMeters }.max() ?? 0.0
        let totalDistanceMeters = completedSets.reduce(0.0) { total, set in
            total + (set.distanceMeters ?? 0)
        }
        let totalVolume = completedSets.reduce(0.0) { total, set in
            let weight = set.weight ?? 0.0
            return total + (weight * Double(set.reps ?? 0))
        }
        let estimatedOneRepMax = completedSets.compactMap { set -> Double? in
            guard let weight = set.weight, weight > 0,
                  let reps = set.reps, reps > 0 else { return nil }
            return weight * (1 + Double(reps) / 30.0)
        }.max() ?? 0.0

        return WorkoutSessionSummary(
            id: id,
            date: date,
            sets: setSummaries,
            estimatedOneRepMax: estimatedOneRepMax,
            totalVolume: totalVolume,
            maxWeight: maxWeight,
            maxReps: maxReps,
            maxDurationSeconds: maxDurationSeconds,
            totalDurationSeconds: totalDurationSeconds,
            maxDistanceMeters: maxDistanceMeters,
            totalDistanceMeters: totalDistanceMeters,
            trackingType: trackingType
        )
    }

    /// Get calculated metrics for a specific exercise and time period
    func getExerciseMetrics(exerciseId: Int, period: TimePeriod, context: ModelContext? = nil) async throws -> ExerciseMetrics {
        print("📈 ExerciseHistoryDataService: Calculating metrics for exercise \(exerciseId), period: \(period.displayName)")

        let metricsKey = "metrics_\(exerciseId)_\(period.rawValue)"
        if let cached = metricsCache[metricsKey] {
            return cached
        }

        let historyData = try await getExerciseHistory(exerciseId: exerciseId, period: period, context: context)
        
        // Calculate metrics from workout sessions
        var allSets: [SetSummary] = []
        var maxReps = 0
        var maxWeight = 0.0
        var totalVolume = 0.0
        var estimatedOneRepMaxValues: [Double] = []
        var maxDurationSeconds = 0.0
        var totalDurationSeconds = 0.0
        var durationSamples = 0
        var maxDistanceMeters = 0.0
        var totalDistanceMeters = 0.0
        var distanceSamples = 0
        
        for session in historyData.workoutSessions {
            allSets.append(contentsOf: session.sets)
            
            for set in session.sets where set.isCompleted {
                if let reps = set.reps, reps > maxReps {
                    maxReps = reps
                }
                
                if let weight = set.weight, weight > maxWeight {
                    maxWeight = weight
                }
                
                if let weight = set.weight, let reps = set.reps {
                    let volume = weight * Double(reps)
                    totalVolume += volume
                    
                    // Calculate estimated 1RM using Epley formula: weight * (1 + reps/30)
                    let estimatedOneRM = weight * (1 + Double(reps) / 30.0)
                    estimatedOneRepMaxValues.append(estimatedOneRM)
                }
                
                if let duration = set.durationSeconds {
                    let durationValue = Double(duration)
                    maxDurationSeconds = max(maxDurationSeconds, durationValue)
                    totalDurationSeconds += durationValue
                    durationSamples += 1
                }
                
                if let distance = set.distanceMeters {
                    maxDistanceMeters = max(maxDistanceMeters, distance)
                    totalDistanceMeters += distance
                    distanceSamples += 1
                }
            }
        }
        
        let weightSets = allSets.filter { $0.isCompleted && $0.weight != nil && ($0.reps ?? 0) > 0 }
        let repSets = allSets.filter { $0.isCompleted && ($0.reps ?? 0) > 0 }
        let averageReps = repSets.isEmpty ? 0.0 : Double(repSets.compactMap { $0.reps }.reduce(0, +)) / Double(repSets.count)
        let averageWeight = weightSets.isEmpty ? 0.0 : weightSets.compactMap { $0.weight }.reduce(0, +) / Double(weightSets.count)
        let averageVolume = historyData.workoutSessions.isEmpty ? 0.0 : historyData.workoutSessions.map { $0.totalVolume }.reduce(0, +) / Double(historyData.workoutSessions.count)
        let maxEstimatedOneRepMax = estimatedOneRepMaxValues.max() ?? 0.0
        let averageDurationSeconds = durationSamples == 0 ? 0.0 : totalDurationSeconds / Double(durationSamples)
        let averageDistanceMeters = distanceSamples == 0 ? 0.0 : totalDistanceMeters / Double(distanceSamples)
        
        let metrics = ExerciseMetrics(
            maxReps: maxReps,
            maxWeight: maxWeight,
            totalVolume: totalVolume,
            estimatedOneRepMax: maxEstimatedOneRepMax,
            averageReps: averageReps,
            averageWeight: averageWeight,
            averageVolume: averageVolume,
            maxDurationSeconds: maxDurationSeconds,
            totalDurationSeconds: totalDurationSeconds,
            averageDurationSeconds: averageDurationSeconds,
            maxDistanceMeters: maxDistanceMeters,
            totalDistanceMeters: totalDistanceMeters,
            averageDistanceMeters: averageDistanceMeters,
            period: period,
            dateRange: (start: historyData.dateRange.start, end: historyData.dateRange.end)
        )
        
        print("✅ ExerciseHistoryDataService: Calculated metrics - maxReps: \(maxReps), maxWeight: \(maxWeight), totalVolume: \(totalVolume), maxDuration: \(maxDurationSeconds), totalDuration: \(totalDurationSeconds), maxDistance: \(maxDistanceMeters)")
        // Cache metrics for fast subsequent access
        metricsCache[metricsKey] = metrics
        return metrics
    }
    
    /// Get personal records for a specific exercise
    func getPersonalRecords(exerciseId: Int, context: ModelContext? = nil) async throws -> PersonalRecords {
        print("🏆 ExerciseHistoryDataService: Fetching personal records for exercise \(exerciseId)")

        // Try to get from cache first
        if let cached = recordsCache[exerciseId] {
            return cached
        }

        // Get all-time history
        let allTimeHistory = try await getExerciseHistory(exerciseId: exerciseId, period: .year, context: context)
        
        var maxWeight: (value: Double, date: Date) = (0.0, Date.distantPast)
        var maxReps: (value: Int, date: Date) = (0, Date.distantPast)
        var maxVolume: (value: Double, date: Date) = (0.0, Date.distantPast)
        var maxEstimatedOneRepMax: (value: Double, date: Date) = (0.0, Date.distantPast)
        
        for session in allTimeHistory.workoutSessions {
            if session.maxWeight > maxWeight.value {
                maxWeight = (session.maxWeight, session.date)
            }
            
            if session.maxReps > maxReps.value {
                maxReps = (session.maxReps, session.date)
            }
            
            if session.totalVolume > maxVolume.value {
                maxVolume = (session.totalVolume, session.date)
            }
            
            if session.estimatedOneRepMax > maxEstimatedOneRepMax.value {
                maxEstimatedOneRepMax = (session.estimatedOneRepMax, session.date)
            }
        }
        
        let exerciseName = getExerciseName(exerciseId: exerciseId)
        
        let records = PersonalRecords(
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            maxWeight: maxWeight,
            maxReps: maxReps,
            maxVolume: maxVolume,
            maxEstimatedOneRepMax: maxEstimatedOneRepMax
        )
        
        // Cache the result
        recordsCache[exerciseId] = records
        
        return records
    }
    
    /// Get chart data for a specific metric and time period
    func getChartData(exerciseId: Int, metric: ChartMetric, period: TimePeriod, context: ModelContext? = nil) async throws -> [(Date, Double)] {
        print("📊 ExerciseHistoryDataService: Getting chart data for exercise \(exerciseId), metric: \(metric.rawValue), period: \(period.displayName)")

        let chartKey = "chart_\(exerciseId)_\(metric.rawValue)_\(period.rawValue)"
        if let cached = chartDataCache[chartKey] {
            return cached
        }

        let historyData = try await getExerciseHistory(exerciseId: exerciseId, period: period, context: context)
        
        // Convert workout sessions to chart data points
        var chartData: [(Date, Double)] = []
        
        for session in historyData.workoutSessions {
            let value: Double
            
            switch metric {
            case .reps:
                value = Double(session.maxReps)
            case .weight:
                value = session.maxWeight
            case .volume:
                value = session.totalVolume
            case .estOneRepMax:
                value = session.estimatedOneRepMax
            case .duration:
                value = session.maxDurationSeconds
            case .totalDuration:
                value = session.totalDurationSeconds
            case .distance:
                value = session.totalDistanceMeters
            }
            
            chartData.append((session.date, value))
        }
        
        // Sort by date
        chartData.sort { $0.0 < $1.0 }
        
        print("✅ ExerciseHistoryDataService: Generated \(chartData.count) chart data points")
        // Cache generated chart data
        chartDataCache[chartKey] = chartData
        return chartData
    }
    
    /// Clear cached data for an exercise (called when new workout is completed)
    func invalidateCache(for exerciseId: Int) async {
        print("🗑️ ExerciseHistoryDataService: Invalidating cache for exercise \(exerciseId)")
        
        // Clear all cached data for this exercise
        for period in TimePeriod.allCases {
            let historyKey = "exercise_history_\(exerciseId)_\(period.rawValue)"
            historyCache.removeValue(forKey: historyKey)
            
            for metric in ChartMetric.allCases {
                let chartKey = "chart_\(exerciseId)_\(metric.rawValue)_\(period.rawValue)"
                chartDataCache.removeValue(forKey: chartKey)
            }
        }
        
        // Clear personal records cache
        recordsCache.removeValue(forKey: exerciseId)
        
        // Clear metrics cache
        for period in TimePeriod.allCases {
            let metricsKey = "metrics_\(exerciseId)_\(period.rawValue)"
            metricsCache.removeValue(forKey: metricsKey)
        }

        for period in TimePeriod.allCases {
            let remoteKey = remoteHistoryKey(exerciseId: exerciseId, period: period)
            lastRemoteHistoryFetch.removeValue(forKey: remoteKey)
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchWorkoutSessionsFromLocal(exerciseId: Int, period: TimePeriod, context: ModelContext) async throws -> [WorkoutSessionSummary] {
        print("🔍 ExerciseHistoryDataService: Fetching local workout sessions for exercise \(exerciseId)")

        // Get current user email from UserDefaults
        guard let currentUserEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            print("⚠️ No current user email found in UserDefaults")
            return []
        }

        do {
            // Use WorkoutDataManager to access SwiftData
            let workoutManager = WorkoutDataManager.shared
            let allWorkouts = try await workoutManager.fetchWorkouts(for: currentUserEmail, context: context)
            
            // Get date range for filtering
            let (startDate, endDate) = getDateRange(for: period)
            
            // Filter workouts that contain the specific exercise and are in date range
            var matchingWorkouts: [WorkoutSessionSummary] = []
            
            for workout in allWorkouts {
                // Check if workout is in date range
                guard workout.startedAt >= startDate && workout.startedAt <= endDate else {
                    continue
                }
                
                // Check if workout contains the exercise we're looking for
                if let matchingExercise = workout.exercises.first(where: { $0.exerciseId == exerciseId }) {
                    let flexibleSets: [FlexibleSetData] = {
                        guard let data = matchingExercise.flexibleSetsData,
                              let decoded = try? JSONDecoder().decode([FlexibleSetData].self, from: data) else {
                            return []
                        }
                        return decoded.filter { !$0.isWarmupSet }
                    }()
                    
                    // Convert sets to SetSummary format
                    let setSummaries: [SetSummary] = matchingExercise.sets.enumerated().map { index, set in
                        let flex = index < flexibleSets.count ? flexibleSets[index] : nil
                        
                        let resolvedReps: Int? = {
                            if let actual = set.actualReps, actual > 0 { return actual }
                            if set.targetReps > 0 { return set.targetReps }
                            if let repsString = flex?.reps, let parsed = parseNumericString(repsString) {
                                return Int(parsed.rounded())
                            }
                            if let baseline = flex?.baselineReps, baseline > 0 { return baseline }
                            return nil
                        }()
                        
                        let resolvedDurationSeconds: Int? = {
                            if let duration = set.durationSeconds, duration > 0 { return duration }
                            if let duration = flex?.duration, duration > 0 { return Int(duration.rounded()) }
                            if let baseline = flex?.baselineDuration, baseline > 0 { return Int(baseline.rounded()) }
                            return nil
                        }()
                        
                        let resolvedDistanceMeters: Double? = {
                            if let distance = set.distanceMeters, distance > 0 { return distance }
                            guard let distance = flex?.distance, distance > 0 else { return nil }
                            return convertDistanceToMeters(distance, unit: flex?.distanceUnit)
                        }()
                        
                        let resolvedTrackingType = set.trackingType ?? flex?.trackingType
                        
                        return SetSummary(
                            id: set.id,
                            reps: resolvedReps,
                            weight: set.actualWeight ?? set.targetWeight,
                            durationSeconds: resolvedDurationSeconds,
                            distanceMeters: resolvedDistanceMeters,
                            trackingType: resolvedTrackingType,
                            isCompleted: set.isCompleted,
                            completedAt: set.completedAt
                        )
                    }
                    
                    let completedSets = setSummaries.filter { $0.isCompleted }
                    
                    var trackingType = completedSets.compactMap { $0.trackingType }.first
                    if trackingType == nil,
                       let flexFirst = flexibleSets.compactMap({ $0.trackingType }).first {
                        trackingType = flexFirst
                    }
                    
                    let sessionDate = workout.completedAt ?? workout.startedAt
                    
                    let workoutSummary = makeWorkoutSessionSummary(
                        id: workout.id,
                        date: sessionDate,
                        setSummaries: setSummaries,
                        trackingType: trackingType
                    )
                    
                    matchingWorkouts.append(workoutSummary)
                }
            }
            
            // Sort by date (oldest first)
            matchingWorkouts.sort { $0.date < $1.date }
            
            print("📊 Found \(matchingWorkouts.count) workout sessions for exercise \(exerciseId) in period \(period.displayName)")
            return matchingWorkouts
            
        } catch {
            print("❌ Error fetching workouts from SwiftData: \(error)")
            throw error
        }
    }
    
    private func parseNumericString(_ value: String?) -> Double? {
        guard let value else { return nil }
        let filtered = value.filter { "0123456789.,".contains($0) }.replacingOccurrences(of: ",", with: ".")
        guard !filtered.isEmpty else { return nil }
        return Double(filtered)
    }
    
    private func convertDistanceToMeters(_ value: Double, unit: DistanceUnit?) -> Double {
        guard let unit else { return value }
        switch unit {
        case .kilometers:
            return value * 1000.0
        case .miles:
            return value * 1609.34
        case .meters:
            return value
        }
    }
    
    
    private func getDateRange(for period: TimePeriod) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch period {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .sixMonths:
            startDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        return (start: startDate, end: now)
    }
    
    private func getExerciseName(exerciseId: Int) -> String {
        // Get exercise name from the exercise database
        let allExercises = ExerciseDatabase.getAllExercises()
        return allExercises.first { $0.id == exerciseId }?.name ?? "Unknown Exercise"
    }
}

// MARK: - Data Error

enum DataError: Error, LocalizedError {
    case contextNotAvailable
    case noDataFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .contextNotAvailable:
            return "SwiftData context not available"
        case .noDataFound:
            return "No data found for the specified criteria"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

// MARK: - Extensions

extension TimePeriod: Codable {}

extension ChartMetric: Codable {}

private extension TimePeriod {
    var approximateDays: Int {
        switch self {
        case .week:
            return 7
        case .month:
            return 30
        case .sixMonths:
            return 180
        case .year:
            return 365
        }
    }
}
