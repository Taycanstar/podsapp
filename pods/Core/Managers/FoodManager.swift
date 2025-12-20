import Foundation
import SwiftUI
import Combine
import Mixpanel

enum NutritionixServiceError: LocalizedError {
    case credentialsMissing
    case invalidRequest
    case invalidResponse
    case noResults
    case statusCode(Int)

    var errorDescription: String? {
        switch self {
        case .credentialsMissing:
            return "Nutritionix credentials are missing"
        case .invalidRequest:
            return "Unable to build Nutritionix request"
        case .invalidResponse:
            return "Nutritionix returned an invalid response"
        case .noResults:
            return "No nutrition data found for this barcode"
        case .statusCode(let code):
            return "Nutritionix request failed with status code \(code)"
        }
    }
}

final class NutritionixService {
    static let shared = NutritionixService()

    private let session: URLSession
    private let appId: String
    private let apiKey: String

    init(session: URLSession = .shared, configurationManager: ConfigurationManager = .shared) {
        self.session = session
        self.appId = configurationManager.getValue(forKey: "NUTRITIONIX_APP_ID") as? String ?? ""
        self.apiKey = configurationManager.getValue(forKey: "NUTRITIONIX_KEY") as? String ?? ""
    }

    var isConfigured: Bool {
        !appId.isEmpty && !apiKey.isEmpty
    }

    func lookupFood(by barcode: String, userEmail: String?, completion: @escaping (Result<Food, Error>) -> Void) {
        guard isConfigured else {
            completion(.failure(NutritionixServiceError.credentialsMissing))
            return
        }

        guard var components = URLComponents(string: "https://trackapi.nutritionix.com/v2/search/item") else {
            completion(.failure(NutritionixServiceError.invalidRequest))
            return
        }
        components.queryItems = [URLQueryItem(name: "upc", value: barcode)]
        guard let url = components.url else {
            completion(.failure(NutritionixServiceError.invalidRequest))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(appId, forHTTPHeaderField: "x-app-id")
        request.setValue(apiKey, forHTTPHeaderField: "x-app-key")
        if let userEmail, !userEmail.isEmpty {
            request.setValue(userEmail, forHTTPHeaderField: "x-remote-user-id")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NutritionixServiceError.invalidResponse)) }
                return
            }

            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 404 {
                    DispatchQueue.main.async { completion(.failure(NutritionixServiceError.noResults)) }
                } else {
                    DispatchQueue.main.async { completion(.failure(NutritionixServiceError.statusCode(httpResponse.statusCode))) }
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NutritionixServiceError.invalidResponse)) }
                return
            }

            do {
// #if DEBUG
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                   let pretty = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
                   let jsonString = String(data: pretty, encoding: .utf8) {
                    print("📦 [Nutritionix] Raw response for barcode \(barcode):\n\(jsonString)")
                } else if let rawString = String(data: data, encoding: .utf8) {
                    print("📦 [Nutritionix] Raw response (fallback) for barcode \(barcode):\n\(rawString)")
                }
// #endif
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let itemResponse = try decoder.decode(NutritionixItemResponse.self, from: data)
                guard let food = self.makeFood(from: itemResponse, barcode: barcode) else {
                    throw NutritionixServiceError.noResults
                }
                DispatchQueue.main.async { completion(.success(food)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    private func makeFood(from response: NutritionixItemResponse, barcode: String) -> Food? {
        guard let item = response.foods?.first ?? response.branded?.first else {
            return nil
        }

        func formattedQuantity(_ value: Double) -> String {
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(Int(value))
            }
            var string = String(format: "%.2f", value)
            while string.last == "0" {
                string.removeLast()
            }
            if string.last == "." {
                string.removeLast()
            }
            return string
        }

        func gramWeight(from qty: Double?, unitRaw: String?) -> Double? {
            guard let qty, qty > 0 else { return nil }
            guard let raw = unitRaw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return qty
            }
            if raw.contains("ml") { return qty }
            if raw.contains("gram") || raw == "g" { return qty }
            if raw.contains("fl oz") || raw.contains("floz") { return qty * 29.5735 }
            if raw.contains("oz") { return qty * 28.3495 }
            return nil
        }

#if DEBUG
        print("🍽 [Nutritionix] Raw item for barcode \(barcode):")
        print("  foodName: \(item.foodName ?? "<nil>")")
        print("  brandName: \(item.brandName ?? "<nil>")")
        print("  servingQty: \(item.servingQty.map(String.init) ?? "<nil>")")
        print("  servingUnit: \(item.servingUnit ?? "<nil>")")
        print("  servingWeightGrams: \(item.servingWeightGrams.map(String.init) ?? "<nil>")")
        if let measures = item.altMeasures, !measures.isEmpty {
            print("  altMeasures (\(measures.count)):")
            for (idx, alt) in measures.enumerated() {
                let qtyText = alt.qty.map(String.init) ?? "<nil>"
                let weightText = alt.servingWeight.map(String.init) ?? "<nil>"
                print("    [\(idx)] measure: \(alt.measure ?? "<nil>"), qty: \(qtyText), grams: \(weightText)")
            }
        } else {
            print("  altMeasures: <none>")
        }
        if let nutrients = item.fullNutrients, !nutrients.isEmpty {
            print("  fullNutrients count: \(nutrients.count)")
        } else {
            print("  fullNutrients: <none>")
        }
#endif

        let name = item.brandNameItemName ?? item.foodName ?? "Food"
        let brand = item.brandName ?? item.brandOwner
        let servingQty = item.servingQty ?? 1
        let servingUnit = item.servingUnit ?? "serving"
        let servingWeight = item.servingWeightGrams
        let calories = item.nfCalories ?? 0
        let protein = item.nfProtein ?? 0
        let carbs = item.nfTotalCarbohydrate ?? 0
        let fat = item.nfTotalFat ?? 0
        let sugars = item.nfSugars
        let fiber = item.nfDietaryFiber
        let sodium = item.nfSodium

        var nutrients: [Nutrient] = []
        var addedKeys = Set<String>()

        func appendNutrient(name: String, value: Double?, unit: String) {
            // Keep zero values - they indicate the nutrient was measured (e.g., 0g trans fat)
            // Only skip if value is nil (not present in response)
            guard let value else { return }
            if !addedKeys.contains(name) {
                nutrients.append(Nutrient(nutrientName: name, value: value, unitName: unit))
                addedKeys.insert(name)
            }
        }

        appendNutrient(name: "Energy", value: calories, unit: "kcal")
        appendNutrient(name: "Protein", value: protein, unit: "g")
        appendNutrient(name: "Carbohydrate, by difference", value: carbs, unit: "g")
        appendNutrient(name: "Total lipid (fat)", value: fat, unit: "g")
        appendNutrient(name: "Sugars, total including NLEA", value: sugars, unit: "g")
        appendNutrient(name: "Fiber, total dietary", value: fiber, unit: "g")
        appendNutrient(name: "Sodium, Na", value: sodium, unit: "mg")

        if let fullNutrients = item.fullNutrients {
            for nutrient in fullNutrients {
                guard let mapping = NutritionixService.attrIdMap[nutrient.attrId] else { continue }
                appendNutrient(name: mapping.name, value: nutrient.value, unit: mapping.unit)
            }
        }

        var measures: [MealItemMeasure] = item.altMeasures?.compactMap { alt -> MealItemMeasure? in
            guard let weight = alt.servingWeight, weight > 0 else { return nil }
            let description = alt.measure?.isEmpty == false ? alt.measure! : "serving"
            return MealItemMeasure(unit: description, description: description, gramWeight: weight)
        } ?? []

        let metricQty = item.nfMetricQty
        let metricUnit = item.nfMetricUom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let metricGramWeight = gramWeight(from: metricQty, unitRaw: metricUnit)
        let baseWeight = servingWeight ?? metricGramWeight ?? measures.first?.gramWeight ?? 0
        let baseLabel: String = {
            if let metricQty, metricQty > 0, !metricUnit.isEmpty {
                return "\(servingUnit) (\(formattedQuantity(metricQty)) \(metricUnit))"
            }
            let fallback = formattedServingText(qty: servingQty, unit: servingUnit, grams: servingWeight)
            return fallback.isEmpty ? "\(formattedQuantity(servingQty)) \(servingUnit)" : fallback
        }()
        // Ensure we always have a baseline measure that matches the serving unit
        if !measures.contains(where: { $0.unit.lowercased() == servingUnit.lowercased() }) {
            let grams = baseWeight > 0 ? baseWeight : 1
            measures.insert(MealItemMeasure(unit: servingUnit, description: baseLabel, gramWeight: grams), at: 0)
        }

        if measures.isEmpty {
            let grams = baseWeight > 0 ? baseWeight : 1
            measures.append(MealItemMeasure(unit: servingUnit, description: baseLabel, gramWeight: grams))
        }

        let foodMeasures: [FoodMeasure] = measures.enumerated().map { index, measure in
            FoodMeasure(
                disseminationText: measure.description,
                gramWeight: measure.gramWeight,
                id: index,
                modifier: measure.description,
                measureUnitName: measure.unit,
                rank: index
            )
        }

        let originalServing = MealItemServingDescriptor(
            amount: servingQty,
            unit: servingUnit,
            text: formattedServingText(qty: servingQty, unit: servingUnit, grams: servingWeight)
        )

        let mealItem = MealItem(
            name: name,
            serving: servingQty,
            servingUnit: servingUnit,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            subitems: nil,
            baselineServing: servingQty,
            measures: measures,
            originalServing: originalServing
        )

        let pseudoId = makePseudoFdcId(from: barcode)
        let servingText = formattedServingText(qty: servingQty, unit: servingUnit, grams: servingWeight)

        return Food(
            fdcId: pseudoId,
            description: name,
            brandOwner: brand,
            brandName: brand,
            servingSize: servingQty,
            numberOfServings: 1,  // User logs 1 serving by default, not servingQty
            servingSizeUnit: servingUnit,
            householdServingFullText: servingText,
            foodNutrients: nutrients,
            foodMeasures: foodMeasures,
            healthAnalysis: nil,
            aiInsight: defaultInsight(for: item),
            nutritionScore: nil,
            mealItems: [mealItem],
            barcode: barcode
        )
    }

    private func formattedServingText(qty: Double?, unit: String?, grams: Double?) -> String {
        var components: [String] = []
        if let qty {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            let text = formatter.string(from: NSNumber(value: qty)) ?? "\(qty)"
            if let unit, !unit.isEmpty {
                components.append("\(text) \(unit)")
            } else {
                components.append(text)
            }
        }
        if let grams, grams > 0 {
            components.append("(\(String(format: "%.0f", grams)) g)")
        }
        return components.joined(separator: " ")
    }

    private func defaultInsight(for item: NutritionixFood) -> String? {
        guard let brand = item.brandName else { return nil }
        return "Nutrition data provided by \(brand)."
    }

    private func makePseudoFdcId(from barcode: String) -> Int {
        if let numeric = Int(barcode) {
            return numeric
        }
        let scalars = barcode.unicodeScalars.map { UInt32($0.value) }
        let hash = scalars.reduce(UInt64(5381)) { ($0 << 5) &+ $0 &+ UInt64($1) }
        return Int(hash % 1_000_000_000) + 900_000_000
    }

    private static let attrIdMap: [Int: (name: String, unit: String)] = [
        // Carbohydrates
        269: ("Sugars, total including NLEA", "g"),
        291: ("Fiber, total dietary", "g"),
        539: ("Sugars, added", "g"),
        209: ("Starch", "g"),
        // Sugar alcohols
        299: ("Sugar Alcohol", "g"),
        1001: ("Erythritol", "g"),
        1006: ("Allulose", "g"),
        // Fats
        601: ("Cholesterol", "mg"),
        605: ("Fatty acids, total trans", "g"),
        606: ("Fatty acids, total saturated", "g"),
        645: ("Fatty acids, total monounsaturated", "g"),
        646: ("Fatty acids, total polyunsaturated", "g"),
        // Omega fatty acids
        851: ("18:3 n-3 c,c,c (ALA)", "g"),
        629: ("20:5 n-3 (EPA)", "g"),
        621: ("22:6 n-3 (DHA)", "g"),
        631: ("22:5 n-3 (DPA)", "g"),
        // Minerals
        301: ("Calcium, Ca", "mg"),
        303: ("Iron, Fe", "mg"),
        304: ("Magnesium, Mg", "mg"),
        305: ("Phosphorus, P", "mg"),
        306: ("Potassium, K", "mg"),
        307: ("Sodium, Na", "mg"),
        309: ("Zinc, Zn", "mg"),
        312: ("Copper, Cu", "mg"),
        315: ("Manganese, Mn", "mg"),
        317: ("Selenium, Se", "mcg"),
        313: ("Fluoride, F", "mcg"),
        // Vitamins
        320: ("Vitamin A, RAE", "mcg"),
        318: ("Vitamin A, IU", "IU"),
        404: ("Thiamin", "mg"),
        405: ("Riboflavin", "mg"),
        406: ("Niacin", "mg"),
        410: ("Pantothenic acid", "mg"),
        415: ("Vitamin B-6", "mg"),
        418: ("Vitamin B-12", "mcg"),
        401: ("Vitamin C, total ascorbic acid", "mg"),
        324: ("Vitamin D", "IU"),
        328: ("Vitamin D (D2 + D3)", "mcg"),
        323: ("Vitamin E (alpha-tocopherol)", "mg"),
        430: ("Vitamin K (phylloquinone)", "mcg"),
        417: ("Folate, total", "mcg"),
        431: ("Folic acid", "mcg"),
        435: ("Folate, DFE", "mcg"),
        // Other vitamins/compounds
        321: ("Carotene, beta", "mcg"),
        322: ("Carotene, alpha", "mcg"),
        334: ("Cryptoxanthin, beta", "mcg"),
        337: ("Lycopene", "mcg"),
        338: ("Lutein + zeaxanthin", "mcg"),
        319: ("Retinol", "mcg"),
        421: ("Choline, total", "mg"),
        454: ("Betaine", "mg"),
        // Amino acids
        512: ("Histidine", "g"),
        503: ("Isoleucine", "g"),
        504: ("Leucine", "g"),
        505: ("Lysine", "g"),
        506: ("Methionine", "g"),
        507: ("Cystine", "g"),
        508: ("Phenylalanine", "g"),
        502: ("Threonine", "g"),
        501: ("Tryptophan", "g"),
        509: ("Tyrosine", "g"),
        510: ("Valine", "g"),
        511: ("Arginine", "g"),
        513: ("Alanine", "g"),
        514: ("Aspartic acid", "g"),
        515: ("Glutamic acid", "g"),
        516: ("Glycine", "g"),
        517: ("Proline", "g"),
        518: ("Serine", "g"),
        // Other compounds
        255: ("Water", "g"),
        221: ("Alcohol, ethyl", "g"),
        262: ("Caffeine", "mg"),
        263: ("Theobromine", "mg"),
        // Individual sugars
        212: ("Fructose", "g"),
        211: ("Glucose (dextrose)", "g"),
        213: ("Lactose", "g"),
        214: ("Maltose", "g"),
        210: ("Sucrose", "g"),
        287: ("Galactose", "g")
    ]
}

private struct NutritionixItemResponse: Decodable {
    let foods: [NutritionixFood]?
    let branded: [NutritionixFood]?
}

private struct NutritionixFood: Decodable {
    let foodName: String?
    let brandName: String?
    let brandOwner: String?
    let brandNameItemName: String?
    let servingQty: Double?
    let servingUnit: String?
    let servingWeightGrams: Double?
    let nfCalories: Double?
    let nfProtein: Double?
    let nfTotalCarbohydrate: Double?
    let nfTotalFat: Double?
    let nfSugars: Double?
    let nfDietaryFiber: Double?
    let nfSodium: Double?
    let nfIngredientStatement: String?
    let nfMetricQty: Double?
    let nfMetricUom: String?
    let altMeasures: [NutritionixAltMeasure]?
    let fullNutrients: [NutritionixFullNutrient]?
}

private struct NutritionixAltMeasure: Decodable {
    let servingWeight: Double?
    let measure: String?
    let qty: Double?
}

private struct NutritionixFullNutrient: Decodable {
    let attrId: Int
    let value: Double?
}

// Memory tracking helper for crash debugging (duplicated from FoodScannerView)
func getMemoryUsage() -> (used: Double, available: Double) {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
        let availableMB = totalMB - usedMB
        return (used: usedMB, available: availableMB)
    } else {
        return (used: 0, available: 0)
    }
}
// Extension to convert Food to LoggedFoodItem
extension Food {
    var asLoggedFoodItem: LoggedFoodItem {
        return LoggedFoodItem(
            foodLogId: nil,
            fdcId: self.fdcId,
            displayName: self.displayName,
            calories: self.calories ?? 0,
            servingSizeText: self.servingSizeText,
            numberOfServings: self.numberOfServings ?? 1,
            brandText: self.brandText,
            protein: self.protein,
            carbs: self.carbs,
            fat: self.fat,
            healthAnalysis: nil,
            foodNutrients: self.foodNutrients,
            aiInsight: self.aiInsight,
            nutritionScore: self.nutritionScore,
            mealItems: self.mealItems
        )
    }
}

// MARK: - Modern Food Scanning State System
enum FoodScanningState: Equatable {
    case inactive                                 // Hidden state - no loader shown
    case initializing                            // Show loader at 0% - isActive = true
    case preparing(image: UIImage)
    case uploading(progress: Double)  // Real network progress 0.0 to 0.5
    case analyzing 
    case processing
    case completed(result: CombinedLog)
    case failed(error: FoodScanError)
    
    // UNIFIED: New states for macro and meal generation (replacing legacy states)
    case generatingMacros                        // AI macro generation
    case generatingMeal                          // AI meal generation from image
    case generatingFood                          // AI food generation from text/voice
    
    // Computed properties for UI
    var isActive: Bool {
        switch self {
        case .inactive: return false              // Hide loader when inactive
        default: return true                      // Show loader for all processing states including completed
        }
    }
    
    var displayMessage: String {
        switch self {
        case .inactive: return ""
        case .initializing, .preparing, .uploading, .analyzing, .processing: return "Finishing up..."
        case .generatingMacros: return "Generating macros..."
        case .generatingMeal: return "Analyzing meal..."
        case .generatingFood: return "Creating food..."
        case .completed: return "Complete!"
        case .failed(let error): return error.localizedDescription
        }
    }
    
    // Real progress based on actual state transitions (no fake timers)
    var progress: Double {
        switch self {
        case .inactive: return 0.0
        case .initializing: return 0.0            // Start at 0% with loader visible
        case .preparing: return 0.1               // 10% when preparing
        case .uploading(let progress): return 0.1 + (progress * 0.4)  // 10-50% for upload
        case .analyzing: return 0.6               // 60% when analyzing
        case .processing: return 0.8              // 80% when processing
        case .generatingMacros: return 0.5        // 50% for macro generation
        case .generatingMeal: return 0.7          // 70% for meal generation
        case .generatingFood: return 0.6          // 60% for food generation
        case .completed: return 1.0               // 100% when done
        case .failed: return 0.0                  // Reset on failure
        }
    }
    
    var canDismiss: Bool {
        switch self {
        case .inactive, .completed, .failed: return true
        default: return false
        }
    }
    
    // Equatable implementation
    static func == (lhs: FoodScanningState, rhs: FoodScanningState) -> Bool {
        switch (lhs, rhs) {
        case (.inactive, .inactive): return true
        case (.initializing, .initializing): return true
        case (.preparing(let img1), .preparing(let img2)): return img1 == img2
        case (.uploading, .uploading): return true
        case (.analyzing, .analyzing): return true
        case (.processing, .processing): return true
        case (.generatingMacros, .generatingMacros): return true
        case (.generatingMeal, .generatingMeal): return true
        case (.generatingFood, .generatingFood): return true
        case (.completed(let result1), .completed(let result2)): return result1.foodLogId == result2.foodLogId
        case (.failed(let error1), .failed(let error2)): return error1.localizedDescription == error2.localizedDescription
        default: return false
        }
    }
}

enum FoodScanError: LocalizedError {
    case imageProcessingFailed
    case networkError(String)
    case invalidResponse
    case analysisTimeout
    case userCancelled
    case unsupportedBarcode

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Unable to process image. Please try again."
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .analysisTimeout:
            return "Analysis took too long. Please try again."
        case .userCancelled:
            return "Scan cancelled"
        case .unsupportedBarcode:
            return "This code isn't a nutrition barcode. Please scan the UPC/EAN printed near the nutrition label."
        }
    }
}


@MainActor
class FoodManager: ObservableObject {
    @Published var loggedFoods: [LoggedFood] = []
    @Published var isLoading = false
    @Published var isLoadingLogs = false
    @Published var isLoadingMoreLogs = false  // Added missing variable
    @Published var isLoadingFood = false
    @Published var isLoadingMeals = false
    @Published var isLoadingMeal = false
    @Published var hasMore = true
    @Published var error: Error?
    @Published var lastLoggedFoodId: Int? = nil
    @Published var showToast = false
    @Published var showMealToast = false
    @Published var showMealLoggedToast = false
    @Published var showRecipeLoggedToast = false
    @Published var showSavedMealToast = false
    @Published var showUnsavedMealToast = false
    @Published var recentlyAddedFoodIds: Set<Int> = []
    @Published var lastLoggedMealId: Int? = nil
    @Published var lastLoggedRecipeId: Int? = nil
    @Published var lastCoachMessage: CoachMessage? = nil  // AI coach message for most recent food log
    @Published var isAwaitingCoachMessage: Bool = false  // True while waiting for coach response after food log
    @Published var awaitingCoachForFoodLogId: Int? = nil  // The food log ID we're generating coach message for

    // Add properties for user-created foods
    @Published var userFoods: [Food] = []
    @Published var isLoadingUserFoods = false
    private var hasMoreUserFoods = true
    // Read-only exposure for views
    var hasMoreUserFoodsAvailable: Bool { hasMoreUserFoods }
    private var currentUserFoodsPage = 1
    
    private let networkManager: NetworkManager
    private let feedRepository = FoodFeedRepository.shared
    private let combinedLogsRepository = CombinedLogsRepository.shared
    private let mealsRepository = MealsRepository.shared
    private let recipesRepository = RecipesRepository.shared
    private let savedMealsRepository = SavedMealsRepository.shared
    private let userFoodsRepository = UserFoodsRepository.shared
    private var feedCancellables: Set<AnyCancellable> = []
    private var repositoryCancellables: Set<AnyCancellable> = []
     var userEmail: String?
    private var currentPage = 1
    private let pageSize = 20
    // Add these properties
    @Published var meals: [Meal] = []
    @Published var isLoadingMealPage = false
    private var currentMealPage = 1
    private var mealCurrentPage = 1  // Added missing variable
    private var hasMoreMeals = true
    // Read-only for UI pagination checks
    var hasMoreMealsAvailable: Bool { hasMoreMeals }
    private var mealsHasMore = true  // Added missing variable
    @Published var combinedLogs: [CombinedLog] = []
    private var lastRefreshTime: Date?
    private var lastMealsFetchDate: Date?
    private var lastRecipesFetchDate: Date?
    private var lastCombinedLogsFetchDate: Date?
    private var lastUserFoodsFetchDate: Date?
    private var lastSavedMealsFetchDate: Date?

    private var isFetchingMeals = false
    private var isFetchingRecipes = false
    private var isFetchingCombinedLogs = false
    private var isFetchingUserFoods = false
    private var isFetchingSavedMeals = false

    private var lastInitializedEmail: String?
    private var lastRefreshDate: Date?
    private let refreshInterval: TimeInterval = 120
    
    // Recipe-related properties
    @Published var recipes: [Recipe] = []
    @Published var isLoadingRecipePage = false
    private var currentRecipePage = 1
    private var hasMoreRecipes = true
    private var totalRecipesPages = 1
    private var currentRecipesPage = 1
    
