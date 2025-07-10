
import Foundation
import SwiftData

@Model
class Exercise {
    @Attribute var id: Int
    @Attribute var name: String
    @Attribute var exerciseType: String
    @Attribute var bodyPart: String
    @Attribute var equipment: String
    @Attribute var gender: String
    @Attribute var target: String
    @Attribute var synergist: String
    @Attribute var createdAt: Date
    
    init(id: Int, name: String, exerciseType: String, bodyPart: String, equipment: String, gender: String, target: String, synergist: String) {
        self.id = id
        self.name = name
        self.exerciseType = exerciseType
        self.bodyPart = bodyPart
        self.equipment = equipment
        self.gender = gender
        self.target = target
        self.synergist = synergist
        self.createdAt = Date()
    }
    
    // Computed properties for compatibility with ExerciseData
    var muscle: String { bodyPart }
    var category: String { equipment }
    var instructions: String? { target.isEmpty ? nil : target }
    
    // Helper method to convert from ExerciseData
    static func fromExerciseData(_ exerciseData: ExerciseData) -> Exercise {
        return Exercise(
            id: exerciseData.id,
            name: exerciseData.name,
            exerciseType: exerciseData.exerciseType,
            bodyPart: exerciseData.bodyPart,
            equipment: exerciseData.equipment,
            gender: exerciseData.gender,
            target: exerciseData.target,
            synergist: exerciseData.synergist
        )
    }
}