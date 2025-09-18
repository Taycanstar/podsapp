//
//  MuscleRecoveryService.swift
//  pods
//
//  Created by Dimi Nunez on 7/16/25.
//

//
//  MuscleRecoveryService.swift
//  Pods
//
//  Created by Assistant on 12/21/24.
//

import Foundation
import SwiftUI

class MuscleRecoveryService: ObservableObject {
    static let shared = MuscleRecoveryService()
    
    private init() {}
    
    // MARK: - Fitbod-Aligned Experience Recovery Multipliers
    
    /// Get recovery rate multiplier based on fitness experience level
    /// Based on Fitbod's proven approach: beginners recover slower, advanced recover faster
    private func getExperienceRecoveryMultiplier(_ experienceLevel: ExperienceLevel) -> Double {
        switch experienceLevel {
        case .beginner:
            return 1.3      // 30% slower recovery (6-7 days vs 4-5 days)
        case .intermediate:
            return 1.0      // Standard recovery rate
        case .advanced:
            return 0.8      // 20% faster recovery (better adaptation, efficiency)
        }
    }
    
    // MARK: - Main Muscle Groups (science-backed recovery times)
    
    enum MainMuscleGroup: String, CaseIterable {
        case abs = "Abs"
        case back = "Back"
        case biceps = "Biceps"
        case chest = "Chest"
        case glutes = "Glutes"
        case hamstrings = "Hamstrings"
        case quadriceps = "Quadriceps"
        case shoulders = "Shoulders"
        case triceps = "Triceps"
        case lowerBack = "Lower Back"
        
        var baseRecoveryHours: Double {
            switch self {
            case .abs: return 24.0                    // 1 day - can train 3-4x/week
            case .back: return 48.0                   // 2 days - train 2-3x/week
            case .biceps: return 48.0                 // 2 days - train 2-3x/week
            case .chest: return 48.0                  // 2 days - train 2-3x/week
            case .glutes: return 72.0                 // 3 days - train 2x/week
            case .hamstrings: return 72.0             // 3 days - train 2x/week
            case .quadriceps: return 72.0             // 3 days - train 2x/week
            case .shoulders: return 48.0              // 2 days - train 2-3x/week
            case .triceps: return 48.0                // 2 days - train 2-3x/week
            case .lowerBack: return 48.0              // 2 days - train 2-3x/week
            }
        }
        
        var trainingFrequencyPerWeek: String {
            switch self {
            case .abs: return "3-4x"
            case .back, .biceps, .chest, .shoulders, .triceps, .lowerBack: return "2-3x"
            case .glutes, .hamstrings, .quadriceps: return "2x"
            }
        }
    }
    
    // MARK: - Accessory Muscle Groups (science-backed recovery times)
    
    enum AccessoryMuscleGroup: String, CaseIterable {
        case calves = "Calves"
        case trapezius = "Trapezius"
        case abductors = "Abductors"
        case adductors = "Adductors"
        case forearms = "Forearms"
        case neck = "Neck"
        
        var baseRecoveryHours: Double {
            switch self {
            case .calves: return 24.0                 // 1 day - train 3-4x/week
            case .trapezius: return 24.0              // 1 day - train 3-4x/week
            case .abductors: return 48.0              // 2 days - train 2-3x/week
            case .adductors: return 48.0              // 2 days - train 2-3x/week
            case .forearms: return 24.0               // 1 day - train 3-4x/week
            case .neck: return 24.0                   // 1 day - train 3-4x/week
            }
        }
        
        var trainingFrequencyPerWeek: String {
            switch self {
            case .calves, .trapezius, .forearms, .neck: return "3-4x"
            case .abductors, .adductors: return "2-3x"
            }
        }
    }
    
    // MARK: - Combined Muscle Group Protocol
    
    enum MuscleGroup: String, CaseIterable, Codable {
        // Main muscle groups
        case abs = "Abs"
        case back = "Back"
        case biceps = "Biceps"
        case chest = "Chest"
        case glutes = "Glutes"
        case hamstrings = "Hamstrings"
        case quadriceps = "Quadriceps"
        case shoulders = "Shoulders"
        case triceps = "Triceps"
        case lowerBack = "Lower Back"
        
        // Accessory muscle groups
        case calves = "Calves"
        case trapezius = "Trapezius"
        case abductors = "Abductors"
        case adductors = "Adductors"
        case forearms = "Forearms"
        case neck = "Neck"
        
        var displayName: String {
            return rawValue
        }
        
