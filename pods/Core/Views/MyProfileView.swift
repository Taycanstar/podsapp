//
//  MyProfileView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/30/25.
//

import SwiftUI
import Charts
import Combine

private enum ProfileTab: Hashable, CaseIterable {
    case summary, logs, workouts, meals

    var title: String {
        switch self {
        case .summary: return "Summary"
        case .logs: return "Logs"
        case .workouts: return "Workouts"
        case .meals: return "Meals"
        }
    }
}

// MARK: - Macro Split Data Models
enum WeekOption: CaseIterable {
    case thisWeek, lastWeek, twoWeeksAgo, threeWeeksAgo
    
    var displayName: String {
        switch self {
        case .thisWeek: return "This week"
        case .lastWeek: return "Last week"
        case .twoWeeksAgo: return "2 wks. ago"
        case .threeWeeksAgo: return "3 wks. ago"
        }
    }
}

struct DailyMacroSplit: Identifiable {
    let id = UUID()
    let date: Date
    var calories: Double  // Raw calories from backend
    var proteinCals: Double
    var carbCals: Double
    var fatCals: Double
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double
    var totalCals: Double { calories }  // Use raw calories from backend
}

struct MyProfileView: View {
    @Binding var isAuthenticated: Bool
    @EnvironmentObject var onboarding: OnboardingViewModel
    @EnvironmentObject var vm: DayLogsViewModel  // Add this to access current weight
    @ObservedObject private var combinedLogsRepository = CombinedLogsRepository.shared
    @Namespace private var profileTabNamespace
    
    // Weight data state
    @State private var currentWeightKg: Double? = nil
    @State private var weightDate: String? = nil
    @State private var isLoadingWeight = false
    @State private var recentWeightLogs: [WeightLogResponse] = []
    
    // Sheet states
    @State private var showEditWeightSheet = false
    @State private var selectedWeek: WeekOption = .thisWeek
    @State private var showEditProfile = false
    
    // Macro split data
    @State private var macroSplitData: [WeekOption: [DailyMacroSplit]] = [:]
    @State private var isLoadingMacros = false
    @State private var selectedDay: DailyMacroSplit? = nil
    
    // Pull to refresh state
    @State private var isRefreshing = false
    @State private var hasInitiallyLoaded = false
    @State private var selectedProfileTab: ProfileTab = .summary
    @State private var hasConfiguredCombinedLogs = false
    
    // Streak state
    @ObservedObject private var streakManager = StreakManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("primarybg")
                    .ignoresSafeArea()
                
