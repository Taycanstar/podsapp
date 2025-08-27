//
//  PerformanceFeedbackService.swift
//  pods
//
//  Created by Dimi Nunez on 8/26/25.
//

//
//  PerformanceFeedbackService.swift
//  pods
//
//  Created by Dimi Nunez on 8/26/25.
//

import Foundation
import SwiftUI

// Import core model types from proper model files
// TodayWorkout and related types are now in WorkoutModels.swift
// WorkoutSessionFeedback is in DynamicWorkoutModels.swift

/// Service for collecting, storing, and analyzing workout performance feedback
@MainActor
class PerformanceFeedbackService: ObservableObject {
    static let shared = PerformanceFeedbackService()
    
    @Published private(set) var feedbackHistory: [WorkoutSessionFeedback] = []
    @Published var currentFeedback: WorkoutSessionFeedback?
    @Published private(set) var performanceMetrics: PerformanceMetrics?
    
    private let feedbackStorageKey = "workoutFeedbackHistory"
    private let maxFeedbackHistory = 50  // Keep last 50 workouts
    
    private init() {
        loadFeedbackHistory()
        updatePerformanceMetrics()
    }
    
    // MARK: - Feedback Collection
    
    /// Initialize feedback collection for a completed workout
    func initializeFeedback(for workout: TodayWorkout) -> WorkoutSessionFeedback {
        let estimatedRPE = estimateInitialRPE(for: workout)
        
        let feedback = WorkoutSessionFeedback(
            workoutId: workout.id,
            overallRPE: estimatedRPE,
            difficultyRating: .justRight,  // Default assumption
            completionRate: 1.0,  // Assume full completion initially
            exerciseFeedback: [:],
            timestamp: Date()
        )
        
        currentFeedback = feedback
        return feedback
    }
    
    /// Submit completed feedback and trigger adaptation
    func submitFeedback(_ feedback: WorkoutSessionFeedback) async {
        print("📊 Submitting workout feedback: \(feedback.difficultyRating.displayName) (RPE: \(feedback.overallRPE))")
        
        // Add to history
        feedbackHistory.append(feedback)
        
        // Maintain reasonable history size
        if feedbackHistory.count > maxFeedbackHistory {
            feedbackHistory = Array(feedbackHistory.suffix(maxFeedbackHistory))
        }
        
        // Update performance metrics
        updatePerformanceMetrics()
        
        // Save to storage
        saveFeedbackHistory()
        
        // Clear current feedback
        currentFeedback = nil
        
        // Trigger next workout adaptation
        await triggerWorkoutAdaptation(feedback)
        
        print("📊 Feedback submitted successfully. Total feedback history: \(feedbackHistory.count)")
    }
    
    /// Skip feedback collection (still record the skip)
    func skipFeedback(for workoutId: UUID) async {
        let skippedFeedback = WorkoutSessionFeedback(
            workoutId: workoutId,
            overallRPE: 6.5,  // Neutral assumption
            difficultyRating: .justRight,
            completionRate: 1.0,
            exerciseFeedback: [:],
            timestamp: Date()
        )
        
        await submitFeedback(skippedFeedback)
        print("📊 Feedback skipped for workout \(workoutId)")
    }
    
    // MARK: - Performance Analysis
    
    /// Get current performance trends for auto-regulation
    func getPerformanceTrends() async -> PerformanceMetrics {
        if let cached = performanceMetrics {
            return cached
        }
        
        let metrics = calculatePerformanceMetrics()
        performanceMetrics = metrics
        return metrics
    }
    
