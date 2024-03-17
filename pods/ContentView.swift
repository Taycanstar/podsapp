//
//  ContentView.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//
import AVFoundation
import SwiftUI

//// For an iOS app in Swift
import MicrosoftCognitiveServicesSpeech


struct ContentView: View {
    @State private var selectedTab = 0
    @State private var isAuthenticated = true
    @Environment(\.colorScheme) var colorScheme
    @State private var shouldNavigateToHome = false

    var body: some View {
        Group {
            if isAuthenticated {
                TabView(selection: $selectedTab) {
                    HomeView()
//                        .preferredColorScheme(determineAccentColor())
                        .tag(0)
                        .tabItem {
                            Image(systemName: "house")
                             
                            
                               
                        }
                        
                    CameraContainerView(shouldNavigateToHome: $shouldNavigateToHome)
                        .preferredColorScheme(selectedTab == 1 ? .dark : nil)
                                                /* .background(Color.black.edgesIgnoringSafeArea(.top))*/ // Assume necessary properties are passed
                        .tag(1)
                        .tabItem {
                            Image(systemName: "camera")
                             
                        }
                        
                    ProfileView() // Assume ProfileView exists
                        .tag(2)
                        .tabItem {
                            Image(systemName: "person")
                               
                        }
                }
                .accentColor(determineAccentColor())
         
                .onChange(of: selectedTab) {
                                   // Call setTabBarAppearance here if you need to adjust based on the selected tab
                                   setTabBarAppearanceBasedOnSelectedTab()
                               }
            } else {
                // Show authentication view if not authenticated
                MainOnboardingView(isAuthenticated: $isAuthenticated)
            }
        }
    }
    
    private func determineAccentColor() -> Color {
          colorScheme == .dark ? .white : .black
      }
    
    private func setTabBarAppearanceBasedOnSelectedTab() {
        // This function now checks the selectedTab and applies appearance changes accordingly
        if selectedTab == 1 { // Assuming the Camera view is at index 1
            // Apply dark appearance specifically for Camera view
            setTabBarAppearance(colorScheme: .dark)
        } else {
            // Apply appearance based on system colorScheme for other tabs
            setTabBarAppearance(colorScheme: colorScheme)
        }
    }

    private func setTabBarAppearance(colorScheme: ColorScheme) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = colorScheme == .dark ? UIColor.black : UIColor.white

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
