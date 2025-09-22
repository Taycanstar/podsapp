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
    
    // MARK: - Session Preferences (separate concern)
    @Published var sessionDuration: WorkoutDuration?
    @Published var sessionFitnessGoal: FitnessGoal?
    @Published var sessionFitnessLevel: ExperienceLevel?
    @Published var sessionFlexibilityPreferences: FlexibilityPreferences?
    @Published var customTargetMuscles: [String]?
    @Published var customEquipment: [Equipment]?
    @Published var selectedMuscleType: String = "Recovered Muscles"
    @Published var selectedEquipmentType: String = "Auto"
    
    // MARK: - Session Rest Timer Settings (workout-wide)
    @Published var sessionRestTimerEnabled: Bool = false
    @Published var sessionRestWarmupSeconds: Int = 60
    @Published var sessionRestWorkingSeconds: Int = 60
    
    // MARK: - Debug Flags
    @Published var debugForceIncludeDurationExercise = true // Debug: Always include a duration-based exercise
    
    // MARK: - Workout History State (for routines view)
    @Published private(set) var hasWorkouts: Bool = false
    @Published private(set) var isLoadingWorkouts: Bool = false
    
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
    private var sessionMonitorTimer: Timer?
    private var activeWorkoutState: ActiveWorkoutState?
    private let sessionTimeoutInterval: TimeInterval = 3 * 60 * 60
    private var pendingSummaryRegeneration = false
    private var lastModelContext: ModelContext?
    
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
    private let todayWorkoutRecoverySnapshotKey = "todayWorkoutRecoverySnapshot"
    private let todayWorkoutMusclesKey = "todayWorkoutMuscles"
    private let activeWorkoutStateKey = "activeWorkoutState"

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
    
    // MARK: - Initialization
    private init() {
        setupObservers()
        loadSessionData()
        loadTodayWorkout()
        setupSessionMonitoring()
        setupDynamicProgramming()  // Initialize dynamic programming
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
            customTargetMuscles: customTargetMuscles,
            customEquipment: customEquipment
        )
        
        return try await backgroundWorkoutGeneration(parameters)
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
        guard !trimmedTitle.isEmpty, let existingWorkout = todayWorkout else { return }
        guard existingWorkout.title != trimmedTitle else { return }

        let updatedWorkout = TodayWorkout(
            id: existingWorkout.id,
            date: existingWorkout.date,
            title: trimmedTitle,
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
                title: trimmedTitle,
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
    
    /// Generate today's workout with dynamic programming (1 second simple loading)
    func generateTodayWorkout() async {
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
                customTargetMuscles: customTargetMuscles,
                customEquipment: customEquipment
            )
            
            // Perform heavy workout generation in background
            let result = try await backgroundWorkoutGeneration(parameters)
            
            // Update on main thread
            let sanitized = sanitizeWarmupsIfNeeded(result.workout)
            todayWorkout = sanitized
            todayWorkoutMuscleGroups = result.muscleGroups
            todayWorkoutRecoverySnapshot = captureCurrentRecoverySnapshot()
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
        UserDefaults.standard.removeObject(forKey: sessionDurationKey)
        
        // Update UserDefaults directly (UserProfileService reads from here)
        UserDefaults.standard.set(duration.rawValue, forKey: "defaultWorkoutDuration")
        UserDefaults.standard.set(duration.minutes, forKey: "availableTime")
    }
    
    /// Set session-only workout duration (temporary override)
    func setSessionDuration(_ duration: WorkoutDuration) {
        sessionDuration = duration
        
        // Persist session override with date validation
        UserDefaults.standard.set(duration.rawValue, forKey: sessionDurationKey)
        UserDefaults.standard.set(Date(), forKey: sessionDateKey)
    }
    
    /// Set default fitness goal (permanent preference)
    func setDefaultFitnessGoal(_ goal: FitnessGoal) {
        // Clear session override
        sessionFitnessGoal = nil
        UserDefaults.standard.removeObject(forKey: sessionFitnessGoalKey)
        
        // Update UserProfileService
        userProfileService.fitnessGoal = goal
    }
    
    /// Set session-only fitness goal (temporary override)
    func setSessionFitnessGoal(_ goal: FitnessGoal) {
        sessionFitnessGoal = goal
        UserDefaults.standard.set(goal.rawValue, forKey: sessionFitnessGoalKey)
    }
    
    /// Set default fitness level (permanent preference)
    func setDefaultFitnessLevel(_ level: ExperienceLevel) {
        sessionFitnessLevel = nil
        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionFitnessLevel")
        userProfileService.experienceLevel = level
    }
    
    /// Set session-only fitness level (temporary override)
    func setSessionFitnessLevel(_ level: ExperienceLevel) {
        sessionFitnessLevel = level
        UserDefaults.standard.set(level.rawValue, forKey: "currentWorkoutSessionFitnessLevel")
    }
    
    /// Set default flexibility preferences
    func setDefaultFlexibilityPreferences(_ prefs: FlexibilityPreferences) {
        sessionFlexibilityPreferences = nil
        UserDefaults.standard.removeObject(forKey: sessionFlexibilityKey)
        
        // Update UserDefaults directly (since UserProfileService has no flexibilityPreferences property)
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: "flexibilityPreferences")
        }
    }
    
    /// Set session-only flexibility preferences
    func setSessionFlexibilityPreferences(_ prefs: FlexibilityPreferences) {
        sessionFlexibilityPreferences = prefs
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: sessionFlexibilityKey)
        }
    }
    
    /// Set session rest-timer enabled (temporary override)
    func setSessionRestTimerEnabled(_ enabled: Bool) {
        sessionRestTimerEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: sessionRestEnabledKey)
        UserDefaults.standard.set(Date(), forKey: sessionDateKey)
    }
    
    /// Set session rest warmup seconds (temporary override)
    func setSessionRestWarmupSeconds(_ seconds: Int) {
        sessionRestWarmupSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: sessionRestWarmupKey)
        UserDefaults.standard.set(Date(), forKey: sessionDateKey)
    }
    
    /// Set session rest working seconds (temporary override)
    func setSessionRestWorkingSeconds(_ seconds: Int) {
        sessionRestWorkingSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: sessionRestWorkingKey)
        UserDefaults.standard.set(Date(), forKey: sessionDateKey)
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
        UserDefaults.standard.removeObject(forKey: sessionDurationKey)
        UserDefaults.standard.removeObject(forKey: sessionDateKey)
        UserDefaults.standard.removeObject(forKey: sessionFitnessGoalKey)
        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionFitnessLevel")
        UserDefaults.standard.removeObject(forKey: sessionFlexibilityKey)
        UserDefaults.standard.removeObject(forKey: customMusclesKey)
        UserDefaults.standard.removeObject(forKey: "currentWorkoutCustomEquipment")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutMuscleType")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutEquipmentType")
        UserDefaults.standard.removeObject(forKey: sessionRestEnabledKey)
        UserDefaults.standard.removeObject(forKey: sessionRestWarmupKey)
        UserDefaults.standard.removeObject(forKey: sessionRestWorkingKey)
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
        todayWorkout = workout.map { sanitizeWarmupsIfNeeded($0) }
        if let workout = workout {
            saveTodayWorkout()
            print("📅 WorkoutManager: Set today's workout - \(workout.title)")
        }
    }

    /// Remove an exercise (by ExerciseData.id) from today's workout (all sections)
    func removeExerciseFromToday(exerciseId: Int) {
        guard let currentWorkout = todayWorkout else { return }
        
        let newMain = currentWorkout.exercises.filter { $0.exercise.id != exerciseId }
        let newWarmUp = currentWorkout.warmUpExercises?.filter { $0.exercise.id != exerciseId }
        let newCoolDown = currentWorkout.coolDownExercises?.filter { $0.exercise.id != exerciseId }
        
        let adjustedBlocks: [WorkoutBlock]? = currentWorkout.blocks.map { blocks in
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

        let updated = TodayWorkout(
            id: currentWorkout.id,
            date: currentWorkout.date,
            title: currentWorkout.title,
            exercises: newMain,
            blocks: adjustedBlocks,
            estimatedDuration: currentWorkout.estimatedDuration,
            fitnessGoal: currentWorkout.fitnessGoal,
            difficulty: currentWorkout.difficulty,
            warmUpExercises: newWarmUp,
            coolDownExercises: newCoolDown
        )
        todayWorkout = sanitizeWarmupsIfNeeded(updated)
        saveTodayWorkout()
        print("🧹 Removed exercise id=\(exerciseId) from today's workout")
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

            let loggedSets = makeLoggedSets(from: exercise, units: preferredUnitsSystem)
            guard !loggedSets.isEmpty else { continue }

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

    private func makeLoggedSets(from exercise: TodayWorkoutExercise, units: UnitsSystem) -> [SetInstance] {
        guard let flexibleSets = exercise.flexibleSets else { return [] }

        var results: [SetInstance] = []
        for setData in flexibleSets where !setData.isWarmupSet {
            let wasLogged = setData.wasLogged ?? setData.isCompleted
            guard wasLogged else { continue }

            switch setData.trackingType {
            case .repsWeight, .repsOnly:
                guard let repsValue = parseInt(setData.reps), repsValue > 0 else { continue }
                let weightValue = parseWeight(setData.weight, units: units)

                let set = SetInstance(setNumber: 0, targetReps: repsValue, targetWeight: weightValue)
                set.actualReps = repsValue
                set.actualWeight = weightValue
                set.isCompleted = true
                set.completedAt = Date()
                set.notes = setData.notes
                results.append(set)

            case .timeOnly, .holdTime:
                guard let duration = setData.duration, duration > 0 else { continue }
                let set = SetInstance(setNumber: 0, targetReps: 0, targetWeight: nil)
                set.actualReps = nil
                set.actualWeight = nil
                set.isCompleted = true
                set.completedAt = Date()
                set.notes = setData.notes
                set.durationSeconds = Int(duration.rounded())
                results.append(set)

            case .timeDistance:
                guard (setData.duration ?? 0) > 0 || (setData.distance ?? 0) > 0 else { continue }
                let set = SetInstance(setNumber: 0, targetReps: 0, targetWeight: nil)
                set.actualReps = nil
                set.actualWeight = nil
                set.isCompleted = true
                set.completedAt = Date()
                set.notes = setData.notes
                if let duration = setData.duration {
                    set.durationSeconds = Int(duration.rounded())
                }
                if let distance = setData.distance {
                    set.distanceMeters = convertDistance(distance, unit: setData.distanceUnit)
                }
                results.append(set)

            case .rounds:
                guard let rounds = setData.rounds, rounds > 0 else { continue }
                let set = SetInstance(setNumber: 0, targetReps: rounds, targetWeight: nil)
                set.actualReps = rounds
                set.actualWeight = nil
                set.isCompleted = true
                set.completedAt = Date()
                set.notes = setData.notes
                set.durationSeconds = Int((setData.duration ?? 0).rounded())
                results.append(set)
            }
        }

        return results
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

    private func convertToWorkoutExercises(from workout: TodayWorkout) -> [WorkoutExercise] {
        workout.exercises.map { exercise in
            let sets = (0..<max(exercise.sets, 0)).map { _ in
                WorkoutSet(
                    id: Int.random(in: 1000...9999),
                    reps: exercise.reps,
                    weight: exercise.weight ?? 0,
                    duration: nil,
                    distance: nil,
                    restTime: nil
                )
            }

            return WorkoutExercise(
                id: Int.random(in: 1000...9999),
                exercise: LegacyExercise(
                    id: exercise.exercise.id,
                    name: exercise.exercise.name,
                    category: exercise.exercise.category,
                    description: nil,
                    instructions: exercise.exercise.instructions
                ),
                sets: sets,
                notes: nil
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
                let status = autoComplete ? "Auto-completed" : "Completed"
                print("✅ WorkoutManager: \(status) and saved workout")
            } catch {
                print("❌ WorkoutManager: Failed to save completed workout: \(error)")
            }
        }

        // Maintain legacy workout history analytics
        let historyExercises = convertToWorkoutExercises(from: workout)
        WorkoutHistoryService.shared.completeFullWorkout(
            historyExercises,
            duration: duration,
            notes: nil
        )

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
                await workoutDataManager.syncNow(context: resolvedContext)
            }
        } else {
            completedWorkoutSummary = summary
            pendingSummaryRegeneration = true
            isDisplayingSummary = true
        }
    }

    func dismissWorkoutSummary() {
        completedWorkoutSummary = nil
        isDisplayingSummary = false

        if pendingSummaryRegeneration {
            pendingSummaryRegeneration = false
            scheduleNextWorkoutGeneration()
        }
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
        selectedMuscleType = "Recovered Muscles"
        selectedEquipmentType = "Auto"
        
        // Clear from UserDefaults
        clearSessionUserDefaults()
        
        print("🗑️ WorkoutManager: Cleared all session overrides")
    }
    
    // MARK: - Private Methods
    
    private var userEmail: String {
        UserDefaults.standard.string(forKey: "userEmail") ?? ""
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

    private func setGenerating(_ generating: Bool, message: String = "") async {
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
        let muscleGroups: [String]
        if let customMuscles = parameters.customTargetMuscles, !customMuscles.isEmpty {
            muscleGroups = customMuscles
            print("🎯 WorkoutManager: Using CUSTOM muscle selection: \(muscleGroups)")
        } else {
            // Use schedule-aware + recovery optimization for selection
            muscleGroups = recoveryService.getScheduleOptimizedMuscleGroups(targetCount: 4)
            print("🧠 WorkoutManager: Using schedule-optimized muscles: \(muscleGroups)")
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
        return false
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
        if currentWorkout == nil,
           let workout = todayWorkout,
           let state = activeWorkoutState,
           workout.id == state.workoutId {
            currentWorkout = workout
        }
        guard currentWorkout != nil else {
            clearActiveWorkoutState()
            return
        }
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

        switch (hasPush, hasPull, hasLower) {
        case (true, false, false):
            return "Push Day"
        case (false, true, false):
            return "Pull Day"
        case (true, true, false):
            return "Upper Body Day"
        case (false, false, true):
            return "Lower Body Day"
        case (true, false, true), (false, true, true), (true, true, true):
            return "Full Body Day"
        default:
            break
        }

        if hasCoreOnly {
            return "Core Day"
        }

        if let single = muscleGroups.first, muscleGroups.count == 1 {
            return "\(single) Day"
        }

        return "Today's Workout"
    }
    
    private func setupObservers() {
        // Listen for user profile changes to update defaults
        userProfileService.$profileData
            .compactMap { $0 }
            .sink { [weak self] _ in
                // Profile data updated, could trigger workout regeneration if needed
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    
    private func loadTodayWorkout() {
        loadTodayWorkoutMetadata()
        let key = storageKey(todayWorkoutKey)
        
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

    private func saveTodayWorkout() {
        guard let workout = todayWorkout else { return }
        let key = storageKey(todayWorkoutKey)
        
        if let data = try? JSONEncoder().encode(workout) {
            UserDefaults.standard.set(data, forKey: key)
            saveTodayWorkoutMetadata()
            print("💾 WorkoutManager: Saved today's workout to storage")
        }
    }
    
    private func saveTodayWorkoutMetadata() {
        let defaults = UserDefaults.standard
        let snapshotKey = storageKey(todayWorkoutRecoverySnapshotKey)
        let musclesKey = storageKey(todayWorkoutMusclesKey)
        
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
    }
    
    private func loadTodayWorkoutMetadata() {
        let defaults = UserDefaults.standard
        let snapshotKey = storageKey(todayWorkoutRecoverySnapshotKey)
        let musclesKey = storageKey(todayWorkoutMusclesKey)
        
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
        
        activeWorkoutState = loadActiveWorkoutState()
    }
    
    private func clearTodayWorkoutStorage() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: storageKey(todayWorkoutKey))
        defaults.removeObject(forKey: storageKey(todayWorkoutRecoverySnapshotKey))
        defaults.removeObject(forKey: storageKey(todayWorkoutMusclesKey))
    }
    
    private func loadActiveWorkoutState() -> ActiveWorkoutState? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: storageKey(activeWorkoutStateKey)) else { return nil }
        return try? JSONDecoder().decode(ActiveWorkoutState.self, from: data)
    }
    
    private func persistActiveWorkoutState(_ state: ActiveWorkoutState?) {
        let defaults = UserDefaults.standard
        let key = storageKey(activeWorkoutStateKey)
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
        // Load session duration
        if let savedDurationString = UserDefaults.standard.string(forKey: sessionDurationKey),
           let savedDuration = WorkoutDuration(rawValue: savedDurationString) {
            
            if let sessionDate = UserDefaults.standard.object(forKey: sessionDateKey) as? Date,
               Calendar.current.isDateInToday(sessionDate) {
                sessionDuration = savedDuration
            } else {
                clearSessionUserDefaults()
            }
        }
        
        // Load other session data similarly...
        if let savedGoalString = UserDefaults.standard.string(forKey: sessionFitnessGoalKey) {
            sessionFitnessGoal = FitnessGoal(rawValue: savedGoalString)
        }
        
        if let savedMuscles = UserDefaults.standard.array(forKey: customMusclesKey) as? [String] {
            customTargetMuscles = savedMuscles
        }
        
        if let flexibilityData = UserDefaults.standard.data(forKey: sessionFlexibilityKey),
           let flexibility = try? JSONDecoder().decode(FlexibilityPreferences.self, from: flexibilityData) {
            sessionFlexibilityPreferences = flexibility
        }

        // Load rest timer session settings (same-day)
        if let sessionDate = UserDefaults.standard.object(forKey: sessionDateKey) as? Date,
           Calendar.current.isDateInToday(sessionDate) {
            if UserDefaults.standard.object(forKey: sessionRestEnabledKey) != nil {
                sessionRestTimerEnabled = UserDefaults.standard.bool(forKey: sessionRestEnabledKey)
            }
            let warm = UserDefaults.standard.integer(forKey: sessionRestWarmupKey)
            if warm > 0 { sessionRestWarmupSeconds = warm }
            let work = UserDefaults.standard.integer(forKey: sessionRestWorkingKey)
            if work > 0 { sessionRestWorkingSeconds = work }
        } else {
            sessionRestTimerEnabled = false
            sessionRestWarmupSeconds = 60
            sessionRestWorkingSeconds = 60
        }
    }
    
    private func saveSessionData() {
        if let duration = sessionDuration {
            UserDefaults.standard.set(duration.rawValue, forKey: sessionDurationKey)
            UserDefaults.standard.set(Date(), forKey: sessionDateKey)
        }
        
        if let goal = sessionFitnessGoal {
            UserDefaults.standard.set(goal.rawValue, forKey: sessionFitnessGoalKey)
        }
        
        if let muscles = customTargetMuscles {
            UserDefaults.standard.set(muscles, forKey: customMusclesKey)
        }
        
        if let flexibility = sessionFlexibilityPreferences,
           let data = try? JSONEncoder().encode(flexibility) {
            UserDefaults.standard.set(data, forKey: sessionFlexibilityKey)
        }

        // Persist rest timer settings
        UserDefaults.standard.set(sessionRestTimerEnabled, forKey: sessionRestEnabledKey)
        UserDefaults.standard.set(sessionRestWarmupSeconds, forKey: sessionRestWarmupKey)
        UserDefaults.standard.set(sessionRestWorkingSeconds, forKey: sessionRestWorkingKey)
        UserDefaults.standard.set(Date(), forKey: sessionDateKey)
    }
    
    private func clearSessionUserDefaults() {
        UserDefaults.standard.removeObject(forKey: sessionDurationKey)
        UserDefaults.standard.removeObject(forKey: sessionDateKey)
        UserDefaults.standard.removeObject(forKey: customMusclesKey)
        UserDefaults.standard.removeObject(forKey: sessionFitnessGoalKey)
        UserDefaults.standard.removeObject(forKey: sessionFlexibilityKey)
        UserDefaults.standard.removeObject(forKey: sessionRestEnabledKey)
        UserDefaults.standard.removeObject(forKey: sessionRestWarmupKey)
        UserDefaults.standard.removeObject(forKey: sessionRestWorkingKey)
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
    let name: String
    let date: Date
    let duration: Int?
    let exercises: [WorkoutExercise]
    let notes: String?
    let category: String?
    
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    var displayName: String {
        name.isEmpty ? "Workout" : name
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

// MARK: - Notification Names

extension Notification.Name {
    static let workoutCompletedNeedsFeedback = Notification.Name("workoutCompletedNeedsFeedback")
}
