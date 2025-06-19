import SwiftUI
import HealthKit

struct DashboardView: View {

    // ─── Shared app-wide state ──────────────────────────────────────────────
    @EnvironmentObject private var onboarding: OnboardingViewModel
    @EnvironmentObject private var foodMgr   : FoodManager
    @Environment(\.isTabBarVisible) private var isTabBarVisible
    @EnvironmentObject var vm: DayLogsViewModel
    
    // ─── Health data state ───────────────────────────────────────────────────
    @StateObject private var healthViewModel = HealthKitViewModel()

    // ─── Local UI state ─────────────────────────────────────────────────────
    @State private var showDatePicker = false
    @State private var showWaterLogSheet = false


    @State private var showLogFlowSheet = false
    @State private var selectedFoodLogId: String? = nil
    
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

    // ─── Quick helpers ──────────────────────────────────────────────────────
    private var isToday     : Bool { Calendar.current.isDateInToday(vm.selectedDate) }
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


    private var navTitle: String {
        if isToday      { return "Today" }
        if isYesterday  { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: vm.selectedDate)
    }

    // ────────────────────────────────────────────────────────────────────────
    // MARK: -- View body
    // ────────────────────────────────────────────────────────────────────────

    var body: some View {
        NavigationView {
            ZStack {
                Color("iosbg2").ignoresSafeArea()

                // Single List containing everything for smooth scrolling
                List {
                    // Header content as list sections
                    Section {
                        nutritionSummaryCard
                                 .padding(.horizontal, -16) 
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        if foodMgr.isGeneratingMacros {
                            MacroGenerationCard()
                                .padding(.horizontal)
                                .transition(.opacity)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        if foodMgr.isAnalyzingImage {
                            ImageAnalysisCard()
                                .padding(.horizontal)
                                .transition(.opacity)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        if foodMgr.isScanningBarcode {
                            BarcodeAnalysisCard()
                                .padding(.horizontal)
                                .transition(.opacity)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
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
                    } else if vm.logs.isEmpty {
                        Section {
                            emptyState
                                .padding(.horizontal)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } else {
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
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .font(.system(size: 20))
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
                                // Delete action with trash icon
                                Button(action: {
                                    deleteLogItem(log: log)
                                }) {
                                    Image(systemName: "trash.fill")
                                }
                                .tint(.red)
                            }
                            .id("\(log.id)_\(foodMgr.savedLogIds.count)")
                        }
                        .onDelete { indexSet in
                            deleteLogItems(at: indexSet)
                        }
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
            .padding(.bottom, 55)
        }
        .zIndex(1)
        .transition(.opacity)
        .animation(.spring(), value: foodMgr.showAIGenerationSuccess)
      }
      else if foodMgr.showLogSuccess, let item = foodMgr.lastLoggedItem {
        VStack {
          Spacer()
          BottomPopup(message: "\(item.name) logged")
            .padding(.bottom, 55)
        }
        .zIndex(1)
        .transition(.opacity)
        .animation(.spring(), value: foodMgr.showLogSuccess)
      }
      else if foodMgr.showSavedMealToast {
        VStack {
          Spacer()
          BottomPopup(message: "Saved Meal")
            .padding(.bottom, 55)
        }
        .zIndex(1)
        .transition(.opacity)
        .animation(.spring(), value: foodMgr.showSavedMealToast)
      }
      else if foodMgr.showUnsavedMealToast {
        VStack {
          Spacer()
          BottomPopup(message: "Unsaved Meal")
            .padding(.bottom, 55)
        }
        .zIndex(1)
        .transition(.opacity)
        .animation(.spring(), value: foodMgr.showUnsavedMealToast)
      }
    }
            
                 
            
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(date: $vm.selectedDate,
                                isPresented: $showDatePicker)
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
                
                // CRITICAL FIX: Only show log flow if onboarding is completed
                // This prevents modal conflicts when both onboarding and log flow try to present
                if !UserDefaults.standard.hasSeenLogFlow && onboarding.onboardingCompleted && !onboarding.isShowingOnboarding {
                    print("🔍 DashboardView onAppear - showing log flow (user hasn't completed it and onboarding is done)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showLogFlowSheet = true
                    }
                } else if !UserDefaults.standard.hasSeenLogFlow {
                    print("🔍 DashboardView onAppear - log flow needed but onboarding in progress, deferring log flow")
                } else {
                    print("🔍 DashboardView onAppear - user has completed log flow, not showing")
                }
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
                vm.loadLogs(for: newDate)   // fetch fresh ones
                
                // Update health data for the selected date
                healthViewModel.reloadHealthData(for: newDate)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WaterLoggedNotification"))) { _ in
                print("💧 DashboardView received WaterLoggedNotification - refreshing logs for \(vm.selectedDate)")
                // Refresh logs data when water is logged (for current selected date)
                vm.loadLogs(for: vm.selectedDate)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FoodLogUpdated"))) { notification in
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HealthDataAvailableNotification"))) { _ in
                // Refresh health data when permissions are granted
                healthViewModel.reloadHealthData(for: vm.selectedDate)
            }
            .onChange(of: onboarding.onboardingCompleted) { _, isCompleted in
                // CRITICAL: Show log flow after onboarding is completed (if user hasn't seen it yet)
                if isCompleted && !UserDefaults.standard.hasSeenLogFlow && !showLogFlowSheet {
                    print("🔍 DashboardView - Onboarding completed, now showing log flow")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Longer delay to ensure onboarding UI is dismissed
                        showLogFlowSheet = true
                    }
                }
            }
            .sheet(isPresented: $showLogFlowSheet) {
                LogFlowContainerView()
            }

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
            }
        }
        
