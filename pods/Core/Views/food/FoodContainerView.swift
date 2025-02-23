//
//  FoodContainerView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/10/25.
//

import Foundation
import SwiftUI

enum FoodNavigationDestination: Hashable {
    case logFood
    case foodDetails(Food, Binding<String>) // Food and selected meal
    case createMeal 
    case addMealItems
    
    static func == (lhs: FoodNavigationDestination, rhs: FoodNavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.logFood, .logFood):
            return true
        case let (.foodDetails(food1, meal1), .foodDetails(food2, meal2)):
            return food1.id == food2.id && meal1.wrappedValue == meal2.wrappedValue
        case (.addMealItems, .addMealItems):
            return true
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .logFood:
            hasher.combine(0)
        case .foodDetails(let food, let meal):   
            hasher.combine(1)
            hasher.combine(food.id)
            hasher.combine(meal.wrappedValue)
        case .createMeal:
            hasher.combine(2)
        case .addMealItems:
            hasher.combine(3)
        }
    }
}


struct FoodContainerView: View {
    @State private var path = NavigationPath()
    @Binding var selectedTab: Int
    @State private var selectedMeal: String
        @State private var selectedFoods: [Food] = []
    
    
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
        NavigationStack(path: $path) {
            // LogFood(selectedTab: $selectedTab, selectedMeal: $selectedMeal, path: $path)

            LogFood(
            selectedTab: $selectedTab,
            selectedMeal: $selectedMeal,
            path: $path,
            mode: .logFood, 
            selectedFoods: $selectedFoods
        )
                .navigationDestination(for: FoodNavigationDestination.self) { destination in
                    switch destination {
                    case .logFood:
                        // LogFood(selectedTab: $selectedTab, selectedMeal: $selectedMeal, path: $path)
                             LogFood(
            selectedTab: $selectedTab,
            selectedMeal: $selectedMeal,
            path: $path,
            mode: .logFood,
            selectedFoods: $selectedFoods
        )
                    case .foodDetails(let food, _):
                        FoodDetailsView(food: food, selectedMeal: $selectedMeal)
                    case .createMeal:
                        // Implementation of create meal view
                        //  CreateMealView()
                        CreateMealView(path: $path, selectedFoods: $selectedFoods )
                    case .addMealItems:
                        LogFood(
                            selectedTab: $selectedTab,
                            selectedMeal: $selectedMeal,
                            path: $path,
                            mode: .addToMeal,
                            selectedFoods: $selectedFoods
                        )
             
                    }
                }
        }
    }
}
