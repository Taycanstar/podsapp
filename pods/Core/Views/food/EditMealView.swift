//
//  EditMealView.swift
//  Pods
//
//  Created by Claude AI on 3/15/25.
//

import SwiftUI
import PhotosUI

struct EditMealView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var mealName: String
    @State private var shareWith: String
    @State private var instructions: String
    @State private var servings: String
    @State private var scheduledAt: Date?
    
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
    @State private var imageChanged = false

    @State private var uiImage: UIImage? = nil
    @State private var originalImageURL: String?

    @FocusState private var focusedField: Field?

    @State private var selectedFoods: [Food]
    @EnvironmentObject var foodManager: FoodManager

    // Add these states to track saving
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var saveError: String = ""
    
    // The meal being edited
    private let meal: Meal
    
    // MARK: - Initialization
    init(meal: Meal) {
        self.meal = meal
        
        // Initialize state variables with meal data
        _mealName = State(initialValue: meal.title)
        _shareWith = State(initialValue: meal.privacy)
        _instructions = State(initialValue: meal.directions ?? "")
        _servings = State(initialValue: String(meal.servings))
        _scheduledAt = State(initialValue: meal.scheduledAt)
        _selectedFoods = State(initialValue: meal.mealItems)
        _originalImageURL = State(initialValue: meal.image)
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Meal Image Section
                        Group {
                            if let selectedImage = selectedImage {
                                selectedImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(12)
                            } else if let imageURLString = originalImageURL, let url = URL(string: imageURLString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(height: 200)
                                            .frame(maxWidth: .infinity)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 200)
                                            .frame(maxWidth: .infinity)
                                            .clipped()
                                            .cornerRadius(12)
                                    case .failure:
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 200)
                                            .frame(maxWidth: .infinity)
                                            .foregroundColor(.gray)
                                            .cornerRadius(12)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.gray)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showOptionsSheet = true
                            }) {
                                Text("Change Photo")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 10)
                        }
                        
                        // Meal Details Section
                        Group {
                            TextField("Meal Name", text: $mealName)
                                .font(.title2)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .focused($focusedField, equals: .mealName)
                            
                            HStack {
                                Text("Share with:")
                                    .font(.headline)
                                
                                Picker("", selection: $shareWith) {
                                    Text("Private").tag("private")
                                    Text("Everyone").tag("public")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            TextField("Number of servings", text: $servings)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            DatePicker(
                                "Scheduled Time",
                                selection: Binding(
                                    get: { scheduledAt ?? Date() },
                                    set: { scheduledAt = $0 }
                                ),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            Toggle("No specific time", isOn: Binding(
                                get: { scheduledAt == nil },
                                set: { if $0 { scheduledAt = nil } else { scheduledAt = Date() } }
                            ))
                            .padding(.horizontal)
                            
                            Text("Instructions")
                                .font(.headline)
                            
                            TextEditor(text: $instructions)
                                .frame(minHeight: 100)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .focused($focusedField, equals: .instructions)
                        }
                        
                        // Meal Items Section
                        Group {
                            Text("Meal Items")
                                .font(.headline)
                            
                            ForEach(selectedFoods) { food in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(food.name)
                                            .font(.headline)
                                        Text("\(food.servingText ?? "1 serving") - \(Int(food.calories)) calories")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        if let index = selectedFoods.firstIndex(where: { $0.id == food.id }) {
                                            selectedFoods.remove(at: index)
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            // Macro Circle
                            macroCircleAndStats
                                .padding(.vertical)
                        }
                    }
                    .padding()
                }
                
                // Loading overlay
                if isSaving {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text("Saving meal...")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                }
            }
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        updateMeal()
                    }
                    .disabled(mealName.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showOptionsSheet) {
                VStack(spacing: 20) {
                    Button(action: {
                        sourceType = .camera
                        showImagePicker = true
                        showOptionsSheet = false
                    }) {
                        Text("Take Photo")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        sourceType = .photoLibrary
                        showImagePicker = true
                        showOptionsSheet = false
                    }) {
                        Text("Choose from Library")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        showOptionsSheet = false
                    }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .alert("Error Saving Meal", isPresented: $showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    // Calculate a unique signature for the selected foods to force view updates
    private var foodsSignature: String {
        selectedFoods.map { "\($0.id):\($0.servings)" }.joined(separator: ",")
    }
    
    private var macroCircleAndStats: some View {
        let macros = calculateTotalMacros(selectedFoods)
        let totalCalories = macros.calories
        let totalProtein = macros.protein
        let totalCarbs = macros.carbs
        let totalFat = macros.fat
        
        let totalMacroGrams = totalProtein + totalCarbs + totalFat
        let proteinPercentage = totalMacroGrams > 0 ? totalProtein / totalMacroGrams : 0
        let carbsPercentage = totalMacroGrams > 0 ? totalCarbs / totalMacroGrams : 0
        let fatPercentage = totalMacroGrams > 0 ? totalFat / totalMacroGrams : 0
        
        return VStack {
            Text("Nutrition Summary")
                .font(.headline)
                .padding(.bottom, 5)
            
            ZStack {
                // Outer circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                // Carbs segment (green)
                Circle()
                    .trim(from: 0, to: carbsPercentage)
                    .stroke(Color.green, lineWidth: 20)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                
                // Fat segment (yellow)
                Circle()
                    .trim(from: 0, to: fatPercentage)
                    .stroke(Color.yellow, lineWidth: 20)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90 + 360 * carbsPercentage))
                
                // Protein segment (blue)
                Circle()
                    .trim(from: 0, to: proteinPercentage)
                    .stroke(Color.blue, lineWidth: 20)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90 + 360 * (carbsPercentage + fatPercentage)))
                
                // Center text
                VStack {
                    Text("\(Int(totalCalories))")
                        .font(.system(size: 32, weight: .bold))
                    Text("calories")
                        .font(.subheadline)
                }
            }
            .frame(height: 220)
            .padding(.bottom, 10)
            
            // Macro details
            HStack(spacing: 20) {
                MacroLabel(color: .green, name: "Carbs", value: "\(Int(totalCarbs))g", percentage: Int(carbsPercentage * 100))
                MacroLabel(color: .yellow, name: "Fat", value: "\(Int(totalFat))g", percentage: Int(fatPercentage * 100))
                MacroLabel(color: .blue, name: "Protein", value: "\(Int(totalProtein))g", percentage: Int(proteinPercentage * 100))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .id(foodsSignature) // Force redraw when foods change
    }
    
    // MARK: - Methods
    
    func updateMeal() {
        isSaving = true
        
        // First, check if we need to upload a new image
        if imageChanged, let uiImage = uiImage {
            // Upload the image first
            // This would be implemented in your NetworkManager or similar
            // For now, we'll simulate it
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                // Simulate image upload success
                self.imageURL = URL(string: "https://example.com/meal-image.jpg")
                self.completeUpdate()
            }
        } else {
            // No image change, proceed with update
            completeUpdate()
        }
    }
    
    private func completeUpdate() {
        // Calculate macro totals
        let macros = calculateTotalMacros(selectedFoods)
        
        // Create updated meal object
        let updatedMeal = Meal(
            id: meal.id,
            title: mealName,
            description: "",
            directions: instructions,
            privacy: shareWith,
            servings: Int(servings) ?? 1,
            createdAt: meal.createdAt,
            mealItems: selectedFoods,
            image: imageURL?.absoluteString ?? originalImageURL,
            totalCalories: macros.calories,
            totalProtein: macros.protein,
            totalCarbs: macros.carbs,
            totalFat: macros.fat,
            scheduledAt: scheduledAt
        )
        
        // Call API to update meal
        foodManager.updateMeal(meal: updatedMeal) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                
                switch result {
                case .success:
                    // Dismiss the view
                    self.dismiss()
                    
                case .failure(let error):
                    // Show error
                    self.saveError = error.localizedDescription
                    self.showSaveError = true
                }
            }
        }
    }
    
    private func calculateTotalMacros(_ foods: [Food]) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0
        
        for food in foods {
            totalCalories += food.calories * food.servings
            totalProtein += (food.protein ?? 0) * food.servings
            totalCarbs += (food.carbs ?? 0) * food.servings
            totalFat += (food.fat ?? 0) * food.servings
        }
        
        return (totalCalories, totalProtein, totalCarbs, totalFat)
    }
}

// MARK: - Supporting Views

struct MacroLabel: View {
    let color: Color
    let name: String
    let value: String
    let percentage: Int
    
    var body: some View {
        VStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("\(percentage)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Field Enum
enum Field: Hashable {
    case mealName
    case instructions
}

// MARK: - Preview
#Preview {
    // Create a sample meal for preview
    let sampleMeal = Meal(
        id: "123",
        title: "Sample Meal",
        description: "A delicious sample meal",
        directions: "Cook and enjoy!",
        privacy: "private",
        servings: 2,
        createdAt: Date(),
        mealItems: [],
        image: nil,
        totalCalories: 500,
        totalProtein: 30,
        totalCarbs: 50,
        totalFat: 20,
        scheduledAt: Date()
    )
    
    return EditMealView(meal: sampleMeal)
        .environmentObject(FoodManager())
} 