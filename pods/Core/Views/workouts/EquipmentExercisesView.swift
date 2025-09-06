//
//  EquipmentExercisesView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/22/25.
//

import SwiftUI

struct EquipmentExercisesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedExercises: Set<Int> = []
    @State private var exercises: [ExerciseData] = []
    
    let equipmentName: String
    let equipmentType: String
    let onExercisesSelected: ([ExerciseData]) -> Void
    
    init(equipmentName: String, equipmentType: String, onExercisesSelected: @escaping ([ExerciseData]) -> Void) {
        self.equipmentName = equipmentName
        self.equipmentType = equipmentType
        self.onExercisesSelected = onExercisesSelected
    }
    
    var body: some View {
        contentView
            .background(Color(.systemBackground))
        .navigationTitle(equipmentName)
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
                    // Dismiss this view and let the parent handle closing the sheet
                    dismiss()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.accentColor)
                .disabled(selectedExercises.isEmpty)
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
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
        let equipmentFiltered = exercises.filter { exercise in
            matchesEquipment(exercise: exercise, equipmentType: equipmentType)
        }
        
        if searchText.isEmpty {
            return equipmentFiltered.sorted { $0.name < $1.name }
        } else {
            return equipmentFiltered.filter { exercise in
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
        print("🏋️ EquipmentExercisesView: Loaded \(self.exercises.count) exercises for \(equipmentName)")
    }
    
    private func matchesEquipment(exercise: ExerciseData, equipmentType: String) -> Bool {
        // Handle body weight exercises
        if equipmentType == "" {
            return exercise.equipment.lowercased() == "body weight"
        }
        
        // Direct equipment match
        if exercise.equipment.lowercased().contains(equipmentType.lowercased()) {
            return true
        }
        
        // Handle specific equipment mappings based on exercise names and equipment field
        switch equipmentType {
        case "barbells":
            return exercise.equipment.lowercased().contains("barbell") || 
                   exercise.name.lowercased().contains("barbell")
        case "dumbbells":
            return exercise.equipment.lowercased().contains("dumbbell") || 
                   exercise.name.lowercased().contains("dumbbell")
        case "crossovercable":
            return exercise.equipment.lowercased().contains("cable") || 
                   exercise.name.lowercased().contains("cable")
        case "smith":
            return exercise.equipment.lowercased().contains("smith") || 
                   exercise.name.lowercased().contains("smith")
        case "hammerstrength":
            return exercise.equipment.lowercased().contains("leverage") || 
                   exercise.name.lowercased().contains("leverage")
        case "kbells":
            return exercise.equipment.lowercased().contains("kettlebell") || 
                   exercise.name.lowercased().contains("kettlebell")
        case "handlebands":
            return exercise.equipment.lowercased().contains("band") || 
                   exercise.name.lowercased().contains("band")
        case "swissball":
            return exercise.equipment.lowercased().contains("stability") || 
                   exercise.name.lowercased().contains("stability ball") ||
                   exercise.name.lowercased().contains("swiss ball")
        case "battleropes":
            return exercise.equipment.lowercased().contains("rope") || 
                   exercise.name.lowercased().contains("rope")
        case "ezbar":
            return exercise.equipment.lowercased().contains("ez") || 
                   exercise.name.lowercased().contains("ez bar")
        case "bosu":
            return exercise.equipment.lowercased().contains("bosu") || 
                   exercise.name.lowercased().contains("bosu")
        case "sled":
            return exercise.equipment.lowercased().contains("sled") || 
                   exercise.name.lowercased().contains("sled")
        case "medballs":
            return exercise.equipment.lowercased().contains("medicine") || 
                   exercise.name.lowercased().contains("medicine ball")
        case "flatbench":
            return exercise.name.lowercased().contains("bench press") ||
                   exercise.name.lowercased().contains("bench dip") ||
                   (exercise.equipment.lowercased().contains("barbell") && exercise.name.lowercased().contains("bench"))
        case "declinebench":
            return exercise.name.lowercased().contains("decline bench")
        case "preachercurlmachine":
            return exercise.name.lowercased().contains("preacher curl")
        case "inclinebench":
            return exercise.name.lowercased().contains("incline bench")
        case "latpulldown":
            return exercise.name.lowercased().contains("lat pulldown") ||
                   exercise.name.lowercased().contains("pulldown")
        case "legextmachine":
            return exercise.name.lowercased().contains("leg extension")
        case "legcurlmachine":
            return exercise.name.lowercased().contains("leg curl")
        case "calfraisesmachine":
            return exercise.name.lowercased().contains("calf raise")
        case "seatedrow":
            return exercise.name.lowercased().contains("seated row") ||
                   exercise.name.lowercased().contains("cable row")
        case "legpress":
            return exercise.name.lowercased().contains("leg press")
        case "pullupbar":
            return exercise.name.lowercased().contains("pull-up") ||
                   exercise.name.lowercased().contains("pull up") ||
                   exercise.name.lowercased().contains("chin-up") ||
                   exercise.name.lowercased().contains("chin up")
        case "dipbar":
            return exercise.name.lowercased().contains("dip") && 
                   exercise.equipment.lowercased() == "body weight"
        case "squatrack":
            return (exercise.name.lowercased().contains("squat") && 
                    exercise.equipment.lowercased().contains("barbell")) ||
                   exercise.name.lowercased().contains("rack")
        case "box":
            return exercise.name.lowercased().contains("box jump") ||
                   exercise.name.lowercased().contains("box squat") ||
                   exercise.name.lowercased().contains("step up")
        case "platforms":
            return exercise.name.lowercased().contains("step up") ||
                   exercise.name.lowercased().contains("platform")
        case "hacksquat":
            return exercise.name.lowercased().contains("hack squat")
        case "shoulderpress":
            return exercise.name.lowercased().contains("shoulder press") && 
                   exercise.equipment.lowercased().contains("leverage")
        case "tricepext":
            return exercise.name.lowercased().contains("tricep extension") && 
                   exercise.equipment.lowercased().contains("leverage")
        case "bicepscurlmachine":
            return exercise.name.lowercased().contains("bicep curl") && 
                   exercise.equipment.lowercased().contains("leverage")
        case "abcrunch":
            return exercise.name.lowercased().contains("crunch") && 
                   exercise.equipment.lowercased().contains("leverage")
        default:
            return false
        }
    }
}

#Preview {
    NavigationView {
        EquipmentExercisesView(
            equipmentName: "Dumbbells",
            equipmentType: "dumbbells"
        ) { exercises in
            print("Selected exercises: \(exercises.map { $0.name })")
        }
    }
} 
