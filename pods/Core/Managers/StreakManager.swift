//
//  StreakManager.swift
//  pods
//
//  Created by Dimi Nunez on 7/15/25.
//

//
//  StreakManager.swift
//  Pods
//
//  Created by Dimi Nunez on 7/11/25.
//

import Foundation

class StreakManager {
    static let shared = StreakManager()
    
    private let networkManager = NetworkManagerTwo.shared
    
    private init() {}
    
    /// Update user streak when any activity is logged
    /// - Parameter activityDate: The date of the activity (defaults to today)
    func updateStreak(activityDate: Date = Date()) {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            print("⚠️ StreakManager: No user email found")
            return
        }
        
        print("🔥 StreakManager: Updating streak for activity on \(activityDate)")
        
        // Call the backend to update the streak
        updateStreakOnServer(userEmail: userEmail, activityDate: activityDate) { result in
            switch result {
            case .success(let streakData):
                print("✅ StreakManager: Successfully updated streak - Current: \(streakData.currentStreak), Longest: \(streakData.longestStreak)")
                
                // Post notification to refresh UI components that display streaks
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("StreakUpdatedNotification"),
                        object: streakData
                    )
                }
                
            case .failure(let error):
                print("❌ StreakManager: Failed to update streak - \(error.localizedDescription)")
            }
        }
    }
    
    /// Update streak on the server
    /// - Parameters:
    ///   - userEmail: User's email address
    ///   - activityDate: Date of the activity
    ///   - completion: Result callback with streak data or error
    private func updateStreakOnServer(
        userEmail: String,
        activityDate: Date,
        completion: @escaping (Result<UserStreakData, Error>) -> Void
    ) {
        let urlString = "\(networkManager.baseUrl)/update-streak/"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkManagerTwo.NetworkError.invalidURL))
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let activityDateString = dateFormatter.string(from: activityDate)
        
        let parameters: [String: Any] = [
            "user_email": userEmail,
            "activity_date": activityDateString
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
                    completion(.failure(NetworkManagerTwo.NetworkError.invalidResponse))
                }
                return
            }
            
            // Check if there's an error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NetworkManagerTwo.NetworkError.serverError(message: errorMessage)))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                let streakData = try decoder.decode(UserStreakData.self, from: data)
                
                DispatchQueue.main.async {
                    completion(.success(streakData))
                }
                
            } catch {
                print("❌ StreakManager: Decoding error - \(error)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response data: \(json)")
                }
                DispatchQueue.main.async {
                    completion(.failure(NetworkManagerTwo.NetworkError.decodingError))
                }
            }
        }.resume()
    }
}

// MARK: - Data Models

struct UserStreakData: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let streakAsset: String
    let lastActivityDate: String?
    let streakStartDate: String?
    
    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case streakAsset = "streak_asset"
        case lastActivityDate = "last_activity_date"
        case streakStartDate = "streak_start_date"
    }
} 