//
//  WorkoutManager.swift
//  Pods
//
//  Created by Dimi Nunez on 6/14/25.
//

import SwiftUI
import Foundation
import Combine
import SwiftData

// Core workout types are now in WorkoutModels.swift
// Dynamic programming types are in DynamicWorkoutModels.swift
// Note: WorkoutSessionFeedback is used by adaptNextWorkout method
// workout manager file

// MARK: - Workout Duration Enum
enum WorkoutDuration: String, CaseIterable, Codable {
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case fortyFiveMinutes = "45m"
    case oneHour = "1h"
    case oneAndHalfHours = "1.5h"
    case twoHours = "2h"
    
    var displayValue: String {
        return rawValue
    }
    
    var minutes: Int {
        switch self {
        case .fifteenMinutes: return 15
        case .thirtyMinutes: return 30
        case .fortyFiveMinutes: return 45
        case .oneHour: return 60
        case .oneAndHalfHours: return 90
        case .twoHours: return 120
        }
    }
    
    static func fromMinutes(_ minutes: Int) -> WorkoutDuration {
        switch minutes {
        case 0..<20: return .fifteenMinutes
        case 20..<40: return .thirtyMinutes
        case 40..<55: return .fortyFiveMinutes
        case 55..<75: return .oneHour
        case 75..<105: return .oneAndHalfHours
        default: return .twoHours
        }
    }
}

// MARK: - Error Types
enum WorkoutGenerationError: LocalizedError {
    case noUserEmail
    case generationFailed(String)
    case noMuscleGroups
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .noUserEmail:
            return "User not logged in"
        case .generationFailed(let message):
            return "Workout generation failed: \(message)"
        case .noMuscleGroups:
            return "No muscle groups available for workout"
        case .serviceUnavailable:
            return "Workout service temporarily unavailable"
        }
    }
}

// MARK: - Workout Generation Parameters
struct WorkoutGenerationParameters {
    let duration: WorkoutDuration
    let fitnessGoal: FitnessGoal
    let fitnessLevel: ExperienceLevel
    let flexibilityPreferences: FlexibilityPreferences
    let customTargetMuscles: [String]?
    let customEquipment: [Equipment]?
    
    init(duration: WorkoutDuration,
         fitnessGoal: FitnessGoal,
         fitnessLevel: ExperienceLevel,
         flexibilityPreferences: FlexibilityPreferences,
         customTargetMuscles: [String]? = nil,
         customEquipment: [Equipment]? = nil) {
        self.duration = duration
        self.fitnessGoal = fitnessGoal
        self.fitnessLevel = fitnessLevel
        self.flexibilityPreferences = flexibilityPreferences
        self.customTargetMuscles = customTargetMuscles
        self.customEquipment = customEquipment
    }
}

// MARK: - Enhanced WorkoutManager (Global State)
@MainActor
class WorkoutManager: ObservableObject {
    static let shared = WorkoutManager()
    
    // MARK: - Core Workout State (private(set) for controlled access)
    @Published private(set) var todayWorkout: TodayWorkout?
    @Published private(set) var currentWorkout: TodayWorkout? // Active workout in progress
    @Published private(set) var isGeneratingWorkout = false
    @Published private(set) var generationMessage = "Creating your workout..."
    @Published private(set) var generationError: WorkoutGenerationError?
    @Published private(set) var completedWorkoutSummary: CompletedWorkoutSummary?
    @Published private(set) var isDisplayingSummary: Bool = false
    @Published private(set) var isWorkoutViewActive: Bool = false

    // MARK: - Workout Log Card Display (similar to FoodManager pattern)
    @Published var showWorkoutLogCard = false
    @Published var lastCompletedWorkout: CompletedWorkoutSummary?
    
    // MARK: - Session Preferences (separate concern)
    @Published var sessionDuration: WorkoutDuration?
    @Published var sessionFitnessGoal: FitnessGoal?
    @Published var sessionFitnessLevel: ExperienceLevel?
    @Published var sessionFlexibilityPreferences: FlexibilityPreferences?
    @Published var customTargetMuscles: [String]?
    @Published private(set) var defaultTargetMuscles: [String]?
    @Published var customEquipment: [Equipment]?
    @Published var selectedMuscleType: String = "Recovered Muscles"
    @Published private(set) var defaultMuscleType: String = "Recovered Muscles"
    @Published var selectedEquipmentType: String = "Auto"
    
    // MARK: - Session Rest Timer Settings (workout-wide)
    @Published var sessionRestTimerEnabled: Bool = false
    @Published var sessionRestWarmupSeconds: Int = 60
    @Published var sessionRestWorkingSeconds: Int = 60

    // MARK: - Debug Flags
    @Published var debugForceIncludeDurationExercise = true // Debug: Always include a duration-based exercise
    @Published var syncErrorMessage: String?
    
    // MARK: - Workout History State (for routines view)
    @Published private(set) var hasWorkouts: Bool = false
    @Published private(set) var isLoadingWorkouts: Bool = false
    @Published private(set) var customWorkouts: [Workout] = []
    @Published private(set) var customWorkoutsError: String?
    
    // MARK: - Service Dependencies (NOT @Published to avoid unnecessary updates)
    private let workoutGenerationService = WorkoutGenerationService.shared
    private let recommendationService = WorkoutRecommendationService.shared
    private let recoveryService = MuscleRecoveryService.shared
    private let userProfileService = UserProfileService.shared
    private let workoutDataManager = WorkoutDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var manualWarmupExerciseIDs: Set<Int> = []
    private var todayWorkoutRecoverySnapshot: [String: Double]?
    private var todayWorkoutMuscleGroups: [String] = []
    private var todayWorkoutTrainingSplit: String?
    private var todayWorkoutBodyweightOnly: Bool?
    private var sessionMonitorTimer: Timer?
    private var activeWorkoutState: ActiveWorkoutState?
    private let sessionTimeoutInterval: TimeInterval = 3 * 60 * 60
    private var pendingSummaryRegeneration = false
    private var lastModelContext: ModelContext?
    private var exerciseLookupCache: [Int: ExerciseData] = [:]
    private let networkManager = NetworkManagerTwo.shared
    private let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    // MARK: - UserDefaults Keys
    private let todayWorkoutKey = "todayWorkout"
    private let sessionDurationKey = "currentWorkoutSessionDuration"
    private let sessionDateKey = "currentWorkoutSessionDate"
    private let customMusclesKey = "currentWorkoutCustomMuscles"
    private let sessionFitnessGoalKey = "currentWorkoutSessionFitnessGoal"
    private let sessionFlexibilityKey = "currentWorkoutSessionFlexibility"
    private let sessionRestEnabledKey = "currentWorkoutSessionRestEnabled"
    private let sessionRestWarmupKey = "currentWorkoutSessionRestWarmupSeconds"
    private let sessionRestWorkingKey = "currentWorkoutSessionRestWorkingSeconds"
    private let defaultMuscleTypeKey = "defaultWorkoutMuscleType"
    private let defaultCustomMusclesKey = "defaultWorkoutCustomMuscles"
    private let sessionMuscleTypeKey = "currentWorkoutMuscleType"
    private let sessionFitnessLevelKey = "currentWorkoutSessionFitnessLevel"
    private let sessionCustomEquipmentKey = "currentWorkoutCustomEquipment"
    private let sessionEquipmentTypeKey = "currentWorkoutEquipmentType"
    private let todayWorkoutRecoverySnapshotKey = "todayWorkoutRecoverySnapshot"
    private let todayWorkoutMusclesKey = "todayWorkoutMuscles"
    private let todayWorkoutTrainingSplitKey = "todayWorkoutTrainingSplit"
    private let todayWorkoutBodyweightOnlyKey = "todayWorkoutBodyweightOnly"
    private let activeWorkoutStateKey = "activeWorkoutState"
    private let customWorkoutsKey = "custom_workouts"
    private let customWorkoutIdCounterKey = "customWorkoutIdCounter"
    private let customWorkoutsLastFetchKey = "customWorkoutsLastFetch"
    private let pinnedCustomWorkoutsKey = "pinnedCustomWorkouts"

    private var customWorkoutsLastFetch: Date?
    private var isFetchingCustomWorkouts = false
    private var pinnedCustomWorkoutIDs: Set<Int> = []

    private func profileScopedKey(_ key: String) -> String {
        UserProfileService.shared.scopedDefaultsKey(key)
    }

    private func assertMainActor(_ context: String, file: StaticString = #fileID, line: UInt = #line) {
        MainActorDiagnostics.assertIsolated("WorkoutManager.\(context)", file: file, line: line)
    }

    private struct ActiveWorkoutState: Codable {
        let workoutId: UUID
        let startedAt: Date
        var lastActivityAt: Date
        var pausedIntervals: [DateInterval] = []
        var pauseBeganAt: Date? = nil

        func hasTimedOut(referenceDate: Date = Date(), timeout: TimeInterval) -> Bool {
            referenceDate.timeIntervalSince(lastActivityAt) > timeout
        }

        func totalPausedDuration(referenceDate: Date = Date()) -> TimeInterval {
            let closedIntervals = pausedIntervals.reduce(0) { partial, interval in
                partial + interval.duration
            }

            guard let pauseStart = pauseBeganAt else {
                return closedIntervals
            }

            return closedIntervals + max(referenceDate.timeIntervalSince(pauseStart), 0)
        }
    }
    
    private struct GeneratedWorkoutResult {
        let workout: TodayWorkout
        let muscleGroups: [String]
    }
    
    // MARK: - Computed Properties (Effective Values)
    var effectiveDuration: WorkoutDuration {
        sessionDuration ?? userProfileService.workoutDuration
    }
    
    var effectiveFitnessGoal: FitnessGoal {
        sessionFitnessGoal ?? userProfileService.fitnessGoal
    }
    
    var effectiveFitnessLevel: ExperienceLevel {
        sessionFitnessLevel ?? userProfileService.experienceLevel
    }
    
    var effectiveFlexibilityPreferences: FlexibilityPreferences {
        if let sessionPrefs = sessionFlexibilityPreferences {
            return sessionPrefs
        }
        
        // Fallback to UserDefaults since UserProfileService doesn't have flexibilityPreferences
        if let data = UserDefaults.standard.data(forKey: "flexibilityPreferences"),
           let prefs = try? JSONDecoder().decode(FlexibilityPreferences.self, from: data) {
            return prefs
        }
        
        // Default: no flexibility options enabled
        return FlexibilityPreferences(warmUpEnabled: false, coolDownEnabled: false)
    }
    
    var hasSessionModifications: Bool {
        sessionDuration != nil ||
        customTargetMuscles != nil ||
        customEquipment != nil ||
        sessionFitnessGoal != nil ||
        sessionFitnessLevel != nil ||
        sessionFlexibilityPreferences != nil
    }

    var muscleSelectionDisplayLabel: String {
        if let customTargetMuscles, !customTargetMuscles.isEmpty {
            return selectedMuscleType
        }
        return defaultMuscleType
    }

    var baselineCustomMuscles: [String]? {
        if let customTargetMuscles, !customTargetMuscles.isEmpty {
            return customTargetMuscles
        }
        return defaultTargetMuscles
    }
    
    // MARK: - Initialization
    private init() {
        setupObservers()
        loadSessionData()
        loadDefaultMusclePreferences()
        loadTodayWorkout()
        setupSessionMonitoring()
        setupDynamicProgramming()  // Initialize dynamic programming

        workoutDataManager.$syncError
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                guard let self else { return }
                self.syncErrorMessage = message
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .workoutSyncRateLimited)
            .compactMap { $0.userInfo?["message"] as? String }
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.syncErrorMessage = message
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Dynamic Programming Properties
    
    /// Session phase computed directly from fitness goal (single source of truth)
    var sessionPhase: SessionPhase {
        // Simple computed property - no storage, no syncing needed
        return SessionPhase.alignedWith(fitnessGoal: effectiveFitnessGoal)
    }
    
    /// Alias for backward compatibility
    var effectiveSessionPhase: SessionPhase {
        return sessionPhase
    }
    
