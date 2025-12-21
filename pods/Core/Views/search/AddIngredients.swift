//
//  AddIngredientsView.swift
//  pods
//
//  Created by Dimi Nunez on 12/20/25.
//

import SwiftUI

enum IngredientTab: String, CaseIterable {
    case search = "Search"
    case scan = "Scan"
    case describe = "Describe"
}

struct AddIngredients: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    @ObservedObject private var recentFoodsRepo = RecentFoodLogsRepository.shared

    var onIngredientAdded: (Food) -> Void

    @State private var selectedTab: IngredientTab = .search
    @State private var searchText = ""
    @State private var isSearchFocused = false

    /// Recent food logs from the repository
    private var recentFoodLogs: [CombinedLog] {
        recentFoodsRepo.snapshot.logs
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Picker
                Picker("", selection: $selectedTab) {
                    ForEach(IngredientTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Tab Content
                switch selectedTab {
                case .search:
                    searchTabContent
                case .scan:
                    AddIngredientsScanner(onIngredientAdded: { food in
                        onIngredientAdded(food)
                        // Don't dismiss - let user add more ingredients
                    })
                    .environmentObject(foodManager)
                case .describe:
                    AddIngredientsDescribe(onIngredientAdded: { food in
                        onIngredientAdded(food)
                        // Don't dismiss - let user add more ingredients
                    })
                    .environmentObject(foodManager)
                }
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .task {
                if let email = foodManager.userEmail {
                    recentFoodsRepo.configure(email: email)
                    await recentFoodsRepo.refresh()
                }
            }
        }
    }

    // MARK: - Search Tab Content

    private var searchTabContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !recentFoodLogs.isEmpty {
                    // Recents Header
                    Text("Recents")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    Divider()
                        .padding(.leading, 16)

                    // Recent foods list
                    ForEach(recentFoodLogs) { log in
                        IngredientSearchRow(log: log, onPlusTapped: {
                            if let food = log.food?.asFood {
                                onIngredientAdded(food)
                                dismiss()
                            }
                        })

                        if log.id != recentFoodLogs.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                } else {
                    Text("No recent foods")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 32)
                }
            }
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search foods")
        .onSubmit(of: .search) {
            // Handle search submission - TODO: implement search API call
        }
    }
}

// MARK: - Ingredient Search Row

struct IngredientSearchRow: View {
    let log: CombinedLog
    var onPlusTapped: (() -> Void)?

    private var displayName: String {
        log.food?.displayName ?? log.message
    }

    private var caloriesValue: Int {
        Int(log.displayCalories.rounded())
    }

    private var proteinValue: Int {
        if let food = log.food, let protein = food.protein {
            let servings = food.numberOfServings > 0 ? food.numberOfServings : 1
            return Int((protein * servings).rounded())
        }
        if let protein = log.meal?.protein ?? log.recipe?.protein {
            return Int(protein.rounded())
        }
        return 0
    }

    private var fatValue: Int {
        if let food = log.food, let fat = food.fat {
            let servings = food.numberOfServings > 0 ? food.numberOfServings : 1
            return Int((fat * servings).rounded())
        }
        if let fat = log.meal?.fat ?? log.recipe?.fat {
            return Int(fat.rounded())
        }
        return 0
    }

    private var carbsValue: Int {
        if let food = log.food, let carbs = food.carbs {
            let servings = food.numberOfServings > 0 ? food.numberOfServings : 1
            return Int((carbs * servings).rounded())
        }
        if let carbs = log.meal?.carbs ?? log.recipe?.carbs {
            return Int(carbs.rounded())
        }
        return 0
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // Calories with flame icon
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("\(caloriesValue) cal")
                    }

                    // Macros: P F C
                    macroLabel(prefix: "P", value: proteinValue)
                    macroLabel(prefix: "F", value: fatValue)
                    macroLabel(prefix: "C", value: carbsValue)
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

    private func macroLabel(prefix: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(prefix)
                .foregroundColor(.secondary)
            Text("\(value)g")
        }
    }
}

#Preview {
    AddIngredients(onIngredientAdded: { _ in })
        .environmentObject(FoodManager())
        .environmentObject(OnboardingViewModel())
}