    // MARK: - New Modern State System (replaces 15+ competing @Published properties)
    @Published var foodScanningState: FoodScanningState = .inactive
    @Published var animatedProgress: Double = 0.0  // Global animated progress
    @Published var currentScanningImage: UIImage? = nil  // Persistent image during scanning
    @Published var isImageScanning: Bool = false  // Flag to determine scanning type
    
    // MARK: - Legacy Properties (TO BE REMOVED - cause race conditions)
    // These properties cause competing DispatchQueue.main.async updates and timer race conditions
    @Published var isAnalyzingFood = false  // DEPRECATED: Use foodScanningState instead
    @Published var analysisStage = 0  // DEPRECATED: Use foodScanningState instead
    @Published var showAIGenerationSuccess = false
    @Published var aiGeneratedFood: LoggedFoodItem?
    @Published var showLogSuccess = false
    
    // MARK: - Voice Logging Timer Management
    private var voiceStageTimer: Timer?
    
    private func stopVoiceTimer() {
        voiceStageTimer?.invalidate()
        voiceStageTimer = nil
    }
    
    private func resetVoiceLoggingState() {
        stopVoiceTimer()
        // UNIFIED: Reset to inactive state (keeping legacy for backward compatibility)
        foodScanningState = .inactive
        isGeneratingMacros = false
        isLoading = false
        macroGenerationStage = 0
        macroLoadingMessage = ""
        showAIGenerationSuccess = false
        aiGeneratedFood = nil
    }

    struct AgentFoodImageResult {
        let foods: [Food]
        let mealItems: [MealItem]
        let message: String?
    }
    @Published var lastLoggedItem: (name: String, calories: Double)?
    
    // Add these properties for meal generation with AI
    @Published var isGeneratingMeal = false
    @Published var mealGenerationStage = 0
    @Published var lastGeneratedMeal: Meal? = nil
    
    // Add this property for meal generation success
    @Published var showMealGenerationSuccess = false
    
    // Add state for food generation
    @Published var isGeneratingFood = false  // DEPRECATED: Use foodScanningState instead
    @Published var foodGenerationStage = 0  // DEPRECATED: Use foodScanningState instead
    @Published var showFoodGenerationSuccess = false
    @Published var lastGeneratedFood: Food? = nil
    
    // Add these properties for food image analysis
    @Published var loadingMessage: String = ""  // DEPRECATED: Use foodScanningState.displayMessage instead
    
    // Food Scanning - THESE CAUSE THE RACE CONDITIONS
    @Published var isScanningFood = false  // DEPRECATED: Use foodScanningState.isActive instead
    @Published var scanningFoodError: String? = nil  // DEPRECATED: Use foodScanningState failed case instead
    @Published var scannedImage: UIImage? = nil  // DEPRECATED: Use foodScanningState preparing case instead
    @Published var uploadProgress: Double = 0.0  // DEPRECATED: Fake progress causes timer race conditions

    // New specific loading states for different functionalities
    @Published var isGeneratingMacros = false
    @Published var macroGenerationStage = 0
    @Published var macroLoadingMessage: String = ""
    @Published var macroLoadingTitle: String = "Generating Macros with AI"
    
    @Published var isScanningBarcode = false  // DEPRECATED: Use foodScanningState instead
    @Published var barcodeLoadingMessage: String = ""  // DEPRECATED: Use foodScanningState.displayMessage instead
    
    @Published var isAnalyzingImage = false  // DEPRECATED: Use foodScanningState instead
    @Published var imageAnalysisMessage: String = ""  // DEPRECATED: Use foodScanningState.displayMessage instead

    
    // Add the new property
    @Published var isLoggingFood = false
    
    // Add errorMessage property after other published properties, around line 85
    @Published var errorMessage: String? = nil
    
    // Saved meals properties
    @Published var savedMeals: [SavedMeal] = []
    @Published var isLoadingSavedMeals = false
    private var currentSavedMealsPage = 1
    private var hasMoreSavedMeals = true
    @Published var savedLogIds: Set<Int> = [] // Track which log IDs are saved

    // Reference to DayLogsViewModel for updating UI after voice logging
    weak var dayLogsViewModel: DayLogsViewModel?
    
    // Nutrition label name input state (for logging)
    @Published var showNutritionNameInput = false
    @Published var pendingNutritionData: [String: Any] = [:]
    @Published var pendingMealType = "Lunch"
    
    // Nutrition label name input state (for creation)
    @Published var showNutritionNameInputForCreation = false
    @Published var pendingNutritionDataForCreation: [String: Any] = [:]
    @Published var pendingMealTypeForCreation = "Lunch"
    
    // Nutrition label name input state (for recipe/meal adding)
    @Published var showNutritionNameInputForRecipe = false
    @Published var pendingNutritionDataForRecipe: [String: Any] = [:]
    @Published var pendingMealTypeForRecipe = "Lunch"
    
    // Scan failure error handling
    @Published var showScanFailureAlert = false
    @Published var scanFailureMessage = ""
    @Published var scanFailureType = ""
    
    // DEPRECATED: These timer-based properties cause race conditions and app freezes
    // Progress timer for upload progress
    private var progressTimer: Timer?  // DEPRECATED: Causes 25+ competing main thread updates
    
    // CRITICAL FIX: Track all active timers for cleanup
    private var activeTimers: Set<Timer> = []  // DEPRECATED: Should not need timer tracking in modern approach
    private var scannerDismissed = false  // DEPRECATED: Use Task cancellation instead
    
    // Auto-reset work item for completed state (cancellable)
    private var stateAutoResetWorkItem: DispatchWorkItem? = nil
    
    // MARK: - Modern State Management (replaces timers)
    // These methods eliminate race conditions by using deterministic state transitions
    
    /// Safely transition to a new food scanning state on main thread
    func updateFoodScanningState(_ newState: FoodScanningState) {
        assert(Thread.isMainThread, "Food scanning state must be updated on main thread")
        let oldState = foodScanningState

        // FORCE UI UPDATE: Explicitly notify SwiftUI of changes
        objectWillChange.send()

        // Cancel any pending auto-reset from a previous session when moving to an active state
        if newState.isActive {
            stateAutoResetWorkItem?.cancel()
            stateAutoResetWorkItem = nil
        }

        foodScanningState = newState
        
        // Manage animated progress globally
        if newState.isActive {
            // Animate to new progress while active
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newState.progress
            }
        } else {
            // Reset to 0 when loader disappears
            animatedProgress = 0.0
        }
        
        print("🔍 DEBUG updateFoodScanningState - OLD: \(oldState) (\(oldState.progress)), NEW: \(newState) (\(newState.progress)), AnimatedProgress: \(animatedProgress)")
        
        // Handle completed state with 100% visibility
        if case .completed = newState {
            print("✅ Completed state reached - showing 100% for 1.5 seconds before auto-reset")
            // Use a cancellable work item so a new session doesn't get clobbered by a stale reset
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                print("⏰ Auto-resetting from completed state to inactive")
                self.resetFoodScanningState()
            }
            stateAutoResetWorkItem?.cancel()
            stateAutoResetWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
        }
        
        // ADDITIONAL FORCE: Send another update after state change
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    /// Start a new food scanning session with loader visible at 0%
    func startFoodScanning() {
        print("🆕 Starting new food scanning session")
        updateFoodScanningState(.initializing)
    }
    
    /// Complete food scanning with result and auto-reset
    func completeFoodScanning(result: CombinedLog) {
        print("🏁 Completing food scanning with result")
        updateFoodScanningState(.completed(result: result))
        // Auto-reset is handled by updateFoodScanningState
    }
    
    /// Reset food scanning state to inactive with proper cleanup
    func resetFoodScanningState() {
        updateFoodScanningState(.inactive)

        // Clean up new state system
        isImageScanning = false
        currentScanningImage = nil
        
        // Clean up any legacy state (temporary during migration)
        isScanningFood = false
        isAnalyzingFood = false
        isAnalyzingImage = false
        isScanningBarcode = false
        uploadProgress = 0.0
        loadingMessage = ""
        scannedImage = nil
        
        // 🔧 CRITICAL FIX: Reset voice logging state too
        resetVoiceLoggingState()

        // Cancel any pending auto-reset work
        stateAutoResetWorkItem?.cancel()
        stateAutoResetWorkItem = nil
    }
    
    /// Handle scan failure with proper error state
    func handleScanFailure(_ error: FoodScanError) {
        updateFoodScanningState(.failed(error: error))
        
        // Auto-reset to inactive after a delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.resetFoodScanningState()
        }
    }

    /// Agent-powered image analysis (vision -> agent tool -> Nutritionix). Preview-only helper.
    @MainActor
    func analyzeFoodImageWithAgent(
        image: UIImage,
        userEmail: String,
        mealType: String = "Lunch",
        logDate: String? = nil
    ) async throws -> AgentFoodImageResult {
        try await withCheckedThrowingContinuation { continuation in
            networkManager.analyzeFoodImageViaAgent(
                image: image,
                userEmail: userEmail,
                mealType: mealType,
                logDate: logDate
            ) { success, response, errorMessage in
                if success, let response = response {
                    let foods = response.foods ?? []
                    let items = response.mealItems ?? []
                    continuation.resume(returning: AgentFoodImageResult(foods: foods, mealItems: items, message: response.message))
                } else {
                    let err = NetworkError.serverError(errorMessage ?? "Unknown error")
                    continuation.resume(throwing: err)
                }
            }
        }
    }

    // MARK: - Fast Food Image Analysis (MacroFactor-style, 2-4 seconds)

    /// Fast food image analysis result
    struct FastFoodImageResult {
        let foods: [Food]
        let mealItems: [MealItem]
        let message: String?
        let timingMs: Int?
    }

    /// Ultra-fast food image analysis using minimal vision + async Nutritionix
    func analyzeFoodImageFast(
        image: UIImage,
        userEmail: String
    ) async throws -> FastFoodImageResult {
        try await withCheckedThrowingContinuation { continuation in
            networkManager.analyzeFoodImageFast(
                image: image,
                userEmail: userEmail
            ) { success, response, errorMessage in
                if success, let response = response {
                    let foods = response.foods ?? []
                    let items = response.mealItems ?? []
                    let timingMs = response.timing?.totalMs
                    continuation.resume(returning: FastFoodImageResult(
                        foods: foods,
                        mealItems: items,
                        message: response.message,
                        timingMs: timingMs
                    ))
                } else {
                    let err = NetworkError.serverError(errorMessage ?? "Unknown error")
                    continuation.resume(throwing: err)
                }
            }
        }
    }

    // MARK: - Modern Network Methods (eliminates race conditions)

    /// Modern food image analysis with deterministic state transitions (replaces timer-based method)
    @MainActor
    func analyzeFoodImageModern(
        image: UIImage,
        userEmail: String,
        mealType: String = "Lunch",
        shouldLog: Bool = true,
        scanMode: String? = nil
    ) async throws -> CombinedLog {
        print("🆕 Starting MODERN food image analysis with proper session flow, scanMode=\(scanMode ?? "nil")")
        
        // Set image scanning flag and store image
        isImageScanning = true
        currentScanningImage = image
        
        // CHECKPOINT 0: 0% - Start session with loader visible
        updateFoodScanningState(.initializing)
        try await Task.sleep(nanoseconds: 300_000_000) // Show 0% briefly
        
        // CHECKPOINT 1: 10% - Image preparation
        updateFoodScanningState(.preparing(image: image))
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // CHECKPOINT 2: 30% - Starting network upload
        updateFoodScanningState(.uploading(progress: 0.0))
        try await Task.sleep(nanoseconds: 200_000_000) // Brief delay for UX
        
        // CHECKPOINT 2.5: 35% - Upload progress
        updateFoodScanningState(.uploading(progress: 0.5))
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Make network call with proper error handling
        return try await withCheckedThrowingContinuation { continuation in
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; df.timeZone = .current
            let selected = self.dayLogsViewModel?.selectedDate ?? Date()
            let dateString = df.string(from: selected)
            networkManager.analyzeFoodImage(
                image: image,
                userEmail: userEmail,
                mealType: mealType,
                shouldLog: shouldLog,
                logDate: dateString,
                scanMode: scanMode
            ) { [weak self] success, payload, errMsg in
                guard let self = self else {
                    continuation.resume(throwing: FoodScanError.userCancelled)
                    return
                }
                
                DispatchQueue.main.async {
                    if success, let payload = payload {
                        // CHECKPOINT 3: 60% - Network complete, starting analysis
                        self.updateFoodScanningState(.analyzing)
                        
                        // Process response
                        do {
                            let combinedLog = try self.processFoodAnalysisResponse(
                                payload: payload,
                                shouldLog: shouldLog,
                                mealType: mealType
                            )
                            
                            // CHECKPOINT 4: 80% - Analysis complete, processing result
                            self.updateFoodScanningState(.processing)
                            
                            // Brief processing delay for UX with intermediate progress
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // Show 90% during processing
                                // Note: .processing returns 0.8 (80%), but we can't easily show 90% without new state
                                // CHECKPOINT 5: 100% - Everything complete
                                self.updateFoodScanningState(.completed(result: combinedLog))
                                continuation.resume(returning: combinedLog)
                            }
                            
                        } catch {
                            self.handleScanFailure(.invalidResponse)
                            continuation.resume(throwing: error)
                        }
                    } else {
                        let error = FoodScanError.networkError(errMsg ?? "Unknown error")
                        self.handleScanFailure(error)
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Process food analysis response without timers or race conditions
    private func processFoodAnalysisResponse(
        payload: [String: Any],
        shouldLog: Bool,
        mealType: String
    ) throws -> CombinedLog {
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        let decoder = JSONDecoder()

        // Parse coach message if present (only for shouldLog=true responses)
        if shouldLog, let coachDict = payload["coach"] as? [String: Any] {
            do {
                let coachData = try JSONSerialization.data(withJSONObject: coachDict)
                let coachMessage = try decoder.decode(CoachMessage.self, from: coachData)
                self.lastCoachMessage = coachMessage
           
            } catch {
                print("⚠️ [COACH] Failed to parse coach message: \(error)")
                self.lastCoachMessage = nil
            }
        } else {
            // Clear coach message for preview/non-log responses
            if shouldLog {
                self.lastCoachMessage = nil
            }
        }

        if shouldLog {
            // When shouldLog=true, backend returns LoggedFood with foodLogId
            let loggedFood = try decoder.decode(LoggedFood.self, from: jsonData)

            return CombinedLog(
                type: .food,
                status: loggedFood.status,
                calories: loggedFood.calories,
                message: loggedFood.message,
                foodLogId: loggedFood.foodLogId,
                food: loggedFood.food,
                mealType: loggedFood.mealType,
                mealLogId: nil,
                meal: nil,
                mealTime: nil,
                scheduledAt: Date(),
                recipeLogId: nil,
                recipe: nil,
                servingsConsumed: nil
            )
        } else {
            // Process creation-only response (preview mode)
            guard let foodDict = payload["food"] as? [String: Any] else {
                throw FoodScanError.invalidResponse
            }
            
            // Extract food data and create CombinedLog for preview
            let loggedFoodItem = try createLoggedFoodItemFromResponse(foodDict: foodDict)
            
            return CombinedLog(
                type: .food,
                status: "success",
                calories: loggedFoodItem.calories,
                message: "Food analyzed successfully",
                foodLogId: nil, // No logging in preview mode
                food: loggedFoodItem,
                mealType: mealType,
                mealLogId: nil,
                meal: nil,
                mealTime: nil,
                scheduledAt: Date(),
                recipeLogId: nil,
                recipe: nil,
                servingsConsumed: nil
            )
        }
    }
    
    /// Helper method to create LoggedFoodItem from response dictionary
    private func createLoggedFoodItemFromResponse(
        foodDict: [String: Any],
        fallbackHealthAnalysis: [String: Any]? = nil
    ) throws -> LoggedFoodItem {
        let fdcId = foodDict["fdcId"] as? Int ?? 0
        let description = foodDict["description"] as? String ?? "Unknown Food"
        let brandName = foodDict["brandName"] as? String
        let servingSize = foodDict["servingSize"] as? Double ?? 1
        let servingSizeUnit = foodDict["servingSizeUnit"] as? String ?? "serving"
        let householdServingFullText = foodDict["householdServingFullText"] as? String
        let numberOfServings = foodDict["numberOfServings"] as? Double ?? 1
        
        // Extract nutrition from foodNutrients array
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var foodNutrients: [Nutrient] = []
        
        if let nutrients = foodDict["foodNutrients"] as? [[String: Any]] {
            for nutrient in nutrients {
                let name = nutrient["nutrientName"] as? String ?? ""
                let value = nutrient["value"] as? Double ?? 0
                let unit = nutrient["unitName"] as? String ?? ""
                
                // Create Nutrient object
                foodNutrients.append(Nutrient(
                    nutrientName: name,
                    value: value,
                    unitName: unit
                ))
                
                // Extract key macros
                switch name {
                case "Energy": calories = value
                case "Protein": protein = value
                case "Carbohydrate, by difference": carbs = value
                case "Total lipid (fat)": fat = value
                default: break
                }
            }
        }
        
        let aiInsight = foodDict["ai_insight"] as? String
        let nutritionScore: Double? = {
            if let value = foodDict["nutrition_score"] as? Double {
                return value
            }
            if let value = foodDict["nutrition_score"] as? NSNumber {
                return value.doubleValue
            }
            if let value = foodDict["nutrition_score"] as? String,
               let double = Double(value) {
                return double
            }
            return nil
        }()

        // Extract health analysis
        var healthAnalysis: HealthAnalysis?
        if let healthDict = foodDict["health_analysis"] as? [String: Any] {
            do {
                let healthData = try JSONSerialization.data(withJSONObject: healthDict)
                healthAnalysis = try JSONDecoder().decode(HealthAnalysis.self, from: healthData)
            } catch {
                print("⚠️ Failed to decode health analysis: \(error)")
            }
        } else if let fallbackDict = fallbackHealthAnalysis {
            do {
                let healthData = try JSONSerialization.data(withJSONObject: fallbackDict)
                healthAnalysis = try JSONDecoder().decode(HealthAnalysis.self, from: healthData)
            } catch {
                print("⚠️ Failed to decode fallback health analysis: \(error)")
            }
        }
        
        return LoggedFoodItem(
            foodLogId: nil,
            fdcId: fdcId,
            displayName: description,
            calories: calories,
            servingSizeText: householdServingFullText ?? "\(servingSize) \(servingSizeUnit)",
            numberOfServings: numberOfServings,
            brandText: brandName,
            protein: protein,
            carbs: carbs,
            fat: fat,
            healthAnalysis: healthAnalysis,
            foodNutrients: foodNutrients.isEmpty ? nil : foodNutrients,
            aiInsight: aiInsight,
            nutritionScore: nutritionScore,
            mealItems: decodeMealItems(from: foodDict)
        )
    }

    private func decodeMealItems(from foodDict: [String: Any]) -> [MealItem]? {
        guard let rawItems = foodDict["meal_items"] as? [[String: Any]] ?? foodDict["mealItems"] as? [[String: Any]],
              !rawItems.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: rawItems)
        else { return nil }

        return try? JSONDecoder().decode([MealItem].self, from: data)
    }

    
    init() {
        self.networkManager = NetworkManager()
    }

    // MARK: Streaming helper pass-through
    @discardableResult
    func streamAIResponse(
        messages: [[String: Any]],
        model: String = "gpt-5.1",
        temperature: Double = 0.3,
        onDelta: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) -> UUID? {
        return networkManager.streamAIResponse(
            messages: messages,
            model: model,
            temperature: temperature,
            onDelta: onDelta,
            onComplete: onComplete,
            onError: onError
        )
    }

    func cancelStream(token: UUID) {
        networkManager.cancelStream(token: token)
    }
    
    
    func initialize(userEmail: String) {
        initialize(userEmail: userEmail, force: false)
    }

    func initialize(userEmail: String, force: Bool) {
        if !force,
           let lastEmail = lastInitializedEmail,
           lastEmail == userEmail,
           let lastRefreshDate = lastRefreshDate,
           Date().timeIntervalSince(lastRefreshDate) < refreshInterval {
            return
        }

        lastInitializedEmail = userEmail
        lastRefreshDate = Date()

        if force {
            lastMealsFetchDate = nil
            lastRecipesFetchDate = nil
            lastCombinedLogsFetchDate = nil
            lastUserFoodsFetchDate = nil
            lastSavedMealsFetchDate = nil
        }

        print("🏁 FoodManager: Initializing with email \(userEmail)")
        self.userEmail = userEmail

        configureFeedRepository(for: userEmail)
        configureDataRepositories(for: userEmail)

        for key in UserDefaults.standard.dictionaryRepresentation().keys
        where key.hasPrefix("logs_by_date_\(userEmail)_") {
            UserDefaults.standard.removeObject(forKey: key)
        }

        print("📋 FoodManager: Starting initialization sequence")
        resetAndFetchFoods(force: force)
        resetAndFetchMeals(force: force)
        resetAndFetchRecipes(force: force)
        resetAndFetchLogs(force: force)
        resetAndFetchUserFoods(force: force)
        resetAndFetchSavedMeals(force: force)
    }

    func refresh(userEmail: String) {
        initialize(userEmail: userEmail, force: true)
    }
    func trackRecentlyAdded(foodId: Int) {
    recentlyAddedFoodIds.insert(foodId)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        self.recentlyAddedFoodIds.remove(foodId)
        }
    }




    private func configureFeedRepository(for email: String) {
        feedRepository.configure(email: email)
        feedCancellables.removeAll()

        feedRepository.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.applyFoodFeedSnapshot(snapshot)
            }
            .store(in: &feedCancellables)

        applyFoodFeedSnapshot(feedRepository.snapshot)
    }

    private func applyFoodFeedSnapshot(_ snapshot: FoodFeedSnapshot) {
        loggedFoods = snapshot.loggedFoods
        hasMore = snapshot.hasMoreFoods
    }

    private func configureDataRepositories(for email: String) {
        repositoryCancellables.removeAll()

        combinedLogsRepository.configure(email: email)
        applyCombinedLogsSnapshot(combinedLogsRepository.snapshot)

        combinedLogsRepository.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.applyCombinedLogsSnapshot(snapshot)
            }
            .store(in: &repositoryCancellables)

        Publishers.CombineLatest(
            combinedLogsRepository.$isRefreshing,
            combinedLogsRepository.$isLoadingNextPage
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isRefreshing, isPaging in
            self?.isLoadingLogs = isRefreshing
            self?.isLoadingMoreLogs = isPaging
        }
        .store(in: &repositoryCancellables)

        mealsRepository.configure(email: email)
        applyMealsSnapshot(mealsRepository.snapshot)

        mealsRepository.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.applyMealsSnapshot(snapshot)
            }
            .store(in: &repositoryCancellables)

        mealsRepository.$isRefreshing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRefreshing in
                self?.isLoadingMeals = isRefreshing
            }
            .store(in: &repositoryCancellables)

        mealsRepository.$isLoadingNextPage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPaging in
                self?.isLoadingMealPage = isPaging
            }
            .store(in: &repositoryCancellables)

        recipesRepository.configure(email: email)
        applyRecipesSnapshot(recipesRepository.snapshot)

        recipesRepository.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.applyRecipesSnapshot(snapshot)
            }
            .store(in: &repositoryCancellables)

        Publishers.CombineLatest(
            recipesRepository.$isRefreshing,
            recipesRepository.$isLoadingNextPage
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isRefreshing, isPaging in
            self?.isLoadingRecipePage = isRefreshing || isPaging
        }
        .store(in: &repositoryCancellables)

        savedMealsRepository.configure(email: email)
        applySavedMealsSnapshot(savedMealsRepository.snapshot)

        savedMealsRepository.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.applySavedMealsSnapshot(snapshot)
            }
            .store(in: &repositoryCancellables)

        Publishers.CombineLatest(
            savedMealsRepository.$isRefreshing,
            savedMealsRepository.$isLoadingNextPage
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isRefreshing, isPaging in
            self?.isLoadingSavedMeals = isRefreshing || isPaging
        }
        .store(in: &repositoryCancellables)

        userFoodsRepository.configure(email: email)
        applyUserFoodsSnapshot(userFoodsRepository.snapshot)

        userFoodsRepository.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.applyUserFoodsSnapshot(snapshot)
            }
            .store(in: &repositoryCancellables)

        Publishers.CombineLatest(
            userFoodsRepository.$isRefreshing,
            userFoodsRepository.$isLoadingNextPage
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isRefreshing, isPaging in
            self?.isLoadingUserFoods = isRefreshing || isPaging
        }
        .store(in: &repositoryCancellables)
    }

    private func applyCombinedLogsSnapshot(_ snapshot: CombinedLogsSnapshot) {
        combinedLogs = snapshot.logs
        hasMore = snapshot.hasMore
        currentPage = snapshot.nextPage
    }

    private func applyMealsSnapshot(_ snapshot: MealsSnapshot) {
        meals = snapshot.meals
        hasMoreMeals = snapshot.hasMore
        currentMealPage = snapshot.nextPage
    }

    private func applyRecipesSnapshot(_ snapshot: RecipesSnapshot) {
        recipes = snapshot.recipes
        hasMoreRecipes = snapshot.hasMore
        currentRecipePage = snapshot.nextPage
    }

    private func applySavedMealsSnapshot(_ snapshot: SavedMealsSnapshot) {
        savedMeals = snapshot.savedMeals
        hasMoreSavedMeals = snapshot.hasMore
        currentSavedMealsPage = snapshot.nextPage
        rebuildSavedLogIds(from: snapshot.savedMeals)
    }

    private func applyUserFoodsSnapshot(_ snapshot: UserFoodsSnapshot) {
        userFoods = snapshot.foods
        hasMoreUserFoods = snapshot.hasMore
        currentUserFoodsPage = snapshot.nextPage
    }

    private func rebuildSavedLogIds(from savedMeals: [SavedMeal]) {
        savedLogIds.removeAll()
        for savedMeal in savedMeals {
            switch savedMeal.itemType {
            case .foodLog:
                if let foodLog = savedMeal.foodLog, let id = foodLog.foodLogId {
                    savedLogIds.insert(id)
                }
            case .mealLog:
                if let mealLog = savedMeal.mealLog, let id = mealLog.mealLogId {
                    savedLogIds.insert(id)
                }
            }
        }
    }

    private func resetAndFetchFoods(force: Bool = false) {
        print("🍔 FoodManager: Reset and fetch foods called")
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshFoods(force: force)
        }
    }
    private func resetAndFetchLogs(force: Bool = false) {
        guard !isFetchingCombinedLogs else { return }
        isFetchingCombinedLogs = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            let success = await self.combinedLogsRepository.refresh(force: force)
            if success {
                self.lastCombinedLogsFetchDate = Date()
                self.lastRefreshTime = Date()
            }
            self.isFetchingCombinedLogs = false
        }
    }
    
