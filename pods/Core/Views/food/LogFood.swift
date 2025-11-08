import SwiftUI
import Combine

struct LogFood: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var proFeatureGate: ProFeatureGate
    @Binding var selectedMeal: String
    @Binding var selectedTab: Int
    
    @State private var searchText = ""
    @State private var selectedFoodTab: FoodTab = .all
    @State private var searchResults: [Food] = []
    @State private var isSearching = false
    // We're handling per‑row checkmarks in the FoodRow subview.
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @Binding var path: NavigationPath
    @FocusState private var isSearchFieldFocused: Bool
    @State private var activateSearch = false
    
    // Keyboard height tracking
    @State private var keyboardHeight: CGFloat = 0
    @State private var safeAreaInset: CGFloat = 0
    
    var mode: LogFoodMode = .logFood 
    @Binding var selectedFoods: [Food]  

    
    // Add callback that will be called when an item is added
    var onItemAdded: ((Food) -> Void)?
    @State private var showQuickLogSheet = false

    // Create Food sheets
    @State private var showCreateFoodWithVoice = false
    @State private var showCreateFoodWithScan = false
    @State private var showConfirmFoodView = false
    
    // Nutrition label name input
    @State private var nutritionProductName = ""
    @State private var isProSearchResult = false
    @State private var searchProgressTimer: Timer?

    private var currentUserEmail: String? {
        let email = UserDefaults.standard.string(forKey: "userEmail")
        return email?.isEmpty == false ? email : nil
    }
    
    enum FoodTab: Hashable {
        case all, meals, foods, savedMeals
        
        var title: String {
            switch self {
            case .all: return "All"
            case .meals: return "My Recipes"
            case .foods: return "My Foods"
            case .savedMeals: return "Saved Meals"
            }
        }
        
        var searchPrompt: String {
            switch self {
            case .all:
                return "Describe what you ate"
            case .meals:
                return "Describe your recipe"
            case .foods:
                return "Describe your food"
            case .savedMeals:
                return "Search saved meals"
            }
        }
    }
    
    let foodTabs: [FoodTab] = [.all, .meals, .foods, .savedMeals]
    private let initialTabSelection: FoodTab?
    @State private var hasAppliedInitialTab = false
    
    // IMPORTANT: Keep init argument order exactly the same
    init(selectedTab: Binding<Int>, 
         selectedMeal: Binding<String>, 
         path: Binding<NavigationPath>,
         mode: LogFoodMode = .logFood,
         selectedFoods: Binding<[Food]>,
         onItemAdded: ((Food) -> Void)? = nil,
         initialTab: String? = nil) 
    {
        _selectedTab = selectedTab
        _path = path
        _selectedMeal = selectedMeal
        self.mode = mode
        _selectedFoods = selectedFoods
        self.onItemAdded = onItemAdded
        
        // Set initial tab if provided
        if let tabString = initialTab {
            switch tabString {
            case "savedMeals":
                initialTabSelection = .savedMeals
                _selectedFoodTab = State(initialValue: .savedMeals)
            case "meals":
                initialTabSelection = .meals
                _selectedFoodTab = State(initialValue: .meals)
            case "foods":
                initialTabSelection = .foods
                _selectedFoodTab = State(initialValue: .foods)
            default:
                initialTabSelection = .all
                _selectedFoodTab = State(initialValue: .all)
            }
        } else {
            initialTabSelection = nil
            _selectedFoodTab = State(initialValue: .all)
        }
    }
    
    private func applyInitialTabIfNeeded() {
        guard !hasAppliedInitialTab, let initialTabSelection else { return }
        hasAppliedInitialTab = true
        selectedFoodTab = initialTabSelection
    }
    
    var body: some View {
        coreContent
            .modifier(SearchModifiers())
            .modifier(NavigationModifiers(mode: mode, selectedTab: $selectedTab, dismiss: dismiss))
            .modifier(SheetModifiers(
                showQuickLogSheet: $showQuickLogSheet,
                showConfirmFoodView: $showConfirmFoodView,
                showCreateFoodWithVoice: $showCreateFoodWithVoice,
                showCreateFoodWithScan: $showCreateFoodWithScan,
                foodManager: foodManager
            ))
            .modifier(LifecycleModifiers(
                selectedFoodTab: selectedFoodTab,
                safeAreaInset: $safeAreaInset,
                keyboardHeight: $keyboardHeight,
                foodManager: foodManager
            ))
            .onAppear { applyInitialTabIfNeeded() }
            .alert("Product Name Required", isPresented: $foodManager.showNutritionNameInputForCreation) {
                TextField("Enter product name", text: $nutritionProductName)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    foodManager.cancelNutritionNameInputForCreation()
                }
                Button("Save") {
                    if !nutritionProductName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Create food with user-provided name using the backend to get health analysis
                        foodManager.createNutritionLabelFoodForCreation(nutritionProductName) { result in
                            DispatchQueue.main.async {
                                nutritionProductName = "" // Reset for next time
                                switch result {
                                case .success(let food):
                                    print("✅ Successfully built nutrition label food data for creation")
                                    
                                    // Check preference for food label scan
                                    let foodLabelPreviewEnabled = UserDefaults.standard.object(forKey: "scanPreview_foodLabel") as? Bool ?? true
                                    
                                    if foodLabelPreviewEnabled {
                                        // Show confirmation sheet by setting lastGeneratedFood
                                        print("🏷️ Food label preview enabled - showing confirmation")
                                        self.foodManager.lastGeneratedFood = food
                                        // UNIFIED: Food data is ready - can reset to inactive
                                        self.foodManager.foodScanningState = .inactive
                                    } else {
                                        // Create food directly without confirmation
                                        print("🏷️ Food label preview disabled - creating food directly")
                                        
                                        self.foodManager.createManualFood(food: food, showPreview: false) { result in
                                            DispatchQueue.main.async {
                                                switch result {
                                                case .success(let savedFood):
                                                    print("✅ Successfully created food from nutrition label with name: \(savedFood.displayName)")
                                                    
                                                    // Track as recently added
                                                    self.foodManager.trackRecentlyAdded(foodId: savedFood.fdcId)
                                                    
                                                    // Show success toast
                                                    self.foodManager.showFoodGenerationSuccess = true
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                        self.foodManager.showFoodGenerationSuccess = false
                                                    }
                                                    
                                                case .failure(let error):
                                                    print("❌ Failed to create food from nutrition label with name: \(error)")
                                                }
                                            }
                                        }
                                    }
                                    
                                case .failure(let error):
                                    print("❌ Failed to build nutrition label food data: \(error)")
                                }
                            }
                        }
                    }
                }
                .disabled(nutritionProductName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("We couldn't find the product name on the nutrition label. Please enter it manually.")
            }
            .alert(foodManager.scanFailureType, isPresented: $foodManager.showScanFailureAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(foodManager.scanFailureMessage)
            }
            .onSubmit(of: .search) {
                submitSearch()
            }
            .onChange(of: searchText) { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    searchResults = []
                    isProSearchResult = false
                    resetSearchProgress()
                }
            }
            .onChange(of: foodManager.lastGeneratedFood) { newFood in
                if newFood != nil && !foodManager.showNutritionNameInput && !foodManager.showNutritionNameInputForCreation {
                    showConfirmFoodView = true
                }
            }
            .onDisappear {
                resetSearchProgress()
            }
    }
    
    private var coreContent: some View {
        ZStack(alignment: .bottom) {
            // Add background color for the entire view
            Color("iosbg2").edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Fixed non-transparent header
                VStack(spacing: 0) {
                    tabHeaderView
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
                
               .background(Color("iosbg2"))
               .zIndex(1) // Keep header on top
                
                // Main content
                mainContentView
                Spacer()
            }
            
            toastMessages
        }
        .searchable(
            text: $searchText,
            placement: .automatic,
            prompt: selectedFoodTab.searchPrompt
        )
        .focused($isSearchFieldFocused)
        .alert("Something went wrong", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .background(
            SearchActivator(isActivated: $activateSearch)
        )
    }
    
    // MARK: - Subviews
    
    private var tabHeaderView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(foodTabs, id: \.self) { tab in
                    TabButton(tab: tab, selectedTab: $selectedFoodTab)
                    // Removed .onTapGesture - TabButton's internal Button action handles the tap
                    // The .onChange modifier in the main body will handle showing the correct flow
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 10)
    }
    
    private var mainContentView: some View {
        Group {
            if selectedFoodTab == .all || selectedFoodTab == .foods {
                FoodListView(
                    searchResults: searchResults,
                    isSearching: isSearching,
                    searchText: searchText,
                    selectedFoodTab: selectedFoodTab,
                    isProSearchResult: isProSearchResult,
                    selectedMeal: $selectedMeal,
                    mode: mode,
                    selectedFoods: $selectedFoods,
                    path: $path,
                    showQuickLogSheet: $showQuickLogSheet,
                    showCreateFoodWithVoice: $showCreateFoodWithVoice,
                    showCreateFoodWithScan: $showCreateFoodWithScan
                )
            } else {
                switch selectedFoodTab {
                case .meals:
                    MealListView(
                        selectedMeal: $selectedMeal,
                        mode: mode,
                        selectedFoods: $selectedFoods,
                        path: $path,
                        searchText: searchText,
                        onItemAdded: onItemAdded
                    )
                case .savedMeals:
                    SavedMealListView(
                        selectedMeal: $selectedMeal,
                        mode: mode,
                        selectedFoods: $selectedFoods,
                        path: $path,
                        searchText: searchText,
                        onItemAdded: onItemAdded
                    )
                default:
                    EmptyView()
                }
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            if mode != .addToMeal && mode != .addToRecipe {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        selectedTab = 0
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            
            ToolbarItem(placement: .principal) {
                // MealPickerMenu(selectedMeal: $selectedMeal)
                Text("Log Food")
                    .font(.headline)
            }
        }
    }


    
    private var toastMessages: some View {
        ZStack {
            // AI Generation Success Toast
            if foodManager.showToast {
                VStack {
                    Spacer()
                    BottomPopup(message: "Food logged")
                        .padding(.bottom, max(safeAreaInset + keyboardHeight, 22))
                }
                .zIndex(100)
                .transition(.opacity)
                .animation(.spring(), value: foodManager.showToast)
            }
            
            // Meal Created Toast
            if foodManager.showMealToast {
                VStack {
                    Spacer()
                    BottomPopup(message: "Recipe created")
                        .padding(.bottom, max(safeAreaInset + keyboardHeight, 22))
                }
                .zIndex(100)
                .transition(.opacity)
                .animation(.spring(), value: foodManager.showMealToast)
            }
            
            // Meal Logged Toast
            if foodManager.showMealLoggedToast {
                VStack {
                    Spacer()
                    BottomPopup(message: "Recipe logged")
                        .padding(.bottom, max(safeAreaInset + keyboardHeight, 22))
                }
                .zIndex(100)
                .transition(.opacity)
                .animation(.spring(), value: foodManager.showMealLoggedToast)
            }
            
            // Recipe Logged Toast
            if foodManager.showRecipeLoggedToast {
                VStack {
                    Spacer()
                    BottomPopup(message: "Recipe logged")
                        .padding(.bottom, max(safeAreaInset + keyboardHeight, 22))
                }
                .zIndex(100)
                .transition(.opacity)
                .animation(.spring(), value: foodManager.showRecipeLoggedToast)
            }
        }
    }
    
    // MARK: - Search
    private func submitSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isProSearchResult = false
            return
        }
        isProSearchResult = false
        Task { await searchFoods(query: trimmed) }
    }
    
    @MainActor
    private func searchFoods(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            resetSearchProgress()
            return
        }
        startSearchProgress()
        isSearching = true
        defer { isSearching = false }
        
        if proFeatureGate.hasActiveSubscription(),
           let email = currentUserEmail {
            do {
                let response = try await FoodService.shared.searchFoodsPro(query: query,
                                                                            userEmail: email)
                searchResults = response.foods
                isProSearchResult = true
                withAnimation(.easeInOut(duration: 0.3)) {
                    foodManager.animatedProgress = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    foodManager.animatedProgress = 0.0
                }
                stopSearchProgressTimer()
                return
            } catch {
                print("Pro search error:", error)
                isProSearchResult = false
            }
        }
        
        do {
            let response = try await FoodService.shared.searchFoods(query: query)
            searchResults = response.foods
            isProSearchResult = false
            withAnimation(.easeInOut(duration: 0.3)) {
                foodManager.animatedProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                foodManager.animatedProgress = 0.0
            }
            stopSearchProgressTimer()
        } catch {
            print("Search error:", error)
            searchResults = []
            isProSearchResult = false
            errorMessage = "We couldn't find results. Please try again."
            showErrorAlert = true
            foodManager.animatedProgress = 0.0
            stopSearchProgressTimer()
        }
    }

    private func startSearchProgress() {
        stopSearchProgressTimer()
        foodManager.animatedProgress = 0.05
        searchProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { timer in
            let next = min(self.foodManager.animatedProgress + 0.1, 0.85)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.foodManager.animatedProgress = next
            }
            if next >= 0.85 {
                timer.invalidate()
                self.searchProgressTimer = nil
            }
        }
    }
    
    private func stopSearchProgressTimer() {
        searchProgressTimer?.invalidate()
        searchProgressTimer = nil
    }
    
    private func resetSearchProgress() {
        stopSearchProgressTimer()
        foodManager.animatedProgress = 0.0
    }
}

