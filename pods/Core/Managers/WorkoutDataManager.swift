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

    private let cloudSync = WorkoutCloudSync()
    private var syncTimer: Timer?
    private var lastKnownContext: ModelContext?
    private var hasDeferredSync = false
    private var rateLimitCooldown: Date?
    private var subscriptionObserver: NSObjectProtocol?
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private init() {
        setupSyncTimer()
        subscriptionObserver = NotificationCenter.default.addObserver(
            forName: .subscriptionUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearRateLimitCooldown(trigger: "subscriptionUpdated")
        }
    }

    deinit {
        if let observer = subscriptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public API
    
    /// Save workout with automatic local storage and cloud sync
    func saveWorkout(_ workout: WorkoutSession, context: ModelContext) async throws {
        registerContext(context)
        insertIfNeeded(workout, context: context)
        try saveContextIfNeeded(context)

        await cloudSync.queueForSync(workout)
    }

    /// Fetch workouts with local-first approach
    func fetchWorkouts(for userEmail: String, context: ModelContext) async throws -> [WorkoutSession] {
        registerContext(context)

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { workout in
                workout.userEmail == userEmail && workout.isDeleted == false
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        let localWorkouts = try context.fetch(descriptor)

        // Trigger background sync to refresh data
        Task { @MainActor [weak self] in
            await self?.syncPendingDataUsingStoredContext()
        }

        return localWorkouts
    }

    /// Fetch recent workouts from the server and merge into the local store.
    func refreshServerWorkouts(daysBack: Int, context: ModelContext) async throws {
        registerContext(context)

        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail"), !userEmail.isEmpty else {
            return
        }

        let remoteWorkouts = try await cloudSync.fetchServerChanges(for: userEmail, daysBack: daysBack)
        guard !remoteWorkouts.isEmpty else { return }

        try applyChanges(remoteWorkouts, context: context)
        try saveContextIfNeeded(context)
    }

    func workoutSession(remoteId: Int, context: ModelContext) throws -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { workout in
                workout.remoteId == remoteId && workout.isDeleted == false
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    /// Manual sync trigger
    func syncNow(context: ModelContext) async {
        registerContext(context)
        await syncPendingData(context: context)
    }

    func performDeferredSyncIfNeeded(context: ModelContext) async {
        guard hasDeferredSync else { return }
        registerContext(context)
        await syncPendingData(context: context)
    }

    func clearRateLimitCooldown(trigger: String = "manual") {
        if let cooldown = rateLimitCooldown {
            print("🔓 Workout sync cooldown cleared (\(trigger)) – previous cooldown was \(cooldown)")
        }
        rateLimitCooldown = nil
        hasDeferredSync = false
        guard !isSyncing else { return }
        Task { [weak                                                                                                                                                                     self] in
            await self?.syncPendingDataUsingStoredContext()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSyncTimer() {
        // Sync every 5 minutes when app is active
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.syncPendingDataUsingStoredContext()
            }
        }
    }
    
    @MainActor
    private func syncPendingData(context: ModelContext) async {
        guard !isSyncing else { return }

        if let cooldown = rateLimitCooldown, cooldown > Date() {
            print("⏳ Workout sync skipped – in cooldown until \(cooldown)")
            return
        }

        if WorkoutManager.shared.isDisplayingSummary || WorkoutManager.shared.isWorkoutViewActive {
            hasDeferredSync = true
            return
        }

        if hasDeferredSync {
            print("🔄 Executing deferred workout sync")
            hasDeferredSync = false
        }

        assert(Thread.isMainThread, "ModelContext must be accessed on main thread")
        isSyncing = true
        syncError = nil
        registerContext(context)

        do {
            let localChanges = try getUnsyncedChanges(context: context)
            var didSync = !localChanges.isEmpty

            for change in localChanges {
                if let workout = try fetchWorkout(by: change.id, context: context) {
                    await cloudSync.queueForSync(workout)
                }
            }

            // Push local changes to server (no fetch needed - matches food logging pattern)
            // This prevents fetching all 200 workouts and creating duplicates
            let syncedWorkouts = try await cloudSync.pushQueuedChanges()
            didSync = didSync || !syncedWorkouts.isEmpty
            try saveContextIfNeeded(context)
            lastSyncDate = Date()
            rateLimitCooldown = nil

            if didSync {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LogsChangedNotification"),
                    object: nil
                )
                // Post workout-specific notification with workout data for optimistic UI update
                if !syncedWorkouts.isEmpty {
                    NotificationCenter.default.post(
                        name: .workoutDataChanged,
                        object: nil,
                        userInfo: ["workouts": syncedWorkouts]
                    )
                }
            }
        } catch {
            handleSyncError(error)
        }

        isSyncing = false
    }

    private func syncPendingDataUsingStoredContext() async {
        guard let context = lastKnownContext else { return }
        await syncPendingData(context: context)
    }

    private func registerContext(_ context: ModelContext) {
        lastKnownContext = context
    }

    private func handleSyncError(_ error: Error) {
        syncError = error.localizedDescription

        if let networkError = error as? NetworkManagerTwo.NetworkError {
            switch networkError {
            case .serverError(let message) where message.lowercased().contains("workout limit"):
                rateLimitCooldown = Date().addingTimeInterval(3600) // retry after an hour
                hasDeferredSync = false
                postRateLimitNotification(message)
                return
            case .requestFailed(statusCode: 429):
                rateLimitCooldown = Date().addingTimeInterval(3600)
                hasDeferredSync = false
                postRateLimitNotification("Workout limit reached. Please try again later.")
                return
            default:
                break
            }
        }

        hasDeferredSync = true
    }

    private func postRateLimitNotification(_ message: String) {
        NotificationCenter.default.post(
            name: .workoutSyncRateLimited,
            object: nil,
            userInfo: ["message": message]
        )
    }

    private func insertIfNeeded(_ workout: WorkoutSession, context: ModelContext) {
        if workout.modelContext === context { return }
        if workout.persistentModelID == nil {
            context.insert(workout)
        }
    }

    private func getUnsyncedChanges(context: ModelContext) throws -> [SyncableWorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { workout in
                workout.needsSync == true
            }
        )

        let workouts = try context.fetch(descriptor)
        return workouts.map { SyncableWorkoutSession(from: $0) }
    }

    private func applyChanges(_ changes: [SyncableWorkoutSession], context: ModelContext) throws {
        for change in changes {
            if change.isDeleted {
                if let remoteId = change.remoteId {
                    let descriptor = FetchDescriptor<WorkoutSession>(
                        predicate: #Predicate<WorkoutSession> { $0.remoteId == remoteId }
                    )
                    if let existing = try context.fetch(descriptor).first {
                        existing.isDeleted = true
                        existing.needsSync = false
                        continue
                    }
                }

                let byId = FetchDescriptor<WorkoutSession>(
                    predicate: #Predicate<WorkoutSession> { $0.id == change.id }
                )
                if let existing = try context.fetch(byId).first {
                    existing.isDeleted = true
                    existing.needsSync = false
                }
            } else {
                if let remoteId = change.remoteId {
                    let descriptor = FetchDescriptor<WorkoutSession>(
                        predicate: #Predicate<WorkoutSession> { $0.remoteId == remoteId }
                    )
                    if let existing = try context.fetch(descriptor).first {
                        existing.updateFromSyncable(change)
                        continue
                    }
                }

                let byId = FetchDescriptor<WorkoutSession>(
                    predicate: #Predicate<WorkoutSession> { $0.id == change.id }
                )
                if let existing = try context.fetch(byId).first {
                    existing.updateFromSyncable(change)
                } else {
                    let newWorkout = WorkoutSession(from: change)
                    newWorkout.needsSync = false
                    context.insert(newWorkout)
                }
            }
        }
    }

    private func saveContextIfNeeded(_ context: ModelContext) throws {
        guard context.hasChanges else { return }

        do {
            try context.save()
            print("✅ ModelContext saved successfully")
        } catch {
            print("❌ ModelContext save failed: \(error)")
            context.rollback()
            throw error
        }
    }

    private func fetchWorkout(by id: UUID, context: ModelContext) throws -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
}

