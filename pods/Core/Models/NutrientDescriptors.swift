//
//  NutrientRowDescriptor.swift
//  pods
//
//  Created by Dimi Nunez on 12/21/25.
//


//
//  NutrientDescriptors.swift
//  pods
//
//  Created by Dimi Nunez on 12/21/25.
//

import SwiftUI

// MARK: - Nutrient Row Descriptor

/// Describes a single nutrient row for display in nutrition views
struct NutrientRowDescriptor: Identifiable {
    let id: String
    let label: String
    let slug: String?
    let defaultUnit: String
    let source: NutrientValueSource
    let color: Color

    init(id: String? = nil,
         label: String,
         slug: String?,
         defaultUnit: String,
         source: NutrientValueSource,
         color: Color) {
        self.id = id ?? slug ?? label
        self.label = label
        self.slug = slug
        self.defaultUnit = defaultUnit
        self.source = source
        self.color = color
    }
}

// MARK: - Value Source Types

/// Defines how to retrieve the value for a nutrient
enum NutrientValueSource {
    case macro(NutrientMacroType)
    case nutrient(names: [String], aggregation: NutrientAggregation = .first)
    case computed(NutrientComputation)
}

/// Primary macronutrient types for nutrient descriptors
enum NutrientMacroType {
    case protein
    case carbs
    case fat
}

/// How to aggregate multiple nutrient matches
enum NutrientAggregation {
    case first  // Use first matching nutrient
    case sum    // Sum all matching nutrients (e.g., EPA + DHA)
}

/// Computed nutrient values
enum NutrientComputation {
    case netCarbs   // Carbs - Fiber
    case calories   // Direct calorie value
}

// MARK: - Shared Nutrient Descriptors

/// Complete nutrient descriptor definitions used across all nutrition views
/// Contains 50+ nutrients across 6 categories: carbs, fat, protein, vitamins, minerals, other
enum NutrientDescriptors {
    static let proteinColor = Color("protein")
    static let fatColor = Color("fat")
    static let carbColor = Color("carbs")

    // MARK: - Carbohydrate Section (5 items)
    // Backend sends exact USDA names: "Fiber, total dietary", "Sugars, total including NLEA"

