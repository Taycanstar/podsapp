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
                return "Search Food"
            case .meals:
                return "Search Meals"
            }
        }
    }
    
    let foodTabs: [FoodTab] = [.all, .meals, .foods]
    
    init(selectedTab: Binding<Int>, 
         selectedMeal: Binding<String>, 
         path: Binding<NavigationPath>,
         mode: LogFoodMode = .logFood,
         selectedFoods: Binding<[Food]>,
         onItemAdded: ((Food) -> Void)? = nil) {
        _selectedTab = selectedTab
        _path = path
        _selectedMeal = selectedMeal
        self.mode = mode
        _selectedFoods = selectedFoods
        self.onItemAdded = onItemAdded
    }
    
    var body: some View {
          ZStack(alignment: .bottom) {
        VStack(spacing: 0) {
                tabHeaderView
                Divider()
                mainContentView
                Spacer()
            }
            .edgesIgnoringSafeArea(.horizontal)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: selectedFoodTab.searchPrompt)
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
                HStack(spacing: 35) {
                    ForEach(foodTabs, id: \.self) { tab in
                    TabButton(tab: tab, selectedTab: $selectedFoodTab)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
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
                MealPickerMenu(selectedMeal: $selectedMeal)
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
    
    var body: some View {
                        VStack(spacing: 8) {
                            Text(tab.title)
                                .font(.system(size: 17))
                                .fontWeight(.semibold)
                .foregroundColor(selectedTab == tab ? .primary : .gray)
                            Rectangle()
                                .frame(height: 2)
                .foregroundColor(selectedTab == tab ? .accentColor : .clear)
                        }
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                selectedTab = tab
            }
        }
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
    
    // Add onItemAdded callback
    var onItemAdded: ((Food) -> Void)?
    
    var body: some View {
        List {
            if searchResults.isEmpty && !isSearching {
                Section {
                    ForEach(foodManager.combinedLogs, id: \.id) { log in
                        HistoryRow(
                            log: log,
                            selectedMeal: $selectedMeal,
                            mode: mode,
                            selectedFoods: $selectedFoods,
                            path: $path,
                            onItemAdded: onItemAdded
                        )
                        .onAppear {
                            foodManager.loadMoreIfNeeded(log: log)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                }
                .listSectionSeparator(.hidden)
            } else {
                ForEach(searchResults) { food in
                    FoodRow(
                        food: food,
                        selectedMeal: $selectedMeal,
                        mode: mode,
                        selectedFoods: $selectedFoods,
                        path: $path,
                        onItemAdded: onItemAdded
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 60)
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
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
         .padding(.horizontal)
        .padding(.top)
    }
}

private struct MealListView: View {
    @EnvironmentObject var foodManager: FoodManager
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    // Add onItemAdded callback
    var onItemAdded: ((Food) -> Void)?
    
    var body: some View {
        List {
            CreateMealButton(path: $path)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)

            Text("History")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 8)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            
            ForEach(foodManager.meals) { meal in
                MealRow(
                    meal: meal,
                    selectedMeal: $selectedMeal,
                    mode: mode,
                    selectedFoods: $selectedFoods,
                    path: $path,
                    onItemAdded: onItemAdded
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70)
        }
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
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
         .padding(.horizontal)
        .padding(.top)
    }
}

private struct RecipeListView: View {
    @EnvironmentObject var foodManager: FoodManager
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    // Add onItemAdded callback
    var onItemAdded: ((Food) -> Void)?
    
    var body: some View {
        List {
            CreateRecipeButton(path: $path)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
            
            RecipeHistorySection(
                selectedMeal: $selectedMeal,
                mode: mode,
                selectedFoods: $selectedFoods,
                path: $path,
                onItemAdded: onItemAdded
            )
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 60)
        }
    }
}

struct FoodRow: View {
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    let food: Food
    let selectedMeal: Binding<String>
    @State private var checkmarkVisible: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // Add a specific state for logging errors
    @State private var showLoggingErrorAlert: Bool = false

    // Add these properties
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath 
    
    // Add the onItemAdded callback
    var onItemAdded: ((Food) -> Void)?

    var body: some View {
        ZStack {
            NavigationLink(value: FoodNavigationDestination.foodDetails(food, selectedMeal)) {
                EmptyView()
            }
            .opacity(0)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    HStack {
                        Image(systemName: "flame.fill")
                            .padding(.trailing, 4)
                        if let calories = food.calories {
                            Text("\(Int(calories)) cal")
                        }
                        Text("•")
                        Text(food.servingSizeText)
                        if let brand = food.brandText {
                            Text("•")
                            Text(brand)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.primary)
                }
                
                Spacer() // Push the button to the right edge
                
                // Fixed-width container for the button
                HStack {
                    Spacer() // Center the button within the container
                
                Button {
                    HapticFeedback.generate()
                    handleFoodTap()
                } label: {
                        switch mode {
                        case .addToMeal, .addToRecipe:
                                if foodManager.recentlyAddedFoodIds.contains(food.fdcId) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color("bg"))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                        case .logFood:
                        if foodManager.lastLoggedFoodId == food.fdcId {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                                .transition(.opacity)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color("bg"))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                    .frame(width: 44, height: 44) // Fixed size for the button
                    .contentShape(Rectangle())
            }
                .frame(width: 44) // Fixed width for the button container
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)  // Reduced from 12
            .background(Color("iosbg"))
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)  // Reduced from 4
        .alert("Something went wrong", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        // Add a specific logging error alert
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
            // Create a new mutable Food object with the same properties
            let newFood = Food(
                fdcId: food.fdcId,
                description: food.description,
                brandOwner: food.brandOwner,
                brandName: food.brandName,
                servingSize: food.servingSize,
                numberOfServings: 1, // Always start with 1 serving
                servingSizeUnit: food.servingSizeUnit,
                householdServingFullText: food.householdServingFullText,
                foodNutrients: food.foodNutrients,
                foodMeasures: food.foodMeasures
            )
            
            // Debug before adding
            print("📝 Adding food to selection: \(newFood.displayName)")
            print("📊 Current selection count: \(selectedFoods.count)")
            
            // Create a completely new array to force binding update
            var updatedFoods = [Food]()
            // Add all existing foods
            for existingFood in selectedFoods {
                updatedFoods.append(existingFood)
            }
            // Add the new food
            updatedFoods.append(newFood)
            
            // Replace the entire array to force binding is triggered
            selectedFoods = updatedFoods
            
            // Debug after adding
            print("✅ Food added to selection, new count: \(selectedFoods.count)")
            print("📋 Current foods in selection:")
            for (index, item) in selectedFoods.enumerated() {
                print("  \(index+1). \(item.displayName)")
            }
            
            // Track recently added food
            foodManager.trackRecentlyAdded(foodId: food.fdcId)
            
            // Call the onItemAdded callback if provided - this will close the sheet
            // If we're not in a sheet context, fall back to navigation path handling
            if let callback = onItemAdded {
                print("📲 Using callback to close sheet after adding item")
                callback(newFood)
            } else if !path.isEmpty {
                print("👈 Using navigation path to go back after adding item")
                path.removeLast()
            }
        }
    }
    
    private func logFood() {
        // Track the request is in progress locally to prevent multiple taps
        let isRequestInProgress = true
        
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
                
                // Clear the checkmark after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { 
                        checkmarkVisible = false
                         }
                }
                
            case .failure(let error):
                print("Error logging food: \(error)")
                
                // Make sure we immediately clear any green checkmark
                withAnimation {
                    // Ensure the food manager's lastLoggedFoodId is cleared
                    if self.foodManager.lastLoggedFoodId == self.food.fdcId {
                        self.foodManager.lastLoggedFoodId = nil
                    }
                    
                    // Reset local checkmark state
                    self.checkmarkVisible = false
                }
                
                // Show the specific logging error alert
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
    
    // Add the onItemAdded callback
    var onItemAdded: ((Food) -> Void)?
    
    var body: some View {
        switch log.type {
        case .food:
            if let food = log.food {
                FoodRow(
                    food: food.asFood, // Make sure LoggedFoodItem has an asFood property
                    selectedMeal: $selectedMeal,
                    mode: mode,
                    selectedFoods: $selectedFoods,
                    path: $path,
                    onItemAdded: onItemAdded
                )
            }
        case .meal:
            if let meal = log.meal {
                // Pass all parameters to CombinedLogMealRow
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
            // Return empty view for recipe cases since we don't want to show them
            EmptyView()
        }
    }
}

// New row that shows displayCalories from the combined log
struct CombinedLogMealRow: View {
    @EnvironmentObject var foodManager: FoodManager
    let log: CombinedLog
    let meal: MealSummary
    @Binding var selectedMeal: String
    
    // Add these properties to match FoodRow
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    // Add the onItemAdded callback
    var onItemAdded: ((Food) -> Void)?
    
    // Add state for logging error alert
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
        ZStack {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.title.isEmpty ? "Untitled Meal" : meal.title)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .padding(.trailing, 4)
                    Text("\(Int(log.displayCalories)) cal")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                }
                
                Spacer() // Push the button to the right edge
                
                // Fixed-width container for the button
                HStack {
                    Spacer() // Center the button within the container
                    
                    Button {
                        HapticFeedback.generate()
                        
                        switch mode {
                        case .logFood:
                            // Original behavior - log the meal
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
                                        // Ensure the food manager's lastLoggedMealId is cleared
                                        withAnimation {
                                            if self.foodManager.lastLoggedMealId == self.meal.id {
                                                self.foodManager.lastLoggedMealId = nil
                                            }
                                        }
                                        
                                        // Show error alert
                                        showLoggingErrorAlert = true
                                    }
                                }
                            )
                        
                        case .addToMeal, .addToRecipe:
                            // Add meal items to selection
                            addMealItemsToSelection()
                        }
                    } label: {
                        if mode == .addToMeal {
                            // Similar to FoodRow's addToMeal mode
                            ZStack {
                                Circle()
                                    .fill(Color("bg"))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        } else {
                            // Original behavior for logFood mode
                            if foodManager.lastLoggedMealId == meal.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                    .transition(.opacity)
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color("bg"))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 44, height: 44)  // Fixed size for the button
                    .contentShape(Rectangle())
                    .zIndex(1) // Keep button on top
                }
                .frame(width: 44) // Fixed width for the button container
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)  // Reduced from 12
            .background(Color("iosbg"))
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                // Find the full meal from FoodManager.meals
                if let fullMeal = foodManager.meals.first(where: { $0.id == meal.id }) {
                    // Navigate to MealDetailView with the full meal
                    path.append(FoodNavigationDestination.mealDetails(fullMeal))
                } else {
                    // Create a minimal meal object to show if we can't find the full meal
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
        .padding(.horizontal, 16)
        .padding(.vertical, 0)  // Reduced from 4
        // Add a specific logging error alert
        .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
    }
    
    // Add this method to add meal items to selection using already loaded meals
    private func addMealItemsToSelection() {
        // Try to find the full meal from FoodManager to get access to mealItems
        if let fullMeal = foodManager.meals.first(where: { $0.id == meal.id }) {
            // Track the last food added for callback
            var lastAddedFood: Food? = nil
            
            for mealItem in fullMeal.mealItems {
                // Try to extract numeric value from servings string
                let servingsValue = Double(mealItem.servings.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 1.0
                
                // Get the proper serving text - use the serving_text if available
                let servingText: String
                if let text = mealItem.servingText, !text.isEmpty {
                    servingText = text
                } else {
                    // Get the unit of measurement, if any
                    if let unit = mealItem.servings.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))).last,
                       !unit.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                        servingText = unit.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    } else {
                        servingText = "serving"
                    }
                }

                
                // Create a Food object from the MealFoodItem
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
                
                // Add to selection
                selectedFoods.append(food)
                lastAddedFood = food
            }
            
            // Use callback if available, otherwise fall back to path
            if let callback = onItemAdded, let lastFood = lastAddedFood {
                print("📲 Using callback to close sheet after adding meal items")
                callback(lastFood)
            } else if !path.isEmpty {
                print("👈 Using navigation path to go back after adding meal items")
                path.removeLast()
            }
        } else {
            // If we couldn't find the meal, navigate back
            if !path.isEmpty {
                path.removeLast()
            }
        }
    }
}

