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
    
    init(selectedTab: Binding<Int>, selectedMeal: Binding<String>) {
        _selectedTab = selectedTab
        // Set default meal based on current hour
        let hour = Calendar.current.component(.hour, from: Date())
        let defaultMeal: String = {
            switch hour {
            case 4...11:
                return "Breakfast"
            case 12...16:
                return "Lunch"
            default:
                return "Dinner"
            }
        }()
        _selectedMeal = selectedMeal // we use the passed‑in binding
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
                        HistoryRow(loggedFood: loggedFood, selectedMeal: $selectedMeal)
                            .onAppear {
                          
                                foodManager.loadMoreIfNeeded(food: loggedFood)
                            }
                    }
                                }
                                
                            } else {
                                ForEach(searchResults) { food in
                                    FoodRow(food: food, selectedMeal: $selectedMeal)
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
                            Text("Meals content")
                        case .recipes:
                            Text("Recipes content")
                        default:
                            EmptyView()
                        }
                    }
                    
                    Spacer()
                }
       
        .edgesIgnoringSafeArea(.horizontal)
        .searchable(text: $searchText, prompt: selectedFoodTab.searchPrompt)
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
                    logFood()
                } label: {
                    if foodManager.lastLoggedFoodId  == food.fdcId {
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
            .contentShape(Rectangle())
        }
        .alert("Something went wrong", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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
    
    
    var body: some View {
        FoodRow(
            food: loggedFood.food.asFood,
            selectedMeal: selectedMeal)
        

    }
}

