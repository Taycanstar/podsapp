import AVFoundation
import SwiftUI
import MicrosoftCognitiveServicesSpeech
import Combine

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
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = false
    @State private var showingVideoCreationScreen = false
    @State private var selectedCameraMode = CameraMode.fifteen
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @State private var showTourView = false
    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var deepLinkHandler: DeepLinkHandler
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var subscriptionStatus: String = "none"
    @State private var subscriptionPlan: String?
    @State private var subscriptionExpiresAt: Date?
    @State private var forceRefresh: Bool = false

    @State private var showAddSheet = false
    @State private var showNewSheet = false
    @State private var showQuickPodView = false
    @State private var showFoodScanner = false
    @State private var showVoiceLog = false
    @State private var showLogWorkoutView = false
    @State private var showBiWeeklyNotificationAlert = false
    
    // State for selected meal - initialized with time-based default
    @State private var selectedMeal: String = {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  // 5:00 AM to 11:59 AM
            return "Breakfast"
        case 12..<17:  // 12:00 PM to 4:59 PM
            return "Lunch"
        default:  // 5:00 PM to 4:59 AM
            return "Dinner"
        }
    }()
    
    // New states for barcode confirmation
    @State private var showConfirmFoodView = false
    @State private var scannedFood: Food?
    @State private var scannedFoodLogId: Int?
    
    @State private var shouldNavigateToNewPod = false
    @State private var newPodId: Int?

    @State private var isTabBarVisible: Bool = true
    @State private var hasCheckedOnboarding = false

    @ObservedObject private var versionManager = VersionManager.shared
    @Environment(\.scenePhase) var scenePhase

    private func fetchInitialPods() {
        homeViewModel.fetchPodsForUser(email: viewModel.email) {
            print("Initial pods fetch completed")
        }
    }

    private var proOnboardingBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showProOnboarding },
            set: { viewModel.showProOnboarding = $0 }
        )
    }

    var body: some View {
        Group {
            if isAuthenticated {
                // Debug logging for navigation state
                let _ = print("🔄 ContentView.body: Authenticated user - showing main app interface")
                let _ = print("🔄 ContentView.body: Onboarding completed: \(viewModel.onboardingCompleted), Server completed: \(viewModel.serverOnboardingCompleted)")
                ZStack(alignment: .bottom) {
                    VStack {
                        Group {
                            switch selectedTab {
                            case 0:
//                                HomeView(shouldNavigateToNewPod: $shouldNavigateToNewPod, newPodId: $newPodId)
                                DashboardView()
                            // PodsContainerView()

                           case 2:
                               
                               PodsContainerView()
                           case 3:
                               FriendsView()
                            case 4:
                                // ProfileView(isAuthenticated: $isAuthenticated, showTourView: $showTourView)
                                MyProfileView(isAuthenticated: $isAuthenticated)
                            default:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(.keyboard)
                        .onChange(of: selectedTab) {_, newValue in
                            if newValue == 1 {
                                showingVideoCreationScreen = true
                            }
                        }
                        .onDisappear {
                            selectedTab = 0
                        }
                    }
      .disabled(versionManager.requiresUpdate)
        .alert("Update Required", isPresented: $versionManager.requiresUpdate) {
            Button("Update") {
                if let url = URL(string: versionManager.storeUrl ?? "") {
                    UIApplication.shared.open(url)
                }
            }
            .tint(.accentColor)
        } message: {
            Text("An update to Humuli is required to continue.")
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active && !hasCheckedOnboarding {
                checkAndResumeOnboarding()
            }
        }
        .task {
            checkAndResumeOnboarding()
        }
                    
                    if isTabBarVisible {
                        CustomTabBar(selectedTab: $selectedTab, showVideoCreationScreen: $showingVideoCreationScreen, showQuickPodView: $showQuickPodView, showNewSheet: $showNewSheet)
                            .ignoresSafeArea(.keyboard)
                    }
                    
                }
                .ignoresSafeArea(.keyboard)

                .fullScreenCover(isPresented: $showingVideoCreationScreen) {
                    CameraContainerView(showingVideoCreationScreen: $showingVideoCreationScreen, selectedTab: $selectedTab)
                        .background(Color.black.edgesIgnoringSafeArea(.all))
                }
                
                // Food container as a fullScreenCover
                .fullScreenCover(isPresented: $viewModel.isShowingFoodContainer) {
                    FoodContainerView()
                        .environmentObject(viewModel)
                }
                

                
                .sheet(isPresented: $showNewSheet) {
                    NewSheetView(isPresented: $showNewSheet,
                                 showingVideoCreationScreen: $showingVideoCreationScreen,
                                 showQuickPodView: $showQuickPodView, 
                                 selectedTab: $selectedTab,
                                 showFoodScanner: $showFoodScanner,
                                 showVoiceLog: $showVoiceLog,
                                 showLogWorkoutView: $showLogWorkoutView,
                                 selectedMeal: $selectedMeal)
                        .presentationDetents([.height(UIScreen.main.bounds.height / 3)])
                        .presentationCornerRadius(25)
                        .presentationBackground(Color(.systemBackground))
                }

                .fullScreenCover(isPresented: $showFoodScanner) {
                    FoodScannerView(isPresented: $showFoodScanner, selectedMeal: selectedMeal, onFoodScanned: { food, foodLogId in
                        // When a barcode is scanned and food is returned, show the confirmation view
                        print("🔍 DEBUG ContentView: Received food: \(food.description), foodLogId: \(String(describing: foodLogId))")
                        scannedFood = food
                        scannedFoodLogId = foodLogId
                        print("🔍 DEBUG ContentView: Set scannedFood and scannedFoodLogId")
                        // Small delay to ensure transitions are smooth
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            print("🔍 DEBUG ContentView: About to show ConfirmLogView sheet")
                            showConfirmFoodView = true
                        }
                    })
                    .edgesIgnoringSafeArea(.all)
                }

                .fullScreenCover(isPresented: $showVoiceLog) {
                    VoiceLogView(isPresented: $showVoiceLog, selectedMeal: selectedMeal)
                        .onAppear {
                            print("VoiceLogView appeared from ContentView")
                            print("🍽️ ContentView passing selectedMeal to VoiceLogView: \(selectedMeal)")
                        }
                        .onDisappear {
                            print("VoiceLogView disappeared from ContentView")
                        }
                }

                .fullScreenCover(isPresented: $showLogWorkoutView) {
                    WorkoutContainerView(selectedTab: $selectedTab)
                }

                .fullScreenCover(item: $deepLinkHandler.activeInvitation) { invitation in
                    InvitationView(invitation: invitation)
                }
                .fullScreenCover(item: $deepLinkHandler.activeTeamInvitation) { invitation in
                                 TeamInvitationView(invitation: invitation)
                             }

                .fullScreenCover(isPresented: proOnboardingBinding) {
                    ProOnboardingView(isPresented: proOnboardingBinding)
                }
                
                // Add presentation for ConfirmLogView when food is scanned
                .sheet(isPresented: $showConfirmFoodView, onDismiss: {
                    // Reset scanned food data
                    scannedFood = nil
                    scannedFoodLogId = nil
                }) {
                    if let food = scannedFood {
                        NavigationView {
                            ConfirmLogView(
                                path: .constant(NavigationPath()), // Dummy navigation path since we're using sheets
                                food: food,
                                foodLogId: scannedFoodLogId
                            )
                        }
                    }
                }
                
                .environment(\.isTabBarVisible, $isTabBarVisible)
            } else {
                // Debug logging for authentication state
                let _ = print("🔄 ContentView.body: Not authenticated - showing onboarding")
                MainOnboardingView(isAuthenticated: $isAuthenticated, showTourView: $showTourView)
            }
        }

        // REMOVED: Old onboarding system (OnboardingFlowContainer) - now using new onboarding in RegisterView
        // .fullScreenCover(isPresented: $viewModel.isShowingOnboarding) {
        //     OnboardingFlowContainer(viewModel: viewModel)
        //         .environmentObject(viewModel)
        // }
        .id(forceRefresh)
        .onAppear {
            print("⚠️ ContentView appeared: Force checking onboarding status")
            forceCheckOnboarding()
            setupNotificationObservers()
        }
        .onChange(of: selectedMeal) { _, newValue in
            print("🍽️ ContentView selectedMeal changed to: \(newValue)")
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                print("⚠️ App became active: Force checking onboarding status")
                forceCheckOnboarding()
                
                // Reset selectedDate to today if we've been away for more than 20 minutes
                if let lastActiveTime = UserDefaults.standard.object(forKey: "lastActiveTime") as? Date {
                    let timeAway = Date().timeIntervalSince(lastActiveTime)
                    let resetThreshold: TimeInterval = 20 * 60 // 20 minutes in seconds
                    
                    if timeAway > resetThreshold {
                        print("🕒 App was backgrounded for \(Int(timeAway/60)) minutes - resetting to today")
                        // Reset to today in DayLogsViewModel
                        dayLogsVM.selectedDate = Date()
                        // Also clear the stored time since we've reset
                        UserDefaults.standard.removeObject(forKey: "lastActiveTime")
                    } else {
                        print("🕒 App was backgrounded for only \(Int(timeAway/60)) minutes - keeping current date")
                    }
                } else {
                    print("🕒 No previous background time recorded")
                }
                
                Task {
                    await versionManager.checkVersion()
                }
            } else if newPhase == .background {
                // Store the time when app goes to background
                UserDefaults.standard.set(Date(), forKey: "lastActiveTime")
                print("🕒 App backgrounded at \(Date())")
            }
        }
        .onChange(of: isAuthenticated) { _, newValue in
            print("🔄 ContentView: isAuthenticated changed to \(newValue)")
            if newValue {
                print("🔄 ContentView: User authenticated - fetching initial data and checking state")
                fetchInitialPods()

     
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    print("🔄 ContentView: Running delayed state check after authentication")
                    self.forceCheckOnboarding()
                }
            }
        }
        .alert("Stay on Track", isPresented: $showBiWeeklyNotificationAlert) {
            Button("Enable in Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Remind Me Later", role: .cancel) {
                // Snooze for another 2 weeks
                let userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? "unknown"
                UserDefaults.standard.set(Date(), forKey: "notification_prompt_date_\(userEmail)")
            }
        } message: {
            Text("Get gentle meal reminders and activity celebrations to help maintain your streak. You can configure these in Settings.")
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: .subscriptionPurchased)
                .receive(on: RunLoop.main)
        ) { _ in
            fetchSubscriptionInfo(force: true)
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSNotification.Name("ShowFoodConfirmation"))
                .receive(on: RunLoop.main)
        ) { notification in
            // Handle scan completion - show confirmation view (works for both barcode and photo scanning)
            print("🔍 DEBUG NotificationCenter: Received ShowFoodConfirmation notification")
            if let userInfo = notification.userInfo,
               let food = userInfo["food"] as? Food {
                print("📱 Received ShowFoodConfirmation notification for: \(food.displayName)")
                print("🩺 [DEBUG] ContentView received food.healthAnalysis: \(food.healthAnalysis?.score ?? -1)")
                print("🔍 DEBUG NotificationCenter: Setting scannedFood and showing sheet")
                
                // Set the scanned food data
                scannedFood = food
                // Try to get foodLogId if it exists (for photo scanning), otherwise nil (for barcode scanning)
                if let foodLogId = userInfo["foodLogId"] as? Int {
                    scannedFoodLogId = foodLogId
                } else {
                    scannedFoodLogId = nil  // No log ID yet since not confirmed
                }
                
                // Show the confirmation view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    print("🔍 DEBUG NotificationCenter: About to set showConfirmFoodView = true")
                    showConfirmFoodView = true
                }
            } else {
                print("❌ DEBUG NotificationCenter: Failed to extract food from notification userInfo")
            }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSNotification.Name("ShowNewSheetFromDashboard"))
                .receive(on: RunLoop.main)
        ) { _ in
            // Handle request from DashboardView to show NewSheetView
            print("📱 Received ShowNewSheetFromDashboard notification")
            showNewSheet = true
        }

    // AppStorage keeps isAuthenticated synchronized; no manual persistence needed here
}
    
    
    func hasPremiumAccess() -> Bool {
            return viewModel.subscriptionStatus == "active" && viewModel.subscriptionPlan != nil && viewModel.subscriptionPlan != "None"
        }
    
    func getCurrentSubscriptionTier() -> SubscriptionTier {
            return SubscriptionTier(rawValue: viewModel.subscriptionPlan ?? "None") ?? .none
        }
    
    private func fetchSubscriptionInfo(force: Bool = false) {
        let email = viewModel.email
        guard !email.isEmpty else { return }

        Task {
            await SubscriptionRepository.shared.refresh(force: force)
            if let info = SubscriptionRepository.shared.subscription {
                await MainActor.run {
                    viewModel.updateSubscriptionInfo(
                        status: info.status,
                        plan: info.plan,
                        expiresAt: info.expiresAt,
                        renews: info.renews,
                        seats: info.seats,
                        canCreateNewTeam: info.canCreateNewTeam
                    )
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
    
    private func checkAndResumeOnboarding() {
        // Mark that we've checked onboarding status
        hasCheckedOnboarding = true
        
        // Get all relevant onboarding state
        self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        
        // REMOVED: Old onboarding trigger logic - now using new onboarding in RegisterView
        // The new onboarding system handles user registration and profile setup directly
        // No need to trigger the old OnboardingFlowContainer

        // Use viewModel for onboarding state
        viewModel.onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")
        print("Onboarding state check: isAuthenticated=\(isAuthenticated), completed=\(viewModel.onboardingCompleted)")
        
        // Load user data if authenticated
        if isAuthenticated {
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
    }

    // FORCE direct check that always runs and has immediate UI updates
    private func forceCheckOnboarding() {
        // Load basic user data first - keep this as we still need to check authentication status
        self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        
        // Always load the server onboarding status if available
        viewModel.serverOnboardingCompleted = UserDefaults.standard.bool(forKey: "serverOnboardingCompleted")
        
        // Load all user data
        if isAuthenticated {
            if let storedEmail = UserDefaults.standard.string(forKey: "userEmail") {
                viewModel.email = storedEmail
                
                // Only check for different user if the server says onboarding is NOT completed
                // If the server says onboarding is completed, we should trust that over the local email check
                if !viewModel.serverOnboardingCompleted {
                    // Check if this is a different user than the one who completed onboarding
                    if let completedEmail = UserDefaults.standard.string(forKey: "emailWithCompletedOnboarding"),
                       completedEmail != storedEmail {
                        // Different user, need to reset onboarding state
                        print("⚠️ Detected different user login. Resetting onboarding state.")
                        viewModel.onboardingCompleted = false
                        // We still set UserDefaults here as other components might be reading it directly
                        UserDefaults.standard.set(false, forKey: "onboardingCompleted")
                        UserDefaults.standard.set(true, forKey: "onboardingInProgress")
                        UserDefaults.standard.removeObject(forKey: "currentOnboardingStep")
                        // Make sure viewModel state is consistent
                        viewModel.currentFlowStep = .gender
                    }
                }
            }
            
            // If the server says onboarding is completed, update our local state to match
            if viewModel.serverOnboardingCompleted {
                viewModel.onboardingCompleted = true
                UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                UserDefaults.standard.set(false, forKey: "onboardingInProgress")
                // Also save the email to prevent future confusion
                if !viewModel.email.isEmpty {
                    UserDefaults.standard.set(viewModel.email, forKey: "emailWithCompletedOnboarding")
                }
                print("✅ Server says onboarding is completed - updating local state to match")
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

        // Now check onboarding state using the viewModel and UserDefaults
        // (we're in a transition, so we read from UserDefaults but update the viewModel)
        viewModel.onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")
        let onboardingInProgress = UserDefaults.standard.bool(forKey: "onboardingInProgress")
        let currentStep = UserDefaults.standard.string(forKey: "currentOnboardingStep")
        let flowStepRaw = UserDefaults.standard.integer(forKey: "onboardingFlowStep")
        
        print("🟥 AUTH STATUS: \(isAuthenticated)")
        print("🟥 ONBOARDING COMPLETED: \(viewModel.onboardingCompleted)")
        print("🟥 ONBOARDING COMPLETED (SERVER): \(viewModel.serverOnboardingCompleted)")
        print("🟥 ONBOARDING IN PROGRESS: \(onboardingInProgress)")
        print("🟥 CURRENT STEP: \(currentStep ?? "none")")
        print("🟥 FLOW STEP RAW: \(flowStepRaw)")

        // REMOVED: Server onboarding sync logic
        // The new onboarding system doesn't need to sync local/server onboarding state
        // since RegisterView handles everything during account creation

        // REMOVED: Old server-based onboarding resume logic
        // The new onboarding system (RegisterView) handles all registration and profile setup
        // No need to check server onboarding status or resume old flow

        print("✅ Using new onboarding system - old flow disabled")

        // Add observer for authentication completion notification
        NotificationCenter.default.addObserver(forName: Notification.Name("AuthenticationCompleted"), object: nil, queue: .main) { _ in
            print("🔔 ContentView: Received AuthenticationCompleted notification")
            // Force refresh authentication state
            self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")

            // Ensure we properly handle the navigation after authentication
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔔 ContentView: Processing authentication completion")
                self.forceCheckOnboarding()
            }
        }

        StartupCoordinator.shared.bootstrapIfNeeded(
            onboarding: viewModel,
            foodManager: foodManager,
            dayLogs: dayLogsVM,
            subscriptionManager: subscriptionManager
        )
    }

    // MARK: - Notification Permission Sheet Setup
    
    private func setupNotificationObservers() {
        // Listen for bi-weekly notification reminder
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowBiWeeklyNotificationReminder"),
            object: nil,
            queue: .main
        ) { _ in
            print("📱 Showing bi-weekly notification alert")
            showBiWeeklyNotificationAlert = true
        }
    }
}
