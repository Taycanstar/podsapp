import XCTest
@testable import pods

final class WorkoutSessionStateTests: XCTestCase {
    func testReorderPersistsAcrossManager() {
        let manager = WorkoutManager.shared
        let original = manager.todayWorkout

        let ex1 = TodayWorkoutExercise(exercise: ExerciseData(id: 1, name: "A", exerciseType: "Strength", bodyPart: "Chest", equipment: "Dumbbells", gender: "Both", target: "Chest", synergist: ""), sets: 3, reps: 8, weight: 50, restTime: 90)
        let ex2 = TodayWorkoutExercise(exercise: ExerciseData(id: 2, name: "B", exerciseType: "Strength", bodyPart: "Back", equipment: "Barbells", gender: "Both", target: "Back", synergist: ""), sets: 3, reps: 8, weight: 60, restTime: 90)
        let workout = TodayWorkout(id: UUID(), date: Date(), title: "Test", exercises: [ex1, ex2], estimatedDuration: 30, fitnessGoal: .strength, difficulty: 3, warmUpExercises: nil, coolDownExercises: nil)

        manager.setTodayWorkout(workout)
        manager.reorderMainExercises(fromOffsets: IndexSet(integer: 0), toOffset: 1)

        XCTAssertEqual(manager.todayWorkout?.exercises.first?.exercise.id, 2)

        if let original {
            manager.setTodayWorkout(original)
        }
    }

    func testFlexibleSetToggleMarksLogged() {
        var set = FlexibleSetData(trackingType: .timeOnly)
        XCTAssertFalse(set.isCompleted)
        XCTAssertNil(set.wasLogged)

        set.toggleCompletion()
        XCTAssertTrue(set.isCompleted)
        XCTAssertEqual(set.wasLogged, true)

        set.toggleCompletion()
        XCTAssertFalse(set.isCompleted)
        XCTAssertEqual(set.wasLogged, false)
    }

    func testActiveWorkoutSnapshotRestores() {
        let manager = WorkoutManager.shared
        let exercise = TodayWorkoutExercise(
            exercise: ExerciseData(id: 10, name: "Test", exerciseType: "Strength", bodyPart: "Chest", equipment: "Dumbbells", gender: "Both", target: "Chest", synergist: ""),
            sets: 3,
            reps: 8,
            weight: 50,
            restTime: 90
        )
        let workout = TodayWorkout(
            id: UUID(),
            date: Date(),
            title: "Snapshot",
            exercises: [exercise],
            estimatedDuration: 30,
            fitnessGoal: .strength,
            difficulty: 3,
            warmUpExercises: nil,
            coolDownExercises: nil
        )
        manager.setTodayWorkout(workout)
        manager.startWorkout(workout)
        manager.debugRestoreActiveWorkoutSnapshot() // ensure no crash when called
        manager.cancelActiveWorkout()
    }
}
