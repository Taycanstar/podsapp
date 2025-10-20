import SwiftUI
import HealthKit
import Combine

struct DashboardView: View {

    // ─── Shared app-wide state ──────────────────────────────────────────────
    @EnvironmentObject private var onboarding: OnboardingViewModel
    @EnvironmentObject private var foodMgr   : FoodManager
    @Environment(\.isTabBarVisible) private var isTabBarVisible
    @EnvironmentObject var vm: DayLogsViewModel
    @EnvironmentObject private var mealReminderService: MealReminderService
    @EnvironmentObject private var proFeatureGate: ProFeatureGate
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @AppStorage(WaterUnit.storageKey) private var storedWaterUnitRawValue: String = WaterUnit.defaultUnit.rawValue
    @ObservedObject private var workoutManager = WorkoutManager.shared
    @ObservedObject private var userProfileService = UserProfileService.shared
    
    // ─── Health data state ───────────────────────────────────────────────────
    @StateObject private var healthViewModel = HealthKitViewModel()

    // ─── Local UI state ─────────────────────────────────────────────────────
    @State private var showDatePicker = false
    @State private var showWaterLogSheet = false
    @State private var showWorkoutContainer = false
    @State private var workoutSelectedTab: Int = 0
    @State private var isTodayWorkoutDismissed = false
    @AppStorage("hideWorkoutPreviews") private var hideWorkoutPreviews = false
    // ─── Streak state ─────────────────────────────────────────────────────
    @ObservedObject private var streakManager = StreakManager.shared


    @State private var selectedFoodLogId: String? = nil
    @State private var selectedMealLogId: String? = nil
    @State private var selectedWorkoutLogId: String? = nil
    @State private var scheduleSheetLog: CombinedLog?
    @State private var scheduleAlert: ScheduleAlert?
    @State private var pendingLogsReload = false
    
    // ─── Nutrition label name input ────────────────────────────────────────
    @State private var nutritionProductName = ""
    
    // ─── Sort state ─────────────────────────────────────────────────────────
    @State private var sortOption: LogSortOption = .date
    
    enum LogSortOption: String, CaseIterable {
        case date = "Date"
        case meal = "Meal"
        
        var iconName: String {
            switch self {
            case .date: return "calendar"
            case .meal: return "fork.knife"
            }
        }
    }

    private enum ScheduleAlert: Identifiable {
        case success(String)
        case failure(String)

        var id: String {
            switch self {
            case .success(let message): return "success_\(message)"
            case .failure(let message): return "failure_\(message)"
            }
        }
    }

    // ─── Quick helpers ──────────────────────────────────────────────────────
    private var isToday     : Bool { Calendar.current.isDateInToday(vm.selectedDate) }
    
    // Reactive water intake calculation
    private var totalWaterIntake: Double {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: vm.selectedDate)

        
        let total = vm.waterLogs.compactMap { log in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let logDate = formatter.date(from: log.dateLogged) else { 
          
                return nil 
            }
            let logDay = calendar.startOfDay(for: logDate)
            
            let isMatchingDay = calendar.isDate(logDay, inSameDayAs: selectedDay)
   
            
            return isMatchingDay ? log.waterOz : nil
        }.reduce(0.0) { $0 + $1 }

        return total
    }
    private var waterDisplayUnit: WaterUnit {
        WaterUnit(rawValue: storedWaterUnitRawValue) ?? .defaultUnit
    }

    private var totalWaterDisplayValue: String {
        let converted = waterDisplayUnit.convertFromUSFluidOunces(totalWaterIntake)
        return waterDisplayUnit.format(converted)
    }
    private var isYesterday : Bool { Calendar.current.isDateInYesterday(vm.selectedDate) }

  private var calorieGoal : Double { vm.calorieGoal }
