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
    let remoteId: Int?
    let userEmail: String
    let name: String
    let startedAt: Date
    let completedAt: Date?
    let exercises: [SyncableExerciseInstance]
    let notes: String?
    let estimatedDurationMinutes: Int
    let actualDurationMinutes: Int?

    // Sync metadata
    let createdAt: Date
    let updatedAt: Date
    let syncVersion: Int
    let isDeleted: Bool

    init(from workout: WorkoutSession) {
        self.id = workout.id
        self.remoteId = workout.remoteId
        self.userEmail = workout.userEmail
        self.name = workout.name
        self.startedAt = workout.startedAt
        self.completedAt = workout.completedAt
        self.exercises = workout.exercises.map { SyncableExerciseInstance(from: $0) }
        self.notes = workout.notes

        let durationMinutes = Int((workout.totalDuration ?? workout.duration ?? 0) / 60)
        self.estimatedDurationMinutes = max(durationMinutes, 0)
        self.actualDurationMinutes = durationMinutes > 0 ? durationMinutes : nil

        self.createdAt = workout.createdAt
        self.updatedAt = workout.updatedAt
        self.syncVersion = workout.syncVersion
        self.isDeleted = workout.isDeleted
    }

    init(serverWorkout: NetworkManagerTwo.WorkoutResponse.Workout, localId: UUID? = nil) {
        self.id = localId ?? UUID()
        self.remoteId = serverWorkout.id
        self.userEmail = serverWorkout.userEmail
        self.name = serverWorkout.name
        self.startedAt = serverWorkout.startedAt ?? Date()
        self.completedAt = serverWorkout.completedAt
        self.notes = serverWorkout.notes
        self.estimatedDurationMinutes = serverWorkout.estimatedDurationMinutes ?? 0
        self.actualDurationMinutes = serverWorkout.actualDurationMinutes
        self.createdAt = serverWorkout.createdAt ?? Date()
        self.updatedAt = serverWorkout.updatedAt ?? Date()
        self.syncVersion = serverWorkout.syncVersion ?? 1
        self.isDeleted = false

        self.exercises = serverWorkout.exercises.enumerated().map { index, exercise in
            SyncableExerciseInstance(serverExercise: exercise, orderFallback: index)
        }
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

    init(serverExercise: NetworkManagerTwo.WorkoutResponse.Exercise, orderFallback: Int) {
        self.id = UUID()
        self.exerciseId = serverExercise.exerciseId
        self.exerciseName = serverExercise.exerciseName
        self.bodyPart = ""
        self.orderIndex = serverExercise.orderIndex ?? orderFallback
        self.sets = serverExercise.sets.enumerated().map { index, set in
            SyncableSetInstance(serverSet: set, fallbackNumber: index + 1)
        }
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
    let durationSeconds: Int?
    let distanceMeters: Double?
    let notes: String?

    init(from set: SetInstance) {
        self.id = set.id
        self.setNumber = set.setNumber
        self.targetReps = set.targetReps
        self.targetWeight = set.targetWeight
        self.actualReps = set.actualReps
        self.actualWeight = set.actualWeight
        self.completed = set.completed
        self.completedAt = set.completedAt
        self.durationSeconds = set.durationSeconds
        self.distanceMeters = set.distanceMeters
        self.notes = set.notes
    }

    init(serverSet: NetworkManagerTwo.WorkoutResponse.ExerciseSet, fallbackNumber: Int) {
        self.id = UUID()
        self.setNumber = serverSet.setNumber ?? fallbackNumber
        self.targetReps = serverSet.reps ?? 0
        self.targetWeight = serverSet.weightKg
        self.actualReps = serverSet.reps
        self.actualWeight = serverSet.weightKg
        self.completed = serverSet.isCompleted ?? true
        self.completedAt = nil
        self.durationSeconds = serverSet.durationSeconds
        self.distanceMeters = serverSet.distanceMeters
        self.notes = serverSet.notes
    }
}

// MARK: - Workout Data Manager

@MainActor
class WorkoutDataManager: ObservableObject {
    static let shared = WorkoutDataManager()
    
    private let localStorage = WorkoutLocalStorage()
    private let cloudSync = WorkoutCloudSync()
    
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
            let localChanges = await localStorage.getUnsyncedChanges()

            for change in localChanges {
                if let workout = await localStorage.fetchWorkout(by: change.id) {
                    await cloudSync.queueForSync(workout)
                }
            }
            let userEmail = localChanges.first?.userEmail ?? UserDefaults.standard.string(forKey: "userEmail")

            if let userEmail {
                let serverChanges = try await cloudSync.fetchServerChanges(for: userEmail)
                try await localStorage.applyChanges(serverChanges)
            }

            try await cloudSync.pushQueuedChanges()
            try await localStorage.saveContextIfNeeded()
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
        // Initialize SwiftData container with migration handling
        let container: ModelContainer
        
        do {
            // Create a dedicated store location for workout data to avoid conflicts
            let storeURL = URL.documentsDirectory.appending(path: "WorkoutData.store")
            let configuration = ModelConfiguration(url: storeURL)
            container = try ModelContainer(for: WorkoutSession.self, configurations: configuration)
        } catch {
            // Handle migration errors by clearing the store and starting fresh
            print("⚠️ SwiftData migration failed: \(error)")
            print("🔄 Clearing existing workout data and starting fresh...")
            
            do {
                // Clear the existing store and create a new one
                let storeURL = URL.documentsDirectory.appending(path: "WorkoutData.store")
                let configuration = ModelConfiguration(url: storeURL)
                try Self.clearExistingStore(at: storeURL)
                container = try ModelContainer(for: WorkoutSession.self, configurations: configuration)
                print("✅ Successfully created new WorkoutSession container")
            } catch {
                fatalError("Failed to initialize ModelContainer even after clearing store: \(error)")
            }
        }
        
        // Assign the successfully created container
        self.modelContainer = container
    }
    
    /// Clear existing SwiftData store to handle migration issues
    private static func clearExistingStore(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let storeDirectory = storeURL.deletingLastPathComponent()
        let storeName = storeURL.deletingPathExtension().lastPathComponent
        
        // Define all possible store files
        let storeFiles = [
            storeURL,                                                    // main store
            storeDirectory.appending(path: "\(storeName).store-wal"),   // WAL file
            storeDirectory.appending(path: "\(storeName).store-shm")    // SHM file
        ]
        
        for file in storeFiles {
            if fileManager.fileExists(atPath: file.path) {
                do {
                    try fileManager.removeItem(at: file)
                    print("🗑️ Removed existing store file: \(file.lastPathComponent)")
                } catch {
                    print("⚠️ Failed to remove \(file.lastPathComponent): \(error)")
                }
            }
        }
    }
    
    @MainActor
    func saveWorkout(_ workout: WorkoutSession) async throws {
        let modelContext = modelContainer.mainContext

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
                if let remoteId = change.remoteId,
                   let existing = try? modelContext.fetch(FetchDescriptor<WorkoutSession>(
                        predicate: #Predicate<WorkoutSession> { $0.remoteId == remoteId }
                   )).first {
                    existing.isDeleted = true
                    existing.needsSync = false
                    continue
                }

                if let existing = try? modelContext.fetch(FetchDescriptor<WorkoutSession>(
                    predicate: #Predicate<WorkoutSession> { $0.id == change.id }
                )).first {
                    existing.isDeleted = true
                    existing.needsSync = false
                }
            } else {
                if let remoteId = change.remoteId,
                   let existing = try? modelContext.fetch(FetchDescriptor<WorkoutSession>(
                        predicate: #Predicate<WorkoutSession> { $0.remoteId == remoteId }
                   )).first {
                    existing.updateFromSyncable(change)
                    continue
                }

                if let existing = try? modelContext.fetch(FetchDescriptor<WorkoutSession>(
                    predicate: #Predicate<WorkoutSession> { $0.id == change.id }
                )).first {
                    existing.updateFromSyncable(change)
                } else {
                    let newWorkout = WorkoutSession(from: change)
                    newWorkout.needsSync = false
                    modelContext.insert(newWorkout)
                }
            }
        }

        try modelContext.save()
    }

    @MainActor
    func saveContextIfNeeded() async throws {
        let modelContext = modelContainer.mainContext
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    @MainActor
    func fetchWorkout(by id: UUID) async -> WorkoutSession? {
        let modelContext = modelContainer.mainContext
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

// MARK: - Cloud Sync

class WorkoutCloudSync {
    private let networkManager = NetworkManagerTwo.shared
    private var syncQueue: [WorkoutSession] = []
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func queueForSync(_ workout: WorkoutSession) async {
        if let existingIndex = syncQueue.firstIndex(where: { $0.id == workout.id }) {
            syncQueue[existingIndex] = workout
        } else {
            syncQueue.append(workout)
        }
    }

    func fetchServerChanges(for userEmail: String) async throws -> [SyncableWorkoutSession] {
        let response = try await networkManager.fetchServerWorkouts(userEmail: userEmail)
        return response.workouts.map { SyncableWorkoutSession(serverWorkout: $0) }
    }

    func pushQueuedChanges() async throws {
        guard !syncQueue.isEmpty else { return }

        for workout in syncQueue {
            if workout.isDeleted {
                if let remoteId = workout.remoteId {
                    try await networkManager.deleteWorkout(sessionId: remoteId, userEmail: workout.userEmail)
                }
                workout.needsSync = false
                continue
            }

            let payload = makePayload(from: workout)
            let response: NetworkManagerTwo.WorkoutResponse.Workout

            if let remoteId = workout.remoteId {
                response = try await networkManager.updateWorkout(sessionId: remoteId, payload: payload)
            } else {
                response = try await networkManager.createWorkout(payload: payload)
            }

            let syncable = SyncableWorkoutSession(serverWorkout: response, localId: workout.id)
            workout.updateFromSyncable(syncable)
            workout.createdAt = syncable.createdAt
            workout.updatedAt = syncable.updatedAt
            workout.remoteId = response.id
            workout.needsSync = false
        }

        syncQueue.removeAll()
    }

    private func makePayload(from workout: WorkoutSession) -> NetworkManagerTwo.WorkoutRequest {
        let status = workout.completedAt != nil ? "completed" : "in_progress"
        let estimatedMinutes = max(Int((workout.totalDuration ?? workout.duration ?? 0) / 60), 0)
        let actualMinutes = workout.completedAt != nil ? estimatedMinutes : nil
        let scheduledDate = isoFormatter.string(from: workout.startedAt)

        let exercises = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }.map { exercise in
            NetworkManagerTwo.WorkoutRequest.Exercise(
                exerciseId: exercise.exerciseId,
                exerciseName: exercise.exerciseName,
                orderIndex: exercise.orderIndex,
                targetSets: exercise.totalSets,
                isCompleted: exercise.isCompleted,
                sets: exercise.sets.sorted { $0.setNumber < $1.setNumber }.map { set in
                    NetworkManagerTwo.WorkoutRequest.ExerciseSet(
                        weightKg: set.actualWeight ?? set.targetWeight,
                        reps: set.actualReps ?? set.targetReps,
                        durationSeconds: nil,
                        restSeconds: nil,
                        distanceMeters: nil,
                        distanceUnit: nil,
                        paceSecondsPerKm: nil,
                        rpe: nil,
                        heartRateBpm: nil,
                        intensityZone: nil,
                        stretchIntensity: nil,
                        rangeOfMotionNotes: nil,
                        roundsCompleted: nil,
                        isWarmup: false,
                        isCompleted: set.completed,
                        notes: set.notes
                    )
                }
            )
        }

        return NetworkManagerTwo.WorkoutRequest(
            userEmail: workout.userEmail,
            name: workout.name,
            status: status,
            startedAt: isoFormatter.string(from: workout.startedAt),
            completedAt: workout.completedAt.map { isoFormatter.string(from: $0) },
            scheduledDate: scheduledDate,
            estimatedDurationMinutes: estimatedMinutes,
            actualDurationMinutes: actualMinutes,
            notes: workout.notes,
            exercises: exercises
        )
    }
}

// MARK: - Conflict Resolution

// MARK: - Extensions

extension WorkoutSession {
    func updateFromSyncable(_ syncable: SyncableWorkoutSession) {
        self.remoteId = syncable.remoteId
        self.name = syncable.name
        self.userEmail = syncable.userEmail
        self.startedAt = syncable.startedAt
        self.completedAt = syncable.completedAt
        self.notes = syncable.notes
        self.totalDuration = syncable.completedAt?.timeIntervalSince(syncable.startedAt)
        self.createdAt = syncable.createdAt
        self.updatedAt = syncable.updatedAt
        self.syncVersion = syncable.syncVersion
        self.isDeleted = syncable.isDeleted
        self.needsSync = false

        // Replace exercises with server copy
        self.exercises.removeAll()
        for (index, exerciseSync) in syncable.exercises.enumerated() {
            let exerciseInstance = ExerciseInstance(
                exerciseId: exerciseSync.exerciseId,
                exerciseName: exerciseSync.exerciseName,
                exerciseType: "strength",
                bodyPart: exerciseSync.bodyPart,
                equipment: "",
                target: "",
                orderIndex: exerciseSync.orderIndex
            )
            exerciseInstance.workoutSession = self

            exerciseInstance.sets = exerciseSync.sets.map { setSync in
                let setInstance = SetInstance(setNumber: setSync.setNumber, targetReps: setSync.targetReps, targetWeight: setSync.targetWeight)
                setInstance.actualReps = setSync.actualReps
                setInstance.actualWeight = setSync.actualWeight
                setInstance.isCompleted = setSync.completed
                setInstance.completedAt = setSync.completedAt
                setInstance.exerciseInstance = exerciseInstance
                setInstance.durationSeconds = setSync.durationSeconds
                setInstance.distanceMeters = setSync.distanceMeters
                setInstance.notes = setSync.notes
                return setInstance
            }

            if exerciseInstance.orderIndex == 0 {
                exerciseInstance.orderIndex = index
            }
            self.exercises.append(exerciseInstance)
        }

        self.exercises.sort { $0.orderIndex < $1.orderIndex }
    }
    
    convenience init(from syncable: SyncableWorkoutSession) {
        self.init(name: syncable.name, userEmail: syncable.userEmail)
        self.id = syncable.id
        self.createdAt = syncable.createdAt
        updateFromSyncable(syncable)
    }
}
