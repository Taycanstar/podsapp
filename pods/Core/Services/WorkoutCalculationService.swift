import Foundation

struct WorkoutStats: Identifiable, Codable {
    let id: UUID = UUID()
    let duration: TimeInterval
    let totalVolume: Double
    let estimatedCalories: Int
    let exerciseCount: Int
    let totalSets: Int
    let unitsSystem: UnitsSystem
    let personalRecords: [PersonalRecord]
}

enum PersonalRecordType: String, Codable {
    case heaviestWeight
    case mostReps
    case bestVolume
}

struct PersonalRecord: Identifiable, Codable {
    let id: UUID = UUID()
    let exerciseId: Int
    let exerciseName: String
    let recordType: PersonalRecordType
    let newValue: Double
    let previousValue: Double?
}

enum WorkoutExerciseSection: String, Codable {
    case warmUp
    case main
    case coolDown
}

struct ExerciseBreakdown: Identifiable, Codable {
    let id: UUID = UUID()
    let exercise: ExerciseData
    let section: WorkoutExerciseSection
    let totalSets: Int
    let totalReps: Int
    let averageWeight: Double?
    let topWeight: Double?
    let volume: Double
    let totalDuration: TimeInterval?
    let trackingType: ExerciseTrackingType?
    let personalRecords: [PersonalRecordType]
}

struct CompletedWorkoutSummary: Identifiable, Codable {
    let id: UUID = UUID()
    let workout: TodayWorkout
    let stats: WorkoutStats
    let exerciseBreakdown: [ExerciseBreakdown]
    let generatedAt: Date
}

final class WorkoutCalculationService {
    static let shared = WorkoutCalculationService()

    private init() {}

    func buildSummary(for workout: TodayWorkout,
                      duration: TimeInterval,
                      unitsSystem: UnitsSystem,
                      profile: ProfileDataResponse?) -> CompletedWorkoutSummary {
        let sanitizedDuration = max(duration, 0)
        let personalRecords = detectPersonalRecords(in: workout.exercises)
        let stats = calculateWorkoutStats(exercises: workout.exercises,
                                          duration: sanitizedDuration,
                                          unitsSystem: unitsSystem,
                                          profile: profile,
                                          personalRecords: personalRecords)
        let breakdown = buildExerciseBreakdown(for: workout,
                                               personalRecords: personalRecords)
        return CompletedWorkoutSummary(workout: workout,
                                       stats: stats,
                                       exerciseBreakdown: breakdown,
                                       generatedAt: Date())
    }

    private struct SetContribution {
        let reps: Double?
        let weight: Double?
        let duration: TimeInterval?
        let trackingType: ExerciseTrackingType
    }

    func calculateWorkoutStats(exercises: [TodayWorkoutExercise],
                               duration: TimeInterval,
                               unitsSystem: UnitsSystem,
                               profile: ProfileDataResponse?,
                               personalRecords: [PersonalRecord] = []) -> WorkoutStats {
        let contributions = exercises.map { setContributions(for: $0) }
        let totalVolume = contributions.reduce(0) { partial, sets in
            partial + sets.reduce(0) { $0 + (($1.reps ?? 0) * ($1.weight ?? 0)) }
        }
        let exerciseCount = exercises.count
        let totalSets = contributions.reduce(0) { $0 + $1.count }
        let calories = estimateCaloriesBurned(volume: totalVolume,
                                              duration: duration,
                                              profile: profile,
                                              unitsSystem: unitsSystem)

        return WorkoutStats(duration: duration,
                            totalVolume: totalVolume,
                            estimatedCalories: calories,
                            exerciseCount: exerciseCount,
                            totalSets: totalSets,
                            unitsSystem: unitsSystem,
                            personalRecords: personalRecords)
    }

