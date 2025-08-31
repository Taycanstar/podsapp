# Duration Exercise Timer Interface Design
*Apple Design System Implementation for iOS SwiftUI Fitness App*

## Executive Summary

This specification defines a comprehensive timer interface for duration-based workout exercises that seamlessly integrates with the existing ExerciseLoggingView. The design follows Apple's Human Interface Guidelines, emphasizing clarity, accessibility, and intuitive interactions that feel native to iOS users.

**Key Innovation**: Quarter-sheet timer interface with automatic set logging that maintains workout flow continuity.

---

## Design Brief

### Problem Statement
Users currently input exercise durations manually, creating friction during active workouts. Live timer functionality is needed to track active duration sets with automatic logging capabilities.

### Target Users
- **Primary**: Active fitness users tracking timed exercises (planks, cardio intervals, holds)
- **Secondary**: Workout beginners needing guided timing assistance
- **Accessibility**: Users relying on VoiceOver, Dynamic Type, and Reduce Motion

### User Goals (Jobs-to-be-Done)
1. **Start Timer**: Quickly begin timing without interrupting workout flow
2. **Monitor Progress**: See clear countdown with motivational feedback
3. **Auto-Log Sets**: Complete sets automatically when timer finishes
4. **Maintain Flow**: Stay focused on exercise without UI distractions
5. **Recover Gracefully**: Handle interruptions (calls, notifications) smoothly

### Constraints
- Must integrate with existing ExerciseLoggingView architecture
- Cannot disrupt current manual logging workflow
- Quarter-sheet presentation only (25% screen coverage)
- iOS 17.2+ SwiftUI compatibility required
- Battery efficiency during long duration exercises

### Success Metrics
- Timer completion rate >90% (vs manual abandonment)
- Reduced logging friction (time from set completion to next set start)
- Maintained accessibility compliance (VoiceOver, Dynamic Type)
- Zero performance degradation during timer operation

---

## Solution Options Analysis

### Option A: Full-Screen Timer (Rejected)
**Pros**: Maximum focus, clear visibility
**Cons**: Disrupts workout context, blocks exercise reference material
**Verdict**: Too disruptive for workout flow

### Option B: Inline Timer (Rejected)  
**Pros**: Minimal UI disruption
**Cons**: Limited space for clear countdown, conflicts with input fields
**Verdict**: Insufficient visual hierarchy for active timing

### Option C: Quarter-Sheet Timer (Selected)
**Pros**: 
- Maintains workout context visibility
- Sufficient space for clear timer display
- Apple-native sheet interaction patterns
- Dismissible without losing progress
**Cons**: Slightly more complex interaction
**Verdict**: ✅ **Optimal balance of focus and context**

---

## Detailed UI Specification

### 1. Bottom Action Button Layout

#### 1.1 Default State (Duration Exercise + Workout in Progress)
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│    [Start Timer]              [Log Set]                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Visual Specifications:**
- **Container**: HStack with `.frame(maxWidth: .infinity)`, 16pt horizontal padding
- **Spacing**: 12pt between buttons
- **Height**: 56pt (optimized for thumb reach)

**Start Timer Button:**
- **Style**: Secondary button (outline style)
- **Background**: Clear with 2pt stroke using `.primary` color
- **Text**: "Start Timer" in SF Pro Text, 16pt, .semibold
- **Icon**: `timer` SF Symbol, 16pt, .semibold
- **Tap Target**: Minimum 44×44pt (exceeds with 56pt height)
- **States**: 
  - Default: Primary color outline
  - Pressed: Background fill with primary color, white text
  - Disabled: `.systemGray3` outline and text

**Log Set Button:**
- **Style**: Primary button
- **Background**: `.primary` color (adaptive for light/dark)
- **Text**: "Log Set" in SF Pro Text, 16pt, .semibold, white color
- **Icon**: `plus.circle.fill` SF Symbol, 16pt
- **Tap Target**: Minimum 44×44pt
- **States**:
  - Default: Primary background
  - Pressed: Slightly darker primary (0.8 opacity)
  - Disabled: `.systemGray3` background

