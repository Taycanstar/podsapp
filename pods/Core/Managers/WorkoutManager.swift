//
//  WorkoutManager.swift
//  Pods
//
//  Created by Dimi Nunez on 6/14/25.
//

import SwiftUI
import Foundation
import Combine

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
    
    // MARK: - Session Preferences (separate concern)
    @Published var sessionDuration: WorkoutDuration?
    @Published var sessionFitnessGoal: FitnessGoal?
    @Published var sessionFitnessLevel: ExperienceLevel?
    @Published var sessionFlexibilityPreferences: FlexibilityPreferences?
    @Published var customTargetMuscles: [String]?
    @Published var customEquipment: [Equipment]?
    @Published var selectedMuscleType: String = "Recovered Muscles"
    @Published var selectedEquipmentType: String = "Auto"
    
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
    
    // MARK: - UserDefaults Keys
    private let todayWorkoutKey = "todayWorkout"
    private let sessionDurationKey = "currentWorkoutSessionDuration"
    private let sessionDateKey = "currentWorkoutSessionDate"
    private let customMusclesKey = "currentWorkoutCustomMuscles"
    private let sessionFitnessGoalKey = "currentWorkoutSessionFitnessGoal"
    private let sessionFlexibilityKey = "currentWorkoutSessionFlexibility"
    
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
        setupDynamicProgramming()  // Initialize dynamic programming
    }
    
    // MARK: - Dynamic Programming Properties
    
    /// Current session phase for periodization
    var sessionPhase: SessionPhase {
        get {
            if let phaseString = UserDefaults.standard.string(forKey: "currentSessionPhase"),
               let phase = SessionPhase(rawValue: phaseString) {
                return phase
            }
            return .volumeFocus  // Safe default
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "currentSessionPhase")
        }
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
    private func generateBaseWorkout() async throws -> TodayWorkout {
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
                fitnessGoal: effectiveFitnessGoal
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
    
    // MARK: - Core Public Methods
    
    /// Generate today's workout with dynamic programming
    func generateTodayWorkout() async {
        await setGenerating(true, message: "Analyzing your recent performance...")
        
        do {
            // Calculate dynamic parameters
            let dynamicParams = await DynamicParameterService.shared.calculateDynamicParameters(
                currentPhase: sessionPhase,
                lastFeedback: PerformanceFeedbackService.shared.feedbackHistory.last
            )
            
            await setGenerating(true, message: "Optimizing rep ranges for your goals...")
            
            // Generate base workout structure (reuse existing logic)
            let baseWorkout = try await generateBaseWorkout()
            
            // Apply dynamic programming
            let dynamicWorkout = await applyDynamicProgramming(to: baseWorkout, parameters: dynamicParams)
            
            // Update state
            self.dynamicParameters = dynamicParams
            self.todayWorkout = dynamicWorkout.legacyWorkout  // Backward compatibility
            self.sessionPhase = dynamicParams.sessionPhase
            
            await setGenerating(true, message: "Finalizing your adaptive workout...")
            
            saveTodayWorkout()
            generationError = nil
            
            print("🎯 Generated dynamic workout: \(sessionPhase.displayName)")
            print("🎯 Dynamic exercises: \(dynamicWorkout.dynamicExercises.count)")
            
        } catch {
            print("⚠️ Dynamic workout generation failed: \(error)")
            generationError = .generationFailed(error.localizedDescription)
        }
        
        await setGenerating(false)
    }
    
    /// Generate static workout with current preferences (legacy method)
    func generateStaticWorkout() async {
        await setGenerating(true, message: "Analyzing your preferences...")
        
        do {
            let parameters = WorkoutGenerationParameters(
                duration: effectiveDuration,
                fitnessGoal: effectiveFitnessGoal,
                fitnessLevel: effectiveFitnessLevel,
                flexibilityPreferences: effectiveFlexibilityPreferences,
                customTargetMuscles: customTargetMuscles,
                customEquipment: customEquipment
            )
            
            await setGenerating(true, message: "Selecting optimal exercises...")
            
            // Perform heavy workout generation in background
            let workout = try await backgroundWorkoutGeneration(parameters)
            
            await setGenerating(true, message: "Finalizing your workout...")
            
            // Update on main thread
            todayWorkout = workout
            generationError = nil
            saveTodayWorkout()
            
        } catch let error as WorkoutGenerationError {
            generationError = error
        } catch {
            generationError = .generationFailed(error.localizedDescription)
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
    
    /// Clear all session overrides
    func clearAllSessionOverrides() {
        sessionDuration = nil
        sessionFitnessGoal = nil
        sessionFitnessLevel = nil
        sessionFlexibilityPreferences = nil
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
            estimatedDuration: currentWorkout.estimatedDuration,
            fitnessGoal: currentWorkout.fitnessGoal,
            difficulty: currentWorkout.difficulty,
            warmUpExercises: currentWorkout.warmUpExercises,
            coolDownExercises: currentWorkout.coolDownExercises
        )
        
        todayWorkout = updatedWorkout
        saveTodayWorkout()
    }
    
    /// Set today's workout (for loading from UserDefaults)
    func setTodayWorkout(_ workout: TodayWorkout?) {
        todayWorkout = workout
        if let workout = workout {
            saveTodayWorkout()
            print("📅 WorkoutManager: Set today's workout - \(workout.title)")
        }
    }
    
    /// Start workout session
    func startWorkout(_ workout: TodayWorkout) {
        currentWorkout = workout
        print("🏃‍♂️ WorkoutManager: Started workout - \(workout.title)")
    }
    
    /// Complete workout session
    func completeWorkout() {
        guard let workout = currentWorkout else { return }
        
        // Save completed workout
        Task {
            do {
                // Convert to WorkoutSession for WorkoutDataManager
                let workoutSession = WorkoutSession(name: workout.title, userEmail: userEmail)
                try await workoutDataManager.saveWorkout(workoutSession)
                print("✅ WorkoutManager: Completed and saved workout")
            } catch {
                print("❌ WorkoutManager: Failed to save completed workout: \(error)")
            }
        }
        
        // Trigger feedback collection for dynamic workouts
        if dynamicParameters != nil {
            NotificationCenter.default.post(
                name: .workoutCompletedNeedsFeedback,
                object: workout
            )
        }
        
        currentWorkout = nil
        clearSessionOverrides()
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
    
    private func setGenerating(_ generating: Bool, message: String = "") async {
        isGeneratingWorkout = generating
        generationMessage = message
    }
    
    private func backgroundWorkoutGeneration(_ parameters: WorkoutGenerationParameters) async throws -> TodayWorkout {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    guard let self = self else {
                        continuation.resume(throwing: WorkoutGenerationError.serviceUnavailable)
                        return
                    }
                    
                    let workout = try self.createIntelligentWorkout(parameters)
                    continuation.resume(returning: workout)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func createIntelligentWorkout(_ parameters: WorkoutGenerationParameters) throws -> TodayWorkout {
        // Get muscle groups based on recovery or custom selection
        let muscleGroups: [String]
        if let customMuscles = parameters.customTargetMuscles, !customMuscles.isEmpty {
            muscleGroups = customMuscles
            print("🎯 WorkoutManager: Using CUSTOM muscle selection: \(muscleGroups)")
        } else {
            // Use recovery service to get optimal muscle groups
            muscleGroups = recoveryService.getRecoveryOptimizedMuscleGroups(targetCount: 4)
            print("🧠 WorkoutManager: Using recovery-optimized muscles: \(muscleGroups)")
        }
        
        guard !muscleGroups.isEmpty else {
            throw WorkoutGenerationError.noMuscleGroups
        }
        
        // Delegate to sophisticated WorkoutGenerationService
        let workoutPlan = try workoutGenerationService.generateWorkoutPlan(
            muscleGroups: muscleGroups,
            targetDuration: parameters.duration,
            fitnessGoal: parameters.fitnessGoal,
            experienceLevel: parameters.fitnessLevel,
            customEquipment: parameters.customEquipment,
            flexibilityPreferences: parameters.flexibilityPreferences
        )
        
        print("✅ WorkoutManager: Generated \(workoutPlan.exercises.count) exercises, actual duration: \(workoutPlan.actualDurationMinutes) minutes")
        
        // Generate warm-up/cool-down if enabled
        let warmUpExercises = parameters.flexibilityPreferences.warmUpEnabled ?
            generateWarmUpExercises(targetMuscles: muscleGroups, equipment: parameters.customEquipment) : nil
        
        let coolDownExercises = parameters.flexibilityPreferences.coolDownEnabled ?
            generateCoolDownExercises(targetMuscles: muscleGroups, equipment: parameters.customEquipment) : nil
        
        return TodayWorkout(
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
    }
    
    private func generateWarmUpExercises(targetMuscles: [String], equipment: [Equipment]?) -> [TodayWorkoutExercise] {
        // Get flexibility/stretching exercises for warm-up
        let warmUpExercises = recommendationService.getFlexibilityExercises(
            type: .warmUp,
            targetMuscles: targetMuscles,
            count: 3
        )
        
        return warmUpExercises.map { exercise in
            TodayWorkoutExercise(
                exercise: exercise,
                sets: 1,
                reps: 10,
                weight: nil,
                restTime: 30
            )
        }
    }
    
    private func generateCoolDownExercises(targetMuscles: [String], equipment: [Equipment]?) -> [TodayWorkoutExercise] {
        // Get flexibility/stretching exercises for cool-down
        let coolDownExercises = recommendationService.getFlexibilityExercises(
            type: .coolDown,
            targetMuscles: targetMuscles,
            count: 3
        )
        
        return coolDownExercises.map { exercise in
            TodayWorkoutExercise(
                exercise: exercise,
                sets: 1,
                reps: 8,
                weight: nil,
                restTime: 15
            )
        }
    }
    
    private func generateWorkoutTitle(_ muscleGroups: [String]) -> String {
        if muscleGroups.count <= 2 {
            return muscleGroups.joined(separator: " & ")
        } else {
            return "Full Body Workout"
        }
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
        let key = "todayWorkout_\(userEmail)"
        
        if let data = UserDefaults.standard.data(forKey: key),
           let workout = try? JSONDecoder().decode(TodayWorkout.self, from: data) {
            
            // Check if workout is from today
            if Calendar.current.isDateInToday(workout.date) {
                todayWorkout = workout
                print("📱 WorkoutManager: Loaded today's workout from storage")
            } else {
                print("📱 WorkoutManager: Found outdated workout, will generate new one")
                Task {
                    await generateTodayWorkout()
                }
            }
        } else {
            print("📱 WorkoutManager: No existing workout found, will generate new one")
            Task {
                await generateTodayWorkout()
            }
        }
    }
    
    private func saveTodayWorkout() {
        guard let workout = todayWorkout else { return }
        let key = "todayWorkout_\(userEmail)"
        
        if let data = try? JSONEncoder().encode(workout) {
            UserDefaults.standard.set(data, forKey: key)
            print("💾 WorkoutManager: Saved today's workout to storage")
        }
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
    }
    
    private func clearSessionUserDefaults() {
        UserDefaults.standard.removeObject(forKey: sessionDurationKey)
        UserDefaults.standard.removeObject(forKey: sessionDateKey)
        UserDefaults.standard.removeObject(forKey: customMusclesKey)
        UserDefaults.standard.removeObject(forKey: sessionFitnessGoalKey)
        UserDefaults.standard.removeObject(forKey: sessionFlexibilityKey)
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

extension WorkoutRecommendationService {
    func getFlexibilityExercises(type: FlexibilityExerciseType, targetMuscles: [String], count: Int) -> [ExerciseData] {
        // This would need to be implemented in WorkoutRecommendationService
        // For now, return empty array
        return []
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
