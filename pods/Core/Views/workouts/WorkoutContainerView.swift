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
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            LogWorkoutView(selectedTab: $selectedTab, navigationPath: $navigationPath)
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
}

#Preview {
    WorkoutContainerView(selectedTab: .constant(0))
}
