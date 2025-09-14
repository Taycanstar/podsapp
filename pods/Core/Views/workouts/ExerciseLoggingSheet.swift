//
//  ExerciseLoggingSheet.swift
//  pods
//
//  Created by Dimi Nunez on 9/14/25.
//

import SwiftUI

struct LogExerciseSheetContext: Identifiable, Equatable {
    let id = UUID()
    let exercise: TodayWorkoutExercise
    let allExercises: [TodayWorkoutExercise]
    let index: Int
}
