//
//  LogFood.swift
//  Pods
//
//  Created by Dimi Nunez on 2/10/25.
//

import SwiftUI

struct LogFood: View {
    @Environment(\.dismiss) private var dismiss
    // @State private var selectedMeal: String
    @Binding var selectedMeal: String
    @State private var showMealPicker = false
    @Binding var selectedTab: Int
    @State private var searchText = ""
    @State private var selectedFoodTab: FoodTab = .all
    @State private var searchResults: [Food] = []
    @State private var isSearching = false
    
    enum FoodTab {
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
        // Set initial meal based on time of day
        let hour = Calendar.current.component(.hour, from: Date())
        let defaultMeal: String
        
        switch hour {
        case 4...11:  // 4:00 AM to 11:00 AM
            defaultMeal = "Breakfast"
        case 12...16:  // 11:01 AM to 4:00 PM
            defaultMeal = "Lunch"
        default:  // 4:01 PM to 3:59 AM
            defaultMeal = "Dinner"
        }
        // _selectedMeal = State(initialValue: defaultMeal)
        _selectedMeal = selectedMeal
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
                            
                            // Indicator bar
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
            
            // Content based on selected tab
            if selectedFoodTab == .all || selectedFoodTab == .foods {
                // List {
                //     ForEach(searchResults) { food in
                //         NavigationLink(value: FoodNavigationDestination.foodDetails(food, $selectedMeal)) {
                //             HStack {
                //                            VStack(alignment: .leading, spacing: 4) {
                //                 Text(food.displayName)
                //                     .font(.headline)
                                
                //                 HStack {
                //                     if let calories = food.calories {
                //                         Text("\(Int(calories)) cal")
                //                     }
                //                     Text("•")
                //                     Text(food.servingSizeText)
                //                     if let brand = food.brandText {
                //                         Text("•")
                //                         Text(brand)
                //                     }
                //                 }
                //                 .font(.subheadline)
                //                 .foregroundColor(.gray)  
                               
                //             }
                           
                //                 Spacer()
                //                 Button(action: {
                //                        print("tapped plus")

                //                     }) {
                //                        Image(systemName: "plus.circle.fill")
                //                        .foregroundColor(.accentColor)
                //                 .font(.system(size: 24))
                //                     }
                //             }
                         
                //             .onTapGesture {
                //                 print("Food tapped:", food)
                //                 print("Nutrients:", food.foodNutrients)
                //                 print("Calories:", food.calories)
                //                 print("Selected Meal:", selectedMeal)
                //             }
                //         }
                     
                       
                     
                //     }
                   
                // }
                List {
    ForEach(searchResults) { food in
        ZStack {
            // Invisible NavigationLink providing the navigation
            NavigationLink(value: FoodNavigationDestination.foodDetails(food, $selectedMeal)) {
                EmptyView()
            }
            .opacity(0)
            
            // Your custom row content
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
                Button(action: {
                    print("Tapped plus")
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 24))
                }
                // Prevent the button tap from triggering the navigation:
                .buttonStyle(PlainButtonStyle())
            }
            .contentShape(Rectangle()) // Makes the whole row tappable
        }
    }
        }        
                .listStyle(.plain)
                .safeAreaInset(edge: .bottom) {
    Color.clear.frame(height: 60)
}
            } else {
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
        .onChange(of: searchText) { newValue in
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await searchFoods()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    selectedTab = 0  // Switch back to Dashboard
                    dismiss()
                }
                .foregroundColor(.accentColor)
            }
            
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
    }
    
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
