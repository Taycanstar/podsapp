//
//  MuscleFatigueEntry.swift
//  pods
//
//  Created by Dimi Nunez on 1/18/26.
//


//
//  WorkoutAnalysisModels.swift
//  Pods
//
//  Created by Claude Code on 1/18/26.
//

import Foundation

// MARK: - Fatigue Map Models

/// Represents the fatigue/stress accumulated for a muscle group from exercises
struct MuscleFatigueEntry: Codable, Equatable {
    let muscleGroup: String
    let totalSets: Int
    let totalVolume: Double  // weight * reps
    let isPrimary: Bool  // true if target muscle, false if synergist

    var fatigueScore: Double {
        // Primary muscles get higher fatigue weighting
        let multiplier = isPrimary ? 1.0 : 0.5
        return Double(totalSets) * multiplier + (totalVolume / 1000.0) * 0.1
    }
}

/// Complete fatigue map for a workout
struct WorkoutFatigueMap: Codable, Equatable {
    let muscleFatigue: [MuscleFatigueEntry]
    let movementPatterns: [MovementPattern]
    let jointsInvolved: [JointInvolvement]
    let primaryMuscles: [String]  // Highest fatigue muscles
    let secondaryMuscles: [String]  // Supporting muscles

    /// Get muscles sorted by fatigue score (highest first)
    var musclesByFatigue: [String] {
        muscleFatigue
            .sorted { $0.fatigueScore > $1.fatigueScore }
            .map { $0.muscleGroup }
    }

    /// Get top N fatigued muscles
    func topFatiguedMuscles(count: Int) -> [String] {
        Array(musclesByFatigue.prefix(count))
    }

    /// Check if workout is predominantly upper or lower body
    var isUpperBodyFocused: Bool {
        let upperBodyMuscles = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms", "Trapezius"]
        let upperCount = primaryMuscles.filter { muscle in
            upperBodyMuscles.contains { muscle.contains($0) }
        }.count
        return upperCount > primaryMuscles.count / 2
    }

    var isLowerBodyFocused: Bool {
        let lowerBodyMuscles = ["Quadriceps", "Hamstrings", "Glutes", "Calves", "Adductors", "Abductors"]
        let lowerCount = primaryMuscles.filter { muscle in
            lowerBodyMuscles.contains { muscle.contains($0) }
        }.count
        return lowerCount > primaryMuscles.count / 2
    }
}

// MARK: - Movement Pattern Detection

enum MovementPattern: String, CaseIterable, Codable {
    case horizontalPush = "horizontal_push"   // Bench press, push-ups
    case verticalPush = "vertical_push"       // Overhead press, dips
    case horizontalPull = "horizontal_pull"   // Rows
    case verticalPull = "vertical_pull"       // Pull-ups, lat pulldown
    case legPressing = "leg_pressing"         // Squats, leg press
    case legHinging = "leg_hinging"           // Deadlifts, RDLs, good mornings
    case coreStabilization = "core_stabilization"  // Planks, carries
    case coreFlexion = "core_flexion"         // Crunches, leg raises
    case rotational = "rotational"            // Russian twists, woodchops

    var displayName: String {
        switch self {
        case .horizontalPush: return "Horizontal Push"
        case .verticalPush: return "Vertical Push"
        case .horizontalPull: return "Horizontal Pull"
        case .verticalPull: return "Vertical Pull"
        case .legPressing: return "Leg Pressing"
        case .legHinging: return "Leg Hinging"
        case .coreStabilization: return "Core Stabilization"
        case .coreFlexion: return "Core Flexion"
        case .rotational: return "Rotational"
        }
    }

    /// Dynamic stretches appropriate for this movement pattern
    var dynamicWarmupKeywords: [String] {
        switch self {
        case .horizontalPush, .verticalPush:
            return ["arm circle", "shoulder", "chest", "push-up", "arm swing"]
        case .horizontalPull, .verticalPull:
            return ["arm circle", "shoulder", "back", "lat", "row", "pull"]
        case .legPressing:
            return ["squat", "lunge", "leg swing", "hip", "quad", "knee circle"]
        case .legHinging:
            return ["hip", "hamstring", "glute", "hinge", "swing", "rdl"]
        case .coreStabilization, .coreFlexion, .rotational:
            return ["rotation", "twist", "core", "spine", "torso"]
        }
    }

