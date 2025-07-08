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
        VStack(spacing: 0) {
            // Background color
            Color(.systemBackground)
                .ignoresSafeArea(.all)
                .overlay(contentView)
        }
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
        let equipment = exercise.equipment.lowercased()
        let name = exercise.name.lowercased()
        let bodyPart = exercise.bodyPart.lowercased()
        let target = exercise.target.lowercased()
        
        // Cardio equipment
        let cardioEquipment = [
            "cardio machine",
            "treadmill",
            "stationary bike",
            "elliptical",
            "rowing machine",
            "stair climber",
            "stepper",
            "bike",
            "cycle",
            "rower"
        ]
        
        // Check if equipment is cardio-specific
        for cardioEq in cardioEquipment {
            if equipment.contains(cardioEq) {
                return true
            }
        }
        
        // Cardio exercise names
        let cardioNames = [
            "run",
            "running",
            "jog",
            "jogging",
            "walk",
            "walking",
            "sprint",
            "sprinting",
            "cycle",
            "cycling",
            "bike",
            "biking",
            "swim",
            "swimming",
            "row",
            "rowing",
            "jump",
            "jumping",
            "hop",
            "hopping",
            "skip",
            "skipping",
            "burpee",
            "burpees",
            "jumping jack",
            "jumping jacks",
            "mountain climber",
            "mountain climbers",
            "high knees",
            "butt kickers",
            "box jump",
            "box jumps",
            "plyometric",
            "plyo",
            "hiit",
            "interval",
            "aerobic",
            "cardio",
            "endurance",
            "conditioning",
            "agility",
            "shuttle run",
            "ladder drill",
            "cone drill",
            "stair climb",
            "step up",
            "step ups",
            "battle rope",
            "battle ropes",
            "kettlebell swing",
            "medicine ball slam",
            "thrusters",
            "squat jump",
            "squat jumps",
            "lunge jump",
            "lunge jumps",
            "broad jump",
            "long jump",
            "vertical jump",
            "tuck jump",
            "star jump",
            "cross trainer",
            "elliptical"
        ]
        
        // Check if exercise name contains cardio keywords
        for cardioName in cardioNames {
            if name.contains(cardioName) {
                return true
            }
        }
        
        // Check body part and target for cardio indicators
        let cardioBodyParts = [
            "cardio",
            "cardiovascular",
            "aerobic",
            "conditioning"
        ]
        
        for cardioPart in cardioBodyParts {
            if bodyPart.contains(cardioPart) || target.contains(cardioPart) {
                return true
            }
        }
        
        // Check exercise type for cardio
        let exerciseType = exercise.exerciseType.lowercased()
        if exerciseType.contains("cardio") || exerciseType.contains("aerobic") || exerciseType.contains("conditioning") {
            return true
        }
        
        // High-intensity bodyweight exercises that are primarily cardio
        if equipment == "body weight" {
            let bodyweightCardio = [
                "burpee",
                "jumping jack",
                "mountain climber",
                "high knees",
                "butt kickers",
                "squat jump",
                "lunge jump",
                "tuck jump",
                "star jump",
                "plank jack",
                "jump squat",
                "jump lunge",
                "broad jump",
                "vertical jump",
                "lateral jump",
                "single leg hop",
                "double leg hop",
                "side shuffle",
                "bear crawl",
                "crab walk",
                "frog jump",
                "split jump",
                "scissor jump"
            ]
            
            for bwCardio in bodyweightCardio {
                if name.contains(bwCardio) {
                    return true
                }
            }
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
