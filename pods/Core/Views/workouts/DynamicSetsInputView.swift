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
    let workoutExercise: TodayWorkoutExercise
    let trackingType: ExerciseTrackingType
    let onSetCompleted: ((Int) -> Void)?
    let onAddSet: (() -> Void)?
    let onRemoveSet: ((Int) -> Void)?
    let onDurationChanged: ((TimeInterval) -> Void)?
    let onSetFocused: ((Int?) -> Void)? // Callback when a set gains/loses focus
    let onSetDataChanged: (() -> Void)? // Callback when set data changes
    
    @State private var showingAddSetOptions = false
    @FocusState private var focusedSetIndex: Int?
    @State private var hasExpandedPicker = false
    
    init(
        sets: Binding<[FlexibleSetData]>,
        workoutExercise: TodayWorkoutExercise,
        trackingType: ExerciseTrackingType,
        onSetCompleted: ((Int) -> Void)? = nil,
        onAddSet: (() -> Void)? = nil,
        onRemoveSet: ((Int) -> Void)? = nil,
        onDurationChanged: ((TimeInterval) -> Void)? = nil,
        onSetFocused: ((Int?) -> Void)? = nil,
        onSetDataChanged: (() -> Void)? = nil
    ) {
        self._sets = sets
        self.workoutExercise = workoutExercise
        self.trackingType = trackingType
        self.onSetCompleted = onSetCompleted
        self.onAddSet = onAddSet
        self.onRemoveSet = onRemoveSet
        self.onDurationChanged = onDurationChanged
        self.onSetFocused = onSetFocused
        self.onSetDataChanged = onSetDataChanged
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // DEBUG: Print rendering details
            let _ = print("🔴 DEBUG DynamicSetsInputView rendering:")
            let _ = print("🔴 - Exercise: \(workoutExercise.exercise.name)")
            let _ = print("🔴 - TrackingType: \(trackingType)")
            let _ = print("🔴 - Sets count: \(sets.count)")
            
            // List with proper height calculation for parent ScrollView integration
            let calculatedHeight = calculateListHeight()
            let _ = print("🔵 About to render List with height: \(calculatedHeight)")
            
            List {
                setsForEachView
            }
            .frame(height: hasExpandedPicker ? calculatedHeight + 180 : calculatedHeight)
            .listStyle(.plain)
            .scrollDisabled(true)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasExpandedPicker)
            
            // Add button OUTSIDE the list
            let _ = print("🔴 - Rendering add button for trackingType: \(trackingType)")
            addSetButton
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .onAppear {
            print("🔴 DEBUG DynamicSetsInputView.onAppear called")
            initializeSetsIfNeeded()
        }
        .onChange(of: focusedSetIndex) { _, newValue in
            handleFocusChange(newValue)
        }
    }
    
    // MARK: - Helper Views and Methods
    
    @ViewBuilder
    private var setsForEachView: some View {
        // Sets section with swipe-to-delete
        let _ = print("🟢 DEBUG setsForEachView: About to render \(sets.count) sets")
        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
            let _ = print("🟢 - Rendering set \(index + 1): \(set)")
            DynamicSetRowView(
                set: binding(for: index),
                setNumber: index + 1,
                workoutExercise: workoutExercise,
                onDurationChanged: onDurationChanged,
                isActive: index == focusedSetIndex,
                onFocusChanged: { focused in
                    if focused {
                        focusedSetIndex = index
                    } else if focusedSetIndex == index {
                        focusedSetIndex = nil
                    }
                },
                onSetChanged: onSetDataChanged,
                onPickerStateChanged: { isExpanded in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        hasExpandedPicker = isExpanded
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
    }
    
    
    private func handleFocusChange(_ newValue: Int?) {
        onSetFocused?(newValue)
    }
    
    @ViewBuilder
    private var addSetButton: some View {
        let _ = print("🔴 DEBUG addSetButton: trackingType = \(trackingType)")
        if trackingType == .repsWeight {
            let _ = print("🔴 DEBUG addSetButton: Creating 'Add Set' button")
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
            .contentShape(Rectangle())
            .onTapGesture {
                print("🔧 DEBUG: Add Set tapped directly")
                addSet()
            }
        } else {
            let _ = print("🔴 DEBUG addSetButton: Creating 'Add Interval' button")
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add Interval")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
            .onTapGesture {
                print("🔧 DEBUG: Add Interval tapped directly")
                addSet()
            }
        }
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
        print("🔧 DEBUG: ========== addSet() CALLED ==========")
        print("🔧 DEBUG: DynamicSetsInputView.addSet() called - Current sets count: \(sets.count)")
        print("🔧 DEBUG: DynamicSetsInputView - trackingType: \(trackingType)")
        
        // Add haptic feedback to confirm button tap
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // DON'T add the set here - let the parent handle it via callback
        print("🔧 DEBUG: DynamicSetsInputView - Calling onAddSet callback (parent will add the set)")
        onAddSet?()
        print("🔧 DEBUG: ========== addSet() FINISHED ==========")
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
    
    // MARK: - Height Calculation
    
    private func calculateListHeight() -> CGFloat {
        let baseRowHeight: CGFloat = 48 // Tighter height for collapsed DynamicSetRowView
        let spacing: CGFloat = 8 // Minimal spacing between rows
        let padding: CGFloat = 4 // Minimal top/bottom padding
        
        // Base calculation for all sets - much more conservative
        let totalHeight = CGFloat(sets.count) * baseRowHeight + CGFloat(max(0, sets.count - 1)) * spacing + padding
        
        print("🔵 DEBUG calculateListHeight:")
        print("🔵 - Sets count: \(sets.count)")
        print("🔵 - Base height per row: \(baseRowHeight)")
        print("🔵 - Calculated total height: \(totalHeight)")
        
        // Minimal height - let List size naturally
        let finalHeight = totalHeight
        
        print("🔵 - Final height returned: \(finalHeight)")
        
        return finalHeight
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
                workoutExercise: TodayWorkoutExercise(
                    exercise: ExerciseData(id: 1, name: "Barbell Bench Press", exerciseType: "Strength", bodyPart: "Chest", equipment: "Barbell", gender: "Male", target: "Pectoralis Major", synergist: "Deltoid Anterior, Triceps"),
                    sets: 3, reps: 8, weight: 135, restTime: 90, notes: nil, warmupSets: nil
                ),
                trackingType: .repsWeight
            )
            
            Divider()
            
            // Cardio exercise preview
            DynamicSetsInputView(
                sets: .constant([
                    FlexibleSetData(trackingType: .timeDistance)
                ]),
                workoutExercise: TodayWorkoutExercise(
                    exercise: ExerciseData(id: 2, name: "Running", exerciseType: "Aerobic", bodyPart: "Cardio", equipment: "Body weight", gender: "Male", target: "Cardiovascular System", synergist: ""),
                    sets: 1, reps: 1, weight: 0, restTime: 60, notes: nil, warmupSets: nil
                ),
                trackingType: .timeDistance
            )
        }
        .padding()
    }
}