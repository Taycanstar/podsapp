//
//  podsApp.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//
import GoogleSignIn
import SwiftUI

@main
struct podsApp: App {
    @StateObject var sharedViewModel = SharedViewModel()
    @StateObject var onboardingViewModel = OnboardingViewModel()
    @StateObject var uploadViewModel = UploadViewModel()
    @StateObject var homeViewModel = HomeViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var deepLinkHandler = DeepLinkHandler()
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

    func handle(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.path == "/pods/invite",
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
            return
        }
        
        fetchInvitationDetails(token: token)
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
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
   
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
           let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: true),
           components.path == "/product/podstack/invite",
           let podIdString = components.queryItems?.first(where: { $0.name == "podId" })?.value,
           let invitationToken = components.queryItems?.first(where: { $0.name == "invitationToken" })?.value,
           let userName = components.queryItems?.first(where: { $0.name == "userName" })?.value,
           let userEmail = components.queryItems?.first(where: { $0.name == "userEmail" })?.value,
           let podName = components.queryItems?.first(where: { $0.name == "podName" })?.value,
           let podId = Int(podIdString) {
            
            let deepLinkHandler = DeepLinkHandler.shared
            deepLinkHandler.activeInvitation = PodInvitation(id: 0, podId: podId, token: invitationToken, userName: userName, userEmail: userEmail, podName: podName)
            return true
        }
        return false
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


//class AppDelegate: NSObject, UIApplicationDelegate {
//    func application(_ application: UIApplication,
//                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        // Restore previous sign-in state if available
//        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
//            if let error = error {
//                print("Error restoring previous sign-in: \(error.localizedDescription)")
//            } else {
//                print("Restored previous sign-in: \(String(describing: user))")
//            }
//        }
//     
//        return true
//    }
//    
//
//        
//    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
//          if url.scheme == "podstack" {
//              // Handle your deep link
//              return true
//          } else {
//              // Handle Google Sign-In
//              return GIDSignIn.sharedInstance.handle(url)
//          }
//      }
//}


