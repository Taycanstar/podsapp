//
//  NetworkManagerTwo.swift
//  Pods
//
//  Created by Dimi Nunez on 5/22/25.
//

import Foundation
import SwiftUI

struct GoalOverridePayload {
    var min: Double?
    var target: Double?
    var max: Double?

    var dictionary: [String: Double] {
        var payload: [String: Double] = [:]
        if let min { payload["min"] = min }
        if let target { payload["target"] = target }
        if let max { payload["max"] = max }
        return payload
    }
}

class NetworkManagerTwo {
    // Shared instance (singleton)
    static let shared = NetworkManagerTwo()

    private let iso8601BasicFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    
    let baseUrl = APIBaseURL.current

    // Network errors - scoped to NetworkManagerTwo
    enum NetworkError: LocalizedError {
        case invalidURL
        case requestFailed(statusCode: Int)
        case invalidResponse
        case decodingError
        case serverError(message: String)
        case featureLimitExceeded(message: String)
        // Add any other specific error cases you might need
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .requestFailed(let statusCode): return "Request failed with status code: \(statusCode)"
            case .invalidResponse: return "Invalid response from server"
            case .decodingError: return "Failed to decode response"
            case .serverError(let message): return message // Use the message directly
            case .featureLimitExceeded(let message): return message
            }
        }
    }

    struct ErrorResponse: Codable {
        let error: String
    }

    struct WorkoutProfilesResponse: Decodable {
        let profiles: [WorkoutProfile]
        let activeProfileId: Int?
        let supportsMultipleWorkoutProfiles: Bool?

        enum CodingKeys: String, CodingKey {
            case profiles
            case activeProfileId = "active_profile_id"
            case supportsMultipleWorkoutProfiles = "supports_multiple_workout_profiles"
        }
    }

    struct CreateWorkoutProfileResponse: Decodable {
        let profile: WorkoutProfile
        let profiles: [WorkoutProfile]
        let activeProfileId: Int?
        let supportsMultipleWorkoutProfiles: Bool?

        enum CodingKeys: String, CodingKey {
            case profile
            case profiles
            case activeProfileId = "active_profile_id"
            case supportsMultipleWorkoutProfiles = "supports_multiple_workout_profiles"
        }
    }

    struct ActivateWorkoutProfileResponse: Decodable {
        let success: Bool
        let profiles: [WorkoutProfile]
        let activeProfileId: Int?
        let supportsMultipleWorkoutProfiles: Bool?

        enum CodingKeys: String, CodingKey {
            case success
            case profiles
            case activeProfileId = "active_profile_id"
            case supportsMultipleWorkoutProfiles = "supports_multiple_workout_profiles"
        }
    }

    struct WorkoutListResponse: Codable {
        let workouts: [WorkoutResponse.Workout]
    }

    struct WorkoutDetailResponse: Codable {
        let workout: WorkoutResponse.Workout
    }

    struct DeleteWorkoutExerciseResponse: Codable {
        struct Summary: Codable {
            let durationSeconds: Int
            let durationMinutes: Int?
            let volumeKg: Double
            let calories: Int
            let exercisesCount: Int
        }

        let workout: WorkoutResponse.Workout
        let combinedLog: CombinedLog
        let summary: Summary
    }

    struct ExerciseHistoryResponse: Codable {
        struct Session: Codable {
            let workoutSessionId: Int
            let exerciseInstanceId: Int
            let exerciseId: Int
            let exerciseName: String
            let trackingType: String?
            let scheduledDate: Date?
            let startedAt: Date?
            let completedAt: Date?
            let status: String?
            let title: String?
            let sets: [ExerciseSet]
        }

        struct ExerciseSet: Codable {
            let id: Int
            let setNumber: Int
            let trackingType: String?
            let weightKg: Double?
            let reps: Int?
            let durationSeconds: Int?
            let distanceMeters: Double?
            let distanceUnit: String?
            let isWarmup: Bool
            let isCompleted: Bool
            let completedAt: Date?
            let notes: String?
        }

        let sessions: [Session]
    }

    struct ProcessScheduledMealResponse: Codable {
        let status: String
        let action: String
        let scheduleType: String
        let nextTargetDate: Date?
        let nextTargetTime: String?
        let isActive: Bool
        let logType: String?
        let loggedLogId: Int?

        enum CodingKeys: String, CodingKey {
            case status
            case action
            case scheduleType = "schedule_type"
            case nextTargetDate = "next_target_date"
            case nextTargetTime = "next_target_time"
            case isActive = "is_active"
            case logType = "log_type"
            case loggedLogId = "logged_log_id"
        }
    }

    struct OuraStatusResponse: Codable {
        let connected: Bool
        let lastSyncedAt: String?
        let ouraUserId: String?
        let scopes: String?

        enum CodingKeys: String, CodingKey {
            case connected
            case lastSyncedAt = "last_synced_at"
            case ouraUserId = "oura_user_id"
            case scopes
        }
    }

    private struct OuraAuthResponse: Codable {
        let authorizationUrl: String

        enum CodingKeys: String, CodingKey {
            case authorizationUrl = "authorization_url"
        }
    }

    struct ExpenditureSnapshot: Codable, Identifiable, Equatable {
        let date: String
        let tdeeCore: Double?
        let tdeeDisplay: Double?
        let impliedExpenditure: Double?
        let caloriesLogged: Double?
        let weightKg: Double?
        let trendWeightKg: Double?
        let loggingQuality: Double?
        let steps: Double?
        let sleepMinutes: Double?
        let hrvScore: Double?
        let activityOverlay: Double?
        let observationNoise: Double?
        let processNoise: Double?
        let notes: [String: Bool]?
        let updatedAt: String?

        var id: String { date }

        var dateValue: Date? {
            ExpenditureSnapshot.dateFormatter.date(from: date)
        }

        var updatedAtValue: Date? {
            guard let updatedAt else { return nil }
            return ExpenditureSnapshot.updatedFormatter.date(from: updatedAt)
        }

        // Parse date as local timezone since the API returns dates in user's local context
        // Using UTC would cause off-by-one errors for users behind UTC
        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = .current  // Use local timezone, not UTC
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()

        private static let updatedFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()
    }

    struct HealthMetricComponents: Codable, Equatable {
        let readiness: [String: Double]?
        let sleep: [String: Double]?
        let activity: [String: Double]?
        let stress: [String: Double]?
    }

    struct HealthMetricRawMetrics: Codable, Equatable {
        struct SleepStageMinutes: Codable, Equatable {
            let deep: Double?
            let rem: Double?
            let core: Double?
            let awake: Double?
        }

        let hrv: Double?
        let hrvShortTerm: Double?
        let hrvBaseline: Double?
        let restingHeartRate: Double?
        let sleepHours: Double?
        let sleepScore: Double?
        let steps: Double?
        let caloriesBurned: Double?
        let respiratoryRate: Double?
        let respiratoryRatePrevious: Double?
        let skinTemperatureC: Double?
        let skinTemperaturePrevious: Double?
        let sleepLatencyMinutes: Double?
        let sleepMidpointMinutes: Double?
        let sleepNeedHours: Double?
        let strainRatio: Double?
        let totalSleepMinutes: Double?
        let sleepStageMinutes: SleepStageMinutes?
        let inBedMinutes: Double?
        let sleepEfficiency: Double?
        let sleepSource: String?
        let fallbackSleepDate: String?
        // Hypnogram: each char = 5 min, 1=deep, 2=light, 3=REM, 4=awake
        let hypnogram: String?
        // Cumulative sleep debt over past 14 days (in minutes)
        let cumulativeSleepDebtMinutes: Double?
        // Sleep onset/offset times (ISO8601 datetime strings)
        let sleepOnset: String?
        let sleepOffset: String?
        // Activity zone minutes (from Oura daily_activity)
        let highActivityMinutes: Double?
        let mediumActivityMinutes: Double?
        let lowActivityMinutes: Double?
        let sedentaryMinutes: Double?
        // Total daily calories (active + BMR)
        let totalCalories: Double?
        // Activity contributors (Oura scores 0-100)
        let activityContributors: ActivityContributors?
        // MET zone minutes (from Oura class_5_min - zones 0-5)
        let metZoneMinutes: MetZoneMinutes?
        // HR zone minutes (calculated from raw HR samples using Oura's methodology)
        let hrZoneMinutes: HRZoneMinutes?
    }

    struct ActivityContributors: Codable, Equatable {
        let stayActive: Double?
        let moveEveryHour: Double?
        let meetDailyTargets: Double?
        let trainingFrequency: Double?
        let trainingVolume: Double?
        let recoveryTime: Double?
    }

    struct MetZoneMinutes: Codable, Equatable {
        // Note: Backend sends zone_0, zone_1, etc.
        // With keyDecodingStrategy = .convertFromSnakeCase, these become zone0, zone1, etc.
        // DO NOT add custom CodingKeys - it conflicts with the automatic conversion
        let zone0: Int?
        let zone1: Int?
        let zone2: Int?
        let zone3: Int?
        let zone4: Int?
        let zone5: Int?
    }

    // HR zone minutes (calculated from raw HR samples using Oura's methodology)
    // Zone thresholds based on % of max HR (220-age):
    // Zone 0: ≤49%, Zone 1: 50-59%, Zone 2: 60-69%, Zone 3: 70-79%, Zone 4: 80-89%, Zone 5: 90-100%
    struct HRZoneMinutes: Codable, Equatable {
        let zone0: Int?
        let zone1: Int?
        let zone2: Int?
        let zone3: Int?
        let zone4: Int?
        let zone5: Int?
    }

    struct HealthMetricsSnapshot: Codable, Equatable {
        let date: String
        let readiness: Double?
        let sleep: Double?
        let activity: Double?
        let stress: Double?
        let confidence: String?
        let isEmpty: Bool?
        let scoreSource: String?
        let sourceScores: [String: Double]?
        let sleepSourceDate: String?
        let components: HealthMetricComponents?
        let rawMetrics: HealthMetricRawMetrics?

        var dateValue: Date? {
            HealthMetricsSnapshot.dateFormatter.date(from: date)
        }

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()
    }

    // MARK: - Vital Metric History

    struct VitalHistoryDataPoint: Codable {
        let date: String
        let value: Double?

        var dateValue: Date? {
            VitalHistoryDataPoint.dateFormatter.date(from: date)
        }

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()
    }

    struct VitalHistoryResponse: Codable {
        let metric: String
        let days: [VitalHistoryDataPoint]
        let count: Int
        let average: Double?
        let min: Double?
        let max: Double?
    }

    struct ExpenditureState: Codable {
        let tdeeEstimate: Double?
        let stateVariance: Double?
        let trendWeightKg: Double?
        let rollingIntakeAvg: Double?
        let baselineSteps: Double?
        let baselineSleepMinutes: Double?
        let baselineHrv: Double?
        let loggingQuality: Double?
        let lastActivityOverlay: Double?
        let lastObservationDate: String?
        let updatedAt: String?
    }

    struct ExpenditureSummaryResponse: Codable {
        let summary: ExpenditureSnapshot
        let state: ExpenditureState?
    }

    struct ExpenditureHistoryResponse: Codable {
        let days: [ExpenditureSnapshot]
        let count: Int
    }

    struct WorkoutResponse: Codable {
        struct Workout: Codable {
            let id: Int
            let userEmail: String
            let name: String
            let status: String?
            let isTemplate: Bool?
            let startedAt: Date?
            let completedAt: Date?
            let scheduledDate: Date?
            let estimatedDurationMinutes: Int?
            let actualDurationMinutes: Int?
            let notes: String?
            let createdAt: Date?
            let updatedAt: Date?
            let syncVersion: Int?
            let exercises: [Exercise]
        }

        struct Exercise: Codable {
            let id: Int
            let exerciseId: Int
            let exerciseName: String
            let orderIndex: Int?
            let notes: String?
            let isCompleted: Bool?
            let targetSets: Int?
            let sets: [ExerciseSet]
        }

        struct ExerciseSet: Codable {
            let id: Int
            let setNumber: Int?
            let trackingType: String?
            let weightKg: Double?
            let reps: Int?
            let durationSeconds: Int?
            let restSeconds: Int?
            let distanceMeters: Double?
            let distanceUnit: String?
            let paceSecondsPerKm: Int?
            let rpe: Int?
            let heartRateBpm: Int?
            let intensityZone: Int?
            let stretchIntensity: Int?
            let rangeOfMotionNotes: String?
            let roundsCompleted: Int?
            let isWarmup: Bool?
            let isCompleted: Bool?
            let notes: String?
        }
    }

    struct LLMCandidateExercise: Codable {
        let exerciseId: Int
        let name: String
    }

    struct LLMSessionBudget: Codable {
        let format: String
        let densityHint: String
        let durationMinutes: Int
        let availableWorkSeconds: Int
        let maxWorkSeconds: Int
        let warmupSeconds: Int
        let cooldownSeconds: Int
        let bufferSeconds: Int
    }

    struct LLMWorkoutRequest: Codable {
        let userEmail: String
        let context: WorkoutContextV1
        let candidates: [LLMCandidateExercise]
        let targetExerciseCount: Int
        let sessionBudget: LLMSessionBudget?
        let requestId: UUID
    }

    struct LLMWorkoutResponse: Codable {
        struct Exercise: Codable {
            let exerciseId: Int
            let muscleGroup: String
            let sets: Int
            let reps: Int
            let weight: Double?
            let restSeconds: Int?
        }

        let exercises: [Exercise]
        let warmupMinutes: Int?
        let cooldownMinutes: Int?
        let rationale: String?
        let warnings: [String]?
    }

    struct WorkoutRequest: Codable {
        struct Exercise: Codable {
            let exerciseId: Int
            let exerciseName: String
            let orderIndex: Int
            let targetSets: Int
            let isCompleted: Bool
            let sets: [ExerciseSet]
        }

        struct ExerciseSet: Codable {
            let trackingType: String?
            let weightKg: Double?
            let reps: Int?
            let durationSeconds: Int?
            let restSeconds: Int?
            let distanceMeters: Double?
            let distanceUnit: String?
            let paceSecondsPerKm: Int?
            let rpe: Int?
            let heartRateBpm: Int?
            let intensityZone: Int?
            let stretchIntensity: Int?
            let rangeOfMotionNotes: String?
            let roundsCompleted: Int?
            let isWarmup: Bool
            let isCompleted: Bool
            let notes: String?
        }

        let userEmail: String
        let name: String
        let status: String
        let isTemplate: Bool?
        let startedAt: String
        let completedAt: String?
        let scheduledDate: String
        let estimatedDurationMinutes: Int
        let actualDurationMinutes: Int?
        let notes: String?
        let exercises: [Exercise]
    }
    
    struct UsernameEligibilityResponse: Codable {
        let canChangeUsername: Bool
        let daysRemaining: Int
        let currentUsername: String
        let lastChanged: String?
        
        enum CodingKeys: String, CodingKey {
            case canChangeUsername = "can_change_username"
            case daysRemaining = "days_remaining"
            case currentUsername = "current_username"
            case lastChanged = "last_changed"
        }
    }
    
    struct UsernameAvailabilityResponse: Codable {
        let available: Bool
        let username: String?
        let error: String?
    }
    
    struct NameEligibilityResponse: Codable {
        let canChangeName: Bool
        let daysRemaining: Int
        let currentName: String
        let lastChanged: String?
        
        enum CodingKeys: String, CodingKey {
            case canChangeName = "can_change_name"
            case daysRemaining = "days_remaining"
            case currentName = "current_name"
            case lastChanged = "last_changed"
        }
    }
    
    // MARK: - Workout Sync API

    func fetchServerWorkouts(userEmail: String, pageSize: Int = 200, isTemplateOnly: Bool? = nil, daysBack: Int? = nil) async throws -> WorkoutListResponse {
        var components = URLComponents(string: "\(baseUrl)/get-user-workouts/")
        components?.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]

        if let isTemplateOnly = isTemplateOnly {
            components?.queryItems?.append(URLQueryItem(name: "is_template", value: isTemplateOnly ? "true" : "false"))
        }

        if let daysBack = daysBack {
            components?.queryItems?.append(URLQueryItem(name: "days_back", value: "\(daysBack)"))
        }

        guard let url = components?.url else { throw NetworkError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = self.iso8601FractionalFormatter.date(from: value) ?? self.iso8601BasicFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
        return try decoder.decode(WorkoutListResponse.self, from: data)
    }

    func fetchExerciseHistory(userEmail: String, exerciseId: Int, daysBack: Int) async throws -> ExerciseHistoryResponse {
        var components = URLComponents(string: "\(baseUrl)/get-exercise-history/")
        var queryItems = [
            URLQueryItem(name: "user_email", value: userEmail),
            URLQueryItem(name: "exercise_id", value: "\(exerciseId)"),
            URLQueryItem(name: "days_back", value: "\(max(1, daysBack))")
        ]
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        queryItems.append(URLQueryItem(name: "tz_offset_minutes", value: "\(offsetMinutes)"))
        components?.queryItems = queryItems

        guard let url = components?.url else { throw NetworkError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = self.iso8601FractionalFormatter.date(from: value) ?? self.iso8601BasicFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }

        return try decoder.decode(ExerciseHistoryResponse.self, from: data)
    }

    func fetchWorkoutDetail(sessionId: Int, userEmail: String) async throws -> WorkoutResponse.Workout {
        var components = URLComponents(string: "\(baseUrl)/get-workout-session/\(sessionId)/")
        components?.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail)
        ]

        guard let url = components?.url else { throw NetworkError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = self.iso8601FractionalFormatter.date(from: value) ?? self.iso8601BasicFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }

        let responsePayload = try decoder.decode(WorkoutDetailResponse.self, from: data)
        return responsePayload.workout
    }

    func createWorkout(payload: WorkoutRequest) async throws -> WorkoutResponse.Workout {
        guard let url = URL(string: "\(baseUrl)/create-workout-session/") else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = self.iso8601FractionalFormatter.date(from: value) ?? self.iso8601BasicFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
        return try decoder.decode(WorkoutResponse.Workout.self, from: data)
    }

    func updateWorkout(sessionId: Int, payload: WorkoutRequest) async throws -> WorkoutResponse.Workout {
        guard let url = URL(string: "\(baseUrl)/update-workout-session/\(sessionId)/") else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = self.iso8601FractionalFormatter.date(from: value) ?? self.iso8601BasicFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
        return try decoder.decode(WorkoutResponse.Workout.self, from: data)
    }

    func deleteWorkout(sessionId: Int, userEmail: String) async throws {
        guard let url = URL(string: "\(baseUrl)/delete-workout-session/\(sessionId)/") else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["user_email": userEmail]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: nil)
    }

    func deleteWorkoutExercise(sessionId: Int, exerciseId: Int, userEmail: String) async throws -> DeleteWorkoutExerciseResponse {
        guard let url = URL(string: "\(baseUrl)/delete-workout-exercise/\(sessionId)/\(exerciseId)/") else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["user_email": userEmail]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = self.iso8601FractionalFormatter.date(from: value) ?? self.iso8601BasicFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }

        return try decoder.decode(DeleteWorkoutExerciseResponse.self, from: data)
    }

    func generateLLMWorkoutPlan(request: LLMWorkoutRequest, completion: @escaping (Result<LLMWorkoutResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/ai/workouts/generate/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase

        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let response = response else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            do {
                try self.validate(response: response, data: data)
            } catch {
                completion(.failure(error))
                return
            }

            guard let data else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            do {
                let payload = try decoder.decode(LLMWorkoutResponse.self, from: data)
                completion(.success(payload))
            } catch {
                completion(.failure(NetworkError.decodingError))
            }
        }.resume()
    }

    private func validate(response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            if let data,
               let json = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(message: json.error)
            }
            throw NetworkError.requestFailed(statusCode: http.statusCode)
        }
    }

    // MARK: - Workout Preferences
    /// Update user's workout preferences on the server. Only non-nil fields are sent.
    func updateWorkoutPreferences(
        userEmail: String,
        workoutDaysPerWeek: Int? = nil,
        restDays: [String]? = nil,
        profileId: Int? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/update-workout-preferences/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL)); return
        }

        var payload: [String: Any] = ["email": userEmail]
        if let workoutDaysPerWeek = workoutDaysPerWeek { payload["workout_days_per_week"] = workoutDaysPerWeek }
        if let restDays = restDays { payload["rest_days"] = restDays }
        if let profileId = profileId ?? UserProfileService.shared.activeWorkoutProfile?.id {
            payload["profile_id"] = profileId
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error)); return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }; return
            }
            guard (200...299).contains(http.statusCode) else {
                // Try to read error message
                if let data = data,
                   let json = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: json.error))) }
                } else {
                    DispatchQueue.main.async { completion(.failure(NetworkError.requestFailed(statusCode: http.statusCode))) }
                }
                return
            }
            DispatchQueue.main.async { completion(.success(())) }
        }.resume()
    }
    

    func lookupFoodByBarcode(
        barcode: String,
        userEmail: String,
        imageData: String? = nil,
        mealType: String = "Lunch",
        shouldLog: Bool = false,
        date: String? = nil,
        useNutritionixOnly: Bool = true,
        completion: @escaping (Result<BarcodeLookupResponse, Error>) -> Void
    ) {
        let endpoint = useNutritionixOnly ? "/lookup_food_by_barcode_nutritionix/" : "/lookup_food_by_barcode/"
        let urlString = "\(baseUrl)\(endpoint)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Create request body
        let tzOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
        var parameters: [String: Any] = [
            "user_email": userEmail,
            "barcode": barcode,
            "meal_type": mealType,
            "should_log": shouldLog,
            "timezone_offset_minutes": tzOffsetMinutes
        ]
        if let date = date { parameters["date"] = date }
        
        // Add optional image data if available
        if let imageData = imageData {
            parameters["image_data"] = imageData
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(message: errorMessage)))
                    }
                    return
                }

                if let response = Self.makeFallbackBarcodeResponse(from: json) {
                    DispatchQueue.main.async {
                        completion(.success(response))
                    }
                    return
                }
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BarcodeLookupResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    func fetchExpenditureSummary(
        userEmail: String,
        forceRecompute: Bool = false,
        timezoneOffsetMinutes: Int? = nil,
        completion: @escaping (Result<ExpenditureSummaryResponse, Error>) -> Void
    ) {
        guard var components = URLComponents(string: "\(baseUrl)/expenditure/summary/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        var queryItems = [URLQueryItem(name: "user_email", value: userEmail)]
        if forceRecompute {
            queryItems.append(URLQueryItem(name: "force_recompute", value: "true"))
        }
        if let offset = timezoneOffsetMinutes {
            queryItems.append(URLQueryItem(name: "timezone_offset", value: "\(offset)"))
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            guard (200 ... 299).contains(http.statusCode) else {
                DispatchQueue.main.async { completion(.failure(NetworkError.requestFailed(statusCode: http.statusCode))) }
                return
            }
            guard let data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let payload = try decoder.decode(ExpenditureSummaryResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(payload)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(NetworkError.decodingError)) }
            }
        }.resume()
    }

    func fetchExpenditureHistory(
        userEmail: String,
        days: Int = 30,
        timezoneOffsetMinutes: Int? = nil,
        completion: @escaping (Result<ExpenditureHistoryResponse, Error>) -> Void
    ) {
        guard var components = URLComponents(string: "\(baseUrl)/expenditure/history/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        var items = [
            URLQueryItem(name: "user_email", value: userEmail),
            URLQueryItem(name: "days", value: "\(days)")
        ]
        if let offset = timezoneOffsetMinutes {
            items.append(URLQueryItem(name: "timezone_offset", value: "\(offset)"))
        }
        components.queryItems = items
        guard let url = components.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            guard (200 ... 299).contains(http.statusCode) else {
                DispatchQueue.main.async { completion(.failure(NetworkError.requestFailed(statusCode: http.statusCode))) }
                return
            }
            guard let data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let payload = try decoder.decode(ExpenditureHistoryResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(payload)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(NetworkError.decodingError)) }
            }
        }.resume()
    }

    func fetchHealthMetrics(
        userEmail: String,
        timezoneOffsetMinutes: Int? = nil,
        targetDate: Date? = nil,
        completion: @escaping (Result<HealthMetricsSnapshot, Error>) -> Void
    ) {
        guard var components = URLComponents(string: "\(baseUrl)/health-metrics/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        var items = [URLQueryItem(name: "user_email", value: userEmail)]
        if let offset = timezoneOffsetMinutes {
            items.append(URLQueryItem(name: "timezone_offset", value: "\(offset)"))
        }
        if let targetDate {
            items.append(URLQueryItem(name: "target_date", value: Self.isoDayFormatter.string(from: targetDate)))
        }
        components.queryItems = items
        guard let url = components.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            guard (200 ... 299).contains(http.statusCode) else {
                DispatchQueue.main.async { completion(.failure(NetworkError.requestFailed(statusCode: http.statusCode))) }
                return
            }
            guard let data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let snapshot = try decoder.decode(HealthMetricsSnapshot.self, from: data)
                DispatchQueue.main.async { completion(.success(snapshot)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(NetworkError.decodingError)) }
            }
        }.resume()
    }

    // MARK: - Vital Metric History

    func fetchVitalMetricHistory(
        userEmail: String,
        metric: String,
        days: Int,
        completion: @escaping (Result<VitalHistoryResponse, Error>) -> Void
    ) {
        guard var components = URLComponents(string: "\(baseUrl)/health-metrics/history/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        components.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail),
            URLQueryItem(name: "metric", value: metric),
            URLQueryItem(name: "days", value: "\(days)")
        ]
        guard let url = components.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            guard (200 ... 299).contains(http.statusCode) else {
                DispatchQueue.main.async { completion(.failure(NetworkError.requestFailed(statusCode: http.statusCode))) }
                return
            }
            guard let data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let history = try decoder.decode(VitalHistoryResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(history)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(NetworkError.decodingError)) }
            }
        }.resume()
    }

    // MARK: - Readiness Summary

    struct ReadinessSummaryResponse: Codable {
        let summary: String
        let date: String
    }

    struct SleepSummaryResponse: Codable {
        let summary: String
        let date: String
    }

    struct ActivitySummaryResponse: Codable {
        let summary: String
        let date: String
    }

    func fetchReadinessSummary(
        userEmail: String,
        targetDate: Date,
        completion: @escaping (Result<ReadinessSummaryResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/agent/readiness-summary/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let dateString = Self.isoDayFormatter.string(from: targetDate)
        let body: [String: Any] = [
            "user_email": userEmail,
            "target_date": dateString
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            guard (200...299).contains(http.statusCode), let data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: "Server error: \(http.statusCode)"))) }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let response = try decoder.decode(ReadinessSummaryResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(response)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(NetworkError.decodingError)) }
            }
        }.resume()
    }

    func fetchSleepSummary(
        userEmail: String,
        targetDate: Date,
        completion: @escaping (Result<SleepSummaryResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/agent/sleep-summary/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let dateString = Self.isoDayFormatter.string(from: targetDate)
        let body: [String: Any] = [
            "user_email": userEmail,
            "target_date": dateString
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            guard (200...299).contains(http.statusCode), let data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: "Server error: \(http.statusCode)"))) }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let response = try decoder.decode(SleepSummaryResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(response)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(NetworkError.decodingError)) }
            }
        }.resume()
    }

    func fetchActivitySummary(
        userEmail: String,
        targetDate: Date,
        completion: @escaping (Result<ActivitySummaryResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/agent/activity-summary/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let dateString = Self.isoDayFormatter.string(from: targetDate)
        let body: [String: Any] = [
            "user_email": userEmail,
            "target_date": dateString
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            guard (200...299).contains(http.statusCode), let data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: "Server error: \(http.statusCode)"))) }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let response = try decoder.decode(ActivitySummaryResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(response)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(NetworkError.decodingError)) }
            }
        }.resume()
    }

    // MARK: - Weekly Activity

    struct WeeklyActivityDay: Codable, Equatable {
        let date: String
        let dayOfWeek: String
        let activityScore: Double?
        let steps: Double?
        let totalCalories: Double?
        let caloriesBurned: Double?
        let metZoneMinutes: MetZoneMinutes?
        let hrZoneMinutes: HRZoneMinutes?
        let totalActiveMinutes: Int?
    }

    struct WeeklyActivityResponse: Codable {
        let days: [WeeklyActivityDay]
    }

    func fetchWeeklyActivity(
        userEmail: String,
        timezoneOffsetMinutes: Int? = nil,
        targetDate: Date? = nil,
        completion: @escaping (Result<[WeeklyActivityDay], Error>) -> Void
    ) {
        guard var components = URLComponents(string: "\(baseUrl)/weekly-activity/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        var items = [URLQueryItem(name: "user_email", value: userEmail)]
        if let offset = timezoneOffsetMinutes {
            items.append(URLQueryItem(name: "timezone_offset", value: "\(offset)"))
        }
        if let targetDate {
            items.append(URLQueryItem(name: "target_date", value: Self.isoDayFormatter.string(from: targetDate)))
        }
        components.queryItems = items
        guard let url = components.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            guard (200...299).contains(http.statusCode), let data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: "Server error: \(http.statusCode)"))) }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let response = try decoder.decode(WeeklyActivityResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(response.days)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(NetworkError.decodingError)) }
            }
        }.resume()
    }

    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current  // Use device's local timezone, not UTC
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func makeFallbackBarcodeResponse(from json: [String: Any]) -> BarcodeLookupResponse? {
        guard let foodDict = json["food"] as? [String: Any] else { return nil }
        guard let food = makeFood(from: foodDict) else { return nil }
        let foodLogId = (json["food_log_id"] as? Int) ?? (json["foodLogId"] as? Int)
        return BarcodeLookupResponse(food: food, foodLogId: foodLogId)
    }

    private static func makeFood(from dict: [String: Any]) -> Food? {
        guard let fdcId = dict["fdcId"] as? Int,
              let description = dict["description"] as? String else { return nil }

        let servingSize = doubleValue(dict["servingSize"]) ?? (dict["serving_size"] as? Double)
        let servingWeightGrams = doubleValue(dict["servingWeightGrams"]) ?? doubleValue(dict["serving_weight_grams"])
        let numberOfServings = doubleValue(dict["numberOfServings"]) ?? (dict["number_of_servings"] as? Double)
        let nutrients = ((dict["foodNutrients"] as? [[String: Any]]) ?? []).compactMap { makeNutrient(from: $0) }
        let measures = ((dict["foodMeasures"] as? [[String: Any]]) ?? []).compactMap { makeMeasure(from: $0) }

        var food = Food(
            fdcId: fdcId,
            description: description,
            brandOwner: dict["brandOwner"] as? String,
            brandName: dict["brandName"] as? String,
            servingSize: servingSize,
            servingWeightGrams: servingWeightGrams,
            numberOfServings: numberOfServings,
            servingSizeUnit: dict["servingSizeUnit"] as? String,
            householdServingFullText: dict["householdServingFullText"] as? String,
            foodNutrients: nutrients.isEmpty ? defaultNutrients(from: dict) : nutrients,
            foodMeasures: measures,
            healthAnalysis: nil,
            aiInsight: dict["ai_insight"] as? String,
            nutritionScore: doubleValue(dict["nutrition_score"])
        )
        if let mealItemsArray = dict["meal_items"] as? [[String: Any]] ?? dict["mealItems"] as? [[String: Any]],
           let data = try? JSONSerialization.data(withJSONObject: mealItemsArray),
           let decoded = try? JSONDecoder().decode([MealItem].self, from: data) {
            food.mealItems = decoded
        }
        return food
    }

    private static func defaultNutrients(from dict: [String: Any]) -> [Nutrient] {
        var nutrients: [Nutrient] = []
        if let calories = doubleValue(dict["calories"]) {
            nutrients.append(Nutrient(nutrientName: "Energy", value: calories, unitName: "kcal"))
        }
        if let protein = doubleValue(dict["protein"]) {
            nutrients.append(Nutrient(nutrientName: "Protein", value: protein, unitName: "g"))
        }
        if let carbs = doubleValue(dict["carbs"]) {
            nutrients.append(Nutrient(nutrientName: "Carbohydrate, by difference", value: carbs, unitName: "g"))
        }
        if let fat = doubleValue(dict["fat"]) {
            nutrients.append(Nutrient(nutrientName: "Total lipid (fat)", value: fat, unitName: "g"))
        }
        return nutrients
    }

    private static func makeNutrient(from dict: [String: Any]) -> Nutrient? {
        guard let name = dict["nutrientName"] as? String,
              let unit = dict["unitName"] as? String,
              let value = doubleValue(dict["value"]) else { return nil }
        return Nutrient(nutrientName: name, value: value, unitName: unit)
    }

    private static func makeMeasure(from dict: [String: Any]) -> FoodMeasure? {
        guard let gramWeight = doubleValue(dict["gramWeight"]),
              let id = dict["id"] as? Int,
              let measureUnitName = dict["measureUnitName"] as? String,
              let rank = dict["rank"] as? Int else { return nil }
        let text = dict["disseminationText"] as? String ?? dict["modifier"] as? String ?? ""
        return FoodMeasure(disseminationText: text,
                           gramWeight: gramWeight,
                           id: id,
                           modifier: dict["modifier"] as? String,
                           measureUnitName: measureUnitName,
                           rank: rank)
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let d as Double: return d
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }

    // MARK: - Food Audio Transcription
    
    /// Transcribe audio specifically for food logging using the newer gpt-4o-transcribe model
    /// - Parameters:
    ///   - audioData: The audio data to transcribe
    ///   - completion: Result callback with transcribed text or error
    func transcribeAudioForFoodLogging(from audioData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiUrl = URL(string: "\(baseUrl)/transcribe-audio-log/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        
        // Add user email to the request
        if let userEmail = UserDefaults.standard.string(forKey: "userEmail") {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"user_email\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(userEmail)\r\n".data(using: .utf8)!)
        }
        
        // Add audio file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio_file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body

        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let text = json["text"] as? String {
                    DispatchQueue.main.async {
                        completion(.success(text))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.decodingError))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }

        task.resume()
    }

    // MARK: - Process Audio and Generate Food Macros
    
    /// Process voice log audio to transcribe and generate AI macros
    /// - Parameters:
    ///   - audioData: The audio data to process
    ///   - completion: Result callback with processed food data or error
    func processVoiceLogAudio(
        audioData: Data,
        completion: @escaping (Result<Food, Error>) -> Void
    ) {
        // Step 1: Transcribe the audio
        transcribeAudioForFoodLogging(from: audioData) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let transcribedText):
                // Step 2: Generate AI macros from the transcribed text
                self.generateMacrosFromText(transcribedText, completion: completion)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Generate AI macros from transcribed text
    /// - Parameters:
    ///   - text: The transcribed text
    ///   - completion: Result callback with generated food data or error
    private func generateMacrosFromText(
        _ text: String,
        completion: @escaping (Result<Food, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/generate-ai-macros/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Create request body
        let parameters: [String: Any] = [
            "user_email": UserDefaults.standard.string(forKey: "userEmail") ?? "",
            "food_description": text,
            "meal_type": "Lunch" // Add default meal type
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                // Don't use convertFromSnakeCase as our Food struct handles key mapping manually
                
                // Check if we have a nested structure with 'food' key
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let foodData = json["food"] as? [String: Any] {
                    // Convert any "displayName" to "description" in the food data
                    var modifiedFoodData = foodData
                    if let displayName = foodData["displayName"] as? String {
                        modifiedFoodData["description"] = displayName
                        modifiedFoodData.removeValue(forKey: "displayName")
                    }
                    
                    // Extract the food object and decode it with the modified data
                    let foodJson = try JSONSerialization.data(withJSONObject: modifiedFoodData)
                    let food = try decoder.decode(Food.self, from: foodJson)
                    
                    DispatchQueue.main.async {
                        completion(.success(food))
                    }
                } else {
                    // Try the old way - maybe it's not nested
                    let food = try decoder.decode(Food.self, from: data)

                    DispatchQueue.main.async {
                        completion(.success(food))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    // MARK: - Onboarding
    
    /// Mark the user's onboarding as completed on the server
    /// - Parameters:
    ///   - email: The user's email address
    ///   - completion: Callback with success or failure result
    func markOnboardingCompleted(email: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let urlString = "\(baseUrl)/complete-onboarding/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = ["email": email]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters)
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool {
                        completion(.success(success))
                    } else {
                        completion(.failure(NetworkError.decodingError))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }

    /// Process user onboarding data and calculate BMR, TDEE, and nutrition goals
    /// - Parameters:
    ///   - userData: The user's onboarding data
    ///   - completion: Callback with nutritional goals or error
    func processOnboardingData(userData: OnboardingData, completion: @escaping (Result<NutritionGoals, Error>) -> Void) {
        let urlString = "\(baseUrl)/process-onboarding-data/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Create JSON data
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        // Create dictionary representation
        var parameters: [String: Any] = [
            "user_email": userData.email,
            "gender": userData.gender,
            "date_of_birth": userData.dateOfBirth,
            "height_cm": userData.heightCm,
            "weight_kg": userData.weightKg,
            "desired_weight_kg": userData.desiredWeightKg,
            "workout_frequency": userData.workoutFrequency,
            "rollover_calories": userData.rolloverCalories,
            "add_calories_burned": userData.addCaloriesBurned
        ]

        // Use serverDietGoal which has the correct values for the server
        if let serverDietGoal = UserDefaults.standard.string(forKey: "serverDietGoal") {
            parameters["diet_goal"] = serverDietGoal
        } else {
            // Fallback to the original dietGoal with mapping
            let mappedDietGoal: String
            switch userData.dietGoal {
            case "loseWeight": mappedDietGoal = "lose"
            case "gainWeight": mappedDietGoal = "gain"
            case "maintain": mappedDietGoal = "maintain"
            default: mappedDietGoal = "maintain"
            }
            parameters["diet_goal"] = mappedDietGoal
        }
        
        // Add optional fields if they exist
        if !userData.dietPreference.isEmpty {
            parameters["diet_preference"] = userData.dietPreference
        }
        
        if !userData.primaryWellnessGoal.isEmpty {
            parameters["primary_wellness_goal"] = userData.primaryWellnessGoal
        }
        
        if let timeframe = userData.goalTimeframeWeeks {
            parameters["goal_timeframe_weeks"] = timeframe
        }
        
        if let weightChange = userData.weeklyWeightChange {
            parameters["weekly_weight_change"] = weightChange
        }
        
        if let obstacles = userData.obstacles, !obstacles.isEmpty {
            parameters["obstacles"] = obstacles
        }
        
        if let fitnessLevel = userData.fitnessLevel, !fitnessLevel.isEmpty {
            parameters["fitness_level"] = fitnessLevel
        }
        
        if let fitnessGoal = userData.fitnessGoal, !fitnessGoal.isEmpty {
            parameters["fitness_goal"] = fitnessGoal
        }
        
        if let sportType = userData.sportType, !sportType.isEmpty {
            parameters["sport_type"] = sportType
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters)
            request.httpBody = jsonData

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }

                // Attempt to parse the API response
                do {
                    // First try to check if there's an error message
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let errorMessage = json["error"] as? String {
                            completion(.failure(NetworkError.serverError(message: errorMessage)))
                            return
                        }

                        var parsedGoals: NutritionGoals?
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase

                        if let goalsPayload = json["goals"] as? [String: Any] {
                            let payloadData = try JSONSerialization.data(withJSONObject: goalsPayload)
                            parsedGoals = try decoder.decode(NutritionGoals.self, from: payloadData)
                        }

                        if parsedGoals == nil {
                            // Fall back to legacy fields
                            var calories: Double = 0
                            var protein: Double = 0
                            var carbs: Double = 0
                            var fat: Double = 0

                            if let nutritionGoals = json["nutrition_goals"] as? [String: Any] {
                                calories = nutritionGoals["calories"] as? Double ?? 0
                                protein = nutritionGoals["protein"] as? Double ?? 0
                                carbs = nutritionGoals["carbohydrates"] as? Double ?? 0
                                fat = nutritionGoals["fats"] as? Double ?? 0
                            } else if let dailyGoals = json["daily_goals"] as? [String: Any] {
                                calories = dailyGoals["calories"] as? Double ?? 0
                                protein = dailyGoals["protein"] as? Double ?? 0
                                carbs = dailyGoals["carbs"] as? Double ?? 0
                                fat = dailyGoals["fat"] as? Double ?? 0
                            }

                            let bmr = (json["bmr"] as? Double)
                            let tdee = (json["tdee"] as? Double)
                            parsedGoals = NutritionGoals(
                                bmr: bmr,
                                tdee: tdee,
                                calories: calories,
                                protein: protein,
                                carbs: carbs,
                                fat: fat
                            )
                        }

                        guard let goals = parsedGoals else {
                            completion(.failure(NetworkError.decodingError))
                            return
                        }

                        // Save goals to UserDefaults for other parts of the app
                        // Avoid overwriting with zeros when API omits fields
                        if goals.calories > 0 || goals.protein > 0 || goals.carbs > 0 || goals.fat > 0 {
                            UserGoalsManager.shared.dailyGoals = DailyGoals(
                                calories: max(Int(goals.calories), 0),
                                protein: max(Int(goals.protein), 0),
                                carbs: max(Int(goals.carbs), 0),
                                fat: max(Int(goals.fat), 0)
                            )
                        }

                        completion(.success(goals))
                    } else {
                        completion(.failure(NetworkError.decodingError))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Logs Management

    func getLogsByDate(
        userEmail: String,
        date: Date,
        includeAdjacent: Bool = false,
        daysBefore: Int = 1,
        daysAfter: Int = 1,
        timezoneOffset: Int = 0,
        completion: @escaping (Result<LogsByDateResponse, Error>) -> Void
    ) {
        // Format the date as YYYY-MM-DD
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Build the URL with query parameters
        var urlComponents = URLComponents(string: "\(baseUrl)/get-logs-by-date/")
        urlComponents?.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail),
            URLQueryItem(name: "date", value: dateString),
            URLQueryItem(name: "include_adjacent", value: includeAdjacent ? "true" : "false"),
            URLQueryItem(name: "timezone_offset", value: "\(timezoneOffset)")
        ]
        
        if includeAdjacent {
            urlComponents?.queryItems?.append(URLQueryItem(name: "days_before", value: "\(daysBefore)"))
            urlComponents?.queryItems?.append(URLQueryItem(name: "days_after", value: "\(daysAfter)"))
        }
        
        guard let url = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                // Server responds with snake_case keys (food_log_id, scheduled_at, etc.)
                // without this, IDs/timestamps decode as nil and replace optimistic logs with *_0 placeholders.
                decoder.keyDecodingStrategy = .convertFromSnakeCase

                // Use a more robust custom date decoding strategy
                decoder.dateDecodingStrategy = .custom { decoder -> Date in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)

                    // Handle empty strings
                    if dateString.isEmpty {
                        return Date()
                    }
                    
                    // Try ISO8601 with various options
                    let iso8601 = ISO8601DateFormatter()
                    
                    // Standard ISO8601
                    if let date = iso8601.date(from: dateString) {

                        return date
                    }
                    
                    // With fractional seconds
                    iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = iso8601.date(from: dateString) {

                        return date
                    }
                    
                    // Fall back to DateFormatter
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    
                    // Try multiple formats
                    let formats = [
                        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",  // With 6 fractional digits and timezone
                        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",       // With 6 fractional digits
                        "yyyy-MM-dd'T'HH:mm:ss.SSS",          // With 3 fractional digits
                        "yyyy-MM-dd'T'HH:mm:ss",              // No fractional digits
                        "yyyy-MM-dd"                          // Just date
                    ]
                    
                    for format in formats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            return date
                        }
                    }
                    
                    // If all else fails, throw an error
                    throw DecodingError.dataCorruptedError(in: container, 
                                                          debugDescription: "Expected date string to be ISO8601-formatted.")
                }
                
                let response = try decoder.decode(LogsByDateResponse.self, from: data)

                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }

        task.resume()
    }

    // MARK: - Health Measurements

    /// Log a height measurement for a user
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - heightCm: Height in centimeters
    ///   - notes: Optional notes about the measurement
    ///   - completion: Result callback with the logged height data or error
    func logHeight(
        userEmail: String,
        heightCm: Double,
        notes: String = "Logged from dashboard",
        completion: @escaping (Result<HeightLogResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/log-height/"

        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let parameters: [String: Any] = [
            "user_email": userEmail,
            "height_cm": heightCm,
            "notes": notes
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                // Don't use convertFromSnakeCase since HeightLogResponse has explicit CodingKeys

                let response = try decoder.decode(HeightLogResponse.self, from: data)

                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Log a weight measurement for a user
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - weightKg: Weight in kilograms
    ///   - notes: Optional notes about the measurement
    ///   - completion: Result callback with the logged weight data or error
    func logWeight(
        userEmail: String,
        weightKg: Double,
        notes: String = "Logged from dashboard",
        photoUrl: String? = nil,
        completion: @escaping (Result<WeightLogResponse, Error>) -> Void
    ) {
        logWeight(
            userEmail: userEmail,
            weightKg: weightKg,
            notes: notes,
            photoUrl: photoUrl,
            date: nil,
            completion: completion
        )
    }
    
    /// Log a weight measurement for a user with custom date (for Apple Health sync)
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - weightKg: Weight in kilograms
    ///   - notes: Optional notes about the measurement
    ///   - photoUrl: Optional photo URL
    ///   - date: Optional custom date (for Apple Health sync)
    ///   - completion: Result callback with the logged weight data or error
    func logWeight(
        userEmail: String,
        weightKg: Double,
        notes: String = "Logged from dashboard",
        photoUrl: String? = nil,
        date: Date? = nil,
        completion: @escaping (Result<WeightLogResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/log-weight/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var parameters: [String: Any] = [
            "user_email": userEmail,
            "weight_kg": weightKg,
            "notes": notes
        ]
        
        // Add photo URL if provided
        if let photoUrl = photoUrl {
            parameters["photo_url"] = photoUrl
        }
        
        // Add custom date if provided
        if let date = date {
            let formatter = ISO8601DateFormatter()
            parameters["date_logged"] = formatter.string(from: date)
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response from server
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(WeightLogResponse.self, from: data)

                DispatchQueue.main.async {
                    completion(.success(response))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Log a weight measurement with Apple Health UUID for duplicate prevention
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - weightKg: Weight in kilograms
    ///   - notes: Optional notes about the measurement
    ///   - date: Date for the weight log
    ///   - appleHealthUUID: Apple Health UUID for duplicate prevention
    ///   - completion: Result callback with the logged weight data or error
    func logWeightWithAppleHealthUUID(
        userEmail: String,
        weightKg: Double,
        notes: String = "Synced from Apple Health",
        date: Date,
        appleHealthUUID: String,
        completion: @escaping (Result<WeightLogResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/log-weight/"

        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = ISO8601DateFormatter()
        let parameters: [String: Any] = [
            "user_email": userEmail,
            "weight_kg": weightKg,
            "notes": notes,
            "date_logged": formatter.string(from: date),
            "apple_health_uuid": appleHealthUUID
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response from server
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(WeightLogResponse.self, from: data)

                DispatchQueue.main.async {
                    completion(.success(response))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Log a water intake measurement for a user
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - waterOz: Water intake in fluid ounces
    ///   - originalAmount: Water amount in the unit the user entered
    ///   - unit: Unit label associated with the logged amount
    ///   - notes: Optional notes about the water intake
    ///   - completion: Result callback with the logged water data or error
    func logWater(
        userEmail: String,
        waterOz: Double,
        originalAmount: Double,
        unit: String,
        notes: String = "",
        completion: @escaping (Result<WaterLogResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/log-water/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var parameters: [String: Any] = [
            "user_email": userEmail,
            "water_oz": waterOz,
            "notes": notes
        ]
        parameters["water_unit"] = unit
        parameters["water_value"] = originalAmount
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                // Don't use convertFromSnakeCase since WaterLogResponse has explicit CodingKeys

                let response = try decoder.decode(WaterLogResponse.self, from: data)

                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Fetch Height & Weight Logs

    /// Fetch a user's height log history
    func fetchHeightLogs(
        userEmail: String,
        limit: Int = 100,
        offset: Int = 0,
        completion: @escaping (Result<HeightLogsResponse, Error>) -> Void
    ) {
        var components = URLComponents(string: "\(baseUrl)/get-height-logs/")!
        components.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        guard let url = components.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: errorMessage))) }
                return
            }
            do {
                let decoder = JSONDecoder()
                // Not using .convertFromSnakeCase because we have explicit CodingKeys

                let response = try decoder.decode(HeightLogsResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(response)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    /// Fetch a user's weight log history
    func fetchWeightLogs(
        userEmail: String,
        limit: Int = 100,
        offset: Int = 0,
        completion: @escaping (Result<WeightLogsResponse, Error>) -> Void
    ) {
        var components = URLComponents(string: "\(baseUrl)/get-weight-logs/")!
        components.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        guard let url = components.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: errorMessage))) }
                return
            }
            do {
                let decoder = JSONDecoder()
                // Not using .convertFromSnakeCase because WeightLogsResponse has explicit CodingKeys
                
                let response = try decoder.decode(WeightLogsResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(response)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    // MARK: - Profile Data
    
    /// Fetch comprehensive profile data for a user
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - timezoneOffset: User's timezone offset in minutes
    ///   - completion: Result callback with profile data or error
    func fetchProfileData(
        userEmail: String,
        timezoneOffset: Int = 0,
        completion: @escaping (Result<ProfileDataResponse, Error>) -> Void
    ) {
        var components = URLComponents(string: "\(baseUrl)/get-profile-data/")!
        components.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail),
            URLQueryItem(name: "timezone_offset", value: String(timezoneOffset))
        ]
        guard let url = components.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: errorMessage))) }
                return
            }
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(ProfileDataResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    func fetchWorkoutProfiles(
        email: String,
        completion: @escaping (Result<WorkoutProfilesResponse, Error>) -> Void
    ) {
        guard var components = URLComponents(string: "\(baseUrl)/workout-profiles/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        components.queryItems = [URLQueryItem(name: "user_email", value: email)]
        guard let url = components.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: errorMessage))) }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(WorkoutProfilesResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(decoded)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    func createWorkoutProfile(
        email: String,
        name: String,
        makeActive: Bool = true,
        completion: @escaping (Result<CreateWorkoutProfileResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/workout-profiles/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let body: [String: Any] = [
            "email": email,
            "name": name,
            "make_active": makeActive
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: errorMessage))) }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(CreateWorkoutProfileResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(decoded)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    func activateWorkoutProfile(
        email: String,
        profileId: Int,
        completion: @escaping (Result<ActivateWorkoutProfileResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/workout-profiles/\(profileId)/activate/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let body: [String: Any] = ["email": email]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: errorMessage))) }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(ActivateWorkoutProfileResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(decoded)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    func deleteWorkoutProfile(
        email: String,
        profileId: Int,
        completion: @escaping (Result<WorkoutProfilesResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/workout-profiles/\(profileId)/delete/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let body: [String: Any] = ["email": email]

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: errorMessage))) }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(WorkoutProfilesResponse.self, from: data)
                DispatchQueue.main.async { completion(.success(decoded)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    // MARK: - Nutrition Goals

    /// Update a user's nutrition goals with custom overrides.
    func updateNutritionGoals(
        userEmail: String,
        overrides: [String: GoalOverridePayload] = [:],
        removeOverrides: [String] = [],
        clearAll: Bool = false,
        additionalFields: [String: Any] = [:],
        completion: @escaping (Result<NutritionGoalsResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/update-nutrition-goals/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var parameters: [String: Any] = ["user_email": userEmail]

        let overridePayload = overrides.compactMapValues { payload -> [String: Double]? in
            let dict = payload.dictionary
            return dict.isEmpty ? nil : dict
        }
        if !overridePayload.isEmpty {
            parameters["overrides"] = overridePayload
        }
        if !removeOverrides.isEmpty {
            parameters["remove_overrides"] = removeOverrides
        }
        if clearAll {
            parameters["clear_all"] = true
        }
        for (key, value) in additionalFields {
            parameters[key] = value
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                let response = try decoder.decode(NutritionGoalsResponse.self, from: data)
                
                DispatchQueue.main.async {
                    completion(.success(response))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Generate optimized nutrition goals based on user's profile data
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - completion: Result callback with generated goals or error
    func generateNutritionGoals(
        userEmail: String,
        completion: @escaping (Result<NutritionGoalsResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/generate-goals/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Create request body (only requires email)
        let parameters: [String: Any] = [
            "user_email": userEmail
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase

                let response = try decoder.decode(NutritionGoalsResponse.self, from: data)

                DispatchQueue.main.async {
                    completion(.success(response))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Ensure the backend has onboarding + nutrition goal records for the user.
    func ensureNutritionGoals(
        userEmail: String,
        fallbackOnboardingPayload: [String: Any]? = nil,
        completion: @escaping (Result<NutritionGoalsResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/ensure-nutrition-goals/"

        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var body: [String: Any] = ["user_email": userEmail]
        if let payload = fallbackOnboardingPayload, !payload.isEmpty {
            body["fallback_onboarding_data"] = payload
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let response = try decoder.decode(NutritionGoalsResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(message: errorMessage)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.decodingError))
                    }
                }
            }
        }.resume()
    }

    func deleteLogItem(userEmail: String, logId: Int, logType: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard var urlComponents = URLComponents(string: "\(baseUrl)/delete-log-item/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail),
            URLQueryItem(name: "log_id", value: String(logId)),
            URLQueryItem(name: "log_type", value: logType)
        ]

        guard let url = urlComponents.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                if let data = data, let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    completion(.failure(NetworkError.serverError(message: errorResponse.error)))
                } else {
                    completion(.failure(NetworkError.requestFailed(statusCode: httpResponse.statusCode)))
                }
            }
        }.resume()
    }

    /// Explode a recipe log into individual food logs for each ingredient
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - recipeLogId: ID of the recipe log to explode
    ///   - completion: Result callback with created food logs or error
    func explodeRecipeLog(
        userEmail: String,
        recipeLogId: Int,
        completion: @escaping (Result<ExplodeRecipeLogResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/explode-recipe-log/"

        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let parameters: [String: Any] = [
            "user_email": userEmail,
            "recipe_log_id": recipeLogId
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    decoder.dateDecodingStrategy = .iso8601
                    let response = try decoder.decode(ExplodeRecipeLogResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            } else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    completion(.failure(NetworkError.serverError(message: errorResponse.error)))
                } else {
                    completion(.failure(NetworkError.requestFailed(statusCode: httpResponse.statusCode)))
                }
            }
        }.resume()
    }

    /// Update a food log entry
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - logId: ID of the food log to update
    ///   - servings: New serving size (optional)
    ///   - date: New date (optional)
    ///   - mealType: New meal type (optional)
    ///   - completion: Result callback with updated food log or error
    func updateFoodLog(
        userEmail: String,
        logId: Int,
        servings: Double? = nil,
        date: Date? = nil,
        mealType: String? = nil,
        calories: Double? = nil,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        completion: @escaping (Result<UpdatedFoodLog, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/update-food-log/\(logId)/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var parameters: [String: Any] = [
            "user_email": userEmail
        ]
        
        // Add optional parameters
        if let servings = servings {
            parameters["servings"] = servings
        }
        
        if let date = date {
            parameters["date"] = ISO8601DateFormatter().string(from: date)
        }
        
        if let mealType = mealType {
            parameters["meal_type"] = mealType
        }
        
        if let calories = calories {
            parameters["calories"] = calories
        }
        
        if let protein = protein {
            parameters["protein"] = protein
        }
        
        if let carbs = carbs {
            parameters["carbs"] = carbs
        }
        
        if let fat = fat {
            parameters["fat"] = fat
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                // Don't use convertFromSnakeCase for this endpoint since UpdateFoodLogResponse expects snake_case keys
                
                let response = try decoder.decode(UpdateFoodLogResponse.self, from: data)
                
                DispatchQueue.main.async {
                    completion(.success(response.food_log))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }
    
    func updateMealLog(
        userEmail: String,
        logId: Int,
        servings: Double? = nil,
        date: Date? = nil,
        mealType: String? = nil,
        calories: Double? = nil,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        completion: @escaping (Result<UpdatedMealLog, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/update-meal-log/\(logId)/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var parameters: [String: Any] = [
            "user_email": userEmail
        ]
        
        // Add optional parameters
        if let servings = servings {
            parameters["servings"] = servings
        }
        
        if let date = date {
            parameters["date"] = ISO8601DateFormatter().string(from: date)
        }
        
        if let mealType = mealType {
            parameters["meal_type"] = mealType
        }
        
        if let calories = calories {
            parameters["calories"] = calories
        }
        
        if let protein = protein {
            parameters["protein"] = protein
        }
        
        if let carbs = carbs {
            parameters["carbs"] = carbs
        }
        
        if let fat = fat {
            parameters["fat"] = fat
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                // Don't use convertFromSnakeCase for this endpoint since UpdateMealLogResponse expects snake_case keys

                let response = try decoder.decode(UpdateMealLogResponse.self, from: data)

                DispatchQueue.main.async {
                    completion(.success(response.meal_log))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }
    
    // MARK: - Saved Meals
    
    /// Save a food log or meal log for quick access
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - itemType: Type of item to save ("food_log" or "meal_log")
    ///   - itemId: ID of the log item to save
    ///   - customName: Optional custom name for the saved item
    ///   - notes: Optional notes for the saved item
    ///   - completion: Result callback with saved meal response or error
    func saveMeal(
        userEmail: String,
        itemType: String,
        itemId: Int,
        customName: String? = nil,
        notes: String? = nil,
        completion: @escaping (Result<SaveMealResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/save-meal/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var parameters: [String: Any] = [
            "email": userEmail,
            "item_type": itemType,
            "item_id": itemId
        ]
        
        if let customName = customName {
            parameters["custom_name"] = customName
        }
        
        if let notes = notes {
            parameters["notes"] = notes
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601

                let response = try decoder.decode(SaveMealResponse.self, from: data)

                DispatchQueue.main.async {
                    completion(.success(response))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }
    
    /// Remove a saved meal
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - savedMealId: ID of the saved meal to remove
    ///   - completion: Result callback with unsave response or error
    func unsaveMeal(
        userEmail: String,
        savedMealId: Int,
        completion: @escaping (Result<UnsaveMealResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/unsave-meal/\(savedMealId)/?email=\(userEmail)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(UnsaveMealResponse.self, from: data)

                DispatchQueue.main.async {
                    completion(.success(response))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }
    
    /// Get all saved meals for the authenticated user
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - page: Page number for pagination (default: 1)
    ///   - pageSize: Number of items per page (default: 20)
    ///   - completion: Result callback with saved meals response or error
    func getSavedMeals(
        userEmail: String,
        page: Int = 1,
        pageSize: Int = 20,
        completion: @escaping (Result<SavedMealsResponse, Error>) -> Void
    ) {
        var urlComponents = URLComponents(string: "\(baseUrl)/get-saved-meals/")
        urlComponents?.queryItems = [
            URLQueryItem(name: "email", value: userEmail),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        
        guard let url = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()

                // Custom date formatter to handle microseconds
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)

                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)

                    // Try ISO8601 with fractional seconds first
                    if let date = isoFormatter.date(from: dateString) {
                        return date
                    }

                    // Try custom formatter
                    if let date = formatter.date(from: dateString) {
                        return date
                    }

                    // Fallback to standard ISO8601
                    let standardFormatter = ISO8601DateFormatter()
                    if let date = standardFormatter.date(from: dateString) {
                        return date
                    }

                    throw DecodingError.dataCorrupted(DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Invalid date format: \(dateString)"
                    ))
                }

                let response = try decoder.decode(SavedMealsResponse.self, from: data)

                DispatchQueue.main.async {
                    completion(.success(response))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    // MARK: - Saved Foods API (Food Templates/Favorites)

    /// Get saved foods for a user with pagination
    func getSavedFoods(
        userEmail: String,
        page: Int = 1,
        pageSize: Int = 20,
        completion: @escaping (Result<SavedFoodsResponse, Error>) -> Void
    ) {
        var urlComponents = URLComponents(string: "\(baseUrl)/get-saved-foods/")
        urlComponents?.queryItems = [
            URLQueryItem(name: "email", value: userEmail),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]

        guard let url = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SavedFoodsResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Save a food (add to favorites)
    func saveFood(
        userEmail: String,
        foodId: Int,
        customName: String? = nil,
        notes: String? = nil,
        completion: @escaping (Result<SaveFoodResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/save-food/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "email": userEmail,
            "food_id": foodId
        ]
        if let customName = customName { body["custom_name"] = customName }
        if let notes = notes { body["notes"] = notes }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(SaveFoodResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Unsave a food by saved_food ID
    func unsaveFood(
        userEmail: String,
        savedFoodId: Int,
        completion: @escaping (Result<UnsaveFoodResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/unsave-food/\(savedFoodId)/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [URLQueryItem(name: "email", value: userEmail)]

        guard let finalUrl = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        request.url = finalUrl

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(UnsaveFoodResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Unsave a food by the food's ID (not the saved_food ID)
    func unsaveFoodByFoodId(
        userEmail: String,
        foodId: Int,
        completion: @escaping (Result<UnsaveFoodResponse, Error>) -> Void
    ) {
        var urlComponents = URLComponents(string: "\(baseUrl)/unsave-food-by-id/\(foodId)/")
        urlComponents?.queryItems = [URLQueryItem(name: "email", value: userEmail)]

        guard let url = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(UnsaveFoodResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Check if a food is saved by the user
    func isFoodSaved(
        userEmail: String,
        foodId: Int,
        completion: @escaping (Result<IsFoodSavedResponse, Error>) -> Void
    ) {
        var urlComponents = URLComponents(string: "\(baseUrl)/is-food-saved/")
        urlComponents?.queryItems = [
            URLQueryItem(name: "email", value: userEmail),
            URLQueryItem(name: "food_id", value: String(foodId))
        ]

        guard let url = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(IsFoodSavedResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    // MARK: - Saved Recipes

    /// Get all saved recipes for a user
    func getSavedRecipes(
        userEmail: String,
        page: Int = 1,
        pageSize: Int = 20,
        completion: @escaping (Result<SavedRecipesResponse, Error>) -> Void
    ) {
        var urlComponents = URLComponents(string: "\(baseUrl)/get-saved-recipes/")
        urlComponents?.queryItems = [
            URLQueryItem(name: "email", value: userEmail),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]

        guard let url = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .custom { decoder -> Date in
                    let value = try decoder.singleValueContainer().decode(String.self)
                    if let date = self.iso8601FractionalFormatter.date(from: value) ?? self.iso8601BasicFormatter.date(from: value) {
                        return date
                    }
                    throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Cannot decode date from \(value)")
                }
                let response = try decoder.decode(SavedRecipesResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Save a recipe (add to favorites)
    func saveRecipe(
        userEmail: String,
        recipeId: Int,
        completion: @escaping (Result<SaveRecipeResponse, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseUrl)/save-recipe/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": userEmail,
            "recipe_id": recipeId
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .custom { decoder -> Date in
                    let value = try decoder.singleValueContainer().decode(String.self)
                    if let date = self.iso8601FractionalFormatter.date(from: value) ?? self.iso8601BasicFormatter.date(from: value) {
                        return date
                    }
                    throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Cannot decode date from \(value)")
                }
                let response = try decoder.decode(SaveRecipeResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Unsave a recipe by recipe ID
    func unsaveRecipe(
        userEmail: String,
        recipeId: Int,
        completion: @escaping (Result<UnsaveRecipeResponse, Error>) -> Void
    ) {
        var urlComponents = URLComponents(string: "\(baseUrl)/unsave-recipe/\(recipeId)/")
        urlComponents?.queryItems = [URLQueryItem(name: "email", value: userEmail)]

        guard let url = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(UnsaveRecipeResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Check if a recipe is saved by the user
    func isRecipeSaved(
        userEmail: String,
        recipeId: Int,
        completion: @escaping (Result<IsRecipeSavedResponse, Error>) -> Void
    ) {
        var urlComponents = URLComponents(string: "\(baseUrl)/is-recipe-saved/")
        urlComponents?.queryItems = [
            URLQueryItem(name: "email", value: userEmail),
            URLQueryItem(name: "recipe_id", value: String(recipeId))
        ]

        guard let url = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let response = try decoder.decode(IsRecipeSavedResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    /// Update a weight log by ID with full parameters
    /// - Parameters:
    ///   - logId: ID of the weight log to update
    ///   - userEmail: User's email address
    ///   - weightKg: New weight in kilograms
    ///   - dateLogged: New date for the log
    ///   - notes: Notes for the log
    ///   - photoUrl: Photo URL (optional)
    ///   - completion: Result callback with updated weight log or error
    func updateWeightLog(
        logId: Int,
        userEmail: String, 
        weightKg: Double, 
        dateLogged: Date,
        notes: String?, 
        photoUrl: String?,
        completion: @escaping (Result<WeightLogResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/update-weight-log/\(logId)/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var requestBody: [String: Any] = [
            "user_email": userEmail,
            "weight_kg": weightKg,
            "date_logged": dateFormatter.string(from: dateLogged)
        ]
        
        if let notes = notes {
            requestBody["notes"] = notes
        }
        
        if let photoUrl = photoUrl {
            requestBody["photo_url"] = photoUrl
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            // Try to decode the updated weight log
            do {
                let response = try JSONDecoder().decode(WeightLogResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    func updateWeightLogWithPhotoUrl(userEmail: String, weightKg: Double, photoUrl: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "\(baseUrl)/update-weight-log-photo/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let requestBody: [String: Any] = [
            "user_email": userEmail,
            "weight_kg": weightKg,
            "photo_url": photoUrl
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            // Check for success response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
            }
        }.resume()
    }

    // MARK: - Delete Logs
    
    /// Delete a weight log by ID
    /// - Parameters:
    ///   - logId: ID of the weight log to delete
    ///   - completion: Result callback indicating success or error
    func deleteWeightLog(logId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            completion(.failure(NetworkError.serverError(message: "No user email found")))
            return
        }
        
        var urlComponents = URLComponents(string: "\(baseUrl)/delete-weight-log/\(logId)/")
        urlComponents?.queryItems = [URLQueryItem(name: "user_email", value: userEmail)]
        
        guard let url = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.requestFailed(statusCode: httpResponse.statusCode)))
                }
            }
        }.resume()
    }

    /// Delete a height log by ID
    /// - Parameters:
    ///   - logId: ID of the height log to delete
    ///   - completion: Result callback indicating success or error
    func deleteHeightLog(logId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            completion(.failure(NetworkError.serverError(message: "No user email found")))
            return
        }
        
        var urlComponents = URLComponents(string: "\(baseUrl)/delete-height-log/\(logId)/")
        urlComponents?.queryItems = [URLQueryItem(name: "user_email", value: userEmail)]
        
        guard let url = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.requestFailed(statusCode: httpResponse.statusCode)))
                }
            }
        }.resume()
    }

    // MARK: - Profile Updates
    
    /// Update user's name
    /// - Parameters:
    ///   - email: User's email address
    ///   - name: New name
    ///   - completion: Result callback indicating success or error
    func updateName(email: String, name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "\(baseUrl)/update-name/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let requestBody: [String: Any] = [
            "email": email,
            "name": name
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            // Check for success response (backend returns message and name on success)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let _ = json["message"] as? String,
               let _ = json["name"] as? String {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
            }
        }.resume()
    }

    /// Update user's username
    /// - Parameters:
    ///   - email: User's email address
    ///   - username: New username
    ///   - completion: Result callback indicating success or error
    func updateUsername(email: String, username: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "\(baseUrl)/update-username/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let requestBody: [String: Any] = [
            "email": email,
            "username": username
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }
            
            // Check for success response (backend returns message and username on success)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let _ = json["message"] as? String,
               let _ = json["username"] as? String {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
            }
        }.resume()
    }

    /// Update user's profile photo
    /// - Parameters:
    ///   - email: User's email address
    ///   - photoUrl: New photo URL (can be empty to remove photo)
    ///   - completion: Result callback indicating success or error
    func updatePhoto(email: String, photoUrl: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "\(baseUrl)/update-photo/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let requestBody: [String: Any] = [
            "email": email,
            "photo_url": photoUrl
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }

            // Check for success response (backend returns message and photo_url on success)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let _ = json["message"] as? String,
               let _ = json["photo_url"] as? String {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
            }
        }.resume()
    }

    /// Upload photo to Azure Blob Storage and update user's profile photo
    /// - Parameters:
    ///   - email: User's email address
    ///   - imageData: Photo data to upload
    ///   - completion: Result callback indicating success or error
    func uploadAndUpdateProfilePhoto(email: String, imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let containerName = ConfigurationManager.shared.getValue(forKey: "BLOB_CONTAINER") as? String else {
            completion(.failure(NetworkError.serverError(message: "BLOB_CONTAINER not configured")))
            return
        }
        
        let blobName = UUID().uuidString + ".jpg"

        // Use NetworkManager's uploadFileToAzureBlob method
        NetworkManager().uploadFileToAzureBlob(
            containerName: containerName,
            blobName: blobName,
            fileData: imageData,
            contentType: "image/jpeg"
        ) { [weak self] success, url in
            if success, let imageUrl = url {
                
                // Now update the user's profile with the photo URL
                self?.updatePhoto(email: email, photoUrl: imageUrl) { result in
                    switch result {
                    case .success:
                        DispatchQueue.main.async {
                            completion(.success(imageUrl))
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: "Failed to upload photo to Azure Blob Storage")))
                }
            }
        }
    }
    
    /// Check if user can change username and get remaining cooldown days
    /// - Parameters:
    ///   - email: User's email address
    ///   - completion: Result callback with eligibility information or error
    func checkUsernameEligibility(email: String, completion: @escaping (Result<UsernameEligibilityResponse, Error>) -> Void) {
        guard let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseUrl)/check-username-eligibility/?email=\(encodedEmail)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let eligibilityResponse = try JSONDecoder().decode(UsernameEligibilityResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(eligibilityResponse))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.decodingError))
                    }
                }
            } else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(message: errorMessage)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(message: "Failed to check username eligibility")))
                    }
                }
            }
        }.resume()
    }
    
    /// Check if user can change name and get remaining cooldown days
    /// - Parameters:
    ///   - email: User's email address
    ///   - completion: Result callback with eligibility information or error
    func checkNameEligibility(email: String, completion: @escaping (Result<NameEligibilityResponse, Error>) -> Void) {
        guard let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseUrl)/check-name-eligibility/?email=\(encodedEmail)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            if httpResponse.statusCode == 200 {
                do {
                    let eligibilityResponse = try JSONDecoder().decode(NameEligibilityResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(eligibilityResponse))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.decodingError))
                    }
                }
            } else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(message: errorMessage)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(message: "Failed to check name eligibility")))
                    }
                }
            }
        }.resume()
    }
    
    /// Check if a username is available (not taken by another user)
    /// - Parameters:
    ///   - username: Username to check
    ///   - email: Current user's email address
    ///   - completion: Result callback with availability information or error
    func checkUsernameAvailability(username: String, email: String, completion: @escaping (Result<UsernameAvailabilityResponse, Error>) -> Void) {
        guard let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseUrl)/check-username-availability/?username=\(encodedUsername)&email=\(encodedEmail)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let availabilityResponse = try JSONDecoder().decode(UsernameAvailabilityResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(availabilityResponse))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.decodingError))
                    }
                }
            } else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(message: errorMessage)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(message: "Failed to check username availability")))
                    }
                }
            }
        }.resume()
    }
    
    /// Update user's workout preferences
    /// - Parameters:
    ///   - email: User's email address
    ///   - workoutData: Dictionary containing workout preference updates
    ///   - completion: Result callback indicating success or error
    func updateWorkoutPreferences(email: String, workoutData: [String: Any], profileId: Int? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "\(baseUrl)/update-workout-preferences/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var requestBody: [String: Any] = [
            "email": email
        ]
        
        // Merge workout data into request body
        for (key, value) in workoutData {
            requestBody[key] = value
        }
        if requestBody["profile_id"] == nil {
            if let profileId = profileId ?? UserProfileService.shared.activeWorkoutProfile?.id {
                requestBody["profile_id"] = profileId
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(message: errorMessage)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.requestFailed(statusCode: httpResponse.statusCode)))
                    }
                }
            }
        }.resume()
    }

    // MARK: - Oura Integration

    func fetchOuraStatus(email: String, completion: @escaping (Result<OuraStatusResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/oura/status/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if httpResponse.statusCode == 200 {
                do {
                    let decoded = try JSONDecoder().decode(OuraStatusResponse.self, from: data)
                    DispatchQueue.main.async { completion(.success(decoded)) }
                } catch {
                    DispatchQueue.main.async { completion(.failure(NetworkError.decodingError)) }
                }
            } else {
                let message = self.parseServerError(from: data) ?? "Failed to fetch Oura status"
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: message))) }
            }
        }.resume()
    }

    func startOuraAuthorization(email: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/oura/start/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if httpResponse.statusCode == 200 {
                do {
                    let decoded = try JSONDecoder().decode(OuraAuthResponse.self, from: data)
                    DispatchQueue.main.async { completion(.success(decoded.authorizationUrl)) }
                } catch {
                    DispatchQueue.main.async { completion(.failure(NetworkError.decodingError)) }
                }
            } else {
                let message = self.parseServerError(from: data) ?? "Failed to start Oura authorization"
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: message))) }
            }
        }.resume()
    }

    func disconnectOura(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/oura/disconnect/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if httpResponse.statusCode == 200 {
                DispatchQueue.main.async { completion(.success(())) }
            } else {
                let message = self.parseServerError(from: data) ?? "Failed to disconnect Oura"
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: message))) }
            }
        }.resume()
    }

    func syncOura(email: String, days: Int = 7, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/oura/sync/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["email": email, "days": days]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NetworkError.invalidResponse)) }
                return
            }

            if httpResponse.statusCode == 200 {
                DispatchQueue.main.async { completion(.success(())) }
            } else {
                let message = self.parseServerError(from: data) ?? "Failed to sync Oura data"
                DispatchQueue.main.async { completion(.failure(NetworkError.serverError(message: message))) }
            }
        }.resume()
    }

    private func parseServerError(from data: Data?) -> String? {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errorMessage = json["error"] as? String
        else { return nil }
        return errorMessage
    }

    // MARK: - Unified Meal and Activity Analysis
    
    /// Analyze a text description to determine if it's food or physical activity
    /// - Parameters:
    ///   - description: The user's text description
    ///   - mealType: The meal type (for food logs)
    ///   - completion: Result callback with response data or error
    func analyzeMealOrActivity(description: String, mealType: String, date: String? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let tzOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
        var parameters: [String: Any] = [
            "user_email": UserDefaults.standard.string(forKey: "userEmail") ?? "",
            "description": description,
            "meal_type": mealType,
            "timezone_offset_minutes": tzOffsetMinutes
        ]
        if let date = date { parameters["date"] = date }
        
        let urlString = "\(baseUrl)/analyze-meal-or-activity/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Create and configure request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            if httpResponse.statusCode == 429 {
                let message: String
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    message = errorMessage
                } else {
                    message = "You’ve reached today’s free food scan limit. Upgrade to Metryc Pro for unlimited scans."
                }
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.featureLimitExceeded(message: message)))
                }
                return
            }
            
            // Check if there's an error response first
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }
            
            // Parse response as generic dictionary
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    
                    DispatchQueue.main.async {
                        completion(.success(jsonResponse))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.invalidResponse))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }

    // MARK: - Activity Log Management
    
    /// Delete an AI-generated activity log by ID
    func deleteActivityLog(activityLogId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            completion(.failure(NetworkError.serverError(message: "No user email found")))
            return
        }
        
        var urlComponents = URLComponents(string: "\(baseUrl)/delete-activity-log/\(activityLogId)/")
        urlComponents?.queryItems = [URLQueryItem(name: "user_email", value: userEmail)]
        
        guard let url = urlComponents?.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.requestFailed(statusCode: httpResponse.statusCode)))
                }
            }
        }.resume()
    }
    
    // MARK: - Creation-Only Functions
    // These functions create foods without logging them, for use in food creation contexts
    
    // Function to analyze food image for creation (without logging)
    func analyzeFoodImageForCreation(image: UIImage, userEmail: String, completion: @escaping (Bool, [String: Any]?, String?) -> Void) {
        // Configure the URL
        guard let url = URL(string: "\(baseUrl)/analyze_food_image_for_creation/") else {
            completion(false, nil, "Invalid URL")
            return
        }
        
        // Compress the image to reduce upload size (quality: 0.7 is a good balance)
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(false, nil, "Failed to compress image")
            return
        }
        
        // Convert image data to Base64 string
        let base64Image = imageData.base64EncodedString()
        
        // Create request body (no meal_type needed for creation)
        let tzOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let parameters: [String: Any] = [
            "user_email": userEmail,
            "image_data": base64Image,
            "timezone_offset_minutes": tzOffsetMinutes
        ]
        
        // Configure the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(false, nil, "Failed to serialize request: \(error.localizedDescription)")
            return
        }
        
        // Create and start the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network error
            if let error = error {
                completion(false, nil, "Network error: \(error.localizedDescription)")
                return
            }
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, nil, "Invalid response")
                return
            }
            
            // Check status code
            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                completion(false, nil, "Server error: HTTP \(httpResponse.statusCode)")
                return
            }
            
            // Parse response data
            guard let data = data else {
                completion(false, nil, "No data received")
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for error in response
                    if let errorMessage = jsonResponse["error"] as? String {
                        completion(false, nil, errorMessage)
                        return
                    }
                    
                    // Handle successful response
                    completion(true, jsonResponse, nil)
                } else {
                    completion(false, nil, "Invalid response format")
                }
            } catch {
                completion(false, nil, "Failed to parse response: \(error.localizedDescription)")
            }
        }
        
        // Start the request
        task.resume()
    }
    
    // Function to analyze nutrition label for creation (without logging)
    func analyzeNutritionLabelForCreation(image: UIImage, userEmail: String, completion: @escaping (Bool, [String: Any]?, String?) -> Void) {
        // Configure the URL
        guard let url = URL(string: "\(baseUrl)/analyze_nutrition_label_for_creation/") else {
            completion(false, nil, "Invalid URL")
            return
        }
        
        // Compress the image to reduce upload size (quality: 0.8 for better text clarity)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(false, nil, "Failed to compress image")
            return
        }
        
        // Convert image data to Base64 string
        let base64Image = imageData.base64EncodedString()
        
        // Create request body (no meal_type needed for creation)
        let tzOffsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let parameters: [String: Any] = [
            "user_email": userEmail,
            "image_data": base64Image,
            "timezone_offset_minutes": tzOffsetMinutes
        ]
        
        // Configure the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(false, nil, "Failed to serialize request: \(error.localizedDescription)")
            return
        }
        
        // Create and start the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network error
            if let error = error {
                completion(false, nil, "Network error: \(error.localizedDescription)")
                return
            }
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, nil, "Invalid response")
                return
            }
            
            // Check status code
            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                completion(false, nil, "Server error: HTTP \(httpResponse.statusCode)")
                return
            }
            
            // Parse response data
            guard let data = data else {
                completion(false, nil, "No data received")
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for error in response
                    if let errorMessage = jsonResponse["error"] as? String {
                        completion(false, nil, errorMessage)
                        return
                    }
                    
                    // Handle successful response
                    completion(true, jsonResponse, nil)
                } else {
                    completion(false, nil, "Invalid response format")
                }
            } catch {
                completion(false, nil, "Failed to parse response: \(error.localizedDescription)")
            }
        }
        
        // Start the request
        task.resume()
    }
    
    // MARK: - Device Token Management
    
    /// Update device token for push notifications
    /// - Parameters:
    ///   - token: The device token string
    ///   - userEmail: User's email address
    ///   - completion: Result callback with success/failure
    func updateDeviceToken(token: String, userEmail: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/api/update-device-token/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "device_token": token,
            "user_email": userEmail
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }

                if httpResponse.statusCode == 200 {
                    completion(.success(()))
                } else {
                    completion(.failure(NetworkError.requestFailed(statusCode: httpResponse.statusCode)))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Exercise Notes Management
    
    /// Create or update exercise notes for a user
    /// - Parameters:
    ///   - exerciseId: The ID of the exercise
    ///   - notes: The notes text to save
    ///   - userEmail: User's email address
    ///   - completion: Result callback with success/failure
    func createOrUpdateExerciseNotes(exerciseId: Int, notes: String, userEmail: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/create-or-update-exercise-notes/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "user_email": userEmail,
            "exercise_id": exerciseId,
            "notes": notes
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            completion(.success(json))
                        } else {
                            completion(.failure(NetworkError.decodingError))
                        }
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    // Try to parse error message from response
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["error"] as? String {
                        completion(.failure(NetworkError.serverError(message: errorMessage)))
                    } else {
                        completion(.failure(NetworkError.requestFailed(statusCode: httpResponse.statusCode)))
                    }
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Flexibility Preferences
    
    struct FlexibilityPreferences: Codable {
        let warmUpEnabled: Bool
        let coolDownEnabled: Bool
        let warmUpDuration: Int
        let coolDownDuration: Int
        
        enum CodingKeys: String, CodingKey {
            case warmUpEnabled = "default_warmup_enabled"
            case coolDownEnabled = "default_cooldown_enabled"
            case warmUpDuration = "default_warmup_duration"
            case coolDownDuration = "default_cooldown_duration"
        }
    }
    
    struct FlexibilityPreferencesResponse: Codable {
        let preferences: FlexibilityPreferences
    }
    
    /// Update user's flexibility preferences on the server
    func updateFlexibilityPreferences(email: String, warmUpEnabled: Bool, coolDownEnabled: Bool, warmUpDuration: Int = 5, coolDownDuration: Int = 5, completion: @escaping (Result<Bool, Error>) -> Void) {
        let urlString = "\(baseUrl)/update-workout-preferences/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "email": email,
            "default_warmup_enabled": warmUpEnabled,
            "default_cooldown_enabled": coolDownEnabled,
            "default_warmup_duration": warmUpDuration,
            "default_cooldown_duration": coolDownDuration
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters)
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }

                if httpResponse.statusCode == 200 {
                    completion(.success(true))
                } else {
                    // Try to parse error message from response
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["error"] as? String {
                        completion(.failure(NetworkError.serverError(message: errorMessage)))
                    } else {
                        completion(.failure(NetworkError.requestFailed(statusCode: httpResponse.statusCode)))
                    }
                }
            }
            
            task.resume()

        } catch {
            completion(.failure(error))
        }
    }

    /// Get user's flexibility preferences from the server  
    func getFlexibilityPreferences(email: String, completion: @escaping (Result<FlexibilityPreferences, Error>) -> Void) {
        let urlString = "\(baseUrl)/get-workout-preferences/"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = ["email": email]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters)
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }

                if httpResponse.statusCode == 200 {
                    do {
                        let response = try JSONDecoder().decode(FlexibilityPreferencesResponse.self, from: data)
                        completion(.success(response.preferences))
                    } catch {
                        completion(.failure(NetworkError.decodingError))
                    }
                } else {
                    // Try to parse error message from response
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["error"] as? String {
                        completion(.failure(NetworkError.serverError(message: errorMessage)))
                    } else {
                        completion(.failure(NetworkError.requestFailed(statusCode: httpResponse.statusCode)))
                    }
                }
            }
            
            task.resume()

        } catch {
            completion(.failure(error))
        }
    }

    func processScheduledMealLog(userEmail: String,
                                 scheduledId: Int,
                                 action: String,
                                 targetDate: Date,
                                 timezoneOffset: Int,
                                 completion: @escaping (Result<ProcessScheduledMealResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl)/scheduled-meal-log-action/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let payload: [String: Any] = [
            "user_email": userEmail,
            "scheduled_id": scheduledId,
            "action": action,
            "target_date": dateFormatter.string(from: targetDate),
            "timezone_offset": timezoneOffset,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  let data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                if let errorMessage = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(message: errorMessage)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.requestFailed(statusCode: httpResponse.statusCode)))
                    }
                }
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder -> Date in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                if let date = self.iso8601FractionalFormatter.date(from: value) ?? self.iso8601BasicFormatter.date(from: value) {
                    return date
                }
                let formatter = DateFormatter()
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.timeZone = TimeZone.current
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: value) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container,
                                                       debugDescription: "Invalid date string: \(value)")
            }

            do {
                let responsePayload = try decoder.decode(ProcessScheduledMealResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(responsePayload))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Training Program Methods

    func fetchActiveProgram(userEmail: String) async throws -> TrainingProgram? {
        var components = URLComponents(string: "\(baseUrl)/api/programs/active/")
        components?.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail)
        ]

        guard let url = components?.url else { throw NetworkError.invalidURL }

        print("[FETCH ACTIVE PROGRAM] Fetching from: \(url)")

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse {
            print("[FETCH ACTIVE PROGRAM] Response status: \(httpResponse.statusCode)")
        }
        if let responseString = String(data: data, encoding: .utf8) {
            print("[FETCH ACTIVE PROGRAM] Raw response (first 500 chars): \(String(responseString.prefix(500)))")
        }

        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let responsePayload = try decoder.decode(ProgramResponse.self, from: data)
            if let program = responsePayload.program {
                print("[FETCH ACTIVE PROGRAM] Successfully decoded program: \(program.name)")
            } else {
                print("[FETCH ACTIVE PROGRAM] No active program found")
            }
            return responsePayload.program
        } catch {
            print("[FETCH ACTIVE PROGRAM ERROR] Decoding failed: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("[FETCH ACTIVE PROGRAM ERROR] Key not found: \(key.stringValue), path: \(context.codingPath.map { $0.stringValue })")
                case .typeMismatch(let type, let context):
                    print("[FETCH ACTIVE PROGRAM ERROR] Type mismatch: expected \(type), path: \(context.codingPath.map { $0.stringValue })")
                case .valueNotFound(let type, let context):
                    print("[FETCH ACTIVE PROGRAM ERROR] Value not found: \(type), path: \(context.codingPath.map { $0.stringValue })")
                case .dataCorrupted(let context):
                    print("[FETCH ACTIVE PROGRAM ERROR] Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("[FETCH ACTIVE PROGRAM ERROR] Unknown decoding error")
                }
            }
            throw error
        }
    }

    func updateProgramPreferences(
        programId: Int,
        userEmail: String,
        fitnessGoal: String? = nil,
        experienceLevel: String? = nil,
        sessionDurationMinutes: Int? = nil,
        defaultWarmupEnabled: Bool? = nil,
        defaultCooldownEnabled: Bool? = nil,
        includeFoamRolling: Bool? = nil
    ) async throws -> TrainingProgram {
        guard let url = URL(string: "\(baseUrl)/api/programs/\(programId)/preferences/") else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["user_email": userEmail]

        if let fitnessGoal = fitnessGoal {
            body["fitness_goal"] = fitnessGoal
        }
        if let experienceLevel = experienceLevel {
            body["experience_level"] = experienceLevel
        }
        if let sessionDurationMinutes = sessionDurationMinutes {
            body["session_duration_minutes"] = sessionDurationMinutes
        }
        if let defaultWarmupEnabled = defaultWarmupEnabled {
            body["default_warmup_enabled"] = defaultWarmupEnabled
        }
        if let defaultCooldownEnabled = defaultCooldownEnabled {
            body["default_cooldown_enabled"] = defaultCooldownEnabled
        }
        if let includeFoamRolling = includeFoamRolling {
            body["include_foam_rolling"] = includeFoamRolling
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        struct UpdateResponse: Codable {
            let success: Bool
            let program: TrainingProgram
        }

        let responsePayload = try decoder.decode(UpdateResponse.self, from: data)
        return responsePayload.program
    }

    func fetchTodayWorkout(userEmail: String) async throws -> TodayWorkoutResponse {
        var components = URLComponents(string: "\(baseUrl)/api/programs/today/")
        components?.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail)
        ]

        guard let url = components?.url else { throw NetworkError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TodayWorkoutResponse.self, from: data)
    }

    func generateProgram(userEmail: String, request: GenerateProgramRequest) async throws -> TrainingProgram {
        guard let url = URL(string: "\(baseUrl)/api/programs/generate/") else { throw NetworkError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120  // Program generation can take time

        // Create body with user_email
        var body: [String: Any] = [
            "user_email": userEmail,
            "program_type": request.programType,
            "fitness_goal": request.fitnessGoal,
            "experience_level": request.experienceLevel,
            "days_per_week": request.daysPerWeek,
            "session_duration_minutes": request.sessionDurationMinutes,
            "total_weeks": request.totalWeeks,
            "include_deload": request.includeDeload,
            "default_warmup_enabled": request.defaultWarmupEnabled,
            "default_cooldown_enabled": request.defaultCooldownEnabled
        ]

        if let startDate = request.startDate {
            body["start_date"] = startDate
        }
        if let equipment = request.availableEquipment {
            body["available_equipment"] = equipment
        }
        if let excluded = request.excludedExercises {
            body["excluded_exercises"] = excluded
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[PROGRAM GENERATE] Sending request to: \(url)")
        print("[PROGRAM GENERATE] Request body: \(body)")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // Log raw response for debugging
        if let httpResponse = response as? HTTPURLResponse {
            print("[PROGRAM GENERATE] Response status: \(httpResponse.statusCode)")
        }
        if let responseString = String(data: data, encoding: .utf8) {
            print("[PROGRAM GENERATE] Raw response (first 500 chars): \(String(responseString.prefix(500)))")
        }

        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let responsePayload = try decoder.decode(ProgramResponse.self, from: data)
            guard let program = responsePayload.program else {
                print("[PROGRAM GENERATE ERROR] Program is nil in response")
                throw NetworkError.serverError(message: "Failed to generate program")
            }
            print("[PROGRAM GENERATE] Successfully decoded program: \(program.name)")
            return program
        } catch {
            print("[PROGRAM GENERATE ERROR] Decoding failed: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("[PROGRAM GENERATE ERROR] Key not found: \(key.stringValue), path: \(context.codingPath.map { $0.stringValue })")
                case .typeMismatch(let type, let context):
                    print("[PROGRAM GENERATE ERROR] Type mismatch: expected \(type), path: \(context.codingPath.map { $0.stringValue })")
                case .valueNotFound(let type, let context):
                    print("[PROGRAM GENERATE ERROR] Value not found: \(type), path: \(context.codingPath.map { $0.stringValue })")
                case .dataCorrupted(let context):
                    print("[PROGRAM GENERATE ERROR] Data corrupted: \(context.debugDescription), path: \(context.codingPath.map { $0.stringValue })")
                @unknown default:
                    print("[PROGRAM GENERATE ERROR] Unknown decoding error")
                }
            }
            throw error
        }
    }

    func fetchProgramTypes() async throws -> [ProgramTypeInfo] {
        guard let url = URL(string: "\(baseUrl)/api/programs/types/") else { throw NetworkError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responsePayload = try decoder.decode(ProgramTypesResponse.self, from: data)
        return responsePayload.programTypes
    }

    func markProgramDayComplete(dayId: Int, userEmail: String) async throws -> ProgramDay {
        guard let url = URL(string: "\(baseUrl)/api/programs/day/\(dayId)/complete/") else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["user_email": userEmail]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responsePayload = try decoder.decode(MarkDayCompleteResponse.self, from: data)
        return responsePayload.day
    }

    func deleteProgram(programId: Int, userEmail: String) async throws {
        guard let url = URL(string: "\(baseUrl)/api/programs/\(programId)/delete/") else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["user_email": userEmail]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[DELETE PROGRAM] Deleting program \(programId) for user: \(userEmail)")
        print("[DELETE PROGRAM] URL: \(url)")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("[DELETE PROGRAM] Response status: \(httpResponse.statusCode)")
        }
        if let responseString = String(data: data, encoding: .utf8) {
            print("[DELETE PROGRAM] Response: \(responseString)")
        }

        try validate(response: response, data: data)
        print("[DELETE PROGRAM] Successfully deleted program \(programId)")
    }

    /// Update plan settings (MacroFactor-style)
    /// PATCH /api/programs/{id}/settings/
    func updateProgramSettings(
        programId: Int,
        userEmail: String,
        name: String? = nil,
        totalWeeks: Int? = nil,
        includeDeload: Bool? = nil,
        dayOrder: [[String: String]]? = nil
    ) async throws -> TrainingProgram {
        guard let url = URL(string: "\(baseUrl)/api/programs/\(programId)/settings/") else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["user_email": userEmail]
        if let name = name { body["name"] = name }
        if let totalWeeks = totalWeeks { body["total_weeks"] = totalWeeks }
        if let includeDeload = includeDeload { body["include_deload"] = includeDeload }
        if let dayOrder = dayOrder { body["day_order"] = dayOrder }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responsePayload = try decoder.decode(ProgramResponse.self, from: data)

        guard let program = responsePayload.program else {
            throw NetworkError.decodingError
        }
        return program
    }

    func listPrograms(userEmail: String) async throws -> [TrainingProgram] {
        var components = URLComponents(string: "\(baseUrl)/api/programs/")
        components?.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail)
        ]

        guard let url = components?.url else { throw NetworkError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responsePayload = try decoder.decode(ProgramsListResponse.self, from: data)
        return responsePayload.programs
    }

    func skipProgramDayWorkout(dayId: Int, userEmail: String) async throws -> ProgramDay {
        guard let url = URL(string: "\(baseUrl)/api/programs/day/\(dayId)/skip/") else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["user_email": userEmail]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responsePayload = try decoder.decode(MarkDayCompleteResponse.self, from: data)
        return responsePayload.day
    }

    func updateProgramDayLabel(dayId: Int, workoutLabel: String, userEmail: String) async throws {
        guard let url = URL(string: "\(baseUrl)/api/programs/day/\(dayId)/update/") else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_email": userEmail,
            "workout_label": workoutLabel
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        // Response contains the updated program, but caller will refresh separately
    }

    func deleteProgramDay(dayId: Int, userEmail: String) async throws {
        guard let url = URL(string: "\(baseUrl)/api/programs/day/\(dayId)/delete/") else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_email": userEmail
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    /// Change a program day's type (workout <-> rest)
    /// PATCH /api/programs/day/{dayId}/update/
    /// When changing to rest, all exercises are deleted
    func updateProgramDayType(dayId: Int, dayType: String, userEmail: String) async throws {
        guard let url = URL(string: "\(baseUrl)/api/programs/day/\(dayId)/update/") else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_email": userEmail,
            "day_type": dayType
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        // Response contains the updated program, caller will handle UI update
    }

    /// Reorder exercises within a program day
    /// PATCH /api/programs/day/{dayId}/reorder-exercises/
    func reorderProgramExercises(dayId: Int, exerciseOrder: [Int], userEmail: String) async throws -> ProgramDay {
        guard let url = URL(string: "\(baseUrl)/api/programs/day/\(dayId)/reorder-exercises/") else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_email": userEmail,
            "exercise_order": exerciseOrder
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responsePayload = try decoder.decode(MarkDayCompleteResponse.self, from: data)
        return responsePayload.day
    }

    func activateProgram(programId: Int, userEmail: String) async throws -> TrainingProgram {
        guard let url = URL(string: "\(baseUrl)/api/programs/\(programId)/activate/") else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["user_email": userEmail]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responsePayload = try decoder.decode(ProgramResponse.self, from: data)
        guard let program = responsePayload.program else {
            throw NetworkError.invalidResponse
        }
        return program
    }

    /// Deactivate a program and activate the next available one
    /// - Parameters:
    ///   - programId: The program ID to deactivate
    ///   - userEmail: The user's email
    /// - Returns: Tuple of (deactivated program, new active program or nil)
    func deactivateProgram(programId: Int, userEmail: String) async throws -> (deactivated: TrainingProgram, newActive: TrainingProgram?) {
        guard let url = URL(string: "\(baseUrl)/api/programs/\(programId)/deactivate/") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["user_email": userEmail]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responsePayload = try decoder.decode(DeactivateProgramResponse.self, from: data)
        return (responsePayload.deactivatedProgram, responsePayload.newActiveProgram)
    }

    /// Add a new day (rest or workout) to all weeks in the program
    /// - Parameters:
    ///   - programId: The program ID
    ///   - dayType: "rest" or "workout"
    ///   - position: Optional 0-indexed position where to insert (default: end)
    ///   - userEmail: The user's email
    /// - Returns: The updated TrainingProgram with the new day added to each week
    func addProgramDay(programId: Int, dayType: String, position: Int? = nil, userEmail: String) async throws -> TrainingProgram {
        guard let url = URL(string: "\(baseUrl)/api/programs/\(programId)/add-day/") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "user_email": userEmail,
            "day_type": dayType
        ]
        if let position = position {
            body["position"] = position
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responsePayload = try decoder.decode(ProgramResponse.self, from: data)
        guard let program = responsePayload.program else {
            throw NetworkError.invalidResponse
        }
        return program
    }

    /// Add exercises to a program day. If the day is a rest day, it will be
    /// converted to a workout day with proper naming (e.g., "Workout D").
    /// - Parameters:
    ///   - dayId: The program day ID
    ///   - exercises: Array of exercises to add with their details
    ///   - userEmail: The user's email
    /// - Returns: The updated ProgramDay with the added exercises
    func addExercisesToDay(
        dayId: Int,
        exercises: [(exerciseId: Int, exerciseName: String, targetSets: Int, targetReps: Int)],
        userEmail: String
    ) async throws -> ProgramDay {
        guard let url = URL(string: "\(baseUrl)/api/programs/day/\(dayId)/add-exercises/") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let exercisesArray = exercises.map { ex -> [String: Any] in
            return [
                "exercise_id": ex.exerciseId,
                "exercise_name": ex.exerciseName,
                "target_sets": ex.targetSets,
                "target_reps": ex.targetReps
            ]
        }

        let body: [String: Any] = [
            "user_email": userEmail,
            "exercises": exercisesArray
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responsePayload = try decoder.decode(ProgramDayResponse.self, from: data)
        guard let day = responsePayload.day else {
            throw NetworkError.invalidResponse
        }
        return day
    }

    /// Update exercise targets (sets and/or reps) for a specific exercise instance
    func updateExerciseTargets(
        exerciseInstanceId: Int,
        targetSets: Int?,
        targetReps: Int?,
        userEmail: String
    ) async throws {
        guard let url = URL(string: "\(baseUrl)/api/programs/exercise/\(exerciseInstanceId)/targets/") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["user_email": userEmail]
        if let sets = targetSets {
            body["target_sets"] = sets
        }
        if let reps = targetReps {
            body["target_reps"] = reps
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

}
