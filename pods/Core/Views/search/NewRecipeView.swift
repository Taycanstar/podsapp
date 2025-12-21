//
//  NewRecipeView.swift
//  pods
//
//  Created by Dimi Nunez on 12/18/25.
//

import SwiftUI

struct NewRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    // Basic Info
    @State private var name = ""
    @State private var servings = 1

    // Ingredients
    @State private var ingredients: [Food] = []
    @State private var showAddIngredients = false

    private var chipColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemFill) : Color(.secondarySystemFill)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // Basic Info Section
                    Section {
                        HStack {
                            Text("Name")
                            Spacer()
                            TextField("Required", text: $name)
                                .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Text("Servings")
                            Spacer()
                            HStack(spacing: 12) {
                                Button {
                                    if servings > 1 {
                                        servings -= 1
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(servings > 1 ? .primary : .secondary.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                                .disabled(servings <= 1)

                                Text("\(servings)")
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(minWidth: 30)

                                Button {
                                    if servings < 99 {
                                        servings += 1
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(servings < 99 ? .primary : .secondary.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                                .disabled(servings >= 99)
                            }
                        }
                    }

                    // Ingredients Section
                    Section {
                        if ingredients.isEmpty {
                            Button {
                                showAddIngredients = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.accentColor)
                                    Text("Add Ingredient")
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            ForEach(ingredients, id: \.fdcId) { food in
                                IngredientRow(food: food)
                            }
                            .onDelete(perform: deleteIngredient)

                            Button {
                                showAddIngredients = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.accentColor)
                                    Text("Add Ingredient")
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Ingredients")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .textCase(nil)
                    }
                    .listRowBackground(Color("sheetcard"))
                }
                .listStyle(.insetGrouped)

                footerBar
            }
            .navigationTitle("Create Recipe")
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
            .sheet(isPresented: $showAddIngredients) {
                AddIngredients(onIngredientAdded: { food in
                    ingredients.append(food)
                })
                .environmentObject(foodManager)
                .environmentObject(viewModel)
            }
        }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            Button(action: {
                HapticFeedback.generateLigth()
                // TBD: Next step after Continue
            }) {
                Text("Continue")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color("background"))
            )
            .foregroundColor(Color("text"))
            .disabled(name.isEmpty)
            .opacity(name.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Actions

    private func deleteIngredient(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }
}

// MARK: - Ingredient Row

struct IngredientRow: View {
    let food: Food

    private var caloriesValue: Int {
        Int((food.calories ?? 0).rounded())
    }

    private var proteinValue: Int {
        Int((food.protein ?? 0).rounded())
    }

    private var fatValue: Int {
        Int((food.fat ?? 0).rounded())
    }

    private var carbsValue: Int {
        Int((food.carbs ?? 0).rounded())
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.description)
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
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
    NewRecipeView()
        .environmentObject(FoodManager())
        .environmentObject(OnboardingViewModel())
}
