// FILE: Models/WorkoutSession.swift
import Foundation
import SwiftData

@Model
class WorkoutSession {
    var id: UUID
    var name: String
    var startedAt: Date
    var completedAt: Date?
    var exercises: [ExerciseInstance]
    var userEmail: String
    var remoteId: Int?
    var notes: String?
    var totalDuration: TimeInterval?

    // Block-based workout structure (JSON encoded)
    var blocksData: Data?

    // Sync properties
    var createdAt: Date
    var updatedAt: Date
    var syncVersion: Int
    var isDeleted: Bool
    var needsSync: Bool
    
    init(name: String, userEmail: String, notes: String? = nil, blocks: [WorkoutBlock]? = nil) {
        self.id = UUID()
        self.name = name
        self.startedAt = Date()
        self.exercises = []
        self.userEmail = userEmail
        self.remoteId = nil
        self.notes = notes
        self.blocksData = blocks.flatMap { try? JSONEncoder().encode($0) }

        // Initialize sync properties
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncVersion = 1
        self.isDeleted = false
        self.needsSync = true
    }

    // Computed property to access blocks
    var blocks: [WorkoutBlock]? {
        get {
            guard let data = blocksData else { return nil }
            return try? JSONDecoder().decode([WorkoutBlock].self, from: data)
        }
        set {
            blocksData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }
    
    var isCompleted: Bool {
        completedAt != nil
    }
    
    var duration: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }
    
    var totalExercises: Int {
        exercises.count
    }
    
    var completedExercises: Int {
        exercises.filter { $0.isCompleted }.count
    }
    
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.totalSets }
    }
    
    var completedSets: Int {
        exercises.reduce(0) { $0 + $1.completedSets }
    }
    
    // Helper method to add an exercise
    func addExercise(_ exercise: ExerciseInstance) {
        exercise.workoutSession = self
        exercise.orderIndex = exercises.count
        exercises.append(exercise)
        markAsNeedingSync()
    }
    
    // Helper method to remove an exercise
    func removeExercise(at index: Int) {
        guard index >= 0 && index < exercises.count else { return }
        let exercise = exercises.remove(at: index)
        exercise.workoutSession = nil
        
        // Reorder remaining exercises
        for (i, exercise) in exercises.enumerated() {
            exercise.orderIndex = i
        }
        markAsNeedingSync()
    }
    
    // Helper method to complete the workout
    func completeWorkout() {
        completedAt = Date()
        totalDuration = duration
        markAsNeedingSync()
    }
    
    // Helper method to mark as needing sync
    func markAsNeedingSync() {
        updatedAt = Date()
        if !needsSync {
            syncVersion += 1
            needsSync = true
        }
    }
    
    // Helper method to get workout summary
    func getWorkoutSummary() -> String {
        let exerciseCount = exercises.count
        let completedExerciseCount = completedExercises
        let totalSetsCount = totalSets
        let completedSetsCount = completedSets
        
        return """
        Workout: \(name)
        Exercises: \(completedExerciseCount)/\(exerciseCount)
        Sets: \(completedSetsCount)/\(totalSetsCount)
        Duration: \(formatDuration(duration ?? 0))
        """
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