private var remainingCal: Double { vm.remainingCalories }

    // ─── Sorted logs ────────────────────────────────────────────────────────
    private var sortedLogs: [CombinedLog] {
        switch sortOption {
        case .date:
            // Default sorting: most recent first
            return vm.logs
        case .meal:
            // Sort by meal type: Breakfast, Lunch, Dinner, Snacks
            return vm.logs.sorted { log1, log2 in
                let mealOrder = ["Breakfast": 0, "Lunch": 1, "Dinner": 2, "Snacks": 3]
                let meal1 = log1.mealType ?? ""
                let meal2 = log2.mealType ?? ""
                let order1 = mealOrder[meal1] ?? 999
                let order2 = mealOrder[meal2] ?? 999
                return order1 < order2
            }
        }
    }

    private var scheduledPreviewsForSelectedDate: [ScheduledLogPreview] {
        let calendar = Calendar.current
        return vm.scheduledPreviews
            .filter { calendar.isDate($0.normalizedTargetDate, inSameDayAs: vm.selectedDate) }
            .sorted { $0.normalizedTargetDate < $1.normalizedTargetDate }
    }

    @ViewBuilder
    private var scheduledPreviewsSection: some View {
        if !scheduledPreviewsForSelectedDate.isEmpty {
            Section {
                                ForEach(scheduledPreviewsForSelectedDate) { preview in
                                    let _ = print("[Dashboard] scheduled card", preview.id, preview.summary.title, preview.normalizedTargetDate, vm.selectedDate)
#if DEBUG
                                    let _ = print("[Dashboard] Rendering scheduled preview id:\(preview.id) normalized:\(preview.normalizedTargetDate) selected:\(vm.selectedDate)")
#endif
                                    ScheduledLogPreviewCard(
                                        preview: preview,
                                        onAccept: { handleScheduled(preview: preview, action: .log) },
                                        onSkip: { handleScheduled(preview: preview, action: .skip) }
                                    )
                                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            handleCancelScheduled(preview: preview)
                                        } label: {
                                            Label("Delete", systemImage: "trash.fill")
                                        }
                                    }
                                }
                            }
        }
    }

    @ViewBuilder
    private var logsSection: some View {
        if !vm.logs.isEmpty {
            Section {
                HStack {
                    Text("Recent Logs")
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer()

                    Menu {
                        ForEach(LogSortOption.allCases, id: \.self) { option in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    sortOption = option
                                }
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    Spacer()
                                    Image(systemName: option.iconName)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(sortedLogs) { log in
                ZStack {
                    LogRow(log: log)
                        .id(log.id)
                        .onTapGesture {
                            if log.type == .food {
                                selectedFoodLogId = log.id
                            } else if log.type == .meal {
                                selectedMealLogId = log.id
                            } else if log.type == .workout {
                                selectedWorkoutLogId = log.id
                            }
                        }
                    // NavigationLink for food logs
                    if log.type == .food {
                        NavigationLink(
                            destination: FoodLogDetails(log: log),
                            tag: log.id,
                            selection: $selectedFoodLogId
                        ) {
                            EmptyView()
                        }
                        .opacity(0)
                        .frame(width: 0, height: 0)
                    }

                    // NavigationLink for meal logs
                    if log.type == .meal {
                        NavigationLink(
                            destination: MealLogDetails(log: log),
                            tag: log.id,
                            selection: $selectedMealLogId
                        ) {
                            EmptyView()
                        }
                        .opacity(0)
                        .frame(width: 0, height: 0)
                    }

                    if log.type == .workout {
                        NavigationLink(
                            destination: WorkoutLogDetailView(log: log),
                            tag: log.id,
                            selection: $selectedWorkoutLogId
                        ) {
                            EmptyView()
                        }
                        .opacity(0)
                        .frame(width: 0, height: 0)
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading) {
                    // Save/Unsave action - only for meal logs and food logs
                    if log.type == .meal || log.type == .food {
                        let isSaved = foodMgr.isLogSaved(
                            foodLogId: log.type == .food ? log.foodLogId : nil,
                            mealLogId: log.type == .meal ? log.mealLogId : nil
                        )

                        Button(action: {
                            if isSaved {
                                unsaveMealAction(log: log)
                            } else {
                                saveMealAction(log: log)
                            }
                        }) {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        }
                        .tint(.accentColor)
                    }
                }
                .swipeActions(edge: .trailing) {
                    // Delete action with trash icon (keep furthest trailing)
                    Button {
                        deleteLogItem(log: log)
                    } label: {
                        Image(systemName: "trash.fill")
                    }
                    .tint(.red)

                    if canSchedule(log) {
                        Button {
                            handleScheduleAction(for: log)
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                        }
                        .tint(.indigo)
                    }
                }
                .id("\(log.id)_\(foodMgr.savedLogIds.count)")
            }
            .onDelete { indexSet in
                deleteLogItems(at: indexSet)
            }
        }
    }

    @ViewBuilder
    private var emptyStateSection: some View {
        if vm.logs.isEmpty && scheduledPreviewsForSelectedDate.isEmpty {
            Section {
                emptyState
                    .padding(.horizontal)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
    }


    private var navTitle: String {
        if isToday      { return "Today" }
        if isYesterday  { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: vm.selectedDate)
    }

    private var currentUserEmail: String? {
        if onboarding.email.isEmpty == false {
            return onboarding.email
        }
        if let stored = UserDefaults.standard.string(forKey: "userEmail"), stored.isEmpty == false {
            return stored
        }
        return nil
    }
    
    // ─── Units system helpers ──────────────────────────────────────────────
    private var weightUnit: String {
        switch onboarding.unitsSystem {
        case .imperial:
            return "lb"
        case .metric:
            return "kg"
        }
    }
    
    private var heightUnit: String {
        switch onboarding.unitsSystem {
        case .imperial:
            return ""  // For imperial, we show the units inline (e.g., "5' 9\"")
        case .metric:
            return "cm"
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
    
    private func formatHeight(_ heightCm: Double) -> String {
        switch onboarding.unitsSystem {
        case .imperial:
            let totalInches = heightCm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
            return "\(feet)' \(inches)\""
        case .metric:
            return String(format: "%.1f", heightCm)
        }
    }

    // ────────────────────────────────────────────────────────────────────────
    // MARK: -- View body
    // ────────────────────────────────────────────────────────────────────────

    var body: some View {

        
        NavigationView {
            ZStack {
                Color("primarybg").ignoresSafeArea()

                // Single List containing everything for smooth scrolling
                List {
                    // Header content as list sections
                    Section {
                        nutritionSummaryCard
                                 .padding(.horizontal, -16) 
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        if isToday && !isTodayWorkoutDismissed && !hideWorkoutPreviews {
                            todayWorkoutCard
                                .padding(.horizontal)
                                // .padding(.top, 8)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }


                        
                        // UNIFIED: Single modern loader with dynamic progress (legacy states now synchronized)
                        if foodMgr.foodScanningState.isActive {

                            ModernFoodLoadingCard(state: foodMgr.foodScanningState)
                                .padding(.horizontal)
                                .padding(.top, 16)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {

                        }
                    }
                    
                    // Logs section
                    if vm.isLoading {
                        Section {
                            loadingState
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } else if let err = vm.error {
                        Section {
                            errorState(err)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } else {
                        scheduledPreviewsSection
                        logsSection
                        emptyStateSection
                    }
                    }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    // Add buffer space for tab bar
                    Spacer()
                        .frame(height: 100)
                }
                .animation(.default, value: sortedLogs)

                   if foodMgr.showAIGenerationSuccess, let food = foodMgr.aiGeneratedFood {
        VStack {
          Spacer()
          BottomPopup(message: "Food logged")
            .padding(.bottom, 90)
        }
        .zIndex(1)
        .transition(.opacity)
        .animation(.spring(), value: foodMgr.showAIGenerationSuccess)
      }
      else if foodMgr.showLogSuccess, let item = foodMgr.lastLoggedItem {
        VStack {
          Spacer()
          BottomPopup(message: "\(item.name) logged")
            .padding(.bottom, 90)
        }
        .zIndex(1)
        .transition(.opacity)
        .animation(.spring(), value: foodMgr.showLogSuccess)
      }
      else if foodMgr.showSavedMealToast {
        VStack {
          Spacer()
          BottomPopup(message: "Saved Meal")
            .padding(.bottom, 90)
        }
        .zIndex(1)
        .transition(.opacity)
        .animation(.spring(), value: foodMgr.showSavedMealToast)
      }
      else if foodMgr.showUnsavedMealToast {
        VStack {
          Spacer()
          BottomPopup(message: "Unsaved Meal")
            .padding(.bottom, 90)
        }
        .zIndex(1)
        .transition(.opacity)
        .animation(.spring(), value: foodMgr.showUnsavedMealToast)
      }
      else if workoutManager.showWorkoutLogCard, let workout = workoutManager.lastCompletedWorkout {
        VStack {
          Spacer()
          WorkoutLogCard(summary: workout)
            .padding(.horizontal, 16)
            .padding(.bottom, 90)
        }
        .zIndex(1)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: workoutManager.showWorkoutLogCard)
      }
    }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color("primarybg"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbarContent }
            .sheet(item: $scheduleSheetLog) { log in
                ScheduleMealSheet(initialMealType: initialMealType(for: log)) { selection in
                    scheduleLog(selection: selection, for: log)
                }
            }
            .sheet(isPresented: Binding(
                get: { proFeatureGate.showUpgradeSheet && proFeatureGate.blockedFeature != .workouts },
                set: { if !$0 { proFeatureGate.dismissUpgradeSheet() } }
            )) {
                if proFeatureGate.blockedFeature == .foodScans {
                    LogProUpgradeSheet(
                        usageSummary: proFeatureGate.usageSummary,
                        onDismiss: { proFeatureGate.dismissUpgradeSheet() }
                    )
                } else {
                    HumuliProUpgradeSheet(
                        feature: proFeatureGate.blockedFeature,
                        usageSummary: proFeatureGate.usageSummary,
                        onDismiss: { proFeatureGate.dismissUpgradeSheet() }
                    )
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(date: $vm.selectedDate,
                                isPresented: $showDatePicker)
            }
            .alert("Product Name Required", isPresented: $foodMgr.showNutritionNameInput) {
                TextField("Enter product name", text: $nutritionProductName)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    foodMgr.cancelNutritionNameInput()
                }
                Button("Save") {
                    if !nutritionProductName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        foodMgr.createNutritionLabelFoodWithName(nutritionProductName) { result in
                            DispatchQueue.main.async {
                                nutritionProductName = "" // Reset for next time
                                switch result {
                                case .success:
                                    print("✅ Successfully created nutrition label food")
                                case .failure(let error):
                                    print("❌ Failed to create nutrition label food: \(error)")
                                }
                            }
                        }
                    }
                }
                .disabled(nutritionProductName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("We couldn't find the product name on the nutrition label. Please enter it manually.")
            }
            .alert(foodMgr.scanFailureType, isPresented: $foodMgr.showScanFailureAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(foodMgr.scanFailureMessage)
            }
            .alert(item: $scheduleAlert) { alert in
                switch alert {
                case .success(let message):
                    return Alert(title: Text("Scheduled"), message: Text(message), dismissButton: .default(Text("OK")))
                case .failure(let message):
                    return Alert(title: Text("Error"), message: Text(message), dismissButton: .default(Text("OK")))
                }
            }
            .onAppear {
                configureOnAppear() 
                
                // Initialize food manager with user email only if we have a valid email
                if !onboarding.email.isEmpty {
                    foodMgr.initialize(userEmail: onboarding.email)
                    
                    // Set up the connection between FoodManager and DayLogsViewModel for voice logging
                    foodMgr.dayLogsViewModel = vm
                } else {
                    print("⚠️ DashboardView onAppear - No email available for FoodManager initialization")
                }
                
                // Load health data for the selected date
                healthViewModel.reloadHealthData(for: vm.selectedDate)
                

            }
            .onChange(of: onboarding.email) { newEmail in
                print("🔄 DashboardView - User email changed to: \(newEmail)")
                
                // If email changed, reinitialize everything for the new user
                if !newEmail.isEmpty && vm.email != newEmail {
                    print("🔄 DashboardView - Reinitializing for new user")
                    
                    // Update DayLogsViewModel
                    vm.setEmail(newEmail)
                    vm.logs = [] // Clear existing logs
                    vm.loadLogs(for: vm.selectedDate) // Load logs for new user
                    
                    // Update UserDefaults
                    UserDefaults.standard.set(newEmail, forKey: "userEmail")
                    
                    // Clear cached data from previous user
                    UserDefaults.standard.removeObject(forKey: "preloadedWeightLogs")
                    UserDefaults.standard.removeObject(forKey: "preloadedHeightLogs")
                    
                    // Reinitialize FoodManager for new user
                    foodMgr.initialize(userEmail: newEmail)
                    foodMgr.dayLogsViewModel = vm
                    
                    // Preload data for new user
                    preloadHealthData()
                }
            }
            .onChange(of: vm.selectedDate) { newDate in
                // Force refresh to ensure correct data for the selected date
                // This prevents stale cache from showing wrong date's logs
                vm.loadLogs(for: newDate, force: true)

                // Update health data for the selected date
                healthViewModel.reloadHealthData(for: newDate)
            }
            .onChange(of: foodMgr.foodScanningState) { oldState, newState in

            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: NSNotification.Name("WaterLoggedNotification"))
                    .receive(on: RunLoop.main)
            ) { _ in
                print("💧 DashboardView received WaterLoggedNotification - refreshing logs for \(vm.selectedDate)")
                // Refresh logs data when water is logged (for current selected date)
                vm.loadLogs(for: vm.selectedDate, force: true)
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: NSNotification.Name("FoodLogUpdated"))
                    .receive(on: RunLoop.main)
            ) { notification in
                print("🍎 DashboardView received FoodLogUpdated notification")
                if let userInfo = notification.userInfo,
                   let updatedLog = userInfo["updatedLog"] as? CombinedLog,
                   let logId = userInfo["logId"] as? Int {
                    
                    // Update the log in our local state immediately
                    if let index = vm.logs.firstIndex(where: { $0.foodLogId == logId }) {
                        vm.logs[index] = updatedLog
                        print("✅ Updated log in dashboard view")
                    }
                }
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: NSNotification.Name("HealthDataAvailableNotification"))
                    .receive(on: RunLoop.main)
            ) { _ in
                print("📊 Health data available - reloading dashboard")
                vm.loadLogs(for: vm.selectedDate)
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: NSNotification.Name("LogsChangedNotification"))
                    .receive(on: RunLoop.main)
            ) { notification in
                let isLocal = (notification.userInfo?["localOnly"] as? Bool) ?? false
                let source = notification.userInfo?["source"] as? String
                print("🔄 DashboardView received LogsChangedNotification - localOnly=\(isLocal), source=\(source ?? "unknown")")
                if isLocal {
                    // Optimistic updates already handled; defer heavy refresh until date change
                    return
                }
                if source != "DayLogsViewModel" {
                    refreshPreloadedProfileData()
                }
                if source == "DayLogsViewModel" {
                    // View model already reconciled with the server; no need to refetch logs again
                    return
                }
                if selectedWorkoutLogId != nil {
                    pendingLogsReload = true
                } else {
                    vm.requestLogsReloadFromNotification()
                }
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .workoutDataChanged)
                    .receive(on: RunLoop.main)
            ) { notification in
                print("🔄 DashboardView received WorkoutDataChanged - adding workouts to UI")
                // Extract workout data from notification (matches food logging pattern)
                if let workouts = notification.userInfo?["workouts"] as? [CombinedLog] {
                    print("✅ Adding \(workouts.count) workout(s) to dashboard via addPending")
                    for workout in workouts {
                        vm.addPending(workout)
                    }
                } else {
                    // Fallback: refresh logs if no workout data in notification
                    if selectedWorkoutLogId != nil {
                        pendingLogsReload = true
                    } else {
                        vm.requestLogsReloadFromNotification()
                    }
                }
            }
            .onChange(of: selectedWorkoutLogId) { newValue in
                if newValue == nil, pendingLogsReload {
                    pendingLogsReload = false
                    vm.requestLogsReloadFromNotification()
                }
            }


            .background(
                NavigationLink(
                    destination: WeightDataView(),
                    isActive: $vm.navigateToWeightData,
                    label: { EmptyView() }
                )
                .hidden()
            )
        }
        .navigationViewStyle(.stack)
    }

    // Delete function for swipe-to-delete functionality
    private func deleteLogItems(at indexSet: IndexSet) {
        print("Deleting log items at indices: \(indexSet)")
        
        // Get the logs that should be deleted from the sorted array
        let logsToDelete = indexSet.map { sortedLogs[$0] }
        
        // Log detailed information about the logs to be deleted
        for log in logsToDelete {
            print("🔍 Dashboard Log to delete - ID: \(log.id), Type: \(log.type)")
            
            // More detailed info based on type
            switch log.type {
            case .food:
                print("  • Food log details:")
                print("    - Food log ID: \(log.foodLogId ?? -1)")
                if let food = log.food {
                    print("    - Food ID: \(food.fdcId)")
                    print("    - Food name: \(food.displayName)")
                }
            case .meal:
                print("  • Meal log details:")
                print("    - Meal log ID: \(log.mealLogId ?? -1)")
                if let meal = log.meal {
                    print("    - Meal ID: \(meal.id)")
                    print("    - Meal title: \(meal.title)")
                }
            case .recipe:
                print("  • Recipe log details:")
                print("    - Recipe log ID: \(log.recipeLogId ?? -1)")
                if let recipe = log.recipe {
                    print("    - Recipe ID: \(recipe.id)")
                    print("    - Recipe title: \(recipe.title)")
                }
            case .activity:
                print("  • Activity log details:")
                print("    - Activity ID: \(log.activityId ?? "N/A")")
                if let activity = log.activity {
                    print("    - Activity type: \(activity.workoutActivityType)")
                    print("    - Activity name: \(activity.displayName)")
                }
            case .workout:
                print("  • Workout log details:")
                print("    - Workout log ID: \(log.workoutLogId ?? -1)")
                if let workout = log.workout {
                    print("    - Workout title: \(workout.title)")
                    print("    - Duration: \(workout.durationMinutes ?? 0) min")
                    print("    - Exercises: \(workout.exercisesCount)")
                }
            }
        }
        
        // Actually delete the items – unified via DayLogsViewModel (optimistic + server rollback)
        for log in logsToDelete {
            switch log.type {
            case .activity:
                // Preserve HealthKit safeguard
                if let activityId = log.activityId, activityId.count > 10 && activityId.contains("-") {
                    print("🏃 HealthKit activity logs cannot be deleted (they come from Apple Health)")
                    continue
                }
                fallthrough
            case .food, .meal, .recipe:
                HapticFeedback.generate()
                Task { await vm.removeLog(log) }
            case .workout:
                print("🏋️ Workout logs cannot be deleted from the dashboard (completed sessions are permanent)")
            }
        }
    }
    
    // Save function for swipe-to-save functionality
    private func saveMealAction(log: CombinedLog) {
     
        
        switch log.type {
        case .food:
            guard let foodLogId = log.foodLogId else {
                print("❌ No food log ID available")
                return
            }
            
            HapticFeedback.generateLigth()
            
            foodMgr.saveMeal(
                itemType: .foodLog,
                itemId: foodLogId,
                customName: nil,
                notes: nil
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        print("✅ Successfully saved food log: \(response.message)")
                        // Show success feedback
                        withAnimation {
                            // Could add a success animation here
                        }
                    case .failure(let error):
                        print("❌ Failed to save food log: \(error)")
                        // Could show an error alert here
                    }
                }
            }
            
        case .meal:
            guard let mealLogId = log.mealLogId else {
                print("❌ No meal log ID available")
                return
            }
            
            HapticFeedback.generateLigth()
            
            foodMgr.saveMeal(
                itemType: .mealLog,
                itemId: mealLogId,
                customName: nil,
                notes: nil
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        print("✅ Successfully saved meal log: \(response.message)")
                        // Show success feedback
                        withAnimation {
                            // Could add a success animation here
                        }
                    case .failure(let error):
                        print("❌ Failed to save meal log: \(error)")
                        // Could show an error alert here
                    }
                }
            }
            
        case .recipe:
            print("📝 Recipe saving not yet implemented")
        case .activity:
            print("🏃 Activity logs cannot be saved (they come from Apple Health)")
        case .workout:
            print("🏋️ Workout logs cannot be saved from the dashboard")
        }
    }
    
    // Unsave function for swipe-to-unsave functionality
    private func unsaveMealAction(log: CombinedLog) {
        print("🗑️ Unsaving meal/food log: \(log.id)")
        
        switch log.type {
        case .food:
            guard let foodLogId = log.foodLogId else {
                print("❌ No food log ID available")
                return
            }
            
            HapticFeedback.generateLigth()
            
            foodMgr.unsaveByLogId(foodLogId: foodLogId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        print("✅ Successfully unsaved food log: \(response.message)")
                    case .failure(let error):
                        print("❌ Failed to unsave food log: \(error)")
                    }
                }
            }
            
        case .meal:
            guard let mealLogId = log.mealLogId else {
                print("❌ No meal log ID available")
                return
            }
            
            HapticFeedback.generateLigth()
            
            foodMgr.unsaveByLogId(mealLogId: mealLogId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        print("✅ Successfully unsaved meal log: \(response.message)")
                    case .failure(let error):
                        print("❌ Failed to unsave meal log: \(error)")
                    }
                }
            }
            
        case .recipe:
            print("📝 Recipe unsaving not yet implemented")
        case .activity:
            print("🏃 Activity logs cannot be unsaved (they come from Apple Health)")
        case .workout:
            print("🏋️ Workout logs cannot be unsaved from the dashboard")
        }
    }
    
    // Delete function for individual log items
    private func deleteLogItem(log: CombinedLog) {
        print("🗑️ Deleting individual log item: \(log.id)")
        
        switch log.type {
        case .activity:
            // Keep HealthKit safeguard
            if let activityId = log.activityId, activityId.count > 10 && activityId.contains("-") {
                print("🏃 HealthKit activity logs cannot be deleted (they come from Apple Health)")
                return
            }
            fallthrough
        case .food, .meal, .recipe:
            HapticFeedback.generate()
            Task { await vm.removeLog(log) }
        case .workout:
            print("🏋️ Workout logs cannot be deleted from the dashboard (completed sessions are permanent)")
        }
    }

    private func handleScheduleAction(for log: CombinedLog) {
        guard canSchedule(log) else { return }

        guard let email = currentUserEmail else {
            scheduleAlert = .failure("Please sign in again before scheduling.")
            return
        }

        Task { @MainActor in
            await subscriptionManager.fetchSubscriptionInfoIfNeeded(for: email)
            proFeatureGate.requirePro(for: .scheduledLogging, userEmail: email) {
                scheduleSheetLog = log
            }
        }
    }

    private func scheduleLog(selection: ScheduleMealSelection, for log: CombinedLog) {
        guard let email = currentUserEmail else {
            scheduleAlert = .failure("Please sign in again before scheduling.")
            return
        }

        let (logType, logId): (String, Int?) = {
            switch log.type {
            case .meal: return ("meal", log.mealLogId)
            case .food: return ("food", log.foodLogId)
            default: return ("", nil)
            }
        }()

        guard let resolvedId = logId else {
            scheduleAlert = .failure("We couldn't schedule this entry. Please try again.")
            return
        }

        NetworkManager().scheduleMealLog(
            logId: resolvedId,
            logType: logType,
            scheduleType: selection.scheduleType.rawValue,
            targetDate: selection.targetDate,
            mealType: selection.mealType,
            userEmail: email
        ) { result in
            DispatchQueue.main.async {
                scheduleSheetLog = nil
                switch result {
                case .success(let response):
                    vm.upsertScheduledPreview(from: response, sourceLog: log)

                    let calendar = Calendar.current
                    if calendar.isDate(response.targetDate, inSameDayAs: vm.selectedDate) {
                        vm.loadLogs(for: vm.selectedDate, force: true)
                    }

                    let message = "This meal will appear in your scheduled previews for the selected day."
                    scheduleAlert = .success(message)
                case .failure(let error):
                    scheduleAlert = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func canSchedule(_ log: CombinedLog) -> Bool {
        switch log.type {
        case .meal:
            return log.mealLogId != nil
        case .food:
            return log.foodLogId != nil
        default:
            return false
        }
    }

    private func initialMealType(for log: CombinedLog) -> String {
        if let mealType = log.mealType, mealType.isEmpty == false {
            return mealType
        }
        if let mealTime = log.mealTime, mealTime.isEmpty == false {
            return mealTime
        }
        return "Lunch"
    }

    private func mealName(for log: CombinedLog) -> String {
        switch log.type {
        case .meal:
            return log.meal?.title ?? "Meal"
        case .food:
            return log.food?.displayName ?? "Meal"
        default:
            return "Meal"
        }
    }

    private func handleScheduled(preview: ScheduledLogPreview, action: DayLogsViewModel.ScheduledLogAction) {
        vm.removeScheduledPreview(preview)

        var placeholderIdentifier: String?

        if action == .log {
            placeholderIdentifier = vm.addOptimisticScheduledLog(from: preview)
        }

        Task {
            do {
                try await vm.processScheduledLog(
                    preview,
                    action: action,
                    placeholderIdentifier: placeholderIdentifier
                )
            } catch {
                await MainActor.run {
                    if let placeholder = placeholderIdentifier {
                        vm.removePlaceholderLog(withIdentifier: placeholder)
                    }
                    vm.restoreScheduledPreview(preview)
                    vm.error = error
                }
            }
        }
    }

    private func handleCancelScheduled(preview: ScheduledLogPreview) {
        vm.removeScheduledPreview(preview, recordSkip: false)

        Task {
            do {
                try await vm.processScheduledLog(
                    preview,
                    action: .cancel,
                    placeholderIdentifier: nil
                )
            } catch {
                await MainActor.run {
                    vm.restoreScheduledPreview(preview)
                    vm.error = error
                }
            }
        }
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: -- Sub-views
// ────────────────────────────────────────────────────────────────────────────
private extension DashboardView {
 
    // ① Nutrition summary ----------------------------------------------------
    var nutritionSummaryCard: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                TabView {
                    // Page 1: Original cards
                    VStack(spacing: 10) {
                        remainingCaloriesCard
                        macrosCard

                    }
                    .padding(.trailing, 16) // Add horizontal padding for spacing between pages
                         .padding(.leading, 16)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .padding(.top, 8)
                    
                    // Page 2: Health data summary
                    VStack(spacing: 10) {
                        macroCirclesCard
                        healthSummaryCard
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 16) // Add horizontal padding for spacing between pages
                       
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .padding(.top, 8)
                    
                    // Page 3: Health Data
                    VStack(spacing: 10) {
                        sleepCard
                        .padding(.bottom, 0)

                            // Match the healthSummaryCard approach (uses content height + padding)
                        HStack(spacing: 10) {
                            heightCard
                            weightCard
                        }
                          .frame(height: 100)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 16) // Add horizontal padding for spacing between pages
                    
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .padding(.top, 8)
                }
                .frame(height: 300) // Enough height so cards fully visible, with 8px above page dots
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
            .frame(height: 300) // Set the same height for GeometryReader
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    var todayWorkoutCard: some View {
        if let workout = workoutManager.todayWorkout,
           Calendar.current.isDate(workout.date, inSameDayAs: Date()) {
            Button {
                HapticFeedback.generate()
                workoutSelectedTab = 0
                showWorkoutContainer = true
            } label: {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: workoutIconName(for: workout))
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today's Workout")
                                .font(.subheadline)
                                .fontWeight(.regular)
                                .foregroundColor(.secondary)

                            Text(workoutManager.todayWorkoutDisplayTitle)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }

                        Spacer()

                        HStack(alignment: .center, spacing: 12) {
                            Menu {
                                ShareLink(item: generateWorkoutShareURL(workout)) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }

                                Button {
                                    HapticFeedback.generate()
                                    showWorkoutContainer = true
                                } label: {
                                    Label("See Details", systemImage: "info.circle")
                                }

                                Button(role: .destructive) {
                                    HapticFeedback.generate()
                                    withAnimation {
                                        hideWorkoutPreviews = true
                                    }
                                } label: {
                                    Label("Stop Showing", systemImage: "nosign")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)

                            Button {
                                HapticFeedback.generate()
                                withAnimation {
                                    isTodayWorkoutDismissed = true
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            summaryChip(icon: "clock", text: formattedDurationLabel(for: workout))
                            summaryChip(icon: "list.bullet", text: "\(workout.exercises.count) exercises")
                            summaryChip(icon: "target", text: workout.fitnessGoal.displayName)
                        }

                        let muscles = primaryMuscleHighlights(for: workout)
                        if !muscles.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(muscles, id: \.self) { muscle in
                                    summaryChip(text: muscle)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(cardBackgroundColor)
                        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showWorkoutContainer) {
                WorkoutContainerView(selectedTab: $workoutSelectedTab)
            }
        }
    }

    // Remaining calories card
    var remainingCaloriesCard: some View {
        NavigationLink(destination: GoalProgress()) {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Remaining")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                Text("\(Int(remainingCal))cal")
                    .font(.system(size: 32, weight: .bold))
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.2)
                    .foregroundColor(.green)

                // Protect against divide-by-zero and NaN
                let safeGoal = max(1.0, calorieGoal)
                let progress = 1 - max(0, min(remainingCal / safeGoal, 1))
                Circle()
                    .trim(from: 0,
                          to: CGFloat(progress))
                    .stroke(style: StrokeStyle(lineWidth: 10,
                                               lineCap: .round))
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(270))
                    .animation(.linear, value: remainingCal)
            }
            .frame(width: 60, height: 60)
        }
        .frame(height: 85) // Reduced height
        .padding(.vertical, 12) // Slightly reduced vertical padding
        .padding(.horizontal)
        .background(Color("containerbg"))
        // .cornerRadius(12)
        .cornerRadius(24)
        }
        .buttonStyle(PlainButtonStyle()) // Remove button styling
    }
    
    // Macros card as a separate component
    var macrosCard: some View {
        NavigationLink(destination: GoalProgress()) {
        VStack(spacing: 16) {
            macroRow(left:  ("Calories", vm.totalCalories,  "flame.fill",    Color("brightOrange")),
                    right: ("Protein",  vm.totalProtein,   "fish",        .blue))
            macroRow(left:  ("Carbs",     vm.totalCarbs,   "laurel.leading", Color("darkYellow")),
                    right: ("Fat",       vm.totalFat,      "drop.fill",     .pink))
        }
        .padding()
        .background(Color("containerbg"))
        // .cornerRadius(12)
        .cornerRadius(24)
        }
        .buttonStyle(PlainButtonStyle()) // Remove button styling
    }

    // Macro Circles Card for page 2
    var macroCirclesCard: some View {
        HStack(spacing: 8) {
            // Protein Circle
            macroCircle(
                title: "Protein",
                value: vm.totalProtein,
                goal: proteinGoal,
                color: .blue
            )
            
            // Carbs Circle
            macroCircle(
                title: "Carbs",
                value: vm.totalCarbs,
                goal: carbsGoal,
                color: Color("darkYellow")
            )
            
            // Fat Circle
            macroCircle(
                title: "Fat",
                value: vm.totalFat,
                goal: fatGoal,
                color: .pink
            )
        }
        .frame(height: 85) // Reduced height
        .padding(.vertical, 12) // Slightly reduced vertical padding
        .padding(.horizontal)
        .background(Color("containerbg"))
        // .cornerRadius(12)
        .cornerRadius(24)
    }

    // Helper function to create each macro circle
    func macroCircle(title: String, value: Double, goal: Double, color: Color) -> some View {
        let percentage = min(value / max(goal, 1) * 100, 100)
        
        return VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .padding(.top, 2)
                .padding(.bottom, 6) // Added bottom padding for the label
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(lineWidth: 6)
                    .opacity(0.2)
                    .foregroundColor(color)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(percentage / 100))
                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .foregroundColor(color)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: percentage)
                
                // Percentage and grams inside the circle
                VStack(spacing: 0) {
                    Text("\(Int(percentage))%")
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("\(Int(value))/\(Int(goal))g")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 65, height: 65) // Larger circles to fill space
        }
        .frame(maxWidth: .infinity)
    }

    // Placeholder card template for carousel
    func placeholderCard(title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                Text(subtitle)
                    .font(.system(size: 32, weight: .bold))
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: title == "Coming Soon" ? "hourglass" : "checkmark")
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(Color("containerbg"))
        .cornerRadius(12)
    }

    // Sleep card for page 3
    var sleepCard: some View {
        
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "bed.double.fill")
                        .foregroundColor(.teal)
                        .font(.system(size: 16))
                    
                    Text("Sleep")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.teal)
                }
                Spacer()
                 .frame(height: 30)
                Text("Time Asleep")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(healthViewModel.sleepHours))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("hr")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                    
                    Text("\(healthViewModel.sleepMinutes)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("min")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.2)
                    .foregroundColor(.teal)

                Circle()
                    .trim(from: 0,
                          to: CGFloat(healthViewModel.sleepProgress))
                    .stroke(style: StrokeStyle(lineWidth: 10,
                                               lineCap: .round))
                    .foregroundColor(.teal)
                    .rotationEffect(.degrees(270))
                    .animation(.linear, value: healthViewModel.sleepProgress)
            }
            .frame(width: 60, height: 60)
        }
        // .frame(height: 100)
        .padding(.vertical, 12) // Match macroCirclesCard padding
        .padding(.horizontal)
        .background(Color("containerbg"))
        // .cornerRadius(12)
        .cornerRadius(24)
    }

    // ② Loading / error / empty / list --------------------------------------
    var loadingState: some View {
        DashboardLoadingView()
    }

    func errorState(_ err: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            Text("Error loading logs").font(.headline)
            Text(err.localizedDescription)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Try again") { vm.loadLogs(for: vm.selectedDate) }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Color.accentColor).foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    var emptyState: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                let titleText = getTimeBasedGreeting()
                
                Text(titleText)
                    .font(.system(size: 36))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: true, vertical: false)
                
                Text("Your plate is empty. Tap + to start logging.")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: titleTextWidth(for: titleText))
            }
            
            Image("plate")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .onTapGesture {
            // Send notification to show NewSheetView
            NotificationCenter.default.post(name: NSNotification.Name("ShowNewSheetFromDashboard"), object: nil)
        }
    }
    
    // Helper function to get time-based greeting
    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:  // 5:00 AM to 11:59 AM
        
            return "Good Morning"
        case 12..<17:  // 12:00 PM to 4:59 PM
            return "Good Afternoon"
        default:  // 5:00 PM to 4:59 AM
            return "Good Evening"
        }
    }
    
    // Helper function to calculate title text width
    private func titleTextWidth(for text: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 36, weight: .semibold)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return size.width
    }



    // ③ Toolbar --------------------------------------------------------------
@ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            HStack(spacing: 10) {
                Button {
                    vm.selectedDate.addDays(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }

                Button {
                    showDatePicker = true
                } label: {
                    Text(navTitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }

                Button {
                    vm.selectedDate.addDays(+1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }

        ToolbarItem(placement: .navigationBarLeading) {
            // Streaks display
            StreaksView(
                currentStreak: $streakManager.currentStreak,
                longestStreak: $streakManager.longestStreak,
                streakAsset: $streakManager.streakAsset,
                isVisible: $onboarding.isStreakVisible
            )
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showDatePicker = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }

    // Height card for page 3
    var heightCard: some View {
        HStack(spacing: 16) {
            NavigationLink(destination: {
                // Retrieve preloaded height logs if available
                if let preloadedData = UserDefaults.standard.data(forKey: "preloadedHeightLogs"),
                   let response = try? JSONDecoder().decode(HeightLogsResponse.self, from: preloadedData) {
                    HeightDataView(initialAllLogs: response.logs)
                } else {
                    HeightDataView(initialAllLogs: [])
                }
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "ruler")
                            .foregroundColor(.purple)
                            .font(.system(size: 16))
                        Text("Height")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.purple)
                    }
                    Spacer()
                    if vm.height > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatHeight(vm.height))
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            if !heightUnit.isEmpty {
                                Text(heightUnit)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("No data")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
            }
            Spacer()
            Button(action: {
                vm.navigateToEditHeight = true
            }) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
            }
            .sheet(isPresented: $vm.navigateToEditHeight) {
                EditHeightView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("containerbg"))
        // .cornerRadius(12)
        .cornerRadius(24)
    }

    // Weight card for page 3
    var weightCard: some View {
        HStack(spacing: 16) {
            NavigationLink(destination: {
                // Retrieve preloaded weight logs if available
                if let preloadedData = UserDefaults.standard.data(forKey: "preloadedWeightLogs"),
                   let response = try? JSONDecoder().decode(WeightLogsResponse.self, from: preloadedData) {
                    WeightDataView(initialAllLogs: response.logs)
                } else {
                    WeightDataView(initialAllLogs: [])
                }
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass")
                            .foregroundColor(.purple)
                            .font(.system(size: 16))
                        Text("Weight")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.purple)
                    }
                    Spacer()
                    HStack(spacing: 0) {
                        Text(formatWeight(vm.weight))
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(" \(weightUnit)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Button(action: {
                vm.navigateToEditWeight = true
            }) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
            }
            .sheet(isPresented: $vm.navigateToEditWeight) {
                EditWeightView(onWeightSaved: {
                    // Navigate to WeightDataView after saving weight
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        vm.navigateToWeightData = true
                    }
                })
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("containerbg"))
        // .cornerRadius(12)
        .cornerRadius(24)
    }
}

