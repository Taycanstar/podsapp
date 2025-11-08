//
//  SetScheme.swift
//  pods
//
//  Created by Dimi Nunez on 11/7/25.
//


//
//  SetSchemePlanner.swift
//  Pods
//
//  Created by Codex on 2/10/26.
//

import Foundation

/// Canonical representation of a set/rep prescription for a single exercise.
struct SetScheme {
    let sets: Int
    let repRange: ClosedRange<Int>
    let targetReps: Int
    let restSeconds: Int
    let loadPercentage: ClosedRange<Int>?
    let targetRPE: ClosedRange<Double>?
    let overrideReason: String?
}

/// Optional hints coming from another system (e.g., LLM suggestions).
struct SetSchemeSuggestion {
    let sets: Int?
    let reps: Int?
}

/// Planner that turns research-backed rules + recovery signals into exact set prescriptions.
@MainActor
final class SetSchemePlanner {
    static let shared = SetSchemePlanner()

    private struct SchemeTemplate {
        let compoundSets: ClosedRange<Int>
        let accessorySets: ClosedRange<Int>
        let repRange: ClosedRange<Int>
        let restSeconds: ClosedRange<Int>
        let loadPercent: ClosedRange<Int>?
        let rpeRange: ClosedRange<Double>?
    }

    private struct GoalTemplate {
        let novice: SchemeTemplate
        let intermediate: SchemeTemplate
        let advanced: SchemeTemplate

        func template(for experience: ExperienceLevel) -> SchemeTemplate {
            switch experience {
            case .beginner: return novice
            case .intermediate: return intermediate
            case .advanced: return advanced
            }
        }
    }

    private let feedbackService = PerformanceFeedbackService.shared

    private lazy var templates: [FitnessGoal: GoalTemplate] = {
        return [
            .hypertrophy: GoalTemplate(
                novice: SchemeTemplate(
                    compoundSets: 2...3,
                    accessorySets: 2...3,
                    repRange: 8...12,
                    restSeconds: 60...90,
                    loadPercent: 65...75,
                    rpeRange: 6...8
                ),
                intermediate: SchemeTemplate(
                    compoundSets: 3...4,
                    accessorySets: 3...4,
                    repRange: 6...12,
                    restSeconds: 90...120,
                    loadPercent: 70...85,
                    rpeRange: 6...9
                ),
                advanced: SchemeTemplate(
                    compoundSets: 4...6,
                    accessorySets: 3...5,
                    repRange: 5...15,
                    restSeconds: 90...120,
                    loadPercent: 70...100,
                    rpeRange: 5...10
                )
            ),
            .strength: GoalTemplate(
                novice: SchemeTemplate(
                    compoundSets: 3...5,
                    accessorySets: 2...4,
                    repRange: 3...5,
                    restSeconds: 120...180,
                    loadPercent: 75...85,
                    rpeRange: 8...9
                ),
                intermediate: SchemeTemplate(
                    compoundSets: 4...6,
                    accessorySets: 3...4,
                    repRange: 2...5,
                    restSeconds: 180...300,
                    loadPercent: 80...90,
                    rpeRange: 9...10
                ),
                advanced: SchemeTemplate(
                    compoundSets: 5...8,
                    accessorySets: 3...5,
                    repRange: 1...4,
                    restSeconds: 180...300,
                    loadPercent: 85...100,
                    rpeRange: 9...10
                )
            ),
            .powerlifting: GoalTemplate(
                novice: SchemeTemplate(
                    compoundSets: 4...5,
                    accessorySets: 3...4,
                    repRange: 3...5,
                    restSeconds: 180...240,
                    loadPercent: 75...85,
                    rpeRange: 8...9
                ),
                intermediate: SchemeTemplate(
                    compoundSets: 5...7,
                    accessorySets: 3...4,
                    repRange: 2...4,
                    restSeconds: 240...360,
                    loadPercent: 85...95,
                    rpeRange: 9...10
                ),
                advanced: SchemeTemplate(
                    compoundSets: 6...8,
                    accessorySets: 3...5,
                    repRange: 1...3,
                    restSeconds: 240...420,
                    loadPercent: 88...100,
                    rpeRange: 9...10
                )
            ),
            .olympicWeightlifting: GoalTemplate(
                novice: SchemeTemplate(
                    compoundSets: 3...4,
                    accessorySets: 2...3,
                    repRange: 3...5,
                    restSeconds: 180...240,
                    loadPercent: 70...80,
                    rpeRange: 7...8
                ),
                intermediate: SchemeTemplate(
                    compoundSets: 4...6,
                    accessorySets: 3...4,
                    repRange: 2...4,
                    restSeconds: 180...300,
                    loadPercent: 80...90,
                    rpeRange: 8...9
                ),
                advanced: SchemeTemplate(
                    compoundSets: 5...7,
                    accessorySets: 3...5,
                    repRange: 1...3,
                    restSeconds: 240...300,
                    loadPercent: 85...100,
                    rpeRange: 9...10
                )
            ),
            .circuitTraining: GoalTemplate(
                novice: SchemeTemplate(
                    compoundSets: 2...3,
                    accessorySets: 2...3,
                    repRange: 12...20,
                    restSeconds: 30...60,
                    loadPercent: 50...65,
                    rpeRange: 6...8
                ),
                intermediate: SchemeTemplate(
                    compoundSets: 3...4,
                    accessorySets: 3...4,
                    repRange: 15...25,
                    restSeconds: 30...60,
                    loadPercent: 60...75,
                    rpeRange: 7...9
                ),
                advanced: SchemeTemplate(
                    compoundSets: 3...5,
                    accessorySets: 3...5,
                    repRange: 20...30,
                    restSeconds: 20...45,
                    loadPercent: 60...80,
                    rpeRange: 8...10
                )
            ),
            .general: GoalTemplate(
                novice: SchemeTemplate(
                    compoundSets: 2...3,
                    accessorySets: 2...3,
                    repRange: 8...12,
                    restSeconds: 60...90,
                    loadPercent: 60...70,
                    rpeRange: 6...8
                ),
                intermediate: SchemeTemplate(
                    compoundSets: 3...4,
                    accessorySets: 3...4,
                    repRange: 8...12,
                    restSeconds: 60...90,
                    loadPercent: 65...80,
                    rpeRange: 6...8
                ),
                advanced: SchemeTemplate(
                    compoundSets: 3...5,
                    accessorySets: 3...4,
                    repRange: 6...12,
                    restSeconds: 60...120,
                    loadPercent: 70...85,
                    rpeRange: 6...9
                )
            )
        ]
    }()

