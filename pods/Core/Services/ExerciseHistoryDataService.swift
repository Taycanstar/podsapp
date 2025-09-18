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
    let period: TimePeriod
    let dateRange: DateRangeCodable
    
    init(maxReps: Int, maxWeight: Double, totalVolume: Double, estimatedOneRepMax: Double, averageReps: Double, averageWeight: Double, averageVolume: Double, period: TimePeriod, dateRange: (start: Date, end: Date)) {
        self.maxReps = maxReps
        self.maxWeight = maxWeight
        self.totalVolume = totalVolume
        self.estimatedOneRepMax = estimatedOneRepMax
        self.averageReps = averageReps
        self.averageWeight = averageWeight
        self.averageVolume = averageVolume
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
}

struct SetSummary: Codable {
    let id: UUID
    let reps: Int
    let weight: Double?
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
    
    private init() {}

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
    func getExerciseHistory(exerciseId: Int, period: TimePeriod) async throws -> ExerciseHistoryData {
        print("📊 ExerciseHistoryDataService: Fetching history for exercise \(exerciseId), period: \(period.displayName)")
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let cacheKey = "exercise_history_\(exerciseId)_\(period.rawValue)"
            
            // Check simple cache first
            if let cached = historyCache[cacheKey] {
                print("✅ ExerciseHistoryDataService: Found cached data for exercise \(exerciseId)")
                return cached
            }
            
            // Fetch from local data
            let workoutSessions = try await fetchWorkoutSessionsFromLocal(exerciseId: exerciseId, period: period)
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
    
    /// Get calculated metrics for a specific exercise and time period
    func getExerciseMetrics(exerciseId: Int, period: TimePeriod) async throws -> ExerciseMetrics {
        print("📈 ExerciseHistoryDataService: Calculating metrics for exercise \(exerciseId), period: \(period.displayName)")
        
        let historyData = try await getExerciseHistory(exerciseId: exerciseId, period: period)
        
        // Calculate metrics from workout sessions
        var allSets: [SetSummary] = []
        var maxReps = 0
        var maxWeight = 0.0
        var totalVolume = 0.0
        var estimatedOneRepMaxValues: [Double] = []
        
        for session in historyData.workoutSessions {
            allSets.append(contentsOf: session.sets)
            
            for set in session.sets where set.isCompleted {
                if set.reps > maxReps {
                    maxReps = set.reps
                }
                
                if let weight = set.weight, weight > maxWeight {
                    maxWeight = weight
                }
                
                if let weight = set.weight {
                    let volume = weight * Double(set.reps)
                    totalVolume += volume
                    
                    // Calculate estimated 1RM using Epley formula: weight * (1 + reps/30)
                    let estimatedOneRM = weight * (1 + Double(set.reps) / 30.0)
                    estimatedOneRepMaxValues.append(estimatedOneRM)
                }
            }
        }
        
        let completedSets = allSets.filter { $0.isCompleted && $0.weight != nil }
        let averageReps = completedSets.isEmpty ? 0.0 : Double(completedSets.map { $0.reps }.reduce(0, +)) / Double(completedSets.count)
        let averageWeight = completedSets.isEmpty ? 0.0 : completedSets.compactMap { $0.weight }.reduce(0, +) / Double(completedSets.count)
        let averageVolume = historyData.workoutSessions.isEmpty ? 0.0 : historyData.workoutSessions.map { $0.totalVolume }.reduce(0, +) / Double(historyData.workoutSessions.count)
        let maxEstimatedOneRepMax = estimatedOneRepMaxValues.max() ?? 0.0
        
        let metrics = ExerciseMetrics(
            maxReps: maxReps,
            maxWeight: maxWeight,
            totalVolume: totalVolume,
            estimatedOneRepMax: maxEstimatedOneRepMax,
            averageReps: averageReps,
            averageWeight: averageWeight,
            averageVolume: averageVolume,
            period: period,
            dateRange: (start: historyData.dateRange.start, end: historyData.dateRange.end)
        )
        
        print("✅ ExerciseHistoryDataService: Calculated metrics - maxReps: \(maxReps), maxWeight: \(maxWeight), totalVolume: \(totalVolume)")
        return metrics
    }
    
    /// Get personal records for a specific exercise
    func getPersonalRecords(exerciseId: Int) async throws -> PersonalRecords {
        print("🏆 ExerciseHistoryDataService: Fetching personal records for exercise \(exerciseId)")
        
        // Try to get from cache first
        if let cached = recordsCache[exerciseId] {
            return cached
        }
        
        // Get all-time history
        let allTimeHistory = try await getExerciseHistory(exerciseId: exerciseId, period: .year) // Get longest period available
        
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
    func getChartData(exerciseId: Int, metric: ChartMetric, period: TimePeriod) async throws -> [(Date, Double)] {
        print("📊 ExerciseHistoryDataService: Getting chart data for exercise \(exerciseId), metric: \(metric.rawValue), period: \(period.displayName)")
        
        let historyData = try await getExerciseHistory(exerciseId: exerciseId, period: period)
        
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
            }
            
            chartData.append((session.date, value))
        }
        
        // Sort by date
        chartData.sort { $0.0 < $1.0 }
        
        print("✅ ExerciseHistoryDataService: Generated \(chartData.count) chart data points")
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
    }
    
    // MARK: - Private Methods
    
    private func fetchWorkoutSessionsFromLocal(exerciseId: Int, period: TimePeriod) async throws -> [WorkoutSessionSummary] {
        print("🔍 ExerciseHistoryDataService: Fetching local workout sessions for exercise \(exerciseId)")
        
        // Get current user email from UserDefaults
        guard let currentUserEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            print("⚠️ No current user email found in UserDefaults")
            return []
        }
        
        do {
            // Use WorkoutDataManager to access SwiftData
            let workoutManager = WorkoutDataManager.shared
            let allWorkouts = try await workoutManager.fetchWorkouts(for: currentUserEmail)
            
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
                    // Convert sets to SetSummary format
                    let setSummaries = matchingExercise.sets.map { set in
                        SetSummary(
                            id: set.id,
                            reps: set.actualReps ?? set.targetReps,
                            weight: set.actualWeight ?? set.targetWeight,
                            isCompleted: set.isCompleted,
                            completedAt: set.completedAt
                        )
                    }
                    
                    // Calculate session metrics
                    let completedSets = setSummaries.filter { $0.isCompleted }
                    let maxReps = completedSets.map { $0.reps }.max() ?? 0
                    let maxWeight = completedSets.compactMap { $0.weight }.max() ?? 0.0
                    
                    // Calculate total volume
                    let totalVolume = completedSets.reduce(0.0) { total, set in
                        let weight = set.weight ?? 0.0
                        return total + (weight * Double(set.reps))
                    }
                    
                    // Calculate estimated 1RM using Epley formula: weight * (1 + reps/30)
                    let estimatedOneRepMax = completedSets.compactMap { set -> Double? in
                        guard let weight = set.weight, weight > 0 else { return nil }
                        return weight * (1 + Double(set.reps) / 30.0)
                    }.max() ?? 0.0
                    
                    let workoutSummary = WorkoutSessionSummary(
                        id: workout.id,
                        date: workout.startedAt,
                        sets: setSummaries,
                        estimatedOneRepMax: estimatedOneRepMax,
                        totalVolume: totalVolume,
                        maxWeight: maxWeight,
                        maxReps: maxReps
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
