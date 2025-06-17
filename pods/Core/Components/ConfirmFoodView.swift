import SwiftUI

struct ConfirmFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var viewModel: OnboardingViewModel
    
    @Binding var path: NavigationPath
    
    // Basic food info
    @State private var title: String = ""
    @State private var servingSize: String = ""
    @State private var numberOfServings: Double = 1
    @State private var calories: String = ""
    
    // Basic nutrition facts
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    // Flag to show additional nutrients
    @State private var showMoreNutrients: Bool = false
    
    // Additional nutrients
    @State private var saturatedFat: String = ""
    @State private var polyunsaturatedFat: String = ""
    @State private var monounsaturatedFat: String = ""
    @State private var transFat: String = ""
    @State private var cholesterol: String = ""
    @State private var sodium: String = ""
    @State private var potassium: String = ""
    @State private var sugar: String = ""
    @State private var fiber: String = ""
    @State private var vitaminA: String = ""
    @State private var vitaminC: String = ""
    @State private var calcium: String = ""
    @State private var iron: String = ""
    
    // Brand information
    @State private var brand: String = ""
    
    // UI states
    @State private var isCreating: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // NEW: Add a flag to distinguish between creation and logging modes
    @State private var isCreationMode: Bool = true  // Always true for this view
    
    // Base nutrition values (per single serving) for dynamic calculation
    @State private var baseCalories: Double = 0
    @State private var baseProtein: Double = 0
    @State private var baseCarbs: Double = 0
    @State private var baseFat: Double = 0
    @State private var baseSaturatedFat: Double = 0
    @State private var basePolyunsaturatedFat: Double = 0
    @State private var baseMonounsaturatedFat: Double = 0
    @State private var baseTransFat: Double = 0
    @State private var baseCholesterol: Double = 0
    @State private var baseSodium: Double = 0
    @State private var basePotassium: Double = 0
    @State private var baseSugar: Double = 0
    @State private var baseFiber: Double = 0
    @State private var baseVitaminA: Double = 0
    @State private var baseVitaminC: Double = 0
    @State private var baseCalcium: Double = 0
    @State private var baseIron: Double = 0
    
    // Flag to indicate if this food was created from scanned data (should update dynamically)
    @State private var isFromScannedData: Bool = false
    
    // Default initializer for manual food creation
    init(path: Binding<NavigationPath>) {
        self._path = path
        self._isCreationMode = State(initialValue: true)
    }
    
    // Initializer for editing/confirming a scanned/analyzed food
    init(path: Binding<NavigationPath>, food: Food) {
        self._path = path
        self._isCreationMode = State(initialValue: true)
        self._isFromScannedData = State(initialValue: true)
        
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
        var saturatedFatBase: Double = 0
        var polyunsaturatedFatBase: Double = 0
        var monounsaturatedFatBase: Double = 0
        var transFatBase: Double = 0
        var cholesterolBase: Double = 0
        var sodiumBase: Double = 0
        var potassiumBase: Double = 0
        var sugarBase: Double = 0
        var fiberBase: Double = 0
        var vitaminABase: Double = 0
        var vitaminCBase: Double = 0
        var calciumBase: Double = 0
        var ironBase: Double = 0
        
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
            } else if name.contains("saturated") {
                saturatedFatBase = value
            } else if name.contains("polyunsaturated") {
                polyunsaturatedFatBase = value
            } else if name.contains("monounsaturated") {
                monounsaturatedFatBase = value
            } else if name.contains("trans") {
                transFatBase = value
            } else if name.contains("cholesterol") {
                cholesterolBase = value
            } else if name.contains("sodium") {
                sodiumBase = value
            } else if name.contains("potassium") {
                potassiumBase = value
            } else if name.contains("sugar") {
                sugarBase = value
            } else if name.contains("fiber") {
                fiberBase = value
            } else if name.contains("vitamin a") {
                vitaminABase = value
            } else if name.contains("vitamin c") {
                vitaminCBase = value
            } else if name.contains("calcium") {
                calciumBase = value
            } else if name.contains("iron") {
                ironBase = value
            }
        }
        
        // Set base values for dynamic calculation
        self._baseCalories = State(initialValue: caloriesBase)
        self._baseProtein = State(initialValue: proteinBase)
        self._baseCarbs = State(initialValue: carbsBase)
        self._baseFat = State(initialValue: fatBase)
        self._baseSaturatedFat = State(initialValue: saturatedFatBase)
        self._basePolyunsaturatedFat = State(initialValue: polyunsaturatedFatBase)
        self._baseMonounsaturatedFat = State(initialValue: monounsaturatedFatBase)
        self._baseTransFat = State(initialValue: transFatBase)
        self._baseCholesterol = State(initialValue: cholesterolBase)
        self._baseSodium = State(initialValue: sodiumBase)
        self._basePotassium = State(initialValue: potassiumBase)
        self._baseSugar = State(initialValue: sugarBase)
        self._baseFiber = State(initialValue: fiberBase)
        self._baseVitaminA = State(initialValue: vitaminABase)
        self._baseVitaminC = State(initialValue: vitaminCBase)
        self._baseCalcium = State(initialValue: calciumBase)
        self._baseIron = State(initialValue: ironBase)
        
        // Set display values (will be updated by numberOfServings)
        let servings = food.numberOfServings ?? 1.0
        self._calories = State(initialValue: String(format: "%.1f", caloriesBase * servings))
        self._protein = State(initialValue: String(format: "%.1f", proteinBase * servings))
        self._carbs = State(initialValue: String(format: "%.1f", carbsBase * servings))
        self._fat = State(initialValue: String(format: "%.1f", fatBase * servings))
        self._saturatedFat = State(initialValue: String(format: "%.1f", saturatedFatBase * servings))
        self._polyunsaturatedFat = State(initialValue: String(format: "%.1f", polyunsaturatedFatBase * servings))
        self._monounsaturatedFat = State(initialValue: String(format: "%.1f", monounsaturatedFatBase * servings))
        self._transFat = State(initialValue: String(format: "%.1f", transFatBase * servings))
        self._cholesterol = State(initialValue: String(format: "%.1f", cholesterolBase * servings))
        self._sodium = State(initialValue: String(format: "%.1f", sodiumBase * servings))
        self._potassium = State(initialValue: String(format: "%.1f", potassiumBase * servings))
        self._sugar = State(initialValue: String(format: "%.1f", sugarBase * servings))
        self._fiber = State(initialValue: String(format: "%.1f", fiberBase * servings))
        self._vitaminA = State(initialValue: String(format: "%.1f", vitaminABase * servings))
        self._vitaminC = State(initialValue: String(format: "%.1f", vitaminCBase * servings))
        self._calcium = State(initialValue: String(format: "%.1f", calciumBase * servings))
        self._iron = State(initialValue: String(format: "%.1f", ironBase * servings))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Basic food info card
                basicInfoCard
                
                // Nutrition facts section
                nutritionFactsCard
                
                // Additional nutrients section (collapsible)
                if showMoreNutrients {
                    additionalNutrientsCard
                }
                
                Spacer().frame(height: 40) // extra bottom space
            }
            .padding(.top, 16)
        }
        .background(Color("iosbg"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Create Food")
                    .font(.headline)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: createFood) {
                    Text("Create")
                        .fontWeight(.semibold)
                }
                .disabled(isCreating)
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.accentColor)
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay(
            Group {
                if isCreating {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
            }
        )

    }
    
    // MARK: - Card Views
    private var basicInfoCard: some View {
        ZStack(alignment: .top) {
            // Background with rounded corners
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("iosnp"))
            
            // Content
            VStack(spacing: 0) {
                // Title
                TextField("Title", text: $title)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                
                // Divider
                Divider()
                    .padding(.leading, 16)
                
                // Serving Size Row - with label on left and input on right
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
                .onChange(of: numberOfServings) { _ in
                    if isFromScannedData {
                        updateNutritionValues()
                    }
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
                    // Calories (editable)
                    HStack {
                        Text("Calories")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("Calories", text: $calories)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Protein (editable)
                    HStack {
                        Text("Protein (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("Protein", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Carbs (editable)
                    HStack {
                        Text("Carbs (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("Carbs", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Fat (editable)
                    HStack {
                        Text("Total Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("Fat", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal)
            
            // Show More Nutrients button
            Button(action: {
                withAnimation {
                    showMoreNutrients.toggle()
                }
            }) {
                HStack {
                    Text(showMoreNutrients ? "Hide Additional Nutrients" : "Show More Nutrients")
                        .foregroundColor(.accentColor)
                    
                    Image(systemName: showMoreNutrients ? "chevron.up" : "chevron.down")
                        .foregroundColor(.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 14)
                .background(Color("iosnp"))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    private var additionalNutrientsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .top) {
                // Background with rounded corners
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("iosnp"))
                
                // Content
                VStack(spacing: 0) {
                    // Saturated Fat
                    HStack {
                        Text("Saturated Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(saturatedFat.isEmpty ? "0" : saturatedFat)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Polyunsaturated Fat
                    HStack {
                        Text("Polyunsaturated Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(polyunsaturatedFat.isEmpty ? "0" : polyunsaturatedFat)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Monounsaturated Fat
                    HStack {
                        Text("Monounsaturated Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(monounsaturatedFat.isEmpty ? "0" : monounsaturatedFat)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Trans Fat
                    HStack {
                        Text("Trans Fat (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(transFat.isEmpty ? "0" : transFat)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Cholesterol
                    HStack {
                        Text("Cholesterol (mg)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(cholesterol.isEmpty ? "0" : cholesterol)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Sodium
                    HStack {
                        Text("Sodium (mg)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(sodium.isEmpty ? "0" : sodium)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Potassium
                    HStack {
                        Text("Potassium (mg)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(potassium.isEmpty ? "0" : potassium)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Sugar
                    HStack {
                        Text("Sugar (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(sugar.isEmpty ? "0" : sugar)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Fiber
                    HStack {
                        Text("Fiber (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(fiber.isEmpty ? "0" : fiber)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Vitamin A
                    HStack {
                        Text("Vitamin A (%)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(vitaminA.isEmpty ? "0" : vitaminA)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Vitamin C
                    HStack {
                        Text("Vitamin C (%)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(vitaminC.isEmpty ? "0" : vitaminC)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Calcium
                    HStack {
                        Text("Calcium (%)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(calcium.isEmpty ? "0" : calcium)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.leading, 16)
                    
                    // Iron
                    HStack {
                        Text("Iron (%)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(iron.isEmpty ? "0" : iron)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal)
        }
        .transition(.opacity)
    }
    
    // Function to create the food (for manual food creation)
    private func createFood() {
        guard !title.isEmpty, !calories.isEmpty else {
            errorMessage = "Title and calories are required"
            showErrorAlert = true
            return
        }
        
        guard let caloriesValue = Double(calories) else {
            errorMessage = "Calories must be a valid number"
            showErrorAlert = true
            return
        }
        
        // Mark as creating
        isCreating = true
        
        // Format serving text
        let servingText = servingSize.isEmpty ? "1 serving" : servingSize
        
        // Create a list of nutrients
        var nutrients: [Nutrient] = [
            Nutrient(nutrientName: "Energy", value: caloriesValue, unitName: "kcal")
        ]
        
        // Add optional nutrients if provided
        if let proteinValue = Double(protein) {
            nutrients.append(Nutrient(nutrientName: "Protein", value: proteinValue, unitName: "g"))
        }
        
        if let carbsValue = Double(carbs) {
            nutrients.append(Nutrient(nutrientName: "Carbohydrate, by difference", value: carbsValue, unitName: "g"))
        }
        
        if let fatValue = Double(fat) {
            nutrients.append(Nutrient(nutrientName: "Total lipid (fat)", value: fatValue, unitName: "g"))
        }
        
        // Add all other nutrients if provided
        addNutrientIfPresent(name: "Saturated Fatty Acids", value: saturatedFat, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Polyunsaturated Fatty Acids", value: polyunsaturatedFat, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Monounsaturated Fatty Acids", value: monounsaturatedFat, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Trans Fatty Acids", value: transFat, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Cholesterol", value: cholesterol, unit: "mg", to: &nutrients)
        addNutrientIfPresent(name: "Sodium", value: sodium, unit: "mg", to: &nutrients)
        addNutrientIfPresent(name: "Potassium", value: potassium, unit: "mg", to: &nutrients)
        addNutrientIfPresent(name: "Sugar", value: sugar, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Fiber", value: fiber, unit: "g", to: &nutrients)
        addNutrientIfPresent(name: "Vitamin A", value: vitaminA, unit: "%", to: &nutrients)
        addNutrientIfPresent(name: "Vitamin C", value: vitaminC, unit: "%", to: &nutrients)
        addNutrientIfPresent(name: "Calcium", value: calcium, unit: "%", to: &nutrients)
        addNutrientIfPresent(name: "Iron", value: iron, unit: "%", to: &nutrients)
        
        // Create food measure
        let foodMeasure = FoodMeasure(
            disseminationText: servingText,
            gramWeight: 100.0, // Default gram weight
            id: 1,
            modifier: servingText,
            measureUnitName: "serving",
            rank: 1
        )
        
        // Create the food object
        let food = Food(
            fdcId: Int.random(in: 1000000..<9999999), // Generate a random ID
            description: title,
            brandOwner: nil,
            brandName: nil,
            servingSize: 1.0,
            numberOfServings: numberOfServings,
            servingSizeUnit: "serving",
            householdServingFullText: servingText,
            foodNutrients: nutrients,
            foodMeasures: [foodMeasure]
        )
        
        // Use the API to create the food manually
        foodManager.createManualFood(food: food) { result in
            DispatchQueue.main.async {
                isCreating = false
                
                switch result {
                case .success(let createdFood):
                    print("Food created successfully: \(createdFood.displayName)")
                    
                    // Show success toast via the food manager
                    foodManager.lastGeneratedFood = createdFood
                    foodManager.showFoodGenerationSuccess = true
                    
                    // Hide toast after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        foodManager.showFoodGenerationSuccess = false
                    }
                    
                    // Track as recently added
                    foodManager.trackRecentlyAdded(foodId: createdFood.fdcId)
                    
                    // Navigate back
                    dismiss()
                    
                case .failure(let error):
                    errorMessage = "Failed to create food: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
    
    // Helper to add optional nutrients
    private func addNutrientIfPresent(name: String, value: String, unit: String, to nutrients: inout [Nutrient]) {
        if let doubleValue = Double(value), doubleValue > 0 {
            nutrients.append(Nutrient(nutrientName: name, value: doubleValue, unitName: unit))
        }
    }
    
    // Helper method to calculate adjusted values based on number of servings
    private func calculateAdjustedValue(_ baseValue: Double, servings: Double) -> Double {
        return (baseValue * servings).rounded(toPlaces: 1)
    }
    
    // Update all nutrition values when number of servings changes (only for scanned foods)
    private func updateNutritionValues() {
        // Only update if this food came from scanned data
        guard isFromScannedData else { return }
        
        // Update main nutrition values
        calories = String(format: "%.1f", baseCalories * numberOfServings)
        protein = String(format: "%.1f", baseProtein * numberOfServings)
        carbs = String(format: "%.1f", baseCarbs * numberOfServings)
        fat = String(format: "%.1f", baseFat * numberOfServings)
        
        // Update additional nutrients
        saturatedFat = String(format: "%.1f", baseSaturatedFat * numberOfServings)
        polyunsaturatedFat = String(format: "%.1f", basePolyunsaturatedFat * numberOfServings)
        monounsaturatedFat = String(format: "%.1f", baseMonounsaturatedFat * numberOfServings)
        transFat = String(format: "%.1f", baseTransFat * numberOfServings)
        cholesterol = String(format: "%.1f", baseCholesterol * numberOfServings)
        sodium = String(format: "%.1f", baseSodium * numberOfServings)
        potassium = String(format: "%.1f", basePotassium * numberOfServings)
        sugar = String(format: "%.1f", baseSugar * numberOfServings)
        fiber = String(format: "%.1f", baseFiber * numberOfServings)
        vitaminA = String(format: "%.1f", baseVitaminA * numberOfServings)
        vitaminC = String(format: "%.1f", baseVitaminC * numberOfServings)
        calcium = String(format: "%.1f", baseCalcium * numberOfServings)
        iron = String(format: "%.1f", baseIron * numberOfServings)
    }

}

// Extension to round doubles to a specific number of decimal places
extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension ConfirmFoodView {
    // Helper function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


