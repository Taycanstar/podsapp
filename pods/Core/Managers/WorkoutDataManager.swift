//
//  WorkoutDataManager.swift
//  pods
//
//  Created by Dimi Nunez on 7/11/25.
//

//
//  WorkoutDataManager.swift
//  Pods
//
//  Created by Dimi Nunez on 7/10/25.
//

import Foundation
import SwiftData

// MARK: - Data Models with Sync Support

struct SyncableWorkoutSession: Codable {
    let id: UUID
    let userEmail: String
    let name: String
    let startedAt: Date
    let completedAt: Date?
    let exercises: [SyncableExerciseInstance]
    let notes: String?
    
    // Sync metadata
    let createdAt: Date
    let updatedAt: Date
    let syncVersion: Int
    let isDeleted: Bool
    
    init(from workout: WorkoutSession) {
        self.id = workout.id
        self.userEmail = workout.userEmail
        self.name = workout.name
        self.startedAt = workout.startedAt
        self.completedAt = workout.completedAt
        self.exercises = workout.exercises.map { SyncableExerciseInstance(from: $0) }
        self.notes = workout.notes
        
        // Sync metadata
        self.createdAt = workout.createdAt
        self.updatedAt = workout.updatedAt
        self.syncVersion = workout.syncVersion
        self.isDeleted = workout.isDeleted
    }
}

struct SyncableExerciseInstance: Codable {
    let id: UUID
    let exerciseId: Int
    let exerciseName: String
    let bodyPart: String
    let orderIndex: Int
    let sets: [SyncableSetInstance]
    
    init(from exercise: ExerciseInstance) {
        self.id = exercise.id
        self.exerciseId = exercise.exerciseId
        self.exerciseName = exercise.exerciseName
        self.bodyPart = exercise.bodyPart
        self.orderIndex = exercise.orderIndex
        self.sets = exercise.sets.map { SyncableSetInstance(from: $0) }
    }
}

struct SyncableSetInstance: Codable {
    let id: UUID
    let setNumber: Int
    let targetReps: Int
    let targetWeight: Double?
    let actualReps: Int?
    let actualWeight: Double?
    let completed: Bool
    let completedAt: Date?
    
    init(from set: SetInstance) {
        self.id = set.id
        self.setNumber = set.setNumber
        self.targetReps = set.targetReps
        self.targetWeight = set.targetWeight
        self.actualReps = set.actualReps
        self.actualWeight = set.actualWeight
        self.completed = set.completed
        self.completedAt = set.completedAt
    }
}

// MARK: - Workout Data Manager

@MainActor
class WorkoutDataManager: ObservableObject {
    static let shared = WorkoutDataManager()
    
    private let localStorage = WorkoutLocalStorage()
    private let cloudSync = WorkoutCloudSync()
    private let conflictResolver = WorkoutConflictResolver()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private init() {
        setupSyncTimer()
    }
    
    // MARK: - Public API
    
    /// Save workout with automatic local storage and cloud sync
    func saveWorkout(_ workout: WorkoutSession) async throws {
        // 1. Save locally immediately
        try await localStorage.saveWorkout(workout)
        
        // 2. Queue for cloud sync
        await cloudSync.queueForSync(workout)
        
        // 3. Trigger background sync
        await syncPendingData()
    }
    
    /// Fetch workouts with local-first approach
    func fetchWorkouts(for userEmail: String) async throws -> [WorkoutSession] {
        // 1. Get local data immediately
        let localWorkouts = try await localStorage.fetchWorkouts(for: userEmail)
        
        // 2. Trigger background sync to get latest data
        Task {
            await syncPendingData()
        }
        
        return localWorkouts
    }
    
    /// Manual sync trigger
    func syncNow() async {
        await syncPendingData()
    }
    
    // MARK: - Private Methods
    
    private func setupSyncTimer() {
        // Sync every 5 minutes when app is active
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                await self.syncPendingData()
            }
        }
    }
    
    private func syncPendingData() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // 1. Get local changes
            let localChanges = await localStorage.getUnsyncedChanges()
            
            // 2. Get server changes
            let serverChanges = try await cloudSync.fetchServerChanges()
            
            // 3. Resolve conflicts
            let resolvedChanges = await conflictResolver.resolveConflicts(
                local: localChanges,
                server: serverChanges
            )
            
            // 4. Apply resolved changes
            try await localStorage.applyChanges(resolvedChanges)
            try await cloudSync.pushChanges(resolvedChanges)
            
            lastSyncDate = Date()
            
        } catch {
            syncError = error.localizedDescription
        }
        
        isSyncing = false
    }
}

// MARK: - Local Storage

class WorkoutLocalStorage {
    private let modelContainer: ModelContainer
    
