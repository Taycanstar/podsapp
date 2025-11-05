//
//  TimeEstimatorTests.swift
//  podsTests
//

import XCTest
@testable import pods

final class TimeEstimatorTests: XCTestCase {

    func testSessionBudgetRespectsShortDuration() {
        let budget = TimeEstimator.shared.makeSessionBudget(
            duration: .thirtyMinutes,
            fitnessGoal: .hypertrophy,
            experienceLevel: .intermediate,
            preferences: FlexibilityPreferences(warmUpEnabled: true, coolDownEnabled: true)
        )

        XCTAssertEqual(budget.warmupSeconds, 4 * 60)
        XCTAssertEqual(budget.cooldownSeconds, 3 * 60)
        XCTAssertEqual(budget.bufferSeconds, 60)
        XCTAssertEqual(budget.availableWorkSeconds, 30 * 60 - (4 * 60) - (3 * 60) - 60)
        XCTAssertEqual(budget.format, .superset)
    }

    func testOptimalExerciseCountScalesWithDuration() {
        let service = WorkoutRecommendationService.shared
        let short = service.getOptimalExerciseCount(
            duration: .thirtyMinutes,
            fitnessGoal: .hypertrophy,
            muscleGroupCount: 3,
            experienceLevel: .beginner,
            equipment: nil,
            flexibilityPreferences: nil
        )
        let long = service.getOptimalExerciseCount(
            duration: .oneAndHalfHours,
            fitnessGoal: .hypertrophy,
            muscleGroupCount: 3,
            experienceLevel: .beginner,
            equipment: nil,
            flexibilityPreferences: nil
        )

        XCTAssertLessThan(short.total, long.total)
        XCTAssertLessThanOrEqual(short.perMuscle, long.perMuscle)
        XCTAssertGreaterThan(long.total, 0)
    }
}
