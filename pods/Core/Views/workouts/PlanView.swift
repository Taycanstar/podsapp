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
//  Shows the active program's calendar with week selector and daily workouts.
//

import SwiftUI

struct PlanView: View {
    @ObservedObject private var programService = ProgramService.shared
    @State private var selectedWeekNumber: Int = 1
    @State private var showingCreateProgram = false
    @State private var isRefreshing = false

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
        .sheet(isPresented: $showingCreateProgram) {
            CreateProgramView(userEmail: userEmail)
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

            Button(action: { showingCreateProgram = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Program")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
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

                // Days for selected week
                if let weeks = program.weeks,
                   let selectedWeek = weeks.first(where: { $0.weekNumber == selectedWeekNumber }),
                   let days = selectedWeek.days {
                    VStack(spacing: 8) {
                        ForEach(days) { day in
                            ProgramDayRow(day: day, isToday: day.isToday)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
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
                        .background(isSelected ? Color.blue : Color("primarybg"))
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

// MARK: - Program Day Row

struct ProgramDayRow: View {
    let day: ProgramDay
    let isToday: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Day indicator
            VStack(spacing: 2) {
                Text(day.weekdayShort)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(day.dayOfMonth)
                    .font(.title3.bold())
                    .foregroundColor(isToday ? .blue : .primary)
            }
            .frame(width: 44)

            // Content
            if day.dayType == .workout {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.workoutLabel)
                        .font(.headline)

                    if !day.targetMuscles.isEmpty {
                        Text(day.targetMuscles.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if let workout = day.workout, let exercises = workout.exercises {
                        Text("\(exercises.count) exercises")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Completion indicator
                Image(systemName: day.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(day.isCompleted ? .green : .secondary.opacity(0.3))
            } else {
                Text("Rest Day")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(.secondary.opacity(0.3))
            }
        }
        .padding(12)
        .background(isToday ? Color.blue.opacity(0.08) : Color("containerbg"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isToday ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Create Program View (Placeholder)

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
