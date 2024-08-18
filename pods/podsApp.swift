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
              components.path == "/product/podstack/invite",
              let podIdString = components.queryItems?.first(where: { $0.name == "podId" })?.value,
              let invitationToken = components.queryItems?.first(where: { $0.name == "invitationToken" })?.value,
              let podId = Int(podIdString) else {
            return
        }

        activeInvitation = PodInvitation(id: 0, podId: podId, token: invitationToken)
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
           let podId = components.queryItems?.first(where: { $0.name == "podId" })?.value,
           let invitationToken = components.queryItems?.first(where: { $0.name == "invitationToken" })?.value {
            
            if let podIdInt = Int(podId) {
                let deepLinkHandler = DeepLinkHandler.shared
                deepLinkHandler.activeInvitation = PodInvitation(id: 0, podId: podIdInt, token: invitationToken)
            }
            return true
        }
        return false
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "podstack" {
            // Handle your deep link
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


