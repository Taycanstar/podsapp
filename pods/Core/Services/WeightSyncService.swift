//
//  WeightSyncService.swift
//  pods
//
//  Created by Dimi Nunez on 7/12/25.
//

//
//  WeightSyncService.swift
//  Pods
//
//  Created by AI Assistant on Weight Sync Implementation
//

import Foundation
import HealthKit
import SwiftUI

// FIXED: Removed @MainActor to prevent blocking UI on app foreground
// @Published properties automatically update on MainActor, so UI updates still work correctly
// But async network operations in syncAppleHealthWeights() now run on background thread
class WeightSyncService: ObservableObject {
    static let shared = WeightSyncService()

    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var lastSyncDate: Date?
    
    private let healthKitManager = HealthKitManager.shared
    private let networkManager = NetworkManagerTwo.shared
    
    // UserDefaults keys for tracking sync state
    private let lastSyncDateKey = "lastAppleHealthWeightSync"
    private let syncedWeightIDsKey = "syncedAppleHealthWeightIDs"

    // Add sync operation protection
    private var syncInProgress = false
    private var processingWeightIDs: Set<String> = []

    // CRITICAL FIX: Throttle resume-triggered syncs
    private var lastSyncAttemptTime: Date?
    private let minimumSyncInterval: TimeInterval = 60 // 1 minute between syncs
    
    private init() {
        // Load last sync date from UserDefaults
        if let lastSync = UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date {
            lastSyncDate = lastSync
        }
    }
    
    // MARK: - Public Methods

    /// Clear sync state to force re-sync of all weights (for debugging)
    func clearSyncState() {
        UserDefaults.standard.removeObject(forKey: syncedWeightIDsKey)
        UserDefaults.standard.removeObject(forKey: lastSyncDateKey)
        lastSyncDate = nil
    }

    /// Sync Apple Health weight data with the server
    func syncAppleHealthWeights() async {
        // CRITICAL FIX: Skip if workout is active to avoid interfering with workout logging
        let hasActiveWorkout = await MainActor.run {
            WorkoutManager.shared.currentWorkout != nil
        }
        if hasActiveWorkout {
            return
        }

        // CRITICAL FIX: Throttle rapid resume-triggered syncs
        if let last = lastSyncAttemptTime, Date().timeIntervalSince(last) < minimumSyncInterval {
            return
        }

        lastSyncAttemptTime = Date()

        // Prevent concurrent sync operations
        guard !syncInProgress else {
            return
        }

        syncInProgress = true
        defer { syncInProgress = false }

        guard healthKitManager.isHealthDataAvailable else {
            return
        }

        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            return
        }

        await MainActor.run {
            isSyncing = true
            syncError = nil
        }

