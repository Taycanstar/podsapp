// FILE: Services/WorkoutRecommendationService.swift
import Foundation

class WorkoutRecommendationService {
    static let shared = WorkoutRecommendationService()
    
    private init() {}
    
    // Enhanced recommendation system using user profile and performance history
    func getSmartRecommendation(for exercise: ExerciseData) -> (sets: Int, reps: Int, weight: Double?) {
        let userProfile = UserProfileService.shared
        let exerciseCategory = getExerciseCategory(exercise)
        
        // Get base recommendation from fitness goal
        let baseRecommendation = getDefaultSetsAndReps(for: exercise, fitnessGoal: userProfile.fitnessGoal)
        
        // Adjust based on experience level
        let adjustedRecommendation = adjustForExperienceLevel(baseRecommendation, experience: userProfile.experienceLevel)
        
        // Check for historical performance and progressive overload
        let smartWeight = getSmartWeight(for: exercise, baseWeight: adjustedRecommendation.weight)
        
        return (
            sets: adjustedRecommendation.sets,
            reps: adjustedRecommendation.reps,
            weight: smartWeight
        )
    }
    
    // Default sets and reps based on fitness goal and exercise category
    func getDefaultSetsAndReps(for exercise: ExerciseData, fitnessGoal: FitnessGoal) -> (sets: Int, reps: Int, weight: Double?) {
        let exerciseCategory = getExerciseCategory(exercise)
        
        switch fitnessGoal {
        case .strength:
            return getStrengthRecommendation(for: exerciseCategory)
        case .hypertrophy:
            return getHypertrophyRecommendation(for: exerciseCategory)
        case .endurance:
            return getEnduranceRecommendation(for: exerciseCategory)
        case .power:
            return getPowerRecommendation(for: exerciseCategory)
        case .general:
            return getGeneralRecommendation(for: exerciseCategory)
        case .tone:
            return getToneRecommendation(for: exerciseCategory)
        case .powerlifting:
            return getPowerliftingRecommendation(for: exerciseCategory)
        case .sport:
            return getSportRecommendation(for: exerciseCategory)
        }
    }
    
    // MARK: - Smart Filtering & Recommendations
    
    func getRecommendedExercises(for muscleGroup: String, count: Int = 5) -> [ExerciseData] {
        let userProfile = UserProfileService.shared
        let recoveryService = MuscleRecoveryService.shared
        let allExercises = ExerciseDatabase.getAllExercises()
        
        // Check recovery status for this muscle group
        let recoveryPercentage = recoveryService.getMuscleRecoveryPercentage(for: muscleGroup)
        
        // Filter by muscle group
        let muscleExercises = allExercises.filter { exercise in
            exercise.bodyPart.lowercased().contains(muscleGroup.lowercased()) ||
            exercise.target.lowercased().contains(muscleGroup.lowercased())
        }
        
        // Filter by available equipment
        let availableExercises = muscleExercises.filter { exercise in
            userProfile.canPerformExercise(exercise)
        }
        
        // Filter out avoided exercises
        let filteredExercises = availableExercises.filter { exercise in
            !userProfile.avoidedExercises.contains(exercise.id)
        }
        
        // Prioritize exercises based on user preferences, experience, and recovery
        return prioritizeExercises(filteredExercises, recoveryPercentage: recoveryPercentage, maxCount: count)
    }
    
