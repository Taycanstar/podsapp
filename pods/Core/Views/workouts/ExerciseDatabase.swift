//
//  ExerciseDatabase.swift
//  Pods
//
//  Created by Dimi Nunez on 6/14/25.
//

import Foundation
import UIKit

struct ExerciseDatabase {
    private static var cachedExercises: [ExerciseData]?
    private static var isPreloading = false
    private static let preloadQueue = DispatchQueue(label: "com.humuli.pods.exercise-loader", qos: .userInitiated)
    private static let preloadGroup = DispatchGroup()
    private static let csvFileName = "exercisesdb"
    private static let minimumExerciseCount = 1000
    
    static func preloadIfNeeded() {
        if cachedExercises != nil || isPreloading {
            return
        }
        isPreloading = true
        preloadGroup.enter()
        preloadQueue.async {
#if DEBUG
            print("⚙️ ExerciseDatabase: Preloading exercises...")
#endif
            let exercises = loadExercisesFromCSV()
            cachedExercises = exercises
            isPreloading = false
            preloadGroup.leave()
#if DEBUG
            print("⚙️ ExerciseDatabase: Preload finished (\(exercises.count) exercises)")
#endif
        }
    }

    static func warmCache() {
        if cachedExercises != nil {
            return
        }
        preloadQueue.sync {
            if cachedExercises == nil {
                let exercises = loadExercisesFromCSV()
#if DEBUG
                print("⚙️ ExerciseDatabase: Warm cache loaded (\(exercises.count) exercises)")
#endif
                cachedExercises = exercises
                isPreloading = false
            }
        }
    }

    static func cachedSnapshot() -> [ExerciseData]? {
        cachedExercises
    }

    static func getAllExercises() -> [ExerciseData] {
        if let cachedExercises {
            return cachedExercises
        }

        preloadIfNeeded()
        if isPreloading {
            preloadGroup.wait()
        }

        guard let cached = cachedExercises else {
            let exercises = loadExercisesFromCSV()
#if DEBUG
            assert(
                exercises.count >= minimumExerciseCount,
                "exercisesdb.csv parsed only \(exercises.count) exercises"
            )
#endif
            cachedExercises = exercises
            return exercises
        }

        return cached
    }

    /// Find an exercise by ID
    static func findExercise(byId id: Int) -> ExerciseData? {
        let exercises = getAllExercises()
        return exercises.first { $0.id == id }
    }
    
