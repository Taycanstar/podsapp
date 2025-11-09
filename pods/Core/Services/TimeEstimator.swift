//
//  TimeEstimator.swift
//  pods
//
//  Created by Dimi Nunez on 11/5/25.
//


import Foundation

struct TimeEstimator {
    static let shared = TimeEstimator()

    private let config: TimeCostModelConfig

    private init(config: TimeCostModelConfig = TimeCostModelLoader.load()) {
        self.config = config
    }

    // MARK: - Session Level Estimates

    func sessionOverhead(
        for duration: WorkoutDuration,
        preferences: FlexibilityPreferences? = nil
    ) -> (warmupMinutes: Int, cooldownMinutes: Int) {
        let entry = config.sessionOverhead[duration.rawValue]
        var warmup = entry?.warmupMinutes ?? legacySessionOverhead(for: duration).warmup
        var cooldown = entry?.cooldownMinutes ?? legacySessionOverhead(for: duration).cooldown

        if let prefs = preferences {
            if !prefs.warmUpEnabled { warmup = 0 }
            if !prefs.coolDownEnabled { cooldown = 0 }
        }

        return (warmupMinutes: warmup, cooldownMinutes: cooldown)
    }

    func bufferSeconds(for duration: WorkoutDuration) -> Int {
        config.bufferSeconds[duration.rawValue] ?? legacyBuffer(for: duration)
    }

    func exerciseCap(for duration: WorkoutDuration) -> Int {
        config.exerciseCaps[duration.rawValue] ?? legacyExerciseCap(for: duration)
    }

    func minimumExercises(for duration: WorkoutDuration, muscleGroupCount: Int) -> Int {
        let base = config.minimumExercises[duration.rawValue] ?? legacyMinimum(for: duration)
        return min(base, max(1, muscleGroupCount))
    }

    func preferredFormat(duration: WorkoutDuration, goal: FitnessGoal) -> TrainingFormat {
        let normalized = goal.normalized
        if normalized == .circuitTraining {
            return .circuit3
        }

        switch duration {
        case .fifteenMinutes:
            return .circuit3
        case .thirtyMinutes:
            return normalized == .hypertrophy ? .superset : .circuit3
        case .fortyFiveMinutes:
            return .superset
        case .oneHour:
            return (normalized == .strength || normalized == .powerlifting || normalized == .olympicWeightlifting) ? .straightSets : .superset
        case .oneAndHalfHours, .twoHours:
            return .straightSets
        }
    }

    func averageExerciseSeconds(
        goal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        format overrideFormat: TrainingFormat? = nil
    ) -> Double {
        let normalized = goal.normalized
        let sets = typicalSets(for: normalized)
        let reps = typicalReps(for: normalized)
        let compoundShare = compoundShare(for: normalized)
        let adjustment = experienceAdjustment(for: experienceLevel)
        let format = overrideFormat ?? preferredFormat(duration: .oneHour, goal: normalized)
        let formatParams = format.parameters(from: config)

        let compoundEstimate = perMovementEstimate(
            goal: normalized,
            movement: .compound,
            sets: sets,
            reps: reps,
            adjustment: adjustment,
            format: formatParams
        )

        let isolationEstimate = perMovementEstimate(
            goal: normalized,
            movement: .isolation,
            sets: max(3, sets - 1),
            reps: max(8, reps + 2),
            adjustment: adjustment,
            format: formatParams
        )

        return compoundShare * compoundEstimate + (1 - compoundShare) * isolationEstimate
    }

