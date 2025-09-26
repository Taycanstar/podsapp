//
//  CardioExercisesView.swift
//  Pods
//
//  Created by Dimi Nunez on 7/8/25.
//

import SwiftUI

struct CardioExercisesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedExercises: Set<Int> = []
    @State private var exercises: [ExerciseData] = []
    
    let onExercisesSelected: ([ExerciseData]) -> Void
    
    init(onExercisesSelected: @escaping ([ExerciseData]) -> Void) {
        self.onExercisesSelected = onExercisesSelected
    }
    
    var body: some View {
        contentView
            .background(Color(.systemBackground))
        .navigationTitle("Cardio Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let selected = exercises.filter { selectedExercises.contains($0.id) }
                    onExercisesSelected(selected)
                    dismiss()
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.primary)
                .disabled(selectedExercises.isEmpty)
            }
        }
        .searchable(text: $searchText, prompt: "Search cardio exercises")
        .onAppear {
            loadExercises()
        }
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(filteredExercises, id: \.id) { exercise in
                    ExerciseRow(
                        exercise: exercise,
                        isSelected: selectedExercises.contains(exercise.id)
                    ) {
                        toggleExerciseSelection(exercise)
                    }
                    .padding(.horizontal, 16)
                    .background(Color(.systemBackground))
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Computed Properties
    private var filteredExercises: [ExerciseData] {
        let cardioFiltered = exercises.filter { exercise in
            isCardioExercise(exercise: exercise)
        }
        
        if searchText.isEmpty {
            return cardioFiltered.sorted { $0.name < $1.name }
        } else {
            return cardioFiltered.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.muscle.localizedCaseInsensitiveContains(searchText) ||
                exercise.target.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.name < $1.name }
        }
    }
    
    // MARK: - Methods
    private func toggleExerciseSelection(_ exercise: ExerciseData) {
        HapticFeedback.generate()
        if selectedExercises.contains(exercise.id) {
            selectedExercises.remove(exercise.id)
        } else {
            selectedExercises.insert(exercise.id)
        }
    }
    
    private func loadExercises() {
        self.exercises = ExerciseDatabase.getAllExercises()
        print("🏋️ CardioExercisesView: Loaded \(self.exercises.count) exercises")
    }
    
    private func isCardioExercise(exercise: ExerciseData) -> Bool {
        let exerciseType = exercise.exerciseType.lowercased()
        let bodyPart = exercise.bodyPart.lowercased()
        let name = exercise.name.lowercased()
        
        // Primary filter: Exercise type is "Aerobic"
        if exerciseType == "aerobic" {
            return true
        }
        
        // Body part is "Cardio" or "Plyometrics"
        if bodyPart == "cardio" || bodyPart == "plyometrics" {
            return true
        }
        
        // Specific cardio exercise names (only if they're not strength training)
        let cardioNames = [
            "burpee",
            "mountain climber",
            "jump squat",
            "jumping jack",
            "rowing",
            "standing long jump",
            "walking lunges"
        ]
        
        for cardioName in cardioNames {
            if name.contains(cardioName) {
                return true
            }
        }
        
        // Equipment-based cardio (rowing machines, etc.)
        let equipment = exercise.equipment.lowercased()
        if equipment.contains("rowing machine") || equipment.contains("cardio machine") {
            return true
        }
        
        return false
    }
}

#Preview {
    NavigationView {
        CardioExercisesView { exercises in
            print("Selected cardio exercises: \(exercises.map { $0.name })")
        }
    }
}
