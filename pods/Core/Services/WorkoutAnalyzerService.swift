//
//  WorkoutAnalyzerService.swift
//  pods
//
//  Created by Dimi Nunez on 1/18/26.
//


//
//  WorkoutAnalyzerService.swift
//  Pods
//
//  Created by Claude Code on 1/18/26.
//

import Foundation

/// Analyzes workout exercises to build fatigue maps and detect movement patterns
class WorkoutAnalyzerService {
    static let shared = WorkoutAnalyzerService()

    private init() {}

    // MARK: - Main Analysis Entry Point

    /// Analyze a workout's exercises to build a complete fatigue map
    func analyzeWorkout(_ exercises: [TodayWorkoutExercise]) -> WorkoutFatigueMap {
        print("📊 WorkoutAnalyzer: Analyzing \(exercises.count) exercises")

        let muscleFatigue = buildMuscleFatigueEntries(from: exercises)
        let movementPatterns = detectMovementPatterns(from: exercises)
        let jointsInvolved = analyzeJointInvolvement(from: exercises)

        // Separate primary (target) and secondary (synergist) muscles
        let primaryMuscles = muscleFatigue
            .filter { $0.isPrimary }
            .sorted { $0.fatigueScore > $1.fatigueScore }
            .map { $0.muscleGroup }

        let secondaryMuscles = muscleFatigue
            .filter { !$0.isPrimary }
            .sorted { $0.fatigueScore > $1.fatigueScore }
            .map { $0.muscleGroup }

        let fatigueMap = WorkoutFatigueMap(
            muscleFatigue: muscleFatigue,
            movementPatterns: movementPatterns,
            jointsInvolved: jointsInvolved,
            primaryMuscles: Array(Set(primaryMuscles)),
            secondaryMuscles: Array(Set(secondaryMuscles))
        )

        logAnalysisResults(fatigueMap)

        return fatigueMap
    }

    // MARK: - Muscle Fatigue Analysis

    private func buildMuscleFatigueEntries(from exercises: [TodayWorkoutExercise]) -> [MuscleFatigueEntry] {
        var fatigueMap: [String: (sets: Int, volume: Double, isPrimary: Bool)] = [:]

        for exercise in exercises {
            let data = exercise.exercise
            let sets = exercise.sets
            let reps = exercise.reps
            let weight = exercise.weight ?? 0
            let volume = Double(sets * reps) * weight

            // Process target muscles (primary)
            let targetMuscles = parseMuscles(from: data.target)
            for muscle in targetMuscles {
                let normalized = MuscleGroupNormalizer.normalize(muscle)
                if var existing = fatigueMap[normalized] {
                    existing.sets += sets
                    existing.volume += volume
                    fatigueMap[normalized] = existing
                } else {
                    fatigueMap[normalized] = (sets: sets, volume: volume, isPrimary: true)
                }
            }

            // Process synergist muscles (secondary)
            let synergistMuscles = parseMuscles(from: data.synergist)
            for muscle in synergistMuscles {
                let normalized = MuscleGroupNormalizer.normalize(muscle)
                if var existing = fatigueMap[normalized] {
                    existing.sets += sets
                    existing.volume += volume * 0.5  // Synergists get less volume credit
                    // Don't override isPrimary if already set
                    fatigueMap[normalized] = existing
                } else {
                    fatigueMap[normalized] = (sets: sets, volume: volume * 0.5, isPrimary: false)
                }
            }

            // Also consider bodyPart as a backup
            let bodyPart = MuscleGroupNormalizer.normalize(data.bodyPart)
            if !bodyPart.isEmpty && fatigueMap[bodyPart] == nil {
                fatigueMap[bodyPart] = (sets: sets, volume: volume, isPrimary: true)
            }
        }

        return fatigueMap.map { key, value in
            MuscleFatigueEntry(
                muscleGroup: key,
                totalSets: value.sets,
                totalVolume: value.volume,
                isPrimary: value.isPrimary
            )
        }.sorted { $0.fatigueScore > $1.fatigueScore }
    }

    // MARK: - Movement Pattern Detection

    private func detectMovementPatterns(from exercises: [TodayWorkoutExercise]) -> [MovementPattern] {
        var detectedPatterns: Set<MovementPattern> = []

        for exercise in exercises {
            let name = exercise.exercise.name.lowercased()
            let bodyPart = exercise.exercise.bodyPart.lowercased()
            let target = exercise.exercise.target.lowercased()

            // Horizontal Push detection
            if isHorizontalPush(name: name, bodyPart: bodyPart) {
                detectedPatterns.insert(.horizontalPush)
            }

            // Vertical Push detection
            if isVerticalPush(name: name, bodyPart: bodyPart) {
                detectedPatterns.insert(.verticalPush)
            }

            // Horizontal Pull detection
            if isHorizontalPull(name: name) {
                detectedPatterns.insert(.horizontalPull)
            }

            // Vertical Pull detection
            if isVerticalPull(name: name) {
                detectedPatterns.insert(.verticalPull)
            }

            // Leg Pressing detection
            if isLegPressing(name: name) {
                detectedPatterns.insert(.legPressing)
            }

            // Leg Hinging detection
            if isLegHinging(name: name) {
                detectedPatterns.insert(.legHinging)
            }

            // Core detection
            if isCore(name: name, bodyPart: bodyPart, target: target) {
                let corePattern = detectCorePattern(name: name)
                detectedPatterns.insert(corePattern)
            }
        }

        return Array(detectedPatterns).sorted { $0.order < $1.order }
    }

    // MARK: - Pattern Detection Helpers

