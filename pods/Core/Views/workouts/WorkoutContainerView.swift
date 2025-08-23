//
//  WorkoutContainerView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/14/25.
//

import SwiftUI

struct WorkoutContainerView: View {
    @Binding var selectedTab: Int
    @State private var navigationPath = NavigationPath()
    @State private var exerciseReplacementCallback: ((Int, ExerciseData) -> Void)?
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            LogWorkoutView(
                selectedTab: $selectedTab, 
                navigationPath: $navigationPath,
                onExerciseReplacementCallbackSet: { callback in
                    exerciseReplacementCallback = callback
                }
            )
                .navigationDestination(for: WorkoutNavigationDestination.self) { destination in
                    switch destination {
                    case .createWorkout:
                        CreateWorkoutView(navigationPath: $navigationPath)
                    case .editWorkout(let workout):
                        // TODO: Implement EditWorkoutView
                        CreateWorkoutView(navigationPath: $navigationPath, workout: workout)
                    case .exerciseSelection:
                        // TODO: Implement ExerciseSelectionView
                        Text("Exercise Selection View")
                            .navigationTitle("Select Exercise")
                    case .recentlyAdded:
                        RecentlyAddedView()
                    case .startWorkout(let todayWorkout):
                        StartWorkoutView(todayWorkout: todayWorkout)
                    case .logExercise(let exercise, let allExercises, let index):
                        ExerciseLoggingView(
                            exercise: exercise, 
                            allExercises: allExercises,
                            onSetLogged: nil, // No set logging needed from this context
                            isFromWorkoutInProgress: false,
                            initialCompletedSetsCount: nil,
                            initialRIRValue: nil,
                            onExerciseReplaced: { newExercise in
                                // Call the stored callback to update the parent list
                                exerciseReplacementCallback?(index, newExercise)
                            },
                            onWarmupSetsChanged: { warmupSets in
                                // TODO: Handle warm-up sets persistence in parent context
                                // This will need to update the specific exercise in the workout data
                            }
                        )
                    }
                }
        }
    }
}

// MARK: - Navigation Destinations
enum WorkoutNavigationDestination: Hashable {
    case createWorkout
    case editWorkout(Workout)
    case exerciseSelection
    case recentlyAdded
    case startWorkout(TodayWorkout)
    case logExercise(TodayWorkoutExercise, [TodayWorkoutExercise], Int)
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .createWorkout:
            hasher.combine("createWorkout")
        case .editWorkout(let workout):
            hasher.combine("editWorkout")
            hasher.combine(workout.id)
        case .exerciseSelection:
            hasher.combine("exerciseSelection")
        case .recentlyAdded:
            hasher.combine("recentlyAdded")
        case .startWorkout(let todayWorkout):
            hasher.combine("startWorkout")
            hasher.combine(todayWorkout.id)
        case .logExercise(let exercise, let allExercises, let index):
            hasher.combine("logExercise")
            hasher.combine(exercise.exercise.id)
            hasher.combine(allExercises.count)
            hasher.combine(index)
        }
    }
    
    // Implement Equatable conformance
    static func == (lhs: WorkoutNavigationDestination, rhs: WorkoutNavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.createWorkout, .createWorkout):
            return true
        case (.editWorkout(let lhsWorkout), .editWorkout(let rhsWorkout)):
            return lhsWorkout.id == rhsWorkout.id
        case (.exerciseSelection, .exerciseSelection):
            return true
        case (.recentlyAdded, .recentlyAdded):
            return true
        case (.startWorkout(let lhsTodayWorkout), .startWorkout(let rhsTodayWorkout)):
            return lhsTodayWorkout.id == rhsTodayWorkout.id
        case (.logExercise(let lhsExercise, _, _), .logExercise(let rhsExercise, _, _)):
            return lhsExercise.exercise.id == rhsExercise.exercise.id
        default:
            return false
        }
    }
}

#Preview {
    WorkoutContainerView(selectedTab: .constant(0))
}
