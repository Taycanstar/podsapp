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
    case bestVolume
}

struct PersonalRecord: Identifiable, Codable {
    let id: UUID = UUID()
    let exerciseId: Int
    let exerciseName: String
    let recordType: PersonalRecordType
    let newValue: Double
    let previousValue: Double?
    let weight: Double?
    let reps: Int?
    let previousWeight: Double?
    let previousReps: Int?
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
    let bestSetWeight: Double?
    let bestSetReps: Int?
    let volume: Double
    let totalDuration: TimeInterval?
    let trackingType: ExerciseTrackingType?
    let setSummaries: [ExerciseSetSummary]
    let personalRecords: [PersonalRecordType]
}

struct CompletedWorkoutSummary: Identifiable, Codable {
    let id: UUID = UUID()
    let workout: TodayWorkout
    let stats: WorkoutStats
    let exerciseBreakdown: [ExerciseBreakdown]
    let generatedAt: Date
}

struct ExerciseSetSummary: Identifiable, Codable {
    let id: UUID = UUID()
    let index: Int
    let trackingType: ExerciseTrackingType
    let reps: Double?
    let weight: Double?
    let duration: TimeInterval?
    let distance: Double?
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
        let breakdown = buildExerciseBreakdown(for: workout,
                                               personalRecords: personalRecords)
        let allSections = (workout.warmUpExercises ?? []) + workout.exercises + (workout.coolDownExercises ?? [])
        let stats = calculateWorkoutStats(exercises: allSections,
                                          duration: sanitizedDuration,
                                          unitsSystem: unitsSystem,
                                          profile: profile,
                                          personalRecords: personalRecords)
        return CompletedWorkoutSummary(workout: workout,
                                       stats: stats,
                                       exerciseBreakdown: breakdown,
                                       generatedAt: Date())
    }

    private struct SetContribution {
        let index: Int
        let trackingType: ExerciseTrackingType
        let reps: Double?
        let weight: Double?
        let duration: TimeInterval?
        let distance: Double?
    }

    func calculateWorkoutStats(exercises: [TodayWorkoutExercise],
                               duration: TimeInterval,
                               unitsSystem: UnitsSystem,
                               profile: ProfileDataResponse?,
                               personalRecords: [PersonalRecord] = []) -> WorkoutStats {
        let contributionsByExercise = exercises.map { setContributions(for: $0) }
        let flattenedContributions = contributionsByExercise.flatMap { $0 }

        let totalVolume = flattenedContributions.reduce(0) { partial, contribution in
            partial + ((contribution.reps ?? 0) * (contribution.weight ?? 0))
        }.rounded()
        let exerciseCount = contributionsByExercise.filter { !$0.isEmpty }.count
        let totalSets = contributionsByExercise.reduce(0) { $0 + $1.count }
        let roundedDuration = duration.rounded()
        let calories = estimateCaloriesBurned(volume: totalVolume,
                                              duration: roundedDuration,
                                              profile: profile,
                                              unitsSystem: unitsSystem)

        // Debug logging to compare with workoutToCombinedLog calculation
        print("🔥 buildSummary Calories Calculation:")
        print("   - Total Volume: \(String(format: "%.1f", totalVolume)) \(unitsSystem == .metric ? "kg" : "lbs")")
        print("   - Duration: \(Int(roundedDuration))s (\(Int(roundedDuration/60))min)")
        print("   - Body Weight: \(profile?.currentWeightKg ?? 0)kg")
        print("   - Units System: \(unitsSystem)")
        print("   - Estimated Calories: \(calories)")

        return WorkoutStats(duration: roundedDuration,
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
            let weightedContributions = contributions.filter { ($0.weight ?? 0) > 0 && ($0.reps ?? 0) > 0 }
            guard !weightedContributions.isEmpty else { continue }

            let heaviestContribution = weightedContributions.max { lhs, rhs in
                let lhsWeight = lhs.weight ?? 0
                let rhsWeight = rhs.weight ?? 0
                if lhsWeight == rhsWeight {
                    return (lhs.reps ?? 0) < (rhs.reps ?? 0)
                }
                return lhsWeight < rhsWeight
            }

            let bestVolumeContribution = weightedContributions.max { lhs, rhs in
                let lhsVolume = (lhs.weight ?? 0) * (lhs.reps ?? 0)
                let rhsVolume = (rhs.weight ?? 0) * (rhs.reps ?? 0)
                return lhsVolume < rhsVolume
            }

            let performance = userProfile.getExercisePerformance(exerciseId: exercise.exercise.id)
            let previousSets = previousBestSets(from: performance)

            if let heaviestContribution,
               let weight = heaviestContribution.weight,
               weight > 0 {
                let reps = Int(round(heaviestContribution.reps ?? 0))
                let previousWeight = previousSets.heaviest?.weight
                if previousWeight == nil || weight > (previousWeight ?? 0) + 0.1 {
                    records.append(PersonalRecord(exerciseId: exercise.exercise.id,
                                                  exerciseName: exercise.exercise.name,
                                                  recordType: .heaviestWeight,
                                                  newValue: weight,
                                                  previousValue: previousWeight,
                                                  weight: weight,
                                                  reps: reps > 0 ? reps : nil,
                                                  previousWeight: previousWeight,
                                                  previousReps: previousSets.heaviest?.reps))
                }
            }

            if let bestVolumeContribution,
               let weight = bestVolumeContribution.weight,
               let repsValue = bestVolumeContribution.reps,
               weight > 0,
               repsValue > 0 {
                let reps = Int(round(repsValue))
                let volume = weight * repsValue
                let previousVolume = previousSets.bestVolume?.volume ?? 0
                if previousSets.bestVolume == nil || volume > previousVolume + 0.1 {
                    records.append(PersonalRecord(exerciseId: exercise.exercise.id,
                                                  exerciseName: exercise.exercise.name,
                                                  recordType: .bestVolume,
                                                  newValue: volume,
                                                  previousValue: previousSets.bestVolume?.volume,
                                                  weight: weight,
                                                  reps: reps > 0 ? reps : nil,
                                                  previousWeight: previousSets.bestVolume?.weight,
                                                  previousReps: previousSets.bestVolume.map { $0.reps }))
                }
            }
        }

        return records
    }

    private func previousBestSets(from performance: ExercisePerformance?) -> (heaviest: (weight: Double, reps: Int)?, bestVolume: (weight: Double, reps: Int, volume: Double)?) {
        guard let performance else { return (nil, nil) }

        let weightedRecords = performance.records.filter { $0.weight > 0 && $0.reps > 0 }

        let heaviestRecord = weightedRecords.max { lhs, rhs in
            if lhs.weight == rhs.weight {
                return lhs.reps < rhs.reps
            }
            return lhs.weight < rhs.weight
        }

        let bestVolumeRecord = weightedRecords.max { lhs, rhs in
            lhs.volume < rhs.volume
        }

        return (heaviestRecord.map { ($0.weight, $0.reps) },
                bestVolumeRecord.map { ($0.weight, $0.reps, $0.volume) })
    }

    // MARK: - Helpers

    private func setContributions(for exercise: TodayWorkoutExercise) -> [SetContribution] {
        if let flexibleSets = exercise.flexibleSets, !flexibleSets.isEmpty {
            let result: [SetContribution] = flexibleSets.enumerated().compactMap { index, set in
                let wasLogged = set.wasLogged ?? set.isCompleted
                if set.isWarmupSet || !wasLogged { return nil }

                switch set.trackingType {
                case .repsWeight:
                    guard let reps = parseDouble(set.reps), reps > 0 else { return nil }
                    if let weight = parseDouble(set.weight), weight > 0 {
                        return SetContribution(index: index,
                                               trackingType: .repsWeight,
                                               reps: reps,
                                               weight: weight,
                                               duration: nil,
                                               distance: nil)
                    } else {
                        return SetContribution(index: index,
                                               trackingType: .repsOnly,
                                               reps: reps,
                                               weight: nil,
                                               duration: nil,
                                               distance: nil)
                    }
                case .repsOnly:
                    guard let reps = parseDouble(set.reps), reps > 0 else { return nil }
                    return SetContribution(index: index,
                                           trackingType: .repsOnly,
                                           reps: reps,
                                           weight: nil,
                                           duration: nil,
                                           distance: nil)
                case .timeOnly, .holdTime:
                    guard let duration = set.duration, duration > 0 else { return nil }
                    return SetContribution(index: index,
                                           trackingType: set.trackingType,
                                           reps: nil,
                                           weight: nil,
                                           duration: duration,
                                           distance: nil)
                case .timeDistance:
                    let duration = set.duration ?? 0
                    let distance = set.distance ?? 0
                    guard duration > 0 || distance > 0 else { return nil }
                    return SetContribution(index: index,
                                           trackingType: .timeDistance,
                                           reps: nil,
                                           weight: nil,
                                           duration: duration > 0 ? duration : nil,
                                           distance: distance > 0 ? distance : nil)
                case .rounds:
                    guard let rounds = set.rounds, rounds > 0 else { return nil }
                    return SetContribution(index: index,
                                           trackingType: .rounds,
                                           reps: Double(rounds),
                                           weight: nil,
                                           duration: nil,
                                           distance: nil)
                }
            }

            if !result.isEmpty {
                return result
            }
        }

        return []
    }

    private func parseDouble(_ string: String?) -> Double? {
        guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "0123456789.,-")
        let filtered = raw.unicodeScalars.filter { allowed.contains($0) }
        guard !filtered.isEmpty else { return nil }
        let normalized = String(String.UnicodeScalarView(filtered)).replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func buildExerciseBreakdown(for workout: TodayWorkout,
                                        personalRecords: [PersonalRecord]) -> [ExerciseBreakdown] {
        let prMap = Dictionary(grouping: personalRecords, by: { $0.exerciseId }).mapValues { records in
            Array(Set(records.map { $0.recordType }))
        }

        var breakdown: [ExerciseBreakdown] = []

        if let warmups = workout.warmUpExercises {
            breakdown.append(contentsOf: warmups.compactMap { exercise in
                buildBreakdownEntry(for: exercise,
                                    section: .warmUp,
                                    prMap: prMap)
            })
        }

        breakdown.append(contentsOf: workout.exercises.compactMap { exercise in
            buildBreakdownEntry(for: exercise,
                                section: .main,
                                prMap: prMap)
        })

        if let cooldowns = workout.coolDownExercises {
            breakdown.append(contentsOf: cooldowns.compactMap { exercise in
                buildBreakdownEntry(for: exercise,
                                    section: .coolDown,
                                    prMap: prMap)
            })
        }

        return breakdown
    }

    private func buildBreakdownEntry(for exercise: TodayWorkoutExercise,
                                     section: WorkoutExerciseSection,
                                     prMap: [Int: [PersonalRecordType]]) -> ExerciseBreakdown? {
        let contributions = setContributions(for: exercise)
        guard !contributions.isEmpty else { return nil }
        let totalSets = contributions.count
        let totalReps = contributions.reduce(0) { $0 + Int(round($1.reps ?? 0)) }

        let heaviestSet = contributions.max { lhs, rhs in
            let lhsWeight = lhs.weight ?? 0
            let rhsWeight = rhs.weight ?? 0
            if lhsWeight == rhsWeight {
                return (lhs.reps ?? 0) < (rhs.reps ?? 0)
            }
            return lhsWeight < rhsWeight
        }

        let bestSetWeight = heaviestSet?.weight
        let bestSetReps = heaviestSet?.reps.flatMap { value -> Int? in
            let reps = Int(round(value))
            return reps > 0 ? reps : nil
        }

        let volume = contributions.reduce(0) { $0 + (($1.reps ?? 0) * ($1.weight ?? 0)) }
        let totalDuration = contributions.compactMap { $0.duration }.reduce(0, +)
        let durationValue = totalDuration > 0 ? totalDuration : nil
        let trackingType = contributions.first?.trackingType ?? exercise.trackingType
        let setSummaries = contributions.map { contribution in
            ExerciseSetSummary(index: contribution.index,
                               trackingType: contribution.trackingType,
                               reps: contribution.reps,
                               weight: contribution.weight,
                               duration: contribution.duration,
                               distance: contribution.distance)
        }

        return ExerciseBreakdown(exercise: exercise.exercise,
                                 section: section,
                                 totalSets: totalSets,
                                 totalReps: totalReps,
                                 bestSetWeight: bestSetWeight,
                                 bestSetReps: bestSetReps,
                                 volume: volume,
                                 totalDuration: durationValue,
                                 trackingType: trackingType,
                                 setSummaries: setSummaries,
                                 personalRecords: prMap[exercise.exercise.id] ?? [])
    }
}
