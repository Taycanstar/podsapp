//
//  WorkoutInProgressView.swift
//  pods
//
//  Created by Dimi Nunez on 8/16/25.
//

import SwiftUI
import UIKit

struct WorkoutInProgressView: View {
    @Binding var isPresented: Bool
    @State private var workout: TodayWorkout
    @State private var isPaused = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var completedExercises: Set<Int> = []
    @State private var navigationPath = NavigationPath()
    // Full-screen logging sheet context
    @State private var loggingContext: LogExerciseSheetContext?
    @Environment(\.colorScheme) var colorScheme
    
    // Track if any sets have been logged during this workout
    @State private var hasLoggedSets = false
    @State private var showDiscardAlert = false
    // Track completed exercises with their logged sets count and RIR values
    @State private var exerciseCompletionStatus: [Int: Int] = [:] // exerciseIndex: loggedSetsCount
    @State private var exerciseRIRValues: [Int: Double] = [:] // exerciseIndex: rirValue
    
    init(isPresented: Binding<Bool>, workout: TodayWorkout) {
        self._isPresented = isPresented
        self._workout = State(initialValue: workout)
    }
    
    // Computed property for easy access to main exercises
    private var exercises: [TodayWorkoutExercise] {
        return workout.exercises
    }
    
    // Pre-computed combined exercises array to avoid repeated concatenation
    private var allCombinedExercises: [TodayWorkoutExercise] {
        let warmUp = workout.warmUpExercises ?? []
        let main = workout.exercises
        let coolDown = workout.coolDownExercises ?? []
        return warmUp + main + coolDown
    }
    
