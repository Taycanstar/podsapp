import SwiftUI

struct CreateCustomFoodView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var brand: String
    @State private var servingText: String
    @State private var servings: Double
    @State private var servingsInput: String

    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String

    @State private var sugarText: String
    @State private var fiberText: String
    @State private var addedSugarText: String

    @State private var saturatedFatText: String
    @State private var polyFatText: String
    @State private var monoFatText: String
    @State private var transFatText: String
    @State private var omega3Text: String
    @State private var omega6Text: String

    @State private var cysteineText: String
    @State private var histidineText: String
    @State private var isoleucineText: String
    @State private var leucineText: String
    @State private var lysineText: String
    @State private var methionineText: String
    @State private var phenylalanineText: String
    @State private var threonineText: String
    @State private var tryptophanText: String
    @State private var tyrosineText: String
    @State private var valineText: String

    @State private var vitaminAText: String
    @State private var vitaminB1Text: String
    @State private var vitaminB2Text: String
    @State private var vitaminB3Text: String
    @State private var vitaminB5Text: String
    @State private var vitaminB6Text: String
    @State private var vitaminB12Text: String
    @State private var vitaminCText: String
    @State private var vitaminDText: String
    @State private var vitaminEText: String
    @State private var vitaminKText: String
    @State private var biotinText: String
    @State private var folateText: String

    @State private var calciumText: String
    @State private var copperText: String
    @State private var ironText: String
    @State private var magnesiumText: String
    @State private var manganeseText: String
    @State private var phosphorusText: String
    @State private var potassiumText: String
    @State private var sodiumText: String
    @State private var seleniumText: String
    @State private var zincText: String

    @State private var alcoholText: String
    @State private var caffeineText: String
    @State private var cholineText: String
    @State private var cholesterolText: String
    @State private var waterText: String

    private let mealItems: [MealItem]
    private let baseNutrients: [Nutrient]
    private let onSubmit: ((CustomFoodDraft, CustomFoodAction) -> Void)?

    init(draft: CustomFoodDraft, onSubmit: ((CustomFoodDraft, CustomFoodAction) -> Void)? = nil) {
        _name = State(initialValue: draft.name)
        _brand = State(initialValue: draft.brand)
        _servingText = State(initialValue: draft.servingText)
        _servings = State(initialValue: draft.servings)
        _servingsInput = State(initialValue: draft.servings.cleanOneDecimal)

        let nutrientLookup = Dictionary(uniqueKeysWithValues: draft.nutrients.map { (Self.normalizedKey($0.nutrientName), $0.safeValue) })
        func value(_ names: [String]) -> String {
            for name in names {
                let key = Self.normalizedKey(name)
                if let stored = nutrientLookup[key] {
                    return stored.cleanOneDecimal
                }
            }
            return ""
        }

        _caloriesText = State(initialValue: value(["Energy"]))
        _proteinText = State(initialValue: value(["Protein"]))
        _carbsText = State(initialValue: value(["Carbohydrate, by difference"]))
        _fatText = State(initialValue: value(["Total lipid (fat)"]))

        _sugarText = State(initialValue: value(["Sugars, total including NLEA", "Sugars, total"]))
        _fiberText = State(initialValue: value(["Fiber, total dietary", "Dietary fiber"]))
        _addedSugarText = State(initialValue: value(["Sugars, added", "Added sugars"]))

        _saturatedFatText = State(initialValue: value(["Fatty acids, total saturated"]))
        _polyFatText = State(initialValue: value(["Fatty acids, total polyunsaturated"]))
        _monoFatText = State(initialValue: value(["Fatty acids, total monounsaturated"]))
        _transFatText = State(initialValue: value(["Fatty acids, total trans"]))
        _omega3Text = State(initialValue: value(["Fatty acids, total n-3", "Omega 3", "Omega-3"]))
        _omega6Text = State(initialValue: value(["Fatty acids, total n-6", "Omega 6", "Omega-6"]))

        _cysteineText = State(initialValue: value(["Cysteine", "Cystine"]))
        _histidineText = State(initialValue: value(["Histidine"]))
        _isoleucineText = State(initialValue: value(["Isoleucine"]))
        _leucineText = State(initialValue: value(["Leucine"]))
        _lysineText = State(initialValue: value(["Lysine"]))
        _methionineText = State(initialValue: value(["Methionine"]))
        _phenylalanineText = State(initialValue: value(["Phenylalanine"]))
        _threonineText = State(initialValue: value(["Threonine"]))
        _tryptophanText = State(initialValue: value(["Tryptophan"]))
        _tyrosineText = State(initialValue: value(["Tyrosine"]))
        _valineText = State(initialValue: value(["Valine"]))

        _vitaminAText = State(initialValue: value(["Vitamin A, RAE", "Vitamin A"]))
        _vitaminB1Text = State(initialValue: value(["Thiamin", "Vitamin B-1"]))
        _vitaminB2Text = State(initialValue: value(["Riboflavin", "Vitamin B-2"]))
        _vitaminB3Text = State(initialValue: value(["Niacin", "Vitamin B-3"]))
        _vitaminB5Text = State(initialValue: value(["Pantothenic acid"]))
        _vitaminB6Text = State(initialValue: value(["Vitamin B-6", "Pyridoxine"]))
        _vitaminB12Text = State(initialValue: value(["Vitamin B-12", "Cobalamin"]))
        _vitaminCText = State(initialValue: value(["Vitamin C, total ascorbic acid", "Vitamin C"]))
        _vitaminDText = State(initialValue: value(["Vitamin D (D2 + D3)", "Vitamin D"]))
        _vitaminEText = State(initialValue: value(["Vitamin E (alpha-tocopherol)", "Vitamin E"]))
        _vitaminKText = State(initialValue: value(["Vitamin K (phylloquinone)", "Vitamin K"]))
        _biotinText = State(initialValue: value(["Biotin"]))
        _folateText = State(initialValue: value(["Folate, total", "Folic acid"]))

        _calciumText = State(initialValue: value(["Calcium, Ca"]))
        _copperText = State(initialValue: value(["Copper, Cu"]))
        _ironText = State(initialValue: value(["Iron, Fe"]))
        _magnesiumText = State(initialValue: value(["Magnesium, Mg"]))
        _manganeseText = State(initialValue: value(["Manganese, Mn"]))
        _phosphorusText = State(initialValue: value(["Phosphorus, P"]))
        _potassiumText = State(initialValue: value(["Potassium, K"]))
        _sodiumText = State(initialValue: value(["Sodium, Na"]))
        _seleniumText = State(initialValue: value(["Selenium, Se"]))
        _zincText = State(initialValue: value(["Zinc, Zn"]))

        _alcoholText = State(initialValue: value(["Alcohol, ethyl"]))
        _caffeineText = State(initialValue: value(["Caffeine"]))
        _cholineText = State(initialValue: value(["Choline, total"]))
        _cholesterolText = State(initialValue: value(["Cholesterol"]))
        _waterText = State(initialValue: value(["Water"]))

        self.mealItems = draft.mealItems
        self.baseNutrients = draft.nutrients
        self.onSubmit = onSubmit
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        portionCard
                        macroInputsCard
                        additionalCarbsSection
                        additionalFatSection
                        additionalProteinSection
                        vitaminsSection
                        mineralsSection
                        otherNutrientsSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
                footerButton
            }
            .background(Color("iosbg").ignoresSafeArea())
            .navigationTitle("Create Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { submit(action: .createOnly) }
                }
            }
        }
    }

    private var portionCard: some View {
        card {
            VStack(spacing: 12) {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.body)
                Divider()
                TextField("Brand (optional)", text: $brand)
                    .textFieldStyle(.plain)
                Divider()
                labeledRow("Serving Size") {
                    TextField("e.g., 1 cup", text: $servingText)
                        .multilineTextAlignment(.trailing)
                }
                Divider()
                labeledRow("Servings") {
                    TextField("1", text: $servingsInput)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: servingsInput) { updateServings(from: $0) }
                        .onSubmit { updateServings(from: servingsInput) }
                }
            }
        }
    }

    private var macroInputsCard: some View {
        card {
            VStack(spacing: 12) {
                nutrientField(label: "Calories", unit: "kcal", text: $caloriesText)
                Divider()
                nutrientField(label: "Protein", unit: "g", text: $proteinText)
                Divider()
                nutrientField(label: "Carbs", unit: "g", text: $carbsText)
                Divider()
                nutrientField(label: "Fat", unit: "g", text: $fatText)
            }
        }
    }

    private var additionalCarbsSection: some View {
        section(title: "Additional Carbs") {
            VStack(spacing: 12) {
                nutrientField(label: "Fiber", unit: "g", text: $fiberText)
                Divider()
                nutrientValueRow(label: "Net (Non-fiber)", value: netCarbsDisplay, unit: "g")
                Divider()
                nutrientField(label: "Sugars", unit: "g", text: $sugarText)
                Divider()
                nutrientField(label: "Sugars Added", unit: "g", text: $addedSugarText)
            }
        }
    }

    private var additionalFatSection: some View {
        section(title: "Additional Fat") {
            VStack(spacing: 12) {
                nutrientField(label: "Monounsaturated", unit: "g", text: $monoFatText)
                Divider()
                nutrientField(label: "Polyunsaturated", unit: "g", text: $polyFatText)
                Divider()
                nutrientField(label: "Omega-3", unit: "g", text: $omega3Text)
                Divider()
                nutrientField(label: "Omega-6", unit: "g", text: $omega6Text)
                Divider()
                nutrientField(label: "Saturated", unit: "g", text: $saturatedFatText)
                Divider()
                nutrientField(label: "Trans Fat", unit: "g", text: $transFatText)
            }
        }
    }

    private var additionalProteinSection: some View {
        section(title: "Additional Protein") {
            VStack(spacing: 12) {
                nutrientField(label: "Cysteine", unit: "mg", text: $cysteineText)
                Divider()
                nutrientField(label: "Histidine", unit: "mg", text: $histidineText)
                Divider()
                nutrientField(label: "Isoleucine", unit: "mg", text: $isoleucineText)
                Divider()
                nutrientField(label: "Leucine", unit: "mg", text: $leucineText)
                Divider()
                nutrientField(label: "Lysine", unit: "mg", text: $lysineText)
                Divider()
                nutrientField(label: "Methionine", unit: "mg", text: $methionineText)
                Divider()
                nutrientField(label: "Phenylalanine", unit: "mg", text: $phenylalanineText)
                Divider()
                nutrientField(label: "Threonine", unit: "mg", text: $threonineText)
                Divider()
                nutrientField(label: "Tryptophan", unit: "mg", text: $tryptophanText)
                Divider()
                nutrientField(label: "Tyrosine", unit: "mg", text: $tyrosineText)
                Divider()
                nutrientField(label: "Valine", unit: "mg", text: $valineText)
            }
        }
    }

    private var vitaminsSection: some View {
        section(title: "Vitamins") {
            VStack(spacing: 12) {
                nutrientField(label: "Vitamin A", unit: "mcg", text: $vitaminAText)
                Divider()
                nutrientField(label: "B1, Thiamine", unit: "mg", text: $vitaminB1Text)
                Divider()
                nutrientField(label: "B2, Riboflavin", unit: "mg", text: $vitaminB2Text)
                Divider()
                nutrientField(label: "B3, Niacin", unit: "mg", text: $vitaminB3Text)
                Divider()
                nutrientField(label: "B5, Pantothenic Acid", unit: "mg", text: $vitaminB5Text)
                Divider()
                nutrientField(label: "B6, Pyridoxine", unit: "mg", text: $vitaminB6Text)
                Divider()
                nutrientField(label: "B12, Cobalamin", unit: "mcg", text: $vitaminB12Text)
                Divider()
                nutrientField(label: "Vitamin C", unit: "mg", text: $vitaminCText)
                Divider()
                nutrientField(label: "Vitamin D", unit: "IU", text: $vitaminDText)
                Divider()
                nutrientField(label: "Vitamin E", unit: "mg", text: $vitaminEText)
                Divider()
                nutrientField(label: "Vitamin K", unit: "mcg", text: $vitaminKText)
                Divider()
                nutrientField(label: "Biotin", unit: "mcg", text: $biotinText)
                Divider()
                nutrientField(label: "Folate", unit: "mcg", text: $folateText)
            }
        }
    }

    private var mineralsSection: some View {
        section(title: "Minerals") {
            VStack(spacing: 12) {
                nutrientField(label: "Calcium", unit: "mg", text: $calciumText)
                Divider()
                nutrientField(label: "Copper", unit: "mcg", text: $copperText)
                Divider()
                nutrientField(label: "Iron", unit: "mg", text: $ironText)
                Divider()
                nutrientField(label: "Magnesium", unit: "mg", text: $magnesiumText)
                Divider()
                nutrientField(label: "Manganese", unit: "mg", text: $manganeseText)
                Divider()
                nutrientField(label: "Phosphorus", unit: "mg", text: $phosphorusText)
                Divider()
                nutrientField(label: "Potassium", unit: "mg", text: $potassiumText)
                Divider()
                nutrientField(label: "Selenium", unit: "mcg", text: $seleniumText)
                Divider()
                nutrientField(label: "Sodium", unit: "mg", text: $sodiumText)
                Divider()
                nutrientField(label: "Zinc", unit: "mg", text: $zincText)
            }
        }
    }

    private var otherNutrientsSection: some View {
        section(title: "Other") {
            VStack(spacing: 12) {
                nutrientField(label: "Cholesterol", unit: "mg", text: $cholesterolText)
                Divider()
                nutrientField(label: "Alcohol", unit: "g", text: $alcoholText)
                Divider()
                nutrientField(label: "Caffeine", unit: "mg", text: $caffeineText)
                Divider()
                nutrientField(label: "Choline", unit: "mg", text: $cholineText)
                Divider()
                nutrientField(label: "Water", unit: "ml", text: $waterText)
            }
        }
    }

    private var footerButton: some View {
        VStack(spacing: 16) {
            Divider()
            Button(action: { submit(action: .createAndAdd) }) {
                Text("Create and Add")
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
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color("iosbg").ignoresSafeArea(edges: .bottom))
    }

    private func card<T: View>(@ViewBuilder content: () -> T) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color("iosnp")))
    }

    private func section<T: View>(title: String, @ViewBuilder content: () -> T) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            card { content() }
        }
    }

    private func labeledRow(_ title: String, content: () -> some View) -> some View {
        HStack {
            Text(title)
            Spacer()
            content()
                .foregroundColor(.primary)
        }
    }

    private func nutrientField(label: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 80)
            Text(unit)
                .foregroundColor(.secondary)
        }
    }

    private func nutrientValueRow(label: String, value: String, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text((value.isEmpty ? "0" : value))
                .fontWeight(.medium)
            Text(unit)
                .foregroundColor(.secondary)
        }
    }

    private var netCarbsDisplay: String {
        let total = parsedValue(carbsText) ?? 0
        let fiberValue = parsedValue(fiberText) ?? 0
        let net = max(total - fiberValue, 0)
        return net.cleanOneDecimal
    }

    private func updateServings(from input: String) {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(normalized), value > 0 else { return }
        servings = value
    }

    private func parsedValue(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized)
    }

    private static func normalizedKey(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func submit(action: CustomFoodAction) {
        var updated = Dictionary(uniqueKeysWithValues: baseNutrients.map { ($0.nutrientName, $0) })
        var normalized = Dictionary(uniqueKeysWithValues: baseNutrients.map { (Self.normalizedKey($0.nutrientName), $0.nutrientName) })

        func assign(_ names: [String], text: String, unit: String) {
            guard let value = parsedValue(text) else { return }
            if let existing = names.map(Self.normalizedKey).compactMap({ normalized[$0] }).first {
                updated[existing] = Nutrient(nutrientName: existing, value: value, unitName: unit)
                return
            }
            if let preferred = names.first {
                let key = Self.normalizedKey(preferred)
                normalized[key] = preferred
                updated[preferred] = Nutrient(nutrientName: preferred, value: value, unitName: unit)
            }
        }

        assign(["Energy"], text: caloriesText, unit: "kcal")
        assign(["Protein"], text: proteinText, unit: "g")
        assign(["Carbohydrate, by difference"], text: carbsText, unit: "g")
        assign(["Total lipid (fat)"], text: fatText, unit: "g")

        assign(["Fiber, total dietary", "Dietary fiber"], text: fiberText, unit: "g")
        assign(["Sugars, total including NLEA", "Sugars, total"], text: sugarText, unit: "g")
        assign(["Sugars, added", "Added sugars"], text: addedSugarText, unit: "g")

        assign(["Fatty acids, total monounsaturated"], text: monoFatText, unit: "g")
        assign(["Fatty acids, total polyunsaturated"], text: polyFatText, unit: "g")
        assign(["Fatty acids, total n-3", "Omega 3", "Omega-3"], text: omega3Text, unit: "g")
        assign(["Fatty acids, total n-6", "Omega 6", "Omega-6"], text: omega6Text, unit: "g")
        assign(["Fatty acids, total saturated"], text: saturatedFatText, unit: "g")
        assign(["Fatty acids, total trans"], text: transFatText, unit: "g")

        assign(["Cysteine", "Cystine"], text: cysteineText, unit: "mg")
        assign(["Histidine"], text: histidineText, unit: "mg")
        assign(["Isoleucine"], text: isoleucineText, unit: "mg")
        assign(["Leucine"], text: leucineText, unit: "mg")
        assign(["Lysine"], text: lysineText, unit: "mg")
        assign(["Methionine"], text: methionineText, unit: "mg")
        assign(["Phenylalanine"], text: phenylalanineText, unit: "mg")
        assign(["Threonine"], text: threonineText, unit: "mg")
        assign(["Tryptophan"], text: tryptophanText, unit: "mg")
        assign(["Tyrosine"], text: tyrosineText, unit: "mg")
        assign(["Valine"], text: valineText, unit: "mg")

        assign(["Vitamin A, RAE", "Vitamin A"], text: vitaminAText, unit: "mcg")
        assign(["Thiamin", "Vitamin B-1"], text: vitaminB1Text, unit: "mg")
        assign(["Riboflavin", "Vitamin B-2"], text: vitaminB2Text, unit: "mg")
        assign(["Niacin", "Vitamin B-3"], text: vitaminB3Text, unit: "mg")
        assign(["Pantothenic acid"], text: vitaminB5Text, unit: "mg")
        assign(["Vitamin B-6", "Pyridoxine"], text: vitaminB6Text, unit: "mg")
        assign(["Vitamin B-12", "Cobalamin"], text: vitaminB12Text, unit: "mcg")
        assign(["Vitamin C, total ascorbic acid", "Vitamin C"], text: vitaminCText, unit: "mg")
        assign(["Vitamin D (D2 + D3)", "Vitamin D"], text: vitaminDText, unit: "IU")
        assign(["Vitamin E (alpha-tocopherol)", "Vitamin E"], text: vitaminEText, unit: "mg")
        assign(["Vitamin K (phylloquinone)", "Vitamin K"], text: vitaminKText, unit: "mcg")
        assign(["Biotin"], text: biotinText, unit: "mcg")
        assign(["Folate, total", "Folic acid"], text: folateText, unit: "mcg")

        assign(["Calcium, Ca"], text: calciumText, unit: "mg")
        assign(["Copper, Cu"], text: copperText, unit: "mcg")
        assign(["Iron, Fe"], text: ironText, unit: "mg")
        assign(["Magnesium, Mg"], text: magnesiumText, unit: "mg")
        assign(["Manganese, Mn"], text: manganeseText, unit: "mg")
        assign(["Phosphorus, P"], text: phosphorusText, unit: "mg")
        assign(["Potassium, K"], text: potassiumText, unit: "mg")
        assign(["Sodium, Na"], text: sodiumText, unit: "mg")
        assign(["Selenium, Se"], text: seleniumText, unit: "mcg")
        assign(["Zinc, Zn"], text: zincText, unit: "mg")

        assign(["Cholesterol"], text: cholesterolText, unit: "mg")
        assign(["Alcohol, ethyl"], text: alcoholText, unit: "g")
        assign(["Caffeine"], text: caffeineText, unit: "mg")
        assign(["Choline, total"], text: cholineText, unit: "mg")
        assign(["Water"], text: waterText, unit: "ml")

        let draft = CustomFoodDraft(
            name: name,
            brand: brand,
            servingText: servingText,
            servings: servings,
            mealItems: mealItems,
            nutrients: Array(updated.values)
        )

        onSubmit?(draft, action)
        dismiss()
    }
}
