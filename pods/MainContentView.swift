import AVFoundation
import SwiftUI
import MicrosoftCognitiveServicesSpeech
import Combine




struct MainContentView: View {
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
    @State private var agentInputText: String = ""
    
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

    @ObservedObject private var versionManager = VersionManager.shared
    @Environment(\.scenePhase) var scenePhase

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
                let _ = print("🔄 MainContentView.body: Authenticated user - showing main app interface")
                let _ = print("🔄 MainContentView.body: Onboarding completed: \(viewModel.onboardingCompleted), Server completed: \(viewModel.serverOnboardingCompleted)")
                ZStack(alignment: .bottom) {
                    VStack {
                        Group {
                            switch selectedTab {
                            case 0:
//                                HomeView(shouldNavigateToNewPod: $shouldNavigateToNewPod, newPodId: $newPodId)
                                DashboardContainer(
                                    agentText: $agentInputText,
                                    onPlusTapped: {
                                        HapticFeedback.generate()
                                        showNewSheet = true
                                    },
                                    onBarcodeTapped: {
                                        HapticFeedback.generate()
                                        showFoodScanner = true
                                    },
                                    onMicrophoneTapped: {
                                        HapticFeedback.generate()
                                        showVoiceLog = true
                                    },
                                    onWaveformTapped: {
                                        HapticFeedback.generate()
                                        handleAgentSubmit()
                                    },
                                    onSubmit: {
                                        handleAgentSubmit()
                                    }
                                )
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
        // Removed deprecated onboarding resume task

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
                        print("🔍 DEBUG MainContentView: Received food: \(food.description), foodLogId: \(String(describing: foodLogId))")
                        scannedFood = food
                        scannedFoodLogId = foodLogId
                        print("🔍 DEBUG MainContentView: Set scannedFood and scannedFoodLogId")
                        // Small delay to ensure transitions are smooth
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            print("🔍 DEBUG MainContentView: About to show ConfirmLogView sheet")
                            showConfirmFoodView = true
                        }
                    })
                    .edgesIgnoringSafeArea(.all)
                }

                .fullScreenCover(isPresented: $showVoiceLog) {
                    VoiceLogView(isPresented: $showVoiceLog, selectedMeal: selectedMeal)
                        .onAppear {
                            print("VoiceLogView appeared from MainContentView")
                            print("🍽️ MainContentView passing selectedMeal to VoiceLogView: \(selectedMeal)")
                        }
                        .onDisappear {
                            print("VoiceLogView disappeared from MainContentView")
    }
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
                let _ = print("🔄 MainContentView.body: Not authenticated - showing onboarding")
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
            print("⚠️ MainContentView appeared")
            hydrateAuthenticatedState()
            setupNotificationObservers()
        }
        .onChange(of: selectedMeal) { _, newValue in
            print("🍽️ MainContentView selectedMeal changed to: \(newValue)")
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                print("⚠️ App became active")
                
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

                // CRITICAL FIX: Use Task { @MainActor in } to ensure version check runs on main thread
                // This prevents "Publishing changes from background threads" violations
                Task { @MainActor in
                    await versionManager.checkVersion()
                }
            } else if newPhase == .background {
                // Store the time when app goes to background
                UserDefaults.standard.set(Date(), forKey: "lastActiveTime")
                print("🕒 App backgrounded at \(Date())")
            }
        }
        .onChange(of: isAuthenticated) { _, newValue in
            print("🔄 MainContentView: isAuthenticated changed to \(newValue)")
            if newValue {
                print("🔄 MainContentView: User authenticated - refreshing state")
                hydrateAuthenticatedState()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    print("🔄 MainContentView: Bootstrapping after authentication")
                    StartupCoordinator.shared.bootstrapIfNeeded(
                        onboarding: viewModel,
                        foodManager: foodManager,
                        dayLogs: dayLogsVM,
                        subscriptionManager: subscriptionManager
                    )
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
                print("🩺 [DEBUG] MainContentView received food.healthAnalysis: \(food.healthAnalysis?.score ?? -1)")
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

        // Listen for explicit authentication completion
        .onReceive(
            NotificationCenter.default
                .publisher(for: Notification.Name("AuthenticationCompleted"))
                .receive(on: RunLoop.main)
        ) { _ in
            print("🔔 MainContentView: Received AuthenticationCompleted notification")
            hydrateAuthenticatedState()
            // Bootstrap for the current user and refresh the view
            StartupCoordinator.shared.bootstrapIfNeeded(
                onboarding: viewModel,
                foodManager: foodManager,
                dayLogs: dayLogsVM,
                subscriptionManager: subscriptionManager
            )
            self.forceRefresh.toggle()
        }
    }

    // AppStorage keeps isAuthenticated synchronized; no manual persistence needed here
    
    private func handleAgentSubmit() {
        let trimmedText = agentInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        print("📝 Agent prompt submitted: \(trimmedText)")
        agentInputText = ""
    }
    
    func hasPremiumAccess() -> Bool {
            return viewModel.subscriptionStatus == "active" && viewModel.subscriptionPlan != nil && viewModel.subscriptionPlan != "None"
        }
    
    func getCurrentSubscriptionTier() -> SubscriptionTier {
            return SubscriptionTier(rawValue: viewModel.subscriptionPlan ?? "None") ?? .none
        }
    
    private func hydrateAuthenticatedState() {
        guard isAuthenticated else { return }

        if viewModel.email.isEmpty,
           let storedEmail = UserDefaults.standard.string(forKey: "userEmail"),
           !storedEmail.isEmpty {
            viewModel.email = storedEmail
        }

        if viewModel.username.isEmpty,
           let storedUsername = UserDefaults.standard.string(forKey: "username"),
           !storedUsername.isEmpty {
            viewModel.username = storedUsername
        }

        if viewModel.profileInitial.isEmpty {
            viewModel.profileInitial = UserDefaults.standard.string(forKey: "profileInitial") ?? ""
        }

        if viewModel.profileColor.isEmpty {
            viewModel.profileColor = UserDefaults.standard.string(forKey: "profileColor") ?? ""
        }

        if viewModel.activeTeamId == nil,
           let storedTeamId = UserDefaults.standard.object(forKey: "activeTeamId") as? Int {
            viewModel.activeTeamId = storedTeamId
        }

        if viewModel.activeWorkspaceId == nil,
           let storedWorkspaceId = UserDefaults.standard.object(forKey: "activeWorkspaceId") as? Int {
            viewModel.activeWorkspaceId = storedWorkspaceId
        }

        viewModel.serverOnboardingCompleted = UserDefaults.standard.bool(forKey: "serverOnboardingCompleted")
        viewModel.onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")

        subscriptionStatus = UserDefaults.standard.string(forKey: "subscriptionStatus") ?? "none"
        subscriptionPlan = UserDefaults.standard.string(forKey: "subscriptionPlan")

        if let expiresAtString = UserDefaults.standard.string(forKey: "subscriptionExpiresAt"),
           !expiresAtString.isEmpty {
            subscriptionExpiresAt = ISO8601DateFormatter().date(from: expiresAtString)
        } else {
            subscriptionExpiresAt = nil
        }
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
    
    // Deprecated onboarding checks removed. Auth + StartupCoordinator handle app state.

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
