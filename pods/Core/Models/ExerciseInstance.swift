// FILE: Models/ExerciseInstance.swift
import Foundation
import SwiftData

@Model
class ExerciseInstance {
    var id: UUID
    var exerciseId: Int
    var exerciseName: String
    var exerciseType: String
    var bodyPart: String
    var equipment: String
    var target: String
    var sets: [SetInstance]
    var workoutSession: WorkoutSession?
    var orderIndex: Int
    
    init(exerciseId: Int, exerciseName: String, exerciseType: String, bodyPart: String, equipment: String, target: String, orderIndex: Int) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.exerciseType = exerciseType
        self.bodyPart = bodyPart
        self.equipment = equipment
        self.target = target
        self.sets = []
        self.orderIndex = orderIndex
    }
    
    // Convenience initializer from ExerciseData
    convenience init(from exerciseData: ExerciseData, orderIndex: Int) {
        self.init(
            exerciseId: exerciseData.id,
            exerciseName: exerciseData.name,
            exerciseType: exerciseData.exerciseType,
            bodyPart: exerciseData.bodyPart,
            equipment: exerciseData.equipment,
            target: exerciseData.target,
            orderIndex: orderIndex
        )
    }
    
    var completedSets: Int {
        sets.filter { $0.isCompleted }.count
    }
    
    var totalSets: Int {
        sets.count
    }
    
    var isCompleted: Bool {
        !sets.isEmpty && sets.allSatisfy { $0.isCompleted }
    }
    
    // Helper method to add a set with default values
    func addSet(targetReps: Int, targetWeight: Double? = nil) {
        let setNumber = sets.count + 1
        let newSet = SetInstance(setNumber: setNumber, targetReps: targetReps, targetWeight: targetWeight)
        newSet.exerciseInstance = self
        sets.append(newSet)
    }
    
    // Helper method to remove a set
    func removeSet(at index: Int) {
        guard index >= 0 && index < sets.count else { return }
        sets.remove(at: index)
        // Reorder remaining sets
        for (i, set) in sets.enumerated() {
            set.setNumber = i + 1
        }
    }
}