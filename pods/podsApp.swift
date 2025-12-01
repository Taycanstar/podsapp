//
//  podsApp.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//
import GoogleSignIn
import SwiftUI
import Mixpanel
import SwiftData
import os.log

@main
struct podsApp: App {
    init() {
        // VERY LOUD LOG USING OS_LOG (guaranteed to appear in Console.app)
        let logger = Logger(subsystem: "com.humuli.pods", category: "App")
        logger.critical("🚀🚀🚀 APP STARTED WITH OS_LOG DIAGNOSTICS 🚀🚀🚀")
        logger.critical("🚀🚀🚀 BUILD TIMESTAMP: \(Date().description) 🚀🚀🚀")

        // Also try NSLog as backup
        NSLog("🚀🚀🚀 APP STARTED - BUILD WITH NSLOG DIAGNOSTICS 🚀🚀🚀")
        NSLog("🚀🚀🚀 BUILD TIMESTAMP: \(Date()) 🚀🚀🚀")

        // And print as final backup
        print("🚀🚀🚀 APP STARTED - BUILD WITH PRINT DIAGNOSTICS 🚀🚀🚀")

        // Warm exercise database synchronously so data is ready before UI usage
        ExerciseDatabase.warmCache()
    }

    @StateObject var sharedViewModel = SharedViewModel()
    @StateObject var onboardingViewModel = OnboardingViewModel()
    @StateObject var uploadViewModel = UploadViewModel()
    @StateObject var homeViewModel = HomeViewModel()
    @StateObject var podsViewModel = PodsViewModel()
    @StateObject var videoPreloader = VideoPreloader()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var activityManager = ActivityManager()
    @StateObject private var foodManager = FoodManager()
    @StateObject private var deepLinkHandler = DeepLinkHandler()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var dayLogsVM    = DayLogsViewModel()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var mealReminderService = MealReminderService.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
//    @State private var isAuthenticated = false
    @Environment(\.scenePhase) var scenePhase

    private let modelContainer: ModelContainer = podsApp.buildModelContainer()

    // Initialize data architecture services
    @StateObject private var dataLayer = DataLayer.shared
    @StateObject private var dataSyncService = DataSyncService.shared
    
    // Apple Health weight sync service
    @StateObject private var weightSyncService = WeightSyncService.shared
    
    // Global workout manager for state synchronization
    @StateObject private var workoutManager = WorkoutManager.shared
    @StateObject private var proFeatureGate = ProFeatureGate()

    // CRITICAL FIX: Prevent data architecture from reinitializing on every resume
    @State private var hasInitializedDataArchitecture = false
    @State private var hasLoggedOuraStatus = false

    var body: some Scene {
        WindowGroup {
            MainContentView()

                .environmentObject(onboardingViewModel)
                .environmentObject(sharedViewModel)
                .environmentObject(uploadViewModel)
                .environmentObject(podsViewModel)
                .environmentObject(homeViewModel)
                .environmentObject(themeManager)
                .environmentObject(activityManager)
                .environmentObject(foodManager)
                .environmentObject(deepLinkHandler)
                .environmentObject(videoPreloader)
                .environmentObject(subscriptionManager)
                .environmentObject(dayLogsVM)
                .environmentObject(dataLayer)
                .environmentObject(dataSyncService)
                .environmentObject(notificationManager)
                .environmentObject(mealReminderService)
                .environmentObject(workoutManager)
                .environmentObject(proFeatureGate)
                .preferredColorScheme(themeManager.currentTheme == .system ? nil : (themeManager.currentTheme == .dark ? .dark : .light))
//                .onChange(of: scenePhase) { newPhase in
//                                   if newPhase == .active {
//                                       NetworkManager().determineUserLocation()
//                                   }
//                                       }
        .modelContainer(modelContainer)
                .onAppear{
                    Task { @MainActor in
                        migrateLegacyWorkoutStoreIfNeeded(using: modelContainer)
                    }
                    // Migrate legacy fitness goal values in UserDefaults
                    FitnessGoalMigrationService.migrateUserDefaults()
                    NetworkManager().determineUserLocation()

                    // CRITICAL FIX: Only initialize data architecture once per app launch
                    if !hasInitializedDataArchitecture {
                        hasInitializedDataArchitecture = true
                        initializeDataArchitecture()
                    }

                    proFeatureGate.configure(subscriptionManager: subscriptionManager)
                    StartupCoordinator.shared.bootstrapIfNeeded(
                        onboarding: onboardingViewModel,
                        foodManager: foodManager,
                        dayLogs: dayLogsVM,
                        subscriptionManager: subscriptionManager
                    )

                    if !hasLoggedOuraStatus {
                        hasLoggedOuraStatus = true
                        logOuraStatusOnStartup()
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        print("⚠️  App became active")
                        // Only trigger sync if user is authenticated
                        if let userEmail = UserDefaults.standard.string(forKey: "userEmail"), !userEmail.isEmpty {
                            print("✅ User authenticated (\(userEmail)) - triggering Apple Health weight sync")
                            // FIXED: Use Task.detached to run sync on background thread
                            // This prevents UI freeze when app returns from background
                            Task.detached {
                                await WeightSyncService.shared.syncAppleHealthWeights()
                            }
                        } else {
                            print("⏭️  User not authenticated - skipping weight sync")
                        }
                    }
                }
                .onOpenURL { url in
                                  deepLinkHandler.handle(url: url)
                              }
         
        }

    }
    
