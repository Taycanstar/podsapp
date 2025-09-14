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
    
    // MARK: - Muscle Group Mapping (copied from AddExerciseView.swift)
    
    // Mapping from display names to actual database bodyPart values
    private func getDatabaseBodyPart(for displayMuscle: String) -> [String] {
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
    private func exerciseMatchesMuscle(_ exercise: ExerciseData, muscleGroup: String) -> Bool {
        let targetBodyParts = getDatabaseBodyPart(for: muscleGroup)
        
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
        
        print("🎯 Smart muscle filtering for '\(muscleGroup)': Found \(muscleExercises.count) exercises out of \(allExercises.count) total")
        
        // PROGRESSIVE EXERCISE SELECTION: Different exercise pools for different levels
        let experienceAppropriate = getExperienceTailoredExercises(muscleExercises, userProfile: userProfile)
        
        print("🎓 Progressive Selection for \(userProfile.experienceLevel): \(muscleExercises.count) → \(experienceAppropriate.count) exercises")
        
        // Filter by available equipment
        let availableExercises = experienceAppropriate.filter { exercise in
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
        
        print("🎯 Smart muscle filtering for '\(muscleGroup)': Found \(muscleExercises.count) exercises out of \(allExercises.count) total")
        
        // PROGRESSIVE EXERCISE SELECTION: Different exercise pools for different levels
        let experienceAppropriate = getExperienceTailoredExercises(muscleExercises, userProfile: userProfile)
        
        print("🎓 Progressive Selection for \(userProfile.experienceLevel): \(muscleExercises.count) → \(experienceAppropriate.count) exercises")
        
        // Filter by exercise type (exclude stretching for strength workouts by default)
        let typeFilteredExercises = filterByExerciseType(exercises: experienceAppropriate, flexibilityPreferences: flexibilityPreferences, muscleGroup: muscleGroup)
        
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
        
        // Let the caller handle truncation to avoid double truncation bug
        return sortedExercises
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
        
        // DEBUG: Show the evidence-based scoring breakdown
        print("🎯 EVIDENCE-BASED SCORING: \(exercise.name)")
        print("   └── Experience: \(userProfile.experienceLevel) | Goal: \(userProfile.fitnessGoal) | Complexity: L\(complexity)")
        print("   └── Progression: \(progressionScore) × 4 = \(progressionScore * 4)")
        print("   └── Quality: \(qualityScore) × 3 = \(qualityScore * 3)")
        print("   └── Goal: \(goalScore) × 2 = \(goalScore * 2)")
        print("   └── EquipmentPref: \(equipmentPref) × 2 = \(equipmentPref * 2)")
        print("   └── Preference: \(preferenceScore) × 1 = \(preferenceScore)")
        print("   └── TOTAL SCORE: \(score) 🎯")
        
        return score
    }

    // MARK: - Goal × Equipment weighting (prevents bodyweight dominance for hypertrophy/strength when weights exist)
    private func getEquipmentPreferenceScore(_ exercise: ExerciseData, userProfile: UserProfileService) -> Int {
        let goal = userProfile.fitnessGoal.normalized
        let equip = exercise.equipment.lowercased()
        let hasBarbell = userProfile.availableEquipment.contains(.barbells)
        let hasDumbbell = userProfile.availableEquipment.contains(.dumbbells)
        let hasCable = userProfile.availableEquipment.contains(.cable) || userProfile.availableEquipment.contains(.latPulldownCable)
        let hasMachines = userProfile.availableEquipment.contains(.hammerstrengthMachine) || userProfile.availableEquipment.contains(.legPress) || userProfile.availableEquipment.contains(.smithMachine)
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
            if isBodyweight() && hasWeightedOptions { return -2 }
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
        
        print("🎯 Movement Quality Analysis: L\(complexity) exercise for \(experience) → Quality Score: \(qualityScore)/5")
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
        enum MovementPattern { case squat, press, pull, explosive, isolation, unilateral }
        func classifyMovement(_ e: ExerciseData) -> MovementPattern {
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
        func equipmentBase(_ e: ExerciseData, mp: MovementPattern) -> Double {
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
        func experienceMultiplier(_ mp: MovementPattern) -> Double {
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
        func applyMinimums(_ weight: Double, eq: String, mp: MovementPattern) -> Double {
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
