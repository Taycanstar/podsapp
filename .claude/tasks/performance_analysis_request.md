performance-architect: I need performance analysis and optimization guidance for SwiftUI computed properties in LogWorkoutView.

## CONTEXT:
User is adding computed properties to LogWorkoutView to delegate to WorkoutManager:

```swift
// Properties that reference WorkoutManager (single source of truth)
private var sessionDuration: WorkoutDuration? {
    workoutManager.sessionDuration
}

private var sessionFitnessGoal: FitnessGoal? {
    workoutManager.sessionFitnessGoal
}

private var sessionFitnessLevel: ExperienceLevel? {
    workoutManager.sessionFitnessLevel
}

private var flexibilityPreferences: FlexibilityPreferences? {
    workoutManager.sessionFlexibilityPreferences
}
```

## USAGE PATTERNS:
1. Called in isButtonModified() function that checks if session overrides exist
2. Used for UI state computation showing modified states in workout controls
3. Called frequently during UI updates
4. WorkoutManager has @Published properties that are accessed directly

## PERFORMANCE QUESTIONS:
1. Are simple computed properties like these performant for SwiftUI?
2. Should these values be cached or is direct access fine?
3. Will this cause unnecessary view recomputations?
4. Any performance considerations for @Published property access through computed properties?

## ARCHITECTURE:
- WorkoutManager is @EnvironmentObject with @Published properties
- Properties are Optional types that can be nil
- Used in workout generation and UI state logic

Please provide performance analysis and optimization recommendations.
