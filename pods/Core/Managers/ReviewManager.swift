//
//  ReviewManager.swift
//  pods
//
//  Created by Dimi Nunez on 8/4/25.
//

//
//  ReviewManager.swift
//  Pods
//
//  Created for Humuli on 8/5/25.
//

import SwiftUI
import StoreKit

/// Manages in-app review requests following Apple's guidelines
/// Tracks milestones and ensures we don't over-prompt users
class ReviewManager: ObservableObject {
    static let shared = ReviewManager()
    
    // MARK: - UserDefaults Keys
    private let firstFoodDateKey = "review_first_food_date"
    private let totalFoodsLoggedKey = "review_total_foods_logged"
    private let reviewRequestDatesKey = "review_request_dates"
    private let hasShownFirstFoodReviewKey = "review_shown_first_food"
    private let hasShownEngagedReviewKey = "review_shown_engaged"
    private let hasShownRetentionReviewKey = "review_shown_retention"
    
    // MARK: - Properties
    @Published var totalFoodsLogged: Int = 0
    private var firstFoodDate: Date?
    private var reviewRequestDates: [Date] = []
    
    // Public accessors for debugging
    var debugFirstFoodDate: Date? { firstFoodDate }
    
    /// Public methods for debug UI to check milestone status
    func hasShownFirstFoodReview() -> Bool {
        return hasShownReview(for: .firstFood)
    }
    
    func hasShownEngagedReview() -> Bool {
        return hasShownReview(for: .engaged)
    }
    
    func hasShownRetentionReview() -> Bool {
        return hasShownReview(for: .retention)
    }
    
    // MARK: - Initialization
    private init() {
        loadPersistedData()
    }
    
    // MARK: - Public Methods
    
    /// Call this after a food is successfully logged
    func foodWasLogged() {
        totalFoodsLogged += 1
        saveTotalFoodsLogged()
        
        // Set first food date if not already set (for analytics/debugging)
        if firstFoodDate == nil {
            firstFoodDate = Date()
            saveFirstFoodDate()
        }
        
        // Simple check: Show review if user has never been shown one before
        checkAndRequestReviewIfNeeded()
    }
    
    /// Check if we should request a review - 3-milestone system with simplified milestone #1
    func checkAndRequestReviewIfNeeded() {
        // Check if we're under the 3-per-year limit (Apple's restriction)
        let recentRequests = reviewRequestDates.filter { daysSince($0) < 365 }
        if recentRequests.count >= 3 {
            print("📱 Skipping review request - already hit 3-per-year limit")
            return
        }
        
        // Milestone #1: Any food log (simplified) - if never shown any review before
        if !hasShownReview(for: .firstFood) {
            requestReview(for: .firstFood)
            return
        }
        
        // Milestone #2: Engaged user (14+ days, 10+ foods OR 7-day streak)
        if let firstFood = firstFoodDate,
           daysSince(firstFood) >= 14,
           !hasShownReview(for: .engaged) {
            
            let hasEnoughFoods = totalFoodsLogged >= 10
            let hasStreak = StreakManager.shared.currentStreak >= 7
            
            if hasEnoughFoods || hasStreak {
                requestReview(for: .engaged)
                return
            }
        }
        
        // Milestone #3: Retention (30+ days after engaged milestone)
        if hasShownReview(for: .engaged),
           let lastEngagedDate = getLastReviewDate(for: .engaged),
           daysSince(lastEngagedDate) >= 30,
           !hasShownReview(for: .retention) {
            
            requestReview(for: .retention)
        }
    }
    
    // MARK: - Private Methods
    
    /// Check if user has been shown any review before (simplified)
    func hasShownAnyReview() -> Bool {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        return UserDefaults.standard.bool(forKey: "review_shown_\(userEmail)")
    }
    
    /// Mark that user has been shown a review (simplified)
    private func markReviewShown() {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        UserDefaults.standard.set(true, forKey: "review_shown_\(userEmail)")
    }
    