    // Method with custom equipment and flexibility filtering
    func getRecommendedExercises(for muscleGroup: String, count: Int = 5, customEquipment: [Equipment]?, flexibilityPreferences: FlexibilityPreferences? = nil) -> [ExerciseData] {
        let userProfile = UserProfileService.shared
        let recoveryService = MuscleRecoveryService.shared
        let allExercises = ExerciseDatabase.getAllExercises()
        
        // Check recovery status for this muscle group
        let recoveryPercentage = recoveryService.getMuscleRecoveryPercentage(for: muscleGroup)
        
        // Filter by muscle group
        let muscleExercises = allExercises.filter { exercise in
            exercise.bodyPart.lowercased().contains(muscleGroup.lowercased()) ||
            exercise.target.lowercased().contains(muscleGroup.lowercased())
        }
        
        // Filter by exercise type (exclude stretching for strength workouts by default)
        let typeFilteredExercises = filterByExerciseType(exercises: muscleExercises, flexibilityPreferences: flexibilityPreferences)
        
        // Filter by available equipment (use custom equipment if provided)
        let availableExercises: [ExerciseData]
        if let customEquipment = customEquipment, !customEquipment.isEmpty {
            availableExercises = typeFilteredExercises.filter { exercise in
                canPerformExerciseWithCustomEquipment(exercise, equipment: customEquipment)
            }
            print("🎯 Filtered exercises for \(muscleGroup) with custom equipment: \(customEquipment.map { $0.rawValue }), found \(availableExercises.count) exercises")
        } else {
            availableExercises = typeFilteredExercises.filter { exercise in
                userProfile.canPerformExercise(exercise)
            }
        }
        
        // Filter out avoided exercises
        let filteredExercises = availableExercises.filter { exercise in
            !userProfile.avoidedExercises.contains(exercise.id)
        }
        
        // Prioritize exercises based on user preferences, experience, and recovery
        return prioritizeExercises(filteredExercises, recoveryPercentage: recoveryPercentage, maxCount: count)
    }
    
