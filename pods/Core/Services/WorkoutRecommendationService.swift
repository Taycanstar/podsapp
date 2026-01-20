// FILE: Services/WorkoutRecommendationService.swift
import Foundation

@MainActor
class WorkoutRecommendationService {
    static let shared = WorkoutRecommendationService()
    
    private init() {}
    
    // Enhanced recommendation system using user profile and Perplexity algorithm
    func getSmartRecommendation(
        for exercise: ExerciseData,
        fitnessGoal: FitnessGoal? = nil,
        sessionPhase: SessionPhase? = nil
    ) -> (sets: Int, reps: Int, weight: Double?) {
        let userProfile = UserProfileService.shared

        let goalToUse = (fitnessGoal ?? userProfile.fitnessGoal).normalized
        let phase = sessionPhase ?? SessionPhase.alignedWith(fitnessGoal: goalToUse)
        let scheme = SetSchemePlanner.shared.scheme(
            for: exercise,
            goal: goalToUse,
            experienceLevel: userProfile.experienceLevel,
            sessionPhase: phase,
            isCompound: SetSchemePlanner.isCompoundExercise(exercise)
        )

        let smartWeight = getSmartWeight(for: exercise, baseWeight: nil)

        return (
            sets: scheme.sets,
            reps: scheme.targetReps,
            weight: smartWeight
        )
    }

    // Default sets and reps used in UI helpers
    func getDefaultSetsAndReps(
        for exercise: ExerciseData,
        fitnessGoal: FitnessGoal,
        sessionPhase: SessionPhase? = nil
    ) -> (sets: Int, reps: Int, weight: Double?) {
        let userProfile = UserProfileService.shared
        let phase = sessionPhase ?? SessionPhase.alignedWith(fitnessGoal: fitnessGoal)
        let scheme = SetSchemePlanner.shared.scheme(
            for: exercise,
            goal: fitnessGoal,
            experienceLevel: userProfile.experienceLevel,
            sessionPhase: phase,
            isCompound: SetSchemePlanner.isCompoundExercise(exercise)
        )
        return (sets: scheme.sets, reps: scheme.targetReps, weight: nil)
    }
    
    // MARK: - Muscle Group Mapping (copied from AddExerciseView.swift)
    
    // Mapping from display names to actual database bodyPart values
    private nonisolated static func getDatabaseBodyPart(for displayMuscle: String) -> [String] {
        switch displayMuscle {
        case "Chest":
            return ["Chest"]
        case "Abs":
            return ["Waist"]  // Core/abs exercises are listed as "Waist" in the database
        case "Back":
            return ["Back"]
        case "Lower Back":
            return ["Hips"]  // Lower back exercises are often categorized as "Hips" 
        case "Trapezius":
            return ["Back"]  // Trapezius exercises are in the "Back" category
        case "Neck":
            return ["Neck"]
        case "Shoulders":
            return ["Shoulders"]
        case "Biceps":
            return ["Upper Arms"]  // Biceps exercises are in "Upper Arms"
        case "Triceps":
            return ["Upper Arms"]  // Triceps exercises are in "Upper Arms"
        case "Forearms":
            return ["Forearms"]
        case "Glutes":
            return ["Hips"]  // Glute exercises are categorized as "Hips"
        case "Quads", "Quadriceps":
            return ["Thighs"]  // Quad exercises are in "Thighs"
        case "Hamstrings":
            return ["Thighs"]  // Hamstring exercises are in "Thighs"
        case "Calves":
            return ["Calves"]
        case "Abductors":
            return ["Thighs"]  // Abductor exercises are in "Thighs"
        case "Adductors":
            return ["Thighs"]  // Adductor exercises are in "Thighs"
        default:
            return []
        }
    }
    
    // Smart muscle filtering with target muscle matching
    nonisolated func exerciseMatchesMuscle(_ exercise: ExerciseData, muscleGroup: String) -> Bool {
        let targetBodyParts = Self.getDatabaseBodyPart(for: muscleGroup)

        // First check if bodyPart matches
        let bodyPartMatches = targetBodyParts.contains { bodyPart in
            exercise.bodyPart.localizedCaseInsensitiveContains(bodyPart)
        }
        
        // For more specific filtering, also check target muscle
        let targetMatches: Bool
        switch muscleGroup {
        case "Biceps":
            targetMatches = exercise.target.localizedCaseInsensitiveContains("Biceps")
        case "Triceps":
            targetMatches = exercise.target.localizedCaseInsensitiveContains("Triceps")
        case "Abs":
            targetMatches = exercise.target.localizedCaseInsensitiveContains("Rectus Abdominis") ||
                           exercise.target.localizedCaseInsensitiveContains("Obliques")
        case "Glutes":
            targetMatches = exercise.target.localizedCaseInsensitiveContains("Gluteus")
        case "Quads", "Quadriceps":
            targetMatches = exercise.target.localizedCaseInsensitiveContains("Quadriceps")
        case "Hamstrings":
            targetMatches = exercise.target.localizedCaseInsensitiveContains("Hamstrings")
        case "Trapezius":  
            targetMatches = exercise.target.localizedCaseInsensitiveContains("Trapezius")
        case "Lower Back":
            targetMatches = exercise.target.localizedCaseInsensitiveContains("Erector Spinae") ||
                           exercise.target.localizedCaseInsensitiveContains("Gluteus Maximus")
        case "Abductors":
            targetMatches = exercise.target.localizedCaseInsensitiveContains("Abductor") ||
                           exercise.target.localizedCaseInsensitiveContains("Gluteus Medius")
        case "Adductors":
            targetMatches = exercise.target.localizedCaseInsensitiveContains("Adductor")
        default:
            targetMatches = bodyPartMatches
        }
        
        return bodyPartMatches || targetMatches
    }
    
    // MARK: - Smart Filtering & Recommendations
    
    func getRecommendedExercises(for muscleGroup: String, count: Int = 5) -> [ExerciseData] {
        let userProfile = UserProfileService.shared
        let recoveryService = MuscleRecoveryService.shared
        let complexityService = ExerciseComplexityService.shared
        let allExercises = ExerciseDatabase.getAllExercises()
        
        // FITBOD-ALIGNED: Check if muscle is ready for training
        let recoveryPercentage = recoveryService.getMuscleRecoveryPercentage(for: muscleGroup)
        let isReadyForTraining = recoveryService.isMuscleReadyForTraining(muscleGroup)
        
        if !isReadyForTraining {
            let restHours = recoveryService.getRecommendedRestHours(for: muscleGroup)
            print("⚠️ \(muscleGroup) not ready for training (\(Int(recoveryPercentage))% recovered). Recommended rest: \(Int(restHours)) hours")
            // Return fewer exercises or lighter variants for insufficient recovery
        }
        
        // Filter by muscle group using smart muscle mapping
        let muscleExercises = allExercises.filter { exercise in
            exerciseMatchesMuscle(exercise, muscleGroup: muscleGroup)
        }
        print("🧮 \(muscleGroup): initial pool \(muscleExercises.count) exercises")
        
        print("🎯 Smart muscle filtering for '\(muscleGroup)': Found \(muscleExercises.count) exercises out of \(allExercises.count) total")
        
        // PROGRESSIVE EXERCISE SELECTION: Different exercise pools for different levels
        let experienceAppropriate = getExperienceTailoredExercises(muscleExercises, userProfile: userProfile)
        
        print("🎓 Progressive Selection for \(userProfile.experienceLevel): \(muscleExercises.count) → \(experienceAppropriate.count) exercises")
        
        // Filter by available equipment
        let availableExercises = experienceAppropriate.filter { exercise in
            let allowed = userProfile.canPerformExercise(exercise)
            if !allowed {
                logFilterRejection(exercise, reason: "profile_equipment")
            }
            return allowed
        }
        
        // Filter out avoided exercises
        let filteredExercises = availableExercises.filter { exercise in
            if userProfile.avoidedExercises.contains(exercise.id) {
                logFilterRejection(exercise, reason: "user_avoided")
                return false
            }
            return true
        }
        
        // Prioritize exercises based on user preferences, experience, and recovery
        let sortedExercises = prioritizeExercises(filteredExercises, recoveryPercentage: recoveryPercentage, maxCount: count)
        let variabilityAdjusted = applyVariabilitySelection(
            sortedExercises,
            muscleGroup: muscleGroup,
            desiredCount: count
        )
        print("✅ \(muscleGroup): returning \(min(count, variabilityAdjusted.count)) exercises after filtering")
        return Array(variabilityAdjusted.prefix(count))
    }

    // Method with custom equipment and flexibility filtering
    func getRecommendedExercises(for muscleGroup: String, count: Int = 5, customEquipment: [Equipment]?, flexibilityPreferences: FlexibilityPreferences? = nil) -> [ExerciseData] {
        let userProfile = UserProfileService.shared
        let recoveryService = MuscleRecoveryService.shared
        let complexityService = ExerciseComplexityService.shared
        let allExercises = ExerciseDatabase.getAllExercises()
        
        // FITBOD-ALIGNED: Check if muscle is ready for training
        let recoveryPercentage = recoveryService.getMuscleRecoveryPercentage(for: muscleGroup)
        let isReadyForTraining = recoveryService.isMuscleReadyForTraining(muscleGroup)
        
        if !isReadyForTraining {
            let restHours = recoveryService.getRecommendedRestHours(for: muscleGroup)
      
            // Return fewer exercises or lighter variants for insufficient recovery
        }
        
        // Filter by muscle group using smart muscle mapping
        let muscleExercises = allExercises.filter { exercise in
            exerciseMatchesMuscle(exercise, muscleGroup: muscleGroup)
        }
        
    
        
        // PROGRESSIVE EXERCISE SELECTION: Different exercise pools for different levels
        let experienceAppropriate = getExperienceTailoredExercises(muscleExercises, userProfile: userProfile)
        
   
        
        // Filter by exercise type (exclude stretching for strength workouts by default)
        let typeFilteredExercises = filterByExerciseType(exercises: experienceAppropriate, flexibilityPreferences: flexibilityPreferences, muscleGroup: muscleGroup)
        
        // Filter by available equipment (use custom equipment if provided)
        let availableExercises: [ExerciseData]
        if let customEquipment = customEquipment {
            let allowedSet = equipmentOverrideSet(from: customEquipment)
            availableExercises = typeFilteredExercises.filter { exercise in
                let (canPerform, missing, required) = canPerformExerciseWithCustomEquipment(exercise, allowedEquipment: allowedSet)
                if !canPerform {
            logFilterRejection(exercise, reason: "session_equipment")
#if DEBUG
            if !missing.isEmpty {
                print("🚫 Session equipment filter dropped \(exercise.name) requires \(describeEquipmentSet(required)) missing \(describeEquipmentSet(missing)) (allowed \(describeEquipmentSet(allowedSet)))")
            }
#endif
        }
        return canPerform
    }
            print("🧮 \(muscleGroup): after session equipment filter \(availableExercises.count)")
        } else {
            availableExercises = typeFilteredExercises.filter { exercise in
                let allowed = userProfile.canPerformExercise(exercise)
                if !allowed {
                    logFilterRejection(exercise, reason: "profile_equipment")
                }
                return allowed
            }
            print("🧮 \(muscleGroup): after profile equipment filter \(availableExercises.count)")
        }
        
        // Filter out avoided exercises
        var filteredExercises = availableExercises.filter { exercise in
            if userProfile.avoidedExercises.contains(exercise.id) {
                logFilterRejection(exercise, reason: "user_avoided")
                return false
            }
            return true
        }

        if filteredExercises.count < count {
            let allowedSet = customEquipment != nil
                ? equipmentOverrideSet(from: customEquipment!)
                : equipmentOverrideSet(from: userProfile.availableEquipment)
            filteredExercises = augmentWithFallbacks(
                basePool: typeFilteredExercises,
                current: filteredExercises,
                allowedEquipment: allowedSet,
                avoidedIds: Set(userProfile.avoidedExercises),
                recoveryPercentage: recoveryPercentage,
                desiredCount: count
            )
        }
        
        // Prioritize exercises based on user preferences, experience, and recovery
        let sortedExercises = prioritizeExercises(filteredExercises, recoveryPercentage: recoveryPercentage, maxCount: count)
        let variabilityAdjusted = applyVariabilitySelection(
            sortedExercises,
            muscleGroup: muscleGroup,
            desiredCount: count
        )
        return Array(variabilityAdjusted.prefix(count))
    }

    // MARK: - Research-backed deterministic selector (toggleable)

    /// New deterministic selector that applies sport-science heuristics from the exercise-selection guide.
    /// Keeps the existing filtering pipeline but replaces generic prioritization with goal/equipment/taxonomy weights.
    func getResearchBackedExercises(
        for muscleGroup: String,
        count: Int = 5,
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences? = nil
    ) -> [ExerciseData] {
        let userProfile = UserProfileService.shared
        let recoveryService = MuscleRecoveryService.shared
        let allExercises = ExerciseDatabase.getAllExercises()

        let recoveryPercentage = recoveryService.getMuscleRecoveryPercentage(for: muscleGroup)

        // Muscle match → experience gating → type filter
        let muscleExercises = allExercises.filter { exerciseMatchesMuscle($0, muscleGroup: muscleGroup) }
        let experienceAppropriate = getExperienceTailoredExercises(muscleExercises, userProfile: userProfile)
        let typeFiltered = filterByExerciseType(exercises: experienceAppropriate, flexibilityPreferences: flexibilityPreferences, muscleGroup: muscleGroup)

        // Equipment filtering (session override if provided)
        let availableExercises: [ExerciseData]
        if let customEquipment {
            let allowed = equipmentOverrideSet(from: customEquipment)
            availableExercises = typeFiltered.filter { exercise in
                let (canPerform, _, _) = canPerformExerciseWithCustomEquipment(exercise, allowedEquipment: allowed)
                if !canPerform { logFilterRejection(exercise, reason: "session_equipment") }
                return canPerform
            }
        } else {
            availableExercises = typeFiltered.filter { exercise in
                let allowed = userProfile.canPerformExercise(exercise)
                if !allowed { logFilterRejection(exercise, reason: "profile_equipment") }
                return allowed
            }
        }

        // Remove avoided exercises
        let basePool = availableExercises.filter { !userProfile.avoidedExercises.contains($0.id) }

        // Score by sport-science heuristics
        let scored = basePool.map { ex -> (ExerciseData, Double) in
            let s = researchScore(
                exercise: ex,
                goal: userProfile.fitnessGoal,
                experience: userProfile.experienceLevel,
                recovery: recoveryPercentage
            )
            return (ex, s)
        }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }

