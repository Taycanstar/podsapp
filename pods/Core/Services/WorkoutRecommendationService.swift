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
        let allExercises = ExerciseDatabase.getAllExercises()
        
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
        
        // Prioritize exercises based on user preferences and experience
        let prioritizedExercises = prioritizeExercises(filteredExercises)
        
        return Array(prioritizedExercises.prefix(count))
    }
    
    private func prioritizeExercises(_ exercises: [ExerciseData]) -> [ExerciseData] {
        let userProfile = UserProfileService.shared
        
        return exercises.sorted { exercise1, exercise2 in
            let score1 = getExerciseScore(exercise1, userProfile: userProfile)
            let score2 = getExerciseScore(exercise2, userProfile: userProfile)
            return score1 > score2
        }
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