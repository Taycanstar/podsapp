//
//  MealDetailView.swift
//  Pods
//
//  Created by Dimi Nunez on 3/3/25.
//

import SwiftUI

//
//  EditMealView.swift
//  Pods
//
//  Created by Dimi Nunez on 3/12/25.
//

import SwiftUI

struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    
    // MARK: - Properties
    let meal: Meal
    @Binding var path: NavigationPath
    
    // MARK: - State
    @State private var isShowingEditMeal = false
    @State private var isShowingDeleteAlert = false
    @State private var showLoggingSuccess = false
    @State private var servingsCount: Double
    @State private var selectedPrivacy: String
    @State private var selectedMealTime: String = "Breakfast"

    
    // Alert states for error handling
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // Add a real @State for selectedFoods
    @State private var selectedFoods: [Food] = []
    
    // Add backup for selected foods
    @State private var backupFoods: [Food] = []
    
    // Flag to track if meal was saved
    @State private var mealWasSaved = false
    
    // MARK: - Initializer
    init(meal: Meal, path: Binding<NavigationPath>) {
        self.meal = meal
        self._path = path
        self._servingsCount = State(initialValue: Double(meal.servings))
        self._selectedPrivacy = State(initialValue: meal.privacy.capitalized)
        
        // Convert meal items to Food objects for the selectedFoods array
        var foods: [Food] = []
        
        for item in meal.mealItems {
            let food = Food(
                fdcId: Int(item.externalId) ?? item.foodId,
                description: item.name,
                brandOwner: nil,
                brandName: nil,
                servingSize: 1.0,
                numberOfServings: Double(item.servings) != 0 ? Double(item.servings) : 1.0,
                servingSizeUnit: item.servingText ?? "",
                householdServingFullText: item.servingText ?? "",
                foodNutrients: [
                    Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                    Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                    Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                    Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
                ],
                foodMeasures: []
            )
            foods.append(food)
        }
    }
    
    // MARK: - Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                mealDetailsSection
                
                if !meal.mealItems.isEmpty {
                    mealItemsSection
                }
                
                // if let directions = meal.directions, !directions.isEmpty {
                //     directionsSection
                // }

                ButtonWithIcon(
                    label: "Edit Recipe",
                    iconName: "square.and.pencil",
                    action: {
                        isShowingEditMeal = true
                    },
                    bgColor: Color("iosnp"),
                    textColor: .accentColor
                )
                .padding(.top, -16)
                
                Spacer().frame(height: 40) // extra bottom space
            }
            .padding(.top, 16)
        }
        .background(Color("iosbg"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Recipe Details")
                    .fontWeight(.semibold)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Menu {
                        Button {
                            isShowingEditMeal = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            isShowingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    
                    Button("Log") {
                        logMeal()
                    }
                    .fontWeight(.semibold)
                }
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
        .onAppear {
            // Initialize selectedFoods on appear
            initializeSelectedFoods()
            
            // Reset servingsCount to meal's original servings
            self.servingsCount = Double(meal.servings)
        }
        .onChange(of: isShowingEditMeal) { isShowing in
            if isShowing {
                // Sheet is about to show, make a backup
                self.backupFoods = self.selectedFoods
                // Reset the saved flag
                self.mealWasSaved = false
            }
        }
        .sheet(isPresented: $isShowingEditMeal, onDismiss: {
            print("🔍 EditMeal dismissed, checking if saved: \(mealWasSaved)")
            
            if mealWasSaved {
                // If saved, update the UI with the edited values
                // we get from userInfo dictionary
                let updatedMeal = meal
                servingsCount = updatedMeal.servings
                selectedPrivacy = updatedMeal.privacy.capitalized
            }
            
            // If the meal wasn't saved (user tapped X), restore from backup
            if !mealWasSaved {
                print("📝 Restoring original foods - meal was not saved")
                selectedFoods = backupFoods
            }
        }) {
            NavigationView {
                EditMealView(
                    meal: meal,
                    path: $path,
                    selectedFoods: $selectedFoods,
                    onSave: {
                        // Mark as saved when Done is tapped
                        mealWasSaved = true
                    }
                )
            }
        }
        .alert("Delete Meal", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteMeal()
            }
        } message: {
            Text("Are you sure you want to delete this meal?")
        }
        .alert("Success", isPresented: $showLoggingSuccess) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Meal logged successfully")
        }
        .onChange(of: selectedPrivacy) { _ in
            // Don't update the meal - this should only happen in EditMealView
            // Just update the local UI
        }

        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func logMeal() {
        // Calculate the scaled calories based on serving count
        let baseCalories = meal.calories
        let scaledCalories = baseCalories * servingsCount / Double(meal.servings)
        
        // First, close the food container immediately
        viewModel.isShowingFoodContainer = false
        
        foodManager.logMeal(
            meal: meal,
            mealTime: selectedMealTime,
            calories: scaledCalories
        ) { result in
            switch result {
            case .success(let loggedMeal):
                // Create CombinedLog and add to DayLogsVM
                let combinedLog = CombinedLog(
                    type:        .meal,
                    status:      loggedMeal.status,
                    calories:    loggedMeal.calories,
                    message:     "\(loggedMeal.meal.title) – \(loggedMeal.mealTime)",
                    foodLogId:   nil,
                    food:        nil,
                    mealType:    loggedMeal.mealTime,
                    mealLogId:   loggedMeal.mealLogId,
                    meal:        loggedMeal.meal,
                    mealTime:    loggedMeal.mealTime,
                    scheduledAt: Date(),
                    recipeLogId: nil,
                    recipe:      nil,
                    servingsConsumed: nil,
                    isOptimistic: true
                )
                
                // Add to DayLogsViewModel
                DispatchQueue.main.async {
                    dayLogsVM.addPending(combinedLog)
                    print("After addPending from MealDetailView, logs contains meal? \(dayLogsVM.logs.contains(where: { $0.id == combinedLog.id }))")
                    
                    // Update foodManager.combinedLogs
                    if let idx = foodManager.combinedLogs.firstIndex(where: { $0.mealLogId == combinedLog.mealLogId }) {
                        foodManager.combinedLogs.remove(at: idx)
                    }
                    foodManager.combinedLogs.insert(combinedLog, at: 0)
                    
                    // Show success alert
                    showLoggingSuccess = true
                }
                
            case .failure(let error):
                print("❌ Failed to log meal:", error)
                DispatchQueue.main.async {
                    alertTitle = "Logging Failed"
                    alertMessage = "Could not log this meal. Please try again."
                    showAlert = true
                }
            }
        }
    }
    
    private func deleteMeal() {
        // Call FoodManager's deleteMeal method for deleting meal templates
        foodManager.deleteMeal(id: meal.id) { result in
            switch result {
            case .success:
                print("✅ Successfully deleted meal with ID: \(self.meal.id)")
                // Dismiss the view after successful deletion
                DispatchQueue.main.async {
                    self.dismiss()
                }
            case .failure(let error):
                print("❌ Failed to delete meal: \(error)")
                // Show error alert
                DispatchQueue.main.async {
                    self.alertTitle = "Delete Failed"
                    self.alertMessage = "Could not delete this meal. Please try again."
                    self.showAlert = true
                }
            }
        }
    }
    
    // MARK: - Subviews
    private var mealDetailsSection: some View {
        VStack(spacing: 8) {
            // Title (non-editable)
            Text(meal.title)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
            
            // Servings row
            servingsRowView
            
            Divider()
            
            // Meal time row
            // HStack {
            //     Text("Meal")
            //         .foregroundColor(.primary)
                
            //     Spacer()
                
            //     Menu {
            //         Button("Breakfast") { selectedMealTime = "Breakfast" }
            //         Button("Lunch") { selectedMealTime = "Lunch" }
            //         Button("Dinner") { selectedMealTime = "Dinner" }
            //         Button("Snack") { selectedMealTime = "Snack" }
            //     } label: {
            //         HStack {
            //             Text(selectedMealTime)
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
            
            // Share-with row
            HStack {
                Text("Shared with")
                    .foregroundColor(.primary)
                    
                Spacer()
                
                Menu {
                    Button("Everyone") {
                        selectedPrivacy = "Everyone"
                    }
                    Button("Friends") {
                        selectedPrivacy = "Friends"
                    }
                    Button("Only You") {
                        selectedPrivacy = "Only You"
                    }
                } label: {
                    HStack {
                        Text(selectedPrivacy)
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

    private var mealItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Food Items")
                .font(.title2)
                .fontWeight(.bold)
            
            List {
                ForEach(Array(meal.mealItems.enumerated()), id: \.offset) { index, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            HStack(spacing: 4) {
                                Text(item.servingText ?? "1 serving")
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                if item.servings != "1" {
                                    Text("×\(item.servings)")
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Text("\(Int(item.calories))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color("iosnp"))
                    .listRowSeparator(index == meal.mealItems.count - 1 ? .hidden : .visible)
                }
            }
            .listStyle(.plain)
            .background(Color("iosnp"))
            .cornerRadius(12)
            .scrollDisabled(true)
            .frame(height: CGFloat(meal.mealItems.count * 65))
        }
        .padding(.horizontal)
    }

    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Directions")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(meal.directions ?? "")
                .padding()                                 // internal text padding
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("iosnp"))                // background spans full width
                .cornerRadius(12)
        }
        .padding(.horizontal)                              // horizontal margin from screen edges
    }

    private var macroCircleAndStats: some View {
        // Base values for a single serving
        let baseProteinValue = meal.totalProtein ?? 0
        let baseCarbsValue = meal.totalCarbs ?? 0
        let baseFatValue = meal.totalFat ?? 0
        let baseCalories = meal.calories
        
        // Scale values according to servings count
        let proteinValue = baseProteinValue * servingsCount / Double(meal.servings)
        let carbsValue = baseCarbsValue * servingsCount / Double(meal.servings)
        let fatValue = baseFatValue * servingsCount / Double(meal.servings)
        let scaledCalories = baseCalories * servingsCount / Double(meal.servings)
        
        // Calculate percentages
        let totalMacros = proteinValue + carbsValue + fatValue
        let proteinPercent = totalMacros > 0 ? (proteinValue / totalMacros) * 100 : 0
        let carbsPercent = totalMacros > 0 ? (carbsValue / totalMacros) * 100 : 0
        let fatPercent = totalMacros > 0 ? (fatValue / totalMacros) * 100 : 0
        
        return HStack(spacing: 40) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                // Draw the circle segments with percentages
                Circle()
                    .trim(from: 0, to: CGFloat(carbsPercent) / 100)
                    .stroke(Color("teal"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(from: CGFloat(carbsPercent) / 100,
                          to: CGFloat(carbsPercent + fatPercent) / 100)
                    .stroke(Color("pinkRed"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(from: CGFloat(carbsPercent + fatPercent) / 100,
                          to: CGFloat(carbsPercent + fatPercent + proteinPercent) / 100)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(Int(scaledCalories))").font(.system(size: 20, weight: .bold))
                    Text("Cal").font(.system(size: 14))
                }
            }
            
            Spacer()
            
            // Use MacroView component for macro stats
            VStack(spacing: 4) {
                Text("\(Int(carbsPercent))%")
                    .foregroundColor(Color("teal"))
                    .font(.caption)
                Text("\(Int(carbsValue))g")
                    .font(.body)
                Text("Carbs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("\(Int(fatPercent))%")
                    .foregroundColor(Color("pinkRed"))
                    .font(.caption)
                Text("\(Int(fatValue))g")
                    .font(.body)
                Text("Fat")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("\(Int(proteinPercent))%")
                    .foregroundColor(Color.purple)
                    .font(.caption)
                Text("\(Int(proteinValue))g")
                    .font(.body)
                Text("Protein")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .id(servingsCount) // Force redraw when servings change
    }
    
    // Add a method to initialize selectedFoods from meal.mealItems
    private func initializeSelectedFoods() {
        if selectedFoods.isEmpty {
            // Convert meal items to Food objects
            var foods: [Food] = []
            for item in meal.mealItems {
                let food = Food(
                    fdcId: Int(item.externalId) ?? item.foodId,
                    description: item.name,
                    brandOwner: nil,
                    brandName: nil,
                    servingSize: 1.0,
                    numberOfServings: Double(item.servings) != 0 ? Double(item.servings) : 1.0,
                    servingSizeUnit: item.servingText,
                    householdServingFullText: item.servingText,
                    foodNutrients: [
                        Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                        Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                        Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                        Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
                    ],
                    foodMeasures: []
                )
                foods.append(food)
            }
            selectedFoods = foods
            // Also initialize the backup
            backupFoods = foods
            print("📊 MealDetailView initialized \(selectedFoods.count) foods from meal items")
        }
    }
}

// MARK: - Servings Selector Components
extension MealDetailView {
    private var servingsRowView: some View {
        HStack {
            Text("Servings")
                .foregroundColor(.primary)
            Spacer()
            TextField("Servings", value: $servingsCount, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                }
        }
    }
    
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