    /// Request review from App Store (simplified)
    private func requestReview() {
        // Record the request
        reviewRequestDates.append(Date())
        saveReviewRequestDates()
        markReviewShown()
        
        // Log for analytics
        print("📱 Requesting App Store review after food logged")
        
        // Request review from the current window scene
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                print("❌ Could not find window scene for review request")
                return
            }
            
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: windowScene)
            } else {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }
    
    /// Request review for specific milestone (3-milestone system)
    private func requestReview(for milestone: ReviewMilestone) {
        // Record the request
        reviewRequestDates.append(Date())
        saveReviewRequestDates()
        
        // Mark both simplified tracking and milestone-specific tracking
        markReviewShown()  // Simplified tracking
        markReviewShown(for: milestone)  // Milestone-specific tracking
        
        // Log for analytics
        print("📱 Requesting App Store review for milestone: \(milestone.rawValue)")
        
        // Request review from the current window scene
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                print("❌ Could not find window scene for review request")
                return
            }
            
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: windowScene)
            } else {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadPersistedData() {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        
        totalFoodsLogged = UserDefaults.standard.integer(forKey: "\(totalFoodsLoggedKey)_\(userEmail)")
        
        if let firstFoodTimestamp = UserDefaults.standard.object(forKey: "\(firstFoodDateKey)_\(userEmail)") as? Date {
            firstFoodDate = firstFoodTimestamp
        }
        
        if let dates = UserDefaults.standard.array(forKey: "\(reviewRequestDatesKey)_\(userEmail)") as? [Date] {
            reviewRequestDates = dates
        }
    }
    
    private func saveTotalFoodsLogged() {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        UserDefaults.standard.set(totalFoodsLogged, forKey: "\(totalFoodsLoggedKey)_\(userEmail)")
    }
    
    private func saveFirstFoodDate() {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        UserDefaults.standard.set(firstFoodDate, forKey: "\(firstFoodDateKey)_\(userEmail)")
    }
    
    private func saveReviewRequestDates() {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        UserDefaults.standard.set(reviewRequestDates, forKey: "\(reviewRequestDatesKey)_\(userEmail)")
    }
    
    // MARK: - Milestone Tracking
    
    private func hasShownReview(for milestone: ReviewMilestone) -> Bool {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        let key = "\(milestone.userDefaultsKey)_\(userEmail)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    private func markReviewShown(for milestone: ReviewMilestone) {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        let key = "\(milestone.userDefaultsKey)_\(userEmail)"
        UserDefaults.standard.set(true, forKey: key)
    }
    
    private func getLastReviewDate(for milestone: ReviewMilestone) -> Date? {
        // Find the date when this milestone was shown
        // For simplicity, we'll use the review request dates
        guard hasShownReview(for: milestone) else { return nil }
        
        // Return the most recent review date as an approximation
        return reviewRequestDates.last
    }
    
    // MARK: - Utilities
    
    private func daysSince(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: Date())
        return components.day ?? 0
    }
}

// MARK: - Review Milestone Enum

private enum ReviewMilestone: String {
    case firstFood = "first_food"
    case engaged = "engaged_user"
    case retention = "retention"
    
    var userDefaultsKey: String {
        switch self {
        case .firstFood:
            return "review_shown_first_food"
        case .engaged:
            return "review_shown_engaged"
        case .retention:
            return "review_shown_retention"
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension ReviewManager {
    /// Force show review prompt for testing (only works in debug/TestFlight)
    func forceShowReview() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                print("❌ Could not find window scene for review request")
                return
            }
            
            print("🧪 DEBUG: Force showing review prompt")
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: windowScene)
            } else {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }
    
    /// Reset all review tracking for testing - ALWAYS AVAILABLE
    func resetAllTracking() {
        let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
        
        // Clear simplified tracking
        UserDefaults.standard.removeObject(forKey: "review_shown_\(userEmail)")
        
        // Clear legacy tracking (for backward compatibility)
        UserDefaults.standard.removeObject(forKey: "\(firstFoodDateKey)_\(userEmail)")
        UserDefaults.standard.removeObject(forKey: "\(totalFoodsLoggedKey)_\(userEmail)")
        UserDefaults.standard.removeObject(forKey: "\(reviewRequestDatesKey)_\(userEmail)")
        UserDefaults.standard.removeObject(forKey: "\(hasShownFirstFoodReviewKey)_\(userEmail)")
        UserDefaults.standard.removeObject(forKey: "\(hasShownEngagedReviewKey)_\(userEmail)")
        UserDefaults.standard.removeObject(forKey: "\(hasShownRetentionReviewKey)_\(userEmail)")
        
        totalFoodsLogged = 0
        firstFoodDate = nil
        reviewRequestDates = []
        
        print("🧹 DEBUG: Reset all review tracking (simplified + legacy)")
    }
    
    /// Force show review prompt for testing
    func forceShowReview() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                print("❌ Could not find window scene for review request")
                return
            }
            
            print("🧪 DEBUG: Force showing review prompt")
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: windowScene)
            } else {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }
}
#endif