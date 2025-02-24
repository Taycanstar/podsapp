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
                            
        ForEach(foodManager.loggedFoods, id: \.id) { loggedFood in
                        HistoryRow(loggedFood: loggedFood, selectedMeal: $selectedMeal, mode: mode, selectedFoods: $selectedFoods, path: $path)
                            .onAppear {
                          
                                foodManager.loadMoreIfNeeded(food: loggedFood)
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
                        VStack(spacing: 16) {
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
                            // .padding(.vertical, 16)
                            
                            Button {
                                print("Copy previous meal tapped")
                            } label: {
                                VStack(alignment: .leading, spacing: 16) {
                                    Image("sushi")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 85, height: 85)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Copy Previous Meal")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                        Text("Copy the meal you previously create to log your go-to meals faster.")
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
                        }
                        .padding()
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Cancel button
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    selectedTab = 0 // switch back to Dashboard
                    dismiss()
                }
                .foregroundColor(.accentColor)
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
                    Text("Food logged successfully")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.label))  // Adapt to color scheme
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Material.ultraThin,  // Apply the glass effect
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.label).opacity(0.7), lineWidth: 1)  // Add a border for contrast
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 65)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                }
        .navigationBarBackButtonHidden(mode == .addToMeal)
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
                    .foregroundColor(.gray)
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

                //     private func handleFoodTap() {
                //     HapticFeedback.generate()
                //     switch mode {
                //     case .logFood:
                //         logFood()
                //     case .addToMeal:
                //         selectedFoods.append(food)  
                //         path.removeLast() 
                //     }
                // }
                private func handleFoodTap() {
    HapticFeedback.generate()
    switch mode {
    case .logFood:
        logFood()
    case .addToMeal:
        // if let index = selectedFoods.firstIndex(where: { $0.fdcId == food.fdcId }) {
        //     // Increment existing servings
        //     var updatedFood = selectedFoods[index]
        //     updatedFood.numberOfServings = (updatedFood.numberOfServings ?? 1) + 1
        //     // selectedFoods[index] = updatedFood
        //     var newArray = selectedFoods  // Make copy
        // newArray[index] = updatedFood  // Modify copy
        // selectedFoods = newArray 
        // } else {
        //     // Add new entry with initial serving
        //     var newFood = food
        //     newFood.numberOfServings = 1
        //     selectedFoods.append(newFood)
        // }
        // foodManager.trackRecentlyAdded(foodId: food.fdcId)
        // path.removeLast()
              if let index = selectedFoods.firstIndex(where: { $0.fdcId == food.fdcId }) {
            print("Found existing item \(food.fdcId), incrementing from \(selectedFoods[index].numberOfServings ?? 1).")
             print("Incrementing from \(selectedFoods[index].numberOfServings ?? 1).")
            var updatedFood = selectedFoods[index]
            updatedFood.numberOfServings = (updatedFood.numberOfServings ?? 1) + 1
            
            var newArray = selectedFoods
            newArray[index] = updatedFood
            selectedFoods = newArray
             print("After assignment, selectedFoods[index] = \(selectedFoods[index])")
        } else {
            print("New item \(food.fdcId), adding with 1 serving.")
            
            var newFood = food
            newFood.numberOfServings = 1
            selectedFoods.append(newFood)
        }
        print("Now selectedFoods = \(selectedFoods)")
       

        
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
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    let loggedFood: LoggedFood
    let selectedMeal: Binding<String>
    @State private var checkmarkVisible: Bool = false
    @State private var errorMessage: String = ""
    @State private var showErrorAlert: Bool = false
    let mode: LogFoodMode  
    @Binding var selectedFoods: [Food]
    @Binding var path: NavigationPath
    
    
    var body: some View {
        // FoodRow(
        //     food: loggedFood.food.asFood,
        //     selectedMeal: selectedMeal)
        FoodRow(
            food: loggedFood.food.asFood,
            selectedMeal: selectedMeal,
            mode: mode,              // Pass through from LogFood
            selectedFoods: $selectedFoods,
            path: $path)
    }
}

