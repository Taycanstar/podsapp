//
//  podsApp.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//
import GoogleSignIn
import SwiftUI
import Mixpanel

@main
struct podsApp: App {
    @StateObject var sharedViewModel = SharedViewModel()
    @StateObject var onboardingViewModel = OnboardingViewModel()
    @StateObject var uploadViewModel = UploadViewModel()
    @StateObject var homeViewModel = HomeViewModel()
    @StateObject var videoPreloader = VideoPreloader()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var deepLinkHandler = DeepLinkHandler()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
//    @State private var isAuthenticated = false
    @Environment(\.scenePhase) var scenePhase
    
      

    var body: some Scene {
        WindowGroup {
            ContentView()

                .environmentObject(onboardingViewModel)
                .environmentObject(sharedViewModel)
                .environmentObject(uploadViewModel)
                .environmentObject(homeViewModel)
                .environmentObject(themeManager) 
                .environmentObject(deepLinkHandler)
                .environmentObject(videoPreloader)
                .environmentObject(subscriptionManager)
                .preferredColorScheme(themeManager.currentTheme == .system ? nil : (themeManager.currentTheme == .dark ? .dark : .light))
//                .onChange(of: scenePhase) { newPhase in
//                                   if newPhase == .active {
//                                       NetworkManager().determineUserLocation()
//                                   }
//                               }
                .onAppear{
                    NetworkManager().determineUserLocation()
                }
                .onOpenURL { url in
                                  deepLinkHandler.handle(url: url)
                              }
         
        }

    }
}

class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    @Published var activeInvitation: PodInvitation?
    @Published var activeTeamInvitation: TeamInvitation?

    func handle(url: URL) {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
                return
            }
            
            if components.path == "/pods/invite" {
                fetchInvitationDetails(token: token)
            } else if components.path == "/teams/invite" {
                fetchTeamInvitationDetails(token: token)
            }
        }

    private func fetchInvitationDetails(token: String) {
        NetworkManager().fetchInvitationDetails(token: token) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let invitation):
                    self.activeInvitation = invitation
                case .failure(let error):
                    print("Failed to fetch invitation details: \(error)")
                }
            }
        }
    }
    
    private func fetchTeamInvitationDetails(token: String) {
          NetworkManager().fetchTeamInvitationDetails(token: token) { result in
              DispatchQueue.main.async {
                  switch result {
                  case .success(let invitation):
                      self.activeTeamInvitation = invitation
                  case .failure(let error):
                      print("Failed to fetch team invitation details: \(error)")
                  }
              }
          }
      }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        if let mixpanelToken = ConfigurationManager.shared.getValue(forKey: "MP_TOKEN") as? String {
            Mixpanel.initialize(token: mixpanelToken, trackAutomaticEvents: false)
            print("Mixpanel set!")
            
            // Send a test event to verify Mixpanel initialization
            Mixpanel.mainInstance().track(event: "Test Initialization Event")
            print("Test Initialization Event sent to Mixpanel")
        } else {
            print("Error: MP_TOKEN is missing or not a valid String.")
        }


   
        // Restore previous sign-in state if available
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                print("Error restoring previous sign-in: \(error.localizedDescription)")
            } else {
                print("Restored previous sign-in: \(String(describing: user))")
            }
        }
     
        return true
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let incomingURL = userActivity.webpageURL,
           let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: true) {
            
            let deepLinkHandler = DeepLinkHandler.shared
            
            if components.path == "/pods/invite" {
                handlePodInvitation(components: components, deepLinkHandler: deepLinkHandler)
                return true
            } else if components.path == "/teams/invite" {
                handleTeamInvitation(components: components, deepLinkHandler: deepLinkHandler)
                return true
            }
        }
        return false
    }

    private func handlePodInvitation(components: URLComponents, deepLinkHandler: DeepLinkHandler) {
        guard let podIdString = components.queryItems?.first(where: { $0.name == "podId" })?.value,
              let invitationToken = components.queryItems?.first(where: { $0.name == "invitationToken" })?.value,
              let userName = components.queryItems?.first(where: { $0.name == "userName" })?.value,
              let userEmail = components.queryItems?.first(where: { $0.name == "userEmail" })?.value,
              let podName = components.queryItems?.first(where: { $0.name == "podName" })?.value,
              let invitationType = components.queryItems?.first(where: { $0.name == "invitationType" })?.value,
              let podId = Int(podIdString) else {
            return
        }
        
        deepLinkHandler.activeInvitation = PodInvitation(id: 0, podId: podId, token: invitationToken, userName: userName, userEmail: userEmail, podName: podName, invitationType: invitationType)
    }

    private func handleTeamInvitation(components: URLComponents, deepLinkHandler: DeepLinkHandler) {
        guard let teamIdString = components.queryItems?.first(where: { $0.name == "teamId" })?.value,
              let invitationToken = components.queryItems?.first(where: { $0.name == "invitationToken" })?.value,
              let userName = components.queryItems?.first(where: { $0.name == "userName" })?.value,
              let userEmail = components.queryItems?.first(where: { $0.name == "userEmail" })?.value,
              let teamName = components.queryItems?.first(where: { $0.name == "teamName" })?.value,
              let invitationType = components.queryItems?.first(where: { $0.name == "invitationType" })?.value,
              let teamId = Int(teamIdString) else {
            return
        }
        
        deepLinkHandler.activeTeamInvitation = TeamInvitation(id: 0, teamId: teamId, token: invitationToken, userName: userName, userEmail: userEmail, teamName: teamName, invitationType: invitationType)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "podstack" {
            // Handle your deep link
            DeepLinkHandler.shared.handle(url: url)
            return true
        } else {
            // Handle Google Sign-In
            return GIDSignIn.sharedInstance.handle(url)
        }
    }
}


