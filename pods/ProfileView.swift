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
    @Environment(\.isTabBarVisible) var isTabBarVisible
    
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
                            NavigationLink(destination: SubscriptionView()) {
                                Label("Subscription", systemImage: "plus.app")
                                    .foregroundColor(iconColor)
                            }
                            NavigationLink(destination: DataControlsView(isAuthenticated: $isAuthenticated)) {
                                Label("Data Controls", systemImage: "tablecells.badge.ellipsis")
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
//                            Button(action: {
//                                self.showTourView = true
//                            }) {
//                                Label("App tour guide", systemImage: "safari")
//                                    .foregroundColor(iconColor)
//                            }
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
                    .padding(.bottom, 70)
            }
         
            .navigationBarTitle("Settings and privacy", displayMode: .inline)
            .sheet(isPresented: $showingMail) {
                MailView(isPresented: self.$showingMail)
                     }
            .onAppear{
                isTabBarVisible.wrappedValue = true
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
    @State private var isUpdating = false
    @State private var isLoading = true
    @State private var showCreateTeamView = false
    @State private var showSubscriptionView = false
    @State private var showTeamOptionsSheet = false
    @State private var selectedTeam: Team?
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @State private var teamForOptions: Team?  = nil
    
    

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(homeViewModel.teams) { team in
                            teamView(team: team)
                        }
                        addTeamButton
                    }
                    .padding()
                }
            }
        }
        .background(backgroundColorForTheme.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("My team", displayMode: .inline)
        .onAppear {
            isTabBarVisible.wrappedValue = false
            fetchTeams()
        }
        
        .overlay(Group {
            if isUpdating {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(width: 60, height: 60)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(10)
            }
        })
        .sheet(isPresented: $showCreateTeamView) {
            CreateTeamView(isPresented: $showCreateTeamView)
                .presentationDetents([.height(UIScreen.main.bounds.height / 4)])
        }

        .background(
            NavigationLink(destination: SubscriptionView(), isActive: $showSubscriptionView) {
                EmptyView()
            }
        )
        
    }
    
    private func deleteTeam(team: Team) {
        // Implement team deletion logic here
        print("Deleting team: \(team.name)")
    }
    
    
   
    
    private var addTeamButton: some View {
        Button(action: {
            handleAddTeamAction()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.accentColor)
                
                HStack {
                    Spacer()
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                    Text("Add team")
                        .fontWeight(.medium)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .padding(.vertical, 3)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleAddTeamAction() {
        if viewModel.hasActiveSubscription() {
            if viewModel.subscriptionPlan?.contains("Team") == true {
                if viewModel.canCreateNewTeam {
                        showCreateTeamView = true
                    } else {
                        showSubscriptionView = true
                    }
            } else {
                showSubscriptionView = true
            }
        } else {
            showSubscriptionView = true
        }
    }
    
    private func fetchTeams() {
        isLoading = true
        homeViewModel.fetchTeamsForUser(email: viewModel.email)

        isLoading = false

    }

    private var backgroundColorForTheme: Color {
        colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242)
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
                
//                Button(action: {
//           
//                    DispatchQueue.main.async {
//                        self.teamForOptions = team  // Set the correct team
//                    }
//                    
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                        print("Team selected for options: \(team.name), ID: \(team.id)")
//                        // Now show the sheet
//                        showTeamOptionsSheet = true
//        
//                        
//                    }
//                 
//                                     
//                    
//                            
//                           }) {
//                               Image(systemName: "info.circle")
//                                   .font(.system(size: 20))
//                                   .foregroundColor(.accentColor)
//                           }
                
                NavigationLink(destination: TeamOptionsView(
                             showTeamOptionsSheet: .constant(true),
                             onDeleteTeam: { deleteTeam(team: team) },
                             teamName: team.name,
                             teamId: team.id,
                             navigationAction: { destination in
                                 handleNavigation(destination: destination, for: team)
                             }
                         )) {
                             Image(systemName: "info.circle")
                                 .font(.system(size: 20))
                                 .foregroundColor(.accentColor)
                         }
                
            }
            .padding()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(team.id == viewModel.activeTeamId ? Color.accentColor : Color.clear, lineWidth: 3)
        )
        .onTapGesture {
            updateActiveTeam(teamId: team.id)
        }
    }
    
    private func handleNavigation(destination: TeamNavigationDestination, for team: Team) {
        switch destination {
        case .teamInfo:
            // Navigate to TeamInfoView
            // You might want to use a NavigationLink here or programmatic navigation
            print("Navigate to TeamInfoView for team: \(team.name)")
        case .teamMembers:
            // Navigate to TeamMembersView
            print("Navigate to TeamMembersView for team: \(team.name)")
        }
    }

    private func updateActiveTeam(teamId: Int) {
        isUpdating = true
        NetworkManager().updateActiveTeam(email: viewModel.email, teamId: teamId) { result in
            DispatchQueue.main.async {
                isUpdating = false
                switch result {
                case .success(let newActiveTeamId):
                    viewModel.activeTeamId = newActiveTeamId
                    UserDefaults.standard.set(newActiveTeamId, forKey: "activeTeamId")
                case .failure(let error):
                    print("Failed to update active team: \(error.localizedDescription)")
                }
            }
        }
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
        .onTapGesture {
            viewModel.updateActiveWorkspace(workspaceId: workspace.id)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(workspace.id == viewModel.activeWorkspaceId ? Color.accentColor : Color.clear, lineWidth: 3)
        )
    }
}


