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
