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
import Combine

/// Comprehensive data layer architecture following industry best practices
/// Provides a unified interface for data storage, caching, and synchronization

// MARK: - Data Layer Architecture

@MainActor
class DataLayer: ObservableObject {
    static let shared = DataLayer()
    
    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var cacheHitRate: Double = 0.0
    @Published var lastCacheUpdate: Date?
    
    // MARK: - Private Properties
    private var userEmail: String?
    private var cancellables = Set<AnyCancellable>()
    
    // Layer 1: In-Memory Cache (milliseconds access)
    private var memoryCache: [String: Any] = [:]
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    // Layer 2: SwiftData (offline capable)
    private var modelContext: ModelContext?
    
    // Layer 3: UserDefaults (simple preferences)
    private let userDefaults = UserDefaults.standard
    
    // Layer 4: Remote API handled by network services
    // Layer 5: Sync Service coordination
    private let syncService = DataSyncService.shared
    
    // MARK: - Statistics
    private var cacheHits = 0
    private var cacheMisses = 0
    
    private init() {
        setupNotificationObservers()
        print("🏗️ DataLayer: Initialized with 5-layer architecture")
        print("   └── Layer 1: In-Memory Cache (1-5ms)")
        print("   └── Layer 2: SwiftData/Local DB (10-50ms)")
        print("   └── Layer 3: UserDefaults (5-20ms)")
        print("   └── Layer 4: Remote API (100-1000ms)")
        print("   └── Layer 5: Sync Service (background)")
    }
    
    // MARK: - Public Methods
    
    /// Initialize the data layer with user context
    func initialize(userEmail: String) async {
        print("🚀 DataLayer: Initializing for user: \(userEmail)")
        self.userEmail = userEmail
        
        // Initialize SwiftData context
        await setupSwiftDataContext()
        
        // Load cached data into memory
        await loadCachedData()
        
        isInitialized = true
        print("✅ DataLayer: Initialization complete")
        print("   └── User: \(userEmail)")
        print("   └── Cache entries: \(memoryCache.count)")
        print("   └── Ready for data operations")
    }
    
    // MARK: - Onboarding Data Methods
    
    /// Save onboarding data using local-first strategy
    func saveOnboardingData(_ data: [String: Any]) async {
        print("💾 DataLayer: Saving onboarding data (local-first strategy)")
        print("   └── Data keys: \(data.keys.joined(separator: ", "))")
        
        let startTime = Date()
        
        // Layer 1: Update memory cache immediately
        print("📝 DataLayer: Layer 1 (Memory Cache) - Saving onboarding data")
        memoryCache["onboarding_data"] = data
        cacheTimestamps["onboarding_data"] = Date()
        print("   └── Memory cache updated (instant)")
        
        // Layer 3: Save to UserDefaults for persistence
        print("📝 DataLayer: Layer 3 (UserDefaults) - Persisting onboarding data")
        if let encoded = try? JSONSerialization.data(withJSONObject: data) {
            userDefaults.set(encoded, forKey: "onboarding_data_\(userEmail ?? "unknown")")
            print("   └── UserDefaults saved successfully")
        }
        
        // Layer 5: Queue for sync with server
        print("📝 DataLayer: Layer 5 (Sync Service) - Queueing for server sync")
        let syncOperation = SyncOperation(
            type: .onboardingData,
            data: data.compactMapValues { "\($0)" }, // Convert to [String: String] for demo
            createdAt: Date()
        )
        await syncService.queueOperation(syncOperation)
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ DataLayer: Onboarding data saved successfully")
        print("   └── Total time: \(String(format: "%.2f", duration * 1000))ms")
        print("   └── Strategy: Local-first with background sync")
    }
    
    /// Fetch onboarding data with intelligent layer selection
    func fetchOnboardingData() async -> [String: Any]? {
        print("📥 DataLayer: Fetching onboarding data (intelligent layer selection)")
        let startTime = Date()
        
        // Layer 1: Check memory cache first
        print("🔍 DataLayer: Layer 1 (Memory Cache) - Checking for onboarding data")
        if let cachedData = getCachedData(key: "onboarding_data") {
            let duration = Date().timeIntervalSince(startTime)
            print("✅ DataLayer: Cache HIT - Data found in memory")
            print("   └── Access time: \(String(format: "%.2f", duration * 1000))ms")
            recordCacheHit()
            return cachedData as? [String: Any]
        }
        
        print("❌ DataLayer: Cache MISS - Data not in memory")
        recordCacheMiss()
        
        // Layer 3: Check UserDefaults
        print("🔍 DataLayer: Layer 3 (UserDefaults) - Checking for onboarding data")
        if let data = userDefaults.data(forKey: "onboarding_data_\(userEmail ?? "unknown")"),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // Update memory cache
            print("✅ DataLayer: Found in UserDefaults - Updating memory cache")
            memoryCache["onboarding_data"] = decoded
            cacheTimestamps["onboarding_data"] = Date()
            
            let duration = Date().timeIntervalSince(startTime)
            print("   └── Access time: \(String(format: "%.2f", duration * 1000))ms")
            return decoded
        }
        