    // MARK: - Data Architecture Initialization
    
    /// Initialize data architecture services when user is authenticated
    private func initializeDataArchitecture() {
        // Check if user is authenticated
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail"), 
              !userEmail.isEmpty else {
            print("🔄 DataLayer: User not authenticated, skipping initialization")
            return
        }
        
        print("🚀 DataLayer: Initializing data architecture for user: \(userEmail)")
        
        // Initialize DataLayer with user context
        Task {
            await dataLayer.initialize(userEmail: userEmail)
            await dataSyncService.initialize(userEmail: userEmail)
            
            print("✅ DataLayer: Successfully initialized data architecture")

            // Perform initial sync if online
            if dataSyncService.isOnline {
                await dataSyncService.performFullSync()
            }

            // REMOVED: Demo operations that were adding fake sync work on every init
            // This was causing unnecessary notification storms on app resume
        }
    }

    /// Fetch and log Oura connection status once per launch to verify backend data
    private func logOuraStatusOnStartup() {
        let resolvedEmail: String?
        if !onboardingViewModel.email.isEmpty {
            resolvedEmail = onboardingViewModel.email
        } else if let stored = UserDefaults.standard.string(forKey: "userEmail"), !stored.isEmpty {
            resolvedEmail = stored
        } else {
            resolvedEmail = nil
        }

        guard let email = resolvedEmail else {
            print("ℹ️ OuraStatus: Skipping fetch because no authenticated user was found")
            return
        }

        print("🔍 OuraStatus: Fetching remote state for \(email)")
        NetworkManagerTwo.shared.fetchOuraStatus(email: email) { result in
            switch result {
            case .success(let status):
                print("✅ OuraStatus: connected=\(status.connected) userId=\(status.ouraUserId ?? "nil")")
                if let lastSynced = status.lastSyncedAt {
                    print("   └── lastSyncedAt=\(lastSynced)")
                } else {
                    print("   └── lastSyncedAt=nil")
                }
                if let scopes = status.scopes, !scopes.isEmpty {
                    print("   └── scopes=\(scopes)")
                }
            case .failure(let error):
                print("❌ OuraStatus: Failed to fetch status for \(email) - \(error.localizedDescription)")
            }
        }
    }
    
