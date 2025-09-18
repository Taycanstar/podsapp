//
//  BlockAssemblyService.swift
//  pods
//
//  Minimal dynamic modality selector + block assembler.
//  Uses existing session knobs (goal, duration, equipment) and recent history
//  to assemble Standard, Superset, Circuit, and Interval blocks.
//

import Foundation

struct ModalityWeights {
    var standard: Double
    var superset: Double
    var circuit: Double

    func normalized() -> ModalityWeights {
        let sum = standard + superset + circuit
        guard sum > 0 else { return ModalityWeights(standard: 1, superset: 0, circuit: 0) }
        return ModalityWeights(
            standard: standard / sum,
            superset: superset / sum,
            circuit: circuit / sum
        )
    }

    func asDict() -> [BlockType: Double] {
        [
            .standard: standard,
            .superset: superset,
            .circuit: circuit
        ]
    }
}

enum BlockAssemblyService {
    // MARK: - Public Entrypoint
    static func assembleBlocks(
        from workout: TodayWorkout,
        goal: FitnessGoal,
        duration: WorkoutDuration,
        equipment: [Equipment]?,
        recentHistory: [BlockType]
    ) -> [WorkoutBlock] {
        // User preference gates (backward-compatible defaults)
        let profile = UserProfileService.shared
        let groupingEnabled = profile.autoGroupingEnabled
        let baseWeights = baselineWeights(for: goal)
        let weighted = adjustedWeights(baseWeights, duration: duration, equipment: equipment, recentHistory: recentHistory, goal: goal)

        // Decide an ordered plan of block types for this workout length
        let mainExercises = workout.exercises
        var remaining = Array(mainExercises.indices)
        var blocks: [WorkoutBlock] = []

        // If very short sessions, only CircuitTraining gets auto circuit/interval
        if mainExercises.count <= 3 {
            if groupingEnabled && goal.normalized == .circuitTraining, let circuit = makeCircuit(from: mainExercises, pickingFrom: &remaining, duration: duration) {
                blocks.append(circuit)
            }
            // Any leftovers become standard
            if !remaining.isEmpty, let std = makeStandard(from: mainExercises, pickingFrom: &remaining) { blocks.append(std) }
            return blocks
        }

        // Greedy sampling by weights until we assign all exercises (with conservative caps)
        var supersetCount = 0
        var circuitCount = 0
        let (supersetCap, circuitCap) = caps(for: goal)
        while !remaining.isEmpty {
            guard var nextType = sample(by: weighted) else { break }
            if nextType == .circuit && (!groupingEnabled || !circuitsAllowed(for: goal)) { nextType = .standard }
            if nextType == .superset && (!groupingEnabled) { nextType = .standard }
            if nextType == .superset && supersetCount >= supersetCap { nextType = .standard }
            if nextType == .circuit && circuitCount >= circuitCap { nextType = .standard }
            switch nextType {
            case .circuit:
                if let circuit = makeCircuit(from: mainExercises, pickingFrom: &remaining, duration: duration) {
                    blocks.append(circuit)
                    circuitCount += 1
                }
            case .superset:
                if let ss = makeSuperset(from: mainExercises, pickingFrom: &remaining) {
                    blocks.append(ss)
                    supersetCount += 1
                }
            case .standard:
                if let std = makeStandard(from: mainExercises, pickingFrom: &remaining) {
                    blocks.append(std)
                }
            }
            // Safety: Avoid runaway loops
            if blocks.count > 10 { break }
        }

        // Always ensure we have at least one block
        if blocks.isEmpty, let std = makeStandard(from: mainExercises, pickingFrom: &remaining) {
            blocks.append(std)
        }
        return blocks
    }

