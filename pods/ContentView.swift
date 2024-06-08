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
//    @State private var isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
    @State private var showingVideoCreationScreen = false
    @State private var selectedCameraMode = CameraMode.fifteen
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
   
    
 


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
//                            ProfileView() // Assuming you have a ProfileView
                            ProfileView(isAuthenticated: $isAuthenticated)
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
                                       .onDisappear {
                                           selectedTab = 0
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
        .onAppear {
                              // Update the authentication state on appearance
                              self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
            if let storedEmail = UserDefaults.standard.string(forKey: "userEmail") {
                                       viewModel.email = storedEmail
                                   }
                          }
                          .onChange(of: isAuthenticated) { newValue in
                              // Persist the authentication state
                              UserDefaults.standard.set(newValue, forKey: "isAuthenticated")
                          }
    }
}

//#Preview {
//    ContentView()
//}
