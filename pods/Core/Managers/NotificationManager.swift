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
        ("Quick Pause👀",              "Jot down breakfast before the morning blurs."),
        ("Psst… friendly nudge",       "How'd that breakfast go? Drop it in the log."),
        ("Live it, love it, log it🙂‍↕️", "Little taps, big wins."),
        ("Breakfast recap?",           "Your log is all ears — two taps and done."),
        ("Start on-track",             "Log breakfast and watch your numbers fall into place."),
        ("Morning fuel check☀️",       "What powered you up? Log it while the coffee's hot."),
        ("Best day starter",           "Before the day sprints ahead, tag your breakfast and keep the streak alive."),
        ("Sunrise check-in",           "What kicked off your morning? Log and launch."),
        ("Fuel gauge🚀",               "Breakfast logged = green light for the day ahead."),
        ("Bite-size victory",          "One entry now saves guesswork later—tag breakfast."),
        ("Coffee & context",           "While the mug's warm, give breakfast its timestamp."),
        ("Morning snapshot📸",         "Scan your plate before the calendar fills."),
        ("Day-one data",               "Every trend starts with breakfast—note it down."),
        ("Small step, strong start",   "Two taps, then conquer the to-do list."),
        ("First win of the day",       "Logging breakfast? That's momentum talking."),
        ("Breakfast Bookmark🔖",       "Mark the moment—future insights start here."),
        ("Early streak spark",         "Add breakfast and keep the chain unbroken."),
        ("Taste memory",               "Record flavors now, reminisce later."),
        ("Minute-one mindfulness🧘",     "Pause, log, breathe—carry on."),
        ("Chart your course",          "Numbers look best with breakfast on board."),
        ("Early bird balance🐥",         "Feed the log before you feed the inbox."),
        ("Good-morning glance👀",        "Sync your fork with your phone—breakfast awaits its spot.")
    ]
    
    // ───────── Lunch (20 variations) ─────────
    static let lunch: [(title: String, body: String)] = [
        ("Lunch roll-call",            "Got a fruit or veggie on deck? High-five yourself and log it."),
        ("Menu-planning already?",     "Tick lunch off your log before dinner steals the spotlight."),
        ("Earn your kudos🤓",          "Log that lunch and own it."),
        ("Tiny Task —> big streak 🔥", "Log lunch, keep rolling."),
        ("Midday snapshot📸",          "What's in the box? Give it a home in your logs."),
        ("Streaks love honesty",       "Log anything, big or small."),
        ("Had anything for breakfast?", "Tiny taps today save head-scratching tomorrow."),
        ("New me?",                    "Future-you thanks you for every entry you make today."),
        ("Midday milestone",           "Lock in lunch and own the afternoon."),
        ("Plate progress",             "What's fueling the next sprint? Jot it down."),
        ("Desk-to-log",                "Sandwich, salad, or surprise—record it before the 2 p.m. rush."),
        ("Refuel record🔥",              "Add lunch; your stats will thank you."),
        ("Half-time report",           "Game's not over—update the score with lunch."),
        ("Fork-lift🍴",                  "Elevate your streak—log that forkful."),
        ("Lunch ledger💰",               "Quick entry keeps the data honest."),
        ("Bite, scan, done🍴",           "A tap or two beats a blank later."),
        ("Noon nudge👀",                 "Give lunch its cameo while it's camera-ready."),
        ("Recharge recap🔋",             "Logging lunch = battery boost for the day."),
        ("Balanced break",             "Pencil in lunch, then power back up."),
        ("Plate math🧮",               "Add today's numbers before the next meeting starts.")
    ]
    
    // ───────── Dinner (21 variations) ─────────
    static let dinner: [(title: String, body: String)] = [
        ("Future you checking in",     "Thanks for logging today. I'm so glad I did!"),
        ("What a ride!",               "Capture today's eats while they're fresh."),
        ("Food = joy",                 "Had a delicious dinner? Immortalize it in the log."),
        ("Memory jog✅",               "Note dinner now, before \"What did I eat?\" kicks in."),
        ("Plate-to-phone📱",           "Log tonight's feast before coach-mode kicks in."),
        ("Wind down right😶‍🌫️",        "Log dinner, close your nutrition rings."),
        ("Evening wrap-up",            "Final log = flawless daily record."),
        ("Day in review",              "Close the loop—log tonight's plate."),
        ("Fork-down finale 📽️",        "Dinner logged, rings closed, couch unlocked."),
        ("Night-cap note",             "Log dinner, rest easier."),
        ("Last bite, last scan",       "Seal today's stats before tomorrow starts."),
        ("Good-night gratitude",       "Log dinner and toast to your progress."),
        ("Twilight tally🌙",           "Your numbers need their nightcap—add dinner."),
        ("Supper Snapshot📸",          "Capture flavor memories—log while they're vivid."),
        ("Bedtime bonus🌙",              "Logging now beats back-tracking later."),
        ("Daily storybook📖",          "The final chapter: enter dinner, hit save."),
        ("Digest & document💬",          "Quick save before shutdown mode."),
        ("Moonlight Metrics🌙",          "Let today's data shine—dinner goes in."),
        ("Plate History📖",              "Preserve tonight's masterpiece for future you."),
        ("Cook-to-cloud☁️",              "From stove to stats in two taps."),
        ("Evening audit",              "Check dinner off, then check out.")
    ]
}

/// Manages all notification functionality for Humuli
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
        let index = UserDefaults.standard.integer(forKey: breakfastIndexKey)
        let copy = NotificationCopy.breakfast[index]
        
        // Advance to next index
        let nextIndex = (index + 1) % NotificationCopy.breakfast.count
        UserDefaults.standard.set(nextIndex, forKey: breakfastIndexKey)
        
        return copy
    }
    
    /// Get next lunch notification copy with rotation
    func getNextLunchCopy() -> (title: String, body: String) {
        let index = UserDefaults.standard.integer(forKey: lunchIndexKey)
        let copy = NotificationCopy.lunch[index]
        
        // Advance to next index
        let nextIndex = (index + 1) % NotificationCopy.lunch.count
        UserDefaults.standard.set(nextIndex, forKey: lunchIndexKey)
        
        return copy
    }
    
    /// Get next dinner notification copy with rotation
    func getNextDinnerCopy() -> (title: String, body: String) {
        let index = UserDefaults.standard.integer(forKey: dinnerIndexKey)
        let copy = NotificationCopy.dinner[index]
        
        // Advance to next index
        let nextIndex = (index + 1) % NotificationCopy.dinner.count
        UserDefaults.standard.set(nextIndex, forKey: dinnerIndexKey)
        
        return copy
    }
    
    /// Get next activity notification template with rotation and interpolation
    func getNextActivityCopy(burned: Int, activity: String, duration: String, left: Int) -> (title: String, body: String) {
        let index = UserDefaults.standard.integer(forKey: activityIndexKey)
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