    private init() {}

    func scheme(
        for exercise: ExerciseData,
        goal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        sessionPhase _: SessionPhase,
        isCompound: Bool,
        suggestion: SetSchemeSuggestion? = nil
    ) -> SetScheme {
        let normalizedGoal = goal.normalized
        let template = templates[normalizedGoal]?.template(for: experienceLevel)
            ?? templates[.hypertrophy]!.template(for: .beginner)

        let baseRange = isCompound ? template.compoundSets : template.accessorySets
        var targetSets = deriveSets(
            from: baseRange,
            suggestion: suggestion?.sets
        )

        targetSets = clamp(targetSets, within: baseRange)
        targetSets = applyFatigue(to: targetSets)

        let repRange = adjustRepRange(template.repRange, goal: normalizedGoal)
        let targetReps = clamp(
            suggestion?.reps ?? defaultReps(for: repRange, goal: normalizedGoal),
            within: repRange
        )

        var overrideReasons: [String] = []
        if let suggestedSets = suggestion?.sets,
           suggestedSets != targetSets {
            overrideReasons.append("sets_adjusted")
        }
        if let suggestedReps = suggestion?.reps,
           !repRange.contains(suggestedReps) {
            overrideReasons.append("reps_adjusted")
        }

        let restSeconds = adjustRest(template.restSeconds, isCompound: isCompound, goal: normalizedGoal)

        return SetScheme(
            sets: targetSets,
            repRange: repRange,
            targetReps: targetReps,
            restSeconds: restSeconds,
            loadPercentage: template.loadPercent,
            targetRPE: template.rpeRange,
            overrideReason: overrideReasons.isEmpty ? nil : overrideReasons.joined(separator: ",")
        )
    }

    // MARK: - Helpers

    private func deriveSets(
        from range: ClosedRange<Int>,
        suggestion: Int?
    ) -> Int {
        return suggestion ?? midpoint(of: range)
    }

    private func adjustRepRange(_ base: ClosedRange<Int>, goal: FitnessGoal) -> ClosedRange<Int> {
        switch goal.normalized {
        case .strength, .powerlifting, .olympicWeightlifting:
            let lower = max(1, base.lowerBound - 2)
            let upper = max(lower, base.lowerBound + 2)
            return lower...upper
        case .circuitTraining, .endurance:
            let lower = base.lowerBound + 2
            let upper = base.upperBound + 4
            return lower...upper
        default:
            return base
        }
    }

    private func adjustRest(_ base: ClosedRange<Int>, isCompound: Bool, goal: FitnessGoal) -> Int {
        switch goal.normalized {
        case .strength, .powerlifting, .olympicWeightlifting:
            return isCompound ? base.upperBound : midpoint(of: base)
        case .circuitTraining, .endurance:
            return base.lowerBound
        default:
            return midpoint(of: base)
        }
    }

    private func applyFatigue(to sets: Int) -> Int {
        var multiplier = 1.0
        if feedbackService.shouldRecommendDeload() {
            multiplier = 0.6
        } else if let metrics = feedbackService.performanceMetrics {
            if metrics.averageRPE > 8.5 {
                multiplier = 0.85
            } else if metrics.averageRPE < 6.0 && metrics.trend == .improving {
                multiplier = 1.1
            }
        }
        return max(1, Int(round(Double(sets) * multiplier)))
    }

    private func defaultReps(for range: ClosedRange<Int>, goal: FitnessGoal) -> Int {
        switch goal.normalized {
        case .strength, .powerlifting, .olympicWeightlifting:
            return max(range.lowerBound, min(range.upperBound, range.lowerBound + 1))
        case .circuitTraining, .endurance:
            return range.upperBound - 1
        default:
            return midpoint(of: range)
        }
    }

    private func midpoint(of range: ClosedRange<Int>) -> Int {
        return (range.lowerBound + range.upperBound) / 2
    }

    private func clamp(_ value: Int, within range: ClosedRange<Int>) -> Int {
        return min(range.upperBound, max(range.lowerBound, value))
    }

    nonisolated static func isCompoundExercise(_ exercise: ExerciseData) -> Bool {
        let keywords = ["squat", "deadlift", "press", "row", "pull", "clean", "snatch", "lunge"]
        let name = exercise.name.lowercased()
        return keywords.contains { name.contains($0) }
    }
}
