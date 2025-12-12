import Foundation
import Combine

struct AgentDailyMetricsPayload {
    let userEmail: String
    let date: Date
    var stepCount: Int?
    var sleepHours: Double?
    var sleepScore: Double?
    var restingHeartRate: Double?
    var hrvScore: Double?
    var recoveryScore: Double?
    var fatigueLevel: Int?
    var sorenessLevel: Int?
    var sorenessNotes: String?
    var painFlags: [String]?
    var hydrationOz: Double?
    var caloriesBurned: Double?
    var caloriesConsumed: Double?
    var macroTargets: [String: Double]?
    var macroActuals: [String: Double]?
    var calendarConstraints: [[String: AnyCodable]]?
    var equipmentAvailable: [String]?
    var readinessNotes: String?
    var walkingHeartRateAverage: Double?
    var sleepMetrics: [String: Any]?
    var respiratoryRate: Double?
    var skinTemperatureC: Double?

    func dictionary(dateFormatter: ISO8601DateFormatter) -> [String: Any] {
        var dict: [String: Any] = [
            "user_email": userEmail,
            "date": dateFormatter.string(from: date),
        ]
        dict["step_count"] = stepCount
        dict["sleep_hours"] = sleepHours
        dict["sleep_score"] = sleepScore
        dict["resting_heart_rate"] = restingHeartRate
        dict["hrv_score"] = hrvScore
        dict["recovery_score"] = recoveryScore
        dict["fatigue_level"] = fatigueLevel
        dict["soreness_level"] = sorenessLevel
        dict["soreness_notes"] = sorenessNotes
        dict["pain_flags"] = painFlags
        dict["hydration_oz"] = hydrationOz
        dict["calories_burned"] = caloriesBurned
        dict["calories_consumed"] = caloriesConsumed
        dict["macro_targets"] = macroTargets
        dict["macro_actuals"] = macroActuals
        dict["calendar_constraints"] = calendarConstraints?.map { item in
            item.mapValues { $0.value }
        }
        dict["equipment_available"] = equipmentAvailable
        dict["readiness_notes"] = readinessNotes
        dict["walking_heart_rate_average"] = walkingHeartRateAverage
        dict["sleep_metrics"] = sleepMetrics
        dict["respiratory_rate"] = respiratoryRate
        dict["skin_temperature_c"] = skinTemperatureC
        return dict.compactMapValues { $0 }
    }
}

struct AgentChatReply {
    let text: String
    let pendingLog: AgentPendingLog?
    let statusHint: AgentResponseHint
}

struct AgentLogCommitResult {
    let entryType: String
    let message: String?
    let payload: [String: Any]
}

enum AgentServiceError: Error {
    case invalidURL
    case missingUserEmail
    case decodingFailed
    case emptyResponse
}