private extension DashboardView {
    func primaryMuscleHighlights(for workout: TodayWorkout) -> [String] {
        var seen = Set<String>()
        let highlights: [String] = workout.exercises.compactMap { exercise -> String? in
            let normalized = exercise.exercise.bodyPart.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return nil }
            let titleCased = normalized.capitalized
            guard !seen.contains(titleCased) else { return nil }
            seen.insert(titleCased)
            return titleCased
        }

        if let split = currentTrainingSplit {
            switch split {
            case .fullBody:
                return ["Upper Body", "Lower Body", "Core"]
            case .upperLower:
                return ["Upper Body", "Lower Body"]
            case .pushPullLower:
                return ["Push", "Pull", "Lower Body"]
            case .bodyPart:
                return ["Chest", "Back", "Legs", "Shoulders", "Arms"]
            case .pushPull:
                return ["Push", "Pull"]
            case .fresh:
                break
            }
        }

        if highlights.isEmpty {
            return []
        }

        let prioritized: [String]
        if highlights.count > 3 {
            let lowerKeywords: Set<String> = ["legs", "hamstrings", "quads", "glutes", "calves", "lower body"]
            let hasLower = highlights.first { lowerKeywords.contains($0.lowercased()) }
            var trimmed = Array(highlights.prefix(3))
            if hasLower == nil,
               let lower = highlights.first(where: { lowerKeywords.contains($0.lowercased()) }) {
                trimmed[trimmed.count - 1] = lower
            }
            prioritized = trimmed
        } else {
            prioritized = highlights
        }