#### 1.2 All Sets Completed State
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                     [Done]                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Done Button:**
- **Style**: Primary action button, full width
- **Background**: Success green (`.systemGreen`)
- **Text**: "Done" in SF Pro Text, 18pt, .bold
- **Icon**: `checkmark.circle.fill` SF Symbol, 18pt
- **Height**: 56pt
- **Corner Radius**: 12pt
- **Animation**: Slide transition when replacing dual buttons

### 2. Timer Sheet Interface

#### 2.1 Presentation Style
- **Type**: `.presentationDetents([.fraction(0.25)])`
- **Background**: `.systemBackground` with blur effect
- **Corner Radius**: 16pt (system default)
- **Drag Indicator**: Visible (`.presentationDragIndicator(.visible)`)
- **Interactive Dismissal**: Enabled

#### 2.2 Timer Sheet Layout
```
┌─────────────────────────────────────────────────────────┐
│  ×                   2:35                               │
│                                                         │
│              ┌─────────────┐                           │
│              │             │                           │
│              │    01:30    │     ●                      │
│              │             │                           │
│              └─────────────┘                           │
│                                                         │
│               [Pause]    [Stop]                        │
└─────────────────────────────────────────────────────────┘
```

**Header Section:**
- **Dismiss Button**: X mark, top-left, 24pt tap target
- **Exercise Name**: Center, SF Pro Text, 17pt, .medium
- **Height**: 60pt including safe area

**Timer Display:**
- **Countdown**: SF Pro Display, 48pt, .bold, monospaced
- **Format**: MM:SS for durations <1 hour, H:MM:SS for longer
- **Color**: `.primary` (adapts to light/dark)
- **Background**: Circular progress ring (see Progress Ring section)
- **Position**: Centered in available space

**Progress Ring:**
- **Style**: Circular stroke, 8pt line width
- **Colors**: 
  - Background: `.systemGray5` (20% opacity)
  - Progress: `.systemBlue` (active), `.systemGreen` (final 10 seconds)
- **Animation**: Smooth reduction with easeInOut timing
- **Size**: 200pt diameter (scales with Dynamic Type)

**Control Buttons:**
- **Layout**: HStack, equally distributed
- **Pause Button**:
  - Icon: `pause.circle.fill` / `play.circle.fill` (toggle state)
  - Size: 60pt diameter
  - Color: `.systemBlue`
- **Stop Button**:
  - Icon: `stop.circle.fill`
  - Size: 60pt diameter  
  - Color: `.systemRed`

#### 2.3 Timer States

**Running State:**
- Progress ring animates countdown
- Pause button shows pause icon
- Haptic feedback every 30 seconds (if enabled)

**Paused State:**
- Progress ring pauses at current position
- Pause button shows play icon
- Subtle pulsing animation on play button

**Final 10 Seconds:**
- Progress ring color changes to `.systemGreen`
- Countdown text color becomes `.systemGreen`
- Haptic feedback every second (if enabled)

**Completion State:**
- Brief success animation (scale + opacity)
- Sheet auto-dismisses after 1 second
- Set automatically logged
- Success haptic feedback

**Cancelled State:**
- Sheet dismisses immediately
- No set logging
- No haptic feedback

### 3. User Interaction Flows

#### 3.1 Start Timer Flow
```
Exercise Screen → Tap "Start Timer" → Timer Sheet Appears → Timer Starts
```

**Detailed Steps:**
1. User taps "Start Timer" button
2. Sheet presentation animation (0.3s ease-out)
3. Timer automatically starts countdown from set duration
4. Progress ring begins animation
5. First haptic feedback pulse (if enabled)

#### 3.2 Timer Completion Flow
```
Timer Runs → Reaches 00:00 → Auto-logs Set → Sheet Dismisses → Returns to Exercise
```

**Detailed Steps:**
1. Countdown reaches 00:00
2. Success animation plays (0.2s)
3. Success haptic feedback
4. Set marked as completed in background
5. Sheet dismisses after 1s delay
6. Exercise screen updates to show completed set
7. Focus automatically moves to next set or "Done" state

#### 3.3 Timer Cancellation Flow
```
Timer Running → Tap X or Swipe Down → Confirm Cancel → Sheet Dismisses
```

