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
        VStack(spacing: 0) {
            // Background color
            Color(.systemBackground)
                .ignoresSafeArea(.all)
                .overlay(contentView)
        }
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
        let equipment = exercise.equipment.lowercased()
        let name = exercise.name.lowercased()
        let bodyPart = exercise.bodyPart.lowercased()
        let target = exercise.target.lowercased()
        let exerciseType = exercise.exerciseType.lowercased()
        
        // Stretching and mobility equipment
        let mobilityEquipment = [
            "foam roller",
            "massage ball",
            "lacrosse ball",
            "theraband",
            "resistance band",
            "yoga mat",
            "stretching strap",
            "mobility stick",
            "roller",
            "massage roller",
            "trigger point",
            "pvc pipe",
            "tennis ball"
        ]
        
        // Check if equipment is mobility-specific
        for mobilityEq in mobilityEquipment {
            if equipment.contains(mobilityEq) {
                return true
            }
        }
        
        // Stretching and mobility exercise names
        let stretchMobilityNames = [
            "stretch",
            "stretching",
            "mobility",
            "flexibility",
            "foam roll",
            "foam rolling",
            "massage",
            "myofascial release",
            "trigger point",
            "self massage",
            "dynamic warm",
            "static stretch",
            "passive stretch",
            "active stretch",
            "pnf stretch",
            "range of motion",
            "rom",
            "hip circle",
            "shoulder roll",
            "neck roll",
            "arm circle",
            "leg swing",
            "hip flexor stretch",
            "hamstring stretch",
            "quad stretch",
            "calf stretch",
            "chest stretch",
            "shoulder stretch",
            "back stretch",
            "spinal twist",
            "cat cow",
            "child's pose",
            "downward dog",
            "cobra stretch",
            "pigeon pose",
            "figure four",
            "butterfly stretch",
            "seated twist",
            "standing twist",
            "side bend",
            "lateral stretch",
            "forward fold",
            "back bend",
            "hip opener",
            "shoulder opener",
            "thoracic spine",
            "cervical spine",
            "lumbar spine",
            "ankle circle",
            "wrist circle",
            "toe touch",
            "reach",
            "extension",
            "flexion",
            "rotation",
            "lateral flexion",
            "abduction",
            "adduction",
            "internal rotation",
            "external rotation",
            "scapular",
            "glute activation",
            "hip activation",
            "core activation",
            "warm up",
            "cool down",
            "recovery",
            "relaxation",
            "breathing",
            "meditation",
            "mindfulness",
            "yoga",
            "pilates",
            "tai chi",
            "qigong",
            "feldenkrais",
            "alexander technique",
            "corrective exercise",
            "postural",
            "alignment",
            "balance",
            "proprioception",
            "neuromuscular",
            "activation",
            "release",
            "decompression",
            "mobilization",
            "manipulation",
            "adjustment",
            "reset",
            "restore",
            "rejuvenate",
            "rehabilitate",
            "therapy",
            "therapeutic"
        ]
        
        // Check if exercise name contains stretching/mobility keywords
        for stretchName in stretchMobilityNames {
            if name.contains(stretchName) {
                return true
            }
        }
        
        // Check body part and target for mobility indicators
        let mobilityBodyParts = [
            "flexibility",
            "mobility",
            "stretching",
            "range of motion",
            "recovery",
            "warm up",
            "cool down",
            "therapeutic",
            "corrective",
            "postural",
            "alignment",
            "balance",
            "proprioception",
            "activation",
            "release",
            "decompression"
        ]
        
        for mobilityPart in mobilityBodyParts {
            if bodyPart.contains(mobilityPart) || target.contains(mobilityPart) {
                return true
            }
        }
        
        // Check exercise type for stretching/mobility
        let mobilityTypes = [
            "stretch",
            "stretching",
            "mobility",
            "flexibility",
            "recovery",
            "warm up",
            "cool down",
            "therapeutic",
            "corrective",
            "postural",
            "balance",
            "proprioception",
            "activation",
            "release",
            "decompression",
            "yoga",
            "pilates",
            "tai chi",
            "qigong"
        ]
        
        for mobilityType in mobilityTypes {
            if exerciseType.contains(mobilityType) {
                return true
            }
        }
        
        // Body weight exercises that are primarily stretching/mobility
        if equipment == "body weight" {
            let bodyweightMobility = [
                "cat cow",
                "child's pose",
                "downward dog",
                "cobra",
                "pigeon",
                "warrior",
                "triangle",
                "forward fold",
                "side bend",
                "spinal twist",
                "seated twist",
                "standing twist",
                "hip circle",
                "arm circle",
                "leg swing",
                "shoulder roll",
                "neck roll",
                "ankle circle",
                "wrist circle",
                "toe touch",
                "reach",
                "butterfly",
                "figure four",
                "knee to chest",
                "hip flexor",
                "calf raise",
                "heel walk",
                "toe walk",
                "bear crawl",
                "crab walk",
                "lizard crawl",
                "duck walk",
                "lateral walk",
                "side step",
                "high knees",
                "butt kickers",
                "leg swing",
                "arm swing",
                "torso twist",
                "shoulder shrug",
                "neck stretch",
                "eye movement",
                "jaw exercise",
                "breathing exercise",
                "meditation",
                "relaxation",
                "mindfulness"
            ]
            
            for bwMobility in bodyweightMobility {
                if name.contains(bwMobility) {
                    return true
                }
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
