//
//  VoiceToolService.swift
//  pods
//
//  Created by Dimi Nunez on 12/18/25.
//


//
//  VoiceToolService.swift
//  pods
//
//  Created by Claude on 12/17/25.
//

import Foundation

/// Service for executing voice mode tool calls via the backend API.
/// This service communicates with `/agent/voice-tool/` to execute tools
/// like activity logging, data queries, and goal updates during voice sessions.
@MainActor
final class VoiceToolService {
    static let shared = VoiceToolService()
    private let networkManager = NetworkManager()

    private init() {}

    // MARK: - Activity Logging

    /// Log an activity via the backend
    func logActivity(
        activityName: String,
        activityType: String?,
        durationMinutes: Int,
        caloriesBurned: Int?,
        notes: String?
    ) async throws -> VoiceToolResult {
        var arguments: [String: Any] = [
            "activity_name": activityName,
            "duration_minutes": durationMinutes
        ]
        if let activityType = activityType {
            arguments["activity_type"] = activityType
        }
        if let caloriesBurned = caloriesBurned {
            arguments["calories_burned"] = caloriesBurned
        }
        if let notes = notes {
            arguments["notes"] = notes
        }

        return try await executeVoiceTool(toolName: "log_activity", arguments: arguments)
    }

    // MARK: - Data Queries

    /// Execute a query tool via the backend
    func executeQuery(queryType: VoiceQueryType, args: [String: Any]) async throws -> VoiceToolResult {
        return try await executeVoiceTool(toolName: queryType.rawValue, arguments: args)
    }

    // MARK: - Goal Updates

    /// Update user goals via the backend
    func updateGoals(goals: [String: Int]) async throws -> VoiceToolResult {
        var arguments: [String: Any] = [:]
        for (key, value) in goals {
            arguments[key] = value
        }
        return try await executeVoiceTool(toolName: "update_goals", arguments: arguments)
    }

    // MARK: - Private

    /// Execute a voice tool via the backend `/agent/voice-tool/` endpoint
    private func executeVoiceTool(toolName: String, arguments: [String: Any]) async throws -> VoiceToolResult {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            return VoiceToolResult.failure(error: "No user email found")
        }

        let baseUrl = networkManager.baseUrl
        guard let url = URL(string: "\(baseUrl)/agent/voice-tool/") else {
            return VoiceToolResult.failure(error: "Invalid URL")
        }

        // Build request body
        var body: [String: Any] = [
            "user_email": userEmail,
            "tool_name": toolName,
            "arguments": arguments
        ]

        // Add timezone offset for date-sensitive queries
        let timezoneOffset = TimeZone.current.secondsFromGMT() / 60
        body["timezone_offset_minutes"] = timezoneOffset

        // Add target date (today)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        body["target_date"] = formatter.string(from: Date())

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("🎤 [VOICE TOOL SERVICE] Executing \(toolName) with args: \(arguments)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return VoiceToolResult.failure(error: "Invalid response")
        }

        if httpResponse.statusCode != 200 {
            print("❌ [VOICE TOOL SERVICE] Server returned status \(httpResponse.statusCode)")
            if let responseStr = String(data: data, encoding: .utf8) {
                print("❌ [VOICE TOOL SERVICE] Response body: \(responseStr.prefix(500))")
            }
            return VoiceToolResult.failure(error: "Server error: \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return VoiceToolResult.failure(error: "Invalid JSON response")
        }

        print("✅ [VOICE TOOL SERVICE] Response type: \(json["type"] ?? "unknown")")

        // Parse the response
        let responseType = json["type"] as? String ?? "unknown"

        if responseType == "error" {
            let errorMessage = json["error"] as? String ?? "Unknown error"
            return VoiceToolResult.failure(error: errorMessage)
        }

        // Extract data based on response type
        var resultData: [String: Any] = ["type": responseType]

        switch responseType {
        case "activity_logged":
            if let activity = json["activity"] as? [String: Any] {
                resultData["activity"] = activity
            }
        case "data_response":
            if let data = json["data"] as? [String: Any] {
                resultData["data"] = data
            }
        case "goals_updated":
            if let goals = json["goals"] as? [String: Any] {
                resultData["goals"] = goals
            }
            if let message = json["message"] as? String {
                resultData["message"] = message
            }
        case "food_logged":
            if let food = json["food"] as? [String: Any] {
                resultData["food"] = food
            }
            if let mealItems = json["meal_items"] as? [[String: Any]] {
                resultData["meal_items"] = mealItems
            }
        case "needs_clarification":
            if let options = json["options"] as? [[String: Any]] {
                resultData["options"] = options
            }
            if let question = json["question"] as? String {
                resultData["question"] = question
            }
        default:
            // Copy all data from response
            for (key, value) in json where key != "type" {
                resultData[key] = value
            }
        }

        return VoiceToolResult.success(type: responseType, data: resultData)
    }
}