// MARK: - Supporting Views

private struct TabButton: View {
    let tab: LogFood.FoodTab
    @Binding var selectedTab: LogFood.FoodTab
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                selectedTab = tab
            }
        }) {
            Text(tab.title)
                .font(.system(size: 15))
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selectedTab == tab 
                              ? (colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.06))
                              : Color.clear)
                )
                .foregroundColor(selectedTab == tab ? .primary : Color.gray.opacity(0.8))
        }
      
        .buttonStyle(PlainButtonStyle())
    }
}

private struct MealPickerMenu: View {
    @Binding var selectedMeal: String
    
    var body: some View {
        Menu {
            Button("Breakfast") { selectedMeal = "Breakfast" }
            Button("Lunch") { selectedMeal = "Lunch" }
            Button("Dinner") { selectedMeal = "Dinner" }
        } label: {
            HStack(spacing: 4) {
                Text(selectedMeal)
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
            }
        }
    }
}

private struct FoodListView: View {
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    let searchResults: [Food]
    let isSearching: Bool
    let searchText: String
    let selectedFoodTab: LogFood.FoodTab
    let isProSearchResult: Bool
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    @Binding var showQuickLogSheet: Bool
    @Binding var showCreateFoodWithVoice: Bool
    @Binding var showCreateFoodWithScan: Bool
    
    // UNIFIED: Legacy states removed - now using foodManager.foodScanningState
    @State private var isGeneratingMacros = false  // TODO: Can be removed when macro generation uses unified state
    @State private var showAIErrorAlert = false
    @State private var aiErrorMessage = ""
    @State private var showFoodCreatedToast = false
    @State private var generatedFood: Food? = nil
    // Add state to show CreateFoodView
    @State private var showCreateFoodView = false
    
    var onItemAdded: ((Food) -> Void)?
    
    @State private var isShowingMinimumLoader = false
    
    private var trimmedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var recentLogMatches: [CombinedLog] {
        guard selectedFoodTab == .all else { return [] }
        let query = trimmedSearchQuery.lowercased()
        guard !query.isEmpty else { return [] }
        
        var seen = Set<String>()
        
        return foodManager.combinedLogs.compactMap { log in
            guard log.type == .food, let foodItem = log.food else { return nil }
            
            let candidates = [
                foodItem.displayName,
                foodItem.brandText ?? "",
                log.mealType ?? "",
                log.message
            ]
            
            guard candidates.contains(where: { $0.lowercased().contains(query) }) else { return nil }
            
            let dedupeKey = "\(foodItem.fdcId)-\(foodItem.displayName.lowercased())"
            guard seen.insert(dedupeKey).inserted else { return nil }
            
            return log
        }
    }
    
