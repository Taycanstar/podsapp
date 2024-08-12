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
    @Binding var showTourView: Bool
    
    var body: some View {
        
        NavigationView {
            ZStack {
                formBackgroundColor.edgesIgnoringSafeArea(.all)
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
                            NavigationLink(destination: MyTeamsView()) {
                                Label("My team", systemImage: "person.2")
                                    .foregroundColor(iconColor)
                            }
                            NavigationLink(destination: MyWorkspacesView()) {
                                Label("My workspace", systemImage: "sparkles.rectangle.stack")
                                    .foregroundColor(iconColor)
                            }
                            
                        }
                        .listRowBackground(colorScheme == .dark ? Color(rgb:44,44,44) : .white)
                        
                        Section(header: Text("Content & Display")) {
                            
                            NavigationLink(destination: ColorThemeView().environmentObject(themeManager)) {
                                Label("Color theme", systemImage: "moon")
                                    .foregroundColor(iconColor)
                            }
                            
                        }
                        .listRowBackground(colorScheme == .dark ? Color(rgb:44,44,44) : .white)
                        Section(header: Text("Support & About")) {
                            Button(action: {
                                self.showingMail = true
                            }) {
                                Label("Send feedback", systemImage: "message")
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
                            Button(action: {
                                self.showTourView = true
                            }) {
                                Label("App tour guide", systemImage: "safari")
                                    .foregroundColor(iconColor)
                            }
                        }
                        .listRowBackground(colorScheme == .dark ? Color(rgb:44,44,44) : .white)
                        
                        Section() {
                            
                            Button(action: {
                                logOut()
                            }) {
                                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(iconColor)
                                    .foregroundColor(.red)
                            }
                            
                        }
                        .listRowBackground(colorScheme == .dark ? Color(rgb:44,44,44) : .white)
                        
                    }
                    .scrollContentBackground(.hidden)
                    .padding(.bottom, 50)
            }
         
            .navigationBarTitle("Settings and privacy", displayMode: .inline)
            .sheet(isPresented: $showingMail) {
                MailView(isPresented: self.$showingMail)
                     }
        }
     
    }
    
    private var iconColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var formBackgroundColor: Color {
           colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242)
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
    @Binding var isPresented: Bool

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                print("Mail compose error: \(error.localizedDescription)")
            } else {
                switch result {
                case .cancelled:
                    print("Mail cancelled")
                case .saved:
                    print("Mail saved")
                case .sent:
                    print("Mail sent")
                case .failed:
                    print("Mail failed")
                @unknown default:
                    print("Unknown result")
                }
            }
            controller.dismiss(animated: true) {
                self.isPresented = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.setToRecipients(["support@humuli.com"])
        mail.setSubject("Humuli Feedback")
        mail.setMessageBody("", isHTML: true)
        mail.mailComposeDelegate = context.coordinator
        return mail
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: MFMailComposeViewController, coordinator: Coordinator) {
        uiViewController.dismiss(animated: true)
    }
}

struct MyTeamsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                ForEach(homeViewModel.teams) { team in
                    teamView(team: team)
                }
            }
            .padding()
        }
        .background( colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242))
        .navigationBarTitle("My team", displayMode: .inline)
        .onAppear {
            homeViewModel.fetchTeamsForUser(email: viewModel.email)
        }
    }

    private func teamView(team: Team) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color(rgb:44,44,44) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            HStack {
                DefaultProfilePicture(
                    initial: team.profileInitial ?? "",
                    color: team.profileColor ?? "",
                    size: 30
                )
                
                Text(team.name)
                    .fontWeight(.medium)
                    .font(.system(size: 14))
                Spacer()
                
                if team.id == viewModel.activeTeamId {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(team.id == viewModel.activeTeamId ? Color.accentColor : Color.clear, lineWidth: 3)
        )
    }
}

struct MyWorkspacesView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                ForEach(homeViewModel.workspaces) { workspace in
                    workspaceView(workspace: workspace)
                }
            }
            .padding()
        }
        .background( colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242))
        .navigationBarTitle("My workspace", displayMode: .inline)
        .onAppear {
            homeViewModel.fetchWorkspacesForUser(email: viewModel.email)
        }
    }

    private func workspaceView(workspace: Workspace) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color("container") : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            HStack {
                DefaultProfilePicture(
                    initial: workspace.profileInitial ?? "",
                    color: workspace.profileColor ?? "",
                    size: 30
                )
                
                Text(workspace.name)
                    .fontWeight(.medium)
                    .font(.system(size: 14))
                Spacer()
                
                if workspace.id == viewModel.activeWorkspaceId {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(workspace.id == viewModel.activeWorkspaceId ? Color.accentColor : Color.clear, lineWidth: 3)
        )
    }
}