        var isMainMuscleGroup: Bool {
            switch self {
            case .abs, .back, .biceps, .chest, .glutes, .hamstrings, .quadriceps, .shoulders, .triceps, .lowerBack:
                return true
            case .calves, .trapezius, .abductors, .adductors, .forearms, .neck:
                return false
            }
        }
        
        // Science-backed recovery times
        var baseRecoveryHours: Double {
            switch self {
            // 24-hour recovery (small muscles, can train 3-4x/week)
            case .abs, .calves, .trapezius, .forearms, .neck:
                return 24.0
            
            // 48-hour recovery (medium muscles, train 2-3x/week)
            case .back, .biceps, .chest, .shoulders, .triceps, .lowerBack, .abductors, .adductors:
                return 48.0
            
            // 72-hour recovery (large muscles, train 2x/week)
            case .glutes, .hamstrings, .quadriceps:
                return 72.0
            }
        }
        
        var trainingFrequencyPerWeek: String {
            switch self {
            case .abs, .calves, .trapezius, .forearms, .neck: return "3-4x"
            case .back, .biceps, .chest, .shoulders, .triceps, .lowerBack, .abductors, .adductors: return "2-3x"
            case .glutes, .hamstrings, .quadriceps: return "2x"
            }
        }
        
        var priority: Int {
            // Higher numbers = higher priority for workout selection
            if isMainMuscleGroup {
                switch self {
                case .chest, .back, .shoulders, .glutes, .quadriceps, .hamstrings: return 3 // Primary movers
                case .biceps, .triceps: return 2 // Secondary movers
                case .abs, .lowerBack: return 1 // Stabilizers
                default: return 1
                }
            } else {
                return 0 // Accessory muscles
            }
        }
    }
    
    // MARK: - Recovery Data Models
    
    struct MuscleRecoveryData: Codable {
        let muscleGroup: MuscleGroup
        let lastWorkedDate: Date
        let workoutIntensity: Double      // 0.0 to 1.0 scale
        let recoveryPercentage: Double    // 0.0 to 100.0
        let estimatedFullRecoveryDate: Date
        
        var isFullyRested: Bool {
            recoveryPercentage >= 100.0
        }
        
        var isRecommendedForTraining: Bool {
            recoveryPercentage >= 85.0  // Fitbod-like threshold
        }
    }
    
    struct WorkoutStimulus: Codable {
        let date: Date
        let muscleGroup: MuscleGroup
        let intensity: Double           // Based on volume, sets, reps
        let exercises: [Int]           // Exercise IDs that contributed
        let totalVolume: Double        // Total weight × reps
    }
    
    // MARK: - Public Methods
    
    func getMuscleRecoveryData() -> [MuscleRecoveryData] {
        let allMuscleGroups = MuscleGroup.allCases
        let overrides = UserProfileService.shared.muscleRecoveryOverrides

        let data = allMuscleGroups.map { muscleGroup -> MuscleRecoveryData in
            let base = calculateRecoveryForMuscle(muscleGroup)
            if let override = overrides[muscleGroup.rawValue] {
                let clamped = min(100.0, max(0.0, override))
                return MuscleRecoveryData(
                    muscleGroup: base.muscleGroup,
                    lastWorkedDate: base.lastWorkedDate,
                    workoutIntensity: base.workoutIntensity,
                    recoveryPercentage: clamped,
                    estimatedFullRecoveryDate: base.estimatedFullRecoveryDate
                )
            }
            return base
        }

        return data.sorted { $0.recoveryPercentage < $1.recoveryPercentage }
    }
    
