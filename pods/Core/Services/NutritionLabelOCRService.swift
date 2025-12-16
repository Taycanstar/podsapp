//
//  NutritionLabelOCRService.swift
//  pods
//
//  Created by Dimi Nunez on 12/15/25.
//


//
//  NutritionLabelOCRService.swift
//  Pods
//
//  Created by Claude on 12/15/25.
//

import Foundation
import Vision
import UIKit

/// On-device OCR service for nutrition label scanning using Apple Vision framework
/// Target: ~300ms total processing time (10x faster than cloud-based GPT approach)
final class NutritionLabelOCRService {

    // MARK: - Singleton

    static let shared = NutritionLabelOCRService()

    private init() {}

    // MARK: - Regex Patterns

    /// US FDA Nutrition Facts patterns
    private enum USPatterns {
        static let nutritionFactsHeader = #"(?i)nutrition\s*facts"#
        static let supplementFactsHeader = #"(?i)supplement\s*facts"#
        static let servingSize = #"(?i)serving\s*size[:\s]*(.+?)(?=\n|servings|calories|amount)"#
        static let servingsPerContainer = #"(?i)(?:servings?\s*per\s*container|about)\s*:?\s*(\d+\.?\d*)"#
        static let calories = #"(?i)calories[:\s]*(\d+)"#
        static let totalFat = #"(?i)total\s*fat[:\s]*(\d+\.?\d*)\s*g"#
        static let saturatedFat = #"(?i)saturated\s*fat[:\s]*(\d+\.?\d*)\s*g"#
        static let transFat = #"(?i)trans\s*fat[:\s]*(\d+\.?\d*)\s*g"#
        static let cholesterol = #"(?i)cholesterol[:\s]*(\d+\.?\d*)\s*mg"#
        static let sodium = #"(?i)sodium[:\s]*(\d+\.?\d*)\s*mg"#
        static let totalCarbs = #"(?i)total\s*carb(?:ohydrate)?s?[:\s]*(\d+\.?\d*)\s*g"#
        static let dietaryFiber = #"(?i)(?:dietary\s*)?fiber[:\s]*(\d+\.?\d*)\s*g"#
        static let totalSugars = #"(?i)(?:total\s*)?sugars?[:\s]*(\d+\.?\d*)\s*g"#
        static let addedSugars = #"(?i)(?:includes?\s*)?added\s*sugars?[:\s]*(\d+\.?\d*)\s*g"#
        static let protein = #"(?i)protein[:\s]*(\d+\.?\d*)\s*g"#
        static let vitaminD = #"(?i)vitamin\s*d[:\s]*(\d+\.?\d*)\s*(?:mcg|µg)"#
        static let calcium = #"(?i)calcium[:\s]*(\d+\.?\d*)\s*mg"#
        static let iron = #"(?i)iron[:\s]*(\d+\.?\d*)\s*mg"#
        static let potassium = #"(?i)potassium[:\s]*(\d+\.?\d*)\s*mg"#
    }

    /// EU/International patterns
    private enum EUPatterns {
        // Headers
        static let nutritionHeader = #"(?i)(valeur|valeurs?)\s*nutritive|nutrition(al)?\s*(information|declaration)|n[äa]hrwert"#
        static let informacionNutricional = #"(?i)informaci[óo]n\s*nutricional"#

        // Energy (EU uses kJ and kcal)
        static let energyKcal = #"(?i)energ(?:y|ie|[íi]a)[:\s]*(\d+)\s*kcal"#
        static let energyKj = #"(?i)energ(?:y|ie|[íi]a)[:\s]*(\d+)\s*kj"#

        // Salt (EU shows Salt instead of Sodium)
        static let salt = #"(?i)(?:sel|salt|sale|salz)[:\s]*(\d+\.?\d*)\s*g"#

        // Multilingual nutrient names
        static let fatEU = #"(?i)(?:lipides?|mati[èe]res?\s*grasses?|fett|fat|grasas?|grassi)[:\s]*(\d+\.?\d*)\s*g"#
        static let saturatedFatEU = #"(?i)(?:acides?\s*gras\s*satur[ée]s?|ges[äa]ttigte|saturated|saturados?|saturi)[:\s]*(\d+\.?\d*)\s*g"#
        static let carbsEU = #"(?i)(?:glucides?|hydrates?\s*de\s*carbone|kohlenhydrate?|carbohydrate?s?|carbohidratos?|carboidrati)[:\s]*(\d+\.?\d*)\s*g"#
        static let sugarsEU = #"(?i)(?:sucres?|zucker|sugars?|az[úu]cares?|zuccheri|dont\s*sucres)[:\s]*(\d+\.?\d*)\s*g"#
        static let fiberEU = #"(?i)(?:fibres?|ballaststoffe?|fiber|fibra)[:\s]*(\d+\.?\d*)\s*g"#
        static let proteinEU = #"(?i)(?:prot[ée]ines?|protein|eiwei[ßs]|prote[íi]nas?)[:\s]*(\d+\.?\d*)\s*g"#