        // Preserve variability selection pass
        let variabilityAdjusted = applyVariabilitySelection(scored, muscleGroup: muscleGroup, desiredCount: count)
        return Array(variabilityAdjusted.prefix(count))
    }

    // MARK: - Heuristics helpers

    private enum EquipmentKind { case barbell, dumbbell, machine, cable, bodyweight, band, kettlebell, smith, other }

    private func classifyEquipmentKind(_ exercise: ExerciseData) -> EquipmentKind {
        let eq = exercise.equipment.lowercased()
        if eq.contains("barbell") { return .barbell }
        if eq.contains("dumbbell") { return .dumbbell }
        if eq.contains("machine") { return .machine }
        if eq.contains("cable") { return .cable }
        if eq.contains("body") { return .bodyweight }
        if eq.contains("band") || eq.contains("resistance band") { return .band }
        if eq.contains("kettlebell") { return .kettlebell }
        if eq.contains("smith") { return .smith }
        return .other
    }

    private func researchScore(
        exercise: ExerciseData,
        goal: FitnessGoal,
        experience: ExperienceLevel,
        recovery: Double
    ) -> Double {
        // Taxonomy
        let movement = MovementType.classify(exercise)
        let equip = classifyEquipmentKind(exercise)
        var score = 0.0

        // Base: compounds first
        switch movement {
        case .compound: score += 3
        case .isolation: score += 1
        case .core: score += 1
        case .cardio: score += 0
        }

        // Goal-specific modality weighting
        switch goal.normalized {
        case .strength, .powerlifting:
            if movement == .compound { score += 1 }
            switch equip {
            case .barbell: score += 3
            case .dumbbell: score += 1
            case .machine: score -= 0.5
            case .smith: score -= 0.5
            case .bodyweight, .band: score -= 1
            default: break
            }
        case .olympicWeightlifting:
            // Strict bias to barbell structural compounds
            if movement == .compound { score += 2 }
            switch equip {
            case .barbell: score += 3
            default: score -= 1
            }
        case .hypertrophy, .general:
            if movement == .compound { score += 1 }
            // Modalities roughly equal; slight edge for cables/machines on accessories
            switch equip {
            case .barbell, .dumbbell: score += 1
            case .cable, .machine: score += 1
            case .band: score += 0.5
            default: break
            }
        case .circuitTraining, .endurance, .tone:
            switch equip {
            case .bodyweight, .band: score += 2
            case .dumbbell, .cable: score += 1
            case .machine: score += 0.5
            case .barbell, .smith: score -= 1
            default: break
            }
            if movement == .cardio || movement == .core { score += 0.5 }
        default:
            break
        }

        // Experience-level adjustments
        switch experience {
        case .advanced:
            if movement == .compound && (equip == .barbell || equip == .kettlebell) { score += 1 }
        case .beginner:
            if equip == .barbell && movement == .compound { score -= 0.5 }
        case .intermediate:
            break
        }

        // Recovery moderation
        if recovery < 70 { score -= 1 } else if recovery < 85 { score -= 0.5 }

        return score
    }
    
    // Helper method to check if exercise can be performed with custom equipment
    private func canPerformExerciseWithCustomEquipment(_ exercise: ExerciseData, allowedEquipment: Set<Equipment>) -> (Bool, Set<Equipment>, Set<Equipment>) {
        var allowed = allowedEquipment
        allowed.insert(.bodyWeight)
        let required = ExerciseEquipmentResolver.shared.equipment(for: exercise)
        if required.isEmpty {
            return (true, [], required)
        }
        let missing = required.subtracting(allowed)
        return (missing.isEmpty, missing, required)
    }

    private func logFilterRejection(_ exercise: ExerciseData, reason: String) {
        WorkoutGenerationTelemetry.record(.filterRejected, metadata: [
            "exerciseId": exercise.id,
            "reason": reason
        ])
#if DEBUG
        print("🚫 Filtered \(exercise.name) [\(exercise.id)] – \(reason)")
#endif
    }
    
    // Helper method for box/step exercises
    private func requiresBoxAndEquipment(_ exercise: ExerciseData, availableEquipment: [Equipment]) -> Bool {
        let exerciseName = exercise.name.lowercased()
        let exerciseEquipment = exercise.equipment.lowercased()
        
        let needsBox = exerciseName.contains("step-up") ||
                      exerciseName.contains("step up") ||
                      exerciseName.contains("box jump") ||
                      exerciseName.contains("box squat")
        
        if !needsBox { return false }
        
        // Check primary equipment
        if exerciseEquipment.contains("barbell") {
            return availableEquipment.contains(.barbells)
        } else if exerciseEquipment.contains("dumbbell") {
            return availableEquipment.contains(.dumbbells)
        }
        return true
    }
    
    // Helper method for platform exercises (Olympic lifts)
    private func requiresPlatformAndEquipment(_ exercise: ExerciseData, availableEquipment: [Equipment]) -> Bool {
        let exerciseName = exercise.name.lowercased()
        let exerciseEquipment = exercise.equipment.lowercased()
        
        let needsPlatform = exerciseName.contains("clean") ||
                           exerciseName.contains("snatch") ||
                           exerciseName.contains("deadlift")
        
        if !needsPlatform { return false }
        
        // Check primary equipment
        if exerciseEquipment.contains("barbell") {
            return availableEquipment.contains(.barbells)
        }
        return true
    }
    
    // Helper method for lat pulldown exercises
    private func requiresLatPulldown(_ exercise: ExerciseData) -> Bool {
        let exerciseName = exercise.name.lowercased()
        return exerciseName.contains("lat pulldown") ||
               exerciseName.contains("pulldown") ||
               (exerciseName.contains("lat") && exerciseName.contains("pull"))
    }
    
    // Helper method for leg curl exercises
    private func requiresLegCurl(_ exercise: ExerciseData) -> Bool {
        let exerciseName = exercise.name.lowercased()
        return exerciseName.contains("leg curl") ||
               exerciseName.contains("lying curl") ||
               exerciseName.contains("hamstring curl")
    }
    
    // Helper method for calf raise machine exercises
    private func requiresCalfRaiseMachine(_ exercise: ExerciseData) -> Bool {
        let exerciseName = exercise.name.lowercased()
        let exerciseEquipment = exercise.equipment.lowercased()
        return exerciseName.contains("calf raise") && 
               (exerciseEquipment.contains("leverage") || exerciseEquipment.contains("machine"))
    }
    
    // Helper method for row machine exercises
    private func requiresRowMachine(_ exercise: ExerciseData) -> Bool {
        let exerciseName = exercise.name.lowercased()
        let exerciseEquipment = exercise.equipment.lowercased()
        return exerciseName.contains("seated row") &&
               (exerciseEquipment.contains("leverage") || exerciseEquipment.contains("machine"))
    }

    private func equipmentOverrideSet(from equipment: [Equipment]) -> Set<Equipment> {
        if equipment.isEmpty {
            return [.bodyWeight]
        }
        var allowed = Set(equipment)
        allowed.insert(.bodyWeight)
        return allowed
    }

    private func describeEquipmentSet(_ equipment: Set<Equipment>) -> String {
        guard !equipment.isEmpty else { return "[]" }
        return "[" + equipment.map { $0.rawValue }.sorted().joined(separator: ", ") + "]"
    }

    private func augmentWithFallbacks(
        basePool: [ExerciseData],
        current: [ExerciseData],
        allowedEquipment: Set<Equipment>,
        avoidedIds: Set<Int>,
        recoveryPercentage: Double,
        desiredCount: Int
    ) -> [ExerciseData] {
        var augmented = current
        guard augmented.count < desiredCount else { return augmented }

        let alreadySelected = Set(augmented.map { $0.id })
        let supplementalCandidates = basePool.filter { exercise in
            guard !alreadySelected.contains(exercise.id),
                  !avoidedIds.contains(exercise.id) else { return false }
            let required = ExerciseEquipmentResolver.shared.equipment(for: exercise)
            return required.subtracting(allowedEquipment.union([.bodyWeight])).isEmpty
        }

        guard !supplementalCandidates.isEmpty else { return augmented }

        let prioritized = prioritizeExercises(supplementalCandidates, recoveryPercentage: recoveryPercentage, maxCount: desiredCount)
        for exercise in prioritized where augmented.count < desiredCount {
            augmented.append(exercise)
        }
        return augmented
    }
    
    // MARK: - Flexibility Exercise Filtering
    
    // Filter exercises by type based on flexibility preferences
    private func filterByExerciseType(exercises: [ExerciseData], flexibilityPreferences: FlexibilityPreferences?, muscleGroup: String? = nil) -> [ExerciseData] {
        // Stretching should NOT appear in the main exercise list; warm-up/cool-down handle those separately.
        // Always exclude stretching regardless of flexibility preferences.
        return exercises.filter { $0.exerciseType.lowercased() != "stretching" }
    }
    
    // Get warm-up exercises (dynamic stretches and activation exercises)
    func getWarmUpExercises(targetMuscles: [String], customEquipment: [Equipment]? = nil, count: Int = 3) -> [TodayWorkoutExercise] {
        let allExercises = ExerciseDatabase.getAllExercises()
        print("🔥 WARMUP DEBUG: Starting with \(allExercises.count) total exercises")
        
        // FITBOD-ALIGNED: Filter for warmup-appropriate exercises
        let warmUpExercises = allExercises.filter { exercise in
            let exerciseType = exercise.exerciseType.lowercased()
            let exerciseName = exercise.name.lowercased()
            let bodyPart = exercise.bodyPart.lowercased()
            let equipment = exercise.equipment.lowercased()

            // Exclude heavy loaded strength patterns from warm-up (especially when not targeting those muscles)
            let isHeavyLoaded = equipment.contains("barbell") || equipment.contains("dumbbell") || equipment.contains("kettlebell") || exerciseName.contains("smith") || exerciseName.contains("trap")
            let isHeavyLowerBodyPattern = exerciseName.contains("lunge") || exerciseName.contains("squat") || exerciseName.contains("deadlift")
            if isHeavyLoaded && isHeavyLowerBodyPattern {
                return false
            }
            
            // WARMUP RULE: NO STATIC STRETCHES - only dynamic movements
            if exerciseType == "stretching" {
                // Check if it's a dynamic stretch (good for warmup)
                let isDynamicStretch = exerciseName.contains("dynamic") ||
                                      exerciseName.contains("swing") ||
                                      exerciseName.contains("circle") ||
                                      exerciseName.contains("rotation") ||
                                      exerciseName.contains("roll") ||
                                      exerciseName.contains("walk")
                
                // Exclude static holds (save for cooldown)
                let isStaticStretch = exerciseName.contains("static") ||
                                     exerciseName.contains("hold") ||
                                     exerciseName.contains("stretch") && !isDynamicStretch
                
                if isDynamicStretch && !isStaticStretch {
                    print("🎯 Including DYNAMIC stretch for warmup: \(exercise.name)")
                    return true
                }
            }
            
            // SECONDARY: Dynamic movement patterns (Fitbod style)
            let isDynamic = exerciseName.contains("dynamic") ||
                           exerciseName.contains("swing") ||
                           exerciseName.contains("circle") ||
                           exerciseName.contains("rotation") ||
                           exerciseName.contains("walk") ||
                           exerciseName.contains("march") ||
                           exerciseName.contains("activation") ||
                           exerciseName.contains("mobility")

            // Only accept dynamic movements when they are bodyweight/cardio/stretching (avoid loaded patterns like barbell walking lunge)
            let dynamicIsAppropriate = isDynamic && (
                equipment.contains("body weight") ||
                bodyPart.contains("cardio") ||
                exerciseType == "stretching"
            )
            
            // TERTIARY: Light cardio for general warmup
            let isCardioWarmup = bodyPart.contains("cardio") && equipment.contains("body weight")
            
            // QUATERNARY: Bodyweight activation exercises (muscle primers)
            let isActivation = equipment.contains("body weight") && (
                exerciseName.contains("bridge") ||
                exerciseName.contains("activation") ||
                exerciseName.contains("primer") ||
                (exerciseName.contains("squat") && exerciseName.contains("bodyweight")) ||
                (exerciseName.contains("lunge") && !exerciseName.contains("hold")) ||
                (exerciseName.contains("push-up") && exerciseName.contains("knee")) ||
                exerciseName.contains("bird dog") ||
                exerciseName.contains("plank") && exerciseName.contains("knee") ||
                exerciseName.contains("arm") && exerciseName.contains("raise")
            )
            
            if dynamicIsAppropriate {
                print("🎯 Including DYNAMIC movement for warmup: \(exercise.name)")
                return true
            } else if isCardioWarmup {
                print("🎯 Including CARDIO warmup: \(exercise.name)")
                return true
            } else if isActivation {
                print("🎯 Including ACTIVATION exercise for warmup: \(exercise.name)")
                return true
            }
            
            return false
        }
        
        print("🔥 WARMUP DEBUG: Filtered to \(warmUpExercises.count) warmup-suitable exercises")
        
        // FITBOD-ALIGNED: Start from muscle-targeted candidates
        let targeted = targetExercisesForMuscles(warmUpExercises, targetMuscles: targetMuscles, exerciseType: .warmup)
        // Select ensuring coverage across target muscles (no pure random)
        let selected = selectExercisesCoveringTargetMuscles(targeted, targetMuscles: targetMuscles, maxCount: count)
        
        print("🔥 WARMUP DEBUG: Final selection: \(selected.count) exercises for muscles: \(targetMuscles.joined(separator: ", "))")
        for exercise in selected {
            print("   └── \(exercise.name) (\(exercise.exerciseType))")
        }
        
        // Convert to TodayWorkoutExercise with proper tracking for warm-up
        return selected.map { exercise in
            let (sets, reps, restTime) = getWarmupParameters(exercise)
            let tracking = ExerciseClassificationService.determineTrackingType(for: exercise)
            switch tracking {
            case .timeOnly, .timeDistance, .holdTime:
                // Use duration-based warmups: 2 short intervals by default
                let intervalCount = max(2, sets)
                let perInterval: TimeInterval = tracking == .timeDistance ? 60 : 20
                var flex: [FlexibleSetData] = []
                for _ in 0..<intervalCount {
                    var set = FlexibleSetData(trackingType: tracking == .holdTime ? .holdTime : .timeOnly)
                    set.duration = perInterval
                    set.durationString = String(format: "%d:%02d", Int(perInterval) / 60, Int(perInterval) % 60)
                    flex.append(set)
                }
                return TodayWorkoutExercise(
                    exercise: exercise,
                    sets: intervalCount,
                    reps: 1,
                    weight: nil,
                    restTime: restTime,
                    notes: "Warm-up: Prepare muscles for training",
                    warmupSets: nil,
                    flexibleSets: flex,
                    trackingType: flex.first?.trackingType
                )
            default:
                // Keep reps-based for activation moves
                return TodayWorkoutExercise(
                    exercise: exercise,
                    sets: sets,
                    reps: reps,
                    weight: nil,
                    restTime: restTime,
                    notes: "Warm-up: Prepare muscles for training"
                )
            }
        }
    }
    
    // Get cool-down exercises (static stretches for recovery)
    func getCoolDownExercises(targetMuscles: [String], customEquipment: [Equipment]? = nil, count: Int = 3) -> [TodayWorkoutExercise] {
        let allExercises = ExerciseDatabase.getAllExercises()
        print("🧊 COOLDOWN DEBUG: Starting with \(allExercises.count) total exercises")
        
        // FITBOD-ALIGNED: Filter for cooldown-appropriate exercises (STATIC STRETCHES ONLY)
        let coolDownExercises = allExercises.filter { exercise in
            let exerciseType = exercise.exerciseType.lowercased()
            let exerciseName = exercise.name.lowercased()
            let bodyPart = exercise.bodyPart.lowercased()
            let equipment = exercise.equipment.lowercased()

            // Exclude heavy loaded strength patterns from cooldown
            let isHeavyLoaded = equipment.contains("barbell") || equipment.contains("dumbbell") || equipment.contains("kettlebell") || exerciseName.contains("smith") || exerciseName.contains("trap")
            if isHeavyLoaded { return false }

            // COOLDOWN RULE: ONLY STATIC STRETCHES - no dynamic movements
            if exerciseType == "stretching" {
                // Exclude dynamic
                let isDynamic = exerciseName.contains("dynamic") ||
                               exerciseName.contains("swing") ||
                               exerciseName.contains("circle") ||
                               exerciseName.contains("rotation") ||
                               exerciseName.contains("march") ||
                               exerciseName.contains("walk") ||
                               exerciseName.contains("roll")
                if !isDynamic {
                    print("🎯 Including STATIC stretch for cooldown: \(exercise.name)")
                    return true
                }
            }

            // SECONDARY: Recovery-focused static movements only; restrict "hold" to stretching/bodyweight context
            let isStaticRecoveryName = (exerciseName.contains("recovery") ||
                                       exerciseName.contains("cooldown") ||
                                       exerciseName.contains("cool-down") ||
                                       exerciseName.contains("relax")) &&
                                       !exerciseName.contains("dynamic") &&
                                       !exerciseName.contains("swing")
            let isBodyweightOrBand = equipment.contains("body weight") || equipment.contains("band") || equipment.contains("strap")
            if isStaticRecoveryName && isBodyweightOrBand {
                print("🎯 Including STATIC recovery exercise: \(exercise.name)")
                return true
            }

            return false
        }
        
        print("🧊 COOLDOWN DEBUG: Filtered to \(coolDownExercises.count) cooldown-suitable exercises")
        
        // FITBOD-ALIGNED: Start from muscle-targeted candidates
        let targeted = targetExercisesForMuscles(coolDownExercises, targetMuscles: targetMuscles, exerciseType: .cooldown)
        // Select ensuring coverage across target muscles (no pure random)
        let selected = selectExercisesCoveringTargetMuscles(targeted, targetMuscles: targetMuscles, maxCount: count)
        
        print("🧊 COOLDOWN DEBUG: Final selection: \(selected.count) exercises for muscles: \(targetMuscles.joined(separator: ", "))")
        for exercise in selected {
            print("   └── \(exercise.name) (\(exercise.exerciseType))")
        }
        
        // Convert to TodayWorkoutExercise with proper hold-time tracking for cooldown
        return selected.map { exercise in
            let (sets, _, restTime) = getCooldownParameters(exercise)
            let holdDuration: TimeInterval = 30
            let intervalCount = max(2, sets)
            var flex: [FlexibleSetData] = []
            for _ in 0..<intervalCount {
                var set = FlexibleSetData(trackingType: .holdTime)
                set.duration = holdDuration
                set.durationString = String(format: "%d:%02d", Int(holdDuration) / 60, Int(holdDuration) % 60)
                flex.append(set)
            }
            return TodayWorkoutExercise(
                exercise: exercise,
                sets: intervalCount,
                reps: 1,
                weight: nil,
                restTime: restTime,
                notes: "Hold stretch for 20-30 seconds",
                warmupSets: nil,
                flexibleSets: flex,
                trackingType: .holdTime
            )
        }
    }

    // MARK: - Intelligent Warmup/Cooldown Generation (Workout-Aware)

    /// Generate intelligent warmup exercises based on workout analysis
    /// Returns exercises in structured phases: Foam Rolling -> Dynamic Stretching -> Activation
    func getIntelligentWarmupExercises(
        workoutExercises: [TodayWorkoutExercise],
        customEquipment: [Equipment]? = nil,
        includeFoamRolling: Bool = true,
        totalCount: Int = 5
    ) -> [TodayWorkoutExercise] {

        // Step 1: Analyze the workout to build fatigue map
        let fatigueMap = WorkoutAnalyzerService.shared.analyzeWorkout(workoutExercises)

        print("🔥 INTELLIGENT WARMUP: Analyzing workout with \(workoutExercises.count) exercises")
        print("   └── Movement patterns: \(fatigueMap.movementPatterns.map { $0.displayName }.joined(separator: ", "))")
        print("   └── Primary muscles: \(fatigueMap.primaryMuscles.prefix(5).joined(separator: ", "))")
        print("   └── Joints involved: \(fatigueMap.jointsInvolved.prefix(3).map { $0.joint.displayName }.joined(separator: ", "))")

        var warmupExercises: [TodayWorkoutExercise] = []
        let allExercises = ExerciseDatabase.getAllExercises()

        // Step 2: Phase allocation
        let foamRollingCount = includeFoamRolling ? 1 : 0
        let dynamicStretchCount = max(2, (totalCount - foamRollingCount) / 2)
        let activationCount = totalCount - foamRollingCount - dynamicStretchCount

        // Step 3: Foam Rolling (optional, targets most fatigued muscles)
        if includeFoamRolling {
            let topMuscle = fatigueMap.musclesByFatigue.first ?? "Full Body"
            let foamRollingExercise = createFoamRollingExercise(targetMuscle: topMuscle)
            warmupExercises.append(foamRollingExercise)
            print("   └── 🧘 Foam Rolling: \(topMuscle)")
        }

        // Step 4: Dynamic Stretching (based on movement patterns)
        var usedExerciseIds: Set<Int> = []
        let dynamicExercises = selectDynamicStretchesForPatterns(
            patterns: fatigueMap.movementPatterns,
            allExercises: allExercises,
            targetMuscles: fatigueMap.primaryMuscles,
            count: dynamicStretchCount,
            usedIds: &usedExerciseIds
        )
        warmupExercises.append(contentsOf: dynamicExercises)

        // Step 5: Activation/Primer exercises
        let activationExercises = selectActivationExercises(
            patterns: fatigueMap.movementPatterns,
            allExercises: allExercises,
            targetMuscles: fatigueMap.primaryMuscles,
            count: activationCount,
            usedIds: &usedExerciseIds
        )
        warmupExercises.append(contentsOf: activationExercises)

        print("🔥 INTELLIGENT WARMUP: Generated \(warmupExercises.count) exercises")
        for (index, exercise) in warmupExercises.enumerated() {
            print("   \(index + 1). \(exercise.exercise.name)")
        }

        return warmupExercises
    }

    /// Generate intelligent cooldown exercises prioritized by muscle fatigue
    func getIntelligentCooldownExercises(
        workoutExercises: [TodayWorkoutExercise],
        customEquipment: [Equipment]? = nil,
        totalCount: Int = 4
    ) -> [TodayWorkoutExercise] {

        // Analyze the workout
        let fatigueMap = WorkoutAnalyzerService.shared.analyzeWorkout(workoutExercises)

        print("🧊 INTELLIGENT COOLDOWN: Analyzing workout")
        print("   └── Top fatigued muscles: \(fatigueMap.musclesByFatigue.prefix(5).joined(separator: ", "))")

        let allExercises = ExerciseDatabase.getAllExercises()

        // Get static stretches prioritized by fatigue
        let topFatiguedMuscles = fatigueMap.topFatiguedMuscles(count: totalCount + 2)

        var cooldownExercises: [TodayWorkoutExercise] = []
        var usedExerciseIds: Set<Int> = []

        // Select one stretch per top fatigued muscle
        for muscle in topFatiguedMuscles {
            guard cooldownExercises.count < totalCount else { break }

            if let stretch = selectStaticStretch(
                for: muscle,
                from: allExercises,
                excludingIds: usedExerciseIds
            ) {
                cooldownExercises.append(stretch)
                usedExerciseIds.insert(stretch.exercise.id)
            }
        }

        // If we still need more, add general stretches
        if cooldownExercises.count < totalCount {
            let additionalStretches = selectGeneralStaticStretches(
                from: allExercises,
                excludingIds: usedExerciseIds,
                count: totalCount - cooldownExercises.count
            )
            cooldownExercises.append(contentsOf: additionalStretches)
        }

        print("🧊 INTELLIGENT COOLDOWN: Generated \(cooldownExercises.count) exercises")
        for (index, exercise) in cooldownExercises.enumerated() {
            print("   \(index + 1). \(exercise.exercise.name)")
        }

        return cooldownExercises
    }

    // MARK: - Private Intelligent Warmup Helpers

    private func createFoamRollingExercise(targetMuscle: String) -> TodayWorkoutExercise {
        // Find a real foam rolling exercise from the database
        let allExercises = ExerciseDatabase.getAllExercises()

        // Filter to foam rolling exercises (name contains "Roll" but not "Rollout", type is Stretching)
        let foamRollExercises = allExercises.filter { exercise in
            let name = exercise.name.lowercased()
            let exerciseType = exercise.exerciseType.lowercased()

            // Must be a rolling exercise (not rollout which is an ab exercise)
            let isRolling = name.contains("roll") && !name.contains("rollout") && !name.contains("roll-up")
            let isStretching = exerciseType == "stretching"
            let isBodyweight = exercise.equipment.lowercased().contains("body weight")

            return isRolling && isStretching && isBodyweight
        }

        // Try to find one that targets the specific muscle
        let targetLower = targetMuscle.lowercased()
        let bodyPart = MuscleGroupNormalizer.bodyPartFor(muscleGroup: targetMuscle).lowercased()

        // Priority 1: Exercise name or target contains the muscle name
        var matchingExercise = foamRollExercises.first { exercise in
            let name = exercise.name.lowercased()
            let target = exercise.target.lowercased()
            return name.contains(targetLower) || target.contains(targetLower)
        }

        // Priority 2: Exercise body part matches
        if matchingExercise == nil {
            matchingExercise = foamRollExercises.first { exercise in
                exercise.bodyPart.lowercased() == bodyPart
            }
        }

        // Priority 3: Use muscle-to-exercise mapping for common muscles
        if matchingExercise == nil {
            let muscleToExerciseKeywords: [String: [String]] = [
                "quadriceps": ["rectus femoris", "thigh", "quad"],
                "hamstrings": ["hamstring"],
                "glutes": ["glute", "piriformis", "gluteus"],
                "calves": ["calf", "calves", "tibialis"],
                "back": ["lat", "thoracic", "upper back", "rhomboid", "erector"],
                "chest": ["pec", "chest"],
                "shoulders": ["shoulder", "deltoid"],
                "hip": ["hip", "iliospsoas", "tensor", "adductor"],
                "lats": ["lat"],
            ]

            if let keywords = muscleToExerciseKeywords[targetLower] ?? muscleToExerciseKeywords[bodyPart] {
                matchingExercise = foamRollExercises.first { exercise in
                    let name = exercise.name.lowercased()
                    return keywords.contains { name.contains($0) }
                }
            }
        }

        // Priority 4: Fall back to a general foam roll exercise
        if matchingExercise == nil {
            // Common general foam roll exercises by ID
            let generalFoamRollIds = [3566, 5384, 2206, 5390] // Upper Back, Thoracic Spine, Calves, Glutes
            matchingExercise = foamRollExercises.first { generalFoamRollIds.contains($0.id) }
        }

        // Last resort: just pick any foam roll exercise
        if matchingExercise == nil {
            matchingExercise = foamRollExercises.first
        }

        guard let foamRollExercise = matchingExercise else {
            // Ultimate fallback: use Roll Upper Back (ID 3566) if it exists, or first stretching exercise
            let fallback = allExercises.first { $0.id == 3566 } ?? allExercises.first { $0.exerciseType == "Stretching" }!
            return createWarmupExercise(from: fallback)
        }

        return createWarmupExercise(from: foamRollExercise)
    }

    private func createWarmupExercise(from exercise: ExerciseData) -> TodayWorkoutExercise {
        var flexibleSets: [FlexibleSetData] = []
        for _ in 0..<2 {
            var set = FlexibleSetData(trackingType: .timeOnly)
            set.duration = 45  // 45 seconds per side
            set.durationString = "0:45"
            flexibleSets.append(set)
        }

        return TodayWorkoutExercise(
            exercise: exercise,
            sets: 2,
            reps: 1,
            weight: nil,
            restTime: 10,
            notes: "Roll slowly, pause on tender spots for 30-45 seconds",
            warmupSets: nil,
            flexibleSets: flexibleSets,
            trackingType: .timeOnly
        )
    }

    private func selectDynamicStretchesForPatterns(
        patterns: [MovementPattern],
        allExercises: [ExerciseData],
        targetMuscles: [String],
        count: Int,
        usedIds: inout Set<Int>
    ) -> [TodayWorkoutExercise] {

        // Collect keywords from detected patterns
        var dynamicKeywords: Set<String> = []
        for pattern in patterns {
            dynamicKeywords.formUnion(pattern.dynamicWarmupKeywords)
        }

        // Filter to dynamic stretches/movements
        let candidates = allExercises.filter { exercise in
            guard !usedIds.contains(exercise.id) else { return false }

            let name = exercise.name.lowercased()
            let exerciseType = exercise.exerciseType.lowercased()
            let equipment = exercise.equipment.lowercased()

            // Must be bodyweight or minimal equipment
            guard equipment.contains("body weight") || equipment.contains("band") else {
                return false
            }

            // Check for dynamic patterns
            let isDynamic = name.contains("dynamic") ||
                           name.contains("swing") ||
                           name.contains("circle") ||
                           name.contains("rotation") ||
                           name.contains("march") ||
                           (name.contains("walk") && !name.contains("farmer"))

            // Check if matches pattern keywords
            let matchesPattern = dynamicKeywords.contains { keyword in
                name.contains(keyword.lowercased())
            }

            // Check if targets workout muscles
            let targetsWorkoutMuscles = targetMuscles.contains { muscle in
                exercise.bodyPart.lowercased().contains(muscle.lowercased()) ||
                exercise.target.lowercased().contains(muscle.lowercased())
            }

            return (isDynamic || matchesPattern) && (exerciseType == "stretching" || targetsWorkoutMuscles)
        }

        // Prioritize by muscle targeting
        let prioritized = prioritizeDynamicByMuscleTargeting(candidates, targetMuscles: targetMuscles)
        let selected = Array(prioritized.prefix(count))

        // Track used IDs
        for exercise in selected {
            usedIds.insert(exercise.id)
        }

        return selected.map { exercise in
            createDynamicWarmupExercise(from: exercise)
        }
    }

    private func selectActivationExercises(
        patterns: [MovementPattern],
        allExercises: [ExerciseData],
        targetMuscles: [String],
        count: Int,
        usedIds: inout Set<Int>
    ) -> [TodayWorkoutExercise] {

        // Collect activation keywords from patterns
        var activationKeywords: Set<String> = []
        for pattern in patterns {
            activationKeywords.formUnion(pattern.activationKeywords)
        }

        // Filter to activation-appropriate exercises
        let candidates = allExercises.filter { exercise in
            guard !usedIds.contains(exercise.id) else { return false }

            let name = exercise.name.lowercased()
            let exerciseType = exercise.exerciseType.lowercased()
            let equipment = exercise.equipment.lowercased()

            // Must be bodyweight or band
            guard equipment.contains("body weight") || equipment.contains("band") else {
                return false
            }

            // Exclude stretching type for activation
            guard exerciseType != "stretching" else { return false }

            // Check activation patterns
            let isActivation = name.contains("bridge") ||
                              name.contains("activation") ||
                              name.contains("primer") ||
                              name.contains("bird dog") ||
                              name.contains("dead bug") ||
                              (name.contains("band") && name.contains("pull"))

            // Check if matches pattern keywords
            let matchesPattern = activationKeywords.contains { keyword in
                name.contains(keyword.lowercased())
            }

            return isActivation || matchesPattern
        }

        let prioritized = prioritizeDynamicByMuscleTargeting(candidates, targetMuscles: targetMuscles)
        let selected = Array(prioritized.prefix(count))

        // Track used IDs
        for exercise in selected {
            usedIds.insert(exercise.id)
        }

        return selected.map { exercise in
            createActivationExercise(from: exercise)
        }
    }

    private func selectStaticStretch(
        for muscle: String,
        from allExercises: [ExerciseData],
        excludingIds: Set<Int>
    ) -> TodayWorkoutExercise? {

        let candidates = allExercises.filter { exercise in
            guard !excludingIds.contains(exercise.id) else { return false }

            let exerciseType = exercise.exerciseType.lowercased()
            let name = exercise.name.lowercased()

            // Must be stretching type
            guard exerciseType == "stretching" else { return false }

            // Exclude dynamic movements
            let isDynamic = name.contains("dynamic") ||
                           name.contains("swing") ||
                           name.contains("circle") ||
                           name.contains("rotation")
            guard !isDynamic else { return false }

            // Check muscle targeting
            let muscleKey = muscle.lowercased()
            let targetsMuscle = exercise.bodyPart.lowercased().contains(muscleKey) ||
                               exercise.target.lowercased().contains(muscleKey) ||
                               exercise.name.lowercased().contains(muscleKey)

            return targetsMuscle
        }

        guard let selected = candidates.first else { return nil }
        return createCooldownStretchExercise(from: selected)
    }

    private func selectGeneralStaticStretches(
        from allExercises: [ExerciseData],
        excludingIds: Set<Int>,
        count: Int
    ) -> [TodayWorkoutExercise] {

        let candidates = allExercises.filter { exercise in
            guard !excludingIds.contains(exercise.id) else { return false }

            let exerciseType = exercise.exerciseType.lowercased()
            let name = exercise.name.lowercased()

            guard exerciseType == "stretching" else { return false }

            let isDynamic = name.contains("dynamic") ||
                           name.contains("swing") ||
                           name.contains("circle")

            return !isDynamic
        }

        return Array(candidates.prefix(count)).map { createCooldownStretchExercise(from: $0) }
    }

    // MARK: - Exercise Creation Helpers

    private func createDynamicWarmupExercise(from exercise: ExerciseData) -> TodayWorkoutExercise {
        var flexibleSets: [FlexibleSetData] = []
        for _ in 0..<2 {
            var set = FlexibleSetData(trackingType: .timeOnly)
            set.duration = 30  // 30 seconds
            set.durationString = "0:30"
            flexibleSets.append(set)
        }

        return TodayWorkoutExercise(
            exercise: exercise,
            sets: 2,
            reps: 10,
            weight: nil,
            restTime: 10,
            notes: "Dynamic movement - controlled tempo",
            warmupSets: nil,
            flexibleSets: flexibleSets,
            trackingType: .timeOnly
        )
    }

    private func createActivationExercise(from exercise: ExerciseData) -> TodayWorkoutExercise {
        return TodayWorkoutExercise(
            exercise: exercise,
            sets: 2,
            reps: 8,
            weight: nil,
            restTime: 15,
            notes: "Activation - focus on mind-muscle connection",
            warmupSets: nil,
            flexibleSets: nil,
            trackingType: .repsOnly
        )
    }

    private func createCooldownStretchExercise(from exercise: ExerciseData) -> TodayWorkoutExercise {
        var flexibleSets: [FlexibleSetData] = []
        for _ in 0..<2 {
            var set = FlexibleSetData(trackingType: .holdTime)
            set.duration = 30  // 30 second hold
            set.durationString = "0:30"
            flexibleSets.append(set)
        }

        return TodayWorkoutExercise(
            exercise: exercise,
            sets: 2,
            reps: 1,
            weight: nil,
            restTime: 5,
            notes: "Hold stretch for 20-30 seconds",
            warmupSets: nil,
            flexibleSets: flexibleSets,
            trackingType: .holdTime
        )
    }

    private func prioritizeDynamicByMuscleTargeting(_ exercises: [ExerciseData], targetMuscles: [String]) -> [ExerciseData] {
        return exercises.sorted { ex1, ex2 in
            let score1 = muscleTargetingScoreForWarmup(ex1, targetMuscles: targetMuscles)
            let score2 = muscleTargetingScoreForWarmup(ex2, targetMuscles: targetMuscles)
            return score1 > score2
        }
    }

    private func muscleTargetingScoreForWarmup(_ exercise: ExerciseData, targetMuscles: [String]) -> Int {
        var score = 0
        for muscle in targetMuscles {
            let muscleKey = muscle.lowercased()
            if exercise.bodyPart.lowercased().contains(muscleKey) { score += 3 }
            if exercise.target.lowercased().contains(muscleKey) { score += 2 }
            if exercise.synergist.lowercased().contains(muscleKey) { score += 1 }
        }
        return score
    }

    // Helper method to prioritize exercises for target muscles
    private func prioritizeForTargetMuscles(_ exercises: [ExerciseData], targetMuscles: [String]) -> [ExerciseData] {
        let targetMusclesLower = targetMuscles.map { $0.lowercased() }
        
        return exercises.sorted { exercise1, exercise2 in
            let score1 = getTargetMuscleScore(exercise1, targetMuscles: targetMusclesLower)
            let score2 = getTargetMuscleScore(exercise2, targetMuscles: targetMusclesLower)
            return score1 > score2
        }
    }
    
    // Calculate how well an exercise matches target muscles
    private func getTargetMuscleScore(_ exercise: ExerciseData, targetMuscles: [String]) -> Int {
        let bodyPart = exercise.bodyPart.lowercased()
        let target = exercise.target.lowercased()
        var score = 0
        
        for muscle in targetMuscles {
            if bodyPart.contains(muscle) {
                score += 2 // Higher score for body part match
            }
            if target.contains(muscle) {
                score += 1 // Lower score for target match
            }
        }
        
        return score
    }

    /// Select exercises ensuring coverage of target muscles first, then fill remaining by overall priority.
    private func selectExercisesCoveringTargetMuscles(
        _ candidates: [ExerciseData],
        targetMuscles: [String],
        maxCount: Int
    ) -> [ExerciseData] {
        if maxCount <= 0 || candidates.isEmpty { return [] }
        let lowerTargets = targetMuscles.map { $0.lowercased() }
        var selected: [ExerciseData] = []
        var usedIds = Set<Int>()

        // Deterministic day offset to rotate within top options without randomness
        let dayOffset = (Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0) % 3

        // 1) Coverage pass: try to pick one per target muscle
        for muscle in lowerTargets {
            guard selected.count < maxCount else { break }
            let muscleMatches = candidates.filter { ex in
                let bp = ex.bodyPart.lowercased()
                let tg = ex.target.lowercased()
                return bp.contains(muscle) || tg.contains(muscle)
            }
            if muscleMatches.isEmpty { continue }

            // Sort matches by evidence-based priority
            let prioritized = prioritizeExercises(muscleMatches)

            // Rotate pick within top 3 by dayOffset (stable variety)
            let pickIndex = min(dayOffset, max(0, prioritized.count - 1))
            let pick = prioritized[pickIndex]
            if !usedIds.contains(pick.id) {
                selected.append(pick)
                usedIds.insert(pick.id)
            }
        }

        // 2) Fill remaining slots by overall priority
        if selected.count < maxCount {
            let prioritizedAll = prioritizeExercises(candidates)
            for ex in prioritizedAll {
                if selected.count >= maxCount { break }
                if !usedIds.contains(ex.id) {
                    selected.append(ex)
                    usedIds.insert(ex.id)
                }
            }
        }

        // Truncate to maxCount
        if selected.count > maxCount {
            selected = Array(selected.prefix(maxCount))
        }
        return selected
    }
    
    // New method to get recovery-optimized workout recommendations
    func getRecoveryOptimizedWorkout(targetMuscleCount: Int = 4) -> [String] {
        let recoveryService = MuscleRecoveryService.shared
        let recommendedMuscles = recoveryService.getRecommendedMuscleGroups(for: targetMuscleCount)
        return recommendedMuscles.map { $0.rawValue }
    }
    
    private func prioritizeExercises(_ exercises: [ExerciseData]) -> [ExerciseData] {
        let userProfile = UserProfileService.shared
        
        return exercises.sorted { exercise1, exercise2 in
            let score1 = getExerciseScore(exercise1, userProfile: userProfile)
            let score2 = getExerciseScore(exercise2, userProfile: userProfile)
            return score1 > score2
        }
    }
    
    private func prioritizeExercises(_ exercises: [ExerciseData], recoveryPercentage: Double, maxCount: Int) -> [ExerciseData] {
        let userProfile = UserProfileService.shared

        let sortedExercises = exercises.sorted { exercise1, exercise2 in
            let score1 = getExerciseScore(exercise1, userProfile: userProfile)
            let score2 = getExerciseScore(exercise2, userProfile: userProfile)
            
            // Prioritize based on recovery status
            if recoveryPercentage > 0.7 { // High recovery, prioritize recovery-specific exercises
                return score1 > score2
            } else { // Low recovery, prioritize general fitness/hypertrophy
                return score1 > score2
            }
        }
        
        // Enforce diversity and redundancy caps (Fitbod-style)
        let diversified = enforceDiversity(sortedExercises, goal: userProfile.fitnessGoal, maxCount: maxCount)
        return diversified
    }

    private func applyVariabilitySelection(
        _ sortedExercises: [ExerciseData],
        muscleGroup: String,
        desiredCount: Int
    ) -> [ExerciseData] {
        guard desiredCount > 0, sortedExercises.count > 1 else { return sortedExercises }

        let variabilityPreference = UserProfileService.shared.exerciseVariability
        let reuseRatio: Double
        switch variabilityPreference {
        case .consistent: reuseRatio = 0.75
        case .balanced: reuseRatio = 0.5
        case .variable: reuseRatio = 0.25
        }

        // Skip extra work when ratio aligns with default outcome (balanced) and no history exists
        let recentUsage = ExerciseHistoryDataService.getRecentExercises(for: muscleGroup, days: 14)
        guard !recentUsage.isEmpty else { return sortedExercises }

        let recentIds = Set(recentUsage.map { $0.exercise.id })

        // Partition list while preserving current score ordering
        let recentExercises = sortedExercises.filter { recentIds.contains($0.id) }
        let freshExercises = sortedExercises.filter { !recentIds.contains($0.id) }

        if recentExercises.isEmpty || freshExercises.isEmpty {
            // Not enough variety data to make a meaningful adjustment
            return sortedExercises
        }

        var targetReuse = min(recentExercises.count, Int(round(Double(desiredCount) * reuseRatio)))
        var targetFresh = desiredCount - targetReuse

        if targetFresh > freshExercises.count {
            targetFresh = freshExercises.count
            targetReuse = min(desiredCount - targetFresh, recentExercises.count)
        }

        if targetReuse > recentExercises.count {
            targetReuse = recentExercises.count
            targetFresh = min(desiredCount - targetReuse, freshExercises.count)
        }

        var selected: [ExerciseData] = []
        selected.reserveCapacity(desiredCount)
        var usedIds = Set<Int>()

        var reuseIndex = 0
        var freshIndex = 0
        var reuseTaken = 0
        var freshTaken = 0

        func takeFromRecent() -> ExerciseData? {
            guard reuseIndex < recentExercises.count else { return nil }
            let exercise = recentExercises[reuseIndex]
            reuseIndex += 1
            if usedIds.contains(exercise.id) { return takeFromRecent() }
            usedIds.insert(exercise.id)
            return exercise
        }

        func takeFromFresh() -> ExerciseData? {
            guard freshIndex < freshExercises.count else { return nil }
            let exercise = freshExercises[freshIndex]
            freshIndex += 1
            if usedIds.contains(exercise.id) { return takeFromFresh() }
            usedIds.insert(exercise.id)
            return exercise
        }

        switch variabilityPreference {
        case .consistent:
            while selected.count < desiredCount, reuseTaken < targetReuse, let exercise = takeFromRecent() {
                selected.append(exercise)
                reuseTaken += 1
            }
            while selected.count < desiredCount, let exercise = takeFromFresh() {
                selected.append(exercise)
                freshTaken += 1
            }
            while selected.count < desiredCount {
                if let exercise = takeFromRecent() {
                    selected.append(exercise)
                    reuseTaken += 1
                } else if let exercise = takeFromFresh() {
                    selected.append(exercise)
                    freshTaken += 1
                } else {
                    break
                }
            }

        case .variable:
            while selected.count < desiredCount, freshTaken < targetFresh, let exercise = takeFromFresh() {
                selected.append(exercise)
                freshTaken += 1
            }
            while selected.count < desiredCount, reuseTaken < targetReuse, let exercise = takeFromRecent() {
                selected.append(exercise)
                reuseTaken += 1
            }
            while selected.count < desiredCount {
                if let exercise = takeFromFresh() {
                    selected.append(exercise)
                    freshTaken += 1
                } else if let exercise = takeFromRecent() {
                    selected.append(exercise)
                    reuseTaken += 1
                } else {
                    break
                }
            }

        case .balanced:
            while selected.count < desiredCount {
                var appended = false
                if freshTaken < targetFresh, let exercise = takeFromFresh() {
                    selected.append(exercise)
                    freshTaken += 1
                    appended = true
                }
                if selected.count >= desiredCount { break }
                if reuseTaken < targetReuse, let exercise = takeFromRecent() {
                    selected.append(exercise)
                    reuseTaken += 1
                    appended = true
                }
                if !appended { break }
                if freshTaken >= targetFresh && reuseTaken >= targetReuse { break }
            }
        }

        // Fill remaining slots with whichever pool still has candidates, preserving original order
        while selected.count < desiredCount, let exercise = takeFromRecent() {
            selected.append(exercise)
        }
        while selected.count < desiredCount, let exercise = takeFromFresh() {
            selected.append(exercise)
        }

        // Append any exercises not yet selected to keep availability for downstream callers (e.g. duration tuning)
        let remainder = sortedExercises.filter { !usedIds.contains($0.id) }
        let adjusted = selected + remainder

        if adjusted.count >= desiredCount {
            print("🔄 Variability applied for \(muscleGroup): mode=\(variabilityPreference) → reuse target \(min(reuseTaken, desiredCount))/\(desiredCount)")
        }

        return adjusted
    }
    
    private func getExerciseScore(_ exercise: ExerciseData, userProfile: UserProfileService) -> Int {
        // Evidence-based Training Stimulus Scoring System
        // Prioritizes progressive overload potential over arbitrary complexity
        var score = 0
        let complexityService = ExerciseComplexityService.shared
        let complexity = complexityService.getExerciseComplexity(exercise)
        
        // PRIMARY FACTOR: Progressive Overload Potential (40% weight)
        let progressionScore = getProgressionPotential(exercise, userProfile: userProfile)
        score += progressionScore * 4
        
        // SECONDARY FACTOR: Movement Quality & Safety (30% weight)
        let qualityScore = getMovementQuality(exercise, userProfile: userProfile)
        score += qualityScore * 3
        
        // TERTIARY FACTOR: Goal-Specific Optimization (20% weight)
        let goalScore = getGoalSpecificScore(exercise, userProfile: userProfile)
        score += goalScore * 2

        // EQUIPMENT FACTOR: Prefer appropriate equipment for the goal (Fitbod‑style)
        let equipmentPref = getEquipmentPreferenceScore(exercise, userProfile: userProfile)
        score += equipmentPref * 2 // meaningful weight so it shifts selection

        // MINOR FACTOR: User Preferences & History (10% weight)
        let preferenceScore = getUserPreferenceScore(exercise, userProfile: userProfile)
        score += preferenceScore
        
        // Evidence-based scoring: progression(\(progressionScore)×4) + quality(\(qualityScore)×3) + goal(\(goalScore)×2) + equipment(\(equipmentPref)×2) + preference(\(preferenceScore)×1) = \(score)
        
        return score
    }

    // MARK: - Goal × Equipment weighting (prevents bodyweight dominance for hypertrophy/strength when weights exist)
    private func getEquipmentPreferenceScore(_ exercise: ExerciseData, userProfile: UserProfileService) -> Int {
        let goal = userProfile.fitnessGoal.normalized
        let availableEquipment = userProfile.bodyweightOnlyWorkouts ? [] : userProfile.availableEquipment
        let equip = exercise.equipment.lowercased()
        let hasBarbell = availableEquipment.contains(.barbells)
        let hasDumbbell = availableEquipment.contains(.dumbbells)
        let hasCable = availableEquipment.contains(.cable) || availableEquipment.contains(.latPulldownCable)
        let hasMachines = availableEquipment.contains(.hammerstrengthMachine) || availableEquipment.contains(.legPress) || availableEquipment.contains(.smithMachine)
        let hasWeightedOptions = hasBarbell || hasDumbbell || hasCable || hasMachines

        func isBodyweight() -> Bool {
            return equip == "body weight" || equip.isEmpty || equip.contains("bodyweight")
        }
        func isBarbell() -> Bool { equip.contains("barbell") && !equip.contains("ez") }
        func isDumbbell() -> Bool { equip.contains("dumbbell") }
        func isCable() -> Bool { equip.contains("cable") }
        func isMachine() -> Bool { equip.contains("machine") || equip.contains("leverage") || equip.contains("smith") }

        switch goal {
        case .hypertrophy:
            if isBarbell() { return 3 }
            if isDumbbell() { return 2 }
            if isCable() || isMachine() { return 2 }
            if isBodyweight() {
                return hasWeightedOptions ? -1 : 0
            }
            return 0
        case .strength, .powerlifting:
            if isBarbell() { return 4 }
            if isDumbbell() { return 2 }
            if isMachine() { return 1 }
            if isBodyweight() { return -1 }
            return 0
        case .circuitTraining:
            if isBodyweight() { return 2 }
            if isDumbbell() { return 1 }
            if isBarbell() { return -1 }
            return 0
        default:
            return 0
        }
    }
    
    // MARK: - Evidence-Based Scoring Components
    
    private func getProgressionPotential(_ exercise: ExerciseData, userProfile: UserProfileService) -> Int {
        let equipment = exercise.equipment.lowercased()
        let name = exercise.name.lowercased()
        
        // Highest progression: External load exercises (infinite scalability)
        if equipment.contains("barbell") || equipment.contains("dumbbell") || equipment.contains("machine") {
            // Compound movements with external load = maximum progression potential
            if getExerciseCategory(exercise) == .compound {
                return 5 // Squats, deadlifts, presses with weight
            }
            return 4 // Isolation with weight still has good progression
        }
        
        // Moderate progression: Bodyweight with progression options
        if equipment.contains("body") || equipment.contains("bodyweight") {
            // Check if exercise has clear progression path
            if containsProgressionKeywords(name) {
                return 3 // Push-ups (can add weight), pull-ups (can add weight)
            }
            return 2 // Basic bodyweight (limited progression)
        }
        
        // Low progression: Fixed resistance or complex skills
        if containsFixedComplexityKeywords(name) {
            return 1 // Handstands, pistol squats (limited progression options)
        }
        
        return 3 // Default moderate progression
    }
    
    private func getMovementQuality(_ exercise: ExerciseData, userProfile: UserProfileService) -> Int {
        let complexity = ExerciseComplexityService.shared.getExerciseComplexity(exercise)
        let experience = userProfile.experienceLevel
        
        // Evidence: Movement quality deteriorates with excessive complexity
        // Advanced users benefit from mastery of fundamentals, not just hard exercises
        let qualityScore: Int
        switch experience {
        case .beginner:
            // Beginners need simple, safe movements they can master
            qualityScore = complexity <= 2 ? 5 : (complexity == 3 ? 2 : 0)
        case .intermediate:
            // Intermediates benefit from moderate complexity with room to master
            qualityScore = complexity <= 3 ? 5 : (complexity == 4 ? 3 : 1)
        case .advanced:
            // Advanced users: Optimal training comes from MASTERY, not maximum complexity
            // Elite athletes use 80% Level 2-3 exercises for a reason
            switch complexity {
            case 1, 2: qualityScore = 5 // Foundation work always valuable (recovery, volume)
            case 3: qualityScore = 5    // Intermediate complexity is the sweet spot for advanced users
            case 4: qualityScore = 3    // Advanced complexity occasionally, with purpose
            case 5: qualityScore = 1    // Expert complexity sparingly, for specific goals only
            default: qualityScore = 3
            }
        }
        
        // Movement Quality: L\(complexity) for \(experience) → Score: \(qualityScore)/5
        return qualityScore
    }
    
    private func getGoalSpecificScore(_ exercise: ExerciseData, userProfile: UserProfileService) -> Int {
        let category = getExerciseCategory(exercise)
        let goal = userProfile.fitnessGoal
        
        switch goal.normalized {
        case .strength, .powerlifting:
            // Strength goals: Prioritize progressive overload with compounds
            return category == .compound ? 5 : 2
        case .hypertrophy:
            // Hypertrophy: Balance compounds and isolation, volume focus
            return category == .isolation ? 5 : 4
        case .circuitTraining, .endurance:
            // Endurance: Higher rep ranges, time efficiency
            return 4 // Most exercises work for endurance with proper programming
        case .general:
            // General fitness: Balanced approach, sustainability focus
            return category == .compound ? 4 : 3
        default:
            return 3
        }
    }
    
    private func getUserPreferenceScore(_ exercise: ExerciseData, userProfile: UserProfileService) -> Int {
        var score = 0
        
        // Historical performance (proven exercises)
        if userProfile.getExercisePerformance(exerciseId: exercise.id) != nil {
            score += 2 // Experience with exercise is valuable
        }
        
        // User preferences by type
        let exerciseType = getExerciseType(exercise)
        if userProfile.preferredExerciseTypes.contains(exerciseType) {
            score += 1
        }
        
        // Per-exercise bias (More/Less Often)
        score += userProfile.getExercisePreferenceBias(exerciseId: exercise.id)
        
        return score
    }

    // MARK: - Redundancy/Diversity System
    private enum DiversityPattern: String { case squat, hinge, lunge, push, pull, isolation, core, other }

    private func enforceDiversity(_ sorted: [ExerciseData], goal: FitnessGoal, maxCount: Int) -> [ExerciseData] {
        var selected: [ExerciseData] = []
        var patternCounts: [DiversityPattern: Int] = [:]
        var isolationMuscleCounts: [String: Int] = [:]
        var selectedIds = Set<Int>()

        let minPatterns = (goal.normalized == .hypertrophy || goal.normalized == .strength) ? 3 : 3
        let caps: [DiversityPattern: Int] = [
            .squat: 2, .hinge: 2, .lunge: 2, .push: 2, .pull: 2, .isolation: 99, .core: 2, .other: 99
        ]

        for candidate in sorted {
            if selected.count >= maxCount { break }
            let pattern = diversityPattern(for: candidate)
            let countForPattern = patternCounts[pattern] ?? 0
            if countForPattern >= (caps[pattern] ?? 2) { continue }

            // Isolation per-muscle cap (max 2)
            if pattern == .isolation {
                let muscle = primaryMuscleKey(candidate)
                if (isolationMuscleCounts[muscle] ?? 0) >= 2 { continue }
            }

            // Similarity gate
            var redundant = false
            for ex in selected {
                let sim = similarity(candidate, ex)
                let exPat = diversityPattern(for: ex)
                let exCount = patternCounts[exPat] ?? 0
                // If we already have one of this pattern and similarity is very high, skip
                if exPat == pattern && exCount >= 1 && sim > 0.8 { redundant = true; break }
                // If we already have two of this pattern and similarity is medium, skip
                if exPat == pattern && exCount >= 2 && sim > 0.6 { redundant = true; break }
            }
            if redundant { continue }

            // Diversity bias: prefer a new pattern until we reach minPatterns
            let uniquePatterns = Set(selected.map { diversityPattern(for: $0) })
            if uniquePatterns.count < minPatterns {
                // If this candidate adds a new pattern, strongly prefer it; otherwise allow only 50% chance
                if uniquePatterns.contains(pattern) == false {
                    // ok
                } else {
                    // allow but deprioritize: continue if we still need patterns and we already have a duplicate
                    continue
                }
            }

            // Accept
            selected.append(candidate)
            selectedIds.insert(candidate.id)
            patternCounts[pattern] = (patternCounts[pattern] ?? 0) + 1
            if pattern == .isolation {
                let muscle = primaryMuscleKey(candidate)
                isolationMuscleCounts[muscle] = (isolationMuscleCounts[muscle] ?? 0) + 1
            }
        }

        if selected.count < maxCount {
            let relaxedCaps = caps.mapValues { $0 + 1 }
            for candidate in sorted {
                if selected.count >= maxCount { break }
                if selectedIds.contains(candidate.id) { continue }

                let pattern = diversityPattern(for: candidate)
                let currentCount = patternCounts[pattern] ?? 0
                let allowed = relaxedCaps[pattern] ?? (currentCount + 1)
                if currentCount >= allowed { continue }

                if pattern == .isolation {
                    let muscle = primaryMuscleKey(candidate)
                    if (isolationMuscleCounts[muscle] ?? 0) >= 3 { continue }
                }

                var redundant = false
                for ex in selected {
                    if ex.id == candidate.id { continue }
                    let sim = similarity(candidate, ex)
                    if diversityPattern(for: ex) == pattern && sim > 0.9 {
                        redundant = true
                        break
                    }
                }
                if redundant { continue }

                selected.append(candidate)
                selectedIds.insert(candidate.id)
                patternCounts[pattern] = (patternCounts[pattern] ?? 0) + 1
                if pattern == .isolation {
                    let muscle = primaryMuscleKey(candidate)
                    isolationMuscleCounts[muscle] = (isolationMuscleCounts[muscle] ?? 0) + 1
                }
            }
        }
        return selected
    }

    private func diversityPattern(for ex: ExerciseData) -> DiversityPattern {
        let n = ex.name.lowercased()
        let eq = ex.equipment.lowercased()
        let part = ex.bodyPart.lowercased()

        // Legs
        if n.contains("squat") || n.contains("leg press") || n.contains("hack squat") { return .squat }
        if n.contains("deadlift") || n.contains("rdl") || n.contains("good morning") || n.contains("hip thrust") || n.contains("glute bridge") { return .hinge }
        if n.contains("lunge") || n.contains("split squat") || n.contains("step-up") || n.contains("bulgarian") { return .lunge }
        if n.contains("leg curl") || n.contains("leg extension") || n.contains("calf raise") { return .isolation }

        // Upper body
        if n.contains("bench press") || (n.contains("press") && (part.contains("chest") || part.contains("shoulder"))) || n.contains("dip") { return .push }
        if n.contains("row") || n.contains("pulldown") || n.contains("pull-up") || n.contains("chin-up") || n.contains("face pull") { return .pull }

        // Core
        if n.contains("plank") || n.contains("crunch") || n.contains("sit-up") || n.contains("rotation") || n.contains("pallof") || n.contains("carry") { return .core }

        // Fallback by type/equipment
        if ex.exerciseType.lowercased() == "stretching" { return .core }
        if eq.contains("barbell") || eq.contains("dumbbell") || eq.contains("machine") || eq.contains("cable") { return .other }
        return .other
    }

    private func equipmentCategory(for ex: ExerciseData) -> String {
        let e = ex.equipment.lowercased()
        if e.contains("barbell") && !e.contains("ez") { return "barbell" }
        if e.contains("dumbbell") { return "dumbbell" }
        if e.contains("cable") { return "cable" }
        if e.contains("machine") || e.contains("leverage") || e.contains("smith") { return "machine" }
        if e.contains("kettlebell") { return "kettlebell" }
        if e.contains("body") || e.isEmpty { return "bodyweight" }
        return e
    }

    private func isUnilateral(_ ex: ExerciseData) -> Bool {
        let n = ex.name.lowercased()
        return n.contains("single") || n.contains("one-arm") || n.contains("one arm") || n.contains("one-leg") || n.contains("bulgarian") || n.contains("split squat") || n.contains("lunge") || n.contains("step-up")
    }

    private func primaryMuscleKey(_ ex: ExerciseData) -> String {
        let t = ex.target.lowercased()
        if t.contains("quad") || t.contains("rectus femoris") || t.contains("vastus") { return "quads" }
        if t.contains("hamstring") || t.contains("biceps femoris") { return "hamstrings" }
        if t.contains("glute") || t.contains("gluteus") { return "glutes" }
        if t.contains("calf") || t.contains("gastrocnemius") || t.contains("soleus") { return "calves" }
        if t.contains("chest") || t.contains("pectoralis") { return "chest" }
        if t.contains("lat") || t.contains("back") { return "back" }
        if t.contains("deltoid") || t.contains("shoulder") { return "shoulders" }
        if t.contains("triceps") { return "triceps" }
        if t.contains("biceps") { return "biceps" }
        if t.contains("abs") || t.contains("core") || t.contains("rectus abdominis") { return "core" }
        return ex.bodyPart.lowercased()
    }

    private func variationKey(_ ex: ExerciseData) -> String {
        let n = ex.name.lowercased()
        if n.contains("pause") { return "pause" }
        if n.contains("tempo") || n.contains("eccentric") { return "tempo" }
        if n.contains("box") { return "box" }
        if n.contains("sumo") { return "sumo" }
        return "standard"
    }

    private func similarity(_ a: ExerciseData, _ b: ExerciseData) -> Double {
        var score: Double = 0
        let pa = diversityPattern(for: a)
        let pb = diversityPattern(for: b)
        if pa == pb { score += 0.4 }
        if variationKey(a) == variationKey(b) { score += 0.2 }
        if equipmentCategory(for: a) == equipmentCategory(for: b) { score += 0.2 }
        // muscle overlap heuristic
        if primaryMuscleKey(a) == primaryMuscleKey(b) { score += 0.2 }
        if isUnilateral(a) == isUnilateral(b) { score += 0.05 }
        return min(score, 1.0)
    }
    
    // MARK: - Experience-Tailored Exercise Selection
    
    private func getExperienceTailoredExercises(_ exercises: [ExerciseData], userProfile: UserProfileService) -> [ExerciseData] {
        let complexityService = ExerciseComplexityService.shared
        let experience = userProfile.experienceLevel
        let goal = userProfile.fitnessGoal
        
        // FITBOD-ALIGNED: First filter by progressive unlocking
        let unlockedExercises = exercises.filter { exercise in
            complexityService.isExerciseUnlockedForUser(exercise, userProfile: userProfile)
        }
        
        print("🔓 Progressive Unlocking: \(exercises.count) → \(unlockedExercises.count) exercises unlocked for \(experience)")
        
        // Get complexity distribution for unlocked exercises
        var categorizedExercises: [Int: [ExerciseData]] = [:]
        for exercise in unlockedExercises {
            let complexity = complexityService.getExerciseComplexity(exercise)
            if categorizedExercises[complexity] == nil {
                categorizedExercises[complexity] = []
            }
            categorizedExercises[complexity]?.append(exercise)
        }
        
        print("📊 Complexity Distribution Available:")
        for level in 1...5 {
            let count = categorizedExercises[level]?.count ?? 0
            if count > 0 {
                print("   Level \(level): \(count) exercises")
            }
        }
        
        // EVIDENCE-BASED EXERCISE SELECTION BY EXPERIENCE
        var selectedExercises: [ExerciseData] = []
        
        switch experience {
        case .beginner:
            // Beginners: 80% Level 1-2, 20% Level 3, 0% Level 4+
            selectedExercises += selectExercises(from: categorizedExercises[1] ?? [], percentage: 0.5)
            selectedExercises += selectExercises(from: categorizedExercises[2] ?? [], percentage: 0.3) 
            selectedExercises += selectExercises(from: categorizedExercises[3] ?? [], percentage: 0.2)
            print("🔰 BEGINNER SELECTION: Prioritizing safety & mastery (L1-2: 80%, L3: 20%)")
            
        case .intermediate:
            // Intermediates: 30% Level 1-2, 50% Level 3, 20% Level 4
            selectedExercises += selectExercises(from: categorizedExercises[1] ?? [], percentage: 0.15)
            selectedExercises += selectExercises(from: categorizedExercises[2] ?? [], percentage: 0.15)
            selectedExercises += selectExercises(from: categorizedExercises[3] ?? [], percentage: 0.5)
            selectedExercises += selectExercises(from: categorizedExercises[4] ?? [], percentage: 0.2)
            print("💯 INTERMEDIATE SELECTION: Building complexity progressively (L3: 50%, L4: 20%)")
            
        case .advanced:
            // Advanced: EVIDENCE-BASED approach - Elite athletes use 80% L2-3!
            switch goal {
            case .strength, .powerlifting:
                // Strength: Focus on progressive overload with fundamentals
                selectedExercises += selectExercises(from: categorizedExercises[2] ?? [], percentage: 0.4)
                selectedExercises += selectExercises(from: categorizedExercises[3] ?? [], percentage: 0.4)
                selectedExercises += selectExercises(from: categorizedExercises[4] ?? [], percentage: 0.2)
                print("💪 ADVANCED STRENGTH: Elite approach - fundamentals with progressive overload (L2-3: 80%)")
                
            case .hypertrophy:
                // Hypertrophy: Volume focus with variety
                selectedExercises += selectExercises(from: categorizedExercises[1] ?? [], percentage: 0.2) // Isolation work
                selectedExercises += selectExercises(from: categorizedExercises[2] ?? [], percentage: 0.3)
                selectedExercises += selectExercises(from: categorizedExercises[3] ?? [], percentage: 0.35)
                selectedExercises += selectExercises(from: categorizedExercises[4] ?? [], percentage: 0.15)
                print("📞 ADVANCED HYPERTROPHY: Volume & variety focus (L1-3: 85%)")
                
            default:
                // General advanced: Balanced but intelligent
                selectedExercises += selectExercises(from: categorizedExercises[1] ?? [], percentage: 0.1)
                selectedExercises += selectExercises(from: categorizedExercises[2] ?? [], percentage: 0.3)
                selectedExercises += selectExercises(from: categorizedExercises[3] ?? [], percentage: 0.4)
                selectedExercises += selectExercises(from: categorizedExercises[4] ?? [], percentage: 0.15)
                selectedExercises += selectExercises(from: categorizedExercises[5] ?? [], percentage: 0.05)
                print("🎆 ADVANCED GENERAL: Smart complexity distribution (L2-3: 70%)")
            }
        }
        
        // If we don't have enough exercises, add from available pool
        if selectedExercises.count < 5 {
            let remainingExercises = exercises.filter { exercise in
                !selectedExercises.contains(where: { $0.id == exercise.id })
            }
            selectedExercises += Array(remainingExercises.prefix(5 - selectedExercises.count))
            print("ℹ️ Added \(5 - selectedExercises.count) exercises from remaining pool")
        }
        
        print("🎯 Final Selection: \(selectedExercises.count) exercises tailored for \(experience)")
        
        // FITBOD-ALIGNED SUMMARY: Show all evidence-based decisions
        logFitbodAlignedSummary(selectedExercises, experience: experience, goal: goal)
        
        return selectedExercises
    }
    
    // MARK: - Fitbod-Aligned System Summary
    
    private func logFitbodAlignedSummary(_ exercises: [ExerciseData], experience: ExperienceLevel, goal: FitnessGoal) {
        let complexityService = ExerciseComplexityService.shared
        let recoveryService = MuscleRecoveryService.shared
        let userProfile = UserProfileService.shared
        
        print("🎆 ========== FITBOD-ALIGNED SYSTEM SUMMARY ===========")
        print("📊 User Profile: \(experience) | Goal: \(goal) | Workouts: \(userProfile.completedWorkouts)")
        
        // Show complexity distribution
        var complexityDistribution: [Int: Int] = [:]
        for exercise in exercises {
            let complexity = complexityService.getExerciseComplexity(exercise)
            complexityDistribution[complexity] = (complexityDistribution[complexity] ?? 0) + 1
        }
        
        print("🔄 Exercise Complexity Distribution:")
        for level in 1...5 {
            if let count = complexityDistribution[level] {
                let percentage = Double(count) / Double(exercises.count) * 100
                print("   Level \(level): \(count) exercises (\(Int(percentage))%)")
            }
        }
        
        // Show recovery status
        let musclesReady = recoveryService.getMusclesReadyForTraining()
        print("🔄 Recovery Status: \(musclesReady.count) muscle groups ready for training")
        
        // Show unlocking status
        let totalExercisesInDB = ExerciseDatabase.getAllExercises().count
        let unlockedCount = exercises.count
        print("🔓 Progressive Unlocking: \(unlockedCount) of ~\(totalExercisesInDB) exercises accessible")
        
        print("🎆 =================================================")
    }
    
    private func selectExercises(from exercises: [ExerciseData], percentage: Double) -> [ExerciseData] {
        let count = max(1, Int(Double(exercises.count) * percentage))
        return Array(exercises.shuffled().prefix(count))
    }
    
    // MARK: - Fitbod-Aligned Warmup/Cooldown Helpers
    
    enum FlexibilityExerciseType {
        case warmup
        case cooldown
    }
    
    /// Target exercises for specific muscles (Fitbod's approach)
    private func targetExercisesForMuscles(_ exercises: [ExerciseData], targetMuscles: [String], exerciseType: FlexibilityExerciseType) -> [ExerciseData] {
        var targeted: [ExerciseData] = []
        var general: [ExerciseData] = []
        
        for exercise in exercises {
            let bodyPart = exercise.bodyPart.lowercased()
            let target = exercise.target.lowercased()
            let synergist = exercise.synergist.lowercased()
            let name = exercise.name.lowercased()
            
            var isTargeted = false
            
            // Check if exercise targets any of the main workout muscles
            for muscle in targetMuscles {
                let muscleKey = muscle.lowercased()
                
                if bodyPart.contains(muscleKey) ||
                   target.contains(muscleKey) ||
                   synergist.contains(muscleKey) ||
                   name.contains(muscleKey) ||
                   isRelatedMuscle(muscleKey: muscleKey, exercise: exercise) {
                    isTargeted = true
                    break
                }
            }
            
            if isTargeted {
                targeted.append(exercise)
            } else {
                general.append(exercise)
            }
        }
        
        print("🎯 Muscle targeting: \(targeted.count) targeted, \(general.count) general exercises")
        
        // Return targeted exercises first, then general ones
        return targeted + general
    }
    
    /// Check if exercise targets related muscle groups
    private func isRelatedMuscle(muscleKey: String, exercise: ExerciseData) -> Bool {
        let name = exercise.name.lowercased()
        let bodyPart = exercise.bodyPart.lowercased()
        
        // Muscle group relationships for better targeting
        switch muscleKey {
        case "chest", "pectoralis":
            return name.contains("chest") || name.contains("pec") || bodyPart.contains("chest")
        case "back", "latissimus":
            return name.contains("back") || name.contains("lat") || name.contains("spine") || bodyPart.contains("back")
        case "shoulders", "deltoid":
            return name.contains("shoulder") || name.contains("deltoid") || bodyPart.contains("shoulder")
        case "legs", "quadriceps", "hamstrings":
            return name.contains("leg") || name.contains("quad") || name.contains("hamstring") || name.contains("thigh")
        case "glutes":
            return name.contains("glute") || name.contains("hip") || name.contains("butt")
        case "arms", "biceps", "triceps":
            return name.contains("arm") || name.contains("bicep") || name.contains("tricep") || bodyPart.contains("upper arms")
        default:
            return false
        }
    }
    
    // MARK: - Fitbod-Style Exercise Parameters
    
    /// Get warmup-specific sets, reps, and rest time (Fitbod approach)
    private func getWarmupParameters(_ exercise: ExerciseData) -> (sets: Int, reps: Int, restTime: Int) {
        let exerciseName = exercise.name.lowercased()
        let exerciseType = exercise.exerciseType.lowercased()
        
        if exerciseType == "stretching" {
            // Dynamic stretches: movement-based preparation
            if exerciseName.contains("dynamic") || exerciseName.contains("swing") || exerciseName.contains("circle") {
                return (sets: 2, reps: 10, restTime: 10)  // Multiple sets of movement
            } else {
                return (sets: 1, reps: 6, restTime: 10)  // Light movement
            }
        } else if exerciseName.contains("activation") || exerciseName.contains("primer") {
            // Muscle activation exercises (key for warmup)
            return (sets: 2, reps: 8, restTime: 15)
        } else if exerciseName.contains("cardio") {
            // Light cardio warmup
            return (sets: 1, reps: 12, restTime: 30)
        } else {
            // General warmup movements
            return (sets: 1, reps: 8, restTime: 15)
        }
    }
    
    /// Get cooldown-specific sets, reps, and rest time (Fitbod approach)
    private func getCooldownParameters(_ exercise: ExerciseData) -> (sets: Int, reps: Int, restTime: Int) {
        let exerciseName = exercise.name.lowercased()
        let exerciseType = exercise.exerciseType.lowercased()
        
        if exerciseType == "stretching" {
            // Static stretches: holds for deep relaxation and lengthening
            if exerciseName.contains("hold") || exerciseName.contains("static") {
                return (sets: 1, reps: 1, restTime: 20)   // Long hold with more rest
            } else {
                return (sets: 1, reps: 1, restTime: 15)  // Standard static stretch hold
            }
        } else if exerciseName.contains("recovery") || exerciseName.contains("relax") {
            // Recovery-focused gentle movements
            return (sets: 1, reps: 2, restTime: 20)
        } else {
            // General cooldown exercises
            return (sets: 1, reps: 1, restTime: 15)
        }
    }
    
    // MARK: - Fitbod-Aligned Warmup/Cooldown Summary
    
    /// Log comprehensive warmup/cooldown generation summary
    func logFlexibilitySystemSummary(warmupCount: Int, cooldownCount: Int, targetMuscles: [String]) {
        print("🎆 ========== FITBOD-ALIGNED FLEXIBILITY SYSTEM ===========")
        print("🎯 Target Muscles: \(targetMuscles.joined(separator: ", "))")
        print("🔥 WARMUP: \(warmupCount) DYNAMIC exercises (movement prep, activation)")
        print("🧊 COOLDOWN: \(cooldownCount) STATIC exercises (stretches, recovery holds)")
        print("🎆 DIFFERENTIATION: Warmup = Movement, Cooldown = Holds")
        
        if warmupCount > 0 || cooldownCount > 0 {
            print("✅ SUCCESS: Flexibility sections will appear with DIFFERENT exercises!")
        } else {
            print("⚠️ WARNING: No flexibility exercises generated - sections won't appear")
        }
        
        print("🎆 =================================================")
    }
    
    // MARK: - Helper Functions
    
    private func containsProgressionKeywords(_ name: String) -> Bool {
        let progressionKeywords = ["push-up", "pull-up", "squat", "lunge", "dip", "row", "press"]
        return progressionKeywords.contains { name.contains($0) }
    }
    
    private func containsFixedComplexityKeywords(_ name: String) -> Bool {
        let fixedKeywords = ["handstand", "pistol", "muscle-up", "planche", "human flag", "one-arm"]
        return fixedKeywords.contains { name.contains($0) }
    }
    
    private func getExerciseType(_ exercise: ExerciseData) -> ExerciseType {
        let category = getExerciseCategory(exercise)
        
        switch category {
        case .compound:
            return .compound
        case .isolation:
            return .isolation
        case .core:
            return .functional
        case .cardio:
            return .cardio
        }
    }
    
    private func adjustForExperienceLevel(_ recommendation: (sets: Int, reps: Int, weight: Double?), experience: ExperienceLevel) -> (sets: Int, reps: Int, weight: Double?) {
        switch experience {
        case .beginner:
            // Beginners: slightly fewer sets, focus on form
            return (
                sets: max(1, recommendation.sets - 1),
                reps: recommendation.reps,
                weight: recommendation.weight
            )
        case .intermediate:
            // Intermediate: standard recommendations
            return recommendation
        case .advanced:
            // Advanced: more volume and intensity
            return (
                sets: recommendation.sets + 1,
                reps: min(recommendation.reps + 2, 20), // Cap at 20 reps
                weight: recommendation.weight
            )
        }
    }
    
    private func getSmartWeight(for exercise: ExerciseData, baseWeight: Double?) -> Double? {
        let userProfile = UserProfileService.shared
        
        // Try to get recommended weight from performance history
        if let recommendedWeight = userProfile.getRecommendedWeight(exerciseId: exercise.id) {
            return recommendedWeight
        }
        
        // If no history, estimate based on bodyweight and exercise type
        if baseWeight == nil {
            return estimateStartingWeight(for: exercise)
        }
        
        return baseWeight
    }
    
    // Exposed for generators/UI fallbacks that need a deterministic starting value
    func estimateStartingWeight(for exercise: ExerciseData) -> Double? {
        // Skip true bodyweight
        let equipment = exercise.equipment.lowercased()
        if equipment.contains("body weight") || equipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }

        // Phase 1: Movement pattern classification
        enum WeightEstimatePattern { case squat, press, pull, explosive, isolation, unilateral }
        func classifyMovement(_ e: ExerciseData) -> WeightEstimatePattern {
            let n = e.name.lowercased()
            if n.contains("clean") || n.contains("snatch") || n.contains("thruster") { return .explosive }
            if n.contains("single") || n.contains("one-arm") || n.contains("one arm") || n.contains("single-arm") { return .unilateral }
            if n.contains("squat") { return .squat }
            if n.contains("press") || n.contains("push") { return .press }
            if n.contains("raise") || n.contains("curl") || n.contains("extension") || n.contains("fly") || n.contains("kickback") { return .isolation }
            return .pull
        }

        let mp = classifyMovement(exercise)

        // Phase 2: Equipment-specific base weights (in lbs). Dumbbell values are per-hand.
        func equipmentBase(_ e: ExerciseData, mp: WeightEstimatePattern) -> Double {
            let name = e.name.lowercased()
            let eq = e.equipment.lowercased()
            // Smith machine
            if eq.contains("smith") {
                if mp == .squat { return 95 } // more realistic for smith squat
                if mp == .press { return 45 }
                if mp == .pull { return 95 }
                if mp == .explosive { return 65 }
                return 30 // default smith for isolation/other
            }
            // Barbell
            if eq.contains("barbell") {
                if name.contains("deadlift") { return 135 }
                if name.contains("bench") { return 75 }
                if mp == .squat { return 95 }
                if mp == .press { return 65 } // overhead press baseline
                if mp == .pull { return 95 }
                if mp == .explosive { return 95 }
                return 45
            }
            // Dumbbell (per hand)
            if eq.contains("dumbbell") {
                if mp == .isolation { return 12 }
                if mp == .explosive { return 20 }
                if mp == .press { return 20 }
                if mp == .pull { return 20 }
                if mp == .squat { return 25 }
                return 15
            }
            // Kettlebell
            if eq.contains("kettlebell") { return (mp == .isolation ? 15 : 25) }
            // Cable / Machine / Leverage
            if eq.contains("cable") || eq.contains("machine") || eq.contains("leverage") || eq.contains("hammer") {
                if mp == .isolation { return 20 }
                if mp == .press { return 50 }
                if mp == .pull { return 70 }
                if mp == .squat { return 90 }
                if mp == .explosive { return 70 }
                return 40
            }
            // Fallback
            return 30
        }

        // Phase 3: Muscle group scaling
        func muscleMultiplier(_ e: ExerciseData) -> Double {
            let bp = e.bodyPart.lowercased()
            if bp.contains("thigh") || bp.contains("ham") || bp.contains("quad") || bp.contains("glute") || bp.contains("hip") || bp.contains("back") { return 1.0 }
            if bp.contains("chest") || bp.contains("shoulder") { return 0.7 }
            if bp.contains("arm") || bp.contains("bicep") || bp.contains("tricep") || bp.contains("calf") { return 0.4 }
            if bp.contains("forearm") || bp.contains("rear delt") { return 0.25 }
            return 0.7
        }

        // Phase 5: Experience adjustments refined
        func experienceMultiplier(_ mp: WeightEstimatePattern) -> Double {
            switch UserProfileService.shared.experienceLevel {
            case .beginner:
                switch mp {
                case .isolation: return 0.7
                case .explosive: return 0.6
                default: return 0.8 // compound
                }
            case .intermediate: return 0.9
            case .advanced: return 1.0
            }
        }

        var w = equipmentBase(exercise, mp: mp)
        w *= muscleMultiplier(exercise)

        // Unilateral adjustment (40–60% of bilateral → choose midpoint 0.5)
        if mp == .unilateral { w *= 0.5 }

        // Explosive movements tend to need higher floor
        if mp == .explosive { w = max(w, 20) }

        // Apply experience factor
        w *= experienceMultiplier(mp)

        // Phase 4: Movement-appropriate safety minimums
        func applyMinimums(_ weight: Double, eq: String, mp: WeightEstimatePattern) -> Double {
            var minW = 8.0
            if eq.contains("barbell") { minW = 45 }
            else if eq.contains("smith") { minW = 35 }
            else if mp == .explosive { minW = max(minW, 20) }
            else if mp == .squat || mp == .press || mp == .pull { minW = max(minW, 15) }
            return max(weight, minW)
        }
        w = applyMinimums(w, eq: equipment, mp: mp)

        // Round to reasonable plate steps (lbs 5, kg 2.5)
        func roundForUnits(_ value: Double) -> Double {
            let units = UserDefaults.standard.string(forKey: "workoutUnitsSystem") ?? "imperial"
            if units == "metric" { return (round(value / 2.5) * 2.5) }
            return (round(value / 5.0) * 5.0)
        }
        w = roundForUnits(w)

        if w.isNaN || !w.isFinite { return nil }
        return w
    }
    
    private func getExperienceMultiplier(_ level: ExperienceLevel) -> Double {
        switch level {
        case .beginner: return 0.6
        case .intermediate: return 1.0
        case .advanced: return 1.5
        }
    }
    
    private func getExerciseCategory(_ exercise: ExerciseData) -> ExerciseCategory {
        let bodyPart = exercise.bodyPart.lowercased()
        let equipment = exercise.equipment.lowercased()
        let exerciseType = exercise.exerciseType.lowercased()
        let exerciseName = exercise.name.lowercased()
        
        
        
        let manualOverrides: [(keyword: String, category: ExerciseCategory)] = [
            ("handstand hold", .compound),
            ("handstand push", .compound),
            ("handstand", .compound),
            ("face pull", .compound),
            ("rear delt row", .compound),
            ("rear drive", .compound)
        ]

        if let override = manualOverrides.first(where: { exerciseName.contains($0.keyword) }) {
         
            return override.category
        }

        // Core/Abs first (most specific)
        if bodyPart == "waist" || bodyPart.contains("abs") || exerciseName.contains("crunch") || exerciseName.contains("plank") {
         
            return .core
        }
        
        // Cardio/Aerobic
        if exerciseType == "aerobic" || bodyPart == "cardio" || exerciseName.contains("treadmill") {
    
            return .cardio
        }
        
        // Compound movements (multi-joint) - enhanced detection
        if isCompoundMovement(exercise) {
            
            return .compound
        }
        
        // Isolation movements (single-joint) - enhanced detection
        if isIsolationMovement(exercise) {
          
            return .isolation
        }
      
        return .isolation
    }
    
    /// Enhanced compound movement detection using exercise science principles
    private func isCompoundMovement(_ exercise: ExerciseData) -> Bool {
        let exerciseName = exercise.name.lowercased()
        let bodyPart = exercise.bodyPart.lowercased()
        let target = exercise.target.lowercased()
        
        // Primary compound movement patterns
        let compoundKeywords = [
            "squat", "deadlift", "bench press", "press", "row", "pull-up", "pullup", "chin-up", "chinup",
            "dip", "lunge", "clean", "snatch", "thrust", "burpee", "push-up", "pushup",
            "face pull", "upright row", "handstand", "rear delt row", "rear drive", "push press", "arnold press"
        ]
        
        // Check exercise name for compound patterns
        for keyword in compoundKeywords {
            if exerciseName.contains(keyword) {
                return true
            }
        }
        
        // Multi-muscle targeting (compound exercises work multiple muscle groups)
        let muscleCount = target.components(separatedBy: ",").count
        if muscleCount > 1 {
            return true
        }
        
        // Body part patterns that indicate compound movements
        let compoundBodyParts = ["back", "chest", "shoulders", "legs", "upper", "lower"]
        for bodyPartKeyword in compoundBodyParts {
            if bodyPart.contains(bodyPartKeyword) && 
               (exerciseName.contains("press") || exerciseName.contains("pull") || exerciseName.contains("squat")) {
                return true
            }
        }
        
        return false
    }
    
    /// Enhanced isolation movement detection using exercise science principles
    private func isIsolationMovement(_ exercise: ExerciseData) -> Bool {
        let exerciseName = exercise.name.lowercased()
        let bodyPart = exercise.bodyPart.lowercased()
        
        // Primary isolation movement patterns
        let isolationKeywords = [
            "curl", "extension", "raise", "fly", "kickback", "shrug", "calf raise",
            "tricep", "bicep", "lateral", "reverse", "hammer", "concentration",
            "t-raise", "y-raise"
        ]
        
        // Check exercise name for isolation patterns
        for keyword in isolationKeywords {
            if exerciseName.contains(keyword) {
                return true
            }
        }
        
        // Body part patterns that typically indicate isolation
        if bodyPart.contains("bicep") || bodyPart.contains("tricep") || 
           bodyPart.contains("forearm") || bodyPart.contains("calves") {
            return true
        }
        
        return false
    }
    
    // MARK: - Strength Training Recommendations (1-6 reps, 3-5 sets)
    private func getStrengthRecommendation(for category: ExerciseCategory) -> (sets: Int, reps: Int, weight: Double?) {
        switch category {
        case .compound:
            return (sets: 5, reps: 5, weight: nil) // 5x5 for compound movements
        case .isolation:
            return (sets: 4, reps: 6, weight: nil) // 4x6 for isolation
        case .core:
            return (sets: 3, reps: 8, weight: nil) // 3x8 for core
        case .cardio:
            return (sets: 3, reps: 6, weight: nil) // 3x6 for cardio-based strength
        }
    }
    
    // MARK: - Hypertrophy Recommendations (6-12 reps, 3-6 sets)
    private func getHypertrophyRecommendation(for category: ExerciseCategory) -> (sets: Int, reps: Int, weight: Double?) {
        switch category {
        case .compound:
            return (sets: 4, reps: 8, weight: nil) // 4x8 for compound movements
        case .isolation:
            return (sets: 3, reps: 12, weight: nil) // 3x12 for isolation
        case .core:
            return (sets: 3, reps: 15, weight: nil) // 3x15 for core
        case .cardio:
            return (sets: 3, reps: 10, weight: nil) // 3x10 for cardio-based hypertrophy
        }
    }
    
    // MARK: - Endurance Recommendations (15-20+ reps, 2-3 sets)
    private func getEnduranceRecommendation(for category: ExerciseCategory) -> (sets: Int, reps: Int, weight: Double?) {
        switch category {
        case .compound:
            return (sets: 3, reps: 15, weight: nil) // 3x15 for compound movements
        case .isolation:
            return (sets: 3, reps: 20, weight: nil) // 3x20 for isolation
        case .core:
            return (sets: 3, reps: 25, weight: nil) // 3x25 for core
        case .cardio:
            return (sets: 2, reps: 30, weight: nil) // 2x30 for cardio endurance
        }
    }
    
    // MARK: - Power Recommendations (1-5 reps, 3-6 sets)
    private func getPowerRecommendation(for category: ExerciseCategory) -> (sets: Int, reps: Int, weight: Double?) {
        switch category {
        case .compound:
            return (sets: 5, reps: 3, weight: nil) // 5x3 for compound movements
        case .isolation:
            return (sets: 4, reps: 5, weight: nil) // 4x5 for isolation
        case .core:
            return (sets: 3, reps: 8, weight: nil) // 3x8 for core
        case .cardio:
            return (sets: 3, reps: 5, weight: nil) // 3x5 for explosive cardio
        }
    }
    

    // MARK: - General Fitness Recommendations (8-12 reps, 3 sets)
    private func getGeneralRecommendation(for category: ExerciseCategory) -> (sets: Int, reps: Int, weight: Double?) {
        switch category {
        case .compound:
            return (sets: 3, reps: 10, weight: nil) // 3x10 for compound movements
        case .isolation:
            return (sets: 3, reps: 12, weight: nil) // 3x12 for isolation
        case .core:
            return (sets: 3, reps: 15, weight: nil) // 3x15 for core
        case .cardio:
            return (sets: 2, reps: 20, weight: nil) // 2x20 for cardio fitness
        }
    }
    
    // MARK: - Muscle Tone Recommendations (10-15 reps, 2-4 sets)
    private func getToneRecommendation(for category: ExerciseCategory) -> (sets: Int, reps: Int, weight: Double?) {
        switch category {
        case .compound:
            return (sets: 3, reps: 12, weight: nil) // 3x12 for compound movements
        case .isolation:
            return (sets: 3, reps: 15, weight: nil) // 3x15 for isolation
        case .core:
            return (sets: 2, reps: 20, weight: nil) // 2x20 for core
        case .cardio:
            return (sets: 2, reps: 15, weight: nil) // 2x15 for cardio tone
        }
    }
    
    // MARK: - Powerlifting Recommendations (1-5 reps, 3-6 sets)
    private func getPowerliftingRecommendation(for category: ExerciseCategory) -> (sets: Int, reps: Int, weight: Double?) {
        switch category {
        case .compound:
            return (sets: 5, reps: 3, weight: nil) // 5x3 for main lifts
        case .isolation:
            return (sets: 3, reps: 8, weight: nil) // 3x8 for accessory work
        case .core:
            return (sets: 3, reps: 10, weight: nil) // 3x10 for core strength
        case .cardio:
            return (sets: 3, reps: 5, weight: nil) // 3x5 for conditioning
        }
    }
    
    // MARK: - Sports Performance Recommendations (varies by sport needs)
    private func getSportRecommendation(for category: ExerciseCategory) -> (sets: Int, reps: Int, weight: Double?) {
        switch category {
        case .compound:
            return (sets: 4, reps: 6, weight: nil) // 4x6 for functional strength
        case .isolation:
            return (sets: 3, reps: 10, weight: nil) // 3x10 for sport-specific muscles
        case .core:
            return (sets: 3, reps: 12, weight: nil) // 3x12 for core stability
        case .cardio:
            return (sets: 3, reps: 8, weight: nil) // 3x8 for power endurance
        }
    }
    
    // MARK: - Duration-Based Exercise Recommendations
    
    /// Calculate optimal exercise count based on duration and fitness parameters using research-based algorithm
    func getOptimalExerciseCount(
        duration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        muscleGroupCount: Int,
        experienceLevel: ExperienceLevel,
        equipment: [Equipment]? = nil,
        flexibilityPreferences: FlexibilityPreferences? = nil
    ) -> (total: Int, perMuscle: Int) {
        let estimator = TimeEstimator.shared
        let format = estimator.preferredFormat(duration: duration, goal: fitnessGoal)
        let budget = estimator.makeSessionBudget(
            duration: duration,
            fitnessGoal: fitnessGoal,
            experienceLevel: experienceLevel,
            preferences: flexibilityPreferences
        )
        var averageExerciseSeconds = max(45, estimator.averageExerciseSeconds(
            goal: fitnessGoal,
            experienceLevel: experienceLevel,
            format: format
        ))

        if let equipment, !equipment.isEmpty, equipment.allSatisfy({ $0 == .bodyWeight }) {
            averageExerciseSeconds *= 0.85
        }

        var total = Int(Double(budget.availableWorkSeconds) / averageExerciseSeconds)
        let cap = estimator.exerciseCap(for: duration)
        let minExercises = estimator.minimumExercises(for: duration, muscleGroupCount: muscleGroupCount)
        if total == 0 {
            total = minExercises
        }
        total = min(cap, max(minExercises, total))
        let perMuscle = max(1, total / max(1, muscleGroupCount))
        print("⏱️ Time-estimated calculation: budget=\(budget.availableWorkSeconds)s avg=\(Int(averageExerciseSeconds))s format=\(format.rawValue) → total=\(total), cap=\(cap), perMuscle=\(perMuscle)")
        return (total: total, perMuscle: perMuscle)
    }
    
    /// Get research-based parameters using Perplexity algorithm with individual factors
    private func getGoalParameters(
        _ fitnessGoal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        gender: Gender,
        exerciseType: ExerciseCategory
    ) -> (sets: Int, reps: Int, restSeconds: Int, repDurationSeconds: Int) {
        // Base reps by goal (Perplexity algorithm)
        let baseReps = getBaseRepsForGoal(fitnessGoal)
        
        // Experience modifiers
        let experienceModifier = getExperienceModifier(experienceLevel)
        
        // Sex modifiers (Perplexity research-based)
        let genderModifier = getGenderModifier(gender)
        
        // Exercise type modifiers
        let exerciseTypeModifier = getExerciseTypeModifier(exerciseType)
        
        // Calculate final reps using Perplexity formula
        let calculatedReps = baseReps + experienceModifier + genderModifier + exerciseTypeModifier
        let unclamped = max(1, calculatedReps)
        
        // Map to standard gym rep ranges for practical use
        let finalReps = mapToStandardRepRange(unclamped, fitnessGoal: fitnessGoal, exerciseType: exerciseType)
        
      
    
        
        // Sets by goal (Exercise science validated)
        let sets = getSetsForGoal(fitnessGoal, exerciseType: exerciseType)
      
        // Rest times based on goal and reps
        let restSeconds = getRestSecondsForGoal(fitnessGoal)
        
        // Rep duration based on goal
        let repDuration = getRepDurationForGoal(fitnessGoal)
        
        return (sets: sets, reps: finalReps, restSeconds: restSeconds, repDurationSeconds: repDuration)
    }
    
    // MARK: - Perplexity Algorithm Components
    
    /// Base reps by fitness goal (Perplexity research)
    private func getBaseRepsForGoal(_ goal: FitnessGoal) -> Int {
        let base: Int
        switch goal {
        case .strength: base = 5
        case .powerlifting: base = 3
        case .hypertrophy: base = 10
        case .endurance: base = 20
        case .general: base = 12
        case .tone: base = 15
        default: base = 12 // General fitness fallback
        }
    
        return base
    }
    
    /// Experience level modifiers (Exercise science validated)
    private func getExperienceModifier(_ experience: ExperienceLevel) -> Int {
        let modifier: Int
        switch experience {
        case .beginner: modifier = 1  // Slightly higher reps for skill acquisition (reduced from 2)
        case .intermediate: modifier = 0  // Use base recommendations
        case .advanced: modifier = 0  // Keep practical ranges (changed from -1)
        }
       
        return modifier
    }
    
    /// Sex-based modifiers (Exercise science validated - reduced impact)
    private func getGenderModifier(_ gender: Gender) -> Int {
        let modifier: Int
        switch gender {
        case .male: modifier = 0  // Base recommendations
        case .female: modifier = 1  // Slight increase for fatigue resistance (reduced from 2)
        case .other: modifier = 1  // Conservative middle ground
        }
   
        return modifier
    }
    
    /// Exercise type modifiers (Exercise science validated)
    private func getExerciseTypeModifier(_ exerciseType: ExerciseCategory) -> Int {
        let modifier: Int
        switch exerciseType {
        case .compound: modifier = -1  // Multi-joint movements, lower reps (reduced from -2)
        case .isolation: modifier = 2   // Single-joint movements, higher reps (reduced from 3)
        case .core: modifier = 3        // Core work benefits from higher reps
        case .cardio: modifier = 3      // Cardio-strength work, higher reps
        }
     
        return modifier
    }
    
    /// Sets by fitness goal (Exercise science validated - practical gym standards)
    private func getSetsForGoal(_ goal: FitnessGoal, exerciseType: ExerciseCategory = .compound) -> Int {
        switch (goal, exerciseType) {
        case (.powerlifting, .compound): return 3    // Focus on quality over quantity
        case (.powerlifting, .isolation): return 3   // Accessory work
        
        case (.strength, .compound): return 3        // 3×5 or 5×3 standard
        case (.strength, .isolation): return 3       // Consistent volume
        
        case (.hypertrophy, .compound): return 3     // 3×8-12 standard
        case (.hypertrophy, .isolation): return 3    // Volume through multiple exercises
        
        case (.endurance, _): return 3              // Higher reps, moderate sets
        case (.general, _): return 3                // User-friendly standard
        case (.tone, _): return 3                   // Accessible volume
        default: return 3
        }
    }
    
    /// Rest seconds by fitness goal (research-based)
    private func getRestSecondsForGoal(_ goal: FitnessGoal) -> Int {
        switch goal {
        case .strength, .powerlifting: return 105  // ATP regeneration
        case .hypertrophy: return 75               // Metabolic stress balance
        case .endurance: return 35                 // Cardiovascular adaptation
        case .general, .tone: return 60            // General fitness
        default: return 60
        }
    }
    
    /// Rep duration by fitness goal (research-based)
    private func getRepDurationForGoal(_ goal: FitnessGoal) -> Int {
        switch goal {
        case .strength, .powerlifting: return 3  // Controlled movement
        case .hypertrophy: return 4              // Time under tension
        case .endurance: return 2                // Faster tempo
        default: return 3                        // General fitness
        }
    }
    
    /// Map calculated reps to standard gym rep schemes for practical use
    private func mapToStandardRepRange(_ reps: Int, fitnessGoal: FitnessGoal, exerciseType: ExerciseCategory) -> Int {
        var mappedReps: Int
        
        // Map to standard gym rep schemes based on fitness goal
        switch fitnessGoal {
        case .powerlifting:
            if reps <= 2 { mappedReps = 1 }        // Singles
            else if reps <= 4 { mappedReps = 3 }   // Triples  
            else { mappedReps = 5 }                // Fives
            
        case .strength:
            if reps <= 4 { mappedReps = 3 }        // 3×3
            else if reps <= 6 { mappedReps = 5 }   // 3×5 or 5×5
            else { mappedReps = 6 }                // 4×6
            
        case .hypertrophy:
            if reps <= 7 { mappedReps = 6 }        // 3×6
            else if reps <= 9 { mappedReps = 8 }   // 3×8  
            else if reps <= 11 { mappedReps = 10 } // 3×10
            else { mappedReps = 12 }               // 3×12
            
        case .endurance:
            if reps <= 17 { mappedReps = 15 }      // 3×15
            else if reps <= 22 { mappedReps = 20 } // 3×20
            else { mappedReps = 25 }               // 3×25
            
        case .general:
            if reps <= 9 { mappedReps = 8 }        // 3×8
            else if reps <= 11 { mappedReps = 10 } // 3×10
            else { mappedReps = 12 }               // 3×12
            
        case .tone:
            if reps <= 11 { mappedReps = 10 }      // 3×10
            else if reps <= 14 { mappedReps = 12 } // 3×12
            else { mappedReps = 15 }               // 3×15
            
        default:
            // Safe default mapping to common gym ranges
            if reps <= 6 { mappedReps = 5 }
            else if reps <= 9 { mappedReps = 8 }
            else if reps <= 11 { mappedReps = 10 }
            else { mappedReps = 12 }
        }
        
        // Fine-tune based on exercise type
        switch exerciseType {
        case .compound:
            // Compound movements prefer slightly lower, strength-focused ranges
            if fitnessGoal == .hypertrophy && mappedReps > 8 {
                mappedReps = max(6, mappedReps - 2) // 10→8, 12→10
            }
        case .isolation:
            // Isolation movements can handle slightly higher reps
            if fitnessGoal == .strength && mappedReps <= 5 {
                mappedReps = min(8, mappedReps + 2) // 3→5, 5→8
            }
        case .core, .cardio:
            // Core and cardio-strength exercises prefer higher reps
            mappedReps = max(mappedReps, 10)
        }
        
        if mappedReps != reps {
            
        }
        
        return mappedReps
    }

    // MARK: - Role-Based Exercise Selection

    /// Select exercises using role-based structure from session structure service.
    ///
    /// This method implements evidence-based workout programming by:
    /// 1. Determining session structure (how many of each role based on goal)
    /// 2. Classifying available exercises by role
    /// 3. Scoring exercises WITHIN each role context
    /// 4. Filling slots in order: primary compounds → secondary compounds → isolation
    ///
    /// - Parameters:
    ///   - muscleGroup: Target muscle group
    ///   - goal: Fitness goal (strength, hypertrophy, endurance, balanced)
    ///   - experience: User's experience level
    ///   - customEquipment: Available equipment for this session
    ///   - exerciseCount: Total number of exercises to select
    ///   - excludedIds: Exercise IDs to exclude from selection
    /// - Returns: Array of tuples containing (exercise, role, repRange)
    func selectExercisesByRole(
        for muscleGroup: String,
        goal: FitnessGoal,
        experience: ExperienceLevel,
        customEquipment: [Equipment]?,
        exerciseCount: Int,
        excludedIds: Set<Int> = []
    ) -> [(exercise: ExerciseData, role: ExerciseRole, repRange: String)] {

        let classifier = ExerciseRoleClassifier.shared
        let scoring = RoleBasedEquipmentScoring.shared
        let slots = SessionStructureService.shared.getExerciseSlots(goal: goal, totalExercises: exerciseCount)

        print("🎯 Role-Based Selection for \(muscleGroup): goal=\(goal.rawValue), count=\(exerciseCount)")
        print("   └── Slot distribution: \(slots.map { $0.role.rawValue }.joined(separator: ", "))")

        var usedIds = excludedIds
        var selected: [(ExerciseData, ExerciseRole, String)] = []

        // Get filtered candidates for this muscle group
        let allExercises = ExerciseDatabase.getAllExercises()
        let muscleExercises = allExercises.filter { exerciseMatchesMuscle($0, muscleGroup: muscleGroup) }

        // Filter by equipment
        let availableExercises: [ExerciseData]
        if let customEquipment = customEquipment {
            let allowedSet = equipmentOverrideSet(from: customEquipment)
            availableExercises = muscleExercises.filter { exercise in
                let (canPerform, _, _) = canPerformExerciseWithCustomEquipment(exercise, allowedEquipment: allowedSet)
                return canPerform
            }
        } else {
            let userProfile = UserProfileService.shared
            availableExercises = muscleExercises.filter { userProfile.canPerformExercise($0) }
        }

        print("   └── Available exercises after filtering: \(availableExercises.count)")

        // Group exercises by role with scores
        var byRole: [ExerciseRole: [(ExerciseData, Double)]] = [
            .primaryCompound: [],
            .secondaryCompound: [],
            .isolation: []
        ]

        for exercise in availableExercises {
            guard !usedIds.contains(exercise.id) else { continue }

            let role = classifier.classify(exercise)
            let score = calculateRoleBasedScore(
                exercise,
                goal: goal,
                role: role,
                muscleGroup: muscleGroup,
                experience: experience
            )
            byRole[role]?.append((exercise, score))
        }

        // Sort each role's exercises by score (highest first)
        for role in byRole.keys {
            byRole[role]?.sort { $0.1 > $1.1 }
        }

        print("   └── By role: primary=\(byRole[.primaryCompound]?.count ?? 0), secondary=\(byRole[.secondaryCompound]?.count ?? 0), isolation=\(byRole[.isolation]?.count ?? 0)")

        // Fill slots in order
        for slot in slots {
            let role = slot.role
            let repRange = slot.repRange

            // Find best available exercise for this role
            if let (exercise, _) = byRole[role]?.first(where: { !usedIds.contains($0.0.id) }) {
                selected.append((exercise, role, repRange))
                usedIds.insert(exercise.id)
                print("   └── Selected [\(role.rawValue)]: \(exercise.name) @ \(repRange) reps")
            } else {
                // Fallback: try adjacent roles if current role is exhausted
                let fallbackRoles: [ExerciseRole] = {
                    switch role {
                    case .primaryCompound: return [.secondaryCompound, .isolation]
                    case .secondaryCompound: return [.primaryCompound, .isolation]
                    case .isolation: return [.secondaryCompound, .primaryCompound]
                    }
                }()

                var found = false
                for fallbackRole in fallbackRoles {
                    if let (exercise, _) = byRole[fallbackRole]?.first(where: { !usedIds.contains($0.0.id) }) {
                        selected.append((exercise, fallbackRole, repRange))
                        usedIds.insert(exercise.id)
                        print("   └── Fallback [\(fallbackRole.rawValue)]: \(exercise.name) @ \(repRange) reps")
                        found = true
                        break
                    }
                }

                if !found {
                    print("   └── ⚠️ No exercise found for slot \(role.rawValue)")
                }
            }
        }

        print("🎯 Role-Based Selection complete: \(selected.count) exercises")
        return selected
    }

    /// Calculate exercise score within its role context.
    /// Equipment scores vary by (goal, role) - barbells score high for primary compounds,
    /// but cables/dumbbells score high for isolation.
    private func calculateRoleBasedScore(
        _ exercise: ExerciseData,
        goal: FitnessGoal,
        role: ExerciseRole,
        muscleGroup: String,
        experience: ExperienceLevel
    ) -> Double {
        var score = 0.0
        let scoring = RoleBasedEquipmentScoring.shared

        // 1. Role-aware equipment score (weighted heavily - this is the key differentiator)
        let equipmentScore = scoring.getScore(goal: goal, role: role, equipment: exercise.equipment)
        score += Double(equipmentScore) * 3.0

        // 2. Muscle match bonus
        let muscleKey = muscleGroup.lowercased()
        if exercise.bodyPart.lowercased().contains(muscleKey) {
            score += 15.0
        }
        if exercise.target.lowercased().contains(muscleKey) {
            score += 10.0
        }

        // 3. Equipment tier (general quality)
        let tier = scoring.getEquipmentTier(exercise.equipment)
        score += Double(tier) * 0.5

        // 4. Experience-level adjustments
        let complexity = ExerciseComplexityService.shared.getExerciseComplexity(exercise)
        switch experience {
        case .beginner:
            if complexity <= 2 { score += 5.0 }
            else if complexity >= 4 { score -= 5.0 }
        case .intermediate:
            if complexity == 3 { score += 3.0 }
        case .advanced:
            if complexity >= 3 { score += 2.0 }
        }

        return score
    }

    /// Get duration-optimized exercise recommendations
    func getDurationOptimizedExercises(
        for muscleGroup: String,
        count: Int,
        duration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences? = nil
    ) -> [ExerciseData] {
        // First get recommendations using the selected selector
        var exercises: [ExerciseData]
        if FeatureFlags.useResearchBackedSelector {
            exercises = getResearchBackedExercises(
                for: muscleGroup,
                count: count * 2,
                customEquipment: customEquipment,
                flexibilityPreferences: flexibilityPreferences
            )
        } else {
            exercises = getRecommendedExercises(
                for: muscleGroup,
                count: count * 2, // Get extra to filter optimally
                customEquipment: customEquipment,
                flexibilityPreferences: flexibilityPreferences
            )
        }

        // For shorter workouts, prioritize compound movements for time efficiency
        if duration.minutes <= 30 {
            exercises = exercises.sorted { ex1, ex2 in
                let compound1 = isCompoundMovement(ex1)
                let compound2 = isCompoundMovement(ex2)
                if compound1 != compound2 { return compound1 }
                // Prefer exercises that target more muscles
                return ex1.target.count > ex2.target.count
            }
        }

        // Apply final truncation here (single point of control)
        let finalExercises = Array(exercises.prefix(count))

        print("🎯 getDurationOptimizedExercises for \(muscleGroup): requested=\(count), available=\(exercises.count), returned=\(finalExercises.count)")

        return finalExercises
    }

    /// Get role-based exercise recommendations with rep ranges.
    ///
    /// This method uses the new role-based selection architecture when enabled,
    /// returning exercises with their assigned roles and goal-specific rep ranges.
    ///
    /// - Parameters:
    ///   - muscleGroup: Target muscle group
    ///   - count: Number of exercises to select
    ///   - duration: Workout duration (for time-based adjustments)
    ///   - fitnessGoal: Fitness goal (determines role distribution)
    ///   - experienceLevel: User's experience level
    ///   - customEquipment: Available equipment for this session
    ///   - excludedIds: Exercise IDs to exclude
    /// - Returns: Array of tuples containing (exercise, role, repRange)
    func getRoleBasedExercises(
        for muscleGroup: String,
        count: Int,
        duration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        customEquipment: [Equipment]?,
        excludedIds: Set<Int> = []
    ) -> [(exercise: ExerciseData, role: ExerciseRole, repRange: String)] {

        // Use role-based selection if feature flag is enabled
        if FeatureFlags.useRoleBasedSelection {
            return selectExercisesByRole(
                for: muscleGroup,
                goal: fitnessGoal,
                experience: experienceLevel,
                customEquipment: customEquipment,
                exerciseCount: count,
                excludedIds: excludedIds
            )
        }

        // Fallback: use traditional selection and classify after the fact
        let exercises = getDurationOptimizedExercises(
            for: muscleGroup,
            count: count,
            duration: duration,
            fitnessGoal: fitnessGoal,
            customEquipment: customEquipment
        ).filter { !excludedIds.contains($0.id) }

        let classifier = ExerciseRoleClassifier.shared

        // Map exercises to roles with default rep ranges
        return exercises.map { exercise in
            let role = classifier.classify(exercise)
            let repRange = SessionStructureService.shared.getDefaultRepRange(
                for: fitnessGoal,
                role: role
            )
            return (exercise, role, repRange)
        }
    }

}

