//
//  ExerciseDetailView.swift
//  pods
//
//  Created by Dimi Nunez on 7/10/25.
//

//
//  ExerciseDetailView.swift
//  Pods
//
//  Created by Dimi Nunez on 7/10/25.
//

import SwiftUI

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: WorkoutExercise
    let onUpdate: (WorkoutExercise) -> Void
    @State private var sets: [WorkoutSet]
    @State private var notes: String
    
    init(exercise: WorkoutExercise, onUpdate: @escaping (WorkoutExercise) -> Void) {
        self.exercise = exercise
        self.onUpdate = onUpdate
        self._sets = State(initialValue: exercise.sets)
        self._notes = State(initialValue: exercise.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Background color
                Color(.systemBackground)
                    .ignoresSafeArea(.all)
                    .overlay(contentView)
            }
            .navigationTitle(exercise.exercise.name)
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
                        saveChanges()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            // Exercise info header
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    // Exercise thumbnail
                    Group {
                        let imageId = String(format: "%04d", exercise.exercise.id)
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
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exercise.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let description = exercise.exercise.description {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            
            // Sets section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sets")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: addSet) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                // Sets list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                            ExerciseSetRow(
                                setNumber: index + 1,
                                set: set,
                                onUpdate: { updatedSet in
                                    sets[index] = updatedSet
                                },
                                onRemove: {
                                    removeSet(at: index)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Notes section
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                TextField("Add notes for this exercise...", text: $notes, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    private func addSet() {
        let newSetId = (sets.map { $0.id }.max() ?? 0) + 1
        let lastSet = sets.last
        
        let newSet = WorkoutSet(
            id: newSetId,
            reps: lastSet?.reps ?? 10,
            weight: lastSet?.weight,
            duration: nil,
            distance: nil,
            restTime: nil
        )
        
        sets.append(newSet)
        HapticFeedback.generate()
    }
    
    private func removeSet(at index: Int) {
        guard index >= 0 && index < sets.count else { return }
        sets.remove(at: index)
        HapticFeedback.generate()
    }
    
    private func saveChanges() {
        let updatedExercise = WorkoutExercise(
            id: exercise.id,
            exercise: exercise.exercise,
            sets: sets,
            notes: notes.isEmpty ? nil : notes
        )
        
        onUpdate(updatedExercise)
        dismiss()
    }
}

struct ExerciseSetRow: View {
    let setNumber: Int
    let set: WorkoutSet
    let onUpdate: (WorkoutSet) -> Void
    let onRemove: () -> Void
    
    @State private var repsText: String = ""
    @State private var weightText: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Set number
            Text("Set \(setNumber)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .leading)
            
            // Reps input
            VStack(alignment: .leading, spacing: 4) {
                Text("Reps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("0", text: $repsText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .onChange(of: repsText) { _, newValue in
                        updateSet()
                    }
            }
            
            // Weight input
            VStack(alignment: .leading, spacing: 4) {
                Text("Weight")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
                    .onChange(of: weightText) { _, newValue in
                        updateSet()
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onAppear {
            repsText = "\(set.reps ?? 0)"
            weightText = set.weight != nil ? String(format: "%.1f", set.weight!) : ""
        }
    }
    
    private func updateSet() {
        let reps = Int(repsText) ?? 0
        let weight = weightText.isEmpty ? nil : Double(weightText)
        
        let updatedSet = WorkoutSet(
            id: set.id,
            reps: reps,
            weight: weight,
            duration: set.duration,
            distance: set.distance,
            restTime: set.restTime
        )
        
        onUpdate(updatedSet)
    }
}

#Preview {
    let sampleExercise = WorkoutExercise(
        id: 1,
        exercise: LegacyExercise(
            id: 1,
            name: "Bench Press",
            category: "Chest",
            description: "Compound chest exercise",
            instructions: "Lie on bench and press weight up"
        ),
        sets: [
            WorkoutSet(id: 1, reps: 10, weight: 135, duration: nil, distance: nil, restTime: nil),
            WorkoutSet(id: 2, reps: 8, weight: 155, duration: nil, distance: nil, restTime: nil),
            WorkoutSet(id: 3, reps: 6, weight: 175, duration: nil, distance: nil, restTime: nil)
        ],
        notes: nil
    )
    
    ExerciseDetailView(exercise: sampleExercise) { _ in }
} 