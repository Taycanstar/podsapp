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
        
        // Try to load from DataLayer - expect JSON structure
        let dataKey = "exercise_notes_\(exerciseId)"
        if let notesData = await DataLayer.shared.getData(key: dataKey) as? [String: Any],
           let notesString = notesData["notes"] as? String {
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
        
        // Save to DataLayer in JSON format
        let dataKey = "exercise_notes_\(exerciseId)"
        if notes.isEmpty {
            // Remove from DataLayer completely when notes are empty
            await DataLayer.shared.removeData(key: dataKey)
            print("📝 Cleared notes from DataLayer for exercise \(exerciseId)")
        } else {
            // Create JSON structure for DataLayer
            let notesData: [String: Any] = [
                "exercise_id": exerciseId,
                "notes": notes,
                "updated_at": ISO8601DateFormatter().string(from: Date()),
                "sync_version": 1
            ]
            await DataLayer.shared.setData(key: dataKey, value: notesData)
        }
        
        // Schedule debounced server sync
        scheduleServerSync(exerciseId: exerciseId, notes: notes)
    }
    
    /// Delete notes for a specific exercise
    func deleteNotes(for exerciseId: Int) async {
        let key = notesKey(for: exerciseId)
        
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: key)
        
        // Remove from DataLayer completely
        let dataKey = "exercise_notes_\(exerciseId)"
        await DataLayer.shared.removeData(key: dataKey)
        print("📝 Cleared notes from both UserDefaults and DataLayer for exercise \(exerciseId)")
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
        print("Syncing notes for exercise \(exerciseId) to server...")
        
        guard let userEmail = await getCurrentUserEmail() else {
            print("No user email found for server sync")
            return
        }
        
        // Use NetworkManagerTwo with proper completion handler
        await withCheckedContinuation { continuation in
            NetworkManagerTwo.shared.createOrUpdateExerciseNotes(
                exerciseId: exerciseId,
                notes: notes,
                userEmail: userEmail
            ) { result in
                switch result {
                case .success(let responseData):
                    print("Server sync successful for exercise \(exerciseId)")
                case .failure(let error):
                    print("Server sync failed for exercise \(exerciseId): \(error)")
                }
                continuation.resume()
            }
        }
    }
    
    private func getCurrentUserEmail() async -> String? {
        // Get the current user's email from UserDefaults or DataLayer
        if let email = UserDefaults.standard.string(forKey: "user_email") {
            return email
        }
        
        // Try to get from DataLayer as fallback
        if let userData = await DataLayer.shared.getData(key: "current_user") as? [String: Any],
           let email = userData["email"] as? String {
            return email
        }
        
        return nil
    }
}

