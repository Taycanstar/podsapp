//
//  SupersetCircuitSelectionSheet.swift
//  Pods
//
//  Created by Codex on 2024-08-31.
//

import SwiftUI

struct SupersetCircuitSelectionSheet: View {
    struct ExerciseItem: Identifiable {
        let id: UUID
        let index: Int
        let exercise: TodayWorkoutExercise
    }

    private let workout: TodayWorkout
    private let onCreate: (BlockCreationService.CreationResult) -> Void
    private let exerciseItems: [ExerciseItem]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedExercises: Set<UUID> = []
    @State private var errorMessage: String?

    init(workout: TodayWorkout, onCreate: @escaping (BlockCreationService.CreationResult) -> Void) {
        self.workout = workout
        self.onCreate = onCreate
        self.exerciseItems = workout.exercises.enumerated().map { index, exercise in
            ExerciseItem(id: UUID(), index: index, exercise: exercise)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                exerciseList

                VStack {
                    actionButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .padding(.bottom, 28)
            }
            .navigationTitle("Build Superset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var exerciseList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if circuitOrSupersetBlocks.isEmpty {
                    exerciseContainer(for: nonGroupedItems)
                } else {
                    ForEach(Array(circuitOrSupersetBlocks.enumerated()), id: \.offset) { _, block in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(block.exercises.count >= 3 ? "Circuit" : "Superset")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            exerciseContainer(for: orderedItems(for: block))
                        }
                    }

                    if !nonGroupedItems.isEmpty {
                        exerciseContainer(for: nonGroupedItems)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }

                // Spacer to ensure content isn't obscured by floating button
                Color.clear.frame(height: 140)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var circuitOrSupersetBlocks: [WorkoutBlock] {
        (workout.blocks ?? []).filter { ($0.type == .circuit || $0.type == .superset) && $0.exercises.count >= 2 }
    }

    private var groupedExerciseIds: Set<Int> {
        Set(circuitOrSupersetBlocks.flatMap { $0.exercises.map { $0.exercise.id } })
    }

    private var nonGroupedItems: [ExerciseItem] {
        var seen = Set<Int>()
        return exerciseItems.filter { item in
            let exerciseId = item.exercise.exercise.id
            guard !groupedExerciseIds.contains(exerciseId) else { return false }
            return seen.insert(exerciseId).inserted
        }
    }

    private var itemsGroupedByExerciseId: [Int: [ExerciseItem]] {
        Dictionary(grouping: exerciseItems, by: { $0.exercise.exercise.id })
    }

    private func orderedItems(for block: WorkoutBlock) -> [ExerciseItem] {
        var occurrenceCounter: [Int: Int] = [:]
        var ordered: [ExerciseItem] = []

        for blockExercise in block.exercises {
            let exerciseId = blockExercise.exercise.id
            let occurrence = occurrenceCounter[exerciseId, default: 0]
            let matches = itemsGroupedByExerciseId[exerciseId] ?? []
            if occurrence < matches.count {
                ordered.append(matches[occurrence])
            }
            occurrenceCounter[exerciseId] = occurrence + 1
        }

        return ordered
    }

    @ViewBuilder
    private func exerciseContainer(for items: [ExerciseItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                selectionCard(for: item)
                if idx != items.count - 1 {
                    Divider().opacity(0.08)
                }
            }
        }
    }

    private func selectionCard(for item: ExerciseItem) -> some View {
        let isSelected = selectedExercises.contains(item.id)
        return ExerciseWorkoutCard(
            exercise: item.exercise,
            allExercises: workout.exercises,
            exerciseIndex: item.index,
            onExerciseReplaced: { _, _ in },
            onOpen: {},
            useBackground: false,
            isSelectable: true,
            isSelected: isSelected,
            onSelectionToggle: { toggleSelection(for: item.id) },
            showsContextMenu: false
        )
    }

    private var actionButton: some View {
        Button(action: createBlock) {
            Text(buttonTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isSelectionValid ? .primary : .primary.opacity(0.4))
                .cornerRadius(100)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
        }
        .disabled(!isSelectionValid)
    }

    private var buttonTitle: String {
        selectionCount >= 3 ? "Create Circuit" : "Create Superset"
    }

    private var selectionCount: Int { selectedExercises.count }

    private var isSelectionValid: Bool { selectionCount >= 2 }

    private func toggleSelection(for id: UUID) {
        if selectedExercises.contains(id) {
            selectedExercises.remove(id)
        } else {
            selectedExercises.insert(id)
        }
        errorMessage = nil
    }

    private func createBlock() {
        guard isSelectionValid else { return }
        let indices = exerciseItems
            .filter { selectedExercises.contains($0.id) }
            .map { $0.index }
        do {
            let result = try BlockCreationService.createBlock(from: workout, selectedIndices: indices)
            onCreate(result)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
