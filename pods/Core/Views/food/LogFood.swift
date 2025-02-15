//
//  LogFood.swift
//  Pods
//
//  Created by Dimi Nunez on 2/10/25.
//

// import SwiftUI

// struct LogFood: View {
//     @Environment(\.dismiss) private var dismiss
//     @EnvironmentObject var foodManager: FoodManager
//     @EnvironmentObject var viewModel: OnboardingViewModel
//     @Binding var selectedMeal: String
//     @State private var showMealPicker = false
//     @Binding var selectedTab: Int
//     @State private var searchText = ""
//     @State private var selectedFoodTab: FoodTab = .all
//     @State private var searchResults: [Food] = []
//     @State private var isSearching = false
//    @State private var checkmarkStates: [Int: Bool] = [:]
//    @State private var showErrorAlert = false
//     @State private var errorMessage = ""
    
//     enum FoodTab {
//         case all, meals, recipes, foods
        
//         var title: String {
//             switch self {
//             case .all: return "All"
//             case .meals: return "Meals"
//             case .recipes: return "Recipes"
//             case .foods: return "Foods"
//             }
//         }
        
//         var searchPrompt: String {
//             switch self {
//             case .all, .foods:
//                 return "Search Food"
//             case .meals:
//                 return "Search Meals"
//             case .recipes:
//                 return "Search Recipes"
//             }
//         }
//     }
    
//     let foodTabs: [FoodTab] = [.all, .meals, .recipes, .foods]
    
//     init(selectedTab: Binding<Int>, selectedMeal: Binding<String>) {
//         _selectedTab = selectedTab
//         // Set initial meal based on time of day
//         let hour = Calendar.current.component(.hour, from: Date())
//         let defaultMeal: String
        
//         switch hour {
//         case 4...11:  // 4:00 AM to 11:00 AM
//             defaultMeal = "Breakfast"
//         case 12...16:  // 11:01 AM to 4:00 PM
//             defaultMeal = "Lunch"
//         default:  // 4:01 PM to 3:59 AM
//             defaultMeal = "Dinner"
//         }
//         // _selectedMeal = State(initialValue: defaultMeal)
//         _selectedMeal = selectedMeal
//     }
    
//     var body: some View {
//         VStack(spacing: 0) {
//             // Horizontal tab panel
//             ScrollView(.horizontal, showsIndicators: false) {
//                 HStack(spacing: 35) {
//                     ForEach(foodTabs, id: \.self) { tab in
//                         VStack(spacing: 8) {
//                             Text(tab.title)
//                                 .font(.system(size: 17))
//                                 .fontWeight(.semibold)
//                                 .foregroundColor(selectedFoodTab == tab ? .primary : .gray)
                            
//                             // Indicator bar
//                             Rectangle()
//                                 .frame(height: 2)
//                                 .foregroundColor(selectedFoodTab == tab ? .accentColor : .clear)
//                         }
//                         .onTapGesture {
//                             withAnimation(.easeInOut) {
//                                 selectedFoodTab = tab
//                             }
//                         }
//                     }
//                 }
//                 .padding(.horizontal)
//             }
//             .padding(.vertical, 8)
            
//             Divider()
            
//             // Content based on selected tab
//             if selectedFoodTab == .all || selectedFoodTab == .foods {
//                 List {
//     ForEach(searchResults) { food in
//         ZStack {
//             // Invisible NavigationLink providing the navigation
//             NavigationLink(value: FoodNavigationDestination.foodDetails(food, $selectedMeal)) {
//                 EmptyView()
//             }
//             .opacity(0)
            
//             // Your custom row content
//             HStack {
//                 VStack(alignment: .leading, spacing: 4) {
//                     Text(food.displayName)
//                         .font(.headline)
//                     HStack {
//                         if let calories = food.calories {
//                             Text("\(Int(calories)) cal")
//                         }
//                         Text("•")
//                         Text(food.servingSizeText)
//                         if let brand = food.brandText {
//                             Text("•")
//                             Text(brand)
//                         }
//                     }
//                     .font(.subheadline)
//                     .foregroundColor(.gray)
//                 }
//                 Spacer()


