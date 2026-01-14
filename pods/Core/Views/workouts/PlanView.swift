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
    @State private var selectedWeekNumber: Int = 1
    @State private var selectedWorkoutDay: ProgramDay?

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
                onStart: { _ in
                    // TODO: Start workout from program
                    selectedWorkoutDay = nil
                }
            )
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
            VStack(spacing: 16) {
                // Header with title and week selector
                planHeader(program: program)

                // All days for selected week (including rest days)
                if let weeks = program.weeks,
                   let selectedWeek = weeks.first(where: { $0.weekNumber == selectedWeekNumber }),
                   let days = selectedWeek.days {
                    VStack(spacing: 12) {
                        ForEach(days.sorted(by: { $0.dayNumber < $1.dayNumber })) { day in
                            if day.dayType == .workout {
                                ProgramWorkoutCard(day: day) {
                                    selectedWorkoutDay = day
                                }
                            } else {
                                // Rest day card
                                RestDayCard()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
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
                selectedWeekNumber = min(currentWeek, program.totalWeeks)
            }
        }
    }

    // MARK: - Plan Header

    private func planHeader(program: TrainingProgram) -> some View {
        HStack {
            Text("Active Plan")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            // Week selector dropdown menu
            Menu {
                ForEach(1...program.totalWeeks, id: \.self) { weekNum in
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
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color("containerbg"))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Actions

    private func loadData() async {
        do {
            _ = try await programService.fetchActiveProgram(userEmail: userEmail)
        } catch {
            print("Error loading program: \(error)")
        }
    }
}

// MARK: - Rest Day Card

struct RestDayCard: View {
    var body: some View {
        HStack {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 18))
                .foregroundColor(.secondary)

            Text("Rest Day")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()
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
                            .foregroundColor(.green)
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

    private var userEmail: String {
        UserDefaults.standard.string(forKey: "userEmail") ?? ""
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
                            }

                            // Exercise list
                            VStack(spacing: 0) {
                                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                                    ProgramExerciseRow(exercise: exercise)

                                    if index < exercises.count - 1 {
                                        Divider()
                                            .padding(.leading, 88)
                                    }
                                }
                            }
                            .background(Color("containerbg"))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
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
                    Text(day.workoutLabel)
                        .font(.system(size: 17, weight: .semibold))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            editedName = day.workoutLabel
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

    private var thumbnailImageName: String {
        String(format: "%04d", exercise.exerciseId)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Exercise thumbnail
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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let sets = exercise.targetSets, let reps = exercise.targetReps {
                    Text("\(sets) sets × \(reps) reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Completion indicator
            Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(exercise.isCompleted ? .green : .secondary.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Create Program View

struct CreateProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var programService = ProgramService.shared

    let userEmail: String

    @State private var programName: String = ""
    @State private var selectedGoal: ProgramFitnessGoal = .hypertrophy
    @State private var selectedType: ProgramType = .upperLower
    @State private var selectedExperience: ProgramExperienceLevel = .intermediate
    @State private var sessionDuration: Int = 60
    @State private var totalWeeks: Int = 6
    @State private var includeDeload: Bool = true
    @State private var isGenerating = false
    @State private var error: String?

    private var canCreate: Bool {
        !programName.trimmingCharacters(in: .whitespaces).isEmpty && !isGenerating
    }

    var body: some View {
        NavigationStack {
            Form {
                // Program Name
                Section {
                    TextField("Program Name", text: $programName)
                }

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
                    Stepper("\(sessionDuration) min per session", value: $sessionDuration, in: 30...120, step: 15)
                    Stepper("\(totalWeeks) weeks", value: $totalWeeks, in: 4...12)
                    Toggle(isOn: $includeDeload) {
                        VStack(alignment: .leading) {
                            Text("Include Deload Week")
                            Text("Recovery week at the end")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Duration")
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

                // Error Message
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
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
                    if isGenerating {
                        ProgressView()
                    } else {
                        Button {
                            Task { await generateProgram() }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .disabled(!canCreate)
                    }
                }
            }
        }
    }

    private func generateProgram() async {
        isGenerating = true
        error = nil

        do {
            _ = try await programService.generateProgram(
                userEmail: userEmail,
                programType: selectedType,
                fitnessGoal: selectedGoal,
                experienceLevel: selectedExperience,
                daysPerWeek: selectedType.daysPerWeek,
                sessionDurationMinutes: sessionDuration,
                totalWeeks: totalWeeks,
                includeDeload: includeDeload
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }
}

#Preview {
    PlanView()
}