    private static func loadExercisesFromCSV() -> [ExerciseData] {
        guard let url = csvResourceURL() else {
            assertionFailure("exercisesdb.csv not found in bundle")
            return []
        }
        
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let rows = CSVParser.parse(contents)
            var exercises: [ExerciseData] = []
            var seenIds = Set<Int>()
            
            for row in rows {
                guard row.count >= 11 else { continue }
                guard let id = Int(row[0]) else { continue }
                if seenIds.contains(id) { continue }
                seenIds.insert(id)
                
                let trimmed = row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                let categoryValue = trimmed[10].isEmpty ? nil : trimmed[10]
                
                let exercise = ExerciseData(
                    id: id,
                    name: trimmed[1],
                    exerciseType: trimmed[2],
                    bodyPart: trimmed[3],
                    equipment: trimmed[4],
                    gender: trimmed[5],
                    target: trimmed[6],
                    synergist: trimmed[7],
                    category: categoryValue
                )
                exercises.append(exercise)
            }
            
            return exercises
        } catch {
            assertionFailure("Failed to load exercisesdb.csv: \(error)")
            return []
        }
    }
    
    private static func csvResourceURL() -> URL? {
        if let url = Bundle.main.url(forResource: csvFileName, withExtension: "csv") {
            return url
        }
        return Bundle(for: BundleToken.self).url(forResource: csvFileName, withExtension: "csv")
    }
    
    private final class BundleToken {}

    // MARK: - Body Part Mapping (Sports Science-based)

    /// Maps the CSV target muscle to a user-friendly body part category.
    /// Uses anatomical knowledge to group specific muscles into general body parts.
    static func mapTargetToBodyPart(_ target: String, fallbackBodyPart: String) -> String {
        let normalizedTarget = target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Abs
        if normalizedTarget.contains("rectus abdominis") ||
           normalizedTarget.contains("obliques") ||
           normalizedTarget.contains("transverse abdominis") {
            return "Abs"
        }

        // Chest
        if normalizedTarget.contains("pectoralis") ||
           normalizedTarget.contains("serratus anterior") {
            return "Chest"
        }

        // Back (Lats, Rhomboids, Teres, Infraspinatus)
        if normalizedTarget.contains("latissimus") ||
           normalizedTarget.contains("rhomboids") ||
           normalizedTarget.contains("teres major") ||
           normalizedTarget.contains("infraspinatus") ||
           normalizedTarget.contains("supraspinatus") {
            return "Back"
        }

        // Lower Back
        if normalizedTarget.contains("erector spinae") {
            return "Lower Back"
        }

        // Trapezius
        if normalizedTarget.contains("trapezius") {
            return "Trapezius"
        }

        // Neck
        if normalizedTarget.contains("sternocleidomastoid") ||
           normalizedTarget.contains("splenius") ||
           normalizedTarget.contains("levator scapulae") {
            return "Neck"
        }

        // Shoulders
        if normalizedTarget.contains("deltoid") {
            return "Shoulders"
        }

        // Biceps
        if normalizedTarget.contains("biceps brachii") ||
           normalizedTarget.contains("brachialis") {
            return "Biceps"
        }

        // Triceps
        if normalizedTarget.contains("triceps") {
            return "Triceps"
        }

        // Forearms
        if normalizedTarget.contains("brachioradialis") ||
           normalizedTarget.contains("wrist flexor") ||
           normalizedTarget.contains("wrist extensor") ||
           normalizedTarget.contains("forearm") {
            return "Forearms"
        }

        // Glutes
        if normalizedTarget.contains("gluteus") ||
           normalizedTarget.contains("deep hip external rotator") {
            return "Glutes"
        }

        // Quads
        if normalizedTarget.contains("quadriceps") ||
           normalizedTarget.contains("iliopsoas") ||
           normalizedTarget.contains("rectus femoris") ||
           normalizedTarget.contains("vastus") {
            return "Quads"
        }

        // Hamstrings
        if normalizedTarget.contains("hamstrings") ||
           normalizedTarget.contains("biceps femoris") ||
           normalizedTarget.contains("semitendinosus") ||
           normalizedTarget.contains("semimembranosus") {
            return "Hamstrings"
        }

        // Calves
        if normalizedTarget.contains("gastrocnemius") ||
           normalizedTarget.contains("soleus") ||
           normalizedTarget.contains("tibialis") {
            return "Calves"
        }

        // Adductors
        if normalizedTarget.contains("adductor") {
            return "Adductors"
        }

        // Abductors (tensor fasciae latae, gluteus medius in abduction context)
        if normalizedTarget.contains("tensor fasciae") ||
           normalizedTarget.contains("abductor") {
            return "Abductors"
        }

        // Fallback: Map the old bodyPart column to new categories
        return mapOldBodyPartToNew(fallbackBodyPart)
    }

    /// Maps the old CSV bodyPart column values to the new standardized body parts
    private static func mapOldBodyPartToNew(_ bodyPart: String) -> String {
        let normalized = bodyPart.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalized {
        case "waist":
            return "Abs"
        case "chest":
            return "Chest"
        case "back":
            return "Back"
        case "shoulders":
            return "Shoulders"
        case "upper arms":
            return "Biceps" // Could be either, but we'll refine via target
        case "forearms":
            return "Forearms"
        case "hips":
            return "Glutes"
        case "thighs":
            return "Quads" // Could be quads/hamstrings, refined via target
        case "calves":
            return "Calves"
        case "neck":
            return "Neck"
        default:
            // Return original if no mapping found
            return bodyPart.isEmpty ? "Other" : bodyPart
        }
    }

    // MARK: - Multi-Muscle Mapping

    /// Maps the target muscle string to ALL matching body part categories.
    /// Unlike mapTargetToBodyPart which returns the first match, this returns all matches.
    /// Useful for showing multiple muscle chips (e.g., "Shoulders, Trapezius" for a shrug).
    static func mapTargetToAllBodyParts(_ target: String) -> [String] {
        let normalizedTarget = target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var bodyParts: [String] = []

        // Abs
        if normalizedTarget.contains("rectus abdominis") ||
           normalizedTarget.contains("obliques") ||
           normalizedTarget.contains("transverse abdominis") {
            bodyParts.append("Abs")
        }

        // Chest
        if normalizedTarget.contains("pectoralis") ||
           normalizedTarget.contains("serratus anterior") {
            bodyParts.append("Chest")
        }

        // Back (Lats, Rhomboids, Teres, Infraspinatus)
        if normalizedTarget.contains("latissimus") ||
           normalizedTarget.contains("rhomboids") ||
           normalizedTarget.contains("teres major") ||
           normalizedTarget.contains("infraspinatus") ||
           normalizedTarget.contains("supraspinatus") {
            bodyParts.append("Back")
        }

        // Lower Back
        if normalizedTarget.contains("erector spinae") {
            bodyParts.append("Lower Back")
        }

        // Trapezius
        if normalizedTarget.contains("trapezius") {
            bodyParts.append("Trapezius")
        }

        // Neck
        if normalizedTarget.contains("sternocleidomastoid") ||
           normalizedTarget.contains("splenius") ||
           normalizedTarget.contains("levator scapulae") {
            bodyParts.append("Neck")
        }

        // Shoulders
        if normalizedTarget.contains("deltoid") {
            bodyParts.append("Shoulders")
        }

        // Biceps
        if normalizedTarget.contains("biceps brachii") ||
           normalizedTarget.contains("brachialis") {
            bodyParts.append("Biceps")
        }

        // Triceps
        if normalizedTarget.contains("triceps") {
            bodyParts.append("Triceps")
        }

        // Forearms
        if normalizedTarget.contains("brachioradialis") ||
           normalizedTarget.contains("wrist flexor") ||
           normalizedTarget.contains("wrist extensor") ||
           normalizedTarget.contains("forearm") {
            bodyParts.append("Forearms")
        }

        // Glutes
        if normalizedTarget.contains("gluteus") ||
           normalizedTarget.contains("deep hip external rotator") {
            bodyParts.append("Glutes")
        }

        // Quads
        if normalizedTarget.contains("quadriceps") ||
           normalizedTarget.contains("iliopsoas") ||
           normalizedTarget.contains("rectus femoris") ||
           normalizedTarget.contains("vastus") {
            bodyParts.append("Quads")
        }

        // Hamstrings
        if normalizedTarget.contains("hamstrings") ||
           normalizedTarget.contains("biceps femoris") ||
           normalizedTarget.contains("semitendinosus") ||
           normalizedTarget.contains("semimembranosus") {
            bodyParts.append("Hamstrings")
        }

        // Calves
        if normalizedTarget.contains("gastrocnemius") ||
           normalizedTarget.contains("soleus") ||
           normalizedTarget.contains("tibialis") {
            bodyParts.append("Calves")
        }

        // Adductors
        if normalizedTarget.contains("adductor") {
            bodyParts.append("Adductors")
        }

        // Abductors
        if normalizedTarget.contains("tensor fasciae") ||
           normalizedTarget.contains("abductor") {
            bodyParts.append("Abductors")
        }

        return bodyParts
    }

    /// Get all body parts for an exercise, combining target and synergist muscles.
    /// Returns unique body parts, primary muscles first.
    static func getAllBodyParts(for exercise: ExerciseData) -> [String] {
        var allBodyParts: [String] = []

        // Get body parts from target muscle
        let targetBodyParts = mapTargetToAllBodyParts(exercise.target)
        for bp in targetBodyParts where !allBodyParts.contains(bp) {
            allBodyParts.append(bp)
        }

        // If no target body parts found, use the bodyPart field
        if allBodyParts.isEmpty {
            let fallback = mapOldBodyPartToNew(exercise.bodyPart)
            if !fallback.isEmpty && fallback != "Other" {
                allBodyParts.append(fallback)
            }
        }

        // Get body parts from synergist muscles
        let synergistBodyParts = mapTargetToAllBodyParts(exercise.synergist)
        for bp in synergistBodyParts where !allBodyParts.contains(bp) {
            allBodyParts.append(bp)
        }

        return allBodyParts
    }

    private struct CSVParser {
        static func parse(_ text: String) -> [[String]] {
            var rows: [[String]] = []
            var currentRow: [String] = []
            var currentField = ""
            var insideQuotes = false
            
            let scalars = Array(text.unicodeScalars)
            var index = 0
            
            while index < scalars.count {
                let scalar = scalars[index]
                switch scalar.value {
                case 34: // double quote
                    if insideQuotes && index + 1 < scalars.count && scalars[index + 1].value == 34 {
                        currentField.append("\"")
                        index += 1
                    } else {
                        insideQuotes.toggle()
                    }
                case 44: // comma
                    if insideQuotes {
                        currentField.append(Character(scalar))
                    } else {
                        currentRow.append(currentField)
                        currentField.removeAll(keepingCapacity: true)
                    }
                case 10: // newline
                    if insideQuotes {
                        currentField.append(Character(scalar))
                    } else {
                        currentRow.append(currentField)
                        rows.append(currentRow)
                        currentRow.removeAll(keepingCapacity: true)
                        currentField.removeAll(keepingCapacity: true)
                    }
                case 13: // carriage return
                    if insideQuotes {
                        currentField.append(Character(scalar))
                    } else {
                        if index + 1 < scalars.count && scalars[index + 1].value == 10 {
                            index += 1
                        }
                        currentRow.append(currentField)
                        rows.append(currentRow)
                        currentRow.removeAll(keepingCapacity: true)
                        currentField.removeAll(keepingCapacity: true)
                    }
                default:
                    currentField.append(Character(scalar))
                }
                index += 1
            }
            
            if !currentField.isEmpty || !currentRow.isEmpty {
                currentRow.append(currentField)
                rows.append(currentRow)
            }
            
            guard !rows.isEmpty else {
                return []
            }
            
            return Array(rows.dropFirst())
        }
    }
}