struct MealHistoryRow: View {
    @EnvironmentObject var foodManager: FoodManager
    let meal: MealSummary  // Changed from Meal to MealSummary since that's what we get from the log
    @Binding var selectedMeal: String
    
    // Add state for logging error alert
    @State private var showLoggingErrorAlert: Bool = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.title.isEmpty ? "Untitled Meal" : meal.title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text("\(Int(meal.displayCalories)) cal")
                            .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer() // Push the button to the right edge
            
            // Fixed-width container for the button
            HStack {
                Spacer() // Center the button within the container
                
                Button {
                    HapticFeedback.generate()
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
                            totalCalories: meal.displayCalories, 
                            totalProtein: nil, 
                            totalCarbs: nil, 
                            totalFat: nil, 
                            scheduledAt: meal.scheduledAt
                        ), 
                        mealTime: selectedMeal,
                        calories: meal.displayCalories,
                        statusCompletion: { success in
                            if !success {
                                // Ensure the food manager's lastLoggedMealId is cleared
                                withAnimation {
                                    if self.foodManager.lastLoggedMealId == self.meal.id {
                                        self.foodManager.lastLoggedMealId = nil
                                    }
                                }
                                
                                // Show error alert
                                showLoggingErrorAlert = true
                            }
                        }
                    )
                } label: {
                    if foodManager.lastLoggedMealId == meal.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 44, height: 44) // Fixed size for the button
                .contentShape(Rectangle())
            }
            .frame(width: 44) // Fixed width for the button container
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
        // Add a specific logging error alert
        .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
    }
}

