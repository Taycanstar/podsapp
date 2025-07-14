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

@MainActor
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
    
    private init() {
        // Load last sync date from UserDefaults
        if let lastSync = UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date {
            lastSyncDate = lastSync
        }
    }
    
    // MARK: - Public Methods
    
    /// Sync Apple Health weight data with the server
    func syncAppleHealthWeights() async {
        // Prevent concurrent sync operations
        guard !syncInProgress else {
            print("⏸️ WeightSyncService: Sync already in progress, skipping duplicate request")
            return
        }
        
        syncInProgress = true
        defer { syncInProgress = false }
        
        print("🔍 WeightSyncService: Starting sync debug...")
        print("  - HealthKit available: \(healthKitManager.isHealthDataAvailable)")
        print("  - HealthKit authorized: \(healthKitManager.isAuthorized)")
        
        guard healthKitManager.isAuthorized && healthKitManager.isHealthDataAvailable else {
            print("⚠️ WeightSyncService: HealthKit not authorized or available")
            print("  - isAuthorized: \(healthKitManager.isAuthorized)")
            print("  - isHealthDataAvailable: \(healthKitManager.isHealthDataAvailable)")
            return
        }
        
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            print("⚠️ WeightSyncService: No user email found")
            return
        }
        
        print("🔄 WeightSyncService: Starting Apple Health weight sync for \(userEmail)")
        
        isSyncing = true
        syncError = nil
        
        do {
            // Determine sync start date (last sync or 30 days ago)
            // For first-time sync or when no weights have been synced, always look back 30 days
            let syncedIDs = getSyncedWeightIDs()
            let isFirstTimeSync = syncedIDs.isEmpty
            
            let syncStartDate: Date
            if isFirstTimeSync {
                // First time sync - always look back 30 days regardless of stored date
                syncStartDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                print("📅 WeightSyncService: First-time sync - looking back 30 days")
            } else {
                // Subsequent sync - use last sync date
                syncStartDate = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            }
            
            print("📅 WeightSyncService: Sync start date: \(syncStartDate)")
            print("📅 WeightSyncService: Last sync date: \(lastSyncDate?.description ?? "never")")
            print("📅 WeightSyncService: Is first-time sync: \(isFirstTimeSync) (synced IDs: \(syncedIDs.count))")
            
            // Fetch Apple Health weight entries
            let appleHealthWeights = try await fetchAppleHealthWeights(since: syncStartDate)
            print("📊 WeightSyncService: Found \(appleHealthWeights.count) Apple Health weight entries since \(syncStartDate)")
            
            // Debug: Print each Apple Health weight
            for (index, weight) in appleHealthWeights.enumerated() {
                print("  - Apple Health Weight \(index + 1): \(weight.weightKg)kg from \(weight.date) (source: \(weight.sourceApp))")
            }
            
            if appleHealthWeights.isEmpty {
                print("✅ WeightSyncService: No new Apple Health weight entries to sync")
                updateLastSyncDate()
                isSyncing = false
                return
            }
            
            // Get existing server weight logs to check for duplicates
            let serverWeights = try await fetchServerWeights(for: userEmail)
            print("📊 WeightSyncService: Found \(serverWeights.count) existing server weight logs")
            
            // Debug: Print recent server weights
            for (index, weight) in serverWeights.prefix(5).enumerated() {
                print("  - Server Weight \(index + 1): \(weight.weightKg)kg from \(weight.dateLogged)")
            }
            
            // Filter out weights that already exist on server
            let newWeights = filterNewWeights(appleHealthWeights: appleHealthWeights, serverWeights: serverWeights)
            print("📊 WeightSyncService: \(newWeights.count) new weight entries to sync after filtering")
            
            // Debug: Print weights that will be synced
            for (index, weight) in newWeights.enumerated() {
                print("  - Will sync Weight \(index + 1): \(weight.weightKg)kg from \(weight.date)")
            }
            
            if newWeights.isEmpty {
                print("✅ WeightSyncService: All Apple Health weights already synced")
                updateLastSyncDate()
                isSyncing = false
                return
            }
            
            // Mark weights as being processed to prevent concurrent operations from processing them
            let weightIDsToProcess = Set(newWeights.map { $0.id })
            processingWeightIDs.formUnion(weightIDsToProcess)
            defer { processingWeightIDs.subtract(weightIDsToProcess) }
            
            // Sync new weights to server
            var syncedCount = 0
            for weightEntry in newWeights {
                do {
                    try await syncWeightToServer(weightEntry: weightEntry, userEmail: userEmail)
                    syncedCount += 1
                    print("✅ WeightSyncService: Synced weight \(weightEntry.weightKg)kg from \(weightEntry.date)")
                } catch {
                    print("❌ WeightSyncService: Failed to sync weight from \(weightEntry.date): \(error)")
                }
            }
            
            print("✅ WeightSyncService: Successfully synced \(syncedCount)/\(newWeights.count) weight entries")
            
            // Update last sync date and post notification
            updateLastSyncDate()
            
            // Post notification to refresh UI
            NotificationCenter.default.post(name: Notification.Name("AppleHealthWeightSynced"), object: nil)
            
        } catch {
            print("❌ WeightSyncService: Sync failed: \(error)")
            syncError = error.localizedDescription
        }
        
        isSyncing = false
    }
    
    /// Check if there are new Apple Health weights available for sync
    func hasNewWeightsToSync() async -> Bool {
        // Don't check for new weights if a sync is already in progress
        guard !syncInProgress else {
            print("⏸️ WeightSyncService: Sync in progress, deferring hasNewWeightsToSync check")
            return false
        }
        
        print("🔍 WeightSyncService: Checking for new weights...")
        print("  - HealthKit available: \(healthKitManager.isHealthDataAvailable)")
        print("  - HealthKit authorized: \(healthKitManager.isAuthorized)")
        
        guard healthKitManager.isAuthorized && healthKitManager.isHealthDataAvailable else {
            print("❌ WeightSyncService: HealthKit not authorized or available for hasNewWeightsToSync")
            return false
        }
        
        do {
            let syncStartDate = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            print("📅 WeightSyncService: Checking for weights since: \(syncStartDate)")
            
            // Call the new, simple async function
            let weights = try await healthKitManager.fetchWeightEntriesSince(syncStartDate)
            
            print("⚖️ WeightSyncService: Found \(weights.count) new weights since last sync")
            return !weights.isEmpty
        } catch {
            print("❌ WeightSyncService: Error checking for new weights: \(error)")
            return false
        }
    }
    
    /// DEBUG: Force sync bypassing authorization checks (since we know data exists)
    func debugForceSyncAppleHealthWeights() async {
        print("🐛 DEBUG: FORCE SYNC - Bypassing authorization checks")
        
        // Prevent concurrent sync operations
        guard !syncInProgress else {
            print("⏸️ DEBUG: Sync already in progress, skipping duplicate request")
            return
        }
        
        syncInProgress = true
        defer { syncInProgress = false }
        
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            print("❌ No user email found")
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil // Clear previous errors
        }
        
        do {
            // Get weights from last 30 days regardless of authorization status
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            print("🐛 DEBUG: Fetching weights since \(thirtyDaysAgo)")
            
            // Use direct HealthKit query since we know it works
            let healthStore = HKHealthStore()
            guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                print("🐛 DEBUG: Cannot create body mass type")
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
            
            print("🐛 DEBUG: Found \(weights.count) weights to potentially sync")
            
                         // Filter out already synced weights
             let syncedIDs = Set(UserDefaults.standard.stringArray(forKey: "syncedAppleHealthWeightIDs") ?? [])
             let newWeights = weights.filter { !syncedIDs.contains($0.id) }
            
            print("🐛 DEBUG: \(newWeights.count) weights are new (not previously synced)")
            
            // Mark weights as being processed to prevent concurrent operations from processing them
            let weightIDsToProcess = Set(newWeights.map { $0.id })
            processingWeightIDs.formUnion(weightIDsToProcess)
            defer { processingWeightIDs.subtract(weightIDsToProcess) }
            
            var successCount = 0
            let totalWeights = newWeights.count
            
            for (index, weight) in newWeights.enumerated() {
                await MainActor.run {
                    // No syncProgress published in this class, so this line is removed
                }
                
                                 do {
                     try await syncWeightToServer(weightEntry: weight, userEmail: userEmail)
                     markWeightAsSynced(weight.id)
                     successCount += 1
                     print("✅ Synced weight: \(weight.weightKg)kg from \(weight.date)")
                 } catch {
                     print("❌ Failed to sync weight from \(weight.date): \(error)")
                 }
            }
            
            await MainActor.run {
                isSyncing = false
                updateLastSyncDate()
            }
            
            print("🎉 DEBUG SYNC COMPLETE: \(successCount)/\(totalWeights) weights synced")
            
            // Post notification
            NotificationCenter.default.post(name: Notification.Name("AppleHealthWeightSynced"), object: nil)
            
        } catch {
            await MainActor.run {
                isSyncing = false
                syncError = error.localizedDescription
            }
            print("❌ DEBUG Force sync failed: \(error)")
        }
    }
    
    /// Check for new weights to sync bypassing authorization checks
    /// This method is used when we know HealthKit data is available but authorization status is unreliable
    func debugHasNewWeightsToSync() async -> Bool {
        print("🐛 DEBUG: Checking for new weights (bypassing authorization checks)")
        
        // Check if HealthKit is available on device
        guard HKHealthStore.isHealthDataAvailable() else {
            print("🐛 DEBUG: HealthKit not available on device")
            return false
        }
        
        do {
            // Get weights from last 30 days regardless of authorization status
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            print("🐛 DEBUG: Checking for weights since \(thirtyDaysAgo)")
            
            // Use direct HealthKit query since we know it works
            let healthStore = HKHealthStore()
            guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                print("🐛 DEBUG: Cannot create body mass type")
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
            
            print("🐛 DEBUG: Found \(weights.count) weights in Apple Health")
            
            // Filter out already synced weights
            let syncedIDs = Set(UserDefaults.standard.stringArray(forKey: "syncedAppleHealthWeightIDs") ?? [])
            let newWeights = weights.filter { !syncedIDs.contains($0.id) }
            
            print("🐛 DEBUG: \(newWeights.count) weights are new (not previously synced)")
            return !newWeights.isEmpty
            
        } catch {
            print("🐛 DEBUG: Error checking for new weights: \(error)")
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
                print("⚠️ Skipping unrealistic weight: \(weightKg)kg")
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
        let syncedIDs = Set(UserDefaults.standard.stringArray(forKey: syncedWeightIDsKey) ?? [])
        
        return appleHealthWeights.filter { appleWeight in
            // Skip if we've already synced this specific Apple Health entry
            if syncedIDs.contains(appleWeight.id) {
                print("⏭️ Skipping already synced weight ID: \(appleWeight.id)")
                return false
            }
            
            // Skip if this weight is currently being processed by another sync operation
            if processingWeightIDs.contains(appleWeight.id) {
                print("⏭️ Skipping weight currently being processed: \(appleWeight.id)")
                return false
            }
            
            // Round Apple Health weight timestamp to nearest minute
            let roundedAppleDate = Calendar.current.date(bySetting: .second, value: 0, of: appleWeight.date) ?? appleWeight.date
            let appleTimestamp = ISO8601DateFormatter().string(from: roundedAppleDate)
            
            // Skip if a weight with the same timestamp already exists on server
            if serverWeightTimestamps.contains(appleTimestamp) {
                print("⏭️ Skipping duplicate weight from \(appleWeight.date) (already on server)")
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
                        print("⏭️ Skipping similar weight: Apple Health \(appleWeight.weightKg)kg vs Server \(serverWeight.weightKg)kg")
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
                    continuation.resume(throwing: error)
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
}

// MARK: - Data Models

struct AppleHealthWeight {
    let id: String
    let weightKg: Double
    let date: Date
    let sourceApp: String
} 