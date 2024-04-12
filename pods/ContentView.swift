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
    @State private var isAuthenticated = true
    @State private var showingVideoCreationScreen = false
    @State private var selectedCameraMode = CameraMode.fifteen
    
 


    var body: some View {
        Group {
            if isAuthenticated {
//                 User is authenticated, show main content
                ZStack(alignment: .bottom) {
                    // Content views
                    Group {
                        switch selectedTab {
                        case 0:
                            HomeView()
                        case 2:
                            ProfileView() // Assuming you have a ProfileView
                        default:
                                                    EmptyView() // Removed placeholder text to avoid showing incorrect content
                                                }

                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Detect tab selection changes
                                       .onChange(of: selectedTab) { _ in
                                           if selectedTab == 1 {
                                               showingVideoCreationScreen = true
                                           }
                                       }
                    CustomTabBar(selectedTab: $selectedTab, showVideoCreationScreen: $showingVideoCreationScreen)

                        .fullScreenCover(isPresented: $showingVideoCreationScreen) {
                            CameraContainerView(showingVideoCreationScreen: $showingVideoCreationScreen)
                                .background(Color.black.edgesIgnoringSafeArea(.all))
                        }

                    
                    
                }
             
            } else {
                MainOnboardingView(isAuthenticated:$isAuthenticated)
            }
        }
    }
}

//#Preview {
//    ContentView()
//}