    /// Dynamic workout parameters for current session
    var dynamicParameters: DynamicWorkoutParameters? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "dynamicWorkoutParameters"),
                  let params = try? JSONDecoder().decode(DynamicWorkoutParameters.self, from: data) else {
                return nil
            }
            return params
        }
        set {
            if let params = newValue,
               let data = try? JSONEncoder().encode(params) {
                UserDefaults.standard.set(data, forKey: "dynamicWorkoutParameters")
            } else {
                UserDefaults.standard.removeObject(forKey: "dynamicWorkoutParameters")
            }
        }
    }
    
    // MARK: - Dynamic Programming Helper Methods
    
    /// Generate base workout using existing logic
    private func generateBaseWorkout() async throws -> GeneratedWorkoutResult {
        let parameters = WorkoutGenerationParameters(
            duration: effectiveDuration,
            fitnessGoal: effectiveFitnessGoal,
            fitnessLevel: effectiveFitnessLevel,
            flexibilityPreferences: effectiveFlexibilityPreferences,
            customTargetMuscles: baselineCustomMuscles,
            customEquipment: customEquipment
        )
        
        return try await backgroundWorkoutGeneration(parameters)
    }

    func clearSyncErrorMessage() {
        syncErrorMessage = nil
        workoutDataManager.syncError = nil
    }
    
    /// Apply dynamic programming to base workout
    private func applyDynamicProgramming(
        to workout: TodayWorkout,
        parameters: DynamicWorkoutParameters
    ) async -> DynamicTodayWorkout {
        
        let dynamicExercises = workout.exercises.map { staticExercise in
            DynamicParameterService.shared.generateDynamicExercise(
                for: staticExercise.exercise,
                parameters: parameters,
                fitnessGoal: effectiveFitnessGoal,
                baseExercise: staticExercise
            )
        }
        
        print("🔄 Converted \(workout.exercises.count) static exercises to dynamic")
        
        // Log rep range changes for transparency
        for (index, dynamicEx) in dynamicExercises.enumerated() {
            let originalReps = workout.exercises[index].reps
            let newRange = dynamicEx.repRangeDisplay
            print("🔄 \(dynamicEx.exercise.name): \(originalReps) reps → \(newRange) reps (\(parameters.sessionPhase.displayName))")
        }
        
        return DynamicTodayWorkout(
            baseWorkout: workout,
            dynamicExercises: dynamicExercises,
            sessionPhase: parameters.sessionPhase,
            dynamicParameters: parameters
        )
    }
    
    // MARK: - Workout Updates

    func renameTodayWorkout(to newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedTitle = sanitizeWorkoutTitle(trimmedTitle)
        guard !sanitizedTitle.isEmpty, let existingWorkout = todayWorkout else { return }
        guard existingWorkout.title != sanitizedTitle else { return }

        let updatedWorkout = TodayWorkout(
            id: existingWorkout.id,
            date: existingWorkout.date,
            title: sanitizedTitle,
            exercises: existingWorkout.exercises,
            blocks: existingWorkout.blocks,
            estimatedDuration: existingWorkout.estimatedDuration,
            fitnessGoal: existingWorkout.fitnessGoal,
            difficulty: existingWorkout.difficulty,
            warmUpExercises: existingWorkout.warmUpExercises,
            coolDownExercises: existingWorkout.coolDownExercises
        )

        todayWorkout = sanitizeWarmupsIfNeeded(updatedWorkout)

        if let activeWorkout = currentWorkout, activeWorkout.id == existingWorkout.id {
            let updatedActiveWorkout = TodayWorkout(
                id: activeWorkout.id,
                date: activeWorkout.date,
                title: sanitizedTitle,
                exercises: activeWorkout.exercises,
                blocks: activeWorkout.blocks,
                estimatedDuration: activeWorkout.estimatedDuration,
                fitnessGoal: activeWorkout.fitnessGoal,
                difficulty: activeWorkout.difficulty,
                warmUpExercises: activeWorkout.warmUpExercises,
                coolDownExercises: activeWorkout.coolDownExercises
            )
            currentWorkout = sanitizeWarmupsIfNeeded(updatedActiveWorkout)
        }

        saveTodayWorkout()
    }

    // MARK: - Core Public Methods

    /// Reset workout state when user logs out/in to prevent data leakage between accounts
    func resetForUserChange() {
        print("🔄 WorkoutManager: Resetting state for user change")

        // Clear all workout state
        todayWorkout = nil
        currentWorkout = nil
        todayWorkoutRecoverySnapshot = nil
        todayWorkoutMuscleGroups = []
        activeWorkoutState = nil
        completedWorkoutSummary = nil
        isDisplayingSummary = false
        lastCompletedWorkout = nil

        // Reset session preferences
        resetSessionStateForActiveProfile()

        // Reload data for new user
        loadSessionData()
        loadDefaultMusclePreferences()
        loadTodayWorkout()
    }

    /// Check if workout should be regenerated and regenerate if needed
    func checkAndRegenerateIfNeeded() {
        guard let workout = todayWorkout else {
            // No workout exists, generate one
            Task { await generateTodayWorkout() }
            return
        }

        if shouldRegenerateWorkout(using: workout) {
            print("🔄 WorkoutManager: Regeneration needed, generating new workout")
            Task { await generateTodayWorkout() }
        } else {
            print("✅ WorkoutManager: Workout is up to date, no regeneration needed")
        }
    }

    /// Generate today's workout with dynamic programming (1 second simple loading)
    func generateTodayWorkout() async {
        assertMainActor("generateTodayWorkout")
        let startTime = Date()
        await setGenerating(true, message: "Generating workout")
        
        do {
            // Calculate dynamic parameters using synced phase
            let dynamicParams = await DynamicParameterService.shared.calculateDynamicParameters(
                currentPhase: effectiveSessionPhase,
                lastFeedback: PerformanceFeedbackService.shared.feedbackHistory.last
            )
            
            // Generate base workout structure (reuse existing logic)
            let baseResult = try await generateBaseWorkout()
            let baseWorkout = baseResult.workout
            
            // Apply dynamic programming
            let dynamicWorkout = await applyDynamicProgramming(to: baseWorkout, parameters: dynamicParams)
            
            // Update state (but DON'T override the synced session phase)
            self.dynamicParameters = dynamicParams
            // Keep legacy exercises for compatibility, but also attach blocks for unified architecture
            let legacy = dynamicWorkout.legacyWorkout
            // Preserve the blocks that were assembled on the base workout
            let baseBlocks = dynamicWorkout.baseWorkout.blocks
            let withBlocks = TodayWorkout(
                id: legacy.id,
                date: legacy.date,
                title: legacy.title,
                exercises: legacy.exercises,
                blocks: baseBlocks,
                estimatedDuration: legacy.estimatedDuration,
                fitnessGoal: legacy.fitnessGoal,
                difficulty: legacy.difficulty,
                warmUpExercises: legacy.warmUpExercises,
                coolDownExercises: legacy.coolDownExercises
            )
            let sanitized = sanitizeWarmupsIfNeeded(withBlocks)
            self.todayWorkout = sanitized
            self.todayWorkoutMuscleGroups = baseResult.muscleGroups
            self.todayWorkoutRecoverySnapshot = captureCurrentRecoverySnapshot()
            self.todayWorkoutTrainingSplit = userProfileService.trainingSplit.rawValue
            self.todayWorkoutBodyweightOnly = userProfileService.bodyweightOnlyWorkouts
            // REMOVED: self.sessionPhase = dynamicParams.sessionPhase (this was overriding our sync!)

            saveTodayWorkout()
            generationError = nil
            
            print("🎯 Generated dynamic workout: \(sessionPhase.displayName)")
            print("🎯 Dynamic exercises: \(dynamicWorkout.dynamicExercises.count)")
            
        } catch {
            print("⚠️ Dynamic workout generation failed: \(error)")
            generationError = .generationFailed(error.localizedDescription)
        }
        
        // Simple 1-second minimum loading
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < 1.0 {
            let remainingTime = 1.0 - elapsed
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }
        
        await setGenerating(false)
    }
    
    /// Generate static workout with current preferences (1 second simple loading)
    func generateStaticWorkout() async {
        let startTime = Date()
        await setGenerating(true, message: "Generating workout")
        
        do {
            let parameters = WorkoutGenerationParameters(
                duration: effectiveDuration,
                fitnessGoal: effectiveFitnessGoal,
                fitnessLevel: effectiveFitnessLevel,
                flexibilityPreferences: effectiveFlexibilityPreferences,
                customTargetMuscles: baselineCustomMuscles,
                customEquipment: customEquipment
            )
            
            // Perform heavy workout generation in background
            let result = try await backgroundWorkoutGeneration(parameters)
            
            // Update on main thread
            let sanitized = sanitizeWarmupsIfNeeded(result.workout)
            todayWorkout = sanitized
            todayWorkoutMuscleGroups = result.muscleGroups
            todayWorkoutRecoverySnapshot = captureCurrentRecoverySnapshot()
            todayWorkoutTrainingSplit = userProfileService.trainingSplit.rawValue
            todayWorkoutBodyweightOnly = userProfileService.bodyweightOnlyWorkouts
            generationError = nil
            saveTodayWorkout()
            
        } catch let error as WorkoutGenerationError {
            generationError = error
        } catch {
            generationError = .generationFailed(error.localizedDescription)
        }
        
        // Simple 1-second minimum loading
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < 1.0 {
            let remainingTime = 1.0 - elapsed
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }
        
        await setGenerating(false)
    }
    
    // MARK: - Preference Setters with Persistence
    
    /// Set default workout duration (permanent preference)
    func setDefaultDuration(_ duration: WorkoutDuration) {
        // Clear session override since we're setting a new default
        sessionDuration = nil
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionDurationKey))
        
        // Update UserDefaults directly (UserProfileService reads from here)
        UserDefaults.standard.set(duration.rawValue, forKey: "defaultWorkoutDuration")
        UserDefaults.standard.set(duration.minutes, forKey: "availableTime")
    }
    
    /// Set session-only workout duration (temporary override)
    func setSessionDuration(_ duration: WorkoutDuration) {
        sessionDuration = duration
        
        // Persist session override with date validation
        UserDefaults.standard.set(duration.rawValue, forKey: profileScopedKey(sessionDurationKey))
        UserDefaults.standard.set(Date(), forKey: profileScopedKey(sessionDateKey))
    }
    
    /// Set default fitness goal (permanent preference)
    func setDefaultFitnessGoal(_ goal: FitnessGoal) {
        // Clear session override
        sessionFitnessGoal = nil
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionFitnessGoalKey))
        
        // Update UserProfileService
        userProfileService.fitnessGoal = goal
    }
    
    /// Set session-only fitness goal (temporary override)
    func setSessionFitnessGoal(_ goal: FitnessGoal) {
        sessionFitnessGoal = goal
        UserDefaults.standard.set(goal.rawValue, forKey: profileScopedKey(sessionFitnessGoalKey))
    }
    
    /// Set default fitness level (permanent preference)
    func setDefaultFitnessLevel(_ level: ExperienceLevel) {
        sessionFitnessLevel = nil
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionFitnessLevelKey))
        userProfileService.experienceLevel = level
    }
    
    /// Set session-only fitness level (temporary override)
    func setSessionFitnessLevel(_ level: ExperienceLevel) {
        sessionFitnessLevel = level
        UserDefaults.standard.set(level.rawValue, forKey: profileScopedKey(sessionFitnessLevelKey))
    }
    
    /// Set default flexibility preferences
    func setDefaultFlexibilityPreferences(_ prefs: FlexibilityPreferences) {
        sessionFlexibilityPreferences = nil
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionFlexibilityKey))
        
        // Update UserDefaults directly (since UserProfileService has no flexibilityPreferences property)
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: "flexibilityPreferences")
        }
    }
    
    /// Set session-only flexibility preferences
    func setSessionFlexibilityPreferences(_ prefs: FlexibilityPreferences) {
        sessionFlexibilityPreferences = prefs
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: profileScopedKey(sessionFlexibilityKey))
        }
    }

    /// Set session-only target muscles (temporary override)
    func setSessionTargetMuscles(_ muscles: [String], type: String) {
        let normalized = muscles.filter { !$0.isEmpty }

        if normalized.isEmpty {
            customTargetMuscles = nil
            UserDefaults.standard.removeObject(forKey: profileScopedKey(customMusclesKey))
        } else {
            customTargetMuscles = normalized
        }

        selectedMuscleType = type
        UserDefaults.standard.set(type, forKey: profileScopedKey(sessionMuscleTypeKey))
        saveSessionData()
    }

    /// Set default muscle selection (permanent preference)
    func setDefaultMuscleSelection(type: String, muscles: [String]) {
        customTargetMuscles = nil
        UserDefaults.standard.removeObject(forKey: profileScopedKey(customMusclesKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionMuscleTypeKey))

        defaultMuscleType = type
        selectedMuscleType = type

        let normalized = muscles.filter { !$0.isEmpty }
        if normalized.isEmpty || type == "Recovered Muscles" {
            defaultTargetMuscles = nil
            persistDefaultMusclePreferences(type: type, muscles: nil)
        } else {
            defaultTargetMuscles = normalized
            persistDefaultMusclePreferences(type: type, muscles: normalized)
        }
    }

    // MARK: - Custom Workout Templates

    func fetchCustomWorkouts(force: Bool = false) async {
        let shouldSkip = await MainActor.run { isLoadingWorkouts && !force }
        if shouldSkip { return }

        await MainActor.run {
            isLoadingWorkouts = true
            if force {
                customWorkoutsError = nil
            }
            loadPinnedCustomWorkouts()
        }

        let raw = await DataLayer.shared.getData(key: customWorkoutsKey)
        var decoded = decodeCustomWorkouts(raw)
        decoded.sort { $0.date > $1.date }

        await MainActor.run {
            customWorkouts = reorderCustomWorkouts(decoded)
            hasWorkouts = !decoded.isEmpty
            pinnedCustomWorkoutIDs = pinnedCustomWorkoutIDs.filter { id in
                customWorkouts.contains { pinnedIdentifier(for: $0) == id }
            }
            savePinnedCustomWorkouts()
        }

        guard !userEmail.isEmpty else {
            await MainActor.run { isLoadingWorkouts = false }
            return
        }

        let shouldFetchRemote = await MainActor.run { () -> Bool in
            loadCustomWorkoutsLastFetch()
            if force {
                isFetchingCustomWorkouts = true
                return true
            }
            if isFetchingCustomWorkouts {
                return false
            }
            if let lastFetch = customWorkoutsLastFetch,
               Date().timeIntervalSince(lastFetch) < RepositoryTTL.customWorkouts {
                return false
            }
            isFetchingCustomWorkouts = true
            return true
        }

        guard shouldFetchRemote else {
            await MainActor.run {
                if !customWorkouts.isEmpty {
                    customWorkoutsError = nil
                }
                isLoadingWorkouts = false
            }
            return
        }

        defer {
            Task { @MainActor in
                isFetchingCustomWorkouts = false
                isLoadingWorkouts = false
            }
        }

        do {
            let response = try await networkManager.fetchServerWorkouts(userEmail: userEmail, pageSize: 200, isTemplateOnly: true)
            let templateSessions = response.workouts.filter { ($0.isTemplate ?? false) }
            var remoteTemplates = templateSessions.map(remoteWorkoutToTemplate)

            let localTemplatesByRemoteId = Dictionary(uniqueKeysWithValues: decoded.compactMap { workout -> (Int, Workout)? in
                if let remoteId = workout.remoteId {
                    return (remoteId, workout)
                }
                if workout.id > 0 {
                    return (workout.id, workout)
                }
                return nil
            })

            remoteTemplates = remoteTemplates.map { remote in
                let key = remote.remoteId ?? remote.id
                guard remote.blocks == nil,
                      let local = localTemplatesByRemoteId[key],
                      local.blocks != nil else {
                    return remote
                }
                return mergeWorkout(current: local, with: remote)
            }

            var usedIds = Set(remoteTemplates.map { $0.id })
            let unsyncedLocals = decoded.filter { $0.remoteId == nil }
            let normalizedUnsynced = unsyncedLocals.map { uniqueLocalTemplate($0, usedIds: &usedIds) }
            remoteTemplates.append(contentsOf: normalizedUnsynced)
            remoteTemplates.sort { $0.date > $1.date }

            await MainActor.run {
                let ordered = reorderCustomWorkouts(remoteTemplates)
                customWorkouts = ordered
                hasWorkouts = !ordered.isEmpty
                customWorkoutsError = nil
                updateCustomWorkoutsLastFetch(Date())
                pinnedCustomWorkoutIDs = pinnedCustomWorkoutIDs.filter { id in
                    ordered.contains { pinnedIdentifier(for: $0) == id }
                }
                savePinnedCustomWorkouts()
            }

            await persistCustomWorkouts()
        } catch {
            if !isCancellationError(error) {
                await MainActor.run {
                    customWorkoutsError = error.localizedDescription
                }
            }
        }
    }

    func saveCustomWorkout(name: String,
                           exercises: [WorkoutExercise],
                           notes: String? = nil,
                           workoutId: Int? = nil,
                           blocks: [WorkoutBlock]? = nil,
                           syncImmediately: Bool = true) async throws -> Workout {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw CustomWorkoutError.invalidName }
        guard !exercises.isEmpty else { throw CustomWorkoutError.noExercises }

        let sanitizedExercises = sanitizeCustomWorkoutExercises(exercises)
        let durationMinutes = estimatedDurationMinutes(for: sanitizedExercises)
        let resolvedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let identifier: Int
        if let workoutId = workoutId {
            identifier = workoutId
        } else {
            identifier = -abs(nextCustomWorkoutId())
        }
        let existing = workoutId.flatMap { id in customWorkouts.first(where: { $0.id == id }) }

        let template = Workout(
            id: identifier,
            remoteId: existing?.remoteId,
            name: trimmedName,
            date: Date(),
            duration: durationMinutes,
            exercises: sanitizedExercises,
            notes: resolvedNotes?.isEmpty == true ? nil : resolvedNotes,
            category: existing?.category,
            isTemplate: true,
            syncVersion: existing?.syncVersion,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date(),
            blocks: blocks ?? existing?.blocks
        )

        await MainActor.run {
            withAnimation(.easeInOut) {
                if let workoutId = workoutId, let index = customWorkouts.firstIndex(where: { $0.id == workoutId }) {
                    customWorkouts[index] = template
                } else {
                    customWorkouts.append(template)
                }

                customWorkouts = reorderCustomWorkouts(customWorkouts)
                hasWorkouts = !customWorkouts.isEmpty
                updateCustomWorkoutsLastFetch(Date())
            }
        }
        await persistCustomWorkouts()

        var finalWorkout = template

        if syncImmediately {
            do {
                finalWorkout = try await syncCustomWorkout(template, originalIdentifier: identifier)
            } catch {
                if !isCancellationError(error) {
                    await MainActor.run {
                        self.customWorkoutsError = error.localizedDescription
                    }
                }
                throw error
            }
        } else {
            Task {
                do {
                    _ = try await syncCustomWorkout(template, originalIdentifier: identifier)
                } catch {
                    if !isCancellationError(error) {
                        await MainActor.run {
                            self.customWorkoutsError = error.localizedDescription
                        }
                    }
                }
            }
        }

        return finalWorkout
    }

    func saveTodayWorkoutAsCustom() async throws -> Workout {
        guard let todayWorkout = todayWorkout else {
            throw CustomWorkoutError.noExercises
        }

        let resolvedName = todayWorkout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = resolvedName.isEmpty ? "Workout" : resolvedName
        let workoutExercises = convertToWorkoutExercises(from: todayWorkout)

        return try await saveCustomWorkout(
            name: name,
            exercises: workoutExercises,
            notes: nil,
            blocks: todayWorkout.blocks,
            syncImmediately: false
        )
    }

    func deleteCustomWorkout(id: Int) async {
        guard let workout = customWorkouts.first(where: { $0.id == id }) else { return }

        do {
            if let remoteId = workout.remoteId, !userEmail.isEmpty {
                try await networkManager.deleteWorkout(sessionId: remoteId, userEmail: userEmail)
            }

            await MainActor.run {
                withAnimation(.easeInOut) {
                    removePinnedIdentifier(for: workout)
                    if let index = customWorkouts.firstIndex(where: { $0.id == id }) {
                        customWorkouts.remove(at: index)
                    }
                    customWorkouts = reorderCustomWorkouts(customWorkouts)
                    hasWorkouts = !customWorkouts.isEmpty
                    updateCustomWorkoutsLastFetch(Date())
                }
            }
            await persistCustomWorkouts()
        } catch {
            if !isCancellationError(error) {
                await MainActor.run {
                    self.customWorkoutsError = error.localizedDescription
                }
            }
        }
    }

    func duplicateCustomWorkout(from workout: Workout) async {
        let base = workout.name.isEmpty ? workout.displayName : workout.name
        let newName = await MainActor.run { duplicateName(for: base) }

        do {
            _ = try await saveCustomWorkout(name: newName,
                                            exercises: workout.exercises,
                                            notes: workout.notes,
                                            blocks: workout.blocks)
        } catch {
            if !isCancellationError(error) {
                await MainActor.run {
                    self.customWorkoutsError = error.localizedDescription
                }
            }
            return
        }

        await MainActor.run {
            withAnimation(.easeInOut) {
                _ = positionDuplicate(named: newName, after: workout)
            }
        }
    }

    func pinCustomWorkout(_ workout: Workout) async {
        await MainActor.run {
            withAnimation(.easeInOut) {
                let identifier = pinnedIdentifier(for: workout)
                if !pinnedCustomWorkoutIDs.contains(identifier) {
                    pinnedCustomWorkoutIDs.insert(identifier)
                    savePinnedCustomWorkouts()
                }
                customWorkouts = reorderCustomWorkouts(customWorkouts)
                updateCustomWorkoutsLastFetch(Date())
            }
        }
        await persistCustomWorkouts()
    }

    func unpinCustomWorkout(_ workout: Workout) async {
        await MainActor.run {
            withAnimation(.easeInOut) {
                removePinnedIdentifier(for: workout)
                customWorkouts = reorderCustomWorkouts(customWorkouts)
                updateCustomWorkoutsLastFetch(Date())
            }
        }
        await persistCustomWorkouts()
    }

    @MainActor
    func isCustomWorkoutPinned(_ workout: Workout) -> Bool {
        pinnedCustomWorkoutIDs.contains(pinnedIdentifier(for: workout))
    }

    func startCustomWorkout(_ workout: Workout) -> TodayWorkout {
        let todayWorkout = makeTodayWorkout(from: workout)
        startWorkout(todayWorkout)
        return todayWorkout
    }

    private func persistCustomWorkouts() async {
        let encoded = encodeCustomWorkouts(customWorkouts)
        await DataLayer.shared.setData(key: customWorkoutsKey, value: encoded)
        await MainActor.run {
            customWorkoutsError = nil
        }
    }

    private func decodeCustomWorkouts(_ raw: Any?) -> [Workout] {
        guard let entries = raw as? [[String: Any]] else { return [] }
        return entries.compactMap(decodeWorkoutDictionary)
    }

    private func decodeWorkoutDictionary(_ dictionary: [String: Any]) -> Workout? {
        guard let id = valueAsInt(dictionary["id"]),
              let name = dictionary["name"] as? String,
              let dateInterval = valueAsDouble(dictionary["date"]),
              let exerciseEntries = dictionary["exercises"] as? [[String: Any]] else {
            return nil
        }

        let exercises = exerciseEntries.compactMap(decodeWorkoutExercise)
        guard !exercises.isEmpty else { return nil }

        let duration = valueAsInt(dictionary["duration"])
        let notes = trimmedOrNil(dictionary["notes"] as? String)
        let category = trimmedOrNil(dictionary["category"] as? String)
        let remoteId = valueAsInt(dictionary["remote_id"])
        let isTemplate = valueAsBool(dictionary["is_template"]) ?? true
        let syncVersion = valueAsInt(dictionary["sync_version"])
        let createdAt: Date? = {
            if let interval = valueAsDouble(dictionary["created_at"]) {
                return Date(timeIntervalSince1970: interval)
            }
            return nil
        }()
        let updatedAt: Date? = {
            if let interval = valueAsDouble(dictionary["updated_at"]) {
                return Date(timeIntervalSince1970: interval)
            }
            return nil
        }()

        let blocks = decodeWorkoutBlocks(dictionary["blocks"])

        return Workout(
            id: id,
            remoteId: remoteId,
            name: name,
            date: Date(timeIntervalSince1970: dateInterval),
            duration: duration,
            exercises: exercises,
            notes: notes,
            category: category,
            isTemplate: isTemplate,
            syncVersion: syncVersion,
            createdAt: createdAt,
            updatedAt: updatedAt,
            blocks: blocks
        )
    }

    private func decodeWorkoutExercise(_ dictionary: [String: Any]) -> WorkoutExercise? {
        guard let id = valueAsInt(dictionary["id"]),
              let legacyDict = dictionary["exercise"] as? [String: Any],
              let setEntries = dictionary["sets"] as? [[String: Any]],
              let legacyExercise = decodeLegacyExercise(legacyDict) else {
            return nil
        }

        let sets = setEntries.compactMap(decodeWorkoutSet)
        return WorkoutExercise(
            id: id,
            exercise: legacyExercise,
            sets: sets,
            notes: trimmedOrNil(dictionary["notes"] as? String)
        )
    }

    private func decodeLegacyExercise(_ dictionary: [String: Any]) -> LegacyExercise? {
        guard let id = valueAsInt(dictionary["id"]),
              let name = dictionary["name"] as? String,
              let category = dictionary["category"] as? String else {
            return nil
        }

        let description = trimmedOrNil(dictionary["description"] as? String)
        let instructions = trimmedOrNil(dictionary["instructions"] as? String)

        return LegacyExercise(
            id: id,
            name: name,
            category: category,
            description: description,
            instructions: instructions
        )
    }

    private func decodeWorkoutSet(_ dictionary: [String: Any]) -> WorkoutSet? {
        guard let id = valueAsInt(dictionary["id"]) else { return nil }

        let reps = valueAsInt(dictionary["reps"])
        let rest = valueAsInt(dictionary["restTime"])
        let duration = valueAsInt(dictionary["duration"])
        let distance = valueAsDouble(dictionary["distance"])
        let weight = valueAsDouble(dictionary["weight"])

        return WorkoutSet(
            id: id,
            reps: reps,
            weight: weight,
            duration: duration,
            distance: distance,
            restTime: rest
        )
    }

    private func sanitizeCustomWorkoutExercises(_ exercises: [WorkoutExercise]) -> [WorkoutExercise] {
        var exerciseIdentifier = 1
        return exercises.map { exercise in
            let sanitizedSets: [WorkoutSet] = exercise.sets.enumerated().map { offset, set in
                WorkoutSet(
                    id: offset + 1,
                    reps: set.reps,
                    weight: set.weight,
                    duration: set.duration,
                    distance: set.distance,
                    restTime: set.restTime
                )
            }

            defer { exerciseIdentifier += 1 }
            return WorkoutExercise(
                id: exerciseIdentifier,
                exercise: exercise.exercise,
                sets: sanitizedSets,
                notes: trimmedOrNil(exercise.notes)
            )
        }
    }

    private func legacyExercise(from exerciseId: Int, fallbackName: String) -> LegacyExercise {
        if exerciseLookupCache.isEmpty {
            let allExercises = ExerciseDatabase.getAllExercises()
            exerciseLookupCache = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        }

        if let data = exerciseLookupCache[exerciseId] {
            return LegacyExercise(
                id: data.id,
                name: data.name,
                category: data.bodyPart,
                description: data.target.isEmpty ? nil : data.target,
                instructions: data.synergist.isEmpty ? nil : data.synergist
            )
        }

        return LegacyExercise(
            id: exerciseId,
            name: fallbackName,
            category: "General",
            description: nil,
            instructions: nil
        )
    }

    private func remoteWorkoutToTemplate(_ server: NetworkManagerTwo.WorkoutResponse.Workout) -> Workout {
        let referenceDate = server.scheduledDate ?? server.startedAt ?? server.createdAt ?? Date()
        let convertedExercises = server.exercises.enumerated().map { _, exercise in
            remoteExerciseToTemplate(exercise)
        }

        return Workout(
            id: server.id,
            remoteId: server.id,
            name: server.name,
            date: referenceDate,
            duration: server.estimatedDurationMinutes,
            exercises: convertedExercises,
            notes: server.notes,
            category: nil,
            isTemplate: server.isTemplate ?? false,
            syncVersion: server.syncVersion,
            createdAt: server.createdAt,
            updatedAt: server.updatedAt,
            blocks: nil
        )
    }

    private func remoteExerciseToTemplate(_ exercise: NetworkManagerTwo.WorkoutResponse.Exercise) -> WorkoutExercise {
        let legacy = legacyExercise(from: exercise.exerciseId, fallbackName: exercise.exerciseName)
        let convertedSets = exercise.sets.enumerated().map { index, set in
            remoteSetToTemplate(set, fallbackIndex: index + 1)
        }

        return WorkoutExercise(
            id: exercise.id,
            exercise: legacy,
            sets: convertedSets,
            notes: trimmedOrNil(exercise.notes)
        )
    }

    private func remoteSetToTemplate(_ set: NetworkManagerTwo.WorkoutResponse.ExerciseSet, fallbackIndex: Int) -> WorkoutSet {
        WorkoutSet(
            id: set.id,
            reps: set.reps,
            weight: set.weightKg,
            duration: set.durationSeconds,
            distance: set.distanceMeters,
            restTime: set.restSeconds
        )
    }

    private func copyWorkout(_ workout: Workout, id: Int, remoteId: Int?) -> Workout {
        Workout(
            id: id,
            remoteId: remoteId,
            name: workout.name,
            date: workout.date,
            duration: workout.duration,
            exercises: workout.exercises,
            notes: workout.notes,
            category: workout.category,
            isTemplate: workout.isTemplate,
            syncVersion: workout.syncVersion,
            createdAt: workout.createdAt,
            updatedAt: workout.updatedAt,
            blocks: workout.blocks
        )
    }

    private func uniqueLocalTemplate(_ workout: Workout, usedIds: inout Set<Int>) -> Workout {
        var adjustedId = workout.id
        if usedIds.contains(adjustedId) {
            adjustedId = workout.id < 0 ? workout.id : -abs(workout.id)
            if adjustedId == 0 { adjustedId = -1 }
            while usedIds.contains(adjustedId) {
                adjustedId -= 1
            }
            usedIds.insert(adjustedId)
            return copyWorkout(workout, id: adjustedId, remoteId: nil)
        }

        usedIds.insert(adjustedId)
        return workout
    }

    private func determineTrackingType(for set: WorkoutSet) -> String {
        if set.reps != nil {
            return "reps_weight"
        }
        if set.duration != nil {
            return "time"
        }
        if set.distance != nil {
            return "distance"
        }
        return "custom"
    }

    @MainActor
    private func loadCustomWorkoutsLastFetch() {
        guard customWorkoutsLastFetch == nil else { return }
        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: storageKey(customWorkoutsLastFetchKey)) as? Date {
            customWorkoutsLastFetch = stored
        }
    }

    @MainActor
    private func updateCustomWorkoutsLastFetch(_ date: Date?) {
        customWorkoutsLastFetch = date
        let defaults = UserDefaults.standard
        let key = storageKey(customWorkoutsLastFetchKey)
        if let date {
            defaults.set(date, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    @MainActor
    private func loadPinnedCustomWorkouts() {
        if !pinnedCustomWorkoutIDs.isEmpty { return }
        let defaults = UserDefaults.standard
        let key = storageKey(pinnedCustomWorkoutsKey)
        if let stored = defaults.array(forKey: key) as? [Int] {
            pinnedCustomWorkoutIDs = Set(stored)
        }
    }

    @MainActor
    private func savePinnedCustomWorkouts() {
        let defaults = UserDefaults.standard
        defaults.set(Array(pinnedCustomWorkoutIDs), forKey: storageKey(pinnedCustomWorkoutsKey))
    }

    private func pinnedIdentifier(for workout: Workout) -> Int {
        workout.remoteId ?? workout.id
    }

    private func reorderCustomWorkouts(_ workouts: [Workout]) -> [Workout] {
        var pinned: [Workout] = []
        var regular: [Workout] = []

        for workout in workouts {
            if pinnedCustomWorkoutIDs.contains(pinnedIdentifier(for: workout)) {
                pinned.append(workout)
            } else {
                regular.append(workout)
            }
        }

        return pinned + regular
    }

    @MainActor
    private func positionDuplicate(named newName: String, after original: Workout) -> Workout? {
        guard let duplicateIndex = customWorkouts.firstIndex(where: { $0.name == newName }) else {
            return nil
        }

        var workingList = customWorkouts
        var duplicate = workingList.remove(at: duplicateIndex)

        let originalIdentifier = pinnedIdentifier(for: original)
        let duplicateIdentifier = pinnedIdentifier(for: duplicate)

        if pinnedCustomWorkoutIDs.contains(originalIdentifier) {
            pinnedCustomWorkoutIDs.insert(duplicateIdentifier)
            savePinnedCustomWorkouts()
        }

        let insertIndex: Int
        if let originalIndex = workingList.firstIndex(where: { $0.id == original.id }) {
            insertIndex = min(originalIndex + 1, workingList.count)
        } else {
            insertIndex = workingList.count
        }

        workingList.insert(duplicate, at: insertIndex)
        customWorkouts = reorderCustomWorkouts(workingList)
        updateCustomWorkoutsLastFetch(Date())

        if let currentIndex = customWorkouts.firstIndex(where: { $0.name == newName }) {
            duplicate = customWorkouts[currentIndex]
        }

        return duplicate
    }

    @MainActor
    private func removePinnedIdentifier(for workout: Workout) {
        let identifier = pinnedIdentifier(for: workout)
        if pinnedCustomWorkoutIDs.remove(identifier) != nil {
            savePinnedCustomWorkouts()
        }
    }

    @MainActor
    private func duplicateName(for base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "Workout" : trimmed
        var candidate = "Duplicate of \(fallback)"
        var counter = 2
        let existingNames = Set(customWorkouts.map { $0.name.lowercased() })
        while existingNames.contains(candidate.lowercased()) {
            candidate = "Duplicate of \(fallback) (\(counter))"
            counter += 1
        }
        return candidate
    }

    private func isCancellationError(_ error: Error) -> Bool {
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }
        return nsError.localizedDescription.lowercased().contains("cancelled")
    }

    private func estimatedDurationMinutes(for exercises: [WorkoutExercise]) -> Int {
        let totalSets = exercises.reduce(0) { $0 + max($1.sets.count, 1) }
        let estimate = Int(ceil(Double(max(totalSets, 1)) * 1.5))
        return max(10, min(estimate, 150))
    }

    private func makeWorkoutRequest(from workout: Workout) -> NetworkManagerTwo.WorkoutRequest {
        let startedAt = workout.createdAt ?? workout.date
        let scheduledDate = workout.date
        let estimatedDuration = workout.duration ?? estimatedDurationMinutes(for: workout.exercises)

        let exercisesPayload = workout.exercises.enumerated().map { index, exercise in
            NetworkManagerTwo.WorkoutRequest.Exercise(
                exerciseId: exercise.exercise.id,
                exerciseName: exercise.exercise.name,
                orderIndex: index,
                targetSets: max(1, exercise.sets.count),
                isCompleted: false,
                sets: exercise.sets.enumerated().map { setIndex, set in
                    NetworkManagerTwo.WorkoutRequest.ExerciseSet(
                        trackingType: determineTrackingType(for: set),
                        weightKg: set.weight,
                        reps: set.reps,
                        durationSeconds: set.duration,
                        restSeconds: set.restTime,
                        distanceMeters: set.distance,
                        distanceUnit: nil,
                        paceSecondsPerKm: nil,
                        rpe: nil,
                        heartRateBpm: nil,
                        intensityZone: nil,
                        stretchIntensity: nil,
                        rangeOfMotionNotes: nil,
                        roundsCompleted: nil,
                        isWarmup: false,
                        isCompleted: false,
                        notes: nil
                    )
                }
            )
        }

        return NetworkManagerTwo.WorkoutRequest(
            userEmail: userEmail,
            name: workout.name,
            status: "planned",
            isTemplate: true,
            startedAt: iso8601Formatter.string(from: startedAt),
            completedAt: nil,
            scheduledDate: iso8601Formatter.string(from: scheduledDate),
            estimatedDurationMinutes: estimatedDuration,
            actualDurationMinutes: nil,
            notes: workout.notes,
            exercises: exercisesPayload
        )
    }

    @MainActor
    private func replaceCustomWorkout(originalIdentifier: Int, with synced: Workout) {
        withAnimation(.easeInOut) {
            if let index = customWorkouts.firstIndex(where: { $0.id == originalIdentifier }) {
                let current = customWorkouts[index]
                customWorkouts[index] = mergeWorkout(current: current, with: synced)
            } else if let remoteId = synced.remoteId,
                      let index = customWorkouts.firstIndex(where: { $0.remoteId == remoteId }) {
                let current = customWorkouts[index]
                customWorkouts[index] = mergeWorkout(current: current, with: synced)
            } else {
                customWorkouts.append(synced)
            }

            if pinnedCustomWorkoutIDs.remove(originalIdentifier) != nil {
                pinnedCustomWorkoutIDs.insert(pinnedIdentifier(for: synced))
                savePinnedCustomWorkouts()
            }

            customWorkouts = reorderCustomWorkouts(customWorkouts)
            hasWorkouts = !customWorkouts.isEmpty
            customWorkoutsError = nil
        }
    }

    private func mergeWorkout(current: Workout, with synced: Workout) -> Workout {
        Workout(
            id: synced.id,
            remoteId: synced.remoteId,
            name: synced.name,
            date: synced.date,
            duration: synced.duration,
            exercises: synced.exercises,
            notes: synced.notes,
            category: synced.category,
            isTemplate: synced.isTemplate,
            syncVersion: synced.syncVersion,
            createdAt: synced.createdAt,
            updatedAt: synced.updatedAt,
            blocks: synced.blocks ?? current.blocks
        )
    }

    private func syncCustomWorkout(_ workout: Workout, originalIdentifier: Int) async throws -> Workout {
        if userEmail.isEmpty {
            return workout
        }

        let payload = makeWorkoutRequest(from: workout)
        let response: NetworkManagerTwo.WorkoutResponse.Workout

        if let remoteId = workout.remoteId {
            response = try await networkManager.updateWorkout(sessionId: remoteId, payload: payload)
        } else {
            response = try await networkManager.createWorkout(payload: payload)
        }

        let synced = remoteWorkoutToTemplate(response)
        await MainActor.run {
            replaceCustomWorkout(originalIdentifier: originalIdentifier, with: synced)
            updateCustomWorkoutsLastFetch(Date())
        }
        await persistCustomWorkouts()
        return synced
    }

    private func nextCustomWorkoutId() -> Int {
        let defaults = UserDefaults.standard
        let key = storageKey(customWorkoutIdCounterKey)
        let current = defaults.integer(forKey: key)
        let next = current + 1
        defaults.set(next, forKey: key)
        return next
    }

    private func encodeCustomWorkouts(_ workouts: [Workout]) -> [[String: Any]] {
        workouts.map { workout in
            var payload: [String: Any] = [
                "id": workout.id,
                "remote_id": workout.remoteId ?? NSNull(),
                "name": workout.name,
                "date": workout.date.timeIntervalSince1970,
                "duration": workout.duration ?? NSNull(),
                "notes": workout.notes ?? "",
                "category": workout.category ?? "",
                "is_template": workout.isTemplate,
                "sync_version": workout.syncVersion ?? NSNull(),
                "created_at": workout.createdAt?.timeIntervalSince1970 ?? NSNull(),
                "updated_at": workout.updatedAt?.timeIntervalSince1970 ?? NSNull(),
                "exercises": workout.exercises.map(encodeWorkoutExercise)
            ]

            if let blocksPayload = encodeWorkoutBlocks(workout.blocks) {
                payload["blocks"] = blocksPayload
            }

            return payload
        }
    }

    private func encodeWorkoutExercise(_ exercise: WorkoutExercise) -> [String: Any] {
        [
            "id": exercise.id,
            "notes": exercise.notes ?? "",
            "exercise": encodeLegacyExercise(exercise.exercise),
            "sets": exercise.sets.map(encodeWorkoutSet)
        ]
    }

    private func encodeLegacyExercise(_ exercise: LegacyExercise) -> [String: Any] {
        [
            "id": exercise.id,
            "name": exercise.name,
            "category": exercise.category,
            "description": exercise.description ?? "",
            "instructions": exercise.instructions ?? ""
        ]
    }

    private func encodeWorkoutSet(_ set: WorkoutSet) -> [String: Any] {
        [
            "id": set.id,
            "reps": set.reps ?? NSNull(),
            "weight": set.weight ?? NSNull(),
            "duration": set.duration ?? NSNull(),
            "distance": set.distance ?? NSNull(),
            "restTime": set.restTime ?? NSNull()
        ]
    }

    private func encodeWorkoutBlocks(_ blocks: [WorkoutBlock]?) -> [[String: Any]]? {
        guard let blocks, !blocks.isEmpty else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(blocks),
              let object = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        return object
    }

    private func decodeWorkoutBlocks(_ value: Any?) -> [WorkoutBlock]? {
        guard let array = value as? [[String: Any]], !array.isEmpty else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: array),
              let blocks = try? JSONDecoder().decode([WorkoutBlock].self, from: data) else {
            return nil
        }
        return blocks
    }

    private func makeTodayWorkout(from template: Workout) -> TodayWorkout {
        let todayExercises = template.exercises.map(convertWorkoutExerciseToToday)
        let estimatedDuration = template.duration ?? estimatedDurationMinutes(for: template.exercises)

        return TodayWorkout(
            title: template.displayName,
            exercises: todayExercises,
            blocks: template.blocks,
            estimatedDuration: estimatedDuration,
            fitnessGoal: effectiveFitnessGoal,
            difficulty: userProfileService.experienceLevel.workoutComplexity,
            warmUpExercises: nil,
            coolDownExercises: nil
        )
    }

    private func convertWorkoutExerciseToToday(_ exercise: WorkoutExercise) -> TodayWorkoutExercise {
        let exerciseData = exerciseData(for: exercise.exercise)
        let setsCount = max(exercise.sets.count, 1)
        let primarySet = exercise.sets.first
        let resolvedReps = primarySet?.reps ?? 10
        let resolvedWeight = primarySet?.weight
        let resolvedRest = primarySet?.restTime ?? 75

        return TodayWorkoutExercise(
            exercise: exerciseData,
            sets: max(setsCount, 1),
            reps: max(resolvedReps, 1),
            weight: resolvedWeight,
            restTime: resolvedRest,
            notes: trimmedOrNil(exercise.notes),
            warmupSets: nil,
            flexibleSets: nil,
            trackingType: nil
        )
    }

    private func exerciseData(for legacy: LegacyExercise) -> ExerciseData {
        if exerciseLookupCache.isEmpty {
            let allExercises = ExerciseDatabase.getAllExercises()
            exerciseLookupCache = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        }

        if let cached = exerciseLookupCache[legacy.id] {
            return cached
        }

        // Fallback if exercise isn't present in the embedded database
        return ExerciseData(
            id: legacy.id,
            name: legacy.name,
            exerciseType: "Strength",
            bodyPart: legacy.category,
            equipment: legacy.category,
            gender: "Unisex",
            target: legacy.description ?? "",
            synergist: legacy.instructions ?? ""
        )
    }

    private func valueAsInt(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string) }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    private func valueAsDouble(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String { return Double(string) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private func valueAsBool(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            if ["1", "true", "yes"].contains(string) { return true }
            if ["0", "false", "no"].contains(string) { return false }
        }
        return nil
    }

    private func trimmedOrNil(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
    
    /// Set session rest-timer enabled (temporary override)
    func setSessionRestTimerEnabled(_ enabled: Bool) {
        sessionRestTimerEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: profileScopedKey(sessionRestEnabledKey))
        UserDefaults.standard.set(Date(), forKey: profileScopedKey(sessionDateKey))
    }
    
    /// Set session rest warmup seconds (temporary override)
    func setSessionRestWarmupSeconds(_ seconds: Int) {
        sessionRestWarmupSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: profileScopedKey(sessionRestWarmupKey))
        UserDefaults.standard.set(Date(), forKey: profileScopedKey(sessionDateKey))
    }
    
    /// Set session rest working seconds (temporary override)
    func setSessionRestWorkingSeconds(_ seconds: Int) {
        sessionRestWorkingSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: profileScopedKey(sessionRestWorkingKey))
        UserDefaults.standard.set(Date(), forKey: profileScopedKey(sessionDateKey))
    }
    
    func handleProfileChange() {
        loadDefaultMusclePreferences()
        loadSessionData()
        Task { await generateTodayWorkout() }
    }
    
    /// Clear all session overrides
    func clearAllSessionOverrides() {
        sessionDuration = nil
        sessionFitnessGoal = nil
        sessionFitnessLevel = nil
        sessionFlexibilityPreferences = nil
        sessionRestTimerEnabled = false
        sessionRestWarmupSeconds = 60
        sessionRestWorkingSeconds = 60
        customTargetMuscles = nil
        customEquipment = nil
        selectedMuscleType = "Recovered Muscles"
        selectedEquipmentType = userProfileService.workoutLocationDisplay
        
        // Clear from UserDefaults
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionDurationKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionDateKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionFitnessGoalKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionFitnessLevelKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionFlexibilityKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(customMusclesKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionCustomEquipmentKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionMuscleTypeKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionEquipmentTypeKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionRestEnabledKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionRestWarmupKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionRestWorkingKey))
    }
    
    /// Replace exercise at index with new exercise data
    func replaceExercise(at index: Int, with newExercise: ExerciseData) {
        guard let currentWorkout = todayWorkout else { return }
        guard index < currentWorkout.exercises.count else { return }
        
        var updatedExercises = currentWorkout.exercises
        let currentExercise = updatedExercises[index]
        
        // Get smart recommendation for the new exercise
        let recommendation = recommendationService.getSmartRecommendation(for: newExercise)
        
        // Create updated exercise preserving user modifications
        let updatedExercise = TodayWorkoutExercise(
            exercise: newExercise,
            sets: recommendation.sets,
            reps: recommendation.reps,
            weight: recommendation.weight,
            restTime: currentExercise.restTime,
            notes: currentExercise.notes,
            warmupSets: currentExercise.warmupSets
        )
        
        updatedExercises[index] = updatedExercise
        
        // Create new workout instance (efficient due to struct copy-on-write)
        let updatedWorkout = TodayWorkout(
            id: currentWorkout.id,
            date: currentWorkout.date,
            title: currentWorkout.title,
            exercises: updatedExercises,
            blocks: currentWorkout.blocks,
            estimatedDuration: currentWorkout.estimatedDuration,
            fitnessGoal: currentWorkout.fitnessGoal,
            difficulty: currentWorkout.difficulty,
            warmUpExercises: currentWorkout.warmUpExercises,
            coolDownExercises: currentWorkout.coolDownExercises
        )
        
        todayWorkout = updatedWorkout
        saveTodayWorkout()
    }
    
    /// Update exercise at index with modified exercise data
    func updateExercise(at index: Int, with updatedExercise: TodayWorkoutExercise) {
        guard let currentWorkout = todayWorkout else { return }
        guard index < currentWorkout.exercises.count else { return }

        var updatedExercises = currentWorkout.exercises
        updatedExercises[index] = updatedExercise

        let updatedWorkout = TodayWorkout(
            id: currentWorkout.id,
            date: currentWorkout.date,
            title: currentWorkout.title,
            exercises: updatedExercises,
            blocks: currentWorkout.blocks,
            estimatedDuration: currentWorkout.estimatedDuration,
            fitnessGoal: currentWorkout.fitnessGoal,
            difficulty: currentWorkout.difficulty,
            warmUpExercises: currentWorkout.warmUpExercises,
            coolDownExercises: currentWorkout.coolDownExercises
        )

        todayWorkout = updatedWorkout
        saveTodayWorkout()
    }

    /// Apply a manual block creation result and persist the updated workout
    func applyManualBlockResult(_ result: BlockCreationService.CreationResult) {
        todayWorkout = result.workout
        saveTodayWorkout()
    }

    /// Set today's workout (for loading from UserDefaults)
    func setTodayWorkout(_ workout: TodayWorkout?) {
        guard let workout else {
            todayWorkout = nil
            return
        }

        let sanitizedTitle = sanitizeWorkoutTitle(workout.title)
        let sanitizedWorkout = TodayWorkout(
            id: workout.id,
            date: workout.date,
            title: sanitizedTitle,
            exercises: workout.exercises,
            blocks: workout.blocks,
            estimatedDuration: workout.estimatedDuration,
            fitnessGoal: workout.fitnessGoal,
            difficulty: workout.difficulty,
            warmUpExercises: workout.warmUpExercises,
            coolDownExercises: workout.coolDownExercises
        )
        let normalizedWorkout = sanitizeWarmupsIfNeeded(sanitizedWorkout)

        if let current = todayWorkout, current == normalizedWorkout {
            return
        }

        todayWorkout = normalizedWorkout
        saveTodayWorkout()
        print("📅 WorkoutManager: Set today's workout - \(sanitizedTitle)")
    }

    /// Remove an exercise (by ExerciseData.id) from today's workout (all sections)
    @discardableResult
    func removeExerciseFromToday(exerciseId: Int) -> TodayWorkout? {
        var updatedToday: TodayWorkout?

        if let today = todayWorkout {
            let stripped = removeExercise(exerciseId, from: today)
            let sanitized = sanitizeWarmupsIfNeeded(stripped)
            todayWorkout = sanitized
            saveTodayWorkout()
            updatedToday = sanitized
        }

        if let active = currentWorkout {
            let strippedActive = removeExercise(exerciseId, from: active)
            currentWorkout = sanitizeWarmupsIfNeeded(strippedActive)
        }

        if updatedToday != nil || currentWorkout != nil {
            print("🧹 Removed exercise id=\(exerciseId) from today's workout")
        }

        return currentWorkout ?? updatedToday
    }

    private func removeExercise(_ exerciseId: Int, from workout: TodayWorkout) -> TodayWorkout {
        let main = workout.exercises.filter { $0.exercise.id != exerciseId }
        let warmUp = workout.warmUpExercises?.filter { $0.exercise.id != exerciseId }
        let coolDown = workout.coolDownExercises?.filter { $0.exercise.id != exerciseId }

        let adjustedBlocks: [WorkoutBlock]? = workout.blocks.map { blocks in
            blocks.compactMap { block in
                var filteredExercises = block.exercises.filter { $0.exercise.id != exerciseId }

                if filteredExercises.isEmpty {
                    return nil
                }

                switch block.type {
                case .superset, .circuit:
                    // Drop the block entirely if fewer than 2 exercises remain
                    guard filteredExercises.count >= 2 else { return nil }

                    let desiredType: BlockType = filteredExercises.count >= 3 ? .circuit : .superset

                    if desiredType == block.type {
                        var updatedBlock = block
                        updatedBlock.exercises = filteredExercises
                        return updatedBlock
                    }

                    return WorkoutBlock(
                        id: block.id,
                        type: desiredType,
                        exercises: filteredExercises,
                        rounds: block.rounds,
                        restBetweenExercises: block.restBetweenExercises,
                        restBetweenRounds: block.restBetweenRounds,
                        weightNormalization: block.weightNormalization,
                        timingConfig: block.timingConfig
                    )

                default:
                    var updatedBlock = block
                    updatedBlock.exercises = filteredExercises
                    return updatedBlock
                }
            }
        }

        return TodayWorkout(
            id: workout.id,
            date: workout.date,
            title: workout.title,
            exercises: main,
            blocks: adjustedBlocks,
            estimatedDuration: workout.estimatedDuration,
            fitnessGoal: workout.fitnessGoal,
            difficulty: workout.difficulty,
            warmUpExercises: warmUp,
            coolDownExercises: coolDown
        )
    }

    /// Convert all weights in today's workout between Imperial and Metric and persist
    func convertTodayWorkoutUnits(from old: UnitsSystem, to new: UnitsSystem) {
        guard old != new, let currentWorkout = todayWorkout else { return }

        func convert(_ value: Double) -> Double {
            if old == .imperial && new == .metric { return value / 2.20462 }
            if old == .metric && new == .imperial { return value * 2.20462 }
            return value
        }

        func formatString(_ value: Double) -> String {
            if new == .metric { return String(format: "%.1f", value) }
            return String(format: "%.0f", round(value))
        }

        // Map helper for a single exercise
        func mapExercise(_ ex: TodayWorkoutExercise) -> TodayWorkoutExercise {
            // Convert recommended weight
            let newWeight = ex.weight.map(convert)

            // Convert warmup set strings
            var newWarmups: [WarmupSetData]? = nil
            if let warm = ex.warmupSets {
                newWarmups = warm.map { ws in
                    if let w = Double(ws.weight) {
                        return WarmupSetData(reps: ws.reps, weight: formatString(convert(w)))
                    }
                    return ws
                }
            }

            // Convert flexible set weight strings
            var newFlexibleSets: [FlexibleSetData]? = nil
            if let flex = ex.flexibleSets {
                newFlexibleSets = flex.map { fs in
                    var updated = fs
                    if let wStr = fs.weight, let w = Double(wStr) {
                        let converted = convert(w)
                        updated.weight = formatString(converted)
                    }
                    return updated
                }
            }

            return TodayWorkoutExercise(
                exercise: ex.exercise,
                sets: ex.sets,
                reps: ex.reps,
                weight: newWeight,
                restTime: ex.restTime,
                notes: ex.notes,
                warmupSets: newWarmups,
                flexibleSets: newFlexibleSets,
                trackingType: ex.trackingType
            )
        }

        // Apply to all sections
        let convertedExercises = currentWorkout.exercises.map(mapExercise)
        let convertedWarmups = currentWorkout.warmUpExercises?.map(mapExercise)
        let convertedCooldowns = currentWorkout.coolDownExercises?.map(mapExercise)

        let updatedWorkout = TodayWorkout(
            id: currentWorkout.id,
            date: currentWorkout.date,
            title: currentWorkout.title,
            exercises: convertedExercises,
            blocks: currentWorkout.blocks,
            estimatedDuration: currentWorkout.estimatedDuration,
            fitnessGoal: currentWorkout.fitnessGoal,
            difficulty: currentWorkout.difficulty,
            warmUpExercises: convertedWarmups,
            coolDownExercises: convertedCooldowns
        )

        todayWorkout = sanitizeWarmupsIfNeeded(updatedWorkout)
        saveTodayWorkout()
        UserDefaults.standard.set(new.rawValue, forKey: "workoutUnitsSystem")
        print("🔁 Converted todayWorkout units from \(old.rawValue) to \(new.rawValue)")
    }

    /// Remove all stored warm-up sets from the current workouts when the user disables them.
    func clearWarmupSetsForCurrentWorkout() {
        manualWarmupExerciseIDs.removeAll()
        if let workout = todayWorkout {
            todayWorkout = stripWarmups(from: workout)
            saveTodayWorkout()
        }

        if let activeWorkout = currentWorkout {
            currentWorkout = stripWarmups(from: activeWorkout)
        }
    }

    private func stripWarmups(from exercise: TodayWorkoutExercise) -> TodayWorkoutExercise {
        if manualWarmupExerciseIDs.contains(exercise.exercise.id) {
            return exercise
        }
        if !userProfileService.warmupSetsEnabled,
           let warmups = exercise.warmupSets,
           !warmups.isEmpty {
            manualWarmupExerciseIDs.insert(exercise.exercise.id)
            return exercise
        }
        let filteredFlexible = exercise.flexibleSets?.filter { !$0.isWarmupSet }
        let normalizedFlexible = (filteredFlexible?.isEmpty ?? true) ? nil : filteredFlexible

        return TodayWorkoutExercise(
            exercise: exercise.exercise,
            sets: exercise.sets,
            reps: exercise.reps,
            weight: exercise.weight,
            restTime: exercise.restTime,
            notes: exercise.notes,
            warmupSets: nil,
            flexibleSets: normalizedFlexible,
            trackingType: exercise.trackingType
        )
    }

    private func stripWarmups(from workout: TodayWorkout) -> TodayWorkout {
        TodayWorkout(
            id: workout.id,
            date: workout.date,
            title: workout.title,
            exercises: workout.exercises.map(stripWarmups),
            blocks: workout.blocks,
            estimatedDuration: workout.estimatedDuration,
            fitnessGoal: workout.fitnessGoal,
            difficulty: workout.difficulty,
            warmUpExercises: workout.warmUpExercises,
            coolDownExercises: workout.coolDownExercises
        )
    }

    private func sanitizeWarmupsIfNeeded(_ workout: TodayWorkout) -> TodayWorkout {
        guard !userProfileService.warmupSetsEnabled else { return workout }
        return stripWarmups(from: workout)
    }
    
    @MainActor
    private func buildWorkoutSession(from workout: TodayWorkout,
                                     startTime: Date,
                                     duration: TimeInterval,
                                     context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(name: workout.title, userEmail: userEmail)
        session.startedAt = startTime
        context.insert(session)

        var exerciseInstances: [ExerciseInstance] = []
        let allExercises = (workout.warmUpExercises ?? []) + workout.exercises + (workout.coolDownExercises ?? [])

        for (index, exercise) in allExercises.enumerated() {
            let instance = ExerciseInstance(from: exercise.exercise, orderIndex: index)
            context.insert(instance)
            instance.workoutSession = session

            let (loggedSets, loggedFlexibleSets) = makeLoggedSets(from: exercise, units: preferredUnitsSystem)
            guard !loggedSets.isEmpty else { continue }

            if !loggedFlexibleSets.isEmpty,
               let encoded = try? JSONEncoder().encode(loggedFlexibleSets) {
                instance.flexibleSetsData = encoded
            }

            loggedSets.enumerated().forEach { offset, set in
                set.setNumber = offset + 1
                context.insert(set)
                set.exerciseInstance = instance
            }

            exerciseInstances.append(instance)
        }

        session.exercises = exerciseInstances
        session.completedAt = startTime.addingTimeInterval(duration)
       session.totalDuration = duration
       session.markAsNeedingSync()
        return session
    }

    private func makeLoggedSets(from exercise: TodayWorkoutExercise, units: UnitsSystem) -> ([SetInstance], [FlexibleSetData]) {
        guard let flexibleSets = exercise.flexibleSets else { return ([], []) }

        var results: [SetInstance] = []
        var capturedFlexibleSets: [FlexibleSetData] = []

        for setData in flexibleSets where !setData.isWarmupSet {
            let wasLogged = setData.wasLogged ?? setData.isCompleted
            guard wasLogged else { continue }

            var sanitizedSet = setData
            sanitizedSet.wasLogged = true
            sanitizedSet.isWarmupSet = false
            sanitizedSet.restTime = setData.restTime
            sanitizedSet.notes = setData.notes

            if (sanitizedSet.reps?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
               let baselineReps = sanitizedSet.baselineReps,
               baselineReps > 0 {
                sanitizedSet.reps = String(baselineReps)
            }

            if sanitizedSet.trackingType == .rounds, sanitizedSet.rounds == nil {
                if let resolvedRounds = resolveRounds(from: sanitizedSet) {
                    sanitizedSet.rounds = resolvedRounds
                }
            }

            if let resolvedDuration = resolveDuration(for: sanitizedSet) {
                sanitizedSet.duration = resolvedDuration
                if sanitizedSet.durationString?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                    sanitizedSet.durationString = formatDurationString(resolvedDuration)
                }
            }

            switch sanitizedSet.trackingType {
            case .repsWeight:
                guard let repsValue = parseInt(sanitizedSet.reps) ?? sanitizedSet.baselineReps, repsValue > 0 else { continue }
                let weightValue = parseWeight(sanitizedSet.weight, units: units) ?? sanitizedSet.baselineWeight

                let set = SetInstance(setNumber: 0, targetReps: repsValue, targetWeight: weightValue)
                set.actualReps = repsValue
                set.actualWeight = weightValue
                set.isCompleted = true
                set.completedAt = Date()
                set.notes = sanitizedSet.notes
                set.trackingType = .repsWeight
                results.append(set)

            case .repsOnly:
                guard let repsValue = parseInt(sanitizedSet.reps) ?? sanitizedSet.baselineReps, repsValue > 0 else { continue }
                let set = SetInstance(setNumber: 0, targetReps: repsValue, targetWeight: nil)
                set.actualReps = repsValue
                set.actualWeight = nil
                set.isCompleted = true
                set.completedAt = Date()
                set.notes = sanitizedSet.notes
                set.trackingType = .repsOnly
                results.append(set)

            case .timeOnly, .holdTime:
                guard let duration = sanitizedSet.duration, duration > 0 else { continue }
                let set = SetInstance(setNumber: 0, targetReps: 0, targetWeight: nil)
                set.isCompleted = true
                set.completedAt = Date()
                set.notes = sanitizedSet.notes
                set.durationSeconds = Int(duration.rounded())
                set.trackingType = sanitizedSet.trackingType
                results.append(set)

            case .timeDistance:
                let distanceUnit = sanitizedSet.distanceUnit ?? defaultDistanceUnit(for: units)
                let distanceMeters = sanitizedSet.distance.map { convertDistance($0, unit: distanceUnit) }
                let duration = sanitizedSet.duration
                guard (duration ?? 0) > 0 || (distanceMeters ?? 0) > 0 else { continue }
                sanitizedSet.distanceUnit = distanceUnit

                let set = SetInstance(setNumber: 0, targetReps: 0, targetWeight: nil)
                set.isCompleted = true
                set.completedAt = Date()
                set.notes = sanitizedSet.notes
                if let duration {
                    set.durationSeconds = Int(duration.rounded())
                }
                if let distanceMeters {
                    set.distanceMeters = distanceMeters
                }
                set.trackingType = .timeDistance
                results.append(set)

            case .rounds:
                guard let rounds = sanitizedSet.rounds ?? sanitizedSet.baselineReps ?? parseInt(sanitizedSet.reps), rounds > 0 else { continue }
                let set = SetInstance(setNumber: 0, targetReps: rounds, targetWeight: nil)
                set.actualReps = rounds
                set.isCompleted = true
                set.completedAt = Date()
                set.notes = sanitizedSet.notes
                if let duration = sanitizedSet.duration, duration > 0 {
                    set.durationSeconds = Int(duration.rounded())
                }
                set.trackingType = .rounds
                sanitizedSet.rounds = rounds
                results.append(set)
            }

            sanitizedSet.isCompleted = true
            capturedFlexibleSets.append(sanitizedSet)
        }

        return (results, capturedFlexibleSets)
    }

    private func resolveRounds(from set: FlexibleSetData) -> Int? {
        if let rounds = set.rounds, rounds > 0 {
            return rounds
        }
        if let repsString = set.reps, let reps = parseInt(repsString), reps > 0 {
            return reps
        }
        if let baseline = set.baselineReps, baseline > 0 {
            return baseline
        }
        return nil
    }

    private func resolveDuration(for set: FlexibleSetData) -> TimeInterval? {
        if let duration = set.duration, duration > 0 {
            return duration
        }
        if let baseline = set.baselineDuration, baseline > 0 {
            return baseline
        }
        if let durationString = set.durationString,
           let parsed = parseDurationString(durationString),
           parsed > 0 {
            return parsed
        }
        return nil
    }

    private func parseDurationString(_ value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let components = trimmed.split(separator: ":")
        guard !components.isEmpty else { return nil }

        var totalSeconds = 0
        for component in components {
            guard let number = Int(component) else { return nil }
            totalSeconds = totalSeconds * 60 + number
        }

        return TimeInterval(totalSeconds)
    }

    private func formatDurationString(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func defaultDistanceUnit(for units: UnitsSystem) -> DistanceUnit {
        switch units {
        case .metric:
            return .kilometers
        case .imperial:
            return .miles
        }
    }

    private func parseInt(_ string: String?) -> Int? {
        guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let sanitized = raw.filter { "0123456789.,".contains($0) }.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(sanitized) else { return nil }
        return Int(value.rounded())
    }

    private func parseWeight(_ string: String?, units: UnitsSystem) -> Double? {
        guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let sanitized = raw.filter { "0123456789.,".contains($0) }.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(sanitized) else { return nil }
        return value
    }

    private func convertDistance(_ value: Double, unit: DistanceUnit?) -> Double {
        guard let unit else { return value }
        switch unit {
        case .kilometers:
            return value * 1000.0
        case .miles:
            return value * 1609.34
        case .meters:
            return value
        }
    }

    private func legacyExercise(from data: ExerciseData) -> LegacyExercise {
        LegacyExercise(
            id: data.id,
            name: data.name,
            category: data.category,
            description: data.synergist.isEmpty ? nil : data.synergist,
            instructions: data.instructions
        )
    }

    private func convertToWorkoutExercises(from workout: TodayWorkout) -> [WorkoutExercise] {
        workout.exercises.map { exercise in
            let durationValue: Int?
            if let tracking = exercise.trackingType,
               (tracking == .timeOnly || tracking == .holdTime),
               let duration = exercise.flexibleSets?.first?.duration {
                durationValue = Int(duration)
            } else {
                durationValue = nil
            }

            let sets = (0..<max(exercise.sets, 1)).map { index in
                WorkoutSet(
                    id: index + 1,
                    reps: exercise.reps,
                    weight: exercise.weight,
                    duration: durationValue,
                    distance: nil,
                    restTime: exercise.restTime
                )
            }

            return WorkoutExercise(
                id: Int.random(in: 1000...9999),
                exercise: legacyExercise(from: exercise.exercise),
                sets: sets,
                notes: exercise.notes
            )
        }
    }

    private func makeCompletedExercises(from workout: TodayWorkout) -> [CompletedExercise] {
        let exercises = convertToWorkoutExercises(from: workout)
        return exercises.map { workoutExercise in
            let completedSets = workoutExercise.sets.map { set in
                CompletedSet(
                    reps: set.reps ?? 0,
                    weight: set.weight ?? 0,
                    restTime: set.restTime.map { TimeInterval($0) },
                    completed: true
                )
            }

            return CompletedExercise(
                exerciseId: workoutExercise.exercise.id,
                exerciseName: workoutExercise.exercise.name,
                sets: completedSets
            )
        }
    }

    func registerManualWarmup(for exerciseId: Int) {
        manualWarmupExerciseIDs.insert(exerciseId)
    }

    func unregisterManualWarmup(for exerciseId: Int) {
        manualWarmupExerciseIDs.remove(exerciseId)
    }

    func setModelContext(_ context: ModelContext) {
        lastModelContext = context
    }

    /// Start workout session
    func startWorkout(_ workout: TodayWorkout) {
        let sanitized = sanitizeWarmupsIfNeeded(workout)
        currentWorkout = sanitized
        let state = ActiveWorkoutState(
            workoutId: sanitized.id,
            startedAt: Date(),
            lastActivityAt: Date()
        )
        activeWorkoutState = state
        persistActiveWorkoutState(state)
        print("🏃‍♂️ WorkoutManager: Started workout - \(sanitized.title)")
    }

    /// Cancel the active workout session without logging it.
    /// Keeps today's workout so the user can restart later.
    func cancelActiveWorkout(discardSessionOverrides: Bool = false) {
        guard currentWorkout != nil || activeWorkoutState != nil else { return }
        currentWorkout = nil
        clearActiveWorkoutState()

        if discardSessionOverrides {
            clearSessionOverrides()
        }
    }
    
    func registerWorkoutActivity() {
        let now = Date()

        if var state = activeWorkoutState {
            state.lastActivityAt = now
            activeWorkoutState = state
            persistActiveWorkoutState(state)
            return
        }

        if currentWorkout == nil, let today = todayWorkout {
            currentWorkout = sanitizeWarmupsIfNeeded(today)
        }

        let workoutId = currentWorkout?.id ?? todayWorkout?.id ?? UUID()
        let state = ActiveWorkoutState(workoutId: workoutId,
                                       startedAt: now,
                                       lastActivityAt: now)
        activeWorkoutState = state
        persistActiveWorkoutState(state)
    }

    func pauseActiveWorkout(at date: Date = Date()) {
        if activeWorkoutState == nil {
            registerWorkoutActivity()
        }

        guard var state = activeWorkoutState else { return }
        guard state.pauseBeganAt == nil else { return }

        state.pauseBeganAt = date
        state.lastActivityAt = date
        activeWorkoutState = state
        persistActiveWorkoutState(state)
        print("⏸️ WorkoutManager: Paused active workout at \(date)")
    }

    func resumeActiveWorkout(at date: Date = Date()) {
        guard var state = activeWorkoutState else { return }
        guard let pauseStart = state.pauseBeganAt else { return }
        guard date >= pauseStart else { return }

        let interval = DateInterval(start: pauseStart, end: date)
        if interval.duration > 0 {
            state.pausedIntervals.append(interval)
        }

        state.pauseBeganAt = nil
        state.lastActivityAt = date
        activeWorkoutState = state
        persistActiveWorkoutState(state)
        let formatted = String(format: "%.0f", interval.duration)
        print("▶️ WorkoutManager: Resumed workout, paused for \(formatted)s")
    }

    var isActiveWorkoutPaused: Bool {
        activeWorkoutState?.pauseBeganAt != nil
    }

    func currentActiveWorkoutDuration(asOf referenceDate: Date = Date()) -> TimeInterval? {
        guard let state = activeWorkoutState else { return nil }
        let endTime = max(referenceDate, state.lastActivityAt)
        let pausedDuration = state.totalPausedDuration(referenceDate: endTime)
        let rawDuration = endTime.timeIntervalSince(state.startedAt) - pausedDuration
        return max(rawDuration, 0)
    }

    func applyActiveExerciseUpdate(_ exercise: TodayWorkoutExercise) {
        let sanitizedExercise = stripWarmups(from: exercise)

        if var active = currentWorkout,
           let index = active.exercises.firstIndex(where: { $0.exercise.id == sanitizedExercise.exercise.id }) {
            active.exercises[index] = sanitizedExercise
            currentWorkout = active
        }

        if var today = todayWorkout,
           let index = today.exercises.firstIndex(where: { $0.exercise.id == exercise.exercise.id }) {
            today.exercises[index] = exercise
            todayWorkout = sanitizeWarmupsIfNeeded(today)
            saveTodayWorkout()
        }
    }

    /// Complete workout session
    func completeWorkout(autoComplete: Bool = false, context: ModelContext? = nil) {
        let resolvedContext: ModelContext
        if let context {
            resolvedContext = context
            lastModelContext = context
        } else if let cachedContext = lastModelContext {
            resolvedContext = cachedContext
        } else {
            print("❌ WorkoutManager: Missing ModelContext for completing workout")
            cleanupAfterIncompleteCompletion()
            return
        }

        guard let sourceWorkout = currentWorkout ?? todayWorkout else { return }
        let workout = sanitizeWarmupsIfNeeded(sourceWorkout)
        let now = Date()
        let state = activeWorkoutState
        let startTime = state?.startedAt ?? now
        let lastActivity = state?.lastActivityAt ?? now
        let endTime = lastActivity > now ? lastActivity : now
        let pausedDuration = state?.totalPausedDuration(referenceDate: endTime) ?? 0
        let rawDuration = endTime.timeIntervalSince(startTime)
        let duration = max(rawDuration - pausedDuration, 0)
        if pausedDuration > 0 {
            print("⏱️ WorkoutManager: Excluding paused time (\(pausedDuration)s) from workout duration")
        }
        let unitsSystem = preferredUnitsSystem
        let summary = WorkoutCalculationService.shared.buildSummary(for: workout,
                                                                    duration: duration,
                                                                    unitsSystem: unitsSystem,
                                                                    profile: userProfileService.profileData)

        // Persist workout session details for history & sync
        Task { @MainActor [resolvedContext] in
            do {
                let workoutSession = buildWorkoutSession(from: workout,
                                                         startTime: startTime,
                                                         duration: duration,
                                                         context: resolvedContext)
                try await workoutDataManager.saveWorkout(workoutSession, context: resolvedContext)

                // Immediately emit an optimistic CombinedLog so Dashboard shows the workout right away
                let optimistic = makeOptimisticCombinedLog(for: workoutSession)
                NotificationCenter.default.post(
                    name: .workoutDataChanged,
                    object: nil,
                    userInfo: ["workouts": [optimistic], "optimistic": true]
                )

                // Sync immediately so workout appears in dashboard before user dismisses summary
                await workoutDataManager.syncNow(context: resolvedContext)

                let status = autoComplete ? "Auto-completed" : "Completed"
                print("✅ WorkoutManager: \(status) and saved workout")
            } catch {
                print("❌ WorkoutManager: Failed to save completed workout: \(error)")
            }
        }

        // Invalidate history caches so SwiftUI surfaces the new session immediately
        Task {
            let ids = Set(workout.exercises.map { $0.exercise.id })
            for id in ids {
                await ExerciseHistoryDataService.shared.invalidateCache(for: id)
            }
        }

        let completedExercises = makeCompletedExercises(from: workout)
        recoveryService.recordWorkout(completedExercises)

        LogWorkoutView.clearWorkoutSessionDuration()

        if !autoComplete, dynamicParameters != nil {
            NotificationCenter.default.post(
                name: .workoutCompletedNeedsFeedback,
                object: workout
            )
        }

        // Clear active workout state and persistence
        currentWorkout = nil
        clearActiveWorkoutState()
        clearSessionOverrides()
        todayWorkout = nil
        todayWorkoutMuscleGroups = []
        todayWorkoutRecoverySnapshot = nil
        clearTodayWorkoutStorage()

        if autoComplete {
            pendingSummaryRegeneration = false
            scheduleNextWorkoutGeneration()
            Task { @MainActor [resolvedContext] in
                try? await Task.sleep(nanoseconds: 300_000_000)
                await workoutDataManager.syncNow(context: resolvedContext)
            }
        } else {
            completedWorkoutSummary = summary
            pendingSummaryRegeneration = true
            isDisplayingSummary = true
        }
    }

    private func cleanupAfterIncompleteCompletion() {
        currentWorkout = nil
        clearActiveWorkoutState()
        clearSessionOverrides()
        todayWorkout = nil
        todayWorkoutMuscleGroups = []
        todayWorkoutRecoverySnapshot = nil
        todayWorkoutBodyweightOnly = nil
        clearTodayWorkoutStorage()
    }

    func dismissWorkoutSummary() {
        // Store the completed workout before clearing it
        if let summary = completedWorkoutSummary {
            lastCompletedWorkout = summary
        }

        completedWorkoutSummary = nil
        isDisplayingSummary = false

        if pendingSummaryRegeneration {
            pendingSummaryRegeneration = false
            scheduleNextWorkoutGeneration()
        }

        // Note: Sync already happened immediately in completeWorkout(), no need to sync again here
        // Note: Both DayLogsRepository and CombinedLogsRepository refreshes
        // moved to LogWorkoutView after dismiss to avoid re-render loop
    }

    func setWorkoutViewActive(_ active: Bool) {
        guard isWorkoutViewActive != active else { return }
        isWorkoutViewActive = active

        if !active, let context = lastModelContext {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                await workoutDataManager.performDeferredSyncIfNeeded(context: context)
            }
        }
    }
    
    /// Update flexibility preferences
    func updateFlexibilityPreferences(_ preferences: FlexibilityPreferences, isSession: Bool) {
        if isSession {
            sessionFlexibilityPreferences = preferences
            saveSessionData()
        } else {
            // Update default preferences - handled by the server sync
            // The computed property will return default FlexibilityPreferences()
            
            // Sync with server
            Task {
                if let email = UserDefaults.standard.string(forKey: "userEmail") {
                    NetworkManagerTwo.shared.updateFlexibilityPreferences(
                        email: email,
                        warmUpEnabled: preferences.warmUpEnabled,
                        coolDownEnabled: preferences.coolDownEnabled
                    ) { result in
                        switch result {
                        case .success:
                            print("✅ Flexibility preferences synced with server")
                        case .failure(let error):
                            print("❌ Failed to sync flexibility preferences: \(error)")
                        }
                    }
                }
            }
        }
        
        // Regenerate workout with new preferences
        Task {
            await generateTodayWorkout()
        }
    }
    
    /// Clear all session overrides
    func clearSessionOverrides() {
        sessionDuration = nil
        sessionFitnessGoal = nil
        sessionFitnessLevel = nil
        sessionFlexibilityPreferences = nil
        customTargetMuscles = nil
        customEquipment = nil
        selectedMuscleType = defaultMuscleType
        selectedEquipmentType = "Auto"

        // Clear from UserDefaults
        clearSessionUserDefaults()

        print("🗑️ WorkoutManager: Cleared all session overrides")
    }

    // MARK: - Private Methods

    // Create an optimistic CombinedLog from a freshly saved WorkoutSession
    private func makeOptimisticCombinedLog(for session: WorkoutSession) -> CombinedLog {
        let rawDuration = session.totalDuration ?? session.duration ?? 0
        let durationMinutes = Int(rawDuration / 60)
        let durationSeconds = Int(rawDuration)

        let totalVolume = session.exercises.reduce(0.0) { total, exercise in
            let exerciseVolume = exercise.sets.reduce(0.0) { setTotal, set in
                let reps = Double(set.actualReps ?? set.targetReps ?? 0)
                let weight = set.actualWeight ?? set.targetWeight ?? 0
                return setTotal + (reps * weight)
            }
            return total + exerciseVolume
        }

        let units = preferredUnitsSystem
        let profile = userProfileService.profileData
        let estimatedCalories = WorkoutCalculationService.shared.estimateCaloriesBurned(
            volume: totalVolume,
            duration: rawDuration,
            profile: profile,
            unitsSystem: units
        )

        let workoutSummary = WorkoutSummary(
            id: session.remoteId ?? -1,
            title: session.name,
            durationMinutes: durationMinutes,
            durationSeconds: durationSeconds,
            exercisesCount: session.exercises.count,
            status: session.completedAt != nil ? "completed" : "in_progress",
            scheduledAt: session.startedAt
        )

        return CombinedLog(
            type: .workout,
            status: "success",
            calories: Double(estimatedCalories),
            message: session.name,
            foodLogId: nil,
            food: nil,
            mealType: nil,
            mealLogId: nil,
            meal: nil,
            mealTime: nil,
            scheduledAt: session.startedAt,
            recipeLogId: nil,
            recipe: nil,
            servingsConsumed: nil,
            activityId: nil,
            activity: nil,
            workoutLogId: session.remoteId,
            workout: workoutSummary,
            logDate: nil,
            dayOfWeek: nil,
            isOptimistic: true
        )
    }

    private var userEmail: String {
        UserDefaults.standard.string(forKey: "userEmail") ?? ""
    }

    private func resetSessionStateForActiveProfile() {
        sessionDuration = nil
        sessionFitnessGoal = nil
        sessionFitnessLevel = nil
        sessionFlexibilityPreferences = nil
        customTargetMuscles = nil
        customEquipment = nil
        defaultTargetMuscles = nil
        defaultMuscleType = "Recovered Muscles"
        selectedMuscleType = defaultMuscleType
        selectedEquipmentType = "Auto"
        sessionRestTimerEnabled = false
        sessionRestWarmupSeconds = 60
        sessionRestWorkingSeconds = 60
    }

    private var preferredUnitsSystem: UnitsSystem {
        if let saved = UserDefaults.standard.string(forKey: "unitsSystem"),
           let units = UnitsSystem(rawValue: saved) {
            return units
        }
        return .imperial
    }

    private func storageKey(_ base: String) -> String {
        guard !userEmail.isEmpty else { return base }
        return "\(base)_\(userEmail)"
    }

    private func profileStorageKey(_ base: String) -> String {
        let emailScoped = userEmail.isEmpty ? base : "\(base)_\(userEmail)"
        return userProfileService.scopedDefaultsKey(emailScoped)
    }

    private func setGenerating(_ generating: Bool, message: String = "") async {
        assertMainActor("setGenerating")
        isGeneratingWorkout = generating
        generationMessage = message
    }
    
    private func backgroundWorkoutGeneration(_ parameters: WorkoutGenerationParameters) async throws -> GeneratedWorkoutResult {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    guard let self = self else {
                        continuation.resume(throwing: WorkoutGenerationError.serviceUnavailable)
                        return
                    }
                    
                    let result = try self.createIntelligentWorkout(parameters)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func createIntelligentWorkout(_ parameters: WorkoutGenerationParameters) throws -> GeneratedWorkoutResult {
        // Get muscle groups based on recovery or custom selection
        var muscleGroups: [String]
        if let customMuscles = parameters.customTargetMuscles, !customMuscles.isEmpty {
            muscleGroups = customMuscles
            print("🎯 WorkoutManager: Using CUSTOM muscle selection: \(muscleGroups)")
        } else {
            // Use schedule-aware + recovery optimization for selection with training split
            let trainingSplit = userProfileService.trainingSplit
            muscleGroups = recoveryService.getScheduleOptimizedMuscleGroups(targetCount: 4, trainingSplit: trainingSplit)

            // FALLBACK: If recovery service returns empty, use default muscles to prevent errors
            if muscleGroups.isEmpty {
                print("⚠️ Recovery service returned empty muscles, using fallback for \(trainingSplit.displayName)")
                muscleGroups = ["Chest", "Back", "Quadriceps", "Shoulders"]
            }

            print("🧠 WorkoutManager: Using split-optimized muscles (\(trainingSplit.displayName)): \(muscleGroups)")
        }

        guard !muscleGroups.isEmpty else {
            throw WorkoutGenerationError.noMuscleGroups
        }
        
        // Delegate to sophisticated WorkoutGenerationService
        var workoutPlan = try workoutGenerationService.generateWorkoutPlan(
            muscleGroups: muscleGroups,
            targetDuration: parameters.duration,
            fitnessGoal: parameters.fitnessGoal,
            experienceLevel: parameters.fitnessLevel,
            customEquipment: parameters.customEquipment,
            flexibilityPreferences: parameters.flexibilityPreferences
        )
        
        // Debug: Force include a duration exercise if flag is enabled
        if debugForceIncludeDurationExercise {
            workoutPlan = try forceDurationExerciseInWorkout(workoutPlan, parameters: parameters)
        }
        
        print("✅ WorkoutManager: Generated \(workoutPlan.exercises.count) exercises, actual duration: \(workoutPlan.actualDurationMinutes) minutes")
        
        // Generate warm-up/cool-down if enabled
        let warmUpExercises = parameters.flexibilityPreferences.warmUpEnabled ?
            generateWarmUpExercises(targetMuscles: muscleGroups, equipment: parameters.customEquipment) : nil
        
        let coolDownExercises = parameters.flexibilityPreferences.coolDownEnabled ?
            generateCoolDownExercises(targetMuscles: muscleGroups, equipment: parameters.customEquipment) : nil
        
        // Build base workout
        let base = TodayWorkout(
            id: UUID(),
            date: Date(),
            title: generateWorkoutTitle(muscleGroups),
            exercises: workoutPlan.exercises,
            estimatedDuration: workoutPlan.actualDurationMinutes,
            fitnessGoal: parameters.fitnessGoal,
            difficulty: parameters.fitnessLevel.workoutComplexity,
            warmUpExercises: warmUpExercises,
            coolDownExercises: coolDownExercises
        )
        let recentBlockTypes: [BlockType] = todayWorkout?.blocks?.map { $0.type } ?? []
        let assembledBlocks = BlockAssemblyService.assembleBlocks(
            from: base,
            goal: parameters.fitnessGoal,
            duration: parameters.duration,
            equipment: parameters.customEquipment,
            recentHistory: recentBlockTypes
        )
        let combinedExercises = BlockAssemblyService.applyBlockSchemes(to: base.exercises, using: assembledBlocks)

        let finalWorkout = TodayWorkout(
            id: base.id,
            date: base.date,
            title: base.title,
            exercises: combinedExercises,
            blocks: assembledBlocks,
            estimatedDuration: base.estimatedDuration,
            fitnessGoal: base.fitnessGoal,
            difficulty: base.difficulty,
            warmUpExercises: base.warmUpExercises,
            coolDownExercises: base.coolDownExercises
        )
        
        return GeneratedWorkoutResult(workout: finalWorkout, muscleGroups: muscleGroups)
    }
    
    private func generateWarmUpExercises(targetMuscles: [String], equipment: [Equipment]?) -> [TodayWorkoutExercise] {
        // FITBOD-ALIGNED: Get warmup exercises using proper method
        return recommendationService.getWarmUpExercises(
            targetMuscles: targetMuscles,
            customEquipment: equipment,
            count: 3
        )
    }
    
    private func generateCoolDownExercises(targetMuscles: [String], equipment: [Equipment]?) -> [TodayWorkoutExercise] {
        // FITBOD-ALIGNED: Get cooldown exercises using proper method
        return recommendationService.getCoolDownExercises(
            targetMuscles: targetMuscles,
            customEquipment: equipment,
            count: 3
        )
    }
    
    // MARK: - Debug Helper Functions
    
    /// Debug function to force inclusion of a duration-based exercise in the workout
    private func forceDurationExerciseInWorkout(_ workoutPlan: WorkoutPlan, parameters: WorkoutGenerationParameters) throws -> WorkoutPlan {
        print("🔧 DEBUG: Forcing duration exercise inclusion in workout")
        
        // Check if we already have a duration-based exercise
        let hasDurationExercise = workoutPlan.exercises.contains { exercise in
            let trackingType = ExerciseClassificationService.determineTrackingType(for: exercise.exercise)
            return trackingType == .timeOnly || trackingType == .timeDistance || trackingType == .holdTime
        }
        
        if hasDurationExercise {
            print("🔧 DEBUG: Workout already contains a duration exercise, no changes needed")
            return workoutPlan
        }
        
        // Find a suitable duration exercise from the actual database
        let durationExercise = getDurationExerciseFromDatabase()
        
        // Build a proper duration-based exercise (3 × 30s) to preserve tracking
        let intervalCount = 3
        var flexSets: [FlexibleSetData] = []
        for _ in 0..<intervalCount {
            var set = FlexibleSetData(trackingType: .timeOnly)
            set.duration = 30
            set.durationString = String(format: "%d:%02d", 0, 30)
            flexSets.append(set)
        }
        let durationWorkoutExercise = TodayWorkoutExercise(
            exercise: durationExercise,
            sets: intervalCount,
            reps: 1,
            weight: nil,
            restTime: 60,
            notes: "DEBUG: Forced duration exercise for testing",
            warmupSets: nil,
            flexibleSets: flexSets,
            trackingType: .timeOnly
        )
        
        // Replace the last exercise with our duration exercise to keep workout length reasonable
        var modifiedExercises = workoutPlan.exercises
        if !modifiedExercises.isEmpty {
            modifiedExercises[modifiedExercises.count - 1] = durationWorkoutExercise
            print("🔧 DEBUG: Replaced last exercise with Plank Hold for duration testing")
        } else {
            modifiedExercises.append(durationWorkoutExercise)
            print("🔧 DEBUG: Added Plank Hold as first exercise for duration testing")
        }
        
        return WorkoutPlan(
            exercises: modifiedExercises,
            actualDurationMinutes: workoutPlan.actualDurationMinutes, // Keep same duration estimate
            totalTimeBreakdown: workoutPlan.totalTimeBreakdown
        )
    }
    
    /// Get a duration-based exercise from the actual exercise database
    private func getDurationExerciseFromDatabase() -> ExerciseData {
        let allExercises = ExerciseDatabase.getAllExercises()
        
        // Look for duration-based exercises (exercises that are typically time-based)
        let durationExerciseNames = [
            "Plank", "Hold", "Mountain Climber", "Burpee", "Bear Crawl",
            "Spider Plank", "Side Plank", "Front Plank", "Body Saw Plank",
            "Plank Jack", "Iron Cross Plank", "Stability Ball Front Plank"
        ]
        
        // Find exercises that match duration exercise patterns
        let durationExercises = allExercises.filter { exercise in
            // Check if exercise name contains any duration exercise keywords
            let exerciseName = exercise.name.lowercased()
            return durationExerciseNames.contains { keyword in
                exerciseName.contains(keyword.lowercased())
            } ||
            // Also look for exercises classified as Aerobic (often time-based)
            exercise.exerciseType == "Aerobic" ||
            // Or exercises with "Cardio" body part
            exercise.bodyPart == "Cardio" ||
            // Or stretching exercises (often held for time)
            exercise.exerciseType == "Stretching"
        }
        
        // Prefer core/plank exercises for consistency with user's testing scenario
        let plankExercises = durationExercises.filter { exercise in
            exercise.name.lowercased().contains("plank")
        }
        
        if let plankExercise = plankExercises.first {
            print("🔧 DEBUG: Selected plank exercise for duration testing: \(plankExercise.name)")
            return plankExercise
        }
        
        // Fallback to any duration exercise
        if let durationExercise = durationExercises.first {
            print("🔧 DEBUG: Selected duration exercise for testing: \(durationExercise.name)")
            return durationExercise
        }
        
        // Final fallback - use Mountain Climber if nothing else found
        print("🔧 DEBUG: No duration exercises found, using fallback Mountain Climber")
        return ExerciseData(
            id: 630,
            name: "Mountain Climber",
            exerciseType: "Aerobic",
            bodyPart: "Cardio",
            equipment: "Body weight",
            gender: "Male",
            target: "",
            synergist: ""
        )
    }

    private func captureCurrentRecoverySnapshot() -> [String: Double] {
        recoveryService.captureRecoverySnapshot()
    }

    private func hasSignificantRecoveryChange(for workout: TodayWorkout) -> Bool {
        guard let snapshot = todayWorkoutRecoverySnapshot else { return false }
        guard Date().timeIntervalSince(workout.date) >= 6 * 60 * 60 else { return false }
        return recoveryService.hasSignificantRecoveryChange(
            since: snapshot,
            muscles: todayWorkoutMuscleGroups
        )
    }

    private func shouldRegenerateWorkout(using workout: TodayWorkout) -> Bool {
        if !Calendar.current.isDateInToday(workout.date) {
            return true
        }
        if let state = activeWorkoutState,
           state.workoutId == workout.id,
           state.hasTimedOut(timeout: sessionTimeoutInterval) {
            autoCompleteAbandonedWorkout()
            return false
        }
        if hasSignificantRecoveryChange(for: workout) {
            return true
        }
        if hasTrainingSplitChanged() {
            return true
        }
        if hasBodyweightPreferenceChanged() {
            return true
        }
        return false
    }

    private func hasTrainingSplitChanged() -> Bool {
        let currentSplit = userProfileService.trainingSplit.rawValue
        let savedSplit = todayWorkoutTrainingSplit

        if currentSplit != savedSplit {
            print("🔄 Training split changed from \(savedSplit ?? "nil") to \(currentSplit), regenerating workout")
            return true
        }
        return false
    }

    private func hasBodyweightPreferenceChanged() -> Bool {
        let currentPreference = userProfileService.bodyweightOnlyWorkouts
        if let storedPreference = todayWorkoutBodyweightOnly {
            return storedPreference != currentPreference
        }
        // If we have an existing workout but no stored preference, regenerate only when bodyweight mode is enabled.
        return currentPreference
    }

    private func setupSessionMonitoring() {
        sessionMonitorTimer?.invalidate()
        let timer = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.checkForAbandonedSession()
            }
        }
        sessionMonitorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func checkForAbandonedSession() {
        guard let state = activeWorkoutState else { return }
        if state.hasTimedOut(timeout: sessionTimeoutInterval) {
            print("🕒 Auto-completing abandoned workout after timeout")
            autoCompleteAbandonedWorkout()
        }
    }

    private func autoCompleteAbandonedWorkout() {
        guard let workout = todayWorkout,
              let state = activeWorkoutState,
              workout.id == state.workoutId else {
            clearActiveWorkoutState()
            return
        }
        // Complete using the cached workout without presenting the in-progress UI
        // (currentWorkout is intentionally left nil to avoid auto-launching the logging surface)
        completeWorkout(autoComplete: true)
    }

    private func scheduleNextWorkoutGeneration() {
        Task { @MainActor [weak self] in
            guard let self, !self.isGeneratingWorkout else { return }
            await self.generateTodayWorkout()
        }
    }

    private func generateWorkoutTitle(_ muscleGroups: [String]) -> String {
        let normalized = muscleGroups.map { $0.lowercased() }
        let muscleSet = Set(normalized)

        let pushMuscles: Set<String> = ["chest", "shoulders", "triceps"]
        let pullMuscles: Set<String> = ["back", "biceps", "rear delts", "forearms"]
        let lowerMuscles: Set<String> = ["quadriceps", "hamstrings", "glutes", "calves", "lower back", "hips", "thighs"]
        let coreMuscles: Set<String> = ["abs", "core", "waist"]

        let hasPush = !muscleSet.isDisjoint(with: pushMuscles)
        let hasPull = !muscleSet.isDisjoint(with: pullMuscles)
        let hasLower = !muscleSet.isDisjoint(with: lowerMuscles)
        let hasCoreOnly = muscleSet.subtracting(pushMuscles).subtracting(pullMuscles).subtracting(lowerMuscles).isSubset(of: coreMuscles)

        let rawTitle: String

        switch (hasPush, hasPull, hasLower) {
        case (true, false, false):
            rawTitle = "Push Day"
        case (false, true, false):
            rawTitle = "Pull Day"
        case (true, true, false):
            rawTitle = "Upper Body Day"
        case (false, false, true):
            rawTitle = "Lower Body Day"
        case (true, false, true), (false, true, true), (true, true, true):
            rawTitle = "Full Body Day"
        default:
            if hasCoreOnly {
                rawTitle = "Core Day"
            } else if let single = muscleGroups.first, muscleGroups.count == 1 {
                rawTitle = "\(single) Day"
            } else {
                rawTitle = "Today's Workout"
            }
        }

        return sanitizeWorkoutTitle(rawTitle)
    }

    var todayWorkoutDisplayTitle: String {
        guard let workout = todayWorkout else { return "Today's Workout" }
        return sanitizeWorkoutTitle(workout.title)
    }

    private func sanitizeWorkoutTitle(_ rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Today's Workout" }

        let components = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        let candidateComponent = components.last?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = (components.count > 1 && !(candidateComponent?.isEmpty ?? true)) ? candidateComponent! : trimmed

        var allowed = CharacterSet.alphanumerics
        allowed.formUnion(.whitespacesAndNewlines)
        allowed.insert(charactersIn: "-'&/()")

        let filteredScalars = candidate.unicodeScalars.filter { allowed.contains($0) }
        let cleaned = String(String.UnicodeScalarView(filteredScalars))
        let condensed = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let finalTitle = condensed.trimmingCharacters(in: .whitespacesAndNewlines)

        return finalTitle.isEmpty ? "Today's Workout" : finalTitle
    }
    
    private func setupObservers() {
        // Listen for user profile changes to update defaults
        // CRITICAL FIX: Ensure updates arrive on main thread to prevent
        // "Updating ObservedObject from background threads" violations
        userProfileService.$profileData
            .compactMap { $0 }
            .receive(on: RunLoop.main)  // ← Force main thread context
            .sink { [weak self] _ in
                // Profile data updated, could trigger workout regeneration if needed
            }
            .store(in: &cancellables)

        userProfileService.$activeWorkoutProfileId
            .removeDuplicates()
            .receive(on: RunLoop.main)  // ← Force main thread context
            .sink { [weak self] _ in
                self?.handleActiveWorkoutProfileChange()
            }
            .store(in: &cancellables)
    }

    private func handleActiveWorkoutProfileChange() {
        assertMainActor("handleActiveWorkoutProfileChange")
        // Reset in-memory session state so new profile starts cleanly
        resetSessionStateForActiveProfile()

        // Reload defaults and any stored overrides for the new profile
        loadDefaultMusclePreferences()
        loadSessionData()

        // Refresh cached workouts for the active profile scope
        todayWorkout = nil
        currentWorkout = nil
        todayWorkoutRecoverySnapshot = nil
        todayWorkoutMuscleGroups = []
        activeWorkoutState = nil

        loadTodayWorkout()
    }
    
    // MARK: - Persistence
    
    private func loadTodayWorkout() {
        assertMainActor("loadTodayWorkout")
        loadTodayWorkoutMetadata()
        let key = profileStorageKey(todayWorkoutKey)
        
        if let data = UserDefaults.standard.data(forKey: key),
           let workout = try? JSONDecoder().decode(TodayWorkout.self, from: data) {
            let sanitized = sanitizeWarmupsIfNeeded(workout)
            todayWorkout = sanitized
            
            if shouldRegenerateWorkout(using: sanitized) {
                print("📱 WorkoutManager: Regenerating workout due to recovery or schedule changes")
                Task { await generateTodayWorkout() }
            } else if let currentWorkout = todayWorkout {
                restoreActiveSessionIfNeeded(for: currentWorkout)
                print("📱 WorkoutManager: Loaded existing workout from storage")
            }
        } else {
            print("📱 WorkoutManager: No existing workout found, will generate new one")
            Task { await generateTodayWorkout() }
        }
        
        checkForAbandonedSession()
    }

    func cachedTodayWorkout() -> TodayWorkout? {
        let key = profileStorageKey(todayWorkoutKey)
        guard let data = UserDefaults.standard.data(forKey: key),
              let workout = try? JSONDecoder().decode(TodayWorkout.self, from: data) else {
            return nil
        }

        guard Calendar.current.isDateInToday(workout.date) else {
            return nil
        }

        return sanitizeWarmupsIfNeeded(workout)
    }

    private func saveTodayWorkout() {
        assertMainActor("saveTodayWorkout")
        guard let workout = todayWorkout else { return }
        let key = profileStorageKey(todayWorkoutKey)
        
        if let data = try? JSONEncoder().encode(workout) {
            UserDefaults.standard.set(data, forKey: key)
            saveTodayWorkoutMetadata()
            print("💾 WorkoutManager: Saved today's workout to storage")
        }
    }
    
    private func saveTodayWorkoutMetadata() {
        let defaults = UserDefaults.standard
        let snapshotKey = profileStorageKey(todayWorkoutRecoverySnapshotKey)
        let musclesKey = profileStorageKey(todayWorkoutMusclesKey)
        let splitKey = profileStorageKey(todayWorkoutTrainingSplitKey)

        if let snapshot = todayWorkoutRecoverySnapshot,
           let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        } else {
            defaults.removeObject(forKey: snapshotKey)
        }

        if !todayWorkoutMuscleGroups.isEmpty {
            defaults.set(todayWorkoutMuscleGroups, forKey: musclesKey)
        } else {
            defaults.removeObject(forKey: musclesKey)
        }

        if let split = todayWorkoutTrainingSplit {
            defaults.set(split, forKey: splitKey)
        } else {
            defaults.removeObject(forKey: splitKey)
        }

        let bodyweightKey = profileStorageKey(todayWorkoutBodyweightOnlyKey)
        if let preference = todayWorkoutBodyweightOnly {
            defaults.set(preference, forKey: bodyweightKey)
        } else {
            defaults.removeObject(forKey: bodyweightKey)
        }
    }
    
    private func loadTodayWorkoutMetadata() {
        let defaults = UserDefaults.standard
        let snapshotKey = profileStorageKey(todayWorkoutRecoverySnapshotKey)
        let musclesKey = profileStorageKey(todayWorkoutMusclesKey)
        let splitKey = profileStorageKey(todayWorkoutTrainingSplitKey)
        let bodyweightKey = profileStorageKey(todayWorkoutBodyweightOnlyKey)

        if let data = defaults.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode([String: Double].self, from: data) {
            todayWorkoutRecoverySnapshot = snapshot
        } else {
            todayWorkoutRecoverySnapshot = nil
        }

        if let muscles = defaults.array(forKey: musclesKey) as? [String] {
            todayWorkoutMuscleGroups = muscles
        } else {
            todayWorkoutMuscleGroups = []
        }

        todayWorkoutTrainingSplit = defaults.string(forKey: splitKey)

        if defaults.object(forKey: bodyweightKey) != nil {
            todayWorkoutBodyweightOnly = defaults.bool(forKey: bodyweightKey)
        } else {
            todayWorkoutBodyweightOnly = nil
        }

        activeWorkoutState = loadActiveWorkoutState()
    }
    
    private func clearTodayWorkoutStorage() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: profileStorageKey(todayWorkoutKey))
        defaults.removeObject(forKey: profileStorageKey(todayWorkoutRecoverySnapshotKey))
        defaults.removeObject(forKey: profileStorageKey(todayWorkoutMusclesKey))
        defaults.removeObject(forKey: profileStorageKey(todayWorkoutTrainingSplitKey))
        defaults.removeObject(forKey: profileStorageKey(todayWorkoutBodyweightOnlyKey))
        todayWorkoutBodyweightOnly = nil
    }

    private func loadActiveWorkoutState() -> ActiveWorkoutState? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: profileStorageKey(activeWorkoutStateKey)) else { return nil }
        return try? JSONDecoder().decode(ActiveWorkoutState.self, from: data)
    }

    private func persistActiveWorkoutState(_ state: ActiveWorkoutState?) {
        let defaults = UserDefaults.standard
        let key = profileStorageKey(activeWorkoutStateKey)
        if let state = state, let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
    
    private func restoreActiveSessionIfNeeded(for workout: TodayWorkout) {
        guard let state = activeWorkoutState else { return }
        guard state.workoutId == workout.id else {
            clearActiveWorkoutState()
            return
        }
        if currentWorkout == nil {
            currentWorkout = workout
            print("🏃‍♂️ Restored in-progress workout session from storage")
        }
    }
    
    private func clearActiveWorkoutState() {
        activeWorkoutState = nil
        persistActiveWorkoutState(nil)
    }
    
    private func loadSessionData() {
        sessionDuration = nil
        sessionFitnessGoal = nil
        sessionFitnessLevel = nil
        sessionFlexibilityPreferences = nil
        customTargetMuscles = nil
        customEquipment = nil
        selectedMuscleType = defaultMuscleType
        selectedEquipmentType = "Auto"
        sessionRestTimerEnabled = false
        sessionRestWarmupSeconds = 60
        sessionRestWorkingSeconds = 60

        // Load session duration
        if let savedDurationString = UserDefaults.standard.string(forKey: profileScopedKey(sessionDurationKey)),
           let savedDuration = WorkoutDuration(rawValue: savedDurationString) {

            if let sessionDate = UserDefaults.standard.object(forKey: profileScopedKey(sessionDateKey)) as? Date,
               Calendar.current.isDateInToday(sessionDate) {
                sessionDuration = savedDuration
            } else {
                clearSessionUserDefaults()
            }
        }
        
        // Load other session data similarly...
        if let savedGoalString = UserDefaults.standard.string(forKey: profileScopedKey(sessionFitnessGoalKey)) {
            sessionFitnessGoal = FitnessGoal(rawValue: savedGoalString)
        }
        
        if let savedMuscles = UserDefaults.standard.array(forKey: profileScopedKey(customMusclesKey)) as? [String],
           !savedMuscles.isEmpty {
            customTargetMuscles = savedMuscles
            if let muscleType = UserDefaults.standard.string(forKey: profileScopedKey(sessionMuscleTypeKey)), !muscleType.isEmpty {
                selectedMuscleType = muscleType
            }
        }
        
        if let flexibilityData = UserDefaults.standard.data(forKey: profileScopedKey(sessionFlexibilityKey)),
           let flexibility = try? JSONDecoder().decode(FlexibilityPreferences.self, from: flexibilityData) {
            sessionFlexibilityPreferences = flexibility
        }

        // Load rest timer session settings (same-day)
        if let sessionDate = UserDefaults.standard.object(forKey: profileScopedKey(sessionDateKey)) as? Date,
           Calendar.current.isDateInToday(sessionDate) {
            if UserDefaults.standard.object(forKey: profileScopedKey(sessionRestEnabledKey)) != nil {
                sessionRestTimerEnabled = UserDefaults.standard.bool(forKey: profileScopedKey(sessionRestEnabledKey))
            }
            let warm = UserDefaults.standard.integer(forKey: profileScopedKey(sessionRestWarmupKey))
            if warm > 0 { sessionRestWarmupSeconds = warm }
            let work = UserDefaults.standard.integer(forKey: profileScopedKey(sessionRestWorkingKey))
            if work > 0 { sessionRestWorkingSeconds = work }
        } else {
            sessionRestTimerEnabled = false
        }
    }

    private func saveSessionData() {
        if let duration = sessionDuration {
            UserDefaults.standard.set(duration.rawValue, forKey: profileScopedKey(sessionDurationKey))
            UserDefaults.standard.set(Date(), forKey: profileScopedKey(sessionDateKey))
        }
        
        if let goal = sessionFitnessGoal {
            UserDefaults.standard.set(goal.rawValue, forKey: profileScopedKey(sessionFitnessGoalKey))
        }
        
        if let muscles = customTargetMuscles {
            UserDefaults.standard.set(muscles, forKey: profileScopedKey(customMusclesKey))
        }
        
        if let flexibility = sessionFlexibilityPreferences,
           let data = try? JSONEncoder().encode(flexibility) {
            UserDefaults.standard.set(data, forKey: profileScopedKey(sessionFlexibilityKey))
        }

        // Persist rest timer settings
        UserDefaults.standard.set(sessionRestTimerEnabled, forKey: profileScopedKey(sessionRestEnabledKey))
        UserDefaults.standard.set(sessionRestWarmupSeconds, forKey: profileScopedKey(sessionRestWarmupKey))
        UserDefaults.standard.set(sessionRestWorkingSeconds, forKey: profileScopedKey(sessionRestWorkingKey))
        UserDefaults.standard.set(Date(), forKey: profileScopedKey(sessionDateKey))
    }

    private func clearSessionUserDefaults() {
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionDurationKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionDateKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(customMusclesKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionMuscleTypeKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionFitnessGoalKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionFlexibilityKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionRestEnabledKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionRestWarmupKey))
        UserDefaults.standard.removeObject(forKey: profileScopedKey(sessionRestWorkingKey))
    }

    private func loadDefaultMusclePreferences() {
        let defaults = UserDefaults.standard

        if let storedType = defaults.string(forKey: profileScopedKey(defaultMuscleTypeKey)), !storedType.isEmpty {
            defaultMuscleType = storedType
        }

        if let storedMuscles = defaults.array(forKey: profileScopedKey(defaultCustomMusclesKey)) as? [String],
           !storedMuscles.isEmpty {
            defaultTargetMuscles = storedMuscles
        } else {
            defaultTargetMuscles = nil
        }

        if customTargetMuscles == nil {
            selectedMuscleType = defaultMuscleType
        }
    }

    private func persistDefaultMusclePreferences(type: String, muscles: [String]?) {
        let defaults = UserDefaults.standard
        defaults.set(type, forKey: profileScopedKey(defaultMuscleTypeKey))

        if let muscles, !muscles.isEmpty {
            defaults.set(muscles, forKey: profileScopedKey(defaultCustomMusclesKey))
        } else {
            defaults.removeObject(forKey: profileScopedKey(defaultCustomMusclesKey))
        }
    }
    
    /// Determine if should advance to next session phase
    private func shouldAdvanceToNextPhase(feedback: WorkoutSessionFeedback) -> Bool {
        // Simple logic: advance after each completed workout
        // Could be enhanced with performance analysis
        return feedback.completionRate > 0.8
    }
    
    /// Advance to the next session phase if appropriate
    func advanceSessionPhaseIfNeeded() {
        // Advance to next phase in the A-B-C cycle
        let currentPhase = sessionPhase
        let nextPhase = currentPhase.nextPhase()
        
        // Update session phase
        UserDefaults.standard.set(nextPhase.rawValue, forKey: "currentSessionPhase")
        
        // Update dynamic parameters if they exist
        if var params = dynamicParameters {
            params = DynamicWorkoutParameters(
                sessionPhase: nextPhase,
                recoveryStatus: params.recoveryStatus,
                performanceHistory: params.performanceHistory,
                autoRegulationLevel: params.autoRegulationLevel,
                lastWorkoutFeedback: params.lastWorkoutFeedback,
                timestamp: Date()
            )
            dynamicParameters = params
        }
        
        print("📊 Advanced session phase: \(currentPhase.displayName) → \(nextPhase.displayName)")
    }
    
    /// Sync session phase with current fitness goal
    
    // MARK: - Dynamic Programming (method declarations - implementations in WorkoutManager+DynamicProgramming.swift)
    
    /// Setup dynamic programming integration
    /// Implementation is in WorkoutManager+DynamicProgramming.swift extension
    func setupDynamicProgramming() {
        // Default implementation - will be overridden by extension
        print("⚠️ Dynamic programming setup skipped - extension not loaded")
    }
    
    // Removed generateSmartWorkout() and generateDynamicWorkout() fallback methods
    // generateTodayWorkout() now directly uses dynamic programming
    
    /// Adapt next workout based on performance feedback
    /// Implementation is in WorkoutManager+DynamicProgramming.swift extension
    func adaptNextWorkout(based feedback: WorkoutSessionFeedback) async {
        // Default implementation - will be overridden by extension
        print("⚠️ Dynamic programming not available - using base implementation")
    }
    
    // MARK: - Dynamic Programming Integration Complete
    // Properties and methods have been moved earlier in the file for proper Swift compilation
    // Removed shouldUseDynamicProgramming property - always using dynamic programming
}

