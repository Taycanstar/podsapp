

import Foundation

struct ExerciseEquipmentResolver {
    static let shared = ExerciseEquipmentResolver()

    private init() {}

    func equipment(for exercise: ExerciseData) -> Set<Equipment> {
        if let override = equipmentOverride(for: exercise) {
            return override
        }
        var normalized = parseEquipmentColumn(exercise.equipment)
        normalized.formUnion(heuristics(for: exercise))
        if normalized.isEmpty {
            normalized.insert(.bodyWeight)
        }
        return normalized
    }

    private func parseEquipmentColumn(_ rawValue: String) -> Set<Equipment> {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        var matches: Set<Equipment> = []
        let tokens = trimmed
            .replacingOccurrences(of: "/", with: ",")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        for token in tokens where !token.isEmpty {
            switch token {
            case "body weight", "bodyweight":
                matches.insert(.bodyWeight)
            case "barbell", "barbells":
                matches.insert(.barbells)
            case "dumbbell", "dumbbells":
                matches.insert(.dumbbells)
            case "kettlebell", "kettlebells":
                matches.insert(.kettlebells)
            case "cable":
                matches.insert(.cable)
            case "smith machine":
                matches.insert(.smithMachine)
            case "lever", "leverage machine":
                matches.insert(.hammerstrengthMachine)
            case "resistance bands", "band", "elastic band":
                matches.insert(.resistanceBands)
            case "medicine ball":
                matches.insert(.medicineBalls)
            case "stability ball", "swiss ball", "exercise ball":
                matches.insert(.stabilityBall)
            case "sled":
                matches.insert(.sled)
            case "ez bar", "ez-bar", "ezbar":
                matches.insert(.ezBar)
            case "pull up bar", "pullup bar":
                matches.insert(.pullupBar)
            case "dip bar", "parallel bars":
                matches.insert(.dipBar)
            case "lat pulldown":
                matches.insert(.latPulldownCable)
            case "leg press":
                matches.insert(.legPress)
            case "flat bench", "bench":
                matches.insert(.flatBench)
            case "incline bench":
                matches.insert(.inclineBench)
            case "decline bench":
                matches.insert(.declineBench)
            case "preacher bench":
                matches.insert(.preacherCurlBench)
            case "pvc", "pvc pipe", "dowel":
                matches.insert(.pvc)
            default:
                break
            }
        }

        return matches
    }

    private func heuristics(for exercise: ExerciseData) -> Set<Equipment> {
        var matches: Set<Equipment> = []
        let name = exercise.name.lowercased()

        if name.contains("landmine") {
            matches.insert(.barbells)
            matches.insert(.squatRack)
        }
        if name.contains("trap bar") || name.contains("hex bar") {
            matches.insert(.barbells)
        }
        if name.contains("smith") {
            matches.insert(.smithMachine)
        }
        if name.contains("trx") || name.contains("ring") {
            matches.insert(.rings)
        }
        if name.contains("sled") {
            matches.insert(.sled)
        }
        if name.contains("band") && exercise.equipment.isEmpty {
            matches.insert(.resistanceBands)
        }
        if name.contains("medicine ball") {
            matches.insert(.medicineBalls)
        }
        if name.contains("pvc") || name.contains("dowel") {
            matches.insert(.pvc)
        }

        func inferBenchEquipment() {
            if name.contains("preacher") {
                matches.insert(.preacherCurlBench)
            } else if name.contains("incline") {
                matches.insert(.inclineBench)
            } else if name.contains("decline") {
                matches.insert(.declineBench)
            } else {
                matches.insert(.flatBench)
            }
        }

        if name.contains("bench") {
            inferBenchEquipment()
        }
        if name.contains("flye") || name.contains("fly") {
            if name.contains("incline") {
                matches.insert(.inclineBench)
            } else if name.contains("decline") {
                matches.insert(.declineBench)
            } else if name.contains("bench") {
                inferBenchEquipment()
            }
        }
        if name.contains("step-up") || name.contains("step up") || name.contains("box jump") {
            matches.insert(.box)
        }

        if name.contains("machine") && matches.isEmpty {
            matches.insert(.hammerstrengthMachine)
        }

        return matches
    }

    private func equipmentOverride(for exercise: ExerciseData) -> Set<Equipment>? {
        // Keep existing id-specific overrides but make it easy to extend in one place.
        switch exercise.id {
        case 5696:
            return [.barbells]
        case 9695:
            return [.barbells]
        default:
            return nil
        }
    }
}
