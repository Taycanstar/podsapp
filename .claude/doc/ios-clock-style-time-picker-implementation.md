# iOS Clock-Style Time Picker Implementation Plan

## Executive Summary
Replace the current `MenuPickerStyle()` implementation with a native iOS Clock app-style time picker using `WheelPickerStyle()` and proper state management to create an inline expandable interface.

## Problem Analysis

### Current Issues
- **MenuPickerStyle Creates Dropdowns**: Current implementation shows dropdown menus instead of inline wheel pickers
- **Non-Native Experience**: Doesn't match iOS Clock app behavior users expect
- **Poor Discoverability**: Users don't realize they can interact with time values
- **Inconsistent Interaction**: Doesn't follow iOS Human Interface Guidelines for time input

### User Goals (Jobs-to-be-Done)
- **Primary**: Quickly set exercise duration (e.g., "5:30" for plank hold)
- **Secondary**: Adjust time values with familiar iOS-native gestures
- **Tertiary**: See current time value at a glance without interaction

## Design Solution

### A. Native iOS Clock App Behavior Analysis
The iOS Clock timer uses:
1. **Collapsed State**: Shows "5 min 30 sec" as tappable text
2. **Expanded State**: Shows three inline wheel pickers (hours, minutes, seconds)
3. **Smooth Transition**: Animated expand/collapse with proper height changes
4. **Wheel Styling**: System-standard wheel picker appearance with labels
5. **Auto-Collapse**: Taps outside the picker collapse it back to compact form

### B. SwiftUI Implementation Strategy

#### Component Architecture
```
InlineTimePickerField
├── CollapsedTimeDisplay (tappable summary)
├── ExpandedWheelPickers (HH:MM:SS wheels)
├── AnimationContainer (smooth transitions)
└── FocusManager (keyboard/picker coordination)
```

#### State Management
```swift
@State private var isExpanded: Bool = false
@State private var hours: Int = 0
@State private var minutes: Int = 0  
@State private var seconds: Int = 0
```

## Technical Implementation

### Core Component: `InlineTimePickerField`

```swift
struct InlineTimePickerField: View {
    @Binding var duration: TimeInterval
    let isFocused: Bool
    let showEachLabel: Bool
    
    @State private var isExpanded: Bool = false
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Collapsed display - matches existing TikTok style
            collapsedTimeDisplay
            
            // Expanded wheel pickers - native iOS style
            if isExpanded {
                expandedWheelPickers
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
        .background(Color("tiktoknp"))
        .cornerRadius(8)
        .onAppear { updateTimeComponents() }
        .onChange(of: duration) { _, _ in updateTimeComponents() }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
}
```

### Collapsed Time Display
```swift
private var collapsedTimeDisplay: some View {
    HStack {
        Text("Time")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.secondary)
        
        Spacer()
        
        Text(formatTimeDisplay())
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(isFocused ? .blue : .primary)
        
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .contentShape(Rectangle())
}
```

### Expanded Wheel Pickers
```swift
private var expandedWheelPickers: some View {
    HStack(spacing: 0) {
        // Hours wheel
        wheelPicker(
            selection: $hours,
            range: 0...23,
            label: "hr"
        )
        .frame(maxWidth: .infinity)
        
        // Minutes wheel  
        wheelPicker(
            selection: $minutes,
            range: 0...59,
            label: "min"
        )
        .frame(maxWidth: .infinity)
        
        // Seconds wheel
        wheelPicker(
            selection: $seconds,
            range: 0...59, 
            label: "sec"
        )
        .frame(maxWidth: .infinity)
    }
    .frame(height: 120)
    .clipped()
}
```

### Individual Wheel Picker
```swift
private func wheelPicker<T: Hashable>(
    selection: Binding<T>,
    range: ClosedRange<T>,
    label: String
) -> some View where T: CustomStringConvertible {
    Picker("", selection: selection) {
        ForEach(Array(range), id: \.self) { value in
            Text(String(describing: value))
                .font(.system(size: 20, design: .rounded))
                .tag(value)
        }
    }
    .pickerStyle(.wheel)
    .overlay(
        HStack {
            Spacer()
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .padding(.leading, 8)
        }
    )
    .onChange(of: selection.wrappedValue) { _, _ in
        updateDuration()
    }
}
```

## Visual Design Specifications

### Typography
- **Labels**: SF Pro Text, 16pt, Medium weight, Secondary color
- **Values**: SF Pro Text, 16pt, Medium weight, Primary/Blue when focused  
- **Wheel Text**: SF Pro Rounded, 20pt, Regular weight
- **Unit Labels**: SF Pro Text, 16pt, Regular weight, Secondary color