func loadMoreFoods(refresh: Bool = false) {
    guard userEmail != nil else { return }

    Task { @MainActor [weak self] in
        guard let self else { return }
        if refresh {
            await self.refreshFoods(force: true)
        } else {
            await self.loadNextFoodsPage()
        }
    }
}

    private func refreshFoods(force: Bool) async {
        guard !feedRepository.isRefreshing else { return }
        isLoadingFood = true
        let success = await feedRepository.refresh(force: force)
        isLoadingFood = false
        if success {
            hasMore = feedRepository.snapshot.hasMoreFoods
            lastRefreshTime = Date()
        }
    }

    private func loadNextFoodsPage() async {
        guard feedRepository.snapshot.hasMoreFoods else { return }
        guard !feedRepository.isLoadingNextPage else { return }
        isLoadingFood = true
        let success = await feedRepository.loadNextPage()
        isLoadingFood = false
        if success {
            hasMore = feedRepository.snapshot.hasMoreFoods
            lastRefreshTime = Date()
        }
    }
func loadMoreLogs(refresh: Bool = false, completion: ((Bool) -> Void)? = nil) {
    guard userEmail != nil else {
        completion?(false)
        return
    }

    Task { @MainActor [weak self] in
        guard let self else {
            await MainActor.run { completion?(false) }
            return
        }
        let success = await self.performLoadMoreLogs(refresh: refresh)
        await MainActor.run {
            completion?(success)
        }
    }
}

private func performLoadMoreLogs(refresh: Bool) async -> Bool {
    if refresh {
        guard !combinedLogsRepository.isRefreshing else { return false }

        let success = await combinedLogsRepository.refresh(force: true)
        if success {
            lastCombinedLogsFetchDate = Date()
            lastRefreshTime = Date()
            hasMore = combinedLogsRepository.snapshot.hasMore
            currentPage = combinedLogsRepository.snapshot.nextPage
        }
        return success
    } else {
        guard hasMore else { return false }
        guard !combinedLogsRepository.isLoadingNextPage else { return false }

        let success = await combinedLogsRepository.loadNextPage()
        hasMore = combinedLogsRepository.snapshot.hasMore
        currentPage = combinedLogsRepository.snapshot.nextPage
        if success {
            lastCombinedLogsFetchDate = Date()
            lastRefreshTime = Date()
        }
        return success
    }
}

    // New refresh function that ensures logs are loaded
    func refresh() {
        print("🔄 FoodManager.refresh() called")
        
        // Prevent refresh if loading, analyzing food, etc.
        if isLoadingLogs || isLoadingMoreLogs || isLoadingMeals || isScanningFood || isAnalyzingFood || isGeneratingMeal || isGeneratingFood {
            print("⚠️ Skipping refresh because another operation is in progress")
            return
        }

        lastMealsFetchDate = nil
        lastRecipesFetchDate = nil
        lastCombinedLogsFetchDate = nil
        lastUserFoodsFetchDate = nil
        lastSavedMealsFetchDate = nil

        resetAndFetchMeals(force: true)
        resetAndFetchRecipes(force: true)
        resetAndFetchLogs(force: true)
        resetAndFetchUserFoods(force: true)
        resetAndFetchSavedMeals(force: true)
    }
    
    // MARK: - User Foods Methods
    
    func clearUserFoodsCache() {
        userFoodsRepository.clear()
        lastUserFoodsFetchDate = nil
    }
    
    // Load user foods with pagination
    func loadUserFoods(refresh: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard userEmail != nil else {
            completion?(false)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                await MainActor.run { completion?(false) }
                return
            }

            if refresh {
                guard !self.userFoodsRepository.isRefreshing else {
                    await MainActor.run { completion?(false) }
                    return
                }

                let success = await self.userFoodsRepository.refresh(force: true)
                if success {
                    self.lastUserFoodsFetchDate = Date()
                    self.hasMoreUserFoods = self.userFoodsRepository.snapshot.hasMore
                    self.currentUserFoodsPage = self.userFoodsRepository.snapshot.nextPage
                }
                await MainActor.run { completion?(success) }
            } else {
                guard self.hasMoreUserFoods else {
                    await MainActor.run { completion?(false) }
                    return
                }
                guard !self.userFoodsRepository.isLoadingNextPage else {
                    await MainActor.run { completion?(false) }
                    return
                }

                let success = await self.userFoodsRepository.loadNextPage()
                self.hasMoreUserFoods = self.userFoodsRepository.snapshot.hasMore
                self.currentUserFoodsPage = self.userFoodsRepository.snapshot.nextPage
                if success {
                    self.lastUserFoodsFetchDate = Date()
                }
                await MainActor.run { completion?(success) }
            }
        }
    }
    
    // Method to reset user foods and fetch fresh
    func resetAndFetchUserFoods(force: Bool = false) {
        print("🍎 FoodManager: Reset and fetch user foods called")
        guard !isFetchingUserFoods else { return }
        isFetchingUserFoods = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            let success = await self.userFoodsRepository.refresh(force: force)
            if success {
                self.lastUserFoodsFetchDate = Date()
                self.hasMoreUserFoods = self.userFoodsRepository.snapshot.hasMore
                self.currentUserFoodsPage = self.userFoodsRepository.snapshot.nextPage
            }
            self.isFetchingUserFoods = false
        }
    }

    func updateFoodLog(
        logId: Int,
        servings: Double? = nil,
        date: Date? = nil,
        mealType: String? = nil,
        notes: String? = nil,
        completion: @escaping (Result<UpdatedFoodLog, Error>) -> Void
    ) {
        guard let email = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        
        networkManager.updateFoodLog(
            userEmail: email,
            logId: logId,
            servings: servings,
            date: date,
            mealType: mealType,
            notes: notes
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let updatedLog):
                    print("✅ Successfully updated food log with ID: \(logId)")
                    
                    // Update the existing log in combinedLogs
                    if let index = self.combinedLogs.firstIndex(where: { $0.foodLogId == logId }) {
                        var updatedCombinedLog = self.combinedLogs[index]
                        
                        // Update the properties with new values
                        updatedCombinedLog.calories = updatedLog.calories
                        updatedCombinedLog.food?.numberOfServings = updatedLog.servings
                        
                        // Update message if meal type changed
                        if let newMealType = mealType {
                            updatedCombinedLog.message = "\(updatedLog.food.displayName) – \(newMealType)"
                            updatedCombinedLog.mealType = newMealType
                        }
                        
                        // Update scheduled date if changed
                        if let newDate = date {
                            updatedCombinedLog.scheduledAt = newDate
                        }
                        
                        self.combinedLogs[index] = updatedCombinedLog
                    }
                    
                    completion(.success(updatedLog))
                    
                case .failure(let error):
                    print("❌ Failed to update food log: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func logFood(
    email: String,
    food: Food,
    meal: String,
    servings: Double,
    date: Date,
    notes: String? = nil,
    skipCoach: Bool = false,
    batchContext: [String: Any]? = nil,
    completion: @escaping (Result<LoggedFood, Error>) -> Void
) {
    print("⏳ Starting logFood operation...")
    isLoadingFood = true

    // First, mark this as the last logged food ID to update UI appearance
    self.lastLoggedFoodId = food.fdcId

    // Only await coach message if we're not skipping it (i.e., this is the last item in a batch or a single item)
    if !skipCoach {
        self.isAwaitingCoachMessage = true
        self.lastCoachMessage = nil  // Clear previous coach message
    }

    // REMOVED: Check for existing logs - no longer needed as we'll wait for server response

            networkManager.logFood(
        userEmail: email,
        food: food,
        mealType: meal,
        servings: servings,
        date: date,
        notes: notes,
        skipCoach: skipCoach,
        batchContext: batchContext
    ) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            self.isLoadingFood = false
            
            switch result {
            case .success(let loggedFood):
                print("✅ Successfully logged food with foodLogId: \(loggedFood.foodLogId)")

                // Store coach message if present and stop awaiting
                self.isAwaitingCoachMessage = false
                self.awaitingCoachForFoodLogId = loggedFood.foodLogId
                if let coachMessage = loggedFood.coach {
                    self.lastCoachMessage = coachMessage
                  
                }

                // Mixpanel tracking removed - now handled by backend

                // Create a new CombinedLog from the logged food
                let combinedLog = CombinedLog(
                    type: .food,
                    status: "success",
                    calories: Double(loggedFood.food.calories),
                    message: "\(loggedFood.food.displayName) - \(loggedFood.mealType)",
                    foodLogId: loggedFood.foodLogId,
                    food: loggedFood.food,
                    mealType: loggedFood.mealType,
                    mealLogId: nil,
                    meal: nil,
                    mealTime: nil,
                    // scheduledAt: Date(),
                    scheduledAt: date,
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil
                )
                
                // Ensure all @Published property updates happen on main thread
                DispatchQueue.main.async {
                    // Track the food in recently added - fdcId is non-optional
                    self.lastLoggedFoodId = food.fdcId
                    self.trackRecentlyAdded(foodId: food.fdcId)
                    
                    // Set data for success toast in dashboard
                    self.lastLoggedItem = (name: food.displayName, calories: Double(loggedFood.food.calories))
                    self.showLogSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showLogSuccess = false
                    }
                    
                    // Trigger review check after successful food log
                    ReviewManager.shared.foodWasLogged()
                    
                    // Track meal timing for smart reminders
                    MealReminderService.shared.mealWasLogged(mealType: loggedFood.mealType)
                    
                    // Show the local toast if the food was added manually (not AI generated)
                    if !self.isAnalyzingFood {
                        self.showToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.showToast = false
                        }
                    }
                }
                
                // Clear the lastLoggedFoodId after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        // Only clear if it still matches the food we logged
                        if self.lastLoggedFoodId == food.fdcId {
                            self.lastLoggedFoodId = nil
                        }
                    }
                }
                
                completion(.success(loggedFood))
                
            case .failure(let error):
                print("❌ Failed to log food: \(error)")
                self.error = error
                self.isAwaitingCoachMessage = false  // Stop awaiting on error

                // Clear the lastLoggedFoodId immediately on error
                withAnimation {
                    // Only clear if it still matches the food we tried to log
                    if self.lastLoggedFoodId == food.fdcId {
                        self.lastLoggedFoodId = nil
                    }
                }

                completion(.failure(error))
            }
        }
    }
}
    func loadMoreIfNeeded(food: LoggedFood) {
        guard let index = loggedFoods.firstIndex(where: { $0.id == food.id }) else { return }
        guard index == loggedFoods.count - 5 else { return }
        guard feedRepository.snapshot.hasMoreFoods else { return }
        guard !feedRepository.isLoadingNextPage else { return }
        loadMoreFoods()
    }
    // Update the existing function to handle CombinedLog
func loadMoreIfNeeded(log: CombinedLog) {
    // Try to find the log's index
    let index = combinedLogs.firstIndex(where: { $0.id == log.id })
    
    // Debug output to track why loadMoreIfNeeded might not be triggering
    if let idx = index {
        // The problem with just checking if index is >= count - 10 is that
        // we might trigger loading on logs in the middle of the list if logs
        // are added/removed. We should check both:
        // 1. If this is a high-numbered index (near the end)
        // 2. If there are few logs after this one
        let isNearEndByNumber = idx >= combinedLogs.count - 10
        let isNearEndByPosition = (combinedLogs.count - idx) <= 10
        let shouldLoadMore = isNearEndByNumber || isNearEndByPosition
        
        print("🔍 FoodManager.loadMoreIfNeeded - Log at index \(idx) of \(combinedLogs.count)")
        print("  - Near end by number: \(isNearEndByNumber)")
        print("  - Near end by position: \(isNearEndByPosition)")
        print("  - Should load more: \(shouldLoadMore)")
        print("  - hasMore: \(hasMore)")
        
        // Check if we're near the end AND there are more logs to load
        if shouldLoadMore && hasMore && !isLoadingLogs {
            print("🎯 FoodManager.loadMoreIfNeeded - Triggering loadMoreLogs() at index \(idx)")
            loadMoreLogs()
        } else if !hasMore {
            print("⚠️ FoodManager.loadMoreIfNeeded - Not loading more because hasMore is false")
        } else if isLoadingLogs {
            print("⏳ FoodManager.loadMoreIfNeeded - Not loading more because already loading")
        } else {
            print("⏱️ FoodManager.loadMoreIfNeeded - Not near end yet (\(combinedLogs.count - idx) items remaining)")
        }
    } else {
        print("❓ FoodManager.loadMoreIfNeeded - Log not found in combinedLogs (id: \(log.id))")
    }
    
    // Add a fallback check - if we're at least 2/3 through the list,
    // check if we should load more regardless of exact index
    if combinedLogs.count >= 9 && hasMore && !isLoadingLogs {
        // As a safety measure, trigger loading more logs if we're getting near the end
        // even if the specific index check didn't pass
        print("🔄 FoodManager.loadMoreIfNeeded - Safety check: ensuring we have enough logs")
        loadMoreLogs()
    }
}
func createMeal(
    title: String,
    description: String?,
    directions: String?,
    privacy: String,
    servings: Int,
    foods: [Food],
    image: String?,
    totalCalories: Double?,
    totalProtein: Double?,
    totalCarbs: Double?,
    totalFat: Double?
) {
    guard let email = userEmail else { return }
    
    // Use provided totals or calculate if not provided
    let calculatedCalories = totalCalories ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.calories ?? 0) * servings)
    }
    
    // Calculate macros if not provided
    let calculatedProtein = totalProtein ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.protein ?? 0) * servings)
    }
    
    let calculatedCarbs = totalCarbs ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.carbs ?? 0) * servings)
    }
    
    let calculatedFat = totalFat ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.fat ?? 0) * servings)
    }
    
    
    networkManager.createMeal(
        userEmail: email,
        title: title,
        description: description,
        directions: directions,
        privacy: privacy,
        servings: servings,
        foods: foods,
        image: image,
        totalCalories: calculatedCalories,
        totalProtein: calculatedProtein,
        totalCarbs: calculatedCarbs,
        totalFat: calculatedFat
    ) { [weak self] result in
        DispatchQueue.main.async {
            switch result {
            case .success(let meal):
                print("✅ Meal created successfully: \(meal.title)")
                print("📊 Returned meal calories: \(meal.calories)")
                print("📊 Meal has \(meal.mealItems.count) food items")
                
                self?.meals.insert(meal, at: 0)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.mealsRepository.refresh(force: true)
                }
                
                // Show toast notification
                withAnimation {
                    self?.showMealToast = true
                }
                
                // Hide toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        self?.showMealToast = false
                    }
                }
            case .failure(let error):
                print("❌ Error creating meal: \(error)")
            }
        }
    }
}
private func resetAndFetchMeals(force: Bool = false) {
    print("🍲 FoodManager: Reset and fetch meals called")
    guard !isFetchingMeals else { return }
    isFetchingMeals = true

    Task { @MainActor [weak self] in
        guard let self else { return }
        let success = await self.mealsRepository.refresh(force: force)
        if success {
            print("✅ FoodManager: Successfully loaded meals from server")
            self.prefetchMealImages()
            self.lastMealsFetchDate = Date()
            self.hasMoreMeals = self.mealsRepository.snapshot.hasMore
            self.currentMealPage = self.mealsRepository.snapshot.nextPage
        } else {
            print("❌ FoodManager: Failed to load meals from server")
        }
        self.isFetchingMeals = false
    }
}
// Update loadMoreMeals to include a completion handler
func loadMoreMeals(refresh: Bool = false, completion: ((Bool) -> Void)? = nil) {
    guard userEmail != nil else {
        completion?(false)
        return
    }

    Task { @MainActor [weak self] in
        guard let self else {
            await MainActor.run { completion?(false) }
            return
        }

        if refresh {
            guard !self.mealsRepository.isRefreshing else {
                await MainActor.run { completion?(false) }
                return
            }

            let success = await self.mealsRepository.refresh(force: true)
            if success {
                self.lastMealsFetchDate = Date()
                self.prefetchMealImages()
                self.hasMoreMeals = self.mealsRepository.snapshot.hasMore
                self.currentMealPage = self.mealsRepository.snapshot.nextPage
            }
            await MainActor.run { completion?(success) }
        } else {
            guard self.hasMoreMeals else {
                await MainActor.run { completion?(false) }
                return
            }
            guard !self.mealsRepository.isLoadingNextPage else {
                await MainActor.run { completion?(false) }
                return
            }

            let success = await self.mealsRepository.loadNextPage()
            self.hasMoreMeals = self.mealsRepository.snapshot.hasMore
            self.currentMealPage = self.mealsRepository.snapshot.nextPage
            if success {
                self.lastMealsFetchDate = Date()
            }
            await MainActor.run { completion?(success) }
        }
    }
}

func loadMoreMealsIfNeeded(meal: Meal) {
    guard let index = meals.firstIndex(where: { $0.id == meal.id }) else { return }
    guard index == meals.count - 5 else { return }
    guard hasMoreMeals else { return }
    loadMoreMeals()
}
func refreshMeals() {
    lastMealsFetchDate = nil
    resetAndFetchMeals(force: true)
}

 func logMeal(
        meal: Meal,
        mealTime: String,
        date: Date = Date(),
        notes: String? = nil,
        calories: Double,
        completion: ((Result<LoggedMeal, Error>) -> Void)? = nil,
        statusCompletion: ((Bool) -> Void)? = nil
    ) {
         guard let email = userEmail else { return }

        // basic UI flags so the plus button flashes green
        lastLoggedMealId   = meal.id
        isLoadingMeal      = true
        showMealLoggedToast = true

        networkManager.logMeal(
            userEmail: email,
            mealId:    meal.id,
            mealTime:  mealTime,
            date:      date,
            notes:     notes,
            calories:  calories
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                // reset simple loading flags
                self.isLoadingMeal = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showMealLoggedToast = false
                    self.lastLoggedMealId = nil
                }



                switch result {
                case .success(let logged):
                    // caller will build CombinedLog & update DayLogsVM
                    completion?(.success(logged))

                                    self.lastLoggedItem = (name: meal.title, calories: calories)
                self.showLogSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showLogSuccess = false
                }
                
                // Show the local toast
                self.showToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showToast = false
                }

              
                
                // Clear the flag and toast after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        // Only clear if it still matches the meal we logged
                        if self.lastLoggedMealId == meal.id {
                            self.lastLoggedMealId = nil
                        }
                        self.showMealLoggedToast = false
                    }
                }
                    statusCompletion?(true)

                case .failure(let error):
                    self.error = error
                    completion?(.failure(error))
                    statusCompletion?(false)
                }
            }
        }
    }

