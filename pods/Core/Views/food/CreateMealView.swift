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
    @State private var mealName = ""
    @State private var shareWith = "Everyone"
    @State private var instructions = ""
    @State private var showingShareOptions = false
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    @State private var showImagePicker = false
    @State private var showOptionsSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    
    // ADDED: These must exist in the parent if we reference them in Coordinator
    @State private var imageURL: URL? = nil
    @State private var uploadProgress: Double = 0
    @State private var isUploading = false
    @State private var uploadError: Error?
    @State private var showUploadError = false

    @State private var uiImage: UIImage? = nil

    // Add this state variable with your other @State properties
    @FocusState private var focusedField: Field?

    @Binding var path: NavigationPath
    @Binding var selectedFoods: [Food]
    @EnvironmentObject var foodManager: FoodManager

    // Add these states to track saving
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var errorMessage = ""

private var isCreateButtonDisabled: Bool {
    return mealName.isEmpty
}


    // Example share options
    let shareOptions = ["Everyone", "Friends", "Only You"]
    
    // Adjust how tall you want the banner/collapsing area to be
    let headerHeight: CGFloat = 400

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
        GeometryReader { outerGeo in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .top) {
                    // A) Collapsing / Stretchy Header
                    GeometryReader { headerGeo in
                        let offset = headerGeo.frame(in: .global).minY
                        let height = offset > 0
                            ? (headerHeight + offset)
                            : headerHeight
                        
                        // The banner image (if selected), else a placeholder
                        if let selectedImage {
                            selectedImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: outerGeo.size.width, height: height)
                                .clipped()
                                // Shift upward if scrolled up
                                .offset(y: offset > 0 ? -offset : 0)
                                .overlay(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .ignoresSafeArea(edges: .top)
                                .onTapGesture {
                                    showOptionsSheet = true
                                }
                        } else {
                            ZStack {
                                Color("iosnp")
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.accentColor)
                            }
                            .frame(width: outerGeo.size.width, height: height)
                            .offset(y: offset > 0 ? -offset : 0)
                            .onTapGesture {
                                showOptionsSheet = true
                            }
                            .ignoresSafeArea(edges: .top)
                        }
                    }
                    .frame(height: headerHeight)
                    
                    // B) Main Scrollable Content
                    VStack(spacing: 16) {
                        Spacer().frame(height: headerHeight) // leave space for header
                        
                        mealDetailsSection
                        mealItemsSection
                        directionsSection
                        
                        Spacer().frame(height: 40) // extra bottom space
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
          .background(Color("iosbg"))
        // Transparent nav bar so we see banner behind it
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.clear, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("New Meal")
                    .foregroundColor(selectedImage != nil ? .white : .primary)
                    .fontWeight(.semibold)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create") {
                    // Handle create action
                     saveNewMeal()
                }
                .disabled(isCreateButtonDisabled)
                .foregroundColor(selectedImage != nil ? .white : .primary)
                .fontWeight(.semibold)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(selectedImage != nil ? .white : .primary)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        
        // Full screen cover for ImagePicker
      .fullScreenCover(isPresented: $showImagePicker) {
    ImagePicker(
        uiImage: $uiImage,
        image: $selectedImage,
        sourceType: sourceType
    )
}
.onDisappear {
            resetFields() // Reset fields when the view disappears
        }
