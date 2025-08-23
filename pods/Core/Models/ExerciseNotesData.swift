//
//  ExerciseNotesData.swift
//  pods
//
//  Created by Dimi Nunez on 8/23/25.
//

import SwiftData
import Foundation

@Model
class ExerciseNotesData {
    var exerciseId: Int
    var notes: String
    var lastModified: Date
    var userEmail: String
    
    init(exerciseId: Int, notes: String, userEmail: String) {
        self.exerciseId = exerciseId
        self.notes = notes
        self.lastModified = Date()
        self.userEmail = userEmail
    }
}
