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
    var durationSeconds: Int?
    var distanceMeters: Double?
    var trackingTypeRawValue: String?

    // Additional properties for sync compatibility with Django
    var completed: Bool { isCompleted } // Computed property for backward compatibility
    var completedAt: Date?

    // Extended fields matching Django ExerciseSet model
    var rpe: Int?                    // Rate of Perceived Exertion (1-10)
    var heartRateBpm: Int?           // Heart rate during set
    var intensityZone: Int?          // Training intensity zone (1-5)
    var stretchIntensity: Int?       // For stretching exercises
    var rangeOfMotionNotes: String?  // Notes about ROM
    var restSeconds: Int?            // Rest time after set
    var paceSecondsPerKm: Int?       // Pace for cardio exercises
    var roundsCompleted: Int?        // For circuit/rounds tracking

    init(setNumber: Int, targetReps: Int, targetWeight: Double? = nil) {
        self.id = UUID()
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.isCompleted = false
        self.notes = nil
        self.completedAt = nil
        self.durationSeconds = nil
        self.distanceMeters = nil
        self.trackingTypeRawValue = nil
        self.rpe = nil
        self.heartRateBpm = nil
        self.intensityZone = nil
        self.stretchIntensity = nil
        self.rangeOfMotionNotes = nil
        self.restSeconds = nil
        self.paceSecondsPerKm = nil
        self.roundsCompleted = nil
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

    var trackingType: ExerciseTrackingType? {
        get { trackingTypeRawValue.flatMap(ExerciseTrackingType.init(rawValue:)) }
        set { trackingTypeRawValue = newValue?.rawValue }
    }

    // Helper method to reset set
    func resetSet() {
        self.actualReps = nil
        self.actualWeight = nil
        self.notes = nil
        self.isCompleted = false
        self.completedAt = nil
        self.durationSeconds = nil
        self.distanceMeters = nil
        self.trackingTypeRawValue = nil
        self.rpe = nil
        self.heartRateBpm = nil
        self.intensityZone = nil
        self.stretchIntensity = nil
        self.rangeOfMotionNotes = nil
        self.restSeconds = nil
        self.paceSecondsPerKm = nil
        self.roundsCompleted = nil
    }
    
    // Helper method to update target values
    func updateTargets(targetReps: Int, targetWeight: Double? = nil) {
        self.targetReps = targetReps
        self.targetWeight = targetWeight
    }
}