    static var totalCarbRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "Carbs", slug: "carbs", defaultUnit: "g", source: .macro(.carbs), color: carbColor),
            NutrientRowDescriptor(label: "Fiber", slug: "fiber", defaultUnit: "g", source: .nutrient(names: ["Fiber, total dietary", "fiber, total dietary", "dietary fiber", "fiber"]), color: carbColor),
            NutrientRowDescriptor(label: "Net (Non-fiber)", slug: "net_carbs", defaultUnit: "g", source: .computed(.netCarbs), color: carbColor),
            NutrientRowDescriptor(label: "Sugars", slug: "sugars", defaultUnit: "g", source: .nutrient(names: ["Sugars, total including NLEA", "sugars, total including nlea", "sugars, total", "sugar", "sugars"]), color: carbColor),
            NutrientRowDescriptor(label: "Sugars Added", slug: "added_sugars", defaultUnit: "g", source: .nutrient(names: ["Sugars, added", "sugars, added", "added sugars", "added_sugars"]), color: carbColor)
        ]
    }

    // MARK: - Fat Section (9 items)

    static var fatRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "Fat", slug: "fat", defaultUnit: "g", source: .macro(.fat), color: fatColor),
            NutrientRowDescriptor(label: "Monounsaturated", slug: "monounsaturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total monounsaturated", "monounsaturated_fat", "monounsaturated fat"]), color: fatColor),
            NutrientRowDescriptor(label: "Polyunsaturated", slug: "polyunsaturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total polyunsaturated", "polyunsaturated_fat", "polyunsaturated fat"]), color: fatColor),
            NutrientRowDescriptor(label: "Omega-3", slug: "omega_3_total", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total n-3", "omega 3", "omega-3"]), color: fatColor),
            NutrientRowDescriptor(label: "Omega-3 ALA", slug: "omega_3_ala", defaultUnit: "g", source: .nutrient(names: ["18:3 n-3 c,c,c (ala)", "alpha-linolenic acid", "omega-3 ala", "omega 3 ala", "omega_3_ala"]), color: fatColor),
            NutrientRowDescriptor(label: "Omega-3 EPA+DHA", slug: "omega_3_epa_dha", defaultUnit: "mg", source: .nutrient(names: ["20:5 n-3 (epa)", "22:6 n-3 (dha)", "epa", "dha", "eicosapentaenoic acid", "docosahexaenoic acid", "omega-3 epa + dha", "omega_3_dha", "omega_3_epa"], aggregation: .sum), color: fatColor),
            NutrientRowDescriptor(label: "Omega-6", slug: "omega_6", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total n-6", "omega 6", "omega-6"]), color: fatColor),
            NutrientRowDescriptor(label: "Saturated", slug: "saturated_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total saturated", "saturated_fat", "saturated fat"]), color: fatColor),
            NutrientRowDescriptor(label: "Trans Fat", slug: "trans_fat", defaultUnit: "g", source: .nutrient(names: ["fatty acids, total trans", "trans_fat", "trans fat"]), color: fatColor)
        ]
    }

    // MARK: - Protein Section (12 items - all amino acids)

    static var proteinRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "Protein", slug: "protein", defaultUnit: "g", source: .macro(.protein), color: proteinColor),
            NutrientRowDescriptor(label: "Cysteine", slug: "cysteine", defaultUnit: "mg", source: .nutrient(names: ["cysteine", "cystine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Histidine", slug: "histidine", defaultUnit: "mg", source: .nutrient(names: ["histidine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Isoleucine", slug: "isoleucine", defaultUnit: "mg", source: .nutrient(names: ["isoleucine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Leucine", slug: "leucine", defaultUnit: "mg", source: .nutrient(names: ["leucine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Lysine", slug: "lysine", defaultUnit: "mg", source: .nutrient(names: ["lysine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Methionine", slug: "methionine", defaultUnit: "mg", source: .nutrient(names: ["methionine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Phenylalanine", slug: "phenylalanine", defaultUnit: "mg", source: .nutrient(names: ["phenylalanine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Threonine", slug: "threonine", defaultUnit: "mg", source: .nutrient(names: ["threonine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Tryptophan", slug: "tryptophan", defaultUnit: "mg", source: .nutrient(names: ["tryptophan"]), color: proteinColor),
            NutrientRowDescriptor(label: "Tyrosine", slug: "tyrosine", defaultUnit: "mg", source: .nutrient(names: ["tyrosine"]), color: proteinColor),
            NutrientRowDescriptor(label: "Valine", slug: "valine", defaultUnit: "mg", source: .nutrient(names: ["valine"]), color: proteinColor)
        ]
    }

    // MARK: - Vitamin Section (13 items)
    // Backend sends exact USDA names: "Thiamin", "Riboflavin", "Vitamin A, RAE", "Vitamin B-6", etc.

    static var vitaminRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "B1, Thiamine", slug: "vitamin_b1_thiamin", defaultUnit: "mg", source: .nutrient(names: ["Thiamin", "thiamin", "vitamin b-1", "vitamin_b1_thiamin"]), color: .orange),
            NutrientRowDescriptor(label: "B2, Riboflavin", slug: "vitamin_b2_riboflavin", defaultUnit: "mg", source: .nutrient(names: ["Riboflavin", "riboflavin", "vitamin b-2", "vitamin_b2_riboflavin"]), color: .orange),
            NutrientRowDescriptor(label: "B3, Niacin", slug: "vitamin_b3_niacin", defaultUnit: "mg", source: .nutrient(names: ["Niacin", "niacin", "vitamin b-3", "vitamin_b3_niacin"]), color: .orange),
            NutrientRowDescriptor(label: "B6, Pyridoxine", slug: "vitamin_b6_pyridoxine", defaultUnit: "mg", source: .nutrient(names: ["Vitamin B-6", "vitamin b-6", "pyridoxine", "vitamin b6", "vitamin_b6_pyridoxine"]), color: .orange),
            NutrientRowDescriptor(label: "B5, Pantothenic Acid", slug: "vitamin_b5_pantothenic_acid", defaultUnit: "mg", source: .nutrient(names: ["Pantothenic acid", "pantothenic acid", "vitamin_b5_pantothenic_acid"]), color: .orange),
            NutrientRowDescriptor(label: "B12, Cobalamin", slug: "vitamin_b12_cobalamin", defaultUnit: "mcg", source: .nutrient(names: ["Vitamin B-12", "vitamin b-12", "cobalamin", "vitamin_b12_cobalamin"]), color: .orange),
            NutrientRowDescriptor(label: "Biotin", slug: "biotin", defaultUnit: "mcg", source: .nutrient(names: ["Biotin", "biotin"]), color: .orange),
            NutrientRowDescriptor(label: "Folate", slug: "folate", defaultUnit: "mcg", source: .nutrient(names: ["Folate, total", "folate, total", "folic acid", "folate"]), color: .orange),
            NutrientRowDescriptor(label: "Vitamin A", slug: "vitamin_a", defaultUnit: "mcg", source: .nutrient(names: ["Vitamin A, RAE", "vitamin a, rae", "vitamin a", "vitamin_a"]), color: .orange),
            NutrientRowDescriptor(label: "Vitamin C", slug: "vitamin_c", defaultUnit: "mg", source: .nutrient(names: ["Vitamin C, total ascorbic acid", "vitamin c, total ascorbic acid", "vitamin c", "vitamin_c"]), color: .orange),
            NutrientRowDescriptor(label: "Vitamin D", slug: "vitamin_d", defaultUnit: "IU", source: .nutrient(names: ["Vitamin D", "vitamin d (d2 + d3)", "vitamin d", "vitamin_d"]), color: .orange),
            NutrientRowDescriptor(label: "Vitamin E", slug: "vitamin_e", defaultUnit: "mg", source: .nutrient(names: ["Vitamin E (alpha-tocopherol)", "vitamin e (alpha-tocopherol)", "vitamin e", "vitamin_e"]), color: .orange),
            NutrientRowDescriptor(label: "Vitamin K", slug: "vitamin_k", defaultUnit: "mcg", source: .nutrient(names: ["Vitamin K (phylloquinone)", "vitamin k (phylloquinone)", "vitamin k", "vitamin_k"]), color: .orange)
        ]
    }

    // MARK: - Mineral Section (10 items)
    // Backend sends USDA format: "Calcium, Ca", "Sodium, Na", etc.

    static var mineralRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "Calcium", slug: "calcium", defaultUnit: "mg", source: .nutrient(names: ["Calcium, Ca", "calcium, ca", "calcium"]), color: .blue),
            NutrientRowDescriptor(label: "Copper", slug: "copper", defaultUnit: "mcg", source: .nutrient(names: ["Copper, Cu", "copper, cu", "copper"]), color: .blue),
            NutrientRowDescriptor(label: "Iron", slug: "iron", defaultUnit: "mg", source: .nutrient(names: ["Iron, Fe", "iron, fe", "iron"]), color: .blue),
            NutrientRowDescriptor(label: "Magnesium", slug: "magnesium", defaultUnit: "mg", source: .nutrient(names: ["Magnesium, Mg", "magnesium, mg", "magnesium"]), color: .blue),
            NutrientRowDescriptor(label: "Manganese", slug: "manganese", defaultUnit: "mg", source: .nutrient(names: ["Manganese, Mn", "manganese, mn", "manganese"]), color: .blue),
            NutrientRowDescriptor(label: "Phosphorus", slug: "phosphorus", defaultUnit: "mg", source: .nutrient(names: ["Phosphorus, P", "phosphorus, p", "phosphorus"]), color: .blue),
            NutrientRowDescriptor(label: "Potassium", slug: "potassium", defaultUnit: "mg", source: .nutrient(names: ["Potassium, K", "potassium, k", "potassium"]), color: .blue),
            NutrientRowDescriptor(label: "Selenium", slug: "selenium", defaultUnit: "mcg", source: .nutrient(names: ["Selenium, Se", "selenium, se", "selenium"]), color: .blue),
            NutrientRowDescriptor(label: "Sodium", slug: "sodium", defaultUnit: "mg", source: .nutrient(names: ["Sodium, Na", "sodium, na", "sodium"]), color: .blue),
            NutrientRowDescriptor(label: "Zinc", slug: "zinc", defaultUnit: "mg", source: .nutrient(names: ["Zinc, Zn", "zinc, zn", "zinc"]), color: .blue)
        ]
    }

    // MARK: - Other Section (6 items)

    static var otherRows: [NutrientRowDescriptor] {
        [
            NutrientRowDescriptor(label: "Calories", slug: "calories", defaultUnit: "kcal", source: .computed(.calories), color: .purple),
            NutrientRowDescriptor(label: "Alcohol", slug: "alcohol", defaultUnit: "g", source: .nutrient(names: ["alcohol, ethyl", "alcohol"]), color: .purple),
            NutrientRowDescriptor(label: "Caffeine", slug: "caffeine", defaultUnit: "mg", source: .nutrient(names: ["caffeine"]), color: .purple),
            NutrientRowDescriptor(label: "Cholesterol", slug: "cholesterol", defaultUnit: "mg", source: .nutrient(names: ["cholesterol"]), color: .purple),
            NutrientRowDescriptor(label: "Choline", slug: "choline", defaultUnit: "mg", source: .nutrient(names: ["choline, total", "choline"]), color: .purple),
            NutrientRowDescriptor(label: "Water", slug: "water", defaultUnit: "ml", source: .nutrient(names: ["water"]), color: .purple)
        ]
    }
}

// MARK: - Helper Functions

/// Normalizes a nutrient name for case-insensitive matching
func normalizedNutrientKey(_ name: String) -> String {
    var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    cleaned = cleaned.replacingOccurrences(of: "\\([^\\)]*\\)", with: " ", options: .regularExpression)
    let filtered = cleaned.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
    return String(String.UnicodeScalarView(filtered))
}