                if onboarding.isLoadingProfile && !hasInitiallyLoaded {
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = onboarding.profileError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("Error Loading Profile")
                            .font(.headline)
                        
                        Text(error)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                       Button("Try Again") {
                           Task {
                                await onboarding.fetchProfileData(force: true)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    tabbedProfileContent
                        .padding(.horizontal, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView(isAuthenticated: $isAuthenticated)) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                    }
                }
            }
            .toolbarBackground(Color("primarybg"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force stack style for older iOS versions
        .sheet(isPresented: $showEditWeightSheet) {
            EditWeightView(onWeightSaved: {
                // Refresh weight data after saving with a small delay
                print("🏋️ Weight saved callback received")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    fetchWeightData()
                }
            })
        }
        // Removed the sheet for profile settings since we're now using navigation
        .onAppear {
            // Debug: Check what we have
            print("🔍 MyProfileView onAppear - Debug info:")
            print("  - onboarding.email: '\(onboarding.email)'")
            let userDefaultsEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
            print("  - UserDefaults userEmail: '\(userDefaultsEmail)'")
            if let profileData = onboarding.profileData {
                print("  - onboarding.profileData exists for: '\(profileData.email)'")
                print("  - Email match (onboarding): \(profileData.email == onboarding.email)")
                print("  - Email match (UserDefaults): \(profileData.email == userDefaultsEmail)")
            } else {
                print("  - onboarding.profileData is nil")
            }
            
            // Check if we have fresh preloaded profile data from DashboardView
            // Use the same email source as DashboardView (UserDefaults)
            if let profileData = onboarding.profileData, profileData.email == userDefaultsEmail {
                print("✅ Using fresh preloaded profile data for \(profileData.email) - instant loading!")
                // Process the existing profile data
                processProfileData()
                hasInitiallyLoaded = true
            } else {
                // More detailed debugging for the failure case
                if let profileData = onboarding.profileData {
                    print("⚠️ Preloaded profile data is for wrong user:")
                    print("  - profileData.email: '\(profileData.email)'")
                    print("  - userDefaultsEmail: '\(userDefaultsEmail)'")
                    print("  - Are they equal? \(profileData.email == userDefaultsEmail)")
                    print("  - profileData.email.count: \(profileData.email.count)")
                    print("  - userDefaultsEmail.count: \(userDefaultsEmail.count)")
                    print("  - profileData.email bytes: \(Array(profileData.email.utf8))")
                    print("  - userDefaultsEmail bytes: \(Array(userDefaultsEmail.utf8))")
                } else {
                    print("⏳ No preloaded data - fetching fresh profile data")
                }
                // Fetch fresh profile data if not preloaded or wrong user
               Task {
                    await onboarding.fetchProfileData(force: true)
                    hasInitiallyLoaded = true
                }
            }
            
            // Always fetch weight data and process macro split data
            fetchWeightData()
            fetchMacroSplitData()
            ensureCombinedLogsReady()
            let email = resolvedUserEmail()
            if !email.isEmpty {
                vm.preloadForStartup(email: email)
            }
            vm.setHealthViewModel(HealthKitViewModel.shared)
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: Notification.Name("WeightLoggedNotification"))
                .receive(on: RunLoop.main)
        ) { _ in
            // Refresh weight data when a new weight is logged
            print("🏋️ Received WeightLoggedNotification - refreshing weight data")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Small delay to allow server to update
                fetchWeightData()
            }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: Notification.Name("LogsChangedNotification"))
                .receive(on: RunLoop.main)
        ) { notification in
            let isLocal = (notification.userInfo?["localOnly"] as? Bool) ?? false
            print("🔄 MyProfileView received LogsChangedNotification - localOnly=\(isLocal)")
            guard !isLocal else { return }
            Task {
                await onboarding.fetchProfileData(force: false)
                await combinedLogsRepository.refresh(force: true)
            }
        }
        .onChange(of: onboarding.profileData?.email) { _ in
            ensureCombinedLogsReady(force: true)
        }
    }
    
    private func basicProfileHeaderView() -> some View {
        VStack(spacing: 16) {
            // Profile Picture Circle
            ZStack {
                Circle()
                    .fill(Color(onboarding.profileColor.isEmpty ? "purple" : onboarding.profileColor))
                    .frame(width: 100, height: 100)
                
                // Show initials as fallback for basic view
                Text(onboarding.profileInitial.isEmpty ? "U" : onboarding.profileInitial)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Basic User Info
            VStack(spacing: 8) {
                Text(onboarding.username.isEmpty ? "User" : onboarding.username)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("@\(onboarding.username.isEmpty ? "username" : onboarding.username)")
                    .font(.body)
                    .foregroundColor(.secondary)
                

            }
        }
        .padding()
        .background(Color("containerbg"))
        .cornerRadius(16)
    }
    
    private func profileHeaderView() -> some View {
        VStack(spacing: 16) {
            // Profile Picture with photo support
            ZStack {
                Circle()
                    .fill(Color(onboarding.profileData?.profileColor ?? onboarding.profileColor))
                    .frame(width: 80, height: 80)
                
                if let profileData = onboarding.profileData {
                    if profileData.profilePhoto == "pfp" {
                        // Use asset image
                        Image("pfp")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else if !profileData.profilePhoto.isEmpty {
                        // Use URL image
                        AsyncImage(url: URL(string: profileData.profilePhoto)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            // Show initials while loading
                            Text(profileData.profileInitial)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        // Fallback to initials
                        Text(profileData.profileInitial)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    }
                } else {
                    // Show basic initials while profile data loads
                    Text(onboarding.profileInitial.isEmpty ? "U" : onboarding.profileInitial)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 8) {
                // Name (larger, bold) - show name if available, fallback to username
                Text(onboarding.profileData?.name.isEmpty == false ? onboarding.profileData!.name : (onboarding.profileData?.username ?? onboarding.username))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Username below name (smaller, secondary)
                Text("@\(onboarding.profileData?.username ?? onboarding.username)")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // Edit button - fully rounded
                NavigationLink(destination: EditMyProfileView(isAuthenticated: $isAuthenticated)) {
                    Text("Edit")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color("containerbg"))
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
            }
        }
        .padding(.vertical)
    }
    

    

    
    private func bmiGaugeView(profileData: ProfileDataResponse) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text("Body Mass Index")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)

            if let bmi = calculateBMI(weightKg: vm.weight > 0 ? vm.weight : nil, heightCm: vm.height > 0 ? vm.height : nil) {
                ArcOne(bmiValue: bmi)
            } else {
                Text("BMI calculation requires both height and weight data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .padding(.vertical, 16)
        .background(Color("containerbg"))
        .cornerRadius(12)
    }
    
    private func calculateBMI(weightKg: Double?, heightCm: Double?) -> Double? {
        print("🏥 calculateBMI called with weightKg: \(weightKg?.description ?? "nil"), heightCm: \(heightCm?.description ?? "nil")")
        
        // Debug: Check what we have
        if weightKg == nil && heightCm == nil {
            print("🏥 Both weight and height are missing from profile data")
        } else if weightKg == nil {
            print("🏥 Weight is missing from profile data (but height exists: \(heightCm!)cm)")
        } else if heightCm == nil {
            print("🏥 Height is missing from profile data (but weight exists: \(weightKg!)kg)")
        }
        
        guard let weight = weightKg, let height = heightCm, weight > 0, height > 0 else {
            print("🏥 calculateBMI returning nil - missing or invalid data")
            return nil
        }
        
        let heightInMeters = height / 100.0
        let bmi = weight / (heightInMeters * heightInMeters)
        print("🏥 calculateBMI returning BMI: \(bmi)")
        return bmi
    }
    
    private func nutritionGoalsView(profileData: ProfileDataResponse) -> some View {
        NavigationLink(destination: GoalProgress()) {
            VStack(spacing: 16) {
                HStack {
                    Text("Daily Nutrition Goal")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // Use the same layout as dashboard macros card
                VStack(spacing: 16) {
                    macroRow(left:  ("Calories", profileData.calorieGoal,  "flame.fill",    Color("brightOrange")),
                            right: ("Protein",  profileData.proteinGoal,   "fish",        .blue))
                    macroRow(left:  ("Carbs",     profileData.carbsGoal,   "laurel.leading", Color("darkYellow")),
                            right: ("Fat",       profileData.fatGoal,      "drop.fill",     .pink))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color("containerbg"))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func macroRow(left: (String, Double, String, Color),
                          right: (String, Double, String, Color)) -> some View {
        HStack(spacing: 0) {
            macroCell(title: left.0, value: left.1,
                      sf: left.2, colour: left.3)
            macroCell(title: right.0, value: right.1,
                      sf: right.2, colour: right.3)
        }
    }
    
    @ViewBuilder
    private func macroCell(title: String, value: Double,
                           sf: String, colour: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(colour.opacity(0.2))
                        .frame(width: 40, height: 40)
                Image(systemName: sf).foregroundColor(colour)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 16))
                Text("\(Int(value))\(title == "Calories" ? "" : "g")")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(colour)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var summaryTabContent: some View {
        VStack(spacing: 24) {
            weightCardView

            runStreakCardView

            if let profileData = onboarding.profileData {
                bmiGaugeView(profileData: profileData)
            }

            MacroSplitCardView(
                selectedWeek: $selectedWeek,
                data: macroSplitData[selectedWeek] ?? [],
                weeklyTotal: calculateWeeklyTotal(for: selectedWeek)
            )

            if let profileData = onboarding.profileData {
                nutritionGoalsView(profileData: profileData)
            }

            #if DEBUG
            debugSectionView
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tabbedProfileContent: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    profileHeaderView()
                    profileTabSwitcher
                    selectedTabContent
                    Spacer(minLength: 80)
                }
                .frame(width: geometry.size.width)
                .padding(.top, 8)
            }
            .refreshable {
                await refreshForCurrentTab()
            }
        }
    }

    private var profileTabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedProfileTab = tab
                    }
                    if tab != .summary {
                        ensureCombinedLogsReady()
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(selectedProfileTab == tab ? .primary : .secondary)

                        Group {
                            if selectedProfileTab == tab {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(id: "profileTabUnderline", in: profileTabNamespace)
                            } else {
                                Capsule()
                                    .fill(Color.clear)
                                    .frame(height: 3)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedProfileTab {
        case .summary:
            summaryTabContent
        case .logs:
            logsTabContent
        case .workouts:
            workoutsTabContent
        case .meals:
            mealsTabContent
        }
    }

    private var logsTabContent: some View {
        let logs = allCombinedLogs

        return Group {
            if combinedLogsRepository.isRefreshing && logs.isEmpty {
                loadingStateView(title: "Loading logs…")
            } else if logs.isEmpty {
                emptyStateView(
                    title: "No logs yet",
                    message: "Record meals or workouts to see them here."
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(logs) { log in
                        logCardView(for: log)
                            .onAppear {
                                maybeLoadMoreLogs(currentLog: log, within: logs)
                            }
                    }

                    if combinedLogsRepository.isLoadingNextPage {
                        ProgressView()
                            .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var workoutsTabContent: some View {
        let logs = workoutLogs

        return Group {
            if combinedLogsRepository.isRefreshing && allCombinedLogs.isEmpty {
                loadingStateView(title: "Loading workouts…")
            } else if logs.isEmpty {
                emptyStateView(
                    title: "No workouts logged",
                    message: "Log a workout to track your training history."
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(logs) { log in
                        workoutCardView(for: log)
                            .onAppear {
                                maybeLoadMoreLogs(currentLog: log, within: logs)
                            }
                    }

                    if combinedLogsRepository.isLoadingNextPage {
                        ProgressView()
                            .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var mealsTabContent: some View {
        let logs = mealLogs

        return Group {
            if combinedLogsRepository.isRefreshing && allCombinedLogs.isEmpty {
                loadingStateView(title: "Loading meals…")
            } else if logs.isEmpty {
                emptyStateView(
                    title: "No meals logged",
                    message: "Track what you eat to populate this tab."
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(logs) { log in
                        logCardView(for: log)
                            .onAppear {
                                maybeLoadMoreLogs(currentLog: log, within: logs)
                            }
                    }

                    if combinedLogsRepository.isLoadingNextPage {
                        ProgressView()
                            .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var allCombinedLogs: [CombinedLog] {
        var logsById: [String: CombinedLog] = [:]

        for log in combinedLogsRepository.snapshot.logs {
            logsById[log.id] = log
        }

        for log in vm.logs {
            if let existing = logsById[log.id] {
                logsById[log.id] = preferredLog(existing: existing, candidate: log)
            } else {
                logsById[log.id] = log
            }
        }

        return logsById.values.sorted { lhs, rhs in
            let lhsDate = canonicalDate(for: lhs) ?? Date.distantPast
            let rhsDate = canonicalDate(for: rhs) ?? Date.distantPast

            if lhsDate == rhsDate {
                return lhs.id > rhs.id
            }
            return lhsDate > rhsDate
        }
    }

    private var workoutLogs: [CombinedLog] {
        allCombinedLogs.filter { $0.type == .activity || $0.type == .workout }
    }

    private var mealLogs: [CombinedLog] {
        allCombinedLogs.filter { $0.type == .food || $0.type == .meal }
    }

    private func logCardView(for log: CombinedLog) -> some View {
        // Use workout card styling for activities
        if log.type == .activity || log.type == .workout {
            return AnyView(workoutCardView(for: log))
        } else {
            return AnyView(ProfileLogRow(log: log))
        }
    }

    @ViewBuilder
    private func workoutCardView(for log: CombinedLog) -> some View {
        NavigationLink {
            WorkoutLogDetailView(log: log)
        } label: {
            workoutCardLabel(for: log)
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func workoutCardLabel(for log: CombinedLog) -> some View {
        let directCount = log.workout?.exercisesCount
        let fallbackCount = exerciseCount(from: log)
        let resolvedCountForPrint: Int? = {
            if let direct = directCount, direct > 0 {
                return direct
            }
            return fallbackCount
        }()
#if DEBUG
        print(
            "📦 log",
            log.id,
            "type:",
            String(describing: log.type),
            "optimistic:",
            log.isOptimistic,
            "workoutCount:",
            directCount as Any,
            "fallbackCount:",
            fallbackCount as Any,
            "resolvedCount:",
            resolvedCountForPrint as Any,
            "message:",
            log.message
        )
#endif

        if let activity = log.activity {
            workoutCardContent(
                icon: activity.activityIcon,
                title: activity.displayName,
                subtitle: activity.workoutActivityType.replacingOccurrences(of: "_", with: " "),
                duration: resolvedWorkoutDuration(for: log),
                distance: activity.formattedDistance,
                exercisesCount: fallbackCount,
                calories: Int(log.displayCalories),
                timeLabel: getWorkoutTimeLabel(for: log)
            )
        } else if let workout = log.workout {
            let resolvedCount: Int? = {
                if let direct = directCount, direct > 0 {
                    return direct
                }
                return fallbackCount
            }()
            workoutCardContent(
                icon: "figure.strengthtraining.traditional",
                title: workout.title,
                subtitle: nil,
                duration: resolvedWorkoutDuration(for: log),
                distance: nil,
                exercisesCount: resolvedCount,
                calories: Int(log.displayCalories),
                timeLabel: getWorkoutTimeLabel(for: log)
            )
        } else {
            ProfileLogRow(log: log)
        }
    }

    private func resolvedWorkoutDuration(for log: CombinedLog) -> String? {
        if let activity = log.activity {
            return activity.formattedDuration
        }

        if let workout = log.workout {
            let formatted = workout.formattedDuration
            if formatted != "< 1 min" {
                return formatted
            }

            if let seconds = workout.durationSeconds, seconds > 0 {
                return "\(seconds)s"
            }

            if let minutes = workout.durationMinutes, minutes > 0 {
                return "\(minutes) min"
            }
        }

        // Fallback: try to extract a duration from the message string (e.g. "Workout - 37s")
        let components = log.message.components(separatedBy: "-")
        if let last = components.last {
            let trimmed = last.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private func workoutCardContent(
        icon: String,
        title: String,
        subtitle: String?,
        duration: String?,
        distance: String?,
        exercisesCount: Int?,
        calories: Int,
        timeLabel: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                    }

                    let exercisesLabel = exercisesCount.map { "\($0) exercise\($0 == 1 ? "" : "s")" } ?? " "
                    Text(exercisesLabel)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                        .opacity(exercisesCount == nil ? 0 : 1)
                }

                Spacer()

                if let timeLabel {
                    Text(timeLabel)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(.systemGray2))
                }
            }

            HStack(spacing: 24) {
                workoutCaloriesView(calories)

                Spacer(minLength: 16)

                if let duration {
                    workoutMetricInline(icon: "clock", text: duration, color: .blue)
                }

                if let distance {
                    workoutMetricInline(icon: "location", text: distance, color: .green)
                }

                let exercisesMetricLabel = exercisesCount.map { "\($0) exercise\($0 == 1 ? "" : "s")" } ?? " "
                workoutMetricInline(
                    icon: "list.bullet",
                    text: exercisesMetricLabel,
                    color: .green
                )
                .opacity(exercisesCount == nil ? 0 : 1)
                .accessibilityHidden(exercisesCount == nil)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("containerbg"))
        )
    }

    private func workoutCaloriesView(_ calories: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20))
                .foregroundColor(Color("brightOrange"))

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(calories)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text("cal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func workoutMetricInline(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.primary)
        }
    }

    private func getWorkoutTimeLabel(for log: CombinedLog) -> String? {
        // Same logic as ProfileLogRow - show date/time based on log date
        guard let logDateString = log.logDate,
              let logDate = dateFromString(logDateString) else {
            return nil
        }

        let calendar = Calendar.current

        // TODAY: Show time
        if calendar.isDateInToday(logDate) {
            guard let scheduledAt = log.scheduledAt else { return nil }
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: scheduledAt)
        }

        // YESTERDAY: Show "Yesterday"
        if calendar.isDateInYesterday(logDate) {
            return "Yesterday"
        }

        // LAST 7 DAYS: Show weekday
        let startOfNow = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: logDate)
        if let days = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day,
           days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: logDate)
        }

        // OLDER: Show short date
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: logDate)
    }

    private func dateFromString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

    private func loadingStateView(title: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func emptyStateView(title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func maybeLoadMoreLogs(currentLog: CombinedLog, within logs: [CombinedLog]) {
        guard let index = logs.firstIndex(where: { $0.id == currentLog.id }) else { return }
        if index == logs.count - 1 {
            Task {
                await combinedLogsRepository.loadNextPage()
            }
        }
    }

    private func canonicalDate(for log: CombinedLog) -> Date? {
        if let raw = rawLogDate(for: log) {
            return raw
        }

        if log.isOptimistic {
            return Date()
        }

        return nil
    }

    private func shouldShowDateBadge(for log: CombinedLog) -> Bool {
        guard let date = canonicalDate(for: log) else {
            print("⏰ shouldShowDateBadge - No canonical date for log \(log.id)")
            return false
        }
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        print("⏰ shouldShowDateBadge - Log \(log.id): date=\(date), isToday=\(isToday), shouldShow=\(!isToday)")
        // Only show badge for non-today logs (Yesterday, weekday, or date)
        return !isToday
    }

    private func logLabel(for log: CombinedLog) -> String? {
        guard let date = canonicalDate(for: log) else {
            print("📅 logLabel - Log \(log.id): No canonical date")
            return nil
        }

        print("📅 logLabel - Log \(log.id): canonical date = \(date)")

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let time = Self.timeFormatter.string(from: date)
            print("📅 logLabel - Returning TODAY time: \(time)")
            return time
        }
        if calendar.isDateInYesterday(date) {
            print("📅 logLabel - Returning YESTERDAY")
            return "Yesterday"
        }

        let startOfNow = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: date)
        if let days = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day,
           days < 7 {
            let weekday = Self.weekdayFormatter.string(from: date)
            print("📅 logLabel - Returning WEEKDAY: \(weekday)")
            return weekday
        }

        let shortDate = Self.shortDateFormatter.string(from: date)
        print("📅 logLabel - Returning SHORT DATE: \(shortDate)")
        return shortDate
    }

    private func exerciseCount(from log: CombinedLog) -> Int? {
        if let workoutCount = log.workout?.exercisesCount, workoutCount > 0 {
            return workoutCount
        }

        let words = log.message.replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")

        for (index, word) in words.enumerated() where index + 1 < words.count {
            let next = words[index + 1].lowercased()
            if next.contains("exercise") {
                let digits = word.filter { $0.isNumber }
                if let count = Int(digits) {
                    return count
                }
            }
        }

        return nil
    }

    private func ensureCombinedLogsReady(force: Bool = false) {
        let email = resolvedUserEmail()
        guard !email.isEmpty else { return }

        if force || !hasConfiguredCombinedLogs {
            combinedLogsRepository.configure(email: email)
            hasConfiguredCombinedLogs = true
        }

        Task {
            await combinedLogsRepository.refresh(force: true)
        }
    }

    private func resolvedUserEmail() -> String {
        if let email = onboarding.profileData?.email, !email.isEmpty {
            return email
        }
        if let defaultsEmail = UserDefaults.standard.string(forKey: "userEmail"), !defaultsEmail.isEmpty {
            return defaultsEmail
        }
        return onboarding.email
    }

    private func refreshForCurrentTab() async {
        switch selectedProfileTab {
        case .summary:
            await refreshProfileData()
        default:
            let email = resolvedUserEmail()
            if !email.isEmpty {
                if !hasConfiguredCombinedLogs {
                    combinedLogsRepository.configure(email: email)
                    hasConfiguredCombinedLogs = true
                }
                await combinedLogsRepository.refresh(force: true)
            }
        }
    }

    private static let backendDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter
    }()

    private static let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private func rawLogDate(for log: CombinedLog) -> Date? {
        print("🔍 rawLogDate for log \(log.id):")
        print("   log.logDate = \(log.logDate ?? "nil")")
        print("   log.scheduledAt = \(log.scheduledAt?.description ?? "nil")")
        print("   log.activity?.startDate = \(log.activity?.startDate.description ?? "nil")")
        print("   log.meal?.scheduledAt = \(log.meal?.scheduledAt?.description ?? "nil")")

        // PRIORITY 1: Use scheduledAt when available (includes exact time)
        if let scheduled = log.scheduledAt {
            print("   ✅ Using scheduledAt: \(scheduled)")
            return scheduled
        }
        if let activityDate = log.activity?.startDate {
            print("   ✅ Using activity.startDate: \(activityDate)")
            return activityDate
        }
        if let mealDate = log.meal?.scheduledAt {
            print("   ✅ Using meal.scheduledAt: \(mealDate)")
            return mealDate
        }
        if let recipeDate = log.recipe?.scheduledAt {
            print("   ✅ Using recipe.scheduledAt: \(recipeDate)")
            return recipeDate
        }

        // PRIORITY 2: Fallback to logDate (date only)
        if let logDate = log.logDate {
            if let parsed = Self.backendDateFormatter.date(from: logDate) {
                print("   ✅ Using logDate (backend format): \(parsed)")
                return parsed
            }
            if let isoParsed = Self.iso8601DateFormatter.date(from: logDate) {
                print("   ✅ Using logDate (ISO format): \(isoParsed)")
                return isoParsed
            }
        }

        print("   ❌ No date found")
        return nil
    }

    private func preferredLog(existing: CombinedLog, candidate: CombinedLog) -> CombinedLog {
        let existingDate = rawLogDate(for: existing)
        let candidateDate = rawLogDate(for: candidate)

        if existing.type == .workout || candidate.type == .workout {
            let existingWorkout = existing.workout
            let candidateWorkout = candidate.workout
            let existingCount = existingWorkout?.exercisesCount ?? 0
            let candidateCount = candidateWorkout?.exercisesCount ?? 0

            if existingWorkout == nil, candidateWorkout != nil {
                print("⚖️ preferredLog choosing candidate \(candidate.id) because it has workout details and existing does not")
                return candidate
            }

            if candidateWorkout == nil, existingWorkout != nil {
                return existing
            }

            if candidateCount > existingCount {
                print(
                    "⚖️ preferredLog choosing candidate",
                    candidate.id,
                    "because exercisesCount improved",
                    existingCount,
                    "→",
                    candidateCount
                )
                return candidate
            }

            print(
                "⚖️ preferredLog comparing",
                existing.id,
                "existingCount:",
                existing.workout?.exercisesCount as Any,
                "candidateCount:",
                candidate.workout?.exercisesCount as Any,
                "existingOptimistic:",
                existing.isOptimistic,
                "candidateOptimistic:",
                candidate.isOptimistic,
                "existingDate:",
                existingDate as Any,
                "candidateDate:",
                candidateDate as Any
            )
        }

        // Prefer whichever carries a usable date value
        if existingDate == nil, let candidateDate {
            return candidate
        }
        if candidateDate == nil, existingDate != nil {
            return existing
        }

        // Prefer optimistic entry to keep animation when server copy exists
        if candidate.isOptimistic && !existing.isOptimistic {
            return candidate
        }

        if let candidateDate, let existingDate, candidateDate > existingDate {
            return candidate
        }

        return existing
    }
    
    private var weightCardView: some View {
        NavigationLink(destination: WeightDataView()) {
            weightCardContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var weightCardContent: some View {
        VStack(spacing: 12) {
            // Top row: Weight label on left, date + chevron on right
            HStack {
                // Weight label with icon and plus button
                HStack(spacing: 6) {
                    Image(systemName: "scalemass")
                        .foregroundColor(.purple)
                        .font(.system(size: 16))
                    Text("Weight")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                    
                    // Add weight button
                    Button(action: {
                        showEditWeightSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 18))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // Date with chevron pushed to the right
                if let weightDate = weightDate {
                    HStack(spacing: 4) {
                        Text(formatWeightLogDate(weightDate))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Bottom row: Weight value on left, chart on right
            HStack {
                // Left side - Weight value
                VStack(alignment: .leading, spacing: 4) {
                    if isLoadingWeight {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let weightKg = currentWeightKg {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(formatWeight(weightKg))
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(" \(weightUnit)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No data")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    
                    // Prompt for no data case
                    if currentWeightKg == nil && !isLoadingWeight {
                        Text("Add your first weight entry")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Right side - Chart below the date
                if recentWeightLogs.count >= 2 {
                    weightTrendChart
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color("containerbg"))
        .cornerRadius(12)
        .onAppear {
            // Debug: Print weight data
            print("🏋️ Weight Debug (Local State):")
            print("  - currentWeightKg: \(currentWeightKg?.description ?? "nil")")
            print("  - weightDate: \(weightDate ?? "nil")")
            print("  - vm.weight: \(vm.weight)")
            print("  - recentWeightLogs count: \(recentWeightLogs.count)")
        }
    }
    
    private var runStreakCardView: some View {
        VStack(spacing: 12) {
            // Title
            HStack {
                Text("Run Streak")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            // Content - either streak info or motivational message
            HStack {
                if !onboarding.isStreakVisible {
                    // Hidden state - show motivational message
                    Text("Consistency is key. Come back to tracking your health at times that feel good for you.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    // Visible state - show streak
                    HStack(spacing: 8) {
                        // Fire icon from StreakManager
                        Image(streakManager.streakAsset)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 45, height: 45)
                        
                        // Streak count with days
                        Text("\(streakManager.currentStreak) days")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                // Eye toggle button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onboarding.isStreakVisible.toggle()
                    }
                }) {
                    Image(systemName: onboarding.isStreakVisible ? "eye" : "eye.slash")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color("containerbg"))
        .cornerRadius(12)
    }
    
    private var weightTrendChart: some View {
        // Sort logs chronologically (oldest to newest) for proper chart display
        let sortedLogs = recentWeightLogs.sorted { log1, log2 in
            guard let date1 = parseDate(log1.dateLogged),
                  let date2 = parseDate(log2.dateLogged) else { return false }
            return date1 < date2 // oldest first
        }
        let chartData = Array(sortedLogs.enumerated())
        let weights = chartData.map { getDisplayWeight($0.1.weightKg) }
        
        // Calculate a better Y-axis range to show variation
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? 0
        let range = maxWeight - minWeight
        let defaultPadding = onboarding.unitsSystem == .imperial ? 2.0 : 1.0
        let padding = max(range * 0.3, defaultPadding) // Different padding for different units
        let yAxisMin = minWeight - padding
        let yAxisMax = maxWeight + padding
        
        // Calculate X-axis domain dynamically based on actual data points
        let spacing: Double = 0.8  // Good balance - visible lines but compact chart
        let maxXValue = Double(chartData.count - 1) * spacing
        let xAxisMin: Double = -0.5  // Small negative padding on left
        let xAxisMax: Double = maxXValue + 0.5  // Small padding on right
        
        return Chart {
            ForEach(chartData, id: \.offset) { index, log in
                let xValue = Double(index) * spacing  // Use consistent spacing
                
                LineMark(
                    x: .value("Day", xValue),
                    y: .value("Weight", getDisplayWeight(log.weightKg))
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Color.purple)
                
                // Mask the line so it doesn't show through the hollow point
                PointMark(
                    x: .value("Day", xValue),
                    y: .value("Weight", getDisplayWeight(log.weightKg))
                )
                .symbol(.circle)
                .symbolSize(CGSize(width: 10, height: 10))        // larger background
                .foregroundStyle(Color("containerbg"))  // same as card background

                // Outlined hollow point
                PointMark(
                    x: .value("Day", xValue),
                    y: .value("Weight", getDisplayWeight(log.weightKg))
                )
                .symbol(.circle.strokeBorder(lineWidth: 2))
                .symbolSize(CGSize(width: 8, height: 8))
                .foregroundStyle(Color.purple)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: xAxisMin...xAxisMax) // Dynamic domain that fits all points perfectly
        .chartYScale(domain: yAxisMin...yAxisMax) // Custom scale to show variation
        .chartLegend(.hidden)
        .frame(width: 100, height: 40) // Proper size for good line visibility
        .background(Color.clear)
        .onAppear {
            print("🏋️ Chart Data Debug:")
            print("  - Chart data count: \(chartData.count)")
            print("  - Weight range: \(minWeight) to \(maxWeight) \(onboarding.unitsSystem == .imperial ? "lbs" : "kg")")
            print("  - Y-axis scale: \(yAxisMin) to \(yAxisMax)")
            print("  - X-axis scale: \(xAxisMin) to \(xAxisMax)")
            for (index, log) in chartData {
                let displayWeight = getDisplayWeight(log.weightKg)
                let unit = onboarding.unitsSystem == .imperial ? "lbs" : "kg"
                print("  - Chart point \(index): \(displayWeight)\(unit) from \(log.dateLogged)")
            }
            print("  - Chart trend: \(chartData.first?.1.weightKg ?? 0)kg → \(chartData.last?.1.weightKg ?? 0)kg")
        }
    }
    
    // MARK: - Debug Section (Debug builds only)
    
    #if DEBUG
    private var debugSectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ladybug")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                Text("Debug Tools")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Review status info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review Status (3-Milestone System)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Foods logged:")
                        Spacer()
                        Text("\(ReviewManager.shared.totalFoodsLogged)")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("First food date:")
                        Spacer()
                        Text(ReviewManager.shared.debugFirstFoodDate?.formatted(date: .abbreviated, time: .omitted) ?? "None")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("Current streak:")
                        Spacer()
                        Text("\(streakManager.currentStreak) days")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    // Milestone status
                    Divider()
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Milestone #1 (Any food):")
                            Spacer()
                            Text(ReviewManager.shared.hasShownFirstFoodReview() ? "✅ Shown" : "⭕ Pending")
                                .fontWeight(.medium)
                                .foregroundColor(ReviewManager.shared.hasShownFirstFoodReview() ? .green : .orange)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Milestone #2 (Engaged):")
                            Spacer()
                            Text(ReviewManager.shared.hasShownEngagedReview() ? "✅ Shown" : "⭕ Pending")
                                .fontWeight(.medium)
                                .foregroundColor(ReviewManager.shared.hasShownEngagedReview() ? .green : .orange)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Milestone #3 (Retention):")
                            Spacer()
                            Text(ReviewManager.shared.hasShownRetentionReview() ? "✅ Shown" : "⭕ Pending")
                                .fontWeight(.medium)
                                .foregroundColor(ReviewManager.shared.hasShownRetentionReview() ? .green : .orange)
                        }
                        .font(.caption)
                    }
                }
                
                Divider()
                
                // Debug actions
                VStack(spacing: 8) {
                    Button("Force Show Review Prompt") {
                        ReviewManager.shared.forceShowReview()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                    
                    Button("Reset Review Tracking") {
                        ReviewManager.shared.resetAllTracking()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(8)
                    
                    Button("Check Review Milestones") {
                        ReviewManager.shared.checkAndRequestReviewIfNeeded()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color("containerbg"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
    }
    #endif
    
    // MARK: - Macro Split Data Methods
    
    private func fetchMacroSplitData() {
        // First check if we have preloaded profile data with macro info
        if let profileData = onboarding.profileData, profileData.macroData3Weeks != nil {
            print("📊 Using preloaded macro data from profile - no API call needed!")
            processProfileMacroData(profileData)
            return
        }
        
        // Fallback: fetch fresh data if no preloaded macro data available
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("❌ No user email found for macro data fetch")
            return
        }
        
        print("📊 No preloaded macro data - refreshing profile repository for email: \(email)")
        isLoadingMacros = true

        Task {
            await onboarding.fetchProfileData(force: true)

            await MainActor.run {
                isLoadingMacros = false
                if let profileData = onboarding.profileData {
                    print("✅ Successfully refreshed profile data with macro info")
                    processProfileMacroData(profileData)
                } else {
                    print("❌ Macro data still unavailable after refresh")
                    macroSplitData = [:]
                }
            }
        }
    }
    
    private func processProfileMacroData(_ profileData: ProfileDataResponse) {
        guard let macroData = profileData.macroData3Weeks else {
            print("❌ No macro data in profile response")
            macroSplitData = [:]
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Convert API response to our local data structure
        var processedData: [WeekOption: [DailyMacroSplit]] = [:]
        
        // Parse the macro data and group by weeks
        let dailyMacros = macroData.compactMap { dayData -> DailyMacroSplit? in
            guard let date = dateFormatter.date(from: dayData.date) else {
                print("❌ Failed to parse date: \(dayData.date)")
                return nil
            }
            
            return DailyMacroSplit(
                date: date,
                calories: dayData.calories,  // Use raw calories from backend
                proteinCals: dayData.proteinCals,
                carbCals: dayData.carbCals,
                fatCals: dayData.fatCals,
                proteinGrams: dayData.proteinGrams,
                carbGrams: dayData.carbGrams,
                fatGrams: dayData.fatGrams
            )
        }.sorted { $0.date < $1.date }
        
        print("📊 Processing \(dailyMacros.count) days of macro data from profile")
        
        // Group by weeks relative to today
        let today = Date()
        
        for dayData in dailyMacros {
            // Use the start of each week (Sun‑Sat, local timezone) so we count whole
            // weeks consistently and avoid off‑by‑one issues for Fri/Sat.
            var calendar = Calendar.current
            calendar.timeZone = TimeZone.current

            guard
                let startOfTodayWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
                let startOfDayWeek   = calendar.dateInterval(of: .weekOfYear, for: dayData.date)?.start
            else { return }

            let weeksAgo = calendar.dateComponents([.weekOfYear],
                                                   from: startOfDayWeek,
                                                   to: startOfTodayWeek).weekOfYear ?? 0

            let weekOption: WeekOption
            switch weeksAgo {
            case 0:
                weekOption = .thisWeek
            case 1:
                weekOption = .lastWeek
            case 2:
                weekOption = .twoWeeksAgo
            case 3...:
                weekOption = .threeWeeksAgo
            default:
                continue // Skip future dates
            }
            
            if processedData[weekOption] == nil {
                processedData[weekOption] = []
            }
            processedData[weekOption]?.append(dayData)
        }
        
        // Sort each week's data by date to ensure proper chronological order
        for weekOption in processedData.keys {
            processedData[weekOption]?.sort { $0.date < $1.date }
        }
        
        macroSplitData = processedData
        print("✅ Processed macro data into weeks: \(processedData.keys.count) weeks available")
    }
    
    private func calculateWeeklyTotal(for week: WeekOption) -> Double {
        guard let weekData = macroSplitData[week] else { return 0 }
        let total = weekData.reduce(0) { $0 + $1.totalCals }
        return weekData.isEmpty ? 0 : total / Double(weekData.count)
    }
    
    // MARK: - Helper Functions
    
    private func processProfileData() {
        guard let profileData = onboarding.profileData else { return }
        
        // Process macro data if available
        processProfileMacroData(profileData)
        
        // Update weight/height from profile data
        if let weightKg = profileData.currentWeightKg, weightKg > 0 {
            vm.weight = weightKg
                            currentWeightKg = weightKg
        }
        
        if let heightCm = profileData.heightCm, heightCm > 0 {
            vm.height = heightCm
        }
        
        print("✅ Processed preloaded profile data - weight: \(vm.weight)kg, height: \(vm.height)cm")
    }
    
    // Helper function to parse dates robustly
    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 with fractional seconds first
        let iso8601WithFractional = ISO8601DateFormatter()
        iso8601WithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601WithFractional.date(from: dateString) {
            return date
        }
        
        // Try ISO8601 without fractional seconds
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: dateString) {
            return date
        }
        
        // Try other common formats
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'"
        ]
        
        for formatString in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = formatString
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func formatWeightLogDate(_ dateString: String) -> String {
        // Try ISO8601DateFormatter first
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: dateString) {
            return formatParsedDate(date)
        }
        
        // Try various DateFormatter patterns
        let dateFormatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
                return formatter
            }()
        ]
        
        for formatter in dateFormatters {
            if let date = formatter.date(from: dateString) {
                return formatParsedDate(date)
            }
        }
        
        print("❌ Failed to parse date: \(dateString)")
        return "Unknown date"
    }
    
    private func formatParsedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let result: String
        if calendar.isDateInToday(date) {
            // Today: show time like "4:19 AM"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            result = timeFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            // Yesterday: show "Yesterday"
            result = "Yesterday"
        } else {
            // Other dates: show "Jun 4" format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            result = dateFormatter.string(from: date)
        }
        
        print("📅 Date formatting: \(date) -> '\(result)'")
        return result
    }
    
    private func formatDateString(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func fetchWeightData() {
        // Always fetch from API to get recent logs for the chart, even if vm has weight
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("❌ No user email found for weight fetch")
            return
        }
        
        print("🏋️ Fetching weight data for email: \(email)")
        print("🏋️ vm.weight value: \(vm.weight)")
        
        // Store vm.weight as the preferred source of truth (vm.weight is already in kg)
        let vmWeightKg = vm.weight > 0 ? vm.weight : nil
        
        // If vm has weight, use it immediately but still fetch logs for chart
        if let vmWeight = vmWeightKg {
            currentWeightKg = vmWeight
            print("🏋️ Got initial weight from DayLogsViewModel: \(vm.weight)kg")
        }
        
        isLoadingWeight = true
        NetworkManagerTwo.shared.fetchWeightLogs(userEmail: email, limit: 7, offset: 0) { result in
            DispatchQueue.main.async {
                self.isLoadingWeight = false
                
                switch result {
                case .success(let response):
                    self.recentWeightLogs = response.logs
                    
                    print("🏋️ Weight API Response:")
                    print("  - Total logs received: \(response.logs.count)")
                    print("  - Show chart condition (count >= 2): \(response.logs.count >= 2)")
                    
                    for (index, log) in response.logs.enumerated() {
                        print("  - Log \(index + 1): \(log.weightKg)kg (\(log.weightKg * 2.20462)lbs) on \(log.dateLogged)")
                    }
                    
                    if let mostRecentLog = response.logs.first {
                        self.weightDate = mostRecentLog.dateLogged
                        
                        // Only update currentWeightKg if vm.weight doesn't exist or API has newer data
                        if vmWeightKg == nil {
                            self.currentWeightKg = mostRecentLog.weightKg
                            print("🏋️ Got weight from API (no vm.weight): \(mostRecentLog.weightKg)kg")
                        } else {
                            // Keep vm.weight as it's likely more recent (just saved)
                            print("🏋️ Keeping vm.weight (\(vmWeightKg!)kg) over API weight (\(mostRecentLog.weightKg)kg)")
                        }
                    } else {
                        print("🏋️ No weight logs found")
                        if vmWeightKg == nil {
                            self.currentWeightKg = nil
                        }
                        self.weightDate = nil
                    }
                case .failure(let error):
                    print("❌ Error fetching weight logs: \(error)")
                    if vmWeightKg == nil {
                        self.currentWeightKg = nil
                        self.weightDate = nil
                    }
                    self.recentWeightLogs = []
                }
            }
        }
    }
    
    // MARK: - Pull to Refresh
    
    private func refreshProfileData() async {
        print("🔄 Pull to refresh triggered")
        
        // Refresh profile data (this will show the native pull-to-refresh indicator)
        await onboarding.fetchProfileData(force: true)
        
        // Refresh weight data
        fetchWeightData()
        
        // Refresh macro data
        fetchMacroSplitData()
        
        print("✅ Pull to refresh completed")
    }
}



// MARK: - BMI Gauge (upright semicircle, self‑centering)

enum BMICategory {
    case underweight, normal, overweight
}

struct ArcOne: View {
    let bmiValue: Double
    
    private func getBMICategory() -> BMICategory {
        if bmiValue < 18.5 { return .underweight }
        else if bmiValue <= 24.9 { return .normal }
        else { return .overweight }
    }
    
    private func getBMIColor() -> Color {
        switch getBMICategory() {
        case .underweight: return Color(red: 0.0, green: 0.3, blue: 1.0)
        case .normal: return Color(red: 0.2, green: 0.78, blue: 0.35)
        case .overweight: return Color(red: 1.0, green: 0.1, blue: 0.1)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
        ZStack {
            // The semicircle arc with distinct color zones
            SemicircleArc()
                .stroke(
                                          LinearGradient(
                          stops: [
                              // Blue zone with more visibility - more vibrant blue
                              Gradient.Stop(color: Color(red: 0.0, green: 0.3, blue: 1.0), location: 0.00),
                              Gradient.Stop(color: Color(red: 0.0, green: 0.3, blue: 1.0), location: 0.27),
                              // Gradient transition to green
                              Gradient.Stop(color: Color(red: 0.2, green: 0.78, blue: 0.35), location: 0.40),
                              // Green zone (smaller)
                              Gradient.Stop(color: Color(red: 0.2, green: 0.78, blue: 0.35), location: 0.60),
                              // Gradient transition to red - more vibrant red
                              Gradient.Stop(color: Color(red: 1.0, green: 0.1, blue: 0.1), location: 0.73),
                              // Red zone with more visibility - more vibrant red
                              Gradient.Stop(color: Color(red: 1.0, green: 0.1, blue: 0.1), location: 1.00),
                          ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 8
                )

            // BMI indicator dot on the arc
            BMIIndicatorDot(bmiValue: bmiValue) 

            // BMI value in center
            VStack(spacing: 4) {
                Text("BMI")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(String(format: "%.1f", bmiValue))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(getBMIColor())

            }
            .offset(y: -10) // Moved higher up

      
        }
        .frame(width: 380, height: 180)
        
                // Straight labels below the gauge
        HStack {
            Text("Underweight")
                .font(.subheadline.weight(.medium))
                .foregroundColor(getBMICategory() == .underweight ? Color(red: 0.0, green: 0.3, blue: 1.0) : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Normal")
                .font(.subheadline.weight(.medium))
                .foregroundColor(getBMICategory() == .normal ? Color(red: 0.2, green: 0.78, blue: 0.35) : .secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Text("Overweight")
                .font(.subheadline.weight(.medium))
                .foregroundColor(getBMICategory() == .overweight ? Color(red: 1.0, green: 0.1, blue: 0.1) : .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                }
        .padding(.horizontal, 50)
        .padding(.top, -65)
        }
        .padding(.top, 20)
        .padding(.bottom, -35)
     }
}

// BMI Indicator Dot
struct BMIIndicatorDot: View {
    let bmiValue: Double
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height * 0.55)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 4
            
            // Calculate angle based on BMI value
            let angle = bmiAngleOnArc(bmi: bmiValue)
            let x = center.x + cos(angle * .pi / 180) * radius
            let y = center.y - sin(angle * .pi / 180) * radius
            
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(Color.secondary, lineWidth: 0.2)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                .position(x: x, y: y)
        }
    }
    
    private func bmiAngleOnArc(bmi: Double) -> Double {
        // BMI ranges: Underweight (<18.5), Normal (18.5-24.9), Overweight (>25)
        // Map to arc angles: 180° (left) to 0° (right)
        
        if bmi < 18.5 {
            // Underweight: 180° to 135° (blue section)
            let progress = min(bmi / 18.5, 1.0)
            return 180 - (progress * 45)
        } else if bmi <= 24.9 {
            // Normal: 135° to 45° (green section)  
            let progress = (bmi - 18.5) / (24.9 - 18.5)
            return 135 - (progress * 90)
        } else {
            // Overweight: 45° to 0° (red section)
            let progress = min((bmi - 25) / 10, 1.0) // Cap at BMI 35
            return 45 - (progress * 45)
        }
    }
}

// Custom shape for semicircle arc
struct SemicircleArc: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.height * 0.55)
        let radius = min(rect.width, rect.height) / 2 - 4  // Adjusted for thinner stroke
        
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180), // Start from left (180°)
            endAngle: .degrees(0),     // End at right (0°)
            clockwise: false           // Draw counter-clockwise for top semicircle
        )
        return path
    }
}

// Custom view for text that follows a curved path
struct CurvedText: View {
    let text: String
    let radius: CGFloat
    let centerAngle: Double // Center angle in degrees
    let center: CGPoint
    
    var body: some View {
        ZStack {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                let charAngle = calculateCharacterAngle(for: index)
                let x = center.x + cos(charAngle * .pi / 180) * radius
                let y = center.y - sin(charAngle * .pi / 180) * radius
                
                Text(String(character))
                    .font(.subheadline.weight(.medium))
                    .rotationEffect(.degrees((charAngle - 90) * 0.1)) // VERY minimal rotation
                    .position(x: x, y: y)
            }
        }
    }
    
    private func calculateCharacterAngle(for index: Int) -> Double {
        let textLength = Double(text.count)
        let characterSpacing = 2.0 // Very tight spacing for subtle curve
        let totalSpread = characterSpacing * (textLength - 1)
        let startAngle = centerAngle + totalSpread / 2
        return startAngle - Double(index) * characterSpacing
    }
}



/// One coloured slice of the top semicircle.
private struct GaugeSlice: View {
    var colour: Color
    var startDeg: Double  // e.g. 180
    var endDeg:   Double  // e.g. 135
    var lineWidth: CGFloat

    var body: some View {
        GaugeArc(startDeg: startDeg, endDeg: endDeg)
            .stroke(colour,
                    style: StrokeStyle(lineWidth: lineWidth,
                                       lineCap: .butt))
    }
}

 /// The arc path centred at the *bottom* of the view so only the top half shows.
 private struct GaugeArc: Shape {
     var startDeg: Double
     var endDeg:   Double

     func path(in rect: CGRect) -> Path {
         let centre = CGPoint(x: rect.midX, y: rect.maxY)
         let radius = min(rect.width, rect.height) / 2 - 10  // keep stroke inside
         var p = Path()
         p.addArc(center: centre,
                  radius: radius,
                  startAngle: .degrees(startDeg),
                  endAngle: .degrees(endDeg),
                  clockwise: false)  // Changed to counter-clockwise for proper arc direction
         return p
     }
}

// MARK: - Extensions

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

// MARK: - Macro Split Card View
struct MacroSplitCardView: View {
    @Binding var selectedWeek: WeekOption
    let data: [DailyMacroSplit]
    let weeklyTotal: Double
    @State private var selectedDay: DailyMacroSplit? = nil
    
    // Create complete week data with all 7 days (Sunday to Saturday)
    private var completeWeekData: [DailyMacroSplit] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday = 1
        let today = Date()
        
        // Calculate the start of the week for the selected week option
        let weeksBack: Int
        switch selectedWeek {
        case .thisWeek: weeksBack = 0
        case .lastWeek: weeksBack = 1  
        case .twoWeeksAgo: weeksBack = 2
        case .threeWeeksAgo: weeksBack = 3
        }
        
        // Get the start of the target week (Sunday)
        let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: today) ?? today
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: targetWeekStart)?.start ?? targetWeekStart
        
        // Create all 7 days of the week
        var weekDays: [DailyMacroSplit] = []
        
        for dayOffset in 0..<7 {
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) ?? startOfWeek
            
            // Find existing data for this day
            if let existingData = data.first(where: { 
                calendar.isDate($0.date, inSameDayAs: dayDate) 
            }) {
                weekDays.append(existingData)
            } else {
                // Create empty data for missing days
                weekDays.append(DailyMacroSplit(
                    date: dayDate,
                    calories: 0,  // Add calories field for empty days
                    proteinCals: 0,
                    carbCals: 0,
                    fatCals: 0,
                    proteinGrams: 0,
                    carbGrams: 0,
                    fatGrams: 0
                ))
            }
        }
        
        return weekDays
    }
    
    private func weekdayName(for date: Date) -> String {
        let formatter = DateFormatter()
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday = 1
        formatter.calendar = calendar
        
        let dayIndex = calendar.component(.weekday, from: date) - 1
        return formatter.shortWeekdaySymbols[dayIndex]
    }
    
    private var maxDailyCals: Double {
        let maxCals = completeWeekData.map(\.totalCals).max() ?? 1000
        // Round up to a nice number for better chart scaling
        if maxCals <= 1000 {
            return 1000
        } else if maxCals <= 2000 {
            return 2000
        } else if maxCals <= 3000 {
            return 3000
        } else if maxCals <= 4000 {
            return 4000
        } else if maxCals <= 5000 {
            return 5000
        } else {
            return ceil(maxCals / 1000) * 1000
        }
    }
    
    private var averageDailyCals: Double {
        // Only count days with actual data (non-zero calories) for average
        let daysWithData = completeWeekData.filter { $0.totalCals > 0 }
        let total = daysWithData.reduce(0) { $0 + $1.totalCals }
        return daysWithData.isEmpty ? 0 : total / Double(daysWithData.count)
    }
    

    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Segmented Control
            Picker("Week Selection", selection: $selectedWeek) {
                ForEach(WeekOption.allCases, id: \.self) { week in
                    Text(week.displayName).tag(week)
                }
            }
            .pickerStyle(.segmented)
            
            // Average Daily Calories Header
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Average Daily Calories")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(averageDailyCals))")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("cals")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Stacked Bar Chart
            Chart {
                ForEach(Array(completeWeekData.enumerated()), id: \.element.id) { index, dayData in
                    let dayName = weekdayName(for: dayData.date)
                    let isFocused = selectedDay?.id == dayData.id
                    let dimmedOpacity = selectedDay == nil || isFocused ? 1.0 : 0.3
                    // Fat (pink) - bottom layer
                    BarMark(
                        x: .value("Day", dayName),
                        yStart: .value("Start", 0),
                        yEnd: .value("Fat", dayData.fatCals),
                        width: .fixed(20)
                    )
                    .foregroundStyle(Color.pink)
                    .cornerRadius(0)
                    .opacity(dimmedOpacity)

                    // Carbs (darkYellow) - middle layer
                    BarMark(
                        x: .value("Day", dayName),
                        yStart: .value("Start", dayData.fatCals),
                        yEnd: .value("Carbs", dayData.fatCals + dayData.carbCals),
                        width: .fixed(20)
                    )
                    .foregroundStyle(Color("darkYellow"))
                    .cornerRadius(0)
                    .opacity(dimmedOpacity)

                    // Protein (blue) - top layer
                    BarMark(
                        x: .value("Day", dayName),
                        yStart: .value("Start", dayData.fatCals + dayData.carbCals),
                        yEnd: .value("Protein", dayData.totalCals),
                        width: .fixed(20)
                    )
                    .foregroundStyle(Color.blue)
                    .cornerRadius(0)
                    .opacity(dimmedOpacity)
                    // Tooltip annotation when this bar is selected
                    .annotation(position: .top, alignment: .center, spacing: 0) {
                        if selectedDay?.id == dayData.id {
                            VStack(alignment: .center, spacing: 4) {
                                Text("\(Int(dayData.totalCals)) cals")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                                        Text("Protein: \(Int(dayData.proteinGrams))g")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    HStack(spacing: 4) {
                                        Circle().fill(Color("darkYellow")).frame(width: 6, height: 6)
                                        Text("Carbs: \(Int(dayData.carbGrams))g")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.pink).frame(width: 6, height: 6)
                                        Text("Fat: \(Int(dayData.fatGrams))g")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color("containerbg"))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let plotFrame = geo[proxy.plotAreaFrame]
                                    guard plotFrame.contains(value.location) else { return }
                                    let relativeX = value.location.x - plotFrame.minX
                                    let dayWidth  = plotFrame.width / CGFloat(max(completeWeekData.count, 1))
                                    let index     = Int(relativeX / max(dayWidth, 1))
                                    let clamped   = max(0, min(index, completeWeekData.count - 1))
                                    guard !completeWeekData.isEmpty && clamped < completeWeekData.count else { return }
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedDay = completeWeekData[clamped]
                                    }
                                }
                                .onEnded { _ in
                                    // Remove focus on release
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedDay = nil
                                    }
                                }
                        )
                }
            }
            .chartYScale(domain: 0...maxDailyCals)
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 200)
            
            // Legend - Centered
            HStack {
                Spacer()

                HStack(spacing: 24) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                        Text("Protein")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color("darkYellow"))
                            .frame(width: 12, height: 12)
                        Text("Carbs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.pink)
                            .frame(width: 12, height: 12)
                        Text("Fat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color("containerbg"))
        .cornerRadius(16)
    }
}

// MARK: - Helper Functions
extension MyProfileView {
    // Units system helpers
    private var weightUnit: String {
        switch onboarding.unitsSystem {
        case .imperial:
            return "lbs"
        case .metric:
            return "kg"
        }
    }
    
    private func formatWeight(_ weightKg: Double) -> String {
        switch onboarding.unitsSystem {
        case .imperial:
            let weightLbs = weightKg * 2.20462
            return String(format: "%.0f", weightLbs)
        case .metric:
            return String(format: "%.1f", weightKg)
        }
    }
    
    private func getDisplayWeight(_ weightKg: Double) -> Double {
        switch onboarding.unitsSystem {
        case .imperial:
            return weightKg * 2.20462
        case .metric:
            return weightKg
        }
    }
}

// Remove any BarMark .clipShape(UnevenRoundedRectangle(...)) in MacroSplitCardView (if present)

// MARK: - ProfileLogRow (dedicated component for MyProfileView logs)

struct ProfileLogRow: View {
    let log: CombinedLog
    @State private var isHighlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: Meal icon, Name and optional time (ONLY for today)
            HStack {
                Image(systemName: mealTimeSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)

                Text(displayName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)

                Spacer()

                // Show time ONLY if log is from today
                if let timeLabel = getTimeLabel() {
                    Text(timeLabel)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(.systemGray2))
                }
            }
            Spacer(minLength: 0)

            // Bottom row: Calories (left) and Macros/Activity Info (right)
            HStack(alignment: .bottom) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color("brightOrange"))

                    HStack(alignment: .bottom, spacing: 1) {
                        Text("\(Int(log.displayCalories))")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("cal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Show different info based on log type
                if log.type == .activity {
                    // Activity-specific info: Duration and Distance
                    HStack(spacing: 24) {
                        VStack(spacing: 0) {
                            Image(systemName: "clock")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.blue)
                            Text(log.activity?.formattedDuration ?? "0 min")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.primary)
                        }

                        if let activity = log.activity, activity.isDistanceActivity, let distance = activity.formattedDistance {
                            VStack(spacing: 0) {
                                Image(systemName: "location")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.green)
                                Text(distance)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                } else {
                    // Food/Meal/Recipe macros
                    HStack(spacing: 24) {
                        VStack(spacing: 0) {
                            Text("Protein")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.blue)
                            Text("\(Int(protein))g")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        VStack(spacing: 0) {
                            Text("Carbs")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Color("darkYellow", bundle: nil) ?? .orange)
                            Text("\(Int(carbs))g")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        VStack(spacing: 0) {
                            Text("Fat")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.pink)
                            Text("\(Int(fat))g")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color("containerbg"))
                .shadow(color: Color(.black).opacity(0.04), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.accentColor.opacity(isHighlighted ? 0.5 : 0), lineWidth: 2)
                )
        )
        .cornerRadius(24)
        .onAppear {
            if log.isOptimistic {
                withAnimation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true)) {
                    isHighlighted = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { isHighlighted = false }
                }
            }
        }
    }

    // Helper properties
    private var displayName: String {
        switch log.type {
        case .food:
            return log.food?.displayName ?? "Food"
        case .meal:
            return log.meal?.title ?? "Meal"
        case .recipe:
            return log.recipe?.title ?? "Recipe"
        case .activity:
            return log.activity?.displayName ?? "Activity"
        case .workout:
            return log.workout?.title ?? "Workout"
        }
    }

    private var mealTimeSymbol: String {
        switch log.type {
        case .activity:
            return log.activity?.activityIcon ?? "figure.strengthtraining.traditional"
        case .workout:
            return "figure.strengthtraining.traditional"
        default:
            guard let mealType = log.mealType?.lowercased() else { return "popcorn.fill" }

            switch mealType {
            case "breakfast":
                return "sunrise.fill"
            case "lunch":
                return "sun.max.fill"
            case "dinner":
                return "moon.fill"
            case "snacks", "snack":
                return "popcorn.fill"
            default:
                return "popcorn.fill"
            }
        }
    }

    private func getTimeLabel() -> String? {
        // Determine what date this log is from
        guard let logDateString = log.logDate,
              let logDate = dateFromLogDateString(logDateString) else {
            return nil
        }

        let calendar = Calendar.current

        // TODAY: Show time (e.g., "11:11 AM")
        if calendar.isDateInToday(logDate) {
            guard let scheduledAt = log.scheduledAt else { return nil }
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: scheduledAt)
        }

        // YESTERDAY: Show "Yesterday"
        if calendar.isDateInYesterday(logDate) {
            return "Yesterday"
        }

        // LAST 7 DAYS: Show weekday (e.g., "Saturday")
        let startOfNow = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: logDate)
        if let days = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day,
           days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: logDate)
        }

        // OLDER: Show short date (e.g., "9/5/25")
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: logDate)
    }

    private func dateFromLogDateString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

    // Macro helpers
    private var protein: Double {
        log.food?.protein ?? log.meal?.protein ?? log.recipe?.protein ?? 0
    }
    private var carbs: Double {
        log.food?.carbs ?? log.meal?.carbs ?? log.recipe?.carbs ?? 0
    }
    private var fat: Double {
        log.food?.fat ?? log.meal?.fat ?? log.recipe?.fat ?? 0
    }
}

#Preview {
    MyProfileView(isAuthenticated: .constant(true))
}
