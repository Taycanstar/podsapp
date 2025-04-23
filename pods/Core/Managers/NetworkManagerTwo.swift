//
//  NetworkManagerTwo.swift
//  Pods
//
//  Created by Dimi Nunez on 5/22/25.
//

import Foundation

class NetworkManagerTwo {
    // Shared instance (singleton)
    static let shared = NetworkManagerTwo()
    
    

   //  let baseUrl = "https://humuli-2b3070583cda.herokuapp.com"
  let baseUrl = "http://192.168.1.92:8000"
    // let baseUrl = "http://172.20.10.4:8000"
    
    // Network errors
    enum NetworkError: Error {
        case invalidURL
        case noData
        case decodingError
        case serverError(String)
    }
    
    // MARK: - Barcode Lookup
    
    /// Look up food by barcode (UPC/EAN code)
    /// - Parameters:
    ///   - barcode: The barcode string
    ///   - userEmail: User's email address
    ///   - imageData: Optional base64 image data from the photo taken during barcode scanning
    ///   - mealType: Type of meal (Breakfast, Lunch, Dinner, Snack)
    ///   - completion: Result callback with Food object or error
    func lookupFoodByBarcode(
        barcode: String,
        userEmail: String,
        imageData: String? = nil,
        mealType: String = "Lunch",
        completion: @escaping (Result<Food, Error>) -> Void
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
            "meal_type": mealType
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
                
                // Try to parse the food response
                let food = try decoder.decode(Food.self, from: data)
                
                DispatchQueue.main.async {
                    print("✅ Successfully looked up food by barcode: \(food.displayName)")
                    completion(.success(food))
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
                    completion(.failure(error))
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
        guard let url = URL(string: "\(baseUrl)/mark_onboarding_completed/") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        let parameters: [String: Any] = [
            "email": email
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
        
        print("🔄 Sending request to mark onboarding completed for user: \(email)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    print("❌ Network error marking onboarding completed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    print("❌ No data received from server when marking onboarding completed")
                    completion(.failure(NetworkError.noData))
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool {
                    DispatchQueue.main.async {
                        if success {
                            print("✅ Successfully marked onboarding as completed on server for user: \(email)")
                            completion(.success(true))
                        } else {
                            print("❌ Server returned failure when marking onboarding completed")
                            completion(.success(false))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        print("❌ Invalid server response when marking onboarding completed")
                        completion(.failure(NetworkError.decodingError))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ Error parsing response when marking onboarding completed: \(error)")
                    completion(.failure(NetworkError.decodingError))
                }
            }
        }.resume()
    }
}