    /// Calculate performance metrics from recent feedback
    private func calculatePerformanceMetrics() -> PerformanceMetrics {
        guard !feedbackHistory.isEmpty else {
            return .default
        }
        
        let recentFeedback = Array(feedbackHistory.suffix(10))  // Last 10 workouts
        
        // Calculate averages
        let averageRPE = recentFeedback.map(\.overallRPE).reduce(0, +) / Double(recentFeedback.count)
        let averageCompletionRate = recentFeedback.map(\.completionRate).reduce(0, +) / Double(recentFeedback.count)
        
        // Determine trend
        let trend = calculatePerformanceTrend(recentFeedback)
        
        // Calculate plateau risk
        let plateauRisk = calculatePlateauRisk(recentFeedback)
        
        return PerformanceMetrics(
            averageRPE: averageRPE,
            averageCompletionRate: averageCompletionRate,
            recentFeedbackCount: recentFeedback.count,
            trend: trend,
            plateauRisk: plateauRisk
        )
    }
    
    /// Calculate performance trend from recent feedback
    private func calculatePerformanceTrend(_ feedback: [WorkoutSessionFeedback]) -> PerformanceTrend {
        guard feedback.count >= 3 else { return .stable }
        
        let recent = Array(feedback.suffix(3))
        let earlier = Array(feedback.prefix(max(1, feedback.count - 3)))
        
        let recentAverageRPE = recent.map(\.overallRPE).reduce(0, +) / Double(recent.count)
        let earlierAverageRPE = earlier.map(\.overallRPE).reduce(0, +) / Double(earlier.count)
        
        let rpeDifference = recentAverageRPE - earlierAverageRPE
        
        if rpeDifference < -0.5 {
            return .improving  // RPE decreasing = getting easier = improving
        } else if rpeDifference > 0.5 {
            return .declining   // RPE increasing = getting harder = declining fitness
        } else {
            return .stable
        }
    }
    
    /// Calculate plateau risk (0.0-1.0)
    private func calculatePlateauRisk(_ feedback: [WorkoutSessionFeedback]) -> Double {
        guard feedback.count >= 5 else { return 0.0 }
        
        let recentRPEs = feedback.suffix(5).map(\.overallRPE)
        let rpeVariance = calculateVariance(recentRPEs)
        
        // Low variance = potential plateau
        // High variance = good adaptation
        let normalizedVariance = min(rpeVariance / 2.0, 1.0)  // Normalize to 0-1
        return 1.0 - normalizedVariance  // Invert so low variance = high plateau risk
    }
    