    /// Activation exercises appropriate for this pattern
    var activationKeywords: [String] {
        switch self {
        case .horizontalPush:
            return ["push-up", "band", "press", "chest activation", "scapular"]
        case .verticalPush:
            return ["arm raise", "shoulder", "overhead", "band pull-apart", "y raise"]
        case .horizontalPull, .verticalPull:
            return ["band row", "face pull", "scapular", "back activation", "i-y-t"]
        case .legPressing:
            return ["squat", "glute bridge", "lunge", "leg activation", "split squat"]
        case .legHinging:
            return ["glute bridge", "hip hinge", "rdl", "hamstring", "hip thrust"]
        case .coreStabilization, .coreFlexion, .rotational:
            return ["bird dog", "dead bug", "plank", "core", "hollow"]
        }
    }

    /// Order for sorting patterns (upper body before lower body)
    var order: Int {
        switch self {
        case .horizontalPush: return 1
        case .verticalPush: return 2
        case .horizontalPull: return 3
        case .verticalPull: return 4
        case .legPressing: return 5
        case .legHinging: return 6
        case .coreStabilization: return 7
        case .coreFlexion: return 8
        case .rotational: return 9
        }
    }
}

// MARK: - Joint Involvement

struct JointInvolvement: Codable, Equatable {
    let joint: Joint
    let movementCount: Int  // How many exercises involve this joint
    let intensity: JointIntensity

    enum JointIntensity: String, Codable {
        case light   // 1-2 exercises
        case moderate  // 3-4 exercises
        case heavy   // 5+ exercises

        var mobilityDurationSeconds: Int {
            switch self {
            case .light: return 30
            case .moderate: return 45
            case .heavy: return 60
            }
        }
    }
}

enum Joint: String, CaseIterable, Codable {
    case shoulder = "shoulder"
    case elbow = "elbow"
    case wrist = "wrist"
    case hip = "hip"
    case knee = "knee"
    case ankle = "ankle"
    case spine = "spine"

    var displayName: String {
        rawValue.capitalized
    }

    /// Body parts that indicate this joint is involved
    var relatedBodyParts: [String] {
        switch self {
        case .shoulder: return ["shoulders", "chest", "back"]
        case .elbow: return ["upper arms", "forearms"]
        case .wrist: return ["forearms"]
        case .hip: return ["hips", "thighs", "glutes"]
        case .knee: return ["thighs", "calves"]
        case .ankle: return ["calves"]
        case .spine: return ["back", "waist", "neck"]
        }
    }

    /// Exercise name patterns indicating this joint
    var exercisePatterns: [String] {
        switch self {
        case .shoulder: return ["press", "raise", "fly", "pull", "row", "push-up"]
        case .elbow: return ["curl", "extension", "press", "push-up", "dip", "row"]
        case .wrist: return ["curl", "extension", "grip"]
        case .hip: return ["squat", "deadlift", "lunge", "hip", "glute", "thrust"]
        case .knee: return ["squat", "lunge", "leg press", "extension", "curl"]
        case .ankle: return ["calf", "raise", "squat", "lunge"]
        case .spine: return ["deadlift", "row", "crunch", "twist", "back"]
        }
    }

    /// Mobility exercises for this joint
    var mobilityKeywords: [String] {
        switch self {
        case .shoulder: return ["arm circle", "shoulder rotation", "wall slide"]
        case .elbow: return ["arm circle", "elbow"]
        case .wrist: return ["wrist circle", "wrist extension"]
        case .hip: return ["hip circle", "hip hinge", "leg swing"]
        case .knee: return ["knee circle", "squat", "lunge"]
        case .ankle: return ["ankle circle", "calf raise", "ankle mobility"]
        case .spine: return ["cat-cow", "spine rotation", "thoracic"]
        }
    }
}

// MARK: - Warmup Phase Structure

enum WarmupPhase: String, CaseIterable, Codable {
    case foamRolling = "foam_rolling"
    case dynamicStretching = "dynamic_stretching"
    case activation = "activation"

    var displayName: String {
        switch self {
        case .foamRolling: return "Foam Rolling"
        case .dynamicStretching: return "Dynamic Stretching"
        case .activation: return "Activation"
        }
    }

    var description: String {
        switch self {
        case .foamRolling: return "Release muscle tension and improve tissue quality"
        case .dynamicStretching: return "Increase range of motion and blood flow"
        case .activation: return "Prime muscles for the workout ahead"
        }
    }

    var durationRangeSeconds: ClosedRange<Int> {
        switch self {
        case .foamRolling: return 90...120       // 1.5-2 min
        case .dynamicStretching: return 300...600  // 5-10 min
        case .activation: return 120...300       // 2-5 min
        }
    }