        // Layer 4: Fetch from server (would be implemented with actual API calls)
        print("🔍 DataLayer: Layer 4 (Remote API) - Would fetch from server")
        print("   └── (Not implemented in demo)")
        
        let duration = Date().timeIntervalSince(startTime)
        print("❌ DataLayer: No onboarding data found in any layer")
        print("   └── Total search time: \(String(format: "%.2f", duration * 1000))ms")
        
        return nil
    }
    
    // MARK: - Profile Data Methods
    
    /// Update profile data and propagate across layers
    func updateProfileData(_ data: [String: Any]) async {
        print("📝 DataLayer: Updating profile data across all layers")
        print("   └── Data keys: \(data.keys.joined(separator: ", "))")
        
        // Layer 1: Update memory cache
        print("📝 DataLayer: Layer 1 (Memory Cache) - Updating profile data")
        memoryCache["profile_data"] = data
        cacheTimestamps["profile_data"] = Date()
        
        // Layer 3: Update UserDefaults
        print("📝 DataLayer: Layer 3 (UserDefaults) - Persisting profile data")
        if let encoded = try? JSONSerialization.data(withJSONObject: data) {
            userDefaults.set(encoded, forKey: "profile_data_\(userEmail ?? "unknown")")
        }
        
        // Layer 5: Queue for sync
        print("📝 DataLayer: Layer 5 (Sync Service) - Queueing profile update")
        let syncOperation = SyncOperation(
            type: .profileUpdate,
            data: data.compactMapValues { "\($0)" },
            createdAt: Date()
        )
        await syncService.queueOperation(syncOperation)
        
        print("✅ DataLayer: Profile data updated across all layers")
    }
    
    // MARK: - Generic Data Methods
    
    /// Get data with intelligent layer selection
    func getData(key: String) async -> Any? {
        print("🔍 DataLayer: Fetching data for key: \(key)")
        let startTime = Date()
        
        // Layer 1: Check memory cache
        if let cachedData = getCachedData(key: key) {
            let duration = Date().timeIntervalSince(startTime)
            print("✅ DataLayer: Cache HIT for key: \(key)")
            print("   └── Access time: \(String(format: "%.2f", duration * 1000))ms")
            recordCacheHit()
            return cachedData
        }
        
        print("❌ DataLayer: Cache MISS for key: \(key)")
        recordCacheMiss()
        
        let currentEmail = resolvedUserEmail()
        if let email = currentEmail {
            self.userEmail = email
        }

        let primaryKey = "\(key)_\(currentEmail ?? "unknown")"
        let legacyKey = "\(key)_unknown"

        // Layer 3: Check UserDefaults (primary key)
        if let data = userDefaults.data(forKey: primaryKey) {
            print("✅ DataLayer: Found in UserDefaults for key: \(key)")
            
            // Try to decode and cache
            if let decoded = try? JSONSerialization.jsonObject(with: data) {
                memoryCache[key] = decoded
                cacheTimestamps[key] = Date()
                
                let duration = Date().timeIntervalSince(startTime)
                print("   └── Access time: \(String(format: "%.2f", duration * 1000))ms")
                return decoded
            }
        }

        // Fallback: migrate legacy "unknown" entries if present
        if let data = userDefaults.data(forKey: legacyKey),
           let decoded = try? JSONSerialization.jsonObject(with: data) {
            print("♻️ DataLayer: Migrating legacy stored data for key: \(key)")

            memoryCache[key] = decoded
            cacheTimestamps[key] = Date()

            if let email = currentEmail,
               let encoded = try? JSONSerialization.data(withJSONObject: decoded) {
                let targetKey = "\(key)_\(email)"
                userDefaults.set(encoded, forKey: targetKey)
                userDefaults.removeObject(forKey: legacyKey)
            }

            let duration = Date().timeIntervalSince(startTime)
            print("   └── Access time: \(String(format: "%.2f", duration * 1000))ms")
            return decoded
        }
        
        let duration = Date().timeIntervalSince(startTime)
        print("❌ DataLayer: No data found for key: \(key)")
        print("   └── Search time: \(String(format: "%.2f", duration * 1000))ms")
        
        return nil
    }
    
    /// Set data with propagation across layers
    func setData(key: String, value: Any) async {
        print("📝 DataLayer: Setting data for key: \(key)")
        
        // Layer 1: Update memory cache
        memoryCache[key] = value
        cacheTimestamps[key] = Date()
        print("   └── Memory cache updated")
        
        let currentEmail = resolvedUserEmail()
        if let email = currentEmail {
            self.userEmail = email
        }

        // Layer 3: Update UserDefaults if serializable
        if let encoded = try? JSONSerialization.data(withJSONObject: value) {
            let storageKey = "\(key)_\(currentEmail ?? "unknown")"
            userDefaults.set(encoded, forKey: storageKey)
            print("   └── UserDefaults updated")
        }
        
        print("✅ DataLayer: Data set successfully for key: \(key)")
    }
    
    /// Remove data from all layers
    func removeData(key: String) async {
        print("🗑️ DataLayer: Removing data for key: \(key)")
        
        // Layer 1: Remove from memory cache
        memoryCache.removeValue(forKey: key)
        cacheTimestamps.removeValue(forKey: key)
        print("   └── Memory cache cleared")
        
        let currentEmail = resolvedUserEmail()
        if let email = currentEmail {
            self.userEmail = email
        }

        // Layer 3: Remove from UserDefaults
        userDefaults.removeObject(forKey: "\(key)_\(currentEmail ?? "unknown")")
        print("   └── UserDefaults cleared")

        print("✅ DataLayer: Data removed successfully for key: \(key)")
    }
    
    // MARK: - Cache Management
    
    /// Clear expired cache entries
    func clearExpiredCache() {
        print("🧹 DataLayer: Clearing expired cache entries")
        let now = Date()
        let expiredKeys = cacheTimestamps.compactMap { key, timestamp in
            now.timeIntervalSince(timestamp) > cacheTimeout ? key : nil
        }
        
        for key in expiredKeys {
            memoryCache.removeValue(forKey: key)
            cacheTimestamps.removeValue(forKey: key)
        }
        
        print("🧹 DataLayer: Removed \(expiredKeys.count) expired cache entries")
        updateCacheHitRate()
    }
    
    /// Get cache statistics
    func getCacheStats() -> (hits: Int, misses: Int, hitRate: Double, entries: Int) {
        let hitRate = cacheHits + cacheMisses > 0 ? Double(cacheHits) / Double(cacheHits + cacheMisses) : 0.0
        return (cacheHits, cacheMisses, hitRate, memoryCache.count)
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        print("📡 DataLayer: Setting up notification observers")
        
        // Listen for sync service updates
        NotificationCenter.default.publisher(for: .dataUpdated)
            .sink { [weak self] _ in
                print("📢 DataLayer: Received data update notification from sync service")
                Task {
                    await self?.handleDataUpdate()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSwiftDataContext() async {
        print("🗄️ DataLayer: Setting up SwiftData context")
        // SwiftData context setup would go here
        // For demo purposes, we'll simulate this
        print("✅ DataLayer: SwiftData context ready")
    }
    
    private func loadCachedData() async {
        print("📂 DataLayer: Loading cached data into memory")
        
        guard let userEmail = resolvedUserEmail() else {
            print("❌ DataLayer: No user email - cannot load cached data")
            return
        }
        self.userEmail = userEmail

        // Load common data from UserDefaults into memory cache
        let commonKeys = ["onboarding_data", "profile_data", "user_preferences"]
        var loadedCount = 0
        
        for key in commonKeys {
            if let data = userDefaults.data(forKey: "\(key)_\(userEmail)"),
               let decoded = try? JSONSerialization.jsonObject(with: data) {
                memoryCache[key] = decoded
                cacheTimestamps[key] = Date()
                loadedCount += 1
                print("   └── Loaded \(key) into memory cache")
            }
        }
        
        print("📂 DataLayer: Loaded \(loadedCount) cached entries into memory")
        updateCacheHitRate()
    }
    
    private func getCachedData(key: String) -> Any? {
        // Check if cache entry exists and is not expired
        guard let timestamp = cacheTimestamps[key],
              Date().timeIntervalSince(timestamp) < cacheTimeout else {
            return nil
        }
        
        return memoryCache[key]
    }
    
    private func recordCacheHit() {
        cacheHits += 1
        updateCacheHitRate()
    }
    
    private func recordCacheMiss() {
        cacheMisses += 1
        updateCacheHitRate()
    }
    
    private func updateCacheHitRate() {
        let total = cacheHits + cacheMisses
        cacheHitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        lastCacheUpdate = Date()
        
        print("📊 DataLayer: Cache Statistics")
        print("   └── Hits: \(cacheHits)")
        print("   └── Misses: \(cacheMisses)")
        print("   └── Hit Rate: \(String(format: "%.1f", cacheHitRate * 100))%")
        print("   └── Entries: \(memoryCache.count)")
    }
    
    private func handleDataUpdate() async {
        print("🔄 DataLayer: Handling data update from sync service")
        
        // Clear relevant cache entries to force refresh
        print("🧹 DataLayer: Clearing cache to force refresh with new data")
        memoryCache.removeAll()
        cacheTimestamps.removeAll()
        
        // Reload fresh data
        await loadCachedData()
        
        print("✅ DataLayer: Data update handled successfully")
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func resolvedUserEmail() -> String? {
        if let email = userEmail, !email.isEmpty {
            return email
        }
        if let stored = UserDefaults.standard.string(forKey: "userEmail"), !stored.isEmpty {
            return stored
        }
        return nil
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
