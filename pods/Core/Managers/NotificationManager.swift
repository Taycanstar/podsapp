//
//  NotificationManager.swift
//  pods
//
//  Created by Dimi Nunez on 8/4/25.
//

import Foundation
import UserNotifications
import SwiftUI

/// Complete notification copy with rotation support
struct NotificationCopy {
    
    // ───────── Activity recognised (13 variations) ─────────
    static let activityTemplates: [(title: String, body: String)] = [
        ("Great Job!",            "You burned {burned} cal from {activity} for {duration} and have {left} cal remaining for today."),
        ("Calories Crushed!",     "{activity} for {duration} torched {burned} cal — just {left} cal left today."),
        ("Movement Milestone",    "{duration} of {activity} burned {burned} cal. Only {left} cal remain today!"),
        ("Nice Burn 🔥",          "Boom — {burned} cal gone with {activity}! You're {left} cal shy of today's goal."),
        ("Sweat Session Saved",   "{duration} of {activity} = {burned} cal burned. {left} cal remain — keep rolling!"),
        ("Progress Alert",        "Great pace! {activity} knocked out {burned} cal. Daily balance: {left} cal."),
        ("Energy Expenditure",    "Burned {burned} cal doing {activity} for {duration}. {left} cal left in the bank."),
        ("Way to Move!",          "Your {duration} {activity} session shaved off {burned} cal. Still {left} cal to play with today."),
        ("Ring the Bell 🔔",      "{burned} cal burned via {activity}! Just {left} cal stand between you and today's target."),
        ("Score Update",          "Latest stat: {burned} cal from {activity} over {duration}. Remaining: {left} cal."),
        ("Fitness Win",           "Logged {duration} of {activity}, erased {burned} cal. Daily tally says {left} cal to spare."),
        ("Heat Check 🌡️",        "Your {activity} streak burned {burned} cal in {duration}. {left} cal still on the horizon."),
        ("Momentum Maintained",   "{burned} cal down with {activity}! Keep the momentum — {left} cal remain today.")
    ]
    
    // ───────── Breakfast (22 variations) ─────────
static let breakfast: [(title: String, body: String)] = [
    ("Pssst…",                 "How was breakfast?"),
    ("Morning check-in",       "Log your breakfast to get the day started."),
    ("Start today on track",   "Add breakfast to your log."),
    ("Quick to-do",            "Log breakfast while it’s fresh."),
    ("First things first",     "What did you have for breakfast?"),
    ("Breakfast time",         "A quick log now saves time later."),
    ("Daily kickoff",          "Log breakfast to see how your day begins."),
    ("Just checking",          "Did you have breakfast?"),
    ("Morning note",           "Add breakfast to today’s log."),
    ("Early bird",             "Log breakfast and keep moving.")
]




    
    // ───────── Lunch (20 variations) ─────────
static let lunch: [(title: String, body: String)] = [
    ("Midday nudge",           "Log lunch to keep your diary up to date."),
    ("Quick check",            "What did you have for lunch?"),
    ("Lunch time",             "Add lunch to today’s log."),
    ("Food check-in",          "Log your lunch when you get a minute."),
    ("Halfway point",          "Lunch is a good time to check in."),
    ("Quick to-do",            "Log lunch and move on."),
    ("Midday update",          "Add lunch to see where you stand."),
    ("Lunch recap",            "What was for lunch today?"),
    ("Just lunch",             "Log lunch—nothing fancy."),
    ("On the go?",             "Log lunch whenever you’re ready.")
]


// ───────── Dinner (21 variations) ─────────
static let dinner: [(title: String, body: String)] = [
    ("After-dinner nudge",     "Log dinner while it’s still fresh."),
    ("Evening check-in",       "What was for dinner?"),
    ("Dinner time",            "Add dinner to today’s log."),
    ("Wrap it up",             "Log dinner to close out the day."),
    ("End-of-day note",        "Dinner can be logged now."),
    ("Daily recap",            "Finish the day by logging dinner."),
    ("Last one",               "Just dinner left to log."),
    ("Evening update",         "Add dinner to see your full day."),
    ("Before you forget",      "Log dinner when you get a chance."),
    ("Day complete",           "Dinner is the last step.")
]

}

