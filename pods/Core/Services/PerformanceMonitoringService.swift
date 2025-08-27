//
//  PerformanceMonitoringService.swift
//  pods
//
//  Created by Performance Architect on 8/26/25.
//

import Foundation
import SwiftUI
import os.log

/// Comprehensive performance monitoring for dynamic programming system
/// Tracks algorithm execution, cache performance, and UI responsiveness
@MainActor
class PerformanceMonitoringService: ObservableObject {
    static let shared = PerformanceMonitoringService()
    
    // MARK: - Published State
    
    @Published private(set) var currentMetrics = AlgorithmPerformanceMetrics()
    @Published private(set) var isPerformanceOptimal = true
    @Published private(set) var performanceAlerts: [PerformanceAlert] = []
    
    // MARK: - Performance Budgets
    
    private let performanceBudgets = PerformanceBudgets(
        maxRepRangeCalculationTime: 0.1,    // 100ms
        maxUIUpdateLatency: 0.016,          // 16ms (60fps)
        minCacheHitRate: 0.85,              // 85%
        maxMemoryUsage: 30_000_000,         // 30MB
        maxAlgorithmExecutionTime: 0.05     // 50ms for 12-exercise conversion
    )
    
    // MARK: - Monitoring State
    
    private var measurementHistory: [PerformanceMeasurement] = []
    private let maxHistorySize = 100
    private let logger = Logger(subsystem: "com.pods.performance", category: "DynamicProgramming")
    
    // MARK: - Timing Measurements
    
    private var activeTimers: [String: Date] = [:]
    private var recentMeasurements: [String: [TimeInterval]] = [:]
    
    private init() {
        setupPerformanceObservers()
        startPeriodicMonitoring()
    }
    
    // MARK: - Public Monitoring Interface
    
    /// Start timing a performance-critical operation
    func startTiming(for operation: String) {
        activeTimers[operation] = Date()
        logger.debug("Started timing: \(operation)")
    }
    
