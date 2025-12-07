//
//  AddFoodView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/8/25.
//

import SwiftUI

enum AddFoodTab: Hashable {
    case all, myFoods
    
    var title: String {
        switch self {
        case .all: return "All"
        case .myFoods: return "My Foods"

        }
    }
    
    var searchPrompt: String {
        switch self {
        case .all, .myFoods:
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
    @EnvironmentObject private var proFeatureGate: ProFeatureGate
    
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
    // Legacy local loading state (no longer used with modern loader)
    @State private var isGeneratingFood = false
    // Change from a single generated food to an array of generated foods
    @State private var generatedFoods: [Food] = []
    
    // Create Food sheets
    @State private var showCreateFoodWithVoice = false
    @State private var showCreateFoodWithScan = false
    @State private var showCreateFood = false
    @State private var showProSearch = false
    
    // Confirmation sheet for scanned foods
    @State private var scannedFoodForConfirmation: Food? = nil
    @State private var showConfirmationSheet = false
    
    // Nutrition label name input for recipe
    @State private var nutritionProductName = ""

    
    let foodTabs: [AddFoodTab] = [.all, .myFoods]
    
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
                // Initialize selected food IDs
                for food in selectedFoods {
                    selectedFoodIds.insert(food.fdcId)
                }
                
                // Set focus to the search field
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    isSearchFieldFocused = true
                    activateSearch = true
                }
                
                // Force refresh user foods
                foodManager.loadUserFoods(refresh: true)
            }

            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Food")
                        .font(.headline)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        openProSearch()
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    Button("Done") {
                        addSelectedFoodsToMeal()
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
            .sheet(isPresented: $showCreateFoodWithVoice) {
                AddFoodWithVoice { createdFood in
                    print("🔍 DEBUG: AddFoodWithVoice completion called with food: \(createdFood.displayName)")
                    
                    // Voice input automatically adds without confirmation
                    DispatchQueue.main.async {
                        // Add the food directly to the recipe (no confirmation needed for voice)
                        generatedFoods.append(createdFood)
                        selectedFoodIds.insert(createdFood.fdcId)
                        
                        print("✅ Food added to recipe from voice: \(createdFood.displayName)")
                        
                        // Clean up scanning states
                        cleanupScanningStates()
                    }
                }
            }
            .sheet(isPresented: $showCreateFoodWithScan) {
                AddFoodWithScan(
                    onFoodScanned: { createdFood, scanType in
                        print("🔍 DEBUG: AddFoodWithScan completion called with food: \(createdFood.displayName), scanType: \(scanType)")
                        
                        // Use a slight delay to ensure the sheet has properly dismissed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // IMPORTANT: When onFoodScanned is called, it means the preference check
                            // in AddFoodWithScan has already determined that preview should be shown.
                            // If preview was disabled, AddFoodWithScan would have added directly.
                            
                            // Always show confirmation sheet when this callback is triggered
                            scannedFoodForConfirmation = createdFood
                            showConfirmationSheet = true
                            print("🔍 DEBUG: Set showConfirmationSheet = true for \(scanType) food: \(createdFood.displayName)")
                        }
                    },
                    generatedFoods: $generatedFoods,
                    selectedFoodIds: $selectedFoodIds
                )
            }
            .sheet(isPresented: $showCreateFood) {
                CreateAddFoodView { createdFood in
                    // Add the created food to the selected foods and mark as selected
                    generatedFoods.append(createdFood)
                    selectedFoodIds.insert(createdFood.fdcId)
                    
                    // Track as recently added
                    foodManager.trackRecentlyAdded(foodId: createdFood.fdcId)
                }
            }
            .sheet(isPresented: $showProSearch) {
                if let email = currentUserEmail {
                    ProFoodSearchView(userEmail: email)
                        .environmentObject(proFeatureGate)
                }
            }

            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Product Name Required", isPresented: $foodManager.showNutritionNameInputForRecipe) {
                TextField("Enter product name", text: $nutritionProductName)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    foodManager.cancelNutritionNameInputForRecipe()
                }
                Button("Save") {
                    if !nutritionProductName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Build food data from pending nutrition data instead of creating it in DB
                        foodManager.buildFoodFromNutritionData(
                            name: nutritionProductName,
                            nutritionData: foodManager.pendingNutritionDataForRecipe
                        ) { result in
                            DispatchQueue.main.async {
                                nutritionProductName = "" // Reset for next time
                                switch result {
                                case .success(let food):
                                    print("✅ Successfully built nutrition label food data for recipe")
                                    
                                    // Check preference for food label scan
                                    let foodLabelPreviewEnabled = UserDefaults.standard.object(forKey: "scanPreview_foodLabel") as? Bool ?? true
                                    
                                    if foodLabelPreviewEnabled {
                                        // Show confirmation sheet by setting scannedFoodForConfirmation
                                        print("🏷️ Food label preview enabled - showing confirmation")
                                        self.scannedFoodForConfirmation = food
                                        self.showConfirmationSheet = true
                                        // Clear loader states since food data is ready
                                        self.foodManager.isScanningFood = false
                                        self.foodManager.isGeneratingFood = false
                                    } else {
                                        // Add directly without confirmation
                                        print("🏷️ Food label preview disabled - adding directly")
                                        self.generatedFoods.append(food)
                                        self.selectedFoodIds.insert(food.fdcId)
                                        
                                        // Track as recently added
                                        self.foodManager.trackRecentlyAdded(foodId: food.fdcId)
                                        
                                        // Clear loader states
                                        self.foodManager.isScanningFood = false
                                        self.foodManager.isGeneratingFood = false
                                    }
                                    
                                case .failure(let error):
                                    print("❌ Failed to build nutrition label food data: \(error)")
                                }
                            }
                        }
                    }
                }
                .disabled(nutritionProductName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("We couldn't find the product name on the nutrition label. Please enter it manually.")
            }
            .alert(foodManager.scanFailureType, isPresented: $foodManager.showScanFailureAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(foodManager.scanFailureMessage)
            }
                        .sheet(isPresented: $showConfirmationSheet, onDismiss: {
                // Clean up scanning states if sheet is dismissed without confirming
                if scannedFoodForConfirmation != nil {
                    cleanupScanningStates()
                    scannedFoodForConfirmation = nil
                }
            }) {
                if let food = scannedFoodForConfirmation {
              
                    ConfirmAddFoodView(food: food) { confirmedFood in
                        print("🔍 DEBUG: Food confirmed: \(confirmedFood.displayName)")
                        // Add the confirmed food to the selected foods and mark as selected
                        generatedFoods.append(confirmedFood)
                        selectedFoodIds.insert(confirmedFood.fdcId)
                        
                        // Track as recently added
                        foodManager.trackRecentlyAdded(foodId: confirmedFood.fdcId)
                        
                        // Clear the confirmation state
                        scannedFoodForConfirmation = nil
                        
                        // Clean up scanning states now that confirmation is complete
                        cleanupScanningStates()
                    }
                } else {
          
                    Text("Error: No food to confirm")
                }
            }
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
                    // Show Create Food dropdown when there's no search text
                    if searchText.isEmpty && !foodManager.foodScanningState.isActive {
                                            Menu {
                        Button(action: {
                            print("Tapped Manual Create Food for Recipe")
                            HapticFeedback.generateLigth()
                            showCreateFood = true
                        }) {
                            HStack {
                                Text("Enter Manually")
                                Spacer()
                                Image(systemName: "square.and.pencil")
                            }
                        }
                        
                        Button(action: {
                            print("Tapped Voice Create Food for Recipe")
                            HapticFeedback.generateLigth()
                            showCreateFoodWithVoice = true
                        }) {
                            HStack {
                                Text("Describe with Voice")
                                Spacer()
                                Image(systemName: "waveform")
                            }
                        }
                        
                        Button(action: {
                            print("Tapped Scan Create Food for Recipe")
                            HapticFeedback.generateLigth()
                            showCreateFoodWithScan = true
                        }) {
                            HStack {
                                Text("Scan Food")
                                Spacer()
                                Image(systemName: "barcode.viewfinder")
                            }
                        }
                    } label: {
                            HStack(spacing: 6) {
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.accentColor)
                                Text("Create Food")
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
                    // Show Generate Food with AI button when there's search text
                    else if !searchText.isEmpty {
                        Button(action: {
                            print("AI tapped for: \(searchText)")
                            HapticFeedback.generateLigth()
                            
                            // Modern loader handles state via FoodManager
                            
                            // Generate food with AI - skip confirmation for text search
                            foodManager.generateFoodWithAI(foodDescription: searchText, skipConfirmation: true) { result in

                                switch result {
                                case .success(let response):
                                    switch response.resolvedFoodResult {
                                    case .success(let generatedFood):
                                        // Create the food in the database
                                        foodManager.createManualFood(food: generatedFood, showPreview: false) { createResult in
                                            DispatchQueue.main.async {
                                                switch createResult {
                                                case .success(let createdFood):
                                                    // Store the created food
                                                    generatedFoods.append(createdFood)

                                                    // Mark as selected in the UI (but don't add to meal yet)
                                                    selectedFoodIds.insert(createdFood.fdcId)

                                                    // Track as recently added
                                                    foodManager.trackRecentlyAdded(foodId: createdFood.fdcId)

                                                    // Clear the search text after successful generation
                                                    searchText = ""

                                                    print("✅ Food created from text search for recipe: \(createdFood.displayName)")

                                                case .failure(let error):
                                                    print("❌ Failed to create food in database: \(error)")
                                                }
                                            }
                                        }

                                    case .failure(let genError):
                                        errorMessage = genError.localizedDescription
                                        showErrorAlert = true
                                    }
                                    
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
                        .disabled(foodManager.foodScanningState.isActive) // Disable while modern loader active
                    }
                    
                    // Modern unified loader (replaces legacy FoodGenerationCard)
                    if foodManager.foodScanningState.isActive {
                        ModernFoodLoadingCard(state: foodManager.foodScanningState)
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // Display selected foods section if we have any selections
                    if !selectedFoodIds.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selected Foods")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                let selectedGeneratedFoods = generatedFoods.filter { selectedFoodIds.contains($0.fdcId) }
                                let otherSelectedFoods = getDisplayFoods().filter { food in
                                    selectedFoodIds.contains(food.fdcId) && 
                                    !generatedFoods.contains { genFood in genFood.fdcId == food.fdcId }
                                }
                                let allSelectedFoods = selectedGeneratedFoods + otherSelectedFoods
                                
                                // Show all selected foods with conditional dividers
                                ForEach(Array(allSelectedFoods.enumerated()), id: \.element.id) { index, food in
                                    FoodItem(
                                        food: food,
                                        isSelected: true,
                                        onTap: { toggleFoodSelection(food) }
                                    )
                                    
                                    // Only show divider if not the last item
                                    if index < allSelectedFoods.count - 1 {
                                    Divider()
                                    }
                                }
                            }
                            .background(Color("iosnp"))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Show "all foods" section
                    VStack(alignment: .leading, spacing: 8) {
                        if !selectedFoodIds.isEmpty {
                            Text("All Foods")
                                .font(.headline)
                                .padding(.horizontal)
                        }
                        
                        if getDisplayFoods().filter({ !selectedFoodIds.contains($0.fdcId) }).isEmpty && searchResults.filter({ !selectedFoodIds.contains($0.fdcId) }).isEmpty {
                            Text(getNoResultsMessage())
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            VStack(spacing: 0) {
                                // Show unselected foods
                                let unselectedFoods = getDisplayFoods().filter { food in 
                                    !selectedFoodIds.contains(food.fdcId) && 
                                    !generatedFoods.contains { genFood in genFood.fdcId == food.fdcId }
                                }
                                
                                ForEach(Array(unselectedFoods.enumerated()), id: \.element.id) { index, food in
                                    FoodItem(
                                        food: food,
                                        isSelected: false,
                                        onTap: { toggleFoodSelection(food) }
                                    )
                                    
                                    // Only show divider if not the last item
                                    if index < unselectedFoods.count - 1 {
                                    Divider()
                                    }
                                }
                            }
                            .background(Color("iosnp"))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
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
    
    private func cleanupScanningStates() {
        foodManager.isScanningFood = false
        foodManager.isGeneratingFood = false
        foodManager.scannedImage = nil
        foodManager.loadingMessage = ""
        foodManager.uploadProgress = 0.0
    }
    
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
        }
    }
    
    // Helper method to get foods based on the selected tab
    private func getRecentFoods() -> [Food] {
        switch selectedTab {
        case .all:
            // For the "All" tab, use search results when searching, 
            // or a combination of recently logged foods and user foods when not searching
            if !searchText.isEmpty {
                return searchResults
            } else {
                // Get food items from the combinedLogs for recently logged foods
                let foodLogs = foodManager.combinedLogs.filter { log in
                    if case .food = log.type, log.food != nil {
                        return true
                    }
                    return false
                }
                
                // Convert the food logs to Food objects
                let recentLoggedFoods = foodLogs.compactMap { log -> Food? in
                    guard case .food = log.type, let loggedFood = log.food else {
                        return nil
                    }
                    
                    return Food(
                        fdcId: loggedFood.fdcId,
                        description: loggedFood.displayName,
                        brandOwner: nil,
                        brandName: loggedFood.brandText,
                        servingSize: nil,
                        numberOfServings: loggedFood.numberOfServings,
                        servingSizeUnit: nil,
                        householdServingFullText: loggedFood.servingSizeText,
                        foodNutrients: [
                            Nutrient(nutrientName: "Energy", value: loggedFood.calories, unitName: "kcal"),
                            Nutrient(nutrientName: "Protein", value: loggedFood.protein ?? 0, unitName: "g"),
                            Nutrient(nutrientName: "Carbohydrate, by difference", value: loggedFood.carbs ?? 0, unitName: "g"),
                            Nutrient(nutrientName: "Total lipid (fat)", value: loggedFood.fat ?? 0, unitName: "g")
                        ],
                        foodMeasures: []
                    )
                }
                
                // Combine recent logged foods with user foods (avoiding duplicates)
                let uniqueFoods = Array(Set(recentLoggedFoods + foodManager.userFoods)).sorted { 
                    $0.fdcId > $1.fdcId // Show newest first based on ID
                }
                
                return uniqueFoods
            }
            
        case .myFoods:
            // Use the userFoods array that contains all created foods
            if foodManager.userFoods.isEmpty && !foodManager.isLoadingUserFoods {
                // Try to load them if they're not already loaded
                foodManager.loadUserFoods(refresh: false)
            }
            return foodManager.userFoods
            

        }
    }
    
    private func getNoResultsMessage() -> String {
        switch selectedTab {
        case .all:
            return searchText.isEmpty ? 
                "No suggested foods. Try searching." : 
                "No results found for '\(searchText)'."
        case .myFoods:
            return "No saved foods found."

        }
    }
    
    private func toggleFoodSelection(_ food: Food) {
        if selectedFoodIds.contains(food.fdcId) {
            // Remove food ID from selected list
            selectedFoodIds.remove(food.fdcId)
            
            // Only remove from selectedFoods (actual meal items) if it was already there
            selectedFoods.removeAll(where: { $0.fdcId == food.fdcId })
        } else {
            // Add food ID to selected list
            selectedFoodIds.insert(food.fdcId)
            
            // Don't add to meal until "Done" is tapped
            // This line is commented out to change the behavior
            // selectedFoods.append(food)
        }
        
        // Haptic feedback
        HapticFeedback.generate()
    }
    
    private var currentUserEmail: String? {
        let email = UserDefaults.standard.string(forKey: "userEmail")
        return email?.isEmpty == false ? email : nil
    }
    
    private func openProSearch() {
        guard let email = currentUserEmail else { return }
        proFeatureGate.requirePro(for: .proSearch, userEmail: email) {
            Task { await proFeatureGate.refreshUsageSummary(for: email) }
            showProSearch = true
        }
    }
    
    // Add function to handle the Done button
    // This will add all selected foods to the meal when Done is tapped
    private func addSelectedFoodsToMeal() {
        // For each selected food ID, create a copy with numberOfServings = 1
        // and add it to selectedFoods if it's not already there
        for foodId in selectedFoodIds {
            // Skip if already in selectedFoods
            if selectedFoods.contains(where: { $0.fdcId == foodId }) {
                continue
            }
            
            // Find the food in our generated foods first
            if let food = generatedFoods.first(where: { $0.fdcId == foodId }) {
                var newFood = food
                newFood.numberOfServings = 1
                selectedFoods.append(newFood)
            }
            // Then check in the display foods
            else if let food = (getDisplayFoods().first { $0.fdcId == foodId }) {
                var newFood = food
                newFood.numberOfServings = 1
                selectedFoods.append(newFood)
            }
        }
        
        dismiss()
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
                                .lineLimit(1)
                                .truncationMode(.tail)
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
