//
//  CreateRecipeView.swift
//  Pods
//
//  Created by Dimi Nunez on 3/16/25.
//

import SwiftUI
import PhotosUI



struct CreateRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var recipeName = ""
    @State private var shareWith = "Everyone"
    @State private var instructions = ""
    @State private var prepTime = ""
    @State private var cookTime = ""
    @State private var servings = "1"
    @State private var showingShareOptions = false
    
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
    
    @State private var showNameTakenAlert = false
    @State private var uiImage: UIImage? = nil

    @FocusState private var focusedField: Field?

    @Binding var path: NavigationPath
    @Binding var selectedFoods: [Food]
    @EnvironmentObject var foodManager: FoodManager
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !recipeName.isEmpty && !selectedFoods.isEmpty && Int(servings) ?? 0 > 0
    }
    
    // Break down the nutrition calculations into separate properties
    private var servingsValue: Double {
        Double(Int(servings) ?? 1)
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
    private var caloriesPerServing: Double {
        totalCalories / servingsValue
    }
    
    private var proteinPerServing: Double {
        totalProtein / servingsValue
    }
    
    private var carbsPerServing: Double {
        totalCarbs / servingsValue
    }
    
    private var fatPerServing: Double {
        totalFat / servingsValue
    }
    
    // MARK: - Init
    
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
                }
                
                // Servings
                VStack(alignment: .leading) {
                    Text("Servings")
                        .font(.headline)
                    
                    TextField("Number of servings", text: $servings)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                // Time
                HStack {
                    // Prep Time
                    VStack(alignment: .leading) {
                        Text("Prep Time (mins)")
                            .font(.headline)
                        
                        TextField("Prep time", text: $prepTime)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                    
                    Spacer()
                    
                    // Cook Time
                    VStack(alignment: .leading) {
                        Text("Cook Time (mins)")
                            .font(.headline)
                        
                        TextField("Cook time", text: $cookTime)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
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
                }
                
                // Add ingredients button
                Button(action: {
                    path.append(FoodNavigationDestination.addRecipeIngredients)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Ingredients")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // Selected ingredients
                if !selectedFoods.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredients")
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
                
                // Create button
                Button(action: createRecipe) {
                    Text("Create Recipe")
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
        .navigationTitle("Create Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
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
        }
        .onChange(of: uiImage) { newImage in
            if let newImage = newImage {
                uploadImage(newImage)
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
                Text("Add Photo")
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
        .confirmationDialog("Share Recipe With", isPresented: $showingShareOptions, titleVisibility: .visible) {
            Button("Everyone (Public)") { shareWith = "Everyone" }
            Button("Only Me (Private)") { shareWith = "Only Me" }
        } message: {
            Text("Choose who can see your recipe")
        }
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
    
    private func createRecipe() {
        guard let servingsInt = Int(servings), servingsInt > 0 else {
            // Handle invalid servings
            return
        }
        
        let prepTimeInt = Int(prepTime) ?? 0
        let cookTimeInt = Int(cookTime) ?? 0
        
        let privacy = shareWith == "Everyone" ? "public" : "private"
        
        // Set any existing tags for FoodNavigationDestination
        foodManager.createRecipe(
            title: recipeName,
            description: "",
            instructions: instructions,
            privacy: privacy,
            servings: servingsInt,
            foods: selectedFoods,
            image: imageURL?.absoluteString,
            prepTime: prepTimeInt,
            cookTime: cookTimeInt,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat
        ) { result in
            // Ensure we're on the main thread
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // Clear selected foods for future use
                    self.selectedFoods = []
                    
                    // Navigate back by removing this view from the path
                    self.path.removeLast()
                    
                case .failure(let error):
                    print("Error creating recipe: \(error)")
                    // Handle error (show alert, etc.)
                }
            }
        }
    }
}

struct CreateRecipeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CreateRecipeView(
                path: .constant(NavigationPath()),
                selectedFoods: .constant([])
            )
            .environmentObject(FoodManager())
        }
    }
}
