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
    
    
    var body: some View {
        ZStack {
            formBackgroundColor.edgesIgnoringSafeArea(.all)
            
            Form {
                // Activity Notifications Section
                activityNotificationsSection
                
                // Quiet Hours Section
                quietHoursSection
                
                // Settings Button
                settingsButtonSection
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
                        .font(.subheadline)
                        .foregroundColor(textColor)
                    
                }
                
                Spacer()
                
                Toggle("", isOn: $activityPushEnabled)
                    .labelsHidden()
            }
            .padding(.vertical, 4)
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
                        .font(.subheadline)
                        .foregroundColor(textColor)
                    
                 
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
    
    
    
    
    
    // MARK: - Settings Button Section
    
    private var settingsButtonSection: some View {
        Section {
            Button(action: openNotificationSettings) {
                HStack {
                    Spacer()
                    Text(notificationManager.authorizationStatus == .authorized ? "Notification Settings" : "Enable Notifications")
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Color.systemGray3)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func openNotificationSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
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