    /// Adapt base TodayWorkoutExercise list to reflect interval/circuit prescriptions
    /// so existing exercise-based UI can display time-based sets.
    static func applyBlockSchemes(
        to baseExercises: [TodayWorkoutExercise],
        using blocks: [WorkoutBlock]
    ) -> [TodayWorkoutExercise] {
        // Build a mapping of exerciseId -> (trackingType, flexibleSets)
        var intervalPlan: [Int: (ExerciseTrackingType, [FlexibleSetData])] = [:]

        for block in blocks {
            switch block.type {
            case .circuit:
                // Each exercise gets time-only sets equal to rounds
                let rounds = max(1, block.rounds)
                for bex in block.exercises {
                    guard let scheme = bex.intervalScheme else { continue }
                    var sets: [FlexibleSetData] = []
                    sets.reserveCapacity(rounds)
                    for _ in 0..<rounds {
                        var fs = FlexibleSetData(trackingType: .timeOnly)
                        fs.duration = TimeInterval(scheme.workSec)
                        sets.append(fs)
                    }
                    intervalPlan[bex.exercise.id] = (.timeOnly, sets)
                }

            case .superset, .standard:
                // Leave reps/sets as-is for legacy UI
                continue
            }
        }

        // Apply interval plans onto the base exercises
        var updated: [TodayWorkoutExercise] = []
        updated.reserveCapacity(baseExercises.count)
        for ex in baseExercises {
            if let (tracking, sets) = intervalPlan[ex.exercise.id] {
                let modified = TodayWorkoutExercise(
                    exercise: ex.exercise,
                    sets: sets.count,
                    reps: ex.reps,
                    weight: ex.weight,
                    restTime: ex.restTime,
                    notes: ex.notes,
                    warmupSets: ex.warmupSets,
                    flexibleSets: sets,
                    trackingType: tracking
                )
                updated.append(modified)
            } else {
                updated.append(ex)
            }
        }
        return updated
    }

    // MARK: - Baseline + Adjustments
    private static func baselineWeights(for goal: FitnessGoal) -> ModalityWeights {
        switch goal.normalized {
        case .strength, .powerlifting:
            return ModalityWeights(standard: 0.9, superset: 0.1, circuit: 0.0)
        case .hypertrophy:
            return ModalityWeights(standard: 0.88, superset: 0.12, circuit: 0.0)
        case .circuitTraining:
            return ModalityWeights(standard: 0.25, superset: 0.0, circuit: 0.75)
        case .general:
            return ModalityWeights(standard: 0.9, superset: 0.1, circuit: 0.0)
        case .olympicWeightlifting:
            return ModalityWeights(standard: 0.95, superset: 0.05, circuit: 0.0)
        default:
            return ModalityWeights(standard: 0.9, superset: 0.1, circuit: 0.0)
        }
    }

    private static func adjustedWeights(
        _ base: ModalityWeights,
        duration: WorkoutDuration,
        equipment: [Equipment]?,
        recentHistory: [BlockType],
        goal: FitnessGoal
    ) -> [BlockType: Double] {
        var w = base
        let profile = UserProfileService.shared
        let groupingEnabled = profile.autoGroupingEnabled

        // Time bias: remain conservative for short sessions
        if duration.minutes <= 30 {
            w.circuit *= 1.1
            w.standard *= 0.95
        } else if duration.minutes >= 75 {
            w.circuit *= 0.85
            w.standard *= 1.1
        }

        // Equipment constraints: limited equipment favors circuits
        if let eq = equipment, !eq.isEmpty {
            let hasBarbell = eq.contains(.barbells)
            if !hasBarbell { w.circuit *= 1.1 }
        } else {
            // No declared equipment: err toward bodyweight circuits
            w.circuit *= 1.15
        }

        // History modifier: if no circuit in last 3 sessions, bump circuit ONLY for circuit goal; if many circuits, bump standard
        let recent = Array(recentHistory.suffix(3))
        let hadCircuitRecently = recent.contains(.circuit)
        let circuitCount = recent.filter { $0 == .circuit }.count
        if goal.normalized == .circuitTraining && !hadCircuitRecently { w.circuit *= 1.15 }
        if circuitCount >= 2 { w.standard *= 1.1; w.circuit *= 0.9 }

        // Inject mild noise for variability
        w.standard *= Double.random(in: 0.9...1.1)
        w.superset *= Double.random(in: 0.9...1.1)
        w.circuit *= Double.random(in: 0.9...1.1)

        // Normalize and enforce tiny minimums to avoid zeroing out variety (but 0 for disallowed types below)
        var dict = w.normalized().asDict()
        for key in dict.keys { dict[key] = max(dict[key]!, 0.01) }
        // User preference gates override
        if !groupingEnabled {
            dict[.superset] = 0.0
            dict[.circuit] = 0.0
        }
        // Hard clamp disallowed modalities by goal
        if !circuitsAllowed(for: goal) { dict[.circuit] = 0.0 }
        // Re-normalize after clamping
        let sum = dict.values.reduce(0, +)
        if sum > 0 {
            for key in dict.keys { dict[key] = dict[key]! / sum }
        }
        return dict
    }

