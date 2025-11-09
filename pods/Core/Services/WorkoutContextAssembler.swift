//
//  WorkoutContextAssembler.swift
//  pods
//
//  Created by Dimi Nunez on 11/4/25.
//


//
//  WorkoutContextAssembler.swift
//

import Foundation

@MainActor
struct WorkoutContextAssembler {
    private let userProfileService = UserProfileService.shared
    private let feedbackService = PerformanceFeedbackService.shared
    private let repository = WorkoutContextRepository.shared

    func assembleContext(
        userEmail: String,
        requestedMuscles: [String],
        duration: WorkoutDuration,
        equipmentOverride: [Equipment]?,
        sessionPhase: SessionPhase,
        flexibilityPreferences: FlexibilityPreferences
    ) -> WorkoutContextV1 {
        let profile = userProfileService

        let resolvedEquipment = equipmentOverride ?? profile.availableEquipment
        let equipmentSource = equipmentOverride == nil ? "profile" : "session_override"
        let equipmentSummary = resolvedEquipment.isEmpty ? "[bodyweight-only]" : resolvedEquipment.map { $0.rawValue }.joined(separator: ", ")
        print("🧾 WorkoutContextAssembler: using \(equipmentSource) equipment → \(equipmentSummary)")

        let userSection = WorkoutContextV1.UserSection(
            email: userEmail,
            fitnessGoal: profile.fitnessGoal.normalized,
            experienceLevel: profile.experienceLevel,
            gender: profile.gender,
            preferredSplit: profile.trainingSplit,
            workoutFrequency: profile.workoutFrequency,
            typicalDurationMinutes: profile.workoutDuration.minutes,
            timezoneOffsetMinutes: TimeZone.current.secondsFromGMT() / 60
        )

        let effectiveBodyweightOnly: Bool = {
            if let override = equipmentOverride {
                return override.isEmpty
            }
            return profile.bodyweightOnlyWorkouts
        }()

        let preferences = WorkoutContextV1.PreferenceSection(
            availableEquipment: resolvedEquipment,
            bodyweightOnly: effectiveBodyweightOnly,
            dislikes: profile.avoidedExercises,
            preferredExerciseTypes: profile.preferredExerciseTypes,
            injuriesOrLimitations: [], // Placeholder until onboarding captures injuries explicitly
            scheduleConstraintsMinutes: duration.minutes,
            allowTimedWork: flexibilityPreferences.isEnabled
        )

        let historySection = buildHistorySection(durationMinutes: duration.minutes)

        let constraintSection = WorkoutContextV1.ConstraintSection(
            requestedMuscles: requestedMuscles,
            requestedDurationMinutes: duration.minutes,
            availableEquipment: resolvedEquipment,
            seed: UUID(),
            generatedAt: Date(),
            sessionPhase: sessionPhase,
            flexibilityPreferences: flexibilityPreferences
        )

        let metadata = WorkoutContextV1.Metadata(
            schemaVersion: WorkoutContextV1.schemaVersion,
            generatedAt: Date(),
            source: "ios"
        )

        let context = WorkoutContextV1(
            user: userSection,
            preferences: preferences,
            recovery: nil,
            history: historySection,
            constraints: constraintSection,
            metadata: metadata
        )

        repository.saveContext(context, for: userEmail)
        print("🧾 WorkoutContextAssembler: persisted context for \(userEmail) with \(resolvedEquipment.count) equipment entries")
        return context
    }

    private func buildHistorySection(durationMinutes: Int) -> WorkoutContextV1.HistorySection {
        let feedback = feedbackService.feedbackHistory
        let recentSessions = feedback.suffix(8).map { entry -> WorkoutContextV1.HistorySection.Session in
            let duration = Int(Double(durationMinutes) * entry.completionRate)
            return WorkoutContextV1.HistorySection.Session(
                id: entry.workoutId,
                date: entry.timestamp,
                durationMinutes: max(duration, 10),
                targetMuscles: [],
                totalVolume: 0,
                averageRPE: entry.overallRPE
            )
        }

        return WorkoutContextV1.HistorySection(
            recentSessions: Array(recentSessions),
            prs: []
        )
    }
}
