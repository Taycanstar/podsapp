// FILE: Services/WorkoutSyncService.swift
import Foundation
import SwiftData

class WorkoutSyncService {
    static let shared = WorkoutSyncService()
    
    private init() {}
    
    // Save workout session to SwiftData
    func saveWorkoutSession(_ workout: WorkoutSession, context: ModelContext) {
        context.insert(workout)
        
        do {
            try context.save()
            print("✅ Workout session saved successfully")
            printWorkoutSummary(workout)
        } catch {
            print("❌ Error saving workout session: \(error)")
        }
    }
    
    // Print workout summary
    func printWorkoutSummary(_ workout: WorkoutSession) {
        print("\n🏋️ WORKOUT SUMMARY")
        print("==================")
        print("Name: \(workout.name)")
        print("Date: \(formatDate(workout.startedAt))")
        print("Duration: \(formatDuration(workout.duration ?? 0))")
        print("Exercises: \(workout.totalExercises)")
        print("Sets: \(workout.totalSets)")
        print("")
        
        for exercise in workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            print("📝 \(exercise.exerciseName)")
            print("   Sets: \(exercise.completedSets)/\(exercise.totalSets)")
            
            for set in exercise.sets.sorted(by: { $0.setNumber < $1.setNumber }) {
                let weightText = set.actualWeight != nil ? " @ \(set.displayWeight) lbs" : ""
                let repsText = set.actualReps != nil ? "\(set.actualReps!)" : "\(set.targetReps)"
                print("   Set \(set.setNumber): \(repsText) reps\(weightText)")
            }
            print("")
        }
        
        print("==================\n")
    }
    
    // Get workout history for a user
    func getWorkoutHistory(for userEmail: String, context: ModelContext) -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { workout in
                workout.userEmail == userEmail
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ Error fetching workout history: \(error)")
            return []
        }
    }
    
    // Get user profile
    func getUserProfile(for userEmail: String, context: ModelContext) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { profile in
                profile.email == userEmail
            }
        )
        
        do {
            let profiles = try context.fetch(descriptor)
            return profiles.first
        } catch {
            print("❌ Error fetching user profile: \(error)")
            return nil
        }
    }
    
    // Create or update user profile
    func createOrUpdateUserProfile(email: String, fitnessGoal: FitnessGoal, experienceLevel: ExperienceLevel, context: ModelContext) {
        if let existingProfile = getUserProfile(for: email, context: context) {
            existingProfile.fitnessGoal = fitnessGoal
            existingProfile.experienceLevel = experienceLevel
            existingProfile.updatedAt = Date()
        } else {
            let newProfile = UserProfile(email: email, fitnessGoal: fitnessGoal, experienceLevel: experienceLevel)
            context.insert(newProfile)
        }
        
        do {
            try context.save()
            print("✅ User profile saved successfully")
        } catch {
            print("❌ Error saving user profile: \(error)")
        }
    }
    
    // Helper methods for formatting
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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