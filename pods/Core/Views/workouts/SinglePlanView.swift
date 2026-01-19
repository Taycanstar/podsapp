//
//  SinglePlanView.swift
//  pods
//
//  Created by Dimi Nunez on 1/16/26.
//

import SwiftUI

struct SinglePlanView: View {
    let initialProgram: TrainingProgram

    @Environment(\.dismiss) private var dismiss
    @AppStorage("userEmail") private var userEmail: String = ""
    @ObservedObject private var programService = ProgramService.shared
    @ObservedObject private var userProfileService = UserProfileService.shared
    @EnvironmentObject private var workoutManager: WorkoutManager

    @State private var selectedDayIndex: Int = 0
    @State private var showSettings = false
    @State private var shouldDismiss = false

    // Action button sheets
    @State private var showGymProfiles = false
    @State private var showEditWorkoutName = false
    @State private var showReorderExercises = false
    @State private var showAddExercise = false
    @State private var editingWorkoutName = ""
    @State private var isSavingWorkoutName = false
    @State private var showRestDayConfirmation = false
    @State private var isConvertingToRestDay = false
    @State private var showRemoveDayConfirmation = false
    @State private var isRemovingDay = false

    // Workout in progress
    @State private var currentWorkout: TodayWorkout?

    // Use the active program from ProgramService if available, otherwise use initial
    private var program: TrainingProgram {
        programService.activeProgram ?? initialProgram
    }

    // Computed: Get all days from week 1 as the template
    private var templateDays: [ProgramDay] {
        program.weeks?.first?.days ?? []
    }

    // Current selected day
    private var selectedDay: ProgramDay? {
        guard selectedDayIndex < templateDays.count else { return nil }
        return templateDays[selectedDayIndex]
    }

    // Get exercise with per-week data
    // Shows Week 1-N for training weeks, plus "Deload" for deload week if enabled
    private func weeklyDataForExercise(_ exerciseId: Int) -> [WeeklyExerciseData] {
        let result = program.weeks?.compactMap { week -> WeeklyExerciseData? in
            guard let day = week.days?.first(where: { $0.workoutLabel == selectedDay?.workoutLabel }),
                  let exercise = day.workout?.exercises?.first(where: { $0.exerciseId == exerciseId }) else {
                return nil
            }

            // Determine the display label: "Deload" for deload week, otherwise "Week N"
            let displayLabel = week.isDeload ? "Deload" : "Week \(week.weekNumber)"

            return WeeklyExerciseData(
                week: week.weekNumber,
                sets: exercise.targetSets ?? 0,
                reps: exercise.targetReps ?? 0,
                isDeload: week.isDeload,
                displayLabel: displayLabel,
                exerciseInstanceId: exercise.id  // Include the exercise instance ID for API calls
            )
        } ?? []

        return result
    }

    // Build a TodayWorkout from the selected day's exercises
    private func buildTodayWorkout(from day: ProgramDay) -> TodayWorkout? {
        guard day.dayType == .workout,
              let workout = day.workout,
              let programExercises = workout.exercises else {
            return nil
        }

        // Convert ProgramExercise to TodayWorkoutExercise
        let exercises: [TodayWorkoutExercise] = programExercises.compactMap { progEx in
            guard let exerciseData = ExerciseDatabase.findExercise(byId: progEx.exerciseId) else {
                return nil
            }
            return TodayWorkoutExercise(
                exercise: exerciseData,
                sets: progEx.targetSets ?? 3,
                reps: progEx.targetReps ?? 10,
                weight: nil,
                restTime: 90,
                notes: nil,
                warmupSets: nil,
                flexibleSets: nil,
                trackingType: nil
            )
        }

        guard !exercises.isEmpty else { return nil }

        // Convert ProgramFitnessGoal to FitnessGoal via rawValue
        let fitnessGoal: FitnessGoal
        if let programGoal = program.fitnessGoalEnum,
           let goal = FitnessGoal(rawValue: programGoal.rawValue) {
            fitnessGoal = goal
        } else {
            fitnessGoal = .hypertrophy
        }

        return TodayWorkout(
            id: UUID(),
            date: Date(),
            title: workout.title,
            exercises: exercises,
            blocks: nil,
            estimatedDuration: workout.estimatedDurationMinutes,
            fitnessGoal: fitnessGoal,
            difficulty: 3,
            warmUpExercises: nil,
            coolDownExercises: nil
        )
    }

