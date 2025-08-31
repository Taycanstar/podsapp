# Context Session 1: Fitness Level Filtering System

## Session Goal
Implement a fitness level filtering system to prevent inappropriate exercises from being recommended to users based on their experience level.

## Problem Statement
- Beginners receiving advanced exercises like handstand push-ups
- No complexity ratings in the database
- ~400 exercises all treated equally regardless of difficulty
- Need to filter based on user's fitness level

## Proposed Solution from Exercise Science Advisor
- 5-level complexity rating system (1=Beginner to 5=Expert)
- Experience-based filtering:
  - Beginners: Complexity 1-2 only
  - Intermediate: Complexity 1-3
  - Advanced: Complexity 1-5
- Recovery rate modifiers per experience level

## Current Architecture Analysis

### Key Components Identified
1. **ExerciseData struct** in `/Users/dimi/Documents/dimi/podsapp/pods/Pods/Core/Models/WorkoutModels.swift`
   - Currently has: id, name, exerciseType, bodyPart, equipment, gender, target, synergist
   - NO complexity rating field

2. **WorkoutRecommendationService** in `/Users/dimi/Documents/dimi/podsapp/pods/Pods/Core/Services/WorkoutRecommendationService.swift`
   - Has filtering by muscle groups, equipment
   - Uses UserProfileService.shared.experienceLevel
   - NO complexity-based filtering

3. **UserProfileService** in `/Users/dimi/Documents/dimi/podsapp/pods/Pods/Core/Services/UserProfileService.swift`
   - Already tracks ExperienceLevel enum (beginner, intermediate, advanced)
   - Server-first with UserDefaults fallback

4. **ExerciseDatabase** in `/Users/dimi/Documents/dimi/podsapp/pods/Pods/Core/Views/workouts/ExerciseDatabase.swift`
   - Hardcoded exercise list (400+ exercises)
   - Loads from embedded data, not JSON anymore

5. **exercises.json** - Still exists but not actively used
   - Contains exercise data but no complexity ratings

### Experience Level System
- ExperienceLevel enum: beginner, intermediate, advanced
- Already integrated with user profile and recommendations

### Current Exercise Filtering Points
- AddExerciseView.swift - filteredExercises computed property
- ExerciseLoggingView.swift - filteredExercises for replacements
- WorkoutRecommendationService - muscle group filtering
- Multiple category views (BodyweightExercisesView, etc.)

## Architecture Design Requirements
1. **Data Model Updates** with backward compatibility
2. **Clean service layer architecture** for complexity filtering
3. **Proper state management** for experience level changes
4. **Testable and maintainable implementation**
5. **Progressive enhancement strategy** - works without ratings initially

## Advanced Exercises Identified
- Handstand Push-Up (id: 894)
- Handstand Walk (id: 3444) 
- Full planche (id: 6834)
- Handstand Hold on Wall (id: 10884)

## Session Progress - Fitness Level Filtering
- ✅ Analyzing current codebase structure completed
- ✅ Designing SwiftUI-appropriate architecture completed  
- ✅ Creating comprehensive implementation plan completed

## Implementation Plan Created
- **Location**: `/Users/dimi/Documents/dimi/podsapp/pods/.claude/doc/fitness_level_filtering_implementation_plan.md`
- **Approach**: Progressive enhancement with backward compatibility
- **Key Components**: ExerciseComplexityService, enhanced ExerciseData model, integrated filtering

---

## NEW CRITICAL ISSUE: SwiftUI List Navigation & Swipe Actions

### Problem Statement
- User reports critical issue: swipe-to-delete functionality completely lost in `DynamicSetsInputView`
- Current implementation uses `LazyVStack` instead of `List`, removing native swipe actions
- User explicitly states: "This is bad" and demands: "Go back to List and fix it the way it is"
- Content disappearing when List is embedded in parent ScrollView

### Current Broken Implementation
```swift
// In DynamicSetsInputView.swift - BROKEN (no swipe actions)
LazyVStack(spacing: 8) {
    ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
        DynamicSetRowView(...)
        .padding(.vertical, 4)
    }
}
```

### Parent Context Analysis
- `DynamicSetsInputView` is used inside `ExerciseLoggingView`
- Parent uses `ScrollView` with `mainScrollContent`
- Nested scrolling issue: List inside ScrollView causes display problems
- Swipe-to-delete is essential for workout UX - users need to delete sets

### Requirements for Fix
1. **Must use List** - not LazyVStack or alternatives
2. **Swipe-to-delete must work** - native `.swipeActions` required
3. **Content must be visible** - no disappearing content in ScrollView
4. **Parent ScrollView integration** - proper sizing and scrolling behavior
5. **No nested scrolling conflicts** - List should size to content, parent handles scrolling

### SwiftUI Architect Solution Created
- ✅ **Analysis Complete**: Identified root cause - List height calculation and scrolling conflicts
- ✅ **Architecture Design**: Proper List configuration for parent ScrollView integration
- ✅ **Implementation Plan**: Complete step-by-step solution with code examples
- **Location**: `/Users/dimi/Documents/dimi/podsapp/pods/.claude/doc/swiftui_list_scrollview_fix_implementation.md`

### Key Technical Solutions
1. **Height Calculation**: Explicit `.frame(height: calculateListHeight())` for List sizing
2. **Scroll Disabling**: `.scrollDisabled(true)` to let parent ScrollView handle scrolling
3. **Swipe Actions Restoration**: Native `.swipeActions` with proper delete integration
4. **List Configuration**: `.listStyle(.plain)`, `.listRowSeparator(.hidden)` for clean integration

### Critical Implementation Points
- Replace `LazyVStack` with properly configured `List`
- Add `calculateListHeight()` method for dynamic sizing
- Configure List modifiers: `.scrollDisabled(true)`, `.listStyle(.plain)`
- Restore `.swipeActions(edge: .trailing)` for delete functionality

## Architecture Decisions Made
- **Service Pattern**: Create dedicated ExerciseComplexityService for centralized logic
- **Data Model**: Optional complexityRating field with smart fallback estimation
- **Experience Mapping**: Beginner(1-2), Intermediate(1-3), Advanced(1-5) 
- **Integration**: Leverage existing UserProfileService.experienceLevel
- **Performance**: Use computed properties and caching for filtering