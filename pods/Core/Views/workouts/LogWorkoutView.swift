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
    
    // Use global WorkoutManager from environment
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var onboarding: OnboardingViewModel
    
    // Local UI state
    @State private var showingDurationPicker = false
    @State private var shouldRegenerateWorkout = false
    @State private var showingTargetMusclesPicker = false
    @State private var showingEquipmentPicker = false
    @State private var showingFitnessGoalPicker = false
    @State private var showingFitnessLevelPicker = false
    @State private var showingFlexibilityPicker = false
    @State private var showingWorkoutFeedback = false
    @State private var showingAddExerciseSheet = false
    
    // Keep only essential UI-only state (not data state)
    @State private var currentWorkout: TodayWorkout? = nil
    @State private var userEmail: String = UserDefaults.standard.string(forKey: "userEmail") ?? ""
    
    
    // Properties that delegate to WorkoutManager but are accessed locally
    private var isGeneratingWorkout: Bool {
        workoutManager.isGeneratingWorkout
    }
    
    private var generationMessage: String {
        workoutManager.generationMessage
    }
    
    private var customTargetMuscles: [String]? {
        workoutManager.customTargetMuscles
    }
    
    private var customEquipment: [Equipment]? {
        workoutManager.customEquipment
    }
    
    private var selectedMuscleType: String {
        workoutManager.selectedMuscleType
    }
    
    // selectedEquipmentType is now a @State property above
    
    // Deprecated keys (still needed for cleanup)
    private let sessionDurationKey = "currentWorkoutSessionDuration"
    private let sessionDateKey = "currentWorkoutSessionDate"
    private let customMusclesKey = "currentWorkoutCustomMuscles"
    private let sessionFitnessGoalKey = "currentWorkoutSessionFitnessGoal"
    private let sessionFlexibilityKey = "currentWorkoutSessionFlexibility"
    
    // Use WorkoutManager directly (single source of truth)
    private var effectiveDuration: WorkoutDuration {
        return workoutManager.effectiveDuration
    }
    
    private var effectiveFitnessGoal: FitnessGoal {
        return workoutManager.effectiveFitnessGoal
    }
    
    private var effectiveFlexibilityPreferences: FlexibilityPreferences {
        return workoutManager.effectiveFlexibilityPreferences
    }
    
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
    
    private var hasSessionModifications: Bool {
        return workoutManager.sessionDuration != nil ||
               workoutManager.sessionFitnessGoal != nil ||
               workoutManager.sessionFitnessLevel != nil ||
               workoutManager.sessionFlexibilityPreferences != nil ||
               workoutManager.customTargetMuscles != nil ||
               workoutManager.customEquipment != nil
    }
    
    // Session phase indicator for dynamic programming
    @ViewBuilder
    private var sessionPhaseIndicator: some View {
        EmptyView()
    }
    
    private func getCurrentSessionNumber() -> Int {
        return 1 // Simplified for now
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
        mainBody
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationTitle(selectedWorkoutTab == .workouts ? "Workouts" : "Today's Workout")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
            .if(selectedWorkoutTab == .workouts) { view in
                view.searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: selectedWorkoutTab.searchPrompt
                )
            }
            .onAppear {
                print("🚀 LogWorkoutView appeared - WorkoutManager is globally managed")
                // Ensure workout weights match user's units when view appears
                let savedUnits = UserDefaults.standard.string(forKey: "workoutUnitsSystem")
                let currentUnits = onboarding.unitsSystem.rawValue
                if let saved = savedUnits, saved != currentUnits {
                    if let from = UnitsSystem(rawValue: saved), let to = UnitsSystem(rawValue: currentUnits) {
                        workoutManager.convertTodayWorkoutUnits(from: from, to: to)
                    }
                } else if savedUnits == nil {
                    // Initialize persisted units for workouts
                    UserDefaults.standard.set(currentUnits, forKey: "workoutUnitsSystem")
                }
            }
            .onDisappear {
                // Cleanup if needed - WorkoutManager handles persistence
            }
            .onReceive(NotificationCenter.default.publisher(for: .workoutCompletedNeedsFeedback)) { _ in
                showingWorkoutFeedback = true
            }
            .sheet(isPresented: $showingDurationPicker) {
                durationPickerSheet
            }
            .onChange(of: onboarding.unitsSystem) { newValue in
                // Convert the persisted workout when units preference changes
                let oldRaw = UserDefaults.standard.string(forKey: "workoutUnitsSystem") ?? (newValue == .imperial ? UnitsSystem.metric.rawValue : UnitsSystem.imperial.rawValue)
                if let from = UnitsSystem(rawValue: oldRaw), from != newValue {
                    workoutManager.convertTodayWorkoutUnits(from: from, to: newValue)
                }
                UserDefaults.standard.set(newValue.rawValue, forKey: "workoutUnitsSystem")
            }
            .sheet(isPresented: $showingTargetMusclesPicker) {
                targetMusclesPickerSheet
            }
            .sheet(isPresented: $showingEquipmentPicker) {
                equipmentPickerSheet
            }
            .sheet(isPresented: $showingFitnessGoalPicker) {
                fitnessGoalPickerSheet
            }
            .sheet(isPresented: $showingFitnessLevelPicker) {
                fitnessLevelPickerSheet
            }
            .sheet(isPresented: $showingFlexibilityPicker) {
                flexibilityPickerSheet
            }
            .sheet(isPresented: $showingWorkoutFeedback) {
                workoutFeedbackSheet
            }
            .sheet(isPresented: $showingAddExerciseSheet) {
                addExerciseSheet
            }
            .fullScreenCover(item: $currentWorkout) { workout in
                WorkoutInProgressView(
                    isPresented: Binding(
                        get: { currentWorkout != nil },
                        set: { if !$0 { currentWorkout = nil } }
                    ),
                    workout: workout
                )
            }
    }
    
    @ViewBuilder
    private var mainBody: some View {
        ZStack(alignment: .bottom) {
            backgroundView
            contentStack
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        Color("primarybg").edgesIgnoringSafeArea(.all)
    }
    
    @ViewBuilder
    private var contentStack: some View {
        VStack(spacing: 0) {
            headerSection
            sessionPhaseIndicator
            mainContentView
            Spacer()
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 0) {
            tabHeaderView
            Divider()
                .background(Color.gray.opacity(0.3))
        }
        // .background(Color(.systemBackground))
          .background(Color("primarybg"))
        .zIndex(1) // Keep header on top
    }
    
    // MARK: - Sheet Content Views
    
    @ViewBuilder
    private var durationPickerSheet: some View {
        WorkoutDurationPickerView(
            selectedDuration: .constant(workoutManager.effectiveDuration),
            onSetDefault: { newDuration in
                    // Update WorkoutManager and UserProfileService
                    workoutManager.setDefaultDuration(newDuration)
                    
                    // Update server
                    if let email = UserDefaults.standard.string(forKey: "userEmail") {
                        updateServerWorkoutDuration(email: email, durationMinutes: newDuration.minutes)
                    }
                    
                    showingDurationPicker = false
                    
                    // Regenerate workout with new duration (minimum 1.5s loader)
                    Task {
                        let startTime = Date()
                        await workoutManager.generateTodayWorkout()
                        
                        // Ensure minimum 1.5 seconds of loading for smooth UX
                        let elapsed = Date().timeIntervalSince(startTime)
                        let remaining = max(0, 1.5 - elapsed)
                        if remaining > 0 {
                            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                        }
                    }
                    print("✅ Default duration set to \(newDuration.minutes) minutes")
                },
                onSetForWorkout: { newDuration in
                    // Update WorkoutManager session duration
                    workoutManager.setSessionDuration(newDuration)
                    showingDurationPicker = false
                    
                    // Regenerate with new duration (minimum 1.5s loader)
                    Task {
                        let startTime = Date()
                        await workoutManager.generateTodayWorkout()
                        
                        // Ensure minimum 1.5 seconds of loading for smooth UX
                        let elapsed = Date().timeIntervalSince(startTime)
                        let remaining = max(0, 1.5 - elapsed)
                        if remaining > 0 {
                            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                        }
                    }
                    print("✅ Session duration set to \(newDuration.minutes) minutes")
                }
            )
    }
    
    @ViewBuilder
    private var targetMusclesPickerSheet: some View {
        TargetMusclesView(
                onSelectionChanged: { newMuscles, muscleType in
                    // Save custom muscle selection and type, regenerate workout
                    print("🎯 UI: Selected muscles: \(newMuscles), type: \(muscleType)")
                    workoutManager.customTargetMuscles = newMuscles
                    workoutManager.selectedMuscleType = muscleType
                    
                    // Persist to UserDefaults (WorkoutManager handles this)
                    UserDefaults.standard.set(newMuscles, forKey: customMusclesKey)
                    UserDefaults.standard.set(muscleType, forKey: "currentWorkoutMuscleType")
                    
                    print("🎯 Selected target muscles: \(newMuscles), type: \(muscleType)")
                    showingTargetMusclesPicker = false
                    
                    // Regenerate workout
                    Task {
                        await workoutManager.generateTodayWorkout()
                    }
                },
                currentCustomMuscles: customTargetMuscles,
                currentMuscleType: selectedMuscleType
            )
    }
    
    @ViewBuilder
    private var equipmentPickerSheet: some View {
        EquipmentView(onSelectionChanged: { newEquipment, equipmentType in
                // Save custom equipment selection and type, regenerate workout
                workoutManager.customEquipment = newEquipment
                workoutManager.selectedEquipmentType = equipmentType
                
                // Persist to UserDefaults (WorkoutManager handles this)
                let equipmentStrings = newEquipment.map { $0.rawValue }
                UserDefaults.standard.set(equipmentStrings, forKey: "currentWorkoutCustomEquipment")
                UserDefaults.standard.set(equipmentType, forKey: "currentWorkoutEquipmentType")
                
                print("⚙️ Selected equipment: \(newEquipment.map { $0.rawValue }), type: \(equipmentType)")
                showingEquipmentPicker = false
                
                // Regenerate workout
                Task {
                    await workoutManager.generateTodayWorkout()
                }
            })
    }
    
    @ViewBuilder
    private var fitnessGoalPickerSheet: some View {
        FitnessGoalPickerView(
                selectedFitnessGoal: .constant(workoutManager.effectiveFitnessGoal),
                onSetDefault: { newGoal in
                    workoutManager.setDefaultFitnessGoal(newGoal)
                    
                    if let email = UserDefaults.standard.string(forKey: "userEmail") {
                        updateServerFitnessGoal(email: email, fitnessGoal: newGoal)
                    }
                    
                    showingFitnessGoalPicker = false
                    Task {
                        await workoutManager.generateTodayWorkout()
                    }
                    print("✅ Default fitness goal set to \(newGoal.displayName)")
                },
                onSetForWorkout: { newGoal in
                    workoutManager.setSessionFitnessGoal(newGoal)
                    showingFitnessGoalPicker = false
                    
                    Task {
                        await workoutManager.generateTodayWorkout()
                    }
                    print("✅ Session fitness goal set to \(newGoal.displayName)")
                }
            )
    }
    
    @ViewBuilder
    private var fitnessLevelPickerSheet: some View {
        FitnessLevelPickerView(
                selectedFitnessLevel: .constant(workoutManager.effectiveFitnessLevel),
                onSetDefault: { newLevel in
                    workoutManager.setDefaultFitnessLevel(newLevel)
                    
                    if let email = UserDefaults.standard.string(forKey: "userEmail") {
                        updateServerFitnessLevel(email: email, fitnessLevel: newLevel)
                    }
                    
                    showingFitnessLevelPicker = false
                    Task {
                        await workoutManager.generateTodayWorkout()
                    }
                    print("✅ Default fitness level set to \(newLevel.displayName)")
                },
                onSetForWorkout: { newLevel in
                    workoutManager.setSessionFitnessLevel(newLevel)
                    showingFitnessLevelPicker = false
                    
                    Task {
                        await workoutManager.generateTodayWorkout()
                    }
                    print("✅ Session fitness level set to \(newLevel.displayName)")
                }
            )
    }
    
    @ViewBuilder
    private var flexibilityPickerSheet: some View {
        FlexibilityPickerView(
                warmUpEnabled: .constant(effectiveFlexibilityPreferences.warmUpEnabled),
                coolDownEnabled: .constant(effectiveFlexibilityPreferences.coolDownEnabled),
                onSetDefault: { warmUp, coolDown in
                    let newPrefs = FlexibilityPreferences(warmUpEnabled: warmUp, coolDownEnabled: coolDown)
                    workoutManager.setDefaultFlexibilityPreferences(newPrefs)
                    
                    // Update server if email exists
                    let emailToUse = userEmail.isEmpty ? (UserDefaults.standard.string(forKey: "userEmail") ?? "") : userEmail
                    
                    if !emailToUse.isEmpty {
                        Task {
                            NetworkManagerTwo.shared.updateFlexibilityPreferences(
                                email: emailToUse,
                                warmUpEnabled: warmUp,
                                coolDownEnabled: coolDown
                            ) { result in
                                DispatchQueue.main.async {
                                    switch result {
                                    case .success:
                                        showingFlexibilityPicker = false
                                        Task {
                                            await workoutManager.generateTodayWorkout()
                                        }
                                        print("✅ Default flexibility preferences updated")
                                    case .failure(let error):
                                        print("❌ Failed to update flexibility preferences: \(error)")
                                    }
                                }
                            }
                        }
                    } else {
                        showingFlexibilityPicker = false
                        Task {
                            await workoutManager.generateTodayWorkout()
                        }
                    }
                },
                onSetForWorkout: { warmUp, coolDown in
                    let newPrefs = FlexibilityPreferences(warmUpEnabled: warmUp, coolDownEnabled: coolDown)
                    workoutManager.setSessionFlexibilityPreferences(newPrefs)
                    
                    showingFlexibilityPicker = false
                    Task {
                        await workoutManager.generateTodayWorkout()
                    }
                    print("✅ Session flexibility preferences set")
                }
            )
    }
    
    @ViewBuilder
    private var workoutFeedbackSheet: some View {
        if let workout = workoutManager.todayWorkout {
            WorkoutFeedbackSheet(
                workout: workout,
                onFeedbackSubmitted: { feedback in
                    // Submit feedback via PerformanceFeedbackService
                    Task {
                        await PerformanceFeedbackService.shared.submitFeedback(feedback)
                    }
                    
                    // Advance session phase if needed
                    handleFeedbackSubmitted()
                },
                onSkipped: {
                    // Still advance session phase
                    handleFeedbackSkipped()
                }
            )
        }
    }
    
    private func handleFeedbackSubmitted() {
        workoutManager.advanceSessionPhaseIfNeeded()
        showingWorkoutFeedback = false
    }
    
    private func handleFeedbackSkipped() {
        workoutManager.advanceSessionPhaseIfNeeded()
        showingWorkoutFeedback = false
    }
    
    private func regenerateWorkoutWithNewDuration() {
        print("🔄 Regenerating workout with WorkoutManager")
        Task {
            await workoutManager.generateTodayWorkout()
        }
        // Note: shouldRegenerateWorkout is reset by TodayWorkoutView after it triggers generation
    }
    
    private func clearSessionDuration() {
        workoutManager.clearAllSessionOverrides()
        print("🗑️ Cleared all session overrides via WorkoutManager")
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
                        // Clear all session overrides via WorkoutManager
                        workoutManager.clearAllSessionOverrides()
                        
                        // Regenerate workout with defaults
                        Task {
                            await workoutManager.generateTodayWorkout()
                        }
                        print("🔄 Reset to default preferences")
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            // .background(Color(.systemBackground))
                             .background(Color("primarybg"))
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
            .frame(height: 36)
            // .background(Color(.systemBackground))
            .background(Color("primarybg"))
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
                if isGeneratingWorkout && customTargetMuscles != nil {
                    // Show loading animation when regenerating with custom muscles
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "figure.mixed.cardio")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                // Use selectedMuscleType as single source of truth for button display
                Text(workoutManager.selectedMuscleType)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                if !isGeneratingWorkout {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(height: 36)
            // .background(Color(.systemBackground))
            .background(Color("primarybg"))
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
            .frame(height: 36)
            // .background(Color(.systemBackground))
            .background(Color("primarybg"))
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
            .frame(height: 36)
            // .background(Color(.systemBackground))
            .background(Color("primarybg"))
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
                
                Text(workoutManager.effectiveFitnessLevel.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(height: 36)
            // .background(Color(.systemBackground))
            .background(Color("primarybg"))
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
                    .font(.system(size: 17, weight: .bold))
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
            .frame(height: 36)
            // .background(Color(.systemBackground))
            .background(Color("primarybg"))
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
                        userEmail: userEmail,
                        selectedDuration: effectiveDuration,
                        shouldRegenerate: $shouldRegenerateWorkout,
                        customTargetMuscles: customTargetMuscles,
                        customEquipment: customEquipment,
                        effectiveFitnessGoal: effectiveFitnessGoal,
                        effectiveFitnessLevel: workoutManager.effectiveFitnessLevel,
                        onExerciseReplacementCallbackSet: onExerciseReplacementCallbackSet,
                        onExerciseUpdateCallbackSet: onExerciseUpdateCallbackSet,
                        currentWorkout: $currentWorkout,
                        effectiveFlexibilityPreferences: effectiveFlexibilityPreferences,
                        showAddExerciseSheet: $showingAddExerciseSheet
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

    // MARK: - Add Exercise Sheet
    @ViewBuilder
    private var addExerciseSheet: some View {
        AddExerciseView { selected in
                guard !selected.isEmpty else { return }
                guard let current = workoutManager.todayWorkout else { return }

                // Build TodayWorkoutExercise entries using recommendations
                let recService = WorkoutRecommendationService.shared
                let restDefault = defaultRestTime(for: effectiveFitnessGoal)

                let appended: [TodayWorkoutExercise] = selected.map { ex in
                    let rec = recService.getSmartRecommendation(for: ex, fitnessGoal: effectiveFitnessGoal)
                    let tracking = ExerciseClassificationService.determineTrackingType(for: ex)
                    return TodayWorkoutExercise(
                        exercise: ex,
                        sets: rec.sets,
                        reps: rec.reps,
                        weight: rec.weight,
                        restTime: restDefault,
                        notes: nil,
                        warmupSets: nil,
                        flexibleSets: nil,
                        trackingType: tracking
                    )
                }

                let updated = TodayWorkout(
                    id: current.id,
                    date: current.date,
                    title: current.title,
                    exercises: current.exercises + appended,
                    estimatedDuration: current.estimatedDuration,
                    fitnessGoal: current.fitnessGoal,
                    difficulty: current.difficulty,
                    warmUpExercises: current.warmUpExercises,
                    coolDownExercises: current.coolDownExercises
                )

                workoutManager.setTodayWorkout(updated)
            }
    }

    // Reasonable default rest time by goal
    private func defaultRestTime(for goal: FitnessGoal) -> Int {
        switch goal {
        case .strength: return 105  // midpoint of 90–120s
        case .hypertrophy: return 60
        case .tone: return 50
        case .endurance: return 30
        case .powerlifting: return 150 // midpoint of 120–180s
        default: return 75
        }
    }

}
    
    // MARK: - Flexibility Preferences Methods
    
    // loadSessionFlexibilityPreferences removed - now handled by WorkoutManager.loadSessionData()
    
    // clearSessionFlexibilityPreferences removed - now handled by WorkoutManager.clearAllSessionOverrides()
    

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
    @EnvironmentObject var workoutManager: WorkoutManager
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
    @Binding var showAddExerciseSheet: Bool
    
    
    @State private var userProfile = UserProfileService.shared
    @State private var showSessionPhaseCard = false // Hidden due to sync issues
    
    // Get the workout to display
    private var workoutToShow: TodayWorkout? {
        return workoutManager.todayWorkout
    }
    
    var body: some View {
        Group {
            // Show generation loading
            if workoutManager.isGeneratingWorkout {
                ModernWorkoutLoadingView(message: "Creating your personalized workout...")
                    .transition(.opacity)
            } else if let workout = workoutToShow {
                VStack(spacing: 12) {
                    // Session phase header for dynamic workouts
                    if let dynamicParams = workoutManager.dynamicParameters, showSessionPhaseCard {
                        DynamicSessionPhaseView(
                            sessionPhase: dynamicParams.sessionPhase,
                            workoutCount: calculateWorkoutCountInPhase()
                        )
                        .padding(.horizontal)
                    }

                    // Exercises list with swipe actions
                    TodayWorkoutExerciseList(
                        workout: workout,
                        navigationPath: $navigationPath,
                        onExerciseReplacementCallbackSet: onExerciseReplacementCallbackSet,
                        onExerciseUpdateCallbackSet: onExerciseUpdateCallbackSet,
                        showAddExerciseSheet: $showAddExerciseSheet
                    )
                }
            } else {
                // Empty state when no workout and not generating
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
        }
        .background(Color("primarybg"))
        .safeAreaInset(edge: .bottom) {
            if let workout = workoutManager.todayWorkout {
                HStack {
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
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color("primarybg").opacity(0),
                            Color("primarybg").opacity(0.95),
                            Color("primarybg")
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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
                workoutManager.setTodayWorkout(workout)
                return
            }
        }
        
        // No workout for today, generate one automatically
        generateTodayWorkout()
    }
    
    private func generateTodayWorkout() {
        print("🚀 TodayWorkoutView: Using WorkoutManager to generate workout")
        Task {
            await workoutManager.generateTodayWorkout()
        }
    }
    
    private func createIntelligentWorkout() -> TodayWorkout {
        let recommendationService = WorkoutRecommendationService.shared
        
        // Get user's fitness goal and preferences - use effective fitness goal
        let fitnessGoal = effectiveFitnessGoal
        let experienceLevel = effectiveFitnessLevel
        
        // Use WorkoutManager's current effective duration (handles session overrides)
        let targetDuration = workoutManager.effectiveDuration.minutes
        
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
            
        // FITBOD-ALIGNED SYSTEM SUMMARY
        recommendationService.logFlexibilitySystemSummary(
            warmupCount: warmUpExercises?.count ?? 0,
            cooldownCount: coolDownExercises?.count ?? 0,
            targetMuscles: muscleGroups
        )
        
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
    ) -> LogWorkoutPlan {
        
        print("🏗️ LogWorkoutView: Using WorkoutGenerationService for robust workout generation")
        
        // Convert parameters to WorkoutGenerationService types
        let targetDuration = WorkoutDuration.fromMinutes(targetDurationMinutes)
        
        // Convert FitnessGoal from current session
        let fitnessGoal: FitnessGoal
        if let selectedGoal = workoutManager.sessionFitnessGoal {
            fitnessGoal = selectedGoal
        } else {
            // Fallback to general fitness
            fitnessGoal = .general
        }
        
        // Convert ExperienceLevel from current session  
        let experienceLevel: ExperienceLevel
        if let selectedLevel = workoutManager.sessionFitnessLevel {
            experienceLevel = selectedLevel
        } else {
            experienceLevel = .intermediate
        }
        
        do {
            // Use the robust WorkoutGenerationService instead of duplicate logic
            let generatedPlan = try WorkoutGenerationService.shared.generateWorkoutPlan(
                muscleGroups: muscleGroups,
                targetDuration: targetDuration,
                fitnessGoal: fitnessGoal,
                experienceLevel: experienceLevel,
                customEquipment: customEquipment,
                flexibilityPreferences: flexibilityPreferences
            )
            
            // Convert TimeBreakdown to WorkoutTimeBreakdown for LogWorkoutView compatibility
            let breakdown = WorkoutTimeBreakdown(
                warmupSeconds: generatedPlan.totalTimeBreakdown.warmupMinutes * 60,
                exerciseTimeSeconds: generatedPlan.totalTimeBreakdown.exerciseMinutes * 60,
                cooldownSeconds: generatedPlan.totalTimeBreakdown.cooldownMinutes * 60,
                bufferSeconds: 0, // No additional buffer needed - already included in generation
                totalSeconds: generatedPlan.totalTimeBreakdown.totalMinutes * 60
            )
            
            print("✅ LogWorkoutView: Generated \(generatedPlan.exercises.count) exercises using research-based algorithm")
            
            return LogWorkoutPlan(
                exercises: generatedPlan.exercises,
                actualDurationMinutes: generatedPlan.actualDurationMinutes,
                totalTimeBreakdown: breakdown
            )
            
        } catch {
            print("⚠️ LogWorkoutView: WorkoutGenerationService failed, error: \(error)")
            // Fallback to empty workout rather than minimal exercises
            let breakdown = WorkoutTimeBreakdown(
                warmupSeconds: 0,
                exerciseTimeSeconds: 0,
                cooldownSeconds: 0,
                bufferSeconds: 0,
                totalSeconds: 0
            )
            
            return LogWorkoutPlan(
                exercises: [],
                actualDurationMinutes: 0,
                totalTimeBreakdown: breakdown
            )
        }
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
        var usedIds = Set<Int>()
        
        for muscleGroup in muscleGroups.prefix(4) { // Limit to 4 muscle groups
            let recommendedExercises = recommendationService.getRecommendedExercises(
                for: muscleGroup, 
                count: exercisesPerMuscle,
                customEquipment: customEquipment,
                flexibilityPreferences: effectiveFlexibilityPreferences
            )
            
            for exercise in recommendedExercises {
                guard !usedIds.contains(exercise.id) else { continue }
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
                usedIds.insert(exercise.id)
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
        var usedIds = Set<Int>()
        
        // Generate 1 compound exercise per muscle group with minimal sets
        for muscleGroup in muscleGroups.prefix(3) { // Limit to 3 muscle groups for time
            let recommendedExercises = recommendationService.getRecommendedExercises(
                for: muscleGroup, 
                count: 1,
                customEquipment: customEquipment,
                flexibilityPreferences: effectiveFlexibilityPreferences
            )
            
            if let exercise = recommendedExercises.first, !usedIds.contains(exercise.id) {
                exercises.append(TodayWorkoutExercise(
                    exercise: exercise,
                    sets: parameters.setsPerExercise.lowerBound,
                    reps: parameters.repRange.lowerBound + 2,
                    weight: nil,
                    restTime: parameters.restBetweenSetsSeconds.lowerBound
                ))
                usedIds.insert(exercise.id)
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
    
    private func calculateWorkoutCountInPhase() -> Int {
        // For now, return a simple count based on session phase
        // In a full implementation, this would track workouts within the current phase
        if let dynamicParams = workoutManager.dynamicParameters {
            switch dynamicParams.sessionPhase {
            case .strengthFocus:
                return 1
            case .volumeFocus:
                return 2
            case .conditioningFocus:
                return 3
            }
        }
        return 1
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
        .background(Color("primarybg"))
    }
}

// MARK: - Today Workout Exercise List

private struct TodayWorkoutExerciseList: View {
    let workout: TodayWorkout
    @Binding var navigationPath: NavigationPath
    let onExerciseReplacementCallbackSet: (((Int, ExerciseData) -> Void)?) -> Void
    let onExerciseUpdateCallbackSet: (((Int, TodayWorkoutExercise) -> Void)?) -> Void
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var exercises: [TodayWorkoutExercise]
    @State private var warmUpExpanded: Bool = true
    @State private var coolDownExpanded: Bool = true
    @Binding var showAddExerciseSheet: Bool
    
    init(workout: TodayWorkout, navigationPath: Binding<NavigationPath>, onExerciseReplacementCallbackSet: @escaping (((Int, ExerciseData) -> Void)?) -> Void, onExerciseUpdateCallbackSet: @escaping (((Int, TodayWorkoutExercise) -> Void)?) -> Void, showAddExerciseSheet: Binding<Bool>) {
        self.workout = workout
        self._navigationPath = navigationPath
        self.onExerciseReplacementCallbackSet = onExerciseReplacementCallbackSet
        self.onExerciseUpdateCallbackSet = onExerciseUpdateCallbackSet
        self._exercises = State(initialValue: workout.exercises)
        self._showAddExerciseSheet = showAddExerciseSheet
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
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
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
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
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
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                }
            }

            // Add Exercise button as the final list row
            Section {
                Button(action: { showAddExerciseSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add Exercise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16))
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color("primarybg"))
        .cornerRadius(12)
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
        print("🔧 DEBUG: updateExercise called for index \(index), exercise: \(updatedExercise.exercise.name)")
        print("🔧 DEBUG: Updated exercise has \(updatedExercise.flexibleSets?.count ?? 0) flexible sets")
        guard index < exercises.count else { 
            print("🔧 DEBUG: ERROR - Index \(index) out of bounds for exercises array (count: \(exercises.count))")
            return 
        }
        
        // Replace the exercise with the updated one (including warm-up sets and new set count)
        exercises[index] = updatedExercise
        print("🔧 DEBUG: Successfully updated exercise at index \(index)")

        // Persist to WorkoutManager (single source of truth) so other views see changes immediately
        workoutManager.updateExercise(at: index, with: updatedExercise)

        // Also save to UserDefaults for session persistence across app restarts
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
    
    

}

// MARK: - Exercise Workout Card

private struct ExerciseWorkoutCard: View {
    let exercise: TodayWorkoutExercise
    let allExercises: [TodayWorkoutExercise]
    let exerciseIndex: Int
    let onExerciseReplaced: (Int, ExerciseData) -> Void
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var recommendMoreOften = false
    @State private var recommendLessOften = false
    @State private var cachedDynamicExercise: DynamicWorkoutExercise?
    @State private var showHistory = false
    @State private var showReplace = false
    @State private var tempExercise: TodayWorkoutExercise
    
    // Check if dynamic parameters are available
    private var shouldShowDynamicView: Bool {
        return workoutManager.dynamicParameters != nil
    }
    
    // Convert static exercise to dynamic for display
    private func convertToDynamicExercise(
        _ staticExercise: TodayWorkoutExercise,
        params: DynamicWorkoutParameters
    ) -> DynamicWorkoutExercise? {
        return DynamicParameterService.shared.generateDynamicExercise(
            for: staticExercise.exercise,
            parameters: params,
            fitnessGoal: workoutManager.effectiveFitnessGoal
        )
    }
    
    // Stable cached dynamic exercise (prevents UI flickering)
    private var stableDynamicExercise: DynamicWorkoutExercise? {
        return cachedDynamicExercise
    }
    
    // Computed display based on actual exercise data (updates live)
    private var setsAndRepsDisplay: String {
        if let tracking = exercise.trackingType, let flex = exercise.flexibleSets, !flex.isEmpty {
            switch tracking {
            case .timeOnly, .holdTime, .timeDistance:
                let count = flex.count
                let label = count == 1 ? "set" : "sets"
                return "\(count) \(label)"
            case .rounds:
                let rounds = flex.first?.rounds ?? exercise.sets
                let label = rounds == 1 ? "round" : "rounds"
                return "\(rounds) \(label)"
            default:
                break
            }
        }

        // Reps-based formatting shows current sets × reps
        let setsLabel = exercise.sets == 1 ? "set" : "sets"
        return "\(exercise.sets) \(setsLabel) • \(exercise.reps) reps"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    init(exercise: TodayWorkoutExercise, allExercises: [TodayWorkoutExercise], exerciseIndex: Int, onExerciseReplaced: @escaping (Int, ExerciseData) -> Void, navigationPath: Binding<NavigationPath>) {
        self.exercise = exercise
        self.allExercises = allExercises
        self.exerciseIndex = exerciseIndex
        self.onExerciseReplaced = onExerciseReplaced
        self._navigationPath = navigationPath
        self._tempExercise = State(initialValue: exercise)
    }

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
                    
                    Text(setsAndRepsDisplay)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Menu button
                Menu {
                    Button("Exercise History") { showHistory = true }
                    
                    Button("Replace") { 
                        tempExercise = exercise
                        showReplace = true
                    }
                    
                    Button("Recommend more often") {
                        UserProfileService.shared.setExercisePreferenceMoreOften(exerciseId: exercise.exercise.id)
                        recommendMoreOften = true
                        recommendLessOften = false
                    }
                    
                    Button("Recommend less often") {
                        UserProfileService.shared.setExercisePreferenceLessOften(exerciseId: exercise.exercise.id)
                        recommendLessOften = true
                        recommendMoreOften = false
                    }
                    
                    Divider()
                    
                    Button("Don't recommend again", role: .destructive) {
                        let ups = UserProfileService.shared
                        ups.addToAvoided(exercise.exercise.id)
                        withAnimation { workoutManager.removeExerciseFromToday(exerciseId: exercise.exercise.id) }
                    }
                    
                    Button("Delete from workout", role: .destructive) {
                        withAnimation { workoutManager.removeExerciseFromToday(exerciseId: exercise.exercise.id) }
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
            .background(Color("containerbg"))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            NavigationLink(
                destination: ExerciseHistory(exercise: exercise),
                isActive: $showHistory,
                label: { EmptyView() }
            ).hidden()
        )
        .sheet(isPresented: $showReplace) {
            ReplaceExerciseSheet(
                currentExercise: $tempExercise,
                onExerciseReplaced: { newExercise in
                    onExerciseReplaced(exerciseIndex, newExercise)
                }
            )
        }
        .onAppear {
            // Cache the dynamic exercise on first appearance
            updateCachedExercise()
        }
        .onChange(of: workoutManager.dynamicParameters) { _, _ in
            // Recalculate when dynamic parameters change
            updateCachedExercise()
        }
        .onChange(of: workoutManager.effectiveFitnessGoal) { _, _ in
            // Recalculate when fitness goal changes  
            updateCachedExercise()
        }
    }
    
    // Update cached exercise to prevent recomputation
    private func updateCachedExercise() {
        guard let dynamicParams = workoutManager.dynamicParameters else {
            cachedDynamicExercise = nil
            return
        }
        
        cachedDynamicExercise = DynamicParameterService.shared.generateDynamicExercise(
            for: exercise.exercise,
            parameters: dynamicParams,
            fitnessGoal: workoutManager.effectiveFitnessGoal
        )
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
        // .background(Color(.systemBackground))
        .background(Color("primarybg"))
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

// TodayWorkoutExercise is now defined in WorkoutModels.swift - removed duplicate definition

// MARK: - Workout Parameters

// Using WorkoutParameters from WorkoutGenerationService
// LogWorkoutView-specific structs that differ from WorkoutGenerationService

struct LogWorkoutPlan {
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
            // .background(Color(.systemBackground))
            .background(Color("primarybg"))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Workout Duration Enum (moved to WorkoutManager.swift)

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
        // .background(Color(.systemBackground))
        .background(Color("primarybg"))
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
                            // .background(Color(.systemBackground))
                            .background(Color("primarybg"))
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
        // .background(Color(.systemBackground))
        .background(Color("primarybg"))
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
                            // .background(Color(.systemBackground))
                            .background(Color("primarybg"))
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
        // .background(Color(.systemBackground))
        .background(Color("primarybg"))
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

// MARK: - Dynamic Session Phase View (Inline Definition)

private struct DynamicSessionPhaseView: View {
    let sessionPhase: SessionPhase
    let workoutCount: Int
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Phase icon and name
            HStack(spacing: 8) {
                Image(systemName: phaseIconName)
                    .font(.title2)
                    .foregroundColor(phaseColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(phaseDisplayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(phaseDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Phase indicator dots
            HStack(spacing: 6) {
                ForEach([SessionPhase.strengthFocus, .volumeFocus, .conditioningFocus], id: \.self) { phase in
                    Circle()
                        .fill(phase == sessionPhase ? phaseColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: sessionPhase)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(phaseColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(phaseColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var phaseIconName: String {
        switch sessionPhase {
        case .strengthFocus:
            return "dumbbell.fill"
        case .volumeFocus:
            return "chart.bar.fill"
        case .conditioningFocus:
            return "figure.run"
        }
    }
    
    private var phaseColor: Color {
        switch sessionPhase {
        case .strengthFocus:
            return .red
        case .volumeFocus:
            return .blue
        case .conditioningFocus:
            return .green
        }
    }
    
    private var phaseDisplayName: String {
        // Use contextual display name based on user's fitness goal
        return sessionPhase.contextualDisplayName(for: workoutManager.effectiveFitnessGoal)
    }
    
    private var phaseDescription: String {
        switch sessionPhase {
        case .strengthFocus:
            return "Building maximal strength"
        case .volumeFocus:
            return "Increasing muscle size"
        case .conditioningFocus:
            return "Improving endurance"
        }
    }
}
    