.onChange(of: uiImage) { newUIImage in
    guard let picked = newUIImage else { return }
    // Use your existing `uploadMealImage(_:, completion:)`
    // For example:
    NetworkManager().uploadMealImage(picked) { result in
        switch result {
        case .success(let url):
            print("Upload success. URL: \(url)")
            // store if needed, e.g. self.imageURL = url
        case .failure(let error):
            print("Upload failed:", error)
            // show alert if you like
        }
    }
}

        
        // Photo selection dialog
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
        // Add error alert
        .alert("Upload Error", isPresented: $showUploadError) {
            Button("Retry") {
                // implement retry if needed
            }
            Button("Cancel", role: .cancel) {
                uploadError = nil
            }
        } message: {
            Text(uploadError?.localizedDescription ?? "Unknown error")
        }

        // Add error alert
        .alert("Error Saving Meal", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func resetFields() {
        mealName = ""
        instructions = ""
        selectedImage = nil
        selectedFoods.removeAll() // Assuming selectedFoods is a mutable array
        // Reset any other state variables as needed
    }


    private func saveNewMeal() {
        isSaving = true
        
        // First upload image if exists
        if let uiImage = uiImage {
            NetworkManager().uploadMealImage(uiImage) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let urlString):
                        // Convert the string URL to a URL object
                        if let url = URL(string: urlString) {
                            self.imageURL = url
                            self.createMeal()
                        } else {
                            // Handle invalid URL
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
            createMeal()
        }
    }

    private func createMeal() {
        foodManager.createMeal(
            title: mealName,
            description: nil,
            directions: instructions,
            privacy: shareWith.lowercased(),
            servings: 1,
            foods: selectedFoods,
            image: imageURL?.absoluteString 
        )
        
        // Dismiss and go back to previous screen
        dismiss()
        path.removeLast()
    }
    
    // MARK: - Subviews
    private var mealDetailsSection: some View {
        VStack(spacing: 16) {
            // Title
            TextField("Title", text: $mealName)
                .focused($focusedField, equals: .mealName)
                .textFieldStyle(.plain)
                // .padding(.vertical, 8)

                  Divider()
            
            // Share-with row
            HStack {
                Text("Share with")
                    .foregroundColor(.primary)
                    
                Spacer()
                Menu {
                    ForEach(shareOptions, id: \.self) { option in
                        Button(option) {
                            shareWith = option
                        }
                    }
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
        Text("Meal Items")
            .font(.title2)
            .fontWeight(.bold)
        
        // 1) Aggregate duplicates by fdcId
        let aggregatedFoods = aggregateFoodsByFdcId(selectedFoods)
        
        if !aggregatedFoods.isEmpty {
            List {
                // 2) Use aggregatedFoods instead of selectedFoods
                ForEach(Array(aggregatedFoods.enumerated()), id: \.element.id) { index, food in
                    
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
                    .listRowSeparator(index == aggregatedFoods.count - 1 ? .hidden : .visible)
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
            path.append(FoodNavigationDestination.addMealItems)
        } label: {
            Text("Add item to meal")
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
    
    // Process foods in order
    for food in allFoods {
        if var existing = grouped[food.fdcId] {
            // Update existing entry
            existing.numberOfServings = (existing.numberOfServings ?? 1) + (food.numberOfServings ?? 1)
            grouped[food.fdcId] = existing
        } else {
            // Add new entry
            grouped[food.fdcId] = food
        }
    }
    
    // Return foods in original order (based on first appearance)
    return allFoods.compactMap { food in
        grouped.removeValue(forKey: food.fdcId)
    }.filter { $0 != nil }
}

/// Removes all items from `selectedFoods` that have the same fdcId
/// as the aggregated item the user swiped to delete.
private func removeAllItems(withFdcId fdcId: Int) {
    selectedFoods.removeAll { $0.fdcId == fdcId }
}


    
    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Directions")
                .font(.title2)
                .fontWeight(.bold)
            
            TextField("Add instructions for making this meal", text: $instructions, axis: .vertical)
                .focused($focusedField, equals: .instructions)
                .textFieldStyle(.plain)
                .padding()
                .background(Color("iosnp"))
                .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var macroCircleAndStats: some View {
    // Get the totals
    let totals = calculateTotalMacros(selectedFoods)
    
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
}

//     private var macroCircleAndStats: some View {
//     let totals = calculateTotalMacros(aggregateFoodsByFdcId(selectedFoods))
    
//     return HStack(spacing: 40) {
//         ZStack {
//             Circle()
//                 .stroke(Color.gray.opacity(0.2), lineWidth: 8)
//                 .frame(width: 80, height: 80)
            
//             Circle()
//                 .trim(from: 0, to: CGFloat(totals.carbsPercentage) / 100)
//                 .stroke(Color("teal"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
//                 .frame(width: 80, height: 80)
//                 .rotationEffect(.degrees(-90))
            
//             Circle()
//                 .trim(from: CGFloat(totals.carbsPercentage) / 100,
//                       to: CGFloat(totals.carbsPercentage + totals.fatPercentage) / 100)
//                 .stroke(Color("pinkRed"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
//                 .frame(width: 80, height: 80)
//                 .rotationEffect(.degrees(-90))
            
//             Circle()
//                 .trim(from: CGFloat(totals.carbsPercentage + totals.fatPercentage) / 100,
//                       to: CGFloat(totals.carbsPercentage + totals.fatPercentage + totals.proteinPercentage) / 100)
//                 .stroke(Color("purple"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
//                 .frame(width: 80, height: 80)
//                 .rotationEffect(.degrees(-90))
            
//             VStack(spacing: 0) {
//                 Text("\(Int(totals.calories))").font(.system(size: 20, weight: .bold))
//                 Text("Cal").font(.system(size: 14))
//             }
//         }
        
//         Spacer()
        
//         // Carbs
//         MacroView(
//             value: totals.carbs,
//             percentage: totals.carbsPercentage,
//             label: "Carbs",
//             percentageColor: Color("teal")
//         )
        
//         // Fat
//         MacroView(
//             value: totals.fat,
//             percentage: totals.fatPercentage,
//             label: "Fat",
//             percentageColor: Color("pinkRed")
//         )
        
//         // Protein
//         MacroView(
//             value: totals.protein,
//             percentage: totals.proteinPercentage,
//             label: "Protein",
//             percentageColor: .purple
//         )
//     }
// }

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
        // Dump first few nutrients to see what we have
        if !food.foodNutrients.isEmpty {
            let nutrientNames = food.foodNutrients.prefix(5).map { "\($0.nutrientName): \($0.value)\($0.unitName)" }
            
        }
        
        // Sum up calories
        if let calories = food.calories {
            totals.calories += calories * servings
        }
        
        // Get protein, carbs, and fat from foodNutrients array
        for nutrient in food.foodNutrients {
            let value = nutrient.value * servings
            
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