    /// End timing and record measurement
    func endTiming(for operation: String) -> TimeInterval? {
        guard let startTime = activeTimers.removeValue(forKey: operation) else {
            logger.warning("No active timer found for operation: \(operation)")
            return nil
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordMeasurement(operation: operation, duration: duration)
        
        logger.debug("Completed timing: \(operation) - \(String(format: "%.3f", duration * 1000))ms")
        
        return duration
    }
    
    /// Time an async operation
    func timeOperation<T>(
        _ operation: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        startTiming(for: operation)
        defer { _ = endTiming(for: operation) }
        return try await operation()
    }
    
    /// Time a synchronous operation
    func timeOperation<T>(
        _ operationName: String,
        operation: () throws -> T
    ) rethrows -> T {
        startTiming(for: operationName)
        defer { _ = endTiming(for: operationName) }
        return try operation()
    }
    
    /// Record cache performance metrics
    func recordCacheMetrics(
        operation: String,
        hitRate: Double,
        memoryUsage: Int64,
        totalRequests: Int
    ) {
        let measurement = CachePerformanceMeasurement(
            operation: operation,
            hitRate: hitRate,
            memoryUsage: memoryUsage,
            totalRequests: totalRequests,
            timestamp: Date()
        )
        
        evaluateCachePerformance(measurement)
        updateCurrentMetrics()
        
        logger.info("Cache metrics - \(operation): Hit rate: \(String(format: "%.2f", hitRate * 100))%, Memory: \(ByteCountFormatter.string(fromByteCount: memoryUsage, countStyle: .memory))")
    }
    
    /// Record UI responsiveness measurement
    func recordUILatency(_ latency: TimeInterval, for operation: String) {
        recordMeasurement(operation: "UI_\(operation)", duration: latency)
        
        if latency > performanceBudgets.maxUIUpdateLatency {
            raiseAlert(.uiResponsiveness(
                operation: operation,
                actualLatency: latency,
                maxLatency: performanceBudgets.maxUIUpdateLatency
            ))
        }
    }
    
    /// Get performance summary for debugging
    func getPerformanceSummary() -> String {
        let recentMeasurementsCount = measurementHistory.suffix(20).count
        let averageRepRangeTime = getAverageTime(for: "repRangeCalculation")
        let averageUILatency = getAverageTime(for: "UIUpdate")
        let currentCacheHitRate = currentMetrics.cacheHitRate
        
        return """
        === Performance Summary ===
        Recent Measurements: \(recentMeasurementsCount)
        Rep Range Calculation: \(String(format: "%.1f", averageRepRangeTime * 1000))ms avg
        UI Update Latency: \(String(format: "%.1f", averageUILatency * 1000))ms avg
        Cache Hit Rate: \(String(format: "%.1f", currentCacheHitRate * 100))%
        Memory Usage: \(ByteCountFormatter.string(fromByteCount: currentMetrics.memoryUsage, countStyle: .memory))
        Performance Status: \(isPerformanceOptimal ? "Optimal" : "Needs Attention")
        Active Alerts: \(performanceAlerts.count)
        """
    }
    
    /// Reset all performance data
    func resetMetrics() {
        measurementHistory.removeAll()
        performanceAlerts.removeAll()
        recentMeasurements.removeAll()
        activeTimers.removeAll()
        
        currentMetrics = AlgorithmPerformanceMetrics()
        isPerformanceOptimal = true
        
        logger.info("Performance metrics reset")
    }
    
    // MARK: - Private Implementation
    
    private func setupPerformanceObservers() {
        // Observe memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func startPeriodicMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performPeriodicCheck()
            }
        }
    }
    
    private func recordMeasurement(operation: String, duration: TimeInterval) {
        let measurement = PerformanceMeasurement(
            operation: operation,
            duration: duration,
            timestamp: Date()
        )
        
        measurementHistory.append(measurement)
        
        // Maintain history size
        if measurementHistory.count > maxHistorySize {
            measurementHistory.removeFirst(measurementHistory.count - maxHistorySize)
        }
        
        // Track recent measurements for operation
        if recentMeasurements[operation] == nil {
            recentMeasurements[operation] = []
        }
        recentMeasurements[operation]?.append(duration)
        
        // Keep only recent measurements (last 10)
        if let count = recentMeasurements[operation]?.count, count > 10 {
            recentMeasurements[operation]?.removeFirst(count - 10)
        }
        
        // Check against performance budgets
        evaluatePerformance(measurement)
        updateCurrentMetrics()
    }
    
    private func evaluatePerformance(_ measurement: PerformanceMeasurement) {
        switch measurement.operation {
        case let op where op.contains("repRange"):
            if measurement.duration > performanceBudgets.maxRepRangeCalculationTime {
                raiseAlert(.algorithmPerformance(
                    operation: measurement.operation,
                    actualTime: measurement.duration,
                    maxTime: performanceBudgets.maxRepRangeCalculationTime
                ))
            }
            
        case let op where op.contains("UI"):
            if measurement.duration > performanceBudgets.maxUIUpdateLatency {
                raiseAlert(.uiResponsiveness(
                    operation: measurement.operation,
                    actualLatency: measurement.duration,
                    maxLatency: performanceBudgets.maxUIUpdateLatency
                ))
            }
            
        case let op where op.contains("algorithm"):
            if measurement.duration > performanceBudgets.maxAlgorithmExecutionTime {
                raiseAlert(.algorithmPerformance(
                    operation: measurement.operation,
                    actualTime: measurement.duration,
                    maxTime: performanceBudgets.maxAlgorithmExecutionTime
                ))
            }
            
        default:
            break
        }
    }
    
    private func evaluateCachePerformance(_ measurement: CachePerformanceMeasurement) {
        if measurement.hitRate < performanceBudgets.minCacheHitRate {
            raiseAlert(.cachePerformance(
                operation: measurement.operation,
                actualHitRate: measurement.hitRate,
                minHitRate: performanceBudgets.minCacheHitRate
            ))
        }
        
        if measurement.memoryUsage > performanceBudgets.maxMemoryUsage {
            raiseAlert(.memoryUsage(
                actualUsage: measurement.memoryUsage,
                maxUsage: performanceBudgets.maxMemoryUsage
            ))
        }
    }
    
    private func updateCurrentMetrics() {
        let repRangeTime = getAverageTime(for: "repRange")
        let uiLatency = getAverageTime(for: "UI")
        let algorithmTime = getAverageTime(for: "algorithm")
        
        currentMetrics = AlgorithmPerformanceMetrics(
            repRangeCalculationTime: repRangeTime,
            cacheHitRate: getCacheHitRate(),
            memoryUsage: getEstimatedMemoryUsage(),
            uiUpdateLatency: uiLatency,
            algorithmExecutionTime: algorithmTime
        )
        
        // Update overall performance status
        isPerformanceOptimal = currentMetrics.isWithinBudgets(performanceBudgets)
    }
    
    private func getAverageTime(for operationPrefix: String) -> TimeInterval {
        let matchingMeasurements = recentMeasurements.filter { key, _ in
            key.contains(operationPrefix)
        }.flatMap { $0.value }
        
        guard !matchingMeasurements.isEmpty else { return 0.0 }
        
        return matchingMeasurements.reduce(0.0, +) / Double(matchingMeasurements.count)
    }
    
    private func getCacheHitRate() -> Double {
        // Get cache hit rate from RepRangeCacheService
        return RepRangeCacheService.shared.performanceMetrics.hitRate
    }
    
    private func getEstimatedMemoryUsage() -> Int64 {
        // Estimate memory usage from various sources
        let cacheMemory = RepRangeCacheService.shared.performanceMetrics.memoryUsage
        let historyMemory = Int64(measurementHistory.count * 100) // ~100 bytes per measurement
        return cacheMemory + historyMemory
    }
    
    private func raiseAlert(_ alert: PerformanceAlert) {
        // Avoid duplicate alerts
        if !performanceAlerts.contains(where: { $0.id == alert.id }) {
            performanceAlerts.append(alert)
            logger.warning("Performance alert: \(alert.message)")
        }
        
        // Maintain reasonable alert count
        if performanceAlerts.count > 20 {
            performanceAlerts.removeFirst(performanceAlerts.count - 20)
        }
    }
    
    private func performPeriodicCheck() {
        // Clean up old alerts (older than 5 minutes)
        let cutoffTime = Date().addingTimeInterval(-300)
        performanceAlerts.removeAll { $0.timestamp < cutoffTime }
        
        // Update overall performance status
        updateCurrentMetrics()
        
        logger.info("Periodic performance check completed - Status: \(isPerformanceOptimal ? "Optimal" : "Needs Attention")")
    }
    
    private func handleMemoryWarning() {
        raiseAlert(.memoryPressure)
        
        // Clear old measurement history
        if measurementHistory.count > 50 {
            measurementHistory.removeFirst(measurementHistory.count - 50)
        }
        
        logger.warning("Memory warning handled - cleared old performance data")
    }
}

