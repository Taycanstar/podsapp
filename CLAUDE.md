# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Plan & Review
### Before starting work
- Always in plan mode to make a plan
- After you get the plan, make sure you write the plan to .claude/taks/TASK_NAME.md.
- The plan should be a detailed implementation plan and the reasoning behind them, as well as tasks broken down.
- If the task require external knowledge or certain package, also research to get the latest knowledge (Use task tool for research)
- Don't over plan it, always think MVP.
- Once you write the plan, firstly ask me to review it. Do not continue until I approve the plan/

## While implementing
- You should update the plan as you work.
- After you complete tasks in the plan, you should update and append detailed descriptions of the changes you made, so following tasks can be easily hand over to other engineers.

## Common Commands

### Build and Test
- **Build project**: `xcodebuild -scheme pods -configuration Debug build`
- **Build for release**: `xcodebuild -scheme pods -configuration Release build`
- **Run tests**: `xcodebuild -scheme pods -destination 'platform=iOS Simulator,name=iPhone 15' test`
- **Clean build**: `xcodebuild -scheme pods clean`

### Development Workflow
- **Open in Xcode**: `open pods.xcworkspace` (use workspace, not xcodeproj, due to CocoaPods)
- **Install dependencies**: `pod install` (run when Podfile changes)
- **Update dependencies**: `pod update`

### Project Structure Commands
- **List schemes**: `xcodebuild -list`
- **View project info**: `xcodebuild -showBuildSettings -scheme pods`

## Architecture Overview

This is a comprehensive SwiftUI fitness/health tracking app called "Pods" with the following key architectural patterns:

### Core Architecture Layers

1. **5-Layer Data Architecture** (described in DATA_ARCHITECTURE.md):
   - Layer 1: In-Memory Cache (fastest access)
   - Layer 2: Local Database (SwiftData)
   - Layer 3: UserDefaults (simple preferences)
   - Layer 4: Remote Server (source of truth)
   - Layer 5: Sync Coordinator (intelligent sync)

2. **MVVM Pattern**:
   - Views: SwiftUI views organized by feature
   - ViewModels: Observable objects managing state (`SharedViewModel`, `OnboardingViewModel`, etc.)
   - Models: SwiftData models (`UserProfile`, `Exercise`, `ExerciseInstance`, `SetInstance`)

### Directory Structure

```
Pods/
├── Core/                           # Core business logic
│   ├── Services/                   # Data services (DataLayer, WorkoutDataManager)
│   ├── Managers/                   # Business managers (NetworkManager, ActivityManager)
│   ├── Models/                     # SwiftData models
│   ├── Views/                      # Feature-organized views
│   │   ├── workouts/              # Workout-related views
│   │   ├── food/                  # Food logging views
│   │   ├── dashboard/             # Dashboard and metrics
│   │   └── profile/               # User profile views
│   └── Components/                # Reusable UI components
├── viewModels/                    # View models for state management
├── onboarding/                    # User onboarding flow
├── auth/                          # Authentication views
└── Assets.xcassets/               # App assets and images
```

### Key Services

- **DataLayer**: Unified data access with caching strategies (Core/Services/DataLayer.swift)
- **DataSyncService**: Handles offline-first sync with conflict resolution
- **WorkoutDataManager**: Manages workout sessions and exercise data
- **NetworkManager**: API communication layer
- **HealthKitManager**: Apple Health integration
- **ActivityManager**: Activity logging and tracking

### Data Flow Strategies

The app implements different data access patterns:
- **Memory-First**: For active UI data (`strategy: .memoryFirst`)
- **Local-First**: For offline-capable data (`strategy: .localFirst`) 
- **Remote-First**: For real-time shared data (`strategy: .remoteFirst`)
- **Offline**: For cached-only access (`strategy: .offline`)

## Development Guidelines

### SwiftData Models
- Models are defined in `Core/Models/` and use `@Model` macro
- Primary models: `UserProfile`, `Exercise`, `ExerciseInstance`, `SetInstance`
- WorkoutSession is managed separately by WorkoutDataManager

### View Organization
- Views are organized by feature in `Core/Views/`
- Each major feature has its own subfolder (workouts, food, dashboard, etc.)
- Reusable components go in `Core/Components/`

### State Management
- Use ViewModels for complex state (located in `viewModels/`)
- ObservableObjects are injected via `@EnvironmentObject`
- Simple state can use `@State` and `@Published` properties

### Data Access
- Use DataLayer for new features: `DataLayer.shared.getData()` and `DataLayer.shared.saveData()`
- Legacy UserDefaults access is maintained for backward compatibility
- Choose appropriate data strategy based on use case (see DATA_ARCHITECTURE.md)

### Dependencies
- CocoaPods for dependency management (Podfile)
- Key frameworks: SwiftUI, SwiftData, Combine, GoogleSignIn, Mixpanel
- Use `pods.xcworkspace` not `pods.xcodeproj` for development

### Testing
- Unit tests in `podsTests/`
- UI tests in `podsUITests/`
- Run tests with destination parameter for iOS Simulator

## Key Files to Understand

- `podsApp.swift`: Main app entry point with dependency injection
- `ContentView.swift`: Root view with navigation
- `DATA_ARCHITECTURE.md`: Comprehensive data layer documentation
- `Core/Services/DataLayer.swift`: Main data access interface
- `Core/Models/`: SwiftData model definitions
- `Podfile`: CocoaPods dependencies

## Common Patterns

### Adding New Features
1. Create models in `Core/Models/` if needed
2. Add views in appropriate `Core/Views/` subfolder
3. Create ViewModel if complex state management needed
4. Use DataLayer for data persistence
5. Add to navigation in `ContentView.swift` or appropriate parent view

### Data Operations
```swift
// Save data with sync
try await DataLayer.shared.saveData(
    userData, 
    key: "user_profile_\(userEmail)", 
    strategy: .localFirst
)

// Load data with caching
let userData = try await DataLayer.shared.getData(
    UserProfile.self, 
    key: "user_profile_\(userEmail)", 
    strategy: .memoryFirst
)
```

### Error Handling
- Use proper error handling with do-catch blocks
- DataLayer operations can throw, handle appropriately
- Network operations should handle offline scenarios