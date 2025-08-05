//
//  NotificationSettingsView.swift
//  pods
//
//  Created by Dimi Nunez on 8/5/25.
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var mealReminderService = MealReminderService.shared
    
    // Quiet hours settings
    @AppStorage("quietHoursEnabled") private var quietHoursEnabled: Bool = true
    @AppStorage("quietHoursStart") private var quietHoursStartData: Data = {
        let components = DateComponents(hour: 22, minute: 0)
        return try! JSONEncoder().encode(components)
    }()
    @AppStorage("quietHoursEnd") private var quietHoursEndData: Data = {
        let components = DateComponents(hour: 7, minute: 0)
        return try! JSONEncoder().encode(components)
    }()
    
    // Activity push notifications
    @AppStorage("activityPushEnabled") private var activityPushEnabled: Bool = true
    
    // State for quiet hours time pickers
    @State private var quietHoursStart: Date = {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var quietHoursEnd: Date = {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    
    @State private var showingPermissionAlert = false
    
    var body: some View {
        ZStack {
            formBackgroundColor.edgesIgnoringSafeArea(.all)
            
            Form {
                // Notification Permission Status
                if notificationManager.authorizationStatus != .authorized {
                    permissionSection
                }
                
                // Meal Reminders Section
                mealRemindersSection
                
                // Activity Notifications Section
                activityNotificationsSection
                
                // Quiet Hours Section
                quietHoursSection
                
                #if DEBUG
                // Debug Testing Section
                debugTestingSection
                #endif
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Notifications")
        .onAppear {
            isTabBarVisible.wrappedValue = false
            loadQuietHoursSettings()
            notificationManager.checkAuthorizationStatus()
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
            saveQuietHoursSettings()
        }
        .alert("Notifications Disabled", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To receive meal reminders and activity alerts, please enable notifications in Settings.")
        }
    }
    
    // MARK: - Permission Section
    
    private var permissionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bell.slash.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications Disabled")
                            .font(.headline)
                            .foregroundColor(textColor)
                        
                        Text("Enable notifications to receive meal reminders and activity alerts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Button("Enable Notifications") {
                    requestNotificationPermissions()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Permission Required")
        }
    }
    
    // MARK: - Meal Reminders Section
    
    private var mealRemindersSection: some View {
        Section {
            // Breakfast
            mealReminderRow(
                meal: .breakfast,
                isEnabled: MealReminderService.getBreakfastEnabledBinding(),
                time: MealReminderService.getBreakfastTimeBinding(),
                icon: "sunrise.fill",
                color: .orange
            )
            
            // Lunch
            mealReminderRow(
                meal: .lunch,
                isEnabled: MealReminderService.getLunchEnabledBinding(),
                time: MealReminderService.getLunchTimeBinding(),
                icon: "sun.max.fill",
                color: .yellow
            )
            
            // Dinner
            mealReminderRow(
                meal: .dinner,
                isEnabled: MealReminderService.getDinnerEnabledBinding(),
                time: MealReminderService.getDinnerTimeBinding(),
                icon: "moon.fill",
                color: .blue
            )
        } header: {
            Text("Meal Reminders")
        } footer: {
            Text("Smart reminders learn from your eating patterns and adjust automatically. Times are suggestions and can be customized.")
                .font(.footnote)
        }
    }
    
    private func mealReminderRow(
        meal: MealType,
        isEnabled: Binding<Bool>,
        time: Binding<Date>,
        icon: String,
        color: Color
    ) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.displayName)
                        .font(.headline)
                        .foregroundColor(textColor)
                    
                    if mealReminderService.isUserCustomTime(meal) {
                        Text("Custom time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Auto-tuned")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: isEnabled)
                    .labelsHidden()
            }
            
            if isEnabled.wrappedValue {
                HStack {
                    DatePicker(
                        "Time",
                        selection: time,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    
                    Spacer()
                    
                    if mealReminderService.isUserCustomTime(meal) {
                        Button("Reset to Auto") {
                            mealReminderService.resetToAutoTime(meal)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                // Add test button for lunch only
                if meal == .lunch {
                    Button("Test Lunch Notification (5s)") {
                        testLunchNotification()
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Activity Notifications Section
    
    private var activityNotificationsSection: some View {
        Section {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(.green)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity Alerts")
                        .font(.headline)
                        .foregroundColor(textColor)
                    
                    Text("Get notified when workouts sync from Apple Health")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $activityPushEnabled)
                    .labelsHidden()
            }
            .padding(.vertical, 4)
        } header: {
            Text("Push Notifications")
        } footer: {
            Text("Receive congratulatory messages when your workouts automatically sync from Apple Health.")
                .font(.footnote)
        }
    }
    
    // MARK: - Quiet Hours Section
    
    private var quietHoursSection: some View {
        Section {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(.indigo)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quiet Hours")
                        .font(.headline)
                        .foregroundColor(textColor)
                    
                    Text("Reduce notification interruptions during rest time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $quietHoursEnabled)
                    .labelsHidden()
            }
            .padding(.vertical, 4)
            
            if quietHoursEnabled {
                HStack {
                    Label("Start", systemImage: "bed.double.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Spacer()
                    
                    DatePicker(
                        "Quiet Hours Start",
                        selection: $quietHoursStart,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .onChange(of: quietHoursStart) { _ in
                        saveQuietHoursSettings()
                    }
                }
                
                HStack {
                    Label("End", systemImage: "sunrise.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Spacer()
                    
                    DatePicker(
                        "Quiet Hours End",
                        selection: $quietHoursEnd,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .onChange(of: quietHoursEnd) { _ in
                        saveQuietHoursSettings()
                    }
                }
            }
        } header: {
            Text("Do Not Disturb")
        } footer: {
            if quietHoursEnabled {
                Text("During quiet hours, notifications will be delivered silently unless marked as time-sensitive.")
                    .font(.footnote)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func testLunchNotification() {
        print("🧪 Testing lunch notification in 5 seconds...")
        
        let content = UNMutableNotificationContent()
        let copy = NotificationManager.shared.getNextLunchCopy()
        content.title = "\(copy.title)"
        content.body = copy.body
        content.sound = .default
        content.categoryIdentifier = "MEAL_REMINDER"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_lunch_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test lunch notification: \(error)")
            } else {
                print("✅ Test lunch notification scheduled - background the app now!")
            }
        }
    }
    
    private func requestNotificationPermissions() {
        Task {
            let granted = await notificationManager.requestPermissions()
            
            if !granted {
                DispatchQueue.main.async {
                    showingPermissionAlert = true
                }
            } else {
                // Setup notification categories after permission granted
                notificationManager.setupNotificationCategories()
                
                // Refresh meal reminders
                mealReminderService.refreshAllReminders()
            }
        }
    }
    
    private func loadQuietHoursSettings() {
        // Load quiet hours start
        if let startComponents = try? JSONDecoder().decode(DateComponents.self, from: quietHoursStartData) {
            let calendar = Calendar.current
            quietHoursStart = calendar.date(bySettingHour: startComponents.hour ?? 22, minute: startComponents.minute ?? 0, second: 0, of: Date()) ?? quietHoursStart
        }
        
        // Load quiet hours end
        if let endComponents = try? JSONDecoder().decode(DateComponents.self, from: quietHoursEndData) {
            let calendar = Calendar.current
            quietHoursEnd = calendar.date(bySettingHour: endComponents.hour ?? 7, minute: endComponents.minute ?? 0, second: 0, of: Date()) ?? quietHoursEnd
        }
    }
    
    private func saveQuietHoursSettings() {
        let calendar = Calendar.current
        
        // Save quiet hours start
        let startComponents = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        if let startData = try? JSONEncoder().encode(startComponents) {
            quietHoursStartData = startData
        }
        
        // Save quiet hours end
        let endComponents = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)
        if let endData = try? JSONEncoder().encode(endComponents) {
            quietHoursEndData = endData
        }
    }
    
    // MARK: - Debug Testing Section
    
    #if DEBUG
    private var debugTestingSection: some View {
        Section {
            VStack(spacing: 12) {
                Button("🍳 Test Breakfast Notification (5s)") {
                    testMealNotification(.breakfast)
                }
                .buttonStyle(.borderedProminent)
                
                Button("🥗 Test Lunch Notification (5s)") {
                    testMealNotification(.lunch)
                }
                .buttonStyle(.bordered)
                
                Button("🍽️ Test Dinner Notification (5s)") {
                    testMealNotification(.dinner)
                }
                .buttonStyle(.bordered)
                
                Button("🏃‍♂️ Test Activity Notification (5s)") {
                    testActivityNotification()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.green)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Debug Testing")
        } footer: {
            Text("These buttons schedule test notifications 5 seconds from now. Make sure to background the app to see them.")
                .font(.footnote)
        }
    }
    
    private func testMealNotification(_ meal: MealType) {
        print("🧪 Testing \(meal.displayName) notification in 5 seconds...")
        
        let content = UNMutableNotificationContent()
        let copy = NotificationManager.shared.getNextBreakfastCopy() // Use breakfast copy for testing
        content.title = "\(copy.title)"
        content.body = copy.body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_\(meal.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test notification: \(error)")
            } else {
                print("✅ Test notification scheduled for \(meal.displayName)")
            }
        }
    }
    
    private func testActivityNotification() {
        print("🧪 Testing activity notification in 5 seconds...")
        
        let content = UNMutableNotificationContent()
        let copy = NotificationManager.shared.getNextActivityCopy(
            burned: 350,
            activity: "Running",
            duration: "25 min",
            left: 1200
        )
        content.title = "\(copy.title)"
        content.body = copy.body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_activity_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test activity notification: \(error)")
            } else {
                print("✅ Test activity notification scheduled")
            }
        }
    }
    #endif
    
    // MARK: - Computed Properties
    
    private var formBackgroundColor: Color {
        colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242)
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

// MARK: - Color Extension

extension Color {
    init(rgb red: Double, _ green: Double, _ blue: Double) {
        self.init(red: red/255, green: green/255, blue: blue/255)
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
}