//          Button(action: {
//             HapticFeedback.generate()
//     foodManager.logFood(
//         email: viewModel.email,
//         food: food,
//         meal: selectedMeal,
//         servings: 1,
//         date: Date(),
//         notes: nil
//     ) { result in
//         switch result {
//         case .success(let loggedFood):
//             print("Food logged successfully: \(loggedFood)")
            
//             withAnimation {
//                 checkmarkStates[food.id] = true
//             }
//             DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                 withAnimation {
//                     checkmarkStates[food.id] = false
//                 }
//             }
//         case .failure(let error):
//             print("Error logging food: \(error)")
//             errorMessage = "An error occurred while logging. Try again."
//             showErrorAlert = true
//         }
//     }
// }) {
//     if checkmarkStates[food.id] == true {
//         Image(systemName: "checkmark.circle.fill")
//             .font(.system(size: 24))
//             .foregroundColor(.green)
//             .transition(.opacity)
//     } else {
//         Image(systemName: "plus.circle.fill")
//             .font(.system(size: 24))
//             .foregroundColor(.accentColor)
//     }
// }
// .alert("Something went wrong", isPresented: $showErrorAlert) {
//     Button("OK", role: .cancel) { }
// } message: {
//     Text(errorMessage)
// }
//                 // Prevent the button tap from triggering the navigation:
//                 .buttonStyle(PlainButtonStyle())
//             }
//             .contentShape(Rectangle()) // Makes the whole row tappable
//         }
//     }
//         }        
//                 .listStyle(.plain)
//                 .safeAreaInset(edge: .bottom) {
//     Color.clear.frame(height: 60)
// }
//             } else {
//                 switch selectedFoodTab {
//                 case .meals:
//                     Text("Meals content")
//                 case .recipes:
//                     Text("Recipes content")
//                 default:
//                     EmptyView()
//                 }
//             }
            
//             Spacer()
//         }
//         .edgesIgnoringSafeArea(.horizontal)
//         .searchable(text: $searchText, prompt: selectedFoodTab.searchPrompt)
//         .onChange(of: searchText) { newValue in
//             Task {
//                 try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
//                 await searchFoods()
//             }
//         }
//         .navigationBarTitleDisplayMode(.inline)
//         .toolbar {
//             ToolbarItem(placement: .navigationBarLeading) {
//                 Button("Cancel") {
//                     selectedTab = 0  // Switch back to Dashboard
//                     dismiss()
//                 }
//                 .foregroundColor(.accentColor)
//             }
            
//             ToolbarItem(placement: .principal) {
//                 Menu {
//                     Button("Breakfast") { selectedMeal = "Breakfast" }
//                     Button("Lunch") { selectedMeal = "Lunch" }
//                     Button("Dinner") { selectedMeal = "Dinner" }
//                 } label: {
//                     HStack(spacing: 4) {
//                         Text(selectedMeal)
//                             .foregroundColor(.primary)
//                             .fontWeight(.semibold)
//                         Image(systemName: "chevron.up.chevron.down")
//                             .font(.system(size: 10))
//                             .foregroundColor(.primary)
//                     }
//                 }
//             }
//         }
//     }
    
//     private func searchFoods() async {
//     guard !searchText.isEmpty else {
//         searchResults = []
//         return
//     }
    