// MARK: - Extensions

extension UserProfileService {
    var workoutDuration: WorkoutDuration {
        WorkoutDuration.fromMinutes(availableTime)
    }
    
    var flexibilityPreferences: FlexibilityPreferences {
        // This would need to be added to UserProfileService
        // For now, return default
        FlexibilityPreferences()
    }
}



extension MuscleRecoveryService {
    func getRecoveryOptimizedMuscleGroups(targetCount: Int) -> [String] {
        // This would need to be implemented in MuscleRecoveryService
        // For now, return common muscle groups
        let allMuscleGroups = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Core"]
        return Array(allMuscleGroups.prefix(targetCount))
    }
}

// MARK: - Legacy Compatibility (Keep existing functionality)
// Keep the existing structures for backward compatibility with current views

struct LegacyExercise: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let category: String
    let description: String?
    let instructions: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LegacyExercise, rhs: LegacyExercise) -> Bool {
        lhs.id == rhs.id
    }
}

struct WorkoutSet: Codable, Identifiable, Hashable {
    let id: Int
    let reps: Int?
    let weight: Double?
    let duration: Int?
    let distance: Double?
    let restTime: Int?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WorkoutSet, rhs: WorkoutSet) -> Bool {
        lhs.id == rhs.id
    }
}

struct WorkoutExercise: Codable, Identifiable, Hashable {
    let id: Int
    let exercise: LegacyExercise
    let sets: [WorkoutSet]
    let notes: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WorkoutExercise, rhs: WorkoutExercise) -> Bool {
        lhs.id == rhs.id
    }
}

