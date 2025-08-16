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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
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
                        ForEach(Array(exercises.enumerated()), id: \.offset) { index, exercise in
                            ExerciseRowInProgress(
                                exercise: exercise,
                                isCompleted: completedExercises.contains(index),
                                onToggle: {
                                    toggleExerciseCompletion(index)
                                }
                            )
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
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
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
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Top bar with close button
            HStack {
                Button(action: {
                    isPresented = false
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
}

// MARK: - Exercise Row Component

struct ExerciseRowInProgress: View {
    let exercise: TodayWorkoutExercise
    let isCompleted: Bool
    let onToggle: () -> Void
    
    private var thumbnailImageName: String {
        String(format: "%04d", exercise.exercise.id)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isCompleted ? .green : Color(.systemGray3))
            }
            
            // Exercise thumbnail with muscles overlay
            ZStack(alignment: .bottomTrailing) {
                // Main exercise image
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
                .opacity(isCompleted ? 0.6 : 1.0)
                
                // Muscle group overlay (bottom half)
                if let muscleImageName = getMuscleImageName(for: exercise.exercise.bodyPart) {
                    Image(muscleImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
            }
            
            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exercise.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .strikethrough(isCompleted)
                    .opacity(isCompleted ? 0.6 : 1.0)
                
                HStack(spacing: 4) {
                    Text("\(exercise.sets) sets")
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("\(exercise.reps) reps")
                    if let weight = exercise.weight, weight > 0 {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(Int(weight)) lb")
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .opacity(isCompleted ? 0.6 : 1.0)
            }
            
            Spacer()
            
            // Menu button
            Menu {
                Button("View Details") {
                    // TODO: Show exercise details
                }
                
                Button("Skip Exercise") {
                    // TODO: Skip this exercise
                }
                
                Button("Replace Exercise") {
                    // TODO: Replace with alternative
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
    
    private func getMuscleImageName(for bodyPart: String) -> String? {
        // Map body parts to muscle overlay images
        let muscleMapping: [String: String] = [
            "Chest": "muscle_chest",
            "Back": "muscle_back",
            "Shoulders": "muscle_shoulders",
            "Arms": "muscle_arms",
            "Legs": "muscle_legs",
            "Core": "muscle_core",
            "Full Body": "muscle_full"
        ]
        
        return muscleMapping[bodyPart]
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