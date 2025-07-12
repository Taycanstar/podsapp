# Data Architecture - Industry Best Practices

## Overview

Our app now implements a **comprehensive 5-layer data architecture** that follows industry best practices for mobile applications. This architecture provides:

✅ **Offline-first capabilities**  
✅ **Intelligent caching**  
✅ **Automatic synchronization**  
✅ **Conflict resolution**  
✅ **Backward compatibility**  
✅ **Great user experience**

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                        USER INTERFACE                       │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: In-Memory Cache (Fastest - milliseconds)          │
│ • Active data for current session                          │
│ • Automatic cleanup and memory management                  │
│ • TTL-based expiration                                     │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Local Database (Fast - SwiftData)                 │
│ • Complex relational data (workouts, exercises)           │
│ • Offline capabilities                                     │
│ • Full-text search                                        │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: UserDefaults (Fast - Simple preferences)          │
│ • User preferences and settings                           │
│ • Authentication tokens                                    │
│ • Simple key-value data                                   │
├─────────────────────────────────────────────────────────────┤
│ Layer 4: Remote Server (Source of truth)                   │
│ • Authoritative data source                               │
│ • Cross-device synchronization                            │
│ • Backup and recovery                                     │
├─────────────────────────────────────────────────────────────┤
│ Layer 5: Sync Coordinator (Intelligence)                   │
│ • Conflict resolution                                      │
│ • Background synchronization                              │
│ • Network monitoring                                      │
│ • Retry logic                                            │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow Strategies

### 1. Memory-First Strategy (Default for UI)
```swift
// Perfect for: Active UI data, frequently accessed content
let profileData = try await DataLayer.shared.getData(
    ProfileDataResponse.self, 
    key: "user_profile", 
    strategy: .memoryFirst
)
```

**Flow**: Memory → Local DB → UserDefaults → Remote (background)

### 2. Local-First Strategy (Offline-capable)
```swift
// Perfect for: Workout data, nutrition logs, core app data
let workouts = try await DataLayer.shared.getData(
    [WorkoutSession].self, 
    key: "user_workouts", 
    strategy: .localFirst
)
```

**Flow**: Local DB → Memory → Remote → Update Local

### 3. Remote-First Strategy (Always fresh)
```swift
// Perfect for: Social features, real-time data, shared content
let sharedPods = try await DataLayer.shared.getData(
    [Pod].self, 
    key: "shared_pods", 
    strategy: .remoteFirst
)
```

**Flow**: Remote → Local DB → Memory

### 4. Offline Strategy (Airplane mode)
```swift
// Perfect for: Offline-only scenarios, cached content
let offlineData = try await DataLayer.shared.getData(
    CachedData.self, 
    key: "offline_content", 
    strategy: .offline
)
```

**Flow**: Local DB → Memory (no remote calls)

## Implementation Examples

### Saving User Profile Data
```swift
// Automatically syncs across all layers
try await DataLayer.shared.saveData(
    userProfile, 
    key: "user_profile_\(userEmail)", 
    strategy: .localFirst
)
```

### Loading Workout History
```swift
// Loads from fastest available source
let workouts = try await DataLayer.shared.getData(
    [WorkoutSession].self, 
    key: "workouts_\(userEmail)", 
    strategy: .memoryFirst
)
```

### Handling Network Changes
```swift
// Automatic sync when network becomes available
DataSyncService.shared.$isOnline
    .sink { isOnline in
        if isOnline {
            Task {
                await DataSyncService.shared.performFullSync()
            }
        }
    }
    .store(in: &cancellables)
```

## Migration Guide

### Phase 1: Gradual Migration (Current)
1. **Keep existing UserDefaults code** - it still works
2. **New features use DataLayer** - for modern architecture
3. **Background sync** - automatically keeps data in sync

### Phase 2: Service Integration (Next)
1. **Update UserProfileService** to use DataLayer
2. **Migrate WorkoutDataManager** to new architecture
3. **Update FoodManager** for nutrition data

