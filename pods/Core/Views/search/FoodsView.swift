//
//  FoodsView.swift
//  pods
//
//  Created by Dimi Nunez on 12/18/25.
//

import SwiftUI

struct FoodsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissSearch) private var dismissSearch
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @ObservedObject private var userFoodsRepo = UserFoodsRepository.shared

    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var showQuickAddSheet = false
    @State private var showNewFoodSheet = false
    @State private var selectedFood: Food?
    @State private var createdFoodToAdd: Food?
    @StateObject private var plateViewModel = PlateViewModel()
    @State private var showPlateView = false

    // Filtered foods based on search
    private var filteredFoods: [Food] {
        if searchText.isEmpty {
            return userFoodsRepo.snapshot.foods
        }
        return userFoodsRepo.snapshot.foods.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func closeSearchIfNeeded() {
        dismissSearch()
        isSearchPresented = false
    }

    var body: some View {
        List {
            // Action Buttons Section
            Section {
                HStack(spacing: 12) {
                    // Create Food button
                    Button {
                        closeSearchIfNeeded()
                        showNewFoodSheet = true
                    } label: {
                        Text("Create")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Quick Add button
                    Button {
                        closeSearchIfNeeded()
                        showQuickAddSheet = true
                    } label: {
                        Text("Quick Add")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listSectionSeparator(.hidden)

            // User Foods List Section
            if filteredFoods.isEmpty {
                // Empty state
                Section {
                    VStack(spacing: 8) {
                        Text("No foods yet")
                            .font(.headline)
                        Text("Create your first food to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(filteredFoods) { food in
                        UserFoodRow(
                            food: food,
                            onLogTapped: {
                                closeSearchIfNeeded()
                                logFoodDirectly(food)
                            },
                            onAddToPlateTapped: {
                                closeSearchIfNeeded()
                                addFoodToPlate(food)
                            },
                            onViewDetailsTapped: {
                                closeSearchIfNeeded()
                                selectedFood = food
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteFood(food)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .navigationTitle("Foods")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, isPresented: $isSearchPresented)
        .sheet(isPresented: $showQuickAddSheet) {
            QuickAddSheet()
                .environmentObject(foodManager)
        }
        .sheet(isPresented: $showNewFoodSheet) {
            NewFoodView(
                onFoodCreated: { food in
                    // Optimistically add to local list immediately
                    userFoodsRepo.insertOptimistically(food)
                },
                onFoodCreatedAndAdd: { food in
                    // Close the sheet first, then show FoodDetails
                    showNewFoodSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        createdFoodToAdd = food
                    }
                }
            )
            .environmentObject(foodManager)
            .environmentObject(viewModel)
        }
        .navigationDestination(item: $selectedFood) { food in
            FoodDetails(food: food)
                .environmentObject(dayLogsVM)
                .environmentObject(foodManager)
        }
        .navigationDestination(item: $createdFoodToAdd) { food in
            FoodDetails(food: food)
                .environmentObject(dayLogsVM)
                .environmentObject(foodManager)
        }
        .sheet(isPresented: $showPlateView) {
            NavigationStack {
                PlateView(
                    viewModel: plateViewModel,
                    selectedMealPeriod: suggestedMealPeriod(for: Date()),
                    mealTime: Date(),
                    onFinished: {
                        showPlateView = false
                        plateViewModel.clear()
                    }
                )
                .environmentObject(foodManager)
                .environmentObject(dayLogsVM)
                .environmentObject(viewModel)
            }
        }
        .task {
            await userFoodsRepo.refresh()
        }
    }

    // MARK: - Delete Food
    private func deleteFood(_ food: Food) {
        // Remove optimistically FIRST for smooth UI
        userFoodsRepo.removeOptimistically(fdcId: food.fdcId)

        foodManager.deleteUserFood(id: food.fdcId) { result in
            if case .failure = result {
                // On failure, refresh to restore the item
                Task {
                    await userFoodsRepo.refresh(force: true)
                }
            }
            // On success, no need to refresh - already removed optimistically
        }
    }

    private func addFoodToPlate(_ food: Food) {
        let entry = buildPlateEntry(from: food)
        plateViewModel.add(entry)
        showPlateView = true
    }

    private func buildPlateEntry(from food: Food) -> PlateEntry {
        let baseMacros = MacroTotals(
            calories: food.calories ?? 0,
            protein: food.protein ?? 0,
            carbs: food.carbs ?? 0,
            fat: food.fat ?? 0
        )

        var baseNutrients: [String: RawNutrientValue] = [:]
        for nutrient in food.foodNutrients {
            let key = nutrient.nutrientName.lowercased()
            baseNutrients[key] = RawNutrientValue(value: nutrient.value ?? 0, unit: nutrient.unitName)
        }

        let baselineGramWeight = food.foodMeasures.first?.gramWeight ?? food.servingSize ?? 100

        return PlateEntry(
            food: food,
            servings: food.numberOfServings ?? 1,
            selectedMeasureId: food.foodMeasures.first?.id,
            availableMeasures: food.foodMeasures,
            baselineGramWeight: baselineGramWeight,
            baseNutrientValues: baseNutrients,
            baseMacroTotals: baseMacros,
            servingDescription: food.servingSizeText ?? "1 serving",
            mealItems: food.mealItems ?? [],
            mealPeriod: suggestedMealPeriod(for: Date()),
            mealTime: Date(),
            recipeItems: []
        )
    }

    private func suggestedMealPeriod(for date: Date) -> MealPeriod {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
        }
    }

    // MARK: - Log Food
    private func logFoodDirectly(_ food: Food) {
        let email = foodManager.userEmail ?? viewModel.email
        guard !email.isEmpty else { return }

        let mealDate = Date()
        let mealLabel = suggestedMealPeriod(for: mealDate).title
        let servings = max(food.numberOfServings ?? 1, 0.0001)

        foodManager.logFood(
            email: email,
            food: food,
            meal: mealLabel,
            servings: servings,
            date: mealDate,
            notes: nil
        ) { result in
            switch result {
            case .success:
                dayLogsVM.loadLogs(for: mealDate, force: true)
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToTimeline"), object: nil)
            case .failure(let error):
                print("Failed to log food: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - User Food Row

struct UserFoodRow: View {
    let food: Food
    var onLogTapped: (() -> Void)?
    var onAddToPlateTapped: (() -> Void)?
    var onViewDetailsTapped: (() -> Void)?

    var body: some View {
        HStack {
            // Food info (tappable area for details)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.displayName)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("\(Int(food.calories ?? 0)) cal")
                    }

                    if let protein = food.protein {
                        Text("P \(Int(protein))g")
                    }
                    if let fat = food.fat {
                        Text("F \(Int(fat))g")
                    }
                    if let carbs = food.carbs {
                        Text("C \(Int(carbs))g")
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Plus button menu
            Menu {
                Button {
                    onLogTapped?()
                } label: {
                    Label("Log", systemImage: "plus.circle")
                }

                Button {
                    onAddToPlateTapped?()
                } label: {
                    Label("Add to Plate", systemImage: "fork.knife")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onViewDetailsTapped?()
        }
    }
}

#Preview {
    NavigationStack {
        FoodsView()
            .environmentObject(FoodManager())
            .environmentObject(OnboardingViewModel())
    }
}