// MARK: - Performance Data Structures

/// Performance measurement for timing operations
struct PerformanceMeasurement {
    let operation: String
    let duration: TimeInterval
    let timestamp: Date
    
    var durationMs: Double {
        return duration * 1000.0
    }
}

/// Cache-specific performance measurement
struct CachePerformanceMeasurement {
    let operation: String
    let hitRate: Double
    let memoryUsage: Int64
    let totalRequests: Int
    let timestamp: Date
}

/// Algorithm performance metrics aggregation
struct AlgorithmPerformanceMetrics {
    let repRangeCalculationTime: TimeInterval
    let cacheHitRate: Double
    let memoryUsage: Int64
    let uiUpdateLatency: TimeInterval
    let algorithmExecutionTime: TimeInterval
    
    init() {
        self.repRangeCalculationTime = 0.0
        self.cacheHitRate = 0.0
        self.memoryUsage = 0
        self.uiUpdateLatency = 0.0
        self.algorithmExecutionTime = 0.0
    }
    
    init(
        repRangeCalculationTime: TimeInterval,
        cacheHitRate: Double,
        memoryUsage: Int64,
        uiUpdateLatency: TimeInterval,
        algorithmExecutionTime: TimeInterval
    ) {
        self.repRangeCalculationTime = repRangeCalculationTime
        self.cacheHitRate = cacheHitRate
        self.memoryUsage = memoryUsage
        self.uiUpdateLatency = uiUpdateLatency
        self.algorithmExecutionTime = algorithmExecutionTime
    }
    
