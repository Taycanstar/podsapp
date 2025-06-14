//
//  WorkoutManager.swift
//  Pods
//
//  Created by Dimi Nunez on 6/14/25.
//

import SwiftUI
import Foundation

// MARK: - Workout Models
struct Exercise: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let category: String? // e.g., "Chest", "Back", "Legs"
    let description: String?
    let instructions: String?
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        lhs.id == rhs.id
    }
}

struct WorkoutSet: Codable, Identifiable {
    let id: Int
    let reps: Int?
    let weight: Double? // in kg or lbs
    let duration: Int? // in seconds for time-based exercises
    let distance: Double? // in meters or miles for cardio
    let restTime: Int? // in seconds
}

struct WorkoutExercise: Codable, Identifiable {
    let id: Int
    let exercise: Exercise
    let sets: [WorkoutSet]
    let notes: String?
}

struct Workout: Codable, Identifiable {
    let id: Int
    let name: String
    let date: Date
    let duration: Int? // in minutes
    let exercises: [WorkoutExercise]
    let notes: String?
    let category: String? // e.g., "Push", "Pull", "Legs", "Cardio"
    
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    var displayName: String {
        name.isEmpty ? "Workout" : name
    }
}

struct LoggedWorkout: Codable, Identifiable {
    let id: Int
    let workoutLogId: Int
    let workout: Workout
    let loggedAt: Date
    let status: String
    let message: String
    
    var logDate: Date { loggedAt }
}

// MARK: - WorkoutManager
class WorkoutManager: ObservableObject {
    @Published var workouts: [Workout] = []
    @Published var loggedWorkouts: [LoggedWorkout] = []
    @Published var exercises: [Exercise] = []
    @Published var isLoading = false
    @Published var isLoadingWorkouts = false
    @Published var isLoadingExercises = false
    @Published var error: Error?
    @Published var hasMore = true
    @Published var showToast = false
    @Published var lastLoggedWorkoutId: Int? = nil
    
    // Pagination
    private var currentPage = 1
    private let pageSize = 20
    private var userEmail: String?
    
    init() {
        // Initialize with empty data
        print("🏋️ WorkoutManager: Initialized")
    }
    
    func initialize(userEmail: String) {
        print("🏋️ WorkoutManager: Initializing with email \(userEmail)")
        self.userEmail = userEmail
        
        // Reset state
        currentPage = 1
        hasMore = true
        workouts = []
        loggedWorkouts = []
        exercises = []
        
        // Load initial data
        loadWorkouts()
        loadExercises()
    }
    
    // MARK: - Data Loading
    private func loadWorkouts() {
        guard let email = userEmail else { return }
        guard !isLoadingWorkouts else { return }
        
        isLoadingWorkouts = true
        error = nil
        
        // TODO: Implement API call to load workouts
        // For now, simulate loading with empty data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.isLoadingWorkouts = false
            
            // Simulate empty workout data for now
            self.workouts = []
            self.hasMore = false
            
            print("🏋️ WorkoutManager: Loaded \(self.workouts.count) workouts")
        }
    }
    
    private func loadExercises() {
        guard let email = userEmail else { return }
        guard !isLoadingExercises else { return }
        
        isLoadingExercises = true
        
        // TODO: Implement API call to load exercises
        // For now, simulate loading with sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.isLoadingExercises = false
            
            // Simulate empty exercise data for now
            self.exercises = []
            
            print("🏋️ WorkoutManager: Loaded \(self.exercises.count) exercises")
        }
    }
    
    // MARK: - Computed Properties
    var hasWorkouts: Bool {
        return !workouts.isEmpty || !loggedWorkouts.isEmpty
    }
    
    var hasExercises: Bool {
        return !exercises.isEmpty
    }
    
    // MARK: - Public Methods
    func refresh() {
        print("🔄 WorkoutManager: Refreshing data")
        currentPage = 1
        hasMore = true
        loadWorkouts()
        loadExercises()
    }
    
    func addWorkout(_ workout: Workout) {
        // TODO: Implement API call to add workout
        workouts.append(workout)
        print("🏋️ WorkoutManager: Added workout: \(workout.displayName)")
    }
    
    func deleteWorkout(withId id: Int) {
        // TODO: Implement API call to delete workout
        workouts.removeAll { $0.id == id }
        print("🏋️ WorkoutManager: Deleted workout with id: \(id)")
    }
    
    func logWorkout(_ workout: Workout) {
        // TODO: Implement API call to log workout
        let loggedWorkout = LoggedWorkout(
            id: Int.random(in: 1000...9999),
            workoutLogId: Int.random(in: 1000...9999),
            workout: workout,
            loggedAt: Date(),
            status: "completed",
            message: "Logged \(workout.displayName)"
        )
        
        loggedWorkouts.append(loggedWorkout)
        lastLoggedWorkoutId = loggedWorkout.id
        showToast = true
        
        print("🏋️ WorkoutManager: Logged workout: \(workout.displayName)")
    }
}
