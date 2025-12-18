//
//  QuickAddSheet.swift
//  pods
//
//  Created by Dimi Nunez on 12/17/25.
//

import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // Form inputs
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""
    @State private var alcohol = ""

    // UI state
    @State private var isLogging = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Input form
                VStack(spacing: 0) {
                    inputRow(label: "Name", text: $name, placeholder: "Optional")
                    Divider().padding(.horizontal, 16)
                    inputRow(label: "Calories", text: $calories, placeholder: "Required", keyboardType: .decimalPad)
                    Divider().padding(.horizontal, 16)
                    inputRow(label: "Protein", text: $protein, placeholder: "0", suffix: "g", keyboardType: .decimalPad)
                    Divider().padding(.horizontal, 16)
                    inputRow(label: "Fat", text: $fat, placeholder: "0", suffix: "g", keyboardType: .decimalPad)
                    Divider().padding(.horizontal, 16)
                    inputRow(label: "Carbs", text: $carbs, placeholder: "0", suffix: "g", keyboardType: .decimalPad)
                    Divider().padding(.horizontal, 16)
                    inputRow(label: "Alcohol", text: $alcohol, placeholder: "0", suffix: "g", keyboardType: .decimalPad)
                }
                .background(Color("iosnp"))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 20)

                Spacer()

                // Footer with two buttons
                footerBar
            }
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }

    // MARK: - Input Row

    private func inputRow(
        label: String,
        text: Binding<String>,
        placeholder: String,
        suffix: String? = nil,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 17))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 4) {
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 17))
                    .foregroundColor(.primary)

                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -16)

            HStack(spacing: 12) {
                // Log Food button
                Button(action: {
                    HapticFeedback.generateLigth()
                    logFood()
                }) {
                    Text(isLogging ? "Logging..." : "Log Food")
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
                .foregroundColor(.accentColor)
                .disabled(calories.isEmpty || isLogging)
                .opacity(calories.isEmpty || isLogging ? 0.5 : 1)

                // Quick Add button
                Button(action: {
                    HapticFeedback.generateLigth()
                    quickAdd()
                }) {
                    Text("Quick Add")
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
                .foregroundColor(.accentColor)
                .disabled(calories.isEmpty)
                .opacity(calories.isEmpty ? 0.5 : 1)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .background(
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Actions

    private func logFood() {
        // TODO: Implement food logging with FoodManager
        isLogging = true
        // For now, just dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLogging = false
            dismiss()
        }
    }

    private func quickAdd() {
        // TODO: Implement quick add to plate
        dismiss()
    }
}

#Preview {
    QuickAddSheet()
}