    // Helper method to check if exercise can be performed with custom equipment
    private func canPerformExerciseWithCustomEquipment(_ exercise: ExerciseData, equipment: [Equipment]) -> Bool {
        let exerciseEquipment = exercise.equipment.lowercased()
        let exerciseName = exercise.name.lowercased()
        
        // Always allow bodyweight exercises (no equipment needed)
        if exerciseEquipment == "body weight" || exerciseEquipment.isEmpty {
            return true
        }
        
        // Check if any of the user's equipment matches the exercise equipment
        for userEquipment in equipment {
            let equipmentString = userEquipment.rawValue.lowercased()
            
            // Direct match
            if exerciseEquipment.contains(equipmentString.lowercased()) {
                return true
            }
            
            // Special mappings for equipment names
            switch userEquipment {
            case .bodyWeight:
                if exerciseEquipment == "body weight" || exerciseEquipment.isEmpty {
                    return true
                }
            case .dumbbells:
                if exerciseEquipment.contains("dumbbell") {
                    return true
                }
            case .barbells:
                if exerciseEquipment.contains("barbell") && !exerciseEquipment.contains("ez") {
                    return true
                }
            case .ezBar:
                if exerciseEquipment.contains("ez barbell") || exerciseEquipment.contains("ez bar") {
                    return true
                }
            case .cable:
                if exerciseEquipment.contains("cable") {
                    return true
                }
            case .kettlebells:
                if exerciseEquipment.contains("kettlebell") {
                    return true
                }
            case .smithMachine:
                if exerciseEquipment.contains("smith") {
                    return true
                }
            case .resistanceBands:
                if exerciseEquipment.contains("band") {
                    return true
                }
            case .stabilityBall:
                if exerciseEquipment.contains("stability") || exerciseEquipment.contains("swiss") || exerciseEquipment.contains("exercise ball") {
                    return true
                }
            case .bosuBalanceTrainer:
                if exerciseEquipment.contains("bosu") {
                    return true
                }
            case .medicineBalls:
                if exerciseEquipment.contains("medicine ball") {
                    return true
                }
            case .battleRopes:
                if exerciseEquipment.contains("rope") && !exerciseEquipment.contains("jump") {
                    return true
                }
            case .pullupBar:
                if exerciseEquipment.contains("pull") && (exerciseEquipment.contains("bar") || exerciseEquipment.contains("up")) {
                    return true
                }
            case .dipBar:
                if exerciseEquipment.contains("dip") || (exerciseEquipment.contains("parallel") && exerciseEquipment.contains("bar")) {
                    return true
                }
            case .pvc:
                if exerciseEquipment.contains("pvc") || exerciseEquipment.contains("pipe") {
                    return true
                }
            case .flatBench:
                // Flat bench exercises require both the bench AND the primary equipment
                return requiresBenchAndEquipment(exercise, benchType: "flat", availableEquipment: equipment)
            case .declineBench:
                // Decline bench exercises require both the bench AND the primary equipment  
                return requiresBenchAndEquipment(exercise, benchType: "decline", availableEquipment: equipment)
            case .inclineBench:
                // Incline bench exercises require both the bench AND the primary equipment
                return requiresBenchAndEquipment(exercise, benchType: "incline", availableEquipment: equipment)
            case .preacherCurlBench:
                // Preacher curl exercises require both the bench AND the primary equipment
                return requiresPreacherAndEquipment(exercise, availableEquipment: equipment)
            case .pullupBar:
                // Pull-up exercises require a pull-up bar
                return requiresPullupBar(exercise)
            case .dipBar:
                // Dip exercises require parallel bars
                return requiresDipBar(exercise)
            case .squatRack:
                // Heavy barbell exercises often require a squat rack
                return requiresSquatRackAndEquipment(exercise, availableEquipment: equipment)
            case .box:
                // Box/platform exercises
                return requiresBoxAndEquipment(exercise, availableEquipment: equipment)
            case .platforms:
                // Olympic lift platform exercises
                return requiresPlatformAndEquipment(exercise, availableEquipment: equipment)
            case .legPress:
                // Leg press machine exercises
                return exerciseName.contains("leg press")
            case .latPulldownCable:
                // Lat pulldown machine exercises
                return requiresLatPulldown(exercise)
            case .legExtensionMachine:
                // Leg extension machine exercises
                return exerciseName.contains("leg extension")
            case .legCurlMachine:
                // Leg curl machine exercises  
                return requiresLegCurl(exercise)
            case .calfRaiseMachine:
                // Calf raise machine exercises
                return requiresCalfRaiseMachine(exercise)
            case .rowMachine:
                // Seated row machine exercises
                return requiresRowMachine(exercise)
            case .hammerstrengthMachine:
                // Hammer strength machine exercises
                return exerciseEquipment.contains("leverage") || exerciseName.contains("hammer")
            case .hackSquatMachine:
                // Hack squat machine exercises
                return exerciseName.contains("hack squat")
            case .shoulderPressMachine:
                // Shoulder press machine exercises
                return exerciseName.contains("shoulder press") && exerciseEquipment.contains("leverage")
            case .tricepsExtensionMachine:
                // Triceps extension machine exercises
                return exerciseName.contains("triceps extension") && exerciseEquipment.contains("leverage")
            case .bicepsCurlMachine:
                // Biceps curl machine exercises
                return exerciseName.contains("biceps curl") && exerciseEquipment.contains("leverage")
            case .abCrunchMachine:
                // Ab crunch machine exercises
                return exerciseName.contains("crunch") && exerciseEquipment.contains("leverage")
            case .preacherCurlMachine:
                // Preacher curl machine exercises
                return exerciseName.contains("preacher") && exerciseEquipment.contains("leverage")
            default:
                // For other equipment, try partial matching
                let equipmentWords = equipmentString.components(separatedBy: " ")
                for word in equipmentWords {
                    if word.count > 3 && exerciseEquipment.contains(word.lowercased()) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // Helper method to check bench exercises that require both bench and primary equipment
    private func requiresBenchAndEquipment(_ exercise: ExerciseData, benchType: String, availableEquipment: [Equipment]) -> Bool {
        let exerciseName = exercise.name.lowercased()
        let exerciseEquipment = exercise.equipment.lowercased()
        
        // First check if this exercise actually requires the specific bench type
        let requiresThisBench: Bool
        switch benchType {
        case "flat":
            requiresThisBench = exerciseName.contains("bench") && 
                               !exerciseName.contains("decline") && 
                               !exerciseName.contains("incline")
        case "decline":
            requiresThisBench = exerciseName.contains("decline") && exerciseName.contains("bench")
        case "incline":
            requiresThisBench = exerciseName.contains("incline") && exerciseName.contains("bench")
        default:
            return false
        }
        
        if !requiresThisBench {
            return false
        }
        
        // Now check if user has the primary equipment required for the exercise
        let hasPrimaryEquipment: Bool
        if exerciseEquipment.contains("barbell") {
            hasPrimaryEquipment = availableEquipment.contains(.barbells)
        } else if exerciseEquipment.contains("dumbbell") {
            hasPrimaryEquipment = availableEquipment.contains(.dumbbells)
        } else if exerciseEquipment.contains("cable") {
            hasPrimaryEquipment = availableEquipment.contains(.cable)
        } else if exerciseEquipment.contains("smith") {
            hasPrimaryEquipment = availableEquipment.contains(.smithMachine)
        } else {
            // For other equipment types, allow the exercise
            hasPrimaryEquipment = true
        }
        
        return hasPrimaryEquipment
    }
    
    // Helper method for preacher curl exercises
    private func requiresPreacherAndEquipment(_ exercise: ExerciseData, availableEquipment: [Equipment]) -> Bool {
        let exerciseName = exercise.name.lowercased()
        let exerciseEquipment = exercise.equipment.lowercased()
        
        // Check if this is a preacher curl exercise
        guard exerciseName.contains("preacher") else { return false }
        
        // Check if user has the primary equipment
        if exerciseEquipment.contains("ez") {
            return availableEquipment.contains(.ezBar)
        } else if exerciseEquipment.contains("dumbbell") {
            return availableEquipment.contains(.dumbbells)
        } else if exerciseEquipment.contains("barbell") {
            return availableEquipment.contains(.barbells)
        } else if exerciseEquipment.contains("cable") {
            return availableEquipment.contains(.cable)
        }
        return true
    }
    
    // Helper method for pull-up bar exercises
    private func requiresPullupBar(_ exercise: ExerciseData) -> Bool {
        let exerciseName = exercise.name.lowercased()
        return exerciseName.contains("pull-up") || 
               exerciseName.contains("pullup") ||
               exerciseName.contains("pull up") ||
               exerciseName.contains("chin-up") ||
               exerciseName.contains("chinup")
    }
    
    // Helper method for dip bar exercises
    private func requiresDipBar(_ exercise: ExerciseData) -> Bool {
        let exerciseName = exercise.name.lowercased()
        return (exerciseName.contains("dip") && !exerciseName.contains("bench")) ||
               exerciseName.contains("parallel bar")
    }
    
    // Helper method for squat rack exercises
    private func requiresSquatRackAndEquipment(_ exercise: ExerciseData, availableEquipment: [Equipment]) -> Bool {
        let exerciseName = exercise.name.lowercased()
        let exerciseEquipment = exercise.equipment.lowercased()
        
        // Heavy barbell exercises that typically need a rack
        let needsRack = (exerciseName.contains("squat") && !exerciseName.contains("hack")) ||
                       exerciseName.contains("olympic") ||
                       exerciseName.contains("back squat") ||
                       exerciseName.contains("front squat")
        
        if !needsRack { return false }
        
        // Check if user has the primary equipment
        if exerciseEquipment.contains("barbell") {
            return availableEquipment.contains(.barbells)
        }
        return true
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
    
    // MARK: - Flexibility Exercise Filtering
    
    // Filter exercises by type based on flexibility preferences
    private func filterByExerciseType(exercises: [ExerciseData], flexibilityPreferences: FlexibilityPreferences?) -> [ExerciseData] {
        // If no preferences specified, exclude stretching exercises by default
        guard let prefs = flexibilityPreferences else {
            return exercises.filter { $0.exerciseType.lowercased() != "stretching" }
        }
        
        // If flexibility is completely disabled, exclude all stretching
        if !prefs.isEnabled {
            return exercises.filter { $0.exerciseType.lowercased() != "stretching" }
        }
        
        // If flexibility is enabled, allow both strength and stretching exercises
        // The actual warm-up/cool-down exercises will be handled separately
        return exercises
    }
    
    // Get warm-up exercises (dynamic stretches and activation exercises)
    func getWarmUpExercises(targetMuscles: [String], customEquipment: [Equipment]? = nil, count: Int = 3) -> [TodayWorkoutExercise] {
        let allExercises = ExerciseDatabase.getAllExercises()
        
        // Filter for exercises that are suitable for warm-up
        let warmUpExercises = allExercises.filter { exercise in
            let exerciseType = exercise.exerciseType.lowercased()
            let exerciseName = exercise.name.lowercased()
            let bodyPart = exercise.bodyPart.lowercased()
            
            // Look for bodyweight/mobility exercises suitable for warm-up
            let isBodyweight = exercise.equipment.lowercased().contains("body weight") || exercise.equipment.lowercased().isEmpty
            
            // Look for warm-up suitable exercises by name patterns
            let isWarmupSuitable = exerciseName.contains("stretch") ||
                                  exerciseName.contains("mobility") ||
                                  exerciseName.contains("activation") ||
                                  exerciseName.contains("walk") ||
                                  exerciseName.contains("march") ||
                                  exerciseName.contains("swing") ||
                                  exerciseName.contains("circle") ||
                                  exerciseName.contains("rotation") ||
                                  bodyPart.contains("cardio") ||
                                  (isBodyweight && (bodyPart.contains("shoulder") || bodyPart.contains("hip")))
            
            // Must be suitable for warm-up
            guard isWarmupSuitable else { return false }
            
            // Filter for dynamic/warm-up type stretches
            let isDynamic = exerciseName.contains("dynamic") ||
                           exerciseName.contains("swing") ||
                           exerciseName.contains("circle") ||
                           exerciseName.contains("rotation") ||
                           exerciseName.contains("walk") ||
                           exerciseName.contains("march") ||
                           exerciseName.contains("activation")
            
            // Include general mobility exercises
            let isMobilityPrep = exerciseName.contains("mobility") ||
                                exerciseName.contains("prep") ||
                                exerciseName.contains("warmup") ||
                                exerciseName.contains("warm-up")
            
            return isDynamic || isMobilityPrep
        }
        
        // Prioritize exercises that target the main workout muscles
        let prioritized = prioritizeForTargetMuscles(warmUpExercises, targetMuscles: targetMuscles)
        let selected = Array(prioritized.prefix(count))
        
        // Convert to TodayWorkoutExercise with warm-up specific parameters
        return selected.map { exercise in
            TodayWorkoutExercise(
                exercise: exercise,
                sets: 1,
                reps: 10, // Dynamic warm-up reps
                weight: nil,
                restTime: 30, // Short rest for warm-up
                notes: "Warm-up exercise"
            )
        }
    }
    
    // Get cool-down exercises (static stretches for recovery)
    func getCoolDownExercises(targetMuscles: [String], customEquipment: [Equipment]? = nil, count: Int = 3) -> [TodayWorkoutExercise] {
        let allExercises = ExerciseDatabase.getAllExercises()
        
        // Filter for exercises that are suitable for cool-down
        let coolDownExercises = allExercises.filter { exercise in
            let exerciseType = exercise.exerciseType.lowercased()
            let exerciseName = exercise.name.lowercased()
            let bodyPart = exercise.bodyPart.lowercased()
            
            // Look for bodyweight/mobility exercises suitable for cool-down
            let isBodyweight = exercise.equipment.lowercased().contains("body weight") || exercise.equipment.lowercased().isEmpty
            
            // Look for cool-down suitable exercises by name patterns
            let isCooldownSuitable = exerciseName.contains("stretch") ||
                                    exerciseName.contains("mobility") ||
                                    exerciseName.contains("hold") ||
                                    exerciseName.contains("recovery") ||
                                    (isBodyweight && (exerciseName.contains("calf") || 
                                                     exerciseName.contains("hamstring") ||
                                                     exerciseName.contains("quad") ||
                                                     exerciseName.contains("chest") ||
                                                     exerciseName.contains("back") ||
                                                     bodyPart.contains("waist")))
            
            // Must be suitable for cool-down
            guard isCooldownSuitable else { return false }
            
            // Filter for static/cool-down type stretches (exclude dynamic ones)
            let isStatic = !exerciseName.contains("dynamic") &&
                          !exerciseName.contains("swing") &&
                          !exerciseName.contains("circle") &&
                          !exerciseName.contains("rotation") &&
                          !exerciseName.contains("march")
            
            // Include recovery-focused stretches
            let isRecovery = exerciseName.contains("stretch") ||
                            exerciseName.contains("hold") ||
                            exerciseName.contains("cooldown") ||
                            exerciseName.contains("cool-down") ||
                            exerciseName.contains("recovery")
            
            return isStatic && isRecovery
        }
        
        // Prioritize exercises that target the main workout muscles
        let prioritized = prioritizeForTargetMuscles(coolDownExercises, targetMuscles: targetMuscles)
        let selected = Array(prioritized.prefix(count))
        
        // Convert to TodayWorkoutExercise with cool-down specific parameters
        return selected.map { exercise in
            TodayWorkoutExercise(
                exercise: exercise,
                sets: 1,
                reps: 1, // Hold stretches
                weight: nil,
                restTime: 15, // Short rest for cool-down
                notes: "Hold for 20-30 seconds"
            )
        }
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
        
        return exercises.sorted { exercise1, exercise2 in
            let score1 = getExerciseScore(exercise1, userProfile: userProfile)
            let score2 = getExerciseScore(exercise2, userProfile: userProfile)
            
            // Prioritize based on recovery status
            if recoveryPercentage > 0.7 { // High recovery, prioritize recovery-specific exercises
                return score1 > score2
            } else { // Low recovery, prioritize general fitness/hypertrophy
                return score1 > score2
            }
        }.prefix(maxCount).map { $0 }
    }
    
    private func getExerciseScore(_ exercise: ExerciseData, userProfile: UserProfileService) -> Int {
        var score = 0
        
        // Prefer compound movements for beginners and strength goals
        if getExerciseCategory(exercise) == .compound {
            score += (userProfile.experienceLevel == .beginner) ? 3 : 2
            score += (userProfile.fitnessGoal == .strength || userProfile.fitnessGoal == .powerlifting) ? 2 : 0
        }
        
        // Prefer isolation for hypertrophy goals
        if getExerciseCategory(exercise) == .isolation && userProfile.fitnessGoal == .hypertrophy {
            score += 2
        }
        
        // Boost score for preferred exercise types
        let exerciseType = getExerciseType(exercise)
        if userProfile.preferredExerciseTypes.contains(exerciseType) {
            score += 1
        }
        
        // Consider historical performance (exercises user has done before get slight boost)
        if userProfile.getExercisePerformance(exerciseId: exercise.id) != nil {
            score += 1
        }
        
        return score
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
    
    private func estimateStartingWeight(for exercise: ExerciseData) -> Double? {
        let userProfile = UserProfileService.shared
        let bodyWeight = userProfile.userWeight
        let equipment = exercise.equipment.lowercased()
        
        // Only estimate for weighted exercises
        guard equipment.contains("dumbbell") || equipment.contains("barbell") || equipment.contains("kettlebell") else {
            return nil
        }
        
        let exerciseCategory = getExerciseCategory(exercise)
        let experienceMultiplier = getExperienceMultiplier(userProfile.experienceLevel)
        
        // Base percentages of bodyweight for different exercise categories
        let basePercentage: Double
        switch exerciseCategory {
        case .compound:
            if equipment.contains("barbell") {
                basePercentage = 0.5 // 50% of bodyweight for compound barbell movements
            } else {
                basePercentage = 0.2 // 20% of bodyweight for compound dumbbell movements (per hand)
            }
        case .isolation:
            basePercentage = 0.1 // 10% of bodyweight for isolation movements
        case .core:
            basePercentage = 0.05 // 5% of bodyweight for core exercises
        case .cardio:
            basePercentage = 0.15 // 15% of bodyweight for cardio-strength exercises
        }
        
        return bodyWeight * basePercentage * experienceMultiplier
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
        
        // Compound movements (multi-joint)
        if isCompoundMovement(bodyPart: bodyPart, exerciseType: exerciseType) {
            return .compound
        }
        
        // Isolation movements (single-joint)
        if isIsolationMovement(bodyPart: bodyPart, exerciseType: exerciseType) {
            return .isolation
        }
        
        // Cardio/Aerobic
        if exerciseType == "aerobic" || bodyPart == "cardio" {
            return .cardio
        }
        
        // Core/Abs
        if bodyPart == "waist" || bodyPart.contains("abs") {
            return .core
        }
        
        // Default to isolation
        return .isolation
    }
    
    private func isCompoundMovement(bodyPart: String, exerciseType: String) -> Bool {
        let compoundKeywords = [
            "squat", "deadlift", "bench press", "overhead press", "row", "pull-up", "chin-up",
            "dip", "lunge", "clean", "snatch", "thrust", "burpee"
        ]
        
        return compoundKeywords.contains { keyword in
            bodyPart.contains(keyword) || exerciseType.contains(keyword)
        }
    }
    
    private func isIsolationMovement(bodyPart: String, exerciseType: String) -> Bool {
        let isolationKeywords = [
            "curl", "extension", "raise", "fly", "kickback", "shrug", "crunch", "leg raise"
        ]
        
        return isolationKeywords.contains { keyword in
            bodyPart.contains(keyword) || exerciseType.contains(keyword)
        }
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
}

enum ExerciseCategory {
    case compound
    case isolation
    case core
    case cardio
}