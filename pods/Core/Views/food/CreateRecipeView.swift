//
//  CreateRecipeView.swift
//  Pods
//
//  Created by Dimi Nunez on 3/16/25.
//

import SwiftUI
import PhotosUI



struct CreateRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var recipeName = ""
    @State private var shareWith = "Everyone"
    @State private var instructions = ""
    @State private var prepTime = ""
    @State private var cookTime = ""
    @State private var servings = "1"
    @State private var showingShareOptions = false
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    @State private var showImagePicker = false
    @State private var showOptionsSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    
    @State private var imageURL: URL? = nil
    @State private var uploadProgress: Double = 0
    @State private var isUploading = false
    @State private var uploadError: Error?
    @State private var showUploadError = false
    
    @State private var showNameTakenAlert = false
    @State private var uiImage: UIImage? = nil
    
    // Add these states to track saving
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var errorMessage = ""

    @FocusState private var focusedField: Field?

    @Binding var path: NavigationPath
    @Binding var selectedFoods: [Food]
    @EnvironmentObject var foodManager: FoodManager
    
    // Example share options
    let shareOptions = ["Everyone", "Friends", "Only You"]
    
    // Adjust how tall you want the banner/collapsing area to be
    let headerHeight: CGFloat = 400
    
    // MARK: - Computed Properties
    
    private var isCreateButtonDisabled: Bool {
        return recipeName.isEmpty
    }
    
    // Break down the nutrition calculations into separate properties
    private var servingsValue: Double {
        Double(Int(servings) ?? 1)
    }
    
    private var macroPercentages: (protein: Double, carbs: Double, fat: Double) {
        let totals = calculateTotalMacros(selectedFoods)
        return (
            protein: totals.proteinPercentage,
            carbs: totals.carbsPercentage,
            fat: totals.fatPercentage
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { outerGeo in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .top) {
                    // A) Collapsing / Stretchy Header
                    GeometryReader { headerGeo in
                        let offset = headerGeo.frame(in: .global).minY
                        let height = offset > 0
                            ? (headerHeight + offset)
                            : headerHeight
                        
                        // The banner image (if selected), else a placeholder
                        if let selectedImage {
                            selectedImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: outerGeo.size.width, height: height)
                                .clipped()
                                // Shift upward if scrolled up
                                .offset(y: offset > 0 ? -offset : 0)
                                .overlay(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .ignoresSafeArea(edges: .top)
                                .onTapGesture {
                                    showOptionsSheet = true
                                }
                        } else {
                            ZStack {
                                Color("iosnp")
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.accentColor)
                            }
                            .frame(width: outerGeo.size.width, height: height)
                            .offset(y: offset > 0 ? -offset : 0)
                            .onTapGesture {
                                showOptionsSheet = true
                            }
                            .ignoresSafeArea(edges: .top)
                        }
                    }
                    .frame(height: headerHeight)
                    
                    // B) Main Scrollable Content
                    VStack(spacing: 16) {
                        Spacer().frame(height: headerHeight) // leave space for header
                        
                        recipeDetailsSection
                
                        recipeItemsSection
                        directionsSection
                        
                        Spacer().frame(height: 40) // extra bottom space
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(Color("iosbg"))
        // Transparent nav bar so we see banner behind it
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("New Recipe")
                    .foregroundColor(selectedImage != nil ? .white : .primary)
                    .fontWeight(.semibold)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create") {
                    saveNewRecipe()
                }
                .disabled(isCreateButtonDisabled)
                .foregroundColor(selectedImage != nil ? .white : .primary)
                .fontWeight(.semibold)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    resetFields()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(selectedImage != nil ? .white : .primary)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        
        // Full screen cover for ImagePicker
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePicker(
                uiImage: $uiImage,
                image: $selectedImage,
                sourceType: sourceType
            )
        }
        .onChange(of: uiImage) { newUIImage in
            guard let picked = newUIImage else { return }
            // Use your existing `uploadMealImage(_:, completion:)`
            NetworkManager().uploadMealImage(picked) { result in
                switch result {
                case .success(let url):
                    print("Upload success. URL: \(url)")
                    // store if needed, e.g. self.imageURL = url
                case .failure(let error):
                    print("Upload failed:", error)
                    // show alert if you like
                }
            }
        }
        
        // Photo selection dialog
        .confirmationDialog("Choose Photo", isPresented: $showOptionsSheet) {
            Button("Take Photo") {
                sourceType = .camera
                showImagePicker = true
            }
            Button("Choose from Library") {
                sourceType = .photoLibrary
                showImagePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        // Add error alert
        .alert("Upload Error", isPresented: $showUploadError) {
            Button("Retry") {
                // implement retry if needed
            }
            Button("Cancel", role: .cancel) {
                uploadError = nil
            }
        } message: {
            Text(uploadError?.localizedDescription ?? "Unknown error")
        }
        
        // Add error alert
        .alert("Error Saving Recipe", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        
        // Add name taken alert
        .alert("Recipe Name Already Taken", isPresented: $showNameTakenAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please choose a different name.")
        }
    }
    
    // MARK: - View Components
    
    private var recipeDetailsSection: some View {
        VStack(spacing: 8) {
            // Title
            TextField("Title", text: $recipeName)
                .focused($focusedField, equals: .mealName)
                .textFieldStyle(.plain)
            
            Divider()
            
               // Servings row
            HStack {
                Text("Servings")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Stepper(servings, onIncrement: {
                    let currentValue = Int(servings) ?? 1
                    if currentValue < 20 {
                        servings = "\(currentValue + 1)"
                    }
                }, onDecrement: {
                    let currentValue = Int(servings) ?? 1
                    if currentValue > 1 {
                        servings = "\(currentValue - 1)"
                    }
                })
            }

            Divider()
            
            // Share-with row
            HStack {
                Text("Share with")
                    .foregroundColor(.primary)
                
                Spacer()
                Menu {
                    ForEach(shareOptions, id: \.self) { option in
                        Button(option) {
                            shareWith = option
                        }
                    }
                } label: {
                    HStack {
                        Text(shareWith)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color("iosbtn"))
                    .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Macros
            macroCircleAndStats
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    

    
    private var recipeItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe Ingredients")
                .font(.title2)
                .fontWeight(.bold)
            
            // Aggregate duplicates by fdcId
            let aggregatedFoods = aggregateFoodsByFdcId(selectedFoods)
            
            if !aggregatedFoods.isEmpty {
                List {
                    // Use aggregatedFoods instead of selectedFoods
                    ForEach(Array(aggregatedFoods.enumerated()), id: \.element.id) { index, food in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(food.displayName)
                                    .font(.headline)
                                
                                HStack {
                                    Text(food.servingSizeText)
                                    if let servings = food.numberOfServings,
                                       servings > 1 {
                                        Text("×\(Int(servings))")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            if let calories = food.calories {
                                Text("\(Int(calories * (food.numberOfServings ?? 1)))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .listRowBackground(Color("iosnp"))
                        .listRowSeparator(index == aggregatedFoods.count - 1 ? .hidden : .visible)
                    }
                    .onDelete { indexSet in
                        // Remove all items in selectedFoods that belong to the tapped row
                        if let firstIdx = indexSet.first {
                            let foodToRemove = aggregatedFoods[firstIdx]
                            removeAllItems(withFdcId: foodToRemove.fdcId)
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color("iosnp"))
                .cornerRadius(12)
                .scrollDisabled(true)
                // Frame based on aggregatedFoods count
                .frame(height: CGFloat(aggregatedFoods.count * 65))
            }
            
            Button {
                path.append(FoodNavigationDestination.addRecipeIngredients)
            } label: {
                Text("Add ingredient to recipe")
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color("iosnp"))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Directions")
                .font(.title2)
                .fontWeight(.bold)
            
            TextField("Add instructions for making this recipe", text: $instructions, axis: .vertical)
                .focused($focusedField, equals: .instructions)
                .textFieldStyle(.plain)
                .padding()
                .background(Color("iosnp"))
                .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var macroCircleAndStats: some View {
        // Get the totals
        let totals = calculateTotalMacros(selectedFoods)
        
        // Create a unique identifier string based on the selectedFoods
        // This will cause the view to rebuild when selectedFoods changes
        let foodsSignature = selectedFoods.map { "\($0.fdcId)-\($0.numberOfServings ?? 1)" }.joined(separator: ",")
        
        return HStack(spacing: 40) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                // Draw the circle segments with actual percentages
                Circle()
                    .trim(from: 0, to: CGFloat(totals.carbsPercentage) / 100)
                    .stroke(Color("teal"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(from: CGFloat(totals.carbsPercentage) / 100,
                          to: CGFloat(totals.carbsPercentage + totals.fatPercentage) / 100)
                    .stroke(Color("pinkRed"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(from: CGFloat(totals.carbsPercentage + totals.fatPercentage) / 100,
                          to: CGFloat(totals.carbsPercentage + totals.fatPercentage + totals.proteinPercentage) / 100)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(Int(totals.calories))").font(.system(size: 20, weight: .bold))
                    Text("Cal").font(.system(size: 14))
                }
            }
            
            Spacer()
            
            // Carbs
            MacroView(
                value: totals.carbs,
                percentage: totals.carbsPercentage,
                label: "Carbs",
                percentageColor: Color("teal")
            )
            
            // Fat
            MacroView(
                value: totals.fat,
                percentage: totals.fatPercentage,
                label: "Fat",
                percentageColor: Color("pinkRed")
            )
            
            // Protein
            MacroView(
                value: totals.protein,
                percentage: totals.proteinPercentage,
                label: "Protein",
                percentageColor: Color.purple
            )
        }
        // Force redraw when foods change by using the foodsSignature as an id
        .id(foodsSignature)
    }
    
    // MARK: - Functions
    
    private func resetFields() {
        recipeName = ""
        instructions = ""
        prepTime = ""
        cookTime = ""
        servings = "1"
        selectedImage = nil
        selectedFoods.removeAll()
        // Reset any other state variables as needed
    }
    
    // Check if the recipe name is already taken
    private func isNameAlreadyTaken() -> Bool {
        // Get all recipe names
        let existingRecipeNames = foodManager.recipes
            .map { $0.title.lowercased() }
        
        // Check if the current name (trimmed and lowercased) exists
        return existingRecipeNames.contains(recipeName.trimmed().lowercased())
    }
    
    // Validate name before saving
    private func validateRecipeName() -> Bool {
        // Check if name is already taken
        if isNameAlreadyTaken() {
            // Show the alert
            showNameTakenAlert = true
            return false
        }
        return true
    }
    
    private func saveNewRecipe() {
        // First validate the recipe name
        guard validateRecipeName() else {
            return
        }
        
        isSaving = true
        
        // First upload image if exists
        if let uiImage = uiImage {
            NetworkManager().uploadMealImage(uiImage) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let urlString):
                        // Convert the string URL to a URL object
                        if let url = URL(string: urlString) {
                            self.imageURL = url
                            self.createRecipe()
                            self.resetFields()
                        } else {
                            // Handle invalid URL
                            self.isSaving = false
                            self.errorMessage = "Invalid image URL format"
                            self.showSaveError = true
                        }
                    case .failure(let error):
                        self.isSaving = false
                        self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                        self.showSaveError = true
                    }
                }
            }
        } else {
            createRecipe()
            resetFields()
        }
    }
    
    private func createRecipe() {
        guard let servingsInt = Int(servings), servingsInt > 0 else {
            // Handle invalid servings
            errorMessage = "Please enter a valid number of servings"
            showSaveError = true
            return
        }
        
        let prepTimeInt = Int(prepTime) ?? 0
        let cookTimeInt = Int(cookTime) ?? 0
        
        // Calculate macro totals from the current food items
        let totals = calculateTotalMacros(selectedFoods)
        
        let privacy = shareWith == "Everyone" ? "public" : "private"
        
        // Set any existing tags for FoodNavigationDestination
        foodManager.createRecipe(
            title: recipeName,
            description: "",
            instructions: instructions,
            privacy: privacy,
            servings: servingsInt,
            foods: selectedFoods,
            image: imageURL?.absoluteString,
            prepTime: prepTimeInt,
            cookTime: cookTimeInt,
            totalCalories: totals.calories,
            totalProtein: totals.protein,
            totalCarbs: totals.carbs,
            totalFat: totals.fat
        ) { result in
            // Ensure we're on the main thread
            DispatchQueue.main.async {
                self.isSaving = false
                
                switch result {
                case .success(_):
                    // Clear selected foods for future use
                    self.selectedFoods = []
                    
                    // Navigate back by removing this view from the path
                    dismiss()
                    self.path.removeLast()
                    
                case .failure(let error):
                    self.errorMessage = "Error creating recipe: \(error.localizedDescription)"
                    self.showSaveError = true
                }
            }
        }
    }
    
    // MARK: - Aggregation
    
    /// Groups `selectedFoods` by `fdcId`, merges duplicates into one item each, summing up `numberOfServings`.
    private func aggregateFoodsByFdcId(_ allFoods: [Food]) -> [Food] {
        // Dictionary to store the combined foods
        var grouped: [Int: Food] = [:]
        
        // Process foods in order
        for food in allFoods {
            if var existing = grouped[food.fdcId] {
                // Update existing entry by adding servings
                let existingServings = existing.numberOfServings ?? 1
                let additionalServings = food.numberOfServings ?? 1
                let newServings = existingServings + additionalServings
                
                // Create a mutable copy of the existing food to update
                existing.numberOfServings = newServings
                
                grouped[food.fdcId] = existing
            } else {
                // Add new entry
                grouped[food.fdcId] = food
            }
        }
        
        // Create an ordered array of unique foods
        var result: [Food] = []
        
        // First, keep track of which fdcIds we've seen
        var seenIds = Set<Int>()
        
        // Process foods in original order to maintain order
        for food in allFoods {
            if !seenIds.contains(food.fdcId), let groupedFood = grouped[food.fdcId] {
                result.append(groupedFood)
                seenIds.insert(food.fdcId)
                grouped.removeValue(forKey: food.fdcId)
            }
        }
        
        // Add any remaining grouped foods (shouldn't be any, but just in case)
        result.append(contentsOf: grouped.values)
        
        return result
    }
    
    /// Removes all items from `selectedFoods` that have the same fdcId
    /// as the aggregated item the user swiped to delete.
    private func removeAllItems(withFdcId fdcId: Int) {
        selectedFoods.removeAll { $0.fdcId == fdcId }
    }
}

private struct MacroTotals {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    
    var totalMacros: Double { protein + carbs + fat }
    
    var proteinPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return (protein / totalMacros) * 100
    }
    
    var carbsPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return (carbs / totalMacros) * 100
    }
    
    var fatPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return (fat / totalMacros) * 100
    }
}

private func calculateTotalMacros(_ foods: [Food]) -> MacroTotals {
    var totals = MacroTotals()
    
    for food in foods {
        let servings = food.numberOfServings ?? 1
        
        // Sum up calories - safeguard against nil calories
        if let calories = food.calories {
            totals.calories += calories * servings
        }
        
        // Get protein, carbs, and fat from foodNutrients array
        for nutrient in food.foodNutrients {
            // Apply the servings multiplier to get the total contribution
            let value = nutrient.value * servings
            
            if nutrient.nutrientName == "Protein" {
                totals.protein += value
            } else if nutrient.nutrientName == "Carbohydrate, by difference" {
                totals.carbs += value
            } else if nutrient.nutrientName == "Total lipid (fat)" {
                totals.fat += value
            }
        }
    }
    
    return totals
}



