//
//  DemoFoodManager.swift
//  pods
//
//  Created by Dimi Nunez on 12/27/25.
//


//
//  DemoServices.swift
//  pods
//
//  Mock services for the onboarding demo.
//  These prevent real API calls and data pollution during the demo.
//

import Foundation
import SwiftUI

// MARK: - Demo Food Manager

/// Demo-specific FoodManager that prevents real API calls
/// Used to inject into FoodSummaryView/ConfirmLogView during demo
class DemoFoodManager: FoodManager {
    /// Callback when food is "logged" (for demo flow progression)
    var onFoodLogged: ((Food) -> Void)?

    override func logFood(
        email: String,
        food: Food,
        meal: String,
        servings: Double,
        date: Date,
        notes: String? = nil,
        skipCoach: Bool = false,
        skipToast: Bool = false,
        batchContext: [String: Any]? = nil,
        completion: @escaping (Result<LoggedFood, Error>) -> Void
    ) {
        // Don't make network call - just call completion with mock success
        print("🎬 DemoFoodManager: Simulating log for \(food.description)")

        DispatchQueue.main.async { [weak self] in
            self?.onFoodLogged?(food)

            // Create mock LoggedFoodItem
            let mockFoodItem = LoggedFoodItem(
                foodLogId: -999,
                fdcId: food.fdcId,
                displayName: food.description,
                calories: food.calories ?? 0,
                servingSizeText: food.servingSizeText,
                numberOfServings: servings,
                brandText: food.brandText,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat,
                healthAnalysis: nil,
                foodNutrients: food.foodNutrients
            )

            // Create mock LoggedFood response
            let mockLoggedFood = LoggedFood(
                status: "success",
                foodLogId: -999,
                calories: food.calories ?? 0,
                message: "Demo: Food logged successfully",
                food: mockFoodItem,
                mealType: meal,
                coach: nil
            )

            completion(.success(mockLoggedFood))
        }
    }
}

// MARK: - Demo Onboarding ViewModel

/// Minimal onboarding view model for demo context
/// Provides email property needed by ConfirmLogView
class DemoOnboardingViewModel: OnboardingViewModel {
    override init() {
        super.init()
        // Set demo email for any logging calls
        self.email = "demo@metryc.app"
    }
}
