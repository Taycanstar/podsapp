//
//  RecipeDetailView.swift
//  Pods
//
//  Created by Dimi Nunez on 3/22/25.
//

import SwiftUI
import PhotosUI

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    let recipe: Recipe
    @Binding var path: NavigationPath

    @State private var selectedMealTime: String = "Breakfast"
    @State private var showLoggingSuccess = false
    @State private var showLoggingError = false
    
    @State private var isShowingEditRecipe = false
    @State private var isShowingDeleteAlert = false
    @State private var recipeWasSaved = false
    
    @State private var servingsCount: Int
    @State private var selectedPrivacy: String
    
    // Keep track of the recipe's items in a local array
    @State private var selectedFoods: [Food] = []
    // Backup in case user cancels
    @State private var backupFoods: [Food] = []
    
    // Adjust how tall you want the banner/collapsing area to be
    private let headerHeight: CGFloat = 400
    
    // Whether the recipe has an image
    private var hasImage: Bool {
        guard let imageURL = recipe.image else { return false }
        return !imageURL.isEmpty
    }
    
    // Add the missing state variable
    @State private var isLoggingRecipe = false
    
    // MARK: - Initializer
    init(recipe: Recipe, path: Binding<NavigationPath>) {
        self.recipe = recipe
        self._path = path
        
        // Initialize local states
        _servingsCount = State(initialValue: recipe.servings)
        _selectedPrivacy = State(initialValue: recipe.privacy.capitalized)
        
        // We'll fill `selectedFoods` onAppear below
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
                        
                        if let imageURL = recipe.image,
                           let url = URL(string: imageURL),
                           !imageURL.isEmpty {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: outerGeo.size.width, height: height)
                                        .clipped()
                                        .offset(y: offset > 0 ? -offset : 0)
                                        .overlay(gradientOverlay)
                                case .empty, .failure:
                                    fallbackImageView(height: height, offset: offset, width: outerGeo.size.width)
                                @unknown default:
                                    fallbackImageView(height: height, offset: offset, width: outerGeo.size.width)
                                }
                            }
                            .ignoresSafeArea(edges: .top)
                        } else {
                            fallbackImageView(height: height, offset: offset, width: outerGeo.size.width)
                        }
                    }
                    .frame(height: headerHeight)
                    
                    // B) Main Scrollable Content
                    VStack(spacing: 16) {
                        Spacer().frame(height: headerHeight)
                        
                        recipeDetailsSection
                        if !recipe.recipeItems.isEmpty {
                            recipeItemsSection
                        }
                        if let instructions = recipe.instructions, !instructions.isEmpty {
                            directionsSection
                        }

                        // Edit button
                        ButtonWithIcon(
                            label: "Edit Recipe",
                            iconName: "square.and.pencil",
                            action: {
                                isShowingEditRecipe = true
                            },
                            bgColor: Color("iosnp"),
                            textColor: .accentColor
                        )
                        
                        Spacer().frame(height: 80)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color("iosbg"))
            
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Recipe Details")
                        .foregroundColor(hasImage ? .white : .primary)
                        .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Right side "..." menu + "Log" button
                    HStack {
                        Menu {
                            Button {
                                isShowingEditRecipe = true
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
                                .foregroundColor(hasImage ? .white : .primary)
                        }
                        
                        Button("Log") {
                            logRecipe()
                        }
                        .foregroundColor(hasImage ? .white : .primary)
                        .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(hasImage ? .white : .primary)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            
            .alert("Delete Recipe", isPresented: $isShowingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteRecipe()
                }
            } message: {
                Text("Are you sure you want to delete this recipe?")
            }
            
            .alert("Success", isPresented: $showLoggingSuccess) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Recipe logged successfully")
            }
            
            // Show the edit sheet
            .sheet(isPresented: $isShowingEditRecipe, onDismiss: {
                // If we did not actually save changes, revert
                if !recipeWasSaved {
                    selectedFoods = backupFoods
                }
            }, content: {
                NavigationView {
                    EditRecipeView(
                        recipe: recipe,
                        path: $path,
                        selectedFoods: $selectedFoods,
                        onSave: {
                            // Mark the recipe as saved
                            recipeWasSaved = true
                        }
                    )
                }
            })
            .onAppear(perform: handleOnAppear)
   
        }
    }
    
    // MARK: - Subviews
    
    /// Overlays a dark gradient at the bottom of the image.
    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Fallback "no image" view, same style you used in MealDetailView.
    private func fallbackImageView(height: CGFloat, offset: CGFloat, width: CGFloat) -> some View {
        ZStack {
            Color("iosnp")
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(.gray)
        }
        .frame(width: width, height: height)
        .offset(y: offset > 0 ? -offset : 0)
        .ignoresSafeArea(edges: .top)
    }
    
    /// Show high-level recipe info: title, servings, shareWith, macros
    private var recipeDetailsSection: some View {
        VStack(spacing: 8) {
            // Title (non-editable)
            Text(recipe.title)
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
            
            // Servings row
            HStack {
                Text("Servings")
                    .foregroundColor(.primary)
                Spacer()
                Stepper("\(servingsCount)", value: $servingsCount, in: 1...20)
            }
            
            Divider()
            
            // "Shared with"
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
    
    /// List of the recipe items, if any
    private var recipeItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title2)
                .fontWeight(.bold)
            
            List {
                ForEach(Array(recipe.recipeItems.enumerated()), id: \.element.foodId) { index, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)
                            
                            // Show serving text if present
                            HStack {
                                Text(item.servingText ?? "1 serving")
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
                    .listRowSeparator(index == recipe.recipeItems.count - 1 ? .hidden : .visible)
                }
            }
            .listStyle(.plain)
            .background(Color("iosnp"))
            .cornerRadius(12)
            .scrollDisabled(true)
            // Each row ~65 in your example
            .frame(height: CGFloat(recipe.recipeItems.count * 65))
        }
        .padding(.horizontal)
    }
    
    /// Directions/Instructions box
    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Directions")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(recipe.instructions ?? "")
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("iosnp"))
                .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    /// Macro ring and percentages
    private var macroCircleAndStats: some View {
        // Base values for a single serving
        let baseProteinValue = recipe.totalProtein ?? 0
        let baseCarbsValue = recipe.totalCarbs ?? 0
        let baseFatValue = recipe.totalFat ?? 0
        let baseCalories = recipe.calories
        
        // Scale values according to servings count
        let proteinValue = baseProteinValue * Double(servingsCount) / Double(recipe.servings)
        let carbsValue = baseCarbsValue * Double(servingsCount) / Double(recipe.servings)
        let fatValue = baseFatValue * Double(servingsCount) / Double(recipe.servings)
        let scaledCalories = baseCalories * Double(servingsCount) / Double(recipe.servings)
        
        let totalMacros = proteinValue + carbsValue + fatValue
        let proteinPct = totalMacros > 0 ? (proteinValue / totalMacros) * 100 : 0
        let carbsPct = totalMacros > 0 ? (carbsValue / totalMacros) * 100 : 0
        let fatPct = totalMacros > 0 ? (fatValue / totalMacros) * 100 : 0
        
        return HStack(spacing: 40) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: CGFloat(carbsPct) / 100)
                    .stroke(Color("teal"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(
                        from: CGFloat(carbsPct) / 100,
                        to: CGFloat(carbsPct + fatPct) / 100
                    )
                    .stroke(Color("pinkRed"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(
                        from: CGFloat(carbsPct + fatPct) / 100,
                        to: CGFloat(carbsPct + fatPct + proteinPct) / 100
                    )
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                // Center text: scaled calories
                VStack(spacing: 0) {
                    Text("\(Int(scaledCalories))")
                        .font(.system(size: 20, weight: .bold))
                    Text("Cal").font(.system(size: 14))
                }
            }
            
            Spacer()
            
            // Carbs
            macroStatBlock(
                percentage: carbsPct,
                grams: carbsValue,
                label: "Carbs",
                colorName: "teal"
            )
            
            // Fat
            macroStatBlock(
                percentage: fatPct,
                grams: fatValue,
                label: "Fat",
                colorName: "pinkRed"
            )
            
            // Protein
            macroStatBlock(
                percentage: proteinPct,
                grams: proteinValue,
                label: "Protein",
                colorName: "purple"
            )
        }
        .id(servingsCount) // Force redraw when servings change
    }
    
    private func macroStatBlock(percentage: Double, grams: Double, label: String, colorName: String) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(percentage))%")
                .foregroundColor(Color(colorName))
                .font(.caption)
            Text("\(Int(grams))g")
                .font(.body)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Methods
    
    /// Run once on appear: build `selectedFoods` from `recipeItems`
    private func handleOnAppear() {
        // If we haven't set up foods yet, do it now
        if selectedFoods.isEmpty {
            let foods = recipe.recipeItems.map { item -> Food in
                let sv = Double(item.servings) ?? 1.0
                return Food(
                    fdcId: item.foodId,
                    description: item.name,
                    brandOwner: nil,
                    brandName: nil,
                    servingSize: 1.0,
                    numberOfServings: sv,
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
            }
            selectedFoods = foods
            backupFoods = foods
            print("🍝 RecipeDetailView: Loaded \(foods.count) items from recipe")
        }
    }
    
    /// Fire a "logRecipe" call in your `FoodManager`.
    private func logRecipe() {
        isLoggingRecipe = true
        
        // First, close the food container immediately
        viewModel.isShowingFoodContainer = false
        
        // Calculate the scaled calories based on serving count
        let baseCalories = recipe.calories
        let scaledCalories = baseCalories * Double(servingsCount) / Double(recipe.servings)
        
        foodManager.logRecipe(
            recipe: recipe,
            mealTime: selectedMealTime,
            date: Date(),
            notes: nil,
            calories: scaledCalories,
            statusCompletion: { success in
                isLoggingRecipe = false
                if success {
                    showLoggingSuccess = true
                } else {
                    showLoggingError = true
                }
            }
        )
    }
    
    /// "Delete" the recipe. You might have a function in `NetworkManager` or `FoodManager`.
    private func deleteRecipe() {
        // Example:
        print("Deleting recipe with ID: \(recipe.id)")
        dismiss()
    }
    

}