        do {
            // FIXED: Always check last 7 days to ensure we don't miss any weights
            // The previous logic with lastSyncDate was causing weights to be missed
            let syncStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

            // Fetch Apple Health weight entries
            let appleHealthWeights = try await fetchAppleHealthWeights(since: syncStartDate)

            if appleHealthWeights.isEmpty {
                await MainActor.run {
                    updateLastSyncDate()
                    isSyncing = false
                }
                return
            }

            // Get existing server weight logs to check for duplicates
            let serverWeights: [WeightLogResponse]
            do {
                serverWeights = try await fetchServerWeights(for: userEmail)
            } catch {
                throw error
            }

            // Filter out weights that already exist on server
            let newWeights = filterNewWeights(appleHealthWeights: appleHealthWeights, serverWeights: serverWeights)

            if newWeights.isEmpty {
                await MainActor.run {
                    updateLastSyncDate()
                    isSyncing = false
                }
                return
            }

            // Mark weights as being processed to prevent concurrent operations from processing them
            let weightIDsToProcess = Set(newWeights.map { $0.id })
            processingWeightIDs.formUnion(weightIDsToProcess)
            defer { processingWeightIDs.subtract(weightIDsToProcess) }

            // Sync new weights to server
            for weightEntry in newWeights {
                do {
                    try await syncWeightToServer(weightEntry: weightEntry, userEmail: userEmail)
                } catch {
                    // Continue with other weights even if one fails
                }
            }

            // Update last sync date and post notification
            await MainActor.run {
                updateLastSyncDate()
                // Post notification to refresh UI
                NotificationCenter.default.post(name: Notification.Name("AppleHealthWeightSynced"), object: nil)
            }

        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
            }
        }

        await MainActor.run {
            isSyncing = false
        }
    }
    
    /// Check if there are new Apple Health weights available for sync
    func hasNewWeightsToSync() async -> Bool {
        // Don't check for new weights if a sync is already in progress
        guard !syncInProgress else {
            return false
        }

        guard healthKitManager.isHealthDataAvailable else {
            return false
        }

        do {
            // FIXED: Check last 7 days to match syncAppleHealthWeights() window
            // This prevents the mismatch where hasNewWeights returns false but sync would find weights
            let syncStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

            // Call the new, simple async function
            let weights = try await healthKitManager.fetchWeightEntriesSince(syncStartDate)

            return !weights.isEmpty
        } catch {
            return false
        }
    }
    
    /// DEBUG: Force sync bypassing authorization checks (since we know data exists)
    func debugForceSyncAppleHealthWeights() async {
        // Prevent concurrent sync operations
        guard !syncInProgress else {
            return
        }

        syncInProgress = true
        defer { syncInProgress = false }

        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            return
        }

        await MainActor.run {
            isSyncing = true
            syncError = nil // Clear previous errors
        }

        do {
            // Get weights from last 30 days regardless of authorization status
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

            // Use direct HealthKit query since we know it works
            let healthStore = HKHealthStore()
            guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                return
            }

            // Use explicit typing to avoid inference issues
            let weights: [AppleHealthWeight] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[AppleHealthWeight], Error>) in
                let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: Date(), options: .strictStartDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

                let query = HKSampleQuery(
                    sampleType: bodyMassType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { query, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let weightSamples = (samples as? [HKQuantitySample]) ?? []
                    let appleHealthWeights = weightSamples.map { sample in
                        AppleHealthWeight(
                            id: sample.uuid.uuidString,
                            weightKg: sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)),
                            date: sample.startDate,
                            sourceApp: sample.sourceRevision.source.name
                        )
                    }
                    continuation.resume(returning: appleHealthWeights)
                }

                healthStore.execute(query)
            }

            // Filter out already synced weights
            let syncedIDs = Set(UserDefaults.standard.stringArray(forKey: "syncedAppleHealthWeightIDs") ?? [])
            let newWeights = weights.filter { !syncedIDs.contains($0.id) }

            // Mark weights as being processed to prevent concurrent operations from processing them
            let weightIDsToProcess = Set(newWeights.map { $0.id })
            processingWeightIDs.formUnion(weightIDsToProcess)
            defer { processingWeightIDs.subtract(weightIDsToProcess) }

            for weight in newWeights {
                await MainActor.run {
                    // No syncProgress published in this class, so this line is removed
                }

                do {
                    try await syncWeightToServer(weightEntry: weight, userEmail: userEmail)
                    markWeightAsSynced(weight.id)
                } catch {
                    // Continue with other weights even if one fails
                }
            }

            await MainActor.run {
                isSyncing = false
                updateLastSyncDate()
            }

            // Post notification
            NotificationCenter.default.post(name: Notification.Name("AppleHealthWeightSynced"), object: nil)

        } catch {
            await MainActor.run {
                isSyncing = false
                syncError = error.localizedDescription
            }
        }
    }
    
    /// Check for new weights to sync bypassing authorization checks
    /// This method is used when we know HealthKit data is available but authorization status is unreliable
    func debugHasNewWeightsToSync() async -> Bool {
        // Check if HealthKit is available on device
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }

        do {
            // Get weights from last 30 days regardless of authorization status
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

            // Use direct HealthKit query since we know it works
            let healthStore = HKHealthStore()
            guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                return false
            }

            // Use explicit typing to avoid inference issues
            let weights: [AppleHealthWeight] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[AppleHealthWeight], Error>) in
                let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: Date(), options: .strictStartDate)
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

                let query = HKSampleQuery(
                    sampleType: bodyMassType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { query, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let weightSamples = (samples as? [HKQuantitySample]) ?? []
                    let appleHealthWeights = weightSamples.map { sample in
                        AppleHealthWeight(
                            id: sample.uuid.uuidString,
                            weightKg: sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)),
                            date: sample.startDate,
                            sourceApp: sample.sourceRevision.source.name
                        )
                    }
                    continuation.resume(returning: appleHealthWeights)
                }

                healthStore.execute(query)
            }

            // Filter out already synced weights
            let syncedIDs = Set(UserDefaults.standard.stringArray(forKey: "syncedAppleHealthWeightIDs") ?? [])
            let newWeights = weights.filter { !syncedIDs.contains($0.id) }

            return !newWeights.isEmpty

        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchAppleHealthWeights(since date: Date) async throws -> [AppleHealthWeight] {
        // Call the new, simple async function
        let samples = try await healthKitManager.fetchWeightEntriesSince(date)

        let weights = samples.compactMap { sample -> AppleHealthWeight? in
            let weightKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))

            // Skip weights that seem unrealistic (< 20kg or > 300kg)
            guard weightKg >= 20 && weightKg <= 300 else {
                return nil
            }

            return AppleHealthWeight(
                id: sample.uuid.uuidString,
                weightKg: weightKg,
                date: sample.endDate,
                sourceApp: sample.sourceRevision.source.name
            )
        }
        return weights
    }
    
    private func fetchServerWeights(for userEmail: String) async throws -> [WeightLogResponse] {
        return try await withCheckedThrowingContinuation { continuation in
            // Fetch a reasonable number of recent server weights to check for duplicates
            networkManager.fetchWeightLogs(userEmail: userEmail, limit: 100, offset: 0) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.logs)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func filterNewWeights(appleHealthWeights: [AppleHealthWeight], serverWeights: [WeightLogResponse]) -> [AppleHealthWeight] {
        let dateFormatter = ISO8601DateFormatter()

        // Create a set of server weight timestamps for quick lookup
        let serverWeightTimestamps = Set(serverWeights.compactMap { serverWeight -> String? in
            guard let serverDate = dateFormatter.date(from: serverWeight.dateLogged) else {
                return nil
            }
            // Round to nearest minute to account for small timing differences
            let roundedDate = Calendar.current.date(bySetting: .second, value: 0, of: serverDate) ?? serverDate
            return ISO8601DateFormatter().string(from: roundedDate)
        })

        // Get synced weight IDs from UserDefaults
        var syncedIDs = Set(UserDefaults.standard.stringArray(forKey: syncedWeightIDsKey) ?? [])

        // CLEANUP: Remove any "synced" IDs that don't actually exist on the server
        // This fixes cases where sync marked weights as synced but they never made it to the server
        var cleanedSyncedIDs = syncedIDs
        for appleWeight in appleHealthWeights {
            if syncedIDs.contains(appleWeight.id) {
                // Check if this weight actually exists on server
                let roundedAppleDate = Calendar.current.date(bySetting: .second, value: 0, of: appleWeight.date) ?? appleWeight.date
                let appleTimestamp = ISO8601DateFormatter().string(from: roundedAppleDate)

                // If it's marked as synced but NOT on server, remove it from synced IDs
                if !serverWeightTimestamps.contains(appleTimestamp) {
                    cleanedSyncedIDs.remove(appleWeight.id)
                }
            }
        }

        // Update UserDefaults with cleaned IDs
        if cleanedSyncedIDs.count != syncedIDs.count {
            UserDefaults.standard.set(Array(cleanedSyncedIDs), forKey: syncedWeightIDsKey)
        }
        syncedIDs = cleanedSyncedIDs
        
        return appleHealthWeights.filter { appleWeight in
            // Skip if we've already synced this specific Apple Health entry
            if syncedIDs.contains(appleWeight.id) {
      
                return false
            }
            
            // Skip if this weight is currently being processed by another sync operation
            if processingWeightIDs.contains(appleWeight.id) {
              
                return false
            }
            
            // Round Apple Health weight timestamp to nearest minute
            let roundedAppleDate = Calendar.current.date(bySetting: .second, value: 0, of: appleWeight.date) ?? appleWeight.date
            let appleTimestamp = ISO8601DateFormatter().string(from: roundedAppleDate)
            
            // Skip if a weight with the same timestamp already exists on server
            if serverWeightTimestamps.contains(appleTimestamp) {
               
                return false
            }
            
            // Check for weights within 10 minutes and similar weight (±0.5kg)
            let tenMinutesBefore = Calendar.current.date(byAdding: .minute, value: -10, to: appleWeight.date) ?? appleWeight.date
            let tenMinutesAfter = Calendar.current.date(byAdding: .minute, value: 10, to: appleWeight.date) ?? appleWeight.date
            
            for serverWeight in serverWeights {
                guard let serverDate = dateFormatter.date(from: serverWeight.dateLogged) else { continue }
                
                if serverDate >= tenMinutesBefore && serverDate <= tenMinutesAfter {
                    let weightDifference = abs(appleWeight.weightKg - serverWeight.weightKg)
                    if weightDifference <= 0.5 { // Within 0.5kg
    
                        return false
                    }
                }
            }
            
            return true
        }
    }
    
    private func syncWeightToServer(weightEntry: AppleHealthWeight, userEmail: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            networkManager.logWeightWithAppleHealthUUID(
                userEmail: userEmail,
                weightKg: weightEntry.weightKg,
                notes: "Synced from Apple Health (\(weightEntry.sourceApp))",
                date: weightEntry.date,
                appleHealthUUID: weightEntry.id
            ) { result in
                switch result {
                case .success(let response):
                    // Mark this Apple Health entry as synced
                    self.markWeightAsSynced(weightEntry.id)
                    continuation.resume()
                case .failure(let error):
                    // CRITICAL FIX: Treat duplicate key errors as success
                    // This prevents infinite retry loops when server already has the weight
                    let errorMessage = error.localizedDescription
                    if errorMessage.contains("duplicate key value") ||
                       errorMessage.contains("apple_health_uuid") {
                        self.markWeightAsSynced(weightEntry.id)
                        continuation.resume() // Success, not error
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func getSyncedWeightIDs() -> Set<String> {
        let syncedIDs = UserDefaults.standard.stringArray(forKey: syncedWeightIDsKey) ?? []
        return Set(syncedIDs)
    }
    
    private func markWeightAsSynced(_ weightID: String) {
        var syncedIDs = UserDefaults.standard.stringArray(forKey: syncedWeightIDsKey) ?? []
        if !syncedIDs.contains(weightID) {
            syncedIDs.append(weightID)
            UserDefaults.standard.set(syncedIDs, forKey: syncedWeightIDsKey)
        }
    }
    
    private func updateLastSyncDate() {
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: lastSyncDateKey)
    }
    
    // MARK: - Debug Methods

    /// Reset sync state for debugging (clears last sync date and synced IDs)
    func resetSyncState() {
        lastSyncDate = nil
        UserDefaults.standard.removeObject(forKey: lastSyncDateKey)
        UserDefaults.standard.removeObject(forKey: syncedWeightIDsKey)
    }
}

// MARK: - Data Models

struct AppleHealthWeight {
    let id: String
    let weightKg: Double
    let date: Date
    let sourceApp: String
} 