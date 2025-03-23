import SwiftUI
import PhotosUI

struct EditRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    let recipe: Recipe
    @Binding var path: NavigationPath
    @Binding var selectedFoods: [Food]
    
    // Callback when "Done" is tapped and recipe is successfully saved
    var onSave: (() -> Void)?
    
    // MARK: - State
    @State private var recipeName: String
    @State private var shareWith: String
    @State private var instructions: String
    @State private var servings: Int
    
    // If your recipe has scheduled times, you can track that
    @State private var scheduledDate: Date?
    
    // Image-related states
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    @State private var showImagePicker = false
    @State private var showOptionsSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    
    @State private var imageURL: URL? = nil
    @State private var uploadError: Error?
    @State private var showUploadError = false
    @State private var uiImage: UIImage? = nil
    
    // Track if anything changed
    @State private var hasChanges: Bool = false
    
    // Name-taken checks
    @State private var showNameTakenAlert = false
    
    // Focus management
    @FocusState private var focusedField: Field?
    
    @EnvironmentObject var foodManager: FoodManager
    
    // For saving
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    // Add a state variable for "adding ingredients"
    @State private var isShowingAddItems = false
    @State private var foodCountBeforeSheet = 0
    
    // MARK: - Computed
    private var isDoneButtonDisabled: Bool {
        return recipeName.isEmpty || !hasChanges
    }
    
    // If you have a "headerHeight" for a stretchable top image
    private let headerHeight: CGFloat = 400
    
    // Macro calculation
    private var macroPercentages: (protein: Double, carbs: Double, fat: Double) {
        let totals = calculateTotalMacros(selectedFoods)
        return (protein: totals.proteinPercentage, carbs: totals.carbsPercentage, fat: totals.fatPercentage)
    }
    
    // Whether the recipe has an image
    private var hasImage: Bool {
        selectedImage != nil || (recipe.image != nil && !recipe.image!.isEmpty)
    }
    
    // MARK: - Initializer
    init(
        recipe: Recipe,
        path: Binding<NavigationPath>,
        selectedFoods: Binding<[Food]>,
        onSave: (() -> Void)? = nil
    ) {
        self.recipe = recipe
        self._path = path
        self._selectedFoods = selectedFoods
        self.onSave = onSave
        
        // Initialize local states
        _recipeName   = State(initialValue: recipe.title)
        _shareWith    = State(initialValue: recipe.privacy.capitalized)    // e.g. "Everyone" / "Private"
        _instructions = State(initialValue: recipe.instructions ?? "")
        _servings     = State(initialValue: recipe.servings)
        
        if let imageStr = recipe.image, !imageStr.isEmpty {
            _imageURL = State(initialValue: URL(string: imageStr))
        } else {
            _imageURL = State(initialValue: nil)
        }
        
        print("🍝 EditRecipeView: Initialized for recipe ID: \(recipe.id) - '\(recipe.title)'")
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { outerGeo in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .top) {
                    // A) Collapsing / Stretchy Header
                    GeometryReader { headerGeo in
                        let offset = headerGeo.frame(in: .global).minY
                        let height = offset > 0 ? (headerHeight + offset) : headerHeight
                        
                        // Display either selectedImage or the existing recipe.image
                        if let selectedImage {
                            selectedImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: outerGeo.size.width, height: height)
                                .clipped()
                                .offset(y: offset > 0 ? -offset : 0)
                                .overlay(darkGradient)
                                .ignoresSafeArea(edges: .top)
                                .onTapGesture { showOptionsSheet = true }
                            
                        } else if let imageURLString = recipe.image,
                                  let url = URL(string: imageURLString),
                                  !imageURLString.isEmpty
                        {
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
                                        .overlay(darkGradient)
                                case .failure:
                                    fallbackNoImageView(height: height, offset: offset, width: outerGeo.size.width)
                                @unknown default:
                                    fallbackNoImageView(height: height, offset: offset, width: outerGeo.size.width)
                                }
                            }
                            .ignoresSafeArea(edges: .top)
                            .onTapGesture { showOptionsSheet = true }
                        } else {
                            fallbackNoImageView(height: height, offset: offset, width: outerGeo.size.width)
                        }
                    }
                    .frame(height: headerHeight)
                    
                    // Custom nav bar
                    VStack {
                        HStack {
                            Button(action: {
                                dismiss() // Don't call onSave
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(hasImage ? .white : .primary)
                                    .padding()
                            }
                            
                            Spacer()
                            
                            Text("Edit Recipe")
                                .font(.headline)
                                .foregroundColor(hasImage ? .white : .primary)
                            
                            Spacer()
                            
                            Button(action: { saveUpdatedRecipe() }) {
                                Text("Done")
                                    .foregroundColor(hasImage ? .white : .primary)
                                    .fontWeight(.semibold)
                                    .padding()
                            }
                            .disabled(isDoneButtonDisabled)
                        }
                        .padding(.top)
                        
                        Spacer()
                    }
                    
                    // B) The main content
                    VStack(spacing: 16) {
                        Spacer().frame(height: headerHeight)
                        
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
        
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        
        // Alerts
        .alert("Name Already Taken", isPresented: $showNameTakenAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please choose a different recipe name.")
        }
        
        .alert("Upload Error", isPresented: $showUploadError) {
            Button("Retry") { /* handle retry */ }
            Button("Cancel", role: .cancel) {
                uploadError = nil
            }
        } message: {
            Text(uploadError?.localizedDescription ?? "Unknown error")
        }
        
        .alert("Error Saving Recipe", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Update Failed"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        
        // Full screen cover for picking images
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePicker(uiImage: $uiImage, image: $selectedImage, sourceType: sourceType)
        }
        .onChange(of: uiImage) { newImage in
            guard let picked = newImage else { return }
            hasChanges = true
            NetworkManager().uploadMealImage(picked) { result in
                switch result {
                case .success(let urlString):
                    if let url = URL(string: urlString) {
                        imageURL = url
                    }
                case .failure(let error):
                    self.uploadError = error
                    self.showUploadError = true
                }
            }
        }
        
        // Confirmation for picking camera or library
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
        
        // Show the "Add Ingredients" sheet
        .sheet(isPresented: $isShowingAddItems, onDismiss: {
            let newCount = selectedFoods.count
            print("📋 Ingredient sheet dismissed. Was \(foodCountBeforeSheet) foods, now \(newCount).")
            if newCount > foodCountBeforeSheet {
                hasChanges = true
            }
        }) {
            NavigationView {
                LogFood(
                    selectedTab: .constant(0),
                    selectedMeal: .constant("Breakfast"), // or "Snack," etc.
                    path: $path,
                    mode: .addToRecipe,
                    selectedFoods: $selectedFoods,
                    onItemAdded: { _ in
                        print("✅ Ingredient added -> dismiss sheet")
                        isShowingAddItems = false
                    }
                )
                .navigationBarTitle("Add Ingredients", displayMode: .inline)
                .navigationBarItems(leading: Button("Cancel") {
                    isShowingAddItems = false
                })
            }
        }
        
        // Track changes in any editable field
        .onChange(of: recipeName)       { _ in hasChanges = true }
        .onChange(of: shareWith)        { _ in hasChanges = true }
        .onChange(of: instructions)     { _ in hasChanges = true }
        .onChange(of: servings)         { _ in hasChanges = true }
        .onChange(of: scheduledDate)    { _ in hasChanges = true }
        .onChange(of: selectedFoods)    { _ in hasChanges = true }
    }
    
    // MARK: - Subviews
    
    /// Dark gradient overlay on the top image
    private var darkGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Fallback for when recipe.image is missing
    private func fallbackNoImageView(height: CGFloat, offset: CGFloat, width: CGFloat) -> some View {
        ZStack {
            Color("iosnp")
            Image(systemName: "camera.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
        }
        .frame(width: width, height: height)
        .offset(y: offset > 0 ? -offset : 0)
        .ignoresSafeArea(edges: .top)
        .onTapGesture {
            showOptionsSheet = true
        }
    }
    
    /// Let user edit recipeName, servings, shareWith, etc.
    private var recipeDetailsSection: some View {
        VStack(spacing: 6) {
            TextField("Title", text: $recipeName)
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
            
            // If you store date/time in your recipes, show date picker or similar
            HStack {
                Text("Time")
                Spacer()
                DatePicker(
                    "",
                    selection: Binding(
                        get: { scheduledDate ?? Date() },
                        set: { scheduledDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
            }
            
            Divider()
            
            // Share-with row
            HStack {
                Text("Share with")
                Spacer()
                Menu {
                    Button("Everyone") { shareWith = "Everyone" }
                    Button("Friends")   { shareWith = "Friends"   }
                    Button("Only You")  { shareWith = "Only You"  }
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
            
            // Macros ring
            macroCircleAndStats
                .padding(.top, 16)
        }
        .padding()
        .background(Color("iosnp"))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    /// Shows the aggregated ingredients, plus a button to add more
    private var recipeItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe Ingredients")
                .font(.title2)
                .fontWeight(.bold)
            
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
                                    if let s = food.numberOfServings, s > 1 {
                                        Text("×\(Int(s))")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let cals = food.calories {
                                Text("\(Int(cals * (food.numberOfServings ?? 1)))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .listRowBackground(Color("iosnp"))
                        .listRowSeparator(index == aggregatedFoods.count - 1 ? .hidden : .visible)
                    }
                    .onDelete { indexSet in
                        if let idx = indexSet.first {
                            let item = aggregatedFoods[idx]
                            removeAllItems(withFdcId: item.fdcId)
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
                foodCountBeforeSheet = selectedFoods.count
                isShowingAddItems = true
            } label: {
                Text("Add ingredients")
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color("iosnp"))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    /// Text field for directions
    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Directions")
                .font(.title2)
                .fontWeight(.bold)
            
            TextField("Add instructions for this recipe", text: $instructions, axis: .vertical)
                .focused($focusedField, equals: .instructions)
                .textFieldStyle(.plain)
            
                .padding()
                .background(Color("iosnp"))
                .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    /// Macro ring + stats
    private var macroCircleAndStats: some View {
        let totals = calculateTotalMacros(selectedFoods)
        // Unique ID triggers a redraw when the foods change
        let foodsSignature = selectedFoods
            .map { "\($0.fdcId)-\($0.numberOfServings ?? 1)" }
            .joined(separator: ",")
        
        return HStack(spacing: 40) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: CGFloat(totals.carbsPercentage) / 100)
                    .stroke(Color("teal"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(
                        from: CGFloat(totals.carbsPercentage) / 100,
                        to: CGFloat(totals.carbsPercentage + totals.fatPercentage) / 100
                    )
                    .stroke(Color("pinkRed"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(
                        from: CGFloat(totals.carbsPercentage + totals.fatPercentage) / 100,
                        to: CGFloat(totals.carbsPercentage + totals.fatPercentage + totals.proteinPercentage) / 100
                    )
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(Int(totals.calories))")
                        .font(.system(size: 20, weight: .bold))
                    Text("Cal").font(.system(size: 14))
                }
            }
            
            Spacer()
            
            MacroView(value: totals.carbs,
                      percentage: totals.carbsPercentage,
                      label: "Carbs",
                      percentageColor: Color("teal"))
            MacroView(value: totals.fat,
                      percentage: totals.fatPercentage,
                      label: "Fat",
                      percentageColor: Color("pinkRed"))
            MacroView(value: totals.protein,
                      percentage: totals.proteinPercentage,
                      label: "Protein",
                      percentageColor: Color.purple)
        }
        .id(foodsSignature)
    }
    
    // MARK: - Methods
    
    private func saveUpdatedRecipe() {
        // Check if name is taken
        guard validateRecipeName() else { return }
        
        isSaving = true
        
        // If we have a new local UI image but no upload yet
        if let uiImage = uiImage, imageURL == nil {
            NetworkManager().uploadMealImage(uiImage) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let urlString):
                        if let url = URL(string: urlString) {
                            self.imageURL = url
                            self.updateRecipe()
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
            updateRecipe()
        }
    }
    
    private func updateRecipe() {
        print("🍝 Updating recipe with \(selectedFoods.count) items")
        
        let totals = calculateTotalMacros(selectedFoods)
        let updatedRecipe = Recipe(
            id: recipe.id,
            title: recipeName,
            description: recipe.description,
            instructions: instructions,
            privacy: shareWith.lowercased(),
            servings: servings,
            createdAt: recipe.createdAt,
            updatedAt: Date(),
            recipeItems: [], // Will be replaced by the selectedFoods
            image: imageURL?.absoluteString,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            totalCalories: totals.calories,
            totalProtein: totals.protein,
            totalCarbs: totals.carbs,
            totalFat: totals.fat,
            scheduledAt: scheduledDate  
        )
        
        foodManager.updateRecipe(recipe: updatedRecipe, foods: selectedFoods) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success(_):
                    print("✅ Recipe update succeeded: \(updatedRecipe.title)")
                    
                    // Let the parent know we saved
                    self.onSave?()
                    
                    // Dismiss
                    self.dismiss()
                    self.path.removeLast()
                case .failure(let error):
                    print("❌ Recipe update failed: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func validateRecipeName() -> Bool {
        // gather other recipe names
        let otherRecipes = foodManager.recipes
            .filter { $0.id != recipe.id }
            .map { $0.title.lowercased() }
        
        if otherRecipes.contains(recipeName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            showNameTakenAlert = true
            return false
        }
        return true
    }
    
    // Aggregate & remove duplicates
    private func aggregateFoodsByFdcId(_ allFoods: [Food]) -> [Food] {
        var grouped: [Int: Food] = [:]
        for food in allFoods {
            if var existing = grouped[food.fdcId] {
                let existingServings = existing.numberOfServings ?? 1
                let additionalServings = food.numberOfServings ?? 1
                existing.numberOfServings = existingServings + additionalServings
                grouped[food.fdcId] = existing
            } else {
                grouped[food.fdcId] = food
            }
        }
        
        var result: [Food] = []
        var seenIds = Set<Int>()
        for food in allFoods {
            if !seenIds.contains(food.fdcId), let gf = grouped[food.fdcId] {
                result.append(gf)
                seenIds.insert(food.fdcId)
            }
        }
        result.append(contentsOf: grouped.values)
        return Array(Set(result)) // or do dedup again
    }
    
    private func removeAllItems(withFdcId fdcId: Int) {
        selectedFoods.removeAll { $0.fdcId == fdcId }
    }
    
    // Calculation
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
            if let cals = food.calories { totals.calories += cals * servings }
            for nutrient in food.foodNutrients {
                let val = nutrient.safeValue * servings
                switch nutrient.nutrientName {
                case "Protein":                       totals.protein += val
                case "Carbohydrate, by difference":   totals.carbs   += val
                case "Total lipid (fat)":            totals.fat     += val
                default: break
                }
            }
        }
        
        return totals
    }
}
