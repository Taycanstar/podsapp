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
        return UserDefaults.standard.bool(forKey: "healthKitEnabled")
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
        if authStatus != .sharingAuthorized {
            // Get all health data types to request permission for
            let typesToRead = getHealthDataTypesForRequest()
            
            // Request authorization
            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ HealthKit authorization error: \(error.localizedDescription)")
                    }
                    
                    // Save the user preference
                    UserDefaults.standard.set(success, forKey: "healthKitEnabled")
                    print("✅ HealthKit authorization result: \(success ? "granted" : "denied")")
                    
                    // Notify of permission status
                    completion(success)
                    
                    // Post notification that permission state changed
                    NotificationCenter.default.post(name: NSNotification.Name("HealthKitPermissionsChanged"), object: nil)
                }
            }
        } else {
            // Already authorized
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
        
        // Add all document types
        let documentTypes: [HKDocumentTypeIdentifier] = [
            .CDA
        ]
        
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
        
        // Add all document types
        for typeId in documentTypes {
            if let type = HKDocumentType.documentType(forIdentifier: typeId) {
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
    
    // Fetch sleep data for a specific date
    func fetchSleepData(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            DispatchQueue.main.async {
                completion(nil, NSError(domain: "com.pods.healthkit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sleep analysis type not available"]))
            }
            return
        }
        
        // Create a predicate for a specific day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Apple credits a sleep segment to the calendar day on which it **ends**,
        // so the simplest filter is:  endDate ∈ [startOfDay, endOfDay).
        // `.strictEndDate` guarantees exactly that.
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictEndDate
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
            // ─── DEBUG: print EVERY raw sleep sample ───────────────────────────
            print("──────── Sleep samples for selected date (\(date)) ────────")
            for s in sleepSamples {
                let stage = HealthKitManager.sleepStageName(for: s.value)
                let mins  = Int(s.endDate.timeIntervalSince(s.startDate) / 60)
                print(" • \(stage)  \(s.startDate) → \(s.endDate)  (\(mins) min)")
            }
            print("───────────────────────────────────────────────────────────")
            print("🛌 Found \(sleepSamples.count) sleep samples for date: \(date)")

            // ──────────────────────────────────────────────────────────────
            // 1.  Classify samples into three buckets
            //     • sleepCandidates =  inBed  OR  any “asleep*” value
            //     • awakeIntervals =  value == awake
            // ──────────────────────────────────────────────────────────────
            var sleepCandidates: [(Date,Date)] = []
            var awakeIntervals : [(Date,Date)] = []

            for s in sleepSamples {
                switch s.value {
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    awakeIntervals.append((s.startDate, s.endDate))
                case HKCategoryValueSleepAnalysis.inBed.rawValue,
                     HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                     HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                     HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                     HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    sleepCandidates.append((s.startDate, s.endDate))
                default:
                    break
                }
            }

            // Nothing to do?
            guard !sleepCandidates.isEmpty else {
                print("🛌 No sleep candidates found")
                DispatchQueue.main.async { completion(0, nil) }
                return
            }

            // ──────────────────────────────────────────────────────────────
            // 2.  Merge overlapping sleepCandidate intervals
            // ──────────────────────────────────────────────────────────────
            let sortedSleep = sleepCandidates.sorted { $0.0 < $1.0 }
            var mergedSleep: [(Date,Date)] = []

            var curStart = sortedSleep[0].0
            var curEnd   = sortedSleep[0].1

            for i in 1..<sortedSleep.count {
                let next = sortedSleep[i]
                if next.0 <= curEnd {                       // overlap
                    curEnd = max(curEnd, next.1)
                } else {
                    mergedSleep.append((curStart, curEnd))
                    curStart = next.0
                    curEnd   = next.1
                }
            }
            mergedSleep.append((curStart, curEnd))

            // Keep only sessions that END inside (startOfDay, endOfDay].
            mergedSleep = mergedSleep.filter { $0.1 > startOfDay && $0.1 <= endOfDay }

            // ──────────────────────────────────────────────────────────────
            // 3.  Calculate total “candidate sleep” seconds
            // ──────────────────────────────────────────────────────────────
            var totalSleepSeconds: TimeInterval = 0
            for (s,e) in mergedSleep {
                let dur = e.timeIntervalSince(s)
                totalSleepSeconds += dur
                print("🛌 Candidate sleep interval: \(s) → \(e)  (\(dur/60) min)")
            }

            // ──────────────────────────────────────────────────────────────
            // 4.  Subtract any overlap with AWAKE intervals (micro‑awakenings)
            //    Apple subtracts these from “Time Asleep”.
            // ──────────────────────────────────────────────────────────────
            for (awakeStart, awakeEnd) in awakeIntervals {
                for (sleepIdx, sleepInt) in mergedSleep.enumerated() {
                    let overlapStart = max(awakeStart, sleepInt.0)
                    let overlapEnd   = min(awakeEnd,   sleepInt.1)
                    if overlapStart < overlapEnd {
                        let overlap = overlapEnd.timeIntervalSince(overlapStart)
                        totalSleepSeconds -= overlap
                        print("   ⤷ Subtracting awake overlap \(overlap/60) min at \(overlapStart)")
                    }
                }
            }

            // Make sure we never go negative
            totalSleepSeconds = max(totalSleepSeconds, 0)
            print("🛌 Total sleep seconds (after subtracting awake): \(totalSleepSeconds) hr: \(totalSleepSeconds/3600)")
            DispatchQueue.main.async {
                completion(totalSleepSeconds, nil)
            }
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
