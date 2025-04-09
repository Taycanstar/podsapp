//
//  AddFoodView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/8/25.
//

import SwiftUI

enum AddFoodTab: Hashable {
    case all, myFoods, savedScans
    
    var title: String {
        switch self {
        case .all: return "All"
        case .myFoods: return "My Foods"
        case .savedScans: return "Saved Scans"
        }
    }
    
    var searchPrompt: String {
        switch self {
        case .all, .myFoods, .savedScans:
            return "Search"
        }
    }
}

enum AddFoodMode {
    case addToMeal
    case addToRecipe
}

struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var navState: FoodNavigationState
    
    @Binding var path: NavigationPath
    @Binding var selectedFoods: [Food]
    
    let mode: AddFoodMode
    
    // Search and tab state
    @State private var searchText = ""
    @State private var selectedTab: AddFoodTab = .all
    @State private var searchResults: [Food] = []
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var activateSearch = false
    
    // Track selected food IDs for UI
    @State private var selectedFoodIds = Set<Int>()
    
    // Add state for food generation
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    let foodTabs: [AddFoodTab] = [.all, .myFoods, .savedScans]
    
    // MARK: - Body
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
                ScrollView {
                    VStack(spacing: 12) {
                        // Add invisible spacing at the top to prevent overlap with header
                        Color.clear.frame(height: 4)
                        
                        foodListContent
                    }
                    .padding(.bottom, 16)
                }
            }
            .edgesIgnoringSafeArea(.bottom) // Only ignore bottom safe area
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: selectedTab.searchPrompt
            )
            .focused($isSearchFieldFocused)
            .onChange(of: searchText) { _ in
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await searchFoods()
                }
            }
            .onAppear {
                // Load foods and populate selected IDs
                foodManager.refresh()
                
                // Initialize selected food IDs
                for food in selectedFoods {
                    selectedFoodIds.insert(food.fdcId)
                }
                
                // Set focus to the search field
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    isSearchFieldFocused = true
                    activateSearch = true
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Food")
                        .font(.headline)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .background(
                SearchActivator(isActivated: $activateSearch)
            )
        }
    }
    
    // MARK: - Subviews
    private var tabHeaderView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(foodTabs, id: \.self) { tab in
                    TabButton(tab: tab, selectedTab: $selectedTab)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
    }
    
    private var foodListContent: some View {
        Group {
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                VStack(spacing: 12) {
                    // Show Generate Food with AI button when there's search text
                    if !searchText.isEmpty {
                        Button(action: {
                            print("AI tapped for: \(searchText)")
                            HapticFeedback.generateLigth()
                            
                            // Generate food with AI
                            foodManager.generateFoodWithAI(foodDescription: searchText) { result in
                                switch result {
                                case .success(let food):
                                    // Add to selection
                                    selectedFoodIds.insert(food.fdcId)
                                    selectedFoods.append(food)
                                    
                                    // Track as recently added
                                    foodManager.trackRecentlyAdded(foodId: food.fdcId)
                                    
                                case .failure(let error):
                                    // Show error alert
                                    if let networkError = error as? NetworkError, case .serverError(let message) = networkError {
                                        errorMessage = message
                                    } else {
                                        errorMessage = error.localizedDescription
                                    }
                                    showErrorAlert = true
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Spacer()
                                Image(systemName: "sparkle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.accentColor)
                                Text("Generate Food with AI")
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
                    
                    if getDisplayFoods().isEmpty {
                        Text(getNoResultsMessage())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(getDisplayFoods(), id: \.id) { food in
                                FoodItem(
                                    food: food,
                                    isSelected: selectedFoodIds.contains(food.fdcId),
                                    onTap: { toggleFoodSelection(food) }
                                )
                                Divider()
                            }
                        }
                        .background(Color("iosnp"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Helper Functions
    private func searchFoods() async {
        guard !searchText.isEmpty else {
            searchResults = []
            isSearching = false
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
    
    private func getDisplayFoods() -> [Food] {
        switch selectedTab {
        case .all:
            // Use searchResults for searches
            return searchText.isEmpty ? getRecentFoods() : searchResults
        case .myFoods:
            // Return recent foods from logged foods
            return getRecentFoods()
        case .savedScans:
            // This will be implemented later
            return []
        }
    }
    
    // Helper method to get recent foods from logged foods
    private func getRecentFoods() -> [Food] {
        // Get unique recent foods from the loggedFoods
        let recentFoods = foodManager.loggedFoods.prefix(10).map { loggedFood -> Food in
            Food(
                fdcId: loggedFood.food.fdcId,
                description: loggedFood.food.displayName,
                brandOwner: nil,
                brandName: loggedFood.food.brandText,
                servingSize: nil,
                numberOfServings: loggedFood.food.numberOfServings,
                servingSizeUnit: nil,
                householdServingFullText: loggedFood.food.servingSizeText,
                foodNutrients: [
                    Nutrient(nutrientName: "Energy", value: loggedFood.food.calories, unitName: "kcal"),
                    Nutrient(nutrientName: "Protein", value: loggedFood.food.protein ?? 0, unitName: "g"),
                    Nutrient(nutrientName: "Carbohydrate, by difference", value: loggedFood.food.carbs ?? 0, unitName: "g"),
                    Nutrient(nutrientName: "Total lipid (fat)", value: loggedFood.food.fat ?? 0, unitName: "g")
                ],
                foodMeasures: []
            )
        }
        
        return Array(recentFoods)
    }
    
    private func getNoResultsMessage() -> String {
        switch selectedTab {
        case .all:
            return searchText.isEmpty ? 
                "No suggested foods. Try searching." : 
                "No results found for '\(searchText)'."
        case .myFoods:
            return "No saved foods found."
        case .savedScans:
            return "No saved scans found."
        }
    }
    
    private func toggleFoodSelection(_ food: Food) {
        if selectedFoodIds.contains(food.fdcId) {
            // Remove food
            selectedFoodIds.remove(food.fdcId)
            selectedFoods.removeAll(where: { $0.fdcId == food.fdcId })
        } else {
            // Add food
            selectedFoodIds.insert(food.fdcId)
            
            // Create a copy with numberOfServings = 1
            var newFood = food
            newFood.numberOfServings = 1
            selectedFoods.append(newFood)
        }
        
        // Haptic feedback
        HapticFeedback.generate()
    }
}

// MARK: - Supporting Views

struct FoodItem: View {
    let food: Food
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
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
                        
                        // Check if the serving size text is meaningful
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
                
                // Show checkmark if selected, otherwise show plus button
                if isSelected {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

private struct TabButton: View {
    let tab: AddFoodTab
    @Binding var selectedTab: AddFoodTab
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

// MARK: - Preview
#Preview {
    AddFoodView(
        path: .constant(NavigationPath()),
        selectedFoods: .constant([]),
        mode: .addToMeal
    )
    .environmentObject(FoodManager())
    .environmentObject(FoodNavigationState())
}
