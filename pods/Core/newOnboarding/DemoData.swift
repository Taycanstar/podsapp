//
//  DemoScript.swift
//  pods
//
//  Created by Dimi Nunez on 12/27/25.
//


//
//  DemoData.swift
//  pods
//
//  Demo constants for the onboarding demo flow.
//  Contains pre-written copy, mock food data, and timing configurations.
//

import Foundation

// MARK: - Demo Script Constants

enum DemoScript {
    // User message (typed character by character)
    static let userFoodMessage = "just had a chicken bowl from chipotle"

    // Coach responses (appear sequentially)
    static let coachResponses: [String] = [
        "Logged. 680 cal, 48g protein. You're at 1,850 cal today (target: 2,400).",
        "Noticed something: protein's been under 100g for 3 days. Want a high-protein dinner idea to close the gap?"
    ]

    // User follow-up response (typed character by character)
    static let userFollowUpMessage = "yeah that would help"

    // Coach final suggestion
    static let coachFinalResponse = "Grilled salmon + veggies would add 45g protein and keep you at target. Want me to log it as a plan?"

    // Food search query (kept for compatibility)
    static let foodSearchQuery = "chipotle chicken bowl"

    // Post-log coach message (shown on timeline)
    static let postLogCoachMessage = """
Today: 1,850 / 2,400 cal · 48g / 150g protein

Pattern: Protein under target for 3 consecutive days.

Suggestion: High-protein dinner (salmon + veggies) to close the gap.
"""
}

// MARK: - Demo Food Data

enum DemoFoodData {
    /// Demo food item for the Chipotle Chicken Burrito Bowl
    static func createChipotleBowl() -> Food {
        Food(
            fdcId: -999,  // Negative ID to mark as demo data
            description: "Chipotle — Chicken Burrito Bowl (estimate)",
            brandOwner: nil,
            brandName: "Chipotle",
            servingSize: 1,
            servingWeightGrams: 510,  // ~18oz bowl
            numberOfServings: 1,
            servingSizeUnit: "bowl",
            householdServingFullText: "1 bowl",
            foodNutrients: [
                Nutrient(nutrientName: "Energy", value: 680, unitName: "kcal"),
                Nutrient(nutrientName: "Protein", value: 48, unitName: "g"),
                Nutrient(nutrientName: "Carbohydrate, by difference", value: 52, unitName: "g"),
                Nutrient(nutrientName: "Total lipid (fat)", value: 24, unitName: "g"),
                Nutrient(nutrientName: "Fiber, total dietary", value: 8, unitName: "g"),
                Nutrient(nutrientName: "Sodium, Na", value: 1850, unitName: "mg")
            ],
            foodMeasures: [],
            healthAnalysis: nil,
            aiInsight: nil,
            nutritionScore: nil,
            mealItems: nil,
            barcode: nil
        )
    }
}

// MARK: - Demo Timing Configuration

enum DemoTiming {
    /// Delay between typing each character (milliseconds)
    static let typingCharDelayMs: Int = 60

    /// Delay before starting each step (seconds)
    static let introDisplayDuration: Double = 2.0
    static let afterUserMessageDelay: Double = 0.8
    static let afterCoachResponseDelay: Double = 1.5
    static let afterFoodTypingDelay: Double = 0.8
    static let confirmSheetDisplayDuration: Double = 3.0
    static let afterLoggingDelay: Double = 0.5

    /// Total expected demo duration (for UI indicators)
    static let expectedTotalDurationSeconds: Int = 50
}
