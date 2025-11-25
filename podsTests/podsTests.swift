import XCTest
@testable import pods

final class podsTests: XCTestCase {
    func testMealItemsSurviveDecodeAndConversion() throws {
        let json = """
        {
          "status": "success",
          "food_log_id": 99,
          "calories": 400,
          "message": "Test",
          "meal_type": "Lunch",
          "food": {
            "foodLogId": 99,
            "fdcId": 1234,
            "displayName": "Sample Meal",
            "servingSizeText": "1 plate",
            "numberOfServings": 1,
            "calories": 400,
            "protein": 30,
            "carbs": 20,
            "fat": 10,
            "meal_items": [
              {
                "name": "Grilled Chicken",
                "serving": 1,
                "serving_unit": "breast",
                "calories": 200,
                "protein": 35,
                "carbs": 0,
                "fat": 5,
                "measures": [
                  {"unit": "breast", "description": "1 breast (140 g)", "gram_weight": 140},
                  {"unit": "oz", "description": "1 oz (28 g)", "gram_weight": 28}
                ],
                "subitems": [
                  {
                    "name": "Marinade",
                    "serving": 1,
                    "serving_unit": "tbsp",
                    "calories": 20,
                    "protein": 0,
                    "carbs": 3,
                    "fat": 1,
                    "measures": [
                      {"unit": "tbsp", "description": "1 tbsp (15 g)", "gram_weight": 15}
                    ]
                  }
                ]
              },
              {
                "name": "Rice",
                "serving": 1,
                "serving_unit": "cup",
                "calories": 180,
                "protein": 4,
                "carbs": 40,
                "fat": 1,
                "measures": [
                  {"unit": "cup", "description": "1 cup (158 g)", "gram_weight": 158},
                  {"unit": "tbsp", "description": "1 tbsp (10 g)", "gram_weight": 10}
                ]
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let logged = try decoder.decode(LoggedFood.self, from: json)
        XCTAssertEqual(logged.food.mealItems?.count, 2)
        XCTAssertEqual(logged.food.mealItems?.first?.subitems?.count, 1)
        XCTAssertEqual(logged.food.mealItems?.first?.measures.count, 2)

        let bridgedFood = logged.food.asFood
        XCTAssertEqual(bridgedFood.mealItems?.count, 2)
        XCTAssertEqual(bridgedFood.mealItems?.first?.subitems?.count, 1)
        XCTAssertEqual(bridgedFood.mealItems?.first?.measures.count, 2)
    }

    func testMealItemMeasureScaling() throws {
        let measure = MealItemMeasure(unit: "cup", description: "1 cup (240 g)", gramWeight: 240)
        let tablespoon = MealItemMeasure(unit: "tbsp", description: "1 tbsp (15 g)", gramWeight: 15)
        var item = MealItem(name: "Oats",
                            serving: 1,
                            servingUnit: "cup",
                            calories: 150,
                            protein: 5,
                            carbs: 27,
                            fat: 3,
                            subitems: nil,
                            baselineServing: 1,
                            measures: [measure, tablespoon])

        XCTAssertTrue(item.hasMeasureOptions)
        XCTAssertEqual(item.macroScalingFactor, 1, accuracy: 0.001)

        item.selectedMeasureId = tablespoon.id
        item.serving = 2

        let expectedScale = (2 * tablespoon.gramWeight) / (1 * measure.gramWeight)
        XCTAssertEqual(item.macroScalingFactor, expectedScale, accuracy: 0.001)
    }
}
