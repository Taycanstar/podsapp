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
    
    // Focus state for auto-focus
    @FocusState private var isServingsFocused: Bool
    
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
    
    // Health analysis state
    @State private var healthAnalysis: HealthAnalysis? = nil
    @State private var showPerServing: Bool = true // true = per serving, false = per 100g/100ml
    @State private var isLiquid: Bool = false // Detect if it's a beverage
    @State private var expandedNegativeIndices: Set<Int> = []
    @State private var expandedPositiveIndices: Set<Int> = []
    
    // Default initializer for manual food creation
    init(path: Binding<NavigationPath>) {
        self._path = path
        self._isCreationMode = State(initialValue: true)
    }
    
    // Store the original scanned food data
    @State private var originalScannedFood: Food? = nil
    
    // Initializer for editing/confirming a scanned/analyzed food
    init(path: Binding<NavigationPath>, food: Food) {
        self._path = path
        self._isCreationMode = State(initialValue: true)
        self._isFromScannedData = State(initialValue: true)
        self._originalScannedFood = State(initialValue: food)
        
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
        
        // Initialize health analysis from food if available
        self._healthAnalysis = State(initialValue: food.healthAnalysis)
        self._isLiquid = State(initialValue: food.healthAnalysis?.isBeverage ?? false)
        
        // Debug prints for health analysis
        if let healthAnalysis = food.healthAnalysis {
            print("🩺 [ConfirmFoodView] Health analysis received!")
            print("🩺 [ConfirmFoodView] Score: \(healthAnalysis.score)")
            print("🩺 [ConfirmFoodView] Negatives count: \(healthAnalysis.negatives.count)")
            print("🩺 [ConfirmFoodView] Positives count: \(healthAnalysis.positives.count)")
        } else {
            print("❌ [ConfirmFoodView] No health analysis received")
        }
    }
    
    var body: some View {
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
        .onAppear {
            // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            //     isServingsFocused = true
            // }
        }
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
                    if isFromScannedData {
                        updateNutritionValues()
                    }
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
                                                Image(systemName: expandedNegativeIndices.contains(index) ? "chevron.up" : "chevron.down")
                                                    .font(.caption).foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 12)
                                        .background(Color.clear)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                if expandedNegativeIndices.contains(index) {
                                                    expandedNegativeIndices.remove(index)
                                                } else {
                                                    expandedNegativeIndices.insert(index)
                                                }
                                            }
                                        }

                                        if expandedNegativeIndices.contains(index) {
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
    
    // Function to create the food (for manual food creation)
    private func createFood() {
        // Mark as creating
        isCreating = true
        
        // If this is from scanned data, use the original food with updated servings
        if isFromScannedData, let originalFood = originalScannedFood {
            var updatedFood = originalFood
            updatedFood.numberOfServings = numberOfServings
            
            // Use the updated scanned food data
            foodManager.createManualFood(food: updatedFood) { result in
                DispatchQueue.main.async {
                    self.isCreating = false
                    switch result {
                    case .success(let savedFood):
                        print("✅ Successfully created scanned food: \(savedFood.displayName)")
                        
                        // Track as recently added
                        self.foodManager.trackRecentlyAdded(foodId: savedFood.fdcId)
                        
                        // Show success and dismiss
                        self.foodManager.showFoodGenerationSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.foodManager.showFoodGenerationSuccess = false
                        }
                        
                        self.dismiss()
                        
                    case .failure(let error):
                        print("❌ Failed to create scanned food: \(error)")
                        self.errorMessage = "Failed to create food: \(error.localizedDescription)"
                        self.showErrorAlert = true
                    }
                }
            }
            return
        }
        
        // For manual food creation, continue with the original validation and creation logic
        guard !title.isEmpty, !calories.isEmpty else {
            errorMessage = "Title and calories are required"
            showErrorAlert = true
            isCreating = false
            return
        }
        
        guard let caloriesValue = Double(calories) else {
            errorMessage = "Calories must be a valid number"
            showErrorAlert = true
            isCreating = false
            return
        }
        
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
                    
                    // Clear the lastGeneratedFood to prevent showing confirmation again
                    foodManager.lastGeneratedFood = nil
                    // Show success toast
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
        if let key = nutrientKey(for: facet) {
            dynamicRange(for: key)
        } else {
            Text("Range visualization unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func positiveRangeView(for facet: HealthFacet) -> some View {
        if let key = nutrientKey(for: facet) {
            dynamicRange(for: key)
        } else {
            Text("Range visualization unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private enum NutrientKey: String {
        case energy_kcal, sugars_g, sodium_mg, sat_fat_g, fiber_g, protein_g
    }
    
    private func nutrientKey(for facet: HealthFacet) -> NutrientKey? {
        switch facet.id {
        case "too_sugary", "a_bit_sugary", "low_sugar", "no_sugar":
            return .sugars_g
        case "too_salty", "a_bit_salty", "low_sodium", "no_sodium":
            return .sodium_mg
        case "too_much_sat_fat", "high_sat_fat", "low_sat_fat", "no_sat_fat":
            return .sat_fat_g
        case "too_caloric", "a_bit_caloric", "low_calories", "low_impact_cal", "high_cal_density":
            return .energy_kcal
        case "some_fiber", "high_fiber":
            return .fiber_g
        case "some_protein", "high_protein":
            return .protein_g
        default:
            return nil
        }
    }
    
    private func currentValue(for key: NutrientKey) -> Double {
        guard let health = healthAnalysis else { return 0 }
        let vals = showPerServing ? health.perServingValues : health.per100Values
        
        let raw: Double = {
            switch key {
            case .energy_kcal: return vals?.energy_kcal ?? 0
            case .sugars_g: return vals?.sugars_g ?? 0
            case .sodium_mg: return vals?.sodium_mg ?? 0
            case .sat_fat_g: return vals?.saturated_fat_g ?? 0
            case .fiber_g: return vals?.fiber_g ?? 0
            case .protein_g: return vals?.protein_g ?? 0
            }
        }()
        
        return showPerServing ? raw * numberOfServings : raw
    }
    
    private func activeThresholds(for key: NutrientKey) -> [Double] {
        guard let health = healthAnalysis else { return [] }
        if showPerServing {
            switch key {
            case .sugars_g: return health.thresholds?.per_serving.sugars_g ?? []
            case .sodium_mg: return health.thresholds?.per_serving.sodium_mg ?? []
            case .energy_kcal: return health.thresholds?.per_serving.energy_kcal ?? []
            case .sat_fat_g: return health.thresholds?.per_serving.sat_fat_g ?? []
            case .fiber_g: return health.thresholds?.per100_g.fiber_g ?? []
            case .protein_g: return health.thresholds?.per100_g.protein_g ?? []
            }
        } else {
            // per 100 basis
            if isLiquid {
                switch key {
                case .sugars_g: return health.thresholds?.per100_ml.sugars_g ?? []
                case .sodium_mg: return health.thresholds?.per100_ml.sodium_mg ?? []
                case .energy_kcal: return health.thresholds?.per100_ml.energy_kcal ?? []
                case .sat_fat_g: return health.thresholds?.per100_g.sat_fat_g ?? []
                case .fiber_g: return health.thresholds?.per100_g.fiber_g ?? []
                case .protein_g: return health.thresholds?.per100_g.protein_g ?? []
                }
            } else {
                switch key {
                case .sugars_g: return health.thresholds?.per100_g.sugars_g ?? []
                case .sodium_mg: return health.thresholds?.per100_g.sodium_mg ?? []
                case .energy_kcal:
                    let kj = health.thresholds?.per100_g.energy_kj ?? []
                    return kj.map { $0 / 4.184 }
                case .sat_fat_g: return health.thresholds?.per100_g.sat_fat_g ?? []
                case .fiber_g: return health.thresholds?.per100_g.fiber_g ?? []
                case .protein_g: return health.thresholds?.per100_g.protein_g ?? []
                }
            }
        }
    }
    
    private func unit(for key: NutrientKey) -> String {
        switch key {
        case .sodium_mg: return "mg"
        case .energy_kcal: return "Cal"
        default: return "g"
        }
    }
    
    @ViewBuilder
    private func dynamicRange(for key: NutrientKey) -> some View {
        let value = currentValue(for: key)
        let th = activeThresholds(for: key)
        let unit = unit(for: key)
        
        if th.isEmpty {
            Text("Range unavailable").font(.caption).foregroundColor(.secondary)
        } else {
            let segments = buildSegments(from: th)
            rangeBarView(currentValue: value, segments: segments, unit: unit)
        }
    }
    
    private func buildSegments(from thresholds: [Double]) -> [(threshold: Double, color: Color)] {
        if thresholds.count >= 10 {
            let last = thresholds.last!
            return [
                (thresholds[1], .green),
                (thresholds[2], .mint),
                (thresholds[5], .orange),
                (last, .red)
            ]
        }
        if thresholds.count == 4 {
            return [
                (thresholds[0], .green),
                (thresholds[1], .mint),
                (thresholds[2], .orange),
                (thresholds[3], .red),
            ]
        }
        if thresholds.count == 3 {
            return [
                (thresholds[0], .mint),
                (thresholds[1], .orange),
                (thresholds[2], .red),
            ]
        }
        return [(thresholds.last ?? 1, .red)]
    }
    
    private func rangeBarView(currentValue: Double,
                              segments: [(threshold: Double, color: Color)],
                              unit: String) -> some View {
        let maxValue = max(segments.last?.threshold ?? 1, currentValue)
        let stops: [Gradient.Stop] = {
            var arr: [Gradient.Stop] = [.init(color: .green, location: 0.0)]
            for s in segments {
                let loc = CGFloat(min(max(s.threshold / maxValue, 0), 1))
                arr.append(.init(color: s.color, location: loc))
            }
            return arr
        }()
        
        return VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    LinearGradient(gradient: Gradient(stops: stops),
                                   startPoint: .leading,
                                   endPoint: .trailing)
                        .frame(height: 8)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    let pos = min(currentValue / maxValue, 1.0) * geometry.size.width
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.primary)
                        .offset(x: pos - 5, y: -4)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("0").font(.caption2).foregroundColor(.secondary)
                Spacer()
                ForEach(Array(segments.dropLast().enumerated()), id: \.offset) { _, s in
                    Text(String(format: s.threshold < 10 ? "%.1f" : "%.0f", s.threshold))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Text("\(String(format: maxValue < 10 ? "%.1f" : "%.0f", maxValue)) \(unit)")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
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