//     isSearching = true
//     do {
//         let response = try await FoodService.shared.searchFoods(query: searchText)
//         searchResults = response.foods
//     } catch {
//         print("Search error:", error)
//         searchResults = []
//     }
//     isSearching = false
// }
// }

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
    // We’re handling per‑row checkmarks in the FoodRow subview.
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
                                .padding(.vertical, 8)
                            
                            ForEach(foodManager.loggedFoods) { loggedFood in
                                HistoryRow(
                                    loggedFood: loggedFood,
                                    selectedMeal: $selectedMeal
                                )
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
        .task {
            // Load logged foods when view appears
            try? await foodManager.loadLoggedFoods(email: viewModel.email)
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

// MARK: - FoodRow (for search results)
// struct FoodRow: View {
//     @EnvironmentObject var foodManager: FoodManager
//     @EnvironmentObject var viewModel: OnboardingViewModel
//     let food: Food
//     let selectedMeal: Binding<String>
//     @State private var checkmarkVisible: Bool = false
//     @State private var showErrorAlert: Bool = false
//     @State private var errorMessage: String = ""
    
//     var body: some View {
//         ZStack {
//             NavigationLink(value: FoodNavigationDestination.foodDetails(food, selectedMeal)) {
//                 EmptyView()
//             }
//             .opacity(0)
            
//             HStack {
//                 VStack(alignment: .leading, spacing: 4) {
//                     Text(food.displayName)
//                         .font(.headline)
//                     HStack {
//                         if let calories = food.calories {
//                             Text("\(Int(calories)) cal")
//                         }
//                         Text("•")
//                         Text(food.servingSizeText)
//                         if let brand = food.brandText {
//                             Text("•")
//                             Text(brand)
//                         }
//                     }
//                     .font(.subheadline)
//                     .foregroundColor(.gray)
//                 }
//                 Spacer()
//                 Button {
//                     HapticFeedback.generate()
//                     logFood()
//                 } label: {
//                     if checkmarkVisible {
//                         Image(systemName: "checkmark.circle.fill")
//                             .font(.system(size: 24))
//                             .foregroundColor(.green)
//                             .transition(.opacity)
//                     } else {
//                         Image(systemName: "plus.circle.fill")
//                             .font(.system(size: 24))
//                             .foregroundColor(.accentColor)
//                     }
//                 }
//                 .buttonStyle(PlainButtonStyle())
//             }
//             .contentShape(Rectangle())
//         }
//         .alert("Something went wrong", isPresented: $showErrorAlert) {
//             Button("OK", role: .cancel) { }
//         } message: {
//             Text(errorMessage)
//         }
//     }
    
//    private func logFood() {
//         foodManager.logFood(
//             email: viewModel.email,
//             food: food,
//             meal: selectedMeal.wrappedValue,
//             servings: 1,
//             date: Date(),
//             notes: nil
//         ) { result in
//             switch result {
//             case .success(let loggedFood):
//                 print("Food logged successfully: \(loggedFood)")
//                 withAnimation { checkmarkVisible = true }
//                 // Refresh the logged foods list
//                 foodManager.refreshLoggedFoods(email: viewModel.email)
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                     withAnimation { checkmarkVisible = false }
//                 }
//             case .failure(let error):
//                 print("Error logging food: \(error)")
//                 errorMessage = "An error occurred while logging. Try again."
//                 showErrorAlert = true
//             }
//         }
//     }
// }

// MARK: - HistoryRow (for logged foods)
// Since LoggedFood has no 'displayName' or 'servingSizeText', we use its available properties.
// struct HistoryRow: View {
//     let loggedFood: LoggedFood
    
//     var body: some View {
//         HStack {
//             VStack(alignment: .leading, spacing: 4) {
//                 // Use the logged message as the title
//                 Text(loggedFood.message)
//                     .font(.headline)
//                 HStack {
//                     Text("\(Int(loggedFood.calories)) cal")
//                     Text("•")
//                     Text("Log ID: \(loggedFood.foodLogId)")
//                 }
//                 .font(.subheadline)
//                 .foregroundColor(.gray)
//             }
//             Spacer()
//         }
//     }
// }


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
                    if checkmarkVisible {
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
                withAnimation { checkmarkVisible = true }
                foodManager.refreshLoggedFoods(email: viewModel.email)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { checkmarkVisible = false }
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
            selectedMeal: selectedMeal
        )
    }
}

extension LoggedFoodItem {
    var asFood: Food {
        Food(
            fdcId: 0,  // Local food
            description: displayName,
            brandOwner: nil,
            brandName: brandText,
            servingSize: nil,
            servingSizeUnit: nil,
            householdServingFullText: servingSizeText,
            foodNutrients: [
                Nutrient(
                    nutrientName: "Energy",
                    value: calories,
                    unitName: "kcal"
                )
            ],
            foodMeasures: []
        )
    }
}