    var order: Int {
        switch self {
        case .foamRolling: return 1
        case .dynamicStretching: return 2
        case .activation: return 3
        }
    }

    /// Default number of exercises for this phase
    var defaultExerciseCount: Int {
        switch self {
        case .foamRolling: return 1
        case .dynamicStretching: return 2
        case .activation: return 2
        }
    }
}

// MARK: - Phased Warmup Exercise

/// A warmup exercise with phase classification
struct PhasedWarmupExercise {
    let exercise: TodayWorkoutExercise
    let phase: WarmupPhase
    let targetMuscles: [String]

    var phaseOrder: Int {
        phase.order
    }
}

// MARK: - Cooldown Models

enum CooldownType: String, Codable {
    case staticStretch = "static_stretch"
    case breathingExercise = "breathing"
    case lightMovement = "light_movement"

    var displayName: String {
        switch self {
        case .staticStretch: return "Static Stretch"
        case .breathingExercise: return "Breathing"
        case .lightMovement: return "Light Movement"
        }
    }

    var defaultHoldDuration: TimeInterval {
        switch self {
        case .staticStretch: return 30  // 30 seconds
        case .breathingExercise: return 60  // 1 minute
        case .lightMovement: return 45  // 45 seconds
        }
    }
}

// MARK: - Muscle Group Normalization

/// Mapping of common muscle names to standardized groups
struct MuscleGroupNormalizer {

    /// Normalize a muscle name to a standard group name
    static func normalize(_ muscle: String) -> String {
        let lowercased = muscle.lowercased().trimmingCharacters(in: .whitespaces)

        // Map to standard muscle groups
        if lowercased.contains("pectoralis") || lowercased.contains("chest") {
            return "Chest"
        } else if lowercased.contains("latissimus") || lowercased.contains("lat") ||
                  (lowercased.contains("back") && !lowercased.contains("lower")) {
            return "Back"
        } else if lowercased.contains("deltoid") || lowercased.contains("shoulder") {
            return "Shoulders"
        } else if lowercased.contains("bicep") {
            return "Biceps"
        } else if lowercased.contains("tricep") {
            return "Triceps"
        } else if lowercased.contains("quadriceps") || lowercased.contains("quad") {
            return "Quadriceps"
        } else if lowercased.contains("hamstring") {
            return "Hamstrings"
        } else if lowercased.contains("gluteus") || lowercased.contains("glute") {
            return "Glutes"
        } else if lowercased.contains("rectus abdominis") || lowercased.contains("oblique") ||
                  lowercased.contains("waist") || lowercased.contains("abs") {
            return "Abs"
        } else if lowercased.contains("erector") || lowercased.contains("lower back") {
            return "Lower Back"
        } else if lowercased.contains("gastrocnemius") || lowercased.contains("soleus") ||
                  lowercased.contains("calf") || lowercased.contains("calves") {
            return "Calves"
        } else if lowercased.contains("trapezius") || lowercased.contains("trap") {
            return "Trapezius"
        } else if lowercased.contains("forearm") || lowercased.contains("brachioradialis") ||
                  lowercased.contains("wrist") {
            return "Forearms"
        } else if lowercased.contains("adductor") {
            return "Adductors"
        } else if lowercased.contains("abductor") || lowercased.contains("tensor") {
            return "Abductors"
        } else if lowercased.contains("neck") || lowercased.contains("sternocleidomastoid") {
            return "Neck"
        } else if lowercased.contains("hip") {
            return "Glutes"  // Map hip to glutes as closest match
        } else if lowercased.contains("thigh") {
            return "Quadriceps"
        }

        return muscle  // Return original if no mapping found
    }

    /// Get the body part category for a normalized muscle group
    static func bodyPartFor(muscleGroup: String) -> String {
        let mapping: [String: String] = [
            "Chest": "Chest",
            "Back": "Back",
            "Shoulders": "Shoulders",
            "Biceps": "Upper Arms",
            "Triceps": "Upper Arms",
            "Quadriceps": "Thighs",
            "Hamstrings": "Thighs",
            "Glutes": "Hips",
            "Abs": "Waist",
            "Lower Back": "Back",
            "Calves": "Calves",
            "Trapezius": "Back",
            "Forearms": "Forearms",
            "Adductors": "Thighs",
            "Abductors": "Hips",
            "Neck": "Neck"
        ]
        return mapping[muscleGroup] ?? "Full Body"
    }
}
