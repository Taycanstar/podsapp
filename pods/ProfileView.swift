//
//  ProfileView.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//

import SwiftUI
import MessageUI
import GoogleSignIn

struct ProfileView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingMail = false
    @Binding var isAuthenticated: Bool
    
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
                    HStack {
                        Label("Username", systemImage: "person")
                            .foregroundColor(iconColor)
                        Spacer()
                        Text(viewModel.username)
                            .foregroundColor(iconColor)
                    }
                    NavigationLink(destination: DataControlsView(isAuthenticated: $isAuthenticated)) {
                        Label("Data Controls", systemImage: "tablecells.badge.ellipsis")
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
                    Button(action: {
                                          self.showingMail = true
                                      }) {
                                          Label("Send Feedback", systemImage: "message")
                                              .foregroundColor(iconColor)
                                      }
                    Link(destination: URL(string: "https://www.humuli.com/policies/terms")!) {
                                          Label("Terms of Use", systemImage: "doc.plaintext")
                                              .foregroundColor(iconColor)
                                      }
                                      Link(destination: URL(string: "https://www.humuli.com/policies/privacy-policy")!) {
                                          Label("Privacy Policy", systemImage: "lock")
                                              .foregroundColor(iconColor)
                                      }
                }
              
                Section() {
                   
                    Button(action: {
                        logOut()
                                      }) {
                                          Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                                              .foregroundColor(iconColor)
                                      }
                   
                }
            }
            .navigationBarTitle("Settings and privacy")
            .sheet(isPresented: $showingMail) {
                         MailView()
                     }
        }
     
    }
    
    private var iconColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private func logOut() {
          // Clear the authentication state and email from UserDefaults
          UserDefaults.standard.set(false, forKey: "isAuthenticated")
          UserDefaults.standard.set("", forKey: "userEmail")
        UserDefaults.standard.set("", forKey: "username")
        // Sign out from Google
                GIDSignIn.sharedInstance.signOut()
          // Update the state variables
        isAuthenticated = false
          viewModel.email = ""
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

struct MailView: UIViewControllerRepresentable {
    func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.setToRecipients(["support@humuli.com"])
        mail.setSubject("Humuli Feedback")
        mail.setMessageBody("", isHTML: true)
        return mail
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: UIViewControllerRepresentableContext<MailView>) {
    }
    
    static func dismantleUIViewController(_ uiViewController: MFMailComposeViewController, coordinator: ()) {
        uiViewController.dismiss(animated: true)
    }
}

