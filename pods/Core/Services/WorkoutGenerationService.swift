//
//  WorkoutGenerationService.swift
//  pods
//
//  Created by Dimi Nunez on 8/25/25.
//

//
//  WorkoutGenerationService.swift
//  Pods
//
//  Created by Dimi Nunez on 8/25/25.
//

import Foundation

/// Advanced workout generation service that uses exercise science principles
/// to create scientifically sound workouts based on duration, fitness goals, and equipment
@MainActor
class WorkoutGenerationService {
    static let shared = WorkoutGenerationService()
    
    private let recommendationService = WorkoutRecommendationService.shared
    private let recoveryService = MuscleRecoveryService.shared
    private let llmService = LLMWorkoutService.shared
    private let contextAssembler = WorkoutContextAssembler()
    private let userProfileService = UserProfileService.shared
    private var exerciseCache: [Int: ExerciseData] = [:]
    
    private init() {}
    
    /// Generate optimized workout plan using LLM first, falling back to the deterministic pipeline.
    func generateWorkoutPlan(
        muscleGroups: [String],
        targetDuration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences
    ) throws -> WorkoutPlan {
        let optimalExerciseCount = recommendationService.getOptimalExerciseCount(
            duration: targetDuration,
            fitnessGoal: fitnessGoal,
            muscleGroupCount: muscleGroups.count,
            experienceLevel: experienceLevel,
            equipment: customEquipment
        )

        let userEmail = resolveUserEmail()
        let context = contextAssembler.assembleContext(
            userEmail: userEmail ?? "",
            requestedMuscles: muscleGroups,
            duration: targetDuration,
            equipmentOverride: customEquipment,
            sessionPhase: SessionPhase.alignedWith(fitnessGoal: fitnessGoal),
            flexibilityPreferences: flexibilityPreferences
        )

        if let email = userEmail,
           let llmPlan = attemptLLMPlan(
                userEmail: email,
                context: context,
                muscleGroups: muscleGroups,
                targetDuration: targetDuration,
                fitnessGoal: fitnessGoal,
                optimalExerciseCount: optimalExerciseCount,
                customEquipment: customEquipment,
                flexibilityPreferences: flexibilityPreferences
           ) {
            return llmPlan
        }

        if userEmail == nil {
            WorkoutGenerationTelemetry.record(.llmFallbackUsed, metadata: ["reason": "missing_email"])
        }

        return try generateResearchBackedPlan(
            muscleGroups: muscleGroups,
            targetDuration: targetDuration,
            fitnessGoal: fitnessGoal,
            experienceLevel: experienceLevel,
            customEquipment: customEquipment,
            flexibilityPreferences: flexibilityPreferences,
            optimalExerciseCount: optimalExerciseCount
        )
    }

    /// Deterministic fallback workout generator that uses the research-based algorithm.
    private func generateResearchBackedPlan(
        muscleGroups: [String],
        targetDuration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences,
        optimalExerciseCount: (total: Int, perMuscle: Int)
    ) throws -> WorkoutPlan {
        let targetDurationMinutes = targetDuration.minutes
        
        print("🏗️ WorkoutGenerationService: Generating \(targetDurationMinutes)min \(fitnessGoal) workout using research-based algorithm")
        
        print("🎯 Optimal exercise count: \(optimalExerciseCount.total) total, \(optimalExerciseCount.perMuscle) per muscle")

        // Generate exercises directly using optimal count with proper distribution
        var exercises = generateOptimizedExercisesWithTotalBudget(
            muscleGroups: muscleGroups,
            totalExercises: optimalExerciseCount.total,
            basePerMuscle: optimalExerciseCount.perMuscle,
            targetDuration: targetDuration,
            fitnessGoal: fitnessGoal,
            customEquipment: customEquipment,
            flexibilityPreferences: flexibilityPreferences
        )
        let userProfile = UserProfileService.shared
        exercises = exercises.filter { userProfile.canPerformExercise($0.exercise) }

        // Calculate actual time with single buffer (no double buffering)
        let totalExerciseTime = calculateActualExerciseTime(exercises: exercises, fitnessGoal: fitnessGoal)
        
        let warmupMinutes = getOptimalWarmupDuration(targetDurationMinutes)
        let cooldownMinutes = warmupMinutes
        let bufferMinutes = Int(Double(targetDurationMinutes) * 0.03) // Single 3% buffer
        
        let actualDurationMinutes = warmupMinutes + (totalExerciseTime / 60) + cooldownMinutes + bufferMinutes
        
        let breakdown = TimeBreakdown(
            warmupMinutes: warmupMinutes,
            exerciseMinutes: totalExerciseTime / 60,
            cooldownMinutes: cooldownMinutes,
            totalMinutes: actualDurationMinutes
        )
        
        print("✅ Generated \(exercises.count) exercises, actual duration: \(actualDurationMinutes) minutes (97% efficiency)")
        
        return WorkoutPlan(
            exercises: exercises,
            actualDurationMinutes: actualDurationMinutes,
            totalTimeBreakdown: breakdown
        )
    }