    private var shouldShowCreateFoodMenu: Bool {
        trimmedSearchQuery.isEmpty &&
        selectedFoodTab == .foods &&
        !foodManager.foodScanningState.isActive
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Add invisible spacing at the top to prevent overlap with header
            Color.clear.frame(height: 4)

          
            // Show Create Food dropdown in Foods tab when there's no search text and not generating food
            if shouldShowCreateFoodMenu {
                Menu {
                    Button(action: {
                        print("Tapped Manual Create Food")
                        HapticFeedback.generateLigth()
                        path.append(FoodNavigationDestination.createFood)
                    }) {
                        HStack {
                            Text("Enter Manually")
                            Spacer()
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    
                    Button(action: {
                        print("Tapped Voice Create Food")
                        HapticFeedback.generateLigth()
                        showCreateFoodWithVoice = true
                    }) {
                        HStack {
                            Text("Describe with Voice")
                            Spacer()
                            Image(systemName: "waveform")
                        }
                    }
                    
                    Button(action: {
                        print("Tapped Scan Create Food")
                        HapticFeedback.generateLigth()
                        showCreateFoodWithScan = true
                    }) {
                        HStack {
                            Text("Scan Food")
                            Spacer()
                            Image(systemName: "barcode.viewfinder")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                        Text("Create Food")
                            .font(.system(size: 17))
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 0)
            }
            // Show Quick Log button when there's no search text in .all tab and not generating food
            else if searchText.isEmpty && selectedFoodTab == .all && !foodManager.foodScanningState.isActive {
                // Quick Log Button
                Button(action: {
                    print("Tapped quick Log")
                    HapticFeedback.generateLigth()
                    showQuickLogSheet = true // Show QuickLog sheet
                }) {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                        Text("Quick Log")
                            .font(.system(size: 17))
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 0)
            } 
            // Show AI Generate Macros button when there's search text in the .all tab
            else if selectedFoodTab == .all && !isProSearchResult && !isSearching {
                Button(action: {
                    print("AI tapped for: \(searchText)")
                    HapticFeedback.generateLigth()
                    
                    // First, close the food container immediately
                    viewModel.isShowingFoodContainer = false
                    
                    // Then start the AI analysis process
                    foodManager.generateMacrosWithAI(
                        foodDescription: searchText,
                        mealType: selectedMeal
                    ) { result in
                        switch result {
                        case .success(let loggedFood):
                            // Success is handled by FoodManager (shows toast, updates lists)
                            print("Successfully generated macros with AI")

                          let combinedLog = CombinedLog(
                                type: .food,
                                status: loggedFood.status,
                                calories: loggedFood.calories,
                                message: loggedFood.message,
                                foodLogId: loggedFood.foodLogId,
                                food: loggedFood.food,
                                mealType: loggedFood.mealType,
                                mealLogId: nil, meal: nil, mealTime: nil,
                                 scheduledAt: dayLogsVM.selectedDate,
                                recipeLogId: nil, recipe: nil, servingsConsumed: nil
                                )


                        DispatchQueue.main.async {
                            dayLogsVM.addPending(combinedLog)

                            // 1) see if there's an existing entry with that foodLogId
                            if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                                foodManager.combinedLogs.remove(at: idx)
                            }
                            // 2) prepend the fresh log
                            foodManager.combinedLogs.insert(combinedLog, at: 0)
                        }
                        case .failure(let error):
                            // Show error alert
                            if let networkError = error as? NetworkError, case .serverError(let message) = networkError {
                                aiErrorMessage = message
                            } else {
                                aiErrorMessage = error.localizedDescription
                            }
                            showAIErrorAlert = true
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "sparkle")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                        Text("Generate Macros with AI")
                            .font(.system(size: 17))
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 0)
                .disabled(isGeneratingMacros) // Disable button while loading
            }
            // Show Generate Food with AI button when there's search text in the .foods tab
            else if selectedFoodTab == .foods && !searchText.isEmpty {
                Button(action: {
                    print("Generating food with AI: \(searchText)")
                    HapticFeedback.generateLigth()
                    
                    // Dismiss keyboard
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    
                    // UNIFIED: Start with proper 0% progress, then animate with smooth transitions
                    foodManager.updateFoodScanningState(.initializing)  // Start at 0% with animation
                    
                    // Animate to food generation state after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        foodManager.updateFoodScanningState(.generatingFood)  // Smooth animate to 60%
                    }
                    
                    // Generate food with AI - skip confirmation for text search
                    foodManager.generateFoodWithAI(foodDescription: searchText, skipConfirmation: true) { result in
                        // UNIFIED: Show completion with proper animation and auto-reset (like macro generation)
                        // Need to create a CombinedLog for the completion state
                        
                        switch result {
                        case .success(let generated):
                            // UNIFIED: Show completion before proceeding
                            let completionLog = CombinedLog(
                                type: .food,
                                status: "success",
                                calories: generated.calories ?? 0,
                                message: "Generated \(generated.displayName)",
                                foodLogId: nil
                            )
                            foodManager.updateFoodScanningState(.completed(result: completionLog))
                            
                            // Create the food in the database
                            foodManager.createManualFood(food: generated, showPreview: false) { createResult in
                                DispatchQueue.main.async {
                                    switch createResult {
                                    case .success(let createdFood):
                                        // Store the created food
                                        self.generatedFood = createdFood
                                        
                                        // Track as recently added
                                        foodManager.trackRecentlyAdded(foodId: createdFood.fdcId)
                                        
                                        // IMPORTANT: Add the food to userFoods so it appears in MyFoods tab immediately

                                        if !foodManager.userFoods.contains(where: { $0.fdcId == createdFood.fdcId }) {
                                            foodManager.userFoods.insert(createdFood, at: 0) // Add to beginning of list
                                        }
                                        // Show success toast
                                        showFoodCreatedToast = true
                                        
                                        // Hide the toast after a delay
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                            showFoodCreatedToast = false
                                        }
                                        
                                        print("✅ Food created from text search: \(createdFood.displayName)")
                                        
                                    case .failure(let error):
                                        print("❌ Failed to create food in database: \(error)")
                                    }
                                }
                            }
                            
                        case .failure(let error):
                            // UNIFIED: Show error state then reset
                            foodManager.updateFoodScanningState(.failed(error: .networkError(error.localizedDescription)))
                            
                            // Reset after showing error for a moment
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                foodManager.resetFoodScanningState()
                            }
                            
                            // Show error alert
                            if let networkError = error as? NetworkError, case .serverError(let message) = networkError {
                                aiErrorMessage = message
                            } else {
                                aiErrorMessage = error.localizedDescription
                            }
                            showAIErrorAlert = true
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "sparkle")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                        Text("Generate Food with AI")
                            .font(.system(size: 17))
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 0)
                .disabled(foodManager.foodScanningState.isActive) // UNIFIED: Disable button while any scanning is active
            }
            
            // UNIFIED: Single modern loader for all food generation scenarios
            if foodManager.foodScanningState.isActive {
                ModernFoodLoadingCard(state: foodManager.foodScanningState)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Main content card
            if searchResults.isEmpty && !isSearching {
                // Main content for All/Foods tabs
               
                VStack(spacing: 0) {
                    // Use the helper function to get filtered logs
                    let validLogs = getFilteredLogs()
                    
                    // Main content List with native swipe-to-delete
                    if !validLogs.isEmpty {
                          let cardHeight = min(CGFloat(validLogs.count) * 63, UIScreen.main.bounds.height * 0.7) // Adjusted multiplier to 63
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("bg"))
                            
                            List {
                                ForEach(validLogs) { log in
                                    Group {
                                        switch log.type {
                                        case .food:
                                            if let food = log.food {
                                                FoodRow(
                                                    food: food.asFood,
                                                    selectedMeal: $selectedMeal,
                                                    mode: mode,
                                                    selectedFoods: $selectedFoods,
                                                    path: $path,
                                                    onItemAdded: onItemAdded
                                                )
                                                .onAppear {
                                                    // If we're close to the end of the list, automatically load more
                                                    if let index = validLogs.firstIndex(where: { $0.id == log.id }), index >= validLogs.count - 3 {
                                                        if selectedFoodTab == .foods {
                                                            if foodManager.hasMoreUserFoodsAvailable && !foodManager.isLoadingUserFoods {
                                                                showMinimumLoader()
                                                                foodManager.loadUserFoods(refresh: false)
                                                            }
                                                        } else {
                                                            if foodManager.hasMore && !foodManager.isLoadingLogs {
                                                                showMinimumLoader()
                                                                foodManager.loadMoreLogs()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        case .meal:
                                            if let meal = log.meal, selectedFoodTab != .foods {
                                                CombinedLogMealRow(
                                                    log: log,
                                                    meal: meal,
                                                    selectedMeal: $selectedMeal,
                                                    mode: mode,
                                                    selectedFoods: $selectedFoods,
                                                    path: $path,
                                                    onItemAdded: onItemAdded
                                                )
                                                .onAppear {
                                                    // If we're close to the end of the list, automatically load more
                                                    if let index = validLogs.firstIndex(where: { $0.id == log.id }),
                                                    index >= validLogs.count - 3 && foodManager.hasMore && !foodManager.isLoadingLogs {
                                                         showMinimumLoader()
                                                        foodManager.loadMoreLogs()
                                                    }
                                                }
                                            }
                                        case .recipe:
                                            EmptyView()
                                        case .activity, .workout:
                                            EmptyView() // Activities and workouts are not shown in LogFood view
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                    // .listRowBackground(Color.clear)
                                     .listRowBackground(Color("iosfit"))
                                    .listRowSeparator(.hidden)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .onDelete { indexSet in
                                    deleteItems(from: validLogs, at: indexSet)
                                }
                            }
                            .listStyle(PlainListStyle())
                            .scrollContentBackground(.hidden)
                            .scrollIndicators(.hidden)
                            .scrollIndicators(.hidden)
                       
                        }
                        .frame(maxHeight: cardHeight, alignment: .top)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    } else if (selectedFoodTab == .foods ? foodManager.isLoadingUserFoods : foodManager.isLoadingLogs) {
                        ProgressView()
                            .frame(height: 100)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    } else {
                        // Empty state with proper styling
                        Text(selectedFoodTab == .foods ? "No foods found" : "No items found")
                            .foregroundColor(.secondary)
                            .frame(height: 100)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    }
                    
                    // Show a loader at the bottom when loading more logs/foods
                    if ((selectedFoodTab == .foods ? (foodManager.isLoadingUserFoods && foodManager.hasMoreUserFoodsAvailable) : (foodManager.isLoadingLogs && foodManager.hasMore)) || isShowingMinimumLoader) {
                        ProgressView()
                            .padding()
                    }
                }
                .onAppear {
                    // Ensure initial data is loaded for My Foods tab
                    if selectedFoodTab == .foods && foodManager.userFoods.isEmpty && !foodManager.isLoadingUserFoods {
                        foodManager.loadUserFoods(refresh: true)
                    }
                }
            } else if searchResults.isEmpty && isSearching {
                if selectedFoodTab == .all {
                    ProFoodSearchLoader()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                } else {
                    ProgressView()
                        .padding()
                }
            } else {
                // Search results - using List for native swipe-to-delete
                if isProSearchResult, let proFood = searchResults.first {
                    ProFoodResultCard(
                        food: proFood,
                        selectedMeal: $selectedMeal,
                        mode: mode,
                        selectedFoods: $selectedFoods,
                        path: $path,
                        onItemAdded: onItemAdded
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .scale))
                    
                    let recentMatches = recentLogMatches
                    if !recentMatches.isEmpty {
                        RecentLogsSection(
                            logs: recentMatches,
                            selectedMeal: $selectedMeal,
                            mode: mode,
                            selectedFoods: $selectedFoods,
                            path: $path,
                            onItemAdded: onItemAdded
                        )
                        .padding(.top, 16)
                    }
                } else {
                    VStack(spacing: 0) {
                        if !searchResults.isEmpty {
                             let searchCardHeight = min(CGFloat(searchResults.count) * 60, UIScreen.main.bounds.height * 0.7)
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("bg"))
                                
                                List {
                                    ForEach(searchResults, id: \.fdcId) { food in
                                        FoodRow(
                                            food: food,
                                            selectedMeal: $selectedMeal,
                                            mode: mode,
                                            selectedFoods: $selectedFoods,
                                            path: $path,
                                            onItemAdded: onItemAdded
                                        )
                                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                        .listRowBackground(Color("iosfit"))
                                        .listRowSeparator(.hidden)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    .onDelete { indexSet in
                                        deleteSearchResults(at: indexSet)
                                    }
                                }
                                .listStyle(PlainListStyle())
                                .scrollContentBackground(.hidden)
                            }
                            .frame(maxHeight: searchCardHeight, alignment: .top)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        } else {
                            Text("No results found")
                                .foregroundColor(.secondary)
                                .frame(height: 100)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 20)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 16)
        .background(Color("iosbg2"))
       
          
        .alert("AI Generation Error", isPresented: $showAIErrorAlert) {
            Button("OK", role: .cancel) { showAIErrorAlert = false }
        } message: {
            Text(aiErrorMessage)
        }
        .overlay(
            // Show the food created toast when needed
            Group {
                if showFoodCreatedToast {
                    VStack {
                        Spacer()
                        BottomPopup(message: "Food created")
                            .padding(.bottom, 0)
                    }
                    .zIndex(100)
                    .transition(.opacity)
                    .animation(.spring(), value: showFoodCreatedToast)
                }
            }
        )
    }
    
    private func getFilteredLogs() -> [CombinedLog] {
        // If we're on the foods tab, we should show user foods instead of food logs
        if selectedFoodTab == .foods {
            // Convert userFoods to CombinedLog format for display
            return foodManager.userFoods.map { food in
                // Create a LoggedFoodItem from the Food
                // Filter out empty or default brand texts
                let brandText = food.brandText
                let cleanBrandText: String? = (brandText == nil || brandText!.isEmpty || 
                                             brandText == "Custom" || brandText == "Generic") ? nil : brandText
                
                let loggedFoodItem = LoggedFoodItem(
                    foodLogId: nil,
                    fdcId: food.fdcId,
                    displayName: food.displayName,
                    calories: food.calories ?? 0,
                    servingSizeText: food.servingSizeText,
                    numberOfServings: food.numberOfServings ?? 1,
                    brandText: cleanBrandText,
                    protein: food.protein,
                    carbs: food.carbs,
                    fat: food.fat,
                    healthAnalysis: nil,
                    foodNutrients: food.foodNutrients
                )
                

                
                // Create a CombinedLog for the LoggedFoodItem
                return CombinedLog(
                    type: .food,
                    status: "success",
                    calories: food.calories ?? 0,
                    message: "\(food.displayName)" + (cleanBrandText != nil ? " - \(cleanBrandText!)" : ""),
                    foodLogId: food.fdcId, // Use fdcId as the log ID
                    food: loggedFoodItem,
                    mealType: "",  // No meal type for user foods
                    mealLogId: nil,
                    meal: nil,
                    mealTime: nil,
                    scheduledAt: nil,
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil
                )
            }
        }
        
        // Otherwise, filter the combinedLogs as usual
        return foodManager.combinedLogs.filter { log in
            switch log.type {
            case .food:
                return log.food != nil && selectedFoodTab == .all
            
            case .meal:
                return log.meal != nil && (selectedFoodTab == .meals || selectedFoodTab == .all)
            
            case .recipe:
                return log.recipe != nil && selectedFoodTab == .all
            case .activity, .workout:
                return false // Activities and workouts are not shown in LogFood view
            }
        }
    }
    
    private func showMinimumLoader() {
        isShowingMinimumLoader = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isShowingMinimumLoader = false
        }
    }
    
    private func deleteSearchResults(at indexSet: IndexSet) {
        print("Deleting search results at indices: \(indexSet)")
        
        // Get the foods to delete
        let foodsToDelete = indexSet.map { searchResults[$0] }
        
        // Log information about what will be deleted
        for food in foodsToDelete {
            print("Deleting food from search results: \(food.displayName) (ID: \(food.fdcId))")
        }
        
        // No actual deletion here since these are search results, not user foods
        // If the user wants to delete one of these items, they would need to tap into it
        // and then delete from the detail view
    }
    
    private func deleteItems(from logs: [CombinedLog], at indexSet: IndexSet) {
        print("Deleting items at indices: \(indexSet)")
        
        // Get the logs that should be deleted
        let logsToDelete = indexSet.map { logs[$0] }
        
        // Log detailed information about the logs to be deleted
        for log in logsToDelete {
            print("🔍 Log to delete - ID: \(log.id), Type: \(log.type)")
            
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
            case .activity:
                print("  • Activity log details:")
                print("    - Activity ID: \(log.activityId ?? "unknown")")
                if let activity = log.activity {
                    print("    - Activity name: \(activity.displayName)")
                }
            case .workout:
                print("  • Workout log details:")
                print("    - Workout log ID: \(log.workoutLogId ?? -1)")
                if let workout = log.workout {
                    print("    - Workout title: \(workout.title)")
                    print("    - Duration minutes: \(workout.durationMinutes ?? 0)")
                    print("    - Exercises: \(workout.exercisesCount)")
                }
            }
            print("  • Current tab: \(selectedFoodTab)")
        }
        
        // Actually delete the items
        for log in logsToDelete {
            switch log.type {
            case .food:
                if selectedFoodTab == .foods {
                    // In My Foods tab, we're deleting the actual food
                    if let food = log.food {
                        // fdcId is likely already an Int, no need to convert
                        let foodId = Int(food.fdcId) ?? 0
                        if foodId > 0 {
                            foodManager.deleteFood(id: foodId) { result in
                                switch result {
                                case .success:
                                    print("Successfully deleted food: \(food.displayName)")
                                case .failure(let error):
                                    print("Failed to delete food: \(error)")
                                }
                            }
                        }
                    }
                } else {
                    // In All tab, we're deleting a food log
                    if let foodLogId = log.foodLogId {
                        // foodLogId is likely already an Int or can be directly converted
                        foodManager.deleteFoodLog(id: foodLogId) { result in
                            switch result {
                            case .success:
                                print("Successfully deleted food log ID: \(foodLogId)")
                            case .failure(let error):
                                print("Failed to delete food log: \(error)")
                            }
                        }
                    }
                }
            case .meal:
                // Delete the meal log if we're in All tab
                if selectedFoodTab == .all, let mealLogId = log.mealLogId {
                    // mealLogId is likely already an Int
                    foodManager.deleteMealLog(id: mealLogId) { result in
                        switch result {
                        case .success:
                            print("Successfully deleted meal log ID: \(mealLogId)")
                        case .failure(let error):
                            print("Failed to delete meal log: \(error)")
                        }
                    }
                }
                // Delete the actual meal if in Meals tab
                else if selectedFoodTab == .meals, let meal = log.meal {
                    // meal.id is already an Int
                    foodManager.deleteMeal(id: meal.id) { result in // Reverted to deleteMeal
                        switch result {
                        case .success:
                            print("Successfully deleted meal: \(meal.title)") // Log for meal template
                        case .failure(let error):
                            print("Failed to delete meal: \(error)") // Log for meal template
                        }
                    }
                }
            case .recipe:
                if let recipeLogId = log.recipeLogId {
                    // recipeLogId is likely already an Int
                    print("Recipe log deletion not yet implemented for ID: \(recipeLogId)")
                }
            case .activity:
                print("🏃 Activity logs cannot be deleted (they come from Apple Health)")
            case .workout:
                print("🏋️ Workout logs cannot be deleted from LogFood (completed sessions are permanent)")
            }
        }
    }
}

private struct CreateMealButton: View {
    @Binding var path: NavigationPath
    
    var body: some View {
       


      
                    Button(action: {
                        print("Tapped Create Recipe")
                        HapticFeedback.generateLigth()
                         path.append(FoodNavigationDestination.createMeal)
                    }) {
                        HStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                            Text("Create Recipe")
                                .font(.system(size: 17))
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("iosfit"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 0)
                    .padding(.bottom, 4)
                
    }
}

// MEAL LIST VIEW -- CHANGED to unify divider usage
private struct MealListView: View {
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    let searchText: String
    
    // Add states for AI generation
    @State private var isGeneratingMeal = false
    @State private var showAIErrorAlert = false
    @State private var aiErrorMessage = ""
    
    var onItemAdded: ((Food) -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Add invisible spacing at the top to prevent overlap with header
                Color.clear.frame(height: 6)
            
            // Show "Generate Meal with AI" button when search text is not empty
            if !searchText.isEmpty {
                Button(action: {
                    print("generating meal with ai...")
                    HapticFeedback.generateLigth()
                    
                    // Dismiss keyboard
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    
                    // Set loading state in FoodManager
                    foodManager.isGeneratingMeal = true
                    
                    // Then start the AI meal generation process
                    foodManager.generateMealWithAI(
                        mealDescription: searchText,
                        mealType: selectedMeal
                    ) { result in
                        // Reset is no longer needed as FoodManager handles it
                        
                        switch result {
                        case .success(_):
                            // Success is handled by FoodManager (shows toast, updates lists)
                            print("Successfully generated meal with AI")
                            
                        case .failure(let error):
                            // Show error alert
                            if let networkError = error as? NetworkError, case .serverError(let message) = networkError {
                                aiErrorMessage = message
                            } else {
                                aiErrorMessage = error.localizedDescription
                            }
                            showAIErrorAlert = true
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "sparkle")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                        Text("Generate Recipe with AI")
                            .font(.system(size: 17))
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 0)
                .disabled(foodManager.isGeneratingMeal) // Disable button while loading
            } 
            // Show Create Meal button when no search text
            else {
                // Create Meal Button
                Button(action: {
                    print("Tapped Create Meal from MealListView")
                    HapticFeedback.generateLigth()
                    path.append(FoodNavigationDestination.createMeal) // Navigate to CreateMealView
                }) {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                        Text("Create Recipe")
                            .font(.system(size: 17))
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 0)
                .padding(.bottom, 4)
            }
            
            // UNIFIED: Modern loader already handled above - removed duplicate meal loader
            
            // Meals Card - Single unified card for all meals
            if !foodManager.meals.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("bg"))
                    
                    List {
                        ForEach(foodManager.meals) { meal in
                            MealRow(
                                meal: meal,
                                selectedMeal: $selectedMeal,
                                mode: mode,
                                selectedFoods: $selectedFoods,
                                path: $path,
                                onItemAdded: onItemAdded
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                             .listRowBackground(Color("iosfit"))
                            .listRowSeparator(.hidden)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .onAppear {
                                // Near-end pagination for meals
                                if let index = foodManager.meals.firstIndex(where: { $0.id == meal.id }),
                                   index >= foodManager.meals.count - 3,
                                   foodManager.hasMoreMealsAvailable,
                                   !foodManager.isLoadingMeals {
                                    foodManager.loadMoreMeals(refresh: false)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            deleteMeals(at: indexSet)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                }
                .frame(height: min(CGFloat(foodManager.meals.count * 63), UIScreen.main.bounds.height * 0.7)) // Adjusted calculation
                .cornerRadius(12)
                .padding(.horizontal, 16)
            } else if foodManager.isLoadingMeals {
                // Loading indicator
                ProgressView()
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
            } else {
                // Empty state
                Text("No meals found")
                    .foregroundColor(.secondary)
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .background(Color("iosbg2"))
        .onAppear {
            if foodManager.meals.isEmpty && !foodManager.isLoadingMeals {
                foodManager.refreshMeals()
            }
        }
        .overlay(
            // Show success toast when a meal is generated
            Group {
                if foodManager.showMealGenerationSuccess, let meal = foodManager.lastGeneratedMeal {
                    VStack {
                        Spacer()
                        BottomPopup(message: "\(meal.title) created")
                            .padding(.bottom, 0)
                    }
                    .zIndex(100)
                    .transition(.opacity)
                    .animation(.spring(), value: foodManager.showMealGenerationSuccess)
                }
            }
        )
        .alert("AI Generation Error", isPresented: $showAIErrorAlert) {
            Button("OK", role: .cancel) { showAIErrorAlert = false }
        } message: {
            Text(aiErrorMessage)
        }
    }
    
    private func deleteMeals(at indexSet: IndexSet) {
        print("Deleting meals at indices: \(indexSet)")
        
        // Get the meals to delete
        let mealsToDelete = indexSet.map { foodManager.meals[$0] }
        
        // Actually delete the meals
        for meal in mealsToDelete {
            foodManager.deleteMeal(id: meal.id) { result in
                switch result {
                case .success:
                    print("Successfully deleted meal: \(meal.title)")
                case .failure(let error):
                    print("Failed to delete meal: \(error)")
                }
            }
        }
    }
}

private struct CreateRecipeButton: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        Button(action: {
            path.append(FoodNavigationDestination.createRecipe)
        }) {
            HStack(spacing: 16) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                Text("Create Recipe")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("iosfit"))
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.top, 0)
    }
}

// RECIPE LIST VIEW -- same pattern if you use it
private struct RecipeListView: View {
    @EnvironmentObject var foodManager: FoodManager
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    var onItemAdded: ((Food) -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Create Recipe Button
                CreateRecipeButton(path: $path)
                    .padding(.top, 0)
                
                // Recipes Card - Single unified card for all recipes
                if !foodManager.recipes.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(foodManager.recipes.indices, id: \.self) { index in
                            let recipe = foodManager.recipes[index]
                            
                            // Placeholder for RecipeRow
                            HStack {
                                Text(recipe.title)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                Spacer()
                                
                                Button(action: {}) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .frame(width: 32, height: 32)
                                        .background(Color("iosfit"))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            if index < foodManager.recipes.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                } else {
                    // Empty state
                    Text("No recipes found")
                        .foregroundColor(.secondary)
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color("iosbg2"))
    }
}

// MARK: - FoodRow, MealRow, CombinedLogMealRow, etc. (unchanged in architecture)
struct FoodRow: View {
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    let food: Food
    let selectedMeal: Binding<String>
    @State private var checkmarkVisible: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var showLoggingErrorAlert = false
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    var onItemAdded: ((Food) -> Void)?
    @EnvironmentObject var dayLogsVM: DayLogsViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.displayName)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    if let calories = food.calories {
                        Text("\(Int(calories)) cal")
                            .foregroundColor(.secondary)
                    }
                    
                    // Check if the serving size text is meaningful (not just a default value)
                    // This helps hide the serving info for quick-logged foods
                    let isDefaultServing = food.servingSizeText.isEmpty || 
                                          food.servingSizeText.trimmingCharacters(in: .whitespaces) == "1.0" ||
                                          food.servingSizeText.trimmingCharacters(in: .whitespaces) == "1"
                    
                    // if !food.servingSizeText.isEmpty && !isDefaultServing {
                    //     Text("•")
                    //         .foregroundColor(.secondary)
                    //     Text(food.servingSizeText)
                    //         .foregroundColor(.secondary)
                    // }
                    if let brand = food.brandText, !brand.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(brand)
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 13))
            }
            
            Spacer()
            
            Button {
                HapticFeedback.generate()
                handleFoodTap()
            } label: {
                if foodManager.lastLoggedFoodId == food.fdcId || 
                   foodManager.recentlyAddedFoodIds.contains(food.fdcId) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color("iosbg2"))
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Only navigate if in logFood mode
            if mode == .logFood {
                // Navigate to food details view with the proper binding
                HapticFeedback.generate()
                path.append(FoodNavigationDestination.foodDetails(food, selectedMeal))
            }
        }
        .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
    }

    private func handleFoodTap() {
        HapticFeedback.generate()
        switch mode {
        case .logFood:
            logFood()
            
        case .addToMeal, .addToRecipe:
            let newFood = Food(
                fdcId: food.fdcId,
                description: food.description,
                brandOwner: food.brandOwner,
                brandName: food.brandName,
                servingSize: food.servingSize,
                numberOfServings: 1,
                servingSizeUnit: food.servingSizeUnit,
                householdServingFullText: food.householdServingFullText,
                foodNutrients: food.foodNutrients,
                foodMeasures: food.foodMeasures
            )
            
            var updatedFoods = [Food]()
            for existingFood in selectedFoods {
                updatedFoods.append(existingFood)
            }
            updatedFoods.append(newFood)
            
            selectedFoods = updatedFoods
            foodManager.trackRecentlyAdded(foodId: food.fdcId)
            
            if let callback = onItemAdded {
                callback(newFood)
            } else if !path.isEmpty {
                path.removeLast()
            }
        }
    }
    
    private func logFood() {
        // First, close the food container immediately
        viewModel.isShowingFoodContainer = false
        
        foodManager.logFood(
            email: viewModel.email,
            food: food,
            meal: selectedMeal.wrappedValue,
            servings: 1,
            date: dayLogsVM.selectedDate,
            notes: nil
        ) { result in
            switch result {
            case .success(let loggedFood):
                print("Food logged successfully: \(loggedFood)")
                // Success is handled by FoodManager (shows toast, updates lists)
                let combinedLog = CombinedLog(
                    type:         .food,
                    status:       loggedFood.status,
                    calories:     Double(loggedFood.food.calories),
                    message:      "\(loggedFood.food.displayName) – \(loggedFood.mealType)",
                    foodLogId:    loggedFood.foodLogId,
                    food:         loggedFood.food,
                    mealType:     loggedFood.mealType,
                    mealLogId:    nil,
                    meal:         nil,
                    mealTime:     nil,
                    scheduledAt:  dayLogsVM.selectedDate,
                    recipeLogId:  nil,
                    recipe:       nil,
                    servingsConsumed: nil,
                    isOptimistic: true
                )

                // Ensure all UI updates happen on the main thread
                DispatchQueue.main.async {
                    // Tell the day-logs view model about it
                    dayLogsVM.addPending(combinedLog)
                    print("After addPending from FoodRow, logs contains food? \(dayLogsVM.logs.contains(where: { $0.id == combinedLog.id }))")

                    // Prepend it into the global `combinedLogs` so dashboard's "All" feed updates
                    if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                        foodManager.combinedLogs.remove(at: idx)
                    }
                    foodManager.combinedLogs.insert(combinedLog, at: 0)
                }
                
            case .failure(let error):
                print("Error logging food: \(error)")
                
                withAnimation {
                    if self.foodManager.lastLoggedFoodId == self.food.fdcId {
                        self.foodManager.lastLoggedFoodId = nil
                    }
                }
                self.showLoggingErrorAlert = true
            }
        }
    }
}

private struct ProFoodResultCard: View {
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @Environment(\.dismiss) private var dismiss
    
    let food: Food
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    var onItemAdded: ((Food) -> Void)?
    
    @State private var showLoggingErrorAlert = false
    
    private var alreadyLogged: Bool {
        foodManager.lastLoggedFoodId == food.fdcId ||
        foodManager.recentlyAddedFoodIds.contains(food.fdcId)
    }
    
    private var servingText: String {
        let text = food.servingSizeText
        return text.isEmpty ? "Per serving" : text
    }
    
    private var brandText: String? {
        let brand = food.brandText ?? ""
        return brand.isEmpty ? nil : brand
    }
    
    private var calorieDisplayText: String {
        guard let calories = food.calories else { return "–" }
        return "\(Int(calories.rounded()))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            macroSummary
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color("iosfit"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard mode == .logFood else { return }
            HapticFeedback.generate()
            path.append(FoodNavigationDestination.foodDetails(food, $selectedMeal))
        }
        .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
    }
    
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(food.displayName)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                if let combined = brandServingLine {
                    Text(combined)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            logButton
        }
    }
    
    private var macroSummary: some View {
        HStack(alignment: .center, spacing: 24) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color("brightOrange"))
                HStack(alignment: .bottom, spacing: 2) {
                    Text(calorieDisplayText)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("cal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 24) {
                MacroColumn(title: "Protein", valueText: macroText(for: food.protein), titleTint: .blue)
                MacroColumn(title: "Carbs", valueText: macroText(for: food.carbs), titleTint: Color("darkYellow"))
                MacroColumn(title: "Fat", valueText: macroText(for: food.fat), titleTint: .pink)
            }
        }
        .padding(.top, 20)
    }
    
    private var logButton: some View {
        Button {
            HapticFeedback.generate()
            handleFoodTap()
        } label: {
            Text(alreadyLogged ? "Added" : "Log")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(.systemBackground))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.primary)
                )
        }
        .buttonStyle(.plain)
        .disabled(alreadyLogged)
    }
    
    private var brandServingLine: String? {
        let brand = brandText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let serving = servingText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch (brand?.isEmpty == false, serving.isEmpty == false) {
        case (true, true):
            return "\(brand!) • \(serving)"
        case (true, false):
            return brand
        case (false, true):
            return serving
        default:
            return nil
        }
    }
    
    private func macroText(for value: Double?) -> String {
        guard let value else { return "–" }
        return "\(Int(value.rounded()))g"
    }
    
    private func handleFoodTap() {
        if alreadyLogged { return }
        HapticFeedback.generate()
        switch mode {
        case .logFood:
            logFood()
        case .addToMeal, .addToRecipe:
            let newFood = Food(
                fdcId: food.fdcId,
                description: food.description,
                brandOwner: food.brandOwner,
                brandName: food.brandName,
                servingSize: food.servingSize,
                numberOfServings: 1,
                servingSizeUnit: food.servingSizeUnit,
                householdServingFullText: food.householdServingFullText,
                foodNutrients: food.foodNutrients,
                foodMeasures: food.foodMeasures
            )
            
            var updatedFoods = selectedFoods
            updatedFoods.append(newFood)
            selectedFoods = updatedFoods
            foodManager.trackRecentlyAdded(foodId: food.fdcId)
            
            if let callback = onItemAdded {
                callback(newFood)
            } else if !path.isEmpty {
                path.removeLast()
            }
        }
    }
    
    private func logFood() {
        viewModel.isShowingFoodContainer = false
        
        foodManager.logFood(
            email: viewModel.email,
            food: food,
            meal: selectedMeal,
            servings: 1,
            date: dayLogsVM.selectedDate,
            notes: nil
        ) { result in
            switch result {
            case .success(let loggedFood):
                let combinedLog = CombinedLog(
                    type: .food,
                    status: loggedFood.status,
                    calories: Double(loggedFood.food.calories),
                    message: "\(loggedFood.food.displayName) – \(loggedFood.mealType)",
                    foodLogId: loggedFood.foodLogId,
                    food: loggedFood.food,
                    mealType: loggedFood.mealType,
                    mealLogId: nil,
                    meal: nil,
                    mealTime: nil,
                    scheduledAt: dayLogsVM.selectedDate,
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil,
                    isOptimistic: true
                )
                
                DispatchQueue.main.async {
                    dayLogsVM.addPending(combinedLog)
                    if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                        foodManager.combinedLogs.remove(at: idx)
                    }
                    foodManager.combinedLogs.insert(combinedLog, at: 0)
                }
            case .failure:
                withAnimation {
                    if foodManager.lastLoggedFoodId == food.fdcId {
                        foodManager.lastLoggedFoodId = nil
                    }
                }
                showLoggingErrorAlert = true
            }
        }
    }
    
