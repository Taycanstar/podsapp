//
//  BlockCreationService.swift
//  Pods
//
//  Created by Codex on 2024-08-31.
//

import Foundation

enum BlockCreationService {
    struct CreationResult {
        let workout: TodayWorkout
        let createdBlock: WorkoutBlock
    }

    enum CreationError: LocalizedError {
        case invalidSelection
        case workoutOutOfRange

        var errorDescription: String? {
            switch self {
            case .invalidSelection:
                return "Select at least two exercises to build a superset or circuit."
            case .workoutOutOfRange:
                return "One or more selected exercises is no longer available."
            }
        }
    }

    static func createBlock(from workout: TodayWorkout, selectedIndices: [Int]) throws -> CreationResult {
        let uniqueIndices = Array(Set(selectedIndices)).sorted()
        guard uniqueIndices.count >= 2 else {
            throw CreationError.invalidSelection
        }
        guard uniqueIndices.allSatisfy({ workout.exercises.indices.contains($0) }) else {
            throw CreationError.workoutOutOfRange
        }

        let blockType: BlockType = uniqueIndices.count >= 3 ? .circuit : .superset
        let restValues = uniqueIndices.map { workout.exercises[$0].restTime }
        let restBetweenExercises = restValues.min()
        let restBetweenRounds = restValues.max()

        let blockExercises: [BlockExercise] = uniqueIndices.map { index in
            let exercise = workout.exercises[index]
            if let tracking = exercise.trackingType,
               tracking == .timeOnly,
               let flexibleSet = exercise.flexibleSets?.first,
               let duration = flexibleSet.duration {
                let scheme = IntervalScheme(workSec: Int(duration), restSec: exercise.restTime)
                return BlockExercise(
                    exercise: exercise.exercise,
                    schemeType: .interval,
                    repScheme: nil,
                    intervalScheme: scheme
                )
            } else {
                let scheme = RepScheme(sets: exercise.sets, reps: exercise.reps, restSec: exercise.restTime)
                return BlockExercise(
                    exercise: exercise.exercise,
                    schemeType: .rep,
                    repScheme: scheme,
                    intervalScheme: nil
                )
            }
        }

        let manualBlock = WorkoutBlock(
            type: blockType,
            exercises: blockExercises,
            rounds: 1,
            restBetweenExercises: restBetweenExercises,
            restBetweenRounds: restBetweenRounds,
            weightNormalization: nil,
            timingConfig: nil
        )

        let existingBlocks = workout.blocks ?? BlocksMigrationHelper.toBlocks(from: workout)
        var processedBlocks: [WorkoutBlock] = []
        var insertionIndex: Int?
        let selectedIndexSet = Set(uniqueIndices)

        var occurrenceMap: [Int: [Int]] = [:]
        for (idx, exercise) in workout.exercises.enumerated() {
            occurrenceMap[exercise.exercise.id, default: []].append(idx)
        }
        var occurrenceCursor: [Int: Int] = [:]

        for block in existingBlocks {
            var filteredExercises: [BlockExercise] = []
            var removedFromBlock = false

            for blockExercise in block.exercises {
                let exerciseId = blockExercise.exercise.id
                let usedCount = occurrenceCursor[exerciseId, default: 0]
                let indices = occurrenceMap[exerciseId] ?? []
                let mappedIndex = usedCount < indices.count ? indices[usedCount] : nil
                occurrenceCursor[exerciseId] = usedCount + 1

                if let mappedIndex, selectedIndexSet.contains(mappedIndex) {
                    removedFromBlock = true
                    continue
                }

                filteredExercises.append(blockExercise)
            }

            if insertionIndex == nil, removedFromBlock {
                insertionIndex = processedBlocks.count
            }

            if !filteredExercises.isEmpty {
                var updatedBlock = block
                updatedBlock.exercises = filteredExercises
                processedBlocks.append(updatedBlock)
            }
        }

        let targetIndex = insertionIndex ?? processedBlocks.count
        processedBlocks.insert(manualBlock, at: targetIndex)

        let updatedWorkout = TodayWorkout(
            id: workout.id,
            date: workout.date,
            title: workout.title,
            exercises: workout.exercises,
            blocks: processedBlocks,
            estimatedDuration: workout.estimatedDuration,
            fitnessGoal: workout.fitnessGoal,
            difficulty: workout.difficulty,
            warmUpExercises: workout.warmUpExercises,
            coolDownExercises: workout.coolDownExercises
        )

        return CreationResult(workout: updatedWorkout, createdBlock: manualBlock)
    }
}
