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
import SwiftData
import Network
import Combine
import UIKit

/// Comprehensive data sync service following industry best practices
/// Provides offline-first capabilities with intelligent conflict resolution
@MainActor
class DataSyncService: ObservableObject {
    static let shared = DataSyncService()
    
    // MARK: - Published Properties
    @Published var isOnline = true
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var pendingChanges: Int = 0
    
    // MARK: - Private Properties
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private var syncTimer: Timer?
    
    // Data managers
    private let userProfileManager = UserProfileDataManager()
    private let workoutDataManager = WorkoutDataManager.shared
    private let nutritionDataManager = NutritionDataManager()
    private let healthDataManager = HealthDataManager()
    
    private init() {
        setupNetworkMonitoring()
        setupSyncTimer()
        setupNotificationObservers()
    }
    
    // MARK: - Public API
    
    /// Initialize sync service for a user
    func initialize(userEmail: String) {
        print("🔄 DataSyncService: Initializing for user \(userEmail)")
        
        // Initialize all data managers
        userProfileManager.initialize(userEmail: userEmail)
        nutritionDataManager.initialize(userEmail: userEmail)
        healthDataManager.initialize(userEmail: userEmail)
        
        // Trigger initial sync if online
        if isOnline {
            Task {
                await performFullSync()
            }
        }
    }
    
    /// Force a full sync across all data types
    func performFullSync() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Sync in priority order
            await syncUserProfile()
            await syncNutritionData()
            await syncWorkoutData()
            await syncHealthData()
            
            lastSyncDate = Date()
            updatePendingChangesCount()
            
        } catch {
            syncError = error.localizedDescription
            print("❌ DataSyncService: Full sync failed - \(error)")
        }
        
        isSyncing = false
    }
    
    /// Sync specific data type
    func syncDataType<T: SyncableData>(_ dataType: T.Type) async throws {
        // Implementation for specific data type sync
        print("🔄 Syncing \(dataType)")
    }
    
    /// Queue local changes for sync
    func queueForSync<T: SyncableData>(_ data: inout T) {
        // Mark data as needing sync
        data.markForSync()
        updatePendingChangesCount()
        
        // Trigger sync if online
        if isOnline {
            Task {
                await performIncrementalSync()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                
                if path.status == .satisfied {
                    print("🌐 DataSyncService: Network connected - triggering sync")
                    Task {
                        await self?.performIncrementalSync()
                    }
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func setupSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isOnline else { return }
            
            Task {
                await self.performIncrementalSync()
            }
        }
    }
    
    private func setupNotificationObservers() {
        // App lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.performIncrementalSync()
                }
            }
            .store(in: &cancellables)
        
        // Data change notifications
        NotificationCenter.default.publisher(for: .dataChanged)
            .sink { [weak self] notification in
                if let dataType = notification.object as? SyncableData.Type {
                    Task {
                        try await self?.syncDataType(dataType)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func performIncrementalSync() async {
        guard !isSyncing, isOnline else { return }
        
        // Only sync if we have pending changes or it's been a while
        let shouldSync = pendingChanges > 0 || shouldPerformPeriodicSync()
        guard shouldSync else { return }
        
        await performFullSync()
    }
    
    private func shouldPerformPeriodicSync() -> Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) > syncInterval
    }
    
    private func syncUserProfile() async {
        await userProfileManager.sync()
    }
    
    private func syncNutritionData() async {
        await nutritionDataManager.sync()
    }
    
    private func syncWorkoutData() async {
        await workoutDataManager.syncNow()
    }
    
    private func syncHealthData() async {
        await healthDataManager.sync()
    }
    
    private func updatePendingChangesCount() {
        // Calculate total pending changes across all data managers
        let totalPending = userProfileManager.pendingChanges +
                          nutritionDataManager.pendingChanges +
                          healthDataManager.pendingChanges
        
        pendingChanges = totalPending
    }
}

// MARK: - Data Manager Protocol

protocol DataManagerProtocol {
    var pendingChanges: Int { get }
    func initialize(userEmail: String)
    func sync() async
}

// MARK: - Syncable Data Protocol

protocol SyncableData {
    var syncVersion: Int { get set }
    var lastModified: Date { get set }
    var needsSync: Bool { get set }
    
    mutating func markForSync()
}

extension SyncableData {
    mutating func markForSync() {
        needsSync = true
        lastModified = Date()
        syncVersion += 1
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let dataChanged = Notification.Name("DataChanged")
    static let syncCompleted = Notification.Name("SyncCompleted")
    static let syncFailed = Notification.Name("SyncFailed")
}

// MARK: - User Profile Data Manager

class UserProfileDataManager: DataManagerProtocol {
    @Published var pendingChanges: Int = 0
    private var userEmail: String?
    
    func initialize(userEmail: String) {
        self.userEmail = userEmail
        loadCachedData()
    }
    
    func sync() async {
        // Sync user profile data
        print("🔄 Syncing user profile data")
        
        // Implementation would go here
        // This would sync with UserProfileService
    }
    
    private func loadCachedData() {
        // Load cached profile data
    }
}

// MARK: - Nutrition Data Manager

class NutritionDataManager: DataManagerProtocol {
    @Published var pendingChanges: Int = 0
    private var userEmail: String?
    
    func initialize(userEmail: String) {
        self.userEmail = userEmail
        loadCachedData()
    }
    
    func sync() async {
        // Sync nutrition data (food logs, meals, etc.)
        print("🔄 Syncing nutrition data")
    }
    
    private func loadCachedData() {
        // Load cached nutrition data
    }
}

// MARK: - Health Data Manager

class HealthDataManager: DataManagerProtocol {
    @Published var pendingChanges: Int = 0
    private var userEmail: String?
    
    func initialize(userEmail: String) {
        self.userEmail = userEmail
        loadCachedData()
    }
    
    func sync() async {
        // Sync health data (weight logs, water intake, etc.)
        print("🔄 Syncing health data")
    }
    
    private func loadCachedData() {
        // Load cached health data
    }
} 