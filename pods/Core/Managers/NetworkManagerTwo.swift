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
    
    

//    let baseUrl = "https://humuli-2b3070583cda.herokuapp.com"
  let baseUrl = "http://192.168.1.92:8000"
    // let baseUrl = "http://172.20.10.4:8000"
    
    // Network errors
    enum NetworkError: Error, LocalizedError {
        case invalidURL
        case noData
        case decodingError
        case serverError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .noData: return "No data received"
            case .decodingError: return "Failed to decode response"
            case .serverError(let message): return "Server error: \(message)"
            }
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
                    completion(.failure(NetworkError.noData))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(errorMessage)))
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
                    completion(.failure(NetworkError.noData))
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
                    completion(.failure(NetworkError.noData))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(errorMessage)))
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
                    completion(.failure(NetworkError.noData))
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
                    completion(.failure(NetworkError.noData))
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
                            completion(.failure(NetworkError.serverError(errorMessage)))
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
                    completion(.failure(NetworkError.noData))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                print("❌ Server error: \(errorMessage)")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(errorMessage)))
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
                    completion(.failure(NetworkError.noData))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                print("❌ Server error logging height: \(errorMessage)")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(errorMessage)))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
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
        
        let parameters: [String: Any] = [
            "user_email": userEmail,
            "weight_kg": weightKg,
            "notes": notes
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("⚖️ Logging weight: \(weightKg) kg for user: \(userEmail)")
        
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
                    completion(.failure(NetworkError.noData))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                print("❌ Server error logging weight: \(errorMessage)")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.serverError(errorMessage)))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                let response = try decoder.decode(WeightLogResponse.self, from: data)
                
                DispatchQueue.main.async {
                    print("✅ Successfully logged weight: \(response.weightKg) kg")
                    completion(.success(response))
                }
            } catch {
                print("❌ Error decoding weight log response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response data: \(responseString)")
                }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}