final class AgentService {
    static let shared = AgentService()
    private let decoder: JSONDecoder
    private let isoFormatter: ISO8601DateFormatter

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        isoFormatter.timeZone = TimeZone.current  // Use device's local timezone, not UTC
    }

    private var baseURL: String { NetworkManagerTwo.shared.baseUrl }

    func syncDailyMetrics(payload: AgentDailyMetricsPayload, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/agent/daily-metrics/") else {
            completion(.failure(AgentServiceError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let body = payload.dictionary(dateFormatter: isoFormatter)
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                completion(.failure(AgentServiceError.emptyResponse))
                return
            }
            completion(.success(()))
        }.resume()
    }

    func fetchContext(userEmail: String, completion: @escaping (Result<AgentContextSnapshot, Error>) -> Void) {
        guard var components = URLComponents(string: "\(baseURL)/agent/context/") else {
            completion(.failure(AgentServiceError.invalidURL))
            return
        }
        components.queryItems = [
            URLQueryItem(name: "user_email", value: userEmail),
            URLQueryItem(name: "days", value: "7"),
        ]
        guard let url = components.url else {
            completion(.failure(AgentServiceError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(AgentServiceError.emptyResponse))
                return
            }
            do {
                let snapshot = try self.decoder.decode(AgentContextSnapshot.self, from: data)
                completion(.success(snapshot))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchPendingActions(userEmail: String, completion: @escaping (Result<[AgentPendingAction], Error>) -> Void) {
        guard var components = URLComponents(string: "\(baseURL)/agent/actions/") else {
            completion(.failure(AgentServiceError.invalidURL))
            return
        }
        components.queryItems = [URLQueryItem(name: "user_email", value: userEmail)]
        guard let url = components.url else {
            completion(.failure(AgentServiceError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(AgentServiceError.emptyResponse))
                return
            }
            do {
                let root = try JSONSerialization.jsonObject(with: data, options: [])
                guard
                    let dict = root as? [String: Any],
                    let rawActions = dict["actions"] as? [[String: Any]]
                else {
                    completion(.failure(AgentServiceError.decodingFailed))
                    return
                }
                let actionData = try JSONSerialization.data(withJSONObject: rawActions, options: [])
                let actions = try self.decoder.decode([AgentPendingAction].self, from: actionData)
                completion(.success(actions))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func decide(actionId: Int, approved: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/agent/actions/\(actionId)/decision/") else {
            completion(.failure(AgentServiceError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["approved": approved], options: [])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                completion(.failure(AgentServiceError.emptyResponse))
                return
            }
            completion(.success(()))
        }.resume()
    }

    func sendChat(
        userEmail: String,
        message: String,
        history: [[String: String]] = [],
        targetDate: Date = Date(),
        mealTypeHint: String = "Lunch",
        completion: @escaping (Result<AgentChatReply, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/agent/chat/") else {
            completion(.failure(AgentServiceError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let targetDateString = isoFormatter.string(from: targetDate)
        let timezoneOffsetMinutes = TimeZone.current.secondsFromGMT(for: targetDate) / 60

        let payload: [String: Any] = [
            "user_email": userEmail,
            "message": message,
            "history": history,
            "target_date": targetDateString,
            "timezone_offset_minutes": timezoneOffsetMinutes,
            "meal_type_hint": mealTypeHint,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(AgentServiceError.emptyResponse))
                return
            }
            do {
                let apiResponse = try self.decoder.decode(AgentChatAPIResponse.self, from: data)
                let reply = AgentChatReply(
                    text: apiResponse.response,
                    pendingLog: apiResponse.pendingLog,
                    statusHint: AgentResponseHint(rawValue: apiResponse.statusHint ?? "") ?? .chat
                )
                completion(.success(reply))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func confirmPendingLog(
        userEmail: String,
        pendingLogId: String,
        mealType: String,
        targetDate: Date,
        completion: @escaping (Result<AgentLogCommitResult, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/agent/chat/log/") else {
            completion(.failure(AgentServiceError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_email": userEmail,
            "pending_log_id": pendingLogId,
            "meal_type": mealType,
            "target_date": isoFormatter.string(from: targetDate),
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard
                let httpResponse = response as? HTTPURLResponse,
                200..<300 ~= httpResponse.statusCode,
                let data = data
            else {
                completion(.failure(AgentServiceError.decodingFailed))
                return
            }

            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard
                    let dict = jsonObject as? [String: Any],
                    let log = dict["log"] as? [String: Any],
                    let entryType = log["entry_type"] as? String
                else {
                    completion(.failure(AgentServiceError.decodingFailed))
                    return
                }
                let message = log["message"] as? String
                completion(.success(AgentLogCommitResult(entryType: entryType, message: message, payload: log)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

private struct AgentChatAPIResponse: Decodable {
    let response: String
    let pendingLog: AgentPendingLog?
    let statusHint: String?

    private enum CodingKeys: String, CodingKey {
        case response
        case pendingLog = "pending_log"
        case statusHint = "status_hint"
    }
}

final class AgentMetricsUploader {
    static let shared = AgentMetricsUploader()
    private let agentService = AgentService.shared
    private var lastSignature: String?

    @MainActor
    func uploadSnapshot(from healthVM: HealthKitViewModel, date: Date) {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail"), !userEmail.isEmpty else { return }

        let sleepTotal = Double(healthVM.sleepHours) + Double(healthVM.sleepMinutes) / 60.0
        let restingHR: Double? = healthVM.restingHeartRate
        let hrvScore: Double? = healthVM.heartRateVariability
        let walkingHR: Double? = healthVM.walkingHeartRateAverage > 0 ? healthVM.walkingHeartRateAverage : nil

        let payload = AgentDailyMetricsPayload(
            userEmail: userEmail,
            date: date,
            stepCount: Int(healthVM.stepCount),
            sleepHours: sleepTotal,
            sleepScore: nil,
            restingHeartRate: restingHR,
            hrvScore: hrvScore,
            recoveryScore: nil,
            fatigueLevel: nil,
            sorenessLevel: nil,
            sorenessNotes: nil,
            painFlags: nil,
            hydrationOz: healthVM.waterIntake,
            caloriesBurned: healthVM.totalEnergyBurned,
            caloriesConsumed: nil,
            macroTargets: nil,
            macroActuals: nil,
            calendarConstraints: nil,
            equipmentAvailable: nil,
            readinessNotes: nil,
            walkingHeartRateAverage: walkingHR
        )

        let signature = "\(userEmail)-\(date.timeIntervalSince1970)-\(payload.stepCount ?? 0)-\(payload.sleepHours ?? 0)"
        guard signature != lastSignature else { return }
        lastSignature = signature

        agentService.syncDailyMetrics(payload: payload) { result in
            if case let .failure(error) = result {
                print("⚠️ Failed to sync daily metrics: \(error.localizedDescription)")
            }
        }
    }
}
