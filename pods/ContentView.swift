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
//    @State private var isAuthenticated = true
    @State private var isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
    @State private var showingVideoCreationScreen = false
    @State private var selectedCameraMode = CameraMode.fifteen
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showTourView = false
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    @State private var showAddSheet = false
    @State private var showQuickPodView = false
    
 
    private func fetchInitialPods() {
        homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
            // This closure is called after the fetch operation completes
            print("Initial pods fetch completed")
            // You could update some UI state here if needed
        }
    }
    @State private var shouldNavigateToNewPod = false
        @State private var newPodId: Int?

    var body: some View {
        Group {
            if isAuthenticated {
//                 User is authenticated, show main content
               
                    ZStack(alignment: .bottom) {
                        // Content views
                        VStack {
                            Group {
                                switch selectedTab {
                                case 0:
                                    HomeView(shouldNavigateToNewPod: $shouldNavigateToNewPod, newPodId: $newPodId)

                                
                                case 2:
                                    //                            ProfileView() // Assuming you have a ProfileView
                                    ProfileView(isAuthenticated: $isAuthenticated, showTourView: $showTourView)
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
                        }
                        CustomTabBar(selectedTab: $selectedTab, showVideoCreationScreen: $showingVideoCreationScreen, AddOptionsSheet: $showAddSheet)
                        
                            .sheet(isPresented: $showAddSheet) {
                                AddSheetView(showAddSheet: $showAddSheet, showingVideoCreationScreen: $showingVideoCreationScreen, showQuickPodView: $showQuickPodView)
                                    .presentationDetents([.height(UIScreen.main.bounds.height / 3.5)])
                                               }
                        
                            .fullScreenCover(isPresented: $showingVideoCreationScreen) {
                                CameraContainerView(showingVideoCreationScreen: $showingVideoCreationScreen, selectedTab: $selectedTab)
                                    .background(Color.black.edgesIgnoringSafeArea(.all))
                            }
//                            .sheet(isPresented: $showQuickPodView) {
//                                                QuickPodView(isPresented: $showQuickPodView)
//                                    .presentationDetents([.height(UIScreen.main.bounds.height / 3)])
//                                            }
                            .sheet(isPresented: $showQuickPodView) {
                                                QuickPodView(isPresented: $showQuickPodView) { newPod in
                                                    self.newPodId = newPod.id
                                                 
                                                    self.selectedTab = 0
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                         // Switch to HomeView tab
                                                        self.shouldNavigateToNewPod = true
                                                    }
                                                }
                                                .presentationDetents([.height(UIScreen.main.bounds.height / 3)])
                                            }
                                        }
         
                
            } else {
                MainOnboardingView(isAuthenticated:$isAuthenticated, showTourView: $showTourView)
                   
                    
            }
        }
        .onChange(of: isAuthenticated) {_, newValue in
                    if newValue {
                        fetchInitialPods()
                    }
                }
        .sheet(isPresented: $showTourView) {
                TourView(isTourViewPresented: $showTourView)
            }
        .onAppear {
                              // Update the authentication state on appearance
                              self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
            if let storedEmail = UserDefaults.standard.string(forKey: "userEmail") {
                                       viewModel.email = storedEmail
                                   }
            if let storedUsername = UserDefaults.standard.string(forKey: "username") {
                                       viewModel.username = storedUsername
                                   }
                          }
                          .onChange(of: isAuthenticated) {_, newValue in
                              // Persist the authentication state
                              UserDefaults.standard.set(newValue, forKey: "isAuthenticated")
                          }
    }
}

//#Preview {
//    ContentView()
//}