        return prioritized
    }

    @ViewBuilder
    func summaryChip(icon: String? = nil, text: String) -> some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    var cardBackgroundColor: Color {
        Color("sheetbg").opacity(0.94)
    }
    
    func formattedDurationLabel(for workout: TodayWorkout) -> String {
        let minutes: Int
        if let duration = workoutManager.sessionDuration?.minutes {
            minutes = duration
        } else if let preferred = userProfileService.activeWorkoutProfile?.preferredWorkoutDuration {
            minutes = preferred
        } else {
            minutes = workout.estimatedDuration
        }

        guard minutes > 0 else { return "--" }

        if minutes % 60 == 0 {
            return "\(minutes / 60)h"
        }

        if minutes > 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }

        return "\(minutes)m"
    }

    func workoutIconName(for workout: TodayWorkout) -> String {
        let title = workoutManager.todayWorkoutDisplayTitle.lowercased()
        if title.contains("upper") {
            return "figure.core.training"
        }
        if title.contains("lower") {
            return "figure.strengthtraining.functional"
        }
        switch currentTrainingSplit {
        case .upperLower:
            return "figure.highintensity.intervaltraining"
        case .fullBody:
            return "figure.mixed.cardio"
        case .pushPullLower:
            return "figure.strengthtraining.traditional"
        case .bodyPart:
            return "figure.strengthtraining.traditional"
        case .pushPull:
            return "figure.highintensity.intervaltraining"
        case .fresh:
            return "figure.strengthtraining.functional"
        case .none:
            return "figure.highintensity.intervaltraining"
        }
    }
    
    var currentTrainingSplit: TrainingSplitPreference? {
        if let raw = userProfileService.activeWorkoutProfile?.trainingSplit,
           let split = TrainingSplitPreference(rawValue: raw) {
            return split
        }
        return nil
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: -- Helpers
// ────────────────────────────────────────────────────────────────────────────

private extension DashboardView {
    /// Save today's workout to user's custom workouts
    func saveWorkoutToMyWorkouts(_ workout: TodayWorkout) async {
        guard let todayWorkout = workoutManager.todayWorkout else {
            return
        }

        do {
            _ = try await workoutManager.saveTodayWorkoutAsCustom()
            HapticFeedback.generate()
        } catch {
            print("Error saving workout: \(error.localizedDescription)")
        }
    }

    /// Generate shareable URL for workout
    func generateWorkoutShareURL(_ workout: TodayWorkout) -> URL {
        // Create deep link URL for the workout
        let workoutId = workout.id.uuidString
        let workoutTitle = workout.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "podsapp://workout?id=\(workoutId)&title=\(workoutTitle)"

        // If deep link creation fails, return a fallback URL
        if let url = URL(string: urlString) {
            return url
        } else {
            // Fallback to sharing as text
            return URL(string: "https://fitbod.me")!
        }
    }

    /// Initialise e-mail + first load
   
    func configureOnAppear() {
        isTabBarVisible.wrappedValue = true

        // ALWAYS ensure we're using the correct email from onboarding
        // This is critical for user switching scenarios
        if !onboarding.email.isEmpty {
            let currentEmail = onboarding.email
            
            // Force update the email in DayLogsViewModel if it's different
            if vm.email != currentEmail {
                print("🔄 DashboardView - Email changed from '\(vm.email)' to '\(currentEmail)' - updating DayLogsViewModel")
                vm.setEmail(currentEmail)
                
                // Clear existing logs since they belong to a different user
                vm.logs = []
                
                // Force reload logs for the new user
                vm.loadLogs(for: vm.selectedDate)
            } else if vm.email.isEmpty {
                print("🔄 DashboardView - Setting initial email '\(currentEmail)' in DayLogsViewModel")
                vm.setEmail(currentEmail)
            } else {
                // Email is already set correctly, but ensure nutrition goals are up-to-date
                print("🔄 DashboardView - Email already set, refreshing nutrition goals")
                vm.refreshNutritionGoals()
            }
            
            // Set up HealthKitViewModel connection
            vm.setHealthViewModel(healthViewModel)
            
            // Always update UserDefaults with the current user's email
            UserDefaults.standard.set(currentEmail, forKey: "userEmail")
            
            // Clear any cached preloaded data since it might belong to a different user
            UserDefaults.standard.removeObject(forKey: "preloadedWeightLogs")
            UserDefaults.standard.removeObject(forKey: "preloadedHeightLogs")
        } else {
            print("⚠️ DashboardView - No email available from onboarding")
            return
        }
        
        // Only load logs if the list is empty (to avoid duplicate loading)
        if vm.logs.isEmpty {
            vm.loadLogs(for: vm.selectedDate)
        }
        
        // Preload weight and height logs for the current user
        preloadHealthData()
    }
    
    /// Preload health data logs so they're available when navigating to detail views
    private func preloadHealthData() {
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            return
        }

        Task {
            await ProfileRepository.shared.refresh(force: false)
        }
        
        let weightKey = "preloadedWeightLogsTimestamp"
        if shouldFetchHealthCache(forKey: weightKey) {
            NetworkManagerTwo.shared.fetchWeightLogs(userEmail: email, limit: 1000, offset: 0) { result in
                switch result {
                case .success(let response):
                    if let encodedData = try? JSONEncoder().encode(response) {
                        UserDefaults.standard.set(encodedData, forKey: "preloadedWeightLogs")
                        UserDefaults.standard.set(Date(), forKey: weightKey)
                    }
                case .failure(let error):
                    print("Error preloading weight logs: \(error)")
                }
            }
        }

        let heightKey = "preloadedHeightLogsTimestamp"
        if shouldFetchHealthCache(forKey: heightKey) {
            NetworkManagerTwo.shared.fetchHeightLogs(userEmail: email, limit: 1000, offset: 0) { result in
                switch result {
                case .success(let response):
                    if let encodedData = try? JSONEncoder().encode(response) {
                        UserDefaults.standard.set(encodedData, forKey: "preloadedHeightLogs")
                        UserDefaults.standard.set(Date(), forKey: heightKey)
                    }
                case .failure(let error):
                    print("Error preloading height logs: \(error)")
                }
            }
        }
        
        // Refresh preloaded profile data when logs change
        refreshPreloadedProfileData()
    }

    /// Refresh preloaded profile data when logs change
    private func refreshPreloadedProfileData() {
        Task {
            await ProfileRepository.shared.refresh(force: false)
        }
    }

    private func shouldFetchHealthCache(forKey key: String, ttl: TimeInterval = 300) -> Bool {
        if let last = UserDefaults.standard.object(forKey: key) as? Date {
            return Date().timeIntervalSince(last) >= ttl
        }
        return true
    }
}