// MARK: - Cloud Sync

@MainActor
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

    func fetchServerChanges(for userEmail: String, daysBack: Int) async throws -> [SyncableWorkoutSession] {
        // Only fetch recent workouts to prevent syncing all 200+ historical workouts
        // This prevents creating duplicate workouts and reduces network overhead
        // NOTE: This method is kept for explicit sync operations (e.g., app launch, pull-to-refresh)
        // but is NO LONGER called during routine workout completion sync
        let response = try await networkManager.fetchServerWorkouts(userEmail: userEmail, daysBack: daysBack)
        return response.workouts.map { SyncableWorkoutSession(serverWorkout: $0) }
    }

    private func currentUnitsSystem() -> UnitsSystem {
        if let saved = UserDefaults.standard.string(forKey: "unitsSystem"),
           let units = UnitsSystem(rawValue: saved) {
            return units
        }
        return .imperial
    }

    /// Convert a WorkoutSession to a CombinedLog for optimistic UI updates
    /// Matches the food logging pattern where we create CombinedLog from server response
    private func workoutToCombinedLog(_ workout: WorkoutSession) -> CombinedLog {
        let rawDuration = workout.totalDuration ?? workout.duration ?? 0
        let durationMinutes = Int(rawDuration / 60)
        let durationSeconds = Int(rawDuration)

        // Calculate total volume from exercises (sum of reps * weight for all sets)
        let totalVolume = workout.exercises.reduce(0.0) { total, exercise in
            let exerciseVolume = exercise.sets.reduce(0.0) { setTotal, set in
                let reps = Double(set.actualReps ?? set.targetReps ?? 0)
                let weight = set.actualWeight ?? set.targetWeight ?? 0
                return setTotal + (reps * weight)
            }
            return total + exerciseVolume
        }

        let unitsSystem = currentUnitsSystem()

        // Estimate calories burned using same calculation as WorkoutSummary
        let profile = UserProfileService.shared.profileData
        let estimatedCalories = WorkoutCalculationService.shared.estimateCaloriesBurned(
            volume: totalVolume,
            duration: rawDuration,
            profile: profile,
            unitsSystem: unitsSystem
        )

        // Debug logging to compare with WorkoutSummary calculation
        print("🔥 workoutToCombinedLog Calories Calculation:")
        print("   - Workout: \(workout.name)")
        print("   - Total Volume: \(String(format: "%.1f", totalVolume)) \(unitsSystem == .metric ? "kg" : "lbs")")
        print("   - Duration: \(Int(rawDuration))s (\(Int(rawDuration / 60))min)")
        print("   - Body Weight: \(profile?.currentWeightKg ?? 0)kg")
        print("   - Units System: \(unitsSystem)")
        print("   - Estimated Calories: \(estimatedCalories)")

        let workoutSummary = WorkoutSummary(
            id: workout.remoteId ?? -1,  // Use remoteId from server, or -1 if not synced yet
            title: workout.name,
            durationMinutes: durationMinutes,
            durationSeconds: durationSeconds,  // Pass seconds for < 1 min display
            exercisesCount: workout.exercises.count,
            status: workout.completedAt != nil ? "completed" : "in_progress",
            scheduledAt: workout.startedAt
        )

        return CombinedLog(
            type: .workout,
            status: "success",
            calories: Double(estimatedCalories),  // Use calculated calories, not 0
            message: workout.name,
            foodLogId: nil,
            food: nil,
            mealType: nil,
            mealLogId: nil,
            meal: nil,
            mealTime: nil,
            scheduledAt: workout.startedAt,
            recipeLogId: nil,
            recipe: nil,
            servingsConsumed: nil,
            activityId: nil,
            activity: nil,
            workoutLogId: workout.remoteId,
            workout: workoutSummary,
            logDate: nil,
            dayOfWeek: nil,
            isOptimistic: workout.remoteId == nil  // Mark as optimistic until server confirms
        )
    }

    /// Public helper to create a CombinedLog from a WorkoutSession for optimistic dashboard insert
    func combinedLog(for workout: WorkoutSession) -> CombinedLog {
        return workoutToCombinedLog(workout)
    }

    func pushQueuedChanges() async throws -> [CombinedLog] {
        guard !syncQueue.isEmpty else { return [] }

        var syncedWorkouts: [CombinedLog] = []

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

            // Convert to CombinedLog for optimistic UI update (matches food logging pattern)
            let combinedLog = workoutToCombinedLog(workout)
            syncedWorkouts.append(combinedLog)
        }

        syncQueue.removeAll()
        return syncedWorkouts
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
                    let trackingType = set.trackingType
                    let repsValue: Int? = {
                        guard let trackingType else { return set.actualReps ?? set.targetReps }
                        switch trackingType {
                        case .repsWeight, .repsOnly:
                            return set.actualReps ?? set.targetReps
                        case .rounds:
                            return set.actualReps ?? set.targetReps
                        case .timeOnly, .holdTime, .timeDistance:
                            return nil
                        }
                    }()

                    let roundsCompleted: Int? = {
                        guard let trackingType else { return nil }
                        if trackingType == .rounds {
                            return set.actualReps ?? set.targetReps
                        }
                        return nil
                    }()

                    let durationSeconds = set.durationSeconds
                    let distanceMeters = set.distanceMeters

                    return NetworkManagerTwo.WorkoutRequest.ExerciseSet(
                        trackingType: trackingType?.rawValue,
                        weightKg: set.actualWeight ?? set.targetWeight,
                        reps: repsValue,
                        durationSeconds: durationSeconds,
                        restSeconds: set.restSeconds,
                        distanceMeters: distanceMeters,
                        distanceUnit: nil,
                        paceSecondsPerKm: set.paceSecondsPerKm,
                        rpe: set.rpe,
                        heartRateBpm: set.heartRateBpm,
                        intensityZone: set.intensityZone,
                        stretchIntensity: set.stretchIntensity,
                        rangeOfMotionNotes: set.rangeOfMotionNotes,
                        roundsCompleted: set.roundsCompleted ?? roundsCompleted,
                        isWarmup: false,
                        isCompleted: set.completed,
                        notes: set.notes
                    )
                }
            )
        }

        // Use current user's email from UserDefaults to prevent syncing to wrong account
        // Fallback to workout's stored email only if UserDefaults is empty (shouldn't happen)
        let currentUserEmail = UserDefaults.standard.string(forKey: "userEmail") ?? workout.userEmail

        // Convert blocks to network request format for server-side block visibility
        let blockRequests: [NetworkManagerTwo.WorkoutRequest.Block]? = workout.blocks?.enumerated().map { index, block in
            NetworkManagerTwo.WorkoutRequest.Block(
                orderIndex: index + 1,
                blockType: block.type.rawValue,
                rounds: block.rounds,
                restBetweenExercisesSec: block.restBetweenExercises,
                restBetweenRoundsSec: block.restBetweenRounds,
                weightNormalization: block.weightNormalization?.rawValue,
                timingConfig: block.timingConfig.map {
                    NetworkManagerTwo.WorkoutRequest.TimingConfig(
                        prepareSec: $0.prepareSec,
                        transitionSec: $0.transitionSec,
                        autoAdvance: $0.autoAdvance
                    )
                },
                exercises: block.exercises.enumerated().map { exIndex, blockExercise in
                    NetworkManagerTwo.WorkoutRequest.BlockExerciseRequest(
                        orderIndex: exIndex + 1,
                        exerciseId: blockExercise.exercise.id,
                        exerciseName: blockExercise.exercise.name,
                        schemeType: blockExercise.schemeType.rawValue,
                        repScheme: blockExercise.repScheme.map {
                            NetworkManagerTwo.WorkoutRequest.RepSchemeRequest(
                                sets: $0.sets,
                                reps: $0.reps,
                                rir: $0.rir,
                                restSec: $0.restSec
                            )
                        },
                        intervalScheme: blockExercise.intervalScheme.map {
                            NetworkManagerTwo.WorkoutRequest.IntervalSchemeRequest(
                                workSec: $0.workSec,
                                restSec: $0.restSec,
                                targetReps: $0.targetReps
                            )
                        }
                    )
                }
            )
        }

        return NetworkManagerTwo.WorkoutRequest(
            userEmail: currentUserEmail,
            name: workout.name,
            status: status,
            isTemplate: nil,
            startedAt: isoFormatter.string(from: workout.startedAt),
            completedAt: workout.completedAt.map { isoFormatter.string(from: $0) },
            scheduledDate: scheduledDate,
            estimatedDurationMinutes: estimatedMinutes,
            actualDurationMinutes: actualMinutes,
            notes: workout.notes,
            exercises: exercises,
            blocks: blockRequests
        )
    }
}

