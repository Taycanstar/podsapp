//
//  EditMealView.swift
//  Pods
//
//  Created by Dimi Nunez on 3/12/25.
//

import SwiftUI

struct EditMealView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    let meal: Meal
    @Binding var path: NavigationPath
    @Binding var selectedFoods: [Food]
    
    // Add callback for when Done is tapped and meal is saved successfully
    var onSave: (() -> Void)?
    
    // MARK: - State
    @State private var mealName: String
    @State private var shareWith: String
    @State private var instructions: String
    @State private var servings: Double
    @State private var mealTime: String = "Breakfast"
    @State private var scheduledDate: Date?
    
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
    
    // Add a state variable to track when the add items sheet is being shown
    @State private var isShowingAddItems = false
    
    // Add a state variable to store the food count before showing the sheet
    @State private var foodCountBeforeSheet = 0
    
    // MARK: - Computed Properties
    private var isDoneButtonDisabled: Bool {
        return mealName.isEmpty || !hasChanges
    }
    
    // Available meal times
    private let mealTimes = ["Breakfast", "Lunch", "Dinner", "Snack"]
    
    private var macroPercentages: (protein: Double, carbs: Double, fat: Double) {
        let totals = calculateTotalMacros(selectedFoods)
        return (
            protein: totals.proteinPercentage,
            carbs: totals.carbsPercentage,
            fat: totals.fatPercentage
        )
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
    init(meal: Meal, path: Binding<NavigationPath>, selectedFoods: Binding<[Food]>, onSave: (() -> Void)? = nil) {
        self.meal = meal
        self._path = path
        self._selectedFoods = selectedFoods
        self.onSave = onSave
        
        // Initialize state variables with meal data
        self._mealName = State(initialValue: meal.title)
        self._shareWith = State(initialValue: meal.privacy.capitalized)
        self._instructions = State(initialValue: meal.directions ?? "")
        self._servings = State(initialValue: meal.servings)
        self._scheduledDate = State(initialValue: meal.scheduledAt)
        
        print("📦 EditMealView: Initialized for meal ID: \(meal.id) - '\(meal.title)'")
    }

    // MARK: - Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                mealDetailsSection
                mealItemsSection
                // directionsSection
                
                Spacer().frame(height: 40) // extra bottom space
            }
            .padding(.top, 16)
        }
        .background(Color("iosbg"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Edit Meal")
                    .fontWeight(.semibold)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    saveUpdatedMeal()
                }
                .disabled(isDoneButtonDisabled)
                .fontWeight(.semibold)
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                }
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .font(.system(size: 16, weight: .semibold))
            }
        }
        .navigationBarBackButtonHidden(true)
        
        // Add name taken alert
        .alert("Name Taken", isPresented: $showNameTakenAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please choose a different name.")
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
        // Add sheet for food selection
        .sheet(isPresented: $isShowingAddItems, onDismiss: {
            // Handle sheet dismiss
            let newCount = selectedFoods.count
            print("📝 Sheet dismissed, food count: \(newCount), previous count: \(foodCountBeforeSheet)")
            if newCount > foodCountBeforeSheet {
                print("📈 Items were added: \(newCount - foodCountBeforeSheet) new items")
                hasChanges = true
                // Print each food in the array for debugging
                print("📋 Current foods in EditMealView:")
                for (index, food) in selectedFoods.enumerated() {
                    print("  \(index+1). \(food.displayName)")
                }
            }
        }) {
            NavigationView {
                LogFood(
                    selectedTab: .constant(0),  // Default to first tab
                    selectedMeal: .constant(mealTime),  // Use current meal time
                    path: $path,
                    mode: .addToMeal,
                    selectedFoods: $selectedFoods,  // Direct binding to selectedFoods
                    onItemAdded: { food in
                        // This callback is called when an item is added
                        print("✅ onItemAdded callback triggered - closing LogFood sheet")
                        // Force update to ensure changes are reflected
                        let updatedFoods = selectedFoods
                        print("📊 EditMealView has \(updatedFoods.count) foods after item added")
                        // We'll dismiss the sheet and mark that changes were made
                        isShowingAddItems = false
                        hasChanges = true
                    }
                )
                .navigationBarTitle("Add Item to Meal", displayMode: .inline)
                .navigationBarItems(leading: Button("Cancel") {
                    isShowingAddItems = false
                })
            }
        }
    }
    
    // MARK: - Methods
    private func saveUpdatedMeal() {
        // First validate the meal name
        guard validateMealName() else {
            return
        }
        
        isSaving = true
        updateMeal()
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
            servings: Double(servings),
            mealItems: [],  // Original meal items (will be replaced by selectedFoods)
            image: meal.image, // Preserve existing image if any
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
                    
                    // Call the onSave callback to mark the meal as saved
                    self.onSave?()
                    
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
            
            // // Meal time row
            // HStack {
            //     Text("Meal")
            //         .foregroundColor(.primary)
                
            //     Spacer()
                
            //     Menu {
            //         ForEach(mealTimes, id: \.self) { option in
            //             Button(option) {
            //                 mealTime = option
            //                 hasChanges = true
            //             }
            //         }
            //     } label: {
            //         HStack {
            //             Text(mealTime)
            //             Image(systemName: "chevron.up.chevron.down")
            //                 .font(.system(size: 12))
            //         }
            //         .foregroundColor(.primary)
            //         .padding(.horizontal, 12)
            //         .padding(.vertical, 8)
            //         .background(Color("iosbtn"))
            //         .cornerRadius(8)
            //     }
            // }
            
            // Divider()
            
            // // Scheduled time row
            // HStack {
            //     Text("Time")
            //         .foregroundColor(.primary)
                
            //     Spacer()
                
            //     DatePicker(
            //         "",
            //         selection: Binding(
            //             get: { self.scheduledDate ?? Date() },
            //             set: { self.scheduledDate = $0 }
            //         ),
            //         displayedComponents: [.date, .hourAndMinute]
            //     )
            //     .labelsHidden()
            // }
            
            // Divider()
            
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
                path.append(FoodNavigationDestination.addFoodToMeal)
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
                let value = nutrient.safeValue * servings
                
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
