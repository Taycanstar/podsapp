//
//  StretchMobilityView.swift
//  Pods
//
//  Created by Dimi Nunez on 7/8/25.
//

import SwiftUI

struct StretchMobilityView: View {
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
        .navigationTitle("Stretching & Mobility")
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
                Button("Done") {
                    let selected = exercises.filter { selectedExercises.contains($0.id) }
                    onExercisesSelected(selected)
                    dismiss()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.accentColor)
                .disabled(selectedExercises.isEmpty)
            }
        }
        .searchable(text: $searchText, prompt: "Search stretching & mobility")
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
        let stretchMobilityFiltered = exercises.filter { exercise in
            isStretchMobilityExercise(exercise: exercise)
        }
        
        if searchText.isEmpty {
            return stretchMobilityFiltered.sorted { $0.name < $1.name }
        } else {
            return stretchMobilityFiltered.filter { exercise in
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
        print("🏋️ StretchMobilityView: Loaded \(self.exercises.count) exercises")
    }
    
    private func isStretchMobilityExercise(exercise: ExerciseData) -> Bool {
        let exerciseType = exercise.exerciseType.lowercased()
        let name = exercise.name.lowercased()
        let equipment = exercise.equipment.lowercased()
        
        // Primary filter: Exercise type is "Stretching"
        if exerciseType == "stretching" {
            return true
        }
        
        // Specific stretching exercise names
        let stretchNames = [
            "stretch",
            "cat stretch",
            "spine stretch",
            "hip flexor stretch",
            "calf stretch",
            "knee to chest stretch",
            "ankle circles"
        ]
        
        for stretchName in stretchNames {
            if name.contains(stretchName) {
                return true
            }
        }
        
        // Equipment that's primarily for stretching/mobility
        let mobilityEquipment = [
            "rope" // For stretching straps
        ]
        
        for mobilityEq in mobilityEquipment {
            if equipment.contains(mobilityEq) && name.contains("stretch") {
                return true
            }
        }
        
        return false
    }
}

#Preview {
    NavigationView {
        StretchMobilityView { exercises in
            print("Selected stretching & mobility exercises: \(exercises.map { $0.name })")
        }
    }
}