    private struct MacroColumn: View {
        let title: String
        let valueText: String
        let titleTint: Color
        
        var body: some View {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(titleTint)
                Text(valueText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
            }
        }
    }
}

struct HistoryRow: View {
    let log: CombinedLog
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    @EnvironmentObject var foodManager: FoodManager
    @State private var showLoggingErrorAlert = false
    
    var onItemAdded: ((Food) -> Void)?
    
    var body: some View {
        Group {
            switch log.type {
            case .food:
                if let food = log.food {
                    let updatedFood = food.asFood
                    FoodRow(
                        food: updatedFood,
                        selectedMeal: $selectedMeal,
                        mode: mode,
                        selectedFoods: $selectedFoods,
                        path: $path,
                        onItemAdded: onItemAdded
                    )
                }
            case .meal:
                if let meal = log.meal {
                    CombinedLogMealRow(
                        log: log,
                        meal: meal,
                        selectedMeal: $selectedMeal,
                        mode: mode,
                        selectedFoods: $selectedFoods,
                        path: $path,
                        onItemAdded: onItemAdded
                    )
                }
            case .recipe, .activity, .workout:
                EmptyView() // These log types are not shown in LogFood view
            }
        }
    }
}

// New row that shows displayCalories from the combined log
struct CombinedLogMealRow: View {
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    let log: CombinedLog
    let meal: MealSummary
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    var onItemAdded: ((Food) -> Void)?
    @State private var showLoggingErrorAlert: Bool = false
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    
    init(log: CombinedLog, 
         meal: MealSummary, 
         selectedMeal: Binding<String>, 
         mode: LogFoodMode = .logFood, 
         selectedFoods: Binding<[Food]> = .constant([]), 
         path: Binding<NavigationPath> = .constant(NavigationPath()),
         onItemAdded: ((Food) -> Void)? = nil) {
        self.log = log
        self.meal = meal
        self._selectedMeal = selectedMeal
        self.mode = mode
        self._selectedFoods = selectedFoods
        self._path = path
        self.onItemAdded = onItemAdded
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.title.isEmpty ? "Untitled Meal" : meal.title)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(Int(log.displayCalories)) cal")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                HapticFeedback.generate()
                switch mode {
                case .logFood:
                    // First, close the food container immediately
                    viewModel.isShowingFoodContainer = false
                    
                    foodManager.logMeal(
                        meal: Meal(
                            id: meal.id,
                            title: meal.title,
                            description: meal.description,
                            directions: nil,
                            privacy: "private",
                            servings: meal.servings,
                            mealItems: [],
                            image: meal.image,
                            totalCalories: log.displayCalories,
                            totalProtein: meal.protein,
                            totalCarbs: meal.carbs,
                            totalFat: meal.fat,
                            scheduledAt: dayLogsVM.selectedDate
                        ),
                        mealTime: selectedMeal,
                        date: dayLogsVM.selectedDate,
                        calories: log.displayCalories
                    ) { result in
                        switch result {
                        case .success(let loggedMeal):
                            // Create CombinedLog and add to DayLogsVM
                            let combinedLog = CombinedLog(
                                type:        .meal,
                                status:      loggedMeal.status,
                                calories:    loggedMeal.calories,
                                message:     "\(loggedMeal.meal.title) – \(loggedMeal.mealTime)",
                                foodLogId:   nil,
                                food:        nil,
                                mealType:    loggedMeal.mealTime,
                                mealLogId:   loggedMeal.mealLogId,
                                meal:        loggedMeal.meal,
                                mealTime:    loggedMeal.mealTime,
                                scheduledAt: dayLogsVM.selectedDate,
                                recipeLogId: nil,
                                recipe:      nil,
                                servingsConsumed: nil,
                                isOptimistic: true
                            )
                            
                            // Add to DayLogsViewModel
                            DispatchQueue.main.async {
                                dayLogsVM.addPending(combinedLog)
                                print("After addPending from CombinedLogMealRow, logs contains meal? \(dayLogsVM.logs.contains(where: { $0.id == combinedLog.id }))")
                                
                                // Update foodManager.combinedLogs
                                if let idx = foodManager.combinedLogs.firstIndex(where: { $0.mealLogId == combinedLog.mealLogId }) {
                                    foodManager.combinedLogs.remove(at: idx)
                                }
                                foodManager.combinedLogs.insert(combinedLog, at: 0)
                            }
                            
                        case .failure(let error):
                            // your existing failure UI
                            print("❌ Failed to log meal:", error)
                            withAnimation {
                            if foodManager.lastLoggedMealId == meal.id {
                                foodManager.lastLoggedMealId = nil
                            }
                            }
                            showLoggingErrorAlert = true
                        }
                    }
                case .addToMeal, .addToRecipe:
                    addMealItemsToSelection()
                }
            } label: {
                if foodManager.lastLoggedMealId == meal.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color("iosbg2"))
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if mode == .logFood {
                if let fullMeal = foodManager.meals.first(where: { $0.id == meal.id }) {
                    path.append(FoodNavigationDestination.mealDetails(fullMeal))
                } else {
                    let minimalMeal = Meal(
                        id: meal.id,
                        title: meal.title,
                        description: meal.description,
                        directions: nil,
                        privacy: "private",
                        servings: meal.servings,
                        mealItems: [],
                        image: meal.image,
                        totalCalories: log.displayCalories,
                        totalProtein: meal.protein,
                        totalCarbs: meal.carbs,
                        totalFat: meal.fat,
                        scheduledAt: meal.scheduledAt
                    )
                    path.append(FoodNavigationDestination.mealDetails(minimalMeal))
                }
            }
        }
        .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
    }
    
    private func addMealItemsToSelection() {
        if let fullMeal = foodManager.meals.first(where: { $0.id == meal.id }) {
            var lastAddedFood: Food? = nil
            for mealItem in fullMeal.mealItems {
                let servingsValue = Double(mealItem.servings.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 1.0
                let servingText: String
                if let text = mealItem.servingText, !text.isEmpty {
                    servingText = text
                } else {
                    if let unit = mealItem.servings.components(
                        separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
                    ).last,
                       !unit.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty 
                    {
                        servingText = unit.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        servingText = "serving"
                    }
                }

                let food = Food(
                    fdcId: Int(mealItem.externalId) ?? mealItem.foodId,
                    description: mealItem.name,
                    brandOwner: nil,
                    brandName: nil,
                    servingSize: 1.0,
                    numberOfServings: servingsValue,
                    servingSizeUnit: servingText,
                    householdServingFullText: servingText,
                    foodNutrients: [
                        Nutrient(nutrientName: "Energy", value: mealItem.calories, unitName: "kcal"),
                        Nutrient(nutrientName: "Protein", value: mealItem.protein, unitName: "g"),
                        Nutrient(nutrientName: "Carbohydrate, by difference", value: mealItem.carbs, unitName: "g"),
                        Nutrient(nutrientName: "Total lipid (fat)", value: mealItem.fat, unitName: "g")
                    ],
                    foodMeasures: []
                )
                
                selectedFoods.append(food)
                lastAddedFood = food
            }
            
            if let callback = onItemAdded, let lastFood = lastAddedFood {
                callback(lastFood)
            } else if !path.isEmpty {
                path.removeLast()
            }
        } else {
            if !path.isEmpty {
                path.removeLast()
            }
        }
    }
}

