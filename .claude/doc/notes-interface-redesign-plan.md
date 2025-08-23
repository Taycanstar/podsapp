# Notes Input Interface Redesign Plan
*Following Apple's Design Patterns*

## Design Brief

**Problem**: Current notes input interface takes excessive vertical space with fixed 300pt height, includes unwanted exercise context, and doesn't follow iOS Notes app patterns.

**Users**: Fitness app users adding quick notes about exercises during or after workouts.

**Constraints**: 
- Full-screen NavigationView presentation
- Must feel native and familiar to iOS users
- Single-line start with dynamic growth
- Clean, minimal interface

**Goals**: 
- Reduce initial visual footprint
- Create familiar Notes-like experience
- Maintain usability while removing clutter
- Follow Apple HIG spacing and typography

## Solution Analysis

### Current Issues Identified
1. **Excessive Height**: Fixed 300pt `minHeight` creates large visual footprint
2. **Context Bloat**: Exercise header section (lines 25-36) adds unnecessary context
3. **Visual Noise**: Character count footer (lines 69-87) creates distraction
4. **Poor Growth**: No natural text expansion behavior

### Apple Notes App Analysis
- **Initial Height**: ~36-40pt (single line of text + padding)
- **Growth Behavior**: Expands naturally as content increases
- **Maximum Visible**: ~8-10 lines before scrolling internally
- **Clean Layout**: Just text input with minimal chrome
- **Typography**: System font, comfortable line height

## Implementation Specifications

### Layout Hierarchy
```
NavigationView
├── ScrollView (for keyboard avoidance)
└── VStack
    ├── TextEditor (dynamic height)
    └── Spacer() (pushes content to top)
```

### Height Specifications
- **Initial Height**: 40pt (accommodates single line + padding)
- **Line Height**: ~22pt per line (system default)
- **Maximum Visible**: 200pt (~9 lines) before internal scrolling
- **Padding**: 16pt horizontal, 8pt vertical (Apple standard)

### Typography & Spacing
- **Font**: `.body` (17pt system font)
- **Line Spacing**: System default
- **Text Color**: `.primary` 
- **Placeholder Color**: `.secondary`
- **Background**: `.clear` (let NavigationView handle)

### Dynamic Behavior
- Start at single-line height (40pt)
- Grow incrementally with content
- Smooth animations using SwiftUI's natural behavior
- Internal scrolling after reaching max visible height

## SwiftUI Implementation Plan

### File: ExerciseNotesSheet.swift

#### Remove These Elements:
1. **Exercise Header Section** (lines 25-36)
   - VStack with exercise name
   - Background color styling
   - Padding

2. **Character Count Footer** (lines 69-87)
   - HStack with character count
   - Warning labels
   - Character limit enforcement UI

3. **Fixed Height Constraint** (line 54)
   - `.frame(minHeight: 300)`

#### Modify These Elements:

**1. Main Layout Structure:**
```swift
NavigationView {
    ScrollView {
        VStack(spacing: 0) {
            // Simplified text input only
            textInputSection
            Spacer(minLength: 0)
        }
        .padding()
    }
    .navigationTitle("Add Notes")  // Changed from "Notes"
    .navigationBarTitleDisplayMode(.inline)
    // ... existing toolbar
}
```

**2. Text Input Section:**
```swift
private var textInputSection: some View {
    ZStack(alignment: .topLeading) {
        if tempNotes.isEmpty {
            Text("Add your notes here...")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .allowsHitTesting(false)
        }
        
        TextEditor(text: $tempNotes)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, -4)  // Align with placeholder
            .frame(minHeight: 40)     // Single line start
            .frame(maxHeight: 200)    // Max before scrolling
            .focused($isTextFieldFocused)
            .onChange(of: tempNotes) { _, newValue in
                // Keep character limit logic but remove UI
                if newValue.count > maxCharacters {
                    tempNotes = String(newValue.prefix(maxCharacters))
                    let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
                    impactFeedback.impactOccurred()
                }
            }
    }
}
```

**3. Navigation Title:**
- Change from "Notes" to "Add Notes" for clarity

**4. Placeholder Text:**
- Simplify from verbose instruction to "Add your notes here..."

### Behavior Specifications

#### Focus Management
- Auto-focus on appearance (existing behavior is good)
- Maintain focus during typing
- Handle keyboard dismissal gracefully

#### Save Validation
- Keep existing logic for empty note validation
- Maintain trim whitespace functionality
- Preserve haptic feedback on save

#### Dismiss Behavior
- Keep `interactiveDismissDisabled` for unsaved changes
- Maintain confirmation for data loss prevention

### Accessibility Considerations
- `TextEditor` inherits proper accessibility traits
- Placeholder text provides context for VoiceOver
- Navigation buttons maintain proper accessibility labels
- 44pt minimum tap target maintained for toolbar buttons

### Dark Mode Support
- `.primary` and `.secondary` colors adapt automatically
- No custom colors needed for this simplified interface
- NavigationView background handles theme changes

## Implementation Steps

1. **Remove Exercise Header** (lines 25-36)
2. **Remove Character Count Footer** (lines 69-87) 
3. **Update TextEditor constraints** (replace fixed 300pt with 40pt min, 200pt max)
4. **Simplify placeholder text**
5. **Change navigation title** to "Add Notes"
6. **Test dynamic height behavior**
7. **Verify keyboard handling**
8. **Test on various text lengths**

## Success Metrics

- **Visual**: Input starts at single-line height
- **Behavior**: Grows naturally with content
- **Usability**: Feels like native iOS Notes app
- **Performance**: Smooth scrolling and expansion
- **Accessibility**: Maintains VoiceOver compatibility

## Code Changes Summary

### Deletions:
- Exercise header VStack (lines 25-36)
- Character count footer HStack (lines 69-87)  
- `showCharacterWarning` state variable
- `characterCountColor` computed property

### Modifications:
- TextEditor frame from `minHeight: 300` to `minHeight: 40, maxHeight: 200`
- Navigation title from "Notes" to "Add Notes"
- Simplified placeholder text
- Streamlined layout structure

### Preserves:
- Save/Cancel navigation buttons
- Character limit enforcement (background)
- Auto-focus behavior
- Dismiss protection for unsaved changes
- Haptic feedback
- ExerciseNotesService integration

This redesign creates a clean, Apple Notes-like interface that starts compact and grows naturally, following iOS design patterns while maintaining all essential functionality.