//
//  MealDetailView.swift
//  Pods
//
//  Created by Dimi Nunez on 3/3/25.
//

import SwiftUI

//
//  EditMealView.swift
//  Pods
//
//  Created by Dimi Nunez on 3/12/25.
//

import SwiftUI
import PhotosUI

struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager
    
    // MARK: - Properties
    let meal: Meal
    @Binding var path: NavigationPath
    
    // MARK: - State
    @State private var isShowingEditMeal = false
    @State private var isShowingDeleteAlert = false
    @State private var showLoggingSuccess = false
    @State private var servingsCount: Int
    @State private var selectedPrivacy: String
    @State private var selectedMealTime: String = "Breakfast"
    
    // Adjust how tall you want the banner/collapsing area to be
    private let headerHeight: CGFloat = 400
    
    // Add a computed property to determine if we should show white text
    private var hasImage: Bool {
        return (meal.image != nil && !meal.image!.isEmpty)
    }
    
    // MARK: - Initializer
    init(meal: Meal, path: Binding<NavigationPath>) {
        self.meal = meal
        self._path = path
        self._servingsCount = State(initialValue: meal.servings)
        self._selectedPrivacy = State(initialValue: meal.privacy.capitalized)
        
        // Convert meal items to Food objects for the selectedFoods array
        var foods: [Food] = []
        
        for item in meal.mealItems {
            let food = Food(
                fdcId: Int(item.externalId) ?? item.foodId,
                description: item.name,
                brandOwner: nil,
                brandName: nil,
                servingSize: 1.0,
                numberOfServings: Double(item.servings) != 0 ? Double(item.servings) : 1.0,
                servingSizeUnit: item.servingText ?? "",
                householdServingFullText: item.servingText ?? "",
                foodNutrients: [
                    Nutrient(nutrientName: "Energy", value: item.calories, unitName: "kcal"),
                    Nutrient(nutrientName: "Protein", value: item.protein, unitName: "g"),
                    Nutrient(nutrientName: "Carbohydrate, by difference", value: item.carbs, unitName: "g"),
                    Nutrient(nutrientName: "Total lipid (fat)", value: item.fat, unitName: "g")
                ],
                foodMeasures: []
            )
            foods.append(food)
        }
    }
    
    // MARK: - Body
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
                        
                        // The banner image from meal
                        if let imageUrlString = meal.image, !imageUrlString.isEmpty, let url = URL(string: imageUrlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: outerGeo.size.width, height: height)
                                        .clipped()
                                        .offset(y: offset > 0 ? -offset : 0)
                                        .overlay(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                case .empty, .failure:
                                    fallbackImageView(height: height, offset: offset, outerWidth: outerGeo.size.width)
                                @unknown default:
                                    fallbackImageView(height: height, offset: offset, outerWidth: outerGeo.size.width)
                                }
                            }
                            .ignoresSafeArea(edges: .top)
                        } else {
                            fallbackImageView(height: height, offset: offset, outerWidth: outerGeo.size.width)
                        }
                    }
                    .frame(height: headerHeight)
                    
                    // B) Main Scrollable Content
                    VStack(spacing: 16) {
                        Spacer().frame(height: headerHeight) // leave space for header
                        
                        mealDetailsSection
                        
                        if !meal.mealItems.isEmpty {
                            mealItemsSection
                        }
                        
                        if let directions = meal.directions, !directions.isEmpty {
                            directionsSection
                        }

                        ButtonWithIcon(
                            label: "Edit Meal",
                            iconName: "square.and.pencil",
                            action: {
                                isShowingEditMeal = true
                            },
                            bgColor: Color("iosnp"),
                            textColor: .accentColor
                        )
                        
                        Spacer().frame(height: 80) // extra bottom space
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color("iosbg"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Meal Details")
                        .foregroundColor(hasImage ? .white : .primary)
                        .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Menu {
                            Button {
                                isShowingEditMeal = true
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
                            logMeal()
                        }
                        .foregroundColor(hasImage ? .white : .primary)
                        .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(hasImage ? .white : .primary)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $isShowingEditMeal, onDismiss: {
                // Refresh the meal data after editing
                if let updatedMeal = foodManager.meals.first(where: { $0.id == meal.id }) {
                    // Update local state to match the updated meal
                    servingsCount = updatedMeal.servings
                    selectedPrivacy = updatedMeal.privacy.capitalized
                }
            }) {
                EditMealView(
                    meal: meal,
                    path: $path,
                    selectedFoods: .constant([])
                )
            }
            .alert("Delete Meal", isPresented: $isShowingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteMeal()
                }
            } message: {
                Text("Are you sure you want to delete this meal?")
            }
            .alert("Success", isPresented: $showLoggingSuccess) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Meal logged successfully")
            }
        }
        .onChange(of: servingsCount) { _ in
            updateMealDetails()
        }
        .onChange(of: selectedPrivacy) { _ in
            updateMealDetails()
        }
    }
    
    private func fallbackImageView(height: CGFloat, offset: CGFloat, outerWidth: CGFloat) -> some View {
        ZStack {
            Color("iosnp")
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(.gray)
        }
        .frame(width: outerWidth, height: height)
        .offset(y: offset > 0 ? -offset : 0)
        .ignoresSafeArea(edges: .top)
    }
    
    private func logMeal() {
        // Use the foodManager to log the meal with appropriate parameters
        foodManager.logMeal(
            meal: meal,
            mealTime: selectedMealTime,
            statusCompletion: { success in
                if success {
                    showLoggingSuccess = true
                }
            }
        )
    }
    
    private func deleteMeal() {
        // Since we don't have a direct deleteMeal method in FoodManager,
        // we would need to use networkManager or another approach.
        // For now, just display a message and dismiss the view.
        print("Deleting meal with ID: \(meal.id)")
        dismiss()
    }
    
    // MARK: - Subviews
    private var mealDetailsSection: some View {
        VStack(spacing: 8) {
            // Title (non-editable)
            Text(meal.title)
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
            
            // Meal time row
            HStack {
                Text("Meal")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    Button("Breakfast") { selectedMealTime = "Breakfast" }
                    Button("Lunch") { selectedMealTime = "Lunch" }
                    Button("Dinner") { selectedMealTime = "Dinner" }
                    Button("Snack") { selectedMealTime = "Snack" }
                } label: {
                    HStack {
                        Text(selectedMealTime)
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
            
            // Share-with row
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

    private var mealItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Items")
                .font(.title2)
                .fontWeight(.bold)
            
            List {
                ForEach(Array(meal.mealItems.enumerated()), id: \.element.foodId) { index, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)
                            
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
                    .listRowSeparator(index == meal.mealItems.count - 1 ? .hidden : .visible)
                }
            }
            .listStyle(.plain)
            .background(Color("iosnp"))
            .cornerRadius(12)
            .scrollDisabled(true)
            .frame(height: CGFloat(meal.mealItems.count * 65))
        }
        .padding(.horizontal)
    }

    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Directions")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(meal.directions ?? "")
                .padding()                                 // internal text padding
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("iosnp"))                // background spans full width
                .cornerRadius(12)
        }
        .padding(.horizontal)                              // horizontal margin from screen edges
    }

    private var macroCircleAndStats: some View {
        let proteinValue = meal.totalProtein ?? 0
        let carbsValue = meal.totalCarbs ?? 0
        let fatValue = meal.totalFat ?? 0
        
        // Calculate percentages
        let totalMacros = proteinValue + carbsValue + fatValue
        let proteinPercent = totalMacros > 0 ? (proteinValue / totalMacros) * 100 : 0
        let carbsPercent = totalMacros > 0 ? (carbsValue / totalMacros) * 100 : 0
        let fatPercent = totalMacros > 0 ? (fatValue / totalMacros) * 100 : 0
        
        return HStack(spacing: 40) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                // Draw the circle segments with percentages
                Circle()
                    .trim(from: 0, to: CGFloat(carbsPercent) / 100)
                    .stroke(Color("teal"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(from: CGFloat(carbsPercent) / 100,
                          to: CGFloat(carbsPercent + fatPercent) / 100)
                    .stroke(Color("pinkRed"), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(from: CGFloat(carbsPercent + fatPercent) / 100,
                          to: CGFloat(carbsPercent + fatPercent + proteinPercent) / 100)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(Int(meal.calories))").font(.system(size: 20, weight: .bold))
                    Text("Cal").font(.system(size: 14))
                }
            }
            
            Spacer()
            
            // Use MacroView component for macro stats
            VStack(spacing: 4) {
                Text("\(Int(carbsPercent))%")
                    .foregroundColor(Color("teal"))
                    .font(.caption)
                Text("\(Int(carbsValue))g")
                    .font(.body)
                Text("Carbs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("\(Int(fatPercent))%")
                    .foregroundColor(Color("pinkRed"))
                    .font(.caption)
                Text("\(Int(fatValue))g")
                    .font(.body)
                Text("Fat")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("\(Int(proteinPercent))%")
                    .foregroundColor(Color.purple)
                    .font(.caption)
                Text("\(Int(proteinValue))g")
                    .font(.body)
                Text("Protein")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // Add a function to update meal servings and privacy
    private func updateMealDetails() {
        // Only update if values have changed
        if servingsCount != meal.servings || selectedPrivacy.lowercased() != meal.privacy {
            print("📝 Updating meal details - servings: \(servingsCount), privacy: \(selectedPrivacy)")
            
            // Create a copy of the meal with updated values
            let updatedMeal = Meal(
                id: meal.id,
                title: meal.title,
                description: meal.description,
                directions: meal.directions,
                privacy: selectedPrivacy.lowercased(),
                servings: servingsCount,
                mealItems: meal.mealItems,
                image: meal.image,
                totalCalories: meal.totalCalories,
                totalProtein: meal.totalProtein,
                totalCarbs: meal.totalCarbs,
                totalFat: meal.totalFat,
                scheduledAt: meal.scheduledAt
            )
            
            // Use foodManager to update the meal
            foodManager.updateMeal(meal: updatedMeal) { result in
                switch result {
                case .success(let meal):
                    print("✅ Successfully updated meal details")
                case .failure(let error):
                    print("❌ Failed to update meal details: \(error)")
                }
            }
        }
    }
}

