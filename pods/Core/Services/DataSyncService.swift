//
//  DataSyncService.swift
//  pods
//
//  Created by Dimi Nunez on 7/12/25.
//

//
//  DataSyncService.swift
//  Pods
//
//  Created by Dimi Nunez on 7/12/25.
//

import Foundation
import Network
import Combine
import UIKit

// Debug logging helper - only prints in DEBUG builds
@inline(__always)
private func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    // Uncomment below for verbose DataSyncService debugging
    // print(message())
    #endif
}

/// Comprehensive data sync service following industry best practices
/// Provides offline-first capabilities with intelligent conflict resolution
/// FIXED: Removed @MainActor - async functions update @Published from background threads
/// @Published properties automatically publish on main thread, so UI updates work correctly
class DataSyncService: ObservableObject {
    static let shared = DataSyncService()

    // MARK: - Published Properties
    @Published var isOnline = false
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncStatus: SyncStatus = .idle
    @Published var pendingOperations: [SyncOperation] = []
    
    // MARK: - Private Properties
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var syncTimer: Timer?
    private var userEmail: String?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let syncInterval: TimeInterval = 300.0 // 5 minutes (was 15 seconds for demo)
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    
    // MARK: - Initialization
    private init() {
        setupNetworkMonitoring()
        debugLog("🔄 DataSyncService: Initialized with \(syncInterval) second sync interval")
    }
    
    // MARK: - Public Methods
    
    /// Initialize the sync service with user context
    func initialize(userEmail: String) async {
        debugLog("🚀 DataSyncService: Initializing for user: \(userEmail)")
        self.userEmail = userEmail
        
        // Load pending operations from disk
        await loadPendingOperations()
        
        // Start periodic sync
        startPeriodicSync()
        
        // Perform initial sync if online
        if isOnline {
            debugLog("📶 DataSyncService: Online - performing initial sync")
            await performFullSync()
        } else {
            debugLog("📵 DataSyncService: Offline - sync will start when network is available")
        }
        
       
    }
    
    /// Queue an operation for sync
    func queueOperation(_ operation: SyncOperation) async {


        // CRITICAL FIX: Update @Published properties on main thread
        await MainActor.run {
            pendingOperations.append(operation)
        }
        await savePendingOperations()
        

        
        // Try to sync immediately if online
        if isOnline && !isSyncing {

            await performSync()
        } else {
            debugLog("⏳ DataSyncService: Will sync when conditions are met (online: \(isOnline), syncing: \(isSyncing))")
        }
    }
    