func prefetchMealImages() {
    for meal in meals {
        if let imageUrlString = meal.image, let imageUrl = URL(string: imageUrlString) {
            // Create a URLSession task to prefetch the image
            let task = URLSession.shared.dataTask(with: imageUrl) { _, _, _ in
                // Image is now cached by the system
            }
            task.resume()
        }
    }
}
// Simple helper to ensure no duplicate log IDs
private func uniqueCombinedLogs(from logs: [CombinedLog]) -> [CombinedLog] {
    var seenFoodLogIds = Set<Int>()
    var seenMealLogIds = Set<Int>()
    var seenRecipeLogIds = Set<Int>()
    var seenWorkoutLogIds = Set<Int>()
    var uniqueLogs: [CombinedLog] = []
    
    for log in logs {
        var isUnique = false
        
        switch log.type {
        case .food:
            if let foodLogId = log.foodLogId, !seenFoodLogIds.contains(foodLogId) {
                seenFoodLogIds.insert(foodLogId)
                isUnique = true
            }
        case .meal:
            if let mealLogId = log.mealLogId, !seenMealLogIds.contains(mealLogId) {
                seenMealLogIds.insert(mealLogId)
                isUnique = true
            }
        case .recipe:
            if let recipeLogId = log.recipeLogId, !seenRecipeLogIds.contains(recipeLogId) {
                seenRecipeLogIds.insert(recipeLogId)
                isUnique = true
            }
        case .activity:
            // Activity logs are always unique since they come from Apple Health
            isUnique = true
        case .workout:
            if let workoutLogId = log.workoutLogId, !seenWorkoutLogIds.contains(workoutLogId) {
                seenWorkoutLogIds.insert(workoutLogId)
                isUnique = true
            }
        }
        
        if isUnique {
            uniqueLogs.append(log)
        }
    }
    
    return uniqueLogs
}
func updateMeal(
    meal: Meal,
    foods: [Food] = [],
    completion: ((Result<Meal, Error>) -> Void)? = nil
) {
    guard let email = userEmail else { 
        completion?(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
        return 
    }
    
    print("🔄 updateMeal called with meal ID: \(meal.id), title: \(meal.title), foods count: \(foods.count)")
    
    // If foods array is not empty, use it to calculate macros
    // Otherwise use the meal's existing values
    let calculatedCalories: Double
    let calculatedProtein: Double
    let calculatedCarbs: Double
    let calculatedFat: Double
    
    if !foods.isEmpty {
        // Calculate totals from foods (matching createMeal logic)
        calculatedCalories = meal.totalCalories ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.calories ?? 0) * servings)
        }
        
        calculatedProtein = meal.totalProtein ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.protein ?? 0) * servings)
        }
        
        calculatedCarbs = meal.totalCarbs ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.carbs ?? 0) * servings)
        }
        
        calculatedFat = meal.totalFat ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.fat ?? 0) * servings)
        }
        
    
        networkManager.updateMealWithFoods(
            userEmail: email,
            mealId: meal.id,
            title: meal.title,
            description: meal.description ?? "",
            directions: meal.directions,
            privacy: meal.privacy,
            servings: meal.servings,
            foods: foods,
            image: meal.image,
            totalCalories: calculatedCalories,
            totalProtein: calculatedProtein,
            totalCarbs: calculatedCarbs,
            totalFat: calculatedFat,
            scheduledAt: meal.scheduledAt
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedMeal):
                    print("✅ Meal updated successfully: \(updatedMeal.title) (ID: \(updatedMeal.id))")
                    
                    // Update the meals array if this meal exists in it
                    if let index = self?.meals.firstIndex(where: { $0.id == meal.id }) {
                        self?.meals[index] = updatedMeal
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            await self.mealsRepository.refresh(force: true)
                        }
                    } else {
                        print("ℹ️ Meal not found in meals array")
                    }
                    
                    // Update combined logs if this meal exists there
                    if let index = self?.combinedLogs.firstIndex(where: { 
                        $0.type == .meal && $0.meal?.mealId == meal.id 
                    }) {
                
                        if var log = self?.combinedLogs[index] {
                            // Create a new meal summary from the updated meal
                            do {
                                if let newLogWithUpdatedMeal = try self?.recreateLogWithUpdatedMeal(
                                    originalLog: log, 
                                    updatedMeal: MealSummary(
                                        mealId: updatedMeal.id,
                                        title: updatedMeal.title,
                                        description: updatedMeal.description,
                                        image: updatedMeal.image,
                                        calories: updatedMeal.calories,
                                        servings: updatedMeal.servings,
                                        protein: updatedMeal.totalProtein,
                                        carbs: updatedMeal.totalCarbs,
                                        fat: updatedMeal.totalFat,
                                        scheduledAt: updatedMeal.scheduledAt
                                    )
                                ) {
                                    self?.combinedLogs[index] = newLogWithUpdatedMeal
                                    print("✅ Successfully updated meal in combined logs")
                                } else {
                                    print("⚠️ Failed to create updated log entry")
                                }
                            } catch {
                                print("❌ Error recreating log with updated meal: \(error)")
                            }
                        }
                    } else {
                        print("ℹ️ Meal not found in combined logs")
                    }
                    
                    completion?(.success(updatedMeal))
                    
                case .failure(let error):
                    print("❌ Error updating meal with foods: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }
    } else {
        // Use the original updateMeal if no food items are provided
        // Use provided totals or calculate from meal items
        calculatedCalories = meal.totalCalories ?? meal.mealItems.reduce(0) { sum, item in
            return sum + item.calories
        }
        
        calculatedProtein = meal.totalProtein ?? meal.mealItems.reduce(0) { sum, item in
            return sum + (item.protein)
        }
        
        calculatedCarbs = meal.totalCarbs ?? meal.mealItems.reduce(0) { sum, item in
            return sum + (item.carbs)
        }
        
        calculatedFat = meal.totalFat ?? meal.mealItems.reduce(0) { sum, item in
            return sum + (item.fat)
        }
        
        networkManager.updateMeal(
            userEmail: email,
            mealId: meal.id,
            title: meal.title,
            description: meal.description ?? "",
            directions: meal.directions,
            privacy: meal.privacy,
            servings: meal.servings,
            image: meal.image,
            totalCalories: calculatedCalories,
            totalProtein: calculatedProtein,
            totalCarbs: calculatedCarbs,
            totalFat: calculatedFat,
            scheduledAt: meal.scheduledAt
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedMeal):
                    print("✅ Meal updated successfully: \(updatedMeal.title)")
                    
                    // Update the meals array if this meal exists in it
                    if let index = self?.meals.firstIndex(where: { $0.id == meal.id }) {
                        self?.meals[index] = updatedMeal
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            await self.mealsRepository.refresh(force: true)
                        }
                    }
                    
                    // Update combined logs if this meal exists there
                    if let index = self?.combinedLogs.firstIndex(where: { 
                        $0.type == .meal && $0.meal?.mealId == meal.id 
                    }), var log = self?.combinedLogs[index] {
                        // Create a new meal summary from the updated meal
                        if let newLogWithUpdatedMeal = try? self?.recreateLogWithUpdatedMeal(
                            originalLog: log, 
                            updatedMeal: MealSummary(
                                mealId: updatedMeal.id,
                                title: updatedMeal.title,
                                description: updatedMeal.description,
                                image: updatedMeal.image,
                                calories: updatedMeal.calories,
                                servings: updatedMeal.servings,
                                protein: updatedMeal.totalProtein,
                                carbs: updatedMeal.totalCarbs,
                                fat: updatedMeal.totalFat,
                                scheduledAt: updatedMeal.scheduledAt
                            )
                        ) {
                            self?.combinedLogs[index] = newLogWithUpdatedMeal
                        }
                    }
                    
                    completion?(.success(updatedMeal))
                    
                case .failure(let error):
                    print("❌ Error updating meal: \(error)")
                    completion?(.failure(error))
                }
            }
        }
    }
}
// Helper method to recreate a CombinedLog with an updated meal
private func recreateLogWithUpdatedMeal(originalLog: CombinedLog, updatedMeal: MealSummary) throws -> CombinedLog {
    return CombinedLog(
        type: originalLog.type,
        status: originalLog.status,
        calories: updatedMeal.displayCalories,
        message: "\(updatedMeal.title) - \(originalLog.mealTime ?? "")",
        foodLogId: originalLog.foodLogId,
        food: originalLog.food,
        mealType: originalLog.mealType,
        mealLogId: originalLog.mealLogId,
        meal: updatedMeal,
        mealTime: originalLog.mealTime,
        scheduledAt: updatedMeal.scheduledAt,
        recipeLogId: originalLog.recipeLogId,
        recipe: originalLog.recipe,
        servingsConsumed: originalLog.servingsConsumed
    )
}
// After the resetAndFetchRecipes method
private func resetAndFetchRecipes(force: Bool = false) {
    print("🍛 FoodManager: Reset and fetch recipes called")
    guard !isFetchingRecipes else { return }
    isFetchingRecipes = true

    Task { @MainActor [weak self] in
        guard let self else { return }
        let success = await self.recipesRepository.refresh(force: force)
        if success {
            self.lastRecipesFetchDate = Date()
            self.hasMoreRecipes = self.recipesRepository.snapshot.hasMore
            self.currentRecipePage = self.recipesRepository.snapshot.nextPage
        }
        self.isFetchingRecipes = false
    }
}
func loadMoreRecipes(refresh: Bool = false, completion: ((Bool) -> Void)? = nil) {
    guard userEmail != nil else {
        completion?(false)
        return
    }

    Task { @MainActor [weak self] in
        guard let self else {
            await MainActor.run { completion?(false) }
            return
        }

        if refresh {
            guard !self.recipesRepository.isRefreshing else {
                await MainActor.run { completion?(false) }
                return
            }

            let success = await self.recipesRepository.refresh(force: true)
            if success {
                self.lastRecipesFetchDate = Date()
                self.hasMoreRecipes = self.recipesRepository.snapshot.hasMore
                self.currentRecipePage = self.recipesRepository.snapshot.nextPage
            }
            await MainActor.run { completion?(success) }
        } else {
            guard self.hasMoreRecipes else {
                await MainActor.run { completion?(false) }
                return
            }
            guard !self.recipesRepository.isLoadingNextPage else {
                await MainActor.run { completion?(false) }
                return
            }

            let success = await self.recipesRepository.loadNextPage()
            self.hasMoreRecipes = self.recipesRepository.snapshot.hasMore
            self.currentRecipePage = self.recipesRepository.snapshot.nextPage
            if success {
                self.lastRecipesFetchDate = Date()
            }
            await MainActor.run { completion?(success) }
        }
    }
}

// Add this function after createMeal
func createRecipe(
    title: String,
    description: String? = nil,
    instructions: String? = nil,
    privacy: String,
    servings: Int,
    foods: [Food],
    image: String? = nil,
    prepTime: Int? = nil,
    cookTime: Int? = nil,
    totalCalories: Double? = nil,
    totalProtein: Double? = nil,
    totalCarbs: Double? = nil,
    totalFat: Double? = nil,
    completion: ((Result<Recipe, Error>) -> Void)? = nil
) {
    guard let email = userEmail else { return }
    
    // Use provided totals or calculate if not provided
    let calculatedCalories = totalCalories ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.calories ?? 0) * servings)
    }
    
    // Calculate macros if not provided
    let calculatedProtein = totalProtein ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.protein ?? 0) * servings)
    }
    
    let calculatedCarbs = totalCarbs ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.carbs ?? 0) * servings)
    }
    
    let calculatedFat = totalFat ?? foods.reduce(0) { sum, food in
        let servings = food.numberOfServings ?? 1
        return sum + ((food.fat ?? 0) * servings)
    }
    
    networkManager.createRecipe(
        userEmail: email,
        title: title,
        description: description,
        instructions: instructions,
        privacy: privacy,
        servings: servings,
        foods: foods,
        image: image,
        prepTime: prepTime,
        cookTime: cookTime,
        totalCalories: calculatedCalories,
        totalProtein: calculatedProtein,
        totalCarbs: calculatedCarbs,
        totalFat: calculatedFat
    ) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            
            switch result {
            case .success(let recipe):
                // Add the new recipe to our list
                withAnimation {
                    self.recipes.insert(recipe, at: 0)
                }
                
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.recipesRepository.refresh(force: true)
                }
                
                // Notify success
                completion?(.success(recipe))
                
            case .failure(let error):
                print("❌ Error creating recipe: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }
    }
}
// Add this function after logMeal
func logRecipe(
    recipe: Recipe,
    mealTime: String,
    date: Date,
    notes: String? = nil,
    calories: Double,
    completion: ((Result<LoggedRecipe, Error>) -> Void)? = nil,
    statusCompletion: ((Bool) -> Void)? = nil
) {
    guard let email = userEmail else { return }
    
    networkManager.logRecipe(
        userEmail: email,
        recipeId: recipe.id,
        mealTime: mealTime,
        date: date,
        notes: notes,
        calories: calories
    ) { [weak self] result in
        DispatchQueue.main.async {
            guard let self = self else { return }
            
            switch result {
            case .success(let recipeLog):
       
                
                // Update last logged recipe ID for UI feedback
                self.lastLoggedRecipeId = recipe.id
                
                // Set data for success toast in dashboard
                self.lastLoggedItem = (name: recipe.title, calories: calories)
                self.showLogSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showLogSuccess = false
                }
                
                // Call completion handlers
                completion?(.success(recipeLog))
                statusCompletion?(true)
                
            case .failure(let error):
                print("❌ Error logging recipe: \(error.localizedDescription)")
                completion?(.failure(error))
                statusCompletion?(false)
            }
        }
    }
}
// Add this function after updateMeal
func updateRecipe(
    recipe: Recipe,
    foods: [Food] = [],
    completion: ((Result<Recipe, Error>) -> Void)? = nil
) {
    guard let email = userEmail else { 
        completion?(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
        return 
    }
    
    print("🔄 updateRecipe called with recipe ID: \(recipe.id), title: \(recipe.title), foods count: \(foods.count)")
    
    // If foods array is not empty, use it to calculate macros
    // Otherwise use the recipe's existing values
    let calculatedCalories: Double
    let calculatedProtein: Double
    let calculatedCarbs: Double
    let calculatedFat: Double
    
    if !foods.isEmpty {
        // Calculate totals from foods
        calculatedCalories = recipe.totalCalories ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.calories ?? 0) * servings)
        }
        
        calculatedProtein = recipe.totalProtein ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.protein ?? 0) * servings)
        }
        
        calculatedCarbs = recipe.totalCarbs ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.carbs ?? 0) * servings)
        }
        
        calculatedFat = recipe.totalFat ?? foods.reduce(0) { sum, food in
            let servings = food.numberOfServings ?? 1
            return sum + ((food.fat ?? 0) * servings)
        }
        
        // Use updateRecipeWithFoods if we're changing the ingredients
        networkManager.updateRecipeWithFoods(
            userEmail: email,
            recipeId: recipe.id,
            title: recipe.title,
            description: recipe.description ?? "",
            instructions: recipe.instructions ?? "",
            privacy: recipe.privacy,
            servings: recipe.servings,
            foods: foods,
            image: recipe.image,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            totalCalories: calculatedCalories,
            totalProtein: calculatedProtein,
            totalCarbs: calculatedCarbs,
            totalFat: calculatedFat
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let updatedRecipe):
                    // Update the recipe in our list
                    if let index = self.recipes.firstIndex(where: { $0.id == updatedRecipe.id }) {
                        self.recipes[index] = updatedRecipe
                    }
                    
                    // Invalidate cache for recipe pages
                    for page in 1...9 {
                        UserDefaults.standard.removeObject(forKey: "recipes_\(email)_page_\(page)")
                    }
                    
                    // Notify success
                    completion?(.success(updatedRecipe))
                    
                case .failure(let error):
                    print("❌ Error updating recipe with foods: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }
    } else {
        // Use the original updateRecipe if no food items are provided
        // Use provided totals or calculate from recipe items
        calculatedCalories = recipe.totalCalories ?? recipe.recipeItems.reduce(0) { sum, item in
            return sum + item.calories
        }
        
        calculatedProtein = recipe.totalProtein ?? recipe.recipeItems.reduce(0) { sum, item in
            return sum + (item.protein)
        }
        
        calculatedCarbs = recipe.totalCarbs ?? recipe.recipeItems.reduce(0) { sum, item in
            return sum + (item.carbs)
        }
        
        calculatedFat = recipe.totalFat ?? recipe.recipeItems.reduce(0) { sum, item in
            return sum + (item.fat)
        }
        
        networkManager.updateRecipe(
            userEmail: email,
            recipeId: recipe.id,
            title: recipe.title,
            description: recipe.description ?? "",
            instructions: recipe.instructions ?? "",
            privacy: recipe.privacy,
            servings: recipe.servings,
            image: recipe.image,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            totalCalories: calculatedCalories,
            totalProtein: calculatedProtein,
            totalCarbs: calculatedCarbs,
            totalFat: calculatedFat
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let updatedRecipe):
                    // Update the recipe in our list
                    if let index = self.recipes.firstIndex(where: { $0.id == updatedRecipe.id }) {
                        self.recipes[index] = updatedRecipe
                    }
                    
                    // Invalidate cache for recipe pages
                    for page in 1...9 {
                        UserDefaults.standard.removeObject(forKey: "recipes_\(email)_page_\(page)")
                    }

                    // Notify success
                    completion?(.success(updatedRecipe))

                case .failure(let error):
                    print("❌ Error updating recipe: \(error)")
                    completion?(.failure(error))
                }
            }
        }
    }
}

func deleteRecipe(
    recipeId: Int,
    completion: ((Result<Void, Error>) -> Void)? = nil
) {
    guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
        print("❌ No user email found for delete recipe")
        completion?(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user email"])))
        return
    }

    networkManager.deleteRecipe(recipeId: recipeId, userEmail: email) { [weak self] result in
        DispatchQueue.main.async {
            switch result {
            case .success:
                // Remove recipe from local list
                self?.recipes.removeAll { $0.id == recipeId }

                // Refresh the repository
                Task {
                    await self?.recipesRepository.refresh(force: true)
                }

                print("✅ Recipe deleted successfully")
                completion?(.success(()))

            case .failure(let error):
                print("❌ Error deleting recipe: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }
    }
}

func importRecipe(
    url: String,
    completion: ((Result<Recipe, Error>) -> Void)? = nil
) {
    guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
        print("❌ No user email found for import recipe")
        completion?(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user email"])))
        return
    }

    print("📥 FoodManager: Importing recipe from URL: \(url)")

    networkManager.importRecipe(url: url, userEmail: email) { [weak self] result in
        DispatchQueue.main.async {
            switch result {
            case .success(let recipe):
                // Add the imported recipe to our list
                self?.recipes.insert(recipe, at: 0)

                // Refresh the repository
                Task {
                    await self?.recipesRepository.refresh(force: true)
                }

                print("✅ Recipe imported successfully: \(recipe.title)")
                completion?(.success(recipe))

            case .failure(let error):
                print("❌ Error importing recipe: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }
    }
}

// Update the generateMacrosWithAI method
@MainActor
func generateMacrosWithAI(foodDescription: String, mealType: String, completion: @escaping (Result<LoggedFood, Error>) -> Void) {
    print("🔍 DEBUG generateMacrosWithAI called - food: \(foodDescription), meal: \(mealType)")
    
    // UNIFIED: Start with proper 0% progress, then animate with smooth transitions
    updateFoodScanningState(.initializing)  // Start at 0% with animation
    isGeneratingMacros = true
    isLoading = true  // THIS was missing - needed to show the loading card!
    macroGenerationStage = 0
    
    // Animate to macro generation state after brief delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.updateFoodScanningState(.generatingMacros)  // Smooth animate to 50%
    }
    macroLoadingMessage = "Analyzing food description..."
    showAIGenerationSuccess = false
    
    print("🔍 DEBUG generateMacrosWithAI - Starting with initializing state for proper session flow")
    // CRITICAL FIX: Start with initializing state for proper 0% progress visibility
    updateFoodScanningState(.initializing)
    
    // Move directly to analyzing state without artificial timers to prevent shimmer glitches
    // The network response will drive real progress updates
    updateFoodScanningState(.analyzing)
    
    // Create a timer to cycle through analysis stages for UI feedback
    let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
        guard let self = self else { 
            timer.invalidate()
            return 
        }
        
        // CRITICAL FIX: Ensure all @Published updates happen on main thread
        DispatchQueue.main.async {
            // Cycle through macro generation stages 0-3
            self.macroGenerationStage = (self.macroGenerationStage + 1) % 4
            
            // Update loading message based on current stage
            self.macroLoadingMessage = [
                "Analyzing food description...",
                "Generating nutritional data...",
                "Calculating macros...",
                "Finalizing food creation..."
            ][self.macroGenerationStage]
        }
    }
    
    // Call the network manager to generate macros
    networkManager.generateMacrosWithAI(foodDescription: foodDescription, mealType: mealType) { [weak self] result in
        guard let self = self else { 
            timer.invalidate()
            return 
        }
        
        // Stop the timer
        timer.invalidate()
        
        switch result {
        case .success(let loggedFood):
            print("✅ AI macros generated successfully: \(loggedFood.food.displayName)")

            // Mixpanel tracking removed - now handled by backend

            self.aiGeneratedFood = loggedFood.food
            self.lastLoggedItem = (name: loggedFood.food.displayName, calories: loggedFood.food.calories ?? 0)
            
            // Create a CombinedLog object for the new food
            let combinedLog = CombinedLog(
                type: .food,
                status: loggedFood.status,
                calories: loggedFood.calories,
                message: loggedFood.message,
                foodLogId: loggedFood.foodLogId,
                food: loggedFood.food,
                mealType: loggedFood.mealType,
                mealLogId: nil,
                meal: nil,
                mealTime: nil,
                scheduledAt: Date(), // Set to current date to make it appear in today's logs
                recipeLogId: nil,
                recipe: nil,
                servingsConsumed: nil
            )
            
            // Track the food in recently added - fdcId is non-optional
            self.lastLoggedFoodId = loggedFood.food.fdcId
            self.trackRecentlyAdded(foodId: loggedFood.food.fdcId)
            
      
  
            // UNIFIED: Use proper updateFoodScanningState for smooth animation and auto-reset
            self.updateFoodScanningState(.completed(result: combinedLog))
            
            // Reset macro generation state and show success toast in dashboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // UNIFIED: Only reset legacy states - foodScanningState auto-resets from completed
                self.isGeneratingMacros = false
                self.isLoading = false  // Clear the loading flag
                self.macroGenerationStage = 0
                self.macroLoadingMessage = ""
                
                // Show success toast
                self.showAIGenerationSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showAIGenerationSuccess = false
                }
            }
            
            // Clear the lastLoggedFoodId after 2 seconds, similar to logFood()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    // Only clear if it still matches the food we logged
                    if self.lastLoggedFoodId == loggedFood.food.fdcId {
                        self.lastLoggedFoodId = nil
                    }
                }
            }
            
            // Call completion handler with success
            completion(.success(loggedFood))
            
        case .failure(let error):
            // UNIFIED: Use proper updateFoodScanningState for failure handling
            self.updateFoodScanningState(.failed(error: .networkError(error.localizedDescription)))
            
            // Reset both unified and legacy states after brief delay for failures
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.resetFoodScanningState()  // Reset unified state
                self.isGeneratingMacros = false
                self.isLoading = false  // Clear the loading flag
                self.macroGenerationStage = 0
                self.macroLoadingMessage = ""
            }
            
            // Handle error and pass it along
            completion(.failure(error))
        }
    }
}