**Detailed Steps:**
1. User taps X or swipes down
2. Alert appears: "Cancel timer? Progress will be lost."
3. Options: "Continue Timer" / "Cancel Timer"
4. If cancelled: Sheet dismisses immediately, no set logged
5. If continued: Alert dismisses, timer resumes

### 4. Accessibility Specifications

#### 4.1 VoiceOver Support

**Button Labels:**
- "Start Timer": "Start timer for [exercise name], [duration]"
- "Log Set": "Log completed set"
- "Done": "Mark exercise as complete"
- Timer Dismiss: "Cancel timer"
- Pause: "Pause timer" / "Resume timer"
- Stop: "Stop timer and discard progress"

**Timer Announcements:**
- Every 30 seconds: "Timer: [time remaining]"
- Final 10 seconds: Count down each second
- Completion: "Timer complete. Set logged."

**Focus Order:**
1. Dismiss button
2. Timer display (readable)
3. Pause button
4. Stop button

#### 4.2 Dynamic Type Support

**Text Scaling:**
- Timer display: Scales up to accessibility sizes
- Button text: Standard Dynamic Type scaling
- Minimum tap targets maintained at all sizes

**Layout Adaptation:**
- Larger text sizes may require vertical button stack
- Timer display size scales proportionally
- Sheet height adjusts for larger text (max 40% screen)

#### 4.3 Reduce Motion Support

**Alternative Animations:**
- Progress ring: Static fill instead of smooth animation
- Button press: Opacity change only
- Sheet presentation: Fade instead of slide
- Completion: Simple opacity flash

#### 4.4 Color Accessibility

**High Contrast:**
- All colors meet WCAG AA standards (4.5:1 minimum)
- Progress ring has sufficient contrast in all states
- Timer text remains readable in high contrast mode

**Color Blindness:**
- Success state uses both color and checkmark icon
- Progress states distinguishable through opacity/position
- No color-only information conveying

### 5. SwiftUI Component Architecture

#### 5.1 Primary Components

**DurationExerciseTimerSheet**
```swift
struct DurationExerciseTimerSheet: View {
    @Binding var isPresented: Bool
    let duration: TimeInterval
    let exerciseName: String
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @StateObject private var timerManager = TimerManager()
    
    var body: some View {
        // Implementation
    }
}
```

**TimerManager (ObservableObject)**
```swift
class TimerManager: ObservableObject {
    @Published var timeRemaining: TimeInterval
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    
    private var timer: Timer?
    
    func start(duration: TimeInterval) { /* */ }
    func pause() { /* */ }
    func resume() { /* */ }
    func stop() { /* */ }
}
```

**CircularProgressRing**
```swift
struct CircularProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let lineWidth: CGFloat = 8
    
    var body: some View {
        // Ring implementation with animation
    }
}
```

#### 5.2 Integration Points

**ExerciseLoggingView Modifications:**
```swift
// Add timer sheet presentation
.sheet(isPresented: $showTimerSheet) {
    DurationExerciseTimerSheet(
        isPresented: $showTimerSheet,
        duration: currentSet.duration,
        exerciseName: exercise.name,
        onComplete: { autoLogCurrentSet() },
        onCancel: { /* handle cancellation */ }
    )
}

// Modified bottom buttons for duration exercises
private var bottomActionButtons: some View {
    if isDurationExercise && workoutInProgress {
        if allSetsCompleted {
            doneButton
        } else {
            dualActionButtons
        }
    } else {
        // Existing logic
    }
}
```

#### 5.3 State Management Integration

**Timer State Coordination:**
- Timer state persists during app backgrounding
- Integration with existing set completion logic
- Automatic UI updates when timer completes
- Proper cleanup when view disappears

### 6. Animation and Transition Guidelines

#### 6.1 Sheet Presentation
- **Duration**: 0.3 seconds
- **Curve**: `easeOut`
- **Style**: Native sheet animation with spring physics
- **Backdrop**: Blur effect with fade-in

#### 6.2 Timer Animations
- **Progress Ring**: Linear countdown with `easeInOut` curve
- **Text Updates**: Monospaced font prevents layout jitter
- **Final Seconds**: Gentle pulsing effect on countdown

