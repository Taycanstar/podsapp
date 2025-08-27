// FILE: Services/WorkoutRecommendationService.swift
import Foundation

class WorkoutRecommendationService {
    static let shared = WorkoutRecommendationService()
    
    private init() {}
    
    // Enhanced recommendation system using user profile and Perplexity algorithm
    func getSmartRecommendation(for exercise: ExerciseData, fitnessGoal: FitnessGoal? = nil) -> (sets: Int, reps: Int, weight: Double?) {
        let userProfile = UserProfileService.shared
        
        // Use passed fitness goal (for session overrides) or fall back to user's default
        let goalToUse = fitnessGoal ?? userProfile.fitnessGoal
        
        // Get recommendation using Perplexity algorithm (experience level handled internally)
        let baseRecommendation = getDefaultSetsAndReps(for: exercise, fitnessGoal: goalToUse)
        
        // Check for historical performance and progressive overload
        let smartWeight = getSmartWeight(for: exercise, baseWeight: baseRecommendation.weight)
        
        return (
            sets: baseRecommendation.sets,
            reps: baseRecommendation.reps,
            weight: smartWeight
        )
    }
    
    // Default sets and reps using Perplexity algorithm with individual factors
    func getDefaultSetsAndReps(for exercise: ExerciseData, fitnessGoal: FitnessGoal) -> (sets: Int, reps: Int, weight: Double?) {
        let userProfile = UserProfileService.shared
        let exerciseCategory = getExerciseCategory(exercise)
        
        print("🧮 === Perplexity Algorithm Inputs ===")
        print("🧮 Exercise: \(exercise.name)")
        print("🧮 Fitness Goal: \(fitnessGoal)")
        print("🧮 Experience Level: \(userProfile.experienceLevel)")
        print("🧮 Gender: \(userProfile.gender)")
        print("🧮 Exercise Category: \(exerciseCategory)")
        
        // Use Perplexity algorithm for sets and reps
        let (sets, reps, _, _) = getGoalParameters(
            fitnessGoal,
            experienceLevel: userProfile.experienceLevel,
            gender: userProfile.gender,
            exerciseType: exerciseCategory
        )
        
        print("🧮 Final Result: \(sets)x\(reps)")
        print("🧮 === End Perplexity Algorithm ===")
        
        return (sets: sets, reps: reps, weight: nil)
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
        let sortedExercises = prioritizeExercises(filteredExercises, recoveryPercentage: recoveryPercentage, maxCount: count)
        return Array(sortedExercises.prefix(count))
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
        let sortedExercises = prioritizeExercises(filteredExercises, recoveryPercentage: recoveryPercentage, maxCount: count)
        return Array(sortedExercises.prefix(count))
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
        
        // Let the caller handle truncation to avoid double truncation bug
        return sortedExercises
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
        let exerciseName = exercise.name.lowercased()
        
        print("🧮 Classifying exercise: \(exercise.name) | bodyPart: \(bodyPart) | exerciseType: \(exerciseType)")
        
        // Core/Abs first (most specific)
        if bodyPart == "waist" || bodyPart.contains("abs") || exerciseName.contains("crunch") || exerciseName.contains("plank") {
            print("🧮 → Classified as CORE")
            return .core
        }
        
        // Cardio/Aerobic
        if exerciseType == "aerobic" || bodyPart == "cardio" || exerciseName.contains("treadmill") {
            print("🧮 → Classified as CARDIO")
            return .cardio
        }
        
        // Compound movements (multi-joint) - enhanced detection
        if isCompoundMovement(exercise) {
            print("🧮 → Classified as COMPOUND")
            return .compound
        }
        
        // Isolation movements (single-joint) - enhanced detection
        if isIsolationMovement(exercise) {
            print("🧮 → Classified as ISOLATION")
            return .isolation
        }
        
        // Default to isolation for safety
        print("🧮 → Defaulted to ISOLATION")
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
            "dip", "lunge", "clean", "snatch", "thrust", "burpee", "push-up", "pushup"
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
            "tricep", "bicep", "lateral", "reverse", "hammer", "concentration"
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
        equipment: [Equipment]? = nil
    ) -> (total: Int, perMuscle: Int) {
        let durationMinutes = duration.minutes
        let timeComponents = calculateTimeComponents(
            fitnessGoal: fitnessGoal,
            experienceLevel: experienceLevel,
            equipment: equipment
        )
        
        // Calculate available exercise time with research-based warmup/cooldown
        let warmupMinutes = getOptimalWarmupDuration(durationMinutes)
        let cooldownMinutes = warmupMinutes
        let bufferMinutes = Int(Double(durationMinutes) * 0.03) // Single 3% buffer (no double buffering)
        let availableMinutes = durationMinutes - warmupMinutes - cooldownMinutes - bufferMinutes
        
        // Direct calculation using research-based time per exercise
        let exercisesTotal = Int(Double(availableMinutes) / timeComponents.averageMinutesPerExercise)
        
        // Apply research-based constraints (no arbitrary limits)
        let (minExercises, maxExercises) = getExerciseCountBounds(
            fitnessGoal: fitnessGoal,
            durationMinutes: durationMinutes
        )
        
        let finalTotal = min(maxExercises, max(minExercises, exercisesTotal))
        
        print("🔍 Exercise calculation: \(availableMinutes)min available, \(String(format: "%.1f", timeComponents.averageMinutesPerExercise))min per exercise = \(exercisesTotal) calculated, bounds=(\(minExercises),\(maxExercises)), final=\(finalTotal)")
        
        // Smart distribution: respect time budget over muscle group fairness
        let (actualTotal, finalPerMuscle): (Int, Int)
        if finalTotal < muscleGroupCount {
            // Very short workout: some muscle groups get 0 exercises
            actualTotal = finalTotal // Use all available exercise slots
            finalPerMuscle = 1 // 1 per selected muscle group
        } else {
            // Normal workout: respect the time budget calculation
            let exercisesPerMuscle = finalTotal / muscleGroupCount
            let remainder = finalTotal % muscleGroupCount
            let perMuscle = max(1, min(4, exercisesPerMuscle))
            // CRITICAL FIX: Always use the full finalTotal, never reduce it
            actualTotal = finalTotal // Respect time budget calculation
            finalPerMuscle = perMuscle // Base exercises per muscle
        }
        
        print("🎯 Research-based calculation: \(availableMinutes)min available, \(String(format: "%.1f", timeComponents.averageMinutesPerExercise))min per exercise = \(actualTotal) total, \(finalPerMuscle) per muscle")
        
        return (total: actualTotal, perMuscle: finalPerMuscle)
    }
    