func generateMealWithAI(mealDescription: String, mealType: String, completion: @escaping (Result<Meal, Error>) -> Void) {
    guard let email = userEmail else {
        completion(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
        return
    }
    
    // UNIFIED: Set modern state for meal generation (keeping legacy for backward compatibility)
    foodScanningState = .generatingMeal
    isGeneratingMeal = true
    mealGenerationStage = 0
    
    // Create a timer to cycle through stages for UI feedback
    let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
        guard let self = self else { 
            timer.invalidate()
            return 
        }
        
        // CRITICAL FIX: Ensure all @Published updates happen on main thread
        DispatchQueue.main.async {
            // Cycle through stages 0-3
            self.mealGenerationStage = (self.mealGenerationStage + 1) % 4
        }
    }
    
    // Make the API request
    networkManager.generateMealWithAI(mealDescription: mealDescription, mealType: mealType) { [weak self] result in
        guard let self = self else {
            timer.invalidate()
            return
        }
        
        // Stop the stage cycling timer
        timer.invalidate()
        
        // UNIFIED: Reset to inactive state (keeping legacy for backward compatibility)
        DispatchQueue.main.async {
            self.foodScanningState = .inactive
            self.isGeneratingMeal = false
            
            switch result {
            case .success(let meal):
                // Store the generated meal
                self.lastGeneratedMeal = meal
                
                // Add the meal to the meals list
                if self.meals.isEmpty {
                    self.meals = [meal]
                } else {
                    self.meals.insert(meal, at: 0)
                }
                
                // Show success toast immediately
                self.showMealGenerationSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showMealGenerationSuccess = false
                }
                
                // Call the completion handler
                completion(.success(meal))
                
            case .failure(let error):
                // Just forward the error
                completion(.failure(error))
            }
        }
    }
}

    func generateFoodWithAI(
    foodDescription: String,
    history: [[String: String]] = [],
    skipConfirmation: Bool = false,
    isBrandedHint: Bool = false,
    brandNameHint: String? = nil,
    completion: @escaping (Result<GenerateFoodResponse, Error>) -> Void
) {
    // UNIFIED: Set modern state for food generation (keeping legacy for backward compatibility)
    foodScanningState = .generatingFood
    isGeneratingFood = true
    foodGenerationStage = 0
    showFoodGenerationSuccess = false

    // Create a timer to cycle through stages for UI feedback
    let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
        guard let self = self else {
            timer.invalidate()
            return
        }

        // CRITICAL FIX: Ensure all @Published updates happen on main thread
        DispatchQueue.main.async {
            // Cycle through stages 0-3
            self.foodGenerationStage = (self.foodGenerationStage + 1) % 4
        }
    }

    // Make the API request
    networkManager.generateFoodWithAI(
        foodDescription: foodDescription,
        history: history,
        isBrandedHint: isBrandedHint,
        brandNameHint: brandNameHint
    ) { [weak self] result in
        guard let self = self else {
            timer.invalidate()
            return
        }
        
        // Stop the stage cycling timer
        timer.invalidate()
        
        // UNIFIED: Reset to inactive state (keeping legacy for backward compatibility)
        DispatchQueue.main.async {
            self.foodScanningState = .inactive
            self.isGeneratingFood = false
            
            switch result {
            case .success(let response):
                if let food = response.food {
                    if !skipConfirmation {
                        self.lastGeneratedFood = food
                    }
                    self.showFoodGenerationSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showFoodGenerationSuccess = false
                    }
                }
                completion(.success(response))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

    /// Food chat with orchestrator - uses AI function calling to decide when to log food
    /// This provides behavioral parity with voice mode where the AI decides to call log_food tool
    func foodChatWithOrchestrator(
        message: String,
        history: [[String: String]] = [],
        completion: @escaping (Result<FoodChatResponse, Error>) -> Void
    ) {
        networkManager.foodChatWithOrchestrator(
            message: message,
            history: history,
            completion: completion
        )
    }

    /// Streaming food chat with orchestrator - streams AI response token by token
    func foodChatWithOrchestratorStream(
        message: String,
        history: [[String: String]] = [],
        onDelta: @escaping (String) -> Void,
        onComplete: @escaping (Result<FoodChatResponse, Error>) -> Void
    ) {
        networkManager.foodChatWithOrchestratorStream(
            message: message,
            history: history,
            onDelta: onDelta,
            onComplete: onComplete
        )
    }

// Add the createManualFood function after the generateFoodWithAI function
// This is around line 1879 after the last function in the file
func createManualFood(food: Food, showPreview: Bool = true, completion: @escaping (Result<Food, Error>) -> Void) {
    // UNIFIED: Only set scanning state if not already in an active scanning flow
    let wasAlreadyScanning = foodScanningState.isActive
    if !wasAlreadyScanning {
        updateFoodScanningState(.initializing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateFoodScanningState(.generatingFood)
        }
        isGeneratingFood = true
        showFoodGenerationSuccess = false
    }
    
    guard let email = userEmail else {
        completion(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
        return
    }
    
    // Make the API request
    networkManager.createManualFood(userEmail: email, food: food) { [weak self] result in
        guard let self = self else {
            return
        }
        
        // UNIFIED: Only reset state if we were the ones who set it
        DispatchQueue.main.async {
            if !wasAlreadyScanning {
                // We started the scanning, so we should complete it properly
                self.isGeneratingFood = false
            }
            // If wasAlreadyScanning, don't interfere with the existing scanning flow
            
            switch result {
            case .success(let food):
                // Store the created food only if preview should be shown
                if showPreview {
                    self.lastGeneratedFood = food
                }
                
                // Add the food to userFoods so it appears in MyFoods tab immediately
                if !self.userFoods.contains(where: { $0.fdcId == food.fdcId }) {
                    self.userFoods.insert(food, at: 0) // Add to beginning of list
                }
                
                // Clear the userFoods cache to force refresh from server next time
                self.clearUserFoodsCache()
                
                // UNIFIED: Show completion if we started the scanning flow
                if !wasAlreadyScanning {
                    let completionLog = CombinedLog(
                        type: .food,
                        status: "success",
                        calories: food.calories ?? 0,
                        message: "Created \(food.displayName)",
                        foodLogId: nil
                    )
                    self.updateFoodScanningState(.completed(result: completionLog))
                }
                
                // Show success toast
                self.showFoodGenerationSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showFoodGenerationSuccess = false
                }
                
                // Call the completion handler
                completion(.success(food))
                
            case .failure(let error):
                // Forward the error
                completion(.failure(error))
            }
        }
    }
}
// Add these functions to the FoodManager class to handle deletion
    // Delete a food log
    func deleteFoodLog(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        let repo = LogRepository()
        repo.deleteLogItem(email: email, logId: id, logType: "food") { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.combinedLogs.removeAll { $0.foodLogId == id }
                    self.loggedFoods.removeAll { $0.foodLogId == id } // If still used
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }


    // Delete a food
    func deleteFood(id: Int, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        guard let email = userEmail else {
            print("⚠️ Cannot delete food: User email not set")
            completion(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        
        // Find the food in userFoods
        if let index = userFoods.firstIndex(where: { $0.fdcId == id }) {
            // Remove from local array first for immediate UI update
            let removedFood = userFoods.remove(at: index)
            
            // Call network manager to delete from server
            networkManager.deleteFood(foodId: id, userEmail: email) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success:
                    print("✅ Successfully deleted food with ID: \(id)")
                    
                    // Nothing more to do as we've already removed it locally
                    completion(.success(()))
                    
                case .failure(let error):
                    print("❌ Failed to delete food: \(error)")
                    
                    // Add the food back to the array since deletion failed
                    self.userFoods.insert(removedFood, at: index)
                    completion(.failure(error))
                }
            }
        } else {
            print("⚠️ Food with ID \(id) not found in userFoods")
            completion(.failure(NSError(domain: "FoodManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Food not found"])))
        }
    }
    // Delete a meal log
    func deleteMealLog(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        let repo = LogRepository() // Create an instance of LogRepository
        repo.deleteLogItem(email: email, logId: id, logType: "meal") { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Remove from local combinedLogs as well
                    self.combinedLogs.removeAll { $0.mealLogId == id }
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    // Delete a meal template
    func deleteMeal(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        
        // Use networkManager.deleteMeal to delete the meal template
        networkManager.deleteMeal(mealId: id, userEmail: email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Remove from local meals array
                    self.meals.removeAll { $0.id == id }
                    // Also remove any combined logs that might be showing this meal if it was logged
                    // (though this function is for deleting the template, not specific logs of it)
                    self.combinedLogs.removeAll { $0.meal?.id == id }
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func deleteRecipeLog(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }
        let repo = LogRepository() // Create an instance of LogRepository
        repo.deleteLogItem(email: email, logId: id, logType: "recipe") { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Remove from local combinedLogs as well
                    self.combinedLogs.removeAll { $0.recipeLogId == id }
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    // Function to delete a user-created food
    func deleteUserFood(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let email = userEmail else {
            print("⚠️ Cannot delete user food: User email not set")
            completion(.failure(NSError(domain: "FoodManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User email not set"])))
            return
        }

        if let index = userFoods.firstIndex(where: { $0.fdcId == id }) {
            let removedFood = userFoods.remove(at: index)
            networkManager.deleteFood(foodId: id, userEmail: email) { [weak self] result in // Uses networkManager.deleteFood
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Successfully deleted user food with ID: \(id)")
                        completion(.success(()))
                    case .failure(let error):
                        print("❌ Failed to delete user food: \(error)")
                        self.userFoods.insert(removedFood, at: index) // Add back on failure
                        completion(.failure(error))
                    }
                }
            }
        } else {
            print("⚠️ User food with ID \(id) not found in userFoods")
            completion(.failure(NSError(domain: "FoodManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "User food not found"])))
        }
    }
 

// MARK: - Scan-an-image → CombinedLog
@MainActor
func analyzeFoodImage(
  image: UIImage,
  userEmail: String,
  mealType: String = "Lunch",
  shouldLog: Bool = true,  // Default to true for backward compatibility
  completion: @escaping (Result<CombinedLog, Error>) -> Void
) {
  print("🔍 CRASH_DEBUG: ===== FoodManager.analyzeFoodImage START =====")
  print("🔍 CRASH_DEBUG: shouldLog = \(shouldLog), userEmail = \(userEmail), mealType = \(mealType)")
  
  // CRITICAL FIX: Defensive checks at start of function
  guard !userEmail.isEmpty else {
    print("❌ CRASH_DEBUG: Empty user email, aborting analysis")
    completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User email is required"])))
    return
  }
  
  guard image.size.width > 0 && image.size.height > 0 else {
    print("❌ CRASH_DEBUG: Invalid image size: \(image.size), aborting analysis")
    completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])))
    return
  }
  
  // CRITICAL FIX: Reset scanner dismissed flag for new scan
  resetScannerDismissedFlag()
  
  // Log image details and optimize if needed
  let imageSize = image.size
  let imageSizeBytes = image.jpegData(compressionQuality: 1.0)?.count ?? 0
  let imageSizeMB = Double(imageSizeBytes) / 1024.0 / 1024.0
  print("🔍 CRASH_DEBUG: Image analysis - Size: \(imageSize), File size: \(String(format: "%.2f", imageSizeMB))MB")
  
  // CRITICAL FIX: Auto-compress large images to prevent memory crashes
  let optimizedImage = optimizeImageForProcessing(image)
  let optimizedSizeBytes = optimizedImage.jpegData(compressionQuality: 0.8)?.count ?? 0
  let optimizedSizeMB = Double(optimizedSizeBytes) / 1024.0 / 1024.0
  print("🔍 CRASH_DEBUG: Optimized image - File size: \(String(format: "%.2f", optimizedSizeMB))MB")
  
  // Log memory before starting and check for high pressure
  let memoryBefore = getMemoryUsage()
  print("🔍 CRASH_DEBUG: Memory before analysis - Used: \(String(format: "%.1f", memoryBefore.used))MB, Available: \(String(format: "%.1f", memoryBefore.available))MB")
  
  // Check memory pressure and warn if high
  let isHighMemoryPressure = checkMemoryPressure()
  if isHighMemoryPressure {
    print("⚠️ CRASH_DEBUG: High memory pressure detected, proceeding with extra caution")
  }
  
  if shouldLog {
      print("🔍 DEBUG FoodManager: Will create food AND log to database")
  } else {
      print("🔍 DEBUG FoodManager: Will create food WITHOUT logging (preview mode)")
  }
  
  // ─── 1) UI state ─────────────────────────────
  print("🔍 CRASH_DEBUG: Setting UI state - isAnalyzingImage = true, isLoading = true")
  isAnalyzingImage = true
  isLoading        = true
  imageAnalysisMessage = "Analyzing image…"
  uploadProgress   = 0

  // ─── 2) Fake progress ticker ─────────────────
  print("🔍 CRASH_DEBUG: Creating progress timer")

  uploadProgress = 0
let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
  guard let self = self else { 
    print("🔍 CRASH_DEBUG: Progress timer - self is nil, invalidating timer")
    t.invalidate(); return 
  }
  
  // CRITICAL FIX: Ensure all @Published updates happen on main thread
  DispatchQueue.main.async {
    self.uploadProgress = min(0.9, self.uploadProgress + 0.1)
    print("🔍 CRASH_DEBUG: Progress updated to \(self.uploadProgress) [MAIN THREAD]")
  }
}
// Track timer for cleanup
trackTimer(progressTimer)

  // ─── 3) Call backend ─────────────────────────
  print("🔍 CRASH_DEBUG: Calling networkManager.analyzeFoodImage with optimized image")
  let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; df.timeZone = .current
  let selected = dayLogsViewModel?.selectedDate ?? Date()
  let dateString = df.string(from: selected)
  networkManager.analyzeFoodImage(image: optimizedImage, userEmail: userEmail, mealType: mealType, shouldLog: shouldLog, logDate: dateString) { [weak self] success, payload, errMsg in
    print("🔍 CRASH_DEBUG: Network callback received - success: \(success)")
    guard let self = self else { 
      print("🔍 CRASH_DEBUG: Network callback - self is nil, returning early")
      return 
    }
    DispatchQueue.main.async {
      print("🔍 CRASH_DEBUG: Network callback - on main queue, stopping timer")
      
      // stop ticker + UI
      progressTimer.invalidate()

     withAnimation {
        self.uploadProgress = 1.0
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        print("🔍 CRASH_DEBUG: Resetting UI state after analysis completion")
        let memoryAfter = getMemoryUsage()
        print("🔍 CRASH_DEBUG: Memory after analysis - Used: \(String(format: "%.1f", memoryAfter.used))MB, Available: \(String(format: "%.1f", memoryAfter.available))MB")
        
        self.isAnalyzingImage = false
        self.isLoading        = false
        self.imageAnalysisMessage = ""
        
        // Reset ALL scanning states together to prevent UI glitches
        self.isScanningFood = false
        self.isGeneratingFood = false
        self.scannedImage = nil
        self.loadingMessage = ""

        // reset for next time
        self.uploadProgress = 0
        print("🔍 CRASH_DEBUG: UI state reset complete")
      }

      // failure path
      guard success, let payload = payload else {
        let msg = errMsg ?? "Unknown error"
        print("🔍 CRASH_DEBUG: Network call failed - error: \(msg)")
        print("🔴 [analyzeFoodImage] error: \(msg)")
        
        // Show user-friendly error message for photo scan failures
        DispatchQueue.main.async {
          self.showScanFailure(
            type: "Photo Scan",
            message: "We couldn't recognize the food in this photo. Try taking a clearer picture or enter the food manually."
          )
        }
        
        print("🔍 CRASH_DEBUG: Calling completion(.failure) - Network error")
        completion(.failure(NSError(
          domain: "FoodScan", code: -1,
          userInfo: [NSLocalizedDescriptionKey: msg])))
        return
      }

      //── 4) Dump raw payload for debugging
     
      if let rawJSON = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
         let str     = String(data: rawJSON, encoding: .utf8) {
     
      }

      // CRITICAL FIX: Add defensive checks before processing response
      guard let payload = payload as? [String: Any] else {
        print("❌ CRASH_DEBUG: Invalid payload type - not a dictionary")
        completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
        return
      }
      
      do {
        print("🔍 CRASH_DEBUG: Starting to decode network response")
        //── 5) Handle different response formats based on shouldLog parameter
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        let decoder  = JSONDecoder()
        
        let combined: CombinedLog
        
        if shouldLog {
          // When shouldLog=true, backend returns LoggedFood with foodLogId

          let loggedFood = try decoder.decode(LoggedFood.self, from: jsonData)
   
          
          combined = CombinedLog(
            type:        .food,
            status:      loggedFood.status,
            calories:    loggedFood.calories,
            message:     loggedFood.message,
            foodLogId:   loggedFood.foodLogId,
            food:        loggedFood.food,
            mealType:    loggedFood.mealType,
            mealLogId:   nil,
            meal:        nil,
            mealTime:    nil,
            scheduledAt: Date(),
            recipeLogId: nil,
            recipe:      nil,
            servingsConsumed: nil
          )
        } else {
            // When shouldLog=false, backend returns creation response without foodLogId
            print("🔍 DEBUG FoodManager: Decoding creation response (shouldLog=false)")
            
            // Extract the food from the creation response and convert to LoggedFoodItem
            guard let foodDict = payload["food"] as? [String: Any] else {
                throw NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No food data in creation response"])
            }
            
            // Extract basic food info
            let fdcId = foodDict["fdcId"] as? Int ?? 0
            let description = foodDict["description"] as? String ?? "Unknown Food"
            let brandName = foodDict["brandName"] as? String
            let servingSize = foodDict["servingSize"] as? Double ?? 1
            let servingSizeUnit = foodDict["servingSizeUnit"] as? String ?? "serving"
            let householdServingFullText = foodDict["householdServingFullText"] as? String
            let numberOfServings = foodDict["numberOfServings"] as? Double ?? 1
            
            // Extract calories from nutrients
            var calories: Double = 0
            var protein: Double = 0
            var carbs: Double = 0
            var fat: Double = 0
            
            if let nutrients = foodDict["foodNutrients"] as? [[String: Any]] {
                for nutrient in nutrients {
                    let name = nutrient["nutrientName"] as? String ?? ""
                    let value = nutrient["value"] as? Double ?? 0
                    
                    switch name {
                    case "Energy":
                        calories = value
                    case "Protein":
                        protein = value
                    case "Carbohydrate, by difference":
                        carbs = value
                    case "Total lipid (fat)":
                        fat = value
                    default:
                        break
                    }
                }
            }
            
            // Extract health analysis if available
            var healthAnalysis: HealthAnalysis? = nil
            // First try to get health analysis from food object (correct location for image analysis)
            if let foodDict = payload["food"] as? [String: Any],
               let healthAnalysisDict = foodDict["health_analysis"] as? [String: Any] {
                do {
                    let healthAnalysisData = try JSONSerialization.data(withJSONObject: healthAnalysisDict)
                    healthAnalysis = try JSONDecoder().decode(HealthAnalysis.self, from: healthAnalysisData)
                    print("🩺 [DEBUG] Health analysis extracted from image analysis food object: score=\(healthAnalysis?.score ?? 0)")
                } catch {
                    print("⚠️ [DEBUG] Failed to decode health analysis from image analysis food object: \(error)")
                }
            }
            // Fallback: try top-level health_analysis (for backward compatibility)
            else if let healthAnalysisDict = payload["health_analysis"] as? [String: Any] {
                do {
                    let healthAnalysisData = try JSONSerialization.data(withJSONObject: healthAnalysisDict)
                    healthAnalysis = try JSONDecoder().decode(HealthAnalysis.self, from: healthAnalysisData)
                    print("🩺 [DEBUG] Health analysis extracted from top-level payload: score=\(healthAnalysis?.score ?? 0)")
                } catch {
                    print("⚠️ [DEBUG] Failed to decode health analysis from top-level payload: \(error)")
                }
            }
            
        let aiInsight = foodDict["ai_insight"] as? String
        let nutritionScore: Double? = {
            if let value = foodDict["nutrition_score"] as? Double { return value }
            if let value = foodDict["nutrition_score"] as? NSNumber { return value.doubleValue }
            if let value = foodDict["nutrition_score"] as? String, let double = Double(value) { return double }
            return nil
        }()

        // Create LoggedFoodItem from creation response
        let loggedFoodItem = LoggedFoodItem(
            foodLogId: nil,  // No log ID when not logged yet
            fdcId: fdcId,
            displayName: description,
            calories: calories,
            servingSizeText: householdServingFullText ?? "\(Int(servingSize)) \(servingSizeUnit)",
            numberOfServings: numberOfServings,
            brandText: brandName,
            protein: protein,
            carbs: carbs,
            fat: fat,
            healthAnalysis: healthAnalysis,
            foodNutrients: nil,   // Could extract if needed
            aiInsight: aiInsight,
            nutritionScore: nutritionScore
        )
            
            // Extract other fields
            let status = payload["status"] as? String ?? "success"
            let message = payload["message"] as? String ?? "Food created"
            let mealType = payload["meal_type"] as? String ?? "Lunch"
            
            combined = CombinedLog(
                type:        .food,
                status:      status,
                calories:    calories,
                message:     message,
                foodLogId:   nil,  // No log ID when shouldLog=false
                food:        loggedFoodItem,
                mealType:    mealType,
                mealLogId:   nil,
                meal:        nil,
                mealTime:    nil,
                scheduledAt: Date(),
                recipeLogId: nil,
                recipe:      nil,
                servingsConsumed: nil)
            
        }
        print("🔍 CRASH_DEBUG: Calling completion(.success(combined)) - Analysis complete")
        completion(.success(combined))
        
        // Set success data and show toast - MUST be on main thread
        print("🔍 CRASH_DEBUG: Setting success data and showing toast")
        DispatchQueue.main.async {
           self.lastLoggedItem = (
             name:     combined.food?.displayName ?? "Unknown Food",
             calories: combined.calories
           )
           self.showLogSuccess = true
           
           DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
             self.showLogSuccess = false
           }
           
           // Trigger review check after successful food log
           ReviewManager.shared.foodWasLogged()
           
           // Track meal timing for smart reminders
           MealReminderService.shared.mealWasLogged(mealType: combined.mealType ?? "Lunch")
        }
   
        // Mixpanel tracking removed - now handled by backend
        
      } catch {
        //── 7) On decode error, print the bad JSON + error
        print("❌ [analyzeFoodImage] decoding LoggedFood failed:", error)
        if let rawJSON = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let str     = String(data: rawJSON, encoding: .utf8) {
          print("❌ [analyzeFoodImage] payload was:\n\(str)")
        }
        completion(.failure(error))
      }
    }
  }
}

// MARK: - Scan nutrition label → CombinedLog
@MainActor
func analyzeNutritionLabel(
  image: UIImage,
  userEmail: String,
  mealType: String = "Lunch",
  shouldLog: Bool = true,  // Default to true for backward compatibility
  completion: @escaping (Result<CombinedLog, Error>) -> Void
) {
  print("📊 [DEBUG] ====== FoodManager.analyzeNutritionLabel START ======")
  print("📊 [DEBUG] shouldLog parameter received: \(shouldLog)")
  print("📊 [DEBUG] userEmail: \(userEmail)")
  print("📊 [DEBUG] mealType: \(mealType)")
  if shouldLog {
      print("📊 [DEBUG] MODE: Will create food AND log to database (should_log=true)")
  } else {
      print("📊 [DEBUG] MODE: Will create food WITHOUT logging (should_log=false, preview mode)")
  }
  print("📊 [DEBUG] About to call NetworkManager.analyzeNutritionLabel with shouldLog=\(shouldLog)")
  
  // ─── 1) UI state ─────────────────────────────
  // MODERN: Use modern FoodScanningState system with image thumbnail
  updateFoodScanningState(.preparing(image: image))
  self.isImageScanning = true
  self.currentScanningImage = image
  
  // Legacy state for backward compatibility (will be removed later)
  isAnalyzingImage = true
  isLoading        = true
  imageAnalysisMessage = "Reading nutrition label…"
  uploadProgress   = 0

  // ─── 2) MODERN: Let network progress drive state updates (no artificial timers)
  
  // Legacy progress ticker for backward compatibility (will be removed later)
  uploadProgress = 0
  var progressTimer: Timer?
  progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
    guard let self = self else { 
      progressTimer?.invalidate()
      return 
    }
    // CRITICAL FIX: Ensure all @Published updates happen on main thread
    DispatchQueue.main.async {
      self.uploadProgress = min(0.9, self.uploadProgress + 0.1)
      print("🔍 CRASH_DEBUG: Nutrition label progress updated to \(self.uploadProgress) [MAIN THREAD]")
    }
  }

  // ─── 3) Call backend ─────────────────────────
  let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; df.timeZone = .current
  let selected = dayLogsViewModel?.selectedDate ?? Date()
  let dateString = df.string(from: selected)
  networkManager.analyzeNutritionLabel(image: image, userEmail: userEmail, mealType: mealType, shouldLog: shouldLog, logDate: dateString) { [weak self] success, payload, errMsg in
    guard let self = self else { return }
    
    DispatchQueue.main.async {
      // stop ticker + UI
      progressTimer?.invalidate()

      withAnimation {
        self.uploadProgress = 1.0
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        // MODERN: Cleanup only - don't reset state (handled by .completed auto-reset)
        self.isImageScanning = false
        self.currentScanningImage = nil
        
        // Legacy state cleanup for backward compatibility (will be removed later)
        self.isAnalyzingImage = false
        self.isLoading        = false
        self.imageAnalysisMessage = ""
        
        // Reset ALL scanning states together to prevent UI glitches
        self.isScanningFood = false
        self.isGeneratingFood = false
        self.scannedImage = nil
        self.loadingMessage = ""

        // reset for next time
        self.uploadProgress = 0
      }
    }

    // failure path
    guard success, let payload = payload else {
      let msg = errMsg ?? "Unknown error"
      print("🔴 [analyzeNutritionLabel] error: \(msg)")
      
      // MODERN: Update to failed state immediately (triggers auto-reset)
      DispatchQueue.main.async {
        self.updateFoodScanningState(.failed(error: .networkError("No nutrition label detected")))
        self.isImageScanning = false
        self.currentScanningImage = nil
        
        self.showScanFailure(
          type: "No Nutrition Label Detected",
          message: "Try scanning again."
        )
      }
      
      completion(.failure(NSError(
        domain: "FoodManager",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: msg]
      )))
      return
    }

    // ─── 4) Check if name input is required ─────────────────
    if let status = payload["status"] as? String, status == "name_required" {
      // Product name not found - we need user input
      print("🏷️ [analyzeNutritionLabel] Product name not found, user input required")
      
      // Store nutrition data for later use with user-provided name
      if let nutritionData = payload["nutrition_data"] as? [String: Any] {
        // TODO: Show name input dialog and create food with user-provided name
        // For now, return an error to indicate name is needed
        completion(.failure(NSError(
          domain: "FoodManager",
          code: 1001, // Custom code for name required
          userInfo: [
            NSLocalizedDescriptionKey: "Product name not found on label",
            "nutrition_data": nutritionData,
            "meal_type": payload["meal_type"] as? String ?? "Lunch"
          ]
        )))
      } else {
        completion(.failure(NSError(
          domain: "FoodManager",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Invalid nutrition data format"]
        )))
      }
      return
    }

    // ─── 5) Use the SAME parsing as analyzeFoodImage ───────────
    do {
      if let rawJSON = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
         let str     = String(data: rawJSON, encoding: .utf8) {
        print("🔍 [analyzeNutritionLabel] raw payload:\n\(str)")
      }

      // Handle different response formats based on shouldLog parameter (same as analyzeFoodImage)
      let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
      let decoder  = JSONDecoder()
      
      let combinedLog: CombinedLog
      
      if shouldLog {
        // When shouldLog=true, backend returns LoggedFood with foodLogId
        print("🔍 DEBUG FoodManager: Decoding LoggedFood (shouldLog=true)")
        let loggedFood = try decoder.decode(LoggedFood.self, from: jsonData)
        
        combinedLog = CombinedLog(
          type:        .food,
          status:      loggedFood.status,
          calories:    loggedFood.calories,
          message:     loggedFood.message,
          foodLogId:   loggedFood.foodLogId,
          food:        loggedFood.food,
          mealType:    loggedFood.mealType,
          mealLogId:   nil,
          meal:        nil,
          mealTime:    nil,
          scheduledAt: Date(),
          recipeLogId: nil,
          recipe:      nil,
          servingsConsumed: nil
        )
      } else {
        // When shouldLog=false, backend returns creation response without foodLogId
        print("🔍 DEBUG FoodManager: Decoding creation response (shouldLog=false)")
        
        guard let foodDict = payload["food"] as? [String: Any] else {
          throw NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No food data in creation response"])
        }

        let fallbackHealth = payload["health_analysis"] as? [String: Any]
        let loggedFoodItem = try createLoggedFoodItemFromResponse(
          foodDict: foodDict,
          fallbackHealthAnalysis: fallbackHealth
        )

        let status = payload["status"] as? String ?? "success"
        let message = payload["message"] as? String ?? "Food created"
        let mealType = payload["meal_type"] as? String ?? "Lunch"

        combinedLog = CombinedLog(
          type:        .food,
          status:      status,
          calories:    loggedFoodItem.calories,
          message:     message,
          foodLogId:   nil,
          food:        loggedFoodItem,
          mealType:    mealType,
          mealLogId:   nil,
          meal:        nil,
          mealTime:    nil,
          scheduledAt: Date(),
          recipeLogId: nil,
          recipe:      nil,
          servingsConsumed: nil
        )
      }

       // MODERN: Update to completed state with result BEFORE calling completion
       updateFoodScanningState(.completed(result: combinedLog))
       
       completion(.success(combinedLog))
       
       // Set success data and show toast (same as analyzeFoodImage) - MUST be on main thread
       DispatchQueue.main.async {
         self.lastLoggedItem = (
           name:     combinedLog.food?.displayName ?? "Unknown Food",
           calories: combinedLog.calories
         )
         self.showLogSuccess = true
         
         DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
           self.showLogSuccess = false
         }
         
         // Trigger review check after successful food log
         ReviewManager.shared.foodWasLogged()
         
         // Track meal timing for smart reminders
         MealReminderService.shared.mealWasLogged(mealType: combinedLog.mealType ?? "Lunch")
       }
       
       // Mixpanel tracking removed - now handled by backend

    } catch {
      //── 7) On decode error, print the bad JSON + error
      print("❌ [analyzeNutritionLabel] decoding error:", error)
      if let rawJSON = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
         let str     = String(data: rawJSON, encoding: .utf8) {
        print("❌ [analyzeNutritionLabel] payload was:\n\(str)")
      }
      
      // MODERN: Update to failed state for decoding errors (triggers auto-reset)  
      updateFoodScanningState(.failed(error: .networkError("Failed to process nutrition label")))
      isImageScanning = false
      currentScanningImage = nil
      
      completion(.failure(error))
    }
  }
}

    // // Add this function to handle the barcode scanning logic
    // func lookupFoodByBarcode(barcode: String, image: UIImage? = nil, userEmail: String, completion: @escaping (Bool, String?) -> Void) {
    //     // Set barcode scanning state for UI feedback
    //     isScanningBarcode = true
    //     isLoading = true
    //     barcodeLoadingMessage = "Looking up barcode..."
    //     uploadProgress = 0.3
        
    //     // Convert image to base64 if available
    //     var imageBase64: String? = nil
    //     if let image = image {
    //         if let imageData = image.jpegData(compressionQuality: 0.7) {
    //             imageBase64 = imageData.base64EncodedString()
    //         }
    //     }
        
    //     // Call NetworkManagerTwo to look up the barcode
    //     NetworkManagerTwo.shared.lookupFoodByBarcode(
    //         barcode: barcode,
    //         userEmail: userEmail,
    //         imageData: imageBase64,
    //         mealType: "Lunch", // Default meal type since this method doesn't have mealType parameter
    //         shouldLog: false
    //     ) { [weak self] result in
    //         guard let self = self else { return }
            
    //         // Update progress for UI
    //         self.uploadProgress = 1.0
            
    //         switch result {
    //         case .success(let response):
    //             // Reset barcode scanning state since we'll show the confirmation screen
    //             self.isScanningBarcode = false
    //             self.isLoading = false
    //             self.barcodeLoadingMessage = ""
    //             self.scannedImage = nil
                
    //             // Show the ConfirmFoodView with the barcode data using notification system
    //             DispatchQueue.main.async {
    //                 // Use notification system instead of navigationPath
    //                 NotificationCenter.default.post(
    //                     name: NSNotification.Name("ShowFoodConfirmation"),
    //                     object: nil,
    //                     userInfo: [
    //                         "food": response.food,
    //                         "foodLogId": response.foodLogId
    //                     ]
    //                 )
    //                 completion(true, nil)
    //             }
                
    //         case .failure(let error):
    //             // Update barcode scanner state on failure
    //             self.isScanningBarcode = false
    //             self.isLoading = false
    //             self.barcodeLoadingMessage = ""
    //             self.scannedImage = nil
                
    //             // Set error message for display
    //             let errorMsg: String
    //             if let networkError = error as? NetworkManagerTwo.NetworkError,
    //                case .serverError(let message) = networkError {
    //                 // Use server error message
    //                 errorMsg = message
    //             } else {
    //                 // General error message
    //                 errorMsg = "Could not find food for barcode"
    //             }
                
    //             print("Barcode scan error: \(errorMsg)")
    //             self.scanningFoodError = errorMsg
    //             completion(false, errorMsg)
    //         }
    //     }
    // }
    
    // Original method for backwards compatibility (calls the new method)
    func lookupFoodByBarcode(barcode: String, image: UIImage? = nil, userEmail: String, completion: @escaping (Bool, String?) -> Void) {
        // If we don't have a navigation path, we can't show the confirmation screen
        // This is just a placeholder for backward compatibility
        print("Warning: Using deprecated barcode lookup method without navigation path")
        
        // Set barcode scanning state for UI feedback
        isScanningBarcode = true
        isLoading = true
        barcodeLoadingMessage = "Looking up barcode..."
        uploadProgress = 0.3
        
        // Convert image to base64 if available
        var imageBase64: String? = nil
        if let image = image {
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                imageBase64 = imageData.base64EncodedString()
            }
        }
        
        // Call NetworkManagerTwo to look up the barcode
        let df1 = DateFormatter(); df1.dateFormat = "yyyy-MM-dd"; df1.timeZone = .current
        let selected1 = dayLogsViewModel?.selectedDate ?? Date()
        let dateString1 = df1.string(from: selected1)
        NetworkManagerTwo.shared.lookupFoodByBarcode(
            barcode: barcode,
            userEmail: userEmail,
            imageData: imageBase64,
            mealType: "Lunch", // Default meal type since this method doesn't have mealType parameter
            shouldLog: false,
            date: dateString1
        ) { [weak self] result in
            guard let self = self else { return }
            
            // Update progress for UI
            self.uploadProgress = 1.0
            
            switch result {
            case .success(let payload):
                let food = payload.food
                let serverLogId = payload.foodLogId
                
                // Store the food for confirmation, but DON'T add it to the logs yet
                self.aiGeneratedFood = food.asLoggedFoodItem
                
                // Track ID for later use when confirmed
                self.lastLoggedFoodId = food.fdcId
                
                // CRITICAL FIX: Update barcode scanner state on main thread
                DispatchQueue.main.async {
                    self.isScanningBarcode = false
                    self.isLoading = false
                    self.barcodeLoadingMessage = ""
                    self.scannedImage = nil
                }
                
                // Return success so the scanner can close
                completion(true, nil)
                
            case .failure(let error):
                // CRITICAL FIX: Update barcode scanner state on failure - main thread
                DispatchQueue.main.async {
                    self.isScanningBarcode = false
                    self.isLoading = false
                    self.barcodeLoadingMessage = ""
                    self.scannedImage = nil
                }
                
                // Set error message for display
                let errorMsg: String
                if let networkError = error as? NetworkManagerTwo.NetworkError,
                   case .serverError(let message) = networkError {
                    // Use server error message
                    errorMsg = message
                } else {
                    // General error message
                    errorMsg = "Could not find food for barcode"
                }
                
                print("Barcode scan error: \(errorMsg)")
                self.scanningFoodError = errorMsg
                completion(false, errorMsg)
            }
        }
    }
    // MARK: - Direct Barcode Logging (no preview)
    @MainActor
    func lookupFoodByBarcodeDirect(barcode: String, userEmail: String, mealType: String = "Lunch", completion: @escaping (Bool, String?) -> Void) {
        guard !isAnalyzingFood else { return }
        let currentEmail = userEmail
        if NutritionixService.shared.isConfigured {
            NutritionixService.shared.lookupFood(by: barcode, userEmail: currentEmail) { [weak self] result in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success(var food):
                        if food.barcode == nil {
                            food.barcode = barcode
                        }
                        self.processDirectNutritionixFood(food: food, mealType: mealType, completion: completion)
                    case .failure(let error):
                        print("❌ Nutritionix direct lookup failed: \(error.localizedDescription)")
                        self.legacyLookupFoodByBarcodeDirect(
                            barcode: barcode,
                            userEmail: currentEmail,
                            mealType: mealType,
                            completion: completion
                        )
                    }
                }
            }
            return
        }

        legacyLookupFoodByBarcodeDirect(barcode: barcode, userEmail: userEmail, mealType: mealType, completion: completion)
    }

    private func processDirectNutritionixFood(food: Food, mealType: String, completion: @escaping (Bool, String?) -> Void) {
        isAnalyzingFood = false
        finishLogging(food: food, mealType: mealType) {
            completion(true, nil)
        }
    }

    private func legacyLookupFoodByBarcodeDirect(barcode: String, userEmail: String, mealType: String = "Lunch", completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Starting direct barcode lookup for: \(barcode)")
        
        // MODERN: Use modern FoodScanningState system with proper state progression
        updateFoodScanningState(.initializing)
        
        // Smooth transition to analyzing state after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateFoodScanningState(.analyzing)
        }
        
        // Legacy state for backward compatibility (will be removed later)
        isScanningBarcode = true
        isLoading = true
        barcodeLoadingMessage = "Looking up barcode..."
        uploadProgress = 0.2
        
        // Legacy timer for backward compatibility (will be removed later)
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            // CRITICAL FIX: Ensure all @Published updates happen on main thread
            DispatchQueue.main.async {
                // Update barcode loading message
                self.barcodeLoadingMessage = [
                    "Looking up barcode...",
                    "Searching nutrition databases...",
                    "Enhancing with web search...",
                    "Finalizing food data..."
                ].randomElement() ?? "Processing barcode..."
                
                // Gradually increase progress
                self.uploadProgress = min(self.uploadProgress + 0.1, 0.9)
                print("🔍 CRASH_DEBUG: Barcode progress updated to \(self.uploadProgress) [MAIN THREAD]")
            }
        }
        
        // Call the enhanced barcode lookup endpoint with shouldLog = true
        let df2 = DateFormatter(); df2.dateFormat = "yyyy-MM-dd"; df2.timeZone = .current
        let selected2 = dayLogsViewModel?.selectedDate ?? Date()
        let dateString2 = df2.string(from: selected2)
        NetworkManagerTwo.shared.lookupFoodByBarcode(
            barcode: barcode,
            userEmail: userEmail,
            imageData: nil,
            mealType: mealType,
            shouldLog: true,  // Log directly, no preview
            date: dateString2
        ) { [weak self] result in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Stop the timer and update progress
            timer.invalidate()
            self.uploadProgress = 1.0
            
            switch result {
            case .success(let payload):
                let food = payload.food
                
                print("✅ Direct barcode lookup successful: \(food.displayName)")
                let calories = food.calories ?? 0
                let protein = food.protein ?? 0
                let carbs = food.carbs ?? 0
                let fat = food.fat ?? 0
                print("🍽️ Direct barcode macros – calories: \(calories), protein: \(protein)g, carbs: \(carbs)g, fat: \(fat)g")
                
                // Track barcode scanning in Mixpanel
                Mixpanel.mainInstance().track(event: "Barcode Scan", properties: [
                    "food_name": food.displayName,
                    "barcode": barcode,
                    "calories": food.calories ?? 0,
                    "user_email": userEmail
                ])
                
                // Create combined log for UI update
                let combinedLog = CombinedLog(
                    type: .food,
                    status: "success",
                    calories: food.calories ?? 0,
                    message: "Barcode scan: \(barcode) - \(food.displayName)",
                    foodLogId: payload.foodLogId,
                    food: food.asLoggedFoodItem,
                    mealType: mealType,
                    mealLogId: nil,
                    meal: nil,
                    mealTime: nil,
                    scheduledAt: Date(),
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil
                )
                
                // Ensure all @Published property updates and manager calls happen on main thread
                DispatchQueue.main.async {
                        self.dayLogsViewModel?.addPending(combinedLog)
                        
                        if let idx = self.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                            self.combinedLogs.remove(at: idx)
                        }
                        self.combinedLogs.insert(combinedLog, at: 0)
                        
                        self.lastLoggedItem = (name: food.displayName, calories: food.calories ?? 0)
                        self.showLogSuccess = true
                        
                        // MODERN: Update to completed state with result
                        self.updateFoodScanningState(.completed(result: combinedLog))
                        
                        // Reset legacy barcode scanning states (backward compatibility)
                        self.isScanningBarcode = false
                        self.isLoading = false
                        self.barcodeLoadingMessage = ""
                        
                        // Auto-hide success message after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.showLogSuccess = false
                        }
                        
                        // Trigger review check after successful food log
                        ReviewManager.shared.foodWasLogged()
                        
                        // Track meal timing for smart reminders
                        MealReminderService.shared.mealWasLogged(mealType: mealType)
                    
                    completion(true, nil)
                }
                
            case .failure(let error):
                print("❌ Direct barcode lookup failed: \(error)")
                
                DispatchQueue.main.async {
                    // MODERN: Update to failed state
                    self.updateFoodScanningState(.failed(error: .networkError("Barcode lookup failed")))
                    
                    // Reset legacy barcode scanning states (backward compatibility)
                    self.isScanningBarcode = false
                    self.isLoading = false
                    self.barcodeLoadingMessage = ""
                    
                    // Set error message
                    let errorMsg: String
                    if let networkError = error as? NetworkManagerTwo.NetworkError,
                       case .serverError(let message) = networkError {
                        errorMsg = message
                    } else {
                        errorMsg = "Could not find food for barcode"
                    }
                    
                    self.scanningFoodError = errorMsg
                    completion(false, errorMsg)
                }
            }
        }
    }
    
    // MARK: - Enhanced Barcode Lookup
    @MainActor
    func lookupFoodByBarcodeEnhanced(barcode: String, userEmail: String, mealType: String = "Lunch", completion: @escaping (Bool, String?) -> Void) {
        let shouldShowLoaderCard = false
        if NutritionixService.shared.isConfigured {
            NutritionixService.shared.lookupFood(by: barcode, userEmail: userEmail) { [weak self] result in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success(var food):
                        if food.barcode == nil {
                            food.barcode = barcode
                        }
                        self.processEnhancedNutritionixFood(
                            food: food,
                            barcode: barcode,
                            mealType: mealType,
                            shouldShowLoaderCard: shouldShowLoaderCard,
                            userEmail: userEmail,
                            completion: completion
                        )
                    case .failure(let error):
                        print("❌ Nutritionix enhanced lookup failed: \(error.localizedDescription)")
                        self.legacyLookupFoodByBarcodeEnhanced(
                            barcode: barcode,
                            userEmail: userEmail,
                            mealType: mealType,
                            completion: completion
                        )
                    }
                }
            }
            return
        }

        legacyLookupFoodByBarcodeEnhanced(
            barcode: barcode,
            userEmail: userEmail,
            mealType: mealType,
            completion: completion
        )
    }

    private func processEnhancedNutritionixFood(
        food: Food,
        barcode: String,
        mealType: String,
        shouldShowLoaderCard: Bool,
        userEmail: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        var enrichedFood = food
        if enrichedFood.barcode == nil {
            enrichedFood.barcode = barcode
        }
        print("✅ Enhanced barcode lookup successful: \(enrichedFood.displayName)")
        let calories = enrichedFood.calories ?? 0
        let protein = enrichedFood.protein ?? 0
        let carbs = enrichedFood.carbs ?? 0
        let fat = enrichedFood.fat ?? 0
        print("🍽️ Enhanced barcode macros – calories: \(calories), protein: \(protein)g, carbs: \(carbs)g, fat: \(fat)g")

        Mixpanel.mainInstance().track(event: "Barcode Scan", properties: [
            "food_name": enrichedFood.displayName,
            "barcode": barcode,
            "calories": calories,
            "user_email": userEmail
        ])

        Mixpanel.mainInstance().track(event: "Barcode Food Identified", properties: [
            "food_name": enrichedFood.displayName,
            "barcode": barcode,
            "calories": calories,
            "user_email": userEmail
        ])

        self.aiGeneratedFood = enrichedFood.asLoggedFoodItem
        self.lastLoggedFoodId = enrichedFood.fdcId

        let combinedLog = CombinedLog(
            type: .food,
            status: "success",
            calories: calories,
            message: "Barcode scan: \(barcode) - \(enrichedFood.displayName)",
            foodLogId: nil,
            food: enrichedFood.asLoggedFoodItem,
            mealType: mealType,
            mealLogId: nil,
            meal: nil,
            mealTime: nil,
            scheduledAt: Date(),
            recipeLogId: nil,
            recipe: nil,
            servingsConsumed: nil
        )

        if shouldShowLoaderCard {
            updateFoodScanningState(.completed(result: combinedLog))
            lastLoggedItem = (name: enrichedFood.displayName, calories: calories)
            showLogSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showLogSuccess = false
            }
        } else {
            updateFoodScanningState(.inactive)
        }

        isScanningBarcode = false
        isLoading = false
        barcodeLoadingMessage = ""
        isAnalyzingFood = false

        NotificationCenter.default.post(
            name: NSNotification.Name("ShowFoodConfirmation"),
            object: nil,
            userInfo: [
                "food": enrichedFood,
                "barcode": barcode
            ]
        )
        completion(true, nil)
    }

    private func legacyLookupFoodByBarcodeEnhanced(barcode: String, userEmail: String, mealType: String = "Lunch", completion: @escaping (Bool, String?) -> Void) {
        print("🔍 Starting enhanced barcode lookup for: \(barcode)")
        let shouldShowLoaderCard = false
        var barcodeTimer: Timer?
        
        if shouldShowLoaderCard {
            updateFoodScanningState(.initializing)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.updateFoodScanningState(.analyzing)
            }
            isScanningBarcode = true
            isLoading = true
            barcodeLoadingMessage = "Looking up barcode..."
            uploadProgress = 0.2
            barcodeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                DispatchQueue.main.async {
                    self.barcodeLoadingMessage = [
                        "Looking up barcode...",
                        "Searching nutrition databases...",
                        "Enhancing with web search...",
                        "Finalizing food data..."
                    ].randomElement() ?? "Processing barcode..."
                    self.uploadProgress = min(self.uploadProgress + 0.1, 0.9)
                    print("🔍 CRASH_DEBUG: Barcode progress updated to \(self.uploadProgress) [MAIN THREAD]")
                }
            }
        }
        
        // Call the enhanced barcode lookup endpoint
        let df3 = DateFormatter(); df3.dateFormat = "yyyy-MM-dd"; df3.timeZone = .current
        let selected3 = dayLogsViewModel?.selectedDate ?? Date()
        let dateString3 = df3.string(from: selected3)
        NetworkManagerTwo.shared.lookupFoodByBarcode(
            barcode: barcode,
            userEmail: userEmail,
            imageData: nil,  // No image for barcode-only lookup
            mealType: mealType,
            shouldLog: false,  // Don't log automatically, let user confirm first
            date: dateString3
        ) { [weak self] result in
            guard let self = self else {
                barcodeTimer?.invalidate()
                return
            }
            
            // Stop the timer and update progress
            barcodeTimer?.invalidate()
            if shouldShowLoaderCard {
                self.uploadProgress = 1.0
            }
            
            switch result {
            case .success(let payload):
                let food = payload.food
                
                print("✅ Enhanced barcode lookup successful: \(food.displayName)")
                let calories = food.calories ?? 0
                let protein = food.protein ?? 0
                let carbs = food.carbs ?? 0
                let fat = food.fat ?? 0
                print("🍽️ Enhanced barcode macros – calories: \(calories), protein: \(protein)g, carbs: \(carbs)g, fat: \(fat)g")
                
                // Track barcode scanning in Mixpanel
                Mixpanel.mainInstance().track(event: "Barcode Scan", properties: [
                    "food_name": food.displayName,
                    "barcode": barcode,
                    "calories": food.calories ?? 0,
                    "user_email": userEmail
                ])
                
                // Track universal food logging (for barcode identification, not actual logging)
                Mixpanel.mainInstance().track(event: "Barcode Food Identified", properties: [
                    "food_name": food.displayName,
                    "barcode": barcode,
                    "calories": food.calories ?? 0,
                    "user_email": userEmail
                ])
                
                // Store the food for confirmation
                self.aiGeneratedFood = food.asLoggedFoodItem
                self.lastLoggedFoodId = food.fdcId
                
                // Create a CombinedLog for optimistic UI update (but don't add to logs yet)
                let combinedLog = CombinedLog(
                    type: .food,
                    status: "success",
                    calories: food.calories ?? 0,
                    message: "Barcode scan: \(barcode) - \(food.displayName)",
                    foodLogId: nil,  // No log ID yet since not confirmed
                    food: food.asLoggedFoodItem,
                    mealType: mealType,
                    mealLogId: nil,
                    meal: nil,
                    mealTime: nil,
                    scheduledAt: Date(),
                    recipeLogId: nil,
                    recipe: nil,
                    servingsConsumed: nil
                )
                
                if shouldShowLoaderCard {
                    self.updateFoodScanningState(.completed(result: combinedLog))
                    self.lastLoggedItem = (name: food.displayName, calories: food.calories ?? 0)
                    self.showLogSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showLogSuccess = false
                    }
                } else {
                    self.updateFoodScanningState(.inactive)
                }
                
                self.isScanningBarcode = false
                self.isLoading = false
                self.barcodeLoadingMessage = ""
                // Trigger navigation to confirmation view
                // This will be handled by the DashboardView or ContentView
                print("🩺 [DEBUG] Barcode food.healthAnalysis: \(food.healthAnalysis?.score ?? -1)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowFoodConfirmation"),
                    object: nil,
                    userInfo: [
                        "food": food,
                        "barcode": barcode
                    ]
                )
                print("🔍 DEBUG: Posted ShowFoodConfirmation notification for barcode: \(food.description)")
                print("🔍 DEBUG: Health analysis in barcode notification food: \(food.healthAnalysis?.score ?? -1)")
                
                completion(true, nil)
                
            case .failure(let error):
                print("❌ Enhanced barcode lookup failed: \(error)")
                
                // CRITICAL FIX: Reset barcode scanning states on main thread
                DispatchQueue.main.async {
                    // MODERN: Update to failed state
                    self.updateFoodScanningState(.failed(error: .networkError("Barcode lookup failed")))
                    
                    // Reset legacy states (backward compatibility)
                    self.isScanningBarcode = false
                    self.isLoading = false
                    self.barcodeLoadingMessage = ""
                }
                
                // Set error message
                let errorMsg: String
                if let networkError = error as? NetworkManagerTwo.NetworkError,
                   case .serverError(let message) = networkError {
                    errorMsg = message
                } else {
                    errorMsg = "Could not find food for barcode"
                }
                
                self.scanningFoodError = errorMsg
                completion(false, errorMsg)
            }
        }
    }

    // MARK: - Voice Input Processing
    func processVoiceInput(audioData: Data) {
        // UNIFIED: Set modern state for voice macro generation (keeping legacy for backward compatibility)
        foodScanningState = .generatingMacros
        isGeneratingMacros = true
        macroGenerationStage = 0
        showAIGenerationSuccess = false
        
        // CRITICAL FIX: Start with initializing state for proper 0% progress visibility
        updateFoodScanningState(.initializing)
        
        // Move directly to analyzing state without artificial timers to prevent shimmer glitches
        // The network response will drive real progress updates
        updateFoodScanningState(.analyzing)
        
        // Create a timer to cycle through analysis stages for UI feedback
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            // CRITICAL FIX: Ensure all @Published updates happen on main thread
            DispatchQueue.main.async {
                // Cycle through macro generation stages 0-3
                self.macroGenerationStage = (self.macroGenerationStage + 1) % 4
                self.macroLoadingMessage = [
                    "Transcribing your voice...",
                    "Analyzing food description...",
                    "Generating nutritional data...",
                    "Finalizing your food log..."
                ][self.macroGenerationStage]
            }
        }
        
        // First step: Transcribe the audio using the backend
        transcribeAudio(audioData: audioData) { [weak self] result in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            switch result {
            case .success(let transcribedText):
                print("Voice transcription successful: \(transcribedText)")
                
                // Now use the transcribed text to generate macros, same as the text input flow
                self.generateMacrosWithAI(foodDescription: transcribedText, mealType: "Lunch") { macroResult in
                    // Stop the analysis animation timer
                    timer.invalidate()
                    
                    // Reset macro generation flags
                    self.isGeneratingMacros = false
                    
                    switch macroResult {
                    case .success(let loggedFood):
                        print("AI macros generated successfully from voice input")
                        self.aiGeneratedFood = loggedFood.food
                        self.lastLoggedItem = (name: loggedFood.food.displayName, calories: loggedFood.food.calories ?? 0)
                        self.showAIGenerationSuccess = true
                        
                        // Automatically dismiss the success indicator after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.showAIGenerationSuccess = false
                        }
                        
                 
                        
                    case .failure(let error):
                        print("Failed to generate AI macros: \(error.localizedDescription)")
                        self.error = error
                    }
                }
                
            case .failure(let error):
                // Stop the timer and reset flags if transcription fails
                timer.invalidate()
                self.isGeneratingMacros = false
                self.error = error
                print("Voice transcription failed: \(error.localizedDescription)")
            }
        }
    }
    // Helper method to transcribe audio using the NetworkManager
    private func transcribeAudio(audioData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        // Use the enhanced transcription endpoint for more accurate food logging
        NetworkManagerTwo.shared.transcribeAudioForFoodLogging(from: audioData) { result in
            completion(result)
        }
    }
    // Add a new method to process voice recordings directly in FoodManager
    // This ensures the processing continues even if the view disappears
    @MainActor
    func processVoiceRecording(audioData: Data, mealType: String = "Lunch", dayLogsVM: DayLogsViewModel) {
        print("🍽️ FoodManager.processVoiceRecording called with mealType: \(mealType)")
        // Ensure any prior stage timer is stopped before starting a new session
        stopVoiceTimer()
        
        // UNIFIED: Set modern state for macro generation with voice (keeping legacy for backward compatibility)
        foodScanningState = .generatingMacros  
        isGeneratingMacros = true  // This triggers MacroGenerationCard
        isLoading = true  // This is what makes the loading card visible in DashboardView
        macroGenerationStage = 0
        macroLoadingMessage = "Transcribing your voice…"  
        showAIGenerationSuccess = false
       
        
        // CRITICAL: Start with initializing state for proper 0% progress visibility
        updateFoodScanningState(.initializing)  // Shows 0%
        
        // Smooth staged progression similar to image/barcode flows
        // Step 1: Show upload start while transcription is underway
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            // Only apply if we haven't advanced beyond early stage
            if self.foodScanningState.progress < 0.3 {
                self.updateFoodScanningState(.uploading(progress: 0.0)) // ~10-30%
            }
        }
        
        // Create a timer to cycle through analysis stages for UI feedback
        voiceStageTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Cycle through macro generation stages (on main thread)
            DispatchQueue.main.async {
                self.macroGenerationStage = (self.macroGenerationStage + 1) % 4
                
                // Update loading message based on current stage
                self.macroLoadingMessage = [
                    "Transcribing your voice…",
                    "Analyzing food description…",
                    "Generating nutritional data…",
                    "Finalizing your food log…"
                ][self.macroGenerationStage]
            }
        }
        
        // First step: Transcribe the audio
        NetworkManagerTwo.shared.transcribeAudioForFoodLogging(from: audioData) { [weak self] result in
            guard let self = self else {
                self?.stopVoiceTimer()
                return
            }
            
            switch result {
            case .success(let text):
                print("✅ Voice transcription successful: \(text)")
                // Show mid-upload progress to give smooth fill while moving to analysis
                self.updateFoodScanningState(.uploading(progress: 0.5))
                
                // Second step: Generate AI macros from the transcribed text (call network directly)
                print("🍽️ Calling networkManager.generateMacrosWithAI with mealType: \(mealType)")
                // Move to analyzing state during macro generation
                self.updateFoodScanningState(.analyzing)
                self.networkManager.generateMacrosWithAI(foodDescription: text, mealType: mealType) { result in
                
                    
                    switch result {
                    case .success(let loggedFood):
                        print("✅ Voice log successfully processed: \(loggedFood.food.displayName)")
                        
                        // CRITICAL: Stop the timer to prevent interference with auto-reset
                        self.stopVoiceTimer()
                        
                        // Mixpanel tracking removed - now handled by backend

                        // Check if this is an "Unknown food" with no nutritional value
                        // This happens when the server couldn't identify a food from the transcription
                        if loggedFood.food.displayName.lowercased().contains("unknown food") || 
                           (loggedFood.food.calories == 0 && loggedFood.food.protein == 0 && 
                            loggedFood.food.carbs == 0 && loggedFood.food.fat == 0) {
                            
                            // UNIFIED: Show failure state then reset after delay
                            self.updateFoodScanningState(.failed(error: .networkError("Food not identified. Please try again.")))
                            
                            // Reset after showing error for a moment
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.foodScanningState = .inactive
                                self.isGeneratingMacros = false
                                self.isLoading = false
                                self.macroGenerationStage = 0
                                self.macroLoadingMessage = ""
                            }
                            print("⚠️ Voice log returned Unknown food with no nutrition data")
                            return
                        }
                        
                        // Create a CombinedLog for the voice-recorded food
                        let combinedLog = CombinedLog(
                            type: .food,
                            status: loggedFood.status,
                            calories: loggedFood.calories,
                            message: loggedFood.message,
                            foodLogId: loggedFood.foodLogId,
                            food: loggedFood.food,
                            mealType: loggedFood.mealType,
                            mealLogId: nil,
                            meal: nil,
                            mealTime: nil,
                            scheduledAt: Date(), // Set to current date to make it appear in today's logs
                            recipeLogId: nil,
                            recipe: nil,
                            servingsConsumed: nil
                        )
                        
                        // EXACT generateMacrosWithAI pattern - no state updates or DayLogsViewModel logic
                        self.aiGeneratedFood = loggedFood.food
                        self.lastLoggedItem = (name: loggedFood.food.displayName, calories: loggedFood.food.calories ?? 0)
                        
                        // Track the food in recently added - fdcId is non-optional
                        self.lastLoggedFoodId = loggedFood.food.fdcId
                        self.trackRecentlyAdded(foodId: loggedFood.food.fdcId)
                        
                        // Move through final states with smooth progress
                        self.updateFoodScanningState(.processing) // 80%
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.completeFoodScanning(result: combinedLog) // 100% then auto-reset (cancellable)
                        }
                        
                        // Reset flags after a short delay to let UI settle
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.isGeneratingMacros = false
                            self.isLoading = false
                            self.macroGenerationStage = 0
                            self.macroLoadingMessage = ""
                        }
                        
                        // CRITICAL: Add to DayLogsViewModel so it appears in dashboard
                        dayLogsVM.addPending(combinedLog)
                        
                        // CRITICAL: Add to foodManager.combinedLogs (like all other methods do)
                        // Update global combinedLogs so dashboard's "All" feed updates
                        if let idx = self.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                            self.combinedLogs.remove(at: idx)
                        }
                        self.combinedLogs.insert(combinedLog, at: 0)
                        
                        // Set success data and show toast (like image analysis) - MUST be on main thread
                        DispatchQueue.main.async {
                            self.showLogSuccess = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                self.showLogSuccess = false
                            }
                        }
                        
                        // Clear the lastLoggedFoodId after 2 seconds, similar to logFood()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                // Only clear if it still matches the food we logged
                                if self.lastLoggedFoodId == loggedFood.food.fdcId {
                                    self.lastLoggedFoodId = nil
                                }
                            }
                        }
                        
                    case .failure(let error):
                        // CRITICAL: Stop the timer to prevent interference 
                        self.stopVoiceTimer()
                        
                        // Use proper error handling with auto-reset (like image analysis)
                        let scanError: FoodScanError
                        if let networkError = error as? NetworkError, case .serverError(let message) = networkError {
                            scanError = .networkError(message)
                        } else {
                            scanError = .networkError("Failed to process voice input: \(error.localizedDescription)")
                        }
                        self.updateFoodScanningState(.failed(error: scanError))
                        
                        // Reset flags
                        self.isGeneratingMacros = false
                        self.isLoading = false
                        self.macroGenerationStage = 0
                        self.macroLoadingMessage = ""
                        
                        print("❌ Failed to generate macros from voice input: \(error.localizedDescription)")
                    }
                }
                
            case .failure(let error):
                // Stop the timer and reset macro generation state
                self.stopVoiceTimer()
                
                // Use proper error handling with auto-reset (like image analysis)
                let scanError: FoodScanError
                if let networkError = error as? NetworkError, case .serverError(let message) = networkError {
                    scanError = .networkError(message)
                } else {
                    scanError = .networkError("Failed to transcribe voice input: \(error.localizedDescription)")
                }
                updateFoodScanningState(.failed(error: scanError))
                
                // UNIFIED: Reset to inactive state (keeping legacy for backward compatibility)
                foodScanningState = .inactive
                isGeneratingMacros = false
                isLoading = false
                macroGenerationStage = 0
                macroLoadingMessage = ""
                
                print("❌ Voice transcription failed: \(error.localizedDescription)")
            }
        }
    }
    

    func finishLogging(food: Food, mealType: String, completion: @escaping () -> Void = {}) {
        print("🍽️ Finalizing food logging for \(food.displayName) as \(mealType)")
        
        guard let email = userEmail else { 
            completion()
            return 
        }
        
        self.isLoggingFood = true
        self.lastLoggedFoodId = food.fdcId
        
        print("📡 Sending log request to server for \(food.displayName)")
        // Call the correct NetworkManager logFood method with the required parameters
        networkManager.logFood(
            userEmail: email,
            food: food,
            mealType: mealType,
            servings: 1,
            date: Date()
        ) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoggingFood = false
                
                // Check if this food already exists in our logs
                let existingIndex = self.combinedLogs.firstIndex(where: {
                    ($0.type == .food && $0.food?.fdcId == food.fdcId)
                })
                
                switch result {
                case .success(let loggedFood):
                    print("✅ Successfully logged food with foodLogId: \(loggedFood.foodLogId)")

                    // Mixpanel tracking removed - now handled by backend

                    // Create a new CombinedLog from the logged food
                    let combinedLog = CombinedLog(
                        type: .food,
                        status: "success",
                        calories: Double(loggedFood.food.calories),
                        message: "\(loggedFood.food.displayName) - \(loggedFood.mealType)",
                        foodLogId: loggedFood.foodLogId,
                        food: loggedFood.food,
                        mealType: loggedFood.mealType,
                        mealLogId: nil,
                        meal: nil,
                        mealTime: nil,
                        scheduledAt: Date(), // Set to current date to make it appear in today's logs
                        recipeLogId: nil,
                        recipe: nil,
                        servingsConsumed: nil
                    )
                    
                    // Ensure all @Published property updates happen on main thread
                    DispatchQueue.main.async {
                        // Track the food in recently added - fdcId is non-optional
                        self.lastLoggedFoodId = food.fdcId
                        self.trackRecentlyAdded(foodId: food.fdcId)
                        
                        // Set data for success toast in dashboard
                        self.lastLoggedItem = (name: food.displayName, calories: Double(loggedFood.food.calories))
                        self.showLogSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.showLogSuccess = false
                        }
                        
                        // Clear the lastLoggedFoodId after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                // Only clear if it still matches the food we logged
                                if self.lastLoggedFoodId == food.fdcId {
                                    self.lastLoggedFoodId = nil
                                }
                            }
                        }
                        
                        // Trigger review check after successful food log
                        ReviewManager.shared.foodWasLogged()
                        
                        // Track meal timing for smart reminders
                        MealReminderService.shared.mealWasLogged(mealType: loggedFood.mealType)
                    }
                    
             
                    
                case .failure(let error):
                    print("❌ Failed to log food: \(error.localizedDescription)")
                    
                    // Ensure all @Published property updates happen on main thread
                    DispatchQueue.main.async {
                        // Display error message
                        self.errorMessage = "Failed to log food: \(error.localizedDescription)"
                        
                        // Clear the lastLoggedFoodId immediately on error
                        self.lastLoggedFoodId = nil
                    }
                }
                
                // Call the completion handler
                completion()
            }
        }
    }
    
    
 


   
   
    // Helper method to get the device's timezone offset in minutes
    private func getTimezoneOffsetInMinutes() -> Int {
        return TimeZone.current.secondsFromGMT() / 60
    }
    
    // MARK: - Saved Meals Functions
    
    private func resetAndFetchSavedMeals(force: Bool = false) {
        print("💾 FoodManager: Reset and fetch saved meals called")

        guard !isFetchingSavedMeals else { return }

        currentSavedMealsPage = 1
        hasMoreSavedMeals = true
        isFetchingSavedMeals = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            let success = await self.savedMealsRepository.refresh(force: force)
            if success {
                self.lastSavedMealsFetchDate = Date()
                self.hasMoreSavedMeals = self.savedMealsRepository.snapshot.hasMore
                self.currentSavedMealsPage = self.savedMealsRepository.snapshot.nextPage
            }
            self.isFetchingSavedMeals = false
        }
    }
    func refreshSavedMeals() {
        print("🔄 FoodManager: Refreshing saved meals")
        lastSavedMealsFetchDate = nil
        resetAndFetchSavedMeals(force: true)
    }
    
    private func loadSavedMeals(refresh: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard userEmail != nil else {
            completion?(false)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                await MainActor.run { completion?(false) }
                return
            }

            let success: Bool
            if refresh {
                guard !self.savedMealsRepository.isRefreshing else {
                    await MainActor.run { completion?(false) }
                    return
                }
                success = await self.savedMealsRepository.refresh(force: true)
            } else {
                guard self.hasMoreSavedMeals else {
                    await MainActor.run { completion?(false) }
                    return
                }
                guard !self.savedMealsRepository.isLoadingNextPage else {
                    await MainActor.run { completion?(false) }
                    return
                }
                success = await self.savedMealsRepository.loadNextPage()
            }

            self.hasMoreSavedMeals = self.savedMealsRepository.snapshot.hasMore
            self.currentSavedMealsPage = self.savedMealsRepository.snapshot.nextPage
            if success {
                self.lastSavedMealsFetchDate = Date()
            }
            await MainActor.run { completion?(success) }
        }
    }

    func saveMeal(itemType: SavedItemType, itemId: Int, customName: String? = nil, notes: String? = nil, completion: @escaping (Result<SaveMealResponse, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NetworkManagerTwo.NetworkError.serverError(message: "User email not available")))
            return
        }
        
        let itemTypeString = itemType == .foodLog ? "food_log" : "meal_log"
        
        NetworkManagerTwo.shared.saveMeal(
            userEmail: email,
            itemType: itemTypeString,
            itemId: itemId,
            customName: customName,
            notes: notes
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Successfully saved meal: \(response.message)")
                    // Refresh the saved meals list to include the new item
                    self?.refreshSavedMeals()
                    
                    // Add to saved log IDs
                    self?.savedLogIds.insert(itemId)
                    
                    // Show saved meal toast
                    self?.showSavedMealToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.showSavedMealToast = false
                    }
                    
                    completion(.success(response))
                    
                case .failure(let error):
                    print("❌ Failed to save meal: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func unsaveMeal(savedMealId: Int, completion: @escaping (Result<UnsaveMealResponse, Error>) -> Void) {
        guard let email = userEmail else {
            completion(.failure(NetworkManagerTwo.NetworkError.serverError(message: "User email not available")))
            return
        }
        
        NetworkManagerTwo.shared.unsaveMeal(
            userEmail: email,
            savedMealId: savedMealId
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Successfully unsaved meal: \(response.message)")
                    // Remove the item from the local array and update saved log IDs
                    if let removedMeal = self?.savedMeals.first(where: { $0.id == savedMealId }) {
                        if removedMeal.itemType == .foodLog, let foodLog = removedMeal.foodLog, let foodLogId = foodLog.foodLogId {
                            self?.savedLogIds.remove(foodLogId)
                        } else if removedMeal.itemType == .mealLog, let mealLog = removedMeal.mealLog, let mealLogId = mealLog.mealLogId {
                            self?.savedLogIds.remove(mealLogId)
                        }
                    }
                    self?.savedMeals.removeAll { $0.id == savedMealId }
                    
                    // Show unsaved meal toast
                    self?.showUnsavedMealToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.showUnsavedMealToast = false
                    }
                    
                    completion(.success(response))
                    
                case .failure(let error):
                    print("❌ Failed to unsave meal: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Helper function to check if a log is saved
    func isLogSaved(foodLogId: Int? = nil, mealLogId: Int? = nil) -> Bool {
        if let foodLogId = foodLogId {
            return savedLogIds.contains(foodLogId)
        } else if let mealLogId = mealLogId {
            return savedLogIds.contains(mealLogId)
        }
        return false
    }
    
    // Helper function to find saved meal by log ID and unsave it
    func unsaveByLogId(foodLogId: Int? = nil, mealLogId: Int? = nil, completion: @escaping (Result<UnsaveMealResponse, Error>) -> Void) {
        var targetSavedMeal: SavedMeal?
        
        if let foodLogId = foodLogId {
            targetSavedMeal = savedMeals.first { savedMeal in
                savedMeal.itemType == .foodLog && savedMeal.foodLog?.foodLogId == foodLogId
            }
        } else if let mealLogId = mealLogId {
            targetSavedMeal = savedMeals.first { savedMeal in
                savedMeal.itemType == .mealLog && savedMeal.mealLog?.mealLogId == mealLogId
            }
        }
        
        guard let savedMeal = targetSavedMeal else {
            completion(.failure(NetworkManagerTwo.NetworkError.serverError(message: "Saved meal not found")))
            return
        }

        unsaveMeal(savedMealId: savedMeal.id, completion: completion)
    }
    
    // MARK: - Nutrition Label Name Input
    func createNutritionLabelFoodWithName(_ productName: String, completion: @escaping (Result<CombinedLog, Error>) -> Void) {
        guard !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let userEmail = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid product name or user email"])))
            return
        }
        
        print("🏷️ Creating nutrition label food with user-provided name: \(productName)")
        
        // Call the backend API to create food with the user-provided name and stored nutrition data
        let parameters: [String: Any] = [
            "user_email": userEmail,
            "name": productName.trimmingCharacters(in: .whitespacesAndNewlines),
            "nutrition_data": pendingNutritionData,
            "meal_type": pendingMealType
        ]
        
        // Create the food using NetworkManager
        guard let url = URL(string: "\(networkManager.baseUrl)/create_nutrition_label_food/") else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Network error creating nutrition label food: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    if let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Parse as LoggedFood and create CombinedLog (same as successful nutrition label scan)
                        let jsonData = try JSONSerialization.data(withJSONObject: payload)
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        
                        let loggedFood = try decoder.decode(LoggedFood.self, from: jsonData)
                        
                        let combinedLog = CombinedLog(
                            type: .food,
                            status: loggedFood.status,
                            calories: loggedFood.calories,
                            message: loggedFood.message,
                            foodLogId: loggedFood.foodLogId,
                            food: loggedFood.food,
                            mealType: loggedFood.mealType,
                            mealLogId: nil,
                            meal: nil,
                            mealTime: nil,
                            scheduledAt: Date(),
                            recipeLogId: nil,
                            recipe: nil,
                            servingsConsumed: nil
                        )
                        
                        // Check if we should show the sheet based on user preference
                        let shouldShowSheet = UserDefaults.standard.object(forKey: "scanPreview_foodLabel") as? Bool ?? true
                        
                        if shouldShowSheet {
                                // Show confirmation sheet for food label (similar to barcode)
                                let food = loggedFood.food.asFood
                            print("📊 Food label preview enabled - showing confirmation sheet")
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ShowFoodConfirmation"),
                                object: nil,
                                userInfo: [
                                    "food": food,
                                    "foodLogId": loggedFood.foodLogId ?? NSNull()
                                ]
                            )
                        } else {
                            // Add to logs directly (same as successful scan)
                            print("📊 Food label preview disabled - logging directly")
                            self.dayLogsViewModel?.addPending(combinedLog)
                            
                            if let idx = self.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                                self.combinedLogs.remove(at: idx)
                            }
                            self.combinedLogs.insert(combinedLog, at: 0)
                        }
                        
                        // Clear the pending state
                        self.showNutritionNameInput = false
                        self.pendingNutritionData = [:]
                        self.pendingMealType = "Lunch"
                        
                        completion(.success(combinedLog))
                        print("✅ Successfully created nutrition label food with user-provided name")
                    }
                } catch {
                    print("❌ Failed to parse response: \(error)")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func cancelNutritionNameInput() {
        showNutritionNameInput = false
        pendingNutritionData = [:]
        pendingMealType = "Lunch"
    }
    
    func cancelNutritionNameInputForCreation() {
        showNutritionNameInputForCreation = false
        pendingNutritionDataForCreation = [:]
        pendingMealTypeForCreation = "Lunch"
        // UNIFIED: Reset to inactive state when user cancels name input
        foodScanningState = .inactive
        isScanningFood = false
        isGeneratingFood = false
    }
    
    func cancelNutritionNameInputForRecipe() {
        showNutritionNameInputForRecipe = false
        pendingNutritionDataForRecipe = [:]
        pendingMealTypeForRecipe = "Lunch"
        // UNIFIED: Reset to inactive state when user cancels name input
        foodScanningState = .inactive
        isScanningFood = false
        isGeneratingFood = false
    }
    
    func showScanFailure(type: String, message: String) {
        scanFailureType = type
        scanFailureMessage = message
        showScanFailureAlert = true
        // Clear scanning states and hide modern loader
        isScanningFood = false
        isGeneratingFood = false
        // Immediately hide the modern loader for failure path (alert/sheet will be shown)
        updateFoodScanningState(.inactive)
    }
    
    // MARK: - Build Food Data Without Database Creation
    func buildFoodFromNutritionData(name: String, nutritionData: [String: Any], completion: @escaping (Result<Food, Error>) -> Void) {
        // Build Food object from nutrition data without hitting the backend
        let servingText = nutritionData["serving_size"] as? String ?? "1 serving"
        
        // Create food nutrients from the nutrition data
        var foodNutrients: [Nutrient] = []
        
        if let calories = nutritionData["calories"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Energy", value: calories, unitName: "kcal"))
        }
        if let protein = nutritionData["protein"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Protein", value: protein, unitName: "g"))
        }
        if let carbs = nutritionData["carbs"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Carbohydrate, by difference", value: carbs, unitName: "g"))
        }
        if let fat = nutritionData["fat"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Total lipid (fat)", value: fat, unitName: "g"))
        }
        if let saturatedFat = nutritionData["saturated_fat"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Saturated Fatty Acids", value: saturatedFat, unitName: "g"))
        }
        if let transFat = nutritionData["trans_fat"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Trans Fatty Acids", value: transFat, unitName: "g"))
        }
        if let cholesterol = nutritionData["cholesterol"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Cholesterol", value: cholesterol, unitName: "mg"))
        }
        if let sodium = nutritionData["sodium"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Sodium", value: sodium, unitName: "mg"))
        }
        if let totalCarbs = nutritionData["total_carbs"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Total Carbohydrate", value: totalCarbs, unitName: "g"))
        }
        if let dietaryFiber = nutritionData["dietary_fiber"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Dietary Fiber", value: dietaryFiber, unitName: "g"))
        }
        if let totalSugars = nutritionData["total_sugars"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Total Sugars", value: totalSugars, unitName: "g"))
        }
        if let addedSugars = nutritionData["added_sugars"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Added Sugars", value: addedSugars, unitName: "g"))
        }
        if let vitaminD = nutritionData["vitamin_d"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Vitamin D", value: vitaminD, unitName: "mcg"))
        }
        if let calcium = nutritionData["calcium"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Calcium", value: calcium, unitName: "mg"))
        }
        if let iron = nutritionData["iron"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Iron", value: iron, unitName: "mg"))
        }
        if let potassium = nutritionData["potassium"] as? Double {
            foodNutrients.append(Nutrient(nutrientName: "Potassium", value: potassium, unitName: "mg"))
        }
        
        // Create food measure
        let foodMeasure = FoodMeasure(
            disseminationText: servingText,
            gramWeight: 100.0,
            id: 1,
            modifier: servingText,
            measureUnitName: "serving",
            rank: 1
        )
        
        // Create the food object
        let food = Food(
            fdcId: Int.random(in: 1000000..<9999999), // Temporary ID
            description: name,
            brandOwner: nil,
            brandName: nil,
            servingSize: 1.0,
            numberOfServings: 1.0,
            servingSizeUnit: "serving",
            householdServingFullText: servingText,
            foodNutrients: foodNutrients,
            foodMeasures: [foodMeasure]
        )
        
        completion(.success(food))
    }
    
    // MARK: - Creation-Only Nutrition Label Food
    func createNutritionLabelFoodForCreation(_ productName: String, completion: @escaping (Result<Food, Error>) -> Void) {
        guard !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let userEmail = userEmail else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid product name or user email"])))
            return
        }
        
        print("🏷️ Creating nutrition label food for creation mode with user-provided name: \(productName)")
        
        // Call the backend API to create food with the user-provided name and stored nutrition data
        let parameters: [String: Any] = [
            "user_email": userEmail,
            "name": productName.trimmingCharacters(in: .whitespacesAndNewlines),
            "nutrition_data": pendingNutritionDataForCreation,
            "meal_type": pendingMealTypeForCreation,
            "should_log": false  // Key difference: don't log the food
        ]
        
        // Create the food using NetworkManager
        guard let url = URL(string: "\(networkManager.baseUrl)/create_nutrition_label_food_for_creation/") else {
            completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorMessage = json["error"] as? String {
                        completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                        return
                    }
                    
                    // Parse the food from the response
                    if let foodData = json["food"] as? [String: Any] {
                        // Extract health analysis from root level and merge it into food data
                        var completeFoodData = foodData
                        if let healthAnalysis = json["health_analysis"] {
                            completeFoodData["health_analysis"] = healthAnalysis
                            print("🩺 [DEBUG] Health analysis found and merged into food data (createNutritionLabelFoodForCreation)")
                            
                            // Debug: Print the actual health analysis data structure
                            if let healthDict = healthAnalysis as? [String: Any] {
                                print("🩺 [DEBUG] Health analysis keys: \(Array(healthDict.keys))")
                                print("🩺 [DEBUG] Health analysis score from payload: \(healthDict["score"] ?? "nil")")
                                print("🩺 [DEBUG] Health analysis color from payload: \(healthDict["color"] ?? "nil")")
                            }
                        } else {
                            print("⚠️ [DEBUG] No health analysis found in response (createNutritionLabelFoodForCreation)")
                        }
                        
                        // Debug: Print the complete food data structure before decoding
                        print("🩺 [DEBUG] Complete food data keys: \(Array(completeFoodData.keys))")
                        if let healthInFood = completeFoodData["health_analysis"] as? [String: Any] {
                            print("🩺 [DEBUG] Health analysis in complete food data - score: \(healthInFood["score"] ?? "nil")")
                        }
                        
                        let jsonData = try JSONSerialization.data(withJSONObject: completeFoodData, options: [])
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        
                        // Debug: Print the actual JSON being decoded
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            print("🩺 [DEBUG] JSON being decoded (createNutritionLabelFoodForCreation): \(jsonString)")
                        }
                        
                        let food = try decoder.decode(Food.self, from: jsonData)
                        
                        print("🩺 [DEBUG] Food decoded. Health analysis present: \(food.healthAnalysis != nil)")
                        if let healthAnalysis = food.healthAnalysis {
                            print("🩺 [DEBUG] Health analysis score: \(healthAnalysis.score)")
                            print("🩺 [DEBUG] Health analysis negatives count: \(healthAnalysis.negatives.count)")
                            print("🩺 [DEBUG] Health analysis positives count: \(healthAnalysis.positives.count)")
                        }
                        
                        // Clear the pending state for creation
                        DispatchQueue.main.async {
                            self.showNutritionNameInputForCreation = false
                            self.pendingNutritionDataForCreation = [:]
                            self.pendingMealTypeForCreation = "Lunch"
                        }
                        
                        completion(.success(food))
                        print("✅ Successfully created nutrition label food for creation with user-provided name")
                    } else {
                        completion(.failure(NSError(domain: "FoodManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                    }
                }
            } catch {
                print("❌ Failed to parse response: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Creation-Only Functions
    // These functions create foods without logging them, for use in food creation contexts
    
    @MainActor
    func analyzeFoodImageForCreation(
        image: UIImage,
        userEmail: String,
        completion: @escaping (Result<Food, Error>) -> Void
    ) {
        // ─── 1) UI state ─────────────────────────────
        isAnalyzingImage = true
        isLoading        = true
        imageAnalysisMessage = "Analyzing image for creation…"
        uploadProgress   = 0

        // Deterministic, smooth progress without timers
        updateFoodScanningState(.uploading(progress: 0.2))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateFoodScanningState(.uploading(progress: 0.5))
        }
        
        // ─── 3) Call backend ─────────────────────────
        NetworkManagerTwo.shared.analyzeFoodImageForCreation(image: image, userEmail: userEmail) { [weak self] success, payload, errMsg in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Ensure local progress completes
                self.uploadProgress = 1.0
                
                // failure path
                guard success, let payload = payload else {
                    let msg = errMsg ?? "Unknown error"
                    print("🔴 [analyzeFoodImageForCreation] error: \(msg)")
                    
                    // UNIFIED: Show error state then reset
                    self.updateFoodScanningState(.failed(error: .networkError(msg)))
                    
                    // Reset after showing error for a moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.resetFoodScanningState()
                        self.isAnalyzingImage = false
                        self.isLoading = false
                        // Reset other scanning states
                        self.isScanningFood = false
                        self.isGeneratingFood = false
                        self.scannedImage = nil
                        self.uploadProgress = 0
                        self.loadingMessage = ""
                    }
                    
                    completion(.failure(NSError(
                        domain: "FoodScan", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: msg])))
                    return
                }
                
                //── 4) Parse response as Food object (not LoggedFood)
                do {
                    if let foodData = payload["food"] as? [String: Any] {
                        // Health analysis should already be inside foodData from backend
                        let completeFoodData = foodData
                        if let healthAnalysis = foodData["health_analysis"] {
                            print("🩺 [DEBUG] Health analysis found in food data (analyzeFoodImageForCreation)")
                        } else {
                            print("⚠️ [DEBUG] No health analysis found in response (analyzeFoodImageForCreation)")
                        }
                        
                        let jsonData = try JSONSerialization.data(withJSONObject: completeFoodData, options: [])
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let food = try decoder.decode(Food.self, from: jsonData)
                        
                        print("🩺 [DEBUG] Food decoded (analyzeFoodImageForCreation). Health analysis present: \(food.healthAnalysis != nil)")
                        if let healthAnalysis = food.healthAnalysis {
                            print("🩺 [DEBUG] Health analysis score (analyzeFoodImageForCreation): \(healthAnalysis.score)")
                        }
                        
                        // UNIFIED: Show completion with proper animation
                        let completionLog = CombinedLog(
                            type: .food,
                            status: "success",
                            calories: food.calories ?? 0,
                            message: "Analyzed \(food.displayName)",
                            foodLogId: nil
                        )
                        // Transition through analyzing → processing → completed for smoothness
                        self.updateFoodScanningState(.analyzing)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.updateFoodScanningState(.processing)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                self.updateFoodScanningState(.completed(result: completionLog))
                            }
                        }
                        
                        // Auto-reset after showing completion
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.resetFoodScanningState()
                            self.isAnalyzingImage = false
                            self.isLoading = false
                            // Reset other scanning states
                            self.isScanningFood = false
                            self.isGeneratingFood = false
                            self.scannedImage = nil
                            self.uploadProgress = 0
                            self.loadingMessage = ""
                        }
                        
                        completion(.success(food))
                    } else {
                        // UNIFIED: Show error state for invalid response
                        self.updateFoodScanningState(.failed(error: .networkError("Invalid response format")))
                        
                        // Reset after showing error
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.resetFoodScanningState()
                            self.isAnalyzingImage = false
                            self.isLoading = false
                            self.isScanningFood = false
                            self.isGeneratingFood = false
                            self.scannedImage = nil
                            self.uploadProgress = 0
                            self.loadingMessage = ""
                        }
                        
                        completion(.failure(NSError(
                            domain: "FoodManager", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                    }
                } catch {
                    print("❌ [analyzeFoodImageForCreation] decoding error:", error)
                    
                    // UNIFIED: Show error state for decoding error
                    self.updateFoodScanningState(.failed(error: .networkError(error.localizedDescription)))
                    
                    // Reset after showing error
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.resetFoodScanningState()
                        self.isAnalyzingImage = false
                        self.isLoading = false
                        self.isScanningFood = false
                        self.isGeneratingFood = false
                        self.scannedImage = nil
                        self.uploadProgress = 0
                        self.loadingMessage = ""
                    }
                    
                    completion(.failure(error))
                }
            }
        }
    }
    
    @MainActor
    func analyzeNutritionLabelForCreation(
        image: UIImage,
        userEmail: String,
        completion: @escaping (Result<Food, Error>) -> Void
    ) {
        // ─── 1) UI state ─────────────────────────────
        isAnalyzingImage = true
        isLoading        = true
        imageAnalysisMessage = "Reading nutrition label for creation…"
        uploadProgress   = 0
        
        // Deterministic, smooth progress without timers
        updateFoodScanningState(.uploading(progress: 0.2))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateFoodScanningState(.uploading(progress: 0.5))
        }
        
        // ─── 3) Call backend ─────────────────────────
        NetworkManagerTwo.shared.analyzeNutritionLabelForCreation(image: image, userEmail: userEmail) { [weak self] success, payload, errMsg in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Ensure local progress completes
                self.uploadProgress = 1.0
                
                // failure path
                guard success, let payload = payload else {
                    let msg = errMsg ?? "Unknown error"
                    print("🔴 [analyzeNutritionLabelForCreation] error: \(msg)")
                    
                    // UNIFIED: Show error state then reset
                    self.updateFoodScanningState(.failed(error: .networkError(msg)))
                    
                    // Reset after showing error for a moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.resetFoodScanningState()
                        self.isAnalyzingImage = false
                        self.isLoading = false
                        // Reset other scanning states
                        self.isScanningFood = false
                        self.isGeneratingFood = false
                        self.scannedImage = nil
                        self.uploadProgress = 0
                        self.loadingMessage = ""
                    }
                    
                    completion(.failure(NSError(
                        domain: "FoodManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: msg]
                    )))
                    return
                }
                
                // ─── 4) Check if name input is required ─────────────────
                if let status = payload["status"] as? String, status == "name_required" {
                    // Product name not found - we need user input
                    print("🏷️ [analyzeNutritionLabelForCreation] Product name not found, user input required")
                    
                    // UNIFIED: Show error state for name required then reset
                    self.updateFoodScanningState(.failed(error: .networkError("Product name not found on label")))
                    
                    // Reset after showing error
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.resetFoodScanningState()
                        self.isAnalyzingImage = false
                        self.isLoading = false
                        self.isScanningFood = false
                        self.isGeneratingFood = false
                        self.scannedImage = nil
                        self.uploadProgress = 0
                        self.loadingMessage = ""
                    }
                    
                    // For creation context, we still need to handle name input
                    // This would need UI handling similar to the logging version
                    completion(.failure(NSError(
                        domain: "FoodManager",
                        code: 1001, // Custom code for name required
                        userInfo: [
                            NSLocalizedDescriptionKey: "Product name not found on label",
                            "nutrition_data": payload["nutrition_data"] ?? [:],
                            "meal_type": "Lunch", // Default meal type for creation mode
                            "is_creation_flow": true // Flag to distinguish creation vs logging
                        ]
                    )))
                    return
                }
                
                // ─── 5) Parse response as Food object (not LoggedFood) ───────────
                do {
                    if let foodData = payload["food"] as? [String: Any] {
                        // Extract health analysis from root level and merge it into food data
                        var completeFoodData = foodData
                        if let healthAnalysis = payload["health_analysis"] {
                            completeFoodData["health_analysis"] = healthAnalysis
                            print("🩺 [DEBUG] Health analysis found and merged into food data (analyzeNutritionLabelForCreation)")
                            
                            // Debug: Print the actual health analysis data structure
                            if let healthDict = healthAnalysis as? [String: Any] {
                                print("🩺 [DEBUG] Health analysis keys: \(Array(healthDict.keys))")
                                print("🩺 [DEBUG] Health analysis score from payload: \(healthDict["score"] ?? "nil")")
                                print("🩺 [DEBUG] Health analysis color from payload: \(healthDict["color"] ?? "nil")")
                            }
                        } else {
                            print("⚠️ [DEBUG] No health analysis found in response (analyzeNutritionLabelForCreation)")
                        }
                        
                        // Debug: Print the complete food data structure before decoding
                        print("🩺 [DEBUG] Complete food data keys: \(Array(completeFoodData.keys))")
                        if let healthInFood = completeFoodData["health_analysis"] as? [String: Any] {
                            print("🩺 [DEBUG] Health analysis in complete food data - score: \(healthInFood["score"] ?? "nil")")
                        }
                        
                        let jsonData = try JSONSerialization.data(withJSONObject: completeFoodData, options: [])
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        
                        // Debug: Print the actual JSON being decoded
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            print("🩺 [DEBUG] JSON being decoded (analyzeNutritionLabelForCreation): \(jsonString)")
                        }
                        
                        let food = try decoder.decode(Food.self, from: jsonData)
                        
                        print("🩺 [DEBUG] Food decoded (analyzeNutritionLabelForCreation). Health analysis present: \(food.healthAnalysis != nil)")
                        if let healthAnalysis = food.healthAnalysis {
                            print("🩺 [DEBUG] Health analysis score (analyzeNutritionLabelForCreation): \(healthAnalysis.score)")
                        }
                        
                        // UNIFIED: Show completion with proper animation
                        let completionLog = CombinedLog(
                            type: .food,
                            status: "success",
                            calories: food.calories ?? 0,
                            message: "Analyzed \(food.displayName)",
                            foodLogId: nil
                        )
                        // Transition through analyzing → processing → completed for smooth animation
                        self.updateFoodScanningState(.analyzing)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.updateFoodScanningState(.processing)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                self.updateFoodScanningState(.completed(result: completionLog))
                            }
                        }
                        
                        // Auto-reset after showing completion
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.resetFoodScanningState()
                            self.isAnalyzingImage = false
                            self.isLoading = false
                            // Reset other scanning states
                            self.isScanningFood = false
                            self.isGeneratingFood = false
                            self.scannedImage = nil
                            self.uploadProgress = 0
                            self.loadingMessage = ""
                        }
                        
                        completion(.success(food))
                    } else {
                        // UNIFIED: Show error state for invalid response
                        self.updateFoodScanningState(.failed(error: .networkError("Invalid response format")))
                        
                        // Reset after showing error
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.resetFoodScanningState()
                            self.isAnalyzingImage = false
                            self.isLoading = false
                            self.isScanningFood = false
                            self.isGeneratingFood = false
                            self.scannedImage = nil
                            self.uploadProgress = 0
                            self.loadingMessage = ""
                        }
                        
                        completion(.failure(NSError(
                            domain: "FoodManager", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                    }
                } catch {
                    print("❌ [analyzeNutritionLabelForCreation] decoding error:", error)
                    
                    // UNIFIED: Show error state for decoding error
                    self.updateFoodScanningState(.failed(error: .networkError(error.localizedDescription)))
                    
                    // Reset after showing error
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.resetFoodScanningState()
                        self.isAnalyzingImage = false
                        self.isLoading = false
                        self.isScanningFood = false
                        self.isGeneratingFood = false
                        self.scannedImage = nil
                        self.uploadProgress = 0
                        self.loadingMessage = ""
                    }
                    
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Timer Management and Cleanup Functions
    
    /// Only cancel timers without resetting loading states
    func cancelTimersOnly() {
        print("🔍 CRASH_DEBUG: cancelTimersOnly called - preserving progress timer to show continued loading")
        
        // DON'T invalidate progress timer - let it continue until network completes
        // progressTimer?.invalidate()  // REMOVED - this was causing progress to freeze at 10%
        
        // Only invalidate non-essential timers (stage animations, etc)
        for timer in activeTimers {
            // Only invalidate if it's not the main progress timer
            if timer != progressTimer {
                timer.invalidate()
                print("🔍 CRASH_DEBUG: Invalidated non-progress timer: \(timer)")
            }
        }
        // Remove invalidated timers but keep progress timer
        activeTimers = activeTimers.filter { $0 == progressTimer }
        
        print("🔍 CRASH_DEBUG: Non-essential timers cleaned up, progress timer preserved for smooth loading")
    }
    
    /// Cancel all ongoing operations and timers to prevent crashes (OLD - kept for compatibility)
    func cancelOngoingOperations() {
        print("🔍 CRASH_DEBUG: cancelOngoingOperations called - invalidating all active timers")
        
        // Mark scanner as dismissed to prevent new UI updates
        scannerDismissed = true
        
        // Invalidate main progress timer
        progressTimer?.invalidate()
        progressTimer = nil
        
        // Invalidate all tracked active timers
        for timer in activeTimers {
            timer.invalidate()
            print("🔍 CRASH_DEBUG: Invalidated timer: \(timer)")
        }
        activeTimers.removeAll()
        
        // Note: We don't cancel network operations as they should complete
        // We just prevent UI updates after scanner dismissal
        print("🔍 CRASH_DEBUG: All timers invalidated, operations cancelled")
    }
    
    /// Reset all scanning-related @Published states
    func resetScanningStates() {
        print("🔍 CRASH_DEBUG: resetScanningStates called - clearing all scanning UI states")
        
        // Use main thread for all @Published updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Reset image analysis states
            self.isAnalyzingImage = false
            self.isLoading = false
            self.isScanningFood = false
            self.imageAnalysisMessage = ""
            self.loadingMessage = ""
            
            // Reset barcode states
            self.isScanningBarcode = false
            self.barcodeLoadingMessage = ""
            
            // UNIFIED: Reset to inactive state  
            self.foodScanningState = .inactive
            self.isGeneratingFood = false
            self.isGeneratingMacros = false
            self.isGeneratingMeal = false
            self.macroLoadingMessage = ""
            
            // Reset progress
            self.uploadProgress = 0.0
            
            // Clear scanned image reference
            self.scannedImage = nil
            
            print("🔍 CRASH_DEBUG: All scanning states reset on main thread")
        }
    }
    
    /// Helper to track timers for cleanup
    private func trackTimer(_ timer: Timer) {
        activeTimers.insert(timer)
    }
    
    /// Reset scanner dismissed flag when new scan starts
    private func resetScannerDismissedFlag() {
        scannerDismissed = false
        print("🔍 CRASH_DEBUG: Scanner dismissed flag reset - new scan can proceed")
    }
    
    // MARK: - Memory Management Functions
    
    /// Optimize image size and quality to prevent memory crashes
    private func optimizeImageForProcessing(_ image: UIImage) -> UIImage {
        // CRITICAL FIX: Defensive check for invalid image
        guard image.size.width > 0 && image.size.height > 0 else {
            print("❌ CRASH_DEBUG: Invalid image dimensions: \(image.size)")
            return image
        }
        
        let originalSize = image.size
        let originalData = image.jpegData(compressionQuality: 1.0)
        let originalSizeMB = Double(originalData?.count ?? 0) / 1024.0 / 1024.0
        
        // If image is under 10MB, no optimization needed
        guard originalSizeMB > 10.0 else {
            print("🔍 MEMORY_DEBUG: Image size (\(String(format: "%.1f", originalSizeMB))MB) is acceptable, no optimization needed")
            return image
        }
        
        print("🔍 MEMORY_DEBUG: Large image detected (\(String(format: "%.1f", originalSizeMB))MB), applying optimization")
        
        // Calculate target size - max 2048x2048 for processing
        let maxDimension: CGFloat = 2048
        var targetSize = originalSize
        
        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            let aspectRatio = originalSize.width / originalSize.height
            if originalSize.width > originalSize.height {
                targetSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                targetSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
            print("🔍 MEMORY_DEBUG: Resizing from \(originalSize) to \(targetSize)")
        }
        
        // Create optimized image with error handling
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        
        guard let optimizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("❌ CRASH_DEBUG: Failed to create optimized image, returning original")
            return image
        }
        
        // Verify optimization worked
        let optimizedData = optimizedImage.jpegData(compressionQuality: 0.8)
        let optimizedSizeMB = Double(optimizedData?.count ?? 0) / 1024.0 / 1024.0
        print("🔍 MEMORY_DEBUG: Image optimized from \(String(format: "%.1f", originalSizeMB))MB to \(String(format: "%.1f", optimizedSizeMB))MB")
        
        return optimizedImage
    }
    
    /// Monitor memory usage and handle memory warnings
    private func checkMemoryPressure() -> Bool {
        let memoryUsage = getMemoryUsage()
        let usedMemoryMB = memoryUsage.used
        let availableMemoryMB = memoryUsage.available
        
        // Consider high memory pressure if using more than 300MB or less than 100MB available
        let isHighPressure = usedMemoryMB > 300 || availableMemoryMB < 100
        
        if isHighPressure {
            print("⚠️ MEMORY_DEBUG: High memory pressure detected - Used: \(String(format: "%.1f", usedMemoryMB))MB, Available: \(String(format: "%.1f", availableMemoryMB))MB")
        }
        
        return isHighPressure
    }
}