    /// Create ModelContainer with migration error handling
    private static func buildModelContainer() -> ModelContainer {
        do {
            // Try to create the container normally
            return try ModelContainer(
                for: UserProfile.self,
                Exercise.self,
                ExerciseInstance.self,
                SetInstance.self,
                WorkoutSession.self
            )
        } catch {
            print("⚠️ SwiftData migration failed in main app: \(error)")
            print("🔄 Clearing existing SwiftData store and starting fresh...")

            // Clear the existing store
            clearSwiftDataStore()

            do {
                // Try again after clearing
                return try ModelContainer(
                    for: UserProfile.self,
                    Exercise.self,
                    ExerciseInstance.self,
                    SetInstance.self,
                    WorkoutSession.self
                )
            } catch {
                print("❌ Failed to create ModelContainer even after clearing: \(error)")
                // Create an in-memory container as last resort
                let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(
                        for: UserProfile.self,
                        Exercise.self,
                        ExerciseInstance.self,
                        SetInstance.self,
                        WorkoutSession.self,
                        configurations: configuration
                    )
                } catch {
                    fatalError("Failed to create even in-memory ModelContainer: \(error)")
                }
            }
        }
    }

    /// Clear existing SwiftData store files
    private static func clearSwiftDataStore() {
        let fileManager = FileManager.default
        let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
        let walURL = URL.applicationSupportDirectory.appending(path: "default.store-wal")
        let shmURL = URL.applicationSupportDirectory.appending(path: "default.store-shm")

        // Remove store files if they exist
        [storeURL, walURL, shmURL].forEach { url in
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: url)
                print("🗑️ Removed: \(url.lastPathComponent)")
            }
        }
    }

    @MainActor
    private func migrateLegacyWorkoutStoreIfNeeded(using container: ModelContainer) {
        let defaults = UserDefaults.standard
        let migrationFlagKey = "WorkoutSessionStoreMigrated"

        guard defaults.bool(forKey: migrationFlagKey) == false else { return }

        let legacyStoreURL = URL.documentsDirectory.appending(path: "WorkoutData.store")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: legacyStoreURL.path) else {
            defaults.set(true, forKey: migrationFlagKey)
            return
        }

        do {
            let configuration = ModelConfiguration(url: legacyStoreURL)
            let legacyContainer = try ModelContainer(
                for: WorkoutSession.self,
                ExerciseInstance.self,
                SetInstance.self,
                configurations: configuration
            )

            let legacyContext = legacyContainer.mainContext
            let descriptor = FetchDescriptor<WorkoutSession>()
            let legacyWorkouts = try legacyContext.fetch(descriptor)
            let targetContext = container.mainContext

            for legacyWorkout in legacyWorkouts {
                let legacyId = legacyWorkout.id
                let existingDescriptor = FetchDescriptor<WorkoutSession>(
                    predicate: #Predicate { $0.id == legacyId }
                )

                let alreadyMigrated = try targetContext.fetch(existingDescriptor).isEmpty == false
                if alreadyMigrated { continue }

                let syncable = SyncableWorkoutSession(from: legacyWorkout)
                let migratedSession = WorkoutSession(from: syncable)
                migratedSession.needsSync = legacyWorkout.needsSync
                targetContext.insert(migratedSession)
            }

            if targetContext.hasChanges {
                try targetContext.save()
            }

            try podsApp.removeLegacyWorkoutStore(at: legacyStoreURL)
            defaults.set(true, forKey: migrationFlagKey)
            print("✅ Migrated legacy workout store with \(legacyWorkouts.count) sessions")
        } catch {
            print("❌ Failed to migrate legacy workout store: \(error)")
        }
    }

    private static func removeLegacyWorkoutStore(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let storeDirectory = storeURL.deletingLastPathComponent()
        let storeName = storeURL.deletingPathExtension().lastPathComponent

        let legacyFiles = [
            storeURL,
            storeDirectory.appending(path: "\(storeName).store-wal"),
            storeDirectory.appending(path: "\(storeName).store-shm")
        ]

        for file in legacyFiles where fileManager.fileExists(atPath: file.path) {
            try fileManager.removeItem(at: file)
            print("🗑️ Removed legacy workout store file: \(file.lastPathComponent)")
        }
    }
}

