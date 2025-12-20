//
//  NewFoodView.swift
//  pods
//
//  Created by Dimi Nunez on 12/18/25.
//

import SwiftUI

enum NutritionBasis: String, CaseIterable {
    case serving = "Serving"
    case per100g = "100g"
    case per100ml = "100ml"

    var weightLabel: String {
        self == .per100ml ? "Volume" : "Weight"
    }

    var unitSuffix: String {
        self == .per100ml ? "ml" : "g"
    }

    var hasDefaultServingValues: Bool {
        self == .serving
    }
}

struct NewFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismissSearch) private var dismissSearch
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel

    // Basic Info
    @State private var name = ""
    @State private var brand = ""

    // Nutrition Basis
    @State private var basedOn: NutritionBasis = .serving
    @State private var weight = ""
    @State private var servingAmount = "1"
    @State private var servingUnit = "serving"

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
                            Text("Brand")
                            Spacer()
                            TextField("Optional", text: $brand)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    // Nutrition Values Section
                    Section {
                        // Based on row
                        HStack {
                            Text("Based on")
                            Spacer()
                            Menu {
                                ForEach(NutritionBasis.allCases, id: \.self) { basis in
                                    Button(basis.rawValue) {
                                        basedOn = basis
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(basedOn.rawValue)
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

                        // Weight/Volume row
                        HStack {
                            Text(basedOn.weightLabel)
                            Spacer()
                            HStack(spacing: 4) {
                                TextField(basedOn.unitSuffix, text: $weight)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                if !weight.isEmpty {
                                    Text(basedOn.unitSuffix)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Serving Size row with chips
                        HStack {
                            Text("Serving Size")

                            Spacer()

                            HStack(spacing: 6) {
                                TextField("1", text: $servingAmount)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .frame(width: 50)
                                    .background(
                                        Capsule().fill(chipColor)
                                    )
                                    .font(.system(size: 15))
                                    .fixedSize()

                                TextField("serving", text: $servingUnit)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        Capsule().fill(chipColor)
                                    )
                                    .font(.system(size: 15))
                                    .fixedSize()
                            }
                        }
                    } header: {
                        Text("Nutrition Values")
                    }
                }
                .listStyle(.insetGrouped)

                footerBar
            }
            .navigationTitle("Create Food")
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
            .onChange(of: basedOn) { oldValue, newValue in
                // Reset serving values when switching basis
                if newValue.hasDefaultServingValues {
                    servingAmount = "1"
                    servingUnit = "serving"
                } else {
                    servingAmount = ""
                    servingUnit = ""
                }
            }
            .onAppear {
                dismissSearch()
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
                // TODO: Navigate to next step
            }) {
                Text("Continue")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
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
}

#Preview {
    NewFoodView()
        .environmentObject(FoodManager())
        .environmentObject(OnboardingViewModel())
}
