import Foundation
import HealthKit

class HealthKitManager {
    /// Human‑readable name for the HKCategoryValueSleepAnalysis value.
    private static func sleepStageName(for value: Int) -> String {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:            return "inBed"
        case HKCategoryValueSleepAnalysis.awake.rawValue:            return "awake"
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:return "asleepUnspecified"
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:       return "asleepCore"
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:       return "asleepDeep"
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:        return "asleepREM"
        default:                                                     return "unknown(\(value))"
        }
    }
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
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        // Check UserDefaults first - if user explicitly disabled it, respect that
        let userDefaultsEnabled = UserDefaults.standard.bool(forKey: "healthKitEnabled")
        guard userDefaultsEnabled else { return false }
        
        // IMPORTANT: Apple Health authorization status is unreliable
        // Even when it shows "denied" (status 1), data queries often work
        // So we'll assume it's authorized if UserDefaults says so
        
        print("🔍 HealthKit Authorization Check:")
        print("  - UserDefaults enabled: \(userDefaultsEnabled)")
        print("  - Final result: \(userDefaultsEnabled) (ignoring unreliable auth status)")
        
        return userDefaultsEnabled
    }
    
    private init() {}
    
    // MARK: - Permission Methods
    
    // Check and request health permissions on app start if needed
    func checkAndRequestHealthPermissions(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            // HealthKit not available on this device
            UserDefaults.standard.set(false, forKey: "healthKitEnabled")
            completion(false)
            return
        }
        
        // Get status for a representative set of health data types
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        // Check current authorization status
        let authStatus = healthStore.authorizationStatus(for: stepType)
        
        // Only request if we need to (not determined or denied status)
        let typesToRead = getHealthDataTypesForRequest()
        let typesToShare = getHealthDataTypesForShare()
        if authStatus != .sharingAuthorized {
            // Request authorization
            healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ HealthKit authorization error: \(error.localizedDescription)")
                    }
                    
                    // Save the user preference
                    UserDefaults.standard.set(success, forKey: "healthKitEnabled")
                    let statusMessage = success ? "granted" : "denied"
                    print("✅ HealthKit authorization result: \(statusMessage)")
                    
                    // Notify of permission status
                    completion(success)
                    
                    // Post notification that permission state changed
                    NotificationCenter.default.post(name: NSNotification.Name("HealthKitPermissionsChanged"), object: nil)
                }
            }
        } else {
            // Already authorized
            UserDefaults.standard.set(true, forKey: "healthKitEnabled")
            completion(true)
        }
    }
    
    // Get all health data types we want to request
    private func getHealthDataTypesForRequest() -> Set<HKObjectType> {
        var typesToRead: Set<HKObjectType> = []
        
        // COMPREHENSIVE LIST OF ALL HEALTHKIT DATA TYPES
        
        // Activity and Fitness metrics
        let activityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .distanceWalkingRunning,
            .distanceCycling,
            .distanceSwimming,
            .distanceDownhillSnowSports,
            .distanceWheelchair,
            .pushCount,
            .flightsClimbed,
            .appleExerciseTime,
            .appleStandTime,
            .appleMoveTime,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .walkingSpeed,
            .walkingStepLength,
            .walkingAsymmetryPercentage,
            .walkingDoubleSupportPercentage,
            .sixMinuteWalkTestDistance,
            .stairAscentSpeed,
            .stairDescentSpeed,
            .vo2Max
        ]
        
        // Body measurements
        let bodyMeasurementTypes: [HKQuantityTypeIdentifier] = [
            .height,
            .bodyMass,
            .bodyFatPercentage,
            .leanBodyMass,
            .bodyMassIndex,
            .waistCircumference,
            .appleWalkingSteadiness,
            .physicalEffort
        ]
        
        // Vital signs
        let vitalSignTypes: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .walkingHeartRateAverage,
            .respiratoryRate,
            .oxygenSaturation,
            .bodyTemperature,
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
            .peripheralPerfusionIndex,
            .bloodAlcoholContent,
            .electrodermalActivity,
            .environmentalAudioExposure,
            .environmentalSoundReduction,
            .headphoneAudioExposure,
            .forcedExpiratoryVolume1,
            .forcedVitalCapacity,
            .inhalerUsage,
            .insulinDelivery,
            .numberOfTimesFallen,
            .peakExpiratoryFlowRate,
            .uvExposure
        ]
        
        // Nutrition
        let nutritionTypes: [HKQuantityTypeIdentifier] = [
            .dietaryBiotin,
            .dietaryCaffeine,
            .dietaryCalcium,
            .dietaryCarbohydrates,
            .dietaryChloride,
            .dietaryCholesterol,
            .dietaryChromium,
            .dietaryCopper,
            .dietaryEnergyConsumed,
            .dietaryFatMonounsaturated,
            .dietaryFatPolyunsaturated,
            .dietaryFatSaturated,
            .dietaryFatTotal,
            .dietaryFiber,
            .dietaryFolate,
            .dietaryIodine,
            .dietaryIron,
            .dietaryMagnesium,
            .dietaryManganese,
            .dietaryMolybdenum,
            .dietaryNiacin,
            .dietaryPantothenicAcid,
            .dietaryPhosphorus,
            .dietaryPotassium,
            .dietaryProtein,
            .dietaryRiboflavin,
            .dietarySelenium,
            .dietarySodium,
            .dietarySugar,
            .dietaryThiamin,
            .dietaryVitaminA,
            .dietaryVitaminB12,
            .dietaryVitaminB6,
            .dietaryVitaminC,
            .dietaryVitaminD,
            .dietaryVitaminE,
            .dietaryVitaminK,
            .dietaryWater,
            .dietaryZinc
        ]
        
        // Lab and Test Results
        let labResultTypes: [HKQuantityTypeIdentifier] = [
            .bloodGlucose,
            .bloodAlcoholContent,
            .bloodPressureDiastolic,
            .bloodPressureSystolic,
            .electrodermalActivity
        ]
        
        // Reproductive Health
        let reproductiveTypes: [HKQuantityTypeIdentifier] = [
            .basalBodyTemperature,
            .oxygenSaturation
        ]
        
        // Mobility
        let mobilityTypes: [HKQuantityTypeIdentifier] = [
            .appleWalkingSteadiness,
            .runningGroundContactTime,
            .runningPower,
            .runningSpeed,
            .runningStrideLength,
            .runningVerticalOscillation,
            .sixMinuteWalkTestDistance,
            .stairAscentSpeed,
            .stairDescentSpeed,
            .walkingAsymmetryPercentage,
            .walkingDoubleSupportPercentage,
            .walkingSpeed,
            .walkingStepLength
        ]
        
        // All category types
        let categoryTypes: [HKCategoryTypeIdentifier] = [
            .appleStandHour,
            .highHeartRateEvent,
            .irregularHeartRhythmEvent,
            .lowHeartRateEvent,
            .sleepAnalysis,
            .toothbrushingEvent,
            .mindfulSession,
            .abdominalCramps,
            .acne,
            .bladderIncontinence,
            .bloating,
            .breastPain,
            .cervicalMucusQuality,
            .contraceptive,
            .coughing,
            .dizziness,
            .drySkin,
            .environmentalAudioExposureEvent,
            .fatigue,
            .fever,
            .generalizedBodyAche,
            .hairLoss,
            .handwashingEvent,
            .headache,
            .heartburn,
            .hotFlashes,
            .lowerBackPain,
            .moodChanges,
            .nausea,
            .pelvicPain,
            .rapidPoundingOrFlutteringHeartbeat,
            .runnyNose,
            .sexualActivity,
            .shortnessOfBreath,
            .sinusCongestion,
            .skippedHeartbeat,
            .soreThroat,
            .vomiting,
            .wheezing,
            .intermenstrualBleeding,
            .infrequentMenstrualCycles,
            .irregularMenstrualCycles,
            .persistentIntermenstrualBleeding,
            .prolongedMenstrualPeriods,
            .lactation,
            .pregnancy,
            .ovulationTestResult,
            .menstrualFlow,
            .pregnancyTestResult
        ]
        
        // Add all workout types
        let workoutType = HKObjectType.workoutType()
        typesToRead.insert(workoutType)
        
        // Add all sample types to our read set
        for typeId in activityTypes + bodyMeasurementTypes + vitalSignTypes + nutritionTypes + labResultTypes + reproductiveTypes + mobilityTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: typeId) {
                typesToRead.insert(type)
            }
        }
        
        // Add all category types
        for typeId in categoryTypes {
            if let type = HKCategoryType.categoryType(forIdentifier: typeId) {
                typesToRead.insert(type)
            }
        }
        
        // Add characteristics types that don't need to be included in authorization requests
        // but are still useful for read operations
        if #available(iOS 14.0, *) {
            typesToRead.insert(HKObjectType.characteristicType(forIdentifier: .activityMoveMode)!)
        }
        
        // Always add these characteristic types (some may be omitted based on OS versions)
        typesToRead.insert(HKObjectType.characteristicType(forIdentifier: .biologicalSex)!)
        typesToRead.insert(HKObjectType.characteristicType(forIdentifier: .bloodType)!)
        typesToRead.insert(HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!)
        typesToRead.insert(HKObjectType.characteristicType(forIdentifier: .fitzpatrickSkinType)!)
        typesToRead.insert(HKObjectType.characteristicType(forIdentifier: .wheelchairUse)!)
        
        return typesToRead
    }
    
    private func getHealthDataTypesForShare() -> Set<HKSampleType> {
        var typesToShare: Set<HKSampleType> = []

        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned,
            .basalEnergyBurned,
            .stepCount,
            .distanceWalkingRunning,
            .distanceCycling,
            .distanceSwimming,
            .vo2Max,
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .respiratoryRate,
            .bodyMass,
            .bodyMassIndex,
            .bodyFatPercentage,
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .bloodGlucose
        ]

        for identifier in quantityTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                typesToShare.insert(type)
            }
        }

        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            typesToShare.insert(sleepType)
        }

        if let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            typesToShare.insert(mindfulType)
        }

        typesToShare.insert(HKObjectType.workoutType())

        return typesToShare
    }

    // MARK: - Data Fetching Methods
    
    // Fetch step count for a specific date
    func fetchStepCount(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(nil, NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Step count type not available"]))
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            let stepCount = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            completion(stepCount, nil)
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
    
    // Fetch basal energy burned (BMR) for a specific date
    func fetchBasalEnergy(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        let energyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!
        
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
    
    // Fetch height
    func fetchHeight(completion: @escaping (Double?, Error?) -> Void) {
        let heightType = HKQuantityType.quantityType(forIdentifier: .height)!
        
        let query = HKSampleQuery(
            sampleType: heightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { (query, samples, error) in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil, error)
                return
            }
            
            let heightInCm = sample.quantity.doubleValue(for: HKUnit.meterUnit(with: .centi))
            completion(heightInCm, nil)
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
    
    // Fetch sleep data for a specific date
    func fetchSleepData(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            DispatchQueue.main.async {
                completion(nil, NSError(domain: "com.pods.healthkit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sleep analysis type not available"]))
            }
            return
        }

        // Apple's Sleep "day" is not midnight‑to‑midnight. The Health app groups a night's
        // sleep with the calendar day on which it **ends**, using a 24‑hour window that
        // runs from local noon of the previous day up to (but not including) local noon
        // of the target day. Querying that window captures the entire overnight session,
        // even the part that started before midnight.
        let calendar = Calendar.current
        var noonComponents = calendar.dateComponents([.year, .month, .day], from: date)
        noonComponents.hour = 12
        noonComponents.minute = 0
        noonComponents.second = 0
        guard let noonOfTargetDay = calendar.date(from: noonComponents) else {
            DispatchQueue.main.async {
                completion(nil, NSError(domain: "com.pods.healthkit",
                                        code: 2,
                                        userInfo: [NSLocalizedDescriptionKey: "Could not calculate noon anchor date"]))
            }
            return
        }
        
        // 24‑hour window ending at target‑day noon
        let startOfWindow = calendar.date(byAdding: .day, value: -1, to: noonOfTargetDay)!
        let endOfWindow   = noonOfTargetDay
        
        // Query for samples that intersect with our window (not just end date)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfWindow,
            end: endOfWindow,
            options: []
        )
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { (_, samples, error) in
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }

            let sleepSamples = samples as? [HKCategorySample] ?? []
            print("──────── Sleep samples for selected date (\(date)) ────────")
            for s in sleepSamples {
                let stage = HealthKitManager.sleepStageName(for: s.value)
                let mins  = Int(s.endDate.timeIntervalSince(s.startDate) / 60)
                print(" • \(stage)  \(s.startDate) → \(s.endDate)  (\(mins) min)")
            }
            print("───────────────────────────────────────────────────────────")
            print("🛌 Found \(sleepSamples.count) sleep samples for date: \(date)")

            // Filter to only asleep stages and avoid overlapping periods
            let asleepSamples = sleepSamples.filter { sample in
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                     HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                     HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                     HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    return true
                default:
                    return false
                }
            }
            
            // Sort by start date to process chronologically
            let sortedAsleepSamples = asleepSamples.sorted { $0.startDate < $1.startDate }
            
            // Merge overlapping periods to avoid double counting
            var mergedPeriods: [(start: Date, end: Date)] = []
            
            for sample in sortedAsleepSamples {
                let sampleStart = sample.startDate
                let sampleEnd = sample.endDate
                
                if let lastPeriod = mergedPeriods.last,
                   sampleStart <= lastPeriod.end {
                    // Overlapping or adjacent - extend the last period
                    mergedPeriods[mergedPeriods.count - 1] = (
                        start: lastPeriod.start,
                        end: max(lastPeriod.end, sampleEnd)
                    )
                } else {
                    // Non-overlapping - add new period
                    mergedPeriods.append((start: sampleStart, end: sampleEnd))
                }
            }
            
            // Calculate total sleep time from merged periods
            var totalSleepSeconds: TimeInterval = 0
            for period in mergedPeriods {
                totalSleepSeconds += period.end.timeIntervalSince(period.start)
            }
            
            print("🛌 Merged \(sortedAsleepSamples.count) samples into \(mergedPeriods.count) periods")
            print("🛌 Total sleep time: \(totalSleepSeconds/3600) hours (\(Int(totalSleepSeconds/60)) minutes)")
            
            DispatchQueue.main.async { completion(totalSleepSeconds, nil) }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Weight Data Methods
    
    /// Fetch the most recent weight entry from HealthKit
    func fetchMostRecentWeight(completion: @escaping (Double?, Date?, Error?) -> Void) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil, nil, NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Weight type not available"]))
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                completion(nil, nil, error)
                return
            }
            
            guard let weightSample = samples?.first as? HKQuantitySample else {
                completion(nil, nil, nil)
                return
            }
            
            let weightInKg = weightSample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            completion(weightInKg, weightSample.endDate, nil)
        }
        
        healthStore.execute(query)
    }
    
    /// Fetch weight entries from HealthKit for a date range
    func fetchWeightEntries(from startDate: Date, to endDate: Date, completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil, NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Weight type not available"]))
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            let weightSamples = samples?.compactMap { $0 as? HKQuantitySample } ?? []
            completion(weightSamples, nil)
        }
        
        healthStore.execute(query)
    }
    
    /// Fetch weight entries from HealthKit since a specific date
    func fetchWeightEntriesSince(_ date: Date, completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        let endDate = Date()
        fetchWeightEntries(from: date, to: endDate, completion: completion)
    }
    
    /// A modern async version of `fetchWeightEntriesSince`
    func fetchWeightEntriesSince(_ date: Date) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            fetchWeightEntriesSince(date) { samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
        }
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
 
