//
//  SinglePlanView.swift
//  pods
//
//  Created by Dimi Nunez on 1/16/26.
//

import SwiftUI

struct SinglePlanView: View {
    let program: TrainingProgram

    @Environment(\.dismiss) private var dismiss
    @AppStorage("userEmail") private var userEmail: String = ""

    @State private var selectedDayIndex: Int = 0
    @State private var showSettings = false

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
    private func weeklyDataForExercise(_ exerciseId: Int) -> [WeeklyExerciseData] {
        program.weeks?.compactMap { week in
            guard let day = week.days?.first(where: { $0.workoutLabel == selectedDay?.workoutLabel }),
                  let exercise = day.workout?.exercises?.first(where: { $0.exerciseId == exerciseId }) else {
                return nil
            }
            return WeeklyExerciseData(
                week: week.weekNumber,
                sets: exercise.targetSets ?? 0,
                reps: exercise.targetReps ?? 0
            )
        } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Day picker
            dayPicker
                .padding(.top, 8)
                .padding(.bottom, 16)

            // Content based on selected day
            if let day = selectedDay {
                if day.dayType == .rest {
                    restDayContent
                } else {
                    workoutContent(day: day)
                }
            } else {
                emptyState
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
            PlanSettingsSheet(program: program, userEmail: userEmail)
        }
    }

    // MARK: - Day Picker

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(templateDays.enumerated()), id: \.offset) { index, day in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDayIndex = index
                        }
                    } label: {
                        Text(day.workoutLabel)
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
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Workout Content

    @ViewBuilder
    private func workoutContent(day: ProgramDay) -> some View {
        ScrollView {
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
                                showDivider: index < exercises.count - 1
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    noExercisesState
                }
            }
            .padding(.bottom, 24)
        }
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

    var id: Int { week }
}

// MARK: - Single Plan Exercise Row

private struct SinglePlanExerciseRow: View {
    let exercise: ProgramExercise
    let weeklyData: [WeeklyExerciseData]
    var showDivider: Bool = true

    private var thumbnailImageName: String {
        String(format: "%04d", exercise.exerciseId)
    }

    // Get muscle info from ExerciseDatabase
    private var muscleChips: [String] {
        if let exerciseData = ExerciseDatabase.findExercise(byId: exercise.exerciseId) {
            var muscles: [String] = []
            if !exerciseData.target.isEmpty { muscles.append(exerciseData.target) }
            // Add synergists (split by comma)
            if !exerciseData.synergist.isEmpty {
                muscles.append(contentsOf: exerciseData.synergist.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
            }
            return Array(muscles.prefix(3)) // Max 3 chips
        }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

                // Content: Name, muscle chips, and sets
                VStack(alignment: .leading, spacing: 8) {
                    // Exercise name
                    Text(exercise.exerciseName)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    // Muscle chips (fully rounded, below name)
                    if !muscleChips.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(muscleChips, id: \.self) { muscle in
                                Text(muscle)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color("containerbg"))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    // Sets per week (horizontal scroll with numbered rows)
                    if !weeklyData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(weeklyData) { data in
                                    VStack(alignment: .leading, spacing: 4) {
                                        // Week header
                                        Text("W\(data.week)")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.secondary)

                                        // Numbered set rows
                                        ForEach(1...data.sets, id: \.self) { setNum in
                                            HStack(spacing: 6) {
                                                Text("\(setNum)")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 14, alignment: .leading)
                                                Text("\(data.reps) reps")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.vertical, 12)

            // Divider (starts after thumbnail position)
            if showDivider {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: 62) // 50 thumbnail + 12 spacing
                    Divider()
                }
            }
        }
    }
}

// MARK: - Plan Settings Sheet

private struct PlanSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var programService = ProgramService.shared

    let program: TrainingProgram
    let userEmail: String

    @State private var planName: String
    @State private var selectedGoal: ProgramFitnessGoal
    @State private var selectedExperience: ProgramExperienceLevel
    @State private var sessionDuration: Int
    @State private var warmupEnabled: Bool
    @State private var cooldownEnabled: Bool
    @State private var isSaving = false
    @State private var showRegenerateConfirmation = false
    @State private var error: String?

    init(program: TrainingProgram, userEmail: String) {
        self.program = program
        self.userEmail = userEmail
        _planName = State(initialValue: program.name)
        _selectedGoal = State(initialValue: ProgramFitnessGoal(rawValue: program.fitnessGoal) ?? .hypertrophy)
        _selectedExperience = State(initialValue: ProgramExperienceLevel(rawValue: program.experienceLevel) ?? .intermediate)
        _sessionDuration = State(initialValue: program.sessionDurationMinutes)
        _warmupEnabled = State(initialValue: program.defaultWarmupEnabled ?? false)
        _cooldownEnabled = State(initialValue: program.defaultCooldownEnabled ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Plan Name
                Section("Plan Name") {
                    TextField("Name", text: $planName)
                }

                // Training Preferences
                Section("Training Preferences") {
                    Picker("Goal", selection: $selectedGoal) {
                        ForEach(ProgramFitnessGoal.allCases, id: \.self) { goal in
                            Text(goal.displayName).tag(goal)
                        }
                    }

                    Picker("Experience", selection: $selectedExperience) {
                        ForEach(ProgramExperienceLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }

                    Stepper("Duration: \(sessionDuration) min", value: $sessionDuration, in: 30...120, step: 15)
                }

                // Flexibility
                Section("Flexibility") {
                    Toggle("Warm-Up", isOn: $warmupEnabled)
                    Toggle("Cool-Down", isOn: $cooldownEnabled)
                }

                // Regenerate Plan (danger zone)
                Section {
                    Button(role: .destructive) {
                        showRegenerateConfirmation = true
                    } label: {
                        Label("Regenerate Plan", systemImage: "arrow.triangle.2.circlepath")
                    }
                } footer: {
                    Text("This will create a new plan with fresh exercises based on your preferences. Your current progress will be lost.")
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { saveSettings() }
                    }
                }
            }
            .alert("Regenerate Plan?", isPresented: $showRegenerateConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Regenerate", role: .destructive) {
                    regeneratePlan()
                }
            } message: {
                Text("This will create a new plan with fresh exercises. Your current progress will be lost.")
            }
        }
    }

    private func saveSettings() {
        isSaving = true
        error = nil

        Task {
            do {
                try await programService.updatePlanPreference(
                    userEmail: userEmail,
                    fitnessGoal: selectedGoal.rawValue,
                    experienceLevel: selectedExperience.rawValue,
                    sessionDurationMinutes: sessionDuration,
                    warmupEnabled: warmupEnabled,
                    cooldownEnabled: cooldownEnabled
                )
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func regeneratePlan() {
        // TODO: Implement plan regeneration
        // This would call a new API to regenerate the plan with current settings
        print("Regenerate plan requested")
    }
}

#Preview {
    NavigationStack {
        SinglePlanView(program: TrainingProgram(
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
            isActive: true,
            createdAt: "2026-01-01",
            syncVersion: 1,
            weeks: nil
        ))
    }
}
