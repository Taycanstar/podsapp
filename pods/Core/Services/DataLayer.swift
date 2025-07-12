//
//  DataLayer.swift
//  pods
//
//  Created by Dimi Nunez on 7/12/25.
//

//
//  DataLayer.swift
//  Pods
//
//  Created by Dimi Nunez on 7/12/25.
//

import Foundation
import SwiftData

/// Comprehensive data layer architecture following industry best practices
/// Provides a unified interface for data storage, caching, and synchronization

// MARK: - Data Layer Architecture

/// Main data layer coordinator
@MainActor
class DataLayer: ObservableObject {
    static let shared = DataLayer()
    
    // MARK: - Storage Layers
    
    /// Level 1: In-Memory Cache (Fastest)
    private let memoryCache = MemoryCache()
    
    /// Level 2: Local Database (SwiftData for complex data)
    private let localDatabase = LocalDatabase()
    
    /// Level 3: UserDefaults (Simple preferences)
    private let userDefaults = UserDefaultsManager()
    
    /// Level 4: Remote Server (Source of truth)
    private let remoteAPI = RemoteAPIManager()
    
    /// Level 5: Sync Coordinator
    private let syncService = DataSyncService.shared
    
    private init() {
        setupDataLayer()
    }
    
    // MARK: - Public API
    
    /// Initialize data layer for a user
    func initialize(userEmail: String) {
        print("📊 DataLayer: Initializing for user \(userEmail)")
        
        // Initialize all storage layers
        localDatabase.initialize(userEmail: userEmail)
        userDefaults.initialize(userEmail: userEmail)
        remoteAPI.initialize(userEmail: userEmail)
        syncService.initialize(userEmail: userEmail)
        
        // Setup data flow
        setupDataFlow()
    }
    
    /// Get data with fallback strategy
    func getData<T: Codable>(_ type: T.Type, key: String, strategy: DataStrategy = .memoryFirst) async throws -> T? {
        switch strategy {
        case .memoryFirst:
            return try await getDataMemoryFirst(type, key: key)
        case .localFirst:
            return try await getDataLocalFirst(type, key: key)
        case .remoteFirst:
            return try await getDataRemoteFirst(type, key: key)
        case .offline:
            return try await getDataOffline(type, key: key)
        }
    }
    
    /// Save data with automatic sync
    func saveData<T: Codable>(_ data: T, key: String, strategy: DataStrategy = .localFirst) async throws {
        switch strategy {
        case .memoryFirst, .localFirst:
            try await saveDataLocalFirst(data, key: key)
        case .remoteFirst:
            try await saveDataRemoteFirst(data, key: key)
        case .offline:
            try await saveDataOffline(data, key: key)
        }
    }
    
    /// Save onboarding data with intelligent sync
    func saveOnboardingData(_ data: OnboardingData, strategy: DataStrategy = .localFirst) async throws {
        let key = "onboarding_data_\(data.email)"
        try await saveData(data, key: key, strategy: strategy)
        print("💾 DataLayer: Saved onboarding data for \(data.email)")
    }
    
    /// Get data with convenience method
    func getData<T: Codable>(key: String, strategy: DataStrategy = .memoryFirst) async throws -> T? {
        return try await getData(T.self, key: key, strategy: strategy)
    }
    
    // MARK: - Private Methods
    
    private func setupDataLayer() {
        // Configure caching policies
        memoryCache.configure(maxSize: 50_000_000) // 50MB
        
        // Setup automatic cleanup
        setupAutomaticCleanup()
    }
    
    private func setupDataFlow() {
        // Configure data flow between layers
        print("🔄 DataLayer: Setting up data flow")
    }
    
