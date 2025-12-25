import XCTest
@testable import pods

final class HypertrophyGenerationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        FeatureFlags.setUseLLMForWorkoutGeneration(false)
        UserDefaults.standard.set("test@example.com", forKey: "userEmail")
    }

    func testHypertrophyGymEquipmentPrefersLoadableOverBands() throws {
        let svc = WorkoutGenerationService.shared
        let plan = try svc.generateWorkoutPlan(
            muscleGroups: ["Chest", "Back"],
            targetDuration: .oneHour,
            fitnessGoal: .hypertrophy,
            experienceLevel: .intermediate,
            customEquipment: [.dumbbells, .barbells],
            flexibilityPreferences: FlexibilityPreferences()
        )
        let exercises = plan.exercises.map { $0.exercise }
        let bandCount = exercises.filter { $0.equipment.localizedCaseInsensitiveContains("band") }.count
        XCTAssertGreaterThanOrEqual(exercises.count, 6)
        XCTAssertLessThanOrEqual(bandCount, 1)
        XCTAssertTrue(exercises.contains { !$0.equipment.localizedCaseInsensitiveContains("band") })
    }

    func testHypertrophyBandsOnlyAllowsBands() throws {
        let svc = WorkoutGenerationService.shared
        let plan = try svc.generateWorkoutPlan(
            muscleGroups: ["Chest", "Back"],
            targetDuration: .oneHour,
            fitnessGoal: .hypertrophy,
            experienceLevel: .beginner,
            customEquipment: [.resistanceBands],
            flexibilityPreferences: FlexibilityPreferences()
        )
        let exercises = plan.exercises.map { $0.exercise }
        XCTAssertGreaterThanOrEqual(exercises.count, 3)
        XCTAssertTrue(exercises.contains { $0.equipment.localizedCaseInsensitiveContains("band") })
    }

    func testOneHourGeneratesAdequateVolume() throws {
        let svc = WorkoutGenerationService.shared
        let plan = try svc.generateWorkoutPlan(
            muscleGroups: ["Chest", "Back"],
            targetDuration: .oneHour,
            fitnessGoal: .strength,
            experienceLevel: .intermediate,
            customEquipment: [.dumbbells, .barbells],
            flexibilityPreferences: FlexibilityPreferences()
        )
        XCTAssertGreaterThanOrEqual(plan.exercises.count, 6)
    }
}
