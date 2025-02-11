//
//  LogFood.swift
//  Pods
//
//  Created by Dimi Nunez on 2/10/25.
//

import SwiftUI

struct LogFood: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMeal: String
    @State private var showMealPicker = false
    @Binding var selectedTab: Int
    @State private var searchText = ""
    @State private var selectedFoodTab: FoodTab = .all
    
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
    
    init(selectedTab: Binding<Int>) {
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
        _selectedMeal = State(initialValue: defaultMeal)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Horizontal tab panel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 35) {  // Increased spacing between tabs
                    ForEach(foodTabs, id: \.self) { tab in
                        VStack(spacing: 8) {
                            Text(tab.title)
                                .font(.system(size: 17))  // Increased font size
                                .fontWeight(.semibold)  // Added semibold weight
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
            switch selectedFoodTab {
            case .all:
                Text("All content")
            case .meals:
                Text("Meals content")
            case .recipes:
                Text("Recipes content")
            case .foods:
                Text("Foods content")
            }
            
            Spacer()
        }
        .edgesIgnoringSafeArea(.horizontal)
        .searchable(text: $searchText, prompt: selectedFoodTab.searchPrompt)
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
                    HStack(spacing: 4) {  // Reduced spacing between text and chevron
                        Text(selectedMeal)  // Show the selected meal instead of "Select a Meal"
                            .foregroundColor(.primary)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))  // Even smaller chevron
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}