private extension Date {
    mutating func addDays(_ d: Int) {
        self = Calendar.current.date(byAdding: .day,
                                     value: d,
                                     to: self) ?? self
    }
}


struct DatePickerSheet: View {
    @Binding var date       : Date
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar picker
                DatePicker("Select a date",
                           selection: $date,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                
                Spacer()
                
                // Bottom tab bar with Today button
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack {
                        Spacer()
                        // Today button on the leading side
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                date = Date()
                            }
                        }) {
                            Text("Today")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.accentColor)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color("containerbg"))
                }
            }
            .navigationTitle("Choose Date")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}


// Animated progress bar component
struct ProgressBar: View {
    var width: CGFloat
    var delay: Double
    
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * width, height: 8, alignment: .leading)
                )
        }
        .frame(height: 8)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.6)) {
                    animate = true
                }
            }
        }
    }
}


struct LogRow: View {
    let log: CombinedLog
    var hideTimeLabel: Bool = false
    @State private var isHighlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: Meal icon, Name and time
            HStack {
                Image(systemName: mealTimeSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)

                Text(displayName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                    // .lineLimit(1)
                Spacer()
                if !hideTimeLabel, let timeLabel = getTimeLabel() {
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
                            .onAppear {
                            
                                if let food = log.food {
                                  
                                }
                                if let meal = log.meal {
                             
                                }
                            }
                        Text("cal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Show different info based on log type
                if log.type == .activity {
                    // Activity-specific info: Duration and Distance
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.blue)
                            Text(log.activity?.formattedDuration ?? "0 min")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.primary)
                        }

                        if let activity = log.activity, activity.isDistanceActivity, let distance = activity.formattedDistance {
                            HStack(spacing: 6) {
                                Image(systemName: "location")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.green)
                                Text(distance)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                } else if log.type == .workout {
                    // Workout-specific info: Duration and Exercises
                    HStack(spacing: 16) {
                        if let workout = log.workout, let _ = workout.durationMinutes {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.blue)
                                Text(workout.formattedDuration)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.primary)
                            }
                        }

                        if let workout = log.workout {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.green)
                                Text(workout.exercisesText)
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
            // Apply highlight animation for new (optimistic) logs
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
        guard let date = log.scheduledAt else { return nil }

        // Only show time if log is from today
        let calendar = Calendar.current
        guard calendar.isDateInToday(date) else { return nil }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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


// MARK: - Specialized Loading Cards

struct MacroGenerationCard: View {
    @EnvironmentObject var foodManager: FoodManager
    @State private var animateProgress = false
    @State private var animationTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "sparkle")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(foodManager.macroLoadingTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(foodManager.macroLoadingMessage.isEmpty ? "Processing..." : foodManager.macroLoadingMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                        .animation(.easeInOut, value: foodManager.macroLoadingMessage)
                }
                
                Spacer()
            }
            
            // Progress bars
            VStack(spacing: 12) {
                ContinuousProgressBar(isActive: foodManager.isGeneratingMacros, width: 0.9, delay: 0)
                ContinuousProgressBar(isActive: foodManager.isGeneratingMacros, width: 0.7, delay: 0.2)
                ContinuousProgressBar(isActive: foodManager.isGeneratingMacros, width: 0.8, delay: 0.4)
            }
  
        }
        .padding()
        .background(Color("containerbg"))
        // .cornerRadius(12)
        .cornerRadius(24)
    }
}