    func calculateTotalVolume(_ exercises: [TodayWorkoutExercise]) -> Double {
        exercises.reduce(0) { total, exercise in
            let contributions = setContributions(for: exercise)
            let volume = contributions.reduce(0) { $0 + (($1.reps ?? 0) * ($1.weight ?? 0)) }
            return total + volume
        }
    }

    func estimateCaloriesBurned(volume: Double,
                                duration: TimeInterval,
                                profile: ProfileDataResponse?,
                                unitsSystem: UnitsSystem) -> Int {
        let durationMinutes = max(duration / 60.0, 1.0)

        // Default 70kg if no profile weight is available
        let bodyWeightKg: Double = {
            if let weightKg = profile?.currentWeightKg, weightKg > 0 {
                return weightKg
            }
            if let weightLbs = profile?.currentWeightLbs, weightLbs > 0 {
                return weightLbs * 0.453592
            }
            return 70.0
        }()

        // Convert total volume to kilograms for metabolic calculation
        let volumeKg: Double = {
            switch unitsSystem {
            case .imperial:
                return volume * 0.453592
            case .metric:
                return volume
            }
        }()

        let baseBurn = (bodyWeightKg * 0.05) * durationMinutes
        let volumeBurn = volumeKg * 0.002
        let intensityMultiplier = min(1.5, max(0.8, durationMinutes / 45.0))
        let epocMultiplier = 1.15
        let totalCalories = (baseBurn + volumeBurn) * intensityMultiplier * epocMultiplier
        return max(0, Int(round(totalCalories)))
    }

    func detectPersonalRecords(in exercises: [TodayWorkoutExercise]) -> [PersonalRecord] {
        let userProfile = UserProfileService.shared
        var records: [PersonalRecord] = []

        for exercise in exercises {
            let contributions = setContributions(for: exercise)
            guard !contributions.isEmpty else { continue }

            let exerciseId = exercise.exercise.id
            let performance = userProfile.getExercisePerformance(exerciseId: exerciseId)
            let previousHeaviest = performance?.records.compactMap { $0.weight > 0 ? $0.weight : nil }.max()
            let previousMostReps = performance?.records.map { $0.reps }.max()
            let previousBestVolume = performance?.records.map { $0.volume }.max()

            let maxWeight = contributions.compactMap { $0.weight }.max() ?? 0
            if maxWeight > 0, maxWeight > (previousHeaviest ?? 0) + 0.1 {
                records.append(PersonalRecord(exerciseId: exerciseId,
                                              exerciseName: exercise.exercise.name,
                                              recordType: .heaviestWeight,
                                              newValue: maxWeight,
                                              previousValue: previousHeaviest))
            }

            let maxReps = contributions.compactMap { $0.reps }.max() ?? 0
            if maxReps > Double(previousMostReps ?? 0) {
                records.append(PersonalRecord(exerciseId: exerciseId,
                                              exerciseName: exercise.exercise.name,
                                              recordType: .mostReps,
                                              newValue: maxReps,
                                              previousValue: previousMostReps.map(Double.init)))
            }

            let bestVolume = contributions.map { ($0.reps ?? 0) * ($0.weight ?? 0) }.max() ?? 0
            if bestVolume > (previousBestVolume ?? 0) + 0.1 {
                records.append(PersonalRecord(exerciseId: exerciseId,
                                              exerciseName: exercise.exercise.name,
                                              recordType: .bestVolume,
                                              newValue: bestVolume,
                                              previousValue: previousBestVolume))
            }
        }

        return records
    }

    // MARK: - Helpers

