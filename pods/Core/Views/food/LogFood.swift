import SwiftUI

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

    var mode: LogFoodMode = .logFood 
    @Binding var selectedFoods: [Food]  
    
    // Add callback that will be called when an item is added
    var onItemAdded: ((Food) -> Void)?
    
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
                return "Search Meals"
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Something went wrong", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
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
                    selectedMeal: $selectedMeal,
                    mode: mode,
                    selectedFoods: $selectedFoods,
                    path: $path,
                    onItemAdded: onItemAdded
                )
            } else {
                switch selectedFoodTab {
                case .meals:
                    MealListView(
                        selectedMeal: $selectedMeal,
                        mode: mode,
                        selectedFoods: $selectedFoods,
                        path: $path,
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
    let searchResults: [Food]
    let isSearching: Bool
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    var onItemAdded: ((Food) -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Add invisible spacing at the top to prevent overlap with header
                Color.clear.frame(height: 8)
                
                // Quick Log Button
                Button(action: {
                    print("Tapped quick Log")
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                        Text("Quick Log")
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
                
                // Main content card
                if searchResults.isEmpty && !isSearching {
                    VStack(spacing: 0) {
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
                                            foodManager.loadMoreIfNeeded(log: log)
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
                                            foodManager.loadMoreIfNeeded(log: log)
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
                                    .onAppear {
                                        if case .food = log.type {
                                            print("FoodListView: Adding divider after food at index \(index)")
                                        } else if case .meal = log.type {
                                            print("FoodListView: Adding divider after meal at index \(index)")
                                        }
                                    }
                            }
                        }
                    }
                    .onAppear {
                        print("FoodListView: Starting to render combined logs")
                    }
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                } else {
                    VStack(spacing: 0) {
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
    }
}

private struct CreateMealButton: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        Button(action: {
            path.append(FoodNavigationDestination.createMeal)
        }) {
            HStack(spacing: 16) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                Text("Create Meal")
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

// MEAL LIST VIEW -- CHANGED to unify divider usage
private struct MealListView: View {
    @EnvironmentObject var foodManager: FoodManager
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    var onItemAdded: ((Food) -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Add invisible spacing at the top to prevent overlap with header
                Color.clear.frame(height: 8)
                
                // Create Meal Button
                CreateMealButton(path: $path)
                    .padding(.top, 0)
                
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
                    if !food.servingSizeText.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(food.servingSizeText)
                            .foregroundColor(.secondary)
                    }
                    if let brand = food.brandText {
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
                withAnimation { 
                    checkmarkVisible = true 
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { 
                        checkmarkVisible = false
                    }
                }
                
            case .failure(let error):
                print("Error logging food: \(error)")
                
                withAnimation {
                    if self.foodManager.lastLoggedFoodId == self.food.fdcId {
                        self.foodManager.lastLoggedFoodId = nil
                    }
                    self.checkmarkVisible = false
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