    private func attemptLLMPlan(
        userEmail: String,
        context: WorkoutContextV1,
        muscleGroups: [String],
        targetDuration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        optimalExerciseCount: (total: Int, perMuscle: Int),
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences
    ) -> WorkoutPlan? {
        let candidatePool = buildCandidatePool(
            muscles: muscleGroups,
            targetDuration: targetDuration,
            fitnessGoal: fitnessGoal,
            customEquipment: customEquipment,
            flexibilityPreferences: flexibilityPreferences
        )

        guard !candidatePool.isEmpty else {
            WorkoutGenerationTelemetry.record(.llmFallbackUsed, metadata: ["reason": "empty_candidate_pool"])
            return nil
        }

        do {
            let (response, warnings) = try llmService.generatePlanSync(
                userEmail: userEmail,
                context: context,
                candidates: candidatePool,
                targetExerciseCount: optimalExerciseCount.total
            )

            warnings.forEach {
                WorkoutGenerationTelemetry.record(.planValidationWarning, metadata: ["message": $0])
            }

            let mappedExercises = convertLLMResponse(response, fitnessGoal: fitnessGoal)
            guard !mappedExercises.isEmpty else {
                WorkoutGenerationTelemetry.record(.llmFallbackUsed, metadata: ["reason": "llm_returned_no_valid_exercises"])
                return nil
            }
            let minimumLLMExercises = max(3, optimalExerciseCount.total / 3)
            if mappedExercises.count < minimumLLMExercises {
                WorkoutGenerationTelemetry.record(.llmFallbackUsed, metadata: [
                    "reason": "llm_returned_too_few_exercises",
                    "received": mappedExercises.count,
                    "target": optimalExerciseCount.total
                ])
                return nil
            }

            let warmupMinutes = response.warmupMinutes ?? getOptimalWarmupDuration(targetDuration.minutes)
            let cooldownMinutes = response.cooldownMinutes ?? warmupMinutes
            let minimumWorkBlock = max(targetDuration.minutes / 2, 10)
            let exerciseMinutes = max(targetDuration.minutes - warmupMinutes - cooldownMinutes, minimumWorkBlock)
            let breakdown = TimeBreakdown(
                warmupMinutes: warmupMinutes,
                exerciseMinutes: exerciseMinutes,
                cooldownMinutes: cooldownMinutes,
                totalMinutes: warmupMinutes + exerciseMinutes + cooldownMinutes
            )

            return WorkoutPlan(
                exercises: mappedExercises,
                actualDurationMinutes: breakdown.totalMinutes,
                totalTimeBreakdown: breakdown
            )
        } catch {
            WorkoutGenerationTelemetry.record(.llmFallbackUsed, metadata: ["reason": error.localizedDescription])
            return nil
        }
    }

    private func buildCandidatePool(
        muscles: [String],
        targetDuration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences
    ) -> [NetworkManagerTwo.LLMCandidateExercise] {
        var pool: [NetworkManagerTwo.LLMCandidateExercise] = []
        var seen = Set<Int>()
        for muscle in muscles {
            let recommendations = recommendationService.getRecommendedExercises(
                for: muscle,
                count: 6,
                customEquipment: customEquipment,
                flexibilityPreferences: flexibilityPreferences
            )

            for exercise in recommendations where !seen.contains(exercise.id) {
                seen.insert(exercise.id)
                let candidate = NetworkManagerTwo.LLMCandidateExercise(
                    exerciseId: exercise.id,
                    name: exercise.name
                )
                pool.append(candidate)
            }
        }

        return pool
    }

    private func convertLLMResponse(_ response: NetworkManagerTwo.LLMWorkoutResponse, fitnessGoal: FitnessGoal) -> [TodayWorkoutExercise] {
        var mapped: [TodayWorkoutExercise] = []

        for spec in response.exercises {
            guard let exercise = lookupExercise(by: spec.exerciseId) else {
                WorkoutGenerationTelemetry.record(.planValidationWarning, metadata: ["message": "Missing exercise id \(spec.exerciseId)"])
                continue
            }

            let rest = spec.restSeconds ?? getResearchBasedRestTime(
                fitnessGoal: fitnessGoal,
                isCompound: isCompoundExercise(exercise)
            )

            let trackingType = ExerciseClassificationService.determineTrackingType(for: exercise)
            let sanitizedWeight = (spec.weight ?? 0) <= 0 ? nil : spec.weight
            let todayExercise = TodayWorkoutExercise(
                exercise: exercise,
                sets: max(1, spec.sets),
                reps: max(1, spec.reps),
                weight: sanitizedWeight,
                restTime: rest,
                notes: nil,
                warmupSets: nil,
                flexibleSets: nil,
                trackingType: trackingType
            )

            mapped.append(todayExercise)
        }

        return mapped
    }

    private func resolveUserEmail() -> String? {
        if let cached = UserDefaults.standard.string(forKey: "userEmail"), !cached.isEmpty {
            return cached
        }
        if let profileEmail = userProfileService.profileData?.email, !profileEmail.isEmpty {
            return profileEmail
        }
        return nil
    }