extension Notification.Name {
    static let workoutSyncRateLimited = Notification.Name("WorkoutSyncRateLimited")
    static let workoutDataChanged = Notification.Name("WorkoutDataChanged")
}

// MARK: - Conflict Resolution

// MARK: - Extensions

private struct ExerciseIdentity: Hashable {
    let exerciseId: Int
    let orderIndex: Int
}

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

        var existingById: [UUID: ExerciseInstance] = Dictionary(uniqueKeysWithValues: self.exercises.map { ($0.id, $0) })
        var existingByIdentity: [ExerciseIdentity: ExerciseInstance] = [:]
        for exercise in self.exercises {
            let identity = ExerciseIdentity(exerciseId: exercise.exerciseId, orderIndex: exercise.orderIndex)
            existingByIdentity[identity] = exercise
        }

        var updatedExercises: [ExerciseInstance] = []
        updatedExercises.reserveCapacity(syncable.exercises.count)

        for (index, exerciseSync) in syncable.exercises.enumerated() {
            let identity = ExerciseIdentity(exerciseId: exerciseSync.exerciseId, orderIndex: exerciseSync.orderIndex)

            var exerciseInstance: ExerciseInstance

            if let existing = existingById[exerciseSync.id] {
                exerciseInstance = existing
                existingById.removeValue(forKey: exerciseSync.id)
                existingByIdentity.removeValue(forKey: identity)
            } else if let existing = existingByIdentity.removeValue(forKey: identity) {
                exerciseInstance = existing
                existingById.removeValue(forKey: existing.id)
            } else {
                exerciseInstance = ExerciseInstance(
                    exerciseId: exerciseSync.exerciseId,
                    exerciseName: exerciseSync.exerciseName,
                    exerciseType: "strength",
                    bodyPart: exerciseSync.bodyPart,
                    equipment: "",
                    target: "",
                    orderIndex: exerciseSync.orderIndex
                )
            }

            exerciseInstance.updateFromSyncable(exerciseSync, parent: self)

            if exerciseInstance.orderIndex == 0 {
                exerciseInstance.orderIndex = index
            }

            updatedExercises.append(exerciseInstance)
        }

        // Remove exercises no longer present on the server
        if let context = self.modelContext {
            for orphan in existingById.values {
                if orphan.persistentModelID != nil {
                    context.delete(orphan)
                } else {
                    orphan.workoutSession = nil
                }
            }
        } else {
            for orphan in existingById.values {
                orphan.workoutSession = nil
            }
        }

        self.exercises = updatedExercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    convenience init(from syncable: SyncableWorkoutSession) {
        self.init(name: syncable.name, userEmail: syncable.userEmail)
        self.id = syncable.id
        self.createdAt = syncable.createdAt
        updateFromSyncable(syncable)
    }
}