    /// Calculate time components for exercise planning using Perplexity algorithm
    private func calculateTimeComponents(
        fitnessGoal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        equipment: [Equipment]? = nil
    ) -> (averageMinutesPerExercise: Double, restSeconds: Int, setupSeconds: Int) {
        let userProfile = UserProfileService.shared
        
        // Use average exercise type for time estimation (compound exercises are most common)
        let averageExerciseType = ExerciseCategory.compound
        
        // Get parameters using Perplexity algorithm
        let (sets, reps, restBase, repDuration) = getGoalParameters(
            fitnessGoal,
            experienceLevel: experienceLevel,
            gender: userProfile.gender, 
            exerciseType: averageExerciseType
        )
        
        // Experience level adjustments are now handled in the algorithm
        let adjustedRest = restBase
        
        // Equipment-based time multipliers from research
        let equipmentFactor = calculateEquipmentFactor(equipment)
        
        // Setup time based on equipment complexity
        let setupTime = equipmentFactor > 1.1 ? 25 : 
                       equipmentFactor < 0.9 ? 5 : 15
        
        // Calculate total time per exercise using Perplexity research formulas
        let workingTime = Double(sets * reps * repDuration) / 60.0
        let restTime = Double((sets - 1) * adjustedRest) / 60.0
        let setupMinutes = Double(setupTime + 15) / 60.0 // Include transition time
        
        let totalMinutes = (workingTime + restTime + setupMinutes) * equipmentFactor
        
        return (
            averageMinutesPerExercise: totalMinutes,
            restSeconds: adjustedRest,
            setupSeconds: setupTime
        )
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
        
        print("🧮 Algorithm: \(baseReps) + \(experienceModifier) + \(genderModifier) + \(exerciseTypeModifier) = \(calculatedReps) → mapped to standard: \(finalReps)")
    
        
        // Sets by goal (Exercise science validated)
        let sets = getSetsForGoal(fitnessGoal, exerciseType: exerciseType)
        print("🧮 Final recommendation: \(sets)×\(finalReps) (exercise science validated)")
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
        print("🧮 Base reps for \(goal): \(base)")
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
        print("🧮 Experience modifier for \(experience): \(modifier)")
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
        print("🧮 Gender modifier for \(gender): \(modifier)")
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
        print("🧮 Exercise type modifier for \(exerciseType): \(modifier)")
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
            print("🧮 Standard rep mapping: \(reps) → \(mappedReps) (goal: \(fitnessGoal), type: \(exerciseType))")
        }
        
