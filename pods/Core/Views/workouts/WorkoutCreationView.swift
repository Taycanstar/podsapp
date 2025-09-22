//
//  WorkoutCreationView.swift
//  pods
//
//  Created by Dimi Nunez on 7/10/25.
//

// FILE: Views/workouts/WorkoutCreationView.swift
import SwiftUI
import SwiftData

struct WorkoutCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let selectedExercises: [ExerciseData]
    @State private var workoutName: String = ""
    @State private var exerciseInstances: [ExerciseInstance] = []
    @State private var showingSaveAlert = false
    @State private var saveError: String?
    
    // Get user email from UserDefaults
    private var userEmail: String {
        UserDefaults.standard.string(forKey: "user_email") ?? ""
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Background color
                Color(.systemBackground)
                    .ignoresSafeArea(.all)
                    .overlay(contentView)
            }
            .navigationTitle("Create Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .disabled(workoutName.isEmpty || exerciseInstances.isEmpty)
                }
            }
        }
        .onAppear {
            setupWorkout()
        }
        .alert("Save Workout", isPresented: $showingSaveAlert) {
            Button("OK") {
                if saveError == nil {
                    dismiss()
                }
            }
        } message: {
            if let error = saveError {
                Text("Error: \(error)")
            } else {
                Text("Workout saved successfully!")
            }
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            // Workout name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Workout Name")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Enter workout name", text: $workoutName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Exercise list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(exerciseInstances.enumerated()), id: \.element.id) { index, exercise in
                        ExerciseCreationRow(
                            exercise: exercise,
                            onAddSet: {
                                addSetToExercise(exercise)
                            },
                            onRemoveSet: { setIndex in
                                removeSetFromExercise(exercise, at: setIndex)
                            },
                            onUpdateSet: { setIndex, reps, weight in
                                updateSetInExercise(exercise, at: setIndex, reps: reps, weight: weight)
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
    }
    
    private func setupWorkout() {
        // Get user profile for recommendations
        let fitnessGoal = UserProfileService.shared.fitnessGoal
        
        // Create exercise instances with default sets/reps
        exerciseInstances = selectedExercises.enumerated().map { index, exerciseData in
            let recommendation = WorkoutRecommendationService.shared.getDefaultSetsAndReps(
                for: exerciseData,
                fitnessGoal: fitnessGoal
            )
            
            let exerciseInstance = ExerciseInstance(
                from: exerciseData,
                orderIndex: index
            )
            
            // Add default sets
            for setNumber in 1...recommendation.sets {
                exerciseInstance.addSet(
                    targetReps: recommendation.reps,
                    targetWeight: recommendation.weight
                )
            }
            
            return exerciseInstance
        }
        
        // Set default workout name
        if workoutName.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy"
            workoutName = "Workout \(dateFormatter.string(from: Date()))"
        }
    }
    
    private func addSetToExercise(_ exercise: ExerciseInstance) {
        let lastSet = exercise.sets.last
        let targetReps = lastSet?.targetReps ?? 10
        let targetWeight = lastSet?.targetWeight
        
        exercise.addSet(targetReps: targetReps, targetWeight: targetWeight)
    }
    
    private func removeSetFromExercise(_ exercise: ExerciseInstance, at index: Int) {
        exercise.removeSet(at: index)
    }
    
    private func updateSetInExercise(_ exercise: ExerciseInstance, at index: Int, reps: Int, weight: Double?) {
        guard index >= 0 && index < exercise.sets.count else { return }
        let set = exercise.sets[index]
        set.updateTargets(targetReps: reps, targetWeight: weight)
    }
    
    private func saveWorkout() {
        guard !workoutName.isEmpty else {
            saveError = "Please enter a workout name"
            showingSaveAlert = true
            return
        }
        
        guard !exerciseInstances.isEmpty else {
            saveError = "Please add at least one exercise"
            showingSaveAlert = true
            return
        }
        
        // Create workout session
        let workoutSession = WorkoutSession(
            name: workoutName,
            userEmail: userEmail
        )
        
        // Add exercises to workout
        for exercise in exerciseInstances {
            workoutSession.addExercise(exercise)
        }
        
        // Save using the new sync system
        Task {
            do {
                try await WorkoutDataManager.shared.saveWorkout(workoutSession, context: modelContext)
                
                await MainActor.run {
                    print("✅ Workout saved successfully with sync")
                    WorkoutSyncService.shared.printWorkoutSummary(workoutSession)
                    saveError = nil
                    showingSaveAlert = true
                }
            } catch {
                await MainActor.run {
                    print("❌ Error saving workout: \(error)")
                    saveError = "Failed to save workout: \(error.localizedDescription)"
                    showingSaveAlert = true
                }
            }
        }
    }
}

struct ExerciseCreationRow: View {
    let exercise: ExerciseInstance
    let onAddSet: () -> Void
    let onRemoveSet: (Int) -> Void
    let onUpdateSet: (Int, Int, Double?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise header
            HStack {
                // Exercise image
                Group {
                    let imageId = String(format: "%04d", exercise.exerciseId)
                    if let image = UIImage(named: imageId) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.exerciseName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(exercise.bodyPart)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Add set button
                Button(action: onAddSet) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
            }
            
            // Sets list
            VStack(spacing: 8) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    SetRow(
                        set: set,
                        onRemove: {
                            onRemoveSet(index)
                        },
                        onUpdate: { reps, weight in
                            onUpdateSet(index, reps, weight)
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SetRow: View {
    let set: SetInstance
    let onRemove: () -> Void
    let onUpdate: (Int, Double?) -> Void
    
    @State private var repsText: String = ""
    @State private var weightText: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Set number
            Text("Set \(set.setNumber)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            // Reps input
            VStack(alignment: .leading, spacing: 4) {
                Text("Reps")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("", text: $repsText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .onAppear {
                        repsText = "\(set.targetReps)"
                    }
                    .onChange(of: repsText) { _, newValue in
                        if let reps = Int(newValue) {
                            onUpdate(reps, set.targetWeight)
                        }
                    }
            }
            
            // Weight input
            VStack(alignment: .leading, spacing: 4) {
                Text("Weight")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("", text: $weightText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .onAppear {
                        weightText = set.targetWeight != nil ? String(format: "%.1f", set.targetWeight!) : ""
                    }
                    .onChange(of: weightText) { _, newValue in
                        let weight = Double(newValue)
                        onUpdate(set.targetReps, weight)
                    }
            }
            
            Spacer()
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    WorkoutCreationView(selectedExercises: [
        ExerciseData(id: 25, name: "Barbell Bench Press", exerciseType: "Strength", bodyPart: "Chest", equipment: "Flat Bench", gender: "Male", target: "Pectoralis Major Sternal Head", synergist: "Deltoid Anterior, Pectoralis Major Clavicular Head, Triceps Brachii"),
        ExerciseData(id: 31, name: "Barbell Curl", exerciseType: "Strength", bodyPart: "Upper Arms", equipment: "Barbells", gender: "Male", target: "Biceps Brachii", synergist: "Brachialis, Brachioradialis")
    ])
} 