    func makeSessionBudget(
        duration: WorkoutDuration,
        fitnessGoal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        preferences: FlexibilityPreferences?
    ) -> SessionTimeBudget {
        let overhead = sessionOverhead(for: duration, preferences: preferences)
        let warmupSeconds = overhead.warmupMinutes * 60
        let cooldownSeconds = overhead.cooldownMinutes * 60
        let buffer = bufferSeconds(for: duration)
        let totalSeconds = duration.minutes * 60
        let available = max(0, totalSeconds - warmupSeconds - cooldownSeconds - buffer)
        let overrunAllowance = max(45, Int(Double(available) * 0.05))
        let format = preferredFormat(duration: duration, goal: fitnessGoal)

        return SessionTimeBudget(
            duration: duration,
            fitnessGoal: fitnessGoal,
            experienceLevel: experienceLevel,
            format: format,
            warmupSeconds: warmupSeconds,
            cooldownSeconds: cooldownSeconds,
            bufferSeconds: buffer,
            availableWorkSeconds: available,
            maxWorkSeconds: available + overrunAllowance
        )
    }

    // MARK: - Exercise Level Estimates

    func estimateExerciseSeconds(
        for exercise: TodayWorkoutExercise,
        fitnessGoal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        format: TrainingFormat
    ) -> Int {
        guard exercise.sets > 0 else { return 0 }

        let adjustment = experienceAdjustment(for: experienceLevel)
        let formatParams = format.parameters(from: config)
        let trackingType = exercise.trackingType ?? .repsWeight

        switch trackingType {
        case .repsWeight, .repsOnly:
            return estimateRepetitionExercise(
                exercise,
                goal: fitnessGoal,
                adjustment: adjustment,
                format: formatParams
            )
        case .timeOnly, .holdTime, .timeDistance, .rounds:
            return estimateTimeTrackedExercise(
                exercise,
                goal: fitnessGoal,
                adjustment: adjustment,
                format: formatParams
            )
        }
    }

    func totalSeconds(
        for exercises: [TodayWorkoutExercise],
        fitnessGoal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        format: TrainingFormat
    ) -> Int {
        exercises.reduce(0) { partial, exercise in
            partial + estimateExerciseSeconds(
                for: exercise,
                fitnessGoal: fitnessGoal,
                experienceLevel: experienceLevel,
                format: format
            )
        }
    }

    // MARK: - Private Helpers

    private func estimateRepetitionExercise(
        _ exercise: TodayWorkoutExercise,
        goal: FitnessGoal,
        adjustment: TimeCostModelConfig.ExperienceAdjustment,
        format: FormatParameters
    ) -> Int {
        let movement = movementType(for: exercise.exercise)
        let sets = max(1, exercise.sets)
        let reps = max(1, exercise.reps)
        let tempo = repTempo(for: movement, reps: reps)
        let tempoAdjusted = tempo / max(0.5, adjustment.tempoFactor)

        let working = Double(sets * reps) * tempoAdjusted
        let baseRest = Double(restInterval(for: goal, movement: movement))
        let restSeconds = Double(max(0, sets - 1)) *
            baseRest *
            adjustment.restMultiplier *
            format.restFactor

        let archetype = equipmentArchetype(for: exercise.exercise)
        let setup = Double(setupSeconds(for: archetype)) * adjustment.setupMultiplier
        let warmup = warmupSeconds(for: exercise.warmupSets?.count ?? 0, isCompound: movement == .compound)
        let total = (working + restSeconds + setup + warmup + Double(config.transitionSeconds)) * format.timeMultiplier

        return Int(total.rounded(.up))
    }

    private func estimateTimeTrackedExercise(
        _ exercise: TodayWorkoutExercise,
        goal: FitnessGoal,
        adjustment: TimeCostModelConfig.ExperienceAdjustment,
        format: FormatParameters
    ) -> Int {
        let working = Double(timeTrackedWorkingSeconds(for: exercise))
        let sets = max(1, exercise.flexibleSets?.count ?? exercise.sets)
        let fallbackRest = restInterval(for: goal, movement: .isolation)
        let restPerSet = exercise.restTime > 0 ? exercise.restTime : fallbackRest
        let restSeconds = Double(max(0, sets - 1) * restPerSet) *
            adjustment.restMultiplier *
            format.restFactor

        let archetype = equipmentArchetype(for: exercise.exercise)
        let setup = Double(setupSeconds(for: archetype)) * adjustment.setupMultiplier
        let total = (working + restSeconds + setup + Double(config.transitionSeconds)) * format.timeMultiplier
        return Int(total.rounded(.up))
    }

