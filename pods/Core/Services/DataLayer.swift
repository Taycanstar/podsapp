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

// Debug logging helper - only prints in DEBUG builds
@inline(__always)
private func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    // Uncomment below for verbose DataLayer debugging
    // print(message())
    #endif
}

/// Comprehensive data layer architecture following industry best practices
/// Provides a unified interface for data storage, caching, and synchronization

// MARK: - Data Layer Architecture

// FIXED: Removed @MainActor - async functions update @Published from background threads
// @Published properties automatically publish on main thread, so UI updates work correctly
class DataLayer: ObservableObject {
    static let shared = DataLayer()

    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var cacheHitRate: Double = 0.0
    @Published var lastCacheUpdate: Date?

    // MARK: - Private Properties
    private var userEmail: String?
    private var cancellables = Set<AnyCancellable>()
    private var isInitializing = false

    // Layer 1: In-Memory Cache (milliseconds access)
    private var memoryCache: [String: Any] = [:]
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes

    // CRITICAL FIX: Throttle cache clears to prevent notification storm
    private var lastCacheClearTime: Date?
    private let minimumCacheClearInterval: TimeInterval = 5 // 5 seconds
    
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
        debugLog("🏗️ DataLayer: Initialized with 5-layer architecture")
    }
    
    // MARK: - Public Methods
    
    /// Initialize the data layer with user context
    func initialize(userEmail: String) async {
        debugLog("🚀 DataLayer: Initializing for user: \(userEmail)")
        isInitializing = true
        self.userEmail = userEmail

        // Initialize SwiftData context
        await setupSwiftDataContext()

        // Load cached data into memory
        await loadCachedData()

        // CRITICAL FIX: Update @Published property on main thread (non-blocking to avoid deadlock)
        Task { @MainActor in
            isInitialized = true
        }

        isInitializing = false
   
    }
    
    // MARK: - Onboarding Data Methods
    
    /// Save onboarding data using local-first strategy
    func saveOnboardingData(_ data: [String: Any]) async {

        
        let startTime = Date()
        
        // Layer 1: Update memory cache immediately
    
        memoryCache["onboarding_data"] = data
        cacheTimestamps["onboarding_data"] = Date()
    
        
        // Layer 3: Save to UserDefaults for persistence
   
        if let encoded = try? JSONSerialization.data(withJSONObject: data) {
            userDefaults.set(encoded, forKey: "onboarding_data_\(userEmail ?? "unknown")")
    
        }
        
        // Layer 5: Queue for sync with server
        debugLog("📝 DataLayer: Layer 5 (Sync Service) - Queueing for server sync")
        let syncOperation = SyncOperation(
            type: .onboardingData,
            data: data.compactMapValues { "\($0)" }, // Convert to [String: String] for demo
            createdAt: Date()
        )
        await syncService.queueOperation(syncOperation)
        
        let duration = Date().timeIntervalSince(startTime)
     
    }
    
    /// Fetch onboarding data with intelligent layer selection
    func fetchOnboardingData() async -> [String: Any]? {
        debugLog("📥 DataLayer: Fetching onboarding data (intelligent layer selection)")
        let startTime = Date()
        
        // Layer 1: Check memory cache first
  
        if let cachedData = getCachedData(key: "onboarding_data") {
            let duration = Date().timeIntervalSince(startTime)
            recordCacheHit()
            return cachedData as? [String: Any]
        }

        recordCacheMiss()
        
        // Layer 3: Check UserDefaults
        debugLog("🔍 DataLayer: Layer 3 (UserDefaults) - Checking for onboarding data")
        if let data = userDefaults.data(forKey: "onboarding_data_\(userEmail ?? "unknown")"),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            

            memoryCache["onboarding_data"] = decoded
            cacheTimestamps["onboarding_data"] = Date()
            
            let duration = Date().timeIntervalSince(startTime)
            debugLog("   └── Access time: \(String(format: "%.2f", duration * 1000))ms")
            return decoded
        }
        

        
        let duration = Date().timeIntervalSince(startTime)

        
        return nil
    }
    
    // MARK: - Profile Data Methods

    /// Update profile data and propagate across layers
    /// CRITICAL: @MainActor ensures this always runs on main thread to prevent UI freezes
    @MainActor
    func updateProfileData(_ data: [String: Any]) async {


        // CRITICAL: Assert we're on main thread to catch violations early in debug builds
        // This will crash if DataLayer is called from background thread, preventing UI freezes
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif


        memoryCache["profile_data"] = data
        cacheTimestamps["profile_data"] = Date()
 
        if let encoded = try? JSONSerialization.data(withJSONObject: data) {
            userDefaults.set(encoded, forKey: "profile_data_\(userEmail ?? "unknown")")
        }

        let syncOperation = SyncOperation(
            type: .profileUpdate,
            data: data.compactMapValues { "\($0)" },
            createdAt: Date()
        )
        await syncService.queueOperation(syncOperation)
        

    }
    
    // MARK: - Generic Data Methods
    
    /// Get data with intelligent layer selection
    func getData(key: String) async -> Any? {
        debugLog("🔍 DataLayer: Fetching data for key: \(key)")
        let startTime = Date()
        
        // Layer 1: Check memory cache
        if let cachedData = getCachedData(key: key) {
            let duration = Date().timeIntervalSince(startTime)

            recordCacheHit()
            return cachedData
        }
        

        recordCacheMiss()
        
        let currentEmail = resolvedUserEmail()
        if let email = currentEmail {
            self.userEmail = email
        }

        let primaryKey = "\(key)_\(currentEmail ?? "unknown")"
        let legacyKey = "\(key)_unknown"

        // Layer 3: Check UserDefaults (primary key)
        if let data = userDefaults.data(forKey: primaryKey) {
   
            
            // Try to decode and cache
            if let decoded = try? JSONSerialization.jsonObject(with: data) {
                memoryCache[key] = decoded
                cacheTimestamps[key] = Date()
                
                let duration = Date().timeIntervalSince(startTime)

                return decoded
            }
        }

        // Fallback: migrate legacy "unknown" entries if present
        if let data = userDefaults.data(forKey: legacyKey),
           let decoded = try? JSONSerialization.jsonObject(with: data) {
        

            memoryCache[key] = decoded
            cacheTimestamps[key] = Date()

            if let email = currentEmail,
               let encoded = try? JSONSerialization.data(withJSONObject: decoded) {
                let targetKey = "\(key)_\(email)"
                userDefaults.set(encoded, forKey: targetKey)
                userDefaults.removeObject(forKey: legacyKey)
            }

            let duration = Date().timeIntervalSince(startTime)

            return decoded
        }
        
        let duration = Date().timeIntervalSince(startTime)

        
        return nil
    }
    
    /// Set data with propagation across layers
    func setData(key: String, value: Any) async {

        
        // Layer 1: Update memory cache
        memoryCache[key] = value
        cacheTimestamps[key] = Date()

        
        let currentEmail = resolvedUserEmail()
        if let email = currentEmail {
            self.userEmail = email
        }

        // Layer 3: Update UserDefaults if serializable
        if let encoded = try? JSONSerialization.data(withJSONObject: value) {
            let storageKey = "\(key)_\(currentEmail ?? "unknown")"
            userDefaults.set(encoded, forKey: storageKey)
       
        }
        
        debugLog("✅ DataLayer: Data set successfully for key: \(key)")
    }
    
    /// Remove data from all layers
    func removeData(key: String) async {
        debugLog("🗑️ DataLayer: Removing data for key: \(key)")
        
        // Layer 1: Remove from memory cache
        memoryCache.removeValue(forKey: key)
        cacheTimestamps.removeValue(forKey: key)
        debugLog("   └── Memory cache cleared")
        
        let currentEmail = resolvedUserEmail()
        if let email = currentEmail {
            self.userEmail = email
        }

        // Layer 3: Remove from UserDefaults
        userDefaults.removeObject(forKey: "\(key)_\(currentEmail ?? "unknown")")
        debugLog("   └── UserDefaults cleared")

        debugLog("✅ DataLayer: Data removed successfully for key: \(key)")
    }
    
    // MARK: - Cache Management
    
    /// Clear expired cache entries
    func clearExpiredCache() {
        debugLog("🧹 DataLayer: Clearing expired cache entries")
        let now = Date()
        let expiredKeys = cacheTimestamps.compactMap { key, timestamp in
            now.timeIntervalSince(timestamp) > cacheTimeout ? key : nil
        }
        
        for key in expiredKeys {
            memoryCache.removeValue(forKey: key)
            cacheTimestamps.removeValue(forKey: key)
        }
        
        debugLog("🧹 DataLayer: Removed \(expiredKeys.count) expired cache entries")
        updateCacheHitRate()
    }
    
    /// Get cache statistics
    func getCacheStats() -> (hits: Int, misses: Int, hitRate: Double, entries: Int) {
        let hitRate = cacheHits + cacheMisses > 0 ? Double(cacheHits) / Double(cacheHits + cacheMisses) : 0.0
        return (cacheHits, cacheMisses, hitRate, memoryCache.count)
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        debugLog("📡 DataLayer: Setting up notification observers")

        // CRITICAL FIX: Ensure notification handling runs on main thread
        // receive(on:) ensures the sink closure executes on main RunLoop
        // Task { @MainActor in } ensures handleDataUpdate runs in main actor context
        NotificationCenter.default.publisher(for: .dataUpdated)
            .receive(on: RunLoop.main)  // ← Force main thread context
            .sink { [weak self] _ in
                debugLog("📢 DataLayer: Received .dataUpdated notification")
                debugLog("   └── Thread: \(Thread.isMainThread ? "MAIN ✅" : "BACKGROUND ⚠️")")
                debugLog("   └── Current thread: \(Thread.current)")
                Task { @MainActor in
                    debugLog("📢 DataLayer: About to call handleDataUpdate() on MainActor")
                    await self?.handleDataUpdate()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSwiftDataContext() async {
        debugLog("🗄️ DataLayer: Setting up SwiftData context")
        // SwiftData context setup would go here
        // For demo purposes, we'll simulate this
        debugLog("✅ DataLayer: SwiftData context ready")
    }
    
    private func loadCachedData() async {
        debugLog("📂 DataLayer: Loading cached data into memory")
        
        guard let userEmail = resolvedUserEmail() else {
            debugLog("❌ DataLayer: No user email - cannot load cached data")
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
                debugLog("   └── Loaded \(key) into memory cache")
            }
        }
        
        debugLog("📂 DataLayer: Loaded \(loadedCount) cached entries into memory")
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
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        let updateTime = Date()

        // CRITICAL FIX: Update @Published properties on main thread
        Task { @MainActor in
            cacheHitRate = hitRate
            lastCacheUpdate = updateTime
        }

        debugLog("📊 DataLayer: Cache Statistics")
        debugLog("   └── Hits: \(cacheHits)")
        debugLog("   └── Misses: \(cacheMisses)")
        debugLog("   └── Hit Rate: \(String(format: "%.1f", hitRate * 100))%")
        debugLog("   └── Entries: \(memoryCache.count)")
    }
    
    private func handleDataUpdate() async {
        debugLog("🔄 DataLayer: Handling data update from sync service")

        // CRITICAL FIX: Don't handle updates during initialization
        // This prevents SwiftUI re-evaluation cascade during app startup/resume
        if isInitializing {
            debugLog("⏭️ DataLayer: Skipping update - still initializing")
            return
        }

        // CRITICAL FIX: Throttle cache clears to prevent storm on every notification
        if let last = lastCacheClearTime, Date().timeIntervalSince(last) < minimumCacheClearInterval {
            let elapsed = Int(Date().timeIntervalSince(last))
            debugLog("⏭️ DataLayer: Skipping cache clear - cleared \(elapsed)s ago (min: \(Int(minimumCacheClearInterval))s)")
            return
        }

        // Clear relevant cache entries to force refresh
        debugLog("🧹 DataLayer: Clearing cache to force refresh with new data")
        memoryCache.removeAll()
        cacheTimestamps.removeAll()

        // Reload fresh data
        await loadCachedData()

        lastCacheClearTime = Date()
        debugLog("✅ DataLayer: Data update handled successfully")
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
