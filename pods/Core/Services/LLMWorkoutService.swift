//
//  LLMWorkoutService.swift
//  pods
//
//  Created by Dimi Nunez on 11/4/25.
//


//
//  LLMWorkoutService.swift
//

import Foundation

final class LLMWorkoutService {
    static let shared = LLMWorkoutService()

    private let network = NetworkManagerTwo.shared
    private let validator = WorkoutPlanValidator()

    private init() {}

    func generatePlanSync(
        userEmail: String,
        context: WorkoutContextV1,
        candidates: [NetworkManagerTwo.LLMCandidateExercise],
        targetExerciseCount: Int,
        fitnessGoal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        sessionBudget: TimeEstimator.SessionTimeBudget
    ) throws -> (NetworkManagerTwo.LLMWorkoutResponse, [String]) {
        let request = NetworkManagerTwo.LLMWorkoutRequest(
            userEmail: userEmail,
            context: context.trimmingHistory(maxSessions: 12),
            candidates: candidates,
            targetExerciseCount: targetExerciseCount,
            sessionBudget: buildBudgetPayload(from: sessionBudget),
            requestId: UUID()
        )

        WorkoutGenerationTelemetry.record(.llmRequestStarted, metadata: [
            "exerciseCount": targetExerciseCount,
            "candidatePool": candidates.count
        ])

        var result: Result<NetworkManagerTwo.LLMWorkoutResponse, Error>?
        let semaphore = DispatchSemaphore(value: 0)

        network.generateLLMWorkoutPlan(request: request) { response in
            result = response
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + .seconds(45))
        guard waitResult == .success else {
            throw WorkoutGenerationError.generationFailed("LLM generation timed out")
        }

        let payload = try result!.get()
        let warnings = validator.validate(
            response: payload,
            candidateIds: Set(candidates.map(\.exerciseId)),
            requestedMuscles: context.constraints.requestedMuscles,
            fitnessGoal: fitnessGoal,
            experienceLevel: experienceLevel,
            sessionBudget: sessionBudget
        )

        WorkoutGenerationTelemetry.record(.llmRequestFinished, metadata: [
            "exercises": payload.exercises.count,
            "warnings": warnings.count
        ])

        return (payload, warnings)
    }

    private func buildBudgetPayload(from budget: TimeEstimator.SessionTimeBudget) -> NetworkManagerTwo.LLMSessionBudget {
        let densityHint: String
        switch budget.format {
        case .straightSets:
            densityHint = "straight sets • full rest between efforts"
        case .superset:
            densityHint = "superset • pair movements, ~37% rest compression"
        case .circuit3:
            densityHint = "circuit of 3 exercises • ~35% rest compression"
        case .circuit4:
            densityHint = "circuit of 4 exercises • ~30% rest compression"
        case .emom:
            densityHint = "EMOM • intervals with ~25% rest compression"
        }

        return NetworkManagerTwo.LLMSessionBudget(
            format: budget.format.rawValue,
            densityHint: densityHint,
            durationMinutes: budget.duration.minutes,
            availableWorkSeconds: budget.availableWorkSeconds,
            maxWorkSeconds: budget.maxWorkSeconds,
            warmupSeconds: budget.warmupSeconds,
            cooldownSeconds: budget.cooldownSeconds,
            bufferSeconds: budget.bufferSeconds
        )
    }
}
