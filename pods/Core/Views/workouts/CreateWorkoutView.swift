//
//  CreateWorkoutView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/14/25.
//

import SwiftUI

struct CreateWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutManager: WorkoutManager
    @Binding var navigationPath: NavigationPath
    @State private var workoutTitle: String = ""
    @State private var exercises: [WorkoutExercise] = []
    @State private var showingAddExercise = false
    @State private var showingExerciseFullScreen = false
    @State private var focusedExerciseId: Int? = nil
    @State private var showingSaveAlert = false
    @State private var saveError: String?
    @State private var isSaving = false
    
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
                Color("altbg")
                    .ignoresSafeArea(.all)
                    .overlay(
                        VStack(spacing: 20) {
                            // Title input field
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Name", text: $workoutTitle)
                                    .font(.system(size: 17))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                    .background(Color("altcard"))
                                    .cornerRadius(24)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            
                            // Show dbbell image and text when no exercises
                            if exercises.isEmpty {
                                Spacer(minLength: 0)
                                VStack(spacing: 16) {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .font(.system(size: 64, weight: .regular))
                                        .foregroundColor(.secondary)

                                    Text("Add any exercises to your workout.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 32)
                                .padding(.vertical, 40)
                                .frame(maxWidth: .infinity)
                                .background(Color("altbg"))
                                .cornerRadius(24)
                                .padding(.horizontal, 16)
                                Spacer(minLength: 0)
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
                                                .onTapGesture {
                                                    focusedExerciseId = exercise.id
                                                    showingExerciseFullScreen = true
                                                }
                                            }
                                        }
                                        // .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    .background(Color("altbg"))
                                    .cornerRadius(24)
                                    .padding(.horizontal, 16)

                                    Spacer(minLength: 0)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.bottom, 140)
                    )
            }
                     .navigationTitle(workout != nil ? "Edit Workout" : "New Workout")
         .navigationBarTitleDisplayMode(.inline)
         .navigationBarBackButtonHidden(true)
         .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast()
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.primary)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    saveWorkout()
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.primary)
                .disabled(workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || exercises.isEmpty)
            }
        }
         .sheet(isPresented: $showingAddExercise) {
             AddExerciseView { selectedExercises in
                 addExercisesToWorkout(selectedExercises)
             }
         }
        .fullScreenCover(isPresented: $showingExerciseFullScreen) {
            WorkoutExerciseFullScreenView(
                workoutTitle: workoutTitle,
                exercises: $exercises,
                focusedExerciseId: focusedExerciseId,
                onDismiss: {
                    showingExerciseFullScreen = false
                    focusedExerciseId = nil
                },
                onUpdateExercise: { updatedExercise in
                    updateExercise(updatedExercise)
                },
                onRemoveExercise: { exercise in
                    removeExercise(exercise)
                }
            )
        }
        .alert("Save Workout", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) {
                saveError = nil
            }
        } message: {
            Text(saveError ?? "")
        }
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    ProgressView("Saving workout...")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .background(Color(.systemBackground))
                        .cornerRadius(14)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                HapticFeedback.generate()
                showingAddExercise = true
            }) {
                Text("Add Exercise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary)
                    .cornerRadius(100)
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private func saveWorkout() {
        let trimmedTitle = workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            saveError = "Please enter a workout name."
            showingSaveAlert = true
            return
        }

        guard !exercises.isEmpty else {
            saveError = "Add at least one exercise before saving."
            showingSaveAlert = true
            return
        }

        let currentExercises = exercises
        let existingId = workout?.id

        isSaving = true

        Task {
            do {
                _ = try await workoutManager.saveCustomWorkout(
                    name: trimmedTitle,
                    exercises: currentExercises,
                    notes: nil,
                    workoutId: existingId
                )

                await MainActor.run {
                    isSaving = false
                    HapticFeedback.generate()
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast()
                    } else {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                    showingSaveAlert = true
                }
            }
        }
    }
    
    private func addExercisesToWorkout(_ selectedExercises: [ExerciseData]) {
        // Initialize user profile defaults if needed
        UserProfileService.shared.setupDefaultEquipment()
        
        // Convert ExerciseData to WorkoutExercise with smart recommendations
        let newExercises = selectedExercises.map { exerciseData in
            let exercise = LegacyExercise(
                id: exerciseData.id,
                name: exerciseData.name,
                category: exerciseData.category,
                description: exerciseData.instructions,
                instructions: exerciseData.target
            )
            
            // Get smart recommendation using enhanced system
            let recommendation = WorkoutRecommendationService.shared.getSmartRecommendation(for: exerciseData)
            
            // Create sets array with recommended values
            var sets: [WorkoutSet] = []
            for setNumber in 1...recommendation.sets {
                let set = WorkoutSet(
                    id: setNumber,
                    reps: recommendation.reps,
                    weight: recommendation.weight,
                    duration: nil,
                    distance: nil,
                    restTime: nil
                )
                sets.append(set)
            }
            
            return WorkoutExercise(
                id: Int.random(in: 1000...9999), // Generate random ID
                exercise: exercise,
                sets: sets,
                notes: nil
            )
        }
        
        // Add to existing exercises
        exercises.append(contentsOf: newExercises)
        
        print("🏋️ Added \(selectedExercises.count) exercises to workout using smart recommendations")
        HapticFeedback.generate()
    }
    
    private func removeExercise(_ exercise: WorkoutExercise) {
        exercises.removeAll { $0.id == exercise.id }
        HapticFeedback.generate()
    }
    
    private func updateExercise(_ updatedExercise: WorkoutExercise) {
        if let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            exercises[index] = updatedExercise
        }
    }
}