struct FoodGenerationCard: View {
    @EnvironmentObject var foodManager: FoodManager
    @State private var animateProgress = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Image thumbnail if scanning food
            if foodManager.isScanningFood, let image = foodManager.scannedImage {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 140)
                        .cornerRadius(10)
                        .clipped()
                    
                    // Dark overlay
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 90, height: 140)
                        .cornerRadius(10)
                    
                    // Progress indicator
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 4)
                            .frame(width: 40, height: 40)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(min(foodManager.uploadProgress, 0.99)))
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                        
                        // Percentage text
                        Text("\(Int(min(foodManager.uploadProgress, 0.99) * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(foodManager.loadingMessage.isEmpty ? "Generating food item..." : foodManager.loadingMessage)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.bottom, 4)
                
                VStack(spacing: 12) {
                    ProgressBar(width: animateProgress ? 0.9 : 0.3, delay: 0)
                    ProgressBar(width: animateProgress ? 0.7 : 0.5, delay: 0.2)
                    ProgressBar(width: animateProgress ? 0.8 : 0.4, delay: 0.4)
                }

                Text("We'll notify you when done!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
        .padding()
        .background(Color("containerbg"))
        // .cornerRadius(12)
        .cornerRadius(24)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Reset animation state
        animateProgress = false
        
        // Animate with delay
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            animateProgress = true
        }
    }
}

@ViewBuilder
func macroRow(left: (String, Double, String, Color),
                  right: (String, Double, String, Color)) -> some View {
    HStack(spacing: 0) {
        macroCell(title: left.0, value: left.1,
                  sf: left.2, colour: left.3)
        macroCell(title: right.0, value: right.1,
                  sf: right.2, colour: right.3)
    }
}