/// Manages all notification functionality for Metryc
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    // MARK: - Published Properties
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isQuietHoursEnabled: Bool = true
    
    // MARK: - UserDefaults Keys
    private let breakfastIndexKey = "notification_breakfast_copy_index"
    private let lunchIndexKey = "notification_lunch_copy_index"
    private let dinnerIndexKey = "notification_dinner_copy_index"
    private let activityIndexKey = "notification_activity_copy_index"
    private let scheduledMealIdentifierPrefix = "scheduled_meal_"
    
    // MARK: - Initialization
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - Permission Management
    
    /// Request notification permissions after first food log (happy moment)
    func requestPermissions() async -> Bool {
        // First check current settings
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        print("📱 Current notification settings: authStatus=\(settings.authorizationStatus.rawValue)")
        
        // If already determined, don't request again
        if settings.authorizationStatus == .authorized {
            print("📱 Notifications already authorized")
            await MainActor.run {
                self.authorizationStatus = .authorized
            }
            return true
        } else if settings.authorizationStatus == .denied {
            print("📱 Notifications already denied - user must enable in Settings")
            await MainActor.run {
                self.authorizationStatus = .denied
            }
            return false
        }
        
        // Only request if status is .notDetermined
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            
            await MainActor.run {
                self.authorizationStatus = granted ? .authorized : .denied
            }
            
            print("📱 Notification permission request result: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            print("❌ Failed to request notification permissions: \(error)")
            await MainActor.run {
                self.authorizationStatus = .denied
            }
            return false
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    // MARK: - Quiet Hours Management
    
    /// Check if current time is within quiet hours
    func isInQuietHours() -> Bool {
        guard isQuietHoursEnabled else { return false }
        
        // Get quiet hours from AppStorage (defaulting to 22:00-07:00)
        let quietStart = getQuietHoursStart()
        let quietEnd = getQuietHoursEnd()
        
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let currentTime = (now.hour ?? 0) * 60 + (now.minute ?? 0) // Convert to minutes
        let startTime = quietStart.hour! * 60 + quietStart.minute!
        let endTime = quietEnd.hour! * 60 + quietEnd.minute!
        
        // Handle overnight quiet hours (e.g., 22:00 to 07:00)
        if startTime > endTime {
            return currentTime >= startTime || currentTime <= endTime
        } else {
            return currentTime >= startTime && currentTime <= endTime
        }
    }
    
    private func getQuietHoursStart() -> DateComponents {
        // Default: 22:00 (10 PM)
        return DateComponents(hour: 22, minute: 0)
    }
    
    private func getQuietHoursEnd() -> DateComponents {
        // Default: 07:00 (7 AM)
        return DateComponents(hour: 7, minute: 0)
    }
    
    // MARK: - Copy Rotation
    
    /// Get next breakfast notification copy with rotation
    func getNextBreakfastCopy() -> (title: String, body: String) {
        guard !NotificationCopy.breakfast.isEmpty else {
            return ("Breakfast time", "Log your breakfast")
        }
        let storedIndex = UserDefaults.standard.integer(forKey: breakfastIndexKey)
        let index = storedIndex % NotificationCopy.breakfast.count
        let copy = NotificationCopy.breakfast[index]

        // Advance to next index
        let nextIndex = (index + 1) % NotificationCopy.breakfast.count
        UserDefaults.standard.set(nextIndex, forKey: breakfastIndexKey)

        return copy
    }
    
    /// Get next lunch notification copy with rotation
    func getNextLunchCopy() -> (title: String, body: String) {
        guard !NotificationCopy.lunch.isEmpty else {
            return ("Lunch time", "Log your lunch")
        }
        let storedIndex = UserDefaults.standard.integer(forKey: lunchIndexKey)
        let index = storedIndex % NotificationCopy.lunch.count
        let copy = NotificationCopy.lunch[index]

        // Advance to next index
        let nextIndex = (index + 1) % NotificationCopy.lunch.count
        UserDefaults.standard.set(nextIndex, forKey: lunchIndexKey)

        return copy
    }
    
    /// Get next dinner notification copy with rotation
    func getNextDinnerCopy() -> (title: String, body: String) {
        guard !NotificationCopy.dinner.isEmpty else {
            return ("Dinner time", "Log your dinner")
        }
        let storedIndex = UserDefaults.standard.integer(forKey: dinnerIndexKey)
        let index = storedIndex % NotificationCopy.dinner.count
        let copy = NotificationCopy.dinner[index]

        // Advance to next index
        let nextIndex = (index + 1) % NotificationCopy.dinner.count
        UserDefaults.standard.set(nextIndex, forKey: dinnerIndexKey)

        return copy
    }
    
    /// Get next activity notification template with rotation and interpolation
    func getNextActivityCopy(burned: Int, activity: String, duration: String, left: Int) -> (title: String, body: String) {
        guard !NotificationCopy.activityTemplates.isEmpty else {
            return ("Activity logged", "You burned \(burned) cal from \(activity)")
        }
        let storedIndex = UserDefaults.standard.integer(forKey: activityIndexKey)
        let index = storedIndex % NotificationCopy.activityTemplates.count
        let template = NotificationCopy.activityTemplates[index]

        // Advance to next index
        let nextIndex = (index + 1) % NotificationCopy.activityTemplates.count
        UserDefaults.standard.set(nextIndex, forKey: activityIndexKey)

        // Interpolate values
        let interpolatedBody = template.body
            .replacingOccurrences(of: "{burned}", with: "\(burned)")
            .replacingOccurrences(of: "{activity}", with: activity)
            .replacingOccurrences(of: "{duration}", with: duration)
            .replacingOccurrences(of: "{left}", with: "\(left)")

        return (template.title, interpolatedBody)
    }
    
    // MARK: - Meal Reminder Scheduling
    
    /// Schedule a meal reminder notification
    func scheduleMealReminder(
        meal: MealType,
        time: DateComponents,
        isEnabled: Bool
    ) {
        let identifier = "meal_reminder_\(meal.rawValue)"
        
        // Cancel existing notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        guard isEnabled, authorizationStatus == .authorized else {
            print("📱 Skipping meal reminder for \(meal.rawValue) - not enabled or not authorized")
            return
        }
        
        // Get notification copy based on meal type
        let copy: (title: String, body: String)
        switch meal {
        case .breakfast:
            copy = getNextBreakfastCopy()
        case .lunch:
            copy = getNextLunchCopy()
        case .dinner:
            copy = getNextDinnerCopy()
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        content.categoryIdentifier = "MEAL_REMINDER"
        
        // Set interruption level based on quiet hours
        if #available(iOS 15.0, *) {
            content.interruptionLevel = isInQuietHours() ? .passive : .active
        }
        
        // Create trigger for daily repeating notification
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule meal reminder for \(meal.rawValue): \(error)")
            } else {
                print("✅ Scheduled meal reminder for \(meal.rawValue) at \(time.hour ?? 0):\(String(format: "%02d", time.minute ?? 0))")
            }
        }
    }

    func scheduleScheduledMealNotification(
        id: Int,
        scheduleType: String,
        targetDate: Date,
        targetTimeString: String?,
        mealName: String
    ) {
        let identifier = "\(scheduledMealIdentifierPrefix)\(id)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        if authorizationStatus == .notDetermined {
            Task { _ = await self.requestPermissions() }
        }

        guard authorizationStatus != .denied else {
            print("📱 Skipping scheduled meal notification – not authorized")
            return
        }

        setupNotificationCategories()

        guard let timeComponents = timeComponents(from: targetTimeString) else {
            print("📱 Skipping scheduled meal notification – invalid time components")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Log \(mealName)"
        content.body = "Tap to keep your streak going."
        content.sound = .default
        content.categoryIdentifier = "MEAL_REMINDER"

        let calendar = Calendar.current
        let isDaily = scheduleType.lowercased() == "daily"
        let trigger: UNNotificationTrigger

        if isDaily {
            var components = DateComponents()
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        } else {
            var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute

            if let fireDate = calendar.date(from: components), fireDate > Date() {
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            } else {
                print("📱 Skipping scheduled meal notification – fire date already passed")
                return
            }
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Failed to schedule meal notification: \(error)")
            } else {
                print("✅ Scheduled meal notification (\(scheduleType)) for \(mealName)")
            }
        }
    }

    func cancelScheduledMealNotification(id: Int) {
        let identifier = "\(scheduledMealIdentifierPrefix)\(id)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    /// Schedule a one-off workout plan notification
    func scheduleWorkoutPlanNotification(after delay: TimeInterval) {
        let identifier = "workout_plan_notification"

        // Remove any pending notification with the same identifier so the latest schedule wins
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        guard delay > 0 else {
            print("⚠️ Workout plan notification delay invalid (<= 0). Skipping schedule.")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Here's today's workout plan🏃‍♂️"
        content.body = "Leg Day: Barbell Squats, Bulgarian Split Squats, Leg Extensions and 3 more."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule workout plan notification: \(error)")
            } else {
                print("✅ Scheduled workout plan notification in \(delay) seconds")
            }
        }
    }

    /// Cancel meal reminder for specific meal
    func cancelMealReminder(for meal: MealType) {
        let identifier = "meal_reminder_\(meal.rawValue)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🚫 Cancelled meal reminder for \(meal.rawValue)")
    }
    
    /// Remove meal reminder immediately when meal is logged
    func removePendingMealReminder(for meal: MealType) {
        let identifier = "meal_reminder_\(meal.rawValue)"
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        print("🗑️ Removed pending meal reminder for \(meal.rawValue)")
    }
    
    // MARK: - Remote Push Notifications
    
    /// Handle incoming remote notification for activity recognition
    func handleActivityPushNotification(userInfo: [AnyHashable: Any]) {
        guard let route = userInfo["route"] as? String,
              route == "activity" else {
            print("📱 Received non-activity push notification")
            return
        }
        
        // Extract activity data
        let burnedCals = userInfo["burnedCals"] as? Int ?? 0
        let activityName = userInfo["activityName"] as? String ?? "Unknown Activity"
        let activityDuration = userInfo["activityDuration"] as? String ?? "Unknown Duration"
        let calsLeft = userInfo["calsLeft"] as? Int ?? 0
        
        print("🏃‍♂️ Received activity push: \(activityName) burned \(burnedCals) cal, \(calsLeft) left")
        
        // Navigate to daily summary view
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToActivitySummary"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    /// Create action categories for meal reminders
    func setupNotificationCategories() {
        let logMealAction = UNNotificationAction(
            identifier: "LOG_MEAL",
            title: "Log Meal",
            options: [.foreground]
        )
        
        let mealReminderCategory = UNNotificationCategory(
            identifier: "MEAL_REMINDER",
            actions: [logMealAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([mealReminderCategory])
    }

    private func timeComponents(from timeString: String?) -> (hour: Int, minute: Int)? {
        if let timeString, timeString.isEmpty == false {
            let parts = timeString.split(separator: ":")
            if parts.count >= 2,
               let hour = Int(parts[0]),
               let minute = Int(parts[1]) {
                return (hour, minute)
            }
        }

        let calendar = Calendar.current
        let defaultDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let hour = calendar.component(.hour, from: defaultDate)
        let minute = calendar.component(.minute, from: defaultDate)
        return (hour, minute)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is active (for meal reminders)
        completionHandler([.banner, .sound])
    }
    
    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        
        if identifier.hasPrefix("meal_reminder_") {
            if actionIdentifier == "LOG_MEAL" {
                // Navigate to food logging
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToFoodLogging"),
                        object: nil,
                        userInfo: ["mealType": identifier.replacingOccurrences(of: "meal_reminder_", with: "")]
                    )
                }
            }
        }
        
        completionHandler()
    }
}

// MARK: - Supporting Types

enum MealType: String, CaseIterable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        }
    }
}