struct MealRow: View {
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @Environment(\.dismiss) private var dismiss
    let meal: Meal
    @Binding var selectedMeal: String
    
    var mode: LogFoodMode = .logFood
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    var onItemAdded: ((Food) -> Void)?
    
    @State private var showLoggingErrorAlert: Bool = false
    
    init(meal: Meal, 
         selectedMeal: Binding<String>, 
         mode: LogFoodMode = .logFood, 
         selectedFoods: Binding<[Food]> = .constant([]), 
         path: Binding<NavigationPath> = .constant(NavigationPath()),
         onItemAdded: ((Food) -> Void)? = nil) 
    {
        self.meal = meal
        self._selectedMeal = selectedMeal
        self.mode = mode
        self._selectedFoods = selectedFoods
        self._path = path
        self.onItemAdded = onItemAdded
    }
    
    private var displayCalories: Double {
        if meal.calories > 0 {
            return meal.calories
        }
        
        if !meal.mealItems.isEmpty {
            let totalItemCalories = meal.mealItems.reduce(0) { sum, item in
                sum + item.calories
            }
            if totalItemCalories > 0 {
                return totalItemCalories
            }
        }
        
        if (meal.protein + meal.carbs + meal.fat) > 0 {
            return (meal.protein * 4) + (meal.carbs * 4) + (meal.fat * 9)
        }
        
        return meal.calories
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.title.isEmpty ? "Untitled Meal" : meal.title)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(Int(displayCalories)) cal")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                HapticFeedback.generate()
                switch mode {
                case .logFood:
                    // First, close the food container immediately
                    viewModel.isShowingFoodContainer = false
                    
                    foodManager.logMeal(
                        meal: meal, 
                        mealTime: selectedMeal,
                        date: dayLogsVM.selectedDate,
                        calories: displayCalories
                    ) { result in
                        switch result {
                        case .success(let loggedMeal):
                            // Create CombinedLog and add to DayLogsVM
                            let combinedLog = CombinedLog(
                                type:        .meal,
                                status:      loggedMeal.status,
                                calories:    loggedMeal.calories,
                                message:     "\(loggedMeal.meal.title) – \(loggedMeal.mealTime)",
                                foodLogId:   nil,
                                food:        nil,
                                mealType:    loggedMeal.mealTime,
                                mealLogId:   loggedMeal.mealLogId,
                                meal:        loggedMeal.meal,
                                mealTime:    loggedMeal.mealTime,
                                scheduledAt: dayLogsVM.selectedDate,
                                recipeLogId: nil,
                                recipe:      nil,
                                servingsConsumed: nil,
                                isOptimistic: true
                            )
                            
                            // Add to DayLogsViewModel
                            DispatchQueue.main.async {
                                dayLogsVM.addPending(combinedLog)
                                print("After addPending from MealRow, logs contains meal? \(dayLogsVM.logs.contains(where: { $0.id == combinedLog.id }))")
                                
                                // Update foodManager.combinedLogs
                                if let idx = foodManager.combinedLogs.firstIndex(where: { $0.mealLogId == combinedLog.mealLogId }) {
                                    foodManager.combinedLogs.remove(at: idx)
                                }
                                foodManager.combinedLogs.insert(combinedLog, at: 0)
                            }
                            
                        case .failure(let error):
                            print("❌ Failed to log meal:", error)
                            withAnimation {
                                if self.foodManager.lastLoggedMealId == self.meal.id {
                                    self.foodManager.lastLoggedMealId = nil
                                }
                            }
                            showLoggingErrorAlert = true
                        }
                    }
                case .addToMeal, .addToRecipe:
                    addMealItemsToSelection()
                }
            } label: {
                if foodManager.lastLoggedMealId == meal.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color("iosbg2"))
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if mode == .logFood {
                path.append(FoodNavigationDestination.mealDetails(meal))
            }
        }
        .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }
    
    private func addMealItemsToSelection() {
        if let fullMeal = foodManager.meals.first(where: { $0.id == meal.id }) {
            var lastAddedFood: Food? = nil
            
            for mealItem in fullMeal.mealItems {
                let servingsValue = Double(mealItem.servings.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 1.0
                let servingText: String
                if let text = mealItem.servingText, !text.isEmpty {
                    servingText = text
                } else {
                    if let unit = mealItem.servings.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))).last,
                       !unit.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                        servingText = unit.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    } else {
                        servingText = "serving"
                    }
                }

                let food = Food(
                    fdcId: Int(mealItem.externalId) ?? mealItem.foodId,
                    description: mealItem.name,
                    brandOwner: nil,
                    brandName: nil,
                    servingSize: 1.0,
                    numberOfServings: servingsValue,
                    servingSizeUnit: servingText,
                    householdServingFullText: servingText,
                    foodNutrients: [
                        Nutrient(nutrientName: "Energy", value: mealItem.calories, unitName: "kcal"),
                        Nutrient(nutrientName: "Protein", value: mealItem.protein, unitName: "g"),
                        Nutrient(nutrientName: "Carbohydrate, by difference", value: mealItem.carbs, unitName: "g"),
                        Nutrient(nutrientName: "Total lipid (fat)", value: mealItem.fat, unitName: "g")
                    ],
                    foodMeasures: []
                )
                
                selectedFoods.append(food)
                lastAddedFood = food
            }
            
            if let callback = onItemAdded, let lastFood = lastAddedFood {
                callback(lastFood)
            } else if !path.isEmpty {
                path.removeLast()
            }
        } else {
            if !path.isEmpty {
                path.removeLast()
            }
        }
    }
}

