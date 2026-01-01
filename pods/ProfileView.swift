//
//  ProfileView.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//

import SwiftUI
import MessageUI
import GoogleSignIn
import Combine
import UIKit

struct ProfileView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showingMail = false
    @State private var showUpgradeSheet = false
    @State private var showManageSheet = false
    @Binding var isAuthenticated: Bool
    @Environment(\.isTabBarVisible) var isTabBarVisible

    var body: some View {
        ZStack {
            formBackgroundColor.ignoresSafeArea()
            Form {
                accountSection
                dataSharingSection
                preferencesSection
                supportSection
                logoutSection
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                if isTabBarVisible.wrappedValue {
                    Color.clear.frame(height: 50)
                }
            }
        }
        .navigationBarTitle("Settings and privacy", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }
            }
        }
        .sheet(isPresented: $showingMail) {
            MailView(isPresented: $showingMail)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            HumuliProUpgradeSheet(
                feature: nil,
                usageSummary: nil,
                onDismiss: { showUpgradeSheet = false }
            )
            .environmentObject(subscriptionManager)
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $showManageSheet) {
            ManageSubscriptionSheet(
                subscriptionManager: subscriptionManager,
                viewModel: viewModel,
                onDismiss: { showManageSheet = false }
            )
        }
        .onAppear {
            isTabBarVisible.wrappedValue = true
            refreshSubscriptionState()
        }
    }

    private var accountSection: some View {
        Section(header: Text("Account")) {
            HStack {
                Label("Email", systemImage: "envelope")
                    .foregroundColor(iconColor)
                Spacer()
                Text(viewModel.email)
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)

            NavigationLink(destination: EditNameView()) {
                HStack {
                    Label("Name", systemImage: "person.text.rectangle")
                        .foregroundColor(iconColor)
                    Spacer()
                    Text(displayName)
                        .foregroundColor(iconColor)
                }
            }
            .listRowBackground(rowBackgroundColor)

            NavigationLink(destination: EditUsernameView()) {
                HStack {
                    Label("Username", systemImage: "person")
                        .foregroundColor(iconColor)
                    Spacer()
                    Text(viewModel.username)
                        .foregroundColor(iconColor)
                }
            }
            .listRowBackground(rowBackgroundColor)

            NavigationLink(destination: ManageGoalsView()) {
                Label("Goals and Weight", systemImage: "scalemass")
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)

            Button {
                if isUserSubscribed {
                    showManageSheet = true
                } else {
                    showUpgradeSheet = true
                }
            } label: {
                HStack {
                    Label("Subscription", systemImage: "plus.app")
                        .foregroundColor(iconColor)
                    Spacer()
                    Text(subscriptionLabelText)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(rowBackgroundColor)

            if !isUserSubscribed {
                Button {
                    showUpgradeSheet = true
                } label: {
                    HStack {
                        Label("Upgrade to Metryc Pro", systemImage: "arrow.up.circle")
                            .foregroundColor(iconColor)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(rowBackgroundColor)
            }

            NavigationLink(destination: DataControlsView(isAuthenticated: $isAuthenticated)) {
                Label("Data Controls", systemImage: "tablecells.badge.ellipsis")
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)
        }
    }

    private var dataSharingSection: some View {
        Section(header: Text("Data Sharing")) {
            NavigationLink(destination: AppleHealthSettingsView()) {
                Label("Apple Health", systemImage: "heart.text.square")
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)

            NavigationLink(destination: OuraSettingsView()) {
                Label("Oura Ring", systemImage: "circle")
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)

            NavigationLink(destination: DataSourcesView()) {
                Label("Data Sources", systemImage: "square.3.layers.3d")
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)
        }
    }

    private var preferencesSection: some View {
        Section(header: Text("Preferences")) {
            HStack {
                Label("Theme", systemImage: "paintbrush")
                    .foregroundColor(iconColor)
                Spacer()
                Menu {
                    ForEach(ThemeOption.allCases, id: \.self) { theme in
                        Button(action: {
                            themeManager.setTheme(theme)
                        }) {
                            HStack {
                                Text(theme.rawValue)
                                if themeManager.currentTheme == theme {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(themeManager.currentTheme.rawValue)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listRowBackground(rowBackgroundColor)

            NavigationLink(destination: NotificationSettingsView()) {
                Label("Notifications", systemImage: "bell")
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)

            HStack {
                Label("Units", systemImage: "globe")
                    .foregroundColor(iconColor)
                Spacer()
                Menu {
                    ForEach(UnitsSystem.allCases, id: \.self) { unit in
                        Button(action: {
                            viewModel.unitsSystem = unit
                        }) {
                            HStack {
                                Text(unit.displayName)
                                if viewModel.unitsSystem == unit {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.unitsSystem.displayName)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listRowBackground(rowBackgroundColor)

            NavigationLink(destination: ManageExercisesView()) {
                Label("Manage Exercises", systemImage: "figure.run.square.stack")
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)

            NavigationLink(destination: WorkoutScheduleSettingsView()) {
                Label("Workout Frequency", systemImage: "calendar.badge.clock")
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)

            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(iconColor)
                    Text("Fitness Goal")
                        .font(.system(size: 15))
                        .foregroundColor(iconColor)
                }
                Spacer()
                Menu {
                    ForEach(FitnessGoal.allCases.filter { !["tone", "endurance", "power", "sport"].contains($0.rawValue) }, id: \.self) { goal in
                        Button(action: {
                            updateFitnessGoal(goal)
                        }) {
                            HStack {
                                Text(goal.displayName)
                                if currentFitnessGoal.normalized == goal.normalized {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(currentFitnessGoal.displayName)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listRowBackground(rowBackgroundColor)
        }
    }

    private var supportSection: some View {
        Section(header: Text("Support & About")) {
            Button {
                showingMail = true
            } label: {
                Label("Send feedback", systemImage: "message")
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)

            Link(destination: URL(string: "https://www.humuli.com/policies/terms")!) {
                Label("Terms of Use", systemImage: "doc.plaintext")
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)

            Link(destination: URL(string: "https://www.humuli.com/policies/privacy-policy")!) {
                Label("Privacy Policy", systemImage: "lock")
                    .foregroundColor(iconColor)
            }
            .listRowBackground(rowBackgroundColor)
        }
    }

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                logOut()
            } label: {
                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
            }
            .listRowBackground(rowBackgroundColor)
        }
    }

    private var displayName: String {
        let profileName = viewModel.profileData?.name ?? ""
        let fallbackName = viewModel.name
        let candidate = profileName.isEmpty ? fallbackName : profileName
        return candidate.isEmpty ? "Add name" : candidate
    }
    
    private var subscriptionLabelText: String {
        isUserSubscribed ? "Metryc Pro" : "Free"
    }

    private var isUserSubscribed: Bool {
        if subscriptionManager.hasActiveSubscription() {
            return true
        }

        let status = viewModel.subscriptionStatus.lowercased()
        guard let expires = viewModel.subscriptionExpiresAt,
              let expiryDate = ISO8601DateFormatter.fullFormatter.date(from: expires) else {
            return false
        }

        if status == "active" {
            return true
        }

        if status == "cancelled" {
            return expiryDate > Date()
        }

        return false
    }

    private var iconColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var currentFitnessGoal: FitnessGoal {
        let goalString = UserDefaults.standard.string(forKey: "fitnessGoal") ?? "strength"
        return FitnessGoal.from(string: goalString)
    }

    private var formBackgroundColor: Color {
        colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242)
    }

    private var rowBackgroundColor: Color {
        colorScheme == .dark ? Color(rgb: 44, 44, 44) : .white
    }

    private func updateFitnessGoal(_ goal: FitnessGoal) {
        UserDefaults.standard.set(goal.rawValue, forKey: "fitnessGoal")

        let savedEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        let email = viewModel.email.isEmpty ? savedEmail : viewModel.email

        guard !email.isEmpty else { return }

        NetworkManagerTwo.shared.updateWorkoutPreferences(
            email: email,
            workoutData: ["preferred_fitness_goal": goal.rawValue]
        ) { result in
            switch result {
            case .success:
                print("✅ Fitness goal updated on server")
            case .failure(let error):
                print("❌ Failed to update fitness goal: \(error)")
            }
        }
    }

    private func logOut() {
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "profileInitial")
        UserDefaults.standard.removeObject(forKey: "profileColor")

        UserDefaults.standard.removeObject(forKey: "subscriptionStatus")
        UserDefaults.standard.removeObject(forKey: "subscriptionPlan")
        UserDefaults.standard.removeObject(forKey: "subscriptionExpiresAt")
        UserDefaults.standard.removeObject(forKey: "subscriptionRenews")
        UserDefaults.standard.removeObject(forKey: "subscriptionSeats")
        UserDefaults.standard.removeObject(forKey: "cachedSubscriptionInfo")
        UserDefaults.standard.removeObject(forKey: "cachedSubscriptionInfoTimestamp")
        UserDefaults.standard.removeObject(forKey: "cachedSubscriptionEmail")

        UserDefaults.standard.set(false, forKey: "onboardingCompleted")
        UserDefaults.standard.set(false, forKey: "onboardingInProgress")
        UserDefaults.standard.set(false, forKey: "serverOnboardingCompleted")
        UserDefaults.standard.removeObject(forKey: "currentOnboardingStep")
        UserDefaults.standard.removeObject(forKey: "onboardingFlowStep")
        UserDefaults.standard.removeObject(forKey: "emailWithCompletedOnboarding")

        UserDefaults.standard.removeObject(forKey: "activeTeamId")
        UserDefaults.standard.removeObject(forKey: "activeWorkspaceId")

        GIDSignIn.sharedInstance.signOut()

        isAuthenticated = false
        viewModel.email = ""
        viewModel.username = ""
        viewModel.userId = nil
        viewModel.profileInitial = ""
        viewModel.profileColor = ""
        viewModel.onboardingCompleted = false
        viewModel.serverOnboardingCompleted = false
        viewModel.currentStep = .landing
        viewModel.currentFlowStep = .gender
        viewModel.subscriptionStatus = "none"
        viewModel.subscriptionPlan = nil
        viewModel.subscriptionExpiresAt = nil
        viewModel.subscriptionRenews = false
        viewModel.subscriptionSeats = nil

        Task {
            await subscriptionManager.clearSubscriptionState()
        }

        UserDefaults.standard.synchronize()

        // Clear repo caches tied to previous user
        Task { @MainActor in
            CombinedLogsRepository.shared.clear()
            FoodFeedRepository.shared.clear()
        }

        print("✅ User logged out successfully - all state cleared")
    }
    
    private func refreshSubscriptionState() {
        let savedEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        let email = viewModel.email.isEmpty ? savedEmail : viewModel.email

        guard !email.isEmpty else { return }

        viewModel.bindRepositories(for: email)

        Task {
            await subscriptionManager.fetchSubscriptionInfoIfNeeded(for: email, force: true)
        }
    }
}

struct AccountView: View {
    var body: some View {
        Text("Account Settings")
    }
}

struct PrivacyView: View {
    var body: some View {
        Text("Privacy Settings")
    }
}

struct SecurityPermissionsView: View {
    var body: some View {
        Text("Security & Permissions Settings")
    }
}

struct ShareProfileView: View {
    var body: some View {
        Text("Share Profile Settings")
    }
}

struct NotificationsView: View {
    var body: some View {
        Text("Notifications Settings")
    }
}

struct LiveView: View {
    var body: some View {
        Text("Live Settings")
    }
}

struct MusicView: View {
    var body: some View {
        Text("Music Settings")
    }
}

struct ActivityCenterView: View {
    var body: some View {
        Text("Activity Center Settings")
    }
}

struct ContentPreferencesView: View {
    var body: some View {
        Text("Content Preferences Settings")
    }
}

struct AdsView: View {
    var body: some View {
        Text("Ads Settings")
    }
}

struct PlaybackView: View {
    var body: some View {
        Text("Playback Settings")
    }
}

struct MailView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                print("Mail compose error: \(error.localizedDescription)")
            } else {
                switch result {
                case .cancelled:
                    print("Mail cancelled")
                case .saved:
                    print("Mail saved")
                case .sent:
                    print("Mail sent")
                case .failed:
                    print("Mail failed")
                @unknown default:
                    print("Unknown result")
                }
            }
            controller.dismiss(animated: true) {
                self.isPresented = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.setToRecipients(["support@humuli.com"])
        mail.setSubject("Metryc Feedback")
        mail.setMessageBody("", isHTML: true)
        mail.mailComposeDelegate = context.coordinator
        return mail
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: MFMailComposeViewController, coordinator: Coordinator) {
        uiViewController.dismiss(animated: true)
    }
}

struct AppleHealthSettingsView: View {
    @StateObject private var healthViewModel = HealthKitViewModel()
    @Environment(\.colorScheme) var colorScheme
    @State private var isHealthKitEnabled: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("Health Data Integration"), footer: Text("Sync your health data including steps, sleep, and workouts")) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connect to Health")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                    
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isHealthKitEnabled)
                        .labelsHidden()
                        .onChange(of: isHealthKitEnabled) { newValue in
                            if newValue {
                                // User wants to enable - request permissions
                                healthViewModel.enableHealthDataTracking()
                            } else {
                                // User wants to disable - update local preference only
                                // Note: Can't revoke HealthKit permissions programmatically
                                UserDefaults.standard.set(false, forKey: "healthKitEnabled")
                                healthViewModel.isAuthorized = false
                            }
                        }
                }
                .listRowBackground(colorScheme == .dark ? Color(rgb:44,44,44) : .white)
              
            }
            
               Section(footer: Text("To fully disable health data access, toggle off this setting and manage detailed permissions in iOS Settings > Privacy & Security > Health.")) {
                Button(action: {
                    openHealthApp()
                }) {
                    HStack {
                        Label("Open Health", systemImage: "heart.text.square.fill")
                            .foregroundColor(.pink)
                            .fontWeight(.semibold)
                        Spacer()
                       
                    }
                }
                .listRowBackground(colorScheme == .dark ? Color(rgb:44,44,44) : .white)
            }
            
           
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Check current authorization status
            isHealthKitEnabled = healthViewModel.isAuthorized
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSNotification.Name("HealthKitPermissionsChanged"))
                .receive(on: RunLoop.main)
        ) { _ in
            // Update toggle when permissions change
            isHealthKitEnabled = healthViewModel.isAuthorized
        }
    }
    
    private func openHealthApp() {
        if let healthURL = URL(string: "x-apple-health://") {
            UIApplication.shared.open(healthURL)
        }
    }
}

struct OuraSettingsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var status: NetworkManagerTwo.OuraStatusResponse?
    @State private var isFetchingStatus = false
    @State private var isSyncing = false
    @State private var alertMessage: String?

    private var isConnected: Bool {
        status?.connected == true
    }

    var body: some View {
        Form {
            Section(footer: footerText) {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(isConnected ? "Connected" : "Not Connected")
                        .foregroundColor(isConnected ? .green : .secondary)
                }

                if let last = formattedDate(from: status?.lastSyncedAt) {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(last)
                            .foregroundColor(.secondary)
                    }
                }

                if isConnected {
                    Button(role: .destructive, action: disconnect) {
                        Text("Disconnect Oura")
                    }
                } else {
                    Button(action: startConnection) {
                        Label("Connect Oura", systemImage: "link")
                    }
                }
            }

            Section {
                Button(action: { fetchStatus(triggerSync: true, reason: "refresh_button") }) {
                    HStack(spacing: 8) {
                        if isFetchingStatus {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isFetchingStatus ? "Refreshing..." : "Refresh Status & Sync")
                    }
                }
                .disabled(isFetchingStatus || isSyncing)

                if isSyncing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Syncing fresh Oura data...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let payload = statusPayloadText {
                Section(header: Text("Raw Payload")) {
                    Text(payload)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(nil)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Oura")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fetchStatus(reason: "view_appear") }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            fetchStatus(reason: "foreground")
        }
        .alert(isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Alert(title: Text("Oura"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    private var footerText: some View {
        Text("After approving access in your browser, return to Metryc. We'll automatically refresh when you come back.")
    }

    private var statusPayloadText: String? {
        guard let status else { return nil }
        return payloadString(from: status)
    }

    private func fetchStatus(triggerSync: Bool = false, reason: String = "") {
        guard !viewModel.email.isEmpty else { return }
        guard !isFetchingStatus else {
            print("ℹ️ OuraStatusView: Ignoring fetch because another request is running")
            return
        }

        let context = reason.isEmpty ? "general" : reason
        print("🔎 OuraStatusView: Fetching status [\(context)]")
        isFetchingStatus = true
        NetworkManagerTwo.shared.fetchOuraStatus(email: viewModel.email) { result in
            isFetchingStatus = false
            switch result {
            case .success(let response):
                status = response
                if let payload = payloadString(from: response) {
                    print("📦 OuraStatusView: Payload\n\(payload)")
                }
                if triggerSync {
                    guard response.connected else {
                        alertMessage = "Connect Oura before syncing data."
                        return
                    }
                    syncOura(reason: context)
                }
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }

    private func startConnection() {
        guard !viewModel.email.isEmpty else { return }
        NetworkManagerTwo.shared.startOuraAuthorization(email: viewModel.email) { result in
            switch result {
            case .success(let urlString):
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                } else {
                    alertMessage = "Unable to open authorization link."
                }
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }

    private func disconnect() {
        guard !viewModel.email.isEmpty else { return }
        NetworkManagerTwo.shared.disconnectOura(email: viewModel.email) { result in
            switch result {
            case .success:
                status = nil
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }

    private func syncOura(reason: String) {
        guard !viewModel.email.isEmpty else { return }
        guard !isSyncing else {
            print("ℹ️ OuraStatusView: Sync already in progress")
            return
        }

        isSyncing = true
        print("🔄 OuraStatusView: Sync requested [\(reason)]")
        NetworkManagerTwo.shared.syncOura(email: viewModel.email, days: 14) { result in
            isSyncing = false
            switch result {
            case .success:
                alertMessage = "Requested the latest data from Oura. We'll refresh shortly."
                NotificationCenter.default.post(name: .ouraSyncCompleted, object: nil)
                fetchStatus(triggerSync: false, reason: "post_sync")
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }

    private func formattedDate(from isoString: String?) -> String? {
        guard let isoString, let date = ISO8601DateFormatter().date(from: isoString) else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func payloadString(from response: NetworkManagerTwo.OuraStatusResponse) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(response) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Data Sources

struct DataSourcesView: View {
    private static let lastOuraStatusKey = "data_sources_last_oura_status"

    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var metricSelections: [MetricSelection] = MetricType.allCases.map { MetricSelection(metric: $0) }
    @State private var isOuraConnected = UserDefaults.standard.bool(forKey: DataSourcesView.lastOuraStatusKey)
    @State private var isLoading = false
    @State private var alertMessage: String?

    var body: some View {
        List {
            Text("Choose which device or service should be treated as the default source for each metric.")
                .font(.footnote)
                .foregroundColor(.secondary)

            ForEach(metricSelections) { selection in
                Section(header: MetricHeaderView(metric: selection.metric)) {
                    NavigationLink(destination: MetricSourcePickerView(
                        metric: selection.metric,
                        availableSources: availableSources(for: selection.metric),
                        selectedSourceID: selection.selectedSource?.id,
                        onSelect: { option in
                            setSelection(option, for: selection.metric)
                        }
                    )) {
                        MetricSourceSummaryView(selection: selection)
                    }
                }
            }
        }
        .navigationTitle("Data Sources")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadData)
        .alert(isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Alert(title: Text("Data Sources"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    private func loadData() {
        isOuraConnected = UserDefaults.standard.bool(forKey: Self.lastOuraStatusKey)
        loadSelections()
        fetchOuraStatus()
    }

    private func fetchOuraStatus() {
        guard !viewModel.email.isEmpty else { return }
        isLoading = true
        NetworkManagerTwo.shared.fetchOuraStatus(email: viewModel.email) { result in
            isLoading = false
            switch result {
            case .success(let response):
                isOuraConnected = response.connected
                UserDefaults.standard.set(response.connected, forKey: Self.lastOuraStatusKey)
                loadSelections()
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }

    private func loadSelections() {
        metricSelections = MetricType.allCases.map { metric in
            let savedID = UserDefaults.standard.string(forKey: metric.storageKey)
            let options = availableSources(for: metric)
            let option = options.first(where: { $0.id == savedID }) ?? options.first
            return MetricSelection(metric: metric, selectedSource: option)
        }
    }

    private func setSelection(_ option: DataSourceOption?, for metric: MetricType) {
        if let option {
            UserDefaults.standard.set(option.id, forKey: metric.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: metric.storageKey)
        }

        loadSelections()
    }

    private func availableSources(for metric: MetricType) -> [DataSourceOption] {
        var options: [DataSourceOption] = []

        if metric.supportsOura && isOuraConnected {
            options.append(.oura)
        }

        if metric.supportsAppleHealth {
            options.append(.appleHealth)
        }

        if metric.supportsManualEntry {
            options.append(.manual)
        }

        return options
    }
}

private struct MetricSelection: Identifiable {
    let metric: MetricType
    var selectedSource: DataSourceOption?

    var id: String { metric.rawValue }
}

private struct MetricSourceSummaryView: View {
    let selection: MetricSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selection.selectedSource?.title ?? "No source selected")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

private struct MetricSourcePickerView: View {
    let metric: MetricType
    let availableSources: [DataSourceOption]
    let selectedSourceID: String?
    let onSelect: (DataSourceOption?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if availableSources.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
            } else {
                ForEach(availableSources) { option in
                    Button(action: {
                        onSelect(option)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: option.icon)
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .foregroundColor(.primary)
                                if let subtitle = option.subtitle {
                                    Text(subtitle)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if option.id == selectedSourceID {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }

                Button("Clear Selection", role: .cancel) {
                    onSelect(nil)
                    dismiss()
                }
            }
        }
        .navigationTitle(metric.displayName)
    }
}

private enum MetricType: String, CaseIterable {
    case restingEnergy
    case activeEnergy
    case sleep
    case heartRate
    case hrv
    case bloodOxygen
    case respiratoryRate
    case vo2Max
    case wristTemperature
    case restingHeartRate
    case workouts
    case water
    case weight

    var displayName: String {
        switch self {
        case .restingEnergy: return "Resting Energy"
        case .activeEnergy: return "Active Energy"
        case .sleep: return "Sleep"
        case .heartRate: return "Heart Rate"
        case .hrv: return "Heart Rate Variability"
        case .bloodOxygen: return "Blood Oxygen"
        case .respiratoryRate: return "Respiratory Rate"
        case .vo2Max: return "VO₂ Max"
        case .wristTemperature: return "Wrist Temperature"
        case .restingHeartRate: return "Resting Heart Rate"
        case .workouts: return "Workouts"
        case .water: return "Water"
        case .weight: return "Weight"
        }
    }

    var storageKey: String { "metric_source_\(rawValue)" }

    var supportsManualEntry: Bool {
        switch self {
        case .water, .weight:
            return true
        default:
            return false
        }
    }

    var supportsOura: Bool {
        switch self {
        case .water, .weight:
            return false
        default:
            return true
        }
    }

    var supportsAppleHealth: Bool {
        switch self {
        case .water:
            return false
        default:
            return true
        }
    }

    var icon: String {
        switch self {
        case .restingEnergy, .activeEnergy:
            return "arrow.triangle.swap"
        case .sleep:
            return "moon.fill"
        case .heartRate:
            return "heart.fill"
        case .hrv:
            return "waveform.path.ecg"
        case .bloodOxygen:
            return "drop.degreesign"
        case .respiratoryRate, .vo2Max:
            return "lungs.fill"
        case .wristTemperature:
            return "thermometer.medium"
        case .restingHeartRate:
            return "heart"
        case .workouts:
            return "figure.run"
        case .water:
            return "drop.fill"
        case .weight:
            return "scalemass.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .restingEnergy:
            return .pink
        case .activeEnergy:
            return .orange
        case .sleep:
            return .indigo
        case .heartRate, .restingHeartRate:
            return .red
        case .hrv:
            return .red
        case .bloodOxygen, .respiratoryRate, .vo2Max:
            return .blue
        case .wristTemperature:
            return .orange
        case .workouts:
            return .green
        case .water:
            return .blue
        case .weight:
            return .indigo
        }
    }
}

private struct MetricHeaderView: View {
    let metric: MetricType

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: metric.icon)
                .foregroundColor(metric.iconColor)
            Text(metric.displayName.uppercased())
        }
        .font(.caption.weight(.semibold))
    }
}

private struct DataSourceOption: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String

    static let appleHealth = DataSourceOption(id: "apple_health", title: "Apple Health", subtitle: "Default device", icon: "heart.text.square")
    static let oura = DataSourceOption(id: "oura", title: "Oura Ring", subtitle: nil, icon: "circle")
    static let manual = DataSourceOption(id: "manual", title: "Manual", subtitle: "User-entered data", icon: "pencil")
}

struct MyTeamsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var isUpdating = false
    @State private var isLoading = true
    @State private var showCreateTeamView = false
    @State private var showSubscriptionView = false
    @State private var showTeamOptionsSheet = false
    @State private var selectedTeam: Team?
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @State private var teamForOptions: Team?  = nil
    
    

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(homeViewModel.teams) { team in
                            teamView(team: team)
                        }
                        addTeamButton
                    }
                    .padding()
                }
            }
        }
        .background(backgroundColorForTheme.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("My team", displayMode: .inline)
        .onAppear {
            isTabBarVisible.wrappedValue = false
            fetchTeams()
        }
        
        .overlay(Group {
            if isUpdating {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(width: 60, height: 60)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(10)
            }
        })
        .sheet(isPresented: $showCreateTeamView) {
            CreateTeamView(isPresented: $showCreateTeamView)
                .presentationDetents([.height(UIScreen.main.bounds.height / 4)])
        }

        .background(
            NavigationLink(destination: SubscriptionView(), isActive: $showSubscriptionView) {
                EmptyView()
            }
        )
        
    }
    
    private func deleteTeam(team: Team) {
        // Implement team deletion logic here
        print("Deleting team: \(team.name)")
    }
    
    
   
    
    private var addTeamButton: some View {
        Button(action: {
            handleAddTeamAction()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.accentColor)
                
                HStack {
                    Spacer()
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                    Text("Add team")
                        .fontWeight(.medium)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .padding(.vertical, 3)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleAddTeamAction() {
        if viewModel.hasActiveSubscription() {
            if viewModel.subscriptionPlan?.contains("Team") == true {
                if viewModel.canCreateNewTeam {
                        showCreateTeamView = true
                    } else {
                        showSubscriptionView = true
                    }
            } else {
                showSubscriptionView = true
            }
        } else {
            showSubscriptionView = true
        }
    }
    
    private func fetchTeams() {
        isLoading = true
        homeViewModel.fetchTeamsForUser(email: viewModel.email)

        isLoading = false

    }

    private var backgroundColorForTheme: Color {
        colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242)
    }

    private func teamView(team: Team) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color(rgb:44,44,44) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            HStack {
                DefaultProfilePicture(
                    initial: team.profileInitial ?? "",
                    color: team.profileColor ?? "",
                    size: 30
                )
                
                Text(team.name)
                    .fontWeight(.medium)
                    .font(.system(size: 14))
                Spacer()
                
                if team.id == viewModel.activeTeamId {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
                
//                Button(action: {
//           
//                    DispatchQueue.main.async {
//                        self.teamForOptions = team  // Set the correct team
//                    }
//                    
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                        print("Team selected for options: \(team.name), ID: \(team.id)")
//                        // Now show the sheet
//                        showTeamOptionsSheet = true
//        
//                        
//                    }
//                 
//                                     
//                    
//                            
//                           }) {
//                               Image(systemName: "info.circle")
//                                   .font(.system(size: 20))
//                                   .foregroundColor(.accentColor)
//                           }
                
                NavigationLink(destination: TeamOptionsView(
                             showTeamOptionsSheet: .constant(true),
                             onDeleteTeam: { deleteTeam(team: team) },
                             teamName: team.name,
                             teamId: team.id,
                             navigationAction: { destination in
                                 handleNavigation(destination: destination, for: team)
                             }
                         )) {
                             Image(systemName: "info.circle")
                                 .font(.system(size: 20))
                                 .foregroundColor(.accentColor)
                         }
                
            }
            .padding()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(team.id == viewModel.activeTeamId ? Color.accentColor : Color.clear, lineWidth: 3)
        )
        .onTapGesture {
            updateActiveTeam(teamId: team.id)
        }
    }
    
    private func handleNavigation(destination: TeamNavigationDestination, for team: Team) {
        switch destination {
        case .teamInfo:
            // Navigate to TeamInfoView
            // You might want to use a NavigationLink here or programmatic navigation
            print("Navigate to TeamInfoView for team: \(team.name)")
        case .teamMembers:
            // Navigate to TeamMembersView
            print("Navigate to TeamMembersView for team: \(team.name)")
        }
    }

    private func updateActiveTeam(teamId: Int) {
        isUpdating = true
        NetworkManager().updateActiveTeam(email: viewModel.email, teamId: teamId) { result in
            DispatchQueue.main.async {
                isUpdating = false
                switch result {
                case .success(let newActiveTeamId):
                    viewModel.activeTeamId = newActiveTeamId
                    UserDefaults.standard.set(newActiveTeamId, forKey: "activeTeamId")
                case .failure(let error):
                    print("Failed to update active team: \(error.localizedDescription)")
                }
            }
        }
    }
}



struct MyWorkspacesView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                ForEach(homeViewModel.workspaces) { workspace in
                    workspaceView(workspace: workspace)
                }
            }
            .padding()
        }
        .background( colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242))
        .navigationBarTitle("My workspace", displayMode: .inline)
        .onAppear {
            homeViewModel.fetchWorkspacesForUser(email: viewModel.email)
        }
    }

    private func workspaceView(workspace: Workspace) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color("container") : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            HStack {
                DefaultProfilePicture(
                    initial: workspace.profileInitial ?? "",
                    color: workspace.profileColor ?? "",
                    size: 30
                )
                
                Text(workspace.name)
                    .fontWeight(.medium)
                    .font(.system(size: 14))
                Spacer()
                
                if workspace.id == viewModel.activeWorkspaceId {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
        }
        .onTapGesture {
            viewModel.updateActiveWorkspace(workspaceId: workspace.id)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(workspace.id == viewModel.activeWorkspaceId ? Color.accentColor : Color.clear, lineWidth: 3)
        )
    }
}
