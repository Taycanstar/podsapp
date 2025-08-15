//
//  ConfirmAddFoodView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/28/25.
//

import SwiftUI

struct ConfirmAddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager
    
    // Completion closure to pass the food back to parent
    var onFoodAdded: (Food) -> Void
    
    // Basic food info
    @State private var title: String = ""
    @State private var servingSize: String = ""
    @State private var numberOfServings: Double = 1
    @State private var calories: String = ""
    
    // Basic nutrition facts
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    // Brand information
    @State private var brand: String = ""
    
    // UI states
    @State private var isAdding: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // Focus state for auto-focusing the servings field
    @FocusState private var isServingsFocused: Bool
    
    // Base nutrition values (per single serving) for dynamic calculation
    @State private var baseCalories: Double = 0
    @State private var baseProtein: Double = 0
    @State private var baseCarbs: Double = 0
    @State private var baseFat: Double = 0
    
    // Store the original food for reference
    @State private var originalFood: Food
    
    // Health analysis state
    @State private var healthAnalysis: HealthAnalysis? = nil
    @State private var showPerServing: Bool = true // true = per serving, false = per 100g/100ml
    @State private var isLiquid: Bool = false // Detect if it's a beverage
    @State private var expandedNegativeIndices: Set<Int> = []
    @State private var expandedPositiveIndices: Set<Int> = []
    
    // Initializer for confirming a scanned/analyzed food for adding to recipe
    init(food: Food, onFoodAdded: @escaping (Food) -> Void) {
        self.onFoodAdded = onFoodAdded
        self._originalFood = State(initialValue: food)
        
        // Populate fields with the food data
        self._title = State(initialValue: food.description)
        self._servingSize = State(initialValue: food.servingSizeText)
        self._numberOfServings = State(initialValue: food.numberOfServings ?? 1.0)
        self._brand = State(initialValue: food.brandName ?? "")
        
        // Extract nutrition values from foodNutrients and store both base values and display strings
        var caloriesBase: Double = 0
        var proteinBase: Double = 0
        var carbsBase: Double = 0
        var fatBase: Double = 0
        
        for nutrient in food.foodNutrients {
            let name = nutrient.nutrientName.lowercased()
            guard let value = nutrient.value else { continue }
            
            if name.contains("energy") || name.contains("calorie") {
                caloriesBase = value
            } else if name.contains("protein") {
                proteinBase = value
            } else if name.contains("carbohydrate") {
                carbsBase = value
            } else if name.contains("total lipid") || name.contains("fat") && !name.contains("saturated") && !name.contains("trans") {
                fatBase = value
            }
        }
        
        // Set base values for dynamic calculation
        self._baseCalories = State(initialValue: caloriesBase)
        self._baseProtein = State(initialValue: proteinBase)
        self._baseCarbs = State(initialValue: carbsBase)
        self._baseFat = State(initialValue: fatBase)
        
        // Set display values (will be updated by numberOfServings)
        let servings = food.numberOfServings ?? 1.0
        self._calories = State(initialValue: String(format: "%.1f", caloriesBase * servings))
        self._protein = State(initialValue: String(format: "%.1f", proteinBase * servings))
        self._carbs = State(initialValue: String(format: "%.1f", carbsBase * servings))
        self._fat = State(initialValue: String(format: "%.1f", fatBase * servings))
        
        // Initialize health analysis from food if available
        self._healthAnalysis = State(initialValue: food.healthAnalysis)
        self._isLiquid = State(initialValue: food.healthAnalysis?.isBeverage ?? false)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Basic food info card
                    basicInfoCard
                    
                    // Health analysis section (if available)
                    if healthAnalysis != nil {
                        healthAnalysisCard
                    }
                    
                    // Nutrition facts section
                    nutritionFactsCard
                    
                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
            .background(Color("iosbg"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Confirm Food")
                        .font(.headline)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        addFoodToRecipe()
                    }) {
                        if isAdding {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Add")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isAdding || title.isEmpty)
                    .foregroundColor(.accentColor)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: numberOfServings) { _, _ in
            updateNutritionValues()
        }
        .onAppear {
            // Auto-focus the servings field when the view appears
            // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            //     isServingsFocused = true
            // }
        }
    }
    
    // MARK: - Subviews
    
    private var basicInfoCard: some View {
        ZStack(alignment: .top) {
            // Background with rounded corners
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("iosnp"))
            
            // Content
            VStack(spacing: 0) {
                // Food name
                TextField("Enter food name", text: $title)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                
                // Divider
                Divider()
                    .padding(.leading, 16)
                
                // Brand (only show if not empty)
                if !brand.isEmpty {
                    HStack {
                        Text("Brand")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("Brand", text: $brand)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 200)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                }
                
                // Serving Size
                HStack {
                    Text("Serving Size")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    TextField("e.g., 1 cup, 2 tbsp", text: $servingSize)
                        .keyboardType(.asciiCapable)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 200)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                
                // Divider
                Divider()
                    .padding(.leading, 16)
                
                // Number of Servings
                servingsRowView
                
                // Divider
                Divider()
                    .padding(.leading, 16)
                
                // Calories Row
                caloriesRowView
                
                // Divider 
                Divider()
                    .padding(.leading, 16)
                
                // Health Score Row
                healthScoreRowView
            }
        }
        .padding(.horizontal)
    }
    
    private var servingsRowView: some View {
        HStack {
            Text("Number of Servings")
                .foregroundColor(.primary)
            Spacer()
            TextField("Servings", value: $numberOfServings, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .focused($isServingsFocused)
                .onChange(of: numberOfServings) { _ in
                    updateNutritionValues()
                }
        }
        .padding()
    }
    
    private var caloriesRowView: some View {
        HStack {
            Text("Calories")
                .foregroundColor(.primary)
            Spacer()
            TextField("Calories", text: $calories)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
        .padding()
    }
    
    private var healthScoreRowView: some View {
        HStack {
            Text("Health Score")
                .foregroundColor(.primary)
            Spacer()
            if let health = healthAnalysis {
                Text("\(health.score)/100")
                    .foregroundColor(healthColor(for: health.color))
                    .fontWeight(.medium)
            } else {
                Text("Not available")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var nutritionFactsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Facts")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ZStack(alignment: .top) {
                // Background with rounded corners
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("iosnp"))
                
                // Content
                VStack(spacing: 0) {
                    // Protein
                    HStack {
                        Text("Protein (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Carbs
                    HStack {
                        Text("Carbs (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Fat
                    HStack {
                        Text("Total Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    
    private func addFoodToRecipe() {
        guard !title.isEmpty else {
            errorMessage = "Food name is required"
            showErrorAlert = true
            return
        }
        
        isAdding = true
        
        // Create updated nutrients array
        var nutrients: [Nutrient] = []
        
        if let caloriesValue = Double(calories), caloriesValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Energy", value: caloriesValue, unitName: "kcal"))
        }
        
        if let proteinValue = Double(protein), proteinValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Protein", value: proteinValue, unitName: "g"))
        }
        
        if let carbsValue = Double(carbs), carbsValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Carbohydrate, by difference", value: carbsValue, unitName: "g"))
        }
        
        if let fatValue = Double(fat), fatValue > 0 {
            nutrients.append(Nutrient(nutrientName: "Total lipid (fat)", value: fatValue, unitName: "g"))
        }
        
        // Create the updated food object
        let updatedFood = Food(
            fdcId: originalFood.fdcId,
            description: title,
            brandOwner: originalFood.brandOwner,
            brandName: brand.isEmpty ? originalFood.brandName : brand,
            servingSize: originalFood.servingSize,
            numberOfServings: numberOfServings,
            servingSizeUnit: originalFood.servingSizeUnit,
            householdServingFullText: servingSize.isEmpty ? originalFood.householdServingFullText : servingSize,
            foodNutrients: nutrients,
            foodMeasures: originalFood.foodMeasures
        )
        
        // Pass the food to the parent and dismiss
        onFoodAdded(updatedFood)
        
        isAdding = false
        dismiss()
    }
    
    // MARK: - Health Analysis Card
    private var healthAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("iosnp"))
                
                VStack(spacing: 0) {
                    if let health = healthAnalysis {
                        // Compute which facets to show for the current toggle
                        let negs: [HealthFacet] = showPerServing
                            ? (health.servingFacets?.negatives ?? health.negatives)
                            : health.negatives

                        let poss: [HealthFacet] = showPerServing
                            ? (health.servingFacets?.positives ?? health.positives)
                            : health.positives

                        // Negatives section
                        if !negs.isEmpty {
                            VStack(spacing: 0) {
                                // Header
                                HStack {
                                    Text("Negatives")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Button(action: {
                                        showPerServing.toggle()
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(showPerServing ?
                                                "per serving (\(servingSize))" :
                                                (isLiquid ? "per 100ml" : "per 100g"))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Image(systemName: "arrow.left.arrow.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 12)

                                ForEach(Array(negs.enumerated()), id: \.offset) { index, facet in
                                    VStack(spacing: 0) {
                                        HStack(alignment: .center, spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.gray.opacity(0.1))
                                                    .frame(width: 40, height: 40)
                                                Image(systemName: iconForNegative(facet))
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.primary)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(facet.title).font(.body).fontWeight(.medium)
                                                Text(facet.subtitle).font(.caption).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            HStack(spacing: 8) {
                                                Text(valueForFacet(facet))
                                                    .font(.body).fontWeight(.medium)
                                                Circle().fill(Color.red).frame(width: 12, height: 12)
                                                // Don't show chevron for additives as there's no range to display
                                                if facet.id != "risky_additives" {
                                                    Image(systemName: expandedNegativeIndices.contains(index) ? "chevron.up" : "chevron.down")
                                                        .font(.caption).foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 12)
                                        .background(Color.clear)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            // Don't allow tap for additives as there's no range to display
                                            if facet.id != "risky_additives" {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    if expandedNegativeIndices.contains(index) {
                                                        expandedNegativeIndices.remove(index)
                                                    } else {
                                                        expandedNegativeIndices.insert(index)
                                                    }
                                                }
                                            }
                                        }

                                        if expandedNegativeIndices.contains(index) && facet.id != "risky_additives" {
                                            VStack(spacing: 8) {
                                                negativeRangeView(for: facet)
                                            }
                                            .padding(.horizontal, 16).padding(.bottom, 12)
                                            .transition(.opacity.combined(with: .slide))
                                        }

                                        if index < negs.count - 1 {
                                            Divider().padding(.leading, 68)
                                        }
                                    }
                                }
                            }
                        }

                        // Divider only if both sections exist
                        if !poss.isEmpty && !negs.isEmpty {
                            Divider().padding(.vertical, 8)
                        }

                        // Positives section
                        if !poss.isEmpty {
                            VStack(spacing: 0) {
                                // Header
                                HStack {
                                    Text("Positives")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Button(action: {
                                        showPerServing.toggle()
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(showPerServing ?
                                                "per serving (\(servingSize))" :
                                                (isLiquid ? "per 100ml" : "per 100g"))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Image(systemName: "arrow.left.arrow.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, negs.isEmpty ? 16 : 8)
                                .padding(.bottom, 12)

                                ForEach(Array(poss.enumerated()), id: \.offset) { index, facet in
                                    VStack(spacing: 0) {
                                        HStack(alignment: .center, spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.gray.opacity(0.1))
                                                    .frame(width: 40, height: 40)
                                                Image(systemName: iconForPositive(facet))
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.primary)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(facet.title).font(.body).fontWeight(.medium)
                                                Text(facet.subtitle).font(.caption).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            HStack(spacing: 8) {
                                                Text(valueForFacet(facet))
                                                    .font(.body).fontWeight(.medium)
                                                Circle().fill(Color.green).frame(width: 12, height: 12)
                                                Image(systemName: expandedPositiveIndices.contains(index) ? "chevron.up" : "chevron.down")
                                                    .font(.caption).foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 12)
                                        .background(Color.clear)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                if expandedPositiveIndices.contains(index) {
                                                    expandedPositiveIndices.remove(index)
                                                } else {
                                                    expandedPositiveIndices.insert(index)
                                                }
                                            }
                                        }

                                        if expandedPositiveIndices.contains(index) {
                                            VStack(spacing: 8) {
                                                positiveRangeView(for: facet)
                                            }
                                            .padding(.horizontal, 16).padding(.bottom, 12)
                                            .transition(.opacity.combined(with: .slide))
                                        }

                                        if index < poss.count - 1 {
                                            Divider().padding(.leading, 68)
                                        }
                                    }
                                }
                                .padding(.bottom, 16)
                            }
                        }
                    } else {
                        Text("Health analysis unavailable")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Health Analysis Helper Methods
    
    private func valueForFacet(_ facet: HealthFacet) -> String {
        guard let health = healthAnalysis else { return "—" }
        let vals = showPerServing ? health.perServingValues : health.per100Values
        
        func fmt(_ v: Double, _ unit: String) -> String {
            let adj = showPerServing ? (v * numberOfServings) : v
            return "\(Int(round(adj)))\(unit)"
        }
        
        switch facet.id {
        case "too_sugary", "a_bit_sugary", "low_sugar", "no_sugar":
            return fmt(vals?.sugars_g ?? 0, "g")
        case "too_salty", "a_bit_salty", "low_sodium", "no_sodium":
            return fmt(vals?.sodium_mg ?? 0, "mg")
        case "too_much_sat_fat", "high_sat_fat", "low_sat_fat", "no_sat_fat":
            return fmt(vals?.saturated_fat_g ?? 0, "g")
        case "too_caloric", "a_bit_caloric", "high_cal_density", "low_calories", "low_impact_cal":
            return fmt(vals?.energy_kcal ?? 0, " Cal")
        case "some_fiber", "high_fiber":
            return fmt(vals?.fiber_g ?? 0, "g")
        case "some_protein", "high_protein":
            return fmt(vals?.protein_g ?? 0, "g")
        case "ultra_processed", "risky_additives", "no_additives":
            return "\(health.additives?.count ?? 0)"
        default:
            return "—"
        }
    }
    
    private func iconForNegative(_ facet: HealthFacet) -> String {
        switch facet.id {
        case "too_sugary", "a_bit_sugary": return "cube"
        case "too_salty", "a_bit_salty": return "aqi.low"
        case "too_much_sat_fat", "high_sat_fat": return "drop"
        case "too_caloric", "a_bit_caloric", "high_cal_density": return "flame"
        case "ultra_processed", "risky_additives": return "flask"
        default: return "exclamationmark.circle"
        }
    }
    
    private func iconForPositive(_ facet: HealthFacet) -> String {
        switch facet.id {
        case "no_sat_fat", "low_sat_fat": return "drop"
        case "low_sodium", "no_sodium": return "aqi.low"
        case "low_sugar", "no_sugar": return "cube"
        case "some_fiber", "high_fiber": return "leaf"
        case "some_protein", "high_protein": return "fish"
        case "low_calories", "low_impact_cal": return "flame"
        case "organic": return "leaf.circle"
        case "no_additives": return "checkmark.seal"
        default: return "checkmark.circle"
        }
    }
    
    @ViewBuilder
    private func negativeRangeView(for facet: HealthFacet) -> some View {
        Text("Range visualization unavailable")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private func positiveRangeView(for facet: HealthFacet) -> some View {
        Text("Range visualization unavailable")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    // Update all nutrition values when number of servings changes
    private func updateNutritionValues() {
        // Update main nutrition values
        calories = String(format: "%.1f", baseCalories * numberOfServings)
        protein = String(format: "%.1f", baseProtein * numberOfServings)
        carbs = String(format: "%.1f", baseCarbs * numberOfServings)
        fat = String(format: "%.1f", baseFat * numberOfServings)
    }
    
    private func healthColor(for colorName: String) -> Color {
        switch colorName.lowercased() {
        case "dark_green":
            return Color.green
        case "light_green":
            return Color.mint
        case "orange":
            return Color.orange
        case "red":
            return Color.red
        default:
            return Color.gray
        }
    }
}

#Preview {
    ConfirmAddFoodView(food: Food(
        fdcId: 123456,
        description: "Sample Food",
        brandOwner: "Sample Brand",
        brandName: "Sample Brand",
        servingSize: 100.0,
        numberOfServings: 1.0,
        servingSizeUnit: "g",
        householdServingFullText: "1 serving",
        foodNutrients: [
            Nutrient(nutrientName: "Energy", value: 250.0, unitName: "kcal"),
            Nutrient(nutrientName: "Protein", value: 10.0, unitName: "g"),
            Nutrient(nutrientName: "Carbohydrate, by difference", value: 30.0, unitName: "g"),
            Nutrient(nutrientName: "Total lipid (fat)", value: 8.0, unitName: "g")
        ],
        foodMeasures: []
    )) { food in
        print("Food added: \(food.displayName)")
    }
}
