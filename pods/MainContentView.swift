import AVFoundation
import SwiftUI
import MicrosoftCognitiveServicesSpeech
import Combine
import UIKit




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
    @EnvironmentObject var proFeatureGate: ProFeatureGate
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
    @State private var agentPendingRetryDescription: String?
    @State private var agentPendingRetryMealType: String?
    @State private var showAgentChat = false
    @StateObject private var agentChatViewModel = AgentChatViewModel(userEmail: UserDefaults.standard.string(forKey: "userEmail") ?? "")
    
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
                let _ = print("🔄 MainContentView.body: Authenticated user - showing main app interface")
                let _ = print("🔄 MainContentView.body: Onboarding completed: \(viewModel.onboardingCompleted), Server completed: \(viewModel.serverOnboardingCompleted)")

                ZStack(alignment: .bottom) {
                    VStack {
                        Group {
                            switch selectedTab {
                            case 0:
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
                            case 2:
                                PodsContainerView()
                            case 3:
                                FriendsView()
                            case 4:
                                MyProfileView(isAuthenticated: $isAuthenticated)
                            default:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: selectedTab) { _, newValue in
                            if newValue == 1 {
                                showingVideoCreationScreen = true
                            }
                        }
                        .onDisappear {
                            selectedTab = 0
                        }
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
                .fullScreenCover(isPresented: $showingVideoCreationScreen) {
                    CameraContainerView(showingVideoCreationScreen: $showingVideoCreationScreen, selectedTab: $selectedTab)
                        .background(Color.black.edgesIgnoringSafeArea(.all))
                }
                .fullScreenCover(isPresented: $viewModel.isShowingFoodContainer) {
                    FoodContainerView()
                        .environmentObject(viewModel)
                }
                .sheet(isPresented: $showNewSheet) {
                    NewSheetView(
                        isPresented: $showNewSheet,
                        showingVideoCreationScreen: $showingVideoCreationScreen,
                        showQuickPodView: $showQuickPodView,
                        selectedTab: $selectedTab,
                        showFoodScanner: $showFoodScanner,
                        showVoiceLog: $showVoiceLog,
                        showLogWorkoutView: $showLogWorkoutView,
                        selectedMeal: $selectedMeal
                    )
                    .presentationDetents([.height(UIScreen.main.bounds.height / 3)])
                    .presentationCornerRadius(25)
                    .presentationBackground(Color(.systemBackground))
                }
                .fullScreenCover(isPresented: $showFoodScanner) {
                    FoodScannerView(isPresented: $showFoodScanner, selectedMeal: selectedMeal) { food, foodLogId in
                        scannedFood = food
                        scannedFoodLogId = foodLogId
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showConfirmFoodView = true
                        }
                    }
                    .edgesIgnoringSafeArea(.all)
                }
                .fullScreenCover(isPresented: $showVoiceLog) {
                    VoiceLogView(isPresented: $showVoiceLog, selectedMeal: selectedMeal)
                }
                .fullScreenCover(isPresented: $showAgentChat) {
                    AgentChatView(viewModel: agentChatViewModel)
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
                .sheet(isPresented: $showConfirmFoodView, onDismiss: {
                    scannedFood = nil
                    scannedFoodLogId = nil
                }) {
                    if let food = scannedFood {
                        NavigationView {
                            ConfirmLogView(
                                path: .constant(NavigationPath()),
                                food: food,
                                foodLogId: scannedFoodLogId
                            )
                        }
                    }
                }
            } else {
                // Debug logging for authentication state
                let _ = print("🔄 MainContentView.body: Not authenticated - showing onboarding")
                MainOnboardingView(isAuthenticated: $isAuthenticated, showTourView: $showTourView)
            }
        }
        .environment(\.isTabBarVisible, $isTabBarVisible)
        .onAppear {
            ensureAgentChatEmailUpToDate()
        }
        .onChange(of: viewModel.email) { _, _ in
            ensureAgentChatEmailUpToDate()
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
        .onChange(of: proFeatureGate.showUpgradeSheet) { _, newValue in
            if !newValue {
                if let pendingDescription = agentPendingRetryDescription,
                   let pendingMealType = agentPendingRetryMealType,
                   proFeatureGate.hasActiveSubscription() {
                    agentPendingRetryDescription = nil
                    agentPendingRetryMealType = nil
                    prepareAgentAnalysisStates()
                    performAgentAnalysis(description: pendingDescription, mealType: pendingMealType)
                } else {
                    agentPendingRetryDescription = nil
                    agentPendingRetryMealType = nil
                }
            }
        }
    }

    // AppStorage keeps isAuthenticated synchronized; no manual persistence needed here
    
    private func handleAgentSubmit() {
        let trimmedText = agentInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        agentPendingRetryDescription = nil
        agentPendingRetryMealType = nil
        agentInputText = ""

        ensureAgentChatEmailUpToDate()
        agentChatViewModel.send(message: trimmedText)
        if !showAgentChat {
            showAgentChat = true
        }
    }

    private func prepareAgentAnalysisStates() {
        print("🆕 Agent text analysis: initializing state")
        foodManager.isGeneratingMacros = true
        foodManager.isLoading = true
        foodManager.macroLoadingMessage = "Analyzing description..."
        foodManager.macroLoadingTitle = "Generating with AI"
        foodManager.updateFoodScanningState(.initializing)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.foodManager.updateFoodScanningState(.preparing(image: UIImage()))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.foodManager.updateFoodScanningState(.uploading(progress: 0.5))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.foodManager.updateFoodScanningState(.analyzing)
        }
    }

    private func performAgentAnalysis(description: String, mealType: String) {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.timeZone = .current
        let dateString = formatter.string(from: dayLogsVM.selectedDate)
        NetworkManagerTwo.shared.analyzeMealOrActivity(description: description, mealType: mealType, date: dateString) { result in
            switch result {
            case .success(let responseData):
                print("✅ Agent analysis succeeded")
                self.agentPendingRetryDescription = nil
                self.agentPendingRetryMealType = nil
                if let entryType = responseData["entry_type"] as? String {
                    if entryType == "food" {
                        self.handleAgentFoodResponse(responseData, mealType: mealType)
                    } else if entryType == "activity" {
                        self.handleAgentActivityResponse(responseData)
                    } else {
                        self.handleAgentAnalysisFailure("Unsupported entry type: \(entryType)")
                    }
                } else {
                    self.handleAgentAnalysisFailure("Missing entry type in response")
                }
            case .failure(let error):
                print("❌ Agent analysis failed: \(error)")
                if let netError = error as? NetworkManagerTwo.NetworkError,
                   case .featureLimitExceeded(let message) = netError {
                    self.handleAgentFeatureLimitExceeded(message: message, description: description, mealType: mealType)
                } else {
                    self.handleAgentAnalysisFailure(error.localizedDescription)
                }
            }
        }
    }

    private func ensureAgentChatEmailUpToDate() {
        let currentEmail = viewModel.email.isEmpty ? (UserDefaults.standard.string(forKey: "userEmail") ?? "") : viewModel.email
        if !currentEmail.isEmpty {
            agentChatViewModel.updateUserEmail(currentEmail)
        }
    }

    private func handleAgentAnalysisFailure(_ message: String) {
        DispatchQueue.main.async {
            self.foodManager.handleScanFailure(.networkError(message))
            self.foodManager.isGeneratingMacros = false
            self.foodManager.isLoading = false
            self.foodManager.macroLoadingMessage = ""
            self.foodManager.macroLoadingTitle = "Generating with AI"
        }
    }

    private func handleAgentFeatureLimitExceeded(message: String,
                                                  description: String,
                                                  mealType: String) {
        agentPendingRetryDescription = description
        agentPendingRetryMealType = mealType
        handleAgentAnalysisFailure(message)
        presentAgentUpgradeSheet()
    }

    private func presentAgentUpgradeSheet() {
        let email = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        if !email.isEmpty {
            Task { await proFeatureGate.refreshUsageSummary(for: email) }
        }
        DispatchQueue.main.async {
            self.proFeatureGate.blockedFeature = .foodScans
            self.proFeatureGate.showUpgradeSheet = true
        }
    }

    private func handleAgentFoodResponse(_ responseData: [String: Any], mealType: String) {
        guard let foodLogId = responseData["food_log_id"] as? Int,
              let foodData = responseData["food"] as? [String: Any] else {
            handleAgentAnalysisFailure("Malformed food response")
            return
        }

        let displayName = foodData["displayName"] as? String ?? "Food Log"
        let calories = responseData["calories"] as? Int ?? 0
        let message = responseData["message"] as? String ?? ""

        var healthAnalysisData: HealthAnalysis? = nil
        if let healthDict = foodData["health_analysis"] as? [String: Any] {
            do {
                let data = try JSONSerialization.data(withJSONObject: healthDict, options: [])
                let decoder = JSONDecoder()
                healthAnalysisData = try decoder.decode(HealthAnalysis.self, from: data)
            } catch {
                print("❌ Failed to decode HealthAnalysis: \(error)")
            }
        }

        var foodNutrients: [Nutrient]? = nil
        if let nutrientsArray = foodData["foodNutrients"] as? [[String: Any]] {
            foodNutrients = nutrientsArray.compactMap { nutrientData in
                guard let name = nutrientData["nutrientName"] as? String,
                      let value = nutrientData["value"] as? Double,
                      let unit = nutrientData["unitName"] as? String else { return nil }
                return Nutrient(nutrientName: name, value: value, unitName: unit)
            }
        }

        let loggedFoodItem = LoggedFoodItem(
            foodLogId: foodLogId,
            fdcId: foodData["fdcId"] as? Int ?? 0,
            displayName: displayName,
            calories: foodData["calories"] as? Double ?? Double(calories),
            servingSizeText: foodData["servingSizeText"] as? String ?? "1 serving",
            numberOfServings: foodData["numberOfServings"] as? Double ?? 1.0,
            brandText: foodData["brandText"] as? String ?? "",
            protein: foodData["protein"] as? Double ?? 0.0,
            carbs: foodData["carbs"] as? Double ?? 0.0,
            fat: foodData["fat"] as? Double ?? 0.0,
            healthAnalysis: healthAnalysisData,
            foodNutrients: foodNutrients
        )

        let combinedLog = CombinedLog(
            type: .food,
            status: responseData["status"] as? String ?? "success",
            calories: Double(calories),
            message: message,
            foodLogId: foodLogId,
            food: loggedFoodItem,
            mealType: mealType,
            mealLogId: nil,
            meal: nil,
            mealTime: nil,
            scheduledAt: dayLogsVM.selectedDate,
            recipeLogId: nil,
            recipe: nil,
            servingsConsumed: nil
        )

        DispatchQueue.main.async {
            self.dayLogsVM.addPending(combinedLog)

            if let idx = self.foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                self.foodManager.combinedLogs[idx] = combinedLog
            } else {
                self.foodManager.combinedLogs.insert(combinedLog, at: 0)
            }

            self.foodManager.lastLoggedItem = (name: displayName, calories: Double(calories))
            self.foodManager.showLogSuccess = true
            ReviewManager.shared.foodWasLogged()
            MealReminderService.shared.mealWasLogged(mealType: mealType)
            self.foodManager.updateFoodScanningState(.completed(result: combinedLog))

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.foodManager.resetFoodScanningState()
                self.foodManager.isGeneratingMacros = false
                self.foodManager.isLoading = false
                self.foodManager.macroLoadingMessage = ""
                self.foodManager.macroLoadingTitle = "Generating Macros with AI"
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.foodManager.showLogSuccess = false
            }
        }
    }

    private func handleAgentActivityResponse(_ responseData: [String: Any]) {
        guard let activityLogId = responseData["activity_log_id"] as? Int,
              let activityName = responseData["activity_name"] as? String,
              let caloriesBurned = responseData["calories_burned"] as? Int,
              let durationMinutes = responseData["duration_minutes"] as? Int,
              let message = responseData["message"] as? String else {
            print("❌ Failed to parse activity response data")
            return
        }

        let activitySummary = ActivitySummary(
            id: String(activityLogId),
            workoutActivityType: formatActivityType(responseData["activity_type"] as? String ?? "Other"),
            displayName: formatActivityName(activityName),
            duration: Double(durationMinutes * 60),
            totalEnergyBurned: Double(caloriesBurned),
            totalDistance: nil,
            startDate: Date(),
            endDate: Date()
        )

        let combinedLog = CombinedLog(
            type: .activity,
            status: "success",
            calories: Double(caloriesBurned),
            message: message,
            foodLogId: nil,
            food: nil,
            mealType: nil,
            mealLogId: nil,
            meal: nil,
            mealTime: nil,
            scheduledAt: dayLogsVM.selectedDate,
            recipeLogId: nil,
            recipe: nil,
            servingsConsumed: nil,
            activityId: String(activityLogId),
            activity: activitySummary,
            workoutLogId: nil,
            workout: nil,
            logDate: formatDateForLog(Date()),
            dayOfWeek: formatDayOfWeek(Date())
        )

        DispatchQueue.main.async {
            self.dayLogsVM.addPending(combinedLog)
            self.foodManager.lastLoggedItem = (name: activityName, calories: Double(caloriesBurned))
            self.foodManager.showLogSuccess = true
            self.foodManager.updateFoodScanningState(.completed(result: combinedLog))

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.foodManager.resetFoodScanningState()
                self.foodManager.isGeneratingMacros = false
                self.foodManager.isLoading = false
                self.foodManager.macroLoadingMessage = ""
                self.foodManager.macroLoadingTitle = "Generating Macros with AI"
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.foodManager.showLogSuccess = false
            }
        }
    }
    
    private func formatDateForLog(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func formatActivityName(_ name: String) -> String {
        switch name.lowercased() {
        case "running": return "Running"
        case "walking": return "Walking"
        case "cycling", "biking": return "Cycling"
        case "swimming": return "Swimming"
        case "hiking": return "Hiking"
        case "yoga": return "Yoga"
        case "weightlifting", "weight lifting", "strength training": return "Strength Training"
        case "cardio": return "Cardio Workout"
        case "tennis": return "Tennis"
        case "basketball": return "Basketball"
        case "soccer", "football": return "Soccer"
        case "rowing": return "Rowing"
        case "elliptical": return "Elliptical"
        case "stairs", "stair climbing": return "Stair Climbing"
        default:
            return name.prefix(1).uppercased() + name.dropFirst().lowercased()
        }
    }

    private func formatActivityType(_ type: String) -> String {
        switch type.lowercased() {
        case "cardio":
            return "Running"
        case "strength":
            return "StrengthTraining"
        case "sports":
            return "Other"
        default:
            return formatActivityName(type)
        }
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