    func getRecommendedMuscleGroups(for targetCount: Int = 4) -> [MuscleGroup] {
        let recoveryData = getMuscleRecoveryData()
        
        // Separate main and accessory muscles
        let mainMuscles = recoveryData.filter { $0.muscleGroup.isMainMuscleGroup }
        let accessoryMuscles = recoveryData.filter { !$0.muscleGroup.isMainMuscleGroup }
        
        // Filter main muscles that are ready for training (85%+ recovered)
        let readyMainMuscles = mainMuscles
            .filter { $0.isRecommendedForTraining }
            .sorted { muscle1, muscle2 in
                // Sort by priority first, then recovery percentage
                if muscle1.muscleGroup.priority != muscle2.muscleGroup.priority {
                    return muscle1.muscleGroup.priority > muscle2.muscleGroup.priority
                }
                return muscle1.recoveryPercentage > muscle2.recoveryPercentage
            }
        
        // If we don't have enough ready main muscles, include partially recovered ones (60%+)
        let partiallyReadyMainMuscles = mainMuscles
            .filter { $0.recoveryPercentage >= 60.0 && !$0.isRecommendedForTraining }
            .sorted { muscle1, muscle2 in
                if muscle1.muscleGroup.priority != muscle2.muscleGroup.priority {
                    return muscle1.muscleGroup.priority > muscle2.muscleGroup.priority
                }
                return muscle1.recoveryPercentage > muscle2.recoveryPercentage
            }
        
        // Combine and prioritize main muscles first
        let combinedMainMuscles = readyMainMuscles + partiallyReadyMainMuscles
        let selectedMainMuscles = Array(combinedMainMuscles.prefix(max(3, targetCount - 1)))
        
        // Add accessory muscles if we have room
        let remainingSlots = targetCount - selectedMainMuscles.count
        let readyAccessoryMuscles = accessoryMuscles
            .filter { $0.isRecommendedForTraining }
            .sorted { $0.recoveryPercentage > $1.recoveryPercentage }
        
        let selectedAccessoryMuscles = Array(readyAccessoryMuscles.prefix(remainingSlots))
        
        let finalSelection = selectedMainMuscles + selectedAccessoryMuscles
        
        print("🎯 Recommended muscles: \(finalSelection.map { "\($0.muscleGroup.rawValue) (\(Int($0.recoveryPercentage))%)" }.joined(separator: ", "))")
        
        return finalSelection.map { $0.muscleGroup }
    }
    
    func recordWorkout(_ exercises: [CompletedExercise]) {
        let workoutDate = Date()
        var stimulusRecords: [WorkoutStimulus] = []
        
        // Process each exercise to determine muscle stimulation
        for exercise in exercises {
            let muscleGroups = getMuscleGroupsForExercise(exerciseId: exercise.exerciseId)
            let intensity = calculateWorkoutIntensity(for: exercise)
            let volume = calculateTotalVolume(for: exercise)
            
            // Record stimulus for each muscle group targeted by this exercise
            for muscleGroup in muscleGroups {
                stimulusRecords.append(WorkoutStimulus(
                    date: workoutDate,
                    muscleGroup: muscleGroup,
                    intensity: intensity,
                    exercises: [exercise.exerciseId],
                    totalVolume: volume
                ))
            }
        }
        
        // Save stimulus records
        saveStimulusRecords(stimulusRecords)
        
        print("💪 Recorded muscle recovery data for \(stimulusRecords.count) muscle group stimulations")
    }
    
    // MARK: - Private Methods
    
    private func calculateRecoveryForMuscle(_ muscleGroup: MuscleGroup) -> MuscleRecoveryData {
        let stimulusHistory = getStimulusHistory(for: muscleGroup, days: 14)
        
        // If no recent training, muscle is fully recovered
        guard let lastStimulus = stimulusHistory.first else {
            return MuscleRecoveryData(
                muscleGroup: muscleGroup,
                lastWorkedDate: Date.distantPast,
                workoutIntensity: 0.0,
                recoveryPercentage: 100.0,
                estimatedFullRecoveryDate: Date()
            )
        }
        
        let now = Date()
        let hoursSinceLastWorkout = now.timeIntervalSince(lastStimulus.date) / 3600.0
        
        // Calculate recovery percentage based on time elapsed, workout intensity, and experience level
        let baseRecoveryTime = muscleGroup.baseRecoveryHours
        let intensityAdjustedTime = baseRecoveryTime * lastStimulus.intensity
        
        // FITBOD-ALIGNED: Apply experience-based recovery multiplier
        let userProfile = UserProfileService.shared
        let experienceMultiplier = getExperienceRecoveryMultiplier(userProfile.experienceLevel)
        let finalRecoveryTime = intensityAdjustedTime * experienceMultiplier
        
        let recoveryPercentage = min(100.0, (hoursSinceLastWorkout / finalRecoveryTime) * 100.0)
        
        let estimatedFullRecoveryDate = lastStimulus.date.addingTimeInterval(finalRecoveryTime * 3600)
        
        // Debug logging for recovery calculations
        print("🔄 Recovery Calc: \(muscleGroup) | Experience: \(userProfile.experienceLevel) (\(experienceMultiplier)x) | Base: \(Int(baseRecoveryTime))h → Final: \(Int(finalRecoveryTime))h | Recovery: \(Int(recoveryPercentage))%")
        
        return MuscleRecoveryData(
            muscleGroup: muscleGroup,
            lastWorkedDate: lastStimulus.date,
            workoutIntensity: lastStimulus.intensity,
            recoveryPercentage: recoveryPercentage,
            estimatedFullRecoveryDate: estimatedFullRecoveryDate
        )
    }
    
