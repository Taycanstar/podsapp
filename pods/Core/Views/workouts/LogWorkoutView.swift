//
//  LogWorkoutView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/5/25.
//
//  WORKOUT SESSION DURATION PERSISTENCE:
//  
//  This view implements a two-tier duration system similar to Fitbod:
//  
//  1. DEFAULT DURATION (selectedDuration):
//     - User's permanent preference stored in UserDefaults + server
//     - Updated when "Set as default" is pressed
//     - Syncs with UserProfileService and backend
//
//  2. SESSION DURATION (sessionDuration):
//     - Temporary override for current workout session
//     - Persists across app restarts until workout is completed
//     - Updated when "Set for this workout" is pressed
//     - Stored in UserDefaults with date validation (clears old sessions)
//     - Automatically cleared when workout is completed
//
//  The effectiveDuration computed property returns sessionDuration ?? selectedDuration
//  ensuring session overrides take precedence over defaults.
//

import SwiftUI
import AVKit
import AVFoundation

struct LogWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: Int
    @Binding var navigationPath: NavigationPath
    let onExerciseReplacementCallbackSet: (((Int, ExerciseData) -> Void)?) -> Void
    let onExerciseUpdateCallbackSet: (((Int, TodayWorkoutExercise) -> Void)?) -> Void
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    // Tab management
    @State private var selectedWorkoutTab: WorkoutTab = .today
    
    // Add WorkoutManager
    @StateObject private var workoutManager = WorkoutManager()
    
    // Add user email - you'll need to pass this in or get it from environment
    @State private var userEmail: String = UserDefaults.standard.string(forKey: "userEmail") ?? ""
    
    // Workout controls state
    @State private var selectedDuration: WorkoutDuration = .oneHour
    @State private var sessionDuration: WorkoutDuration? = nil // Session-specific duration (doesn't affect defaults)
    @State private var showingDurationPicker = false
    @State private var shouldRegenerateWorkout = false
    @State private var showingTargetMusclesPicker = false
    @State private var customTargetMuscles: [String]? = nil // Custom muscle selection for session
    @State private var selectedMuscleType: String = "Recovered Muscles" // Track the muscle type selection
    @State private var showingEquipmentPicker = false
    @State private var customEquipment: [Equipment]? = nil // Custom equipment selection for session
    @State private var selectedEquipmentType: String = "Auto" // Track equipment type selection
    
    // Add fitness goal state variables
    @State private var selectedFitnessGoal: FitnessGoal = .strength
    @State private var sessionFitnessGoal: FitnessGoal? = nil // Session-specific goal (doesn't affect defaults)
    @State private var showingFitnessGoalPicker = false
    
    // Add fitness level state variables
    @State private var selectedFitnessLevel: ExperienceLevel = .beginner
    @State private var sessionFitnessLevel: ExperienceLevel? = nil // Session-specific level (doesn't affect defaults)
    @State private var showingFitnessLevelPicker = false
    
    // Add flexibility preferences state variables
    @State private var selectedFlexibilityPreferences: FlexibilityPreferences = FlexibilityPreferences() // Default preferences (both disabled by default)
    @State private var flexibilityPreferences: FlexibilityPreferences? = nil // Session-specific flexibility preferences
    @State private var showingFlexibilityPicker = false
    
    // Add state for showing workout in progress
    @State private var currentWorkout: TodayWorkout? = nil
    
    // Loading state for preferences and workout generation
    @State private var isGeneratingWorkout = false
    @State private var generationMessage = "Creating your workout..."
    
    // Computed property for the actual duration to use
    private var effectiveDuration: WorkoutDuration {
        return sessionDuration ?? selectedDuration
    }
    
    // Computed property for the actual fitness goal to use
    private var effectiveFitnessGoal: FitnessGoal {
        return sessionFitnessGoal ?? selectedFitnessGoal
    }
    
    // Computed property for the actual flexibility preferences to use
    private var effectiveFlexibilityPreferences: FlexibilityPreferences {
        return flexibilityPreferences ?? selectedFlexibilityPreferences // Use session override or defaults
    }
    
    // Check if there are any session modifications
    private var hasSessionModifications: Bool {
        return sessionDuration != nil || customTargetMuscles != nil || customEquipment != nil || sessionFitnessGoal != nil || sessionFitnessLevel != nil || (flexibilityPreferences != nil && flexibilityPreferences!.isEnabled)
    }
    
    // Loading state messages
    private var loadingMessages: [String] {
        [
            "Selecting exercises...",
            "Optimizing your workout...", 
            "Calculating rest periods...",
            "Finalizing recommendations..."
        ]
    }
    
    // Keys for UserDefaults
    private let sessionDurationKey = "currentWorkoutSessionDuration"
    private let sessionDateKey = "currentWorkoutSessionDate"
    private let customMusclesKey = "currentWorkoutCustomMuscles"
    
    // Add fitness goal session keys
    private let sessionFitnessGoalKey = "currentWorkoutSessionFitnessGoal"
    
    // Add flexibility preferences session key
    private let sessionFlexibilityKey = "currentWorkoutSessionFlexibility"
    
    enum WorkoutTab: Hashable {
        case today, workouts
        
        var title: String {
            switch self {
            case .today: return "Today"
            case .workouts: return "My Workouts"
            }
        }
        
        var searchPrompt: String {
            switch self {
            case .today: return "Search today's workout"
            case .workouts: return "Search workouts"
            }
        }
    }
    
    let workoutTabs: [WorkoutTab] = [.today, .workouts]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background color for the entire view
            Color("iosbg2").edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Fixed non-transparent header
                VStack(spacing: 0) {
                    tabHeaderView
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
                .background(Color(.systemBackground))
                .zIndex(1) // Keep header on top
                
                // Main content
                mainContentView
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .navigationBarBackButtonHidden(true)
        .navigationTitle(selectedWorkoutTab == .workouts ? "Workouts" : "Today's Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .if(selectedWorkoutTab == .workouts) { view in
            view.searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: selectedWorkoutTab.searchPrompt
            )
        }
        .onAppear {
            // Debug: Print userEmail value on appear
            print("🚀 LogWorkoutView appeared. UserEmail: '\(userEmail)' (isEmpty: \(userEmail.isEmpty))")
            
            // Initialize WorkoutManager when view appears
            if !userEmail.isEmpty {
                workoutManager.initialize(userEmail: userEmail)
            }
            
            // Load session flexibility preferences
            loadSessionFlexibilityPreferences()
            
            // Load default flexibility preferences from backend
            let emailToUse = userEmail.isEmpty ? (UserDefaults.standard.string(forKey: "userEmail") ?? "") : userEmail
            if !emailToUse.isEmpty {
                // Update userEmail state if we had to fetch it fresh
                if userEmail.isEmpty && !emailToUse.isEmpty {
                    userEmail = emailToUse
                }
                
                NetworkManagerTwo.shared.getFlexibilityPreferences(email: emailToUse) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let preferences):
                            print("✅ Loaded flexibility defaults: warmUp=\(preferences.warmUpEnabled), coolDown=\(preferences.coolDownEnabled)")
                            // Update the default flexibility preferences from backend
                            selectedFlexibilityPreferences = FlexibilityPreferences(
                                warmUpEnabled: preferences.warmUpEnabled, 
                                coolDownEnabled: preferences.coolDownEnabled
                            )
                        case .failure(let error):
                            print("⚠️ Could not load flexibility defaults from backend: \(error)")
                        }
                    }
                }
            }
            
            // No longer need notification listener
        }
        .onDisappear {
            // Don't remove observer here as it might be needed
            
            // Load user's default workout duration preference
            if let defaultDurationString = UserDefaults.standard.string(forKey: "defaultWorkoutDuration"),
               let defaultDuration = WorkoutDuration(rawValue: defaultDurationString) {
                selectedDuration = defaultDuration
            } else {
                // Fallback to UserProfileService preference
                let availableTime = UserProfileService.shared.availableTime
                selectedDuration = WorkoutDuration.fromMinutes(availableTime)
            }
            
            // Load user's default fitness goal preference
            selectedFitnessGoal = UserProfileService.shared.fitnessGoal
            
            // Load user's default fitness level preference
            selectedFitnessLevel = UserProfileService.shared.experienceLevel
            
            // Load session fitness goal if it exists
            if let savedGoalString = UserDefaults.standard.string(forKey: sessionFitnessGoalKey) {
                sessionFitnessGoal = FitnessGoal(rawValue: savedGoalString)
                print("📱 Restored session fitness goal: \(sessionFitnessGoal?.displayName ?? "nil")")
            }
            
            // Load session fitness level if it exists
            if let savedLevelString = UserDefaults.standard.string(forKey: "currentWorkoutSessionFitnessLevel") {
                sessionFitnessLevel = ExperienceLevel(rawValue: savedLevelString)
                print("📱 Restored session fitness level: \(sessionFitnessLevel?.displayName ?? "nil")")
            }
            
            // Load session duration if it exists
            if let savedDurationString = UserDefaults.standard.string(forKey: sessionDurationKey),
               let savedDuration = WorkoutDuration(rawValue: savedDurationString) {
                
                // Check if session is from today (clear old sessions)
                if let sessionDate = UserDefaults.standard.object(forKey: sessionDateKey) as? Date,
                   Calendar.current.isDateInToday(sessionDate) {
                    sessionDuration = savedDuration
                    print("📱 Restored session duration: \(savedDuration.minutes) minutes from today")
                } else {
                    // Clear old session duration from previous days
                    clearSessionDuration()
                    print("🗑️ Cleared expired session duration from previous day")
                }
            }

            // Load custom muscle selection if it exists
            if let savedCustomMuscles = UserDefaults.standard.array(forKey: customMusclesKey) as? [String] {
                customTargetMuscles = savedCustomMuscles
                print("📱 Restored custom muscle selection: \(customTargetMuscles!)")
            }
            
            // Load muscle type if it exists
            if let savedMuscleType = UserDefaults.standard.string(forKey: "currentWorkoutMuscleType") {
                selectedMuscleType = savedMuscleType
                print("📱 Restored muscle type: \(savedMuscleType)")
            }
            
            // Load custom equipment selection if it exists
            if let savedEquipmentStrings = UserDefaults.standard.array(forKey: "currentWorkoutCustomEquipment") as? [String] {
                customEquipment = savedEquipmentStrings.compactMap { Equipment(rawValue: $0) }
                print("📱 Restored custom equipment: \(customEquipment!.map { $0.rawValue })")
            }
            
            // Load equipment type if it exists
            if let savedEquipmentType = UserDefaults.standard.string(forKey: "currentWorkoutEquipmentType") {
                selectedEquipmentType = savedEquipmentType
                print("📱 Restored equipment type: \(savedEquipmentType)")
            } else {
                // Default to showing user's workout location
                let userProfile = UserProfileService.shared
                selectedEquipmentType = userProfile.workoutLocationDisplay
            }
        }
        .sheet(isPresented: $showingDurationPicker) {
            WorkoutDurationPickerView(
                selectedDuration: .constant(sessionDuration ?? selectedDuration),
                onSetDefault: { newDuration in
                    // Save as default duration - update both local and server
                    let durationMinutes = newDuration.minutes
                    
                    print("🔧 Setting as default duration: \(durationMinutes) minutes")
                    
                    // 1. Update UserDefaults (for immediate use)
                    UserDefaults.standard.set(durationMinutes, forKey: "availableTime")
                    UserDefaults.standard.set(newDuration.rawValue, forKey: "defaultWorkoutDuration")
                    
                    // 2. Update UserProfileService 
                    UserProfileService.shared.availableTime = durationMinutes
                    
                    // 3. Update the main selectedDuration to reflect the new default
                    selectedDuration = newDuration
                    
                    // 4. Clear session duration since it's now the default
                    sessionDuration = nil
                    
                    // 5. Clear session duration from UserDefaults
                    UserDefaults.standard.removeObject(forKey: sessionDurationKey)
                    UserDefaults.standard.removeObject(forKey: sessionDateKey)
                    
                    // 6. Update server data (if user email exists)
                    if let email = UserDefaults.standard.string(forKey: "userEmail") {
                        updateServerWorkoutDuration(email: email, durationMinutes: durationMinutes)
                    }
                    
                    showingDurationPicker = false
                },
                onSetForWorkout: { newDuration in
                    // Apply to current workout session only (no server or default updates)
                    print("⚡ Setting session-only duration: \(newDuration.minutes) minutes (won't save to server)")
                    sessionDuration = newDuration
                    
                    // Save session duration to UserDefaults for persistence across app restarts
                    UserDefaults.standard.set(newDuration.rawValue, forKey: sessionDurationKey)
                    UserDefaults.standard.set(Date(), forKey: sessionDateKey)
                    
                    showingDurationPicker = false
                    regenerateWorkoutWithNewDuration()
                }
            )
        }
        .sheet(isPresented: $showingTargetMusclesPicker) {
            TargetMusclesView(onSelectionChanged: { newMuscles, muscleType in
                // Save custom muscle selection and type, regenerate workout
                customTargetMuscles = newMuscles
                selectedMuscleType = muscleType
                
                // Persist custom muscle selection to UserDefaults
                UserDefaults.standard.set(newMuscles, forKey: customMusclesKey)
                UserDefaults.standard.set(muscleType, forKey: "currentWorkoutMuscleType")
                
                print("🎯 Selected target muscles: \(newMuscles), type: \(muscleType)")
                showingTargetMusclesPicker = false
                regenerateWorkoutWithNewDuration()
            })
        }
        .sheet(isPresented: $showingEquipmentPicker) {
            EquipmentView(onSelectionChanged: { newEquipment, equipmentType in
                // Save custom equipment selection and type, regenerate workout
                customEquipment = newEquipment
                selectedEquipmentType = equipmentType
                
                // Persist custom equipment selection to UserDefaults
                let equipmentStrings = newEquipment.map { $0.rawValue }
                UserDefaults.standard.set(equipmentStrings, forKey: "currentWorkoutCustomEquipment")
                UserDefaults.standard.set(equipmentType, forKey: "currentWorkoutEquipmentType")
                
                print("⚙️ Selected equipment: \(newEquipment.map { $0.rawValue }), type: \(equipmentType)")
                showingEquipmentPicker = false
                regenerateWorkoutWithNewDuration()
            })
        }
        .sheet(isPresented: $showingFitnessGoalPicker) {
            FitnessGoalPickerView(
                selectedFitnessGoal: .constant(sessionFitnessGoal ?? selectedFitnessGoal),
                onSetDefault: { newGoal in
                    // Save as default fitness goal - update both local and server
                    print("🔧 Setting as default fitness goal: \(newGoal.displayName)")
                    
                    // 1. Update UserProfileService
                    UserProfileService.shared.fitnessGoal = newGoal
                    
                    // 2. Update the main selectedFitnessGoal to reflect the new default
                    selectedFitnessGoal = newGoal
                    
                    // 3. Clear session fitness goal since it's now the default
                    sessionFitnessGoal = nil
                    
                    // 4. Clear session fitness goal from UserDefaults
                    UserDefaults.standard.removeObject(forKey: sessionFitnessGoalKey)
                    
                    // 5. Update server data (if user email exists)
                    if let email = UserDefaults.standard.string(forKey: "userEmail") {
                        updateServerFitnessGoal(email: email, fitnessGoal: newGoal)
                    }
                    
                    showingFitnessGoalPicker = false
                    regenerateWorkoutWithNewDuration()
                },
                onSetForWorkout: { newGoal in
                    // Apply to current workout session only (no server or default updates)
                    print("⚡ Setting session-only fitness goal: \(newGoal.displayName) (won't save to server)")
                    sessionFitnessGoal = newGoal
                    
                    // Save session fitness goal to UserDefaults for persistence across app restarts
                    UserDefaults.standard.set(newGoal.rawValue, forKey: sessionFitnessGoalKey)
                    
                    showingFitnessGoalPicker = false
                    regenerateWorkoutWithNewDuration()
                }
            )
        }
        .sheet(isPresented: $showingFitnessLevelPicker) {
            FitnessLevelPickerView(
                selectedFitnessLevel: .constant(sessionFitnessLevel ?? selectedFitnessLevel),
                onSetDefault: { newLevel in
                    // Save as default fitness level - update both local and server
                    print("🔧 Setting as default fitness level: \(newLevel.displayName)")
                    
                    // 1. Update UserProfileService
                    UserProfileService.shared.experienceLevel = newLevel
                    
                    // 2. Update the main selectedFitnessLevel to reflect the new default
                    selectedFitnessLevel = newLevel
                    
                    // 3. Clear session fitness level since it's now the default
                    sessionFitnessLevel = nil
                    
                    // 4. Clear session fitness level from UserDefaults
                    UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionFitnessLevel")
                    
                    // 5. Update server data (if user email exists)
                    if let email = UserDefaults.standard.string(forKey: "userEmail") {
                        updateServerFitnessLevel(email: email, fitnessLevel: newLevel)
                    }
                    
                    showingFitnessLevelPicker = false
                    regenerateWorkoutWithNewDuration()
                },
                onSetForWorkout: { newLevel in
                    // Apply to current workout session only (no server or default updates)
                    print("⚡ Setting session-only fitness level: \(newLevel.displayName) (won't save to server)")
                    sessionFitnessLevel = newLevel
                    
                    // Save session fitness level to UserDefaults for persistence across app restarts
                    UserDefaults.standard.set(newLevel.rawValue, forKey: "currentWorkoutSessionFitnessLevel")
                    
                    showingFitnessLevelPicker = false
                    regenerateWorkoutWithNewDuration()
                }
            )
        }
        .sheet(isPresented: $showingFlexibilityPicker) {
            FlexibilityPickerView(
                warmUpEnabled: .constant(effectiveFlexibilityPreferences.warmUpEnabled),
                coolDownEnabled: .constant(effectiveFlexibilityPreferences.coolDownEnabled),
                onSetDefault: { warmUp, coolDown in
                    // Save as default flexibility preferences to backend
                    print("🔧 Setting as default flexibility: Warm-Up \(warmUp), Cool-Down \(coolDown)")
                    print("📧 Using userEmail: '\(userEmail)' (isEmpty: \(userEmail.isEmpty))")
                    
                    // Get fresh email from UserDefaults if current one is empty
                    let emailToUse = userEmail.isEmpty ? (UserDefaults.standard.string(forKey: "userEmail") ?? "") : userEmail
                    print("📧 Final email to use: '\(emailToUse)' (isEmpty: \(emailToUse.isEmpty))")
                    
                    if emailToUse.isEmpty {
                        print("❌ No valid email found - cannot update flexibility preferences")
                        return
                    }
                    
                    Task {
                        NetworkManagerTwo.shared.updateFlexibilityPreferences(
                            email: emailToUse,
                            warmUpEnabled: warmUp,
                            coolDownEnabled: coolDown
                        ) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success:
                                    // Update the default flexibility preferences
                                    selectedFlexibilityPreferences = FlexibilityPreferences(warmUpEnabled: warmUp, coolDownEnabled: coolDown)
                                    print("✅ Updated selectedFlexibilityPreferences: warmUp=\(selectedFlexibilityPreferences.warmUpEnabled), coolDown=\(selectedFlexibilityPreferences.coolDownEnabled)")
                                    
                                    // Clear session flexibility preferences since it's now the default
                                    flexibilityPreferences = nil
                                    UserDefaults.standard.removeObject(forKey: sessionFlexibilityKey)
                                    showingFlexibilityPicker = false
                                    regenerateWorkoutWithNewDuration()
                                case .failure(let error):
                                    print("❌ Failed to update flexibility preferences: \(error)")
                                }
                            }
                        }
                    }
                },
                onSetForWorkout: { warmUp, coolDown in
                    // Apply to current workout session only
                    print("⚡ Setting session-only flexibility: Warm-Up \(warmUp), Cool-Down \(coolDown)")
                    let newPrefs = FlexibilityPreferences(warmUpEnabled: warmUp, coolDownEnabled: coolDown)
                    flexibilityPreferences = newPrefs
                    
                    // Save session flexibility preferences to UserDefaults for persistence
                    if let data = try? JSONEncoder().encode(newPrefs) {
                        UserDefaults.standard.set(data, forKey: sessionFlexibilityKey)
                    }
                    
                    showingFlexibilityPicker = false
                    regenerateWorkoutWithNewDuration()
                }
            )
        }
        .fullScreenCover(item: $currentWorkout) { workout in
            WorkoutInProgressView(
                isPresented: Binding(
                    get: { currentWorkout != nil },
                    set: { if !$0 { currentWorkout = nil } }
                ),
                workout: workout
            )
            .onAppear {
                print("📱 FullScreenCover appeared with \(workout.exercises.count) exercises, \(workout.warmUpExercises?.count ?? 0) warm-up, \(workout.coolDownExercises?.count ?? 0) cool-down")
            }
        }
    }
    
    private func regenerateWorkoutWithNewDuration() {
        // Show loading animation
        withAnimation(.easeInOut(duration: 0.3)) {
            isGeneratingWorkout = true
            generationMessage = loadingMessages.randomElement() ?? "Creating your workout..."
        }
        
        print("🔄 Regenerating workout with duration: \(effectiveDuration.minutes) minutes")
        shouldRegenerateWorkout = true
        
        // Reset the flag and hide loading after realistic generation time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            shouldRegenerateWorkout = false
            
            withAnimation(.easeInOut(duration: 0.3)) {
                isGeneratingWorkout = false
            }
        }
    }
    
    private func clearSessionDuration() {
        sessionDuration = nil
        UserDefaults.standard.removeObject(forKey: sessionDurationKey)
        UserDefaults.standard.removeObject(forKey: sessionDateKey)
        customTargetMuscles = nil
        UserDefaults.standard.removeObject(forKey: customMusclesKey)
        selectedMuscleType = "Recovered Muscles"
        UserDefaults.standard.removeObject(forKey: "currentWorkoutMuscleType")
        customEquipment = nil
        UserDefaults.standard.removeObject(forKey: "currentWorkoutCustomEquipment")
        let userProfile = UserProfileService.shared
        selectedEquipmentType = userProfile.workoutLocationDisplay
        UserDefaults.standard.removeObject(forKey: "currentWorkoutEquipmentType")
        sessionFitnessGoal = nil
        UserDefaults.standard.removeObject(forKey: sessionFitnessGoalKey)
        sessionFitnessLevel = nil
        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionFitnessLevel")
        print("🗑️ Cleared session duration, custom muscles, custom equipment, and fitness preferences")
    }
    
    // Static method to clear session duration from anywhere in the app
    static func clearWorkoutSessionDuration() {
        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionDuration")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionDate")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutCustomMuscles")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutMuscleType")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutCustomEquipment")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutEquipmentType")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionFitnessGoal")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionFitnessLevel")
        print("🗑️ Cleared workout session duration, custom muscles, custom equipment, and fitness preferences (static)")
    }
    
    private func updateServerWorkoutDuration(email: String, durationMinutes: Int) {
        print("🔄 Updating server workout duration: \(durationMinutes) minutes for \(email)")
        
        // Create update payload
        let updateData: [String: Any] = [
            "preferred_workout_duration": durationMinutes
        ]
        
        // Use NetworkManagerTwo to update workout preferences  
        NetworkManagerTwo.shared.updateWorkoutPreferences(
            email: email,
            workoutData: updateData
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Successfully updated workout duration on server")
                    
                    // Update DataLayer cache
                    Task {
                        let profileUpdate = ["preferred_workout_duration": durationMinutes]
                        await DataLayer.shared.updateProfileData(profileUpdate)
                    }
                    
                case .failure(let error):
                    print("❌ Failed to update workout duration on server: \(error.localizedDescription)")
                    // Note: We still keep the local change since UserDefaults was already updated
                }
            }
        }
    }
    
    private func updateServerFitnessGoal(email: String, fitnessGoal: FitnessGoal) {
        print("🔄 Updating server fitness goal: \(fitnessGoal.displayName) for \(email)")
        
        // Create update payload
        let updateData: [String: Any] = [
            "preferred_fitness_goal": fitnessGoal.rawValue
        ]
        
        // Use NetworkManagerTwo to update workout preferences  
        NetworkManagerTwo.shared.updateWorkoutPreferences(
            email: email,
            workoutData: updateData
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Successfully updated fitness goal on server")
                    
                    // Update DataLayer cache
                    Task {
                        let profileUpdate = ["preferred_fitness_goal": fitnessGoal.rawValue]
                        await DataLayer.shared.updateProfileData(profileUpdate)
                    }
                    
                case .failure(let error):
                    print("❌ Failed to update fitness goal on server: \(error.localizedDescription)")
                    // Note: We still keep the local change since UserDefaults was already updated
                }
            }
        }
    }
    
    private func updateServerFitnessLevel(email: String, fitnessLevel: ExperienceLevel) {
        print("🔄 Updating server fitness level: \(fitnessLevel.displayName) for \(email)")
        
        // Create update payload
        let updateData: [String: Any] = [
            "experience_level": fitnessLevel.rawValue
        ]
        
        // Use NetworkManagerTwo to update workout preferences  
        NetworkManagerTwo.shared.updateWorkoutPreferences(
            email: email,
            workoutData: updateData
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Successfully updated fitness level on server")
                    
                    // Update DataLayer cache
                    Task {
                        let profileUpdate = ["experience_level": fitnessLevel.rawValue]
                        await DataLayer.shared.updateProfileData(profileUpdate)
                    }
                    
                case .failure(let error):
                    print("❌ Failed to update fitness level on server: \(error.localizedDescription)")
                    // Note: We still keep the local change since UserDefaults was already updated
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var tabHeaderView: some View {
        VStack(spacing: 0) {
            // Tab buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(workoutTabs, id: \.self) { tab in
                        TabButton(tab: tab, selectedTab: $selectedWorkoutTab)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 16)
            
            // Workout controls (only show for Today tab)
            if selectedWorkoutTab == .today {
                workoutControlsInHeader
                    .padding(.bottom, 12)
            }
        }
    }
    
    private var workoutControlsInHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // X button to reset all session options (only show when any session option is set) - positioned first
                if hasSessionModifications {
                    Button(action: {
                        // Reset to default duration
                        sessionDuration = nil
                        UserDefaults.standard.removeObject(forKey: sessionDurationKey)
                        UserDefaults.standard.removeObject(forKey: sessionDateKey)
                        
                        // Reset to default muscle type
                        customTargetMuscles = nil
                        UserDefaults.standard.removeObject(forKey: customMusclesKey)
                        selectedMuscleType = "Recovered Muscles"
                        UserDefaults.standard.removeObject(forKey: "currentWorkoutMuscleType")
                        
                        // Reset to default equipment
                        customEquipment = nil
                        UserDefaults.standard.removeObject(forKey: "currentWorkoutCustomEquipment")
                        let userProfile = UserProfileService.shared
                        selectedEquipmentType = userProfile.workoutLocationDisplay
                        UserDefaults.standard.removeObject(forKey: "currentWorkoutEquipmentType")
                        
                        // Reset to default fitness goal
                        sessionFitnessGoal = nil
                        UserDefaults.standard.removeObject(forKey: sessionFitnessGoalKey)
                        
                        // Reset to default fitness level
                        sessionFitnessLevel = nil
                        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionFitnessLevel")
                        
                        // Reset to default flexibility preferences
                        clearSessionFlexibilityPreferences()
                        
                        regenerateWorkoutWithNewDuration()
                        print("🔄 Reset to default duration, muscle type, equipment, fitness goal, and flexibility")
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemBackground))
                            .cornerRadius(17.5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 17.5)
                                    .stroke(Color.primary, lineWidth: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 17.5)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Dynamically ordered buttons - modified buttons appear first, then unmodified
                ForEach(orderedButtons, id: \.self) { button in
                    buttonView(for: button)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 2) // Add vertical padding to prevent border cutoff
        }
    }
    
    // MARK: - Button Ordering Logic
    
    private enum WorkoutButton: CaseIterable {
        case duration, muscles, equipment, fitnessGoal, fitnessLevel, flexibility
    }
    
    private func isButtonModified(_ button: WorkoutButton) -> Bool {
        switch button {
        case .duration:
            return sessionDuration != nil
        case .muscles:
            return customTargetMuscles != nil
        case .equipment:
            return customEquipment != nil
        case .fitnessGoal:
            return sessionFitnessGoal != nil
        case .fitnessLevel:
            return sessionFitnessLevel != nil
        case .flexibility:
            return flexibilityPreferences != nil && flexibilityPreferences!.isEnabled
        }
    }
    
    private var orderedButtons: [WorkoutButton] {
        let modifiedButtons = WorkoutButton.allCases.filter { isButtonModified($0) }
        let unmodifiedButtons = WorkoutButton.allCases.filter { !isButtonModified($0) }
        return modifiedButtons + unmodifiedButtons
    }
    
    @ViewBuilder
    private func buttonView(for button: WorkoutButton) -> some View {
        switch button {
        case .duration:
            durationButton
        case .muscles:
            musclesButton
        case .equipment:
            equipmentButton
        case .fitnessGoal:
            fitnessGoalButton
        case .fitnessLevel:
            fitnessLevelButton
        case .flexibility:
            flexibilityButton
        }
    }
    
    // MARK: - Individual Button Views
    
    private var durationButton: some View {
        Button(action: {
            showingDurationPicker = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(effectiveDuration.displayValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(sessionDuration != nil ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                sessionDuration != nil ? 
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.05)) : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var musclesButton: some View {
        Button(action: {
            showingTargetMusclesPicker = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "figure.mixed.cardio")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(selectedMuscleType)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(customTargetMuscles != nil ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                customTargetMuscles != nil ? 
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.05)) : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var equipmentButton: some View {
        Button(action: {
            showingEquipmentPicker = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text("Equipment")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(customEquipment != nil ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                customEquipment != nil ? 
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.05)) : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var fitnessGoalButton: some View {
        Button(action: {
            showingFitnessGoalPicker = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(effectiveFitnessGoal.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(sessionFitnessGoal != nil ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                sessionFitnessGoal != nil ? 
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.05)) : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var fitnessLevelButton: some View {
        Button(action: {
            showingFitnessLevelPicker = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "aqi.medium")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(selectedFitnessLevel.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(sessionFitnessLevel != nil ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                sessionFitnessLevel != nil ? 
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.05)) : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var flexibilityButton: some View {
        Button(action: {
            showingFlexibilityPicker = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: effectiveFlexibilityPreferences.showPlusIcon ? "plus" : "figure.flexibility")
                    .font(.system(size: effectiveFlexibilityPreferences.showPlusIcon ? 20 : 17, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(flexibilityPreferences?.shortText ?? effectiveFlexibilityPreferences.shortText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke((flexibilityPreferences != nil && flexibilityPreferences!.isEnabled) ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                (flexibilityPreferences != nil && flexibilityPreferences!.isEnabled) ? 
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.primary.opacity(0.05)) : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var mainContentView: some View {
        Group {
            switch selectedWorkoutTab {
            case .today:
                if isGeneratingWorkout {
                    ModernWorkoutLoadingView(message: generationMessage)
                        .transition(.opacity.combined(with: .scale))
                        .id("loading") // Force view refresh
                } else {
                    TodayWorkoutView(
                        searchText: searchText,
                        navigationPath: $navigationPath,
                        workoutManager: workoutManager,
                        userEmail: userEmail,
                        selectedDuration: effectiveDuration,
                        shouldRegenerate: $shouldRegenerateWorkout,
                        customTargetMuscles: customTargetMuscles,
                        customEquipment: customEquipment,
                        effectiveFitnessGoal: effectiveFitnessGoal,
                        effectiveFitnessLevel: sessionFitnessLevel ?? selectedFitnessLevel,
                        onExerciseReplacementCallbackSet: onExerciseReplacementCallbackSet,
                        onExerciseUpdateCallbackSet: onExerciseUpdateCallbackSet,
                        currentWorkout: $currentWorkout,
                        effectiveFlexibilityPreferences: effectiveFlexibilityPreferences
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            case .workouts:
                RoutinesWorkoutView(
                    searchText: searchText,
                    navigationPath: $navigationPath,
                    workoutManager: workoutManager,
                    userEmail: userEmail
                )
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    selectedTab = 0
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    // MARK: - Flexibility Preferences Methods
    
    private func loadSessionFlexibilityPreferences() {
        if let data = UserDefaults.standard.data(forKey: sessionFlexibilityKey),
           let preferences = try? JSONDecoder().decode(FlexibilityPreferences.self, from: data) {
            flexibilityPreferences = preferences
        }
    }
    
    private func clearSessionFlexibilityPreferences() {
        flexibilityPreferences = nil
        UserDefaults.standard.removeObject(forKey: sessionFlexibilityKey)
    }
}

// MARK: - Tab Button

private struct TabButton: View {
    let tab: LogWorkoutView.WorkoutTab
    @Binding var selectedTab: LogWorkoutView.WorkoutTab
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                selectedTab = tab
            }
        }) {
            Text(tab.title)
                .font(.system(size: 15))
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selectedTab == tab ? Color("tiktoknp") : Color.clear)
                )
                .foregroundColor(selectedTab == tab ? .primary : Color.gray.opacity(0.8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Today Workout View

private struct TodayWorkoutView: View {
    let searchText: String
    @Binding var navigationPath: NavigationPath
    @ObservedObject var workoutManager: WorkoutManager
    let userEmail: String
    let selectedDuration: WorkoutDuration  // Keep as let since we'll handle changes differently
    @Binding var shouldRegenerate: Bool
    let customTargetMuscles: [String]? // Added this parameter
    let customEquipment: [Equipment]? // Added this parameter
    let effectiveFitnessGoal: FitnessGoal // Added this parameter
    let effectiveFitnessLevel: ExperienceLevel // Added this parameter
    let onExerciseReplacementCallbackSet: (((Int, ExerciseData) -> Void)?) -> Void
    let onExerciseUpdateCallbackSet: (((Int, TodayWorkoutExercise) -> Void)?) -> Void
    @Binding var currentWorkout: TodayWorkout?
    let effectiveFlexibilityPreferences: FlexibilityPreferences // Added this parameter
    
    @State private var todayWorkout: TodayWorkout?
    @State private var isGeneratingWorkout = false
    @State private var userProfile = UserProfileService.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Main scrollable content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Add invisible spacing at the top to prevent overlap with header
                        Color.clear.frame(height: 4)
                        
                        // Show generation loading
                        if isGeneratingWorkout {
                            WorkoutGenerationCard()
                                .padding(.horizontal)
                                .transition(.opacity)
                        }
                        
                        // Show today's workout if available
                        if let workout = todayWorkout {
                            VStack(spacing: 4) {
                                TodayWorkoutExerciseList(
                                    workout: workout,
                                    navigationPath: $navigationPath,
                                    onExerciseReplacementCallbackSet: onExerciseReplacementCallbackSet,
                                    onExerciseUpdateCallbackSet: onExerciseUpdateCallbackSet
                                )
                                .padding(.horizontal)
                                
                                // Add Exercise button below the list
                                Button(action: {
                                    // TODO: Navigate to add exercise view
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Add Exercise")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Empty state when no workout and not generating
                        if todayWorkout == nil && !isGeneratingWorkout {
                            VStack(spacing: 16) {
                                Image("blackex")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 200, maxHeight: 200)
                                
                                Text("Preparing your workout...")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("We're creating a personalized workout based on your goals and preferences.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 45)
                            }
                            .padding(.top, 40)
                        }
                        
                        // Add extra bottom padding for floating buttons
                        Color.clear.frame(height: 120)
                    }
                    .padding(.bottom, 16)
                }
                .background(Color(.systemBackground))
                
                // Sticky Start Workout button at bottom
                if let workout = todayWorkout {
                    VStack {
                        Button(action: {
                            print("🚀 Starting workout with \(workout.exercises.count) exercises")
                            for (index, exercise) in workout.exercises.enumerated() {
                                print("🚀 Exercise \(index): \(exercise.exercise.name)")
                            }
                            currentWorkout = workout
                        }) {
                            Text("Start Workout")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 10)
                    }
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color("iosbg2").opacity(0),
                                Color("iosbg2").opacity(0.95),
                                Color("iosbg2")
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .onAppear {
            loadOrGenerateTodayWorkout()
        }
        .onChange(of: shouldRegenerate) { _, newValue in
            if newValue {
                // Reset the flag and regenerate workout
                generateTodayWorkout()
                shouldRegenerate = false
            }
        }
        .onChange(of: selectedDuration) { _, newDuration in
            // Regenerate workout when duration changes (ensures fresh data)
            print("🔄 Duration changed to \(newDuration.minutes) minutes - regenerating workout")
            generateTodayWorkout()
        }
        .onChange(of: customTargetMuscles) { _, newMuscles in
            print("🎯 Custom muscles changed to: \(newMuscles?.description ?? "nil") - regenerating workout")
            generateTodayWorkout()
        }
        .onChange(of: effectiveFlexibilityPreferences) { _, newPreferences in
            print("🧘 Flexibility preferences changed to: warmUp=\(newPreferences.warmUpEnabled), coolDown=\(newPreferences.coolDownEnabled) - regenerating workout")
            generateTodayWorkout()
        }
        .onChange(of: customEquipment) { _, newEquipment in
            print("⚙️ Custom equipment changed to: \(newEquipment?.description ?? "nil") - regenerating workout") 
            generateTodayWorkout()
        }
        .onChange(of: effectiveFitnessGoal) { _, newGoal in
            print("🏋️ Fitness goal changed to: \(newGoal.displayName) - regenerating workout")
            generateTodayWorkout()
        }
        .onChange(of: effectiveFitnessLevel) { _, newLevel in
            print("📈 Fitness level changed to: \(newLevel.displayName) - regenerating workout")
            generateTodayWorkout()
        }
    }
    
    private func loadOrGenerateTodayWorkout() {
        // Check if we have a workout for today
        if let data = UserDefaults.standard.data(forKey: "todayWorkout_\(userEmail)"),
           let workout = try? JSONDecoder().decode(TodayWorkout.self, from: data) {
            
            // Check if the workout is from today
            if Calendar.current.isDateInToday(workout.date) {
                todayWorkout = workout
                return
            }
        }
        
        // No workout for today, generate one automatically
        generateTodayWorkout()
    }
    
    private func generateTodayWorkout() {
        isGeneratingWorkout = true
        
        // Simulate AI workout generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let generatedWorkout = createIntelligentWorkout()
            todayWorkout = generatedWorkout
            isGeneratingWorkout = false
            
            // Save today's workout
            saveTodayWorkout(generatedWorkout)
        }
    }
    
    private func createIntelligentWorkout() -> TodayWorkout {
        let recommendationService = WorkoutRecommendationService.shared
        
        // Get user's fitness goal and preferences - use effective fitness goal
        let fitnessGoal = effectiveFitnessGoal
        let experienceLevel = effectiveFitnessLevel
        
        // Use selected duration instead of user's available time
        let targetDuration = selectedDuration.minutes
        
        // Define muscle groups based on custom selection or recovery
        let muscleGroups: [String]
        if let customMuscles = customTargetMuscles, !customMuscles.isEmpty {
            // Use custom muscle selection
            muscleGroups = customMuscles
            print("🎯 Using custom muscle selection: \(muscleGroups)")
        } else {
            // Get recovery-optimized muscle groups
            let recoveryOptimizedMuscles = recommendationService.getRecoveryOptimizedWorkout(targetMuscleCount: 4)
            
            if recoveryOptimizedMuscles.count >= 3 {
                // Use recovery-optimized selection
                muscleGroups = recoveryOptimizedMuscles
                print("🧠 Using recovery-optimized muscles: \(muscleGroups)")
            } else {
                // Fallback to goal-based selection
                switch fitnessGoal {
                case .strength, .powerlifting:
                    muscleGroups = ["Chest", "Back", "Shoulders", "Quadriceps", "Glutes"]
                case .hypertrophy:
                    muscleGroups = ["Chest", "Back", "Shoulders", "Biceps", "Triceps"]
                case .endurance:
                    muscleGroups = ["Chest", "Back", "Quadriceps", "Abs"]
                default:
                    muscleGroups = ["Chest", "Back", "Shoulders", "Quadriceps"]
                }
                print("⚠️ Using fallback muscle groups: \(muscleGroups)")
            }
        }
        
        // Calculate workout parameters based on goal
        let workoutParams = getWorkoutParameters(for: fitnessGoal, experienceLevel: experienceLevel)
        
        // Calculate optimal exercises and sets to fit target duration
        let workoutPlan = calculateOptimalWorkout(
            targetDurationMinutes: targetDuration,
            muscleGroups: muscleGroups,
            parameters: workoutParams,
            recommendationService: recommendationService,
            customEquipment: customEquipment,
            flexibilityPreferences: effectiveFlexibilityPreferences
        )
        
        // Create dynamic title based on selected muscles
        let workoutTitle = muscleGroups.count >= 2 ? 
            "\(muscleGroups.prefix(2).joined(separator: " & ")) Focus" : 
            getWorkoutTitle(for: fitnessGoal)
        
        // Generate warm-up exercises if enabled
        print("🔍 Creating workout with flexibility preferences: warmUp=\(effectiveFlexibilityPreferences.warmUpEnabled), coolDown=\(effectiveFlexibilityPreferences.coolDownEnabled)")
        
        let warmUpExercises: [TodayWorkoutExercise]?
        if effectiveFlexibilityPreferences.warmUpEnabled {
            let warmUpResult = recommendationService.getWarmUpExercises(targetMuscles: muscleGroups, customEquipment: customEquipment, count: 3)
            warmUpExercises = warmUpResult
            print("🔥 Warm-up generation: requested=true, received=\(warmUpResult.count) exercises")
        } else {
            warmUpExercises = nil
            print("🔥 Warm-up generation: requested=false")
        }
        
        // Generate cool-down exercises if enabled
        let coolDownExercises: [TodayWorkoutExercise]?
        if effectiveFlexibilityPreferences.coolDownEnabled {
            let coolDownResult = recommendationService.getCoolDownExercises(targetMuscles: muscleGroups, customEquipment: customEquipment, count: 3)
            coolDownExercises = coolDownResult
            print("🧊 Cool-down generation: requested=true, received=\(coolDownResult.count) exercises")
        } else {
            coolDownExercises = nil
            print("🧊 Cool-down generation: requested=false")
        }
            
        print("🏋️ Generated warm-up exercises: \(warmUpExercises?.count ?? 0), cool-down exercises: \(coolDownExercises?.count ?? 0)")
        
        return TodayWorkout(
            id: UUID(),
            date: Date(),
            title: workoutTitle,
            exercises: workoutPlan.exercises,
            estimatedDuration: workoutPlan.actualDurationMinutes,
            fitnessGoal: fitnessGoal,
            difficulty: experienceLevel.workoutComplexity,
            warmUpExercises: warmUpExercises,
            coolDownExercises: coolDownExercises
        )
    }
    
    private func getWorkoutParameters(for goal: FitnessGoal, experienceLevel: ExperienceLevel) -> WorkoutParameters {
        let baseParams: WorkoutParameters
        
        switch goal {
        case .strength:
            baseParams = WorkoutParameters(
                percentageOneRM: 80...90,
                repRange: 1...6,
                repDurationSeconds: 4...6,
                setsPerExercise: 4...6,
                restBetweenSetsSeconds: 90...120,  // Fixed: Time-efficient strength training (1.5-2 min)
                compoundSetupSeconds: 20,
                isolationSetupSeconds: 7,
                transitionSeconds: 20
            )
            
        case .hypertrophy:
            baseParams = WorkoutParameters(
                percentageOneRM: 60...80,
                repRange: 6...12,
                repDurationSeconds: 2...8,
                setsPerExercise: 3...5,
                restBetweenSetsSeconds: 30...90,
                compoundSetupSeconds: 20,
                isolationSetupSeconds: 7,
                transitionSeconds: 15
            )
            
        case .tone:
            baseParams = WorkoutParameters(
                percentageOneRM: 50...70,
                repRange: 12...15,
                repDurationSeconds: 2...4,
                setsPerExercise: 2...4,
                restBetweenSetsSeconds: 45...60,
                compoundSetupSeconds: 15,
                isolationSetupSeconds: 7,
                transitionSeconds: 15
            )
            
        case .endurance:
            baseParams = WorkoutParameters(
                percentageOneRM: 40...60,
                repRange: 15...25,
                repDurationSeconds: 2...4,
                setsPerExercise: 2...4,
                restBetweenSetsSeconds: 20...45,
                compoundSetupSeconds: 15,
                isolationSetupSeconds: 7,
                transitionSeconds: 10
            )
            
        case .powerlifting:
            baseParams = WorkoutParameters(
                percentageOneRM: 85...100,
                repRange: 1...3,
                repDurationSeconds: 4...6,
                setsPerExercise: 3...6,
                restBetweenSetsSeconds: 120...180,  // Fixed: App-friendly powerlifting rest (2-3 min)
                compoundSetupSeconds: 25,
                isolationSetupSeconds: 7,
                transitionSeconds: 25
            )
            
        default:
            // General fitness fallback
            baseParams = WorkoutParameters(
                percentageOneRM: 60...75,
                repRange: 8...12,
                repDurationSeconds: 2...4,
                setsPerExercise: 3...4,
                restBetweenSetsSeconds: 60...90,
                compoundSetupSeconds: 20,
                isolationSetupSeconds: 7,
                transitionSeconds: 15
            )
        }
        
        // Adjust parameters based on experience level
        return adjustParametersForExperienceLevel(baseParams, experienceLevel: experienceLevel)
    }
    
    private func adjustParametersForExperienceLevel(_ params: WorkoutParameters, experienceLevel: ExperienceLevel) -> WorkoutParameters {
        switch experienceLevel {
        case .beginner:
            // Beginners: Lower intensity, fewer sets, minimal additional rest
            return WorkoutParameters(
                percentageOneRM: adjustRange(params.percentageOneRM, by: -10...(-5)),
                repRange: adjustRange(params.repRange, by: 2...4),
                repDurationSeconds: params.repDurationSeconds,
                setsPerExercise: adjustRange(params.setsPerExercise, by: -1...0),
                restBetweenSetsSeconds: adjustRange(params.restBetweenSetsSeconds, by: 0...10),  // Reduced from 15...30 to 0...10
                compoundSetupSeconds: params.compoundSetupSeconds + 10,
                isolationSetupSeconds: params.isolationSetupSeconds + 5,
                transitionSeconds: params.transitionSeconds + 10
            )
            
        case .intermediate:
            // Intermediate: Base parameters (no adjustment)
            return params
            
        case .advanced:
            // Advanced: Maximum intensity, more sets, shorter rest
            return WorkoutParameters(
                percentageOneRM: adjustRange(params.percentageOneRM, by: 5...15),
                repRange: adjustRange(params.repRange, by: -3...(-1)),
                repDurationSeconds: params.repDurationSeconds,
                setsPerExercise: adjustRange(params.setsPerExercise, by: 0...2),
                restBetweenSetsSeconds: adjustRange(params.restBetweenSetsSeconds, by: -20...(-10)),
                compoundSetupSeconds: params.compoundSetupSeconds,
                isolationSetupSeconds: params.isolationSetupSeconds,
                transitionSeconds: max(5, params.transitionSeconds - 5)
            )
        }
    }
    
    private func adjustRange(_ range: ClosedRange<Int>, by adjustment: ClosedRange<Int>) -> ClosedRange<Int> {
        let newLower = max(1, range.lowerBound + adjustment.lowerBound)
        let newUpper = max(newLower, range.upperBound + adjustment.upperBound)
        return newLower...newUpper
    }
    
    private func calculateOptimalWorkout(
        targetDurationMinutes: Int,
        muscleGroups: [String],
        parameters: WorkoutParameters,
        recommendationService: WorkoutRecommendationService,
        customEquipment: [Equipment]?,
        flexibilityPreferences: FlexibilityPreferences
    ) -> WorkoutPlan {
        
        let targetDurationSeconds = targetDurationMinutes * 60
        
        // Calculate warmup and cooldown based on workout duration
        let warmupSeconds = getWarmupDuration(for: targetDurationMinutes)
        let cooldownSeconds = warmupSeconds // Same as warmup
        
        // Available time for exercises (without warmup/cooldown)
        let availableExerciseTime = targetDurationSeconds - warmupSeconds - cooldownSeconds
        
        var exercises: [TodayWorkoutExercise] = []
        var totalExerciseTime = 0
        
        // Calculate target exercise count based on workout duration and fitness goal
        let targetExercisesPerMuscle = getTargetExercisesPerMuscle(
            availableExerciseTimeMinutes: availableExerciseTime / 60,
            muscleGroupCount: muscleGroups.count,
            parameters: parameters
        )
        
        // Start near the target and adjust up/down as needed
        var exercisesPerMuscle = max(1, targetExercisesPerMuscle)
        let maxExercisesPerMuscle = 4
        
        while exercisesPerMuscle <= maxExercisesPerMuscle {
            let testExercises = generateExercises(
                muscleGroups: muscleGroups,
                exercisesPerMuscle: exercisesPerMuscle,
                parameters: parameters,
                recommendationService: recommendationService,
                customEquipment: customEquipment,
                availableTimeMinutes: availableExerciseTime / 60
            )
            
            let testTime = calculateTotalExerciseTime(exercises: testExercises, parameters: parameters)
            
            // Add small buffer for real-world variability (reduced from 12.5% to 7.5%)
            let bufferedTime = Int(Double(testTime) * 1.075)
            
            print("🔍 Testing \(exercisesPerMuscle) per muscle: \(testExercises.count) exercises, \(testTime)s (\(testTime/60)min) + buffer = \(bufferedTime)s vs \(availableExerciseTime)s available")
            
            if bufferedTime <= availableExerciseTime {
                exercises = testExercises
                totalExerciseTime = testTime
                exercisesPerMuscle += 1
            } else {
                print("💥 Hit time limit at \(exercisesPerMuscle) per muscle - stopping")
                break
            }
        }
        
        // If no exercises fit, try with minimal sets
        if exercises.isEmpty {
            exercises = generateMinimalExercises(
                muscleGroups: muscleGroups,
                parameters: parameters,
                recommendationService: recommendationService,
                customEquipment: customEquipment,
                availableTimeMinutes: availableExerciseTime / 60
            )
            totalExerciseTime = calculateTotalExerciseTime(exercises: exercises, parameters: parameters)
        }
        
        let bufferSeconds = Int(Double(totalExerciseTime) * 0.05) // Reduced final buffer to 5%
        let actualTotalSeconds = warmupSeconds + totalExerciseTime + cooldownSeconds + bufferSeconds
        let actualDurationMinutes = (actualTotalSeconds + 59) / 60 // Round up
        
        let breakdown = WorkoutTimeBreakdown(
            warmupSeconds: warmupSeconds,
            exerciseTimeSeconds: totalExerciseTime,
            cooldownSeconds: cooldownSeconds,
            bufferSeconds: bufferSeconds,
            totalSeconds: actualTotalSeconds
        )
        
        print("🎯 Workout Plan Generated:")
        print("   Target: \(targetDurationMinutes)m, Actual: \(actualDurationMinutes)m")
        print("   Exercises: \(exercises.count) (\(exercisesPerMuscle-1) per muscle)")
        print("   Breakdown: \(warmupSeconds/60)m warmup + \(totalExerciseTime/60)m exercises + \(cooldownSeconds/60)m cooldown + \(bufferSeconds)s buffer")
        
        return WorkoutPlan(
            exercises: exercises,
            actualDurationMinutes: actualDurationMinutes,
            totalTimeBreakdown: breakdown
        )
    }
    
    private func getTargetExercisesPerMuscle(availableExerciseTimeMinutes: Int, muscleGroupCount: Int, parameters: WorkoutParameters) -> Int {
        // Use realistic time-efficient calculations instead of raw parameter ranges
        let avgSetsPerExercise = (parameters.setsPerExercise.lowerBound + parameters.setsPerExercise.upperBound) / 2
        let avgRepsPerSet = (parameters.repRange.lowerBound + parameters.repRange.upperBound) / 2
        let avgRepDuration = (parameters.repDurationSeconds.lowerBound + parameters.repDurationSeconds.upperBound) / 2
        
        // Use optimized rest times instead of parameter ranges (time-efficient approach)
        let restRange = parameters.restBetweenSetsSeconds
        let rangeSpan = restRange.upperBound - restRange.lowerBound
        let efficientRestTime = restRange.lowerBound + Int(Double(rangeSpan) * 0.5) // Use middle of range for estimation
        
        // Apply time scaling for constrained workouts (60min and below)
        let scaledRestTime = availableExerciseTimeMinutes <= 46 ? 
            max(restRange.lowerBound, Int(Double(efficientRestTime) * 0.85)) : efficientRestTime
        
        // Estimate time per exercise in minutes
        let workingTimePerExercise = Double(avgSetsPerExercise * avgRepsPerSet * avgRepDuration) / 60.0 // minutes
        let restTimePerExercise = Double((avgSetsPerExercise - 1) * scaledRestTime) / 60.0 // minutes  
        let setupTransitionTime = Double(parameters.compoundSetupSeconds + parameters.transitionSeconds) / 60.0 // minutes
        let totalTimePerExercise = workingTimePerExercise + restTimePerExercise + setupTransitionTime
        
        // Calculate target total exercises with proper floating-point division
        let targetTotalExercises = max(4, min(12, Int(Double(availableExerciseTimeMinutes) / max(1.0, totalTimePerExercise))))
        
        // Distribute across muscle groups (aim for 6-10 exercises for 60min workout)
        let targetPerMuscle = max(1, Int(ceil(Double(targetTotalExercises) / Double(max(1, muscleGroupCount)))))
        
        print("🎯 Target calculation: \(availableExerciseTimeMinutes)min ÷ \(String(format: "%.1f", totalTimePerExercise))min = \(targetTotalExercises) total, \(targetPerMuscle) per muscle")
        
        return min(4, targetPerMuscle) // Cap at 4 per muscle group
    }
    
    private func getWarmupDuration(for workoutMinutes: Int) -> Int {
        switch workoutMinutes {
        case 0..<30:   return 180  // 3 minutes for short workouts
        case 30..<60:  return 300  // 5 minutes for medium workouts
        case 60..<90:  return 420  // 7 minutes for hour-long workouts
        default:       return 600  // 10 minutes for long workouts
        }
    }
    
    private func generateExercises(
        muscleGroups: [String],
        exercisesPerMuscle: Int,
        parameters: WorkoutParameters,
        recommendationService: WorkoutRecommendationService,
        customEquipment: [Equipment]?,
        availableTimeMinutes: Int? = nil
    ) -> [TodayWorkoutExercise] {
        
        var exercises: [TodayWorkoutExercise] = []
        
        for muscleGroup in muscleGroups.prefix(4) { // Limit to 4 muscle groups
            let recommendedExercises = recommendationService.getRecommendedExercises(
                for: muscleGroup, 
                count: exercisesPerMuscle,
                customEquipment: customEquipment,
                flexibilityPreferences: effectiveFlexibilityPreferences
            )
            
            for exercise in recommendedExercises {
                let sets = parameters.setsPerExercise.lowerBound + (exercisesPerMuscle > 2 ? 1 : 0)
                let reps = getOptimalReps(for: exercise, parameters: parameters)
                let restTime = getOptimalRestTime(for: exercise, parameters: parameters, availableTimeMinutes: availableTimeMinutes)
                
                exercises.append(TodayWorkoutExercise(
                    exercise: exercise,
                    sets: min(sets, parameters.setsPerExercise.upperBound),
                    reps: reps,
                    weight: nil, // Will be determined during workout
                    restTime: restTime
                ))
            }
        }
        
        return exercises
    }
    
    private func generateMinimalExercises(
        muscleGroups: [String],
        parameters: WorkoutParameters,
        recommendationService: WorkoutRecommendationService,
        customEquipment: [Equipment]?,
        availableTimeMinutes: Int? = nil
    ) -> [TodayWorkoutExercise] {
        
        var exercises: [TodayWorkoutExercise] = []
        
        // Generate 1 compound exercise per muscle group with minimal sets
        for muscleGroup in muscleGroups.prefix(3) { // Limit to 3 muscle groups for time
            let recommendedExercises = recommendationService.getRecommendedExercises(
                for: muscleGroup, 
                count: 1,
                customEquipment: customEquipment,
                flexibilityPreferences: effectiveFlexibilityPreferences
            )
            
            if let exercise = recommendedExercises.first {
                exercises.append(TodayWorkoutExercise(
                    exercise: exercise,
                    sets: parameters.setsPerExercise.lowerBound,
                    reps: parameters.repRange.lowerBound + 2,
                    weight: nil,
                    restTime: parameters.restBetweenSetsSeconds.lowerBound
                ))
            }
        }
        
        return exercises
    }
    
    private func calculateTotalExerciseTime(exercises: [TodayWorkoutExercise], parameters: WorkoutParameters) -> Int {
        var totalTime = 0
        
        for (index, exercise) in exercises.enumerated() {
            // SingleExerciseTime = (Reps × Sets × RepDurationSec) + ((Sets - 1) × RestBetweenSetsSec) + SetupTimeSec + TransitionTimeSec
            
            let repDuration = parameters.repDurationSeconds.lowerBound + 1 // Use middle of range
            let workingTime = exercise.reps * exercise.sets * repDuration
            let restTime = (exercise.sets - 1) * exercise.restTime
            let setupTime = isCompoundExercise(exercise.exercise) ? 
                parameters.compoundSetupSeconds : parameters.isolationSetupSeconds
            let transitionTime = (index < exercises.count - 1) ? parameters.transitionSeconds : 0
            
            let exerciseTime = workingTime + restTime + setupTime + transitionTime
            totalTime += exerciseTime
            
            print("   Exercise \(exercise.exercise.name): \(exerciseTime)s (\(workingTime)s work + \(restTime)s rest + \(setupTime)s setup + \(transitionTime)s transition)")
        }
        
        return totalTime
    }
    
    private func isCompoundExercise(_ exercise: ExerciseData) -> Bool {
        let compoundKeywords = ["squat", "deadlift", "press", "row", "pull", "clean", "snatch", "lunge"]
        let exerciseName = exercise.name.lowercased()
        
        return compoundKeywords.contains { keyword in
            exerciseName.contains(keyword)
        }
    }
    
    private func getOptimalReps(for exercise: ExerciseData, parameters: WorkoutParameters) -> Int {
        // Use conventional rep counts that athletes actually use
        let conventionalReps = getConventionalRepCount(for: parameters.repRange, exercise: exercise)
        return conventionalReps
    }
    
    private func getConventionalRepCount(for range: ClosedRange<Int>, exercise: ExerciseData) -> Int {
        let isCompound = isCompoundExercise(exercise)
        
        // SCIENCE-BACKED conventional rep counts - based on systematic review of 39 studies
        // Athletes and coaches use these specific numbers (NOT mathematical averages like 9, 14, 21)
        switch range {
        case 1...6:  // Strength/Powerlifting - Research shows 3, 4, 5 reps most common
            return isCompound ? [3, 4, 5].randomElement()! : [4, 5, 6].randomElement()!
            
        case 6...12: // Hypertrophy - Schoenfeld studies consistently use 6, 8, 10, 12
            return isCompound ? [6, 8].randomElement()! : [8, 10, 12].randomElement()!
            
        case 12...15: // Tone/Definition - Standard practice: 12 or 15 (never 13, 14)
            return [12, 15].randomElement()!
            
        case 15...25: // Endurance - Research patterns: 15, 20, 25 (not odd numbers)
            return [15, 20, 25].randomElement()!
            
        default:
            // Fallback for custom ranges - find nearest conventional number
            return findNearestConventionalRep(in: range)
        }
    }
    
    private func findNearestConventionalRep(in range: ClosedRange<Int>) -> Int {
        // Evidence-based conventional rep counts from strength training research
        // These numbers are used by athletes, coaches, and cited in scientific literature
        let conventionalReps = [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30]
        
        // Find conventional reps that fall within our range
        let validReps = conventionalReps.filter { range.contains($0) }
        
        if !validReps.isEmpty {
            // Pick randomly from valid conventional options (not mathematical middle)
            return validReps.randomElement()!
        }
        
        // If no conventional reps fit exactly, find the closest conventional number
        let midRange = (range.lowerBound + range.upperBound) / 2
        let closest = conventionalReps.min { abs($0 - midRange) < abs($1 - midRange) } ?? midRange
        
        // Ensure it's within our range, adjust if needed
        return max(range.lowerBound, min(range.upperBound, closest))
    }
    
    private func getOptimalRestTime(for exercise: ExerciseData, parameters: WorkoutParameters, availableTimeMinutes: Int? = nil) -> Int {
        // Use time-efficient rest periods that still maintain exercise effectiveness
        let isCompound = isCompoundExercise(exercise)
        let restRange = parameters.restBetweenSetsSeconds
        
        // Calculate efficient rest times (prioritize time efficiency for app workouts)
        let rangeSpan = restRange.upperBound - restRange.lowerBound
        var efficientMax = restRange.lowerBound + Int(Double(rangeSpan) * 0.50)  // Use middle of range for compounds
        var isolationMax = restRange.lowerBound + Int(Double(rangeSpan) * 0.25)  // Use lower quarter for isolations
        
        // Apply time scaling if workout duration is constrained
        if let availableMinutes = availableTimeMinutes {
            let scalingFactor = getRestTimeScalingFactor(availableTimeMinutes: availableMinutes)
            efficientMax = max(restRange.lowerBound, Int(Double(efficientMax) * scalingFactor))
            isolationMax = max(restRange.lowerBound, Int(Double(isolationMax) * scalingFactor))
        }
        
        let finalRestTime: Int
        if isCompound {
            // Compound exercises: Use efficient maximum
            finalRestTime = efficientMax
        } else {
            // Isolation exercises: Use lower quarter of range  
            finalRestTime = max(restRange.lowerBound, isolationMax)
        }
        
        print("🔍 Rest time for \(exercise.name): range=\(restRange), compound=\(isCompound), final=\(finalRestTime)s")
        return finalRestTime
    }
    
    private func getRestTimeScalingFactor(availableTimeMinutes: Int) -> Double {
        // Scale rest times down for shorter workouts to fit more exercises
        switch availableTimeMinutes {
        case 0..<35:    return 0.70  // 30% reduction for short workouts
        case 35..<50:   return 0.85  // 15% reduction for medium workouts  
        case 50..<65:   return 0.95  // 5% reduction for hour workouts
        default:        return 1.0   // No reduction for longer workouts
        }
    }
    
    private func getWorkoutTitle(for goal: FitnessGoal) -> String {
        switch goal {
        case .strength:
            return "Strength Training"
        case .hypertrophy:
            return "Muscle Building"
        case .endurance:
            return "Endurance Training"
        case .powerlifting:
            return "Powerlifting Session"
        default:
            return "Full Body Workout"
        }
    }
    

    
    private func saveTodayWorkout(_ workout: TodayWorkout) {
        if let data = try? JSONEncoder().encode(workout) {
            UserDefaults.standard.set(data, forKey: "todayWorkout_\(userEmail)")
        }
    }
}

// MARK: - Routines Workout View

private struct RoutinesWorkoutView: View {
    let searchText: String
    @Binding var navigationPath: NavigationPath
    @ObservedObject var workoutManager: WorkoutManager
    let userEmail: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Add invisible spacing at the top to prevent overlap with header
            Color.clear.frame(height: 4)
            
            // Show "blackex" image when no workouts exist
            if !workoutManager.hasWorkouts && !workoutManager.isLoadingWorkouts {
                VStack(spacing: 16) {
                    Image("blackex")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 250, maxHeight: 250)
                    
                    Text("Build your perfect workout")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Create routines, track progress, and stay consistent. Once you add workouts, they'll show up here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 45)
                }
                .padding(.top, 40)
            }

            // New Workout button
            Button(action: {
                print("Tapped New Workout")
                HapticFeedback.generate()
                navigationPath.append(WorkoutNavigationDestination.createWorkout)
            }) {
                HStack(spacing: 6) {
                    Spacer()
                    Text("New Workout")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundColor(Color("bg"))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(Color.primary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 142)
            .padding(.top, 10)
            
            // Show loading indicator when loading workouts
            if workoutManager.isLoadingWorkouts {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Loading workouts...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
            }
            
            // TODO: Show workout list when workouts exist
            if workoutManager.hasWorkouts {
                // This will be implemented later when we have workout data
                Text("Workouts will be displayed here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 40)
            }
            
            Spacer()
        }
        .padding(.bottom, 16)
        .background(Color("iosbg2"))
    }
}

// MARK: - Today Workout Exercise List

private struct TodayWorkoutExerciseList: View {
    let workout: TodayWorkout
    @Binding var navigationPath: NavigationPath
    let onExerciseReplacementCallbackSet: (((Int, ExerciseData) -> Void)?) -> Void
    let onExerciseUpdateCallbackSet: (((Int, TodayWorkoutExercise) -> Void)?) -> Void
    @State private var exercises: [TodayWorkoutExercise]
    @State private var warmUpExpanded: Bool = true
    @State private var coolDownExpanded: Bool = true
    
    init(workout: TodayWorkout, navigationPath: Binding<NavigationPath>, onExerciseReplacementCallbackSet: @escaping (((Int, ExerciseData) -> Void)?) -> Void, onExerciseUpdateCallbackSet: @escaping (((Int, TodayWorkoutExercise) -> Void)?) -> Void) {
        self.workout = workout
        self._navigationPath = navigationPath
        self.onExerciseReplacementCallbackSet = onExerciseReplacementCallbackSet
        self.onExerciseUpdateCallbackSet = onExerciseUpdateCallbackSet
        self._exercises = State(initialValue: workout.exercises)
    }
    
    var body: some View {
        List {
            // Warm-up section (if exercises exist)
            if let warmUpExercises = workout.warmUpExercises, !warmUpExercises.isEmpty {
                // Warm-Up Section Title
                Section {
                    Text("Warm-Up")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
                // Warm-up exercises
                ForEach(Array(warmUpExercises.enumerated()), id: \.element.exercise.id) { index, exercise in
                    ExerciseWorkoutCard(
                        exercise: exercise,
                        allExercises: warmUpExercises,
                        exerciseIndex: index,
                        onExerciseReplaced: { _, _ in 
                            // Warm-up exercises can't be replaced for now
                        },
                        navigationPath: $navigationPath
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                }
            }
            
            // Main exercises section title (only if warm-up or cool-down exists)
            if (workout.warmUpExercises?.isEmpty == false) || (workout.coolDownExercises?.isEmpty == false) {
                Section {
                    Text("Main Sets")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            
            // Main exercises section
            ForEach(Array(exercises.enumerated()), id: \.element.exercise.id) { index, exercise in
                ExerciseWorkoutCard(
                    exercise: exercise,
                    allExercises: exercises,
                    exerciseIndex: index,
                    onExerciseReplaced: { idx, newExercise in
                        replaceExercise(at: idx, with: newExercise)
                    },
                    navigationPath: $navigationPath
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
            }
            .onMove(perform: moveExercise)
            .onDelete(perform: deleteExercise)
            
            // Cool-down section (if exercises exist)
            if let coolDownExercises = workout.coolDownExercises, !coolDownExercises.isEmpty {
                // Cool-Down Section Title
                Section {
                    Text("Cool-Down")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
                // Cool-down exercises
                ForEach(Array(coolDownExercises.enumerated()), id: \.element.exercise.id) { index, exercise in
                    ExerciseWorkoutCard(
                        exercise: exercise,
                        allExercises: coolDownExercises,
                        exerciseIndex: index,
                        onExerciseReplaced: { _, _ in 
                            // Cool-down exercises can't be replaced for now
                        },
                        navigationPath: $navigationPath
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                }
            }
            
            // Add bottom spacer to prevent last exercise from being hidden by Add Exercise button
            Section {
                Color.clear.frame(height: 8)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .background(Color("bg"))
        .cornerRadius(12)
        .frame(height: calculateTotalHeight()) // Dynamic height calculation with all sections + bottom spacer
        .onAppear {
            // Register the exercise replacement callback with the navigation container
            onExerciseReplacementCallbackSet { index, newExercise in
                replaceExercise(at: index, with: newExercise)
            }
            // Also register the update callback for full exercise updates (with warm-up sets)
            onExerciseUpdateCallbackSet { index, updatedExercise in
                updateExercise(at: index, with: updatedExercise)
            }
        }
        .onChange(of: workout.exercises) { _, newExercises in
            // Update local exercises when workout changes (e.g., from muscle selection change)
            exercises = newExercises
        }
        .onChange(of: exercises) { _, newValue in
            // TODO: Save updated exercise order to UserDefaults or backend
        }
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }
    
    private func updateExercise(at index: Int, with updatedExercise: TodayWorkoutExercise) {
        guard index < exercises.count else { return }
        
        // Replace the exercise with the updated one (including warm-up sets and new set count)
        exercises[index] = updatedExercise
        
        // Save to UserDefaults if needed
        if let userEmail = UserDefaults.standard.string(forKey: "userEmail") {
            let updatedWorkout = TodayWorkout(
                id: workout.id,
                date: workout.date,
                title: workout.title,
                exercises: exercises,
                estimatedDuration: workout.estimatedDuration,
                fitnessGoal: workout.fitnessGoal,
                difficulty: workout.difficulty,
                warmUpExercises: workout.warmUpExercises,
                coolDownExercises: workout.coolDownExercises
            )
            
            if let encoded = try? JSONEncoder().encode(updatedWorkout) {
                UserDefaults.standard.set(encoded, forKey: "todayWorkout_\(userEmail)")
            }
        }
    }
    
    private func replaceExercise(at index: Int, with newExercise: ExerciseData) {
        guard index < exercises.count else { return }
        
        // Create a new TodayWorkoutExercise with the replaced exercise data
        let oldExercise = exercises[index]
        let replacedExercise = TodayWorkoutExercise(
            exercise: newExercise,
            sets: oldExercise.sets,
            reps: oldExercise.reps,
            weight: oldExercise.weight,
            restTime: oldExercise.restTime,
            notes: oldExercise.notes, // Preserve existing notes
            warmupSets: oldExercise.warmupSets // Preserve existing warm-up sets
        )
        
        exercises[index] = replacedExercise
        
        // Save to UserDefaults if needed
        if let userEmail = UserDefaults.standard.string(forKey: "userEmail") {
            let updatedWorkout = TodayWorkout(
                id: workout.id,
                date: workout.date,
                title: workout.title,
                exercises: exercises,
                estimatedDuration: workout.estimatedDuration,
                fitnessGoal: workout.fitnessGoal,
                difficulty: workout.difficulty,
                warmUpExercises: workout.warmUpExercises,
                coolDownExercises: workout.coolDownExercises
            )
            
            if let encoded = try? JSONEncoder().encode(updatedWorkout) {
                UserDefaults.standard.set(encoded, forKey: "todayWorkout_\(userEmail)")
            }
        }
    }
    
    // Calculate total height including all sections and spacing
    private func calculateTotalHeight() -> CGFloat {
        var totalHeight: CGFloat = 0
        
        // Warm-up section height (if exists)
        if let warmUpExercises = workout.warmUpExercises, !warmUpExercises.isEmpty {
            totalHeight += 60 // Title height with padding
            totalHeight += CGFloat(warmUpExercises.count * 96) // 96pt per exercise
        }
        
        // Main exercises section
        // Add title height if warm-up or cool-down exists
        if (workout.warmUpExercises?.isEmpty == false) || (workout.coolDownExercises?.isEmpty == false) {
            totalHeight += 60 // "Main Sets" title height with padding
        }
        totalHeight += CGFloat(exercises.count * 96) // 96pt per exercise
        
        // Cool-down section height (if exists)  
        if let coolDownExercises = workout.coolDownExercises, !coolDownExercises.isEmpty {
            totalHeight += 60 // Title height with padding
            totalHeight += CGFloat(coolDownExercises.count * 96) // 96pt per exercise
        }
        
        // Bottom spacer to prevent content from being hidden under Add Exercise button
        totalHeight += 8
        
        return totalHeight
    }
}

// MARK: - Exercise Workout Card

private struct ExerciseWorkoutCard: View {
    let exercise: TodayWorkoutExercise
    let allExercises: [TodayWorkoutExercise]
    let exerciseIndex: Int
    let onExerciseReplaced: (Int, ExerciseData) -> Void
    @Binding var navigationPath: NavigationPath
    @State private var recommendMoreOften = false
    @State private var recommendLessOften = false
    
    var body: some View {
        Button(action: {
            // Navigate to exercise logging view with index
            navigationPath.append(WorkoutNavigationDestination.logExercise(exercise, allExercises, exerciseIndex))
        }) {
            HStack(spacing: 12) {
                // Exercise thumbnail
                Group {
                    if let image = UIImage(named: thumbnailImageName) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "dumbbell")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            )
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.exercise.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    Text("\(exercise.sets) sets • \(exercise.reps) reps")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Menu button
                Menu {
                    Button("Exercise History") {
                        // TODO: Show exercise history
                    }
                    
                    Button("Replace") {
                        // TODO: Replace exercise
                    }
                    
                    Button("Recommend more often") {
                        recommendMoreOften.toggle()
                        // TODO: Save preference
                    }
                    
                    Button("Recommend less often") {
                        recommendLessOften.toggle()
                        // TODO: Save preference
                    }
                    
                    Divider()
                    
                    Button("Don't recommend again", role: .destructive) {
                        // TODO: Add to avoided exercises
                    }
                    
                    Button("Delete from workout", role: .destructive) {
                        // TODO: Remove from current workout
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color("tiktoknp"))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var thumbnailImageName: String {
        let imageId = String(format: "%04d", exercise.exercise.id)
        return imageId
    }
}

// MARK: - Workout Generation Card

private struct WorkoutGenerationCard: View {
    @State private var animateProgress = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Generating your workout...")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 12) {
                ProgressBarWorkout(width: animateProgress ? 0.9 : 0.3, delay: 0)
                ProgressBarWorkout(width: animateProgress ? 0.7 : 0.5, delay: 0.2)
                ProgressBarWorkout(width: animateProgress ? 0.8 : 0.4, delay: 0.4)
            }

            Text("Analyzing your goals and preferences...")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Reset animation state
        animateProgress = false
        
        // Animate with delay
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            animateProgress = true
        }
    }
}

// MARK: - Progress Bar

private struct ProgressBarWorkout: View {
    let width: CGFloat
    let delay: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * width, height: 4)
                    .cornerRadius(2)
            }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: 1.5).delay(delay).repeatForever(autoreverses: true), value: width)
    }
}

// MARK: - Data Models

struct TodayWorkout: Codable, Hashable, Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let exercises: [TodayWorkoutExercise]
    let estimatedDuration: Int
    let fitnessGoal: FitnessGoal
    let difficulty: Int
    let warmUpExercises: [TodayWorkoutExercise]?
    let coolDownExercises: [TodayWorkoutExercise]?
    
    // Convenience initializer for backward compatibility
    init(id: UUID = UUID(), date: Date = Date(), title: String, exercises: [TodayWorkoutExercise], estimatedDuration: Int, fitnessGoal: FitnessGoal, difficulty: Int, warmUpExercises: [TodayWorkoutExercise]? = nil, coolDownExercises: [TodayWorkoutExercise]? = nil) {
        self.id = id
        self.date = date
        self.title = title
        self.exercises = exercises
        self.estimatedDuration = estimatedDuration
        self.fitnessGoal = fitnessGoal
        self.difficulty = difficulty
        self.warmUpExercises = warmUpExercises
        self.coolDownExercises = coolDownExercises
    }
}

struct TodayWorkoutExercise: Codable, Hashable {
    let exercise: ExerciseData
    let sets: Int
    let reps: Int
    let weight: Double?
    let restTime: Int // in seconds
    let notes: String? // Exercise-specific notes
    let warmupSets: [WarmupSetData]? // Warm-up sets data for persistence
    
    // Convenience initializer for backward compatibility
    init(exercise: ExerciseData, sets: Int, reps: Int, weight: Double?, restTime: Int, notes: String? = nil, warmupSets: [WarmupSetData]? = nil) {
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.restTime = restTime
        self.notes = notes
        self.warmupSets = warmupSets
    }
}

// MARK: - Workout Parameters

struct WorkoutParameters {
    let percentageOneRM: ClosedRange<Int>  // e.g., 60...80
    let repRange: ClosedRange<Int>         // e.g., 6...12
    let repDurationSeconds: ClosedRange<Int> // e.g., 2...8
    let setsPerExercise: ClosedRange<Int>  // e.g., 3...5
    let restBetweenSetsSeconds: ClosedRange<Int> // e.g., 30...90
    let compoundSetupSeconds: Int          // Setup time for compound exercises
    let isolationSetupSeconds: Int         // Setup time for isolation exercises
    let transitionSeconds: Int             // Time between exercises
}

struct WorkoutPlan {
    let exercises: [TodayWorkoutExercise]
    let actualDurationMinutes: Int
    let totalTimeBreakdown: WorkoutTimeBreakdown
}

struct WorkoutTimeBreakdown {
    let warmupSeconds: Int
    let exerciseTimeSeconds: Int
    let cooldownSeconds: Int
    let bufferSeconds: Int
    let totalSeconds: Int
}

// MARK: - Workout Control Button Component

struct WorkoutControlButton: View {
    let title: String
    let value: String
    let onTap: () -> Void
    let icon: String? // Optional SF Symbol icon name
    
    // Convenience init for backward compatibility
    init(title: String, value: String, onTap: @escaping () -> Void) {
        self.title = title
        self.value = value
        self.onTap = onTap
        self.icon = nil
    }
    
    // Init with icon
    init(title: String, value: String, icon: String? = nil, onTap: @escaping () -> Void) {
        self.title = title
        self.value = value
        self.onTap = onTap
        self.icon = icon
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Leading icon if provided
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Workout Duration Enum

enum WorkoutDuration: String, CaseIterable {
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case fortyFiveMinutes = "45m"
    case oneHour = "1h"
    case oneAndHalfHours = "1.5h"
    case twoHours = "2h"
    
    var displayValue: String {
        return rawValue
    }
    
    var minutes: Int {
        switch self {
        case .fifteenMinutes: return 15
        case .thirtyMinutes: return 30
        case .fortyFiveMinutes: return 45
        case .oneHour: return 60
        case .oneAndHalfHours: return 90
        case .twoHours: return 120
        }
    }
    
    /// Create WorkoutDuration from minutes, choosing the closest match
    static func fromMinutes(_ minutes: Int) -> WorkoutDuration {
        switch minutes {
        case 0..<23: return .fifteenMinutes
        case 23..<38: return .thirtyMinutes
        case 38..<53: return .fortyFiveMinutes
        case 53..<75: return .oneHour
        case 75..<105: return .oneAndHalfHours
        default: return .twoHours
        }
    }
}

// MARK: - Workout Duration Picker View

struct WorkoutDurationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDuration: WorkoutDuration
    let onSetDefault: (WorkoutDuration) -> Void
    let onSetForWorkout: (WorkoutDuration) -> Void // Updated to pass the selected duration
    
    @State private var tempSelectedDuration: WorkoutDuration
    
    init(selectedDuration: Binding<WorkoutDuration>, onSetDefault: @escaping (WorkoutDuration) -> Void, onSetForWorkout: @escaping (WorkoutDuration) -> Void) {
        self._selectedDuration = selectedDuration
        self.onSetDefault = onSetDefault
        self.onSetForWorkout = onSetForWorkout
        self._tempSelectedDuration = State(initialValue: selectedDuration.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                      
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            Text("Duration")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            // Duration Slider
            VStack(spacing: 30) {
                // Custom duration selector
                durationSelector
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 10)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .presentationDetents([.fraction(0.33)])
        .presentationDragIndicator(.visible)
    }
    
    private var durationSelector: some View {
        VStack(spacing:16) {
            // Duration track with single selector
            GeometryReader { geometry in
                let labelWidth = geometry.size.width / CGFloat(WorkoutDuration.allCases.count)
                
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 2)
                    
                    // Progress track (from start to selected position)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary)
                        .frame(width: getSliderProgress(geometry.size.width), height: 2)
                    
                    // Slider circle positioned to align with label centers
                    Circle()
                        .fill(Color(.white))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .position(
                            x: getSliderProgress(geometry.size.width),
                            y: 1
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    updateDurationFromSlider(value.location.x, totalWidth: geometry.size.width)
                                }
                        )
                }
                .onTapGesture { location in
                    updateDurationFromSlider(location.x, totalWidth: geometry.size.width)
                }
            }
            .frame(height: 2)
            
            // Duration labels positioned to align with slider positions
            HStack(spacing: 0) {
                ForEach(Array(WorkoutDuration.allCases.enumerated()), id: \.element) { index, duration in
                    Text(duration.displayValue)
                        .font(.system(size: 13))
                        .foregroundColor(duration == tempSelectedDuration ? .primary : .secondary)
                        .fontWeight(duration == tempSelectedDuration ? .medium : .regular)
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            tempSelectedDuration = duration
                        }
                }
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 0) {
            Button("Set as default") {
                selectedDuration = tempSelectedDuration
                onSetDefault(tempSelectedDuration)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.primary)
            
            Spacer()
            
            Button("Set for this workout") {
                onSetForWorkout(tempSelectedDuration) // Pass the selected duration
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color(.systemBackground))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.primary)
            .cornerRadius(8)
        }
        
    }
    
    private func getSliderProgress(_ totalWidth: CGFloat) -> CGFloat {
        let currentIndex = WorkoutDuration.allCases.firstIndex(of: tempSelectedDuration) ?? 0
        let labelWidth = totalWidth / CGFloat(WorkoutDuration.allCases.count)
        return (CGFloat(currentIndex) + 0.5) * labelWidth
    }
    
    private func updateDurationFromSlider(_ xPosition: CGFloat, totalWidth: CGFloat) {
        let labelWidth = totalWidth / CGFloat(WorkoutDuration.allCases.count)
        let stepIndex = Int(round(xPosition / labelWidth))
        let clampedIndex = max(0, min(stepIndex, WorkoutDuration.allCases.count - 1))
        
        tempSelectedDuration = WorkoutDuration.allCases[clampedIndex]
    }
}

// MARK: - Conditional Modifier Helper
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Fitness Goal Picker View

struct FitnessGoalPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFitnessGoal: FitnessGoal
    let onSetDefault: (FitnessGoal) -> Void
    let onSetForWorkout: (FitnessGoal) -> Void
    
    @State private var tempSelectedGoal: FitnessGoal
    
    init(selectedFitnessGoal: Binding<FitnessGoal>, onSetDefault: @escaping (FitnessGoal) -> Void, onSetForWorkout: @escaping (FitnessGoal) -> Void) {
        self._selectedFitnessGoal = selectedFitnessGoal
        self.onSetDefault = onSetDefault
        self.onSetForWorkout = onSetForWorkout
        // If the current goal is .sport or .power, default to .strength since they're not shown
        let initialGoal = (selectedFitnessGoal.wrappedValue == .sport || selectedFitnessGoal.wrappedValue == .power) ? .strength : selectedFitnessGoal.wrappedValue
        self._tempSelectedGoal = State(initialValue: initialGoal)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            Text("Fitness Goal")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            // Fitness Goal List
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    ForEach(FitnessGoal.allCases.filter { $0 != .sport && $0 != .power }, id: \.self) { goal in
                        Button(action: {
                            tempSelectedGoal = goal
                        }) {
                            HStack(spacing: 16) {
                                // Radio button
                                Image(systemName: tempSelectedGoal == goal ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(tempSelectedGoal == goal ? .accentColor : .secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(goal.displayName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Spacer()
                            }
                                                            .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if goal != FitnessGoal.allCases.filter({ $0 != .sport && $0 != .power }).last {
                                                            Divider()
                                    .padding(.leading)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 10)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .presentationDetents([.fraction(0.6)])
        .presentationDragIndicator(.visible)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 0) {
            Button("Set as default") {
                selectedFitnessGoal = tempSelectedGoal
                onSetDefault(tempSelectedGoal)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.primary)
            
            Spacer()
            
            Button("Set for this workout") {
                onSetForWorkout(tempSelectedGoal)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color(.systemBackground))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.primary)
            .cornerRadius(8)
        }
    }
}

// MARK: - Fitness Level Picker View

struct FitnessLevelPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFitnessLevel: ExperienceLevel
    let onSetDefault: (ExperienceLevel) -> Void
    let onSetForWorkout: (ExperienceLevel) -> Void
    
    @State private var tempSelectedLevel: ExperienceLevel
    
    init(selectedFitnessLevel: Binding<ExperienceLevel>, onSetDefault: @escaping (ExperienceLevel) -> Void, onSetForWorkout: @escaping (ExperienceLevel) -> Void) {
        self._selectedFitnessLevel = selectedFitnessLevel
        self.onSetDefault = onSetDefault
        self.onSetForWorkout = onSetForWorkout
                 // Use the current selected level as initial value
         let initialLevel = selectedFitnessLevel.wrappedValue
        self._tempSelectedLevel = State(initialValue: initialLevel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            Text("Fitness Level")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            // Fitness Level List
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                                         ForEach(ExperienceLevel.allCases, id: \.self) { level in
                        Button(action: {
                            tempSelectedLevel = level
                        }) {
                            HStack(spacing: 16) {
                                // Radio button
                                Image(systemName: tempSelectedLevel == level ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(tempSelectedLevel == level ? .accentColor : .secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(level.displayName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Spacer()
                            }
                                                            .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                                                 if level != ExperienceLevel.allCases.last {
                                                            Divider()
                                    .padding(.leading)
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 10)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .presentationDetents([.fraction(0.4)])
        .presentationDragIndicator(.visible)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 0) {
            Button("Set as default") {
                selectedFitnessLevel = tempSelectedLevel
                onSetDefault(tempSelectedLevel)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.primary)
            
            Spacer()
            
            Button("Set for this workout") {
                onSetForWorkout(tempSelectedLevel)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color(.systemBackground))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.primary)
            .cornerRadius(8)
        }
    }
}



// MARK: - Set Log Model

struct SetLog {
    let setNumber: Int
    let weight: Double
    let reps: Int
    let completedAt: Date
}


// MARK: - Custom Modifiers

struct ToolbarBackgroundVisibilityModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        } else {
            content
        }
    }
}

struct NavigationBarSeparatorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Hide navigation bar separator
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor.systemBackground
                appearance.shadowColor = .clear // This removes the separator line
                
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
            }
    }
}

#Preview {
    NavigationView {
        LogWorkoutView(
            selectedTab: .constant(0), 
            navigationPath: .constant(NavigationPath()),
            onExerciseReplacementCallbackSet: { _ in },
            onExerciseUpdateCallbackSet: { _ in }
        )
    }
}

// MARK: - Modern Loading View Component

private struct ModernWorkoutLoadingView: View {
    let message: String
    @State private var shimmerOffset: CGFloat = -200
    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        if reduceMotion {
            // Simple loading for reduced motion
            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.accentColor)
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityLabel("Loading workout. \(message)")
        } else {
            // Full animated loading
            VStack(spacing: 32) {
                // Add top spacing to avoid touching header
                Color.clear.frame(height: 40)
                // Elegant loading indicator
                VStack(spacing: 16) {
                    // Subtle pulsing dots
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                                .scaleEffect(pulseScale)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                    value: pulseScale
                                )
                        }
                    }
                    
                    // Status text
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: message)
                }
                
                // Skeleton exercise cards
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        skeletonExerciseCard
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                startAnimations()
            }
            .accessibilityLabel("Loading workout. \(message)")
        }
    }
    
    private var skeletonExerciseCard: some View {
        HStack(spacing: 16) {
            // Thumbnail skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(shimmerGradient)
                .frame(width: 60, height: 60)
            
            // Content skeleton
            VStack(alignment: .leading, spacing: 8) {
                // Exercise name
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 16)
                
                // Sets/reps info
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 60, height: 12)
                    
                    Spacer()
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private var shimmerGradient: LinearGradient {
        let baseColor = Color(.systemGray5)
        let shimmerColor = Color(.systemGray4)
        
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: baseColor, location: 0),
                .init(color: shimmerColor, location: 0.5),
                .init(color: baseColor, location: 1)
            ]),
            startPoint: .init(x: -0.3 + shimmerOffset/200, y: 0),
            endPoint: .init(x: 0.3 + shimmerOffset/200, y: 0)
        )
    }
    
    private func startAnimations() {
        // Pulsing dots animation
        pulseScale = 1.2
        
        // Shimmer animation
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 200
        }
    }
}
    