### Spacing & Layout
- **Container Padding**: 12pt horizontal, 12pt vertical
- **Wheel Height**: 120pt (matches iOS Clock app)
- **Wheel Spacing**: 0pt (seamless layout)
- **Animation Duration**: 0.3s ease-in-out

### Colors
- **Background**: Color("tiktoknp") - maintains existing consistency
- **Primary Text**: .primary (adapts to dark/light mode)
- **Secondary Text**: .secondary
- **Focused State**: .blue (system accent)
- **Border Radius**: 8pt (matches existing style)

### Interaction States
1. **Default**: Collapsed, chevron down, primary text color
2. **Focused**: Blue accent color, maintains collapsed state unless tapped
3. **Expanded**: Chevron up, wheel pickers visible, height animated
4. **Wheel Interaction**: Native haptic feedback, momentum scrolling

## Accessibility Implementation

### VoiceOver Support
```swift
.accessibilityElement(children: .contain)
.accessibilityLabel("Exercise duration")
.accessibilityHint("Double tap to set time using wheel pickers")
.accessibilityValue(formatTimeForVoiceOver())
```

### Focus Order
1. Collapsed time display (primary interaction)
2. Hours wheel (when expanded)
3. Minutes wheel (when expanded) 
4. Seconds wheel (when expanded)

### Dynamic Type Support
- All text scales with user's preferred text size
- Wheel picker height adjusts proportionally
- Minimum 44x44pt tap target maintained

## Integration Points

### File Modifications Required

#### 1. FlexibleExerciseInputs.swift (Lines 282-364)
**Replace**: Entire `TimePickerField` struct
**With**: New `InlineTimePickerField` implementation

#### 2. Usage Points (No Changes Required)
- Lines 119-128: Time/Distance input
- Lines 153-162: Time-only input  
- Lines 184-193: Hold time input
- Lines 223-233: Rounds duration input

### Backward Compatibility
- Same `@Binding var duration: TimeInterval` interface
- Same `isFocused: Bool` parameter
- Same `showEachLabel: Bool` parameter
- Maintains existing visual consistency

## Implementation Phases

### Phase 1: Core Wheel Picker (MVP)
- Replace MenuPickerStyle with WheelPickerStyle
- Basic expand/collapse functionality
- Time formatting and parsing

### Phase 2: Animation Polish  
- Smooth expand/collapse transitions
- Height animations
- Chevron rotation

### Phase 3: Accessibility & Edge Cases
- VoiceOver implementation
- Dynamic Type support
- Focus management integration
- Error state handling

## Testing Scenarios

### Functional Testing
1. **Time Setting**: Verify accurate time input across all ranges
2. **State Persistence**: Values maintained during expand/collapse
3. **Integration**: Works within existing exercise input context
4. **Performance**: Smooth animations on older devices

### Usability Testing  
1. **Discoverability**: Users understand they can tap to expand
2. **Efficiency**: Time input faster than keyboard entry
3. **Familiarity**: Matches iOS Clock app expectations
4. **Error Prevention**: Invalid times handled gracefully

### Accessibility Testing
1. **VoiceOver**: Clear navigation and value announcements
2. **Dynamic Type**: Text scales appropriately
3. **Reduce Motion**: Respects animation preferences
4. **High Contrast**: Sufficient color contrast ratios

## Success Metrics

### Primary KPIs
- **User Adoption**: % of users who expand time picker vs skip
- **Input Accuracy**: Reduced time input errors
- **Task Completion Time**: Faster exercise duration setting

### Secondary KPIs  
- **User Satisfaction**: Post-feature survey scores
- **Support Tickets**: Reduced time picker related issues
- **Accessibility Compliance**: VoiceOver usability scores

## Risk Mitigation

### Technical Risks
- **iOS Version Compatibility**: Test on iOS 17.2+ minimum
- **Performance Impact**: Monitor animation performance on older devices
- **Layout Constraints**: Ensure proper height calculations in List context

### UX Risks
- **User Confusion**: A/B test with existing implementation
- **Muscle Memory**: Gradual rollout to avoid disruption
- **Edge Cases**: Handle extreme duration values gracefully

## Implementation Notes

### Critical SwiftUI Patterns
1. **State Management**: Use `@State` for internal picker state, sync with `@Binding`
2. **Animation Coordination**: Coordinate picker expansion with focus state changes
3. **Gesture Conflicts**: Ensure tap gestures don't interfere with wheel scrolling
4. **Memory Management**: Dispose of picker resources when collapsed

### iOS Clock App Parity Features
- **Haptic Feedback**: Include subtle haptics for value changes
- **Momentum Scrolling**: Native wheel picker behavior preserved
- **Visual Hierarchy**: Clear label positioning matches system patterns
- **State Restoration**: Remember expanded state during session

This implementation transforms the current dropdown-style time input into a native iOS Clock app experience while maintaining full backward compatibility and visual consistency with the existing codebase.