    private func timeTrackedWorkingSeconds(for exercise: TodayWorkoutExercise) -> Int {
        guard let sets = exercise.flexibleSets, !sets.isEmpty else {
            if exercise.trackingType == .rounds {
                return max(1, exercise.sets) * 180
            }
            return max(1, exercise.sets) * 60
        }

        var total = 0
        for set in sets {
            if let rounds = set.rounds, let duration = set.duration {
                total += Int(duration) * rounds
            } else if let duration = set.duration {
                total += Int(duration)
            }
        }

        if total == 0, let first = sets.first, let duration = first.duration, let rounds = first.rounds {
            total = Int(duration) * rounds
        }

        return max(total, 45)
    }

    private func movementType(for exercise: ExerciseData) -> EstimatorMovementType {
        let name = exercise.name.lowercased()
        let exerciseType = exercise.exerciseType.lowercased()
        let bodyPart = exercise.bodyPart.lowercased()

        let compoundKeywords = ["squat", "deadlift", "press", "row", "pull", "lunge", "clean", "snatch", "thrust", "swing"]
        if compoundKeywords.contains(where: { name.contains($0) }) {
            return .compound
        }

        if bodyPart.contains("back") || bodyPart.contains("legs") {
            if name.contains("press") || name.contains("row") || name.contains("squat") {
                return .compound
            }
        }

        if exerciseType.contains("compound") {
            return .compound
        }

        return .isolation
    }

    private func equipmentArchetype(for exercise: ExerciseData) -> EquipmentArchetype {
        let equipment = exercise.equipment.lowercased()
        if equipment.contains("barbell") || equipment.contains("smith") || equipment.contains("leverage") || equipment.contains("ez bar") {
            return .barbell
        }
        if equipment.contains("dumbbell") {
            return .dumbbell
        }
        if equipment.contains("kettlebell") {
            return .kettlebell
        }
        if equipment.contains("cable") || equipment.contains("pulldown") {
            return .cable
        }
        if equipment.contains("machine") || equipment.contains("leg press") || equipment.contains("hammerstrength") {
            return .machine
        }
        if equipment.contains("band") {
            return .band
        }
        if equipment.contains("sled") {
            return .sled
        }
        if equipment.contains("body weight") || equipment.contains("bodyweight") || equipment.contains("weighted") || equipment.contains("suspension") || equipment.contains("rings") {
            return .bodyweight
        }
        if equipment.contains("medicine") || equipment.contains("battle rope") || equipment.contains("bosu") {
            return .specialty
        }
        return .bodyweight
    }

    private func repTempo(for movement: EstimatorMovementType, reps: Int) -> Double {
        let bucket = RepRangeBucket(reps: reps)
        if let tempo = config.repTempos[movement.rawValue]?[bucket.rawValue] {
            return tempo
        }
        return movement == .compound ? 3.0 : 2.8
    }

    private func restInterval(for goal: FitnessGoal, movement: EstimatorMovementType) -> Int {
        let key = goal.normalized.rawValue
        if let entry = config.restIntervals[key] {
            return movement == .compound ? entry.compound : entry.isolation
        }

        if let entry = config.restIntervals[FitnessGoal.general.rawValue] {
            return movement == .compound ? entry.compound : entry.isolation
        }

        return movement == .compound ? 90 : 60
    }

    private func setupSeconds(for archetype: EquipmentArchetype) -> Double {
        let key = archetype.rawValue
        if let seconds = config.setupSeconds[key] {
            return seconds
        }
        return config.setupSeconds["default"] ?? 15
    }

    private func warmupSeconds(for count: Int, isCompound: Bool) -> Double {
        guard count > 0, isCompound else { return 0 }
        return Double(count * config.warmupSetSeconds)
    }

