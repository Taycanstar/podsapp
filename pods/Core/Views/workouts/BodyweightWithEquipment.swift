//
//  BodyweightWithEquipment.swift
//  Pods
//
//  Created by Dimi Nunez on 7/8/25.
//

import SwiftUI

struct BodyweightWithEquipment: View {
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
        .navigationTitle("Bodyweight with Equipment")
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
        .searchable(text: $searchText, prompt: "Search bodyweight with equipment")
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
        let bodyweightWithEquipmentFiltered = exercises.filter { exercise in
            isBodyweightWithEquipment(exercise: exercise)
        }
        
        if searchText.isEmpty {
            return bodyweightWithEquipmentFiltered.sorted { $0.name < $1.name }
        } else {
            return bodyweightWithEquipmentFiltered.filter { exercise in
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
        print("🏋️ BodyweightWithEquipment: Loaded \(self.exercises.count) exercises")
    }
    
    private func isBodyweightWithEquipment(exercise: ExerciseData) -> Bool {
        let equipment = exercise.equipment.lowercased()
        let name = exercise.name.lowercased()
        let exerciseType = exercise.exerciseType.lowercased()
        
        // Only include strength exercises (exclude cardio and stretching)
        if exerciseType != "strength" {
            return false
        }
        
        // Equipment that supports bodyweight exercises (not heavy weights)
        let bodyweightEquipment = [
            "band",
            "stability ball",
            "bosu ball",
            "pull up bar",
            "dip (parallel) bar",
            "rope",
            "medicine ball"
        ]
        
        // Check if equipment matches bodyweight-friendly equipment
        for bwEquipment in bodyweightEquipment {
            if equipment.contains(bwEquipment) {
                return true
            }
        }
        
        // Exclude heavy weight equipment
        let heavyWeightEquipment = [
            "barbell",
            "dumbbell",
            "kettlebell",
            "smith",
            "leverage",
            "cable",
            "flat bench",
            "incline bench",
            "decline bench",
            "weighted"
        ]
        
        for heavyEquipment in heavyWeightEquipment {
            if equipment.contains(heavyEquipment) {
                return false
            }
        }
        
        // Special case: Pure bodyweight exercises that mention equipment assistance
        if equipment == "body weight" {
            let assistedKeywords = [
                "assisted",
                "elevated",
                "incline",
                "decline"
            ]
            
            for keyword in assistedKeywords {
                if name.contains(keyword) {
                    return true
                }
            }
        }
        
        return false
    }
}

#Preview {
    NavigationView {
        BodyweightWithEquipment { exercises in
            print("Selected bodyweight with equipment exercises: \(exercises.map { $0.name })")
        }
    }
}