// MARK: - Workout Exercise Row

private struct WorkoutExerciseFullScreenView: View {
    let workoutTitle: String
    @Binding var exercises: [WorkoutExercise]
    let focusedExerciseId: Int?
    let onDismiss: () -> Void
    let onUpdateExercise: (WorkoutExercise) -> Void
    let onRemoveExercise: (WorkoutExercise) -> Void

    @State private var sheetExercise: WorkoutExercise?

    var body: some View {
        NavigationView {
            ZStack {
                Color("primarybg")
                    .ignoresSafeArea()

                if exercises.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 48, weight: .regular))
                            .foregroundColor(.secondary)

                        Text("No exercises added yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                header

                                ForEach(exercises) { exercise in
                                    WorkoutExerciseFullScreenCard(
                                        exercise: exercise,
                                        onEdit: {
                                            if let latest = exercises.first(where: { $0.id == exercise.id }) {
                                                sheetExercise = latest
                                            }
                                        },
                                        onRemove: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                onRemoveExercise(exercise)
                                            }
                                        }
                                    )
                                    .id(exercise.id)
                                }
                            }
                            .padding(.top, 24)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        }
                        .onAppear {
                            if let targetId = focusedExerciseId {
                                DispatchQueue.main.async {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        proxy.scrollTo(targetId, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .onChange(of: exercises) { _, _ in
            if let current = sheetExercise,
               exercises.first(where: { $0.id == current.id }) == nil {
                sheetExercise = nil
            }
        }
        .sheet(item: $sheetExercise) { exercise in
            ExerciseDetailView(exercise: exercise) { updatedExercise in
                onUpdateExercise(updatedExercise)

                if let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
                    exercises[index] = updatedExercise
                }

                sheetExercise = nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Workout" : workoutTitle)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)

            Text("Review and edit your exercises")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorkoutExerciseFullScreenCard: View {
    let exercise: WorkoutExercise
    let onEdit: () -> Void
    let onRemove: () -> Void

    private var thumbnailImageName: String {
        String(format: "%04d", exercise.exercise.id)
    }

    private var summaryText: String {
        guard let firstSet = exercise.sets.first else {
            return "No sets configured"
        }

        let setsCount = exercise.sets.count
        let setsLabel = setsCount == 1 ? "set" : "sets"

        if let reps = firstSet.reps {
            return "\(setsCount) \(setsLabel) • \(reps) reps"
        } else if let duration = firstSet.duration, duration > 0 {
            return "\(setsCount) \(setsLabel) • \(formatDuration(duration))"
        } else {
            return "\(setsCount) \(setsLabel)"
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Group {
                        if let image = UIImage(named: thumbnailImageName) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    Image(systemName: "dumbbell")
                                        .font(.system(size: 18))
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.exercise.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Text(summaryText)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("containerbg"))
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
                    .background(
                        Circle()
                            .fill(Color("containerbg"))
                            .frame(width: 32, height: 32)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .padding(.top, 8)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

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
            .frame(width: 45, height: 45)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            // .overlay(
            //     RoundedRectangle(cornerRadius: 8)
            //         .stroke(Color(.systemGray4), lineWidth: 1)
            // )
            
            // Exercise details
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exercise.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                // // Show recommended sets and reps
                // if let firstSet = exercise.sets.first {
                //     Text("\(exercise.sets.count) sets × \(firstSet.reps ?? 0) reps")
                //         .font(.system(size: 14))
                //         .foregroundColor(.secondary)
                // } else {
                //     Text("No sets configured")
                //     .font(.system(size: 14))
                //     .foregroundColor(.secondary)
                // }
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
        .background(Color("altcard"))
        .cornerRadius(24)
        // .overlay(
        //     RoundedRectangle(cornerRadius: 12)
        //         .stroke(Color(.systemGray4), lineWidth: 1)
        // )
    }
}

#Preview {
    NavigationView {
        CreateWorkoutView(navigationPath: .constant(NavigationPath()))
    }
    .environmentObject(WorkoutManager.shared)
}