// MARK: - UIKit Integration for Search Focus
struct SearchActivator: UIViewRepresentable {
    @Binding var isActivated: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard isActivated else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }),
               let rootViewController = window.rootViewController {
                
                // Find the search controller
                findAndActivateSearchController(in: rootViewController)
                
                // Reset the activation flag
                DispatchQueue.main.async {
                    isActivated = false
                }
            }
        }
    }
    
    private func findAndActivateSearchController(in viewController: UIViewController) {
        // Try to find the search controller in the navigation controller
        if let navigationController = viewController as? UINavigationController {
            for child in navigationController.viewControllers {
                findAndActivateSearchController(in: child)
            }
        }
        
        // Check presented view controllers
        if let presented = viewController.presentedViewController {
            findAndActivateSearchController(in: presented)
        }
        
        // Search in child view controllers
        for child in viewController.children {
            findAndActivateSearchController(in: child)
        }
        
        // Look for UISearchController in the view hierarchy
        if let searchController = findSearchController(in: viewController) {
            searchController.isActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                searchController.searchBar.becomeFirstResponder()
            }
        }
    }
    
    private func findSearchController(in viewController: UIViewController) -> UISearchController? {
        // Check if viewController is a UISearchController
        if let searchController = viewController as? UISearchController {
            return searchController
        }
        
        // Check if it has a search controller property
        if let searchController = viewController.navigationItem.searchController {
            return searchController
        }
        
        // Check in the view hierarchy for a UISearchBar
        if let searchBar = findSearchBar(in: viewController.view) {
            searchBar.becomeFirstResponder()
        }
        
        return nil
    }
    
    private func findSearchBar(in view: UIView) -> UISearchBar? {
        // Check if this view is a search bar
        if let searchBar = view as? UISearchBar {
            return searchBar
        }
        
        // Check in subviews
        for subview in view.subviews {
            if let searchBar = findSearchBar(in: subview) {
                return searchBar
            }
        }
        
        return nil
    }
}

