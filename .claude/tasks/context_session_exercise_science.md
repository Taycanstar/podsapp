# Exercise Science Context Session: Dynamic Rep Programming Implementation

## Task Overview
Implementing Fitbod's dynamic rep programming approach to move beyond static workout recommendations to intelligent variability that prevents plateaus and optimizes training adaptations.

## Current State Analysis

### Static Algorithm Issues
- **Hypertrophy**: Always 3×8 (good but static)
- **General Fitness**: Always 3×10 (solid baseline but unchanging)
- **Strength**: Working on optimization
- **Endurance**: Always 3×20 (appropriate but static)
- **Tone**: Always 3×12 (reasonable but unchanging)

### Current Architecture
- `WorkoutRecommendationService`: Handles exercise selection and basic recommendations
- `WorkoutGenerationService`: Creates workout plans with time optimization
- Static `getGoalParameters()` method using Perplexity algorithm with individual factors
- Fixed rep/set combinations per fitness goal
- No session-to-session variability
- No performance feedback integration

## Fitbod's Dynamic Approach Analysis

### Key Concepts Identified
1. **Dynamic Variability**: Rep ranges instead of fixed values (e.g., 8-15 reps vs fixed 10)
2. **Workout Phase Cycling**: 
   - Session A: Lower reps, higher intensity (3×8)
   - Session B: Higher reps, moderate intensity (3×12)  
   - Session C: Balanced approach (4×10)
3. **Exercise Type Differentiation**: Compound vs isolation get different treatment
4. **Performance Feedback Integration**: Adjusts based on previous workout difficulty
5. **Recovery Status Integration**: Fresh muscles get different programming

## Exercise Science Requirements

### Rep Range Optimization
- Optimal rep range windows for each fitness goal
- Scientifically justified range widths
- Exercise type considerations (compound vs isolation)

### Periodization Implementation
- Block periodization principles for app context
- Session-to-session variation patterns
- Cycling frequency between focuses

### Auto-Regulation
- RPE/RiR feedback for unsupervised users
- Performance indicators for adjustments
- Response protocols for workout difficulty

### Recovery Integration
- Muscle recovery status estimation
- Workout frequency patterns
- Fresh vs fatigued muscle programming

## Implementation Goals
1. Replace static recommendations with intelligent variability
2. Implement session cycling patterns
3. Add performance feedback loops
4. Integrate recovery-based adjustments
5. Maintain scientific validity
6. Ensure user-friendly experience

## Status
- ✅ Analyzed current static implementation
- ✅ Reviewed Fitbod's approach and user requirements
- ✅ Identified key exercise science principles
- ✅ Created comprehensive implementation plan at `/claude/doc/dynamic-rep-programming-implementation-plan.md`
- ⏳ Implementation phase (ready for parent agent)

## Key Files Involved
- `/Pods/Core/Services/WorkoutRecommendationService.swift` - Main recommendation logic
- `/Pods/Core/Services/WorkoutGenerationService.swift` - Workout creation
- `/Pods/Core/Views/workouts/LogWorkoutView.swift` - TodayWorkout models
- `/Pods/Core/Models/WorkoutSession.swift` - Session tracking

## Notes
- Focus on practical implementation for unsupervised app users
- Balance scientific accuracy with usability
- Consider iOS offline-first architecture requirements
- Plan for gradual rollout with A/B testing capabilities