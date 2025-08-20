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

@MainActor
class StreakManager: ObservableObject {
    static let shared = StreakManager()
    
    private let networkManager = NetworkManagerTwo.shared
    
    // Published properties for immediate UI updates
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var streakAsset: String = "streaks1"
    @Published var lastActivityDate: Date?
    @Published var streakStartDate: Date?
    
    // UserDefaults keys for persistence
    private let currentStreakKey = "cached_current_streak"
    private let longestStreakKey = "cached_longest_streak"
    private let streakAssetKey = "cached_streak_asset"
    private let lastActivityDateKey = "cached_last_activity_date"
    private let streakStartDateKey = "cached_streak_start_date"
    private let lastSyncDateKey = "streak_last_sync_date"
    
    private init() {
        loadCachedStreakData()
    }
    
    /// Load cached streak data immediately from UserDefaults
    private func loadCachedStreakData() {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        
        currentStreak = UserDefaults.standard.integer(forKey: "\(currentStreakKey)_\(userEmail)")
        longestStreak = UserDefaults.standard.integer(forKey: "\(longestStreakKey)_\(userEmail)")
        streakAsset = UserDefaults.standard.string(forKey: "\(streakAssetKey)_\(userEmail)") ?? "streaks1"
        
        if let lastActivityTimestamp = UserDefaults.standard.object(forKey: "\(lastActivityDateKey)_\(userEmail)") as? Date {
            lastActivityDate = lastActivityTimestamp
        }
        
        if let streakStartTimestamp = UserDefaults.standard.object(forKey: "\(streakStartDateKey)_\(userEmail)") as? Date {
            streakStartDate = streakStartTimestamp
        }
        
        print("📱 StreakManager: Loaded cached streak data - Current: \(currentStreak), Longest: \(longestStreak), Asset: \(streakAsset)")
    }
    
    /// Save streak data to UserDefaults for persistence
    private func saveStreakDataToCache(_ streakData: UserStreakData) {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        
        UserDefaults.standard.set(streakData.currentStreak, forKey: "\(currentStreakKey)_\(userEmail)")
        UserDefaults.standard.set(streakData.longestStreak, forKey: "\(longestStreakKey)_\(userEmail)")
        UserDefaults.standard.set(streakData.streakAsset, forKey: "\(streakAssetKey)_\(userEmail)")
        
        if let lastActivityDateString = streakData.lastActivityDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: lastActivityDateString) {
                UserDefaults.standard.set(date, forKey: "\(lastActivityDateKey)_\(userEmail)")
            }
        }
        
        if let streakStartDateString = streakData.streakStartDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: streakStartDateString) {
                UserDefaults.standard.set(date, forKey: "\(streakStartDateKey)_\(userEmail)")
            }
        }
        
        UserDefaults.standard.set(Date(), forKey: "\(lastSyncDateKey)_\(userEmail)")
        
        print("💾 StreakManager: Saved streak data to cache - Current: \(streakData.currentStreak), Longest: \(streakData.longestStreak)")
    }
    
    /// Update published properties and save to cache
    private func updateLocalStreakData(_ streakData: UserStreakData) {
        // Update published properties (already on main actor)
        self.currentStreak = streakData.currentStreak
        self.longestStreak = streakData.longestStreak
        self.streakAsset = streakData.streakAsset
        
        // Update dates if available
        if let lastActivityDateString = streakData.lastActivityDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            self.lastActivityDate = formatter.date(from: lastActivityDateString)
        }
        
        if let streakStartDateString = streakData.streakStartDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            self.streakStartDate = formatter.date(from: streakStartDateString)
        }
        
        // Save to cache for next app launch
        self.saveStreakDataToCache(streakData)
        
        // Post notification for any views still using the old pattern
        NotificationCenter.default.post(
            name: NSNotification.Name("StreakUpdatedNotification"),
            object: streakData
        )
    }
    
    /// Clear cached data when user logs out
    func clearCachedData() {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        
        UserDefaults.standard.removeObject(forKey: "\(currentStreakKey)_\(userEmail)")
        UserDefaults.standard.removeObject(forKey: "\(longestStreakKey)_\(userEmail)")
        UserDefaults.standard.removeObject(forKey: "\(streakAssetKey)_\(userEmail)")
        UserDefaults.standard.removeObject(forKey: "\(lastActivityDateKey)_\(userEmail)")
        UserDefaults.standard.removeObject(forKey: "\(streakStartDateKey)_\(userEmail)")
        UserDefaults.standard.removeObject(forKey: "\(lastSyncDateKey)_\(userEmail)")
        
        // Reset to defaults (already on main actor)
        currentStreak = 0
        longestStreak = 0
        streakAsset = "streaks1"
        lastActivityDate = nil
        streakStartDate = nil
        
        print("🧹 StreakManager: Cleared cached streak data")
    }
    
    /// Sync streak data from server (called by DataSyncService)
    func syncFromServer(streakData: UserStreakData) {
        updateLocalStreakData(streakData)
    }
    
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
            Task { @MainActor in
                switch result {
                case .success(let streakData):
                    print("✅ StreakManager: Successfully updated streak - Current: \(streakData.currentStreak), Longest: \(streakData.longestStreak)")
                    self.updateLocalStreakData(streakData)
                    
                case .failure(let error):
                    print("❌ StreakManager: Failed to update streak - \(error.localizedDescription)")
                }
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
                // First, let's check the raw JSON to debug the issue
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔍 StreakManager: Raw response data: \(json)")
                    
                    // Manual parsing as fallback
                    if let currentStreak = json["current_streak"] as? Int,
                       let longestStreak = json["longest_streak"] as? Int,
                       let streakAsset = json["streak_asset"] as? String {
                        
                        let streakData = UserStreakData(
                            currentStreak: currentStreak,
                            longestStreak: longestStreak,
                            streakAsset: streakAsset,
                            lastActivityDate: json["last_activity_date"] as? String,
                            streakStartDate: json["streak_start_date"] as? String
                        )
                        
                        DispatchQueue.main.async {
                            completion(.success(streakData))
                        }
                        return
                    }
                }
                
                // Try normal decoding
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