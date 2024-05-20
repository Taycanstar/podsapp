//
//  ProfileView.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    HStack {
                        Label("Email", systemImage: "envelope")
                            .foregroundColor(iconColor)
                        Spacer()
                        Text(viewModel.email)
                            .foregroundColor(iconColor)
                    }

                }
                
                Section(header: Text("Content & Display")) {
//                    NavigationLink(destination: NotificationsView()) {
//                        Label("Notifications", systemImage: "bell")
//                            .foregroundColor(iconColor)
//                    }
                    NavigationLink(destination: ColorThemeView().environmentObject(themeManager)) {
                        Label("Color theme", systemImage: "moon")
                            .foregroundColor(iconColor)
                    }

                }
                Section(header: Text("Support & About")) {
                    NavigationLink(destination: NotificationsView()) {
                        Label("Send Feedback", systemImage: "message")
                            .foregroundColor(iconColor)
                    }
                    NavigationLink(destination: NotificationsView()) {
                        Label("Terms of Use", systemImage: "doc.plaintext")
                            .foregroundColor(iconColor)
                    }
                    NavigationLink(destination: NotificationsView()) {
                        Label("Privacy Policy", systemImage: "lock")
                            .foregroundColor(iconColor)
                    }
                }
            }
            .navigationBarTitle("Settings and privacy")
        }
    }
    
    private var iconColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

struct AccountView: View {
    var body: some View {
        Text("Account Settings")
    }
}

struct PrivacyView: View {
    var body: some View {
        Text("Privacy Settings")
    }
}

struct SecurityPermissionsView: View {
    var body: some View {
        Text("Security & Permissions Settings")
    }
}

struct ShareProfileView: View {
    var body: some View {
        Text("Share Profile Settings")
    }
}

struct NotificationsView: View {
    var body: some View {
        Text("Notifications Settings")
    }
}

struct LiveView: View {
    var body: some View {
        Text("Live Settings")
    }
}

struct MusicView: View {
    var body: some View {
        Text("Music Settings")
    }
}

struct ActivityCenterView: View {
    var body: some View {
        Text("Activity Center Settings")
    }
}

struct ContentPreferencesView: View {
    var body: some View {
        Text("Content Preferences Settings")
    }
}

struct AdsView: View {
    var body: some View {
        Text("Ads Settings")
    }
}

struct PlaybackView: View {
    var body: some View {
        Text("Playback Settings")
    }
}


