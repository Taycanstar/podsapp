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

    
   

    
    enum FoodTab: Hashable {
        case all, meals, recipes, foods
        
        var title: String {
            switch self {
            case .all: return "All"
            case .meals: return "Meals"
            case .recipes: return "Recipes"
            case .foods: return "Foods"
            }
        }
        
        var searchPrompt: String {
            switch self {
            case .all, .foods:
                return "Search Food"
            case .meals:
                return "Search Meals"
            case .recipes:
                return "Search Recipes"
            }
        }
    }
    
    let foodTabs: [FoodTab] = [.all, .meals, .recipes, .foods]
    
    init(selectedTab: Binding<Int>, 
         selectedMeal: Binding<String>, 
         path: Binding<NavigationPath>,
         mode: LogFoodMode = .logFood,
         selectedFoods: Binding<[Food]>) {
        _selectedTab = selectedTab
        _path = path
        _selectedMeal = selectedMeal
        self.mode = mode
        _selectedFoods = selectedFoods
    }
    
    var body: some View {
          ZStack(alignment: .bottom) {
        VStack(spacing: 0) {
            // Horizontal tab panel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 35) {
                    ForEach(foodTabs, id: \.self) { tab in
                        VStack(spacing: 8) {
                            Text(tab.title)
                                .font(.system(size: 17))
                                .fontWeight(.semibold)
                                .foregroundColor(selectedFoodTab == tab ? .primary : .gray)
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(selectedFoodTab == tab ? .accentColor : .clear)
                        }
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                selectedFoodTab = tab
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Main content area:
            if selectedFoodTab == .all || selectedFoodTab == .foods {
                List {
                    if searchResults.isEmpty && !isSearching {
                        Section {
                            Text("History")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 8)
                                 .listRowSeparator(.hidden) 
                            
        // ForEach(foodManager.loggedFoods, id: \.id) { loggedFood in
        ForEach(foodManager.combinedLogs, id: \.id) { log in
                        // HistoryRow(loggedFood: loggedFood, selectedMeal: $selectedMeal, mode: mode, selectedFoods: $selectedFoods, path: $path)
                           HistoryRow(
                                    log: log,
                                    selectedMeal: $selectedMeal,
                                    mode: mode,
                                    selectedFoods: $selectedFoods,
                                    path: $path
                                )
                            .onAppear {
                          
                                // foodManager.loadMoreIfNeeded(food: loggedFood)
                                foodManager.loadMoreIfNeeded(log: log)
                            }
                    }
                                }
                                
                            } else {
                                ForEach(searchResults) { food in
                                    FoodRow(food: food, selectedMeal: $selectedMeal, mode: mode, selectedFoods: $selectedFoods, path: $path)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 60)
                        }
                    } else {
                        // Content for other tabs
                        switch selectedFoodTab {
                        

        case .meals:
    List {
        // ROW 1: "Create Meal" card (Button)
        VStack(spacing: 4) {
            Button {
                print("Create meal tapped")
                path.append(FoodNavigationDestination.createMeal)
            } label: {
                VStack(alignment: .leading, spacing: 16) {
                    Image("burger")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 85, height: 85)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create a Meal")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Create and save your favorite meals to log quickly again and again.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("ioscard"))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top)
        }
        // Remove list padding for this row
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        
        // ROW 2: Meal History Section, exactly your styling
        VStack(spacing: 4) {
            if !foodManager.meals.isEmpty {
                Text("History")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                ForEach(foodManager.meals) { meal in
                    MealRow(meal: meal, selectedMeal: $selectedMeal, mode: mode, selectedFoods: $selectedFoods, path: $path)
                        // .onAppear {
                        //     foodManager.loadMoreMealsIfNeeded(meal: meal)
                        // }
                        // Remove extra list row insets
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    
                    // Divider aligned with text
                    Divider()
                        .padding(.leading, 66) // 50 (image) + 16 (HStack spacing)
                        .padding(.vertical, 0)
                }
            } else if foodManager.isLoadingMeals {
                ProgressView()
                    .padding()
            } else {
                Text("No meal history yet")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        // Also remove insets around this second VStack
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
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
                        case .recipes:
                            Text("Recipes content")
                        default:
                            EmptyView()
                        }
                    }
                    
                    Spacer()
                }
        .edgesIgnoringSafeArea(.horizontal)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: selectedFoodTab.searchPrompt)
        .onChange(of: searchText) { _ in
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await searchFoods()
            }
        }
      // In LogFood.swift, remove the current onAppear and replace with this:
.onAppear {
    // Force an immediate refresh if we don't have meals yet
    if foodManager.meals.isEmpty && !foodManager.isLoadingMeals {
        foodManager.refreshMeals()
    }
    // Otherwise, just prefetch the images for any meals we already have
    else {
        foodManager.prefetchMealImages()
    }
    
    // Always refresh combined logs when the view appears
    foodManager.refresh()
}
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Cancel button
            if mode != .addToMeal {
                ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    selectedTab = 0 // switch back to Dashboard
                    dismiss()
                }
                .foregroundColor(.accentColor)
            }
            }
            
            // Meal picker menu
            ToolbarItem(placement: .principal) {
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
        .alert("Something went wrong", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }

                    if foodManager.showToast {
                  BottomPopup(message: "Food logged")
                }
                       if foodManager.showMealToast {
                    BottomPopup(message: "Meal created")
                }
                if foodManager.showMealLoggedToast {
                    BottomPopup(message: "Meal logged")
                }
                }
        .navigationBarBackButtonHidden(mode != .addToMeal)
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



struct FoodRow: View {
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    let food: Food
    let selectedMeal: Binding<String>
    @State private var checkmarkVisible: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    // Add these properties
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath 
    
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
                        .fontWeight(.regular)
                    HStack {
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
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    HapticFeedback.generate()
                    // logFood()
                    handleFoodTap()
                } label: {
                    if mode == .addToMeal {
                        // if selectedFoods.contains(where: { $0.id == food.id }) {
                                if foodManager.recentlyAddedFoodIds.contains(food.fdcId) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                        }
                    } else {
                        if foodManager.lastLoggedFoodId == food.fdcId {
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
            }
            .contentShape(Rectangle())
        }
        .alert("Something went wrong", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    
private func handleFoodTap() {
    HapticFeedback.generate()
    switch mode {
    case .logFood:
        logFood()
        
    case .addToMeal:
       
    // Create a new mutable Food object with the same properties
    // NOTE: We can't directly modify 'food' because most of its properties are constants
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


    selectedFoods.append(newFood)
    
    // track, then pop back
    foodManager.trackRecentlyAdded(foodId: food.fdcId)
    path.removeLast()
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
                // foodManager.refresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { 
                        checkmarkVisible = false
                         }
                }
            case .failure(let error):
                print("Error logging food: \(error)")
                errorMessage = "An error occurred while logging. Try again."
                showErrorAlert = true
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
    
    var body: some View {
        switch log.type {
        case .food:
            if let food = log.food {
                FoodRow(
                    food: food.asFood, // Make sure LoggedFoodItem has an asFood property
                    selectedMeal: $selectedMeal,
                    mode: mode,
                    selectedFoods: $selectedFoods,
                    path: $path
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
                    path: $path
                )
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
    
    // Add these properties to match FoodRow
    let mode: LogFoodMode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    init(log: CombinedLog, 
         meal: MealSummary, 
         selectedMeal: Binding<String>, 
         mode: LogFoodMode = .logFood, 
         selectedFoods: Binding<[Food]> = .constant([]), 
         path: Binding<NavigationPath> = .constant(NavigationPath())) {
        self.log = log
        self.meal = meal
        self._selectedMeal = selectedMeal
        self.mode = mode
        self._selectedFoods = selectedFoods
        self._path = path
    }
    
    var body: some View {
        let rawCalories = log.calories
        let displayCals = log.displayCalories
        let mealDisplayCals = meal.displayCalories
        
        // Print debugging info when this view is created
        let _ = {
            print("📊 CombinedLogMealRow for '\(meal.title)':")
            print("- Raw log calories: \(rawCalories)")
            print("- Log displayCalories: \(displayCals)")
            print("- Meal displayCalories: \(mealDisplayCals)")
            return 0
        }()
        
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.title.isEmpty ? "Untitled Meal" : meal.title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    // Use the displayCalories from the log directly
                    Text("\(Int(log.displayCalories)) cal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button {
                HapticFeedback.generate()
                
                switch mode {
                case .logFood:
                    // Original behavior - log the meal
                    // Pass the displayCalories as the totalCalories
                    foodManager.logMeal(meal: Meal(
                        id: meal.mealId,
                        title: meal.title,
                        description: meal.description,
                        directions: nil,
                        privacy: "private",
                        servings: meal.servings,
                        createdAt: Date(),
                        mealItems: [],
                        image: meal.image,
                        totalCalories: log.displayCalories,
                        totalProtein: meal.protein,
                        totalCarbs: meal.carbs,
                        totalFat: meal.fat
                    ), mealTime: selectedMeal)
                
                case .addToMeal:
                    // New behavior - add all food items from the meal to selectedFoods
                    addMealItemsToSelection()
                }
            } label: {
                if mode == .addToMeal {
                    // Similar to FoodRow's addToMeal mode
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                } else {
                    // Original behavior for logFood mode
                    if foodManager.lastLoggedMealId == meal.mealId {
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
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
    }
    
    // New method to add meal items to selection using already loaded meals
    private func addMealItemsToSelection() {
        // Find the full meal from FoodManager.meals
        if let fullMeal = foodManager.meals.first(where: { $0.id == meal.mealId }) {
            print("✅ Found meal in FoodManager: \(fullMeal.title) with \(fullMeal.mealItems.count) items")
            
            // DUMP ENTIRE MEAL ITEMS ARRAY FOR INSPECTION
            print("📋 COMPLETE MEAL ITEMS DATA:")
            for (index, item) in fullMeal.mealItems.enumerated() {
                print("  ITEM #\(index+1): \(item.name)")
                print("    - food_id: \(item.foodId)")
                print("    - external_id: \(item.externalId)")
                print("    - servings: \(item.servings)")
             
                print("    - calories: \(item.calories)")
            }
            
            // Convert each MealFoodItem to Food and add to selectedFoods
            for mealItem in fullMeal.mealItems {
                print("🔍 Processing meal item: \(mealItem.name)")
                print("  - Servings: \(mealItem.servings)")
                print("  - Raw serving_text from meal item: \(mealItem.servingText ?? "nil")")
                
                // Try to extract numeric value from servings string
                let servingsValue = Double(mealItem.servings.trimmingCharacters(in: .whitespaces)) ?? 1.0
                
                // Get the proper serving text - use the serving_text if available
                // If not available, create a more descriptive fallback
                let servingText: String
                if let text = mealItem.servingText, !text.isEmpty {
                    servingText = text
                } else {
                    // Get the unit of measurement, if any
                    if let unit = mealItem.servings.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))).last,
                       !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        servingText = unit.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        servingText = "serving"
                    }
                }
                print("  - Final servingText to be used: \(servingText)")
                
                // Create a Food object from the MealFoodItem
                let food = Food(
                    fdcId: Int(mealItem.externalId) ?? mealItem.foodId,
                    description: mealItem.name,
                    brandOwner: nil,
                    brandName: nil,
                    servingSize: 1.0,  // Setting an explicit servingSize
                    numberOfServings: servingsValue,
                    servingSizeUnit: servingText,  // Using the servingText as the unit
                    householdServingFullText: servingText, // Use the proper serving text
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
            }
            
            // Navigate back to the meal creation screen
            path.removeLast()
        } else {
            print("❌ Could not find meal with ID \(meal.mealId) in FoodManager.meals")
            
            // If we couldn't find the meal, still navigate back
            path.removeLast()
        }
    }
}

struct MealHistoryRow: View {
    @EnvironmentObject var foodManager: FoodManager
    let meal: MealSummary  // Changed from Meal to MealSummary since that's what we get from the log
    @Binding var selectedMeal: String
    
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
            Spacer()
            Button {
                HapticFeedback.generate()
                foodManager.logMeal(meal: Meal(id: meal.mealId, title: meal.title, description: meal.description, directions: nil, privacy: "private", servings: meal.servings, createdAt: Date(), mealItems: [], image: meal.image, totalCalories: meal.displayCalories, totalProtein: nil, totalCarbs: nil, totalFat: nil), mealTime: selectedMeal)
            } label: {
                if foodManager.lastLoggedMealId == meal.mealId {
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
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
    }
}
struct MealRow: View {
    @EnvironmentObject var foodManager: FoodManager
    let meal: Meal
    @Binding var selectedMeal: String
    
    // Add these properties to match CombinedLogMealRow
    var mode: LogFoodMode = .logFood  // Default to logFood mode
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    // Make these optional bindings with default values
    init(meal: Meal, 
         selectedMeal: Binding<String>, 
         mode: LogFoodMode = .logFood, 
         selectedFoods: Binding<[Food]> = .constant([]), 
         path: Binding<NavigationPath> = .constant(NavigationPath())) {
        self.meal = meal
        self._selectedMeal = selectedMeal
        self.mode = mode
        self._selectedFoods = selectedFoods
        self._path = path
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
                    Text("\(Int(displayCalories)) cal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button {
                HapticFeedback.generate()
                
                // Switch behavior based on mode
                switch mode {
                case .logFood:
                    // Original behavior - log the meal
                    foodManager.logMeal(meal: meal, mealTime: selectedMeal)
                
                case .addToMeal:
                    // New behavior - add meal items to selection
                    addMealItemsToSelection()
                }
            } label: {
                if mode == .addToMeal {
                    // For add to meal mode
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                } else {
                    // For log food mode
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
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
        // Add debug print to help diagnose
      
    }
    
    // Add this method to handle adding meal items to selection
    private func addMealItemsToSelection() {
     
        for (index, item) in meal.mealItems.enumerated() {
  
        }
        
        // Convert each MealFoodItem to Food and add to selectedFoods
        for mealItem in meal.mealItems {
       
            
            // Try to extract numeric value from servings string
            let servingsValue = Double(mealItem.servings.trimmingCharacters(in: .whitespaces)) ?? 1.0
            
            // Get the proper serving text - use the serving_text if available
            let servingText: String
            if let text = mealItem.servingText, !text.isEmpty {
                servingText = text
            } else {
                // Get the unit of measurement, if any
                if let unit = mealItem.servings.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))).last,
                   !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    servingText = unit.trimmingCharacters(in: .whitespacesAndNewlines)
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
        }
        
        // Navigate back to the meal creation screen
        path.removeLast()
    }
}