    private func setContributions(for exercise: TodayWorkoutExercise) -> [SetContribution] {
        if let flexibleSets = exercise.flexibleSets, !flexibleSets.isEmpty {
            let completedSets = flexibleSets.filter { !$0.isWarmupSet }
            var result: [SetContribution] = []

            for set in completedSets {
                switch set.trackingType {
                case .repsWeight:
                    let reps = set.reps.flatMap { Double($0) }
                    let weight = set.weight.flatMap { Double($0) }
                    result.append(SetContribution(reps: reps,
                                                  weight: weight,
                                                  duration: nil,
                                                  trackingType: set.trackingType))
                case .repsOnly:
                    let reps = set.reps.flatMap { Double($0) }
                    result.append(SetContribution(reps: reps,
                                                  weight: nil,
                                                  duration: nil,
                                                  trackingType: set.trackingType))
                case .timeOnly, .holdTime:
                    result.append(SetContribution(reps: nil,
                                                  weight: nil,
                                                  duration: set.duration,
                                                  trackingType: set.trackingType))
                case .timeDistance:
                    result.append(SetContribution(reps: nil,
                                                  weight: nil,
                                                  duration: set.duration,
                                                  trackingType: set.trackingType))
                case .rounds:
                    let rounds = set.rounds.map { Double($0) }
                    result.append(SetContribution(reps: rounds,
                                                  weight: nil,
                                                  duration: nil,
                                                  trackingType: set.trackingType))
                }
            }

            if !result.isEmpty {
                return result
            }
        }

        let setCount = max(exercise.sets, 0)
        guard setCount > 0 else { return [] }

        let reps = Double(max(exercise.reps, 0))
        let weight = exercise.weight
        let tracking = exercise.trackingType ?? .repsWeight

        return Array(repeating: SetContribution(reps: reps > 0 ? reps : nil,
                                                weight: weight,
                                                duration: nil,
                                                trackingType: tracking),
                      count: setCount)
    }

    private func buildExerciseBreakdown(for workout: TodayWorkout,
                                        personalRecords: [PersonalRecord]) -> [ExerciseBreakdown] {
        let prMap = Dictionary(grouping: personalRecords, by: { $0.exerciseId }).mapValues { records in
            Array(Set(records.map { $0.recordType }))
        }

        var breakdown: [ExerciseBreakdown] = []

        if let warmups = workout.warmUpExercises {
            breakdown.append(contentsOf: warmups.map { exercise in
                buildBreakdownEntry(for: exercise,
                                    section: .warmUp,
                                    prMap: prMap)
            })
        }

        breakdown.append(contentsOf: workout.exercises.map { exercise in
            buildBreakdownEntry(for: exercise,
                                section: .main,
                                prMap: prMap)
        })

        if let cooldowns = workout.coolDownExercises {
            breakdown.append(contentsOf: cooldowns.map { exercise in
                buildBreakdownEntry(for: exercise,
                                    section: .coolDown,
                                    prMap: prMap)
            })
        }

        return breakdown
    }

    private func buildBreakdownEntry(for exercise: TodayWorkoutExercise,
                                     section: WorkoutExerciseSection,
                                     prMap: [Int: [PersonalRecordType]]) -> ExerciseBreakdown {
        let contributions = setContributions(for: exercise)
        let totalSets = contributions.count
        let totalReps = contributions.reduce(0) { $0 + Int($1.reps ?? 0) }
        let weights = contributions.compactMap { $0.weight }.filter { $0 > 0 }
        let averageWeight = weights.isEmpty ? nil : (weights.reduce(0, +) / Double(weights.count))
        let topWeight = weights.max()
        let volume = contributions.reduce(0) { $0 + (($1.reps ?? 0) * ($1.weight ?? 0)) }
        let totalDuration = contributions.compactMap { $0.duration }.reduce(0, +)
        let durationValue = totalDuration > 0 ? totalDuration : nil
        let trackingType = contributions.first?.trackingType ?? exercise.trackingType

        return ExerciseBreakdown(exercise: exercise.exercise,
                                 section: section,
                                 totalSets: totalSets,
                                 totalReps: totalReps,
                                 averageWeight: averageWeight,
                                 topWeight: topWeight,
                                 volume: volume,
                                 totalDuration: durationValue,
                                 trackingType: trackingType,
                                 personalRecords: prMap[exercise.exercise.id] ?? [])
    }
}
