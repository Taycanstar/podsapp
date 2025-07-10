// FILE: Services/WorkoutRecommendationService.swift
import Foundation

class WorkoutRecommendationService {
    static let shared = WorkoutRecommendationService()
    
    private init() {}
    
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