    func isWithinBudgets(_ budgets: PerformanceBudgets) -> Bool {
        return repRangeCalculationTime <= budgets.maxRepRangeCalculationTime &&
               uiUpdateLatency <= budgets.maxUIUpdateLatency &&
               cacheHitRate >= budgets.minCacheHitRate &&
               memoryUsage <= budgets.maxMemoryUsage &&
               algorithmExecutionTime <= budgets.maxAlgorithmExecutionTime
    }
}

/// Performance budgets for different operations
struct PerformanceBudgets {
    let maxRepRangeCalculationTime: TimeInterval
    let maxUIUpdateLatency: TimeInterval
    let minCacheHitRate: Double
    let maxMemoryUsage: Int64
    let maxAlgorithmExecutionTime: TimeInterval
}

/// Performance alert types
enum PerformanceAlert: Identifiable {
    case algorithmPerformance(operation: String, actualTime: TimeInterval, maxTime: TimeInterval)
    case uiResponsiveness(operation: String, actualLatency: TimeInterval, maxLatency: TimeInterval)
    case cachePerformance(operation: String, actualHitRate: Double, minHitRate: Double)
    case memoryUsage(actualUsage: Int64, maxUsage: Int64)
    case memoryPressure
    
    var id: String {
        switch self {
        case .algorithmPerformance(let operation, _, _):
            return "algorithm_\(operation)"
        case .uiResponsiveness(let operation, _, _):
            return "ui_\(operation)"
        case .cachePerformance(let operation, _, _):
            return "cache_\(operation)"
        case .memoryUsage:
            return "memory_usage"
        case .memoryPressure:
            return "memory_pressure"
        }
    }
    
    var message: String {
        switch self {
        case .algorithmPerformance(let operation, let actual, let max):
            return "Algorithm '\(operation)' took \(String(format: "%.1f", actual * 1000))ms (max: \(String(format: "%.1f", max * 1000))ms)"
        case .uiResponsiveness(let operation, let actual, let max):
            return "UI operation '\(operation)' took \(String(format: "%.1f", actual * 1000))ms (max: \(String(format: "%.1f", max * 1000))ms)"
        case .cachePerformance(let operation, let actual, let min):
            return "Cache '\(operation)' hit rate \(String(format: "%.1f", actual * 100))% below minimum \(String(format: "%.1f", min * 100))%"
        case .memoryUsage(let actual, let max):
            return "Memory usage \(ByteCountFormatter.string(fromByteCount: actual, countStyle: .memory)) exceeds limit \(ByteCountFormatter.string(fromByteCount: max, countStyle: .memory))"
        case .memoryPressure:
            return "System memory pressure detected"
        }
    }
    
    var severity: AlertSeverity {
        switch self {
        case .algorithmPerformance(_, let actual, let max):
            return actual > max * 2.0 ? .critical : .warning
        case .uiResponsiveness(_, let actual, let max):
            return actual > max * 2.0 ? .critical : .warning
        case .cachePerformance(_, let actual, let min):
            return actual < min * 0.5 ? .critical : .warning
        case .memoryUsage(let actual, let max):
            return actual > max * 1.5 ? .critical : .warning
        case .memoryPressure:
            return .critical
        }
    }
    
    let timestamp = Date()
}

enum AlertSeverity {
    case info, warning, critical
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Monitoring Convenience Methods

extension PerformanceMonitoringService {
    
    /// Convenience method for timing rep range calculations
    func timeRepRangeCalculation<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        return try await timeOperation("repRangeCalculation", operation: operation)
    }
    
    /// Convenience method for timing UI updates
    func timeUIUpdate<T>(
        _ operation: () throws -> T
    ) rethrows -> T {
        return try timeOperation("UIUpdate", operation: operation)
    }
    
    /// Convenience method for timing algorithm execution
    func timeAlgorithmExecution<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        return try await timeOperation("algorithmExecution", operation: operation)
    }
}