    private func typicalSets(for goal: FitnessGoal) -> Int {
        config.defaultSets[goal.rawValue] ?? 4
    }

    private func typicalReps(for goal: FitnessGoal) -> Int {
        config.defaultReps[goal.rawValue] ?? 10
    }

    private func compoundShare(for goal: FitnessGoal) -> Double {
        config.compoundShare[goal.rawValue] ?? 0.6
    }

    private func perMovementEstimate(
        goal: FitnessGoal,
        movement: EstimatorMovementType,
        sets: Int,
        reps: Int,
        adjustment: TimeCostModelConfig.ExperienceAdjustment,
        format: FormatParameters
    ) -> Double {
        let tempo = repTempo(for: movement, reps: reps)
        let tempoAdjusted = tempo / max(0.5, adjustment.tempoFactor)
        let working = Double(sets * reps) * tempoAdjusted
        let rest = Double(max(0, sets - 1)) *
            Double(restInterval(for: goal, movement: movement)) *
            adjustment.restMultiplier *
            format.restFactor
        let setup = Double(setupSeconds(for: movement.defaultArchetype)) * adjustment.setupMultiplier
        let warmup = movement == .compound ? Double(config.warmupSetSeconds) : 0
        let total = (working + rest + setup + warmup + Double(config.transitionSeconds)) * format.timeMultiplier
        return total
    }

    private func experienceAdjustment(for level: ExperienceLevel) -> TimeCostModelConfig.ExperienceAdjustment {
        if let adjustment = config.experienceAdjustments[level.rawValue] {
            return adjustment
        }
        return TimeCostModelConfig.ExperienceAdjustment(restMultiplier: 1.0, setupMultiplier: 1.0, tempoFactor: 1.0)
    }

    private func legacySessionOverhead(for duration: WorkoutDuration) -> (warmup: Int, cooldown: Int) {
        switch duration {
        case .fifteenMinutes: return (3, 2)
        case .thirtyMinutes: return (4, 3)
        case .fortyFiveMinutes: return (5, 3)
        case .oneHour: return (6, 4)
        case .oneAndHalfHours: return (7, 5)
        case .twoHours: return (8, 6)
        }
    }

    private func legacyBuffer(for duration: WorkoutDuration) -> Int {
        switch duration {
        case .fifteenMinutes, .thirtyMinutes:
            return 60
        case .fortyFiveMinutes:
            return 90
        case .oneHour:
            return 120
        case .oneAndHalfHours:
            return 180
        case .twoHours:
            return 240
        }
    }

    private func legacyExerciseCap(for duration: WorkoutDuration) -> Int {
        switch duration {
        case .fifteenMinutes: return 4
        case .thirtyMinutes: return 6
        case .fortyFiveMinutes: return 8
        case .oneHour: return 10
        case .oneAndHalfHours: return 12
        case .twoHours: return 14
        }
    }

    private func legacyMinimum(for duration: WorkoutDuration) -> Int {
        switch duration {
        case .fifteenMinutes: return 3
        case .thirtyMinutes: return 4
        case .fortyFiveMinutes: return 5
        case .oneHour: return 6
        case .oneAndHalfHours, .twoHours: return 8
        }
    }
}

// MARK: - Session Budget + Formats

extension TimeEstimator {
    struct SessionTimeBudget {
        let duration: WorkoutDuration
        let fitnessGoal: FitnessGoal
        let experienceLevel: ExperienceLevel
        let format: TrainingFormat
        let warmupSeconds: Int
        let cooldownSeconds: Int
        let bufferSeconds: Int
        let availableWorkSeconds: Int
        let maxWorkSeconds: Int

        private(set) var consumedWorkSeconds: Int = 0

        mutating func tryConsume(_ seconds: Int) -> Bool {
            guard seconds > 0 else { return true }
            let updated = consumedWorkSeconds + seconds
            guard updated <= maxWorkSeconds else { return false }
            consumedWorkSeconds = updated
            return true
        }

