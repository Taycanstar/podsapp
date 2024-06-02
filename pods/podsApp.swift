//
//  podsApp.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//

import SwiftUI

@main
struct podsApp: App {
    @StateObject var sharedViewModel = SharedViewModel()
    @StateObject var onboardingViewModel = OnboardingViewModel()
    @StateObject var uploadViewModel = UploadViewModel()
    @StateObject var homeViewModel = HomeViewModel()
    @StateObject private var themeManager = ThemeManager()
    @State private var isAuthenticated = false
   
    
    var body: some Scene {
        WindowGroup {
//            ContentView()
            WelcomeView(isAuthenticated: $isAuthenticated)
                .environmentObject(onboardingViewModel)
                .environmentObject(sharedViewModel)
                .environmentObject(uploadViewModel)
                .environmentObject(homeViewModel)
                .environmentObject(themeManager) 
                .preferredColorScheme(themeManager.currentTheme == .system ? nil : (themeManager.currentTheme == .dark ? .dark : .light))
        }
    }
}
