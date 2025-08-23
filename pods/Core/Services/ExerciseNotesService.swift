//
//  ExerciseNotesService.swift
//  pods
//
//  Created by Dimi Nunez on 8/23/25.
//

import Foundation
import SwiftData
import Combine

@MainActor
class ExerciseNotesService: ObservableObject {
    static let shared = ExerciseNotesService()
    
    private var syncDebouncer: AnyCancellable?
    private let syncDelay: TimeInterval = 2.0 // 2 seconds debounce for server sync
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Load notes for a specific exercise
    func loadNotes(for exerciseId: Int) async -> String {
        // First check UserDefaults for immediate access (Layer 3)
        let key = notesKey(for: exerciseId)
        if let cachedNotes = UserDefaults.standard.string(forKey: key) {
            return cachedNotes
        }
        
        // Try to load from DataLayer
        let dataKey = "exercise_notes_\(exerciseId)"
        if let notesString = await DataLayer.shared.getData(key: dataKey) as? String {
            // Cache in UserDefaults for faster access
            UserDefaults.standard.set(notesString, forKey: key)
            return notesString
        }
        
        return ""
    }
    
    /// Save notes for a specific exercise with immediate local persistence
    func saveNotes(_ notes: String, for exerciseId: Int) async {
        let key = notesKey(for: exerciseId)
        
        // Immediate local save to UserDefaults (Layer 3)
        if notes.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(notes, forKey: key)
        }
        
        // Save to DataLayer
        let dataKey = "exercise_notes_\(exerciseId)"
        if notes.isEmpty {
            // Remove from DataLayer if notes are empty
            await DataLayer.shared.setData(key: dataKey, value: NSNull())
        } else {
            // Save notes string to DataLayer
            await DataLayer.shared.setData(key: dataKey, value: notes)
        }
        
        // Schedule debounced server sync
        scheduleServerSync(exerciseId: exerciseId, notes: notes)
    }
    
    /// Delete notes for a specific exercise
    func deleteNotes(for exerciseId: Int) async {
        let key = notesKey(for: exerciseId)
        
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: key)
        
        // Remove from DataLayer
        let dataKey = "exercise_notes_\(exerciseId)"
        await DataLayer.shared.setData(key: dataKey, value: NSNull())
    }
    
    /// Check if notes exist for an exercise (quick check)
    func hasNotes(for exerciseId: Int) -> Bool {
        let key = notesKey(for: exerciseId)
        return UserDefaults.standard.string(forKey: key) != nil
    }
    
    // MARK: - Private Methods
    
    private func notesKey(for exerciseId: Int) -> String {
        return "exercise_notes_\(exerciseId)"
    }
    
    private func scheduleServerSync(exerciseId: Int, notes: String) {
        // Cancel previous sync if exists
        syncDebouncer?.cancel()
        
        // Schedule new sync with debounce
        syncDebouncer = Just(())
            .delay(for: .seconds(syncDelay), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.performServerSync(exerciseId: exerciseId, notes: notes)
                }
            }
    }
    
    private func performServerSync(exerciseId: Int, notes: String) async {
        // This would sync with the Django backend
        // For now, just log the action
        print("Syncing notes for exercise \(exerciseId) to server...")
        
        // TODO: Implement actual API call when backend endpoint is ready
        /*
        do {
            let endpoint = "/api/exercise-notes/"
            let payload = [
                "exercise_id": exerciseId,
                "notes": notes,
                "last_modified": ISO8601DateFormatter().string(from: Date())
            ]
            
            // Use NetworkManager to make the API call
            // await NetworkManager.shared.post(endpoint, body: payload)
        } catch {
            print("Server sync failed for exercise \(exerciseId): \(error)")
        }
        */
    }
}

