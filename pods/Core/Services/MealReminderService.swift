//
//  MealReminderService.swift
//  pods
//
//  Created by Dimi Nunez on 8/5/25.
//

import Foundation
import SwiftUI
import Combine

/// Service that manages intelligent meal reminder scheduling with auto-tuning based on user behavior
class MealReminderService: ObservableObject {
    static let shared = MealReminderService()
    
    // MARK: - Published Properties
    @Published var isBreakfastEnabled: Bool {
        didSet { updateMealReminder(.breakfast) }
    }
    @Published var isLunchEnabled: Bool {
        didSet { updateMealReminder(.lunch) }
    }
    @Published var isDinnerEnabled: Bool {
        didSet { updateMealReminder(.dinner) }
    }
    
    @Published var breakfastTime: Date {
        didSet { 
            if !isUserCustomTime(.breakfast) {
                markAsUserCustomTime(.breakfast)
            }
            updateMealReminder(.breakfast)
        }
    }
    @Published var lunchTime: Date {
        didSet { 
            if !isUserCustomTime(.lunch) {
                markAsUserCustomTime(.lunch)
            }
            updateMealReminder(.lunch)
        }
    }
    @Published var dinnerTime: Date {
        didSet { 
            if !isUserCustomTime(.dinner) {
                markAsUserCustomTime(.dinner)
            }
            updateMealReminder(.dinner)
        }
    }
    
    // MARK: - Private Properties
    private let notificationManager = NotificationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults keys
    private let breakfastEnabledKey = "meal_reminder_breakfast_enabled"
    private let lunchEnabledKey = "meal_reminder_lunch_enabled"
    private let dinnerEnabledKey = "meal_reminder_dinner_enabled"
    private let breakfastTimeKey = "meal_reminder_breakfast_time"
    private let lunchTimeKey = "meal_reminder_lunch_time"
    private let dinnerTimeKey = "meal_reminder_dinner_time"
    private let breakfastCustomKey = "meal_reminder_breakfast_custom"
    private let lunchCustomKey = "meal_reminder_lunch_custom"
    private let dinnerCustomKey = "meal_reminder_dinner_custom"
    private let lastAutoTuneKey = "meal_reminder_last_auto_tune"
    
    // MARK: - Initialization
    private init() {
        // Initialize time properties with default values first
        self.breakfastTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
        self.lunchTime = Calendar.current.date(from: DateComponents(hour: 12, minute: 0)) ?? Date()
        self.dinnerTime = Calendar.current.date(from: DateComponents(hour: 19, minute: 0)) ?? Date()
        
        // Load saved preferences - but default to true if notifications are authorized
        let shouldDefaultToEnabled = NotificationManager.shared.authorizationStatus == .authorized
        self.isBreakfastEnabled = UserDefaults.standard.object(forKey: breakfastEnabledKey) != nil ? UserDefaults.standard.bool(forKey: breakfastEnabledKey) : shouldDefaultToEnabled
        self.isLunchEnabled = UserDefaults.standard.object(forKey: lunchEnabledKey) != nil ? UserDefaults.standard.bool(forKey: lunchEnabledKey) : shouldDefaultToEnabled
        self.isDinnerEnabled = UserDefaults.standard.object(forKey: dinnerEnabledKey) != nil ? UserDefaults.standard.bool(forKey: dinnerEnabledKey) : shouldDefaultToEnabled
        
        // Now load saved times or keep defaults (this won't trigger didSet during init)
        if let savedBreakfastTime = loadSavedTime(for: .breakfast) {
            self.breakfastTime = savedBreakfastTime
        }
        if let savedLunchTime = loadSavedTime(for: .lunch) {
            self.lunchTime = savedLunchTime
        }
        if let savedDinnerTime = loadSavedTime(for: .dinner) {
            self.dinnerTime = savedDinnerTime
        }
        
        // Setup auto-tuning timer (weekly)
        setupAutoTuning()
        
        // Schedule existing reminders
        scheduleAllReminders()
    }
    
    // MARK: - Public Methods
    
    /// Called when a meal is logged to remove pending reminder and track timing
    func mealWasLogged(mealType: String, at time: Date = Date()) {
        guard let meal = MealType(rawValue: mealType.lowercased()) else { return }
        
        // Remove pending reminder
        notificationManager.removePendingMealReminder(for: meal)
        
        // Store meal timing for auto-tuning
        storeMealTiming(meal: meal, time: time)
        
        print("🍽️ Meal logged: \(meal.displayName) at \(formatTime(time))")
    }
    
    /// Manually refresh all reminders (useful for settings changes)
    func refreshAllReminders() {
        scheduleAllReminders()
    }
    
