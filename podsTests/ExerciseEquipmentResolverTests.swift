import XCTest
@testable import pods

final class ExerciseEquipmentResolverTests: XCTestCase {
    private let resolver = ExerciseEquipmentResolver.shared

    func testBenchExercisesRequireBenchEquipment() {
        let benchPress = makeExercise(name: "Barbell Bench Press", equipment: "Barbell")
        let equipment = resolver.equipment(for: benchPress)

        XCTAssertTrue(equipment.contains(.barbells), "Bench press should still require barbells")
        XCTAssertTrue(equipment.contains(.flatBench), "Bench press should also require a flat bench")
    }

    func testPVCExercisesRequirePVCEquipment() {
        let pvcGoodMorning = makeExercise(name: "PVC Good Morning", equipment: "")
        let equipment = resolver.equipment(for: pvcGoodMorning)

        XCTAssertTrue(equipment.contains(.pvc), "PVC movements should flag PVC equipment")
    }

    func testMedicineBallExercisesRequireMedicineBall() {
        let medBallLunge = makeExercise(name: "Medicine Ball Lunge with Biceps Curl", equipment: "")
       let equipment = resolver.equipment(for: medBallLunge)

        XCTAssertTrue(equipment.contains(.medicineBalls), "Medicine ball work should require medicine ball equipment")
    }

    func testLandmineExercisesRequireBarbellAndRack() {
        let landmineLunge = makeExercise(name: "Landmine Rear Lunge", equipment: "")
        let equipment = resolver.equipment(for: landmineLunge)

        XCTAssertTrue(equipment.contains(.barbells), "Landmine work must flag the barbell requirement")
        XCTAssertTrue(equipment.contains(.squatRack), "Landmine work should also require a squat rack/anchor point")
    }

    func testSmithMachineExercisesRequireSmithMachine() {
        let smithRow = makeExercise(name: "Smith Bent Over Row", equipment: "")
        let equipment = resolver.equipment(for: smithRow)

        XCTAssertTrue(equipment.contains(.smithMachine), "Smith variations must require the Smith Machine")
    }

    private func makeExercise(
        id: Int = 1,
        name: String,
        equipment: String,
        exerciseType: String = "strength",
        bodyPart: String = "Chest"
    ) -> ExerciseData {
        ExerciseData(
            id: id,
            name: name,
            exerciseType: exerciseType,
            bodyPart: bodyPart,
            equipment: equipment,
            gender: "Male",
            target: "",
            synergist: ""
        )
    }
}
