//
//  CreateMealView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/19/25.
//

import SwiftUI
import PhotosUI


enum Field: Hashable {
    case mealName
    case instructions
}

struct CreateMealView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    // Get navigation state to persist between views
    @EnvironmentObject private var navState: FoodNavigationState
    
    @State private var showingShareOptions = false
    
    // Add states for name validation
    @State private var showNameTakenAlert = false

    // Add this state variable with your other @State properties
    @FocusState private var focusedField: Field?

    @Binding var path: NavigationPath
    @Binding var selectedFoods: [Food]
    @EnvironmentObject var foodManager: FoodManager

    // Add these states to track saving
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var errorMessage = ""
    
    // Add an onAppear flag to track if we've seen this view before
    @State private var hasAppeared = false

private var isCreateButtonDisabled: Bool {
    return navState.createMealName.isEmpty
}

    // Example share options
    let shareOptions = ["Everyone", "Friends", "Only You"]

    // Replace the hardcoded macroPercentages with this:
private var macroPercentages: (protein: Double, carbs: Double, fat: Double) {
    let totals = calculateTotalMacros(selectedFoods)
    return (
        protein: totals.proteinPercentage,
        carbs: totals.carbsPercentage,
        fat: totals.fatPercentage
    )
}

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                mealDetailsSection
                mealItemsSection
                
                Spacer().frame(height: 40) // extra bottom space
            }
            .padding(.top, 16)
        }
        .background(Color("iosbg"))
        // Normal nav bar since we don't have an image banner
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("New Recipe")
                    .fontWeight(.semibold)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create") {
                    // Handle create action
                    saveNewMeal()
                }
                .disabled(isCreateButtonDisabled)
                .fontWeight(.semibold)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    resetFields()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                }
            }
            // ToolbarItemGroup(placement: .keyboard) {
            //     Spacer()
            //     Button("Done") {
            //         focusedField = nil
            //     }
            // }
        }
        .navigationBarBackButtonHidden(true)
        
        // Add error alert
        .alert("Error Saving Meal", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        
        // Add name taken alert
        .alert("Name Taken", isPresented: $showNameTakenAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Name already in use. Please choose a different name.")
        }
        // Add debug tracking
        .onAppear {
            print("🔍 CreateMealView appeared with \(selectedFoods.count) foods")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔍 CreateMealView appeared (delayed check): \(selectedFoods.count) foods")
            }
            hasAppeared = true
        }
        .onChange(of: selectedFoods) { newFoods in
            print("📊 CreateMealView selectedFoods changed: now has \(newFoods.count) foods")
            for (index, food) in newFoods.enumerated() {
                print("📊 Food \(index+1): \(food.displayName)")
            }
        }
    }

    private func resetFields() {
        // Reset all state in navState
        navState.resetCreateMealState()
        // Remove any remaining foods
        selectedFoods.removeAll()
    }

    // Check if the meal name is already taken
    private func isNameAlreadyTaken() -> Bool {
        // Get all meal names
        let existingMealNames = foodManager.meals
            .map { $0.title.lowercased() }
        
        // Check if the current name (trimmed and lowercased) exists
        return existingMealNames.contains(navState.createMealName.trimmed().lowercased())
    }
    
    // Validate name before saving
    private func validateMealName() -> Bool {
        if isNameAlreadyTaken() {
            showNameTakenAlert = true
            return false
        }
        return true
    }

    private func saveNewMeal() {
        // First validate the meal name
        guard validateMealName() else {
            return
        }
        
        isSaving = true
        createMeal()
        resetFields()
    }

    private func createMeal() {
        // Calculate macro totals from the current food items
        let totals = calculateTotalMacros(selectedFoods)
        
        print("📊 CreateMealView - Calculated totals before sending to FoodManager:")
        print("- Calories: \(totals.calories)")
        print("- Protein: \(totals.protein)g")
        print("- Carbs: \(totals.carbs)g")
        print("- Fat: \(totals.fat)g")

        foodManager.createMeal(
            title: navState.createMealName,
            description: nil,
            directions: nil, // Remove directions
            privacy: navState.createMealShareWith.lowercased(),
            servings: 1,
            foods: selectedFoods,
            image: nil, // Remove image
            totalCalories: totals.calories,
            totalProtein: totals.protein,
            totalCarbs: totals.carbs,
            totalFat: totals.fat
        )
        
        // Dismiss and go back to previous screen
        dismiss()
        path.removeLast()
    }

    // MARK: - Subviews
    private var mealDetailsSection: some View {
        ZStack(alignment: .top) {
            // Background with rounded corners
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("iosnp"))
            
            // Content
            VStack(spacing: 16) {
                // Title
                TextField("Title", text: $navState.createMealName)
                    .focused($focusedField, equals: .mealName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Divider that extends fully across
                Divider()
                .padding(.leading, 16)
                
                // Share-with row
                HStack {
                    Text("Share with")
                        .foregroundColor(.primary)
                        
                    Spacer()
                    Menu {
                        ForEach(shareOptions, id: \.self) { option in
                            Button(option) {
                                navState.createMealShareWith = option
                            }
                        }
                    } label: {
                        HStack {
                            Text(navState.createMealShareWith)
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
                .padding(.horizontal)
                
                // Divider that extends fully across
                Divider()
                .padding(.leading, 16)
                
                // Macros
                macroCircleAndStats
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .padding(.horizontal)
    }

        private var mealItemsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Food Items")
            .font(.title2)
            .fontWeight(.bold)
        
        // Print the raw array for debugging
        let _ = {
            print("⭐️ CreateMealView.mealItemsSection rendering with \(selectedFoods.count) foods")
            for (index, food) in selectedFoods.enumerated() {
                print("⭐️ Raw Food #\(index+1): \(food.displayName) (ID: \(food.fdcId))")
            }
            return 0
        }()
        
        // 1) Aggregate duplicates by fdcId
        let aggregatedFoods = aggregateFoodsByFdcId(selectedFoods)
        
        if !aggregatedFoods.isEmpty {
            List {
                // 2) Use aggregatedFoods instead of selectedFoods
                ForEach(Array(aggregatedFoods.enumerated()), id: \.element.id) { index, food in
                    
                    // Debug information
                    let _ = {
                        print("🍽️ Displaying food #\(index+1): \(food.displayName)")
                        print("  - householdServingFullText: \(food.householdServingFullText ?? "nil")")
                        print("  - servingSizeText: \(food.servingSizeText)")
                        print("  - numberOfServings: \(food.numberOfServings ?? 1)")
                        return 0
                    }()
                    
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
                    .listRowSeparator(index == 0 || index == aggregatedFoods.count - 1 ? .hidden : .visible)
                }
                .onDelete { indexSet in
                    // 3) Remove *all* items in selectedFoods that belong to the tapped row
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
            // If you want a frame, do it based on aggregatedFoods count:
            .frame(height: CGFloat(aggregatedFoods.count * 65))
        }
        
        Button {
            path.append(FoodNavigationDestination.addFoodToMeal)
        } label: {
            Text("Add item to recipe")
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color("iosnp"))
                .cornerRadius(12)
        }
    }
    .padding(.horizontal)
}

// MARK: - Aggregation

/// Groups `selectedFoods` by `fdcId`, merges duplicates into one item each, summing up `numberOfServings`.
private func aggregateFoodsByFdcId(_ allFoods: [Food]) -> [Food] {
    // Dictionary to store the combined foods
    var grouped: [Int: Food] = [:]
    
    // Debug log
    print("🔍 Aggregating \(allFoods.count) foods")
    
    // Process foods in order
    for food in allFoods {
        print("📦 Processing food: \(food.displayName)")
        print("  - Serving size text: \(food.servingSizeText)")
        print("  - Household serving full text: \(food.householdServingFullText ?? "nil")")
        print("  - Number of servings: \(food.numberOfServings ?? 1)")
        print("  - Calories: \(food.calories ?? 0)")
        
        if var existing = grouped[food.fdcId] {
            // Update existing entry by adding servings
            let existingServings = existing.numberOfServings ?? 1
            let additionalServings = food.numberOfServings ?? 1
            let newServings = existingServings + additionalServings
            
            print("📊 Combining with existing food.")
            print("  - Existing servings: \(existingServings)")
            print("  - Additional servings: \(additionalServings)")
            print("  - New total servings: \(newServings)")
            
            // Create a mutable copy of the existing food to update
            existing.numberOfServings = newServings
            
            // Calculate new calorie total for verification
            let newCalories = (existing.calories ?? 0) * newServings
            print("  - New total calories: \(newCalories)")
            
            grouped[food.fdcId] = existing
        } else {
            // Add new entry
            print("➕ Adding new entry for \(food.displayName)")
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
    
    print("✅ Aggregated to \(result.count) unique foods")
    return result
}

/// Removes all items from `selectedFoods` that have the same fdcId
/// as the aggregated item the user swiped to delete.
private func removeAllItems(withFdcId fdcId: Int) {
    // First, get count for debugging
    let beforeCount = selectedFoods.count
    let matchingFoods = selectedFoods.filter { $0.fdcId == fdcId }
    
    // Debug info about what's being removed
    print("🗑️ Removing all items with fdcId: \(fdcId)")
    print("- Found \(matchingFoods.count) matching foods to remove")
    
    if let firstFood = matchingFoods.first {
        print("- Food being removed: \(firstFood.displayName)")
        print("- Number of servings: \(firstFood.numberOfServings ?? 1)")
        print("- Base calories: \(firstFood.calories ?? 0)")
        
        // Calculate what will be removed
        let servings = firstFood.numberOfServings ?? 1
        let calsToRemove = (firstFood.calories ?? 0) * servings
        
        let proteinNutrient = firstFood.foodNutrients.first { $0.nutrientName == "Protein" }
        let carbsNutrient = firstFood.foodNutrients.first { $0.nutrientName == "Carbohydrate, by difference" }
        let fatNutrient = firstFood.foodNutrients.first { $0.nutrientName == "Total lipid (fat)" }
        
        let proteinToRemove = (proteinNutrient?.safeValue ?? 0) * servings
        let carbsToRemove = (carbsNutrient?.safeValue ?? 0) * servings
        let fatToRemove = (fatNutrient?.safeValue ?? 0) * servings
        
        print("- Total to be removed: \(calsToRemove) cal, \(proteinToRemove)g protein, \(carbsToRemove)g carbs, \(fatToRemove)g fat")
    }
    
    // Remove the items
    selectedFoods.removeAll { $0.fdcId == fdcId }
    
    // Debug result of removal
    let afterCount = selectedFoods.count
    print("✅ Removed \(beforeCount - afterCount) foods. New count: \(afterCount)")
    
    // Force UI update
    let _ = calculateTotalMacros(selectedFoods)
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
    
    // Debug info
    print("🧮 Calculating totals for \(foods.count) foods")
    
    for (index, food) in foods.enumerated() {
        let servings = food.numberOfServings ?? 1
        
        // Debug print for first few foods
        if index < 3 {
            print("📊 Food #\(index+1): \(food.displayName)")
            print("  - Number of servings: \(servings)")
            print("  - Base calories: \(food.calories ?? 0)")
            print("  - Total calories contribution: \(food.calories ?? 0) × \(servings) = \((food.calories ?? 0) * servings)")
            
            // Print nutrients
            let proteinNutrient = food.foodNutrients.first { $0.nutrientName == "Protein" }
            let carbsNutrient = food.foodNutrients.first { $0.nutrientName == "Carbohydrate, by difference" }
            let fatNutrient = food.foodNutrients.first { $0.nutrientName == "Total lipid (fat)" }
            
            print("  - Protein: \(proteinNutrient?.safeValue ?? 0)g × \(servings) = \((proteinNutrient?.safeValue ?? 0) * servings)g")
            print("  - Carbs: \(carbsNutrient?.safeValue ?? 0)g × \(servings) = \((carbsNutrient?.safeValue ?? 0) * servings)g")
            print("  - Fat: \(fatNutrient?.safeValue ?? 0)g × \(servings) = \((fatNutrient?.safeValue ?? 0) * servings)g")
        }
        
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


struct ImagePicker: UIViewControllerRepresentable {
    @Binding var uiImage: UIImage?
    @Binding var image: Image?
    
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject,
                       UIImagePickerControllerDelegate,
                       UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let uiImg = info[.editedImage] as? UIImage {
                // 1) Set raw UIImage
                parent.uiImage = uiImg
                // 2) Also set SwiftUI Image for display
                parent.image = Image(uiImage: uiImg)
            } else if let uiImg = info[.originalImage] as? UIImage {
                parent.uiImage = uiImg
                parent.image = Image(uiImage: uiImg)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}