enum ExerciseCategory {
    case compound
    case isolation
    case core
    case cardio
}

// MARK: - Dynamic Programming Integration

extension WorkoutRecommendationService {
    
    /// Bridge method: Get recommendation with optional dynamic parameters
    /// This allows the service to work with both static and dynamic systems
    @MainActor
    func getSmartRecommendationWithDynamic(
        for exercise: ExerciseData,
        fitnessGoal: FitnessGoal? = nil,
        dynamicParameters: DynamicWorkoutParameters? = nil
    ) -> (sets: Int, reps: Int, weight: Double?) {
        
        // If dynamic parameters are provided, use dynamic system
        if let params = dynamicParameters {
            let userProfile = UserProfileService.shared
            let dynamicExercise = DynamicParameterService.shared.generateDynamicExercise(
                for: exercise,
                parameters: params,
                fitnessGoal: fitnessGoal ?? userProfile.fitnessGoal
            )
            
            print("🧠 Using dynamic recommendation for \(exercise.name): \(dynamicExercise.setsAndRepsDisplay)")
            return (
                sets: dynamicExercise.setCount,
                reps: dynamicExercise.repRange.upperBound, // Use upper bound for compatibility
                weight: dynamicExercise.suggestedWeight
            )
        }
        
        // Otherwise, fall back to existing static system
        print("📊 Using static recommendation for \(exercise.name)")
        return getSmartRecommendation(for: exercise, fitnessGoal: fitnessGoal)
    }
    