    /// Enable all meal reminders when notifications are first granted
    func enableAllMealReminders() {
        isBreakfastEnabled = true
        isLunchEnabled = true
        isDinnerEnabled = true
        print("✅ All meal reminders enabled automatically")
    }
    
    /// Get default time for meal type
    func defaultTime(for meal: MealType) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        switch meal {
        case .breakfast:
            return calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today
        case .lunch:
            return calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today) ?? today
        case .dinner:
            return calendar.date(bySettingHour: 19, minute: 0, second: 0, of: today) ?? today
        }
    }
    
    /// Check if meal time has been customized by user
    func isUserCustomTime(_ meal: MealType) -> Bool {
        let key = customTimeKey(for: meal)
        return UserDefaults.standard.bool(forKey: key)
    }
    
    /// Reset meal time to auto-tuned time (if available) or default
    func resetToAutoTime(_ meal: MealType) {
        let key = customTimeKey(for: meal)
        UserDefaults.standard.set(false, forKey: key)
        
        // Get auto-tuned time or default
        let autoTime = calculateOptimalTime(for: meal) ?? defaultTime(for: meal)
        
        // CRITICAL FIX: Ensure @Published meal time updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch meal {
            case .breakfast:
                self.breakfastTime = autoTime
            case .lunch:
                self.lunchTime = autoTime
            case .dinner:
                self.dinnerTime = autoTime
            }
        }
        
        print("🔄 Reset \(meal.displayName) to auto time: \(formatTime(autoTime))")
    }
    
    // MARK: - Private Methods
    
    private func scheduleAllReminders() {
        updateMealReminder(.breakfast)
        updateMealReminder(.lunch)
        updateMealReminder(.dinner)
    }
    
    private func updateMealReminder(_ meal: MealType) {
        let isEnabled: Bool
        let time: Date
        
        switch meal {
        case .breakfast:
            isEnabled = isBreakfastEnabled
            time = breakfastTime
            UserDefaults.standard.set(isEnabled, forKey: breakfastEnabledKey)
            saveTime(time, for: .breakfast)
        case .lunch:
            isEnabled = isLunchEnabled
            time = lunchTime
            UserDefaults.standard.set(isEnabled, forKey: lunchEnabledKey)
            saveTime(time, for: .lunch)
        case .dinner:
            isEnabled = isDinnerEnabled
            time = dinnerTime
            UserDefaults.standard.set(isEnabled, forKey: dinnerEnabledKey)
            saveTime(time, for: .dinner)
        }
        
        // Convert to DateComponents for scheduling
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        
        // Schedule with NotificationManager
        notificationManager.scheduleMealReminder(
            meal: meal,
            time: components,
            isEnabled: isEnabled
        )
    }
    
    private func loadSavedTime(for meal: MealType) -> Date? {
        let key = timeKey(for: meal)
        let timeInterval = UserDefaults.standard.double(forKey: key)
        
        guard timeInterval > 0 else { return nil }
        return Date(timeIntervalSince1970: timeInterval)
    }
    
    private func saveTime(_ time: Date, for meal: MealType) {
        let key = timeKey(for: meal)
        UserDefaults.standard.set(time.timeIntervalSince1970, forKey: key)
    }
    
    private func markAsUserCustomTime(_ meal: MealType) {
        let key = customTimeKey(for: meal)
        UserDefaults.standard.set(true, forKey: key)
    }
    
    private func timeKey(for meal: MealType) -> String {
        switch meal {
        case .breakfast: return breakfastTimeKey
        case .lunch: return lunchTimeKey
        case .dinner: return dinnerTimeKey
        }
    }
    
    private func customTimeKey(for meal: MealType) -> String {
        switch meal {
        case .breakfast: return breakfastCustomKey
        case .lunch: return lunchCustomKey
        case .dinner: return dinnerCustomKey
        }
    }
    
    // MARK: - Auto-Tuning Logic
    
    private func setupAutoTuning() {
        // Check if we should run auto-tuning (once per week)
        let lastAutoTune = UserDefaults.standard.double(forKey: lastAutoTuneKey)
        let weekAgo = Date().timeIntervalSince1970 - (7 * 24 * 60 * 60)
        
        if lastAutoTune < weekAgo {
            performAutoTuning()
        }
        
        // Setup timer for weekly auto-tuning
        Timer.publish(every: 24 * 60 * 60, on: .main, in: .common) // Daily check
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForAutoTuning()
            }
            .store(in: &cancellables)
    }
    
    private func checkForAutoTuning() {
        let lastAutoTune = UserDefaults.standard.double(forKey: lastAutoTuneKey)
        let weekAgo = Date().timeIntervalSince1970 - (7 * 24 * 60 * 60)
        
        if lastAutoTune < weekAgo {
            performAutoTuning()
        }
    }
    
    private func performAutoTuning() {
        print("🎯 Performing weekly auto-tuning of meal reminders")
        
        for meal in MealType.allCases {
            // Skip if user has set custom time
            guard !isUserCustomTime(meal) else {
                print("⏭️ Skipping \(meal.displayName) - user custom time")
                continue
            }
            
            // Calculate optimal time based on historical data
            if let optimalTime = calculateOptimalTime(for: meal) {
                // CRITICAL FIX: Ensure @Published meal time updates happen on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    switch meal {
                    case .breakfast:
                        if !self.isUserCustomTime(.breakfast) {
                            self.breakfastTime = optimalTime
                            print("🎯 Auto-tuned breakfast time to \(self.formatTime(optimalTime)) [MAIN THREAD]")
                        }
                    case .lunch:
                        if !self.isUserCustomTime(.lunch) {
                            self.lunchTime = optimalTime
                            print("🎯 Auto-tuned lunch time to \(self.formatTime(optimalTime)) [MAIN THREAD]")
                        }
                    case .dinner:
                        if !self.isUserCustomTime(.dinner) {
                            self.dinnerTime = optimalTime
                            print("🎯 Auto-tuned dinner time to \(self.formatTime(optimalTime)) [MAIN THREAD]")
                        }
                    }
                }
            }
        }
        
        // Update last auto-tune timestamp
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastAutoTuneKey)
    }
    
    private func calculateOptimalTime(for meal: MealType) -> Date? {
        let key = "meal_timings_\(meal.rawValue)"
        let timings = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        
        // Need at least 3 data points for meaningful average
        guard timings.count >= 3 else {
            print("📊 Not enough data for \(meal.displayName) auto-tuning (\(timings.count) points)")
            return nil
        }
        
        // Take last 7 timings for weekly average
        let recentTimings = Array(timings.suffix(7))
        let averageTimestamp = recentTimings.reduce(0, +) / Double(recentTimings.count)
        let averageTime = Date(timeIntervalSince1970: averageTimestamp)
        
        // Schedule reminder 15 minutes before average time
        let reminderTime = averageTime.addingTimeInterval(-15 * 60)
        
        // Clamp to reasonable hours (06:00 - 21:00)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderTime)
        let minute = calendar.component(.minute, from: reminderTime)
        
        let clampedHour = max(6, min(21, hour))
        let clampedTime = calendar.date(bySettingHour: clampedHour, minute: minute, second: 0, of: Date()) ?? reminderTime
        
        print("📊 \(meal.displayName) auto-tune: avg \(formatTime(averageTime)) → reminder \(formatTime(clampedTime))")
        return clampedTime
    }
    
    private func storeMealTiming(meal: MealType, time: Date) {
        let key = "meal_timings_\(meal.rawValue)"
        var timings = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        
        // Add new timing
        timings.append(time.timeIntervalSince1970)
        
        // Keep only last 30 timings (for performance)
        if timings.count > 30 {
            timings = Array(timings.suffix(30))
        }
        
        UserDefaults.standard.set(timings, forKey: key)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - AppStorage Integration

extension MealReminderService {
    
    /// Get AppStorage bindings for SwiftUI integration
    static func getBreakfastEnabledBinding() -> Binding<Bool> {
        return Binding(
            get: { shared.isBreakfastEnabled },
            set: { shared.isBreakfastEnabled = $0 }
        )
    }
    
    static func getLunchEnabledBinding() -> Binding<Bool> {
        return Binding(
            get: { shared.isLunchEnabled },
            set: { shared.isLunchEnabled = $0 }
        )
    }
    
    static func getDinnerEnabledBinding() -> Binding<Bool> {
        return Binding(
            get: { shared.isDinnerEnabled },
            set: { shared.isDinnerEnabled = $0 }
        )
    }
    
    static func getBreakfastTimeBinding() -> Binding<Date> {
        return Binding(
            get: { shared.breakfastTime },
            set: { shared.breakfastTime = $0 }
        )
    }
    
    static func getLunchTimeBinding() -> Binding<Date> {
        return Binding(
            get: { shared.lunchTime },
            set: { shared.lunchTime = $0 }
        )
    }
    
    static func getDinnerTimeBinding() -> Binding<Date> {
        return Binding(
            get: { shared.dinnerTime },
            set: { shared.dinnerTime = $0 }
        )
    }
}