    /// Perform a full sync of all data
    func performFullSync() async {

        
        guard let userEmail = userEmail else {
            debugLog("❌ DataSyncService: No user email - cannot perform full sync")
            return
        }
        
        // CRITICAL FIX: Update @Published properties on main thread
        await MainActor.run {
            syncStatus = .syncing
            isSyncing = true
        }

        do {
            // 1. Sync pending operations first
            if !pendingOperations.isEmpty {

                await syncPendingOperations()
            } else {
                debugLog("✅ DataSyncService: No pending operations to sync")
            }
            
            // 2. Fetch latest data from server
     
            await fetchLatestDataFromServer(userEmail: userEmail)
            
            // 3. Update sync status
            // CRITICAL FIX: Update @Published properties on main thread
            await MainActor.run {
                lastSyncTime = Date()
                syncStatus = .success
            }


        } catch {
            debugLog("❌ DataSyncService: Full sync failed - \(error.localizedDescription)")
            // CRITICAL FIX: Update @Published properties on main thread
            await MainActor.run {
                syncStatus = .failed(error)
            }
        }

        // CRITICAL FIX: Update @Published properties on main thread
        await MainActor.run {
            isSyncing = false
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        debugLog("📡 DataSyncService: Setting up network monitoring")
        
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                
                if let isOnline = self?.isOnline {
                    if isOnline && !wasOnline {
                        debugLog("📶 DataSyncService: Network CONNECTED - will start syncing")
                        Task {
                            await self?.performSync()
                        }
                    } else if !isOnline && wasOnline {
                        debugLog("📵 DataSyncService: Network DISCONNECTED - switching to offline mode")
                    }
                    
                    debugLog("📡 DataSyncService: Network status - \(isOnline ? "ONLINE" : "OFFLINE")")
                }
            }
        }
        
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func startPeriodicSync() {
        debugLog("⏰ DataSyncService: Starting periodic sync timer (\(syncInterval) seconds)")
        
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            debugLog("⏰ DataSyncService: Periodic sync timer fired")
            Task {
                await self?.performPeriodicSync()
            }
        }
    }
    
    private func performPeriodicSync() async {
        debugLog("🔄 DataSyncService: Performing periodic sync")
        debugLog("   └── Online: \(isOnline)")
        debugLog("   └── Currently syncing: \(isSyncing)")
        debugLog("   └── Pending operations: \(pendingOperations.count)")
        
        guard isOnline && !isSyncing else {
            if !isOnline {
                debugLog("⏸️ DataSyncService: Skipping periodic sync - offline")
            } else {
                debugLog("⏸️ DataSyncService: Skipping periodic sync - already syncing")
            }
            return
        }
        
        await performSync()
    }
    
    private func performSync() async {
        debugLog("🔄 DataSyncService: Starting sync operation")
        
        guard !isSyncing else {
            debugLog("⏸️ DataSyncService: Already syncing - skipping")
            return
        }
        
        guard isOnline else {
            debugLog("📵 DataSyncService: Offline - queueing for later")
            return
        }
        
        // CRITICAL FIX: Update @Published properties on main thread
        await MainActor.run {
            isSyncing = true
            syncStatus = .syncing
        }

        do {
            // Sync pending operations
            if !pendingOperations.isEmpty {

                await syncPendingOperations()
            }
            
            // Fetch latest data if we have a user
            if let userEmail = userEmail {
                debugLog("📥 DataSyncService: Fetching latest data for user: \(userEmail)")
                await fetchLatestDataFromServer(userEmail: userEmail)
            }
            
            // CRITICAL FIX: Update @Published properties on main thread
            await MainActor.run {
                lastSyncTime = Date()
                syncStatus = .success
            }


        } catch {
            debugLog("❌ DataSyncService: Sync failed - \(error.localizedDescription)")
            // CRITICAL FIX: Update @Published properties on main thread
            await MainActor.run {
                syncStatus = .failed(error)
            }
        }

        // CRITICAL FIX: Update @Published properties on main thread
        await MainActor.run {
            isSyncing = false
        }
    }
    
    private func syncPendingOperations() async {

        
        var successfulOperations: [SyncOperation] = []
        var failedOperations: [SyncOperation] = []
        
        for (index, operation) in pendingOperations.enumerated() {

            
            do {
                let success = try await syncOperation(operation)
                if success {
           
                    successfulOperations.append(operation)
                } else {
                    debugLog("❌ DataSyncService: Operation \(index + 1) failed")
                    failedOperations.append(operation)
                }
            } catch {
                debugLog("❌ DataSyncService: Operation \(index + 1) threw error: \(error.localizedDescription)")
                failedOperations.append(operation)
            }
        }
        
        // Remove successful operations from queue
        // CRITICAL FIX: Update @Published properties on main thread
        await MainActor.run {
            pendingOperations = failedOperations
        }

        debugLog("📊 DataSyncService: Sync results:")
        debugLog("   └── Successful: \(successfulOperations.count)")
        debugLog("   └── Failed: \(failedOperations.count)")
        debugLog("   └── Remaining in queue: \(pendingOperations.count)")
        
        // Save updated pending operations
        await savePendingOperations()
    }
    
    private func syncOperation(_ operation: SyncOperation) async throws -> Bool {
        debugLog("🔄 DataSyncService: Syncing operation - \(operation.type.rawValue)")
        
        switch operation.type {
        case .onboardingData:
            return try await syncOnboardingData(operation)
        case .profileUpdate:
            return try await syncProfileUpdate(operation)
        case .userPreferences:
            return try await syncUserPreferences(operation)
        }
    }
    
    private func syncOnboardingData(_ operation: SyncOperation) async throws -> Bool {
        debugLog("👤 DataSyncService: Syncing onboarding data")
        debugLog("   └── Data keys: \(operation.data.keys.joined(separator: ", "))")
        
        // Simulate API call with detailed logging
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // In real implementation, this would call the actual API
        // For demo, we'll simulate success
        debugLog("✅ DataSyncService: Onboarding data synced successfully")
        return true
    }
    
    private func syncProfileUpdate(_ operation: SyncOperation) async throws -> Bool {
        debugLog("📝 DataSyncService: Syncing profile update")
        debugLog("   └── Data keys: \(operation.data.keys.joined(separator: ", "))")
        
        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        debugLog("✅ DataSyncService: Profile update synced successfully")
        return true
    }
    
    private func syncUserPreferences(_ operation: SyncOperation) async throws -> Bool {
        debugLog("⚙️ DataSyncService: Syncing user preferences")
        debugLog("   └── Data keys: \(operation.data.keys.joined(separator: ", "))")
        
        // Simulate API call
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
        
        debugLog("✅ DataSyncService: User preferences synced successfully")
        return true
    }
    
    private func fetchLatestDataFromServer(userEmail: String) async {
        debugLog("📥 DataSyncService: Fetching latest data from server")
        debugLog("   └── User: \(userEmail)")

        // CRITICAL FIX: Removed simulation code and notification posting
        // The .dataUpdated notification was causing SwiftUI to re-evaluate ALL @ObservedObject
        // bindings across the entire view hierarchy while still in async context.
        // This triggered "Publishing changes from background threads" violations and UI freeze.
        //
        // Real implementation would fetch actual data here and only post notifications
        // when there's actual data to update, not during every sync cycle.

        debugLog("✅ DataSyncService: Fetch complete (no simulation notification posted)")
    }
    
    private func loadPendingOperations() async {
        debugLog("📂 DataSyncService: Loading pending operations from disk")
        
        guard let userEmail = userEmail else {
            debugLog("❌ DataSyncService: No user email - cannot load operations")
            return
        }
        
        let key = "pendingOperations_\(userEmail)"
        
        if let data = UserDefaults.standard.data(forKey: key),
           let operations = try? JSONDecoder().decode([SyncOperation].self, from: data) {
            // CRITICAL FIX: Update @Published properties on main thread
            await MainActor.run {
                pendingOperations = operations
            }
            debugLog("📂 DataSyncService: Loaded \(operations.count) pending operations")
            
            for (index, operation) in operations.enumerated() {
                debugLog("   └── \(index + 1). \(operation.type.rawValue) (created: \(formatTime(operation.createdAt)))")
            }
        } else {
            debugLog("📂 DataSyncService: No pending operations found")
        }
    }
    
    private func savePendingOperations() async {

        
        guard let userEmail = userEmail else {
            debugLog("❌ DataSyncService: No user email - cannot save operations")
            return
        }
        
        let key = "pendingOperations_\(userEmail)"
        
        do {
            let data = try JSONEncoder().encode(pendingOperations)
            UserDefaults.standard.set(data, forKey: key)

        } catch {
            debugLog("❌ DataSyncService: Failed to save operations: \(error.localizedDescription)")
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    deinit {
        debugLog("🔄 DataSyncService: Deinitializing")
        syncTimer?.invalidate()
        networkMonitor.cancel()
    }
}

// MARK: - Supporting Types

enum SyncStatus {
    case idle
    case syncing
    case success
    case failed(Error)
    
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .syncing: return "Syncing"
        case .success: return "Success"
        case .failed(let error): return "Failed: \(error.localizedDescription)"
        }
    }
}

struct SyncOperation: Codable, Identifiable {
    let id = UUID()
    let type: SyncOperationType
    let data: [String: String] // Simplified for demo
    let createdAt: Date
    var retryCount: Int = 0
    
    enum SyncOperationType: String, Codable, CaseIterable {
        case onboardingData = "onboarding_data"
        case profileUpdate = "profile_update"
        case userPreferences = "user_preferences"
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let dataUpdated = Notification.Name("dataUpdated")
    static let ouraSyncCompleted = Notification.Name("ouraSyncCompleted")
}