    private func getMuscleGroupsForExercise(exerciseId: Int) -> [MuscleGroup] {
        let allExercises = ExerciseDatabase.getAllExercises()
        guard let exercise = allExercises.first(where: { $0.id == exerciseId }) else {
            return []
        }
        
        var muscleGroups: [MuscleGroup] = []
        let bodyPart = exercise.bodyPart.lowercased()
        let target = exercise.target.lowercased()
        let synergist = exercise.synergist.lowercased()
        let exerciseName = exercise.name.lowercased()
        
        // Map exercise database bodyPart to specific muscle groups
        switch bodyPart {
        case "chest":
            muscleGroups.append(.chest)
        case "back":
            muscleGroups.append(.back)
        case "shoulders":
            muscleGroups.append(.shoulders)
        case "upper arms":
            // Determine biceps vs triceps from target/exercise name
            if target.contains("biceps") || exerciseName.contains("curl") || exerciseName.contains("chin") {
                muscleGroups.append(.biceps)
            }
            if target.contains("triceps") || exerciseName.contains("extension") || exerciseName.contains("press") || exerciseName.contains("dip") {
                muscleGroups.append(.triceps)
            }
            // If unclear, add both
            if muscleGroups.isEmpty {
                muscleGroups.append(.biceps)
                muscleGroups.append(.triceps)
            }
        case "forearms":
            muscleGroups.append(.forearms)
        case "thighs":
            // Determine quads vs hamstrings from target/exercise name
            if target.contains("quadriceps") || exerciseName.contains("squat") || exerciseName.contains("extension") || exerciseName.contains("lunge") {
                muscleGroups.append(.quadriceps)
            }
            if target.contains("hamstring") || exerciseName.contains("curl") || exerciseName.contains("deadlift") {
                muscleGroups.append(.hamstrings)
            }
            // If unclear, add both
            if muscleGroups.isEmpty {
                muscleGroups.append(.quadriceps)
                muscleGroups.append(.hamstrings)
            }
        case "hips":
            // Determine glutes vs adductors/abductors
            if target.contains("gluteus") || exerciseName.contains("glute") || exerciseName.contains("hip thrust") || exerciseName.contains("bridge") {
                muscleGroups.append(.glutes)
            }
            if target.contains("adductor") || exerciseName.contains("adduction") {
                muscleGroups.append(.adductors)
            }
            if target.contains("abductor") || exerciseName.contains("abduction") {
                muscleGroups.append(.abductors)
            }
            // Default to glutes if unclear
            if muscleGroups.isEmpty {
                muscleGroups.append(.glutes)
            }
        case "calves":
            muscleGroups.append(.calves)
        case "waist":
            muscleGroups.append(.abs)
        case "neck":
            muscleGroups.append(.neck)
        default:
            break
        }
        
        // Add synergist muscle groups (secondary activation)
        if synergist.contains("deltoid") && !muscleGroups.contains(.shoulders) {
            muscleGroups.append(.shoulders)
        }
        if synergist.contains("triceps") && !muscleGroups.contains(.triceps) {
            muscleGroups.append(.triceps)
        }
        if synergist.contains("biceps") && !muscleGroups.contains(.biceps) {
            muscleGroups.append(.biceps)
        }
        if synergist.contains("quadriceps") && !muscleGroups.contains(.quadriceps) {
            muscleGroups.append(.quadriceps)
        }
        if synergist.contains("gluteus") && !muscleGroups.contains(.glutes) {
            muscleGroups.append(.glutes)
        }
        if synergist.contains("latissimus") && !muscleGroups.contains(.back) {
            muscleGroups.append(.back)
        }
        if synergist.contains("pectoralis") && !muscleGroups.contains(.chest) {
            muscleGroups.append(.chest)
        }
        if synergist.contains("trapezius") && !muscleGroups.contains(.trapezius) {
            muscleGroups.append(.trapezius)
        }
        if synergist.contains("rectus abdominis") && !muscleGroups.contains(.abs) {
            muscleGroups.append(.abs)
        }
        if synergist.contains("erector spinae") && !muscleGroups.contains(.lowerBack) {
            muscleGroups.append(.lowerBack)
        }
        
        return muscleGroups.isEmpty ? [.abs] : muscleGroups // Default to abs if no match
    }
    
