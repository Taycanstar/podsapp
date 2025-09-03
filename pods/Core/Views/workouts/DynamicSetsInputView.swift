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
    @State private var expandedPickerIndex: Int? = nil
    
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
        VStack(spacing: 0) {
            // DEBUG: Print rendering details
            let _ = print("🔴 DEBUG DynamicSetsInputView rendering:")
            let _ = print("🔴 - Exercise: \(workoutExercise.exercise.name)")
            let _ = print("🔴 - TrackingType: \(trackingType)")
            let _ = print("🔴 - Sets count: \(sets.count)")
            let _ = print("🔴 - onAddSet callback exists: \(onAddSet != nil)")
            
            // List with proper height calculation for parent ScrollView integration
            let calculatedHeight = calculateListHeight()
            let _ = print("🔵 About to render List with height: \(calculatedHeight)")
            
            List {
                let _ = print("🔴 DEBUG: About to render setsForEachView which includes addSetButtonRow")
                setsForEachView
            }
            .listStyle(.plain)
            .scrollDisabled(true) // Allow scrolling when content exceeds available space
            .frame(height: min(expandedPickerIndex != nil ? calculatedHeight + 200 : calculatedHeight, 600)) // Cap max height to ensure usability
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: expandedPickerIndex)
            .onChange(of: expandedPickerIndex) { oldValue, newValue in
                print("🟢 DEBUG: expandedPickerIndex changed from \(String(describing: oldValue)) to \(String(describing: newValue))")
                print("🟢 DEBUG: Height will be \(newValue != nil ? calculatedHeight + 200 : calculatedHeight)")
            }
            
             
                // .padding(.vertical, 8)
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
                        expandedPickerIndex = isExpanded ? index : nil
                    }
                }
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
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
        
        // Add button as final row in List
        addSetButtonRow
    }
    
    
    private func handleFocusChange(_ newValue: Int?) {
        onSetFocused?(newValue)
    }
    
    @ViewBuilder
    private var addSetButtonRow: some View {
        let _ = print("🔴 DEBUG addSetButtonRow: RENDERING! trackingType = \(trackingType)")
        let _ = print("🔴 DEBUG addSetButtonRow: onAddSet callback exists = \(onAddSet != nil)")
        if trackingType == .repsWeight {
            let _ = print("🔴 DEBUG addSetButtonRow: Creating 'Add Set' button")
            Button(action: {
                print("🔧 DEBUG: Add Set button tapped")
                addSet()
            }) {
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
            .buttonStyle(PlainButtonStyle()) // Ensure button styling works in List
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            let _ = print("🔴 DEBUG addSetButtonRow: Creating 'Add Interval' button")
            Button(action: {
                print("🔧 DEBUG: Add Interval button tapped")
                addSet()
            }) {
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
            }
            .buttonStyle(PlainButtonStyle()) // Ensure button styling works in List
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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
        
        // Prefer parent callback; fallback to local append if not provided (e.g., in Previews)
        if let onAddSet {
            print("🔧 DEBUG: DynamicSetsInputView - Calling onAddSet callback (parent will add the set)")
            onAddSet()
        } else {
            print("🔧 DEBUG: DynamicSetsInputView - No onAddSet callback found; appending set locally")
            sets.append(FlexibleSetData(trackingType: trackingType))
            onSetDataChanged?()
        }
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
        let baseRowHeight: CGFloat = 54 // Height per row including set rows and add button
        let spacing: CGFloat = 8 // Spacing between rows
        let containerPadding: CGFloat = 0 // Container padding
        
        // Calculate for all sets PLUS the add button row (sets.count + 1)
        let totalRows = sets.count + 1 // Include add button as a row
        let totalHeight = CGFloat(totalRows) * baseRowHeight + CGFloat(max(0, totalRows - 1)) * spacing + containerPadding
        
        print("🔵 DEBUG calculateListHeight:")
        print("🔵 - Sets count: \(sets.count)")
        print("🔵 - Total rows (including add button): \(totalRows)")
        print("🔵 - Base height per row: \(baseRowHeight)")
        print("🔵 - Calculated total height: \(totalHeight)")
        
        return totalHeight
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
