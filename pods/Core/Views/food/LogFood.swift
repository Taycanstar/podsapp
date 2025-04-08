import SwiftUI
import Combine

struct LogFood: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
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
    

    var mode: LogFoodMode = .logFood 
    @Binding var selectedFoods: [Food]  
    
    // Add callback that will be called when an item is added
    var onItemAdded: ((Food) -> Void)?
    @State private var showQuickLogSheet = false
    
    enum FoodTab: Hashable {
        case all, meals, foods
        
        var title: String {
            switch self {
            case .all: return "All"
            case .meals: return "My Meals"
            case .foods: return "My Foods"
            }
        }
        
        var searchPrompt: String {
            switch self {
            case .all, .foods:
                return "Describe what you ate"
            case .meals:
                return "Describe your meal"
            }
        }
    }
    
    let foodTabs: [FoodTab] = [.all, .meals, .foods]
    
    // IMPORTANT: Keep init argument order exactly the same
    init(selectedTab: Binding<Int>, 
         selectedMeal: Binding<String>, 
         path: Binding<NavigationPath>,
         mode: LogFoodMode = .logFood,
         selectedFoods: Binding<[Food]>,
         onItemAdded: ((Food) -> Void)? = nil) 
    {
        _selectedTab = selectedTab
        _path = path
        _selectedMeal = selectedMeal
        self.mode = mode
        _selectedFoods = selectedFoods
        self.onItemAdded = onItemAdded
    }
    
    var body: some View {
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
            .edgesIgnoringSafeArea(.bottom)  // Only ignore bottom safe area
            .searchable(
                text: $searchText, 
                placement: .navigationBarDrawer(displayMode: .always), 
                prompt: selectedFoodTab.searchPrompt
            )
            .focused($isSearchFieldFocused)
            .onChange(of: searchText) { _ in
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await searchFoods()
                }
            }
            .onAppear {
                if foodManager.meals.isEmpty && !foodManager.isLoadingMeals {
                    foodManager.refreshMeals()
                } else {
                    foodManager.prefetchMealImages()
                }
                
                if foodManager.recipes.isEmpty {
                    foodManager.refresh()
                }
                
                foodManager.refresh()
                
                // Set focus to the search field after a slight delay
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    isSearchFieldFocused = true
                    activateSearch = true
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Something went wrong", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .background(
                SearchActivator(isActivated: $activateSearch)
            )
            .sheet(isPresented: $showQuickLogSheet) {
                QuickLogFood(isPresented: $showQuickLogSheet)
            }

            toastMessages
        }
        .navigationBarBackButtonHidden(mode != .addToMeal && mode != .addToRecipe)
    }
    
    // MARK: - Subviews
    
    private var tabHeaderView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(foodTabs, id: \.self) { tab in
                    TabButton(tab: tab, selectedTab: $selectedFoodTab)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
    }
    
    private var mainContentView: some View {
        Group {
            if selectedFoodTab == .all || selectedFoodTab == .foods {
                FoodListView(
                    searchResults: searchResults,
                    isSearching: isSearching,
                    searchText: searchText,
                    selectedFoodTab: selectedFoodTab,
                    selectedMeal: $selectedMeal,
                    mode: mode,
                    selectedFoods: $selectedFoods,
                    path: $path,
                    showQuickLogSheet: $showQuickLogSheet
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
                    Button("Cancel") {
                        selectedTab = 0
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
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
        Group {
            if foodManager.showToast {
                BottomPopup(message: "Food logged")
            }
            if foodManager.showMealToast {
                BottomPopup(message: "Meal created")
            }
            if foodManager.showMealLoggedToast {
                BottomPopup(message: "Meal logged")
            }
            if foodManager.showRecipeLoggedToast {
                BottomPopup(message: "Recipe logged")
            }
        }
    }
    
    // MARK: - Search
    private func searchFoods() async {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        do {
            let response = try await FoodService.shared.searchFoods(query: searchText)
            searchResults = response.foods
        } catch {
            print("Search error:", error)
            searchResults = []
        }
        isSearching = false
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
    let searchResults: [Food]
    let isSearching: Bool
    let searchText: String
    let selectedFoodTab: LogFood.FoodTab
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    @Binding var showQuickLogSheet: Bool
    
    // Add states for AI generation
    @State private var isGeneratingMacros = false
    @State private var showAIErrorAlert = false
    @State private var aiErrorMessage = ""
    
    var onItemAdded: ((Food) -> Void)?
    
    @State private var isShowingMinimumLoader = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Add invisible spacing at the top to prevent overlap with header
                Color.clear.frame(height: 6)
                
                // Show Quick Log button when there's no search text
                if searchText.isEmpty {
                    // Quick Log Button
                    Button(action: {
                        print("Tapped quick Log")
                        HapticFeedback.generateLigth()
                        showQuickLogSheet = true
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
                else if selectedFoodTab == .all {
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
                            case .success(_):
                                // Success is handled by FoodManager (shows toast, updates lists)
                                print("Successfully generated macros with AI")
                                
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
                    .overlay(
                        isGeneratingMacros ? 
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8)
                         : nil
                    )
                }
                // Show Generate Meal with AI button when there's search text in the .meals tab
                else if selectedFoodTab == .meals && !searchText.isEmpty {
                    Button(action: {
                        print("generating meal with ai...")
                        HapticFeedback.generateLigth()
                    }) {
                        HStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "sparkle")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                            Text("Generate Meal with AI")
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
                
                // Main content card
                
                if searchResults.isEmpty && !isSearching {
                    LazyVStack(spacing: 0) {
                        // Process logs to remove empty/invalid entries
                        let validLogs = foodManager.combinedLogs.filter { log in
                            if case .food = log.type, log.food != nil { return true }
                            if case .meal = log.type, log.meal != nil { return true }
                            return false
                        }
                        
                        ForEach(Array(validLogs.enumerated()), id: \.element.id) { index, log in
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
                                            print("FoodListView: Rendering food row for \(food.displayName) at index \(index)")
                                            
                                            // If we're close to the end of the list, automatically load more
                                            if index >= validLogs.count - 1 && foodManager.hasMore && !foodManager.isLoadingLogs {
                                                print("🔄 Auto-loading more logs at index \(index)")
                                                HapticFeedback.generateLigth()
                                                showMinimumLoader()
                                                foodManager.loadMoreLogs()
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
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
                                        .onAppear {
                                            print("FoodListView: Rendering meal row for \(meal.title) at index \(index)")
                                            
                                            // If we're close to the end of the list, automatically load more
                                            if index >= validLogs.count - 1 && foodManager.hasMore && !foodManager.isLoadingLogs {
                                                print("🔄 Auto-loading more logs at index \(index)")
                                                HapticFeedback.generateLigth()
                                                showMinimumLoader()
                                                foodManager.loadMoreLogs()
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                case .recipe:
                                    EmptyView()
                                }
                            }
                            
                            // Add divider after every item except the last one
                            if index < validLogs.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    // Show a single loader at the bottom when loading more logs
                    if foodManager.isLoadingLogs && foodManager.hasMore || isShowingMinimumLoader {
                        VStack {
                            ProgressView()
                                .padding(.vertical, 8)
                            
                        }
                        .padding(.top, 8)
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults.indices, id: \.self) { index in
                            let food = searchResults[index]
                            
                            FoodRow(
                                food: food,
                                selectedMeal: $selectedMeal,
                                mode: mode,
                                selectedFoods: $selectedFoods,
                                path: $path,
                                onItemAdded: onItemAdded
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            if index < searchResults.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }
            }
        }
        .alert("AI Generation Error", isPresented: $showAIErrorAlert) {
            Button("OK", role: .cancel) { showAIErrorAlert = false }
        } message: {
            Text(aiErrorMessage)
        }
    }
    
    private func showMinimumLoader() {
        isShowingMinimumLoader = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isShowingMinimumLoader = false
        }
    }
}

private struct CreateMealButton: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        // Button(action: {
        //     path.append(FoodNavigationDestination.createMeal)
        // }) {
        //     HStack(spacing: 16) {
        //         Image(systemName: "plus.circle.fill")
        //             .font(.system(size: 24))
        //             .foregroundColor(.accentColor)
        //         Text("Create Meal")
        //             .font(.system(size: 16))
        //             .foregroundColor(.accentColor)
                
        //         Spacer()
        //     }
        //     .padding(.horizontal, 16)
        //     .padding(.vertical, 12)
        //     .frame(maxWidth: .infinity, alignment: .leading)
        //     .background(Color("iosfit"))
        //     .cornerRadius(12)
        // }
        // .padding(.horizontal)
        // .padding(.top, 0)


        
                    // Quick Log Button
                    Button(action: {
                        print("Tapped Create Meal")
                        HapticFeedback.generateLigth()
                         path.append(FoodNavigationDestination.createMeal)
                    }) {
                        HStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                            Text("Create Meal")
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
}

// MEAL LIST VIEW -- CHANGED to unify divider usage
private struct MealListView: View {
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
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
                            Text("Generate Meal with AI")
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
                    .overlay(
                        foodManager.isGeneratingMeal ? 
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8)
                         : nil
                    )
                } 
                // Show Create Meal button when no search text
                else {
                    // Create Meal Button
                    CreateMealButton(path: $path)
                        .padding(.top, 0)
                }

                  // Show meal generation card if analysis is in progress
                if foodManager.isGeneratingMeal {
                    MealGenerationCard()
                        .padding(.horizontal)
                        .transition(.opacity)
                }
                
                // Meals Card - Single unified card for all meals
                if !foodManager.meals.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(foodManager.meals.indices, id: \.self) { index in
                            let meal = foodManager.meals[index]
                            
                            MealRow(
                                meal: meal,
                                selectedMeal: $selectedMeal,
                                mode: mode,
                                selectedFoods: $selectedFoods,
                                path: $path,
                                onItemAdded: onItemAdded
                            )
                            .onAppear {
                                print("MealListView: Rendering meal at index \(index): \(meal.title)")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            if index < foodManager.meals.count - 1 {
                                Divider()
                                    .padding(.leading, 16)
                                    .onAppear {
                                        print("MealListView: Adding divider after index \(index)")
                                    }
                            }
                        }
                    }
                    .background(Color("iosfit"))
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
                        Text("\(meal.title) created")
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.bottom, 20)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: foodManager.showMealGenerationSuccess)
                }
            }
        )
        .alert("AI Generation Error", isPresented: $showAIErrorAlert) {
            Button("OK", role: .cancel) { showAIErrorAlert = false }
        } message: {
            Text(aiErrorMessage)
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
                    
                    if !food.servingSizeText.isEmpty && !isDefaultServing {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(food.servingSizeText)
                            .foregroundColor(.secondary)
                    }
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
            date: Date(),
            notes: nil
        ) { result in
            switch result {
            case .success(let loggedFood):
                print("Food logged successfully: \(loggedFood)")
                // Success is handled by FoodManager (shows toast, updates lists)
                
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
            case .recipe:
                EmptyView()
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
                            scheduledAt: nil
                        ), 
                        mealTime: selectedMeal,
                        calories: log.displayCalories,
                        statusCompletion: { success in
                            if !success {
                                withAnimation {
                                    if self.foodManager.lastLoggedMealId == self.meal.id {
                                        self.foodManager.lastLoggedMealId = nil
                                    }
                                }
                                showLoggingErrorAlert = true
                            }
                        }
                    )
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
                        calories: displayCalories
                    ) { success in
                        if !success {
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            startAnimation()
        }
    }
    
    private func getStageTitle() -> String {
        switch foodManager.analysisStage {
        case 0:
            return "Analyzing meal description..."
        case 1:
            return "Finding matching ingredients..."
        case 2:
            return "Calculating portions..."
        case 3:
            return "Finalizing meal creation..."
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


