//
//  ProgramService.swift
//  pods
//
//  Created by Dimi Nunez on 1/13/26.
//


//
//  ProgramService.swift
//  pods
//
//  Service for managing training programs and fetching program data.
//

import Foundation
import Combine

@MainActor
class ProgramService: ObservableObject {
    static let shared = ProgramService()

    @Published var activeProgram: TrainingProgram?
    @Published var todayWorkout: TodayWorkoutResponse?
    @Published var isLoading = false
    @Published var error: String?

    private let networkManager = NetworkManagerTwo()

    private init() {}

    // MARK: - Fetch Active Program

    func fetchActiveProgram(userEmail: String) async throws -> TrainingProgram? {
        isLoading = true
        defer { isLoading = false }

        print("[ProgramService] Fetching active program for: \(userEmail)")

        do {
            let program = try await networkManager.fetchActiveProgram(userEmail: userEmail)
            self.activeProgram = program
            if let program = program {
                print("[ProgramService] Successfully loaded program: \(program.name)")
                print("[ProgramService] Program has \(program.weeks?.count ?? 0) weeks")
                if let weeks = program.weeks {
                    for week in weeks {
                        print("[ProgramService] Week \(week.weekNumber) has \(week.days?.count ?? 0) days")
                    }
                }
            } else {
                print("[ProgramService] No active program found")
            }
            return program
        } catch {
            print("[ProgramService ERROR] Failed to fetch active program: \(error)")
            throw error
        }
    }

    // MARK: - Fetch Today's Workout

    func fetchTodayWorkout(userEmail: String) async throws -> TodayWorkoutResponse {
        let response = try await networkManager.fetchTodayWorkout(userEmail: userEmail)
        self.todayWorkout = response
        return response
    }

    // MARK: - Generate Program

    func generateProgram(
        userEmail: String,
        programType: ProgramType,
        fitnessGoal: ProgramFitnessGoal,
        experienceLevel: ProgramExperienceLevel,
        daysPerWeek: Int,
        sessionDurationMinutes: Int,
        startDate: Date? = nil,
        totalWeeks: Int = 6,
        includeDeload: Bool = true,
        availableEquipment: [String]? = nil,
        excludedExercises: [Int]? = nil
    ) async throws -> TrainingProgram {
        isLoading = true
        defer { isLoading = false }

        print("[ProgramService] Generating program for: \(userEmail)")
        print("[ProgramService] Type: \(programType.rawValue), Goal: \(fitnessGoal.rawValue), Level: \(experienceLevel.rawValue)")

        var startDateString: String? = nil
        if let date = startDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            startDateString = formatter.string(from: date)
        }

        let request = GenerateProgramRequest(
            programType: programType.rawValue,
            fitnessGoal: fitnessGoal.rawValue,
            experienceLevel: experienceLevel.rawValue,
            daysPerWeek: daysPerWeek,
            sessionDurationMinutes: sessionDurationMinutes,
            startDate: startDateString,
            totalWeeks: totalWeeks,
            includeDeload: includeDeload,
            availableEquipment: availableEquipment,
            excludedExercises: excludedExercises
        )

