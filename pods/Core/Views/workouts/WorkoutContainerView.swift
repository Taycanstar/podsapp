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
    @State private var exerciseUpdateCallback: ((Int, TodayWorkoutExercise) -> Void)?
    @State private var loggingContext: LogExerciseSheetContext?
    @EnvironmentObject private var proFeatureGate: ProFeatureGate
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            LogWorkoutView(
                selectedTab: $selectedTab, 
                navigationPath: $navigationPath,
                onExerciseReplacementCallbackSet: { callback in
                    exerciseReplacementCallback = callback
                },
                onExerciseUpdateCallbackSet: { callback in
                    exerciseUpdateCallback = callback
                },
                onPresentLogSheet: { ctx in
                    // Present logging as a full-screen cover instead of pushing
                    loggingContext = ctx
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
                        // Legacy fallback: if any view still pushes this route, present sheet
                        Color.clear
                            .onAppear {
                                loggingContext = LogExerciseSheetContext(exercise: exercise, allExercises: allExercises, index: index)
                                // Immediately pop to avoid showing an empty page
                                if !navigationPath.isEmpty { navigationPath.removeLast() }
                            }
                    }
                }
                .fullScreenCover(item: $loggingContext) { ctx in
                    ExerciseLoggingView(
                        exercise: ctx.exercise,
                        allExercises: ctx.allExercises,
                        onSetLogged: nil,
                        isFromWorkoutInProgress: false,
                        initialCompletedSetsCount: nil,
                        initialRIRValue: nil,
                        onExerciseReplaced: { newExercise in
                            exerciseReplacementCallback?(ctx.index, newExercise)
                        },
                        onWarmupSetsChanged: { _ in },
                        onExerciseUpdated: { updated in
                            exerciseUpdateCallback?(ctx.index, updated)
                        }
                    )
                }
        }
        // Note: Upgrade sheet is presented from MainContentView to avoid conflicts
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