// Add the MealGenerationCard struct after MealListView
struct MealGenerationCard: View {
    @EnvironmentObject var foodManager: FoodManager
    @State private var animateProgress = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(getStageTitle())
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
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .onAppear {
            startAnimation()
        }
    }
    
    private func getStageTitle() -> String {
        switch foodManager.analysisStage {
        case 0:
            return "Analyzing recipe description..."
        case 1:
            return "Finding matching ingredients..."
        case 2:
            return "Calculating portions..."
        case 3:
            return "Finalizing recipe creation..."
        default:
            return "Processing..."
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

// Add the FoodGenerationCard struct after MealGenerationCard

// MARK: - Saved Meal List View
private struct SavedMealListView: View {
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    let searchText: String
    
    var onItemAdded: ((Food) -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            // Add invisible spacing at the top to prevent overlap with header
            Color.clear.frame(height: 6)
            
            // Saved Meals Card - Single unified card for all saved meals
            if !foodManager.savedMeals.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("bg"))
                    
                    List {
                        ForEach(foodManager.savedMeals) { savedMeal in
                            SavedMealRow(
                                savedMeal: savedMeal,
                                selectedMeal: $selectedMeal,
                                mode: mode,
                                selectedFoods: $selectedFoods,
                                path: $path,
                                onItemAdded: onItemAdded
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color("iosfit"))
                            .listRowSeparator(.hidden)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .onDelete { indexSet in
                            deleteSavedMeals(at: indexSet)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                }
                .frame(height: min(CGFloat(foodManager.savedMeals.count * 63), UIScreen.main.bounds.height * 0.7))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            } else if foodManager.isLoadingSavedMeals {
                // Loading indicator
                ProgressView()
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image("bookmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .foregroundColor(.secondary)
                    
                    Text("No saved meals yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Swipe right on meals in Home to save them for quick access")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 60)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 16)
        .background(Color("iosbg2"))
        .onAppear {
            if foodManager.savedMeals.isEmpty && !foodManager.isLoadingSavedMeals {
                foodManager.refreshSavedMeals()
            }
        }
    }
    
    private func deleteSavedMeals(at indexSet: IndexSet) {
        print("Deleting saved meals at indices: \(indexSet)")
        
        // Get the saved meals to delete
        let savedMealsToDelete = indexSet.map { foodManager.savedMeals[$0] }
        
        // Actually delete the saved meals
        for savedMeal in savedMealsToDelete {
            foodManager.unsaveMeal(savedMealId: savedMeal.id) { result in
                switch result {
                case .success:
                    print("Successfully removed saved meal: \(savedMeal.displayName)")
                case .failure(let error):
                    print("Failed to remove saved meal: \(error)")
                }
            }
        }
    }
}

// MARK: - Recent Logs Section
private struct RecentLogsSection: View {
    let logs: [CombinedLog]
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    var onItemAdded: ((Food) -> Void)?
    
    private var limitedLogs: [CombinedLog] {
        Array(logs.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Logs")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                // .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                ForEach(Array(limitedLogs.enumerated()), id: \.element.id) { index, log in
                    if let foodItem = log.food {
                        FoodRow(
                            food: foodItem.asFood,
                            selectedMeal: $selectedMeal,
                            mode: mode,
                            selectedFoods: $selectedFoods,
                            path: $path,
                            onItemAdded: onItemAdded
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        if index < limitedLogs.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                                .padding(.trailing, 16)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("bg"))
            )
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Saved Meal Row
private struct SavedMealRow: View {
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @Environment(\.dismiss) private var dismiss
    let savedMeal: SavedMeal
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    var onItemAdded: ((Food) -> Void)?
    @State private var showLoggingErrorAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(savedMeal.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(Int(savedMeal.calories)) cal")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    if !savedMeal.mealType.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(savedMeal.mealType)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button {
                HapticFeedback.generate()
                logSavedMeal()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color("iosbg2"))
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
    }
    
    private func logSavedMeal() {
        // First, close the food container immediately
        viewModel.isShowingFoodContainer = false
        
        if savedMeal.itemType == .foodLog, let foodLog = savedMeal.foodLog {
            // Convert LoggedFoodItem back to Food for logging
            let food = foodLog.asFood
            
            foodManager.logFood(
                email: viewModel.email,
                food: food,
                meal: selectedMeal,
                servings: foodLog.numberOfServings,
                date: dayLogsVM.selectedDate,
                notes: nil
            ) { result in
                switch result {
                case .success(let loggedFood):
                    let combinedLog = CombinedLog(
                        type: .food,
                        status: loggedFood.status,
                        calories: Double(loggedFood.food.calories),
                        message: "\(loggedFood.food.displayName) – \(loggedFood.mealType)",
                        foodLogId: loggedFood.foodLogId,
                        food: loggedFood.food,
                        mealType: loggedFood.mealType,
                        mealLogId: nil,
                        meal: nil,
                        mealTime: nil,
                    scheduledAt: dayLogsVM.selectedDate,
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil,
                    isOptimistic: true
                )

                    DispatchQueue.main.async {
                        dayLogsVM.addPending(combinedLog)
                        if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                            foodManager.combinedLogs.remove(at: idx)
                        }
                        foodManager.combinedLogs.insert(combinedLog, at: 0)
                    }
                case .failure(let error):
                    print("Error logging saved food: \(error)")
                    showLoggingErrorAlert = true
                }
            }
        } else if savedMeal.itemType == .mealLog, let mealSummary = savedMeal.mealLog {
            // Convert MealSummary to Meal for logging
            let meal = Meal(
                id: mealSummary.mealId,
                title: mealSummary.title,
                description: mealSummary.description,
                directions: nil,
                privacy: "private",
                servings: mealSummary.servings,
                mealItems: [],
                image: mealSummary.image,
                totalCalories: mealSummary.calories,
                totalProtein: mealSummary.protein,
                totalCarbs: mealSummary.carbs,
                totalFat: mealSummary.fat,
                scheduledAt: dayLogsVM.selectedDate
            )
            
            foodManager.logMeal(
                meal: meal,
                mealTime: selectedMeal,
                date: dayLogsVM.selectedDate,
                calories: mealSummary.displayCalories
            ) { result in
                switch result {
                case .success(let loggedMeal):
                    let combinedLog = CombinedLog(
                        type: .meal,
                        status: loggedMeal.status,
                        calories: loggedMeal.calories,
                        message: "\(loggedMeal.meal.title) – \(loggedMeal.mealTime)",
                        foodLogId: nil,
                        food: nil,
                        mealType: loggedMeal.mealTime,
                        mealLogId: loggedMeal.mealLogId,
                        meal: loggedMeal.meal,
                        mealTime: loggedMeal.mealTime,
                    scheduledAt: dayLogsVM.selectedDate,
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil,
                    isOptimistic: true
                )
                    
                    DispatchQueue.main.async {
                        dayLogsVM.addPending(combinedLog)
                        if let idx = foodManager.combinedLogs.firstIndex(where: { $0.mealLogId == combinedLog.mealLogId }) {
                            foodManager.combinedLogs.remove(at: idx)
                        }
                        foodManager.combinedLogs.insert(combinedLog, at: 0)
                    }
                case .failure(let error):
                    print("Error logging saved meal: \(error)")
                    showLoggingErrorAlert = true
                }
            }
        }
    }
}

// MARK: - ViewModifiers

struct SearchModifiers: ViewModifier {
    func body(content: Content) -> some View {
        content
            .edgesIgnoringSafeArea(.bottom)
    }
}

struct NavigationModifiers: ViewModifier {
    let mode: LogFoodMode
    @Binding var selectedTab: Int
    let dismiss: DismissAction
    
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Group {
                    if mode != .addToMeal && mode != .addToRecipe {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                selectedTab = 0
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .accessibilityLabel("Close")
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        Text("Log Food")
                            .font(.headline)
                    }
                }
            }
            .navigationBarBackButtonHidden(mode != .addToMeal && mode != .addToRecipe)
    }
}

struct SheetModifiers: ViewModifier {
    @Binding var showQuickLogSheet: Bool
    @Binding var showConfirmFoodView: Bool
    @Binding var showCreateFoodWithVoice: Bool
    @Binding var showCreateFoodWithScan: Bool
    @ObservedObject var foodManager: FoodManager

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showQuickLogSheet) {
                QuickLogFood(isPresented: $showQuickLogSheet)
            }
            .sheet(isPresented: $showConfirmFoodView, onDismiss: {
                foodManager.lastGeneratedFood = nil
                // UNIFIED: Reset to inactive state when confirmation sheet is dismissed
                foodManager.foodScanningState = .inactive
            }) {
                if let food = foodManager.lastGeneratedFood {
                    NavigationView {
                        ConfirmFoodView(path: .constant(NavigationPath()), food: food, isAlreadyCreated: true)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCreateFoodWithVoice) {
                CreateFoodWithVoice()
            }
            .fullScreenCover(isPresented: $showCreateFoodWithScan) {
                CreateFoodWithScan()
            }
    }
}

struct LifecycleModifiers: ViewModifier {
    let selectedFoodTab: LogFood.FoodTab
    @Binding var safeAreaInset: CGFloat
    @Binding var keyboardHeight: CGFloat
    @ObservedObject var foodManager: FoodManager

    func body(content: Content) -> some View {
        content
            .onAppear {
                if foodManager.meals.isEmpty && !foodManager.isLoadingMeals {
                    foodManager.refreshMeals()
                } else {
                    foodManager.prefetchMealImages()
                }

                // Set up keyboard observers
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    safeAreaInset = window.safeAreaInsets.bottom
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        keyboardHeight = keyboardFrame.height - safeAreaInset
                    }
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    keyboardHeight = 0
                }
            }
            .onDisappear {
                // Remove keyboard observers
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
    }
}