class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    @Published var activeInvitation: PodInvitation?
    @Published var activeTeamInvitation: TeamInvitation?
    @Published var shouldNavigateToActivitySummary: Bool = false
    @Published var activityData: [String: Any] = [:]

    init() {
        // Listen for activity navigation notifications from NotificationManager
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToActivitySummary"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleActivityNavigation(userInfo: notification.userInfo)
        }
        
        // Listen for food logging navigation from meal reminders
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToFoodLogging"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFoodLoggingNavigation(userInfo: notification.userInfo)
        }
    }

    func handle(url: URL) {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
                return
            }
            
            if components.path == "/pods/invite" {
                fetchInvitationDetails(token: token)
            } else if components.path == "/teams/invite" {
                fetchTeamInvitationDetails(token: token)
            }
        }
    
    // MARK: - Activity Navigation
    
    private func handleActivityNavigation(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo else { return }
        
        // Store activity data for the dashboard to display
        self.activityData = Dictionary(uniqueKeysWithValues: 
            userInfo.compactMap { key, value in
                guard let stringKey = key as? String else { return nil }
                return (stringKey, value)
            }
        )
        self.shouldNavigateToActivitySummary = true
        
        print("🏃‍♂️ Deep linking to activity summary with data: \(activityData)")
        
        // Reset navigation flag after a delay to allow navigation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.shouldNavigateToActivitySummary = false
        }
    }
    
    // MARK: - Food Logging Navigation
    
    private func handleFoodLoggingNavigation(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
              let mealType = userInfo["mealType"] as? String else {
            print("📱 Food logging navigation: Invalid meal type")
            return
        }
        
        print("🍽️ Deep linking to food logging for meal: \(mealType)")
        
        // Navigate to food logging view
        // This would typically trigger a navigation change in the main app
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowFoodLogging"),
            object: nil,
            userInfo: ["mealType": mealType]
        )
    }

    private func fetchInvitationDetails(token: String) {
        NetworkManager().fetchInvitationDetails(token: token) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let invitation):
                    self.activeInvitation = invitation
                case .failure(let error):
                    print("Failed to fetch invitation details: \(error)")
                }
            }
        }
    }
    
    private func fetchTeamInvitationDetails(token: String) {
          NetworkManager().fetchTeamInvitationDetails(token: token) { result in
              DispatchQueue.main.async {
                  switch result {
                  case .success(let invitation):
                      self.activeTeamInvitation = invitation
                  case .failure(let error):
                      print("Failed to fetch team invitation details: \(error)")
                  }
              }
          }
      }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        if let mixpanelToken = ConfigurationManager.shared.getValue(forKey: "MP_TOKEN") as? String {
            Mixpanel.initialize(token: mixpanelToken, trackAutomaticEvents: false)
            print("Mixpanel set!")
            
        } else {
            print("Error: MP_TOKEN is missing or not a valid String.")
        }

        // Register for remote notifications
        registerForPushNotifications()
   
        // Restore previous sign-in state if available
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                print("Error restoring previous sign-in: \(error.localizedDescription)")
            } else {
                print("Restored previous sign-in: \(String(describing: user))")
            }
        }
     
        return true
    }
    
    // MARK: - Push Notification Registration
    
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Remote Notification Handling
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("📱 Device token: \(token)")
        
        // Send token to backend for push notifications
        // This would typically be done when user is authenticated
        if let userEmail = UserDefaults.standard.string(forKey: "userEmail"), !userEmail.isEmpty {
            NetworkManagerTwo.shared.updateDeviceToken(token: token, userEmail: userEmail) { result in
                switch result {
                case .success:
                    print("✅ Device token updated successfully")
                case .failure(let error):
                    print("❌ Failed to update device token: \(error)")
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📱 Received remote notification: \(userInfo)")
        
        // Handle activity push notifications
        NotificationManager.shared.handleActivityPushNotification(userInfo: userInfo)
        
        completionHandler(.newData)
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if let incomingURL = userActivity.webpageURL,
           let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: true) {
            
            let deepLinkHandler = DeepLinkHandler.shared
            
            if components.path == "/pods/invite" {
                handlePodInvitation(components: components, deepLinkHandler: deepLinkHandler)
                return true
            } else if components.path == "/teams/invite" {
                handleTeamInvitation(components: components, deepLinkHandler: deepLinkHandler)
                return true
            }
        }
        return false
    }

    private func handlePodInvitation(components: URLComponents, deepLinkHandler: DeepLinkHandler) {
        guard let podIdString = components.queryItems?.first(where: { $0.name == "podId" })?.value,
              let invitationToken = components.queryItems?.first(where: { $0.name == "invitationToken" })?.value,
              let userName = components.queryItems?.first(where: { $0.name == "userName" })?.value,
              let userEmail = components.queryItems?.first(where: { $0.name == "userEmail" })?.value,
              let podName = components.queryItems?.first(where: { $0.name == "podName" })?.value,
              let invitationType = components.queryItems?.first(where: { $0.name == "invitationType" })?.value,
              let podId = Int(podIdString) else {
            return
        }
        
        deepLinkHandler.activeInvitation = PodInvitation(id: 0, podId: podId, token: invitationToken, userName: userName, userEmail: userEmail, podName: podName, invitationType: invitationType)
    }

    private func handleTeamInvitation(components: URLComponents, deepLinkHandler: DeepLinkHandler) {
        guard let teamIdString = components.queryItems?.first(where: { $0.name == "teamId" })?.value,
              let invitationToken = components.queryItems?.first(where: { $0.name == "invitationToken" })?.value,
              let userName = components.queryItems?.first(where: { $0.name == "userName" })?.value,
              let userEmail = components.queryItems?.first(where: { $0.name == "userEmail" })?.value,
              let teamName = components.queryItems?.first(where: { $0.name == "teamName" })?.value,
              let invitationType = components.queryItems?.first(where: { $0.name == "invitationType" })?.value,
              let teamId = Int(teamIdString) else {
            return
        }
        
        deepLinkHandler.activeTeamInvitation = TeamInvitation(id: 0, teamId: teamId, token: invitationToken, userName: userName, userEmail: userEmail, teamName: teamName, invitationType: invitationType)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "podstack" {
            // Handle your deep link
            DeepLinkHandler.shared.handle(url: url)
            return true
        } else {
            // Handle Google Sign-In
            return GIDSignIn.sharedInstance.handle(url)
        }
    }
}
