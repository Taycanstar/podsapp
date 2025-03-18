//
//  EditRecipeView.swift
//  Pods
//
//  Created by Dimi Nunez on 3/16/25.
//

import SwiftUI
import PhotosUI



struct EditRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    let recipe: Recipe
    @Binding var path: NavigationPath
    @Binding var selectedFoods: [Food]
    
    // MARK: - State
    @State private var recipeName: String
    @State private var shareWith: String
    @State private var instructions: String
    @State private var servings: Int
    @State private var prepTime: Int
    @State private var cookTime: Int
    
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
    
    // Track if the recipe has been modified
    @State private var hasChanges: Bool = false
    
    // Add states for name validation
    @State private var isNameTaken = false
    @State private var showNameTakenAlert = false
    
    // Add state for share options dialog
    @State private var showingShareOptions = false
    
    @FocusState private var focusedField: Field?
    
    @EnvironmentObject var foodManager: FoodManager
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !recipeName.isEmpty && (!selectedFoods.isEmpty || !recipe.recipeItems.isEmpty)
    }
    
    private var totalCalories: Double {
        selectedFoods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.calories ?? 0) * servings)
        }
    }
    
    private var totalProtein: Double {
        selectedFoods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.protein ?? 0) * servings)
        }
    }
    
    private var totalCarbs: Double {
        selectedFoods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.carbs ?? 0) * servings)
        }
    }
    
    private var totalFat: Double {
        selectedFoods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.fat ?? 0) * servings)
        }
    }
    
    // Additional computed properties to simplify complex expressions
    private var servingsValue: Double {
        Double(servings)
    }
    
    private var combinedCalories: Double {
        recipe.calories + totalCalories
    }
    
    private var combinedProtein: Double {
        recipe.protein + totalProtein
    }
    
    private var combinedCarbs: Double {
        recipe.carbs + totalCarbs
    }
    
    private var combinedFat: Double {
        recipe.fat + totalFat
    }
    
    private var caloriesPerServing: Double {
        combinedCalories / servingsValue
    }
    
    private var proteinPerServing: Double {
        combinedProtein / servingsValue
    }
    
    private var carbsPerServing: Double {
        combinedCarbs / servingsValue
    }
    
    private var fatPerServing: Double {
        combinedFat / servingsValue
    }
    
    // MARK: - Init
    
    init(recipe: Recipe, path: Binding<NavigationPath>, selectedFoods: Binding<[Food]>) {
        self.recipe = recipe
        _path = path
        _selectedFoods = selectedFoods
        
        // Initialize state from recipe
        _recipeName = State(initialValue: recipe.title)
        _instructions = State(initialValue: recipe.instructions ?? "")
        _servings = State(initialValue: recipe.servings)
        _prepTime = State(initialValue: recipe.prepTime ?? 0)
        _cookTime = State(initialValue: recipe.cookTime ?? 0)
        
        // Set privacy based on recipe's privacy setting
        let shareWithValue = recipe.privacy == "public" ? "Everyone" : "Only Me"
        _shareWith = State(initialValue: shareWithValue)
        
        // Set image URL if available
        if let imageStr = recipe.image, !imageStr.isEmpty {
            _imageURL = State(initialValue: URL(string: imageStr))
        } else {
            _imageURL = State(initialValue: nil)
        }
        
        // Only convert recipe items to foods if selectedFoods is empty.
        // If it already has items, we're returning from adding items, so preserve them.
        if selectedFoods.wrappedValue.isEmpty {
            print("📦 EditRecipeView: Initializing foods from recipe items for recipe: \(recipe.title)")
            var recipeItemFoods: [Food] = []
            for item in recipe.recipeItems {
                let food = Food(
                    fdcId: item.foodId,
                    description: item.name,
                    brandOwner: nil,
                    brandName: nil,
                    servingSize: 1.0,
                    numberOfServings: 1.0, // Default to 1 serving
                    servingSizeUnit: item.servingText ?? "",
                    householdServingFullText: item.servings,
                    foodNutrients: [
                        Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                        Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                        Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                        Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
                    ],
                    foodMeasures: []
                )
                recipeItemFoods.append(food)
            }
            selectedFoods.wrappedValue = recipeItemFoods
        } else {
            print("📦 EditRecipeView: Using existing \(selectedFoods.wrappedValue.count) foods for recipe: \(recipe.title)")
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recipe Image
                imageSection
                
                // Recipe Name
                VStack(alignment: .leading) {
                    Text("Recipe Name")
                        .font(.headline)
                    
                    TextField("Enter recipe name", text: $recipeName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($focusedField, equals: .mealName)
                        .onChange(of: recipeName) { _ in hasChanges = true }
                }
                
                // Servings
                VStack(alignment: .leading) {
                    Text("Servings")
                        .font(.headline)
                    
                    TextField("Number of servings", value: $servings, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .onChange(of: servings) { _ in hasChanges = true }
                }
                
                // Time
                HStack {
                    // Prep Time
                    VStack(alignment: .leading) {
                        Text("Prep Time (mins)")
                            .font(.headline)
                        
                        TextField("Prep time", value: $prepTime, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: prepTime) { _ in hasChanges = true }
                    }
                    
                    Spacer()
                    
                    // Cook Time
                    VStack(alignment: .leading) {
                        Text("Cook Time (mins)")
                            .font(.headline)
                        
                        TextField("Cook time", value: $cookTime, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: cookTime) { _ in hasChanges = true }
                    }
                }
                
                // Instructions
                VStack(alignment: .leading) {
                    Text("Instructions")
                        .font(.headline)
                    
                    TextEditor(text: $instructions)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.bottom)
                        .onChange(of: instructions) { _ in hasChanges = true }
                }
                
                // Current ingredients
                if !recipe.recipeItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Ingredients")
                            .font(.headline)
                        
                        ForEach(recipe.recipeItems, id: \.foodId) { item in
                            recipeItemRow(item)
                        }
                    }
                }
                
                // Add ingredients button
                Button(action: {
                    path.append(FoodNavigationDestination.addRecipeIngredients)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add More Ingredients")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // Selected new ingredients
                if !selectedFoods.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Ingredients")
                            .font(.headline)
                        
                        ForEach(selectedFoods) { food in
                            ingredientRow(food)
                        }
                        
                        Divider()
                        
                        // Nutritional Information
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nutritional Information (per serving)")
                                .font(.headline)
                            
                            HStack {
                                nutritionItem(
                                    label: "Calories",
                                    value: String(format: "%.0f", caloriesPerServing)
                                )
                                
                                Spacer()
                                
                                nutritionItem(
                                    label: "Protein",
                                    value: String(format: "%.1fg", proteinPerServing)
                                )
                                
                                Spacer()
                                
                                nutritionItem(
                                    label: "Carbs",
                                    value: String(format: "%.1fg", carbsPerServing)
                                )
                                
                                Spacer()
                                
                                nutritionItem(
                                    label: "Fat",
                                    value: String(format: "%.1fg", fatPerServing)
                                )
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // Privacy settings
                privacySection
                
                // Save button
                Button(action: saveRecipe) {
                    Text("Save Recipe")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!isFormValid)
                .padding(.vertical)
            }
            .padding()
        }
        .navigationTitle("Edit Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    selectedFoods = []
                    dismiss()
                }
            }
        }
        .alert("Recipe Name Already Taken", isPresented: $showNameTakenAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please choose a different name for your recipe.")
        }
        // Full screen cover for ImagePicker
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePicker(
                uiImage: $uiImage,
                image: $selectedImage,
                sourceType: sourceType
            )
        }
        .actionSheet(isPresented: $showOptionsSheet) {
            ActionSheet(
                title: Text("Select Photo"),
                buttons: [
                    .default(Text("Take Photo")) {
                        self.sourceType = .camera
                        self.showImagePicker = true
                    },
                    .default(Text("Choose from Library")) {
                        self.sourceType = .photoLibrary
                        self.showImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .onAppear {
            // Set initial focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .mealName
            }
            
            // Load image if available
            if let imageURL = imageURL {
                loadImage(from: imageURL)
            }
        }
        .onChange(of: uiImage) { newImage in
            if let newImage = newImage {
                uploadImage(newImage)
                hasChanges = true
            }
        }
    }
    
    // MARK: - View Components
    
    private var imageSection: some View {
        ZStack {
            if let selectedImage = selectedImage {
                selectedImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(8)
            } else if let imageURL = recipe.image, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(8)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    )
            }
            
            if isUploading {
                ProgressView(value: uploadProgress)
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2)
                    .tint(.white)
                    .background(Color.black.opacity(0.5))
                    .frame(width: 60, height: 60)
                    .cornerRadius(10)
            }
            
            Button(action: {
                showOptionsSheet = true
            }) {
                Text("Change Photo")
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy")
                .font(.headline)
            
            Button(action: {
                showingShareOptions = true
            }) {
                HStack {
                    Text("Share with: \(shareWith)")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .onChange(of: shareWith) { _ in hasChanges = true }
        .confirmationDialog("Share Recipe With", isPresented: $showingShareOptions, titleVisibility: .visible) {
            Button("Everyone (Public)") { shareWith = "Everyone" }
            Button("Only Me (Private)") { shareWith = "Only Me" }
        } message: {
            Text("Choose who can see your recipe")
        }
    }
    
    private func recipeItemRow(_ item: RecipeFoodItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .fontWeight(.medium)
                
                Text("\(item.servings) \(item.servingText ?? "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // In a real app, you'd add the ability to remove existing items
            // This would require changes to the updateRecipe function in FoodManager
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func ingredientRow(_ food: Food) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.displayName)
                    .fontWeight(.medium)
                
                if let servings = food.numberOfServings {
                    Text("\(String(format: "%.1f", servings)) \(food.servingSizeText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                // Remove this food from the selected list
                selectedFoods.removeAll { $0.id == food.id }
                hasChanges = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func nutritionItem(label: String, value: String) -> some View {
        VStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
        }
    }
    
    // MARK: - Functions
    
    private func loadImage(from url: URL) {
        // In a real app, load the image asynchronously
        // For now, we'll just set selectedImage to nil as we're using AsyncImage above
    }
    
    private func uploadImage(_ image: UIImage) {
        // Set up image for display while uploading
        selectedImage = Image(uiImage: image)
        isUploading = true
        uploadProgress = 0.2
        
        // Simulate image upload with progress - in a real app, replace with actual upload code
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            uploadProgress = 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                uploadProgress = 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isUploading = false
                    // In a real app, you would get the image URL from the server response
                    imageURL = URL(string: "https://example.com/images/recipe123.jpg")
                }
            }
        }
    }
    
    private func saveRecipe() {
        let privacy = shareWith == "Everyone" ? "public" : "private"
        
        // Create a modified recipe
        let modifiedRecipe = Recipe(
            id: recipe.id,
            title: recipeName,
            description: recipe.description,
            instructions: instructions,
            privacy: privacy,
            servings: servings,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
            recipeItems: recipe.recipeItems,
            image: imageURL?.absoluteString ?? recipe.image,
            prepTime: prepTime,
            cookTime: cookTime,
            totalCalories: recipe.totalCalories,
            totalProtein: recipe.totalProtein,
            totalCarbs: recipe.totalCarbs,
            totalFat: recipe.totalFat
        )
        
        // Update the recipe
        foodManager.updateRecipe(
            recipe: modifiedRecipe,
            foods: selectedFoods
        ) { result in
            // Ensure we're on the main thread
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // Clear selected foods for future use
                    self.selectedFoods = []
                    
                    // Navigate back
                    if self.path.count > 0 {
                        self.path.removeLast()
                    } else {
                        self.dismiss()
                    }
                case .failure(let error):
                    print("Error updating recipe: \(error)")
                    // Handle error (show alert, etc.)
                }
            }
        }
    }
}

struct EditRecipeView_Previews: PreviewProvider {
    static let sampleRecipe = Recipe(
        id: 1,
        title: "Sample Recipe",
        description: "A delicious recipe",
        instructions: "Cook it well",
        privacy: "public",
        servings: 4,
        createdAt: Date(),
        updatedAt: Date(),
        recipeItems: [],
        image: nil,
        prepTime: 15,
        cookTime: 30,
        totalCalories: 400,
        totalProtein: 20,
        totalCarbs: 40,
        totalFat: 10
    )
    
    static var previews: some View {
        NavigationView {
            EditRecipeView(
                recipe: sampleRecipe,
                path: .constant(NavigationPath()),
                selectedFoods: .constant([])
            )
            .environmentObject(FoodManager())
        }
    }
}