struct MealRow: View {
    @EnvironmentObject var foodManager: FoodManager
    let meal: Meal
    @Binding var selectedMeal: String
    
    // Add these properties to match CombinedMealRow
    var mode: LogFoodMode = .logFood  // Default to logFood mode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    // Add the onItemAdded callback
    var onItemAdded: ((Food) -> Void)?
    
    // Add state for logging error alert
    @State private var showLoggingErrorAlert: Bool = false
    
    // Make these optional bindings with default values
    init(meal: Meal, 
         selectedMeal: Binding<String>, 
         mode: LogFoodMode = .logFood, 
         selectedFoods: Binding<[Food]> = .constant([]), 
         path: Binding<NavigationPath> = .constant(NavigationPath()),
         onItemAdded: ((Food) -> Void)? = nil) {
        self.meal = meal
        self._selectedMeal = selectedMeal
        self.mode = mode
        self._selectedFoods = selectedFoods
        self._path = path
        self.onItemAdded = onItemAdded
    }
    
    // Computed property to calculate calories from meal items if needed
    private var displayCalories: Double {
        if meal.calories > 0 {
            return meal.calories
        }
        
        // If meal.calories is 0 but we have meal items, calculate from items
        if !meal.mealItems.isEmpty {
            let totalItemCalories = meal.mealItems.reduce(0) { sum, item in
                sum + item.calories
            }
            if totalItemCalories > 0 {
                return totalItemCalories
            }
        }
        
        // Fallback to calculating from macros
        if (meal.protein + meal.carbs + meal.fat) > 0 {
            // Rough estimate: protein and carbs = 4 cal/g, fat = 9 cal/g
            return (meal.protein * 4) + (meal.carbs * 4) + (meal.fat * 9)
        }
        
        return meal.calories // fallback to original value
    }
    
    var body: some View {
        ZStack {
            HStack(alignment: .center, spacing: 12) {
                // If meal has an image, display it
                if let imageUrl = meal.image, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let loadedImage):
                            loadedImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 40))
                                .frame(width: 50, height: 50)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // Display a default system icon if no image
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 40))
                        .frame(width: 50, height: 50)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.title.isEmpty ? "Untitled Meal" : meal.title)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .padding(.trailing, 4)
                    Text("\(Int(displayCalories)) cal")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                }
                
                Spacer() // Push the button to the right edge
                
                // Fixed-width container for the button
                HStack {
                    Spacer() // Center the button within the container
                    
                    Button {
                        HapticFeedback.generate()
                        
                        // Switch behavior based on mode
                        switch mode {
                        case .logFood:
                            // Original behavior - log the meal
                            foodManager.logMeal(
                                meal: meal, 
                                mealTime: selectedMeal,
                                calories: displayCalories,
                                statusCompletion: { success in
                                    if !success {
                                        // Ensure the food manager's lastLoggedMealId is cleared
                                        withAnimation {
                                            if self.foodManager.lastLoggedMealId == self.meal.id {
                                                self.foodManager.lastLoggedMealId = nil
                                            }
                                        }
                                        
                                        // Show error alert
                                        showLoggingErrorAlert = true
                                    }
                                }
                            )
                        
                        case .addToMeal, .addToRecipe:
                            // Add meal items to selection
                            addMealItemsToSelection()
                        }
                    } label: {
                        if mode == .addToMeal {
                            // For add to meal mode
                            ZStack {
                                Circle()
                                    .fill(Color("bg"))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        } else {
                            // For log food mode
                            if foodManager.lastLoggedMealId == meal.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                    .transition(.opacity)
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color("bg"))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .frame(width: 44)
                .zIndex(1)  // Keep button on top
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)  // Reduced from 12
            .background(Color("iosbg"))
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                // Only navigate to MealDetailView when in logFood mode
                if mode == .logFood {
                    path.append(FoodNavigationDestination.mealDetails(meal))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)  // Reduced from 4
        // Add a specific logging error alert
        .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }
    
    // Update this method to handle adding meal items to selection
    private func addMealItemsToSelection() {
        // Try to find the full meal from FoodManager to get access to mealItems
        if let fullMeal = foodManager.meals.first(where: { $0.id == meal.id }) {
            // Track the last food added for callback
            var lastAddedFood: Food? = nil
            
            for mealItem in fullMeal.mealItems {
                // Try to extract numeric value from servings string
                let servingsValue = Double(mealItem.servings.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 1.0
                
                // Get the proper serving text - use the serving_text if available
                let servingText: String
                if let text = mealItem.servingText, !text.isEmpty {
                    servingText = text
                } else {
                    // Get the unit of measurement, if any
                    if let unit = mealItem.servings.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))).last,
                       !unit.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                        servingText = unit.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    } else {
                        servingText = "serving"
                    }
                }

                
                // Create a Food object from the MealFoodItem
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
                
                // Add to selection
                selectedFoods.append(food)
                lastAddedFood = food
            }
            
            // Use callback if available, otherwise fall back to path
            if let callback = onItemAdded, let lastFood = lastAddedFood {
                print("📲 Using callback to close sheet after adding meal items")
                callback(lastFood)
            } else if !path.isEmpty {
                print("👈 Using navigation path to go back after adding meal items")
                path.removeLast()
            }
        } else {
            // If we couldn't find the meal, navigate back
            if !path.isEmpty {
                path.removeLast()
            }
        }
    }
}
struct CombinedLogRecipeRow: View {
    @EnvironmentObject var foodManager: FoodManager
    let log: CombinedLog
    let recipe: RecipeSummary
    @Binding var selectedMeal: String

