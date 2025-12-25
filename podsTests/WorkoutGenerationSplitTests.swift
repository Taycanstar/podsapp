import XCTest
@testable import pods

final class WorkoutGenerationSplitTests: XCTestCase {
    func testPlannedMusclesPushPullLowerCyclesThroughDays() {
        let svc = WorkoutGenerationService.shared
        let sunday = date(year: 2024, month: 12, day: 1) // Sunday
        let monday = date(year: 2024, month: 12, day: 2)
        let tuesday = date(year: 2024, month: 12, day: 3)

        XCTAssertEqual(svc.plannedMuscles(for: .pushPullLower, on: sunday), ["Chest", "Shoulders", "Triceps"])
        XCTAssertEqual(svc.plannedMuscles(for: .pushPullLower, on: monday), ["Back", "Biceps"])
        XCTAssertTrue(svc.plannedMuscles(for: .pushPullLower, on: tuesday).contains("Quadriceps"))
    }

    func testHypertrophyPrioritizesLoadableOverBands() {
        let svc = WorkoutGenerationService.shared
        let band = ExerciseData(id: 1, name: "Band Curl", exerciseType: "Strength", bodyPart: "Arms", equipment: "Resistance Band", gender: "Both", target: "Biceps", synergist: "")
        let dumbbell = ExerciseData(id: 2, name: "DB Curl", exerciseType: "Strength", bodyPart: "Arms", equipment: "Dumbbells", gender: "Both", target: "Biceps", synergist: "")

        let sorted = svc.prioritizeHypertrophyExercises([band, dumbbell], fitnessGoal: .hypertrophy, customEquipment: [.dumbbells])
        XCTAssertEqual(sorted.first?.name, "DB Curl")
    }

    // MARK: - Helpers
    private func date(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.calendar = Calendar.current
        return comps.date ?? Date()
    }
}