### Phase 3: Full Migration (Future)
1. **Replace direct UserDefaults calls** with DataLayer
2. **Consolidate all caching logic** into unified system
3. **Remove duplicate storage code**

## Backward Compatibility

### ✅ Existing Code Continues to Work
```swift
// Old code still works
let email = UserDefaults.standard.string(forKey: "userEmail")

// New code is more powerful
let email = try await DataLayer.shared.getData(
    String.self, 
    key: "userEmail", 
    strategy: .memoryFirst
)
```

### ✅ Data Migration is Automatic
- Existing UserDefaults data is automatically accessible
- No user data is lost during migration
- Background sync keeps everything in sync

### ✅ Gradual Adoption
- New features use the new architecture
- Existing features continue to work
- Migration happens feature by feature

## Key Benefits

### 🚀 Performance
- **Memory cache**: Instant access to frequently used data
- **Local database**: Fast offline access to complex data
- **Background sync**: No UI blocking for network operations

### 🔄 Reliability
- **Offline-first**: App works without internet
- **Automatic sync**: Data stays consistent across devices
- **Conflict resolution**: Handles concurrent edits gracefully

### 📱 User Experience
- **Instant loading**: Data appears immediately from cache
- **Seamless sync**: Changes sync automatically in background
- **Offline capability**: Full app functionality without internet

### 🛡️ Data Safety
- **Multiple backups**: Data stored in multiple layers
- **Automatic recovery**: Failed syncs are automatically retried
- **Conflict resolution**: Prevents data loss from concurrent edits

## Best Practices

### 1. Choose the Right Strategy
```swift
// UI data that changes frequently
.memoryFirst

// Core app data that needs offline access
.localFirst

// Social/shared data that must be fresh
.remoteFirst

// Cached content for offline use
.offline
```

### 2. Handle Errors Gracefully
```swift
do {
    let data = try await DataLayer.shared.getData(...)
    // Use data
} catch {
    // Fallback to cached data or show error
    print("Data loading failed: \(error)")
}
```

### 3. Monitor Sync Status
```swift
DataSyncService.shared.$isSyncing
    .sink { isSyncing in
        // Show sync indicator in UI
        self.showSyncIndicator = isSyncing
    }
    .store(in: &cancellables)
```

### 4. Use Appropriate Keys
```swift
// User-specific data
"user_profile_\(userEmail)"
"workouts_\(userEmail)"

// Global data
"app_settings"
"exercise_database"
```

## Architecture Decisions

### Why 5 Layers?
1. **Memory Cache**: Fastest access for active data
2. **Local Database**: Complex data with relationships
3. **UserDefaults**: Simple preferences and settings
4. **Remote Server**: Source of truth and backup
5. **Sync Coordinator**: Intelligence and conflict resolution

### Why SwiftData + UserDefaults?
- **SwiftData**: Perfect for complex relational data (workouts, exercises)
- **UserDefaults**: Perfect for simple preferences and settings
- **Both**: Complement each other for complete coverage

### Why Offline-First?
- **Better UX**: App works instantly, even without internet
- **Reliability**: No dependency on network connectivity
- **Performance**: Local data is always faster than remote

## Future Enhancements

### Planned Features
1. **Smart prefetching**: Predict and preload data user will need
2. **Compression**: Reduce storage and bandwidth usage
3. **Encryption**: Secure sensitive data at rest
4. **Analytics**: Track data usage patterns for optimization

### Potential Integrations
1. **CloudKit**: For seamless Apple ecosystem sync
2. **Core Data**: If more complex queries are needed
3. **SQLite**: For custom database requirements
4. **GraphQL**: For more efficient API communication

## Summary

This architecture provides:
- ✅ **Industry-standard data management**
- ✅ **Excellent user experience**
- ✅ **Robust offline capabilities**
- ✅ **Automatic synchronization**
- ✅ **Backward compatibility**
- ✅ **Scalable foundation for future growth**

The system is designed to be:
- **Invisible to users** - everything just works
- **Easy for developers** - simple, consistent API
- **Reliable and fast** - multiple layers of caching
- **Future-proof** - extensible architecture 