    private func calculateWorkoutIntensity(for exercise: CompletedExercise) -> Double {
        let totalSets = exercise.sets.count
        let avgReps = Double(exercise.sets.reduce(0) { $0 + $1.reps }) / Double(totalSets)
        let maxWeight = exercise.sets.compactMap { $0.weight > 0 ? $0.weight : nil }.max() ?? 0
        
        // Intensity calculation based on:
        // - Volume (sets × reps)
        // - Weight load
        // - Exercise type (compound vs isolation)
        
        let volumeScore = min(1.0, Double(totalSets) * avgReps / 60.0) // Normalize to max volume
        let weightScore = min(1.0, maxWeight / 100.0) // Normalize weight (adjust based on user's typical weights)
        
        // Get exercise complexity multiplier
        let allExercises = ExerciseDatabase.getAllExercises()
        let isCompound = allExercises.first(where: { $0.id == exercise.exerciseId })?.bodyPart.contains("compound") ?? false
        let complexityMultiplier = isCompound ? 1.2 : 1.0
        
        let intensity = ((volumeScore * 0.6) + (weightScore * 0.4)) * complexityMultiplier
        
        return min(1.0, intensity)
    }
    
    private func calculateTotalVolume(for exercise: CompletedExercise) -> Double {
        return exercise.sets.reduce(0.0) { total, set in
            total + (Double(set.reps) * set.weight)
        }
    }
    
    // MARK: - Data Persistence
    
    private func getStimulusHistory(for muscleGroup: MuscleGroup, days: Int) -> [WorkoutStimulus] {
        let key = "muscle_stimulus_\(muscleGroup.rawValue)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let allRecords = try? JSONDecoder().decode([WorkoutStimulus].self, from: data) else {
            return []
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return allRecords
            .filter { $0.date >= cutoffDate }
            .sorted { $0.date > $1.date } // Most recent first
    }
    