    init() {
        // Initialize SwiftData container
        do {
            self.modelContainer = try ModelContainer(for: WorkoutSession.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    @MainActor
    func saveWorkout(_ workout: WorkoutSession) async throws {
        let modelContext = modelContainer.mainContext
        
        workout.syncVersion += 1
        workout.updatedAt = Date()
        
        modelContext.insert(workout)
        try modelContext.save()
    }
    
    @MainActor
    func fetchWorkouts(for userEmail: String) async throws -> [WorkoutSession] {
        let modelContext = modelContainer.mainContext
        
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { workout in
                workout.userEmail == userEmail && !workout.isDeleted
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    @MainActor
    func getUnsyncedChanges() async -> [SyncableWorkoutSession] {
        let modelContext = modelContainer.mainContext
        
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { workout in
                workout.needsSync == true
            }
        )
        
        do {
            let workouts = try modelContext.fetch(descriptor)
            return workouts.map { SyncableWorkoutSession(from: $0) }
        } catch {
            print("Error fetching unsynced changes: \(error)")
            return []
        }
    }
    
    @MainActor
    func applyChanges(_ changes: [SyncableWorkoutSession]) async throws {
        let modelContext = modelContainer.mainContext
        
        for change in changes {
            if change.isDeleted {
                // Mark as deleted locally
                if let existing = try? modelContext.fetch(FetchDescriptor<WorkoutSession>(
                    predicate: #Predicate<WorkoutSession> { $0.id == change.id }
                )).first {
                    existing.isDeleted = true
                    existing.needsSync = false
                }
            } else {
                // Update or create
                if let existing = try? modelContext.fetch(FetchDescriptor<WorkoutSession>(
                    predicate: #Predicate<WorkoutSession> { $0.id == change.id }
                )).first {
                    // Update existing
                    existing.updateFromSyncable(change)
                    existing.needsSync = false
                } else {
                    // Create new
                    let newWorkout = WorkoutSession(from: change)
                    modelContext.insert(newWorkout)
                }
            }
        }
        
        try modelContext.save()
    }
}

// MARK: - Cloud Sync

class WorkoutCloudSync {
    private let networkManager = NetworkManagerTwo.shared
    private var syncQueue: [WorkoutSession] = []
    
    func queueForSync(_ workout: WorkoutSession) async {
        syncQueue.append(workout)
    }
    
    func fetchServerChanges() async throws -> [SyncableWorkoutSession] {
        // This would call your server API
        // For now, return empty array
        return []
    }
    
    func pushChanges(_ changes: [SyncableWorkoutSession]) async throws {
        // This would push changes to your server
        // For now, just clear the queue
        syncQueue.removeAll()
    }
}

// MARK: - Conflict Resolution

class WorkoutConflictResolver {
    func resolveConflicts(
        local: [SyncableWorkoutSession],
        server: [SyncableWorkoutSession]
    ) async -> [SyncableWorkoutSession] {
        var resolved: [SyncableWorkoutSession] = []
        
        // Create lookup dictionaries
        let localDict = Dictionary(grouping: local, by: { $0.id })
        let serverDict = Dictionary(grouping: server, by: { $0.id })
        
        // Process all unique IDs
        let allIds = Set(localDict.keys).union(serverDict.keys)
        
        for id in allIds {
            let localWorkouts = localDict[id] ?? []
            let serverWorkouts = serverDict[id] ?? []
            
            if let resolvedWorkout = resolveConflict(
                local: localWorkouts.first,
                server: serverWorkouts.first
            ) {
                resolved.append(resolvedWorkout)
            }
        }
        
        return resolved
    }
    
    private func resolveConflict(
        local: SyncableWorkoutSession?,
        server: SyncableWorkoutSession?
    ) -> SyncableWorkoutSession? {
        // Conflict resolution strategy:
        // 1. If only one exists, use that
        // 2. If both exist, use the most recently updated
        // 3. If same timestamp, prefer server (server wins)
        
        guard let local = local else { return server }
        guard let server = server else { return local }
        
        if local.updatedAt > server.updatedAt {
            return local
        } else {
            return server
        }
    }
}

// MARK: - Extensions

extension WorkoutSession {
    func updateFromSyncable(_ syncable: SyncableWorkoutSession) {
        // Update local workout from syncable data
        self.name = syncable.name
        self.startedAt = syncable.startedAt
        self.completedAt = syncable.completedAt
        self.notes = syncable.notes
        self.updatedAt = syncable.updatedAt
        self.syncVersion = syncable.syncVersion
        self.isDeleted = syncable.isDeleted
    }
    
    convenience init(from syncable: SyncableWorkoutSession) {
        self.init(name: syncable.name, userEmail: syncable.userEmail)
        self.id = syncable.id
        self.startedAt = syncable.startedAt
        self.completedAt = syncable.completedAt
        self.notes = syncable.notes
        self.createdAt = syncable.createdAt
        self.updatedAt = syncable.updatedAt
        self.syncVersion = syncable.syncVersion
        self.isDeleted = syncable.isDeleted
    }
} 
