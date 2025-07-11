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
enum EquipmentCategory: String, CaseIterable {
    case freeWeights = "Free Weights"
    case machines = "Machines"
    case bodyweight = "Bodyweight"
    case accessories = "Accessories"
    case specialty = "Specialty"
}

// MARK: - Equipment Types (matching ByEquipmentView)
enum Equipment: String, CaseIterable {
    // Primary Equipment (explicit in equipment field)
    case barbells = "Barbells"
    case dumbbells = "Dumbbells"
    case cable = "Cable"
    case smithMachine = "Smith Machine"
    case hammerstrengthMachine = "Hammerstrength (Leverage) Machine"
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
    
    var category: EquipmentCategory {
        switch self {
        case .dumbbells, .barbells, .kettlebells, .ezBar:
            return .freeWeights
        case .cable, .smithMachine, .hammerstrengthMachine, .legPress, .latPulldownCable, .rowMachine, .legExtensionMachine, .legCurlMachine, .calfRaiseMachine, .hackSquatMachine, .shoulderPressMachine, .tricepsExtensionMachine, .bicepsCurlMachine, .abCrunchMachine, .preacherCurlMachine:
            return .machines
        case .bodyWeight, .pullupBar, .dipBar, .flatBench, .inclineBench, .declineBench, .preacherCurlBench:
            return .bodyweight
        case .resistanceBands, .stabilityBall, .medicineBalls, .bosuBalanceTrainer:
            return .accessories
        case .battleRopes, .sled, .squatRack, .box, .platforms:
            return .specialty
        }
    }
    
    var description: String {
        return self.rawValue
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
enum ExerciseType: String, CaseIterable {
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
enum WorkoutFrequency: String, CaseIterable {
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