        mutating func syncActualExerciseSeconds(_ seconds: Int) {
            consumedWorkSeconds = min(seconds, maxWorkSeconds)
        }

        var remainingWorkSeconds: Int {
            max(0, availableWorkSeconds - consumedWorkSeconds)
        }

        var isDepleted: Bool {
            consumedWorkSeconds >= availableWorkSeconds
        }

        var isOutOfTime: Bool {
            consumedWorkSeconds >= maxWorkSeconds
        }

        var warmupMinutes: Int {
            roundedMinutes(from: warmupSeconds)
        }

        var cooldownMinutes: Int {
            roundedMinutes(from: cooldownSeconds)
        }

        var exerciseMinutes: Int {
            roundedMinutes(from: consumedWorkSeconds)
        }

        var totalMinutes: Int {
            roundedMinutes(from: warmupSeconds + cooldownSeconds + bufferSeconds + consumedWorkSeconds)
        }

        private func roundedMinutes(from seconds: Int) -> Int {
            guard seconds > 0 else { return 0 }
            return Int((Double(seconds) / 60.0).rounded(.up))
        }
    }

    enum TrainingFormat: String {
        case straightSets = "straight_sets"
        case superset = "superset"
        case circuit3 = "circuit_3"
        case circuit4 = "circuit_4"
        case emom = "emom"

        fileprivate func parameters(from config: TimeCostModelConfig) -> FormatParameters {
            if let entry = config.densityFormats[rawValue] {
                let restFactor = max(0.2, 1.0 - entry.restCompression)
                return FormatParameters(timeMultiplier: entry.timeMultiplier, restFactor: restFactor)
            }
            return FormatParameters(timeMultiplier: 1.0, restFactor: 1.0)
        }
    }
}

struct FormatParameters {
    let timeMultiplier: Double
    let restFactor: Double
}

private enum EstimatorMovementType: String {
    case compound
    case isolation

    var defaultArchetype: EquipmentArchetype {
        switch self {
        case .compound:
            return .barbell
        case .isolation:
            return .dumbbell
        }
    }
}

private enum EquipmentArchetype: String {
    case barbell
    case dumbbell
    case machine
    case cable
    case kettlebell
    case band
    case bodyweight
    case sled
    case specialty
}

private enum RepRangeBucket: String {
    case low = "1-5"
    case moderate = "6-8"
    case classic = "8-12"
    case endurance = "12-20"

    init(reps: Int) {
        switch reps {
        case ...5:
            self = .low
        case 6...8:
            self = .moderate
        case 9...12:
            self = .classic
        default:
            self = .endurance
        }
    }
}

// MARK: - Model + Loader

private struct TimeCostModelConfig: Decodable {
    struct SessionOverheadEntry: Decodable {
        let warmupMinutes: Int
        let cooldownMinutes: Int

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            warmupMinutes = try container.decode(Int.self, forKey: .warmup)
            cooldownMinutes = try container.decode(Int.self, forKey: .cooldown)
        }

        init(warmupMinutes: Int, cooldownMinutes: Int) {
            self.warmupMinutes = warmupMinutes
            self.cooldownMinutes = cooldownMinutes
        }

