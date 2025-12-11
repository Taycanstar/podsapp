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

    
    // let baseUrl = "https://humuli-2b3070583cda.herokuapp.com"

    // ### STAGING ###
    //let baseUrl = "https://humuli-staging-b3e9cef208dd.herokuapp.com"
    // ### LOCAL ###
    // let baseUrl = "http://192.168.1.92:8000"  
     let baseUrl = "http://172.20.10.4:8000"

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

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
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
        #if DEBUG
        print("[Network] GET /get-workout-session/\(sessionId)/?user_email=\(userEmail)")
        #endif
        var components = URLComponents(string: "\(baseUrl)/get-workout-session/\(sessionId)/")
        components?.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail)
        ]

        guard let url = components?.url else { throw NetworkError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)

        #if DEBUG
        if let http = response as? HTTPURLResponse {
            print("[Network] ← status=\(http.statusCode) bytes=\(data.count)")
        }
        #endif

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
        print("🌐 Barcode lookup endpoint: \(endpoint) (NutritionixOnly=\(useNutritionixOnly))")
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
        
        // Log what we're sending to server
        print("🔍 Looking up barcode: \(barcode) for user: \(userEmail)")
        
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
                if let source = json["source"] as? String {
                    print("🍽️ Server barcode source: \(source)")
                }
                if let errorMessage = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.serverError(message: errorMessage)))
                    }
                    return
                }

                if let response = Self.makeFallbackBarcodeResponse(from: json) {
                    DispatchQueue.main.async {
                        print("✅ Parsed barcode response (manual) for: \(response.food.displayName)")
                        completion(.success(response))
                    }
                    return
                }
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BarcodeLookupResponse.self, from: data)
                DispatchQueue.main.async {
                    print("✅ Successfully looked up food by barcode: \(response.food.displayName), foodLogId: \(response.foodLogId)")
                    completion(.success(response))
                }
            } catch {
                print("❌ Decoding error in barcode lookup: \(error)")
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

    // MARK: - Readiness Summary

    struct ReadinessSummaryResponse: Codable {
        let summary: String
        let date: String
    }

    struct SleepSummaryResponse: Codable {
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

    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
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
        let numberOfServings = doubleValue(dict["numberOfServings"]) ?? (dict["number_of_servings"] as? Double)
        let nutrients = ((dict["foodNutrients"] as? [[String: Any]]) ?? []).compactMap { makeNutrient(from: $0) }
        let measures = ((dict["foodMeasures"] as? [[String: Any]]) ?? []).compactMap { makeMeasure(from: $0) }

        var food = Food(
            fdcId: fdcId,
            description: description,
            brandOwner: dict["brandOwner"] as? String,
            brandName: dict["brandName"] as? String,
            servingSize: servingSize,
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

        print("🎤 Starting food audio transcription request")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🔴 Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // Log the response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Response: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                print("🔴 No data received.")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }

            do {
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Server response: \(responseString)")
                }
                
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], 
                   let text = json["text"] as? String {
                    print("🎙️ Received food transcription: \(text)")
                    DispatchQueue.main.async {
                        completion(.success(text))
                    }
                } else {
                    print("🔴 Unable to parse response")
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.decodingError))
                    }
                }
            } catch {
                print("🔴 Error parsing JSON: \(error)")
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
                print("✅ Audio transcription successful: \(transcribedText)")
                
                // Step 2: Generate AI macros from the transcribed text
                self.generateMacrosFromText(transcribedText, completion: completion)
                
            case .failure(let error):
                print("❌ Audio transcription failed: \(error.localizedDescription)")
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
        
        print("🧠 Generating AI macros for text: \(text)")
        
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
                        print("✅ Successfully generated food data: \(food.displayName)")
                        completion(.success(food))
                    }
                } else {
                    // Try the old way - maybe it's not nested
                    let food = try decoder.decode(Food.self, from: data)
                    
                    DispatchQueue.main.async {
                        print("✅ Successfully generated food data: \(food.displayName)")
                        completion(.success(food))
                    }
                }
            } catch {
                print("❌ Decoding error in AI macros generation: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
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
                    print("❌ Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from server")
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
            print("✅ Using server-compatible diet goal: \(serverDietGoal)")
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
            print("⚠️ No serverDietGoal found, mapping from dietGoal: \(userData.dietGoal) -> \(mappedDietGoal)")
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
            
            print("⬆️ Sending onboarding data to server with parameters: \(parameters)")
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from server")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                // For debugging, get the raw server response
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("🔍 Raw server response: \(rawResponse)")
                }
                
                // Attempt to parse the API response
                do {
                    // First try to check if there's an error message
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let errorMessage = json["error"] as? String {
                            print("❌ Server error processing onboarding data: \(errorMessage)")
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
                            print("⚠️ Could not find structured goals payload, falling back to legacy fields.")
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
                        
                        print("📝 DEBUG: Saving to UserGoalsManager: Calories=\(Int(goals.calories)), Protein=\(Int(goals.protein))g, Carbs=\(Int(goals.carbs))g, Fat=\(Int(goals.fat))g")
                        
                        print("✅ Successfully parsed nutrition goals: Calories=\(goals.calories), Protein=\(goals.protein)g, Carbs=\(goals.carbs)g, Fat=\(goals.fat)g")
                        print("📊 BMR=\(goals.bmr ?? 0), TDEE=\(goals.tdee ?? 0)")
                        
                        completion(.success(goals))
                    } else {
                        print("❌ Failed to parse JSON response")
                        completion(.failure(NetworkError.decodingError))
                    }
                } catch {
                    print("❌ JSON parsing error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
            task.resume()
        } catch {
            print("❌ JSON encoding error: \(error.localizedDescription)")
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
        
        print("📆 Fetching logs for date: \(dateString), include adjacent: \(includeAdjacent), timezone offset: \(timezoneOffset) minutes")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                print("❌ Server error: \(errorMessage)")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                
                // Use a more robust custom date decoding strategy
                decoder.dateDecodingStrategy = .custom { decoder -> Date in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // Debug the date string we're trying to parse
                    print("🔎 Attempting to decode date string: '\(dateString)'")
                    
                    // Handle empty strings
                    if dateString.isEmpty {
                        print("⚠️ Empty date string found, using current date")
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
                            print("✅ Successfully decoded with format '\(format)': '\(dateString)'")
                            return date
                        }
                    }
                    
                    // If all else fails, throw an error
                    throw DecodingError.dataCorruptedError(in: container, 
                                                          debugDescription: "Expected date string to be ISO8601-formatted.")
                }
                
                let response = try decoder.decode(LogsByDateResponse.self, from: data)
                print("✅ Successfully fetched \(response.logs.count) logs for date: \(dateString)")
                
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                print("❌ Decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response data: \(responseString)")
                }
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
        
        print("📏 Logging height: \(heightCm) cm for user: \(userEmail)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error logging height: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                print("❌ No data received when logging height")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                print("❌ Server error logging height: \(errorMessage)")
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
                    print("✅ Successfully logged height: \(response.heightCm) cm")
                    completion(.success(response))
                }
            } catch {
                print("❌ Error decoding height log response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response data: \(responseString)")
                }
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
        
        let dateString = date != nil ? " at \(date!)" : ""
        print("⚖️ Logging weight: \(weightKg) kg for user: \(userEmail)\(dateString)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error logging weight: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                print("❌ No data received when logging weight")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            // Check if there's an error response from server
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                print("❌ Server error logging weight: \(errorMessage)")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(WeightLogResponse.self, from: data)
                
                DispatchQueue.main.async {
                    print("✅ Successfully logged weight: \(response.weightKg) kg")
                    completion(.success(response))
                }
                
            } catch {
                print("❌ Decoding error logging weight: \(error)")
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
        
        print("🍎 Logging Apple Health weight: \(weightKg) kg with UUID: \(appleHealthUUID)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error logging Apple Health weight: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                print("❌ No data received when logging Apple Health weight")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            // Check if there's an error response from server
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                print("❌ Server error logging Apple Health weight: \(errorMessage)")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(WeightLogResponse.self, from: data)
                
                DispatchQueue.main.async {
                    print("✅ Successfully logged Apple Health weight: \(response.weightKg) kg")
                    completion(.success(response))
                }
                
            } catch {
                print("❌ Decoding error logging Apple Health weight: \(error)")
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
        
        print("💧 Logging water: \(waterOz) oz (\(originalAmount) in \(unit)) for user: \(userEmail)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error logging water: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                print("❌ No data received when logging water")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.invalidResponse))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                print("❌ Server error logging water: \(errorMessage)")
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
                    print("✅ Successfully logged water: \(response.waterOz) oz")
                    completion(.success(response))
                }
            } catch {
                print("❌ Error decoding water log response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response data: \(responseString)")
                }
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
                print("Error decoding HeightLogsResponse: \(error)")
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
                print("Error decoding WeightLogsResponse: \(error)")
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

        print("📊 Fetching profile data for user: \(userEmail)")

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
                // Use snake_case conversion since we have explicit CodingKeys
                
                // Debug: Print raw response to see what we're getting
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
               
                    if let workoutProfile = json["workout_profile"] as? [String: Any] {
                 
                    }
                }
                
                let response = try decoder.decode(ProfileDataResponse.self, from: data)
                DispatchQueue.main.async { 
             
                    completion(.success(response)) 
                }
            } catch {
                print("❌ Error decoding ProfileDataResponse: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔍 Full Response data: \(json)")
                }
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
                print("❌ Error decoding WorkoutProfilesResponse: \(error)")
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
                print("❌ Error decoding CreateWorkoutProfileResponse: \(error)")
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
                print("❌ Error decoding ActivateWorkoutProfileResponse: \(error)")
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
                print("❌ Error decoding WorkoutProfilesResponse: \(error)")
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
        
        print("🧠 Updating nutrition goals for user: \(userEmail)")
        
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
                    print("✅ Successfully updated nutrition goals")
                    completion(.success(response))
                }
                
            } catch {
                print("❌ Decoding error in update nutrition goals: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
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
        
        print("🧠 Generating optimized nutrition goals for user: \(userEmail)")
        
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
                    print("✅ Successfully generated nutrition goals")
                    completion(.success(response))
                }
                
            } catch {
                print("❌ Decoding error in generate nutrition goals: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
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
        
        print("📝 Updating food log \(logId) for user \(userEmail) with parameters: \(parameters)")
        
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
                    print("✅ Successfully updated food log \(logId) for user \(userEmail)")
                    completion(.success(response.food_log))
                }
                
            } catch {
                print("❌ Decoding error in update food log: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
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
        print("🌐 NetworkManagerTwo: updateMealLog called with logId: \(logId)")
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
        
        print("🍽️ Updating meal log \(logId) for user \(userEmail) with parameters: \(parameters)")
        
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
                    print("✅ Successfully updated meal log \(logId) for user \(userEmail)")
                    completion(.success(response.meal_log))
                }
                
            } catch {
                print("❌ Decoding error in update meal log: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
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
        
        print("💾 Saving \(itemType) with ID \(itemId) for user \(userEmail)")
        
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
                    print("✅ Successfully saved meal: \(response.message)")
                    completion(.success(response))
                }
                
            } catch {
                print("❌ Decoding error in save meal: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
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
        
        print("🗑️ Unsaving meal with ID \(savedMealId) for user \(userEmail)")
        
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
                    print("✅ Successfully unsaved meal: \(response.message)")
                    completion(.success(response))
                }
                
            } catch {
                print("❌ Decoding error in unsave meal: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
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
        
        print("📋 Fetching saved meals for user \(userEmail) (page \(page))")
        
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
            
            // Debug: Print raw data
            if let rawString = String(data: data, encoding: .utf8) {
              
                print(rawString)
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(message: errorMessage)))
                }
                return
            }
            
            // Debug: Parse JSON manually first
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
             
                if let savedMealsArray = json["saved_meals"] as? [[String: Any]] {

                } else {
 
                }
                if let hasMore = json["has_more"] {

                }
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
                
                print("🔍 FRONTEND DEBUG - About to decode SavedMealsResponse")
                let response = try decoder.decode(SavedMealsResponse.self, from: data)
                
                DispatchQueue.main.async {
                    print("✅ Successfully fetched \(response.savedMeals.count) saved meals")
                    completion(.success(response))
                }
                
            } catch {
                print("❌ Decoding error in get saved meals: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
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
        
        print("🔄 Updating weight log \(logId) for user: \(userEmail)")
        
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
                    print("✅ Successfully updated weight log")
                    completion(.success(response))
                }
            } catch {
                print("❌ Failed to decode updated weight log response: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
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
        
        print("🔄 Updating weight log for user: \(userEmail) with photo URL: \(photoUrl)")
        
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
                    print("✅ Successfully updated weight log with photo")
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
        
        print("🗑️ Deleting weight log with ID: \(logId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error deleting weight log: \(error.localizedDescription)")
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
                    print("✅ Successfully deleted weight log")
                    completion(.success(()))
                }
            } else {
                print("❌ Failed to delete weight log. Status code: \(httpResponse.statusCode)")
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
        
        print("🗑️ Deleting height log with ID: \(logId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error deleting height log: \(error.localizedDescription)")
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
                    print("✅ Successfully deleted height log")
                    completion(.success(()))
                }
            } else {
                print("❌ Failed to delete height log. Status code: \(httpResponse.statusCode)")
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
        
        print("🔄 Updating name for user: \(email) to: \(name)")
        
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
               let message = json["message"] as? String,
               let name = json["name"] as? String {
                DispatchQueue.main.async {
                    print("✅ Successfully updated name to: \(name) - \(message)")
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    print("❌ Invalid response format from server")
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
        
        print("🔄 Updating username for user: \(email) to: \(username)")
        
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
               let message = json["message"] as? String,
               let username = json["username"] as? String {
                DispatchQueue.main.async {
                    print("✅ Successfully updated username to: \(username) - \(message)")
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    print("❌ Invalid response format from server")
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
        
        print("🔄 Updating photo for user: \(email) to: \(photoUrl)")
        
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
               let message = json["message"] as? String,
               let photoUrl = json["photo_url"] as? String {
                DispatchQueue.main.async {
                    print("✅ Successfully updated profile photo to: \(photoUrl) - \(message)")
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    print("❌ Invalid response format from server")
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
        
        print("🔄 Uploading profile photo to Azure Blob Storage...")
        
        // Use NetworkManager's uploadFileToAzureBlob method
        NetworkManager().uploadFileToAzureBlob(
            containerName: containerName,
            blobName: blobName,
            fileData: imageData,
            contentType: "image/jpeg"
        ) { [weak self] success, url in
            if success, let imageUrl = url {
                print("✅ Profile photo uploaded successfully: \(imageUrl)")
                
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
        
        print("🔄 Checking username eligibility for user: \(email)")
        
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
                        print("✅ Username eligibility check successful. Can change: \(eligibilityResponse.canChangeUsername), Days remaining: \(eligibilityResponse.daysRemaining)")
                        completion(.success(eligibilityResponse))
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("❌ Failed to decode username eligibility response: \(error)")
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
        
        print("🔄 Checking name eligibility for user: \(email)")
        
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
                        print("✅ Name eligibility check successful. Can change: \(eligibilityResponse.canChangeName), Days remaining: \(eligibilityResponse.daysRemaining)")
                        completion(.success(eligibilityResponse))
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("❌ Failed to decode name eligibility response: \(error)")
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
        
        print("🔄 Updating workout preferences for user: \(email)")
        print("   └── Data: \(workoutData)")
        
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
                print("✅ Successfully updated workout preferences")
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                print("❌ Failed to update workout preferences: HTTP \(httpResponse.statusCode)")
                
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
        
        // DEBUG - Print what we're sending to the server
        print("⬆️ SENDING TO SERVER - analyzeMealOrActivity:")
        print("- description: \(description)")
        print("- meal type: \(mealType)")
        
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
                    message = "You’ve reached today’s free food scan limit. Upgrade to Humuli Pro for unlimited scans."
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
                    
                    // DEBUG - Print what we received from the server
                    if let responseData = try? JSONSerialization.data(withJSONObject: jsonResponse, options: .prettyPrinted),
                       let responseString = String(data: responseData, encoding: .utf8) {
                        print("⬇️ SERVER RESPONSE - analyzeMealOrActivity: \(responseString)")
                    }
                    
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
        
        print("🗑️ Deleting activity log ID: \(activityLogId) for user: \(userEmail)")
        
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
                    print("✅ Successfully deleted activity log ID: \(activityLogId)")
                    completion(.success(()))
                }
            } else {
                DispatchQueue.main.async {
                    print("❌ Failed to delete activity log. Status code: \(httpResponse.statusCode)")
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
        
        print("📱 Updating device token for user: \(userEmail)")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Device token update failed: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    print("✅ Device token updated successfully")
                    completion(.success(()))
                } else {
                    print("❌ Device token update failed with status: \(httpResponse.statusCode)")
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
        
        print("📝 Updating exercise notes for exercise \(exerciseId), user: \(userEmail)")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Exercise notes update failed: \(error.localizedDescription)")
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
                            print("✅ Exercise notes updated successfully")
                            completion(.success(json))
                        } else {
                            completion(.failure(NetworkError.decodingError))
                        }
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    print("❌ Exercise notes update failed with status: \(httpResponse.statusCode)")
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
        print("🌐 NetworkManagerTwo: updateFlexibilityPreferences called with email: '\(email)' (isEmpty: \(email.isEmpty))")
        
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
        
        print("🔧 NetworkManagerTwo: Sending parameters: \(parameters)")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters)
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Network error in updateFlexibilityPreferences: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from server")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    print("✅ Flexibility preferences updated successfully")
                    completion(.success(true))
                } else {
                    print("❌ Flexibility preferences update failed with status: \(httpResponse.statusCode)")
                    
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
            print("❌ Failed to encode flexibility preferences request: \(error)")
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
                    print("❌ Network error in getFlexibilityPreferences: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from server")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response")
                    completion(.failure(NetworkError.invalidResponse))
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    do {
                        let response = try JSONDecoder().decode(FlexibilityPreferencesResponse.self, from: data)
                        print("✅ Flexibility preferences loaded successfully")
                        completion(.success(response.preferences))
                    } catch {
                        print("❌ Failed to decode flexibility preferences response: \(error)")
                        completion(.failure(NetworkError.decodingError))
                    }
                } else {
                    print("❌ Get flexibility preferences failed with status: \(httpResponse.statusCode)")
                    
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
            print("❌ Failed to encode get flexibility preferences request: \(error)")
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

}