    // Check if workout has any exercises
    private var hasAnyExercises: Bool {
        !(workout.warmUpExercises?.isEmpty ?? true) || 
        !workout.exercises.isEmpty || 
        !(workout.coolDownExercises?.isEmpty ?? true)
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with close button and timer
                    headerSection
                    
                    // Exercise list
                    ScrollView {
                        VStack(spacing: 8) {
                            if hasAnyExercises {
                                exerciseContentView
                            } else {
                                emptyExercisesView
                            }
                            
                            // Bottom padding for floating buttons
                            Color.clear
                                .frame(height: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
                
                // Floating buttons
                VStack {
                    Spacer()
                    
                    if isPaused {
                        // Resume and Log Workout buttons when paused
                        HStack(spacing: 16) {
                            Button(action: resumeWorkout) {
                                Text("Resume")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color("tiktoknp"))
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                            
                            Button(action: logWorkout) {
                                Text("Log Workout")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Pause button when running
                        Button(action: pauseWorkout) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.red)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
                        }
                        .padding(.bottom, 30)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isPaused)
            } // Closes ZStack
            .navigationDestination(for: WorkoutNavigationDestination.self) { destination in
                switch destination {
                case .logExercise(let exercise, let allExercises, let index):
                    EmptyView()
                        .onAppear {
                            loggingContext = LogExerciseSheetContext(exercise: exercise, allExercises: allExercises, index: index)
                            if !navigationPath.isEmpty { navigationPath.removeLast() }
                        }
                default:
                    EmptyView()
                }
            }
            .fullScreenCover(item: $loggingContext) { ctx in
                ExerciseLoggingView(
                    exercise: ctx.exercise,
                    allExercises: ctx.allExercises,
                    onSetLogged: { activeExercise, completedSetsCount, rirValue in
                            hasLoggedSets = true
                            // Use the exercise actually being logged (may differ from initially tapped)
                            if let globalIndex = allCombinedExercises.firstIndex(where: { $0.exercise.id == activeExercise.exercise.id }) {
                                // DEBUG: Show what the old buggy system would have done
                                let oldExerciseIndex = exercises.firstIndex(where: { $0.exercise.id == ctx.exercise.exercise.id }) ?? -1
                                print("🔍 DEBUG INDEX MAPPING:")
                                print("   Initially tapped: \(ctx.exercise.exercise.name)")
                                print("   Actually logged: \(activeExercise.exercise.name)")
                                print("   ❌ OLD BUGGY exerciseIndex: \(oldExerciseIndex) (would update wrong exercise!)")
                                print("   ✅ FIXED globalIndex: \(globalIndex) (updates correct exercise)")
                                print("   allCombinedExercises[\(globalIndex)]: \(allCombinedExercises[globalIndex].exercise.name)")
                                
                                exerciseCompletionStatus[globalIndex] = completedSetsCount
                                if let rir = rirValue {
                                    exerciseRIRValues[globalIndex] = rir
                                }
                                print("🏋️ ✅ FIXED CONTAMINATION: Updated completion for globalIndex \(globalIndex) - \(completedSetsCount) sets completed")
                            }

                            // Auto-advance within Superset/Circuit groups
                            if let blocks = workout.blocks {
                                // Find the block containing the active exercise
                                if let block = blocks.first(where: { blk in
                                    blk.exercises.contains(where: { $0.exercise.id == activeExercise.exercise.id })
                                }), block.type == .superset || block.type == .circuit {
                                    let ids = block.exercises.map { $0.exercise.id }
                                    if let pos = ids.firstIndex(of: activeExercise.exercise.id) {
                                        let nextPos = pos + 1
                                        if nextPos < ids.count {
                                            let nextId = ids[nextPos]
                                            if let nextExercise = workout.exercises.first(where: { $0.exercise.id == nextId }) {
                                                // Update the sheet to next exercise in the group
                                                loggingContext = LogExerciseSheetContext(exercise: nextExercise, allExercises: workout.exercises, index: nextPos)
                                            }
                                        } else {
                                            // Completed the group round; if more rounds/sets remain, loop back to first
                                            // Heuristic: if completedSetsCount < max sets among group members, go back to first
                                            let groupMaxSets = ids.compactMap { id in
                                                workout.exercises.first(where: { $0.exercise.id == id })?.sets
                                            }.max() ?? 1
                                            if completedSetsCount < groupMaxSets {
                                                let firstId = ids.first!
                                                if let firstExercise = workout.exercises.first(where: { $0.exercise.id == firstId }) {
                                                    loggingContext = LogExerciseSheetContext(exercise: firstExercise, allExercises: workout.exercises, index: 0)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                    },
                    isFromWorkoutInProgress: true,
                    initialCompletedSetsCount: {
                            // 🐛 FIX: Use globalIndex from allCombinedExercises for consistency
                            if let globalIndex = allCombinedExercises.firstIndex(where: { $0.exercise.id == ctx.exercise.exercise.id }) {
                                return exerciseCompletionStatus[globalIndex]
                            }
                            return nil
                        }(),
                    initialRIRValue: {
                            // 🐛 FIX: Use globalIndex from allCombinedExercises for consistency
                            if let globalIndex = allCombinedExercises.firstIndex(where: { $0.exercise.id == ctx.exercise.exercise.id }) {
                                return exerciseRIRValues[globalIndex]
                            }
                            return nil
                        }(),
                    onExerciseReplaced: nil,
                    onWarmupSetsChanged: { warmupSets in
                            // TODO: Handle warm-up sets persistence during workout
                            // This should update the exercise in the workout data structure
                        },
                    onExerciseUpdated: { updatedExercise in
                        // Update the exercise in the workout data
                        var updatedExercises = workout.exercises
                        if let exerciseIndex = updatedExercises.firstIndex(where: { $0.exercise.id == updatedExercise.exercise.id }) {
                            updatedExercises[exerciseIndex] = updatedExercise
                            workout = TodayWorkout(
                                id: workout.id,
                                date: workout.date,
                                title: workout.title,
                                exercises: updatedExercises,
                                blocks: workout.blocks,
                                estimatedDuration: workout.estimatedDuration,
                                fitnessGoal: workout.fitnessGoal,
                                difficulty: workout.difficulty,
                                warmUpExercises: workout.warmUpExercises,
                                coolDownExercises: workout.coolDownExercises
                            )
                        }
                    }
                    
                )
            }
        } // Closes NavigationStack
        .onAppear {
            startTimer()
            let totalExercises = (workout.warmUpExercises?.count ?? 0) + workout.exercises.count + (workout.coolDownExercises?.count ?? 0)
            print("🏋️ WorkoutInProgressView appeared with \(totalExercises) exercises (\(workout.warmUpExercises?.count ?? 0) warm-up, \(workout.exercises.count) main, \(workout.coolDownExercises?.count ?? 0) cool-down)")
            
            let allExercises = (workout.warmUpExercises ?? []) + workout.exercises + (workout.coolDownExercises ?? [])
            for (index, exercise) in allExercises.enumerated() {
                let warmUpCount = workout.warmUpExercises?.count ?? 0
                let section = index < warmUpCount ? "Warm-up" : 
                             index < warmUpCount + workout.exercises.count ? "Main" : "Cool-down"
                print("🏋️ Exercise \(index) (\(section)): \(exercise.exercise.name)")
            }
        }
        .onDisappear {
            stopTimer()
        }
        .alert("Discard Workout?", isPresented: $showDiscardAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Discard", role: .destructive) {
                isPresented = false
            }
        } message: {
            Text("You have logged sets in this workout. Are you sure you want to discard this workout?")
        }
    }
    
    // MARK: - Computed Views
    
    @ViewBuilder
    private var emptyExercisesView: some View {
        Text("No exercises loaded")
            .foregroundColor(.secondary)
            .padding(.top, 50)
    }
    
    @ViewBuilder
    private var exerciseContentView: some View {
        warmUpSectionView
        mainExercisesSectionView
        coolDownSectionView
    }
    
    @ViewBuilder
    private var warmUpSectionView: some View {
        if let warmUpExercises = workout.warmUpExercises, !warmUpExercises.isEmpty {
            sectionHeader(title: "Warm-Up", color: .primary)
            
            ForEach(Array(warmUpExercises.enumerated()), id: \.offset) { index, exercise in
                createExerciseRow(
                    exercise: exercise,
                    globalIndex: index,
                    loggedSetsCount: exerciseCompletionStatus[index]
                )
            }
        }
    }
    
    @ViewBuilder
    private var mainExercisesSectionView: some View {
        if !workout.exercises.isEmpty {
            let mainExercisesStartIndex = workout.warmUpExercises?.count ?? 0
            let shouldShowHeader = !(workout.warmUpExercises?.isEmpty ?? true) || !(workout.coolDownExercises?.isEmpty ?? true)
            
            if shouldShowHeader {
                sectionHeader(title: "Main Sets", color: .primary)
            }
            
            ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, exercise in
                let globalIndex = mainExercisesStartIndex + index
                createExerciseRow(
                    exercise: exercise,
                    globalIndex: globalIndex,
                    loggedSetsCount: exerciseCompletionStatus[globalIndex]
                )
            }
        }
    }
    
    @ViewBuilder
    private var coolDownSectionView: some View {
        if let coolDownExercises = workout.coolDownExercises, !coolDownExercises.isEmpty {
            let coolDownStartIndex = (workout.warmUpExercises?.count ?? 0) + workout.exercises.count
            
            sectionHeader(title: "Cool-Down", color: .primary)
            
            ForEach(Array(coolDownExercises.enumerated()), id: \.offset) { index, exercise in
                let globalIndex = coolDownStartIndex + index
                createExerciseRow(
                    exercise: exercise,
                    globalIndex: globalIndex,
                    loggedSetsCount: exerciseCompletionStatus[globalIndex]
                )
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func sectionHeader(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.top, 16)
    }
    
    @ViewBuilder
    private func createExerciseRow(
        exercise: TodayWorkoutExercise,
        globalIndex: Int,
        loggedSetsCount: Int?
    ) -> some View {
        ExerciseRowInProgress(
            exercise: exercise,
            allExercises: allCombinedExercises,
            isCompleted: completedExercises.contains(globalIndex),
            loggedSetsCount: loggedSetsCount,
            onToggle: {
                toggleExerciseCompletion(globalIndex)
            },
            onExerciseTap: {
                // Present logging fullscreen directly; avoid navigation placeholder
                loggingContext = LogExerciseSheetContext(
                    exercise: exercise,
                    allExercises: allCombinedExercises,
                    index: globalIndex
                )
            }
        )
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Top bar with close button
            HStack {
                Button(action: {
                    handleDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Menu {
                    Button("View Summary") {
                        // TODO: Show workout summary
                    }
                    
                    Button("Settings") {
                        // TODO: Show workout settings
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Timer display
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Circle()
                        .fill(isPaused ? Color.orange : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(timeString(from: elapsedTime))
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                if isPaused {
                    Text("Paused")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Methods
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !isPaused {
                elapsedTime += 1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func pauseWorkout() {
        isPaused = true
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func resumeWorkout() {
        isPaused = false
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func logWorkout() {
        // Complete workout without feedback (simplified for now)
        completeWorkout()
    }
    
    private func completeWorkout() {
        // TODO: Save workout data
        isPresented = false
    }
    
    private func toggleExerciseCompletion(_ index: Int) {
        if completedExercises.contains(index) {
            completedExercises.remove(index)
        } else {
            completedExercises.insert(index)
        }
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func handleDismiss() {
        // Check if any sets have been logged
        if hasLoggedSets {
            // Show confirmation alert if sets have been logged
            showDiscardAlert = true
        } else {
            // Dismiss immediately if no sets have been logged
            isPresented = false
        }
    }
}

// MARK: - Exercise Row Component

struct ExerciseRowInProgress: View {
    let exercise: TodayWorkoutExercise
    let allExercises: [TodayWorkoutExercise]
    let isCompleted: Bool
    let loggedSetsCount: Int?
    let onToggle: () -> Void
    let onExerciseTap: () -> Void
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var showHistory = false
    @State private var showReplace = false
    @State private var tempExercise: TodayWorkoutExercise
    
    // Provide index resolution against current workout for replacement
    private var exerciseIndexInToday: Int? {
        guard let workout = workoutManager.todayWorkout else { return nil }
        return workout.exercises.firstIndex(where: { $0.exercise.id == exercise.exercise.id })
    }
    
    private var thumbnailImageName: String {
        String(format: "%04d", exercise.exercise.id)
    }
    
    private var isExerciseFullyLogged: Bool {
        guard let loggedCount = loggedSetsCount else { return false }
        return loggedCount >= exercise.sets
    }
    
    init(exercise: TodayWorkoutExercise, allExercises: [TodayWorkoutExercise], isCompleted: Bool, loggedSetsCount: Int?, onToggle: @escaping () -> Void, onExerciseTap: @escaping () -> Void) {
        self.exercise = exercise
        self.allExercises = allExercises
        self.isCompleted = isCompleted
        self.loggedSetsCount = loggedSetsCount
        self.onToggle = onToggle
        self.onExerciseTap = onExerciseTap
        self._tempExercise = State(initialValue: exercise)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Tappable left area (thumbnail + labels)
            Button(action: onExerciseTap) {
                HStack(spacing: 12) {
                    // Exercise thumbnail with completion overlay
                    ZStack {
                        Group {
                            if let image = UIImage(named: thumbnailImageName) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "dumbbell")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 16))
                                    )
                            }
                        }
                        .opacity(isExerciseFullyLogged ? 0.6 : 1.0) // Dim when fully completed

                        // Completion checkmark overlay
                        if isExerciseFullyLogged {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Exercise info with completion styling
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exercise.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isExerciseFullyLogged ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Group {
                            if let loggedCount = loggedSetsCount {
                                Text("\(loggedCount)/\(exercise.sets) logged")
                                    .font(.system(size: 14, weight: isExerciseFullyLogged ? .semibold : .regular))
                                    .foregroundColor(isExerciseFullyLogged ? .accentColor : .orange)
                            } else {
                                Text("\(exercise.sets) sets • \(exercise.reps) reps")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Menu button - exactly like LogWorkoutView
            Menu {
                Button("Exercise History") { showHistory = true }

                Button("Replace") {
                    tempExercise = exercise
                    showReplace = true
                }

                Button("Skip Exercise") {
                    withAnimation { workoutManager.removeExerciseFromToday(exerciseId: exercise.exercise.id) }
                }

                Divider()

                Button("Mark Complete") { onToggle() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            isExerciseFullyLogged ?
            Color("tiktoknp").opacity(0.5) :
            Color("tiktoknp")
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isExerciseFullyLogged ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .background(
            NavigationLink(
                destination: ExerciseHistory(exercise: exercise),
                isActive: $showHistory,
                label: { EmptyView() }
            ).hidden()
        )
        .sheet(isPresented: $showReplace) {
            ReplaceExerciseSheet(
                currentExercise: $tempExercise,
                onExerciseReplaced: { newExercise in
                    if let idx = exerciseIndexInToday {
                        // Build updated TodayWorkoutExercise preserving fields
                        let updated = TodayWorkoutExercise(
                            exercise: newExercise,
                            sets: exercise.sets,
                            reps: exercise.reps,
                            weight: exercise.weight,
                            restTime: exercise.restTime,
                            notes: exercise.notes,
                            warmupSets: exercise.warmupSets,
                            flexibleSets: exercise.flexibleSets,
                            trackingType: exercise.trackingType
                        )
                        workoutManager.updateExercise(at: idx, with: updated)
                    }
                }
            )
        }
    }
    
}


// MARK: - Preview

#Preview {
    WorkoutInProgressView(
        isPresented: .constant(true),
        workout: TodayWorkout(
            id: UUID(),
            date: Date(),
            title: "Sample Workout",
            exercises: [
                TodayWorkoutExercise(
                    exercise: ExerciseData(
                        id: 1,
                        name: "Barbell Bench Press",
                        exerciseType: "Strength",
                        bodyPart: "Chest",
                        equipment: "Barbell",
                        gender: "Both",
                        target: "Pectorals",
                        synergist: "Triceps, Anterior Deltoid"
                    ),
                    sets: 3,
                    reps: 6,
                    weight: 140,
                    restTime: 90
                ),
                TodayWorkoutExercise(
                    exercise: ExerciseData(
                        id: 2,
                        name: "Close-Grip Bench Press",
                        exerciseType: "Strength",
                        bodyPart: "Chest",
                        equipment: "Barbell",
                        gender: "Both",
                        target: "Triceps",
                        synergist: "Pectorals"
                    ),
                    sets: 3,
                    reps: 8,
                    weight: 100,
                    restTime: 90
                )
            ],
            estimatedDuration: 45,
            fitnessGoal: .strength,
            difficulty: 3,
            warmUpExercises: [],
            coolDownExercises: []
        )
    )
}
