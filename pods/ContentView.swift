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
    @State private var selectedTab: Int = 0
    @State private var isRecording = false
    @State private var showVideoPreview = false
    @State private var recordedVideoURL: URL?
    @State private var isAuthenticated = true // Track authentication status
    @State private var shouldNavigateToHome = false


    var body: some View {
        Group {
            if isAuthenticated {
                // User is authenticated, show main content
                ZStack(alignment: .bottom) {
                    // Content views
                    Group {
                        switch selectedTab {
                        case 0:
                            HomeView()
                        case 1:
                            CameraContainerView(shouldNavigateToHome: $shouldNavigateToHome)
                                .background(Color.black.edgesIgnoringSafeArea(.all)) 
                                .environment(\.colorScheme, .dark)
                        case 2:
                            ProfileView() // Assuming you have a ProfileView
                        default:
                            Text("Content not available")
                        }


                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: shouldNavigateToHome) { [shouldNavigateToHome] in
                        if shouldNavigateToHome {
                            selectedTab = 0 // Assuming HomeView is at index 0
                            self.shouldNavigateToHome = false // Reset the flag
                        }
                    }

                    // Custom tab bar
                    CustomTabBar(selectedTab: $selectedTab)
                }
            } else {
                // User is not authenticated, show the landing/authentication view
                MainOnboardingView(isAuthenticated:$isAuthenticated)
//                EmptyView()

            }
        }
    }
}

//#Preview {
//    ContentView()
//}