        private enum CodingKeys: String, CodingKey {
            case warmup
            case cooldown
        }
    }

    struct DensityFormatConfig: Decodable {
        let timeMultiplier: Double
        let restCompression: Double

        private enum CodingKeys: String, CodingKey {
            case timeMultiplier = "time_multiplier"
            case restCompression = "rest_compression"
        }
    }

    struct ExperienceAdjustment: Decodable {
        let restMultiplier: Double
        let setupMultiplier: Double
        let tempoFactor: Double

        init(restMultiplier: Double, setupMultiplier: Double, tempoFactor: Double) {
            self.restMultiplier = restMultiplier
            self.setupMultiplier = setupMultiplier
            self.tempoFactor = tempoFactor
        }

        private enum CodingKeys: String, CodingKey {
            case restMultiplier = "rest_multiplier"
            case setupMultiplier = "setup_multiplier"
            case tempoFactor = "tempo_factor"
        }
    }

    struct MovementRest: Decodable {
        let compound: Int
        let isolation: Int
    }

    let sessionOverhead: [String: SessionOverheadEntry]
    let bufferSeconds: [String: Int]
    let exerciseCaps: [String: Int]
    let minimumExercises: [String: Int]
    let repTempos: [String: [String: Double]]
    let restIntervals: [String: MovementRest]
    let setupSeconds: [String: Double]
    let transitionSeconds: Int
    let warmupSetSeconds: Int
    let densityFormats: [String: DensityFormatConfig]
    let experienceAdjustments: [String: ExperienceAdjustment]
    let compoundShare: [String: Double]
    let defaultSets: [String: Int]
    let defaultReps: [String: Int]

    private enum CodingKeys: String, CodingKey {
        case sessionOverhead = "session_overhead"
        case bufferSeconds = "buffer_seconds"
        case exerciseCaps = "exercise_caps"
        case minimumExercises = "minimum_exercises"
        case repTempos = "rep_tempos"
        case restIntervals = "rest_intervals"
        case setupSeconds = "setup_seconds"
        case transitionSeconds = "transition_seconds"
        case warmupSetSeconds = "warmup_set_seconds"
        case densityFormats = "density_formats"
        case experienceAdjustments = "experience_adjustments"
        case compoundShare = "compound_share"
        case defaultSets = "default_sets"
        case defaultReps = "default_reps"
    }

    init(
        sessionOverhead: [String: SessionOverheadEntry],
        bufferSeconds: [String: Int],
        exerciseCaps: [String: Int],
        minimumExercises: [String: Int],
        repTempos: [String: [String: Double]],
        restIntervals: [String: MovementRest],
        setupSeconds: [String: Double],
        transitionSeconds: Int,
        warmupSetSeconds: Int,
        densityFormats: [String: DensityFormatConfig],
        experienceAdjustments: [String: ExperienceAdjustment],
        compoundShare: [String: Double],
        defaultSets: [String: Int],
        defaultReps: [String: Int]
    ) {
        self.sessionOverhead = sessionOverhead
        self.bufferSeconds = bufferSeconds
        self.exerciseCaps = exerciseCaps
        self.minimumExercises = minimumExercises
        self.repTempos = repTempos
        self.restIntervals = restIntervals
        self.setupSeconds = setupSeconds
        self.transitionSeconds = transitionSeconds
        self.warmupSetSeconds = warmupSetSeconds
        self.densityFormats = densityFormats
        self.experienceAdjustments = experienceAdjustments
        self.compoundShare = compoundShare
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
    }

    static var empty: TimeCostModelConfig {
        TimeCostModelConfig(
            sessionOverhead: [:],
            bufferSeconds: [:],
            exerciseCaps: [:],
            minimumExercises: [:],
            repTempos: [:],
            restIntervals: [:],
            setupSeconds: [:],
            transitionSeconds: 0,
            warmupSetSeconds: 0,
            densityFormats: [:],
            experienceAdjustments: [:],
            compoundShare: [:],
            defaultSets: [:],
            defaultReps: [:]
        )
    }
}

private enum TimeCostModelLoader {
    static func load() -> TimeCostModelConfig {
        let decoder = JSONDecoder()
        let bundleCandidates = [
            Bundle.main,
            Bundle(for: TimeEstimatorBundleToken.self)
        ]

        for bundle in bundleCandidates {
            if let url = bundle.url(forResource: "time_cost_model", withExtension: "json") {
                do {
                    let data = try Data(contentsOf: url)
                    return try decoder.decode(TimeCostModelConfig.self, from: data)
                } catch {
#if DEBUG
                    print("⚠️ TimeEstimator: Failed to decode time_cost_model.json - \(error)")
#endif
                }
            }
        }

        return fallback
    }

