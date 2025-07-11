// FILE: Models/SetInstance.swift
import Foundation
import SwiftData

@Model
class SetInstance {
    var id: UUID
    var setNumber: Int
    var targetReps: Int
    var actualReps: Int?
    var targetWeight: Double?
    var actualWeight: Double?
    var isCompleted: Bool
    var notes: String?
    var exerciseInstance: ExerciseInstance?
    
    // Additional properties for sync compatibility
    var completed: Bool { isCompleted } // Computed property for backward compatibility
    var completedAt: Date?
    
    init(setNumber: Int, targetReps: Int, targetWeight: Double? = nil) {
        self.id = UUID()
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.isCompleted = false
        self.notes = nil
        self.completedAt = nil
    }
    
    var displayWeight: String {
        if let weight = actualWeight ?? targetWeight {
            return String(format: "%.1f", weight)
        }
        return "0"
    }
    
    var displayReps: String {
        if let reps = actualReps {
            return "\(reps)"
        }
        return "\(targetReps)"
    }
    
    // Helper method to mark set as completed
    func completeSet(actualReps: Int, actualWeight: Double? = nil, notes: String? = nil) {
        self.actualReps = actualReps
        self.actualWeight = actualWeight
        self.notes = notes
        self.isCompleted = true
        self.completedAt = Date()
    }
    
    // Helper method to reset set
    func resetSet() {
        self.actualReps = nil
        self.actualWeight = nil
        self.notes = nil
        self.isCompleted = false
        self.completedAt = nil
    }
    
    // Helper method to update target values
    func updateTargets(targetReps: Int, targetWeight: Double? = nil) {
        self.targetReps = targetReps
        self.targetWeight = targetWeight
    }
}