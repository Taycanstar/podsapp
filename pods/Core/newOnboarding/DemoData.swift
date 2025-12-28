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
    static let userSlipUpMessage = "i messed up and ate out. i feel guilty."

    // Coach responses (appear sequentially as separate bubbles)
    static let coachResponses: [String] = [
        "You're still okay. Logging this is a win — not a verdict.",
        "This kind of moment usually follows stress or exhaustion. That's biology, not failure.",
        "Let's keep it simple. What did you eat? Type it in and I'll find the closest match."
    ]

    // Food search query (typed character by character)
    static let foodSearchQuery = "chipotle chicken bowl"

    // Post-log coach message (shown on timeline)
    static let postLogCoachMessage = """
Logged. Thank you for facing it.

You don't need to fix anything right now.

One next step: drink some water and keep your next meal normal. I'll check in later.
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
