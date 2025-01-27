
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
    @StateObject private var subscriptionManager = SubscriptionManager()
        @State private var subscriptionStatus: String = "none"
        @State private var subscriptionPlan: String?
        @State private var subscriptionExpiresAt: Date?
    @State private var forceRefresh: Bool = false

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
//                                HomeView(shouldNavigateToNewPod: $shouldNavigateToNewPod, newPodId: $newPodId)
                                DashboardView()
                            case 2:
                                ProfileView(isAuthenticated: $isAuthenticated, showTourView: $showTourView)
                            case 3:
                                PodsView()
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
                        CustomTabBar(selectedTab: $selectedTab, showVideoCreationScreen: $showingVideoCreationScreen, showQuickPodView: $showQuickPodView)
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

                .fullScreenCover(item: $deepLinkHandler.activeInvitation) { invitation in
                    InvitationView(invitation: invitation)
                }
                .fullScreenCover(item: $deepLinkHandler.activeTeamInvitation) { invitation in
                                 TeamInvitationView(invitation: invitation)
                             }
                
                .environment(\.isTabBarVisible, $isTabBarVisible)
            } else {
                MainOnboardingView(isAuthenticated: $isAuthenticated, showTourView: $showTourView)
            }
        }
  
        .id(forceRefresh)
        .onChange(of: isAuthenticated) { _, newValue in
            if newValue {
                fetchInitialPods()
                
            }
        }
//        .sheet(isPresented: $showTourView) {
//            TourView(isTourViewPresented: $showTourView)
//        }
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
            
            // Load subscription information
                       subscriptionStatus = UserDefaults.standard.string(forKey: "subscriptionStatus") ?? "none"
                       subscriptionPlan = UserDefaults.standard.string(forKey: "subscriptionPlan")
                       if let expiresAtString = UserDefaults.standard.string(forKey: "subscriptionExpiresAt") {
                           subscriptionExpiresAt = ISO8601DateFormatter().date(from: expiresAtString)
                       }
            
       
                       
                       if isAuthenticated {
                           Task {
                               await subscriptionManager.updatePurchasedSubscriptions()
                           }
                           
                           fetchSubscriptionInfo()
                       }
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionPurchased)) { _ in
                 fetchSubscriptionInfo()
             }
//             .onReceive(NotificationCenter.default.publisher(for: .subscriptionUpdated)) { _ in
//                 forceRefresh.toggle()
//             }
        .onChange(of: isAuthenticated) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "isAuthenticated")
        }
    }
    
    
    func hasPremiumAccess() -> Bool {
            return viewModel.subscriptionStatus == "active" && viewModel.subscriptionPlan != nil && viewModel.subscriptionPlan != "None"
        }
    
    func getCurrentSubscriptionTier() -> SubscriptionTier {
            return SubscriptionTier(rawValue: viewModel.subscriptionPlan ?? "None") ?? .none
        }
    
    private func fetchSubscriptionInfo() {
        let email = viewModel.email
        
        NetworkManager().fetchSubscriptionInfo(for: email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let subscriptionInfo):
                    viewModel.updateSubscriptionInfo(
                        status: subscriptionInfo.status,
                        plan: subscriptionInfo.plan,
                        expiresAt: subscriptionInfo.expiresAt,
                        renews: subscriptionInfo.renews,
                        seats: subscriptionInfo.seats,
                        canCreateNewTeam: subscriptionInfo.canCreateNewTeam
                    )
                    
//                    self.printSubscriptionInfo(source: "Network")
                    
                case .failure(let error):
                    print("Failed to fetch subscription info: \(error.localizedDescription)")
                    // Optionally handle the error, e.g., show an alert to the user
                }
            }
        }
    }
    
    private func printSubscriptionInfo(source: String) {
        print("Subscription Info (from \(source)):")
        print("Status: \(viewModel.subscriptionStatus)")
        print("Plan: \(viewModel.subscriptionPlan ?? "None")")
        print("Expires At: \(viewModel.subscriptionExpiresAt ?? "N/A")")
        print("Has Premium Access: \(hasPremiumAccess())")
        let currentTier = getCurrentSubscriptionTier()
        print("Current Subscription Tier: \(currentTier)")
        print("Can user create team? \(viewModel.canCreateNewTeam)")
        print("--------------------")
    }
}


