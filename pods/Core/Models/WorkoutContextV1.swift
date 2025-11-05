//
//  WorkoutContextV1.swift
//  pods
//
//  Created by Dimi Nunez on 11/4/25.
//


//
//  WorkoutContextV1.swift
//  Pods
//
//  Created by Codex on 2/9/26.
//
//  Canonical schema describing the full workout generation context that both
//  the deterministic engine and LLM prompts share. The goal is to keep a single
//  source of truth for every signal (profile data, recovery, preferences,
//  history, constraints) so new generation strategies can rely on the same
//  payload without duplicating fetches or risking drift.
//

import Foundation

/// Normalized workout context snapshot persisted in the TTL onboarding store and
/// sent to the backend / LLM pipeline when requesting a recommendation.
struct WorkoutContextV1: Codable {
    static let schemaVersion = 1

    struct UserSection: Codable {
        let email: String
        let fitnessGoal: FitnessGoal
        let experienceLevel: ExperienceLevel
        let gender: Gender
        let preferredSplit: TrainingSplitPreference
        let workoutFrequency: WorkoutFrequency
        let typicalDurationMinutes: Int
        let timezoneOffsetMinutes: Int
    }

    struct PreferenceSection: Codable {
        let availableEquipment: [Equipment]
        let bodyweightOnly: Bool
        let dislikes: [Int]
        let preferredExerciseTypes: [ExerciseType]
        let injuriesOrLimitations: [String]
        let scheduleConstraintsMinutes: Int
        let allowTimedWork: Bool
    }

    struct RecoverySection: Codable {
        struct MuscleSnapshot: Codable {
            let name: String
            let recoveryPercent: Double
            let estimatedReadyInHours: Double
        }

        let muscles: [MuscleSnapshot]
        let readinessScore: Double?
        let hrvScore: Double?
        let sleepHours: Double?
        let lastUpdated: Date
    }

    struct HistorySection: Codable {
        struct Session: Codable {
            let id: UUID
            let date: Date
            let durationMinutes: Int
            let targetMuscles: [String]
            let totalVolume: Double
            let averageRPE: Double?
        }

        struct PersonalRecord: Codable {
            let exerciseId: Int
            let exerciseName: String
            let value: Double
            let metric: String
            let achievedOn: Date
        }

        let recentSessions: [Session]
        let prs: [PersonalRecord]
    }

    struct ConstraintSection: Codable {
        let requestedMuscles: [String]
        let requestedDurationMinutes: Int
        let availableEquipment: [Equipment]
        let seed: UUID
        let generatedAt: Date
        let sessionPhase: SessionPhase
        let flexibilityPreferences: FlexibilityPreferences
    }

    struct Metadata: Codable {
        let schemaVersion: Int
        let generatedAt: Date
        let source: String
    }

    let user: UserSection
    let preferences: PreferenceSection
    let recovery: RecoverySection
    let history: HistorySection
    let constraints: ConstraintSection
    let metadata: Metadata

    /// Produce a trimmed copy that keeps only the most recent sessions to reduce
    /// serialization cost when embedding the payload inside requests.
    func trimmingHistory(maxSessions: Int) -> WorkoutContextV1 {
        guard history.recentSessions.count > maxSessions else { return self }
        let trimmedSessions = Array(history.recentSessions.suffix(maxSessions))
        let trimmedHistory = HistorySection(recentSessions: trimmedSessions, prs: history.prs)
        return WorkoutContextV1(
            user: user,
            preferences: preferences,
            recovery: recovery,
            history: trimmedHistory,
            constraints: constraints,
            metadata: metadata
        )
    }
}