    private static func sample(by weights: [BlockType: Double]) -> BlockType? {
        let keys = Array(weights.keys)
        let vals = keys.map { weights[$0] ?? 0 }
        let total = vals.reduce(0, +)
        guard total > 0 else { return nil }
        let r = Double.random(in: 0..<total)
        var acc: Double = 0
        for (i, k) in keys.enumerated() {
            acc += vals[i]
            if r <= acc { return k }
        }
        return keys.last
    }

    // MARK: - Block Builders
    private static func makeStandard(from list: [TodayWorkoutExercise], pickingFrom remaining: inout [Int]) -> WorkoutBlock? {
        guard let idx = remaining.first else { return nil }
        remaining.removeFirst()
        let ex = list[idx]
        let bex = BlockExercise(
            exercise: ex.exercise,
            schemeType: .rep,
            repScheme: RepScheme(sets: ex.sets, reps: ex.reps, rir: nil, restSec: ex.restTime),
            intervalScheme: nil
        )
        return WorkoutBlock(
            type: .standard,
            exercises: [bex],
            rounds: 1,
            restBetweenExercises: nil,
            restBetweenRounds: nil,
            weightNormalization: nil,
            timingConfig: nil
        )
    }

    private static func makeSuperset(from list: [TodayWorkoutExercise], pickingFrom remaining: inout [Int]) -> WorkoutBlock? {
        guard remaining.count >= 2 else { return nil }
        // Find first safe pair (compatible equipment, avoid big compounds)
        var pair: (Int, Int)? = nil
        outer: for i in 0..<(remaining.count - 1) {
            for j in (i+1)..<remaining.count {
                let a = list[remaining[i]].exercise
                let b = list[remaining[j]].exercise
                if isSupersetSafe(a, b) {
                    pair = (remaining[i], remaining[j])
                    break outer
                }
            }
        }
        guard let (aIdx, bIdx) = pair else { return nil }
        // Remove chosen indices from remaining by value
        remaining.removeAll { $0 == aIdx || $0 == bIdx }
        let a = list[aIdx]
        let b = list[bIdx]
        let aBE = BlockExercise(
            exercise: a.exercise,
            schemeType: .rep,
            repScheme: RepScheme(sets: a.sets, reps: a.reps, rir: nil, restSec: nil),
            intervalScheme: nil
        )
        let bBE = BlockExercise(
            exercise: b.exercise,
            schemeType: .rep,
            repScheme: RepScheme(sets: b.sets, reps: b.reps, rir: nil, restSec: nil),
            intervalScheme: nil
        )
        return WorkoutBlock(
            type: .superset,
            exercises: [aBE, bBE],
            rounds: min(a.sets, b.sets),
            restBetweenExercises: 15,
            restBetweenRounds: 60,
            weightNormalization: nil,
            timingConfig: nil
        )
    }