    private func saveStimulusRecords(_ newRecords: [WorkoutStimulus]) {
        // Group new records by muscle group
        let groupedRecords = Dictionary(grouping: newRecords) { $0.muscleGroup }
        
        for (muscleGroup, records) in groupedRecords {
            let key = "muscle_stimulus_\(muscleGroup.rawValue)"
            var existingRecords = getStimulusHistory(for: muscleGroup, days: 30) // Keep 30 days of history
            
            // Add new records
            existingRecords.append(contentsOf: records)
            
            // Sort by date and keep only recent records
            existingRecords.sort { $0.date > $1.date }
            existingRecords = Array(existingRecords.prefix(50)) // Keep max 50 records per muscle
            
            // Save back to UserDefaults
            if let data = try? JSONEncoder().encode(existingRecords) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
    
    // MARK: - Integration Methods
    
    func getRecoveryBasedWorkoutRecommendation() -> [String] {
        let recommendedMuscles = getRecommendedMuscleGroups(for: 4)
        return recommendedMuscles.map { $0.rawValue }
    }
    
    func shouldSkipMuscleGroup(_ muscleGroup: String) -> Bool {
        let recoveryPercentage = getMuscleRecoveryPercentage(for: muscleGroup)
        return recoveryPercentage < 85.0
    }
    
    func getMuscleRecoveryPercentage(for muscleGroup: String) -> Double {
        guard let muscle = MuscleGroup(rawValue: muscleGroup) else { return 100.0 }
        let profile = UserProfileService.shared
        if let manualOverride = profile.muscleRecoveryOverrides[muscleGroup] {
            print("🎛️ Recovery override: \(muscleGroup) = \(Int(round(manualOverride)))%")
            return min(100.0, max(0.0, manualOverride))
        }
        let recoveryData = calculateRecoveryForMuscle(muscle)
        print("📊 Recovery computed: \(muscleGroup) = \(Int(round(recoveryData.recoveryPercentage)))%")
        return recoveryData.recoveryPercentage
    }
    
    // MARK: - Fitbod-Aligned Workout Scheduling Integration
    
    /// Check if muscle group is ready for training (>70% recovered)
    func isMuscleReadyForTraining(_ muscleGroup: String) -> Bool {
        let recoveryPercentage = getMuscleRecoveryPercentage(for: muscleGroup)
        return recoveryPercentage >= 70.0
    }
    
    /// Get recommended rest time until muscle is ready for training
    func getRecommendedRestHours(for muscleGroup: String) -> Double {
        let recoveryPercentage = getMuscleRecoveryPercentage(for: muscleGroup)
        
        if recoveryPercentage >= 70.0 {
            return 0.0 // Ready to train
        }
        
        guard let muscle = MuscleGroup(rawValue: muscleGroup) else { return 0.0 }
        let recoveryData = calculateRecoveryForMuscle(muscle)
        
        // Calculate hours needed to reach 70% recovery
        let hoursToFullRecovery = recoveryData.estimatedFullRecoveryDate.timeIntervalSince(Date()) / 3600.0
        let hoursTo70Percent = hoursToFullRecovery * 0.3 // 70% = 30% remaining
        
        return max(0.0, hoursTo70Percent)
    }
    
    /// Get muscle groups that are ready for training right now
    func getMusclesReadyForTraining() -> [String] {
        return MainMuscleGroup.allCases.compactMap { muscle in
            isMuscleReadyForTraining(muscle.rawValue) ? muscle.rawValue : nil
        }
    }

    // MARK: - Schedule-Aware Optimization
    /// Choose muscle groups using both recent schedule balance and recovery readiness.
    /// - Strategy:
    ///   1) Read workout days per week (default 3) from UserDefaults (supports both keys we persist).
    ///   2) Count main-muscle appearances in last 7 days of completed history.
    ///   3) Target frequency per muscle = 1 if <=3 days/week else 2.
    ///   4) Prefer muscles that are below target AND recovered >= 80%.
    ///   5) Fill remaining slots by recovery recommendation to keep flow resilient.
    func getScheduleOptimizedMuscleGroups(targetCount: Int) -> [String] {
        let daysPerWeek = readWorkoutDaysPerWeek()
        let targetPerMuscle = daysPerWeek <= 3 ? 1 : 2

        // Frequency for last 7 days
        let freq = fetchLast7DaysMuscleFrequency()

        // Build candidates with recovery info
        struct Candidate { let group: MuscleGroup; let deficit: Int; let recovery: Double; let priority: Int }
        var candidates: [Candidate] = []

        for group in MuscleGroup.allCases where group.isMainMuscleGroup {
            let trained = freq[group] ?? 0
            let deficit = max(0, targetPerMuscle - trained)
            let recovery = getMuscleRecoveryPercentage(for: group.rawValue)
            if deficit > 0 && recovery >= 80.0 { // fit and behind schedule
                candidates.append(Candidate(group: group, deficit: deficit, recovery: recovery, priority: group.priority))
            }
        }

        // Rank: larger deficit → higher, then recovery %, then intrinsic priority
        let ranked = candidates.sorted {
            if $0.deficit != $1.deficit { return $0.deficit > $1.deficit }
            if $0.recovery != $1.recovery { return $0.recovery > $1.recovery }
            return $0.priority > $1.priority
        }

        var result = Array(ranked.prefix(targetCount)).map { $0.group.rawValue }

        // Fallback/fill with recovery-based recommendation (avoiding duplicates)
        if result.count < targetCount {
            let recoveryBackfill = getRecommendedMuscleGroups(for: targetCount)
                .map { $0.rawValue }
                .filter { !result.contains($0) && MuscleGroup(rawValue: $0)?.isMainMuscleGroup == true }
            for m in recoveryBackfill {
                guard result.count < targetCount else { break }
                result.append(m)
            }
        }

        // Final safety: ensure not empty
        if result.isEmpty {
            result = getRecommendedMuscleGroups(for: targetCount).map { $0.rawValue }
        }

        print("🧭 Schedule-optimized muscles: \(result)")
        return result
    }

    // MARK: - Helpers (Schedule)
    private func readWorkoutDaysPerWeek() -> Int {
        // App setting key used by the new UI
        let appStorageValue = UserDefaults.standard.integer(forKey: "workoutDaysPerWeek")
        if appStorageValue > 0 { return appStorageValue }
        // Server-style snake_case key
        let snake = UserDefaults.standard.integer(forKey: "workout_days_per_week")
        return snake > 0 ? snake : 3
    }

    /// Count how often each main muscle group appeared in the last 7 days of history
    private func fetchLast7DaysMuscleFrequency() -> [MuscleGroup: Int] {
        let history = UserProfileService.shared.getWorkoutHistory()
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var counts: [MuscleGroup: Int] = [:]

        for entry in history where entry.date >= cutoff {
            for ex in entry.exercises {
                let groups = getMuscleGroupsForExercise(exerciseId: ex.exerciseId)
                for g in groups where g.isMainMuscleGroup {
                    counts[g, default: 0] += 1
                }
            }
        }
        return counts
    }
}
