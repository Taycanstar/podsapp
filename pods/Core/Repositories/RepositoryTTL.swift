import Foundation

/// Helper describing refresh policies for repositories.
struct RepositoryTTL {
    static let profile: TimeInterval = 5 * 60
    static let subscription: TimeInterval = 5 * 60
    static let foodFeed: TimeInterval = 2 * 60
    static let dayLogs: TimeInterval = 15  // Reduced from 60s to 15s for better date change responsiveness
    static let health: TimeInterval = 5 * 60
    static let combinedLogs: TimeInterval = 2 * 60
    static let meals: TimeInterval = 2 * 60
    static let recipes: TimeInterval = 5 * 60
    static let savedMeals: TimeInterval = 5 * 60
    static let userFoods: TimeInterval = 2 * 60
    static let recentFoodLogs: TimeInterval = 30  // Short TTL since this changes frequently
    static let customWorkouts: TimeInterval = 5 * 60
    static let workoutContext: TimeInterval = 15 * 60
}