        // Serving size (multilingual)
        static let servingSizeEU = #"(?i)(?:pour|per|par|pro|porci[óo]n)[:\s]*(.+?)(?=\n|teneur|energie|energy|valeur)"#
        static let portion = #"(?i)(?:portion|porzione|razione)[:\s]*(.+?)(?=\n|energie|energy)"#
    }

    /// Canadian bilingual patterns
    private enum CanadianPatterns {
        static let valeurNutritive = #"(?i)valeur\s*nutritive"#
        static let servingSizeCA = #"(?i)(?:pour|per|portion\s*de?)[:\s]*(.+?)(?=\n|teneur|amount|calories)"#
    }

    // MARK: - Public API

    /// Extracts nutrition data from an image using on-device Vision OCR
    /// - Parameter image: The captured image containing a nutrition label
    /// - Returns: Parsed nutrition label data
    func extractNutrition(from image: UIImage) async -> NutritionLabelData {
        guard let cgImage = image.cgImage else {
            print("🏷️ [OCR] Failed to get CGImage from UIImage")
            return NutritionLabelData()
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. Extract text using Vision
        let text = await extractText(from: cgImage)
        let ocrTime = CFAbsoluteTimeGetCurrent()
        print("🏷️ [OCR] Text extraction: \(Int((ocrTime - startTime) * 1000))ms")

        guard !text.isEmpty else {
            print("🏷️ [OCR] No text detected in image")
            return NutritionLabelData()
        }

        // 2. Detect label format
        let format = detectFormat(text)
        print("🏷️ [OCR] Detected format: \(format.rawValue)")

        // 3. Parse nutrients based on format
        var data = parseNutrients(text, format: format)
        data.format = format
        data.rawText = text
        data.labelDetected = data.hasNutrients

        let totalTime = CFAbsoluteTimeGetCurrent()
        print("🏷️ [OCR] Total processing: \(Int((totalTime - startTime) * 1000))ms")
        print("🏷️ [OCR] Detected: cal=\(data.calories ?? 0), protein=\(data.protein ?? 0), carbs=\(data.totalCarbs ?? 0), fat=\(data.totalFat ?? 0)")

        return data
    }

    // MARK: - Vision OCR

    /// Extracts text from image using Vision framework
    private func extractText(from cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("🏷️ [OCR] Vision error: \(error.localizedDescription)")
                    continuation.resume(returning: "")
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                // Combine all recognized text
                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            // Configure for accuracy over speed
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "en-GB", "fr-FR", "de-DE", "es-ES", "it-IT", "fr-CA"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("🏷️ [OCR] Handler error: \(error.localizedDescription)")
                continuation.resume(returning: "")
            }
        }
    }

    // MARK: - Format Detection

    /// Detects the nutrition label format based on header text
    private func detectFormat(_ text: String) -> LabelFormat {
        // Check for US FDA format
        if text.range(of: USPatterns.nutritionFactsHeader, options: .regularExpression) != nil ||
           text.range(of: USPatterns.supplementFactsHeader, options: .regularExpression) != nil {
            return .usFDA
        }

        // Check for Canadian bilingual format
        if text.range(of: CanadianPatterns.valeurNutritive, options: .regularExpression) != nil &&
           text.range(of: USPatterns.nutritionFactsHeader, options: .regularExpression) != nil {
            return .canadian
        }

        // Check for EU format
        if text.range(of: EUPatterns.nutritionHeader, options: .regularExpression) != nil ||
           text.range(of: EUPatterns.informacionNutricional, options: .regularExpression) != nil {
            return .euRegulation
        }

        // Check for energy in kJ (strong EU indicator)
        if text.range(of: EUPatterns.energyKj, options: .regularExpression) != nil {
            return .euRegulation
        }

        // Check for salt instead of sodium (EU indicator)
        if text.range(of: EUPatterns.salt, options: .regularExpression) != nil &&
           text.range(of: USPatterns.sodium, options: .regularExpression) == nil {
            return .euRegulation
        }

        return .unknown
    }

    // MARK: - Nutrient Parsing

    /// Parses nutrients from OCR text based on detected format
    private func parseNutrients(_ text: String, format: LabelFormat) -> NutritionLabelData {
        var data = NutritionLabelData()

        switch format {
        case .usFDA, .canadian, .unknown:
            parseUSFormat(text, into: &data)
        case .euRegulation:
            parseEUFormat(text, into: &data)
        }

        // Try EU patterns as fallback for unknown format
        if format == .unknown && !data.hasNutrients {
            parseEUFormat(text, into: &data)
        }

        return data
    }

    /// Parses US FDA format nutrition label
    private func parseUSFormat(_ text: String, into data: inout NutritionLabelData) {
        data.servingSize = extractString(from: text, pattern: USPatterns.servingSize)
        data.servingsPerContainer = extractNumber(from: text, pattern: USPatterns.servingsPerContainer)
        data.calories = extractNumber(from: text, pattern: USPatterns.calories)
        data.totalFat = extractNumber(from: text, pattern: USPatterns.totalFat)
        data.saturatedFat = extractNumber(from: text, pattern: USPatterns.saturatedFat)
        data.transFat = extractNumber(from: text, pattern: USPatterns.transFat)
        data.cholesterol = extractNumber(from: text, pattern: USPatterns.cholesterol)
        data.sodium = extractNumber(from: text, pattern: USPatterns.sodium)
        data.totalCarbs = extractNumber(from: text, pattern: USPatterns.totalCarbs)
        data.dietaryFiber = extractNumber(from: text, pattern: USPatterns.dietaryFiber)
        data.totalSugars = extractNumber(from: text, pattern: USPatterns.totalSugars)
        data.addedSugars = extractNumber(from: text, pattern: USPatterns.addedSugars)
        data.protein = extractNumber(from: text, pattern: USPatterns.protein)

        // Micronutrients
        data.vitaminD = extractNumber(from: text, pattern: USPatterns.vitaminD)
        data.calcium = extractNumber(from: text, pattern: USPatterns.calcium)
        data.iron = extractNumber(from: text, pattern: USPatterns.iron)
        data.potassium = extractNumber(from: text, pattern: USPatterns.potassium)
    }

    /// Parses EU format nutrition label
    private func parseEUFormat(_ text: String, into data: inout NutritionLabelData) {
        // Serving size
        data.servingSize = extractString(from: text, pattern: EUPatterns.servingSizeEU)
            ?? extractString(from: text, pattern: EUPatterns.portion)

        // Energy - prefer kcal, fall back to kJ conversion
        if let kcal = extractNumber(from: text, pattern: EUPatterns.energyKcal) {
            data.calories = kcal
        } else if let kj = extractNumber(from: text, pattern: EUPatterns.energyKj) {
            data.calories = NutritionLabelData.kjToKcal(kj: kj)
        }

        // Fat
        data.totalFat = extractNumber(from: text, pattern: EUPatterns.fatEU)
        data.saturatedFat = extractNumber(from: text, pattern: EUPatterns.saturatedFatEU)

        // Carbs
        data.totalCarbs = extractNumber(from: text, pattern: EUPatterns.carbsEU)
        data.totalSugars = extractNumber(from: text, pattern: EUPatterns.sugarsEU)
        data.dietaryFiber = extractNumber(from: text, pattern: EUPatterns.fiberEU)

        // Protein
        data.protein = extractNumber(from: text, pattern: EUPatterns.proteinEU)

        // Salt → Sodium conversion (EU uses salt, US uses sodium)
        if let salt = extractNumber(from: text, pattern: EUPatterns.salt) {
            data.sodium = NutritionLabelData.saltToSodium(saltGrams: salt)
        }

        // Try US patterns for missing values (some products have both)
        if data.sodium == nil {
            data.sodium = extractNumber(from: text, pattern: USPatterns.sodium)
        }
        if data.cholesterol == nil {
            data.cholesterol = extractNumber(from: text, pattern: USPatterns.cholesterol)
        }
    }

    // MARK: - Regex Helpers

    /// Extracts a numeric value from text using regex
    private func extractNumber(from text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let valueString = String(text[valueRange])
            .replacingOccurrences(of: ",", with: ".")  // Handle European decimal notation
            .trimmingCharacters(in: .whitespaces)

        return Double(valueString)
    }

    /// Extracts a string value from text using regex
    private func extractString(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[valueRange]).trimmingCharacters(in: .whitespaces)
    }
}
