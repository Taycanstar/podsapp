//
//  WeightedExercisesView.swift
//  Pods
//
//  Created by Dimi Nunez on 7/8/25.
//

import SwiftUI

struct WeightedExercisesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedExercises: Set<Int> = []
    @State private var exercises: [ExerciseData] = []
    
    let onExercisesSelected: ([ExerciseData]) -> Void
    
    init(onExercisesSelected: @escaping ([ExerciseData]) -> Void) {
        self.onExercisesSelected = onExercisesSelected
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Background color
            Color(.systemBackground)
                .ignoresSafeArea(.all)
                .overlay(contentView)
        }
        .navigationTitle("Weighted Exercises")
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
        .searchable(text: $searchText, prompt: "Search weighted exercises")
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
        let weightedFiltered = exercises.filter { exercise in
            isWeightedExercise(exercise: exercise)
        }
        
        if searchText.isEmpty {
            return weightedFiltered.sorted { $0.name < $1.name }
        } else {
            return weightedFiltered.filter { exercise in
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
        print("🏋️ WeightedExercisesView: Loaded \(self.exercises.count) exercises")
    }
    
    private func isWeightedExercise(exercise: ExerciseData) -> Bool {
        let equipment = exercise.equipment.lowercased()
        let name = exercise.name.lowercased()
        
        // Equipment that requires weights
        let weightedEquipment = [
            "dumbbell",
            "barbell",
            "kettlebell",
            "ez barbell",
            "smith machine",
            "leverage machine",
            "cable",
            "weighted",
            "medicine ball",
            "olympic barbell",
            "trap bar",
            "hex bar"
        ]
        
        // Check if equipment contains any weighted equipment
        for weightEquipment in weightedEquipment {
            if equipment.contains(weightEquipment) {
                return true
            }
        }
        
        // Check exercise names for weighted variations
        let weightedKeywords = [
            "weighted",
            "dumbbell",
            "barbell",
            "kettlebell",
            "cable",
            "smith",
            "leverage",
            "medicine ball",
            "weight plate",
            "ez bar",
            "trap bar",
            "hex bar"
        ]
        
        for keyword in weightedKeywords {
            if name.contains(keyword) {
                return true
            }
        }
        
        // Exclude purely bodyweight exercises
        if equipment == "body weight" && !name.contains("weighted") {
            return false
        }
        
        return false
    }
}

#Preview {
    NavigationView {
        WeightedExercisesView { exercises in
            print("Selected weighted exercises: \(exercises.map { $0.name })")
        }
    }
}