        // Actually delete the items
        for log in logsToDelete {
            switch log.type {
            case .food:
                if let foodLogId = log.foodLogId {
                    foodMgr.deleteFoodLog(id: foodLogId) { result in
                        switch result {
                        case .success:
                            print("✅ Successfully deleted food log ID: \(foodLogId)")
                            // Remove from local logs after successful deletion
                            DispatchQueue.main.async {
                                vm.removeLog(log)
                            }
                        case .failure(let error):
                            print("❌ Failed to delete food log: \(error)")
                        }
                    }
                }
            case .meal:
                if let mealLogId = log.mealLogId {
                    foodMgr.deleteMealLog(id: mealLogId) { result in
                        switch result {
                        case .success:
                            print("✅ Successfully deleted meal log ID: \(mealLogId)")
                            // Remove from local logs after successful deletion
                            DispatchQueue.main.async {
                                vm.removeLog(log)
                            }
                        case .failure(let error):
                            print("❌ Failed to delete meal log: \(error)")
                        }
                    }
                }
            case .recipe:
                if let recipeLogId = log.recipeLogId {
                    // Note: Implement recipe log deletion if needed in FoodManager
                    print("📝 Recipe log deletion not yet implemented for ID: \(recipeLogId)")
                }
            }
        }
    }
    
    // Save function for swipe-to-save functionality
    private func saveMealAction(log: CombinedLog) {
        print("💾 Saving meal/food log: \(log.id)")
        
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
        }
    }
    
    // Delete function for individual log items
    private func deleteLogItem(log: CombinedLog) {
        print("🗑️ Deleting individual log item: \(log.id)")
        
        switch log.type {
        case .food:
            guard let foodLogId = log.foodLogId else {
                print("❌ No food log ID available")
                return
            }
            
            HapticFeedback.generate()
            
            foodMgr.deleteFoodLog(id: foodLogId) { result in
                switch result {
                case .success:
                    print("✅ Successfully deleted food log ID: \(foodLogId)")
                    // Remove from local logs after successful deletion
                    DispatchQueue.main.async {
                        vm.removeLog(log)
                    }
                case .failure(let error):
                    print("❌ Failed to delete food log: \(error)")
                }
            }
            
        case .meal:
            guard let mealLogId = log.mealLogId else {
                print("❌ No meal log ID available")
                return
            }
            
            HapticFeedback.generate()
            
            foodMgr.deleteMealLog(id: mealLogId) { result in
                switch result {
                case .success:
                    print("✅ Successfully deleted meal log ID: \(mealLogId)")
                    // Remove from local logs after successful deletion
                    DispatchQueue.main.async {
                        vm.removeLog(log)
                    }
                case .failure(let error):
                    print("❌ Failed to delete meal log: \(error)")
                }
            }
            
        case .recipe:
            guard let recipeLogId = log.recipeLogId else {
                print("❌ No recipe log ID available")
                return
            }
            
            HapticFeedback.generate()
            print("📝 Recipe log deletion not yet implemented for ID: \(recipeLogId)")
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

                Circle()
                    .trim(from: 0,
                          to: CGFloat(1 - (remainingCal / calorieGoal)))
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
        .background(Color("iosnp"))
        .cornerRadius(12)
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
        .background(Color("iosnp"))
        .cornerRadius(12)
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
        .background(Color("iosnp"))
        .cornerRadius(12)
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
        .background(Color("iosnp"))
        .cornerRadius(12)
    }

    // Sleep card for page 3
    var sleepCard: some View {
        // Debug print
        let _ = print("Sleep data: \(healthViewModel.sleepHours) hours, \(healthViewModel.sleepMinutes) minutes")
        
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
        .background(Color("iosnp"))
        .cornerRadius(12)
    }

    // ② Loading / error / empty / list --------------------------------------
    var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Loading logs…").foregroundColor(.secondary)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
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
                    if !isToday {
                        vm.selectedDate.addDays(+1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isToday ? .gray : .primary)
                }
                .disabled(isToday)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                // Debug button to reset all flows (remove in production)
                // Button {
                //     UserDefaults.standard.resetAllOnboardingFlows()
                //     print("🔄 All flows reset!")
                //     print("🔄 hasSeenLogFlow: \(UserDefaults.standard.hasSeenLogFlow)")
                //     print("🔄 hasSeenAllFlow: \(UserDefaults.standard.hasSeenAllFlow)")
                //     print("🔄 hasSeenMealFlow: \(UserDefaults.standard.hasSeenMealFlow)")
                //     print("🔄 hasSeenFoodFlow: \(UserDefaults.standard.hasSeenFoodFlow)")
                //     print("🔄 hasSeenScanFlow: \(UserDefaults.standard.hasSeenScanFlow)")
                // } label: {
                //     Image(systemName: "arrow.clockwise")
                //         .font(.system(size: 16, weight: .medium))
                //         .foregroundColor(.red)
                // }

                Button {
                    showDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
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
                        let totalInches = vm.height / 2.54
                        let feet = Int(totalInches / 12)
                        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
                        Text("\(feet)' \(inches)\"")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
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
        .background(Color("iosnp"))
        .cornerRadius(12)
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
                    let weightInLbs = Int(vm.weight * 2.20462)
                    HStack(spacing: 0) {
                        Text("\(weightInLbs)")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(" lb")
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
                EditWeightView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
    }
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: -- Helpers
// ────────────────────────────────────────────────────────────────────────────

private extension DashboardView {
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
            }
            
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
        
        // Preload weight logs
        NetworkManagerTwo.shared.fetchWeightLogs(userEmail: email, limit: 1000, offset: 0) { result in
            switch result {
            case .success(let response):
                // Store logs in UserDefaults for access in WeightDataView
                if let encodedData = try? JSONEncoder().encode(response) {
                    UserDefaults.standard.set(encodedData, forKey: "preloadedWeightLogs")
                }
            case .failure(let error):
                print("Error preloading weight logs: \(error)")
            }
        }
        
        // Preload height logs
        NetworkManagerTwo.shared.fetchHeightLogs(userEmail: email, limit: 1000, offset: 0) { result in
            switch result {
            case .success(let response):
                // Store logs in UserDefaults for access in HeightDataView
                if let encodedData = try? JSONEncoder().encode(response) {
                    UserDefaults.standard.set(encodedData, forKey: "preloadedHeightLogs")
                }
            case .failure(let error):
                print("Error preloading height logs: \(error)")
            }
        }
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
                           in: ...Date(),
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
                    .background(Color(.systemBackground))
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
                if let timeLabel = getTimeLabel() {
                    Text(timeLabel)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(.systemGray2))
                    }
            }
            Spacer(minLength: 0)
            // Bottom row: Calories (left) and Macros (right)
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
        .frame(minHeight: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill( Color("iosnp"))
                .shadow(color: Color(.black).opacity(0.04), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor.opacity(isHighlighted ? 0.5 : 0), lineWidth: 2)
                )
        )
        .cornerRadius(14)
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
        }
    }
    
    private var mealTimeSymbol: String {
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
    private func getTimeLabel() -> String? {
        guard let date = log.scheduledAt else { return nil }
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
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generating Macros with AI")
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
        .background(Color("iosnp"))
        .cornerRadius(12)
    }
}