    /// Calculate variance of an array of doubles
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDeviations = values.map { pow($0 - mean, 2) }
        return squaredDeviations.reduce(0, +) / Double(values.count - 1)
    }
    
    /// Check if user needs a deload week
    func shouldRecommendDeload() -> Bool {
        let metrics = calculatePerformanceMetrics()
        
        // Recommend deload if:
        // 1. Average RPE is high (>8.0)
        // 2. Completion rate is declining (<90%)
        // 3. Performance trend is declining
        return metrics.averageRPE > 8.0 ||
               metrics.averageCompletionRate < 0.9 ||
               metrics.trend == .declining
    }
    
    // MARK: - Workout Adaptation
    
    /// Trigger next workout adaptation based on feedback
    private func triggerWorkoutAdaptation(_ feedback: WorkoutSessionFeedback) async {
        guard let workoutManager = WorkoutManagerHolder.shared.workoutManager else {
            print("⚠️ WorkoutManager not available for adaptation")
            return
        }
        
        await workoutManager.adaptNextWorkout(based: feedback)
        print("🎯 Next workout adaptation triggered based on feedback")
    }
    
    // MARK: - Data Persistence
    
    /// Load feedback history from UserDefaults
    private func loadFeedbackHistory() {
        guard let data = UserDefaults.standard.data(forKey: feedbackStorageKey) else {
            print("📊 No existing feedback history found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let history = try decoder.decode([WorkoutSessionFeedback].self, from: data)
            feedbackHistory = history
            print("📊 Loaded \(history.count) feedback entries from storage")
        } catch {
            print("⚠️ Failed to load feedback history: \(error)")
            feedbackHistory = []
        }
    }
    
    /// Save feedback history to UserDefaults
    private func saveFeedbackHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(feedbackHistory)
            UserDefaults.standard.set(data, forKey: feedbackStorageKey)
            print("📊 Saved \(feedbackHistory.count) feedback entries to storage")
        } catch {
            print("⚠️ Failed to save feedback history: \(error)")
        }
    }
    
    /// Update performance metrics after feedback changes
    private func updatePerformanceMetrics() {
        performanceMetrics = calculatePerformanceMetrics()
    }
    
    // MARK: - Helper Methods
    
    /// Estimate initial RPE based on workout characteristics
    private func estimateInitialRPE(for workout: TodayWorkout) -> Double {
        // Base RPE estimation based on workout properties
        var estimatedRPE: Double = 6.5  // Neutral starting point
        
        // Adjust based on fitness goal
        switch workout.fitnessGoal {
        case .strength, .powerlifting:
            estimatedRPE += 0.5  // Strength training typically feels harder
        case .endurance:
            estimatedRPE -= 0.3  // Endurance training might feel more manageable
        case .hypertrophy, .general, .tone:
            break  // Keep neutral
        default:
            break
        }
        
        // Adjust based on exercise count (more exercises = potentially harder)
        let exerciseCount = workout.exercises.count
        if exerciseCount > 6 {
            estimatedRPE += 0.3
        } else if exerciseCount < 4 {
            estimatedRPE -= 0.3
        }
        
        // Clamp to valid RPE range
        return max(1.0, min(10.0, estimatedRPE))
    }
    
    /// Get feedback summary for analytics
    func getFeedbackSummary() -> String {
        guard !feedbackHistory.isEmpty else {
            return "No feedback history available"
        }
        
        let recentCount = min(5, feedbackHistory.count)
        let recent = feedbackHistory.suffix(recentCount)
        
        let averageRPE = recent.map(\.overallRPE).reduce(0, +) / Double(recent.count)
        let difficultyDistribution = Dictionary(grouping: recent, by: \.difficultyRating)
            .mapValues { $0.count }
        
        return """
        Recent Performance (\(recentCount) workouts):
        Average RPE: \(String(format: "%.1f", averageRPE))
        Difficulty Distribution: \(difficultyDistribution)
        Total Feedback History: \(feedbackHistory.count) workouts
        """
    }
}

// MARK: - WorkoutManager Integration Helper

/// Temporary holder to avoid circular dependencies
class WorkoutManagerHolder {
    static let shared = WorkoutManagerHolder()
    weak var workoutManager: WorkoutManager?
    
    private init() {}
}

// MARK: - Extension for Testing

extension PerformanceFeedbackService {
    /// Clear all feedback history (for testing)
    func clearFeedbackHistory() {
        feedbackHistory = []
        currentFeedback = nil
        performanceMetrics = nil
        UserDefaults.standard.removeObject(forKey: feedbackStorageKey)
        print("📊 Cleared all feedback history")
    }
    
    /// Add mock feedback for testing
    func addMockFeedback(count: Int) {
        let mockWorkoutId = UUID()
        
        for i in 0..<count {
            let difficulty: WorkoutSessionFeedback.DifficultyRating
            switch i % 4 {
            case 0: difficulty = .tooEasy
            case 1: difficulty = .justRight
            case 2: difficulty = .challenging
            default: difficulty = .tooHard
            }
            
            let feedback = WorkoutSessionFeedback(
                workoutId: mockWorkoutId,
                overallRPE: difficulty.estimatedRPE,
                difficultyRating: difficulty,
                completionRate: Double.random(in: 0.8...1.0),
                timestamp: Date().addingTimeInterval(-Double(i) * 86400) // Spread over days
            )
            
            feedbackHistory.append(feedback)
        }
        
        updatePerformanceMetrics()
        saveFeedbackHistory()
        print("📊 Added \(count) mock feedback entries")
    }
}