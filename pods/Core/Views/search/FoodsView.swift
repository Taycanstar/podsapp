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
    @ObservedObject private var userFoodsRepo = UserFoodsRepository.shared

    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var showQuickAddSheet = false
    @State private var showNewFoodSheet = false
    @State private var selectedFood: Food?
    @State private var createdFoodToAdd: Food?

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
        ScrollView {
            VStack(spacing: 16) {
                // Action Buttons
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
                .padding(.horizontal)

                // User Foods List
                if filteredFoods.isEmpty {
                    // Empty state
                    VStack(spacing: 8) {
                        Text("No foods yet")
                            .font(.headline)
                        Text("Create your first food to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredFoods) { food in
                            UserFoodRow(food: food, onPlusTapped: {
                                closeSearchIfNeeded()
                                selectedFood = food
                            })
                            if food.id != filteredFoods.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .padding(.top, 16)
        }
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
                    // Close the sheet first, then show FoodSummaryView
                    showNewFoodSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        createdFoodToAdd = food
                    }
                }
            )
            .environmentObject(foodManager)
            .environmentObject(viewModel)
        }
        .sheet(item: $selectedFood) { food in
            FoodSummaryView(food: food)
                .environmentObject(foodManager)
        }
        .sheet(item: $createdFoodToAdd) { food in
            FoodSummaryView(food: food)
                .environmentObject(foodManager)
        }
        .task {
            await userFoodsRepo.refresh()
        }
    }
}

// MARK: - User Food Row

struct UserFoodRow: View {
    let food: Food
    var onPlusTapped: (() -> Void)?

    var body: some View {
        HStack {
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

            Spacer()

            // Plus button
            Button {
                onPlusTapped?()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        FoodsView()
            .environmentObject(FoodManager())
            .environmentObject(OnboardingViewModel())
    }
}
