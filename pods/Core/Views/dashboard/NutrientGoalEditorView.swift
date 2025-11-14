//
//  NutrientGoalEditorView.swift
//  Pods
//

import SwiftUI

private struct NutrientItem: Identifiable {
    let slug: String
    let details: NutrientTargetDetails

    var id: String { slug }
}

struct NutrientGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let userEmail: String
    let goals: NutritionGoals
    var onUpdated: (NutritionGoals) -> Void

    @State private var editingValues: [String: String]
    @State private var removedOverrides: Set<String> = []
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showResetConfirmation = false

    init(userEmail: String, goals: NutritionGoals, onUpdated: @escaping (NutritionGoals) -> Void) {
        self.userEmail = userEmail
        self.goals = goals
        self.onUpdated = onUpdated
        let initial = goals.overrides?.reduce(into: [String: String]()) { result, element in
            if let target = element.value.target {
                result[element.key] = Self.formatValue(target)
            }
        } ?? [:]
        _editingValues = State(initialValue: initial)
    }

    var body: some View {
        Group {
            if groupedNutrients.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "leaf.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No nutrient targets available yet.")
                        .font(.headline)
                    Text("Complete your plan to unlock advanced target editing.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                List {
                    ForEach(groupedNutrients, id: \.key) { group in
                        Section(header: Text(group.label)) {
                            ForEach(group.rows) { item in
                                nutrientRow(for: item)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Advanced Targets")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Reset All") {
                    showResetConfirmation = true
                }
                .disabled(isSaving || groupedNutrients.isEmpty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { saveOverrides() }) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSaving || groupedNutrients.isEmpty)
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Unable to Save"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog("Reset all overrides and return to defaults?", isPresented: $showResetConfirmation) {
            Button("Reset Targets", role: .destructive) {
                saveOverrides(clearAll: true)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var groupedNutrients: [(key: String, label: String, rows: [NutrientItem]) ] {
        guard let nutrientDict = goals.nutrients else { return [] }
        let items = nutrientDict.map { NutrientItem(slug: $0.key, details: $0.value) }
        let sortedItems = items.sorted {
            let lhsOrder = $0.details.displayOrder ?? Int.max
            let rhsOrder = $1.details.displayOrder ?? Int.max
            if lhsOrder == rhsOrder {
                return $0.slug < $1.slug
            }
            return lhsOrder < rhsOrder
        }
        let grouped = Dictionary(grouping: sortedItems) { $0.details.category ?? "other" }
        let categoryOrder = ["macros", "carbohydrates", "fats", "amino_acids", "vitamins", "minerals", "hydration", "lifestyle", "other"]
        return grouped
            .map { key, rows -> (String, String, [NutrientItem]) in
                let label = rows.first?.details.categoryLabel ?? key.replacingOccurrences(of: "_", with: " ").capitalized
                return (key, label, rows)
            }
            .sorted { lhs, rhs in
                let lhsIndex = categoryOrder.firstIndex(of: lhs.0) ?? categoryOrder.count
                let rhsIndex = categoryOrder.firstIndex(of: rhs.0) ?? categoryOrder.count
                if lhsIndex == rhsIndex {
                    return lhs.2.first?.details.displayOrder ?? 0 < rhs.2.first?.details.displayOrder ?? 0
                }
                return lhsIndex < rhsIndex
            }
    }

    private func nutrientRow(for item: NutrientItem) -> some View {
        let binding = Binding<String>(
            get: { editingValues[item.slug] ?? "" },
            set: { newValue in
                editingValues[item.slug] = newValue
                if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    removedOverrides.insert(item.slug)
                } else {
                    removedOverrides.remove(item.slug)
                }
            }
        )

        let hasOverride = !(binding.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty) || goals.overrides?[item.slug]?.target != nil
        let subtitle = defaultSubtitle(for: item.details)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.details.label ?? item.slug.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.headline)
                        if hasOverride {
                            Text("Custom")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("Reset") {
                    editingValues[item.slug] = ""
                    removedOverrides.insert(item.slug)
                }
                .font(.subheadline)
                .disabled(!hasOverride && removedOverrides.contains(item.slug) == false)
            }

            HStack {
                TextField("Target", text: binding)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                Text(item.details.unit ?? "")
                    .foregroundColor(.secondary)
            }

            if let note = item.details.note {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func defaultSubtitle(for details: NutrientTargetDetails) -> String? {
        guard let defaultTarget = details.defaultTarget else { return nil }
        var components: [String] = []
        components.append("Default \(Self.formatValue(defaultTarget)) \(details.unit ?? "")")
        if let min = details.min {
            components.append("Min \(Self.formatValue(min))")
        }
        if let max = details.max {
            components.append("Max \(Self.formatValue(max))")
        }
        return components.joined(separator: " • ")
    }

    private func saveOverrides(clearAll: Bool = false) {
        do {
            let overridesPayload = clearAll ? [:] : try buildOverridePayloads()
            let removals = clearAll ? [] : Array(removedOverrides)
            isSaving = true

            NetworkManagerTwo.shared.updateNutritionGoals(
                userEmail: userEmail,
                overrides: overridesPayload,
                removeOverrides: removals,
                clearAll: clearAll
            ) { result in
                isSaving = false
                switch result {
                case .success(let response):
                    editingValues = [:]
                    removedOverrides.removeAll()
                    onUpdated(response.goals)
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } catch let validationError as ValidationError {
            errorMessage = validationError.message
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func buildOverridePayloads() throws -> [String: GoalOverridePayload] {
        var payloads: [String: GoalOverridePayload] = [:]
        for (slug, value) in editingValues {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let number = Double(trimmed) else {
                throw ValidationError.invalidNumber(label: slug)
            }
            payloads[slug] = GoalOverridePayload(min: nil, target: number, max: nil)
        }
        return payloads
    }

    private enum ValidationError: Error {
        case invalidNumber(label: String)

        var message: String {
            switch self {
            case .invalidNumber(let label):
                return "Invalid value for \(label.replacingOccurrences(of: "_", with: " ")). Please enter a number."
            }
        }
    }

    private static func formatValue(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.01 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}