extension ExerciseInstance {
    fileprivate func updateFromSyncable(_ syncable: SyncableExerciseInstance, parent: WorkoutSession) {
        exerciseId = syncable.exerciseId
        exerciseName = syncable.exerciseName
        bodyPart = syncable.bodyPart
        if exerciseType.isEmpty {
            exerciseType = "strength"
        }
        if equipment.isEmpty {
            equipment = ""
        }
        if target.isEmpty {
            target = ""
        }
        orderIndex = syncable.orderIndex
        workoutSession = parent

        let context = parent.modelContext ?? self.modelContext

        if let context, self.modelContext == nil {
            context.insert(self)
        }

        let setsList = Array(sets)
        var existingBySetNumber: [Int: SetInstance] = Dictionary(uniqueKeysWithValues: setsList.map { ($0.setNumber, $0) })
        var updatedSets: [SetInstance] = []
        updatedSets.reserveCapacity(syncable.sets.count)

        for setSync in syncable.sets {
            let setInstance: SetInstance

            if let existing = existingBySetNumber.removeValue(forKey: setSync.setNumber) {
                setInstance = existing
            } else {
                let newSet = SetInstance(setNumber: setSync.setNumber, targetReps: setSync.targetReps, targetWeight: setSync.targetWeight)
                if let context, newSet.modelContext == nil {
                    context.insert(newSet)
                }
                setInstance = newSet
            }

            if let context, setInstance.modelContext == nil {
                context.insert(setInstance)
            }

            setInstance.setNumber = setSync.setNumber
            setInstance.targetReps = setSync.targetReps
            setInstance.targetWeight = setSync.targetWeight
            setInstance.actualReps = setSync.actualReps
            setInstance.actualWeight = setSync.actualWeight
            setInstance.isCompleted = setSync.completed
            setInstance.completedAt = setSync.completedAt
            setInstance.durationSeconds = setSync.durationSeconds
            setInstance.distanceMeters = setSync.distanceMeters
            setInstance.notes = setSync.notes
            setInstance.exerciseInstance = self

            updatedSets.append(setInstance)
        }

        if let context {
            for orphan in existingBySetNumber.values {
                if orphan.modelContext == context || orphan.persistentModelID != nil {
                    context.delete(orphan)
                } else {
                    orphan.exerciseInstance = nil
                }
            }
        } else {
            for orphan in existingBySetNumber.values {
                orphan.exerciseInstance = nil
            }
        }

        sets = updatedSets.sorted { $0.setNumber < $1.setNumber }
    }
}
