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
            Text("Loading program...")
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
                Text("No Active Program")
                    .font(.title2.bold())

                Text("Create a structured training program to track your workouts week by week.")
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
                // Program Header
                programHeader(program: program)

                // Week Selector
                weekSelector(program: program)

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

    // MARK: - Program Header

    private func programHeader(program: TrainingProgram) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.name)
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label("\(program.daysPerWeek) days/week", systemImage: "calendar")
                        Label("\(program.sessionDurationMinutes) min", systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Progress indicator
                if let currentWeek = program.currentWeekNumber {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Week \(currentWeek)")
                            .font(.caption.bold())
                        Text("of \(program.totalWeeks)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Goal badge
            HStack(spacing: 8) {
                if let goal = program.fitnessGoalEnum {
                    Text(goal.displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(goalColor(goal).opacity(0.2))
                        .foregroundColor(goalColor(goal))
                        .cornerRadius(6)
                }

                if let type = program.programTypeEnum {
                    Text(type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundColor(.secondary)
                        .cornerRadius(6)
                }
            }
        }
        .padding(16)
        .background(Color("containerbg"))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func goalColor(_ goal: ProgramFitnessGoal) -> Color {
        switch goal {
        case .strength: return .orange
        case .hypertrophy: return .purple
        case .balanced: return .blue
        }
    }

    // MARK: - Week Selector

    private func weekSelector(program: TrainingProgram) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...program.totalWeeks, id: \.self) { weekNum in
                    let isSelected = weekNum == selectedWeekNumber
                    let isCurrent = weekNum == program.currentWeekNumber
                    let isDeload = program.weeks?.first(where: { $0.weekNumber == weekNum })?.isDeload ?? false

                    Button(action: { selectedWeekNumber = weekNum }) {
                        VStack(spacing: 4) {
                            Text("Week \(weekNum)")
                                .font(.caption.bold())

                            if isDeload {
                                Text("Deload")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.blue : Color("containerbg"))
                        .foregroundColor(isSelected ? .white : .primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isCurrent && !isSelected ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
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

                // Exercise count
                if let workout = day.workout, let exercises = workout.exercises {
                    Text("\(exercises.count) exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                                    ProgramExerciseRow(exercise: exercise, index: index + 1)

                                    if index < exercises.count - 1 {
                                        Divider()
                                            .padding(.leading, 56)
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
    }
}

// MARK: - Program Exercise Row

struct ProgramExerciseRow: View {
    let exercise: ProgramExercise
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            // Index number
            Text("\(index)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
                .background(Color("primarybg"))
                .cornerRadius(12)

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

    @State private var selectedType: ProgramType = .upperLower
    @State private var selectedGoal: ProgramFitnessGoal = .hypertrophy
    @State private var selectedExperience: ProgramExperienceLevel = .intermediate
    @State private var sessionDuration: Int = 60
    @State private var totalWeeks: Int = 6
    @State private var includeDeload: Bool = true
    @State private var isGenerating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Program Type") {
                    Picker("Split", selection: $selectedType) {
                        ForEach(ProgramType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Training Goal") {
                    Picker("Goal", selection: $selectedGoal) {
                        ForEach(ProgramFitnessGoal.allCases, id: \.self) { goal in
                            VStack(alignment: .leading) {
                                Text(goal.displayName)
                            }.tag(goal)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Experience Level") {
                    Picker("Level", selection: $selectedExperience) {
                        ForEach(ProgramExperienceLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Duration") {
                    Stepper("\(sessionDuration) minutes per session", value: $sessionDuration, in: 30...120, step: 15)
                    Stepper("\(totalWeeks) weeks", value: $totalWeeks, in: 4...12)
                    Toggle("Include deload week", isOn: $includeDeload)
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await generateProgram() }
                    }
                    .disabled(isGenerating)
                }
            }
            .overlay {
                if isGenerating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Generating program...")
                            .font(.headline)
                    }
                    .padding(24)
                    .background(Color("containerbg"))
                    .cornerRadius(16)
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
