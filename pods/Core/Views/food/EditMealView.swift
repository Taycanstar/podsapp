//
//  EditMealView.swift
//  Pods
//
//  Created by Dimi Nunez on 3/12/25.
//

import SwiftUI
import PhotosUI

struct EditMealView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    let meal: Meal
    @Binding var path: NavigationPath
    @Binding var selectedFoods: [Food]
    
    // MARK: - State
    @State private var mealName: String
    @State private var shareWith: String
    @State private var instructions: String
    @State private var servings: Int
    @State private var mealTime: String = "Breakfast"
    @State private var scheduledDate: Date?
    
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
    @State private var uiImage: UIImage? = nil
    
    // Track if the meal has been modified
    @State private var hasChanges: Bool = false
    
    // Add states for name validation
    @State private var isNameTaken = false
    @State private var showNameTakenAlert = false
    
    @FocusState private var focusedField: Field?
    
    @EnvironmentObject var foodManager: FoodManager
    
    // Add these states to track saving
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var errorMessage = ""
    
    // Add a state for error handling
    @State private var showingError = false
    
    // MARK: - Computed Properties
    private var isDoneButtonDisabled: Bool {
        return mealName.isEmpty || !hasChanges
    }
    
    // Available meal times
    private let mealTimes = ["Breakfast", "Lunch", "Dinner", "Snack"]
    
    // Adjust how tall you want the banner/collapsing area to be
    private let headerHeight: CGFloat = 400
    
    private var macroPercentages: (protein: Double, carbs: Double, fat: Double) {
        let totals = calculateTotalMacros(selectedFoods)
        return (
            protein: totals.proteinPercentage,
            carbs: totals.carbsPercentage,
            fat: totals.fatPercentage
        )
    }
    
    // Add a computed property to determine if we should show white text
    private var hasImage: Bool {
        return selectedImage != nil || (meal.image != nil && !meal.image!.isEmpty)
    }
    
    // Check if the meal name is already taken
    private func isNameAlreadyTaken() -> Bool {
        // Get all other meal names (excluding the current meal)
        let otherMealNames = foodManager.meals
            .filter { $0.id != meal.id }
            .map { $0.title.lowercased() }
        
        // Check if the current name (trimmed and lowercased) exists in other meals
        return otherMealNames.contains(mealName.trimmed().lowercased())
    }
    
    // Validate name before saving
    private func validateMealName() -> Bool {
        // Check if name is already taken
        if isNameAlreadyTaken() {
            // Show the alert
            showNameTakenAlert = true
            return false
        }
        return true
    }
    
    // MARK: - Initializer
    init(meal: Meal, path: Binding<NavigationPath>, selectedFoods: Binding<[Food]>) {
        self.meal = meal
        self._path = path
        self._selectedFoods = selectedFoods
        
        // Initialize state variables with meal data
        self._mealName = State(initialValue: meal.title)
        self._shareWith = State(initialValue: meal.privacy.capitalized)
        self._instructions = State(initialValue: meal.directions ?? "")
        self._servings = State(initialValue: meal.servings)
        self._scheduledDate = State(initialValue: meal.scheduledAt)
        
        // Set image URL if available
        if let imageStr = meal.image, !imageStr.isEmpty {
            self._imageURL = State(initialValue: URL(string: imageStr))
        } else {
            self._imageURL = State(initialValue: nil)
        }
        
        // Food initialization is now handled in FoodContainerView
        print("📦 EditMealView: Initialized for meal ID: \(meal.id) - '\(meal.title)'")
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
                        
                        // The banner image (if selected or from meal)
                        if let selectedImage {
                            selectedImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: outerGeo.size.width, height: height)
                                .clipped()
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
                        } else if let imageUrlString = meal.image, !imageUrlString.isEmpty, let url = URL(string: imageUrlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: outerGeo.size.width, height: height)
                                        .clipped()
                                        .offset(y: offset > 0 ? -offset : 0)
                                        .overlay(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                case .failure:
                                    ZStack {
                                        Color("iosnp")
                                        Image(systemName: "camera.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.accentColor)
                                    }
                                    .frame(width: outerGeo.size.width, height: height)
                                    .offset(y: offset > 0 ? -offset : 0)
                                @unknown default:
                                    EmptyView()
                                }
                            }
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
                    
                    // Custom nav bar overlay
                    VStack {
                        HStack {
                            Button(action: {
                                // Post a notification to restore original meal items
                                NotificationCenter.default.post(
                                    name: Notification.Name("RestoreOriginalMealItemsNotification"),
                                    object: nil,
                                    userInfo: ["mealId": meal.id]
                                )
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(hasImage ? .white : .primary)
                                    .padding()
                            }
                            
                            Spacer()
                            
                            Text("Edit Meal")
                                .font(.headline)
                                .foregroundColor(hasImage ? .white : .primary)
                            
                            Spacer()
                            
                            Button(action: {
                                saveUpdatedMeal()
                            }) {
                                Text("Done")
                                    .foregroundColor(hasImage ? .white : .primary)
                                    .fontWeight(.semibold)
                                    .padding()
                            }
                            .disabled(isDoneButtonDisabled)
                        }
                        .padding(.top)
                        .background(Color.clear)
                        
                        Spacer()
                    }
                    
                    // B) Main Scrollable Content
                    VStack(spacing: 16) {
                        Spacer().frame(height: headerHeight) // leave space for header
                        
                        mealDetailsSection
                        mealItemsSection
                        directionsSection
                        
                        // Spacer().frame(height: 40) 
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(Color("iosbg"))
       

        
        // Keep keyboard toolbar
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        
        // Add name taken alert
        .alert("Name Taken", isPresented: $showNameTakenAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please choose a different name.")
        }
        
        // Full screen cover for ImagePicker
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePicker(
                uiImage: $uiImage,
                image: $selectedImage,
                sourceType: sourceType
            )
        }
        .onChange(of: uiImage) { newUIImage in
            if let picked = newUIImage {
                hasChanges = true
                NetworkManager().uploadMealImage(picked) { result in
                    switch result {
                    case .success(let url):
                        self.imageURL = URL(string: url)
                    case .failure(let error):
                        self.uploadError = error
                        self.showUploadError = true
                    }
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
        .alert("Error Saving Meal", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        
        // Check for changes in any editable fields
        .onChange(of: mealName) { _ in hasChanges = true }
        .onChange(of: shareWith) { _ in hasChanges = true }
        .onChange(of: instructions) { _ in hasChanges = true }
        .onChange(of: servings) { _ in hasChanges = true }
        .onChange(of: mealTime) { _ in hasChanges = true }
        .onChange(of: scheduledDate) { _ in hasChanges = true }
        .onChange(of: selectedFoods) { newValue in 
            hasChanges = true
            print("📋 EditMealView: Food items changed for meal '\(meal.title)' - now has \(newValue.count) items")
        }
        
        // Add onAppear for debugging
        .onAppear {
            print("📋 EditMealView: Appeared for meal '\(meal.title)' with \(selectedFoods.count) food items")
        }
        
        // Add this modifier to your view's body to show the error alert
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Update Failed"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Methods
    private func saveUpdatedMeal() {
        // First validate the meal name
        guard validateMealName() else {
            return
        }
        
        isSaving = true
        
        // First upload image if exists
        if let uiImage = uiImage, imageURL == nil {
            NetworkManager().uploadMealImage(uiImage) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let urlString):
                        if let url = URL(string: urlString) {
                            self.imageURL = url
                            self.updateMeal()
                        } else {
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
            updateMeal()
        }
    }
    
    private func updateMeal() {
        print("📝 Updating meal with \(selectedFoods.count) foods")
        
        // Calculate macro totals from the current food items
        let totals = calculateTotalMacros(selectedFoods)
        
        // Create an updated meal with the current values
        let updatedMeal = Meal(
            id: meal.id,
            title: mealName,
            description: meal.description,
            directions: instructions,
            privacy: shareWith.lowercased(),
            servings: Int(servings),
            mealItems: [],  // Original meal items (will be replaced by selectedFoods)
            image: imageURL?.absoluteString,
            totalCalories: totals.calories,
            totalProtein: totals.protein,
            totalCarbs: totals.carbs,
            totalFat: totals.fat,
            scheduledAt: scheduledDate
        )
        
        print("📊 Calculated totals - Cal: \(totals.calories), P: \(totals.protein), C: \(totals.carbs), F: \(totals.fat)")
        
        // Use the foods parameter to update the meal
        foodManager.updateMeal(meal: updatedMeal, foods: selectedFoods) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success(let updatedMeal):
                    print("✅ Meal update succeeded: \(updatedMeal.title)")
                    
                    // Send notification to update the original saved foods
                    NotificationCenter.default.post(
                        name: Notification.Name("MealSuccessfullySavedNotification"),
                        object: nil,
                        userInfo: [
                            "mealId": self.meal.id,
                            "foods": self.selectedFoods
                        ]
                    )
                    
                    // Only dismiss and navigate back on success
                    self.dismiss()
                    self.path.removeLast()
                    
                case .failure(let error):
                    // On error, show an alert and don't dismiss
                    print("❌ Meal update failed: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    // MARK: - Subviews
    private var mealDetailsSection: some View {
        VStack(spacing: 6) {
            // Title
            TextField("Title", text: $mealName)
                .focused($focusedField, equals: .mealName)
                .textFieldStyle(.plain)
            
            Divider()
            
            // Servings row
            HStack {
                Text("Servings")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Stepper("\(servings)", value: $servings, in: 1...20)
            }
            
            Divider()
            
            // Meal time row
            HStack {
                Text("Meal")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    ForEach(mealTimes, id: \.self) { option in
                        Button(option) {
                            mealTime = option
                            hasChanges = true
                        }
                    }
                } label: {
                    HStack {
                        Text(mealTime)
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
            
            // Scheduled time row
            HStack {
                Text("Time")
                    .foregroundColor(.primary)
                
                Spacer()
                
                DatePicker(
                    "",
                    selection: Binding(
                        get: { self.scheduledDate ?? Date() },
                        set: { self.scheduledDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
            }
            
            Divider()
            
            // Share-with row
            HStack {
                Text("Share with")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    ForEach(["Everyone", "Friends", "Only You"], id: \.self) { option in
                        Button(option) {
                            shareWith = option
                            hasChanges = true
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
            .padding(.top, 16)
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var mealItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Items")
                .font(.title2)
                .fontWeight(.bold)
            
            // Aggregate duplicates by fdcId
            let aggregatedFoods = aggregateFoodsByFdcId(selectedFoods)
            
            if !aggregatedFoods.isEmpty {
                List {
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
                        if let firstIdx = indexSet.first {
                            let foodToRemove = aggregatedFoods[firstIdx]
                            removeAllItems(withFdcId: foodToRemove.fdcId)
                            hasChanges = true
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color("iosnp"))
                .cornerRadius(12)
                .scrollDisabled(true)
                .frame(height: CGFloat(aggregatedFoods.count * 65))
            }
            
            Button {
                path.append(FoodNavigationDestination.addMealItems)
            } label: {
                Text("Add item to meal")
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
            
            TextField("Add instructions for making this meal", text: $instructions, axis: .vertical)
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
        // Force redraw when foods change
        .id(foodsSignature)
    }
    
    // MARK: - Helper Methods
    
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
    private func removeAllItems(withFdcId fdcId: Int) {
        selectedFoods.removeAll { $0.fdcId == fdcId }
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
}

#Preview {
    EditMealView(meal: Meal(id: 1, title: "Sample Meal", description: "A sample meal description", directions: "Sample directions", privacy: "Everyone", servings: 2, mealItems: [], image: nil, totalCalories: 500, totalProtein: 20, totalCarbs: 50, totalFat: 10, scheduledAt: Date()), path: .constant(NavigationPath()), selectedFoods: .constant([Food(fdcId: 1, description: "Sample Food", brandOwner: nil, brandName: nil, servingSize: 1.0, numberOfServings: 1.0, servingSizeUnit: "g", householdServingFullText: "1g", foodNutrients: [], foodMeasures: []), Food(fdcId: 2, description: "Another Food", brandOwner: nil, brandName: nil, servingSize: 1.0, numberOfServings: 1.0, servingSizeUnit: "g", householdServingFullText: "1g", foodNutrients: [], foodMeasures: [])]))
}

// String extension for name validation
extension String {
    func trimmed() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