    // These properties match the meal version
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath

    // Optional callback for when an item is added
    var onItemAdded: ((Food) -> Void)?

    // State to handle logging error alert
    @State private var showLoggingErrorAlert: Bool = false

    init(log: CombinedLog,
         recipe: RecipeSummary,
         selectedMeal: Binding<String>,
         mode: LogFoodMode = .logFood,
         selectedFoods: Binding<[Food]> = .constant([]),
         path: Binding<NavigationPath> = .constant(NavigationPath()),
         onItemAdded: ((Food) -> Void)? = nil) {
        self.log = log
        self.recipe = recipe
        self._selectedMeal = selectedMeal
        self.mode = mode
        self._selectedFoods = selectedFoods
        self._path = path
        self.onItemAdded = onItemAdded
    }

    var body: some View {
        ZStack {
            HStack(spacing: 16) {
                // Recipe details
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title.isEmpty ? "Untitled Recipe" : recipe.title)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    HStack(spacing: 4) {
                        Text("\(Int(log.displayCalories)) cal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                Spacer()
                // Button area
                HStack {
                    Spacer()
                    Button {
                        HapticFeedback.generate()
                        switch mode {
                        case .logFood:
                            // Log the recipe by creating a new Recipe (without items)
                            foodManager.logRecipe(
                                recipe: Recipe(
                                    id: recipe.recipeId,
                                    title: recipe.title,
                                    description: recipe.description,
                                    instructions: nil,
                                    privacy: "private",
                                    servings: recipe.servings,
                                    createdAt: Date(),
                                    updatedAt: Date(),
                                    recipeItems: [],
                                    image: recipe.image,
                                    prepTime: recipe.prepTime,
                                    cookTime: recipe.cookTime,
                                    totalCalories: recipe.calories,
                                    totalProtein: recipe.protein,
                                    totalCarbs: recipe.carbs,
                                    totalFat: recipe.fat,
                                    scheduledAt: nil
                                ),
                                mealTime: selectedMeal,
                               
                                date: Date(),
                                notes: nil,
                                calories: recipe.calories,
                                statusCompletion: { success in
                                    if success {
                                        withAnimation {
                                            self.foodManager.lastLoggedRecipeId = 0
                                        }
                                    } else {
                                        showLoggingErrorAlert = true
                                    }
                                }
                            )
                        case .addToMeal, .addToRecipe:
                            addRecipeItemsToSelection()
                        }
                    } label: {
                        if mode == .addToMeal || mode == .addToRecipe {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                        } else {
                            if foodManager.lastLoggedRecipeId == recipe.recipeId {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                    .transition(.opacity)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .zIndex(1)
                }
                .frame(width: 44)
            }
            .padding(.horizontal, 16)
            // .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if mode == .logFood {
                    if let fullRecipe = foodManager.recipes.first(where: { $0.id == recipe.recipeId }) {
                        path.append(FoodNavigationDestination.recipeDetails(fullRecipe))
                    }
                } else {
                    handleRecipeTap()
                }
            }
        }
        .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
    }

    private func handleRecipeTap() {
        HapticFeedback.generate()
        switch mode {
        case .logFood:
            foodManager.logRecipe(
                recipe: Recipe(
                    id: recipe.recipeId,
                    title: recipe.title,
                    description: recipe.description,
                    instructions: nil,
                    privacy: "private",
                    servings: recipe.servings,
                    createdAt: Date(),
                    updatedAt: Date(),
                    recipeItems: [],
                    image: recipe.image,
                    prepTime: recipe.prepTime,
                    cookTime: recipe.cookTime,
                    totalCalories: recipe.calories,
                    totalProtein: recipe.protein,
                    totalCarbs: recipe.carbs,
                    totalFat: recipe.fat,
                    scheduledAt: nil
                ),
                mealTime: selectedMeal,
                date: Date(),
                notes: nil,
                calories: recipe.calories,
                statusCompletion: { success in
                    if success {
                        withAnimation {
                            self.foodManager.lastLoggedRecipeId = 0
                        }
                    } else {
                        showLoggingErrorAlert = true
                    }
                }
            )
        case .addToMeal, .addToRecipe:
            addRecipeItemsToSelection()
        }
    }

    private func addRecipeItemsToSelection() {
        if let fullRecipe = foodManager.recipes.first(where: { $0.id == recipe.id }) {
            var lastAddedFood: Food? = nil
            for recipeItem in fullRecipe.recipeItems {
                let food = Food(
                    fdcId: recipeItem.foodId,
                    description: recipeItem.name,
                    brandOwner: nil,
                    brandName: nil,
                    servingSize: 1.0,
                    numberOfServings: 1.0,
                    servingSizeUnit: recipeItem.servingText,
                    householdServingFullText: recipeItem.servings,
                    foodNutrients: [
                        Nutrient(nutrientName: "Energy", value: recipeItem.calories, unitName: "kcal"),
                        Nutrient(nutrientName: "Protein", value: recipeItem.protein, unitName: "g"),
                        Nutrient(nutrientName: "Carbohydrate, by difference", value: recipeItem.carbs, unitName: "g"),
                        Nutrient(nutrientName: "Total lipid (fat)", value: recipeItem.fat, unitName: "g")
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

// Add a new struct for recipe logs
// struct CombinedLogRecipeRow: View {
//     @EnvironmentObject var foodManager: FoodManager
//     let log: CombinedLog
//     let recipe: RecipeSummary
//     @Binding var selectedMeal: String
    
//     // Add these properties
//     let mode: LogFoodMode
//     @Binding var selectedFoods: [Food]
//     @Binding var path: NavigationPath
    
//     // Add onItemAdded callback
//     var onItemAdded: ((Food) -> Void)?
    
//     // Add state for logging error alert
//     @State private var showLoggingErrorAlert: Bool = false
    
//     init(log: CombinedLog, 
//          recipe: RecipeSummary, 
//          selectedMeal: Binding<String>, 
//          mode: LogFoodMode = .logFood, 
//          selectedFoods: Binding<[Food]> = .constant([]), 
//          path: Binding<NavigationPath> = .constant(NavigationPath()),
//          onItemAdded: ((Food) -> Void)? = nil) {
//         self.log = log
//         self.recipe = recipe
//         self._selectedMeal = selectedMeal
//         self.mode = mode
//         self._selectedFoods = selectedFoods
//         self._path = path
//         self.onItemAdded = onItemAdded
//     }
    
//     var body: some View {
//         ZStack {
//             HStack {
//                 VStack(alignment: .leading, spacing: 4) {
//                     Text(recipe.title)
//                         .font(.headline)
//                         .fontWeight(.regular)
                    
//                     HStack {
//                         Text("\(Int(log.displayCalories)) cal")
//                         Text("•")
//                         Text("\(log.servingsConsumed ?? 1) serving\(log.servingsConsumed == 1 ? "" : "s")")
//                         if let mealTime = log.mealTime {
//                             Text("•")
//                             Text(mealTime)
//                         }
//                     }
//                             .font(.subheadline)
//                     .foregroundColor(.secondary)
//                 }
                
//                 Spacer()
                
//                 // Fixed-width container for the button
//                 HStack {
//                     Spacer()
                    
//                     Button {
//                         handleRecipeTap()
//                     } label: {
//                         switch mode {
//                         case .logFood:
//                             // For log food mode, similar to meal rows
//                             if foodManager.lastLoggedRecipeId == recipe.recipeId {
//                                 Image(systemName: "checkmark.circle.fill")
//                                     .font(.system(size: 24))
//                                     .foregroundColor(.green)
//                                     .transition(.opacity)
//                             } else {
//                                 Image(systemName: "plus.circle.fill")
//                                     .font(.system(size: 24))
//                                     .foregroundColor(.accentColor)
//                             }
//                         case .addToMeal, .addToRecipe:
//                             Image(systemName: "plus.circle.fill")
//                                 .font(.system(size: 24))
//                                 .foregroundColor(.accentColor)
//                         }
//                     }
//                     .buttonStyle(PlainButtonStyle())
//                     .frame(width: 44, height: 44)
//                     .contentShape(Rectangle())
//                 }
//                 .frame(width: 44)
//                 .zIndex(1)
//             }
//             .padding(.horizontal, 16)
//             .padding(.vertical, 8)
//             .contentShape(Rectangle())
//             .onTapGesture {
//                 // Only navigate to RecipeDetailView when in logFood mode
//                 if mode == .logFood {
//                     // Get full recipe from foodManager and navigate
//                     if let fullRecipe = foodManager.recipes.first(where: { $0.id == recipe.recipeId }) {
//                         path.append(FoodNavigationDestination.recipeDetails(fullRecipe))
//                     }
//                 } else {
//                     handleRecipeTap()
//                 }
//             }
//         }
//         .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
//             Button("OK", role: .cancel) { }
//         } message: {
//             Text("Please try again.")
//         }
//     }
    
//     private func handleRecipeTap() {
//         HapticFeedback.generate()
        
//         switch mode {
//         case .logFood:
//             // Log the recipe instead of navigating
//             foodManager.logRecipe(
//                 recipe: Recipe(
//                     id: recipe.recipeId,
//                     title: recipe.title,
//                     description: recipe.description,
//                     instructions: nil,
//                     privacy: "private",
//                     servings: recipe.servings,
//                     createdAt: Date(),
//                     updatedAt: Date(),
//                     recipeItems: [],
//                     image: recipe.image,
//                     prepTime: recipe.prepTime,
//                     cookTime: recipe.cookTime,
//                     totalCalories: recipe.calories,
//                     totalProtein: recipe.protein,
//                     totalCarbs: recipe.carbs,
//                     totalFat: recipe.fat
//                 ),
//                 mealTime: selectedMeal,
//                 servingsConsumed: 1,
//                 date: Date(),
//                 notes: nil,
//                 statusCompletion: { success in
//                     if !success {
//                         // Show error alert
//                         showLoggingErrorAlert = true
//                     }
//                 }
//             )
            
//         case .addToMeal, .addToRecipe:
//             // Add recipe items to selection
//             addRecipeItemsToSelection()
//         }
//     }
    
//     private func addRecipeItemsToSelection() {
//         // Find the full recipe - use recipe.id instead of recipeId
//         if let fullRecipe = foodManager.recipes.first(where: { $0.id == recipe.id }) {
//             // Create a variable to store the last food added for the callback
//             var lastAddedFood: Food? = nil
            
//             // Convert each RecipeFoodItem to Food and add to selectedFoods
//             for recipeItem in fullRecipe.recipeItems {
//                 // Create a Food object from the RecipeFoodItem
//                 let food = Food(
//                     fdcId: recipeItem.foodId,
//                     description: recipeItem.name,
//                     brandOwner: nil,
//                     brandName: nil,
//                     servingSize: 1.0,
//                     numberOfServings: 1.0,
//                     servingSizeUnit: recipeItem.servingText,
//                     householdServingFullText: recipeItem.servings,
//                     foodNutrients: [
//                         Nutrient(nutrientName: "Energy", value: recipeItem.calories, unitName: "kcal"),
//                         Nutrient(nutrientName: "Protein", value: recipeItem.protein, unitName: "g"),
//                         Nutrient(nutrientName: "Carbohydrate, by difference", value: recipeItem.carbs, unitName: "g"),
//                         Nutrient(nutrientName: "Total lipid (fat)", value: recipeItem.fat, unitName: "g")
//                     ],
//                     foodMeasures: []
//                 )
                
//                 // Add to selection
//                 selectedFoods.append(food)
//                 lastAddedFood = food
//             }
            
//             // Use callback if available, otherwise fall back to path
//             if let callback = onItemAdded, let lastFood = lastAddedFood {
//                 print("📲 Using callback to close sheet after adding recipe items")
//                 callback(lastFood)
//             } else if !path.isEmpty {
//                 print("👈 Using navigation path to go back after adding recipe items")
//                 path.removeLast()
//             }
//         } else {
//             // If recipe not found, still try to navigate back
//             if !path.isEmpty {
//                 path.removeLast()
//             }
//         }
//     }
// }



struct RecipeRow: View {
    @EnvironmentObject var foodManager: FoodManager
    let recipe: Recipe
    @Binding var selectedMeal: String
    
    // Just like MealRow
    var mode: LogFoodMode = .logFood  // Default to logFood
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    var onItemAdded: ((Food) -> Void)?
    
    @State private var showLoggingErrorAlert: Bool = false
    
    init(
        recipe: Recipe,
        selectedMeal: Binding<String>,
        mode: LogFoodMode = .logFood,
        selectedFoods: Binding<[Food]> = .constant([]),
        path: Binding<NavigationPath> = .constant(NavigationPath()),
        onItemAdded: ((Food) -> Void)? = nil
    ) {
        self.recipe = recipe
        self._selectedMeal = selectedMeal
        self.mode = mode
        self._selectedFoods = selectedFoods
        self._path = path
        self.onItemAdded = onItemAdded
    }
    
    // Optional convenience so if totalCalories is 0, we fallback
    private var displayCalories: Double {
        recipe.calories
    }
    
    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                // 1) Recipe image or fallback
                if let imageUrl = recipe.image, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let loaded):
                            loaded
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 40))
                                .frame(width: 50, height: 50)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // Default icon if no image
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 40))
                        .frame(width: 50, height: 50)
                }
                
                // 2) Recipe title & subheadline
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title.isEmpty ? "Untitled Recipe" : recipe.title)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text("\(Int(displayCalories)) cal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("•")
                        Text("\(recipe.servings) servings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if recipe.totalTime > 0 {
                            Text("•")
                            Text("\(recipe.totalTime) min")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // 3) Action Button
                HStack {
                    Spacer()
                    Button {
                        HapticFeedback.generate()
                        switch mode {
                        case .logFood:
                            logRecipe()
                        case .addToMeal, .addToRecipe:
                            addRecipeItemsToSelection()
                        }
                    } label: {
                        // Show a check if just logged
                        if mode == .logFood,
                           foodManager.lastLoggedRecipeId == recipe.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                                .transition(.opacity)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .frame(width: 44)
                .zIndex(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)  // Reduced from 12
            .contentShape(Rectangle())
            .onTapGesture {
                // For logFood mode, let's push to a detail page
                if mode == .logFood {
                    path.append(FoodNavigationDestination.recipeDetails(recipe))
                }
            }
        }
        .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }
    
    // MARK: - Logging
    private func logRecipe() {
        foodManager.logRecipe(
            recipe: recipe,
            mealTime: selectedMeal,
            date: Date(),
            notes: nil,
            calories: recipe.totalCalories ?? (recipe.recipeItems.reduce(0) { $0 + $1.calories })
        ) { result in
            // If you want to handle error messages:
        } statusCompletion: { success in
            if !success {
                showLoggingErrorAlert = true
            }
        }
    }
    
    // MARK: - Adding Items to Another Meal/Recipe
    private func addRecipeItemsToSelection() {
        // We already have a full `Recipe` object in 'recipe'
        // Convert each `RecipeFoodItem` to a `Food` and append
        var lastAddedFood: Food? = nil
        
        for item in recipe.recipeItems {
            // Attempt to parse item.servings or fall back to 1
            let servingsValue = Double(
                item.servings.trimmingCharacters(in: .whitespacesAndNewlines)
            ) ?? 1.0
            
            // Serving text
            let servingText: String
            if let text = item.servingText, !text.isEmpty {
                servingText = text
            } else {
                servingText = "serving"
            }
            
            // Create a Food from the item
            let newFood = Food(
                fdcId: item.foodId,
                description: item.name,
                brandOwner: nil,
                brandName: nil,
                servingSize: 1.0,
                numberOfServings: servingsValue,
                servingSizeUnit: servingText,
                householdServingFullText: servingText,
                foodNutrients: [
                    Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                    Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                    Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                    Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
                ],
                foodMeasures: []
            )
            
            selectedFoods.append(newFood)
            lastAddedFood = newFood
        }
        
        // If we have a callback, call it. Otherwise pop back
        if let callback = onItemAdded, let lastFood = lastAddedFood {
            callback(lastFood)
        } else if !path.isEmpty {
            path.removeLast() // close sheet
        }
    }
}


// Add RecipeRow struct similar to MealRow
// struct RecipeRow: View {
//     @EnvironmentObject var foodManager: FoodManager
//     let recipe: Recipe
//     @Binding var selectedMeal: String
    
//     // Add these properties to match MealRow
//     var mode: LogFoodMode = .logFood  // Default to logFood mode
//     @Binding var selectedFoods: [Food]
//     @Binding var path: NavigationPath
    
//     // Add the onItemAdded callback
//     var onItemAdded: ((Food) -> Void)?
    
//     // Add state for logging error alert
//     @State private var showLoggingErrorAlert: Bool = false
    
//     // Make these optional bindings with default values
//     init(recipe: Recipe, 
//          selectedMeal: Binding<String>, 
//          mode: LogFoodMode = .logFood, 
//          selectedFoods: Binding<[Food]> = .constant([]), 
//          path: Binding<NavigationPath> = .constant(NavigationPath()),
//          onItemAdded: ((Food) -> Void)? = nil) {
//         self.recipe = recipe
//         self._selectedMeal = selectedMeal
//         self.mode = mode
//         self._selectedFoods = selectedFoods
//         self._path = path
//         self.onItemAdded = onItemAdded
//     }
    
//     // Computed property for calories per serving
//     private var caloriesPerServing: Double {
//         return recipe.calories / Double(recipe.servings)
//     }
    
//     var body: some View {
//         ZStack {
//             HStack(spacing: 16) {
//                 // Recipe image or placeholder
//                 if let imageUrl = recipe.image, !imageUrl.isEmpty {
//                     AsyncImage(url: URL(string: imageUrl)) { phase in
//                         switch phase {
//                         case .empty:
//                             Rectangle()
//                                 .fill(Color.gray.opacity(0.2))
//                                 .frame(width: 50, height: 50)
//                                 .cornerRadius(8)
//                     case .success(let image):
//                         image
//                             .resizable()
//                             .aspectRatio(contentMode: .fill)
//                             .frame(width: 50, height: 50)
//                             .clipShape(RoundedRectangle(cornerRadius: 8))
//                     case .failure:
//                             Rectangle()
//                                 .fill(Color.gray.opacity(0.2))
//                             .frame(width: 50, height: 50)
//                                 .cornerRadius(8)
//                                 .overlay(
//                                     Image(systemName: "fork.knife")
//                                         .foregroundColor(.gray)
//                                 )
//                     @unknown default:
//                             Rectangle()
//                                 .fill(Color.gray.opacity(0.2))
//                                 .frame(width: 50, height: 50)
//                                 .cornerRadius(8)
//                         }
//                     }
//                 } else {
//                     Rectangle()
//                         .fill(Color.gray.opacity(0.2))
//                         .frame(width: 50, height: 50)
//                         .cornerRadius(8)
//                         .overlay(
//                             Image(systemName: "fork.knife")
//                                 .foregroundColor(.gray)
//                         )
//                 }
                
//                 // Recipe details
//                 VStack(alignment: .leading, spacing: 4) {
//                     Text(recipe.title)
//                         .font(.headline)
//                         .fontWeight(.regular)
                    
//                     HStack {
//                         Text("\(Int(caloriesPerServing)) cal/serving")
//                         Text("•")
//                         Text("\(recipe.servings) servings")
//                         if recipe.totalTime > 0 {
//                             Text("•")
//                             Text("\(recipe.totalTime) min")
//                         }
//                     }
//                     .font(.subheadline)
//                     .foregroundColor(.secondary)
//                 }
                
//                 Spacer()
                
//                 // Action button
//                 HStack {
//                     Spacer()
                    
//                     Button {
//                         handleRecipeTap()
//                     } label: {
//                         let isAddMode = (mode == .addToMeal || mode == .addToRecipe)
//                         let isChecked = (!isAddMode && foodManager.lastLoggedRecipeId == recipe.id)
                        
//                         Image(systemName: isChecked ? "checkmark.circle.fill" : "plus.circle.fill")
//                             .font(.system(size: 24))
//                             .foregroundColor(isChecked ? .green : .accentColor)
//                             .animation(.easeInOut, value: isChecked)
//                     }
//                     .buttonStyle(PlainButtonStyle())
//                     .frame(width: 44, height: 44)
//                     .contentShape(Rectangle())
//                 }
//                 .frame(width: 44)
//                 .zIndex(1)  // Keep button on top
//             }
//             .padding(.horizontal, 16)
//             .padding(.vertical, 4)
//             .contentShape(Rectangle())
//             .onTapGesture {
//                 // Only navigate to RecipeDetailView when in logFood mode
//                 if mode == .logFood {
//                     path.append(FoodNavigationDestination.recipeDetails(recipe))
//                 }
//             }
//         }
//         .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
//             Button("OK", role: .cancel) { }
//         } message: {
//             Text("Please try again.")
//         }
//     }
    
//     private func handleRecipeTap() {
//         HapticFeedback.generate()
        
//         switch mode {
//         case .logFood:
//             // Log the recipe instead of navigating
//             foodManager.logRecipe(
//                 recipe: Recipe(
//                     id: recipe.id,
//                     title: recipe.title,
//                     description: recipe.description,
//                     instructions: nil,
//                     privacy: "private",
//                     servings: recipe.servings,
//                     createdAt: Date(),
//                     updatedAt: Date(),
//                     recipeItems: [],
//                     image: recipe.image,
//                     prepTime: recipe.prepTime,
//                     cookTime: recipe.cookTime,
//                     totalCalories: recipe.calories,
//                     totalProtein: recipe.protein,
//                     totalCarbs: recipe.carbs,
//                     totalFat: recipe.fat,
//                     scheduledAt: <#Date?#>
//                 ),
//                 mealTime: selectedMeal,
//                 servingsConsumed: 1,
//                 date: Date(),
//                 notes: nil,
//                 statusCompletion: { success in
//                     if !success {
//                         // Show error alert
//                         showLoggingErrorAlert = true
//                     }
//                 }
//             )
            
//         case .addToMeal, .addToRecipe:
//             // Add recipe items to selection
//             addRecipeItemsToSelection()
//         }
//     }
    
//     private func addRecipeItemsToSelection() {
//         // Find the full recipe - use recipe.id instead of recipeId
//         if let fullRecipe = foodManager.recipes.first(where: { $0.id == recipe.id }) {
//             // Create a variable to store the last food added for the callback
//             var lastAddedFood: Food? = nil
            
//             // Convert each RecipeFoodItem to Food and add to selectedFoods
//             for recipeItem in fullRecipe.recipeItems {
//                 // Create a Food object from the RecipeFoodItem
//                 let food = Food(
//                     fdcId: recipeItem.foodId,
//                     description: recipeItem.name,
//                     brandOwner: nil,
//                     brandName: nil,
//                     servingSize: 1.0,
//                     numberOfServings: 1.0,
//                     servingSizeUnit: recipeItem.servingText,
//                     householdServingFullText: recipeItem.servings,
//                     foodNutrients: [
//                         Nutrient(nutrientName: "Energy", value: recipeItem.calories, unitName: "kcal"),
//                         Nutrient(nutrientName: "Protein", value: recipeItem.protein, unitName: "g"),
//                         Nutrient(nutrientName: "Carbohydrate, by difference", value: recipeItem.carbs, unitName: "g"),
//                         Nutrient(nutrientName: "Total lipid (fat)", value: recipeItem.fat, unitName: "g")
//                     ],
//                     foodMeasures: []
//                 )
                
//                 // Add to selection
//                 selectedFoods.append(food)
//                 lastAddedFood = food
//             }
            
//             // Use callback if available, otherwise fall back to path
//             if let callback = onItemAdded, let lastFood = lastAddedFood {
//                 print("📲 Using callback to close sheet after adding recipe items")
//                 callback(lastFood)
//             } else if !path.isEmpty {
//                 print("👈 Using navigation path to go back after adding recipe items")
//                 path.removeLast()
//             }
//         } else {
//             // If recipe not found, still try to navigate back
//             if !path.isEmpty {
//                 path.removeLast()
//             }
//         }
//     }
// }

private struct RecipeHistorySection: View {
    @EnvironmentObject var foodManager: FoodManager
    @Binding var selectedMeal: String
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    // Add onItemAdded callback
    var onItemAdded: ((Food) -> Void)?
    
    var body: some View {
        Section {
            Text("History")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 8)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            
            ForEach(foodManager.recipes) { recipe in
                RecipeRow(
                    recipe: recipe,
                    selectedMeal: $selectedMeal,
                    mode: mode,
                    selectedFoods: $selectedFoods,
                    path: $path,
                    onItemAdded: onItemAdded
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
        }
        .listSectionSeparator(.hidden)
    }
}

struct CombinedMealRow: View {
    @EnvironmentObject var foodManager: FoodManager
    let log: CombinedLog
    let meal: MealSummary
    @Binding var selectedMeal: String
    
    // Add these properties to match FoodRow
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    // Add the onItemAdded callback
    var onItemAdded: ((Food) -> Void)?
    
    // Add state for logging error alert
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
        ZStack {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.title.isEmpty ? "Untitled Meal" : meal.title)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .padding(.trailing, 4)
                    Text("\(Int(log.displayCalories)) cal")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                }
                
                Spacer() // Push the button to the right edge
                
                // Fixed-width container for the button
                HStack {
                    Spacer() // Center the button within the container
                    
                    Button {
                        HapticFeedback.generate()
                        
                        switch mode {
                        case .logFood:
                            // Original behavior - log the meal
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
                                        // Ensure the food manager's lastLoggedMealId is cleared
                                        withAnimation {
                                            if self.foodManager.lastLoggedMealId == self.meal.id {
                                                self.foodManager.lastLoggedMealId = nil
                                            }
                                        }
                                        
                                        // Show error alert
                                        showLoggingErrorAlert = true
                                    }
                                }
                            )
                        
                        case .addToMeal, .addToRecipe:
                            // Add meal items to selection
                            addMealItemsToSelection()
                        }
                    } label: {
                        if mode == .addToMeal {
                            // Similar to FoodRow's addToMeal mode
                            ZStack {
                                Circle()
                                    .fill(Color("bg"))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        } else {
                            // Original behavior for logFood mode
                            if foodManager.lastLoggedMealId == meal.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                    .transition(.opacity)
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color("bg"))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 44, height: 44)  // Fixed size for the button
                    .contentShape(Rectangle())
                    .zIndex(1) // Keep button on top
                }
                .frame(width: 44) // Fixed width for the button container
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)  // Reduced from 12
            .background(Color("iosbg"))
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                // Find the full meal from FoodManager.meals
                if let fullMeal = foodManager.meals.first(where: { $0.id == meal.id }) {
                    // Navigate to MealDetailView with the full meal
                    path.append(FoodNavigationDestination.mealDetails(fullMeal))
                } else {
                    // Create a minimal meal object to show if we can't find the full meal
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
        .padding(.horizontal, 16)
        .padding(.vertical, 0)  // Reduced from 4
        // Add a specific logging error alert
        .alert("Logging Error", isPresented: $showLoggingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
    }
    

    
    // Add this method to add meal items to selection using already loaded meals
    private func addMealItemsToSelection() {
        // Try to find the full meal from FoodManager to get access to mealItems
        if let fullMeal = foodManager.meals.first(where: { $0.id == meal.id }) {
            // Track the last food added for callback
            var lastAddedFood: Food? = nil
            
            for mealItem in fullMeal.mealItems {
                // Try to extract numeric value from servings string
                let servingsValue = Double(mealItem.servings.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 1.0
                
                // Get the proper serving text - use the serving_text if available
                let servingText: String
                if let text = mealItem.servingText, !text.isEmpty {
                    servingText = text
                } else {
                    // Get the unit of measurement, if any
                    if let unit = mealItem.servings.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))).last,
                       !unit.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                        servingText = unit.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    } else {
                        servingText = "serving"
                    }
                }

                
                // Create a Food object from the MealFoodItem
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
                
                // Add to selection
                selectedFoods.append(food)
                lastAddedFood = food
            }
            
            // Use callback if available, otherwise fall back to path
            if let callback = onItemAdded, let lastFood = lastAddedFood {
                print("📲 Using callback to close sheet after adding meal items")
                callback(lastFood)
            } else if !path.isEmpty {
                print("👈 Using navigation path to go back after adding meal items")
                path.removeLast()
            }
        } else {
            // If we couldn't find the meal, navigate back
            if !path.isEmpty {
                path.removeLast()
            }
        }
    }
}
