//
//  PlanView.swift
//  pods
//
//  Created by Dimi Nunez on 1/13/26.
//

//
//  PlanView.swift
//  pods
//
//  MacroFactor-style workout program plan view.
//  Shows workout cards (Workout A, Workout B, etc.) with muscle chips.
//  Tapping a card navigates to workout detail.
//

import SwiftUI

struct PlanView: View {
    @ObservedObject private var programService = ProgramService.shared
    @EnvironmentObject private var workoutManager: WorkoutManager
    @State private var selectedWeekNumber: Int = 1
    @State private var selectedWorkoutDay: ProgramDay?
    @State private var showAllPlans = false
    @State private var showCreateProgram = false
    @State private var showSinglePlanView = false
    @State private var currentWorkout: TodayWorkout?
    /// Tracks days that are optimistically toggled (pending server confirmation)
    /// Value: true = optimistically completed, false = optimistically uncompleted
    @State private var optimisticRestDayStates: [Int: Bool] = [:]

    private var userEmail: String {
        UserDefaults.standard.string(forKey: "userEmail") ?? ""
    }

    var body: some View {
        Group {
            if programService.isLoading && programService.activeProgram == nil {
                loadingView
            } else if let program = programService.activeProgram {
                programContentView(program: program)
            } else {
                emptyStateView
            }
        }
        .task {
            await loadData()
        }
        .fullScreenCover(item: $selectedWorkoutDay) { day in
            ProgramWorkoutDetailView(
                day: day,
                onDismiss: { selectedWorkoutDay = nil },
                onStart: { programDay in
                    selectedWorkoutDay = nil
                    startWorkout(from: programDay)
                }
            )
        }
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
        .sheet(isPresented: $showAllPlans) {
            AllPlansView()
        }
        .sheet(isPresented: $showCreateProgram) {
            CreateProgramView(userEmail: userEmail)
        }
        .fullScreenCover(isPresented: $showSinglePlanView, onDismiss: {
            // Force refresh when returning from SinglePlanView in case days were added/modified
            Task {
                _ = try? await programService.fetchActiveProgram(userEmail: userEmail)
            }
        }) {
            if let program = programService.activeProgram {
                NavigationStack {
                    SinglePlanView(initialProgram: program)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    showSinglePlanView = false
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                        }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCreateProgram)) { _ in
            showCreateProgram = true
        }
        .onChange(of: programService.activeProgram?.id) { oldId, newId in
            // When the active program is deleted (becomes nil), dismiss the SinglePlanView
            if oldId != nil && newId == nil {
                showSinglePlanView = false
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading plan...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Active Plan")
                    .font(.title2.bold())

                Text("Create a structured training plan to track your workouts week by week.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Program Content

    @ViewBuilder
    private func programContentView(program: TrainingProgram) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Program name header with chevron
                Button {
                    showSinglePlanView = true
                } label: {
                    HStack(spacing: 4) {
                        Text(program.name)
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)

                // Active Plan section with week selector
                VStack(alignment: .leading, spacing: 10) {
                    // Section header with Active Plan label and week selector
                    HStack {
                        Text("Active Plan")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)

                        Spacer()

                        weekSelector(program: program)
                    }
                    .padding(.horizontal, 16)

                    // All days for selected week (including rest days)
                    if let weeks = program.weeks,
                       let selectedWeek = weeks.first(where: { $0.weekNumber == selectedWeekNumber }),
                       let days = selectedWeek.days {
                        VStack(spacing: 12) {
                            ForEach(days.sorted(by: { $0.dayNumber < $1.dayNumber })) { day in
                                // Check dayType first, but also fallback to workoutLabel for legacy data
                                let isRestDay = day.dayType == .rest ||
                                    day.workoutLabel.lowercased().hasPrefix("rest")

                                if !isRestDay {
                                    ProgramWorkoutCard(day: day) {
                                        selectedWorkoutDay = day
                                    }
                                } else {
                                    // Rest day card with completion checkbox
                                    RestDayCard(
                                        day: day,
                                        onToggleComplete: { toggleRestDayComplete(day) },
                                        optimisticState: optimisticRestDayStates[day.id]
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Divider and action buttons
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal, 16)

                    // New Workout button
                    Button {
                        HapticFeedback.generate()
                        NotificationCenter.default.post(name: .openCreateWorkout, object: nil)
                    } label: {
                        Text("New Workout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(.systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)

                    // See All Plans button
                    Button {
                        showAllPlans = true
                    } label: {
                        Text("See All Plans")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("containerbg"))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 24)
            }
            .padding(.vertical, 16)
        }
        .background(Color("primarybg"))
        .refreshable {
            await loadData()
        }
        .onAppear {
            // Set selected week to current week
            if let currentWeek = program.currentWeekNumber {
                selectedWeekNumber = min(currentWeek, program.totalCalendarWeeks)
            }
        }
    }

    // MARK: - Week Selector

    private func weekSelector(program: TrainingProgram) -> some View {
        Menu {
            ForEach(1...program.totalCalendarWeeks, id: \.self) { weekNum in
                let isDeload = program.weeks?.first(where: { $0.weekNumber == weekNum })?.isDeload ?? false

                Button(action: { selectedWeekNumber = weekNum }) {
                    HStack {
                        Text("Week \(weekNum)")
                        if isDeload {
                            Text("(Deload)")
                                .foregroundColor(.secondary)
                        }
                        if weekNum == selectedWeekNumber {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("Week \(selectedWeekNumber)")
                    .font(.system(size: 15, weight: .medium))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func loadData() async {
        // Skip fetch if we already have the active program loaded
        // This prevents request cancellation when tab switching causes view recreation
        guard programService.activeProgram == nil else { return }

        do {
            _ = try await programService.fetchActiveProgram(userEmail: userEmail)
        } catch {
            print("Error loading program: \(error)")
        }
    }

    private func toggleRestDayComplete(_ day: ProgramDay) {
        // Determine current visual state (considering any pending optimistic update)
        let currentlyShownAsCompleted: Bool
        if let optimistic = optimisticRestDayStates[day.id] {
            currentlyShownAsCompleted = optimistic
        } else {
            currentlyShownAsCompleted = day.isCompleted
        }

        // Optimistic update - toggle immediately (UI updates instantly)
        let newState = !currentlyShownAsCompleted
        optimisticRestDayStates[day.id] = newState
        HapticFeedback.generateLigth()

        // Sync in background
        Task {
            do {
                let updatedDay = try await programService.toggleDayComplete(dayId: day.id, userEmail: userEmail)
                print("✅ PlanView: Toggled rest day \(day.id) completion to: \(updatedDay.isCompleted)")
                // Clear optimistic state - server state is now authoritative
                optimisticRestDayStates.removeValue(forKey: day.id)
            } catch {
                print("⚠️ PlanView: Failed to toggle rest day complete: \(error)")
                // Revert optimistic update on failure
                optimisticRestDayStates.removeValue(forKey: day.id)
            }
        }
    }

    private func startWorkout(from day: ProgramDay) {
        guard let workout = buildTodayWorkout(from: day) else {
            print("⚠️ PlanView: Failed to build workout from program day")
            return
        }
        HapticFeedback.generateLigth()
        currentWorkout = workout
    }

    private func buildTodayWorkout(from day: ProgramDay) -> TodayWorkout? {
        guard let workoutSession = day.workout,
              let exercises = workoutSession.exercises,
              !exercises.isEmpty else {
            return nil
        }

        let todayExercises: [TodayWorkoutExercise] = exercises.compactMap { programExercise in
            guard let exerciseData = ExerciseDatabase.findExercise(byId: programExercise.exerciseId) else {
                return nil
            }
            let trackingType = ExerciseClassificationService.determineTrackingType(for: exerciseData)
            return TodayWorkoutExercise(
                exercise: exerciseData,
                sets: programExercise.targetSets ?? 3,
                reps: programExercise.targetReps ?? 10,
                weight: nil,
                restTime: 90,
                notes: nil,
                warmupSets: nil,
                flexibleSets: nil,
                trackingType: trackingType
            )
        }

        guard !todayExercises.isEmpty else { return nil }

        return TodayWorkout(
            id: UUID(),
            date: Date(),
            title: day.workoutLabel,
            exercises: todayExercises,
            blocks: nil,
            estimatedDuration: workoutSession.estimatedDurationMinutes,
            fitnessGoal: .hypertrophy,
            difficulty: 5,
            warmUpExercises: nil,
            coolDownExercises: nil,
            programDayId: day.id
        )
    }
}

// MARK: - Rest Day Card

struct RestDayCard: View {
    let day: ProgramDay
    let onToggleComplete: () -> Void
    /// nil = use server state, true = optimistically completed, false = optimistically uncompleted
    let optimisticState: Bool?

    /// Computed property that respects optimistic state over server state
    private var isCompleted: Bool {
        optimisticState ?? day.isCompleted
    }

    var body: some View {
        HStack {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 18))
                .foregroundColor(.secondary)

            Text("Rest Day")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            // Completion checkbox - toggleable
            Button {
                onToggleComplete()
            } label: {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color("containerbg"))
        .cornerRadius(28)
    }
}

// MARK: - Program Workout Card

struct ProgramWorkoutCard: View {
    let day: ProgramDay
    let onTap: () -> Void

    // Show up to 4 muscle chips, rest are hidden
    private let maxVisibleChips = 4

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Title row
                HStack {
                    Text(day.workoutLabel)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Completion indicator
                    if day.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }

                // Muscle chips - horizontal scroll, first few visible
                if !day.targetMuscles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(day.targetMuscles.prefix(maxVisibleChips)), id: \.self) { muscle in
                                Text(muscle)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color("primarybg"))
                                    .cornerRadius(12)
                            }

                            // Show +N more if there are hidden chips
                            if day.targetMuscles.count > maxVisibleChips {
                                Text("+\(day.targetMuscles.count - maxVisibleChips)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color("primarybg"))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color("containerbg"))
            .cornerRadius(28)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flow Layout for Muscle Chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Program Workout Detail View

struct ProgramWorkoutDetailView: View {
    let day: ProgramDay
    let onDismiss: () -> Void
    let onStart: (ProgramDay) -> Void

    @ObservedObject private var profileService = UserProfileService.shared
    @ObservedObject private var programService = ProgramService.shared
    @State private var showEditNameSheet = false
    @State private var editedName: String = ""
    @State private var showGymProfileSheet = false
    @State private var showSkipConfirmation = false
    @State private var isSkipping = false
    @State private var isSavingName = false
    @State private var loggingContext: LogExerciseSheetContext?

    private var userEmail: String {
        UserDefaults.standard.string(forKey: "userEmail") ?? ""
    }

    /// Convert all program exercises to TodayWorkoutExercise for logging context
    private var todayWorkoutExercises: [TodayWorkoutExercise] {
        guard let workout = day.workout, let exercises = workout.exercises else {
            return []
        }
        return exercises.compactMap { programExercise in
            if let exerciseData = ExerciseDatabase.findExercise(byId: programExercise.exerciseId) {
                let trackingType = ExerciseClassificationService.determineTrackingType(for: exerciseData)
                return TodayWorkoutExercise(
                    exercise: exerciseData,
                    sets: programExercise.targetSets ?? 3,
                    reps: programExercise.targetReps ?? 10,
                    weight: nil,
                    restTime: 90,
                    notes: nil,
                    warmupSets: nil,
                    flexibleSets: nil,
                    trackingType: trackingType
                )
            } else {
                let basicExercise = ExerciseData(
                    id: programExercise.exerciseId,
                    name: programExercise.exerciseName,
                    exerciseType: "Strength",
                    bodyPart: "",
                    equipment: "Unknown",
                    gender: "unisex",
                    target: "",
                    synergist: ""
                )
                return TodayWorkoutExercise(
                    exercise: basicExercise,
                    sets: programExercise.targetSets ?? 3,
                    reps: programExercise.targetReps ?? 10,
                    weight: nil,
                    restTime: 90,
                    notes: nil,
                    warmupSets: nil,
                    flexibleSets: nil,
                    trackingType: .repsWeight
                )
            }
        }
    }

    private var resolvedWorkoutLabel: String {
        guard let weeks = programService.activeProgram?.weeks else {
            return day.workoutLabel
        }
        for week in weeks {
            if let match = week.days?.first(where: { $0.id == day.id }) {
                return match.workoutLabel
            }
        }
        return day.workoutLabel
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color("primarybg")
                    .ignoresSafeArea()

                if let workout = day.workout, let exercises = workout.exercises, !exercises.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Muscle targets header
                            if !day.targetMuscles.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(day.targetMuscles, id: \.self) { muscle in
                                        Text(muscle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color("containerbg"))
                                            .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }

                            // Exercise list
                            VStack(spacing: 0) {
                                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                                    ProgramExerciseRow(
                                        exercise: exercise,
                                        onTap: {
                                            // Open exercise logging sheet
                                            let allExercises = todayWorkoutExercises
                                            if index < allExercises.count {
                                                loggingContext = LogExerciseSheetContext(
                                                    exercise: allExercises[index],
                                                    allExercises: allExercises,
                                                    index: index
                                                )
                                            }
                                        },
                                        onReplace: {
                                            // TODO: Implement replace exercise
                                        },
                                        onHistory: {
                                            // TODO: Navigate to exercise history
                                        }
                                    )

                                    if index < exercises.count - 1 {
                                        Divider()
                                            .padding(.leading, 92)
                                    }
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 52, weight: .regular))
                            .foregroundColor(.secondary)

                        Text("No exercises in this workout")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(resolvedWorkoutLabel)
                        .font(.system(size: 17, weight: .semibold))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            editedName = resolvedWorkoutLabel
                            showEditNameSheet = true
                        } label: {
                            Label("Edit Name", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showSkipConfirmation = true
                        } label: {
                            Label("Skip Workout", systemImage: "forward.fill")
                        }

                        Menu {
                            // List all gym profiles
                            ForEach(profileService.workoutProfiles) { profile in
                                Button {
                                    switchToProfile(profile)
                                } label: {
                                    HStack {
                                        Text(profile.displayName)
                                        if profile.id == profileService.activeWorkoutProfile?.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }

                            Divider()

                            Button {
                                showGymProfileSheet = true
                            } label: {
                                Label("Manage Profiles", systemImage: "gearshape")
                            }
                        } label: {
                            Label("Swap Gym Profile", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !day.isCompleted {
                Button(action: { onStart(day) }) {
                    Text("Start Workout")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showEditNameSheet) {
            EditWorkoutNameSheet(
                workoutName: $editedName,
                isSaving: isSavingName,
                onSave: { newName in
                    saveWorkoutName(newName)
                },
                onCancel: {
                    showEditNameSheet = false
                }
            )
        }
        .sheet(isPresented: $showGymProfileSheet) {
            NavigationStack {
                WorkoutProfileSettingsView()
                    .navigationTitle("Gym Profiles")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showGymProfileSheet = false
                            }
                        }
                    }
            }
        }
        .confirmationDialog(
            "Skip Workout",
            isPresented: $showSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Skip", role: .destructive) {
                skipWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to skip this workout? It will be marked as complete.")
        }
        .overlay {
            if isSkipping {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
            }
        }
        .fullScreenCover(item: $loggingContext) { ctx in
            ExerciseLoggingView(
                exercise: ctx.exercise,
                allExercises: ctx.allExercises,
                onSetLogged: nil,
                isFromWorkoutInProgress: false,
                initialCompletedSetsCount: nil,
                initialRIRValue: nil,
                onExerciseReplaced: { _ in },
                onWarmupSetsChanged: { _ in },
                onExerciseUpdated: { _ in }
            )
        }
    }

    private func switchToProfile(_ workoutProfile: WorkoutProfile) {
        guard let profileId = workoutProfile.id else { return }

        Task {
            do {
                try await profileService.activateWorkoutProfile(profileId: profileId)
            } catch {
                print("Failed to switch profile: \(error)")
            }
        }
    }

    private func skipWorkout() {
        guard !userEmail.isEmpty else { return }
        isSkipping = true

        Task {
            do {
                _ = try await programService.skipWorkout(dayId: day.id, userEmail: userEmail)
                onDismiss()
            } catch {
                print("Failed to skip workout: \(error)")
            }
            isSkipping = false
        }
    }

    private func saveWorkoutName(_ newName: String) {
        guard !userEmail.isEmpty else { return }
        isSavingName = true

        Task {
            do {
                _ = try await programService.updateWorkoutName(dayId: day.id, name: newName, userEmail: userEmail)
                showEditNameSheet = false
            } catch {
                print("Failed to save workout name: \(error)")
            }
            isSavingName = false
        }
    }
}

// MARK: - Edit Workout Name Sheet

struct EditWorkoutNameSheet: View {
    @Binding var workoutName: String
    let isSaving: Bool
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout Name", text: $workoutName)
                        .disabled(isSaving)
                }
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            onSave(workoutName)
                        }
                        .disabled(workoutName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isSaving)
    }
}

// MARK: - Program Exercise Row

struct ProgramExerciseRow: View {
    let exercise: ProgramExercise
    let onTap: () -> Void
    let onReplace: () -> Void
    let onHistory: () -> Void

    private var thumbnailImageName: String {
        String(format: "%04d", exercise.exerciseId)
    }

    private var setsAndRepsDisplay: String {
        if let sets = exercise.targetSets, let reps = exercise.targetReps {
            let setsLabel = sets == 1 ? "set" : "sets"
            return "\(sets) \(setsLabel) • \(reps) reps"
        }
        return ""
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Exercise thumbnail with rounded container
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
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Exercise info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exerciseName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        if !setsAndRepsDisplay.isEmpty {
                            Text(setsAndRepsDisplay)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer(minLength: 32)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Ellipsis menu
            Menu {
                Button("Exercise History") {
                    onHistory()
                }

                Button("Replace") {
                    onReplace()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - Create Program View

struct CreateProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var programService = ProgramService.shared

    let userEmail: String

    @State private var selectedGoal: ProgramFitnessGoal = .hypertrophy
    @State private var selectedType: ProgramType = .upperLower
    @State private var selectedExperience: ProgramExperienceLevel = .intermediate
    @State private var daysPerWeek: Int = 4
    @State private var sessionDuration: Int = 60
    @State private var totalWeeks: Int = 6
    // Workout Options (combined section)
    @State private var includeDeload: Bool = true
    @State private var warmupEnabled: Bool = false
    @State private var cooldownEnabled: Bool = false
    @State private var isGenerating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // Training Goal
                    Section {
                        Picker("Training Goal", selection: $selectedGoal) {
                            ForEach(ProgramFitnessGoal.allCases, id: \.self) { goal in
                                VStack(alignment: .leading) {
                                    Text(goal.displayName)
                                }
                                .tag(goal)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text("Training Goal")
                    } footer: {
                        Text(selectedGoal.description)
                    }

                    // Training Split
                    Section {
                        HStack {
                            Text("Split")
                            Spacer()
                            Menu {
                                ForEach(ProgramType.allCases, id: \.self) { type in
                                    Button {
                                        selectedType = type
                                        daysPerWeek = type.daysPerWeek
                                    } label: {
                                        if selectedType == type {
                                            Label(type.displayName, systemImage: "checkmark")
                                        } else {
                                            Text(type.displayName)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedType.displayName)
                                        .foregroundColor(.primary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Training Split")
                    }

                    // Duration
                    Section {
                        Stepper("\(daysPerWeek) days per week", value: $daysPerWeek, in: selectedType.daysPerWeekRange)
                        Stepper("\(sessionDuration) min per session", value: $sessionDuration, in: 30...120, step: 15)
                        Stepper("\(totalWeeks) weeks", value: $totalWeeks, in: 1...12)
                    } header: {
                        Text("Duration")
                    }
                    .onChange(of: selectedType) { oldType, newType in
                        // Clamp daysPerWeek to the new type's valid range
                        let range = newType.daysPerWeekRange
                        if daysPerWeek < range.lowerBound {
                            daysPerWeek = range.lowerBound
                        } else if daysPerWeek > range.upperBound {
                            daysPerWeek = range.upperBound
                        }
                    }

                    // Experience Level
                    Section {
                        Picker("Experience Level", selection: $selectedExperience) {
                            ForEach(ProgramExperienceLevel.allCases, id: \.self) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                    } header: {
                        Text("Experience Level")
                    }

                    // Workout Options (Deload, Warm-Up, Cool-Down)
                    Section {
                        Toggle(isOn: $includeDeload) {
                            VStack(alignment: .leading) {
                                Text("Deload Week")
                                Text("Recovery week at the end")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Toggle(isOn: $warmupEnabled) {
                            VStack(alignment: .leading) {
                                Text("Warm-Up")
                                Text("Dynamic stretches before workout")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Toggle(isOn: $cooldownEnabled) {
                            VStack(alignment: .leading) {
                                Text("Cool-Down")
                                Text("Static stretches after workout")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Workout Options")
                    }

                    // Error Message
                    if let error = error {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
                .opacity(isGenerating ? 0 : 1)

                if isGenerating {
                    ProgramGenerationView(
                        experienceLevel: selectedExperience.displayName,
                        splitName: selectedType.displayName,
                        weeks: totalWeeks
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isGenerating)
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !isGenerating {
                        Button {
                            Task { await generateProgram() }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    private func generateProgram() async {
        withAnimation {
            isGenerating = true
        }
        error = nil

        do {
            _ = try await programService.generateProgram(
                userEmail: userEmail,
                programType: selectedType,
                fitnessGoal: selectedGoal,
                experienceLevel: selectedExperience,
                daysPerWeek: daysPerWeek,
                sessionDurationMinutes: sessionDuration,
                totalWeeks: totalWeeks,
                includeDeload: includeDeload,
                defaultWarmupEnabled: warmupEnabled,
                defaultCooldownEnabled: cooldownEnabled
            )
            // Notify WorkoutManager to refresh today's workout with the new program
            NotificationCenter.default.post(name: .trainingProgramCreated, object: nil)
            dismiss()
        } catch {
            withAnimation {
                isGenerating = false
            }
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Program Generation View

private struct ProgramGenerationView: View {
    let experienceLevel: String
    let splitName: String
    let weeks: Int

    @State private var currentStep = 0
    @State private var completedSteps: Set<Int> = []

    private let steps: [(icon: String, title: String, subtitle: String)] = [
        ("person.fill", "Analyzing Profile", "Experience & fitness level"),
        ("dumbbell.fill", "Selecting Exercises", "Goal-optimized movements"),
        ("figure.strengthtraining.traditional", "Building Structure", "Weekly periodization"),
        ("chart.line.uptrend.xyaxis", "Smart Progression", "Volume & intensity curves"),
        ("calendar", "Scheduling Workouts", "Organizing your weeks"),
        ("checkmark.seal.fill", "Finalizing Plan", "Almost ready...")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .symbolEffect(.pulse, options: .repeating)

                Text("Building Your Plan")
                    .font(.system(size: 28, weight: .bold))

                Text("\(experienceLevel) \(splitName) • \(weeks) weeks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 48)

            // Steps
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    GenerationStepRow(
                        icon: step.icon,
                        title: step.title,
                        subtitle: step.subtitle,
                        state: stepState(for: index),
                        isLast: index == steps.count - 1
                    )
                }
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            startAnimation()
        }
    }

    private func stepState(for index: Int) -> GenerationStepState {
        if completedSteps.contains(index) {
            return .completed
        } else if index == currentStep {
            return .inProgress
        } else {
            return .pending
        }
    }

    private func startAnimation() {
        // Animate through steps with timing that matches typical program generation
        // Total animation: ~10.5s before finalizing step starts
        let stepDurations: [(start: Double, complete: Double)] = [
            (0.3, 2.8),    // Step 1: Analyzing Profile (2.5s duration)
            (3.0, 5.2),    // Step 2: Selecting Exercises (2.2s duration)
            (5.4, 7.4),    // Step 3: Building Structure (2s duration)
            (7.6, 9.6),    // Step 4: Smart Progression (2s duration)
            (9.8, 11.6),   // Step 5: Scheduling Workouts (1.8s duration)
            (11.8, -1)     // Step 6: Finalizing (stays in progress until API returns)
        ]

        for (index, timing) in stepDurations.enumerated() {
            // Start step
            DispatchQueue.main.asyncAfter(deadline: .now() + timing.start) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = index
                }
            }

            // Complete step (except the last one which stays in progress)
            if timing.complete > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + timing.complete) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        _ = completedSteps.insert(index)
                    }
                }
            }
        }
    }
}

// MARK: - Generation Step State

private enum GenerationStepState {
    case pending
    case inProgress
    case completed
}

// MARK: - Generation Step Row

private struct GenerationStepRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let state: GenerationStepState
    let isLast: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Icon/Status indicator
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 44, height: 44)

                if state == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                } else if state == .inProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: state == .inProgress ? .semibold : .medium))
                    .foregroundColor(state == .pending ? .secondary : .primary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .opacity(state == .pending ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: state)
    }

    private var backgroundColor: Color {
        switch state {
        case .completed:
            return .blue
        case .inProgress:
            return .blue
        case .pending:
            return Color(UIColor.systemGray5)
        }
    }
}

// MARK: - All Plans View

struct AllPlansView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var programService = ProgramService.shared
    @State private var allPrograms: [TrainingProgram] = []
    @State private var isLoading = true
    @State private var isActivating = false
    @State private var isEditMode = false
    @State private var programToDelete: TrainingProgram?

    private var userEmail: String {
        UserDefaults.standard.string(forKey: "userEmail") ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("primarybg")
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if allPrograms.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No plans yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(allPrograms) { program in
                            PlanListRow(
                                program: program,
                                isActive: program.id == programService.activeProgram?.id,
                                isEditMode: isEditMode,
                                onSelect: {
                                    if !isEditMode {
                                        activateProgram(program)
                                    }
                                },
                                onDelete: {
                                    programToDelete = program
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onMove(perform: isEditMode ? movePrograms : nil)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
                }
            }
            .navigationTitle("All Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditMode {
                        Button {
                            withAnimation {
                                isEditMode = false
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .modifier(GlassProminentButtonModifier())
                    } else {
                        Menu {
                            Button {
                                withAnimation {
                                    isEditMode = true
                                }
                            } label: {
                                Label("Edit Plans", systemImage: "pencil")
                            }

                            Button {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    NotificationCenter.default.post(name: .openCreateProgram, object: nil)
                                }
                            } label: {
                                Label("New Plan", systemImage: "plus")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
            }
            .overlay {
                if isActivating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .task {
            await loadAllPrograms()
        }
        .confirmationDialog(
            "Delete Plan",
            isPresented: .init(
                get: { programToDelete != nil },
                set: { if !$0 { programToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let program = programToDelete {
                    Task { await deleteProgram(program) }
                }
            }
            Button("Cancel", role: .cancel) {
                programToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this plan? This cannot be undone.")
        }
    }

    private func loadAllPrograms() async {
        isLoading = true
        do {
            allPrograms = try await programService.listPrograms(userEmail: userEmail)
        } catch {
            print("Error loading programs: \(error)")
        }
        isLoading = false
    }

    private func activateProgram(_ program: TrainingProgram) {
        guard program.id != programService.activeProgram?.id else { return }

        isActivating = true
        Task {
            do {
                _ = try await programService.activateProgram(programId: program.id, userEmail: userEmail)
                dismiss()
            } catch {
                print("Error activating program: \(error)")
            }
            isActivating = false
        }
    }

    private func deleteProgram(_ program: TrainingProgram) async {
        do {
            try await programService.deleteProgram(id: program.id, userEmail: userEmail)
            allPrograms.removeAll { $0.id == program.id }
        } catch {
            print("Error deleting program: \(error)")
        }
    }

    private func movePrograms(from source: IndexSet, to destination: Int) {
        allPrograms.move(fromOffsets: source, toOffset: destination)
        // Note: Reordering is visual only - no backend persistence yet
    }
}

// MARK: - Plan List Row

private struct PlanListRow: View {
    let program: TrainingProgram
    let isActive: Bool
    var isEditMode: Bool = false
    let onSelect: () -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if isEditMode {
                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button(action: onSelect) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(program.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)

                            if isActive {
                                Text("Active")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                        }

                        Text("\(program.totalCalendarWeeks) weeks • \(program.programTypeEnum?.displayName ?? program.programType)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !isEditMode {
                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary.opacity(0.3))
                        }
                    }
                }
                .padding(16)
                .background(Color("containerbg"))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isEditMode)
        }
    }
}

// MARK: - Glass Prominent Button Modifier

 struct GlassProminentButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(.blue)
        }
    }
}

#Preview {
    PlanView()
}