    private func isHorizontalPush(name: String, bodyPart: String) -> Bool {
        return name.contains("bench") ||
               name.contains("push-up") ||
               name.contains("pushup") ||
               (name.contains("press") && (bodyPart.contains("chest") || name.contains("chest"))) ||
               (name.contains("fly") && bodyPart.contains("chest"))
    }

    private func isVerticalPush(name: String, bodyPart: String) -> Bool {
        return name.contains("overhead") ||
               name.contains("shoulder press") ||
               name.contains("military") ||
               name.contains("dip") ||
               (name.contains("press") && bodyPart.contains("shoulder"))
    }

    private func isHorizontalPull(name: String) -> Bool {
        return name.contains("row") ||
               name.contains("cable pull") ||
               (name.contains("pull") && name.contains("seated"))
    }

    private func isVerticalPull(name: String) -> Bool {
        return name.contains("pull-up") ||
               name.contains("pullup") ||
               name.contains("chin-up") ||
               name.contains("lat pulldown") ||
               name.contains("pulldown")
    }

    private func isLegPressing(name: String) -> Bool {
        return name.contains("squat") ||
               name.contains("leg press") ||
               name.contains("lunge") ||
               name.contains("step-up") ||
               name.contains("hack")
    }

    private func isLegHinging(name: String) -> Bool {
        return name.contains("deadlift") ||
               name.contains("rdl") ||
               name.contains("romanian") ||
               name.contains("good morning") ||
               name.contains("hip thrust") ||
               name.contains("glute bridge") ||
               name.contains("back extension")
    }

    private func isCore(name: String, bodyPart: String, target: String) -> Bool {
        return bodyPart.contains("waist") ||
               target.contains("rectus abdominis") ||
               target.contains("obliques") ||
               name.contains("plank") ||
               name.contains("crunch") ||
               name.contains("twist")
    }

    private func detectCorePattern(name: String) -> MovementPattern {
        if name.contains("plank") || name.contains("carry") || name.contains("hollow") {
            return .coreStabilization
        } else if name.contains("twist") || name.contains("rotation") || name.contains("woodchop") {
            return .rotational
        } else {
            return .coreFlexion
        }
    }

    // MARK: - Joint Involvement Analysis

    private func analyzeJointInvolvement(from exercises: [TodayWorkoutExercise]) -> [JointInvolvement] {
        var jointCounts: [Joint: Int] = [:]

        for exercise in exercises {
            let name = exercise.exercise.name.lowercased()
            let bodyPart = exercise.exercise.bodyPart.lowercased()

            for joint in Joint.allCases {
                // Check body part relation
                let isRelatedByBodyPart = joint.relatedBodyParts.contains { bodyPart.contains($0.lowercased()) }

                // Check exercise name patterns
                let isRelatedByPattern = joint.exercisePatterns.contains { name.contains($0.lowercased()) }

                if isRelatedByBodyPart || isRelatedByPattern {
                    jointCounts[joint, default: 0] += 1
                }
            }
        }

        return jointCounts.map { joint, count in
            let intensity: JointInvolvement.JointIntensity
            switch count {
            case 1...2: intensity = .light
            case 3...4: intensity = .moderate
            default: intensity = .heavy
            }
            return JointInvolvement(joint: joint, movementCount: count, intensity: intensity)
        }.sorted { $0.movementCount > $1.movementCount }
    }

    // MARK: - Helper Methods

    private func parseMuscles(from string: String) -> [String] {
        guard !string.isEmpty else { return [] }
        return string.components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func logAnalysisResults(_ fatigueMap: WorkoutFatigueMap) {
        print("📊 ========== WORKOUT ANALYSIS RESULTS ==========")
        print("🎯 Movement Patterns: \(fatigueMap.movementPatterns.map { $0.displayName }.joined(separator: ", "))")
        print("💪 Primary Muscles: \(fatigueMap.primaryMuscles.prefix(5).joined(separator: ", "))")
        print("🔗 Secondary Muscles: \(fatigueMap.secondaryMuscles.prefix(3).joined(separator: ", "))")
        print("🦴 Joints (by involvement):")
        for joint in fatigueMap.jointsInvolved.prefix(3) {
            print("   └── \(joint.joint.displayName): \(joint.intensity.rawValue) (\(joint.movementCount) exercises)")
        }
        print("📊 Focus: \(fatigueMap.isUpperBodyFocused ? "Upper Body" : fatigueMap.isLowerBodyFocused ? "Lower Body" : "Full Body")")
        print("📊 ================================================")
    }
}

// MARK: - Convenience Extensions

extension WorkoutAnalyzerService {

    /// Quick check if workout targets specific body region
    func isUpperBodyWorkout(_ exercises: [TodayWorkoutExercise]) -> Bool {
        let fatigueMap = analyzeWorkout(exercises)
        return fatigueMap.isUpperBodyFocused
    }

    func isLowerBodyWorkout(_ exercises: [TodayWorkoutExercise]) -> Bool {
        let fatigueMap = analyzeWorkout(exercises)
        return fatigueMap.isLowerBodyFocused
    }

    /// Get the most heavily used muscles from a workout
    func getTopMuscles(_ exercises: [TodayWorkoutExercise], count: Int = 3) -> [String] {
        let fatigueMap = analyzeWorkout(exercises)
        return fatigueMap.topFatiguedMuscles(count: count)
    }

    /// Get detected movement patterns for a workout
    func getMovementPatterns(_ exercises: [TodayWorkoutExercise]) -> [MovementPattern] {
        let fatigueMap = analyzeWorkout(exercises)
        return fatigueMap.movementPatterns
    }
}