@ViewBuilder
func macroCell(title: String, value: Double,
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

// Use actual macro goals from DayLogsViewModel
private extension DashboardView {
    var proteinGoal: Double {
        return vm.proteinGoal
    }
    
    var carbsGoal: Double {
        return vm.carbsGoal
    }
    
    var fatGoal: Double {
        return vm.fatGoal
    }
}

private extension DashboardView {
    // Health summary card for page 2
    var healthSummaryCard: some View {
        VStack(spacing: 16) {
            // First row: Calories Burned and Water
            HStack(spacing: 0) {
                // Active Calories Burned from Apple Health
                healthMetricCell(
                    title: "Calories Burned",
                    value: Int(vm.totalCaloriesBurned), // Use combined total from ViewModel
                    unit: "",
                    systemImage: "flame.fill",
                    color: Color("brightOrange")
                )
                            // Water with add button
            waterMetricCell(
                title: "Water",
                value: totalWaterDisplayValue,
                unit: waterDisplayUnit.abbreviation,
                systemImage: "drop",
                color: .blue
            )
            }
            
            // Second row: Step Count and Step Distance
            HStack(spacing: 0) {
                // Step Count
                healthMetricCell(
                    title: "Steps",
                    value: Int(healthViewModel.stepCount),
                    unit: "",
                    systemImage: "figure.walk",
                    color: .green
                )
                
                            // Step Distance from HealthKit
            healthMetricCell(
                title: "Distance",
                value: String(format: "%.2f", healthViewModel.distance),
                unit: "mi",
                systemImage: "figure.walk.motion",
                color: .purple
            )
            }
        }
        .padding()
        .background(Color("containerbg"))
        // .cornerRadius(12)
        .cornerRadius(24)
    }

    /// Re‑usable metric cell used by healthSummaryCard
    func healthMetricCell(title: String, value: Any, unit: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: systemImage)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 16))
                let suffix = unit.isEmpty ? "" : " \(unit)"
                if let intValue = value as? Int {
                    Text("\(intValue)\(suffix)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                } else if let stringValue = value as? String {
                    Text("\(stringValue)\(suffix)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    /// Special metric cell for water with add button
    func waterMetricCell(title: String, value: Any, unit: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: systemImage)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 16))
                let suffix = unit.isEmpty ? "" : " \(unit)"
                if let intValue = value as? Int {
                    Text("\(intValue)\(suffix)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                } else if let stringValue = value as? String {
                    Text("\(stringValue)\(suffix)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                }
            }
            
            Spacer(minLength: 0)
            
            // Add water button
            Button(action: {
                showWaterLogSheet = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            .padding(.trailing, 4)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showWaterLogSheet) {
            LogWaterView()
                .onDisappear {
                    // Refresh logs data when sheet is dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        vm.loadLogs(for: vm.selectedDate)
                    }
                }
        }
    }
}

// New continuous progress bar component
struct ContinuousProgressBar: View {
    let isActive: Bool
    let width: CGFloat
    let delay: Double
    
    @State private var animationOffset: CGFloat = 0
    @State private var progressWidth: CGFloat = 0.3
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                // Progress bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progressWidth, height: 8)
                    .offset(x: animationOffset)
            }
        }
        .frame(height: 8)
        .onAppear {
            if isActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    startContinuousAnimation()
                }
            }
        }
        .onChange(of: isActive) { active in
            if active {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    startContinuousAnimation()
                }
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startContinuousAnimation() {
        guard isActive else { return }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            progressWidth = width
        }
    }
    
    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            progressWidth = 0.3
            animationOffset = 0
        }
    }
}

// Get total water intake from backend logs for the selected date
private extension DashboardView {
    func calculateWaterIntake() -> Double {
        // Sum up all water logs for the selected date
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: vm.selectedDate)
        
        return vm.waterLogs.compactMap { log in
            // Parse the date string and check if it matches the selected date
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let logDate = formatter.date(from: log.dateLogged) else { return nil }
            let logDay = calendar.startOfDay(for: logDate)
            
            // Only include logs from the selected date
            return calendar.isDate(logDay, inSameDayAs: selectedDay) ? log.waterOz : nil
        }.reduce(0, +)
    }
}

// MARK: - Dashboard Loading View (Shimmer Cards)
private struct DashboardLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startTime = Date()

    var body: some View {
        Group {
            if reduceMotion {
                // Accessible fallback
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.1)
                        .tint(.accentColor)
                    Text("Loading your logs…")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { _ in
                        skeletonCard
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .onAppear { startTime = Date() }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Loading your logs")
        .accessibilityHint("Please wait while recent entries load")
    }

    private var skeletonCard: some View {
        let skeleton = HStack(spacing: 16) {
            // Icon
            RoundedRectangle(cornerRadius: 10)
                .fill(skeletonBase)
                .frame(width: 44, height: 44)

            // Content
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(skeletonBase)
                    .frame(height: 16)

                HStack {
                    HStack(spacing: 8) {
                        Circle().fill(skeletonBase).frame(width: 14, height: 14)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(skeletonBase)
                            .frame(width: 56, height: 12)
                    }
                    Spacer()
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 6).fill(skeletonBase).frame(width: 46, height: 12)
                        RoundedRectangle(cornerRadius: 6).fill(skeletonBase).frame(width: 46, height: 12)
                        RoundedRectangle(cornerRadius: 6).fill(skeletonBase).frame(width: 38, height: 12)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color("containerbg"))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05), radius: 8, x: 0, y: 3)
        )

        // Apply shimmer by masking the highlight over the skeleton shapes
        return skeleton
            .overlay(
                CALShimmerOverlay(
                    highlightColor: (colorScheme == .dark
                                      ? UIColor(white: 1.0, alpha: 0.15)
                                      : UIColor(white: 1.0, alpha: 0.15)),
                    duration: 1.6
                )
            )
            .mask(skeleton)
    }

    private var skeletonBase: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    // Replaced by CALayer-driven ShimmerView to ensure reliability inside Lists
}

private struct ScheduledLogPreviewCard: View {
    let preview: ScheduledLogPreview
    let isProcessing: Bool
    let onAccept: () -> Void
    let onSkip: () -> Void

    init(
        preview: ScheduledLogPreview,
        isProcessing: Bool = false,
        onAccept: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.preview = preview
        self.isProcessing = isProcessing
        self.onAccept = onAccept
        self.onSkip = onSkip
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: mealTimeSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text(preview.summary.title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)
                }

                Spacer()

                if isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                } else {
                    HStack(spacing: 12) {
                        Button(action: onSkip) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Skip")

                        Button(action: onAccept) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Log")
                    }
                }
            }

            HStack(alignment: .bottom) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)

                    HStack(alignment: .bottom, spacing: 1) {
                        Text("\(caloriesText)")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("cal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 24) {
                    MacroColumn(title: "Protein", valueText: macroText(preview.summary.protein))
                    MacroColumn(title: "Carbs", valueText: macroText(preview.summary.carbs))
                    MacroColumn(title: "Fat", valueText: macroText(preview.summary.fat))
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
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var caloriesText: Int {
        Int((preview.summary.calories ?? 0).rounded())
    }

    private var mealTimeSymbol: String {
        switch preview.displayMealType.lowercased() {
        case "breakfast":
            return "sunrise.fill"
        case "lunch":
            return "sun.max.fill"
        case "dinner":
            return "moon.fill"
        case "snack", "snacks":
            return "popcorn.fill"
        default:
            return "popcorn.fill"
        }
    }

    private func macroText(_ value: Double?) -> String {
        guard let value else { return "–" }
        return "\(Int(value.rounded()))g"
    }

    private struct MacroColumn: View {
        let title: String
        let valueText: String

        var body: some View {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                Text(valueText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Workout Log Card (displayed after workout completion)
struct WorkoutLogCard: View {
    let summary: CompletedWorkoutSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 48, height: 48)
                    .background(Color("primarybg"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.workout.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text("Workout completed")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                // CALORIES FIRST - Orange flame.fill
                workoutMetricChip(icon: "flame.fill",
                                 text: "\(summary.stats.estimatedCalories) cal",
                                 color: Color("brightOrange"))

                // DURATION - Blue clock
                workoutMetricChip(icon: "clock",
                                 text: formattedDuration(summary.stats.duration),
                                 color: .blue)

                // EXERCISES - Accent color
                let exerciseCount = summary.exerciseBreakdown.count
                workoutMetricChip(icon: "list.bullet",
                                 text: "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")",
                                 color: .accentColor)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("containerbg"))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    private func workoutMetricChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color("primarybg"))
        .clipShape(Capsule())
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        if totalSeconds < 60 {
            return "\(max(totalSeconds, 0))s"
        }

        let totalMinutes = totalSeconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}