    // Start workout action
    private func startWorkout() {
        guard let day = selectedDay,
              let workout = buildTodayWorkout(from: day) else { return }

        HapticFeedback.generateLigth()
        currentWorkout = workout
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Day picker (scrolls with content for native feel)
                dayPicker
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Action buttons bar
                actionButtonsBar
                    .padding(.bottom, 16)

                // Content based on selected day
                if let day = selectedDay {
                    if day.dayType == .rest {
                        restDayContent
                    } else {
                        workoutContentInline(day: day)
                    }
                } else {
                    emptyState
                }
            }
        }
        .background(Color("primarybg"))
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            PlanSettingsSheet(program: program, userEmail: userEmail) {
                // Plan was deleted - dismiss this view
                shouldDismiss = true
            } onSettingsSaved: {
                // Refresh program data from backend
                Task {
                    _ = try? await programService.fetchActiveProgram(userEmail: userEmail)
                }
            }
        }
        .onChange(of: shouldDismiss) { _, newValue in
            if newValue {
                dismiss()
            }
        }
        .sheet(isPresented: $showGymProfiles) {
            GymProfilesListSheet(userEmail: userEmail)
        }
        .sheet(isPresented: $showReorderExercises) {
            if let day = selectedDay, day.dayType == .workout,
               let exercises = day.workout?.exercises {
                ExerciseReorderSheet(exercises: exercises) { reorderedExercises in
                    Task {
                        await saveReorderedExercises(dayId: day.id, exercises: reorderedExercises)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddExercise) {
            AddExerciseView { selectedExercises in
                print("[SinglePlanView] AddExerciseView callback received \(selectedExercises.count) exercises")
                Task {
                    await addExercisesToCurrentDay(selectedExercises)
                }
            }
        }
        .alert("Edit Workout Name", isPresented: $showEditWorkoutName) {
            TextField("Workout Name", text: $editingWorkoutName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveWorkoutName()
            }
        } message: {
            Text("Enter a new name for this workout")
        }
        .alert("Turn into Rest Day?", isPresented: $showRestDayConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Convert", role: .destructive) {
                Task {
                    await confirmConvertToRestDay()
                }
            }
        } message: {
            if let exerciseCount = selectedDay?.workout?.exercises?.count, exerciseCount > 0 {
                Text("All \(exerciseCount) exercises will be permanently removed from this day.")
            } else {
                Text("This workout day will be converted to a rest day.")
            }
        }
        .alert("Remove from Plan?", isPresented: $showRemoveDayConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    await confirmRemoveDay()
                }
            }
        } message: {
            Text("This will remove this day from your plan across all weeks. This action cannot be undone.")
        }
        // Floating Start Workout button (only for workout days with exercises)
        .safeAreaInset(edge: .bottom) {
            if let day = selectedDay,
               day.dayType == .workout,
               let exercises = day.workout?.exercises,
               !exercises.isEmpty {
                Button(action: startWorkout) {
                    Text("Start Workout")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        // WorkoutInProgressView fullScreenCover
        .fullScreenCover(item: $currentWorkout) { workout in
            WorkoutInProgressView(
                isPresented: Binding(
                    get: { currentWorkout != nil },
                    set: { isPresented in
                        if !isPresented {
                            currentWorkout = nil
                            workoutManager.cancelActiveWorkout()
                        }
                    }
                ),
                workout: workout
            )
        }
    }

    // MARK: - Action Buttons Bar

    private var isRestDay: Bool {
        selectedDay?.dayType == .rest
    }

    private var actionButtonsBar: some View {
        HStack(spacing: 12) {
            if isRestDay {
                // Rest day: Remove button first (only action available)
                ActionButton(icon: "minus.circle.fill", action: {
                    removeCurrentDay()
                })
                .disabled(templateDays.count <= 1 || isRemovingDay)
            } else {
                // Workout day: Action buttons first, remove button last

                // Gym Profile button
                ActionButton(icon: "dumbbell", action: {
                    showGymProfiles = true
                })

                // Edit workout name button
                ActionButton(icon: "pencil", action: {
                    editingWorkoutName = selectedDay?.workoutLabel ?? ""
                    showEditWorkoutName = true
                })

                // Reorder exercises button
                ActionButton(icon: "arrow.up.arrow.down", action: {
                    showReorderExercises = true
                })

                // Change to rest day button
                ActionButton(icon: "beach.umbrella.fill", action: {
                    changeToRestDay()
                })

                // Remove day button (last for workout days)
                ActionButton(icon: "minus.circle.fill", action: {
                    removeCurrentDay()
                })
                .disabled(templateDays.count <= 1 || isRemovingDay)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action Button Component

    private struct ActionButton: View {
        let icon: String
        let action: () -> Void

        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            if #available(iOS 26, *) {
                Button(action: action) {
                    iconLabel
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            } else {
                Button(action: action) {
                    iconLabelWithBackground
                }
                .buttonStyle(PlainButtonStyle())
            }
        }

        private var iconLabel: some View {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.5))
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }

        private var iconLabelWithBackground: some View {
            iconLabel
                .background(fallbackBackground)
                .clipShape(Circle())
        }

        private var fallbackBackground: Color {
            Color(.systemGray5)
        }
    }

    // MARK: - Day Actions

    private func changeToRestDay() {
        guard let day = selectedDay, day.dayType == .workout else { return }
        showRestDayConfirmation = true
    }

    private func confirmConvertToRestDay() async {
        guard let day = selectedDay, day.dayType == .workout else { return }

        isConvertingToRestDay = true

        // Optimistic update: update UI immediately
        let previousState = programService.optimisticConvertToRestDay(dayId: day.id)
        print("[SinglePlanView] Optimistically converted day to rest")

        // Sync to backend
        do {
            try await NetworkManagerTwo.shared.updateProgramDayType(
                dayId: day.id,
                dayType: "rest",
                userEmail: userEmail
            )
            print("[SinglePlanView] Successfully synced convert to rest day")
        } catch {
            print("[SinglePlanView] Failed to sync convert to rest day: \(error)")
            // Rollback on failure
            if let previousState = previousState {
                programService.rollback(to: previousState)
                print("[SinglePlanView] Rolled back convert to rest day")
            }
        }
        isConvertingToRestDay = false
    }

    private func removeCurrentDay() {
        guard templateDays.count > 1 else { return }
        showRemoveDayConfirmation = true
    }

    private func confirmRemoveDay() async {
        guard let day = selectedDay, !userEmail.isEmpty, !isRemovingDay else { return }
        let removedIndex = selectedDayIndex
        isRemovingDay = true

        // Optimistic update: update UI immediately
        let previousState = programService.optimisticRemoveDay(dayId: day.id)
        print("[SinglePlanView] Optimistically removed day")

        // Update selected index after optimistic removal
        let updatedCount = templateDays.count
        if updatedCount > 0 {
            let newIndex = min(removedIndex, updatedCount - 1)
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDayIndex = newIndex
            }
        } else {
            selectedDayIndex = 0
        }

        // Sync to backend
        do {
            try await NetworkManagerTwo.shared.deleteProgramDay(dayId: day.id, userEmail: userEmail)
            print("[SinglePlanView] Successfully synced remove day")
        } catch {
            print("[SinglePlanView] Failed to sync remove day: \(error)")
            // Rollback on failure
            if let previousState = previousState {
                programService.rollback(to: previousState)
                // Restore the selected index
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDayIndex = removedIndex
                }
                print("[SinglePlanView] Rolled back remove day")
            }
        }
        isRemovingDay = false
    }

    private func saveWorkoutName() {
        let trimmedName = editingWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let dayId = selectedDay?.id,
              !trimmedName.isEmpty,
              !userEmail.isEmpty,
              !isSavingWorkoutName else {
            return
        }

        isSavingWorkoutName = true

        // Optimistic update: update UI immediately
        let previousState = programService.optimisticUpdateWorkoutName(dayId: dayId, newName: trimmedName)
        print("[SinglePlanView] Optimistically updated workout name to: \(trimmedName)")
        showEditWorkoutName = false

        Task {
            // Sync to backend
            do {
                try await NetworkManagerTwo.shared.updateProgramDayLabel(
                    dayId: dayId,
                    workoutLabel: trimmedName,
                    userEmail: userEmail
                )
                print("[SinglePlanView] Successfully synced workout name")
            } catch {
                print("[SinglePlanView] Failed to sync workout name: \(error)")
                // Rollback on failure
                await MainActor.run {
                    if let previousState = previousState {
                        programService.rollback(to: previousState)
                        print("[SinglePlanView] Rolled back workout name change")
                    }
                }
            }
            await MainActor.run {
                isSavingWorkoutName = false
            }
        }
    }

    private func saveReorderedExercises(dayId: Int, exercises: [ProgramExercise]) async {
        let exerciseOrder = exercises.map { $0.id }

        // Optimistic update: update UI immediately
        let previousState = programService.optimisticReorderExercises(dayId: dayId, exerciseOrder: exerciseOrder)
        print("[SinglePlanView] Optimistically reordered exercises")

        // Sync to backend
        do {
            try await NetworkManagerTwo.shared.reorderProgramExercises(
                dayId: dayId,
                exerciseOrder: exerciseOrder,
                userEmail: userEmail
            )
            print("[SinglePlanView] Successfully synced reorder exercises")
        } catch {
            print("[SinglePlanView] Failed to sync reorder exercises: \(error)")
            // Rollback on failure
            if let previousState = previousState {
                programService.rollback(to: previousState)
                print("[SinglePlanView] Rolled back reorder exercises")
            }
        }
    }

    private func addRestDay() {
        // Optimistic update: add day to UI immediately
        let previousState = programService.optimisticAddRestDay()
        print("[SinglePlanView] Optimistically added rest day")

        // Select the new day (it will be at the end)
        let newDayIndex = templateDays.count - 1
        if newDayIndex >= 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDayIndex = newDayIndex
            }
        }

        // Sync to backend
        Task {
            do {
                _ = try await NetworkManagerTwo.shared.addProgramDay(
                    programId: program.id,
                    dayType: "rest",
                    userEmail: userEmail
                )
                // Refresh to get real IDs from backend
                _ = try await programService.fetchActiveProgram(userEmail: userEmail)
                print("[SinglePlanView] Successfully synced add rest day")
            } catch {
                print("[SinglePlanView] Failed to sync add rest day: \(error)")
                // Rollback on failure
                if let previousState = previousState {
                    programService.rollback(to: previousState)
                    print("[SinglePlanView] Rolled back add rest day")
                }
            }
        }
    }

    /// Add exercises to the current day. If the day is a rest day, it will be
    /// converted to a workout day with proper naming (e.g., "Workout D").
    @MainActor
    private func addExercisesToCurrentDay(_ exercises: [ExerciseData]) async {
        print("[SinglePlanView] addExercisesToCurrentDay called with \(exercises.count) exercises")

        guard let day = selectedDay else {
            print("[SinglePlanView] No day selected for adding exercises")
            return
        }

        print("[SinglePlanView] Adding exercises to day \(day.id) (\(day.workoutLabel))")

        do {
            let exerciseTuples = exercises.map { exercise in
                (exerciseId: exercise.id, exerciseName: exercise.name, targetSets: 3, targetReps: 10)
            }

            print("[SinglePlanView] Calling API to add \(exerciseTuples.count) exercises...")
            _ = try await NetworkManagerTwo.shared.addExercisesToDay(
                dayId: day.id,
                exercises: exerciseTuples,
                userEmail: userEmail
            )

            print("[SinglePlanView] API call successful, refreshing program...")
            // Refresh program data to show the updated day
            _ = try await programService.fetchActiveProgram(userEmail: userEmail)

            let wasRestDay = day.dayType == .rest
            if wasRestDay {
                print("[SinglePlanView] Successfully converted rest day to workout and added \(exercises.count) exercises")
            } else {
                print("[SinglePlanView] Successfully added \(exercises.count) exercises to workout")
            }
        } catch {
            print("[SinglePlanView] Failed to add exercises: \(error)")
        }
    }

    // MARK: - Day Picker

    // Normalize day label to ensure "Rest Day" becomes "Rest"
    private func normalizedDayLabel(_ label: String) -> String {
        // Handle variations: "Rest Day", "Rest day", etc.
        if label.lowercased().hasPrefix("rest") {
            return "Rest"
        }
        return label
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(templateDays.enumerated()), id: \.offset) { index, day in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDayIndex = index
                        }
                    } label: {
                        Text(normalizedDayLabel(day.workoutLabel))
                            .font(.system(size: 14, weight: selectedDayIndex == index ? .semibold : .regular))
                            .foregroundColor(selectedDayIndex == index ? .primary : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedDayIndex == index
                                    ? Color("containerbg")
                                    : Color.clear
                            )
                            .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Add day button (plus icon)
                Button {
                    addRestDay()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.2), value: templateDays.count)
        }
    }

    // MARK: - Workout Content

    @ViewBuilder
    private func workoutContentInline(day: ProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Target muscles section
            if !day.targetMuscles.isEmpty {
                targetMusclesSection(muscles: day.targetMuscles)
            }

            // Exercises list
            if let exercises = day.workout?.exercises, !exercises.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        SinglePlanExerciseRow(
                            exercise: exercise,
                            weeklyData: weeklyDataForExercise(exercise.exerciseId),
                            userEmail: userEmail,
                            showDivider: index < exercises.count - 1,
                            onTargetsSaved: {
                                // Refresh program data when targets are updated
                                Task {
                                    _ = try? await programService.fetchActiveProgram(userEmail: userEmail)
                                }
                            }
                        )
                    }

                    // Add Exercise button at the bottom
                    addExerciseButton
                        .padding(.top, 16)
                }
                .padding(.horizontal, 16)
            } else {
                noExercisesState
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Add Exercise Button

    private var addExerciseButton: some View {
        Button {
            showAddExercise = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add Exercise")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Target Muscles Section

    private func targetMusclesSection(muscles: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Muscles")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(muscles, id: \.self) { muscle in
                        Text(muscle)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color("containerbg"))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Rest Day Content

    private var restDayContent: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bed.double.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("Rest Day")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Recovery is essential for muscle growth and performance")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Add Exercise button for rest days (to convert to workout)
            Button {
                showAddExercise = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No days found")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    private var noExercisesState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "dumbbell")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No exercises scheduled")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Weekly Exercise Data

struct WeeklyExerciseData: Identifiable {
    let week: Int
    let sets: Int
    let reps: Int
    let isDeload: Bool
    let displayLabel: String  // "Week 1", "Week 2", ... or "Deload"
    let exerciseInstanceId: Int  // The ID of this specific exercise instance for API calls

    var id: Int { week }

    init(week: Int, sets: Int, reps: Int, isDeload: Bool = false, displayLabel: String? = nil, exerciseInstanceId: Int = 0) {
        self.week = week
        self.sets = sets
        self.reps = reps
        self.isDeload = isDeload
        self.displayLabel = displayLabel ?? "Week \(week)"
        self.exerciseInstanceId = exerciseInstanceId
    }
}

// MARK: - Single Plan Exercise Row

private struct SinglePlanExerciseRow: View {
    let exercise: ProgramExercise
    let weeklyData: [WeeklyExerciseData]
    let userEmail: String
    var showDivider: Bool = true
    var onTargetsSaved: (() -> Void)?  // Called when targets are updated to refresh data

    @State private var showExerciseLogging = false
    @State private var selectedWeekData: WeeklyExerciseData?

    private var thumbnailImageName: String {
        String(format: "%04d", exercise.exerciseId)
    }

    // Get all muscle groups for exercise using ExerciseDatabase.getAllBodyParts
    // This combines target + synergist muscles into a unified list
    private var muscleChips: [String] {
        guard let exerciseData = ExerciseDatabase.findExercise(byId: exercise.exerciseId) else {
            return []
        }

        // Get all body parts from target + synergist muscles
        let allBodyParts = ExerciseDatabase.getAllBodyParts(for: exerciseData)

        // Limit to 3 chips max for UI space
        return Array(allBodyParts.prefix(3))
    }

    // Convert ProgramExercise to TodayWorkoutExercise for ExerciseLoggingView
    private var todayWorkoutExercise: TodayWorkoutExercise? {
        guard let exerciseData = ExerciseDatabase.findExercise(byId: exercise.exerciseId) else {
            return nil
        }

        return TodayWorkoutExercise(
            exercise: exerciseData,
            sets: exercise.targetSets ?? 3,
            reps: exercise.targetReps ?? 10,
            weight: nil,
            restTime: 90,
            notes: nil,
            warmupSets: nil,
            flexibleSets: nil,
            trackingType: nil
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row 1: Thumbnail + Name + Muscle chips (tappable area)
            Button {
                showExerciseLogging = true
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    // Thumbnail (50x50)
                    Group {
                        if let image = UIImage(named: thumbnailImageName) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                Image(systemName: "dumbbell")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Content: Name and muscle chips
                    VStack(alignment: .leading, spacing: 8) {
                        // Exercise name with ellipsis menu
                        HStack {
                            Text(exercise.exerciseName)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                                .lineLimit(2)

                            Spacer()

                            Menu {
                                Button("Exercise History") {
                                    // TODO: Navigate to exercise history
                                }
                                Button("Replace") {
                                    // TODO: Implement replace
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                            }
                        }

                        // Muscle chips (fully rounded, below name)
                        if !muscleChips.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(muscleChips, id: \.self) { muscle in
                                    Text(muscle)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color("containerbg"))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 12)

            // Row 2: Week cards (starts at thumbnail position, scrolls past edges)
            // Tapping a week card opens the edit targets view
            if !weeklyData.isEmpty {
                // Calculate max sets for uniform card height
                let maxSets = weeklyData.map { $0.sets }.max() ?? 0

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(weeklyData) { data in
                            Button {
                                selectedWeekData = data
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    // Week header - uses displayLabel ("Week 1", "Deload", etc.)
                                    Text(data.displayLabel)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)

                                    // Numbered set rows (use maxSets for uniform height)
                                    ForEach(1...max(maxSets, 1), id: \.self) { setNum in
                                        HStack(spacing: 6) {
                                            Text("\(setNum)")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(setNum <= data.sets ? .secondary : .clear)
                                                .frame(width: 14, alignment: .leading)
                                            Text("\(data.reps) reps")
                                                .font(.system(size: 12))
                                                .foregroundColor(setNum <= data.sets ? .primary : .clear)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color("containerbg"))
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.trailing, 16) // Add trailing padding inside scroll content for last card spacing
                }
                .padding(.horizontal, -16) // Extend past parent's horizontal padding (scroll past edges)
                .padding(.leading, 16) // But keep leading aligned with content
                .padding(.top, 8)
                .padding(.bottom, 12)
            } else {
                // No week data - just add bottom padding
                Spacer().frame(height: 12)
            }

            // Divider (starts at thumbnail, extends to edge)
            if showDivider {
                Divider()
                    .padding(.trailing, -16) // Extend past the parent's horizontal padding
            }
        }
        .fullScreenCover(isPresented: $showExerciseLogging) {
            if let workoutExercise = todayWorkoutExercise {
                ExerciseLoggingView(
                    exercise: workoutExercise,
                    allExercises: nil,
                    onSetLogged: nil,
                    isFromWorkoutInProgress: false,
                    initialCompletedSetsCount: nil,
                    initialRIRValue: nil,
                    onExerciseReplaced: nil,
                    onWarmupSetsChanged: nil,
                    onExerciseUpdated: nil
                )
            }
        }
        .fullScreenCover(item: $selectedWeekData) { weekData in
            EditExerciseTargetsView(
                exercise: exercise,
                weekData: weekData,
                exerciseInstanceId: weekData.exerciseInstanceId,
                userEmail: userEmail,
                onSave: { _, _ in
                    onTargetsSaved?()
                }
            )
        }
    }
}

// MARK: - Plan Settings Sheet
// MacroFactor-style: Only settings that don't require regeneration
// High-level knobs (goal, experience, duration, split) are baked into generation
// and cannot be changed without creating a new program.

private struct PlanSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var programService = ProgramService.shared

    let program: TrainingProgram
    let userEmail: String
    var onPlanDeleted: (() -> Void)?
    var onSettingsSaved: (() -> Void)?

    // Editable fields
    @State private var planName: String
    @State private var totalWeeks: Int
    @State private var includeDeload: Bool
    @State private var periodizationEnabled: Bool
    @State private var dayOrder: [DayOrderItem]

    // UI state
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var showDeactivateConfirmation = false
    @State private var showDayOrderSheet = false
    @State private var error: String?

    init(program: TrainingProgram, userEmail: String, onPlanDeleted: (() -> Void)? = nil, onSettingsSaved: (() -> Void)? = nil) {
        self.program = program
        self.userEmail = userEmail
        self.onPlanDeleted = onPlanDeleted
        self.onSettingsSaved = onSettingsSaved
        _planName = State(initialValue: program.name)
        _totalWeeks = State(initialValue: program.totalWeeks)
        _includeDeload = State(initialValue: program.includeDeload)
        _periodizationEnabled = State(initialValue: true) // Default enabled (MacroFactor-style)

        // Initialize day order from week 1 days (use actual day count, not hardcoded 7)
        let week1Days = program.weeks?.first?.days?.sorted(by: { $0.dayNumber < $1.dayNumber }) ?? []
        let items: [DayOrderItem] = week1Days.enumerated().map { index, day in
            DayOrderItem(
                dayNumber: index + 1,
                isWorkout: day.dayType == .workout,
                workoutLabel: day.workoutLabel
            )
        }
        _dayOrder = State(initialValue: items)
    }

    // Format program type for display
    private var programTypeDisplay: String {
        switch program.programType {
        case "full_body": return "Full Body"
        case "ppl": return "Push/Pull/Legs"
        case "upper_lower": return "Upper/Lower"
        default: return program.programType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    // Format goal for display
    private var goalDisplay: String {
        switch program.fitnessGoal {
        case "hypertrophy": return "Hypertrophy"
        case "strength": return "Strength"
        case "balanced": return "Both"
        default: return program.fitnessGoal.capitalized
        }
    }

    // Format experience for display
    private var experienceDisplay: String {
        program.experienceLevel.capitalized
    }

    // Day order pattern string (e.g., "W,R,W,R,W,R,R")
    private var dayOrderPattern: String {
        dayOrder.map { $0.isWorkout ? "W" : "R" }.joined(separator: ",")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Editable: Plan Name
                Section("Plan Name") {
                    TextField("Name", text: $planName)
                }

                // Editable: Number of Weeks
                Section("Duration") {
                    Stepper("\(totalWeeks) weeks", value: $totalWeeks, in: 4...16)
                }

                // Editable: Day Order (7-day cycle)
                Section {
                    Button {
                        showDayOrderSheet = true
                    } label: {
                        HStack {
                            Text("Day Order")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(dayOrderPattern)
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, design: .monospaced))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                } header: {
                    Text("Schedule")
                }

                // Editable: Periodization & Deload
                Section {
                    Toggle("Periodization", isOn: $periodizationEnabled)
                    Toggle("Include Deload Week", isOn: $includeDeload)
                } header: {
                    Text("Periodization")
                } footer: {
                    Text("Periodization automatically adjusts volume and intensity across weeks for optimal progress.")
                }

                // Read-only: Generation Settings (baked in, can't change)
                Section {
                    HStack {
                        Text("Split")
                        Spacer()
                        Text(programTypeDisplay)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Goal")
                        Spacer()
                        Text(goalDisplay)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Experience")
                        Spacer()
                        Text(experienceDisplay)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Days per Week")
                        Spacer()
                        Text("\(program.daysPerWeek)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Session Duration")
                        Spacer()
                        Text("\(program.sessionDurationMinutes) min")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Plan Details")
                } footer: {
                    Text("These settings are fixed when the plan is created. To change them, create a new plan.")
                }

                // Plan Status
                Section("Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(program.isActive ? "Active" : "Inactive")
                            .foregroundColor(program.isActive ? .green : .secondary)
                    }

                    if program.isActive {
                        Button {
                            showDeactivateConfirmation = true
                        } label: {
                            Text("Deactivate Plan")
                                .foregroundColor(.orange)
                        }
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Plan", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }

                // Error display
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Plan Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button {
                            saveSettings()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                    }
                }
            }
            .fullScreenCover(isPresented: $showDayOrderSheet) {
                DayOrderEditorSheet(dayOrder: $dayOrder) {
                    saveSettings()
                }
            }
            .alert("Delete Plan?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deletePlan()
                }
            } message: {
                Text("This will permanently delete the plan and all associated workout data. This action cannot be undone.")
            }
            .alert("Deactivate Plan?", isPresented: $showDeactivateConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Deactivate", role: .destructive) {
                    deactivatePlan()
                }
            } message: {
                Text("This will deactivate the plan. You can reactivate it later from your saved programs.")
            }
        }
    }

    private func saveSettings() {
        isSaving = true
        error = nil

        Task {
            do {
                // Convert day order to backend format
                // Each item contains type and label to preserve workout identity when reordering
                let dayOrderArray: [[String: String]] = dayOrder.map { item in
                    [
                        "type": item.isWorkout ? "workout" : "rest",
                        "label": item.workoutLabel
                    ]
                }

                // Only send values that changed
                let nameToSend = planName != program.name ? planName : nil
                let weeksToSend = totalWeeks != program.totalWeeks ? totalWeeks : nil
                let deloadToSend = includeDeload != program.includeDeload ? includeDeload : nil

                print("[PlanSettings] Saving: name='\(planName)', weeks=\(totalWeeks), includeDeload=\(includeDeload), dayOrder=\(dayOrderPattern)")

                _ = try await programService.updatePlanSettings(
                    programId: program.id,
                    userEmail: userEmail,
                    name: nameToSend,
                    totalWeeks: weeksToSend,
                    includeDeload: deloadToSend,
                    dayOrder: dayOrderArray
                )

                await MainActor.run {
                    onSettingsSaved?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
            await MainActor.run {
                isSaving = false
            }
        }
    }

    private func deletePlan() {
        Task {
            do {
                try await programService.deleteProgram(id: program.id, userEmail: userEmail)
                await MainActor.run {
                    onPlanDeleted?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func deactivatePlan() {
        // TODO: Add deactivate API
        print("[PlanSettings] Deactivate requested for program \(program.id)")
        dismiss()
    }
}

// MARK: - Day Order Item

private struct DayOrderItem: Identifiable {
    let id = UUID()
    var dayNumber: Int
    var isWorkout: Bool
    var workoutLabel: String
}

// MARK: - Day Order Editor Sheet

private struct DayOrderEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var dayOrder: [DayOrderItem]
    var onSave: () -> Void
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach($dayOrder) { $item in
                    HStack {
                        // Day number
                        Text("Day \(item.dayNumber)")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 60, alignment: .leading)

                        Spacer()

                        // Workout/Rest toggle
                        Button {
                            item.isWorkout.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: item.isWorkout ? "dumbbell.fill" : "bed.double.fill")
                                    .font(.system(size: 14))
                                Text(item.isWorkout ? "Workout" : "Rest")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(item.isWorkout ? .primary : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(item.isWorkout ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
                            .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
                .onMove { from, to in
                    dayOrder.move(fromOffsets: from, toOffset: to)
                    // Update day numbers after reordering
                    for (index, _) in dayOrder.enumerated() {
                        dayOrder[index].dayNumber = index + 1
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .navigationTitle("Day Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Gym Profiles List Sheet

private struct GymProfilesListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    let userEmail: String

    @State private var showManageProfiles = false
    @State private var showCreateProfile = false
    @State private var selectedProfileForEdit: WorkoutProfile?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(userProfileService.workoutProfiles, id: \.id) { profile in
                        Button {
                            selectProfile(profile)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.displayName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)

                                    Text("\(profile.availableEquipment.count) equipment items")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if profile.id == userProfileService.activeWorkoutProfileId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Select Gym Profile")
                }

                Section {
                    Button {
                        showManageProfiles = true
                    } label: {
                        Label("Manage Gym Profiles", systemImage: "gearshape")
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Gym Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateProfile = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .navigationDestination(isPresented: $showManageProfiles) {
                ManageGymProfilesView(userEmail: userEmail)
            }
            .navigationDestination(isPresented: $showCreateProfile) {
                CreateGymProfileView(userEmail: userEmail)
            }
        }
    }

    private func selectProfile(_ profile: WorkoutProfile) {
        // Ensure profile has a valid ID
        guard let profileId = profile.id else {
            print("[GymProfiles] ❌ Profile has no ID")
            dismiss()
            return
        }

        // Skip if already the active profile
        guard profileId != userProfileService.activeWorkoutProfileId else {
            dismiss()
            return
        }

        print("[GymProfiles] Activating profile: \(profile.displayName) (id: \(profileId))")

        Task {
            do {
                try await userProfileService.activateWorkoutProfile(profileId: profileId)
                print("[GymProfiles] ✅ Successfully activated profile: \(profile.displayName)")
            } catch {
                print("[GymProfiles] ❌ Failed to activate profile: \(error.localizedDescription)")
            }
        }

        dismiss()
    }
}

// MARK: - Manage Gym Profiles View

private struct ManageGymProfilesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    let userEmail: String

    @State private var selectedProfileForEquipment: WorkoutProfile?
    @State private var showCreateProfile = false

    var body: some View {
        List {
            ForEach(userProfileService.workoutProfiles, id: \.id) { profile in
                NavigationLink {
                    GymProfileEquipmentView(profile: profile, userEmail: userEmail)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.displayName)
                                .font(.system(size: 16, weight: .medium))

                            Text("\(profile.availableEquipment.count) equipment items")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Manage Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateProfile = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .navigationDestination(isPresented: $showCreateProfile) {
            CreateGymProfileView(userEmail: userEmail)
        }
    }
}

// MARK: - Create Gym Profile View

private struct CreateGymProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    let userEmail: String

    @State private var profileName: String
    @State private var selectedOption: OnboardingViewModel.GymLocationOption
    @State private var selectedEquipment: Set<Equipment>
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(userEmail: String) {
        self.userEmail = userEmail
        let existingNames = UserProfileService.shared.workoutProfiles.map { $0.displayName }
        let defaultName = Self.defaultGymName(from: existingNames)
        let defaultOption: OnboardingViewModel.GymLocationOption = .largeGym
        _profileName = State(initialValue: defaultName)
        _selectedOption = State(initialValue: defaultOption)
        _selectedEquipment = State(initialValue: Self.equipmentDefaults(for: defaultOption))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gym Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("Gym Name", text: $profileName)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color("containerbg"))
                        .cornerRadius(100)
                        .submitLabel(.done)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Gym Type")
                        .font(.headline)
                        .foregroundColor(.primary)

                    ForEach(OnboardingViewModel.GymLocationOption.allCases) { option in
                        gymOptionRow(option)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Equipment")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(selectedEquipment.count) selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text("Tap to tweak the equipment for this gym.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(equipmentSections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(section.items, id: \.self) { equipment in
                                    EquipmentSelectionButton(
                                        equipment: equipment,
                                        isSelected: selectedEquipment.contains(equipment),
                                        onTap: { toggleEquipment(equipment) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color("primarybg").ignoresSafeArea())
        .navigationTitle("New Gym Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await createProfile() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .disabled(isSaving || trimmedProfileName.isEmpty)
            }
        }
        .alert("Unable to Create Gym Profile", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var trimmedProfileName: String {
        profileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var equipmentSections: [(title: String, items: [Equipment])] {
        let allEquipment = Set(Equipment.allCases)

        func filtered(_ equipments: [Equipment]) -> [Equipment] {
            equipments
                .filter { allEquipment.contains($0) && $0 != .bodyWeight }
                .sorted { $0.rawValue < $1.rawValue }
        }

        return [
            ("Small Weights", filtered([.dumbbells, .kettlebells])),
            ("Bars & Plates", filtered([.barbells, .ezBar])),
            ("Benches & Racks", filtered([.flatBench, .inclineBench, .declineBench, .squatRack, .preacherCurlBench])),
            ("Cable Machines", filtered([.cable, .latPulldownCable, .rowMachine])),
            ("Resistance Bands", filtered([.resistanceBands])),
            ("Exercise Balls & More", filtered([.stabilityBall, .medicineBalls, .bosuBalanceTrainer, .box, .pvc])),
            ("Plated Machines", filtered([.hammerstrengthMachine, .legPress, .hackSquatMachine, .sled])),
            ("Weight Machines", filtered([
                .smithMachine, .legExtensionMachine, .legCurlMachine, .calfRaiseMachine,
                .shoulderPressMachine, .tricepsExtensionMachine, .bicepsCurlMachine,
                .abCrunchMachine, .preacherCurlMachine
            ])),
            ("Specialties", filtered([
                .pullupBar, .dipBar, .battleRopes, .rings, .platforms
            ]))
        ]
        .filter { !$0.items.isEmpty }
    }

    private func gymOptionRow(_ option: OnboardingViewModel.GymLocationOption) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedOption = option
                if option != .custom {
                    selectedEquipment = Self.equipmentDefaults(for: option)
                }
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(option.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(option.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: selectedOption == option ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedOption == option ? .primary : .secondary)
            }
            .foregroundColor(.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color("containerbg"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selectedOption == option ? Color.primary : Color.clear, lineWidth: selectedOption == option ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private func toggleEquipment(_ equipment: Equipment) {
        HapticFeedback.generate()
        UISelectionFeedbackGenerator().selectionChanged()
        if selectedEquipment.contains(equipment) {
            selectedEquipment.remove(equipment)
        } else {
            selectedEquipment.insert(equipment)
        }
    }

    @MainActor
    private func createProfile() async {
        let trimmed = trimmedProfileName
        guard !trimmed.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await userProfileService.createWorkoutProfile(named: trimmed, makeActive: true)
            persistEquipmentSelection()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistEquipmentSelection() {
        let equipmentList = selectedEquipment
            .filter { $0 != .bodyWeight }
            .map { $0.rawValue }
        let locationValue = Self.workoutLocationValue(for: selectedOption)
        let email = userEmail.isEmpty ? (UserDefaults.standard.string(forKey: "userEmail") ?? "") : userEmail
        guard !email.isEmpty else { return }

        var payload: [String: Any] = [
            "available_equipment": equipmentList,
            "workout_location": locationValue
        ]

        if let profileId = userProfileService.activeWorkoutProfile?.id {
            payload["profile_id"] = profileId
        }

        NetworkManagerTwo.shared.updateWorkoutPreferences(email: email, workoutData: payload) { result in
            switch result {
            case .success:
                print("[GymProfiles] Updated equipment for new gym profile.")
            case .failure(let error):
                print("[GymProfiles] Failed to update equipment: \(error.localizedDescription)")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private static func defaultGymName(from existingNames: [String]) -> String {
        let baseName = "New Gym"
        let usedNames = Set(existingNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        if !usedNames.contains(baseName.lowercased()) {
            return baseName
        }

        var suffix = 1
        while usedNames.contains("\(baseName) \(suffix)".lowercased()) {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }

    private static func equipmentDefaults(for option: OnboardingViewModel.GymLocationOption) -> Set<Equipment> {
        switch option {
        case .largeGym:
            return Set(Equipment.allCases.filter { $0 != .bodyWeight })
        case .smallGym:
            return Set(EquipmentView.EquipmentType.smallGym.equipmentList)
        case .garageGym:
            return Set(EquipmentView.EquipmentType.garageGym.equipmentList)
        case .atHome:
            return Set(EquipmentView.EquipmentType.atHome.equipmentList)
        case .noEquipment:
            return []
        case .custom:
            return []
        }
    }

    private static func workoutLocationValue(for option: OnboardingViewModel.GymLocationOption) -> String {
        switch option {
        case .largeGym: return "large_gym"
        case .smallGym: return "small_gym"
        case .garageGym: return "garage_gym"
        case .atHome: return "home"
        case .noEquipment: return "bodyweight"
        case .custom: return "custom"
        }
    }
}

// MARK: - Gym Profile Equipment View

private struct GymProfileEquipmentView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    let profile: WorkoutProfile
    let userEmail: String

    @State private var editedName: String
    @State private var selectedEquipment: Set<Equipment>
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    // Can only delete if there's more than one profile
    private var canDelete: Bool {
        userProfileService.workoutProfiles.count > 1
    }

    init(profile: WorkoutProfile, userEmail: String) {
        self.profile = profile
        self.userEmail = userEmail
        _editedName = State(initialValue: profile.name)
        // Use Equipment.from(string:) to handle both new format ("Barbells") and legacy format ("barbell")
        let equipment = profile.availableEquipment.compactMap { Equipment.from(string: $0) }
        _selectedEquipment = State(initialValue: Set(equipment))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gym Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("New Gym", text: $editedName)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color("containerbg"))
                        .cornerRadius(100)
                        .submitLabel(.done)
                }

                Text("Pick the equipment available at your gym. We use this to tailor workouts to what you can actually use.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                ForEach(equipmentSections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(section.items, id: \.self) { equipment in
                                EquipmentSelectionButton(
                                    equipment: equipment,
                                    isSelected: selectedEquipment.contains(equipment),
                                    onTap: { toggleEquipment(equipment) }
                                )
                            }
                        }
                    }
                }

                // Extra bottom padding to account for floating delete button
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color("primarybg").ignoresSafeArea())
        .navigationTitle("Gym Equipment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                toolbarButton(systemName: "checkmark") {
                    saveChanges()
                }
                .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        // Floating Delete Gym button (Apple Calendar style)
        .safeAreaInset(edge: .bottom) {
            if canDelete {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    if isDeleting {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Text("Delete Gym")
                    }
                }
                .font(.system(size: 17))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .foregroundColor(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .disabled(isDeleting)
            }
        }
        .confirmationDialog(
            "Delete \"\(profile.displayName)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Gym", role: .destructive) {
                Task {
                    await deleteProfile()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This gym profile will be permanently deleted. This action cannot be undone.")
        }
    }

    private var equipmentSections: [(title: String, items: [Equipment])] {
        let allEquipment = Set(Equipment.allCases)

        func filtered(_ equipments: [Equipment]) -> [Equipment] {
            equipments
                .filter { allEquipment.contains($0) && $0 != .bodyWeight }
                .sorted { $0.rawValue < $1.rawValue }
        }

        return [
            ("Small Weights", filtered([.dumbbells, .kettlebells])),
            ("Bars & Plates", filtered([.barbells, .ezBar])),
            ("Benches & Racks", filtered([.flatBench, .inclineBench, .declineBench, .squatRack, .preacherCurlBench])),
            ("Cable Machines", filtered([.cable, .latPulldownCable, .rowMachine])),
            ("Resistance Bands", filtered([.resistanceBands])),
            ("Exercise Balls & More", filtered([.stabilityBall, .medicineBalls, .bosuBalanceTrainer, .box, .pvc])),
            ("Plated Machines", filtered([.hammerstrengthMachine, .legPress, .hackSquatMachine, .sled])),
            ("Weight Machines", filtered([
                .smithMachine, .legExtensionMachine, .legCurlMachine, .calfRaiseMachine,
                .shoulderPressMachine, .tricepsExtensionMachine, .bicepsCurlMachine,
                .abCrunchMachine, .preacherCurlMachine
            ])),
            ("Specialties", filtered([
                .pullupBar, .dipBar, .battleRopes, .rings, .platforms
            ]))
        ]
        .filter { !$0.items.isEmpty }
    }

    private func toggleEquipment(_ equipment: Equipment) {
        HapticFeedback.generate()
        UISelectionFeedbackGenerator().selectionChanged()
        if selectedEquipment.contains(equipment) {
            selectedEquipment.remove(equipment)
        } else {
            selectedEquipment.insert(equipment)
        }
    }

    private func saveChanges() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? profile.displayName : trimmedName
        let equipmentList = Equipment.allCases
            .filter { selectedEquipment.contains($0) && $0 != .bodyWeight }
            .map { $0.rawValue }
        updateLocalProfile(name: resolvedName, equipment: equipmentList)
        persistEquipmentSelection(equipmentList)
        dismiss()
    }

    private func updateLocalProfile(name: String, equipment: [String]) {
        guard let profileId = profile.id else { return }
        if let index = userProfileService.workoutProfiles.firstIndex(where: { $0.id == profileId }) {
            var updated = userProfileService.workoutProfiles[index]
            updated.name = name
            updated.availableEquipment = equipment
            userProfileService.workoutProfiles[index] = updated
        }
        if var data = userProfileService.profileData,
           let index = data.workoutProfiles.firstIndex(where: { $0.id == profileId }) {
            var updated = data.workoutProfiles[index]
            updated.name = name
            updated.availableEquipment = equipment
            data.workoutProfiles[index] = updated
            userProfileService.profileData = data
        }
    }

    private func persistEquipmentSelection(_ equipment: [String]) {
        guard let profileId = profile.id else { return }
        let email = userEmail.isEmpty ? (UserDefaults.standard.string(forKey: "userEmail") ?? "") : userEmail
        guard !email.isEmpty else { return }
        NetworkManagerTwo.shared.updateWorkoutPreferences(
            email: email,
            workoutData: ["available_equipment": equipment],
            profileId: profileId
        ) { result in
            switch result {
            case .success:
                print("[GymEquipment] Equipment updated for profile \(profileId).")
            case .failure(let error):
                print("[GymEquipment] Failed to update equipment: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func deleteProfile() async {
        guard let profileId = profile.id, canDelete else { return }
        isDeleting = true
        do {
            try await userProfileService.deleteWorkoutProfile(profileId: profileId)
            dismiss()
        } catch {
            print("[GymEquipment] Failed to delete profile: \(error.localizedDescription)")
            isDeleting = false
        }
    }

    @ViewBuilder
    private func toolbarButton(systemName: String, action: @escaping () -> Void) -> some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
        } else {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
        }
    }
}

// MARK: - Exercise Reorder Sheet

private struct ExerciseReorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercises: [ProgramExercise]
    var onSave: ([ProgramExercise]) -> Void

    @State private var reorderedExercises: [ProgramExercise]
    @State private var editMode: EditMode = .active

    init(exercises: [ProgramExercise], onSave: @escaping ([ProgramExercise]) -> Void) {
        self.exercises = exercises
        self.onSave = onSave
        _reorderedExercises = State(initialValue: exercises)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(reorderedExercises, id: \.id) { exercise in
                    HStack(spacing: 12) {
                        // Thumbnail
                        Group {
                            let imageName = String(format: "%04d", exercise.exerciseId)
                            if let image = UIImage(named: imageName) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.systemGray5))
                                    Image(systemName: "dumbbell")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 12))
                                }
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(exercise.exerciseName)
                            .font(.system(size: 15))
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
                .onMove { from, to in
                    reorderedExercises.move(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .navigationTitle("Reorder Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(reorderedExercises)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Edit Exercise Targets View
// Replicates ExerciseLoggingView layout for editing sets/reps targets

private struct EditExerciseTargetsView: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: ProgramExercise
    let weekData: WeeklyExerciseData
    let exerciseInstanceId: Int
    let userEmail: String
    var onSave: ((Int, Int) -> Void)?

    @State private var targetSets: Int
    @State private var targetReps: Int
    @State private var isSaving = false

    // Sheet drag state (matching ExerciseLoggingView)
    @State private var sheetCurrentTop: CGFloat? = nil
    @State private var dragStartTop: CGFloat = 0
    @State private var isDraggingSheet: Bool = false

    private var thumbnailImageName: String {
        String(format: "%04d", exercise.exerciseId)
    }

    private var videoURL: URL? {
        let videoId = String(format: "%04d", exercise.exerciseId)
        return URL(string: "https://humulistoragecentral.blob.core.windows.net/videos/hevc/filtered_vids_alpha_hevc/\(videoId).mov")
    }

    init(
        exercise: ProgramExercise,
        weekData: WeeklyExerciseData,
        exerciseInstanceId: Int,
        userEmail: String,
        onSave: ((Int, Int) -> Void)? = nil
    ) {
        self.exercise = exercise
        self.weekData = weekData
        self.exerciseInstanceId = exerciseInstanceId
        self.userEmail = userEmail
        self.onSave = onSave
        _targetSets = State(initialValue: weekData.sets)
        _targetReps = State(initialValue: weekData.reps)
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let safeTop = geo.safeAreaInsets.top
            let expandedTop = max(safeTop + 40, height * 0.15)
            let collapsedTop = max(expandedTop + 140, height * 0.45)

            ZStack(alignment: .top) {
                // Video background
                Color("sectionbg")
                    .ignoresSafeArea(.all)

                // Video player (adapts to sheet position)
                let sheetTop = sheetCurrentTop ?? expandedTop
                let isCollapsed = sheetTop >= (collapsedTop - 20)
                let extraGapWhenCollapsed: CGFloat = 16
                let videoPadding: CGFloat = isCollapsed ? (12 + extraGapWhenCollapsed) : 12
                let videoH = max(120, sheetTop - videoPadding)

                if let videoURL = videoURL {
                    CustomExerciseVideoPlayer(videoURL: videoURL)
                        .frame(maxWidth: .infinity, minHeight: videoH, maxHeight: videoH, alignment: .center)
                        .clipped()
                        .padding(.top, safeTop - 125)
                } else {
                    // Fallback thumbnail
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
                                        .foregroundColor(.white)
                                        .font(.system(size: 32))
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: videoH, maxHeight: videoH, alignment: .center)
                    .clipped()
                    .padding(.top, safeTop - 125)
                }

                // Draggable content sheet
                VStack(spacing: 0) {
                    // Drag handle
                    Capsule()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 40, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .contentShape(Rectangle())
                        .gesture(sheetDragGesture(expandedTop: expandedTop, collapsedTop: collapsedTop))

                    // Main content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Exercise header
                            exerciseHeaderSection

                            // Sets input section
                            setsInputSection

                            // Bottom spacing
                            Color.clear.frame(height: 120)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollDisabled(isDraggingSheet)
                }
                .background(Color("primarybg"))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .offset(y: sheetTop)
                .simultaneousGesture(sheetDragGesture(expandedTop: expandedTop, collapsedTop: collapsedTop))
            }
            .onAppear {
                if sheetCurrentTop == nil { sheetCurrentTop = expandedTop }
            }
        }
        // Top buttons pinned to safe area (matching ExerciseLoggingView)
        .safeAreaInset(edge: .top) {
            HStack {
                // xmark on left with ultraThinMaterial (no gray container)
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
                }
                .padding(.leading, 12)
                .padding(.top, 4)

                Spacer()

                // checkmark on right with glassProminent
                if isSaving {
                    ProgressView()
                        .padding(.trailing, 12)
                        .padding(.top, 4)
                } else {
                    Button(action: { saveTargets() }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                    }
                    .glassProminentButtonStyle()
                    .padding(.trailing, 12)
                    .padding(.top, 4)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Exercise Header Section
    private var exerciseHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.exerciseName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            // Week label as subtitle
            Text(weekData.displayLabel)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Sets Input Section (matching ExerciseLoggingView style)
    private var setsInputSection: some View {
        VStack(spacing: 0) {
            ForEach(0..<targetSets, id: \.self) { setIndex in
                VStack(spacing: 0) {
                    setRow(setNumber: setIndex + 1)

                    if setIndex < targetSets - 1 {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }

            // Add set button
            Button(action: {
                if targetSets < 10 {
                    targetSets += 1
                    HapticFeedback.generateLigth()
                }
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
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 8)
        }
    }

    // MARK: - Set Row (matching DynamicSetRowView style)
    private func setRow(setNumber: Int) -> some View {
        HStack(spacing: 12) {
            // Set number circle
            ZStack {
                Circle()
                    .fill(Color("thumbbg"))
                    .frame(width: 36, height: 36)
                Text("\(setNumber)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // Reps input
            HStack(spacing: 4) {
                Button {
                    if targetReps > 1 {
                        targetReps -= 1
                        HapticFeedback.generateLigth()
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color("thumbbg"))
                        .clipShape(Circle())
                }

                Text("\(targetReps)")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .frame(minWidth: 32)
                    .multilineTextAlignment(.center)

                Button {
                    if targetReps < 30 {
                        targetReps += 1
                        HapticFeedback.generateLigth()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color("thumbbg"))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color("containerbg"))
            .cornerRadius(12)

            Text("reps")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()

            // Delete set button (swipe alternative)
            if targetSets > 1 {
                Button {
                    if targetSets > 1 {
                        targetSets -= 1
                        HapticFeedback.generateLigth()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }

    // MARK: - Sheet Drag Gesture
    private func sheetDragGesture(expandedTop: CGFloat, collapsedTop: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dy) > abs(dx) else { return }
                if !isDraggingSheet {
                    isDraggingSheet = true
                    dragStartTop = sheetCurrentTop ?? collapsedTop
                }
                let proposed = dragStartTop + dy
                sheetCurrentTop = max(expandedTop, min(collapsedTop, proposed))
            }
            .onEnded { _ in
                guard isDraggingSheet else { return }
                let mid = (expandedTop + collapsedTop) / 2
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    sheetCurrentTop = (sheetCurrentTop ?? mid) < mid ? expandedTop : collapsedTop
                }
                isDraggingSheet = false
            }
    }

    private func saveTargets() {
        isSaving = true
        HapticFeedback.generateLigth()

        Task {
            do {
                try await NetworkManagerTwo.shared.updateExerciseTargets(
                    exerciseInstanceId: exerciseInstanceId,
                    targetSets: targetSets,
                    targetReps: targetReps,
                    userEmail: userEmail
                )
                await MainActor.run {
                    onSave?(targetSets, targetReps)
                    dismiss()
                }
            } catch {
                print("[EditExerciseTargets] Failed to save: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// Helper extension for glass prominent button style
private extension View {
    @ViewBuilder
    func glassProminentButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
        } else {
            self.background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
        }
    }
}

#Preview {
    NavigationStack {
        SinglePlanView(initialProgram: TrainingProgram(
            id: 1,
            name: "12-Week Strength",
            programType: "upper_lower",
            fitnessGoal: "hypertrophy",
            experienceLevel: "intermediate",
            daysPerWeek: 4,
            sessionDurationMinutes: 60,
            startDate: "2026-01-01",
            endDate: "2026-03-25",
            totalWeeks: 12,
            includeDeload: true,
            defaultWarmupEnabled: true,
            defaultCooldownEnabled: false,
            includeFoamRolling: true,
            isActive: true,
            createdAt: "2026-01-01",
            syncVersion: 1,
            weeks: nil
        ))
        .environmentObject(WorkoutManager.shared)
    }
}
