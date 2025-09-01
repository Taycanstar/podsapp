//
//  DynamicSetsInputView.swift
//  pods
//
//  Created by Claude on 8/28/25.
//

import SwiftUI

/// Dynamic sets input view that adapts to different exercise tracking types
struct DynamicSetsInputView: View {
    @Binding var sets: [FlexibleSetData]
    let exercise: ExerciseData
    let trackingType: ExerciseTrackingType
    let onSetCompleted: ((Int) -> Void)?
    let onAddSet: (() -> Void)?
    let onRemoveSet: ((Int) -> Void)?
    let onDurationChanged: ((TimeInterval) -> Void)?
    let onSetFocused: ((Int?) -> Void)? // Callback when a set gains/loses focus
    
    @State private var showingAddSetOptions = false
    @FocusState private var focusedSetIndex: Int?
    
    init(
        sets: Binding<[FlexibleSetData]>,
        exercise: ExerciseData,
        trackingType: ExerciseTrackingType,
        onSetCompleted: ((Int) -> Void)? = nil,
        onAddSet: (() -> Void)? = nil,
        onRemoveSet: ((Int) -> Void)? = nil,
        onDurationChanged: ((TimeInterval) -> Void)? = nil,
        onSetFocused: ((Int?) -> Void)? = nil
    ) {
        self._sets = sets
        self.exercise = exercise
        self.trackingType = trackingType
        self.onSetCompleted = onSetCompleted
        self.onAddSet = onAddSet
        self.onRemoveSet = onRemoveSet
        self.onDurationChanged = onDurationChanged
        self.onSetFocused = onSetFocused
    }
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                // Sets section with swipe-to-delete
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    DynamicSetRowView(
                        set: binding(for: index),
                        setNumber: index + 1,
                        exercise: exercise,
                        onDurationChanged: onDurationChanged,
                        isActive: index == focusedSetIndex,
                        onFocusChanged: { focused in
                            if focused {
                                focusedSetIndex = index
                            } else if focusedSetIndex == index {
                                focusedSetIndex = nil
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteSet(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                
                // Add Set/Interval button as List row
                Section {
                    addSetButton
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true) // KEY: Let parent ScrollView handle scrolling
            .frame(height: calculateListHeight()) // KEY: Give List explicit height
        }
        .onAppear {
            initializeSetsIfNeeded()
        }
        .onChange(of: focusedSetIndex) { _, newValue in
            handleFocusChange(newValue)
        }
    }
    
    // MARK: - Helper Views and Methods
    
    private func handleFocusChange(_ newValue: Int?) {
        onSetFocused?(newValue)
    }
    
    @ViewBuilder
    private var addSetButton: some View {
        if trackingType == .repsWeight {
            Button(action: addSet) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Set")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.clear)
                .cornerRadius(8)
            }
        } else {
            Button(action: addSet) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add Interval")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }
    
    // CRITICAL: Calculate height for List content to prevent disappearing
    private func calculateListHeight() -> CGFloat {
        let baseRowHeight: CGFloat = 60 // Base height of DynamicSetRowView
        let pickerHeight: CGFloat = 180 // Height of inline time picker
        let buttonHeight: CGFloat = 52 // Height of add set button
        let spacing: CGFloat = 8 // Spacing between rows
        
        // Check if any set might have an expanded picker (duration-based exercises)
        let hasExpandableContent = trackingType == .timeDistance || trackingType == .timeOnly || 
                                 trackingType == .holdTime || trackingType == .rounds
        
        // Base calculation for all sets
        let setsHeight = CGFloat(sets.count) * baseRowHeight + CGFloat(max(0, sets.count - 1)) * spacing
        
        // For duration exercises: allow reasonable space for potential picker expansion
        // Allow for 2 expanded pickers max to avoid excessive height
        let maxExpandedPickers = min(sets.count, 2)
        let extraPickerSpace: CGFloat = hasExpandableContent ? CGFloat(maxExpandedPickers) * (pickerHeight + 20) : 0
        
        let totalHeight = setsHeight + buttonHeight + extraPickerSpace + 32 // Extra padding
        
        return totalHeight
    }
    
    private func initializeSetsIfNeeded() {
        if sets.isEmpty {
            // Add default number of sets based on tracking type
            let defaultSets = defaultSetCount(for: trackingType)
            for _ in 0..<defaultSets {
                sets.append(FlexibleSetData(trackingType: trackingType))
            }
        }
    }
    
    private func defaultSetCount(for type: ExerciseTrackingType) -> Int {
        switch type {
        case .repsWeight:
            return 3 // Traditional 3 sets for strength
        case .timeDistance, .timeOnly:
            return 1 // Cardio/aerobic exercises typically 1 session
        // Handle legacy types that might still exist in saved data
        case .repsOnly:
            return 3 // Treat as strength exercise
        case .holdTime, .rounds:
            return 1 // Treat as duration exercises
        }
    }
    
    private func addSet() {
        let newSet = FlexibleSetData(trackingType: trackingType)
        sets.append(newSet)
        onAddSet?()
    }
    
    private func deleteSet(at indexSet: IndexSet) {
        guard sets.count > 1 else { return } // Don't allow deleting the last set
        sets.remove(atOffsets: indexSet)
        if let firstIndex = indexSet.first {
            onRemoveSet?(firstIndex)
        }
    }
    
    private func deleteSet(at index: Int) {
        guard sets.count > 1 else { return } // Don't allow deleting the last set
        guard index >= 0 && index < sets.count else { return }
        sets.remove(at: index)
        onRemoveSet?(index)
    }
    
    private func binding(for index: Int) -> Binding<FlexibleSetData> {
        return Binding(
            get: { sets[index] },
            set: { 
                sets[index] = $0
                if $0.isCompleted {
                    onSetCompleted?(index)
                }
            }
        )
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Strength exercise preview
            DynamicSetsInputView(
                sets: .constant([
                    FlexibleSetData(trackingType: .repsWeight),
                    FlexibleSetData(trackingType: .repsWeight),
                    FlexibleSetData(trackingType: .repsWeight)
                ]),
                exercise: ExerciseData(id: 1, name: "Barbell Bench Press", exerciseType: "Strength", bodyPart: "Chest", equipment: "Barbell", gender: "Male", target: "Pectoralis Major", synergist: "Deltoid Anterior, Triceps"),
                trackingType: .repsWeight
            )
            
            Divider()
            
            // Cardio exercise preview
            DynamicSetsInputView(
                sets: .constant([
                    FlexibleSetData(trackingType: .timeDistance)
                ]),
                exercise: ExerciseData(id: 2, name: "Running", exerciseType: "Aerobic", bodyPart: "Cardio", equipment: "Body weight", gender: "Male", target: "Cardiovascular System", synergist: ""),
                trackingType: .timeDistance
            )
        }
        .padding()
    }
}