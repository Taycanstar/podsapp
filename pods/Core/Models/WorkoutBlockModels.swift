//
//  WorkoutBlockModels.swift
//  pods
//
//  Block-based workout data structures for Standard, Superset, and Circuit blocks.
//

import Foundation

// MARK: - Core Block Types

enum BlockType: String, Codable, CaseIterable, Hashable {
    case standard
    case superset
    case circuit
}

enum SchemeType: String, Codable, CaseIterable, Hashable {
    case rep
    case interval
}

enum WeightNormalizationPolicy: String, Codable, CaseIterable, Hashable {
    case none
    case sameDumbbellPair
    case sameKettlebell
    case bodyweightOnly
}

// MARK: - Schemas

struct RepScheme: Codable, Equatable, Hashable {
    var sets: Int
    var reps: Int?
    var rir: Int?          // Reps in Reserve
    var restSec: Int?

    init(sets: Int, reps: Int? = nil, rir: Int? = nil, restSec: Int? = nil) {
        self.sets = sets
        self.reps = reps
        self.rir = rir
        self.restSec = restSec
    }
}

struct IntervalScheme: Codable, Equatable, Hashable {
    var workSec: Int
    var restSec: Int
    var targetReps: Int?

    init(workSec: Int, restSec: Int, targetReps: Int? = nil) {
        self.workSec = workSec
        self.restSec = restSec
        self.targetReps = targetReps
    }
}

struct TimingConfig: Codable, Equatable, Hashable {
    var prepareSec: Int?
    var transitionSec: Int?
    var autoAdvance: Bool?
}

// MARK: - Block Structures

struct BlockExercise: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let exercise: ExerciseData
    let schemeType: SchemeType
    let repScheme: RepScheme?
    let intervalScheme: IntervalScheme?

    init(
        id: UUID = UUID(),
        exercise: ExerciseData,
        schemeType: SchemeType,
        repScheme: RepScheme? = nil,
        intervalScheme: IntervalScheme? = nil
    ) {
        self.id = id
        self.exercise = exercise
        self.schemeType = schemeType
        self.repScheme = repScheme
        self.intervalScheme = intervalScheme
    }
}

struct WorkoutBlock: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let type: BlockType
    var exercises: [BlockExercise]
    var rounds: Int
    var restBetweenExercises: Int?
    var restBetweenRounds: Int?
    var weightNormalization: WeightNormalizationPolicy?
    var timingConfig: TimingConfig?

    init(
        id: UUID = UUID(),
        type: BlockType,
        exercises: [BlockExercise],
        rounds: Int = 1,
        restBetweenExercises: Int? = nil,
        restBetweenRounds: Int? = nil,
        weightNormalization: WeightNormalizationPolicy? = nil,
        timingConfig: TimingConfig? = nil
    ) {
        self.id = id
        self.type = type
        self.exercises = exercises
        self.rounds = rounds
        self.restBetweenExercises = restBetweenExercises
        self.restBetweenRounds = restBetweenRounds
        self.weightNormalization = weightNormalization
        self.timingConfig = timingConfig
    }
}

// MARK: - Migration Helper (Legacy → Blocks)

struct BlocksMigrationHelper {
    /// Convert a legacy TodayWorkout into a single standard block workout
    static func toBlocks(from legacy: TodayWorkout) -> [WorkoutBlock] {
        let blockExercises: [BlockExercise] = legacy.exercises.enumerated().map { (idx, twEx) in
            let repScheme = RepScheme(sets: twEx.sets, reps: twEx.reps, rir: nil, restSec: twEx.restTime)
            return BlockExercise(
                exercise: twEx.exercise,
                schemeType: .rep,
                repScheme: repScheme,
                intervalScheme: nil
            )
        }

        return [WorkoutBlock(
            type: .standard,
            exercises: blockExercises,
            rounds: 1,
            restBetweenExercises: nil,
            restBetweenRounds: nil,
            weightNormalization: nil,
            timingConfig: nil
        )]
    }
}

// MARK: - TodayWorkout convenience

extension TodayWorkout {
    /// Unified access: always return a block-based representation.
    /// If the server didn’t provide `blocks`, synthesize a single Standard block from legacy `exercises`.
    var blockProgram: [WorkoutBlock] {
        if let blocks { return blocks }
        return BlocksMigrationHelper.toBlocks(from: self)
    }
}
