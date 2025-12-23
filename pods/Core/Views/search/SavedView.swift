//
//  SavedView.swift
//  pods
//
//  Created by Dimi Nunez on 12/23/25.
//

import SwiftUI

struct SavedView: View {
    enum SavedTab: String, CaseIterable {
        case foods = "Foods"
        case recipes = "Recipes"
        case workouts = "Workouts"
    }

    @State private var selectedTab: SavedTab = .foods
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @ObservedObject private var savedFoodsRepo = SavedFoodsRepository.shared
    @State private var selectedFoodForDetails: Food?

    var body: some View {
        List {
            // Segmented control as first section
            Section {
                Picker("", selection: $selectedTab) {
                    ForEach(SavedTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listRowBackground(Color.clear)

            // Content based on selected tab
            switch selectedTab {
            case .foods:
                savedFoodsSection
            case .recipes:
                savedRecipesSection
            case .workouts:
                savedWorkoutsSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedFoodForDetails) { food in
            FoodDetails(food: food)
                .environmentObject(dayLogsVM)
                .environmentObject(foodManager)
        }
        .refreshable {
            await savedFoodsRepo.refresh(force: true)
        }
        .task {
            if let email = foodManager.userEmail {
                savedFoodsRepo.configure(email: email)
                await savedFoodsRepo.refresh()
            }
        }
    }

    // MARK: - Saved Foods Section

    @ViewBuilder
    private var savedFoodsSection: some View {
        if savedFoodsRepo.isRefreshing && savedFoodsRepo.snapshot.savedFoods.isEmpty {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 40)
            }
            .listRowBackground(Color.clear)
        } else if savedFoodsRepo.snapshot.savedFoods.isEmpty {
            Section {
                emptyStateContent(
                    icon: "bookmark",
                    title: "No Saved Foods",
                    message: "Tap the bookmark icon on any food to save it for quick access."
                )
            }
            .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(savedFoodsRepo.snapshot.savedFoods) { savedFood in
                    SavedFoodRow(savedFood: savedFood)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFoodForDetails = savedFood.food
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                unsaveFood(savedFood)
                            } label: {
                                Label("Remove", systemImage: "bookmark.slash")
                            }
                        }
                }
            }
            .listRowBackground(Color("sheetcard"))
        }
    }

    // MARK: - Saved Recipes Section

    @ViewBuilder
    private var savedRecipesSection: some View {
        Section {
            emptyStateContent(
                icon: "fork.knife",
                title: "No Saved Recipes",
                message: "Saved recipes will appear here."
            )
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Saved Workouts Section

    @ViewBuilder
    private var savedWorkoutsSection: some View {
        Section {
            emptyStateContent(
                icon: "dumbbell",
                title: "No Saved Workouts",
                message: "Saved workouts will appear here."
            )
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Helper Views

    private func emptyStateContent(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    private func unsaveFood(_ savedFood: SavedFood) {
        foodManager.unsaveFoodByFoodId(foodId: savedFood.food.fdcId) { result in
            if case .success = result {
                Task {
                    await savedFoodsRepo.refresh(force: true)
                }
            }
        }
    }
}

// MARK: - Saved Food Row

private struct SavedFoodRow: View {
    let savedFood: SavedFood

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(savedFood.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(Int(savedFood.calories)) cal")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if let brand = savedFood.food.brandName, !brand.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(brand)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        SavedView()
            .environmentObject(FoodManager())
            .environmentObject(DayLogsViewModel())
    }
}