#### 6.3 Button Interactions
- **Tap Response**: 0.1s scale animation (0.95 scale)
- **State Changes**: 0.2s opacity/color transitions
- **Success States**: Brief scale animation (1.05x, spring back)

#### 6.4 Completion Sequence
1. **Timer Reaches Zero** (0.0s)
2. **Success Animation** (0.2s): Scale + green color flash
3. **Haptic Feedback** (0.0s)
4. **Pause Before Dismiss** (1.0s)
5. **Sheet Dismissal** (0.3s)

### 7. Performance Considerations

#### 7.1 Battery Optimization
- Timer updates at 1-second intervals (not continuous)
- Progress ring uses efficient Core Animation layer updates
- Background timer handling with proper lifecycle management
- Automatic pause when app backgrounds

#### 7.2 Memory Management
- TimerManager properly deallocates when dismissed
- No retain cycles in timer callbacks
- Efficient animation layer cleanup

#### 7.3 Responsive Design
- 60fps animations maintained during timer operation
- Smooth sheet interactions without frame drops
- Optimistic UI updates for button presses

---

## Implementation Priority

### Phase 1: Core Timer Functionality
1. ✅ **TimerManager** class with basic start/pause/stop
2. ✅ **DurationExerciseTimerSheet** basic layout
3. ✅ **Bottom button layout** modifications
4. ✅ **Basic integration** with ExerciseLoggingView

### Phase 2: Polish and Accessibility
1. ✅ **CircularProgressRing** with animations
2. ✅ **VoiceOver** complete implementation
3. ✅ **Dynamic Type** support
4. ✅ **Haptic feedback** integration

### Phase 3: Edge Cases and Optimization
1. ✅ **Background timer** handling
2. ✅ **Interruption recovery** (calls, notifications)
3. ✅ **Performance optimization**
4. ✅ **Reduce Motion** support

---

## Files to Create/Modify

### New Files
1. `/Pods/Core/Components/DurationExerciseTimerSheet.swift`
2. `/Pods/Core/Managers/TimerManager.swift`
3. `/Pods/Core/Components/CircularProgressRing.swift`

### Modified Files
1. `/Pods/Core/Views/workouts/ExerciseLoggingView.swift`
   - Add timer sheet presentation
   - Modify bottom button layout for duration exercises
   - Add auto-logging logic integration

2. `/Pods/Core/Models/FlexibleSetData.swift` (if needed)
   - Ensure proper timer duration storage

---

## Acceptance Criteria

### Functional Requirements
- [ ] Timer starts immediately when "Start Timer" is tapped
- [ ] Countdown displays accurate time remaining in MM:SS format
- [ ] Progress ring animates smoothly with countdown
- [ ] Timer can be paused and resumed
- [ ] Timer can be cancelled with confirmation
- [ ] Set auto-logs when timer reaches completion
- [ ] Sheet dismisses automatically after completion
- [ ] Bottom buttons update correctly based on completion state

### Accessibility Requirements
- [ ] All controls have proper VoiceOver labels
- [ ] Timer progress announced at appropriate intervals
- [ ] Dynamic Type scaling works correctly
- [ ] High contrast mode supported
- [ ] Reduce Motion respected for all animations
- [ ] Minimum 44pt tap targets maintained

### Performance Requirements
- [ ] Sheet presentation <300ms
- [ ] Timer updates remain smooth during operation
- [ ] No memory leaks during extended timer sessions
- [ ] Battery impact minimal during background operation

### Visual Requirements
- [ ] Matches Apple's timer design patterns
- [ ] Consistent with existing app visual style
- [ ] Progress ring colors follow semantic color system
- [ ] Animations feel responsive and natural

---

## Testing Strategy

### Unit Testing
- TimerManager countdown accuracy
- Auto-logging integration
- State management during interruptions

### Usability Testing
- Timer visibility during workouts
- Button accessibility and discoverability  
- Completion flow satisfaction

### Accessibility Testing
- VoiceOver navigation completeness
- Dynamic Type layout integrity
- High contrast readability

### Performance Testing
- Battery drain during long sessions
- Memory usage stability
- Animation frame rate consistency

---

*This specification provides a complete foundation for implementing an Apple-quality timer interface that enhances the workout experience while maintaining the app's existing design language and accessibility standards.*