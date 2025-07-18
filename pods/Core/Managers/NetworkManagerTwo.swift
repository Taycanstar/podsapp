//
//  NetworkManagerTwo.swift
//  Pods
//
//  Created by Dimi Nunez on 5/22/25.
//

import Foundation
import SwiftUI

class NetworkManagerTwo {
    // Shared instance (singleton)
    static let shared = NetworkManagerTwo()
    
    

let baseUrl = "https://humuli-2b3070583cda.herokuapp.com"
//   let baseUrl = "http://192.168.1.92:8000"
// let baseUrl = "http://172.20.10.4:8000"
    
    // Network errors - scoped to NetworkManagerTwo
    enum NetworkError: LocalizedError {
        case invalidURL
        case requestFailed(statusCode: Int)
        case invalidResponse
        case decodingError
        case serverError(message: String)
        // Add any other specific error cases you might need
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .requestFailed(let statusCode): return "Request failed with status code: \(statusCode)"
            case .invalidResponse: return "Invalid response from server"
            case .decodingError: return "Failed to decode response"
            case .serverError(let message): return message // Use the message directly
            }
        }
    }
    
    struct ErrorResponse: Codable {
        let error: String
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
    
    // MARK: - Barcode Lookup
    
    /// Look up food by barcode (UPC/EAN code)
    /// - Parameters:
    ///   - barcode: The barcode string
    ///   - userEmail: User's email address
    ///   - imageData: Optional base64 image data from the photo taken during barcode scanning
    ///   - mealType: Type of meal (Breakfast, Lunch, Dinner, Snack)
    ///   - shouldLog: Whether to log the lookup
    ///   - completion: Result callback with Food object or error
    func lookupFoodByBarcode(
        barcode: String,
        userEmail: String,
        imageData: String? = nil,
        mealType: String = "Lunch",
        shouldLog: Bool = false,
        completion: @escaping (Result<BarcodeLookupResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/lookup_food_by_barcode/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Create request body
        var parameters: [String: Any] = [
            "user_email": userEmail,
            "barcode": barcode,
            "meal_type": mealType,
            "should_log": shouldLog
        ]
        
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
                
                // Try to parse as BarcodeLookupResponse
                let response = try decoder.decode(BarcodeLookupResponse.self, from: data)
                
                DispatchQueue.main.async {
                    print("✅ Successfully looked up food by barcode: \(response.food.displayName), foodLogId: \(response.foodLogId)")
                    completion(.success(response))
                }
                
            } catch {
                print("❌ Decoding error in barcode lookup: \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
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
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
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
                        
                        // Extract nutrition goals
                        var calories: Double = 0
                        var protein: Double = 0
                        var carbs: Double = 0
                        var fat: Double = 0
                        
                        print("🔍 DEBUG: Looking for nutrition goals in JSON: \(json.keys)")
                        
                        // Try different JSON structures that might contain the nutrition goals
                        if let nutritionGoals = json["nutrition_goals"] as? [String: Any] {
                            print("✅ Found nutrition_goals key")
                            calories = nutritionGoals["calories"] as? Double ?? 0
                            protein = nutritionGoals["protein"] as? Double ?? 0
                            carbs = nutritionGoals["carbohydrates"] as? Double ?? 0
                            fat = nutritionGoals["fats"] as? Double ?? 0
                        } else if let dailyGoals = json["daily_goals"] as? [String: Any] {
                            print("✅ Found daily_goals key: \(dailyGoals)")
                            calories = dailyGoals["calories"] as? Double ?? 0
                            protein = dailyGoals["protein"] as? Double ?? 0
                            carbs = dailyGoals["carbs"] as? Double ?? 0
                            fat = dailyGoals["fat"] as? Double ?? 0
                        } else if let goals = json["goals"] as? [String: Any] {
                            print("✅ Found goals key")
                            calories = goals["calories"] as? Double ?? 0
                            protein = goals["protein"] as? Double ?? 0
                            carbs = goals["carbs"] as? Double ?? 0
                            fat = goals["fat"] as? Double ?? 0
                        } else {
                            print("⚠️ Could not find nutrition goals in JSON structure")
                        }
                        
                        // Extract BMR and TDEE if available
                        let bmr = (json["bmr"] as? Double) ?? 0
                        let tdee = (json["tdee"] as? Double) ?? 0
                        
                        // Extract insights if available
                        var metabolismInsights: InsightDetails? = nil
                        var nutritionInsights: InsightDetails? = nil
                        
                        if let insights = json["insights"] as? [String: Any] {
                            if let metabolism = insights["metabolism"] as? [String: Any] {
                                let metabolismData = try? JSONSerialization.data(withJSONObject: metabolism)
                                metabolismInsights = metabolismData.flatMap { try? JSONDecoder().decode(InsightDetails.self, from: $0) }
                            }
                            if let nutrition = insights["nutrition"] as? [String: Any] {
                                let nutritionData = try? JSONSerialization.data(withJSONObject: nutrition)
                                nutritionInsights = nutritionData.flatMap { try? JSONDecoder().decode(InsightDetails.self, from: $0) }
                            }
                        }
                        
                        // Create nutrition goals object
                        let goals = NutritionGoals(
                            bmr: bmr,
                            tdee: tdee,
                            calories: calories,
                            protein: protein,
                            carbs: carbs,
                            fat: fat,
                            metabolismInsights: metabolismInsights,
                            nutritionInsights: nutritionInsights
                        )
                        
                        // Save goals to UserDefaults for other parts of the app
                        UserGoalsManager.shared.dailyGoals = DailyGoals(
                            calories: Int(calories),
                            protein: Int(protein),
                            carbs: Int(carbs),
                            fat: Int(fat)
                        )
                        
                        print("📝 DEBUG: Saving to UserGoalsManager: Calories=\(Int(calories)), Protein=\(Int(protein))g, Carbs=\(Int(carbs))g, Fat=\(Int(fat))g")
                        
                        print("✅ Successfully parsed nutrition goals: Calories=\(calories), Protein=\(protein)g, Carbs=\(carbs)g, Fat=\(fat)g")
                        print("📊 BMR=\(bmr), TDEE=\(tdee)")
                        
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
                        print("✅ Successfully decoded with standard ISO8601: '\(dateString)'")
                        return date
                    }
                    
                    // With fractional seconds
                    iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = iso8601.date(from: dateString) {
                        print("✅ Successfully decoded with ISO8601 + fractional seconds: '\(dateString)'")
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
    ///   - notes: Optional notes about the water intake
    ///   - completion: Result callback with the logged water data or error
    func logWater(
        userEmail: String,
        waterOz: Double,
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
        
        let parameters: [String: Any] = [
            "user_email": userEmail,
            "water_oz": waterOz,
            "notes": notes
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("💧 Logging water: \(waterOz) oz for user: \(userEmail)")
        
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
                    print("🔍 Raw API Response Keys: \(json.keys.sorted())")
                    print("🔍 Contains workout_profile: \(json.keys.contains("workout_profile"))")
                    if let workoutProfile = json["workout_profile"] as? [String: Any] {
                        print("🔍 Workout profile keys: \(workoutProfile.keys.sorted())")
                    }
                }
                
                let response = try decoder.decode(ProfileDataResponse.self, from: data)
                DispatchQueue.main.async { 
                    print("✅ Successfully fetched profile data for: \(response.username)")
                    print("✅ Workout profile present: \(response.workoutProfile != nil)")
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

    // MARK: - Nutrition Goals

    /// Update a user's nutrition goals
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - caloriesGoal: Daily calorie goal
    ///   - proteinGoal: Daily protein goal in grams
    ///   - carbsGoal: Daily carbs goal in grams
    ///   - fatGoal: Daily fat goal in grams
    ///   - completion: Result callback with updated goals or error
    func updateNutritionGoals(
        userEmail: String,
        caloriesGoal: Double,
        proteinGoal: Double,
        carbsGoal: Double,
        fatGoal: Double,
        completion: @escaping (Result<NutritionGoalsResponse, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/update-nutrition-goals/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        // Create request body
        let parameters: [String: Any] = [
            "user_email": userEmail,
            "calories_goal": caloriesGoal,
            "protein_goal": proteinGoal,
            "carbs_goal": carbsGoal,
            "fat_goal": fatGoal
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
                print("🔍 FRONTEND DEBUG - Raw response string:")
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
                print("🔍 FRONTEND DEBUG - Parsed JSON keys: \(json.keys)")
                if let savedMealsArray = json["saved_meals"] as? [[String: Any]] {
                    print("🔍 FRONTEND DEBUG - saved_meals array count: \(savedMealsArray.count)")
                } else {
                    print("🔍 FRONTEND DEBUG - saved_meals is not an array or missing")
                }
                if let hasMore = json["has_more"] {
                    print("🔍 FRONTEND DEBUG - has_more type: \(type(of: hasMore)), value: \(hasMore)")
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

}



