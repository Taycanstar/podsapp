//
//  Equipment.swift
//  pods
//
//  Created by Dimi Nunez on 7/11/25.
//

//
//  Equipment.swift
//  Pods
//
//  Created by Dimi Nunez on 7/10/25.
//

import Foundation

// MARK: - Equipment Categories
enum EquipmentCategory: String, CaseIterable, Codable {
    case freeWeights = "Free Weights"
    case machines = "Machines"
    case bodyweight = "Bodyweight"
    case accessories = "Accessories"
    case specialty = "Specialty"
}

// MARK: - Equipment Types (matching ByEquipmentView)
enum Equipment: String, CaseIterable, Codable {
    // Primary Equipment (explicit in equipment field)
    case barbells = "Barbells"
    case dumbbells = "Dumbbells"
    case cable = "Cable"
    case smithMachine = "Smith Machine"
    case hammerstrengthMachine = "Hammerstrength Machine"
    case kettlebells = "Kettlebells"
    case resistanceBands = "Resistance Bands"
    case stabilityBall = "Stability (Swiss) Ball"
    case battleRopes = "Battle Ropes"
    case ezBar = "EZ Bar"
    case bosuBalanceTrainer = "BOSU Balance Trainer"
    case sled = "Sled"
    case medicineBalls = "Medicine Balls"
    case bodyWeight = "Body weight"
    
    // Bench Equipment (implied by exercise names)
    case flatBench = "Flat Bench"
    case declineBench = "Decline Bench"
    case preacherCurlBench = "Preacher Curl Bench"
    case inclineBench = "Incline Bench"
    
    // Machine Equipment (implied by exercise names)
    case latPulldownCable = "Lat Pulldown Cable"
    case legExtensionMachine = "Leg Extension Machine"
    case legCurlMachine = "Leg Curl Machine"
    case calfRaiseMachine = "Calf Raise Machine"
    case rowMachine = "Row Machine"
    case legPress = "Leg Press"
    
    // Bar Equipment (implied by exercise names)
    case pullupBar = "Pull up Bar"
    case dipBar = "Dip (Parallel) Bar"
    
    // Additional Equipment (implied by exercise names)
    case squatRack = "Squat Rack"
    case box = "Box"
    case platforms = "Platforms"
    
    // Specialty Equipment (implied by exercise names)
    case hackSquatMachine = "Hack Squat Machine"
    case shoulderPressMachine = "Shoulder Press Machine"
    case tricepsExtensionMachine = "Triceps Extension Machine"
    case bicepsCurlMachine = "Biceps Curl Machine"
    case abCrunchMachine = "Ab Crunch Machine"
    case preacherCurlMachine = "Preacher Curl Machine"
    case pvc = "PVC"
    case rings = "Rings"
    case suspensionTrainer = "TRX"

    var category: EquipmentCategory {
        switch self {
        case .dumbbells, .barbells, .kettlebells, .ezBar:
            return .freeWeights
        case .cable, .smithMachine, .hammerstrengthMachine, .legPress, .latPulldownCable, .rowMachine, .legExtensionMachine, .legCurlMachine, .calfRaiseMachine, .hackSquatMachine, .shoulderPressMachine, .tricepsExtensionMachine, .bicepsCurlMachine, .abCrunchMachine, .preacherCurlMachine:
            return .machines
        case .bodyWeight, .pullupBar, .dipBar, .flatBench, .inclineBench, .declineBench, .preacherCurlBench:
            return .bodyweight
        case .resistanceBands, .stabilityBall, .medicineBalls, .bosuBalanceTrainer, .pvc:
            return .accessories
        case .battleRopes, .sled, .squatRack, .box, .platforms, .rings, .suspensionTrainer:
            return .specialty
        }
    }
    
    var description: String {
        return self.rawValue
    }

    var imageAssetName: String {
        switch self {
        case .barbells: return "barbells"
        case .dumbbells: return "dumbbells"
        case .cable: return "crossovercable"
        case .smithMachine: return "smith"
        case .hammerstrengthMachine: return "hammerstrength"
        case .kettlebells: return "kbells"
        case .resistanceBands: return "handlebands"
        case .stabilityBall: return "swissball"
        case .battleRopes: return "battleropes"
        case .ezBar: return "ezbar"
        case .bosuBalanceTrainer: return "bosu"
        case .sled: return "sled"
        case .medicineBalls: return "medballs"
        case .bodyWeight: return ""
        case .flatBench: return "flatbench"
        case .declineBench: return "declinebench"
        case .preacherCurlBench: return "preachercurlmachine"
        case .inclineBench: return "inclinebench"
        case .latPulldownCable: return "latpulldown"
        case .legExtensionMachine: return "legextmachine"
        case .legCurlMachine: return "legcurlmachine"
        case .calfRaiseMachine: return "calfraisesmachine"
        case .rowMachine: return "seatedrow"
        case .legPress: return "legpress"
        case .pullupBar: return "pullupbar"
        case .dipBar: return "dipbar"
        case .squatRack: return "squatrack"
        case .box: return "box"
        case .platforms: return "platforms"
        case .hackSquatMachine: return "hacksquat"
        case .shoulderPressMachine: return "shoulderpress"
        case .tricepsExtensionMachine: return "tricepext"
        case .bicepsCurlMachine: return "bicepscurlmachine"
        case .abCrunchMachine: return "abcrunch"
        case .preacherCurlMachine: return "preachercurlmachine"
        case .pvc: return "pvc"
        case .rings: return "rrings"
        case .suspensionTrainer: return "trx"
        }
    }

