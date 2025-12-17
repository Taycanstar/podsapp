//
//  HealthCoachService.swift
//  pods
//
//  Created by Dimi Nunez on 12/16/25.
//


//
//  HealthCoachService.swift
//  pods
//
//  Created by Claude on 12/16/24.
//

import Foundation

/// Service for Health Coach AI interactions
/// Handles streaming chat with the health coach orchestrator
final class HealthCoachService {
    static let shared = HealthCoachService()

    private let networkManager = NetworkManager()

    private init() {}

    // MARK: - Streaming Chat

    /// Send a message to the health coach and receive streaming response
    /// - Parameters:
    ///   - message: The user's message
    ///   - history: Conversation history for context
    ///   - context: Optional client-side context (macros, workout, health metrics)
    ///   - targetDate: The date context for logging (defaults to today)
    ///   - onDelta: Called for each streamed text token
    ///   - onComplete: Called when streaming is complete with the full response
    func chatStream(
        message: String,
        history: [[String: String]] = [],
        context: HealthCoachContextPayload? = nil,
        targetDate: Date = Date(),
        onDelta: @escaping (String) -> Void,
        onComplete: @escaping (Result<HealthCoachResponse, Error>) -> Void
    ) {
        networkManager.healthCoachStream(
            message: message,
            history: history,
            context: context,
            targetDate: targetDate,
            onDelta: onDelta,
            onComplete: onComplete
        )
    }

    // MARK: - Context Building

    /// Build context payload from current app state
    /// - Parameters:
    ///   - caloriesConsumed: Total calories consumed today
    ///   - caloriesGoal: Daily calorie goal
    ///   - protein: Protein consumed today
    ///   - proteinGoal: Daily protein goal
    ///   - carbs: Carbs consumed today
    ///   - carbsGoal: Daily carbs goal
    ///   - fat: Fat consumed today
    ///   - fatGoal: Daily fat goal
    ///   - water: Water consumed today (oz)
    ///   - waterGoal: Daily water goal (oz)
    ///   - hasWorkoutToday: Whether user has a workout scheduled today
    ///   - workoutName: Name of today's workout if any
    ///   - exerciseCount: Number of exercises in today's workout
    ///   - workoutStatus: Status of today's workout
    ///   - steps: Steps today
    ///   - sleepHours: Hours slept last night
    ///   - restingHeartRate: Resting heart rate
    ///   - hrv: Heart rate variability
    ///   - weight: Current weight in kg
    func buildContext(
        caloriesConsumed: Double,
        caloriesGoal: Double,
        protein: Double,
        proteinGoal: Double,
        carbs: Double,
        carbsGoal: Double,
        fat: Double,
        fatGoal: Double,
        water: Double,
        waterGoal: Double,
        hasWorkoutToday: Bool = false,
        workoutName: String? = nil,
        exerciseCount: Int? = nil,
        workoutStatus: String? = nil,
        steps: Int? = nil,
        sleepHours: Double? = nil,
        restingHeartRate: Double? = nil,
        hrv: Double? = nil,
        weight: Double? = nil
    ) -> HealthCoachContextPayload {
        let todayMacros = TodayMacrosContext(
            caloriesConsumed: caloriesConsumed,
            caloriesGoal: caloriesGoal,
            protein: protein,
            proteinGoal: proteinGoal,
            carbs: carbs,
            carbsGoal: carbsGoal,
            fat: fat,
            fatGoal: fatGoal,
            water: water,
            waterGoal: waterGoal
        )

        let todayWorkout = TodayWorkoutContext(
            hasWorkoutToday: hasWorkoutToday,
            workoutName: workoutName,
            exerciseCount: exerciseCount,
            status: workoutStatus
        )

        let healthMetrics = HealthMetricsContext(
            steps: steps,
            sleepHours: sleepHours,
            restingHeartRate: restingHeartRate,
            hrv: hrv,
            weight: weight
        )

        return HealthCoachContextPayload(
            todayMacros: todayMacros,
            todayWorkout: todayWorkout,
            healthMetrics: healthMetrics
        )
    }

    // MARK: - Convenience Methods

    /// Convert HealthCoachFood to the standard Food model used by FoodManager
    func convertToFood(_ healthCoachFood: HealthCoachFood) -> Food {
        var nutrients: [Nutrient] = []

        if let calories = healthCoachFood.calories {
            nutrients.append(Nutrient(nutrientName: "Energy", value: calories, unitName: "KCAL"))
        }
        if let protein = healthCoachFood.protein {
            nutrients.append(Nutrient(nutrientName: "Protein", value: protein, unitName: "G"))
        }
        if let carbs = healthCoachFood.carbs {
            nutrients.append(Nutrient(nutrientName: "Carbohydrate, by difference", value: carbs, unitName: "G"))
        }
        if let fat = healthCoachFood.fat {
            nutrients.append(Nutrient(nutrientName: "Total lipid (fat)", value: fat, unitName: "G"))
        }

        return Food(
            fdcId: healthCoachFood.id ?? -1,
            description: healthCoachFood.name ?? "Unknown Food",
            brandOwner: nil,
            brandName: nil,
            servingSize: 1,
            numberOfServings: 1,
            servingSizeUnit: "serving",
            householdServingFullText: healthCoachFood.servingSizeText,
            foodNutrients: nutrients,
            foodMeasures: [],
            barcode: nil
        )
    }

    /// Convert HealthCoachMealItem to MealItem for multi-food logging
    func convertToMealItem(_ item: HealthCoachMealItem) -> MealItem {
        return MealItem(
            name: item.name ?? "Unknown",
            serving: item.serving ?? 1.0,
            servingUnit: item.servingUnit ?? "serving",
            calories: item.calories ?? 0,
            protein: item.protein ?? 0,
            carbs: item.carbs ?? 0,
            fat: item.fat ?? 0
        )
    }
}