    private func lookupExercise(by id: Int) -> ExerciseData? {
        if let cached = exerciseCache[id] {
            return cached
        }

        let snapshot = ExerciseDatabase.cachedSnapshot() ?? ExerciseDatabase.getAllExercises()
        exerciseCache = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.id, $0) })
        return exerciseCache[id]
    }

    // MARK: - Optimized Exercise Generation (No More Iterative Testing)
    
    /// Generate exercises respecting total time budget with smart distribution
    private func generateOptimizedExercisesWithTotalBudget(
        muscleGroups: [String],
        totalExercises: Int,
        basePerMuscle _: Int,
        targetDuration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences
    ) -> [TodayWorkoutExercise] {
        var exercises: [TodayWorkoutExercise] = []
        var usedIds = Set<Int>() // Avoid duplicate exercises across muscle groups
        
        print("🏗️ Starting recovery-aware distribution: \(totalExercises) total exercises across \(muscleGroups.count) muscles")

        let allocations = calculateExerciseAllocations(
            for: muscleGroups,
            totalExercises: totalExercises
        )

        for allocation in allocations {
            let muscle = allocation.muscle
            let plannedCount = allocation.count
            let recoveryPercentage = allocation.recovery

            guard plannedCount > 0 else {
                print("🛌 Skipping \(muscle) due to low recovery (\(Int(recoveryPercentage))%)")
                continue
            }

            print("🎯 \(muscle): recovery \(Int(recoveryPercentage))% → requesting \(plannedCount) exercises")

            let recommended = recommendationService.getDurationOptimizedExercises(
                for: muscle,
                count: plannedCount,
                duration: targetDuration,
                fitnessGoal: fitnessGoal,
                customEquipment: customEquipment,
                flexibilityPreferences: flexibilityPreferences
            )

            print("🎯 \(muscle): requested \(plannedCount), got \(recommended.count) exercises")

            for exercise in recommended where !usedIds.contains(exercise.id) {
                let built = makeWorkoutExercise(
                    for: exercise,
                    targetDuration: targetDuration,
                    fitnessGoal: fitnessGoal,
                    recoveryPercentage: recoveryPercentage
                )
                guard built.sets > 0 else { continue }
                exercises.append(built)
                usedIds.insert(exercise.id)
            }

            print("📊 Running total after \(muscle): \(exercises.count) exercises")
        }

        print("✅ Final recovery-aware distribution result: \(exercises.count) exercises (target was \(totalExercises))")
        print("💪 Generated \(exercises.count) exercises respecting time budget")

        if exercises.count < totalExercises {
            let shortfall = totalExercises - exercises.count
            print("⚠️ Shortfall detected: missing \(shortfall) exercises. Attempting recovery-ordered backfill.")

            for allocation in allocations.sorted(by: { $0.recovery > $1.recovery }) {
                var remainingNeeded = totalExercises - exercises.count
                guard remainingNeeded > 0 else { break }

                // Still skip severely fatigued muscles even during backfill
                if allocation.recovery < 30 {
                    print("🛑 Backfill skip: \(allocation.muscle) at \(Int(allocation.recovery))% recovery")
                    continue
                }

                let muscle = allocation.muscle
                let recoveryPercentage = allocation.recovery

                let supplemental = recommendationService.getDurationOptimizedExercises(
                    for: muscle,
                    count: remainingNeeded,
                    duration: targetDuration,
                    fitnessGoal: fitnessGoal,
                    customEquipment: customEquipment,
                    flexibilityPreferences: flexibilityPreferences
                )

                for exercise in supplemental where !usedIds.contains(exercise.id) {
                    let built = makeWorkoutExercise(
                        for: exercise,
                        targetDuration: targetDuration,
                        fitnessGoal: fitnessGoal,
                        recoveryPercentage: recoveryPercentage
                    )
                    guard built.sets > 0 else { continue }
                    exercises.append(built)
                    usedIds.insert(exercise.id)
                    remainingNeeded = totalExercises - exercises.count
                    if remainingNeeded <= 0 { break }
                }
            }

            print("✅ After backfill: \(exercises.count) exercises")
        }

        if exercises.count < totalExercises {
            let remainingNeeded = totalExercises - exercises.count
            print("⚠️ Still missing \(remainingNeeded) exercises – pulling from high-recovery fallback muscles")

            let readyFallback = recoveryService
                .getMuscleRecoveryData()
                .filter { $0.recoveryPercentage >= 70 }
                .filter { data in !muscleGroups.contains(data.muscleGroup.displayName) }
                .sorted { $0.recoveryPercentage > $1.recoveryPercentage }

            for fallback in readyFallback {
                let muscleName = fallback.muscleGroup.displayName
                var remaining = totalExercises - exercises.count
                guard remaining > 0 else { break }

                let fallbackExercises = recommendationService.getDurationOptimizedExercises(
                    for: muscleName,
                    count: remaining,
                    duration: targetDuration,
                    fitnessGoal: fitnessGoal,
                    customEquipment: customEquipment,
                    flexibilityPreferences: flexibilityPreferences
                )

                if fallbackExercises.isEmpty {
                    continue
                }

                print("🪄 Fallback \(muscleName): adding \(fallbackExercises.count) exercises at \(Int(fallback.recoveryPercentage))% recovery")

                for exercise in fallbackExercises where !usedIds.contains(exercise.id) {
                    let built = makeWorkoutExercise(
                        for: exercise,
                        targetDuration: targetDuration,
                        fitnessGoal: fitnessGoal,
                        recoveryPercentage: fallback.recoveryPercentage
                    )
                    guard built.sets > 0 else { continue }
                    exercises.append(built)
                    usedIds.insert(exercise.id)
                    remaining -= 1
                    if remaining <= 0 { break }
                }
            }

            print("✅ After fallback fill: \(exercises.count) exercises (target \(totalExercises))")
        }

        return exercises
    }

    // MARK: - Interval Support

    private struct MuscleAllocation {
        let muscle: String
        let count: Int
        let recovery: Double
    }

    private func calculateExerciseAllocations(for muscleGroups: [String], totalExercises: Int) -> [MuscleAllocation] {
        guard !muscleGroups.isEmpty else { return [] }

        let resolvedTotal = max(0, totalExercises)

        struct WeightedEntry {
            let index: Int
            let muscle: String
            let recovery: Double
            var weight: Double
            var baseCount: Int = 0
            var fraction: Double = 0
        }

        var entries: [WeightedEntry] = muscleGroups.enumerated().map { index, muscle in
            let recovery = recoveryService.getMuscleRecoveryPercentage(for: muscle)
            let weight = distributionWeight(for: recovery)
            return WeightedEntry(index: index, muscle: muscle, recovery: recovery, weight: weight)
        }

        let totalWeight = entries.reduce(0) { $0 + $1.weight }

        if resolvedTotal == 0 {
            return entries.sorted { $0.index < $1.index }.map { entry in
                MuscleAllocation(muscle: entry.muscle, count: 0, recovery: entry.recovery)
            }
        }

        if totalWeight > 0.0001 {
            for idx in entries.indices {
                let share = entries[idx].weight / totalWeight
                let raw = Double(resolvedTotal) * share
                let base = Int(floor(raw))
                entries[idx].baseCount = base
                entries[idx].fraction = raw - Double(base)
            }

            var remaining = resolvedTotal - entries.reduce(0) { $0 + $1.baseCount }
            if remaining > 0 {
                let orderedIndices = entries.indices.sorted { lhs, rhs in
                    if entries[lhs].fraction != entries[rhs].fraction {
                        return entries[lhs].fraction > entries[rhs].fraction
                    }
                    if entries[lhs].recovery != entries[rhs].recovery {
                        return entries[lhs].recovery > entries[rhs].recovery
                    }
                    return entries[lhs].index < entries[rhs].index
                }

                for idx in orderedIndices where remaining > 0 {
                    entries[idx].baseCount += 1
                    remaining -= 1
                }
            }
        } else {
            let base = resolvedTotal / muscleGroups.count
            let remainder = resolvedTotal % muscleGroups.count
            for idx in entries.indices {
                entries[idx].baseCount = base + (idx < remainder ? 1 : 0)
            }
        }

        // Safety: ensure at least one muscle receives work if total > 0
        if resolvedTotal > 0 && entries.allSatisfy({ $0.baseCount == 0 }) {
            if let index = entries.enumerated().max(by: { $0.element.recovery < $1.element.recovery })?.offset {
                entries[index].baseCount = resolvedTotal
            }
        }

        let ordered = entries.sorted { $0.index < $1.index }
        let debugSummary = ordered.map { entry in
            "\(entry.muscle): \(String(format: "%.0f", entry.recovery))% → \(entry.baseCount)"
        }.joined(separator: ", ")
        print("🧬 Recovery allocation plan: [\(debugSummary)] (target \(resolvedTotal))")

        return ordered.map { entry in
            MuscleAllocation(muscle: entry.muscle, count: entry.baseCount, recovery: entry.recovery)
        }
    }

    private func distributionWeight(for recovery: Double) -> Double {
        switch recovery {
        case let value where value >= 90:
            return 1.0
        case 85..<90:
            return 0.9
        case 70..<85:
            return 0.6
        case 60..<70:
            return 0.4
        case 45..<60:
            return 0.2
        case 30..<45:
            return 0.1
        default:
            // Recovery under 30%: still allocate a small weight so we never zero-out an entire workout
            return 0.1
        }
    }

    private func volumeMultiplier(for recovery: Double) -> Double {
        switch recovery {
        case let value where value >= 90:
            return 1.0
        case 85..<90:
            return 0.9
        case 70..<85:
            return 0.7
        case 60..<70:
            return 0.5
        case 45..<60:
            return 0.35
        case 30..<45:
            return 0.25
        default:
            // Allow a minimum stimulus even when recovery metrics are unavailable or very low
            return 0.3
        }
    }

    private func adjustedSetCount(base: Int, multiplier: Double) -> Int {
        guard base > 0 else { return 0 }
        if multiplier <= 0 { return 0 }
        let adjusted = Int(round(Double(base) * multiplier))
        return max(1, min(base, adjusted))
    }

    private func adjustedDuration(base: Int, multiplier: Double, minimum: Int) -> Int {
        guard base > 0 else { return minimum }
        let adjusted = Int(round(Double(base) * multiplier))
        return max(minimum, min(base, max(1, adjusted)))
    }

    private func adjustedDistance(base: Double, multiplier: Double, minimum: Double) -> Double {
        let adjusted = base * multiplier
        return max(minimum, min(base, adjusted))
    }

    private func minimumDistance(for unit: DistanceUnit?) -> Double {
        switch unit {
        case .miles:
            return 0.25
        case .kilometers:
            return 0.4
        case .meters:
            return 20
        case .none:
            return 0.2
        }
    }
    
    /// Generate exercises using optimal count from WorkoutRecommendationService
    private func generateOptimizedExercises(
        muscleGroups: [String],
        exercisesPerMuscle: Int,
        targetDuration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences
    ) -> [TodayWorkoutExercise] {
        var exercises: [TodayWorkoutExercise] = []
        var usedIds = Set<Int>() // Avoid duplicate exercises across muscle groups
        
        print("🏗️ Starting exercise generation: \(muscleGroups.count) muscles × \(exercisesPerMuscle) exercises = \(muscleGroups.count * exercisesPerMuscle) target")
        
        for muscle in muscleGroups {
            // Use enhanced WorkoutRecommendationService for duration-optimized selection
            let recommended = recommendationService.getDurationOptimizedExercises(
                for: muscle,
                count: exercisesPerMuscle,
                duration: targetDuration,
                fitnessGoal: fitnessGoal,
                customEquipment: customEquipment,
                flexibilityPreferences: flexibilityPreferences
            )
            
            print("🎯 \(muscle): requested \(exercisesPerMuscle), got \(recommended.count) exercises")
            let recovery = recoveryService.getMuscleRecoveryPercentage(for: muscle)
            
        for exercise in recommended {
            guard !usedIds.contains(exercise.id) else { continue }
            let built = makeWorkoutExercise(
                for: exercise,
                targetDuration: targetDuration,
                fitnessGoal: fitnessGoal,
                recoveryPercentage: recovery
            )
            guard built.sets > 0 else { continue }
            exercises.append(built)
            usedIds.insert(exercise.id)
        }
            
            print("📊 Running total after \(muscle): \(exercises.count) exercises")
        }
        
        print("✅ Final generation result: \(exercises.count) exercises (target was \(muscleGroups.count * exercisesPerMuscle))")
        print("💪 Generated \(exercises.count) exercises using research-based optimization")
        return exercises
    }
    
    /// Get research-based rest times for optimal performance
    private func getResearchBasedRestTime(fitnessGoal: FitnessGoal, isCompound: Bool) -> Int {
        switch fitnessGoal {
        case .strength, .powerlifting:
            // ATP regeneration requires 2-3 minutes
            return isCompound ? 120 : 90
        case .hypertrophy:
            // Metabolic stress optimization 1-2 minutes
            return isCompound ? 90 : 60
        case .circuitTraining, .endurance:
            // Minimal rest to drive conditioning
            return isCompound ? 30 : 20
        case .olympicWeightlifting:
            // Technical lifts need long rest for quality
            return isCompound ? 240 : 180
        default:
            // General fitness balanced approach
            return isCompound ? 75 : 60
        }
    }
    
    /// Calculate actual exercise time using research-based formulas
    private func calculateActualExerciseTime(exercises: [TodayWorkoutExercise], fitnessGoal: FitnessGoal) -> Int {
        var totalSeconds = 0
        
        for exercise in exercises {
            let setupTime = isCompoundExercise(exercise.exercise) ? 25 : 15
            let transitionTime = 15
            var workingTime = 0
            var restTime = 0

            if let flex = exercise.flexibleSets, !flex.isEmpty, let type = exercise.trackingType {
                switch type {
                case .timeOnly, .timeDistance, .holdTime:
                    // Sum durations across sets
                    let totalDur = flex.compactMap { $0.duration }.reduce(0, +)
                    workingTime = Int(totalDur)
                    // Rest between sets (use exercise.restTime)
                    restTime = max(0, (flex.count - 1) * exercise.restTime)
                case .rounds:
                    // rounds × duration
                    if let rounds = flex.first?.rounds {
                        let perRound = Int(flex.first?.duration ?? 180)
                        workingTime = rounds * perRound
                        restTime = max(0, (rounds - 1) * exercise.restTime)
                    } else {
                        workingTime = Int(flex.first?.duration ?? 180)
                    }
                default:
                    // Fall back to reps calc below
                    break
                }
            }
            
            if workingTime == 0 {
                // Reps-based fallback using research-based rep duration
                let repDuration = getRepDurationForGoal(fitnessGoal)
                workingTime = exercise.sets * exercise.reps * repDuration
                restTime = max(0, (exercise.sets - 1) * exercise.restTime)
            }

            let warmupTime = estimateWarmupDuration(for: exercise)

            totalSeconds += workingTime + restTime + setupTime + transitionTime + warmupTime
        }

        return totalSeconds
    }

    private func estimateWarmupDuration(for exercise: TodayWorkoutExercise) -> Int {
        guard let warmups = exercise.warmupSets, !warmups.isEmpty else { return 0 }

        let workingWeight = exercise.weight ?? 0
        let baselineWeight = workingWeight > 0 ? workingWeight : (recommendationService.estimateStartingWeight(for: exercise.exercise) ?? 0)
        guard baselineWeight > 0 else { return 0 }

        let relativeLoad = computeRelativeLoad(for: baselineWeight)

        let baseSecondsPerSet: Int
        if relativeLoad > 1.5 {
            baseSecondsPerSet = 60
        } else if relativeLoad > 1.0 {
            baseSecondsPerSet = 50
        } else {
            baseSecondsPerSet = 40
        }

        let transitions = max(0, warmups.count - 1) * 15
        return warmups.count * baseSecondsPerSet + transitions
    }
    
    /// Compute working-weight to bodyweight ratio using the user's preferred unit system
    private func computeRelativeLoad(for workingWeight: Double) -> Double {
        guard workingWeight > 0 else { return 0 }

        let weightKg = UserProfileService.shared.userWeight
        guard weightKg > 0 else { return 0 }

        let usesImperial = UserDefaults.standard.bool(forKey: "isImperial")
        let userWeight = usesImperial ? weightKg * 2.20462 : weightKg
        guard userWeight > 0 else { return 0 }

        let workingWeightInUserUnits = usesImperial ? workingWeight : workingWeight / 2.20462
        return workingWeightInUserUnits / userWeight
    }

    private func shouldForceWarmup(for exercise: ExerciseData, goal: FitnessGoal, relativeLoad: Double, workingWeight: Double) -> Bool {
        if workingWeight <= 0 || relativeLoad >= 0.5 { return false }
        if goal == .strength || goal == .powerlifting { return true }

        let equipment = exercise.equipment.lowercased()
        let name = exercise.name.lowercased()
        let usesImperial = UserDefaults.standard.bool(forKey: "isImperial")
        let displayWorkingWeight = usesImperial ? workingWeight : workingWeight / 2.20462
        let minimumBarWeight = usesImperial ? 45.0 : 20.0
        let hasBarbell = equipment.contains("barbell") || equipment.contains("smith")
        let isKeyCompound = isCompoundExercise(exercise) && (hasBarbell || name.contains("squat") || name.contains("deadlift") || name.contains("press") || name.contains("row"))
        if isKeyCompound && displayWorkingWeight >= minimumBarWeight { return true }
        return false
    }

    /// Get rep duration based on fitness goal research
    private func getRepDurationForGoal(_ goal: FitnessGoal) -> Int {
        switch goal {
        case .strength, .powerlifting:
            return 3  // Controlled movement
        case .hypertrophy:
            return 4  // Time under tension
        case .circuitTraining, .endurance:
            return 2  // Faster tempo for conditioning
        case .olympicWeightlifting:
            return 4  // Explosive with controlled phases
        default:
            return 3  // General fitness
        }
    }
    
    // MARK: - Builders for Correct Tracking Types
    
    /// Build a TodayWorkoutExercise with appropriate tracking and defaults
    private func makeWorkoutExercise(
        for exercise: ExerciseData,
        targetDuration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        recoveryPercentage: Double
    ) -> TodayWorkoutExercise {
        let trackingType = ExerciseClassificationService.determineTrackingType(for: exercise)
        
        // Common rest time based on goal and movement type
        let optimalRest = getResearchBasedRestTime(
            fitnessGoal: fitnessGoal,
            isCompound: isCompoundExercise(exercise)
        )
        let volumeFactor = volumeMultiplier(for: recoveryPercentage)
      
        
        switch trackingType {
        case .repsWeight, .repsOnly:
            let rec = recommendationService.getSmartRecommendation(for: exercise, fitnessGoal: fitnessGoal)
            let adjustedSets = adjustedSetCount(base: rec.sets, multiplier: volumeFactor)
            guard adjustedSets > 0 else {
                print("🪫 Volume suppressed: \(exercise.name) skipped due to low recovery")
                return TodayWorkoutExercise(
                    exercise: exercise,
                    sets: 0,
                    reps: 0,
                    weight: nil,
                    restTime: optimalRest,
                    notes: nil,
                    warmupSets: nil,
                    flexibleSets: nil,
                    trackingType: ExerciseClassificationService.determineTrackingType(for: exercise)
                )
            }
            let finalTrackingType: ExerciseTrackingType = (trackingType == .repsOnly) ? .repsOnly : .repsWeight
            // Ensure a concrete starting weight for all weighted exercises
            let concreteWeight: Double? = {
                if ExerciseClassificationService.determineTrackingType(for: exercise) == .repsWeight {
                    // If generator didn’t provide weight, compute a conservative estimate
                    return rec.weight ?? recommendationService.estimateStartingWeight(for: exercise)
                }
                return nil
            }()
            // Generate warm-up sets if enabled and weight-based
            let warmups: [WarmupSetData]? = {
                guard UserProfileService.shared.warmupSetsEnabled,
                      let w = concreteWeight,
                      trackingType == .repsWeight else { return nil }
                let sets = generateWarmupSets(for: exercise, workingWeight: w, goal: fitnessGoal)
                return sets.isEmpty ? nil : sets
            }()
            return TodayWorkoutExercise(
                exercise: exercise,
                sets: adjustedSets,
                reps: rec.reps,
                weight: concreteWeight,
                restTime: optimalRest,
                notes: nil,
                warmupSets: warmups,
                flexibleSets: nil,
                trackingType: finalTrackingType
            )
        case .timeDistance:
            // One session with recommended duration and default distance
            let durationSeconds = defaultDuration(for: .timeDistance, goal: fitnessGoal)
            var set = FlexibleSetData(trackingType: .timeDistance)
            let adjustedDuration = adjustedDuration(
                base: Int(durationSeconds),
                multiplier: volumeFactor,
                minimum: Int(max(120.0, durationSeconds * 0.4))
            )
            guard adjustedDuration > 0 else {
                print("🪫 Volume suppressed: \(exercise.name) skipped due to low recovery")
                return TodayWorkoutExercise(
                    exercise: exercise,
                    sets: 0,
                    reps: 0,
                    weight: nil,
                    restTime: 0,
                    notes: nil,
                    warmupSets: nil,
                    flexibleSets: nil,
                    trackingType: .timeDistance
                )
            }
            set.duration = TimeInterval(adjustedDuration)
            set.durationString = formatDuration(TimeInterval(adjustedDuration))
            // Use meters for loaded carries, miles for typical cardio
            let lname = exercise.name.lowercased()
            let isCarry = lname.contains("carry") || lname.contains("farmer") || lname.contains("suitcase") || lname.contains("yoke")
            if isCarry {
                let baseDistance = 40.0
                set.distance = adjustedDistance(
                    base: baseDistance,
                    multiplier: volumeFactor,
                    minimum: minimumDistance(for: .meters)
                )
                set.distanceUnit = .meters
            } else {
                let baseDistance = 1.0
                let unit: DistanceUnit = .miles
                set.distance = adjustedDistance(
                    base: baseDistance,
                    multiplier: volumeFactor,
                    minimum: minimumDistance(for: unit)
                )
                set.distanceUnit = .miles
            }
            let flexible = [set]
            return TodayWorkoutExercise(
                exercise: exercise,
                sets: flexible.count,
                reps: 1,
                weight: nil,
                restTime: 45,
                notes: nil,
                warmupSets: nil,
                flexibleSets: flexible,
                trackingType: .timeDistance
            )
        case .timeOnly:
            // Interval-style or hold-based – use 3 intervals by default
            let perInterval = defaultDuration(for: .timeOnly, goal: fitnessGoal)
            let baseIntervals = 3
            let intervals = adjustedSetCount(base: baseIntervals, multiplier: volumeFactor)
            guard intervals > 0 else {
                print("🪫 Volume suppressed: \(exercise.name) skipped due to low recovery")
                return TodayWorkoutExercise(
                    exercise: exercise,
                    sets: 0,
                    reps: 0,
                    weight: nil,
                    restTime: 0,
                    notes: nil,
                    warmupSets: nil,
                    flexibleSets: nil,
                    trackingType: .timeOnly
                )
            }
            let flexible: [FlexibleSetData] = (0..<intervals).map { _ in
                var set = FlexibleSetData(trackingType: .timeOnly)
                set.duration = perInterval
                set.durationString = formatDuration(perInterval)
                return set
            }
            return TodayWorkoutExercise(
                exercise: exercise,
                sets: intervals,
                reps: 1,
                weight: nil,
                restTime: 30,
                notes: nil,
                warmupSets: nil,
                flexibleSets: flexible,
                trackingType: .timeOnly
            )
        case .holdTime:
            // Holds for stretching/core: 3 × 30–45s
            let hold = defaultDuration(for: .holdTime, goal: fitnessGoal)
            let baseSets = 3
            let adjustedSets = adjustedSetCount(base: baseSets, multiplier: volumeFactor)
            guard adjustedSets > 0 else {
                print("🪫 Volume suppressed: \(exercise.name) skipped due to low recovery")
                return TodayWorkoutExercise(
                    exercise: exercise,
                    sets: 0,
                    reps: 0,
                    weight: nil,
                    restTime: 0,
                    notes: nil,
                    warmupSets: nil,
                    flexibleSets: nil,
                    trackingType: .holdTime
                )
            }
            let flexible: [FlexibleSetData] = (0..<adjustedSets).map { _ in
                var set = FlexibleSetData(trackingType: .holdTime)
                set.duration = hold
                set.durationString = formatDuration(hold)
                return set
            }
            return TodayWorkoutExercise(
                exercise: exercise,
                sets: adjustedSets,
                reps: 1,
                weight: nil,
                restTime: 30,
                notes: nil,
                warmupSets: nil,
                flexibleSets: flexible,
                trackingType: .holdTime
            )
        case .rounds:
            // Rounds with default 3 × 3:00
            let roundDuration = defaultDuration(for: .rounds, goal: fitnessGoal)
            let baseRounds = 3
            let rounds = adjustedSetCount(base: baseRounds, multiplier: volumeFactor)
            guard rounds > 0 else {
                print("🪫 Volume suppressed: \(exercise.name) skipped due to low recovery")
                return TodayWorkoutExercise(
                    exercise: exercise,
                    sets: 0,
                    reps: 0,
                    weight: nil,
                    restTime: 0,
                    notes: nil,
                    warmupSets: nil,
                    flexibleSets: nil,
                    trackingType: .rounds
                )
            }
            var set = FlexibleSetData(trackingType: .rounds)
            set.rounds = rounds
            set.duration = roundDuration
            set.durationString = formatDuration(roundDuration)
            let flexible = [set]
            return TodayWorkoutExercise(
                exercise: exercise,
                sets: rounds,
                reps: 1,
                weight: nil,
                restTime: 45,
                notes: nil,
                warmupSets: nil,
                flexibleSets: flexible,
                trackingType: .rounds
            )
        }
    }

    // MARK: - Warm-up Sets Builder
    /// Create 1–3 warm-up sets based on working weight percentages.
    private func generateWarmupSets(for exercise: ExerciseData, workingWeight: Double, goal: FitnessGoal) -> [WarmupSetData] {
        guard isCompoundExercise(exercise) else { return [] }

        let baselineWeight: Double = {
            if workingWeight > 0 { return workingWeight }
            return recommendationService.estimateStartingWeight(for: exercise) ?? 0
        }()
        guard baselineWeight > 0 else { return [] }

        let relativeLoad = computeRelativeLoad(for: baselineWeight)
        let forceWarmup = shouldForceWarmup(for: exercise, goal: goal, relativeLoad: relativeLoad, workingWeight: baselineWeight)

        // Only prescribe warm-up sets once the working weight exceeds 50% of bodyweight
        guard relativeLoad >= 0.5 || forceWarmup else { return [] }

        let scheme: [(pct: Double, reps: Int)]
        if relativeLoad > 1.5 {
            // Very heavy compound work – four-step ramp
            scheme = [(0.4, 10), (0.6, 8), (0.8, 5), (0.9, 3)]
        } else if relativeLoad > 1.0 {
            // Heavy but manageable – three-step ramp
            scheme = [(0.5, 8), (0.75, 5), (0.9, 3)]
        } else {
            // Moderate loading – two primer sets
            scheme = [(0.6, 8), (0.85, 5)]
        }

        let usesImperial = UserDefaults.standard.bool(forKey: "isImperial")
        let displayWorkingWeight = usesImperial ? baselineWeight : baselineWeight / 2.20462
        let minimumIncrement = usesImperial ? 5.0 : 2.5

        func roundedWarmupWeight(for percentage: Double) -> Double {
            let raw = displayWorkingWeight * percentage
            let increment = minimumIncrement
            return max(increment, (raw / increment).rounded() * increment)
        }

        return scheme.map { step in
            let repsText = String(step.reps)
            let rounded = roundedWarmupWeight(for: step.pct)
            let warmupWeight = min(displayWorkingWeight * 0.98, rounded)
            let weightText: String
            if usesImperial {
                weightText = warmupWeight.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", warmupWeight) : String(format: "%.1f", warmupWeight)
            } else {
                weightText = String(format: "%.1f", warmupWeight)
            }
            return WarmupSetData(reps: repsText, weight: weightText)
        }
    }
    
    private func defaultDuration(for type: ExerciseTrackingType, goal: FitnessGoal) -> TimeInterval {
        switch type {
        case .timeDistance:
            // Circuit/endurance favors longer steady-state blocks
            return (goal == .circuitTraining || goal == .endurance) ? 900 : 600 // 15m else 10m
        case .timeOnly:
            // Work-interval length; longer for conditioning
            return (goal == .circuitTraining || goal == .endurance) ? 60 : 45
        case .holdTime:
            return 30
        case .rounds:
            return 180
        default:
            return 60
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(round(seconds))
        let minutes = totalSeconds / 60
        let remaining = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
    
    /// Determine if exercise is a compound movement
    private func isCompoundExercise(_ exercise: ExerciseData) -> Bool {
        let compoundKeywords = ["squat", "deadlift", "press", "row", "pull", "lunge", "clean", "snatch"]
        let exerciseName = exercise.name.lowercased()
        return compoundKeywords.contains { exerciseName.contains($0) }
    }
    
    /// Get optimal warmup duration based on research
    private func getOptimalWarmupDuration(_ workoutMinutes: Int) -> Int {
        switch workoutMinutes {
        case 0..<30:   return 3  // 3 minutes for short workouts
        case 30..<60:  return 5  // 5 minutes for medium workouts
        case 60..<90:  return 7  // 7 minutes for longer workouts
        case 90..<120: return 10 // 10 minutes for very long workouts
        default:       return 12 // 12 minutes for extended workouts
        }
    }
    
    // MARK: - Workout Parameters by Fitness Goal
    
    private func getWorkoutParameters(for goal: FitnessGoal, experienceLevel: ExperienceLevel) -> WorkoutParameters {
        let baseParams: WorkoutParameters
        
        switch goal {
        case .strength:
            baseParams = WorkoutParameters(
                percentageOneRM: 80...90,
                repRange: 1...6,
                repDurationSeconds: 4...6,
                setsPerExercise: 4...6,
                restBetweenSetsSeconds: 90...120,
                compoundSetupSeconds: 20,
                isolationSetupSeconds: 7,
                transitionSeconds: 20
            )
            
        case .hypertrophy:
            baseParams = WorkoutParameters(
                percentageOneRM: 60...80,
                repRange: 6...12,
                repDurationSeconds: 2...8,
                setsPerExercise: 3...5,
                restBetweenSetsSeconds: 30...90,
                compoundSetupSeconds: 20,
                isolationSetupSeconds: 7,
                transitionSeconds: 15
            )
            
        case .circuitTraining, .endurance:
            baseParams = WorkoutParameters(
                percentageOneRM: 50...70,
                repRange: 12...20,
                repDurationSeconds: 2...3,
                setsPerExercise: 2...4,
                restBetweenSetsSeconds: 15...45,
                compoundSetupSeconds: 12,
                isolationSetupSeconds: 6,
                transitionSeconds: 10
            )
        
        case .powerlifting:
            baseParams = WorkoutParameters(
                percentageOneRM: 85...100,
                repRange: 1...3,
                repDurationSeconds: 4...6,
                setsPerExercise: 3...6,
                restBetweenSetsSeconds: 120...180,
                compoundSetupSeconds: 25,
                isolationSetupSeconds: 7,
                transitionSeconds: 25
            )
        case .olympicWeightlifting:
            baseParams = WorkoutParameters(
                percentageOneRM: 80...95,
                repRange: 1...5,
                repDurationSeconds: 3...5,
                setsPerExercise: 4...8,
                restBetweenSetsSeconds: 180...300,
                compoundSetupSeconds: 30,
                isolationSetupSeconds: 10,
                transitionSeconds: 25
            )
        
        default:
            // General fitness fallback
            baseParams = WorkoutParameters(
                percentageOneRM: 60...75,
                repRange: 8...12,
                repDurationSeconds: 2...4,
                setsPerExercise: 3...4,
                restBetweenSetsSeconds: 60...90,
                compoundSetupSeconds: 20,
                isolationSetupSeconds: 7,
                transitionSeconds: 15
            )
        }
        
        return adjustParametersForExperienceLevel(baseParams, experienceLevel: experienceLevel)
    }
    
    private func adjustParametersForExperienceLevel(_ params: WorkoutParameters, experienceLevel: ExperienceLevel) -> WorkoutParameters {
        switch experienceLevel {
        case .beginner:
            return WorkoutParameters(
                percentageOneRM: params.percentageOneRM,
                repRange: params.repRange,
                repDurationSeconds: params.repDurationSeconds,
                setsPerExercise: max(1, params.setsPerExercise.lowerBound)...max(1, params.setsPerExercise.upperBound - 1),
                restBetweenSetsSeconds: params.restBetweenSetsSeconds,
                compoundSetupSeconds: params.compoundSetupSeconds + 15,
                isolationSetupSeconds: params.isolationSetupSeconds + 10,
                transitionSeconds: params.transitionSeconds + 10
            )
        case .advanced:
            return WorkoutParameters(
                percentageOneRM: params.percentageOneRM,
                repRange: params.repRange,
                repDurationSeconds: params.repDurationSeconds,
                setsPerExercise: params.setsPerExercise.lowerBound...(params.setsPerExercise.upperBound + 1),
                restBetweenSetsSeconds: params.restBetweenSetsSeconds,
                compoundSetupSeconds: max(5, params.compoundSetupSeconds - 5),
                isolationSetupSeconds: max(3, params.isolationSetupSeconds - 2),
                transitionSeconds: max(5, params.transitionSeconds - 5)
            )
        default:
            return params
        }
    }
    
    
}

// MARK: - Supporting Data Structures

struct WorkoutPlan {
    let exercises: [TodayWorkoutExercise]
    let actualDurationMinutes: Int
    let totalTimeBreakdown: TimeBreakdown

    init(
        exercises: [TodayWorkoutExercise],
        actualDurationMinutes: Int,
        totalTimeBreakdown: TimeBreakdown
    ) {
        self.exercises = exercises
        self.actualDurationMinutes = actualDurationMinutes
        self.totalTimeBreakdown = totalTimeBreakdown
    }
}

struct TimeBreakdown {
    let warmupMinutes: Int
    let exerciseMinutes: Int
    let cooldownMinutes: Int
    let totalMinutes: Int
}

struct WorkoutParameters {
    let percentageOneRM: ClosedRange<Int>
    let repRange: ClosedRange<Int>
    let repDurationSeconds: ClosedRange<Int>
    let setsPerExercise: ClosedRange<Int>
    let restBetweenSetsSeconds: ClosedRange<Int>
    let compoundSetupSeconds: Int
    let isolationSetupSeconds: Int
    let transitionSeconds: Int
}