struct ImageAnalysisCard: View {
    @EnvironmentObject var foodManager: FoodManager
    @State private var animateProgress = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analyzing Image")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(foodManager.imageAnalysisMessage.isEmpty ? "Processing image..." : foodManager.imageAnalysisMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                        .animation(.easeInOut, value: foodManager.imageAnalysisMessage)
                }
                
                Spacer()
                
                // Show image thumbnail if available
                if let scannedImage = foodManager.scannedImage {
                    Image(uiImage: scannedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            // Progress bars
            VStack(spacing: 12) {
                ContinuousProgressBar(isActive: foodManager.isAnalyzingImage, width: 0.9, delay: 0)
                ContinuousProgressBar(isActive: foodManager.isAnalyzingImage, width: 0.7, delay: 0.2)
                ContinuousProgressBar(isActive: foodManager.isAnalyzingImage, width: 0.8, delay: 0.4)
            }
            
        
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
    }
}

struct BarcodeAnalysisCard: View {
    @EnvironmentObject var foodManager: FoodManager
    @State private var animateProgress = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scanning Barcode")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(foodManager.barcodeLoadingMessage.isEmpty ? "Looking up barcode..." : foodManager.barcodeLoadingMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                        .animation(.easeInOut, value: foodManager.barcodeLoadingMessage)
                }
                
                Spacer()
            }
            
            // Progress bars
            VStack(spacing: 12) {
                ContinuousProgressBar(isActive: foodManager.isScanningBarcode, width: 0.9, delay: 0)
                ContinuousProgressBar(isActive: foodManager.isScanningBarcode, width: 0.7, delay: 0.2)
                ContinuousProgressBar(isActive: foodManager.isScanningBarcode, width: 0.8, delay: 0.4)
            }

        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
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
                // Total Calories Burned (Active + Basal)
                healthMetricCell(
                    title: "Total Burn",
                    value: Int(healthViewModel.totalEnergyBurned),
                    unit: "",
                    systemImage: "flame.fill",
                    color: Color("brightOrange")
                )
                            // Water with add button
            waterMetricCell(
                title: "Water",
                value: String(format: "%.0f", calculateWaterIntake()),
                unit: "oz",
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
        .background(Color("iosnp"))
        .cornerRadius(12)
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
                if let intValue = value as? Int {
                    Text("\(intValue)\(unit)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                } else if let stringValue = value as? String {
                    Text("\(stringValue)\(unit)")
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
                if let intValue = value as? Int {
                    Text("\(intValue)\(unit)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                } else if let stringValue = value as? String {
                    Text("\(stringValue)\(unit)")
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

