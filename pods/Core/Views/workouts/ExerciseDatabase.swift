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
