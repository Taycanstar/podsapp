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
        targetExerciseCount: Int
    ) throws -> (NetworkManagerTwo.LLMWorkoutResponse, [String]) {
        let request = NetworkManagerTwo.LLMWorkoutRequest(
            userEmail: userEmail,
            context: context.trimmingHistory(maxSessions: 12),
            candidates: candidates,
            targetExerciseCount: targetExerciseCount,
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
            requestedMuscles: context.constraints.requestedMuscles
        )

        WorkoutGenerationTelemetry.record(.llmRequestFinished, metadata: [
            "exercises": payload.exercises.count,
            "warnings": warnings.count
        ])

        return (payload, warnings)
    }
}