    private func setupAutomaticCleanup() {
        // Clean up expired cache entries
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in
                self.memoryCache.cleanup()
            }
        }
    }
    
    // MARK: - Data Access Strategies
    
    private func getDataMemoryFirst<T: Codable>(_ type: T.Type, key: String) async throws -> T? {
        // 1. Check memory cache
        if let cached = memoryCache.get(key, type: type) {
            return cached
        }
        
        // 2. Check local database
        if let local = try await localDatabase.get(key, type: type) {
            memoryCache.set(key, value: local)
            return local
        }
        
        // 3. Check UserDefaults
        if let userDefault = userDefaults.get(key, type: type) {
            memoryCache.set(key, value: userDefault)
            return userDefault
        }
        
        // 4. Fetch from remote (background)
        Task {
            if let remote = try? await remoteAPI.get(key, type: type) {
                memoryCache.set(key, value: remote)
                try? await localDatabase.set(key, value: remote)
            }
        }
        
        return nil
    }
    
    private func getDataLocalFirst<T: Codable>(_ type: T.Type, key: String) async throws -> T? {
        // 1. Check local database
        if let local = try await localDatabase.get(key, type: type) {
            memoryCache.set(key, value: local)
            return local
        }
        
        // 2. Check memory cache
        if let cached = memoryCache.get(key, type: type) {
            return cached
        }
        
        // 3. Fetch from remote
        if let remote = try await remoteAPI.get(key, type: type) {
            memoryCache.set(key, value: remote)
            try await localDatabase.set(key, value: remote)
            return remote
        }
        
        return nil
    }
    
    private func getDataRemoteFirst<T: Codable>(_ type: T.Type, key: String) async throws -> T? {
        // 1. Fetch from remote
        if let remote = try await remoteAPI.get(key, type: type) {
            memoryCache.set(key, value: remote)
            try await localDatabase.set(key, value: remote)
            return remote
        }
        
        // 2. Fallback to local
        return try await getDataLocalFirst(type, key: key)
    }
    
    private func getDataOffline<T: Codable>(_ type: T.Type, key: String) async throws -> T? {
        // Only use local storage
        return try await getDataLocalFirst(type, key: key)
    }
    
    private func saveDataLocalFirst<T: Codable>(_ data: T, key: String) async throws {
        // 1. Save to memory cache
        memoryCache.set(key, value: data)
        
        // 2. Save to local database
        try await localDatabase.set(key, value: data)
        
        // 3. Queue for remote sync
        var syncItem = DataSyncItem(key: key, data: data)
        syncService.queueForSync(&syncItem)
    }
    
    private func saveDataRemoteFirst<T: Codable>(_ data: T, key: String) async throws {
        // 1. Save to remote
        try await remoteAPI.set(key, value: data)
        
        // 2. Update local storage
        memoryCache.set(key, value: data)
        try await localDatabase.set(key, value: data)
    }
    
    private func saveDataOffline<T: Codable>(_ data: T, key: String) async throws {
        // Save locally and queue for sync
        try await saveDataLocalFirst(data, key: key)
    }
}

// MARK: - Data Strategy

enum DataStrategy {
    case memoryFirst    // Check memory → local → remote
    case localFirst     // Check local → memory → remote  
    case remoteFirst    // Check remote → local → memory
    case offline        // Only local storage
}

// MARK: - Memory Cache

class MemoryCache {
    private var cache: [String: CacheItem] = [:]
    private var maxSize: Int = 50_000_000 // 50MB
    private let queue = DispatchQueue(label: "MemoryCache", attributes: .concurrent)
    
    func configure(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func get<T: Codable>(_ key: String, type: T.Type) -> T? {
        return queue.sync {
            guard let item = cache[key], !item.isExpired else {
                cache.removeValue(forKey: key)
                return nil
            }
            
            item.lastAccessed = Date()
            return item.data as? T
        }
    }
    
    func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval = 3600) {
        queue.async(flags: .barrier) {
            let item = CacheItem(data: value, ttl: ttl)
            self.cache[key] = item
            self.enforceMemoryLimit()
        }
    }
    
    func cleanup() {
        queue.async(flags: .barrier) {
            let now = Date()
            self.cache = self.cache.filter { !$0.value.isExpired }
        }
    }
    
    private func enforceMemoryLimit() {
        // Remove oldest items if over limit
        let totalSize = cache.values.reduce(0) { $0 + $1.estimatedSize }
        
        if totalSize > maxSize {
            let sortedItems = cache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
            let toRemove = sortedItems.prefix(cache.count / 4) // Remove 25%
            
            for (key, _) in toRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
}

// MARK: - Cache Item

class CacheItem {
    let data: Any
    let createdAt: Date
    let ttl: TimeInterval
    var lastAccessed: Date
    
    init(data: Any, ttl: TimeInterval) {
        self.data = data
        self.createdAt = Date()
        self.lastAccessed = Date()
        self.ttl = ttl
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > ttl
    }
    
    var estimatedSize: Int {
        // Rough estimate - could be more sophisticated
        return 1024 // 1KB default
    }
}

// MARK: - Local Database

class LocalDatabase {
    private var userEmail: String?
    
    func initialize(userEmail: String) {
        self.userEmail = userEmail
    }
    
    func get<T: Codable>(_ key: String, type: T.Type) async throws -> T? {
        // Implementation depends on data type
        // For complex data: use SwiftData
        // For simple data: use UserDefaults
        return nil
    }
    
    func set<T: Codable>(_ key: String, value: T) async throws {
        // Implementation depends on data type
    }
}

// MARK: - UserDefaults Manager

class UserDefaultsManager {
    private var userEmail: String?
    
    func initialize(userEmail: String) {
        self.userEmail = userEmail
    }
    
    func get<T: Codable>(_ key: String, type: T.Type) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    func set<T: Codable>(_ key: String, value: T) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Remote API Manager

class RemoteAPIManager {
    private var userEmail: String?
    
    func initialize(userEmail: String) {
        self.userEmail = userEmail
    }
    
    func get<T: Codable>(_ key: String, type: T.Type) async throws -> T? {
        // Implementation would call actual API
        return nil
    }
    
    func set<T: Codable>(_ key: String, value: T) async throws {
        // Implementation would call actual API
    }
}

// MARK: - Data Sync Item

struct DataSyncItem: SyncableData {
    let key: String
    let data: Any
    var syncVersion: Int = 1
    var lastModified: Date = Date()
    var needsSync: Bool = true
} 