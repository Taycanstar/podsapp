import Foundation
import HealthKit

struct SleepSummary {
    let totalSleepMinutes: Double
    let inBedMinutes: Double
    let coreMinutes: Double
    let deepMinutes: Double
    let remMinutes: Double
    let awakeMinutes: Double
    let sleepOnset: Date?
    let sleepOffset: Date?
    let latencyMinutes: Double?

    var efficiency: Double? {
        guard inBedMinutes > 0 else { return nil }
        return max(0.0, min(1.0, totalSleepMinutes / inBedMinutes))
    }

    var midpointMinutes: Double? {
        guard let start = sleepOnset, let end = sleepOffset else { return nil }
        let midpoint = start.addingTimeInterval(end.timeIntervalSince(start) / 2.0)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: midpoint)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return Double(hour * 60 + minute)
    }

    func dictionaryRepresentation(formatter: ISO8601DateFormatter) -> [String: Any] {
        var dict: [String: Any] = [
            "total_minutes": totalSleepMinutes,
            "in_bed_minutes": inBedMinutes,
            "core_minutes": coreMinutes,
            "deep_minutes": deepMinutes,
            "rem_minutes": remMinutes,
            "awake_minutes": awakeMinutes,
        ]
        if let latencyMinutes {
            dict["latency_minutes"] = latencyMinutes
        }
        if let efficiency = efficiency {
            dict["efficiency"] = efficiency
        }
        if let midpoint = midpointMinutes {
            dict["midpoint_minutes"] = midpoint
        }
        if let onset = sleepOnset {
            dict["sleep_onset"] = formatter.string(from: onset)
        }
        if let offset = sleepOffset {
            dict["sleep_offset"] = formatter.string(from: offset)
        }
        return dict
    }
}

