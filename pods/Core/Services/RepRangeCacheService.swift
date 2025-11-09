//
//  RepRangeCacheService.swift
//  pods
//
//  Created by Performance Architect on 8/26/25.
//

import Foundation
import SwiftUI

/// High-performance caching service for dynamic rep range calculations
/// Implements multi-tier caching strategy for instant feel performance
@MainActor
class RepRangeCacheService: ObservableObject {
    static let shared = RepRangeCacheService()
    
    // MARK: - Cache Tiers
    
    /// Tier 1: Hot cache for immediate access (1-5ms)
    private let hotCache = NSCache<NSString, CachedRepRangeResult>()
    
    /// Tier 2: Performance metrics cache (10-20ms)
    private var metricsCache: PerformanceMetricsCache?
    
    /// Tier 3: Exercise conversion cache (persistent)
    private var exerciseConversionCache: [String: CachedExerciseConversion] = [:]
    
    // MARK: - Performance Monitoring
    
    @Published private(set) var performanceMetrics = CachePerformanceMetrics()
    private var cacheRequests: Int = 0
    private var cacheHits: Int = 0
    
    // MARK: - Configuration
    
    private let maxHotCacheEntries = 100
    private let hotCacheTTL: TimeInterval = 300 // 5 minutes
    private let metricsCacheTTL: TimeInterval = 300 // 5 minutes
    private let conversionCacheTTL: TimeInterval = 1800 // 30 minutes
    
    private init() {
        setupCacheConfiguration()
        setupMemoryWarningObserver()
    }
    
    // MARK: - Public Cache Interface
    
    /// Get cached rep range or calculate if not cached
    func getRepRange(
        for exercise: ExerciseData,
        fitnessGoal: FitnessGoal,
        sessionPhase: SessionPhase,
        recoveryStatus: RecoveryStatus = .moderate,
        feedback: WorkoutSessionFeedback? = nil
    ) async -> ClosedRange<Int> {
        
        let cacheKey = RepRangeCacheKey(
            exerciseId: exercise.id,
            fitnessGoal: fitnessGoal,
            sessionPhase: sessionPhase,
            exerciseType: MovementType.classify(exercise),
            recoveryStatus: recoveryStatus,
            lastFeedbackHash: feedback?.hashValue
        )
        
        cacheRequests += 1
        
        // Tier 1: Check hot cache first
        if let cached = getFromHotCache(key: cacheKey) {
            cacheHits += 1
            updatePerformanceMetrics()
            return cached.repRange
        }
        
        // Cache miss - calculate and store
        let calculatedRange = await calculateRepRange(
            fitnessGoal: fitnessGoal,
            sessionPhase: sessionPhase,
            exerciseType: MovementType.classify(exercise),
            recoveryStatus: recoveryStatus,
            feedback: feedback
        )
        
        // Store in hot cache
        storeInHotCache(key: cacheKey, range: calculatedRange, setCount: calculateSetCount(for: exercise, goal: fitnessGoal, phase: sessionPhase))
        
        updatePerformanceMetrics()
        return calculatedRange
    }
    
    /// Get cached dynamic exercise conversion or calculate
    func getDynamicExercise(
        for exercise: ExerciseData,
        parameters: DynamicWorkoutParameters,
        fitnessGoal: FitnessGoal
    ) async -> DynamicWorkoutExercise {
        
        let conversionKey = ExerciseConversionCacheKey(
            exerciseId: exercise.id,
            parametersHash: parameters.hashValue,
            fitnessGoalHash: fitnessGoal.hashValue
        )
        
        // Check conversion cache
        if let cached = exerciseConversionCache[conversionKey.stringValue],
           cached.isValid {
            cacheHits += 1
            updatePerformanceMetrics()
            return cached.dynamicExercise
        }
        
        // Calculate new conversion
        let dynamicExercise = await DynamicParameterService.shared.generateDynamicExercise(
            for: exercise,
            parameters: parameters,
            fitnessGoal: fitnessGoal
        )
        
        // Store in conversion cache
        exerciseConversionCache[conversionKey.stringValue] = CachedExerciseConversion(
            dynamicExercise: dynamicExercise,
            timestamp: Date()
        )
        
        updatePerformanceMetrics()
        return dynamicExercise
    }
    
    /// Prefetch rep ranges for common scenarios
    func prefetchCommonRanges(
        for exercises: [ExerciseData],
        currentPhase: SessionPhase,
        fitnessGoal: FitnessGoal
    ) async {
        
        // Prefetch current phase + next phase combinations
        let phases = [currentPhase, currentPhase.nextPhase()]
        let recoveryStates: [RecoveryStatus] = [.fresh, .moderate, .fatigued]
        
        await withTaskGroup(of: Void.self) { group in
            for exercise in exercises {
                for phase in phases {
                    for recovery in recoveryStates {
                        group.addTask {
                            _ = await self.getRepRange(
                                for: exercise,
                                fitnessGoal: fitnessGoal,
                                sessionPhase: phase,
                                recoveryStatus: recovery
                            )
                        }
                    }
                }
            }
        }
        
        print("🔄 Prefetched rep ranges for \(exercises.count) exercises across \(phases.count) phases")
    }
    
