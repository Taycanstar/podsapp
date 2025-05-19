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
    
    // UI states
    @State private var isCreating: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    // New properties for barcode flow
    @State private var isBarcodeFood: Bool = false
    @State private var originalFood: Food? = nil
    @State private var barcodeFoodLogId: Int? = nil
    @State private var servingUnit: String = "serving"

    @EnvironmentObject private var dayLogsVM: DayLogsViewModel
    
    // Default initializer for manual food creation
    init(path: Binding<NavigationPath>) {
        self._path = path
        self.isBarcodeFood = false
    }
    
    // New initializer for barcode food confirmation
    init(path: Binding<NavigationPath>, food: Food, foodLogId: Int? = nil) {
        self._path = path
        self._title = State(initialValue: food.description)
        
        // Debug print full barcode food response
        print("====== BARCODE FOOD API RESPONSE ======")
        print("Food ID: \(food.fdcId)")
        print("Description: \(food.description)")
        print("Brand: \(food.brandName ?? "N/A")")
        print("Serving Size: \(food.servingSize ?? 0)")
        print("Serving Size Unit: \(food.servingSizeUnit ?? "N/A")")
        print("Household Serving Text: \(food.householdServingFullText ?? "N/A")")
        print("Number of Servings: \(food.numberOfServings ?? 1)")
        
        // Print food measures for more details about serving options
        print("\nFood Measures:")
        if !food.foodMeasures.isEmpty {
            for (index, measure) in food.foodMeasures.enumerated() {
                print("  Measure \(index + 1):")
                print("    - Text: \(measure.disseminationText ?? "N/A")")
                print("    - Modifier: \(measure.modifier ?? "N/A")")
                print("    - Unit: \(measure.measureUnitName ?? "N/A")")
                print("    - Gram Weight: \(measure.gramWeight ?? 0)")
            }
        } else {
            print("  No measures available")
        }
        
        // Print all nutrients for debugging
        print("\nAll Nutrients:")
        for nutrient in food.foodNutrients {
            print("  \(nutrient.nutrientName): \(nutrient.value ?? 0) \(nutrient.unitName ?? "")")
        }
        
        print("\nRaw Food Object:")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(food), 
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        } else {
            print("Could not encode food object to JSON")
        }
        print("====== END BARCODE FOOD RESPONSE ======")
        
        // Set serving size information
        if let servingSize = food.servingSize, let unit = food.servingSizeUnit {
            self._servingSize = State(initialValue: "\(servingSize) \(unit)")
            self._servingUnit = State(initialValue: unit)
        } else if let servingText = food.householdServingFullText {
            self._servingSize = State(initialValue: servingText)
        }
        
        // Set number of servings (default to 1 if nil)
        self._numberOfServings = State(initialValue: food.numberOfServings ?? 1)
        
        // Set nutrition information
        self._calories = State(initialValue: "\(food.calories ?? 0)")
        self._protein = State(initialValue: "\(food.protein ?? 0)")
        self._carbs = State(initialValue: "\(food.carbs ?? 0)")
        self._fat = State(initialValue: "\(food.fat ?? 0)")
        
        // Get additional nutrients if available
        for nutrient in food.foodNutrients {
            switch nutrient.nutrientName {
            case "Saturated Fatty Acids":
                self._saturatedFat = State(initialValue: "\(nutrient.value ?? 0)")
            case "Polyunsaturated Fatty Acids":
                self._polyunsaturatedFat = State(initialValue: "\(nutrient.value ?? 0)")
            case "Monounsaturated Fatty Acids":
                self._monounsaturatedFat = State(initialValue: "\(nutrient.value ?? 0)")
            case "Trans Fatty Acids":
                self._transFat = State(initialValue: "\(nutrient.value ?? 0)")
            case "Cholesterol":
                self._cholesterol = State(initialValue: "\(nutrient.value ?? 0)")
            case "Sodium":
                self._sodium = State(initialValue: "\(nutrient.value ?? 0)")
            case "Potassium":
                self._potassium = State(initialValue: "\(nutrient.value ?? 0)")
            case "Sugar":
                self._sugar = State(initialValue: "\(nutrient.value ?? 0)")
            case "Fiber":
                self._fiber = State(initialValue: "\(nutrient.value ?? 0)")
            case "Vitamin A":
                self._vitaminA = State(initialValue: "\(nutrient.value ?? 0)")
            case "Vitamin C":
                self._vitaminC = State(initialValue: "\(nutrient.value ?? 0)")
            case "Calcium":
                self._calcium = State(initialValue: "\(nutrient.value ?? 0)")
            case "Iron":
                self._iron = State(initialValue: "\(nutrient.value ?? 0)")
            default:
                break
            }
        }
        
        // Set barcode food properties
        self._isBarcodeFood = State(initialValue: true)
        self._originalFood = State(initialValue: food)
        self._barcodeFoodLogId = State(initialValue: foodLogId)
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
                // Text(isBarcodeFood ? "Confirm Food" : "Create Food")
                      Text("Log Food")
                    .font(.headline)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if isBarcodeFood {
                    Button(action: logBarcodeFood) {
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                    .disabled(isCreating)
                } else {
                    Button(action: createFood) {
                        Text("Create")
                            .fontWeight(.semibold)
                    }
                    .disabled(isCreating)
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Prioritize dismiss() since it's more reliable
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                }
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
                HStack {
                    Text("Number of Servings")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // For decimal servings (barcode foods)
                    if isBarcodeFood {
                        HStack {
                            Button(action: {
                                if numberOfServings > 0.5 {
                                    numberOfServings -= 0.5
                                }
                            }) {
                                Image(systemName: "minus")
                                    .frame(width: 18, height: 18)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            
                            Text(String(format: "%.1f", numberOfServings))
                                .frame(minWidth: 40)
                                .padding(.horizontal, 8)
                            
                            Button(action: {
                                numberOfServings += 0.5
                            }) {
                                Image(systemName: "plus")
                                    .frame(width: 18, height: 18)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                    } else {
                        // Original integer stepper for manual foods
                        Stepper("\(Int(numberOfServings))", value: Binding(
                            get: { Int(self.numberOfServings) },
                            set: { self.numberOfServings = Double($0) }
                        ), in: 1...20)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
        }
        .padding(.horizontal)
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
                    // Calories (required)
                    HStack {
                        Text("Calories")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("0", text: $calories)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                    // Divider
                    Divider()
                        .padding(.leading, 16)
                    
                    // Protein
                    HStack {
                        Text("Protein (g)")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                            .frame(maxWidth: 100)
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
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $saturatedFat)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $polyunsaturatedFat)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $monounsaturatedFat)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $transFat)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $cholesterol)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $sodium)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $potassium)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $sugar)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $fiber)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $vitaminA)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $vitaminC)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $calcium)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
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
                        
                        TextField("0", text: $iron)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .padding(.horizontal)
        }
        .transition(.opacity)
    }
    

    private func logBarcodeFood() {
    // 1. Validate inputs
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

    guard let food = originalFood else {
        errorMessage = "Original food data not found"
        showErrorAlert = true
        return
    }

    isCreating = true

    // 2. Compute adjusted food with user servings
    let originalServings = food.numberOfServings ?? 1
    let userServings     = numberOfServings
    var updatedFood      = food
    updatedFood.numberOfServings = userServings

    // 3. Fire the real network call
    foodManager.logFood(
        email:    viewModel.email,
        food:     updatedFood,
        meal:     "Lunch",                     // or pass in a variable
        servings: Int(userServings),
        date:     Date(),
        notes:    nil
    ) { result in
        DispatchQueue.main.async {
            self.isCreating = false
            switch result {
            case .success(let logged):
                // 4. Build your CombinedLog from the server response
                let combined = CombinedLog(
                    type:            .food,
                    status:          logged.status,
                    calories:        Double(logged.food.calories),
                    message:         "\(logged.food.displayName) - \(logged.mealType)",
                    foodLogId:       logged.foodLogId,
                    food:            logged.food,
                    mealType:        logged.mealType,
                    mealLogId:       nil,
                    meal:            nil,
                    mealTime:        nil,
                    scheduledAt:     Date(),
                    recipeLogId:     nil,
                    recipe:          nil,
                    servingsConsumed:nil
                )

                // 5. Optimistically insert into today's view
                dayLogsVM.addPending(combined)

                // 6. Also insert into the global timeline, de-duplicating first
                if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combined.foodLogId }) {
                    foodManager.combinedLogs.remove(at: idx)
                }
                foodManager.combinedLogs.insert(combined, at: 0)

                // 7. Show the success toast
                foodManager.lastLoggedItem = (name: combined.food?.displayName ?? title,
                                              calories: combined.displayCalories)
                foodManager.showLogSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    foodManager.showLogSuccess = false
                }

                // 8. Finally dismiss
                dismiss()

            case .failure(let error):
                // 9. Show error to the user
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
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
            measureUnitName: servingUnit,
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
            servingSizeUnit: servingUnit,
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
}