struct HealthQuantitySample {
    let value: Double
    let date: Date
}

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
    
    private let preferredReadinessSources = ["oura"]
    
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

    func fetchBodyFatPercentageSamples(limit: Int = 7, completion: @escaping ([HealthQuantitySample]?, Error?) -> Void) {
        let fatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: fatType,
            predicate: nil,
            limit: limit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                completion(nil, error)
                return
            }

            let mapped = samples?.compactMap { sample -> HealthQuantitySample? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                let percent = quantitySample.quantity.doubleValue(for: HKUnit.percent()) * 100
                return HealthQuantitySample(value: percent, date: quantitySample.endDate)
            } ?? []

            completion(mapped, nil)
        }

        healthStore.execute(query)
    }

    // Fetch date of birth from HealthKit characteristics
    func fetchDateOfBirth(completion: @escaping (Date?, Error?) -> Void) {
        do {
            let components = try healthStore.dateOfBirthComponents()
            let calendar = Calendar.current
            if let date = calendar.date(from: components) {
                completion(date, nil)
            } else {
                completion(nil, NSError(domain: "com.pods.healthkit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create birth date from components"]))
            }
        } catch {
            completion(nil, error)
        }
    }

    // Fetch biological sex characteristic
    func fetchBiologicalSex(completion: @escaping (HKBiologicalSex?, Error?) -> Void) {
        do {
            let sexObject = try healthStore.biologicalSex()
            completion(sexObject.biologicalSex, nil)
        } catch {
            completion(nil, error)
        }
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
    func fetchSleepSummary(for date: Date, completion: @escaping (SleepSummary?, Error?) -> Void) {
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
            var remMinutes: Double = 0
            var deepMinutes: Double = 0
            var coreMinutes: Double = 0
            var awakeMinutes: Double = 0
            var inBedStart: Date?
            var inBedEnd: Date?
            var sleepStart: Date?
            var sleepEnd: Date?

            for sample in sleepSamples {
                let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    remMinutes += minutes
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepMinutes += minutes
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                     HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    coreMinutes += minutes
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    awakeMinutes += minutes
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    inBedStart = min(inBedStart ?? sample.startDate, sample.startDate)
                    inBedEnd = max(inBedEnd ?? sample.endDate, sample.endDate)
                default:
                    break
                }

                if sample.value != HKCategoryValueSleepAnalysis.awake.rawValue
                    && sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue {
                    sleepStart = min(sleepStart ?? sample.startDate, sample.startDate)
                    sleepEnd = max(sleepEnd ?? sample.endDate, sample.endDate)
                }
            }

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
            
            let totalMinutes = totalSleepSeconds / 60.0
            let inBedMinutes: Double
            if let start = inBedStart, let end = inBedEnd {
                inBedMinutes = max(0, end.timeIntervalSince(start) / 60.0)
            } else if let start = sleepStart, let end = sleepEnd {
                inBedMinutes = max(0, end.timeIntervalSince(start) / 60.0)
            } else {
                inBedMinutes = totalMinutes
            }

            var latencyMinutes: Double?
            if let bedStart = inBedStart, let start = sleepStart {
                latencyMinutes = max(0, start.timeIntervalSince(bedStart) / 60.0)
            }

            let summary = SleepSummary(
                totalSleepMinutes: totalMinutes,
                inBedMinutes: inBedMinutes,
                coreMinutes: coreMinutes,
                deepMinutes: deepMinutes,
                remMinutes: remMinutes,
                awakeMinutes: awakeMinutes,
                sleepOnset: sleepStart,
                sleepOffset: sleepEnd,
                latencyMinutes: latencyMinutes
            )

            DispatchQueue.main.async { completion(summary, nil) }
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

    func fetchRestingHeartRate(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            completion(nil, NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resting heart rate not available"]))
            return
        }
        let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        fetchLatestQuantity(type: type,
                            unit: bpmUnit,
                            predicate: createOvernightPredicate(for: date),
                            preferredSources: preferredReadinessSources,
                            completion: completion)
    }

    func fetchHeartRateVariability(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(nil, NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "HRV not available"]))
            return
        }
        let unit = HKUnit.secondUnit(with: .milli)
        fetchLatestQuantity(type: type,
                            unit: unit,
                            predicate: createOvernightPredicate(for: date),
                            preferredSources: preferredReadinessSources,
                            completion: completion)
    }

    func fetchWalkingHeartRateAverage(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) else {
            completion(nil, NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Walking heart rate not available"]))
            return
        }
        let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        fetchAverageQuantity(type: type, unit: bpmUnit, date: date, completion: completion)
    }

    func fetchRespiratoryRate(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            completion(nil, NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Respiratory rate not available"]))
            return
        }
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        fetchLatestQuantity(type: type,
                            unit: unit,
                            predicate: createOvernightPredicate(for: date),
                            preferredSources: preferredReadinessSources,
                            completion: completion)
    }

    func fetchBodyTemperature(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        let predicate = createOvernightPredicate(for: date)
        let unit = HKUnit.degreeCelsius()

        if #available(iOS 17.0, *),
           let wristType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            fetchLatestQuantity(type: wristType,
                                unit: unit,
                                predicate: predicate,
                                preferredSources: preferredReadinessSources) { value, error in
                if let value = value {
                    completion(value, nil)
                } else if let error = error {
                    completion(nil, error)
                } else {
                    self.fetchLegacyBodyTemperature(unit: unit, predicate: predicate, completion: completion)
                }
            }
        } else {
            fetchLegacyBodyTemperature(unit: unit, predicate: predicate, completion: completion)
        }
    }

    private func fetchLegacyBodyTemperature(unit: HKUnit,
                                            predicate: NSPredicate,
                                            completion: @escaping (Double?, Error?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) else {
            completion(nil, NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Body temperature not available"]))
            return
        }
        fetchLatestQuantity(type: type,
                            unit: unit,
                            predicate: predicate,
                            preferredSources: preferredReadinessSources) { value, error in
            if let value = value {
                completion(value - 36.7, nil)
            } else {
                completion(value, error)
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

    private func fetchAverageQuantity(
        type: HKQuantityType,
        unit: HKUnit,
        date: Date,
        completion: @escaping (Double?, Error?) -> Void
    ) {
        let predicate = createDayPredicate(for: date)
        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, result, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let quantity = result?.averageQuantity() else {
                completion(nil, nil)
                return
            }

            completion(quantity.doubleValue(for: unit), nil)
        }

        healthStore.execute(query)
    }

    private func fetchLatestQuantity(
        type: HKQuantityType,
        unit: HKUnit,
        predicate: NSPredicate?,
        preferredSources: [String]? = nil,
        completion: @escaping (Double?, Error?) -> Void
    ) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let limit = preferredSources == nil ? 1 : 20
        let query = HKSampleQuery(sampleType: type,
                                  predicate: predicate,
                                  limit: limit,
                                  sortDescriptors: [sort]) { _, samples, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                completion(nil, nil)
                return
            }

            let match = preferredSources.flatMap { preferred -> HKQuantitySample? in
                let lowerPreferred = preferred.map { $0.lowercased() }
                return samples.first { sample in
                    let sourceName = sample.sourceRevision.source.name.lowercased()
                    return lowerPreferred.contains(where: { sourceName.contains($0) })
                }
            } ?? samples.first

            completion(match?.quantity.doubleValue(for: unit), nil)
        }

        healthStore.execute(query)
    }

    private func createOvernightPredicate(for date: Date) -> NSPredicate {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .hour, value: -18, to: startOfDay) ?? startOfDay.addingTimeInterval(-18 * 3600)
        let end = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay.addingTimeInterval(12 * 3600)
        return HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    }
}
