//
//  WorkoutPlanValidator.swift
//  pods
//
//  Created by Dimi Nunez on 11/4/25.
//


//
//  WorkoutPlanValidator.swift
//

import Foundation

struct WorkoutPlanValidator {
    func validate(
        response: NetworkManagerTwo.LLMWorkoutResponse,
        candidateIds: Set<Int>,
        requestedMuscles: [String],
        fitnessGoal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        sessionBudget: TimeEstimator.SessionTimeBudget?
    ) -> [String] {
        var warnings: [String] = []

        let ids = response.exercises.map(\.exerciseId)
        if Set(ids).count != ids.count {
            warnings.append("LLM returned duplicate exercise ids")
        }

        let unknown = ids.filter { !candidateIds.contains($0) }
        if !unknown.isEmpty {
            warnings.append("LLM referenced exercises outside candidate pool: \(unknown.prefix(5))")
        }

        for exercise in response.exercises {
            if exercise.sets <= 0 || exercise.reps <= 0 {
                warnings.append("Non-positive prescription detected for \(exercise.exerciseId)")
                break
            }
        }

        if !requestedMuscles.isEmpty {
            let coverage = Set(response.exercises.map { $0.muscleGroup })
            let missing = requestedMuscles.filter { !coverage.contains($0) }
            if !missing.isEmpty {
                let musclesList = missing.joined(separator: ", ")
                warnings.append("Missing requested muscle coverage for \(musclesList)")
            }
        }

        if let budget = sessionBudget {
            let estimator = TimeEstimator.shared
            let averageSeconds = estimator.averageExerciseSeconds(
                goal: fitnessGoal,
                experienceLevel: experienceLevel,
                format: budget.format
            )
            let estimatedSeconds = Int((Double(response.exercises.count) * averageSeconds).rounded())

            if estimatedSeconds > budget.maxWorkSeconds {
                warnings.append("Estimated session length (~\(estimatedSeconds / 60)m) exceeds budgeted work time of \(budget.maxWorkSeconds / 60)m")
            } else if estimatedSeconds < Int(Double(budget.availableWorkSeconds) * 0.5) {
                warnings.append("Plan may underutilize available time (uses ~\(max(1, estimatedSeconds / 60))m of \(max(1, budget.availableWorkSeconds / 60))m budget)")
            }
        }

        return warnings
    }
}
