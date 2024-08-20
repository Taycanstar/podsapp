
import AVFoundation
import SwiftUI
import MicrosoftCognitiveServicesSpeech

struct TabBarVisibilityKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

extension EnvironmentValues {
    var isTabBarVisible: Binding<Bool> {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }
}

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @State private var isRecording = false
    @State private var showVideoPreview = false
    @State private var recordedVideoURL: URL?
    @State private var isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
    @State private var showingVideoCreationScreen = false
    @State private var selectedCameraMode = CameraMode.fifteen
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showTourView = false
    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var deepLinkHandler: DeepLinkHandler


    @State private var showAddSheet = false
    @State private var showQuickPodView = false
    
    @State private var shouldNavigateToNewPod = false
    @State private var newPodId: Int?
    
    @State private var isTabBarVisible: Bool = true

    private func fetchInitialPods() {
        homeViewModel.fetchPodsForUser(email: viewModel.email) {
            print("Initial pods fetch completed")
        }
    }

    var body: some View {
        Group {
            if isAuthenticated {
                ZStack(alignment: .bottom) {
                    VStack {
                        Group {
                            switch selectedTab {
                            case 0:
                                HomeView(shouldNavigateToNewPod: $shouldNavigateToNewPod, newPodId: $newPodId)
                            case 2:
                                ProfileView(isAuthenticated: $isAuthenticated, showTourView: $showTourView)
                            default:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: selectedTab) {_, _ in
                            if selectedTab == 1 {
                                showingVideoCreationScreen = true
                            }
                        }
                        .onDisappear {
                            selectedTab = 0
                        }
                    }
                    if isTabBarVisible {
                        CustomTabBar(selectedTab: $selectedTab, showVideoCreationScreen: $showingVideoCreationScreen, AddOptionsSheet: $showAddSheet)
                    }
                }
                .sheet(isPresented: $showAddSheet) {
                    AddSheetView(showAddSheet: $showAddSheet, showingVideoCreationScreen: $showingVideoCreationScreen, showQuickPodView: $showQuickPodView)
                        .presentationDetents([.height(UIScreen.main.bounds.height / 3.5)])
                }
             
                .fullScreenCover(isPresented: $showingVideoCreationScreen) {
                    CameraContainerView(showingVideoCreationScreen: $showingVideoCreationScreen, selectedTab: $selectedTab)
                        .background(Color.black.edgesIgnoringSafeArea(.all))
                }
                .sheet(isPresented: $showQuickPodView) {
                    QuickPodView(isPresented: $showQuickPodView) { newPod in
                        self.newPodId = newPod.id
                        self.selectedTab = 0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.shouldNavigateToNewPod = true
                        }
                    }
                    .presentationDetents([.height(UIScreen.main.bounds.height / 3)])
                }
//        
//
//                .fullScreenCover(item: $deepLinkHandler.activeInvitation) { invitation in
//                    InvitationView(podId: invitation.podId, token: invitation.token, userEmail: invitation.userEmail, userName: invitation.userName, podName: invitation.podName)
//                }
                .fullScreenCover(item: $deepLinkHandler.activeInvitation) { invitation in
                    InvitationView(invitation: invitation)
                }
                .environment(\.isTabBarVisible, $isTabBarVisible)
            } else {
                MainOnboardingView(isAuthenticated: $isAuthenticated, showTourView: $showTourView)
            }
        }
        .onChange(of: isAuthenticated) { _, newValue in
            if newValue {
                fetchInitialPods()
            }
        }
        .sheet(isPresented: $showTourView) {
            TourView(isTourViewPresented: $showTourView)
        }
        .onAppear {
            self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
            if let storedEmail = UserDefaults.standard.string(forKey: "userEmail") {
                viewModel.email = storedEmail
            }
            if let storedUsername = UserDefaults.standard.string(forKey: "username") {
                viewModel.username = storedUsername
            }
            if let activeTeamId = UserDefaults.standard.object(forKey: "activeTeamId") as? Int {
                viewModel.activeTeamId = activeTeamId
            }
            if let activeWorkspaceId = UserDefaults.standard.object(forKey: "activeWorkspaceId") as? Int {
                viewModel.activeWorkspaceId = activeWorkspaceId
            }
            viewModel.profileInitial = UserDefaults.standard.string(forKey: "profileInitial") ?? ""
            viewModel.profileColor = UserDefaults.standard.string(forKey: "profileColor") ?? ""
        }
        .onChange(of: isAuthenticated) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "isAuthenticated")
        }
    }
}
