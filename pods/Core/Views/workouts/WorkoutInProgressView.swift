//
//  WorkoutInProgressView.swift
//  pods
//
//  Created by Dimi Nunez on 8/16/25.
//

import SwiftUI
import UIKit

struct WorkoutInProgressView: View {
    @Binding var isPresented: Bool
    let exercises: [TodayWorkoutExercise]
    @State private var isPaused = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var completedExercises: Set<Int> = []
    @State private var navigationPath = NavigationPath()
    @Environment(\.colorScheme) var colorScheme
    
    // Track if any sets have been logged during this workout
    @State private var hasLoggedSets = false
    @State private var showDiscardAlert = false
    // Track completed exercises with their logged sets count
    @State private var exerciseCompletionStatus: [Int: Int] = [:] // exerciseIndex: loggedSetsCount
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with close button and timer
                    headerSection
                    
                    // Exercise list
                    ScrollView {
                        VStack(spacing: 8) {
                            if exercises.isEmpty {
                                Text("No exercises loaded")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 50)
                            } else {
                                ForEach(Array(exercises.enumerated()), id: \.offset) { index, exercise in
                                    ExerciseRowInProgress(
                                        exercise: exercise,
                                        allExercises: exercises,
                                        isCompleted: completedExercises.contains(index),
                                        loggedSetsCount: exerciseCompletionStatus[index],
                                        onToggle: {
                                            toggleExerciseCompletion(index)
                                        },
                                        onExerciseTap: {
                                            navigationPath.append(WorkoutNavigationDestination.logExercise(exercise, exercises))
                                        }
                                    )
                                }
                            }
                            
                            // Bottom padding for floating buttons
                            Color.clear
                                .frame(height: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
                
                // Floating buttons
                VStack {
                    Spacer()
                    
                    if isPaused {
                        // Resume and Log Workout buttons when paused
                        HStack(spacing: 16) {
                            Button(action: resumeWorkout) {
                                Text("Resume")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color("tiktoknp"))
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                            
                            Button(action: logWorkout) {
                                Text("Log Workout")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Pause button when running
                        Button(action: pauseWorkout) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.red)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
                        }
                        .padding(.bottom, 30)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isPaused)
            } // Closes ZStack
            .navigationDestination(for: WorkoutNavigationDestination.self) { destination in
                switch destination {
                case .logExercise(let exercise, let allExercises):
                    ExerciseLoggingView(
                        exercise: exercise, 
                        allExercises: allExercises, 
                        onSetLogged: {
                            hasLoggedSets = true
                            // Find the exercise index and update completion status
                            if let exerciseIndex = exercises.firstIndex(where: { $0.exercise.id == exercise.exercise.id }) {
                                // For now, assume all sets are logged when callback is triggered
                                exerciseCompletionStatus[exerciseIndex] = exercise.sets
                            }
                        },
                        isFromWorkoutInProgress: true  // Pass this flag to show Log Set/Log All Sets buttons immediately
                    )
                default:
                    EmptyView()
                }
            }
        } // Closes NavigationStack
        .onAppear {
            startTimer()
            print("🏋️ WorkoutInProgressView appeared with \(exercises.count) exercises")
            for (index, exercise) in exercises.enumerated() {
                print("🏋️ Exercise \(index): \(exercise.exercise.name)")
            }
        }
        .onDisappear {
            stopTimer()
        }
        .alert("Discard Workout?", isPresented: $showDiscardAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Discard", role: .destructive) {
                isPresented = false
            }
        } message: {
            Text("You have logged sets in this workout. Are you sure you want to discard this workout?")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Top bar with close button
            HStack {
                Button(action: {
                    handleDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Menu {
                    Button("View Summary") {
                        // TODO: Show workout summary
                    }
                    
                    Button("Settings") {
                        // TODO: Show workout settings
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Timer display
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Circle()
                        .fill(isPaused ? Color.orange : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(timeString(from: elapsedTime))
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                if isPaused {
                    Text("Paused")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Methods
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !isPaused {
                elapsedTime += 1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func pauseWorkout() {
        isPaused = true
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func resumeWorkout() {
        isPaused = false
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func logWorkout() {
        // TODO: Save workout data and dismiss
        isPresented = false
    }
    
    private func toggleExerciseCompletion(_ index: Int) {
        if completedExercises.contains(index) {
            completedExercises.remove(index)
        } else {
            completedExercises.insert(index)
        }
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func handleDismiss() {
        // Check if any sets have been logged
        if hasLoggedSets {
            // Show confirmation alert if sets have been logged
            showDiscardAlert = true
        } else {
            // Dismiss immediately if no sets have been logged
            isPresented = false
        }
    }
}

// MARK: - Exercise Row Component

struct ExerciseRowInProgress: View {
    let exercise: TodayWorkoutExercise
    let allExercises: [TodayWorkoutExercise]
    let isCompleted: Bool
    let loggedSetsCount: Int?
    let onToggle: () -> Void
    let onExerciseTap: () -> Void
    
    private var thumbnailImageName: String {
        String(format: "%04d", exercise.exercise.id)
    }
    
    var body: some View {
        Button(action: onExerciseTap) {
            HStack(spacing: 12) {
                // Exercise thumbnail - exactly like LogWorkoutView
                Group {
                    if let image = UIImage(named: thumbnailImageName) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "dumbbell")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            )
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Exercise info - exactly like LogWorkoutView
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.exercise.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Group {
                        if let loggedCount = loggedSetsCount {
                            Text("\(loggedCount)/\(exercise.sets) logged")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        } else {
                            Text("\(exercise.sets) sets • \(exercise.reps) reps")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Menu button - exactly like LogWorkoutView
                Menu {
                    Button("Exercise History") {
                        // TODO: Show exercise history
                    }
                    
                    Button("Replace") {
                        // TODO: Replace exercise
                    }
                    
                    Button("Skip Exercise") {
                        // TODO: Skip this exercise
                    }
                    
                    Divider()
                    
                    Button("Mark Complete") {
                        onToggle()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color("tiktoknp"))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
}


// MARK: - Preview

#Preview {
    WorkoutInProgressView(
        isPresented: .constant(true),
        exercises: [
            TodayWorkoutExercise(
                exercise: ExerciseData(
                    id: 1,
                    name: "Barbell Bench Press",
                    exerciseType: "Strength",
                    bodyPart: "Chest",
                    equipment: "Barbell",
                    gender: "Both",
                    target: "Pectorals",
                    synergist: "Triceps, Anterior Deltoid"
                ),
                sets: 3,
                reps: 6,
                weight: 140,
                restTime: 90
            ),
            TodayWorkoutExercise(
                exercise: ExerciseData(
                    id: 2,
                    name: "Close-Grip Bench Press",
                    exerciseType: "Strength",
                    bodyPart: "Chest",
                    equipment: "Barbell",
                    gender: "Both",
                    target: "Triceps",
                    synergist: "Pectorals"
                ),
                sets: 3,
                reps: 8,
                weight: 100,
                restTime: 90
            )
        ]
    )
}
