//
//  NutritionLabelData.swift
//  pods
//
//  Created by Dimi Nunez on 12/15/25.
//


//
//  NutritionLabelData.swift
//  Pods
//
//  Created by Claude on 12/15/25.
//

import Foundation

/// Data structure for nutrition label OCR results
struct NutritionLabelData: Codable, Equatable {
    /// Whether a nutrition label was detected in the image
    var labelDetected: Bool = false

    /// Detected label format
    var format: LabelFormat = .unknown

    // MARK: - Product Info (user-editable)

    /// Product name (user can edit this)
    var name: String = ""

    // MARK: - Serving Info

    /// Serving size as printed on label (e.g., "1 cup (240ml)")
    var servingSize: String?

    /// Number of servings per container
    var servingsPerContainer: Double?

    // MARK: - Core Nutrients (per serving)

    /// Calories per serving
    var calories: Double?

    /// Total fat in grams
    var totalFat: Double?

    /// Saturated fat in grams
    var saturatedFat: Double?

    /// Trans fat in grams
    var transFat: Double?

    /// Cholesterol in milligrams
    var cholesterol: Double?

    /// Sodium in milligrams
    var sodium: Double?

    /// Total carbohydrates in grams
    var totalCarbs: Double?

    /// Dietary fiber in grams
    var dietaryFiber: Double?

    /// Total sugars in grams
    var totalSugars: Double?

    /// Added sugars in grams
    var addedSugars: Double?

    /// Protein in grams
    var protein: Double?

    // MARK: - Micronutrients (optional)

    /// Vitamin D in micrograms
    var vitaminD: Double?

    /// Calcium in milligrams
    var calcium: Double?

    /// Iron in milligrams
    var iron: Double?

    /// Potassium in milligrams
    var potassium: Double?

    // MARK: - B Vitamins

    /// Thiamin (Vitamin B1) in milligrams
    var thiamin: Double?

    /// Riboflavin (Vitamin B2) in milligrams
    var riboflavin: Double?

    /// Niacin (Vitamin B3) in milligrams
    var niacin: Double?

    /// Pantothenic Acid (Vitamin B5) in milligrams
    var pantothenicAcid: Double?

    /// Vitamin B6 in milligrams
    var vitaminB6: Double?

    /// Folate (Vitamin B9) in micrograms
    var folate: Double?

    /// Vitamin B12 in micrograms
    var vitaminB12: Double?

    /// Biotin (Vitamin B7) in micrograms
    var biotin: Double?

    // MARK: - Other Vitamins

    /// Vitamin A in micrograms (RAE) or IU
    var vitaminA: Double?

    /// Vitamin C in milligrams
    var vitaminC: Double?

    /// Vitamin E in milligrams
    var vitaminE: Double?

    /// Vitamin K in micrograms
    var vitaminK: Double?

    // MARK: - Additional Minerals

    /// Magnesium in milligrams
    var magnesium: Double?

    /// Zinc in milligrams
    var zinc: Double?

    /// Phosphorus in milligrams
    var phosphorus: Double?

    // MARK: - Debug Info

    /// Raw OCR text for debugging
    var rawText: String?
}

// MARK: - Label Format

/// Detected nutrition label format
enum LabelFormat: String, Codable {
    /// US FDA Nutrition Facts format
    case usFDA = "us_fda"

    /// European Union format (Energy in kJ/kcal, Salt instead of Sodium)
    case euRegulation = "eu_regulation"

    /// Canadian format (Valeur nutritive / Nutrition Facts bilingual)
    case canadian = "canadian"

    /// Unknown or undetected format
    case unknown = "unknown"
}

// MARK: - Convenience Methods

extension NutritionLabelData {
    /// Returns true if at least one core nutrient was detected
    var hasNutrients: Bool {
        calories != nil || protein != nil || totalCarbs != nil || totalFat != nil
    }

    /// Converts EU salt value to sodium (mg)
    /// Salt (g) × 400 = Sodium (mg)
    static func saltToSodium(saltGrams: Double) -> Double {
        return saltGrams * 400
    }

    /// Converts EU energy in kJ to kcal
    /// kJ ÷ 4.184 = kcal
    static func kjToKcal(kj: Double) -> Double {
        return kj / 4.184
    }
}
