//
//  BodyweightExercisesView.swift
//  Pods
//
//  Created by Dimi Nunez on 7/8/25.
//

import SwiftUI

struct BodyweightExercisesView: View {
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
        .navigationTitle("Bodyweight Exercises")
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
        .searchable(text: $searchText, prompt: "Search bodyweight exercises")
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
        let bodyweightFiltered = exercises.filter { exercise in
            isBodyweightExercise(exercise: exercise)
        }
        
        if searchText.isEmpty {
            return bodyweightFiltered.sorted { $0.name < $1.name }
        } else {
            return bodyweightFiltered.filter { exercise in
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
        print("🏋️ BodyweightExercisesView: Loaded \(self.exercises.count) exercises")
    }
    
    private func isBodyweightExercise(exercise: ExerciseData) -> Bool {
        let equipment = exercise.equipment.lowercased()
        let name = exercise.name.lowercased()
        
        // Primary check: equipment is explicitly "body weight"
        if equipment == "body weight" {
            // Exclude weighted variations of bodyweight exercises
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
                    return false // This is a weighted variation
                }
            }
            
            return true // Pure bodyweight exercise
        }
        
        // Check for exercises that might be bodyweight but not labeled as such
        // Some exercises might use minimal equipment but are essentially bodyweight
        if equipment == "assisted" || equipment == "suspension" {
            return true
        }
        
        // Check for bodyweight exercises that might be miscategorized
        let bodyweightNames = [
            "push-up",
            "push up",
            "pull-up",
            "pull up",
            "chin-up",
            "chin up",
            "sit-up",
            "sit up",
            "squat",
            "lunge",
            "plank",
            "burpee",
            "jumping jack",
            "mountain climber",
            "crunches",
            "leg raise",
            "pike",
            "bridge",
            "dip"
        ]
        
        // Only include these if they don't explicitly use weights
        let nonWeightedEquipment = [
            "body weight",
            "assisted",
            "suspension",
            ""
        ]
        
        if nonWeightedEquipment.contains(equipment) {
            for bodyweightName in bodyweightNames {
                if name.contains(bodyweightName) {
                    // Double-check it's not a weighted variation
                    let weightedKeywords = [
                        "weighted",
                        "dumbbell",
                        "barbell",
                        "kettlebell",
                        "cable",
                        "smith",
                        "leverage",
                        "medicine ball"
                    ]
                    
                    for keyword in weightedKeywords {
                        if name.contains(keyword) {
                            return false
                        }
                    }
                    
                    return true
                }
            }
        }
        
        return false
    }
}

#Preview {
    NavigationView {
        BodyweightExercisesView { exercises in
            print("Selected bodyweight exercises: \(exercises.map { $0.name })")
        }
    }
}