    private static func makeCircuit(from list: [TodayWorkoutExercise], pickingFrom remaining: inout [Int], duration: WorkoutDuration) -> WorkoutBlock? {
        // Choose 3–5 circuit-friendly exercises
        var chosen: [Int] = []
        let maxCount = min(5, remaining.count)
        let targetCount = max(3, min(maxCount, 4))
        // Greedily select safe exercises
        for idx in remaining where chosen.count < targetCount {
            let ex = list[idx]
            if isCircuitSafe(ex.exercise) { chosen.append(idx) }
        }
        guard !chosen.isEmpty else { return nil }
        // Remove chosen indices from remaining
        remaining.removeAll { chosen.contains($0) }

        // Work/Rest defaults scaled by available time
        let workSec = duration.minutes <= 30 ? 30 : 40
        let restSec = 15
        let rounds = duration.minutes <= 30 ? 3 : 4
        let perExercise = chosen.map { idx in
            let ex = list[idx]
            let tracking = ExerciseClassificationService.determineTrackingType(for: ex.exercise)
            switch tracking {
            case .timeOnly, .timeDistance, .holdTime:
                return BlockExercise(
                    exercise: ex.exercise,
                    schemeType: .interval,
                    repScheme: nil,
                    intervalScheme: IntervalScheme(workSec: workSec, restSec: restSec, targetReps: nil)
                )
            default:
                return BlockExercise(
                    exercise: ex.exercise,
                    schemeType: .rep,
                    repScheme: RepScheme(sets: ex.sets, reps: ex.reps, rir: nil, restSec: ex.restTime),
                    intervalScheme: nil
                )
            }
        }

        // Weight normalization heuristic: same dumbbells if all DB/body weight
        let usesDBOnly = chosen.allSatisfy { list[$0].exercise.equipment.lowercased().contains("dumbbell") || list[$0].exercise.equipment.lowercased().contains("body weight") || list[$0].exercise.equipment.isEmpty }
        return WorkoutBlock(
            type: .circuit,
            exercises: perExercise,
            rounds: rounds,
            restBetweenExercises: 15,
            restBetweenRounds: 60,
            weightNormalization: usesDBOnly ? .sameDumbbellPair : nil,
            timingConfig: TimingConfig(prepareSec: 5, transitionSec: 10, autoAdvance: true)
        )
    }

    // MARK: - Safety Heuristics (client-side)
    private static func circuitsAllowed(for goal: FitnessGoal) -> Bool {
        // Also respect global user gate
        if UserProfileService.shared.autoGroupingEnabled == false { return false }
        switch goal.normalized {
        case .strength, .powerlifting, .olympicWeightlifting:
            return false
        default:
            return true
        }
    }

    private static func isCircuitSafe(_ ex: ExerciseData) -> Bool {
        let name = ex.name.lowercased()
        let equipment = ex.equipment.lowercased()
        // Exclude heavy barbell and Olympic lifts for circuits
        if equipment.contains("barbell") { return false }
        if name.contains("clean") || name.contains("snatch") || name.contains("jerk") { return false }
        if name.contains("deadlift") || name.contains("back squat") || name.contains("front squat") || name.contains("bench press") { return false }
        return true
    }

    private static func isSupersetSafe(_ a: ExerciseData, _ b: ExerciseData) -> Bool {
        let ea = a.equipment.lowercased()
        let eb = b.equipment.lowercased()
        let na = a.name.lowercased()
        let nb = b.name.lowercased()
        // Avoid main compounds
        let isMain: (String) -> Bool = { n in
            n.contains("deadlift") || n.contains("back squat") || n.contains("front squat") || n.contains("bench press") || n.contains("clean") || n.contains("snatch") || n.contains("jerk")
        }
        if isMain(na) || isMain(nb) { return false }
        // Same/compatible equipment only
        let type: (String) -> String = { e in
            if e.contains("dumbbell") { return "db" }
            if e.contains("cable") { return "cable" }
            if e.contains("machine") || e.contains("lever") { return "machine" }
            if e.contains("body weight") { return "bw" }
            return e
        }
        return type(ea) == type(eb)
    }

    private static func caps(for goal: FitnessGoal) -> (superset: Int, circuit: Int) {
        switch goal.normalized {
        case .circuitTraining:
            // Tighten cap: circuits at 2 (not 3)
            return (superset: 0, circuit: 2)
        case .hypertrophy:
            return (superset: 1, circuit: 0)
        case .general:
            // Make circuits truly rare: cap circuits at 0 (supersets only)
            return (superset: 1, circuit: 0)
        case .strength, .powerlifting, .olympicWeightlifting:
            return (superset: 1, circuit: 0)
        default:
            return (superset: 1, circuit: 0)
        }
    }
}
