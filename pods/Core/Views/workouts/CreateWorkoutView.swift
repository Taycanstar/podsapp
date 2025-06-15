//
//  CreateWorkoutView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/14/25.
//

import SwiftUI

struct CreateWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath
    @State private var workoutTitle: String = ""
    @State private var exercises: [WorkoutExercise] = []
    @State private var showingAddExercise = false
    
    // Optional workout for editing
    let workout: Workout?
    
    init(navigationPath: Binding<NavigationPath>, workout: Workout? = nil) {
        self._navigationPath = navigationPath
        self.workout = workout
        
        // Initialize with existing workout data if editing
        if let workout = workout {
            self._workoutTitle = State(initialValue: workout.name)
            self._exercises = State(initialValue: workout.exercises)
        }
    }
    
    var body: some View {
            VStack(spacing: 0) {
                // Background color for the entire view
                Color("iosbg2")
                    .ignoresSafeArea(.all)
                    .overlay(
                        VStack(spacing: 20) {
                            // Title input field
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Title", text: $workoutTitle)
                                    .font(.system(size: 17))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    // .background(Color(.systemBackground))
                                    .background(Color("iosfit"))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            
                            // Show dbbell image and text when no exercises
                            if exercises.isEmpty {
                                VStack(spacing: 16) {
                            
                                    
                                    Image("dbbell")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 150, maxHeight: 150)
                                    
                                    Text("Add exercises to get started")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                                                         // Add Exercise button
                                     Button(action: {
                                         print("Tapped Add Exercise")
                                         HapticFeedback.generate()
                                         showingAddExercise = true
                                     }) {
                                        HStack(spacing: 6) {
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                            Text("Add Exercise")
                                                .font(.system(size: 17))
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.accentColor)
                                        .cornerRadius(12)
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 20)
                                    
                                    Spacer()
                                }
                            } else {
                                // Show exercise list when exercises are added
                                VStack(spacing: 16) {
                                    // Exercise list
                                    ScrollView {
                                        LazyVStack(spacing: 12) {
                                            ForEach(exercises, id: \.id) { exercise in
                                                WorkoutExerciseRow(exercise: exercise) {
                                                    removeExercise(exercise)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    
                                    // Add more exercises button
                                    Button(action: {
                                        showingAddExercise = true
                                        HapticFeedback.generate()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 16))
                                            Text("Add More Exercises")
                                                .font(.system(size: 16, weight: .medium))
                                        }
                                        .foregroundColor(.accentColor)
                                        .padding(.vertical, 12)
                                    }
                                    .padding(.horizontal, 16)
                                    
                                    Spacer()
                                }
                            }
                            
                            Spacer()
                        }
                    )
            }
                     .navigationTitle(workout != nil ? "Edit Workout" : "New Workout")
         .navigationBarTitleDisplayMode(.inline)
         .navigationBarBackButtonHidden(true)
         .toolbar {
             ToolbarItem(placement: .navigationBarLeading) {
                 Button("Cancel") {
                     navigationPath.removeLast()
                 }
                 .foregroundColor(.accentColor)
             }
             
             ToolbarItem(placement: .navigationBarTrailing) {
                 Button("Done") {
                     saveWorkout()
                 }
                 .font(.system(size: 17, weight: .semibold))
                 .foregroundColor(.accentColor)
                 .disabled(workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
             }
         }
         .sheet(isPresented: $showingAddExercise) {
             AddExerciseView { selectedExercises in
                 addExercisesToWorkout(selectedExercises)
             }
         }
    }
    
    private func saveWorkout() {
        // TODO: Implement workout saving logic
        print("Saving workout: \(workoutTitle)")
        HapticFeedback.generate()
        navigationPath.removeLast()
    }
    
    private func addExercisesToWorkout(_ selectedExercises: [ExerciseData]) {
        // Convert ExerciseData to WorkoutExercise
        let newExercises = selectedExercises.map { exerciseData in
            let exercise = Exercise(
                id: exerciseData.id,
                name: exerciseData.name,
                category: exerciseData.category,
                description: exerciseData.instructions,
                instructions: exerciseData.target
            )
            
            return WorkoutExercise(
                id: Int.random(in: 1000...9999), // Generate random ID
                exercise: exercise,
                sets: [],
                notes: nil
            )
        }
        
        // Add to existing exercises
        exercises.append(contentsOf: newExercises)
        
        print("Added \(selectedExercises.count) exercises to workout")
        HapticFeedback.generate()
    }
    
    private func removeExercise(_ exercise: WorkoutExercise) {
        exercises.removeAll { $0.id == exercise.id }
        HapticFeedback.generate()
    }
}

// MARK: - Workout Exercise Row
struct WorkoutExerciseRow: View {
    let exercise: WorkoutExercise
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Exercise thumbnail
            Group {
                // Use 4-digit padded format for exercise images (e.g., "0001", "0025")
                let imageId = String(format: "%04d", exercise.exercise.id)
                if let image = UIImage(named: imageId) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Default exercise icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            
            // Exercise details
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exercise.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Text("\(exercise.sets.count) sets")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("iosfit"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationView {
        CreateWorkoutView(navigationPath: .constant(NavigationPath()))
    }
}