struct Workout: Codable, Identifiable, Hashable {
    let id: Int
    let remoteId: Int?
    let name: String
    let date: Date
    let duration: Int?
    let exercises: [WorkoutExercise]
    let notes: String?
    let category: String?
    let isTemplate: Bool
    let syncVersion: Int?
    let createdAt: Date?
    let updatedAt: Date?
    let blocks: [WorkoutBlock]?
    
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    var displayName: String {
        name.isEmpty ? "Workout" : name
    }

    enum CodingKeys: String, CodingKey {
        case id
        case remoteId
        case name
        case date
        case duration
        case exercises
        case notes
        case category
        case isTemplate
        case syncVersion
        case createdAt
        case updatedAt
        case blocks
    }

    init(
        id: Int,
        remoteId: Int?,
        name: String,
        date: Date,
        duration: Int?,
        exercises: [WorkoutExercise],
        notes: String?,
        category: String?,
        isTemplate: Bool = true,
        syncVersion: Int?,
        createdAt: Date?,
        updatedAt: Date?,
        blocks: [WorkoutBlock]?
    ) {
        self.id = id
        self.remoteId = remoteId
        self.name = name
        self.date = date
        self.duration = duration
        self.exercises = exercises
        self.notes = notes
        self.category = category
        self.isTemplate = isTemplate
        self.syncVersion = syncVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.blocks = blocks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        remoteId = try container.decodeIfPresent(Int.self, forKey: .remoteId)
        name = try container.decode(String.self, forKey: .name)
        date = try container.decode(Date.self, forKey: .date)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        exercises = try container.decode([WorkoutExercise].self, forKey: .exercises)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        isTemplate = try container.decodeIfPresent(Bool.self, forKey: .isTemplate) ?? true
        syncVersion = try container.decodeIfPresent(Int.self, forKey: .syncVersion)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        blocks = try container.decodeIfPresent([WorkoutBlock].self, forKey: .blocks)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(remoteId, forKey: .remoteId)
        try container.encode(name, forKey: .name)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(exercises, forKey: .exercises)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(isTemplate, forKey: .isTemplate)
        try container.encodeIfPresent(syncVersion, forKey: .syncVersion)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(blocks, forKey: .blocks)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Workout, rhs: Workout) -> Bool {
        lhs.id == rhs.id
    }
}

struct LoggedWorkout: Codable, Identifiable, Hashable {
    let id: Int
    let workoutLogId: Int
    let workout: Workout
    let loggedAt: Date
    let status: String
    let message: String
    
    var logDate: Date { loggedAt }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LoggedWorkout, rhs: LoggedWorkout) -> Bool {
        lhs.id == rhs.id
    }
}

enum CustomWorkoutError: LocalizedError {
    case invalidName
    case noExercises

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Please enter a workout name."
        case .noExercises:
            return "Add at least one exercise before saving."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let workoutCompletedNeedsFeedback = Notification.Name("workoutCompletedNeedsFeedback")
}