    // MARK: - Cache Management
    
    /// Invalidate cache entries based on feedback updates
    func invalidateCache(affectedBy feedback: WorkoutSessionFeedback) {
        // Invalidate metrics cache
        metricsCache = nil
        
        // Invalidate hot cache entries that depend on feedback
        hotCache.removeAllObjects()
        
        print("🗑️ Cache invalidated due to feedback update")
    }
    
    /// Clear all caches (for memory pressure or testing)
    func clearAllCaches() {
        hotCache.removeAllObjects()
        metricsCache = nil
        exerciseConversionCache.removeAll()
        
        // Reset performance metrics
        cacheRequests = 0
        cacheHits = 0
        updatePerformanceMetrics()
        
        print("🗑️ All caches cleared")
    }
    
    // MARK: - Private Implementation
    
    private func setupCacheConfiguration() {
        hotCache.countLimit = maxHotCacheEntries
        hotCache.name = "RepRangeHotCache"
        
        // Configure cache for optimal performance
        hotCache.evictsObjectsWithDiscardedContent = true
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        print("⚠️ Memory warning - clearing caches")
        
        // Clear conversion cache first (largest)
        exerciseConversionCache.removeAll()
        
        // Reduce hot cache size
        hotCache.countLimit = maxHotCacheEntries / 2
        
        // Clear metrics cache
        metricsCache = nil
    }
    
    private func getFromHotCache(key: RepRangeCacheKey) -> CachedRepRangeResult? {
        return hotCache.object(forKey: key.stringValue as NSString)
    }
    
    private func storeInHotCache(key: RepRangeCacheKey, range: ClosedRange<Int>, setCount: Int) {
        let cached = CachedRepRangeResult(
            repRange: range,
            setCount: setCount,
            timestamp: Date()
        )
        
        hotCache.setObject(cached, forKey: key.stringValue as NSString)
    }
    
    private func calculateRepRange(
        fitnessGoal: FitnessGoal,
        sessionPhase: SessionPhase,
        exerciseType: MovementType,
        recoveryStatus: RecoveryStatus,
        feedback: WorkoutSessionFeedback?
    ) async -> ClosedRange<Int> {
        
        // Use optimized calculation pipeline
        let service = DynamicParameterService.shared
        
        let baseRange = service.getBaseRepRangeForGoal(fitnessGoal)
        let phaseAdjusted = service.adjustRangeForSessionPhase(baseRange, sessionPhase: sessionPhase)
        let typeAdjusted = service.adjustRangeForExerciseType(phaseAdjusted, exerciseType: exerciseType)
        let recoveryAdjusted = service.adjustRangeForRecovery(typeAdjusted, recoveryStatus: recoveryStatus)
        let finalRange = service.adjustRangeForFeedback(recoveryAdjusted, feedback: feedback)
        
        return finalRange
    }
    
    private func calculateSetCount(for exercise: ExerciseData, goal: FitnessGoal, phase: SessionPhase) -> Int {
        // Simplified set count calculation for caching
        switch goal {
        case .strength, .powerlifting:
            return phase == .strengthFocus ? 4 : 3
        case .hypertrophy:
            return phase == .volumeFocus ? 4 : 3
        default:
            return 3
        }
    }
    
    private func updatePerformanceMetrics() {
        let hitRate = cacheRequests > 0 ? Double(cacheHits) / Double(cacheRequests) : 0.0
        let memoryUsage = estimateMemoryUsage()
        
        performanceMetrics = CachePerformanceMetrics(
            hitRate: hitRate,
            totalRequests: cacheRequests,
            memoryUsage: memoryUsage,
            hotCacheSize: hotCache.totalCostLimit
        )
    }
    
    private func estimateMemoryUsage() -> Int64 {
        // Rough estimation of cache memory usage
        let hotCacheSize = Int64(maxHotCacheEntries * 200) // ~200 bytes per entry
        let conversionCacheSize = Int64(exerciseConversionCache.count * 1000) // ~1KB per exercise
        let metricsCacheSize: Int64 = metricsCache != nil ? 500 : 0 // ~500 bytes for metrics
        
        return hotCacheSize + conversionCacheSize + metricsCacheSize
    }
}

// MARK: - Cache Data Structures

/// Deterministic cache key for rep range calculations
struct RepRangeCacheKey: Hashable {
    let exerciseId: Int
    let fitnessGoal: FitnessGoal
    let sessionPhase: SessionPhase
    let exerciseType: MovementType
    let recoveryStatus: RecoveryStatus
    let lastFeedbackHash: Int?
    
    var stringValue: String {
        let feedbackHash = lastFeedbackHash?.description ?? "nil"
        return "\(exerciseId)_\(fitnessGoal.rawValue)_\(sessionPhase.rawValue)_\(exerciseType.rawValue)_\(recoveryStatus.rawValue)_\(feedbackHash)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(stringValue)
    }
}