        do {
            let program = try await networkManager.generateProgram(userEmail: userEmail, request: request)
            self.activeProgram = program
            print("[ProgramService] Successfully generated program: \(program.name)")
            return program
        } catch {
            print("[ProgramService ERROR] Failed to generate program: \(error)")
            throw error
        }
    }

    // MARK: - Get Program Types

    func getProgramTypes() async throws -> [ProgramTypeInfo] {
        return try await networkManager.fetchProgramTypes()
    }

    // MARK: - Mark Day Complete

    func markDayComplete(dayId: Int, userEmail: String) async throws -> ProgramDay {
        let day = try await networkManager.markProgramDayComplete(dayId: dayId, userEmail: userEmail)

        // Refresh active program to update completion status
        _ = try? await fetchActiveProgram(userEmail: userEmail)

        return day
    }

    // MARK: - Skip Workout

    func skipWorkout(dayId: Int, userEmail: String) async throws -> ProgramDay {
        let day = try await networkManager.skipProgramDayWorkout(dayId: dayId, userEmail: userEmail)

        // Refresh active program to update completion status
        _ = try? await fetchActiveProgram(userEmail: userEmail)

        return day
    }

    // MARK: - Update Workout Name

    func updateWorkoutName(dayId: Int, name: String, userEmail: String) async throws -> ProgramDay {
        let day = try await networkManager.updateProgramDayLabel(dayId: dayId, workoutLabel: name, userEmail: userEmail)

        // Refresh active program to update the name
        _ = try? await fetchActiveProgram(userEmail: userEmail)

        return day
    }

    // MARK: - Update Plan Preferences (MacroFactor-style)

    /// Update plan-level preferences. Future workouts inherit changes.
    /// Does NOT regenerate the plan - just mutates the template.
    func updatePlanPreference(
        userEmail: String,
        fitnessGoal: String? = nil,
        experienceLevel: String? = nil,
        sessionDurationMinutes: Int? = nil,
        warmupEnabled: Bool? = nil,
        cooldownEnabled: Bool? = nil
    ) async throws {
        guard let program = activeProgram else {
            print("[ProgramService] Cannot update preferences: no active program")
            throw ProgramServiceError.programNotFound
        }

        print("[ProgramService] Updating plan preferences for program: \(program.id)")

        // PATCH to backend
        let updatedProgram = try await networkManager.updateProgramPreferences(
            programId: program.id,
            userEmail: userEmail,
            fitnessGoal: fitnessGoal,
            experienceLevel: experienceLevel,
            sessionDurationMinutes: sessionDurationMinutes,
            defaultWarmupEnabled: warmupEnabled,
            defaultCooldownEnabled: cooldownEnabled
        )

        // Update local activeProgram with the response
        self.activeProgram = updatedProgram
        print("[ProgramService] Plan preferences updated successfully")
    }

    // MARK: - Delete Program

    func deleteProgram(id: Int, userEmail: String) async throws {
        try await networkManager.deleteProgram(programId: id, userEmail: userEmail)

        if activeProgram?.id == id {
            activeProgram = nil
        }
    }

    // MARK: - List All Programs

    func listPrograms(userEmail: String) async throws -> [TrainingProgram] {
        return try await networkManager.listPrograms(userEmail: userEmail)
    }

    // MARK: - Activate Program

    func activateProgram(programId: Int, userEmail: String) async throws -> TrainingProgram {
        let program = try await networkManager.activateProgram(programId: programId, userEmail: userEmail)
        self.activeProgram = program

        // Notify WorkoutManager to refresh today's workout with the new active program
        NotificationCenter.default.post(name: .trainingProgramCreated, object: nil)

        return program
    }

    // MARK: - Helper Methods

    func getCurrentWeekDays() -> [ProgramDay]? {
        guard let program = activeProgram,
              let currentWeek = program.currentWeekNumber,
              let weeks = program.weeks,
              let week = weeks.first(where: { $0.weekNumber == currentWeek }) else {
            return nil
        }
        return week.days
    }

    func getTodayProgramDay() -> ProgramDay? {
        guard let days = getCurrentWeekDays() else { return nil }
        return days.first { $0.isToday }
    }

    /// Today's workout from the active program, converted to TodayWorkout format
    /// MacroFactor-style: Returns the NEXT INCOMPLETE workout by cycle_position order
    /// NOT date-based - always finds a workout regardless of calendar date
    var todayProgramWorkout: TodayWorkout? {
        guard let program = activeProgram,
              let weeks = program.weeks else {
            print("🔍 [todayProgramWorkout] No active program or weeks: activeProgram=\(activeProgram != nil), weeks=\(activeProgram?.weeks != nil)")
            return nil
        }

        print("🔍 [todayProgramWorkout] Looking for next incomplete workout (MacroFactor-style). Program=\(program.name)")

        // Collect ALL workout days across all weeks
        var allWorkoutDays: [ProgramDay] = []
        for week in weeks {
            guard let days = week.days else { continue }
            allWorkoutDays.append(contentsOf: days.filter {
                $0.dayType == .workout && $0.cyclePosition != nil
            })
        }

        // Sort by cycle_position
        allWorkoutDays.sort { ($0.cyclePosition ?? 0) < ($1.cyclePosition ?? 0) }

        print("🔍 [todayProgramWorkout] Found \(allWorkoutDays.count) workout days with cycle positions")

        // Find NEXT INCOMPLETE workout
        let targetDay: ProgramDay?
        if let nextIncomplete = allWorkoutDays.first(where: { !$0.isCompleted }) {
            print("🔍 [todayProgramWorkout] Next incomplete: '\(nextIncomplete.workoutLabel)' (cycle_position=\(nextIncomplete.cyclePosition ?? -1))")
            targetDay = nextIncomplete
        } else if let firstWorkout = allWorkoutDays.first {
            // All complete - cycle restarts from position 1
            print("🔍 [todayProgramWorkout] All workouts complete, cycling back to: '\(firstWorkout.workoutLabel)'")
            targetDay = firstWorkout
        } else {
            print("❌ [todayProgramWorkout] No workout days found in program")
            return nil
        }

        // Convert the target day to TodayWorkout
        guard let day = targetDay else { return nil }
        return convertProgramDayToTodayWorkout(day, program: program)
    }

    /// Convert a ProgramDay to TodayWorkout format
    private func convertProgramDayToTodayWorkout(_ day: ProgramDay, program: TrainingProgram) -> TodayWorkout? {
        guard let workoutSession = day.workout,
              let exercises = workoutSession.exercises else {
            print("🔍 [todayProgramWorkout] Day '\(day.workoutLabel)' has no workout session or exercises")
            return nil
        }

        // Convert ProgramExercise to TodayWorkoutExercise
        let todayExercises: [TodayWorkoutExercise] = exercises.compactMap { programExercise in
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
                // Create basic ExerciseData from program exercise
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

        guard !todayExercises.isEmpty else {
            print("🔍 [todayProgramWorkout] Found day but exercises are empty")
            return nil
        }

        // Get fitness goal from program
        let fitnessGoal: FitnessGoal = {
            switch program.fitnessGoal {
            case "hypertrophy": return .hypertrophy
            case "strength": return .strength
            default: return .general
            }
        }()

        print("✅ [todayProgramWorkout] FOUND WORKOUT: '\(day.workoutLabel)' with \(todayExercises.count) exercises, dayId=\(day.id), cyclePosition=\(day.cyclePosition ?? -1)")
        return TodayWorkout(
            id: UUID(),
            date: Date(),
            title: day.workoutLabel,
            exercises: todayExercises,
            blocks: nil,
            estimatedDuration: workoutSession.estimatedDurationMinutes,
            fitnessGoal: fitnessGoal,
            difficulty: 5,
            warmUpExercises: nil,
            coolDownExercises: nil,
            programDayId: day.id
        )
    }

    /// Whether today has a workout scheduled in the active program
    var hasProgramWorkoutToday: Bool {
        todayProgramWorkout != nil
    }

    /// Whether today is a rest day in the active program
    var isProgramRestDayToday: Bool {
        guard let program = activeProgram, let weeks = program.weeks else {
            return false
        }

        for week in weeks {
            guard let days = week.days else { continue }
            for day in days {
                guard let dayDate = day.dateValue,
                      Calendar.current.isDateInToday(dayDate) else {
                    continue
                }
                return day.dayType == .rest
            }
        }
        return false
    }

    func refreshData(userEmail: String) async {
        do {
            _ = try await fetchActiveProgram(userEmail: userEmail)
            _ = try await fetchTodayWorkout(userEmail: userEmail)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Errors

enum ProgramServiceError: LocalizedError {
    case generationFailed
    case programNotFound
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Failed to generate program"
        case .programNotFound:
            return "Program not found"
        case .networkError(let message):
            return message
        }
    }
}