    private static let fallback: TimeCostModelConfig = {
        let decoder = JSONDecoder()
        if let data = embeddedJSON.data(using: .utf8),
           let config = try? decoder.decode(TimeCostModelConfig.self, from: data) {
            return config
        }
        return TimeCostModelConfig.empty
    }()

    private static let embeddedJSON = """
{
    "session_overhead": {
        "15m": { "warmup": 3, "cooldown": 2 },
        "30m": { "warmup": 4, "cooldown": 3 },
        "45m": { "warmup": 5, "cooldown": 3 },
        "1h": { "warmup": 6, "cooldown": 4 },
        "1.5h": { "warmup": 7, "cooldown": 5 },
        "2h": { "warmup": 8, "cooldown": 6 }
    },
    "buffer_seconds": {
        "15m": 60,
        "30m": 60,
        "45m": 90,
        "1h": 120,
        "1.5h": 180,
        "2h": 240
    },
    "exercise_caps": {
        "15m": 4,
        "30m": 6,
        "45m": 8,
        "1h": 10,
        "1.5h": 12,
        "2h": 14
    },
    "minimum_exercises": {
        "15m": 3,
        "30m": 4,
        "45m": 5,
        "1h": 6,
        "1.5h": 8,
        "2h": 8
    },
    "rep_tempos": {
        "compound": {
            "1-5": 2.8,
            "6-8": 3.2,
            "8-12": 3.0,
            "12-20": 2.8
        },
        "isolation": {
            "6-8": 2.8,
            "8-12": 3.2,
            "12-20": 2.5
        }
    },
    "rest_intervals": {
        "strength": { "compound": 240, "isolation": 120 },
        "powerlifting": { "compound": 270, "isolation": 150 },
        "olympic_weightlifting": { "compound": 270, "isolation": 150 },
        "hypertrophy": { "compound": 90, "isolation": 60 },
        "general": { "compound": 75, "isolation": 60 },
        "circuit_training": { "compound": 45, "isolation": 30 }
    },
    "setup_seconds": {
        "barbell": 35,
        "dumbbell": 15,
        "machine": 12,
        "cable": 12,
        "kettlebell": 18,
        "band": 8,
        "bodyweight": 5,
        "sled": 25,
        "specialty": 20,
        "default": 15
    },
    "transition_seconds": 15,
    "warmup_set_seconds": 45,
    "density_formats": {
        "straight_sets": { "time_multiplier": 1.0, "rest_compression": 0.0 },
        "superset": { "time_multiplier": 0.63, "rest_compression": 0.37 },
        "circuit_3": { "time_multiplier": 0.65, "rest_compression": 0.35 },
        "circuit_4": { "time_multiplier": 0.70, "rest_compression": 0.30 },
        "emom": { "time_multiplier": 0.75, "rest_compression": 0.25 }
    },
    "experience_adjustments": {
        "beginner": { "rest_multiplier": 1.25, "setup_multiplier": 1.3, "tempo_factor": 0.8 },
        "intermediate": { "rest_multiplier": 1.0, "setup_multiplier": 1.0, "tempo_factor": 0.95 },
        "advanced": { "rest_multiplier": 0.85, "setup_multiplier": 0.85, "tempo_factor": 1.0 }
    },
    "compound_share": {
        "strength": 0.8,
        "powerlifting": 0.85,
        "olympic_weightlifting": 0.85,
        "hypertrophy": 0.65,
        "general": 0.6,
        "circuit_training": 0.5
    },
    "default_sets": {
        "strength": 4,
        "powerlifting": 4,
        "olympic_weightlifting": 4,
        "hypertrophy": 4,
        "general": 3,
        "circuit_training": 3
    },
    "default_reps": {
        "strength": 4,
        "powerlifting": 3,
        "olympic_weightlifting": 3,
        "hypertrophy": 10,
        "general": 10,
        "circuit_training": 12
    }
}
"""
}

private final class TimeEstimatorBundleToken {}