    /// Check if dynamic programming should be used
    @MainActor
    func shouldUseDynamicRecommendations() -> Bool {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        return DynamicParameterService.shared.shouldUseDynamicProgramming(
            for: userEmail
        )
    }
    
    /// Get dynamic exercise recommendation if dynamic programming is enabled
    func getDynamicExerciseRecommendation(
        for exercise: ExerciseData,
        fitnessGoal: FitnessGoal,
        sessionPhase: SessionPhase,
        lastFeedback: WorkoutSessionFeedback? = nil
    ) async -> DynamicWorkoutExercise? {
        
        guard await shouldUseDynamicRecommendations() else {
            return nil
        }
        
        let parameters = await DynamicParameterService.shared.calculateDynamicParameters(
            currentPhase: sessionPhase,
            lastFeedback: lastFeedback
        )
        
        return await DynamicParameterService.shared.generateDynamicExercise(
            for: exercise,
            parameters: parameters,
            fitnessGoal: fitnessGoal
        )
    }
    
    /// Convert static exercise to dynamic exercise (migration helper)
    func convertToDynamicExercise(
        _ staticExercise: TodayWorkoutExercise,
        sessionPhase: SessionPhase = .volumeFocus,
        fitnessGoal: FitnessGoal
    ) async -> DynamicWorkoutExercise {
        
        // Get dynamic recommendation if available
        if let dynamic = await getDynamicExerciseRecommendation(
            for: staticExercise.exercise,
            fitnessGoal: fitnessGoal,
            sessionPhase: sessionPhase
        ) {
            return dynamic
        }
        
        // Fallback: convert static to fixed range dynamic
        return DynamicWorkoutExercise(
            exercise: staticExercise.exercise,
            setCount: staticExercise.sets,
            repRange: staticExercise.reps...staticExercise.reps, // Fixed range for compatibility
            targetReps: staticExercise.reps, // Use static reps as target
            targetIntensity: .hypertrophy, // Safe default
            suggestedWeight: staticExercise.weight,
            restTime: staticExercise.restTime,
            sessionPhase: sessionPhase,
            recoveryStatus: .moderate, // Default
            notes: staticExercise.notes,
            warmupSets: staticExercise.warmupSets
        )
    }
}
