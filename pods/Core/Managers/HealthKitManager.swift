import Foundation
import HealthKit

class HealthKitManager {
    // Singleton instance
    static let shared = HealthKitManager()
    
    // HealthKit store
    private let healthStore = HKHealthStore()
    
    // Check if HealthKit is available on this device
    var isHealthDataAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    // Check if user has authorized HealthKit access
    var isAuthorized: Bool {
        return UserDefaults.standard.bool(forKey: "healthKitEnabled")
    }
    
    private init() {}
    
    // MARK: - Data Fetching Methods
    
    // Fetch step count for a specific date
    func fetchStepCount(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let predicate = createDayPredicate(for: date)
        let query = HKStatisticsQuery(
            quantityType: stepsQuantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(nil, error)
                return
            }
            
            let steps = sum.doubleValue(for: HKUnit.count())
            completion(steps, nil)
        }
        
        healthStore.execute(query)
    }
    
    // Fetch active energy burned (calories) for a specific date
    func fetchActiveEnergy(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        let predicate = createDayPredicate(for: date)
        let query = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(nil, error)
                return
            }
            
            let calories = sum.doubleValue(for: HKUnit.kilocalorie())
            completion(calories, nil)
        }
        
        healthStore.execute(query)
    }
    
    // Fetch dietary nutrients for a specific day
    func fetchNutrientData(for date: Date, completion: @escaping ([HKQuantityTypeIdentifier: Double], Error?) -> Void) {
        let nutritionTypes: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryFatTotal,
            .dietaryCarbohydrates
        ]
        
        var results: [HKQuantityTypeIdentifier: Double] = [:]
        let group = DispatchGroup()
        var queryError: Error?
        
        for typeIdentifier in nutritionTypes {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else { continue }
            
            group.enter()
            let predicate = createDayPredicate(for: date)
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                defer { group.leave() }
                
                if let error = error {
                    queryError = error
                    return
                }
                
                guard let result = result, let sum = result.sumQuantity() else { return }
                
                let unit: HKUnit
                switch typeIdentifier {
                case .dietaryEnergyConsumed:
                    unit = HKUnit.kilocalorie()
                case .dietaryProtein, .dietaryFatTotal, .dietaryCarbohydrates:
                    unit = HKUnit.gram()
                default:
                    unit = HKUnit.gram()
                }
                
                results[typeIdentifier] = sum.doubleValue(for: unit)
            }
            
            healthStore.execute(query)
        }
        
        group.notify(queue: .main) {
            completion(results, queryError)
        }
    }
    
    // Fetch recent workouts
    func fetchWorkouts(from startDate: Date, to endDate: Date, completion: @escaping ([HKWorkout]?, Error?) -> Void) {
        let workoutType = HKObjectType.workoutType()
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: predicate,
            limit: 10, // Fetch the 10 most recent workouts
            sortDescriptors: [sortDescriptor]
        ) { (query, samples, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let workouts = samples as? [HKWorkout]
                completion(workouts, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    // Fetch water intake for a specific date
    func fetchWaterIntake(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        
        let predicate = createDayPredicate(for: date)
        let query = HKStatisticsQuery(
            quantityType: waterType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(nil, error)
                return
            }
            
            // Convert to liters (1 liter = 1000 ml)
            let waterInLiters = sum.doubleValue(for: HKUnit.liter())
            completion(waterInLiters, nil)
        }
        
        healthStore.execute(query)
    }
    
    // Fetch body weight
    func fetchBodyWeight(completion: @escaping (Double?, Error?) -> Void) {
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        
        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { (query, samples, error) in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil, error)
                return
            }
            
            let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            completion(weightInKg, nil)
        }
        
        healthStore.execute(query)
    }
    
    // Fetch walking and running distance for a specific date
    func fetchDistance(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        
        let predicate = createDayPredicate(for: date)
        let query = HKStatisticsQuery(
            quantityType: distanceType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(nil, error)
                return
            }
            
            // Convert to miles
            let distanceInMiles = sum.doubleValue(for: HKUnit.mile())
            completion(distanceInMiles, nil)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Helper Methods
    
    // Create a predicate for a specific day (midnight to midnight)
    private func createDayPredicate(for date: Date) -> NSPredicate {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
    }
}