/// Cache key for exercise conversions
struct ExerciseConversionCacheKey: Hashable {
    let exerciseId: Int
    let parametersHash: Int
    let fitnessGoalHash: Int
    
    var stringValue: String {
        return "\(exerciseId)_\(parametersHash)_\(fitnessGoalHash)"
    }
}

/// Cached rep range result with metadata
class CachedRepRangeResult: NSObject {
    let repRange: ClosedRange<Int>
    let setCount: Int
    let timestamp: Date
    
    init(repRange: ClosedRange<Int>, setCount: Int, timestamp: Date) {
        self.repRange = repRange
        self.setCount = setCount
        self.timestamp = timestamp
        super.init()
    }
    
    var isValid: Bool {
        let age = Date().timeIntervalSince(timestamp)
        return age < 300 // 5 minute TTL
    }
}

/// Cached exercise conversion with validation
struct CachedExerciseConversion {
    let dynamicExercise: DynamicWorkoutExercise
    let timestamp: Date
    
    var isValid: Bool {
        let age = Date().timeIntervalSince(timestamp)
        return age < 1800 // 30 minute TTL
    }
}

/// Performance metrics cache with invalidation
struct PerformanceMetricsCache {
    let metrics: PerformanceMetrics
    let feedbackCount: Int
    let timestamp: Date
    
    func isValid(currentFeedbackCount: Int) -> Bool {
        let age = Date().timeIntervalSince(timestamp)
        return age < 300 && feedbackCount == currentFeedbackCount // 5 min TTL
    }
}

/// Cache performance metrics for monitoring
struct CachePerformanceMetrics {
    let hitRate: Double
    let totalRequests: Int
    let memoryUsage: Int64
    let hotCacheSize: Int
    
    init() {
        self.hitRate = 0.0
        self.totalRequests = 0
        self.memoryUsage = 0
        self.hotCacheSize = 0
    }
    
    init(hitRate: Double, totalRequests: Int, memoryUsage: Int64, hotCacheSize: Int) {
        self.hitRate = hitRate
        self.totalRequests = totalRequests
        self.memoryUsage = memoryUsage
        self.hotCacheSize = hotCacheSize
    }
    
    var isPerformingWell: Bool {
        return hitRate > 0.85 && memoryUsage < 50_000_000 // 50MB limit
    }
}

// MARK: - Extension for DynamicParameterService Access

extension DynamicParameterService {
    
    // Expose internal methods for caching service
    func getBaseRepRangeForGoal(_ goal: FitnessGoal) -> ClosedRange<Int> {
        // Make internal method accessible
        switch goal.normalized {
        case .strength:
            return 3...6
        case .powerlifting:
            return 1...5
        case .hypertrophy:
            return 6...15
        case .circuitTraining:
            return 15...25
        case .general:
            return 8...15
        case .olympicWeightlifting:
            return 1...5
        default:
            return 8...12
        }
    }
    
    func adjustRangeForSessionPhase(_ baseRange: ClosedRange<Int>, sessionPhase: SessionPhase) -> ClosedRange<Int> {
        switch sessionPhase {
        case .strengthFocus:
            let newUpper = baseRange.lowerBound + (baseRange.upperBound - baseRange.lowerBound) / 2
            return baseRange.lowerBound...max(baseRange.lowerBound + 1, newUpper)
        case .volumeFocus:
            let rangeMid = baseRange.lowerBound + (baseRange.upperBound - baseRange.lowerBound) / 3
            return rangeMid...baseRange.upperBound
        }
    }
    
    func adjustRangeForExerciseType(_ range: ClosedRange<Int>, exerciseType: MovementType) -> ClosedRange<Int> {
        switch exerciseType {
        case .compound:
            return max(1, range.lowerBound - 1)...max(range.lowerBound, range.upperBound - 2)
        case .isolation:
            return (range.lowerBound + 1)...(range.upperBound + 2)
        case .core:
            return max(10, range.lowerBound + 3)...(range.upperBound + 5)
        case .cardio:
            return max(12, range.lowerBound + 5)...(range.upperBound + 8)
        }
    }
    
    func adjustRangeForRecovery(_ range: ClosedRange<Int>, recoveryStatus: RecoveryStatus) -> ClosedRange<Int> {
        switch recoveryStatus {
        case .fresh:
            return max(1, range.lowerBound - 1)...range.upperBound
        case .moderate:
            return range
        case .fatigued:
            return (range.lowerBound + 2)...(range.upperBound + 3)
        }
    }
    
    func adjustRangeForFeedback(_ range: ClosedRange<Int>, feedback: WorkoutSessionFeedback?) -> ClosedRange<Int> {
        guard let feedback = feedback else { return range }
        
        switch feedback.difficultyRating {
        case .tooEasy:
            return max(1, range.lowerBound - 2)...max(range.lowerBound, range.upperBound - 2)
        case .justRight:
            return range
        case .challenging:
            return range.lowerBound...(range.upperBound + 1)
        case .tooHard:
            return (range.lowerBound + 2)...(range.upperBound + 3)
        }
    }
}