        return mappedReps
    }
    
    /// Get optimal warmup duration based on workout length research
    private func getOptimalWarmupDuration(_ workoutMinutes: Int) -> Int {
        switch workoutMinutes {
        case 0..<30: return 3  // 10% of short workouts
        case 30..<45: return 5  // Balanced for medium workouts
        case 45..<60: return 6  // Optimal for 45-60min sessions
        case 60..<90: return 7  // Longer warmup for extended sessions
        default: return 10      // Full warmup for long sessions
        }
    }
    
    /// Get research-based exercise count bounds for fitness goals
    private func getExerciseCountBounds(
        fitnessGoal: FitnessGoal,
        durationMinutes: Int
    ) -> (min: Int, max: Int) {
        let scaleFactor = Double(durationMinutes) / 60.0
        
        switch fitnessGoal {
        case .strength, .powerlifting:
            // Fewer exercises, longer rest periods required
            return (
                min: Int(4 * scaleFactor),
                max: Int(8 * scaleFactor)
            )
        case .hypertrophy:
            // Moderate volume for muscle growth
            return (
                min: Int(5 * scaleFactor),
                max: Int(10 * scaleFactor)
            )
        case .endurance:
            // Higher exercise count, shorter rest
            return (
                min: Int(8 * scaleFactor),
                max: Int(15 * scaleFactor)
            )
        default:
            // General fitness balanced approach
            return (
                min: Int(4 * scaleFactor),
                max: Int(10 * scaleFactor)
            )
        }
    }
    
    /// Calculate equipment factor for time estimation based on research
    private func calculateEquipmentFactor(_ equipment: [Equipment]?) -> Double {
        guard let equipment = equipment, !equipment.isEmpty else { return 1.0 }
        
        var factor = 0.0
        var count = 0
        
        for equip in equipment {
            count += 1
            switch equip {
            case .barbells:
                factor += 1.2  // Plate loading time
            case .dumbbells:
                factor += 1.0  // Baseline
            case .cable, .legPress, .latPulldownCable:
                factor += 1.1  // Pin adjustments
            case .bodyWeight:
                factor += 0.8  // No setup required
            default:
                factor += 1.0
            }
        }
        
        return count > 0 ? factor / Double(count) : 1.0
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
        // First get standard recommendations using existing sophisticated logic
        var exercises = getRecommendedExercises(
            for: muscleGroup,
            count: count * 2, // Get extra to filter optimally
            customEquipment: customEquipment,
            flexibilityPreferences: flexibilityPreferences
        )
        
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