    /// Initialize from a string, supporting both new format ("Barbells") and legacy format ("barbell")
    static func from(string: String) -> Equipment? {
        // First try exact match with rawValue
        if let equipment = Equipment(rawValue: string) {
            return equipment
        }

        // Legacy format mapping (snake_case/lowercase to Equipment)
        let legacyMapping: [String: Equipment] = [
            "barbell": .barbells,
            "barbells": .barbells,
            "dumbbell": .dumbbells,
            "dumbbells": .dumbbells,
            "cable": .cable,
            "smith_machine": .smithMachine,
            "hammerstrength_machine": .hammerstrengthMachine,
            "hammerstrength": .hammerstrengthMachine,
            "kettlebell": .kettlebells,
            "kettlebells": .kettlebells,
            "resistance_bands": .resistanceBands,
            "stability_ball": .stabilityBall,
            "swiss_ball": .stabilityBall,
            "battle_ropes": .battleRopes,
            "ez_bar": .ezBar,
            "bosu_ball": .bosuBalanceTrainer,
            "bosu_balance_trainer": .bosuBalanceTrainer,
            "sled": .sled,
            "medicine_ball": .medicineBalls,
            "medicine_balls": .medicineBalls,
            "body_weight": .bodyWeight,
            "bodyweight": .bodyWeight,
            "flat_bench": .flatBench,
            "bench": .flatBench,
            "decline_bench": .declineBench,
            "preacher_curl_bench": .preacherCurlBench,
            "incline_bench": .inclineBench,
            "lat_pulldown": .latPulldownCable,
            "lat_pulldown_cable": .latPulldownCable,
            "leg_extension": .legExtensionMachine,
            "leg_extension_machine": .legExtensionMachine,
            "leg_curl": .legCurlMachine,
            "leg_curl_machine": .legCurlMachine,
            "calf_raise_machine": .calfRaiseMachine,
            "row_machine": .rowMachine,
            "seated_row": .rowMachine,
            "leg_press": .legPress,
            "pullup_bar": .pullupBar,
            "pull_up_bar": .pullupBar,
            "dip_bar": .dipBar,
            "squat_rack": .squatRack,
            "box": .box,
            "platforms": .platforms,
            "hack_squat": .hackSquatMachine,
            "hack_squat_machine": .hackSquatMachine,
            "shoulder_press_machine": .shoulderPressMachine,
            "triceps_extension_machine": .tricepsExtensionMachine,
            "biceps_curl_machine": .bicepsCurlMachine,
            "ab_crunch_machine": .abCrunchMachine,
            "preacher_curl_machine": .preacherCurlMachine,
            "pvc": .pvc,
            "rings": .rings,
            "trx": .suspensionTrainer,
            "suspension_trainer": .suspensionTrainer,
        ]

        return legacyMapping[string.lowercased()]
    }
}

// MARK: - Workout Location
enum WorkoutLocation: String, CaseIterable {
    case gym = "Gym"
    case home = "Home"
    case outdoor = "Outdoor"
    case hotel = "Hotel"
    
    var description: String {
        return self.rawValue
    }
}

// MARK: - Exercise Type Preferences
enum ExerciseType: String, CaseIterable, Codable {
    case compound = "Compound"
    case isolation = "Isolation"
    case cardio = "Cardio"
    case stretching = "Stretching"
    case plyometric = "Plyometric"
    case powerlifting = "Powerlifting"
    case functional = "Functional"
    
    var description: String {
        return self.rawValue
    }
}



// MARK: - Workout Frequency
enum WorkoutFrequency: String, CaseIterable, Codable {
    case once = "1x per week"
    case twice = "2x per week"
    case three = "3x per week"
    case four = "4x per week"
    case five = "5x per week"
    case six = "6x per week"
    case daily = "Daily"
    
    var sessionsPerWeek: Int {
        switch self {
        case .once: return 1
        case .twice: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .daily: return 7
        }
    }
} 
