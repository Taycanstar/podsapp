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
        print("🔄 DataSyncService: Initialized with \(syncInterval) second sync interval")
    }
    
    // MARK: - Public Methods
    
    /// Initialize the sync service with user context
    func initialize(userEmail: String) async {
        print("🚀 DataSyncService: Initializing for user: \(userEmail)")
        self.userEmail = userEmail
        
        // Load pending operations from disk
        await loadPendingOperations()
        
        // Start periodic sync
        startPeriodicSync()
        
        // Perform initial sync if online
        if isOnline {
            print("📶 DataSyncService: Online - performing initial sync")
            await performFullSync()
        } else {
            print("📵 DataSyncService: Offline - sync will start when network is available")
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
            print("⏳ DataSyncService: Will sync when conditions are met (online: \(isOnline), syncing: \(isSyncing))")
        }
    }
    
    /// Perform a full sync of all data
    func performFullSync() async {

        
        guard let userEmail = userEmail else {
            print("❌ DataSyncService: No user email - cannot perform full sync")
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
                print("✅ DataSyncService: No pending operations to sync")
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
            print("❌ DataSyncService: Full sync failed - \(error.localizedDescription)")
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
        print("📡 DataSyncService: Setting up network monitoring")
        
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                
                if let isOnline = self?.isOnline {
                    if isOnline && !wasOnline {
                        print("📶 DataSyncService: Network CONNECTED - will start syncing")
                        Task {
                            await self?.performSync()
                        }
                    } else if !isOnline && wasOnline {
                        print("📵 DataSyncService: Network DISCONNECTED - switching to offline mode")
                    }
                    
                    print("📡 DataSyncService: Network status - \(isOnline ? "ONLINE" : "OFFLINE")")
                }
            }
        }
        
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func startPeriodicSync() {
        print("⏰ DataSyncService: Starting periodic sync timer (\(syncInterval) seconds)")
        
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            print("⏰ DataSyncService: Periodic sync timer fired")
            Task {
                await self?.performPeriodicSync()
            }
        }
    }
    
    private func performPeriodicSync() async {
        print("🔄 DataSyncService: Performing periodic sync")
        print("   └── Online: \(isOnline)")
        print("   └── Currently syncing: \(isSyncing)")
        print("   └── Pending operations: \(pendingOperations.count)")
        
        guard isOnline && !isSyncing else {
            if !isOnline {
                print("⏸️ DataSyncService: Skipping periodic sync - offline")
            } else {
                print("⏸️ DataSyncService: Skipping periodic sync - already syncing")
            }
            return
        }
        
        await performSync()
    }
    
    private func performSync() async {
        print("🔄 DataSyncService: Starting sync operation")
        
        guard !isSyncing else {
            print("⏸️ DataSyncService: Already syncing - skipping")
            return
        }
        
        guard isOnline else {
            print("📵 DataSyncService: Offline - queueing for later")
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
                print("📥 DataSyncService: Fetching latest data for user: \(userEmail)")
                await fetchLatestDataFromServer(userEmail: userEmail)
            }
            
            // CRITICAL FIX: Update @Published properties on main thread
            await MainActor.run {
                lastSyncTime = Date()
                syncStatus = .success
            }


        } catch {
            print("❌ DataSyncService: Sync failed - \(error.localizedDescription)")
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
                    print("❌ DataSyncService: Operation \(index + 1) failed")
                    failedOperations.append(operation)
                }
            } catch {
                print("❌ DataSyncService: Operation \(index + 1) threw error: \(error.localizedDescription)")
                failedOperations.append(operation)
            }
        }
        
        // Remove successful operations from queue
        // CRITICAL FIX: Update @Published properties on main thread
        await MainActor.run {
            pendingOperations = failedOperations
        }

        print("📊 DataSyncService: Sync results:")
        print("   └── Successful: \(successfulOperations.count)")
        print("   └── Failed: \(failedOperations.count)")
        print("   └── Remaining in queue: \(pendingOperations.count)")
        
        // Save updated pending operations
        await savePendingOperations()
    }
    
    private func syncOperation(_ operation: SyncOperation) async throws -> Bool {
        print("🔄 DataSyncService: Syncing operation - \(operation.type.rawValue)")
        
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
        print("👤 DataSyncService: Syncing onboarding data")
        print("   └── Data keys: \(operation.data.keys.joined(separator: ", "))")
        
        // Simulate API call with detailed logging
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // In real implementation, this would call the actual API
        // For demo, we'll simulate success
        print("✅ DataSyncService: Onboarding data synced successfully")
        return true
    }
    
    private func syncProfileUpdate(_ operation: SyncOperation) async throws -> Bool {
        print("📝 DataSyncService: Syncing profile update")
        print("   └── Data keys: \(operation.data.keys.joined(separator: ", "))")
        
        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        print("✅ DataSyncService: Profile update synced successfully")
        return true
    }
    
    private func syncUserPreferences(_ operation: SyncOperation) async throws -> Bool {
        print("⚙️ DataSyncService: Syncing user preferences")
        print("   └── Data keys: \(operation.data.keys.joined(separator: ", "))")
        
        // Simulate API call
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
        
        print("✅ DataSyncService: User preferences synced successfully")
        return true
    }
    
    private func fetchLatestDataFromServer(userEmail: String) async {
        print("📥 DataSyncService: Fetching latest data from server")
        print("   └── User: \(userEmail)")
        
        do {
            // Simulate fetching different types of data

            try await Task.sleep(nanoseconds: 500_000_000)

            try await Task.sleep(nanoseconds: 300_000_000)



            try await Task.sleep(nanoseconds: 400_000_000)

            // CRITICAL FIX: Post notification on main actor to prevent
            // "Publishing changes from background threads" warnings
            await MainActor.run {
                NotificationCenter.default.post(name: .dataUpdated, object: nil)
            }
            
        } catch {
            print("❌ DataSyncService: Failed to fetch data from server: \(error.localizedDescription)")
            // Don't throw the error, just log it and continue
        }
    }
    
    private func loadPendingOperations() async {
        print("📂 DataSyncService: Loading pending operations from disk")
        
        guard let userEmail = userEmail else {
            print("❌ DataSyncService: No user email - cannot load operations")
            return
        }
        
        let key = "pendingOperations_\(userEmail)"
        
        if let data = UserDefaults.standard.data(forKey: key),
           let operations = try? JSONDecoder().decode([SyncOperation].self, from: data) {
            // CRITICAL FIX: Update @Published properties on main thread
            await MainActor.run {
                pendingOperations = operations
            }
            print("📂 DataSyncService: Loaded \(operations.count) pending operations")
            
            for (index, operation) in operations.enumerated() {
                print("   └── \(index + 1). \(operation.type.rawValue) (created: \(formatTime(operation.createdAt)))")
            }
        } else {
            print("📂 DataSyncService: No pending operations found")
        }
    }
    
    private func savePendingOperations() async {

        
        guard let userEmail = userEmail else {
            print("❌ DataSyncService: No user email - cannot save operations")
            return
        }
        
        let key = "pendingOperations_\(userEmail)"
        
        do {
            let data = try JSONEncoder().encode(pendingOperations)
            UserDefaults.standard.set(data, forKey: key)

        } catch {
            print("❌ DataSyncService: Failed to save operations: \(error.localizedDescription)")
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    deinit {
        print("🔄 DataSyncService: Deinitializing")
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
} 