//
//  LogWorkoutView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/5/25.
//
//  WORKOUT SESSION DURATION PERSISTENCE (MacroFactor-style):
//
//  This view implements a two-tier duration system:
//
//  1. PLAN DURATION:
//     - User's preference stored on the active training plan
//     - Updated from plan creation/editing flows
//     - Syncs via ProgramService.updatePlanPreference() to backend
//     - Future workouts inherit the new value
//
//  2. SESSION DURATION (sessionDuration):
//     - Temporary override for current workout session only
//     - Updated when "Set for this workout" is pressed
//     - Stored in UserDefaults with date validation (clears old sessions)
//     - Automatically cleared when workout is completed
//
//  The effectiveDuration computed property returns sessionDuration ?? planDuration
//  ensuring session overrides take precedence over plan defaults.
//

import SwiftUI
import AVKit
import AVFoundation
import Combine

struct LogWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: Int
    @Binding var navigationPath: NavigationPath
    let onExerciseReplacementCallbackSet: (((Int, ExerciseData) -> Void)?) -> Void
    let onExerciseUpdateCallbackSet: (((Int, TodayWorkoutExercise) -> Void)?) -> Void
    // New: presenter for full-screen logging sheet (provided by container)
    let onPresentLogSheet: (LogExerciseSheetContext) -> Void
    @FocusState private var isSearchFieldFocused: Bool
    
    // Tab management
    @State private var selectedWorkoutTab: WorkoutTab = .today
    
    // Use global WorkoutManager from environment
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var onboarding: OnboardingViewModel
    @EnvironmentObject private var proFeatureGate: ProFeatureGate
    @Environment(\.modelContext) private var modelContext
    private let userProfileService = UserProfileService.shared
    @ObservedObject private var userProfile = UserProfileService.shared
    
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
    @State private var showingSupersetCircuitSheet = false
    @State private var showingCreateProgramSheet = false

    // Keep only essential UI-only state (not data state)
    @State private var currentWorkout: TodayWorkout? = nil
    @State private var userEmail: String = UserDefaults.standard.string(forKey: "userEmail") ?? ""
    @State private var workoutSearchText: String = ""
    @State private var isRenamingWorkout = false
    @State private var renameWorkoutTitle = ""
    @State private var pendingWorkoutFeedback = false
    @FocusState private var isRenameFieldFocused: Bool
    @State private var isSavingTodayWorkout = false
    @State private var saveWorkoutToast: SaveWorkoutToast?
    @State private var actionError: String?
    
    
    
    // Properties that delegate to WorkoutManager but are accessed locally
    private var isGeneratingWorkout: Bool {
        workoutManager.isGeneratingWorkout
    }
    
    private var generationMessage: String {
        workoutManager.generationMessage
    }

    private var toolbarButtonDiameter: CGFloat { 36 }

    private var workoutSummaryBinding: Binding<CompletedWorkoutSummary?> {
        Binding(
            get: { workoutManager.completedWorkoutSummary },
            set: { newValue in
                if newValue == nil {
                    workoutManager.dismissWorkoutSummary()
                    if pendingWorkoutFeedback {
                        pendingWorkoutFeedback = false
                        showingWorkoutFeedback = true
                    } else {
                        dismiss()
                    }
                }
            }
        )
    }

    private var todayWorkoutTitle: String {
        workoutManager.todayWorkoutDisplayTitle
    }

    private var trimmedRenameWorkoutTitle: String {
        renameWorkoutTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // (helpers moved into TodayWorkoutExerciseList where they are used)
    
    private var customTargetMuscles: [String]? {
        workoutManager.customTargetMuscles
    }

    private var customEquipment: [Equipment]? {
        workoutManager.customEquipment
    }

    private var selectedMuscleType: String {
        workoutManager.muscleSelectionDisplayLabel
    }
    
    // selectedEquipmentType is now a @State property above
    
    // Deprecated keys (still needed for cleanup)
    private let sessionDurationKey = "currentWorkoutSessionDuration"
    private let sessionDateKey = "currentWorkoutSessionDate"
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
    
    private struct SaveWorkoutToast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let isError: Bool
    }

    enum WorkoutTab: String, CaseIterable, Hashable {
        case today = "Today"
        case plan = "Plan"
        case saved = "Library"

        var title: String { rawValue }
    }
    
    var body: some View {
        configuredBaseView
    }

    private var configuredBaseView: some View {
        mainBody
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationTitle("Workout")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
            .applyConditionalSearch(isEnabled: selectedWorkoutTab == .saved, text: $workoutSearchText)
            .onChange(of: selectedWorkoutTab) { _, newValue in
                if newValue != .saved {
                    workoutSearchText = ""
                }
            }
            .sheet(isPresented: $isRenamingWorkout) {
                renameWorkoutSheet
            }
            .sheet(isPresented: $showingSupersetCircuitSheet) {
                if let workout = workoutManager.todayWorkout {
                    SupersetCircuitSelectionSheet(workout: workout) { result in
                        workoutManager.applyManualBlockResult(result)
                    }
                    .environmentObject(workoutManager)
                } else {
                    Text("No workout available")
                        .font(.headline)
                        .padding()
                }
            }
            .onAppear {
                workoutManager.setModelContext(modelContext)
                workoutManager.setWorkoutViewActive(true)
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
                workoutManager.setWorkoutViewActive(false)
            }
            .onChange(of: userProfile.bodyweightOnlyWorkouts) { _, newValue in
                shouldRegenerateWorkout = true
            }
            .onChange(of: workoutManager.syncErrorMessage) { _, message in
                if let message, !message.isEmpty {
                    actionError = message
                    workoutManager.clearSyncErrorMessage()
                }
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .workoutCompletedNeedsFeedback)
                    .receive(on: RunLoop.main)
            ) { _ in
                if workoutManager.completedWorkoutSummary != nil {
                    pendingWorkoutFeedback = true
                } else {
                    showingWorkoutFeedback = true
                }
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
                    .environmentObject(workoutManager)
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
            .sheet(isPresented: $showingAddExerciseSheet) {
                addExerciseSheet
            }
            .sheet(isPresented: $showingCreateProgramSheet) {
                CreateProgramView(userEmail: userEmail)
            }
            .sheet(item: workoutSummaryBinding) { summary in
                WorkoutSummarySheet(summary: summary)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openCreateWorkout)) { _ in
                navigationPath.append(WorkoutNavigationDestination.createWorkout)
            }
            .fullScreenCover(item: $currentWorkout) { workout in
                WorkoutInProgressView(
                    isPresented: Binding(
                        get: { currentWorkout != nil },
                        set: { isPresented in
                            if !isPresented {
                                currentWorkout = nil
                                workoutManager.cancelActiveWorkout()
                            }
                        }
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
            saveWorkoutToastOverlay
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        Color("primarybg").ignoresSafeArea(.all)
    }
    
    @ViewBuilder
    private var contentStack: some View {
        VStack(spacing: 0) {
            headerSection
            sessionPhaseIndicator
            mainContentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var saveWorkoutToastOverlay: some View {
        if let toast = saveWorkoutToast {
            Text(toast.message)
                .font(.system(size: 15))
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemBackground).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 52)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 0) {
            navTabSwitcher
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if selectedWorkoutTab == .today {
                workoutControlsInHeader
                    .padding(.bottom, 12)
            }

            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .background(
            Color("primarybg")
                .ignoresSafeArea(edges: .top)
        )
        .zIndex(1)
    }
    
    // MARK: - Sheet Content Views
    
    @ViewBuilder
    private var durationPickerSheet: some View {
        WorkoutDurationPickerView(
            selectedDuration: .constant(workoutManager.effectiveDuration),
            onSetForWorkout: { newDuration in
                // Update WorkoutManager session duration
                workoutManager.setSessionDuration(newDuration)
                showingDurationPicker = false
            }
        )
    }
    
    @ViewBuilder
    private var targetMusclesPickerSheet: some View {
        TargetMusclesView(
            onSetForWorkout: { newMuscles, split in
                workoutManager.setSessionTargetMuscles(newMuscles, type: split.rawValue)
                showingTargetMusclesPicker = false
            },
            currentCustomMuscles: workoutManager.baselineCustomMuscles,
            currentMuscleType: selectedMuscleType
        )
    }
    
    @ViewBuilder
    private var equipmentPickerSheet: some View {
        TodayEquipmentPickerSheet(
            onSetForProfile: { equipment in
                // Update the active profile's equipment and regenerate workout
                workoutManager.setSessionEquipment(equipment, type: "Custom")
                showingEquipmentPicker = false
                // Force regenerate workout with new equipment
                Task {
                    await workoutManager.generateTodayWorkout(forceRegenerate: true)
                }
            },
            onSetForWorkout: { equipment in
                // Only set session equipment and regenerate (ghost edit - profile unchanged)
                workoutManager.setSessionEquipment(equipment, type: "Custom")
                showingEquipmentPicker = false
                // Force regenerate workout with new equipment
                Task {
                    await workoutManager.generateTodayWorkout(forceRegenerate: true)
                }
            }
        )
    }
    
    @ViewBuilder
    private var fitnessGoalPickerSheet: some View {
        FitnessGoalPickerView(
            selectedFitnessGoal: .constant(workoutManager.effectiveFitnessGoal),
            onSetForWorkout: { newGoal in
                workoutManager.setSessionFitnessGoal(newGoal)
                showingFitnessGoalPicker = false
            }
        )
    }
    
    @ViewBuilder
    private var fitnessLevelPickerSheet: some View {
        FitnessLevelPickerView(
            selectedFitnessLevel: .constant(workoutManager.effectiveFitnessLevel),
            onSetForWorkout: { newLevel in
                workoutManager.setSessionFitnessLevel(newLevel)
                showingFitnessLevelPicker = false
            }
        )
    }
    
    @ViewBuilder
    private var flexibilityPickerSheet: some View {
        FlexibilityPickerView(
            warmUpEnabled: .constant(effectiveFlexibilityPreferences.warmUpEnabled),
            coolDownEnabled: .constant(effectiveFlexibilityPreferences.coolDownEnabled),
            onSetForPlan: { warmUp, coolDown in
                // Update plan via ProgramService (setForPlanFlexibilityPreferences handles the API call)
                let newPrefs = FlexibilityPreferences(warmUpEnabled: warmUp, coolDownEnabled: coolDown)
                workoutManager.setForPlanFlexibilityPreferences(newPrefs)
                showingFlexibilityPicker = false
            },
            onSetForWorkout: { warmUp, coolDown in
                let newPrefs = FlexibilityPreferences(warmUpEnabled: warmUp, coolDownEnabled: coolDown)
                workoutManager.setSessionFlexibilityPreferences(newPrefs)
                showingFlexibilityPicker = false
            }
        )
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
        self.requestWorkoutGeneration()
        // Note: shouldRegenerateWorkout is reset by TodayWorkoutView after it triggers generation
    }
    
    private func clearSessionDuration() {
        workoutManager.clearAllSessionOverrides()
    }
    
    // Static method to clear session duration from anywhere in the app
    static func clearWorkoutSessionDuration() {
        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionDuration")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionDate")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutCustomMuscles")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutMuscleType")
        UserDefaults.standard.removeObject(forKey: UserProfileService.shared.scopedDefaultsKey("currentWorkoutMuscleType"))
        UserDefaults.standard.removeObject(forKey: "currentWorkoutCustomEquipment")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutEquipmentType")
        let equipmentKey = UserProfileService.shared.scopedDefaultsKey("currentWorkoutCustomEquipment")
        let typeKey = UserProfileService.shared.scopedDefaultsKey("currentWorkoutEquipmentType")
        UserDefaults.standard.removeObject(forKey: equipmentKey)
        UserDefaults.standard.removeObject(forKey: typeKey)
        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionFitnessGoal")
        UserDefaults.standard.removeObject(forKey: "currentWorkoutSessionFitnessLevel")
    }
    
    private func updateServerWorkoutDuration(email: String, durationMinutes: Int) {
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
                    // Update DataLayer cache
                    // CRITICAL FIX: Use Task { @MainActor in } to ensure DataLayer runs on main thread
                    // This prevents "Publishing changes from background threads" violations
                    Task { @MainActor in
                        let profileUpdate = ["preferred_workout_duration": durationMinutes]
                        await DataLayer.shared.updateProfileData(profileUpdate)
                    }

                case .failure:
                    // Note: We still keep the local change since UserDefaults was already updated
                    break
                }
            }
        }
    }

    private func updateServerFitnessGoal(email: String, fitnessGoal: FitnessGoal) {
        
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
                    // Update DataLayer cache
                    // CRITICAL FIX: Use Task { @MainActor in } to ensure DataLayer runs on main thread
                    Task { @MainActor in
                        let profileUpdate = ["preferred_fitness_goal": fitnessGoal.rawValue]
                        await DataLayer.shared.updateProfileData(profileUpdate)
                    }

                case .failure:
                    // Note: We still keep the local change since UserDefaults was already updated
                    break
                }
            }
        }
    }

    private func updateServerFitnessLevel(email: String, fitnessLevel: ExperienceLevel) {
        
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
                    // Update DataLayer cache
                    // CRITICAL FIX: Use Task { @MainActor in } to ensure DataLayer runs on main thread
                    Task { @MainActor in
                        let profileUpdate = ["experience_level": fitnessLevel.rawValue]
                        await DataLayer.shared.updateProfileData(profileUpdate)
                    }

                case .failure:
                    // Note: We still keep the local change since UserDefaults was already updated
                    break
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var navTabSwitcher: some View {
        Picker("Workout Tab", selection: $selectedWorkoutTab) {
            ForEach(WorkoutTab.allCases, id: \.self) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var workoutControlsInHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if hasSessionModifications {
                    Button(action: {
                        workoutManager.clearAllSessionOverrides()
                        self.requestWorkoutGeneration()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
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

                ForEach(orderedButtons, id: \.self) { button in
                    buttonView(for: button)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
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
                
                // Use workout manager display label (default-aware)
                Text(workoutManager.muscleSelectionDisplayLabel)
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
    
    @ViewBuilder
    private var mainContentView: some View {
        switch selectedWorkoutTab {
        case .today:
            todayTabContent
        case .plan:
            planTabContent
        case .saved:
            workoutsTabContent
        }
    }

    @ViewBuilder
    private var planTabContent: some View {
        PlanView()
    }

    @ViewBuilder
    private var todayTabContent: some View {
        if isGeneratingWorkout {
            VStack {
                ModernWorkoutLoadingView(message: generationMessage)
                    .transition(.opacity.combined(with: .scale))
                    .id("loading") // Force view refresh
                Spacer()
            }
        } else {
            TodayWorkoutView(
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
                showAddExerciseSheet: $showingAddExerciseSheet,
                onPresentLogSheet: onPresentLogSheet,
                onRefresh: {
                    HapticFeedback.generate()
                    self.requestWorkoutGeneration()
                },
                onRenameWorkout: {
                    HapticFeedback.generate()
                    renameWorkoutTitle = workoutManager.todayWorkoutDisplayTitle
                    isRenamingWorkout = workoutManager.todayWorkout != nil
                },
                onSaveWorkout: handleSaveTodayWorkout,
                canShowSupersetMenu: userProfileService.circuitsAndSupersetsEnabled && (workoutManager.todayWorkout?.exercises.count ?? 0) >= 2,
                onShowSuperset: {
                    HapticFeedback.generate()
                    showingSupersetCircuitSheet = true
                },
                onStartWorkout: { workout in
                    handleStartTodayWorkout(workout)
                }
            )
            .transition(.opacity.combined(with: .scale))
        }
    }

    @ViewBuilder
    private var workoutsTabContent: some View {
        VStack {
            RoutinesWorkoutView(
                navigationPath: $navigationPath,
                workoutManager: workoutManager,
                searchText: $workoutSearchText,
                currentWorkout: $currentWorkout,
                onCustomWorkoutStart: { workout, completion in
                    handleStartCustomWorkout(workout, onSuccess: completion)
                }
            )
            .padding(.top)
            Spacer()
        }
    }

    private func handleSaveTodayWorkout() {
        HapticFeedback.generate()

        guard !isSavingTodayWorkout else { return }

        guard let todayWorkout = workoutManager.todayWorkout else {
            Task {
                await presentSaveWorkoutToast(isError: true, message: "No workout available to save.")
            }
            return
        }

        guard !todayWorkout.exercises.isEmpty else {
            let title = todayWorkout.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let descriptor = title.isEmpty ? "this workout" : "\"\(title)\""
            Task {
                await presentSaveWorkoutToast(isError: true, message: "Add at least one exercise to \(descriptor) before saving.")
            }
            return
        }

        isSavingTodayWorkout = true

        Task {
            do {
                _ = try await workoutManager.saveTodayWorkoutAsCustom()
                await presentSaveWorkoutToast(isError: false)
            } catch {
                let message = error.localizedDescription.isEmpty
                    ? "Couldn't save workout. Please try again."
                    : error.localizedDescription
                await presentSaveWorkoutToast(isError: true, message: message)
            }

            await MainActor.run {
                isSavingTodayWorkout = false
            }
        }
    }

    @MainActor
    private func presentSaveWorkoutToast(isError: Bool, message: String? = nil) {
        let displayMessage: String
        if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayMessage = message
        } else {
            displayMessage = isError ? "Couldn't save workout" : "Workout saved"
        }

        let toast = SaveWorkoutToast(message: displayMessage, isError: isError)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            saveWorkoutToast = toast
        }

        Task { @MainActor [toastID = toast.id] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if saveWorkoutToast?.id == toastID {
                withAnimation(.easeOut(duration: 0.25)) {
                    saveWorkoutToast = nil
                }
            }
        }
    }
    
    private func resolvedUserEmail() -> String? {
        if !onboarding.email.isEmpty {
            return onboarding.email
        }
        if !userEmail.isEmpty {
            return userEmail
        }
        if let stored = UserDefaults.standard.string(forKey: "userEmail"), !stored.isEmpty {
            userEmail = stored
            return stored
        }
        return nil
    }

    private func ensureUserDefaultsEmail(_ email: String) {
        let current = UserDefaults.standard.string(forKey: "userEmail")
        if current != email {
            UserDefaults.standard.set(email, forKey: "userEmail")
        }
    }

    private func guardWorkoutQuota(onAllowed: @escaping () -> Void) {
        // Paywall active - all users have full access
        WorkoutDataManager.shared.clearRateLimitCooldown(trigger: "paywall_active")
        onAllowed()
    }

    private func handleStartTodayWorkout(_ workout: TodayWorkout, onSuccess: (() -> Void)? = nil) {
        guardWorkoutQuota {
            HapticFeedback.generate()
            workoutManager.startWorkout(workout)
            currentWorkout = workoutManager.currentWorkout ?? workout
            onSuccess?()
        }
    }

    private func handleStartCustomWorkout(_ workout: Workout, onSuccess: @escaping () -> Void = {}) {
        guardWorkoutQuota {
            HapticFeedback.generate()
            let todayWorkout = workoutManager.startCustomWorkout(workout)
            currentWorkout = workoutManager.currentWorkout ?? todayWorkout
            onSuccess()
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
                        .foregroundColor(.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                switch selectedWorkoutTab {
                case .today:
                    NavigationLink(destination: WorkoutProfileSettingsView()) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: toolbarButtonDiameter, height: toolbarButtonDiameter)
                            .contentShape(Circle())
                    }
                case .plan:
                    Menu {
                        Button {
                            HapticFeedback.generate()
                            navigationPath.append(WorkoutNavigationDestination.createWorkout)
                        } label: {
                            Label("Workout", systemImage: "dumbbell")
                        }

                        Button {
                            HapticFeedback.generate()
                            showingCreateProgramSheet = true
                        } label: {
                            Label("Plan", systemImage: "calendar")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                case .saved:
                    if #available(iOS 26, *) {
                        Button("New") {
                            HapticFeedback.generate()
                            navigationPath.append(WorkoutNavigationDestination.createWorkout)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    } else {
                        EmptyView()
                    }
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
                    blocks: current.blocks,
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
        switch goal.normalized {
        case .strength: return 105  // midpoint of 90–120s
        case .hypertrophy: return 60
        case .circuitTraining: return 30
        case .powerlifting: return 150 // midpoint of 120–180s
        case .olympicWeightlifting: return 240
        case .general: return 75
        default: return 75
        }
    }

    // MARK: - Rename Workout Sheet
    private var renameWorkoutSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $renameWorkoutTitle)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .focused($isRenameFieldFocused)
                }
            }
            .navigationTitle("Rename Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isRenamingWorkout = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let newTitle = trimmedRenameWorkoutTitle
                        guard !newTitle.isEmpty else { return }
                        workoutManager.renameTodayWorkout(to: newTitle)
                        renameWorkoutTitle = newTitle
                        isRenamingWorkout = false
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    .disabled(trimmedRenameWorkoutTitle.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    isRenameFieldFocused = true
                }
            }
            .onDisappear {
                isRenameFieldFocused = false
            }
        }
    }

}
    
    // MARK: - Flexibility Preferences Methods
    
    // loadSessionFlexibilityPreferences removed - now handled by WorkoutManager.loadSessionData()
    
    // clearSessionFlexibilityPreferences removed - now handled by WorkoutManager.clearAllSessionOverrides()
    

// MARK: - Today Workout View

private struct TodayWorkoutView: View {
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
    let onPresentLogSheet: (LogExerciseSheetContext) -> Void
    let onRefresh: () -> Void
    let onRenameWorkout: () -> Void
    let onSaveWorkout: () -> Void
    let canShowSupersetMenu: Bool
    let onShowSuperset: () -> Void
    let onStartWorkout: (TodayWorkout) -> Void
    
    
    @State private var userProfile = UserProfileService.shared
    @State private var showSessionPhaseCard = false // Hidden due to sync issues
    
    // Get the workout to display
    private var workoutToShow: TodayWorkout? {
        let workout = workoutManager.todayWorkout
        print("🎯 [TodayWorkoutView] workoutToShow accessed: title='\(workout?.title ?? "nil")', programDayId=\(workout?.programDayId ?? -1)")
        return workout
    }

    var body: some View {
        let _ = print("🎯 [TodayWorkoutView] body rendering, todayWorkout.title='\(workoutManager.todayWorkout?.title ?? "nil")'")
        content
            .background(Color("primarybg").ignoresSafeArea(edges: [.top, .horizontal]))
            .overlay(alignment: .bottom) {
                if let workout = workoutManager.todayWorkout {
                    HStack {
                        Button(action: { onStartWorkout(workout) }) {
                            Text("Start Workout")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .onAppear {
                loadOrGenerateTodayWorkout()
            }
            .onChange(of: shouldRegenerate) { _, newValue in
                if newValue {
                    requestTodayWorkoutGeneration()
                    shouldRegenerate = false
                }
            }
            .onChange(of: selectedDuration) { _, newDuration in
                requestTodayWorkoutGeneration()
            }
            .onChange(of: customTargetMuscles) { _, newMuscles in
                requestTodayWorkoutGeneration()
            }
            .onChange(of: effectiveFlexibilityPreferences) { _, newPreferences in
                requestTodayWorkoutGeneration()
            }
            .onChange(of: customEquipment) { _, newEquipment in
                requestTodayWorkoutGeneration()
            }
            .onChange(of: effectiveFitnessGoal) { _, newGoal in
                requestTodayWorkoutGeneration()
            }
            .onChange(of: effectiveFitnessLevel) { _, newLevel in
                requestTodayWorkoutGeneration()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let workout = workoutToShow {
            VStack(spacing: 12) {
                if let dynamicParams = workoutManager.dynamicParameters, showSessionPhaseCard {
                    DynamicSessionPhaseView(
                        sessionPhase: dynamicParams.sessionPhase,
                        workoutCount: calculateWorkoutCountInPhase()
                    )
                    .padding(.horizontal)
                }

                TodayWorkoutExerciseList(
                    workout: workout,
                    navigationPath: $navigationPath,
                    onExerciseReplacementCallbackSet: onExerciseReplacementCallbackSet,
                    onExerciseUpdateCallbackSet: onExerciseUpdateCallbackSet,
                    showAddExerciseSheet: $showAddExerciseSheet,
                    onPresentLogSheet: onPresentLogSheet,
                    onRefresh: onRefresh,
                    onRenameWorkout: onRenameWorkout,
                    onSaveWorkout: onSaveWorkout,
                    canShowSupersetMenu: canShowSupersetMenu,
                    onShowSuperset: onShowSuperset
                )
            }
        } else {
            WorkoutSkeletonPlaceholderView()
                .padding(.top, 32)
            Spacer()
        }
    }

    private func loadOrGenerateTodayWorkout() {
        // CRITICAL: Don't regenerate if in error state to prevent infinite loop
        if workoutManager.generationError != nil {
            return
        }

        // Ensure we only surface the logging sheet when a workout is in progress
        currentWorkout = nil

        // Program workouts are now synced reactively via ProgramService observer
        // Just ensure we have SOME workout (program or generated)
        if workoutManager.todayWorkout == nil {
            Task {
                await workoutManager.generateTodayWorkout()
            }
        }
    }

    private func requestTodayWorkoutGeneration() {
        guard !workoutManager.isGeneratingWorkout else {
            return
        }
        Task {
            // Force regenerate because this is triggered by user preference changes
            await workoutManager.generateTodayWorkout(forceRegenerate: true)
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
        } else {
            // Get recovery-optimized muscle groups
            let recoveryOptimizedMuscles = recommendationService.getRecoveryOptimizedWorkout(targetMuscleCount: 4)

            if recoveryOptimizedMuscles.count >= 3 {
                // Use recovery-optimized selection
                muscleGroups = recoveryOptimizedMuscles
            } else {
                // Fallback to goal-based selection
                switch fitnessGoal.normalized {
                case .strength, .powerlifting:
                    muscleGroups = ["Chest", "Back", "Shoulders", "Quadriceps", "Glutes"]
                case .hypertrophy:
                    muscleGroups = ["Chest", "Back", "Shoulders", "Biceps", "Triceps"]
                case .circuitTraining:
                    muscleGroups = ["Chest", "Back", "Quadriceps", "Abs"]
                default:
                    muscleGroups = ["Chest", "Back", "Shoulders", "Quadriceps"]
                }
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
        
        // Generate warm-up exercises if enabled (using intelligent workout-aware algorithm)
        let warmUpExercises: [TodayWorkoutExercise]?
        if effectiveFlexibilityPreferences.warmUpEnabled {
            // Use intelligent warmup that analyzes workout exercises to select appropriate exercises
            warmUpExercises = recommendationService.getIntelligentWarmupExercises(
                workoutExercises: workoutPlan.exercises,
                customEquipment: customEquipment,
                includeFoamRolling: effectiveFlexibilityPreferences.includeFoamRolling,
                totalCount: 4
            )
        } else {
            warmUpExercises = nil
        }

        // Generate cool-down exercises if enabled (using intelligent fatigue-prioritized algorithm)
        let coolDownExercises: [TodayWorkoutExercise]?
        if effectiveFlexibilityPreferences.coolDownEnabled {
            // Use intelligent cooldown that prioritizes stretches for most fatigued muscles
            coolDownExercises = recommendationService.getIntelligentCooldownExercises(
                workoutExercises: workoutPlan.exercises,
                customEquipment: customEquipment,
                totalCount: 3
            )
        } else {
            coolDownExercises = nil
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
        let goal = goal.normalized
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
            
        case .circuitTraining:
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
            
        case .olympicWeightlifting:
            baseParams = WorkoutParameters(
                percentageOneRM: 80...95,
                repRange: 1...5,
                repDurationSeconds: 3...5,
                setsPerExercise: 4...8,
                restBetweenSetsSeconds: 180...300,
                compoundSetupSeconds: 30,
                isolationSetupSeconds: 10,
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
            
            return LogWorkoutPlan(
                exercises: generatedPlan.exercises,
                actualDurationMinutes: generatedPlan.actualDurationMinutes,
                totalTimeBreakdown: breakdown
            )
            
        } catch {
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
            }
        }
        return 1
    }
}



private struct RoutinesWorkoutView: View {
    @Binding var navigationPath: NavigationPath
    @ObservedObject var workoutManager: WorkoutManager
    @Binding var searchText: String
    @Binding var currentWorkout: TodayWorkout?
    let onCustomWorkoutStart: (Workout, @escaping () -> Void) -> Void

    @State private var selectedWorkout: Workout?

    private var workouts: [Workout] {
        workoutManager.customWorkouts
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !normalizedSearchText.isEmpty
    }

    private var filteredWorkouts: [Workout] {
        guard isSearching else { return workouts }
        return workouts.filter { workout in
            workout.displayName.localizedCaseInsensitiveContains(normalizedSearchText)
        }
    }

    private var pinnedFilteredWorkouts: [Workout] {
        filteredWorkouts.filter { workoutManager.isCustomWorkoutPinned($0) }
    }

    private var regularFilteredWorkouts: [Workout] {
        filteredWorkouts.filter { !workoutManager.isCustomWorkoutPinned($0) }
    }

    private var showsEmptyState: Bool {
        !workoutManager.isLoadingWorkouts && workouts.isEmpty && !isSearching
    }

    private var showsSearchEmptyState: Bool {
        !workoutManager.isLoadingWorkouts && filteredWorkouts.isEmpty && isSearching
    }

    var body: some View {
        List {
            if let errorMessage = workoutManager.customWorkoutsError?.trimmingCharacters(in: .whitespacesAndNewlines),
               !errorMessage.isEmpty {
                errorBanner(message: errorMessage)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
                    .listRowSeparator(.hidden)
            }

            if workoutManager.isLoadingWorkouts && workouts.isEmpty {
                loadingState
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
            } else if showsEmptyState {
                emptyState
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
            } else if showsSearchEmptyState {
                searchEmptyState
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
            } else {
                if isSearching {
                    workoutListSection(for: filteredWorkouts)
                } else {
                    workoutListSection(for: pinnedFilteredWorkouts)
                    workoutListSection(for: regularFilteredWorkouts)
                }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .background(Color("primarybg"))
        .safeAreaInset(edge: .bottom) {
            if #available(iOS 26, *) {
                EmptyView()
            } else {
                floatingNewWorkoutButton
            }
        }
        .task {
            await workoutManager.fetchCustomWorkouts()
        }
        .refreshable {
            await workoutManager.fetchCustomWorkouts(force: true)
        }
        .fullScreenCover(item: $selectedWorkout) { workout in
            WorkoutDetailFullScreenView(
                workout: workout,
                onDismiss: {
                    selectedWorkout = nil
                },
                onStart: { updatedWorkout in
                    onCustomWorkoutStart(updatedWorkout) {
                        selectedWorkout = nil
                    }
                },
                onRefreshWorkouts: {
                    Task { await workoutManager.fetchCustomWorkouts(force: true) }
                }
            )
            .environmentObject(workoutManager)
        }
    }

    private var floatingNewWorkoutButton: some View {
        Button(action: {
            HapticFeedback.generate()
            navigationPath.append(WorkoutNavigationDestination.createWorkout)
        }) {
            Text("New Workout")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .cornerRadius(100)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func workoutListSection(for source: [Workout]) -> some View {
        if !source.isEmpty {
            ForEach(source, id: \.id) { workout in
                workoutRow(for: workout)
            }
            .onDelete { offsets in
                deleteWorkouts(at: offsets, in: source)
            }
        }
    }

    private func workoutRow(for workout: Workout) -> some View {
        WorkoutCard(
            workout: workout,
            durationMinutes: workout.duration ?? estimatedDuration(for: workout),
            onStart: {
                onCustomWorkoutStart(workout) {}
            },
            onEdit: {
                HapticFeedback.generate()
                navigationPath.append(WorkoutNavigationDestination.editWorkout(workout))
            },
            onDuplicate: {
                duplicateWorkout(workout)
            },
            onDelete: {
                Task { await workoutManager.deleteCustomWorkout(id: workout.id) }
            },
            onPin: {
                Task {
                    HapticFeedback.generate()
                    await workoutManager.pinCustomWorkout(workout)
                }
            },
            onUnpin: {
                Task {
                    HapticFeedback.generate()
                    await workoutManager.unpinCustomWorkout(workout)
                }
            },
            isPinned: workoutManager.isCustomWorkoutPinned(workout),
            onView: {
                selectedWorkout = workout
            }
        )
        .listRowBackground(Color("primarybg"))
        // spacingg
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.1)
            Text("Loading workouts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 32)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("blackex")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 220, maxHeight: 220)

            Text("Build your perfect workout")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Create routines, track progress, and stay consistent. Once you add workouts, they'll show up here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 24)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(.secondary)

            Text("No workouts match your search.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 32)
    }

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.85))
        .cornerRadius(16)
    }

    private func estimatedDuration(for workout: Workout) -> Int {
        let totalSets = max(workout.totalSets, 1)
        let estimate = Int(ceil(Double(totalSets) * 1.5))
        return max(10, min(estimate, 150))
    }

    private func deleteWorkouts(at offsets: IndexSet, in source: [Workout]) {
        let ids = offsets.compactMap { index -> Int? in
            guard index < source.count else { return nil }
            return source[index].id
        }

        guard !ids.isEmpty else { return }

        Task {
            for id in ids {
                await workoutManager.deleteCustomWorkout(id: id)
            }
        }
    }

    private func duplicateWorkout(_ workout: Workout) {
        Task {
            HapticFeedback.generate()
            await workoutManager.duplicateCustomWorkout(from: workout)
        }
    }
}

private struct WorkoutCard: View {
    let workout: Workout
    let durationMinutes: Int
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onPin: () -> Void
    let onUnpin: () -> Void
    let isPinned: Bool
    let onView: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Text(workout.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Menu {
                    if isPinned {
                        Button(action: onUnpin) {
                            Label("Unpin Workout", systemImage: "pin.slash")
                        }
                    } else {
                        Button(action: onPin) {
                            Label("Pin Workout", systemImage: "pin")
                        }
                    }

                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action: onDuplicate) {
                        Label("Duplicate", systemImage: "square.on.square")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 25, height: 25)
                        .background(Circle().fill(Color(.systemBackground)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Workout options")
            }

            Text("\(durationMinutes) min • \(workout.exercises.count) exercises")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)

            HStack {
                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start workout")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 12)

        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color("containerbg"))
        .cornerRadius(24)
        .contentShape(Rectangle())
        .onTapGesture(perform: onView)
    }
}

private struct WorkoutDetailFullScreenView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager

    let onDismiss: () -> Void
    let onStart: (Workout) -> Void
    let onRefreshWorkouts: () -> Void

    @State private var displayWorkout: Workout
    @State private var todayExercises: [TodayWorkoutExercise]
    @State private var workoutBlocks: [WorkoutBlock]?
    @State private var loggingSelection: LoggingSelection?
    @State private var showingRenameSheet = false
    @State private var renameText: String
    @State private var isRenaming = false
    @State private var renameError: String?
    @State private var actionError: String?
    @State private var showingSupersetSheet = false
    @State private var isPerformingAction = false

    struct LoggingSelection: Identifiable {
        let id: UUID
        let index: Int
        var exercise: TodayWorkoutExercise

        init(index: Int, exercise: TodayWorkoutExercise, id: UUID = UUID()) {
            self.id = id
            self.index = index
            self.exercise = exercise
        }
    }

    init(
        workout: Workout,
        onDismiss: @escaping () -> Void,
        onStart: @escaping (Workout) -> Void,
        onRefreshWorkouts: @escaping () -> Void
    ) {
        self.onDismiss = onDismiss
        self.onStart = onStart
        self.onRefreshWorkouts = onRefreshWorkouts
        _displayWorkout = State(initialValue: workout)
        let exercises = WorkoutDetailFullScreenView.makeTodayExercises(from: workout)
        _todayExercises = State(initialValue: exercises)
        _workoutBlocks = State(initialValue: workout.blocks)
        _renameText = State(initialValue: workout.name)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color("primarybg")
                    .ignoresSafeArea()

                if todayExercises.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header
                                .padding(.horizontal, 20)
                            exerciseGroupsContent
                        }
                        .padding(.top, 28)
                        .padding(.bottom, 120)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(displayWorkout.displayName)
                        .font(.system(size: 17, weight: .semibold))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if isWorkoutPinned {
                            Button(action: unpinWorkout) {
                                Label("Unpin Workout", systemImage: "pin.slash")
                            }
                        } else {
                            Button(action: pinWorkout) {
                                Label("Pin Workout", systemImage: "pin")
                            }
                        }

                        Button(action: presentRenameSheet) {
                            Label("Rename Workout", systemImage: "pencil")
                        }

                        Button(action: duplicateWorkout) {
                            Label("Duplicate Workout", systemImage: "square.on.square")
                        }

                        Button(action: { showingSupersetSheet = true }) {
                            Label("Build superset/circuit", systemImage: "arrow.left.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: startWorkout) {
                Text("Start Workout")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .sheet(item: $loggingSelection) { selection in
            ExerciseLoggingView(
                exercise: selection.exercise,
                allExercises: todayExercises,
                onExerciseReplaced: { newExercise in
                    let replaced = makeReplacementExercise(from: newExercise, base: selection.exercise)
                    updateExercise(at: selection.index, with: replaced)
                    loggingSelection = LoggingSelection(index: selection.index, exercise: replaced, id: selection.id)
                },
                onWarmupSetsChanged: nil,
                onExerciseUpdated: { updatedExercise in
                    updateExercise(at: selection.index, with: updatedExercise)
                    loggingSelection = LoggingSelection(index: selection.index, exercise: updatedExercise, id: selection.id)
                }
            )
        }
        .sheet(isPresented: $showingRenameSheet) {
            renameSheet
        }
        .sheet(isPresented: $showingSupersetSheet) {
            supersetSheet
        }
        .alert("Something went wrong", isPresented: Binding<Bool>(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) {
                actionError = nil
            }
        } message: {
            Text(actionError ?? "Please try again later.")
        }
        .overlay {
            if isPerformingAction {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    ProgressView()
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let notes = displayWorkout.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var estimatedDuration: Int {
        displayWorkout.duration ?? max(Int(ceil(Double(max(displayWorkout.totalSets, 1)) * 1.5)), 10)
    }

    private var isWorkoutPinned: Bool {
        workoutManager.isCustomWorkoutPinned(displayWorkout)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 52, weight: .regular))
                .foregroundColor(.secondary)

            Text("This workout has no exercises yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            Button("Add exercises") {
                showingSupersetSheet = true
            }
            .font(.system(size: 16, weight: .semibold))
        }
        .padding(.horizontal, 24)
    }

    private var supersetSheet: some View {
        SupersetCircuitSelectionSheet(workout: supersetWorkoutRepresentation) { result in
            todayExercises = result.workout.exercises
            workoutBlocks = result.workout.blocks
            syncWorkoutExercises()
            persistCurrentWorkout(showLoader: false)
        }
    }

    private var supersetWorkoutRepresentation: TodayWorkout {
        TodayWorkout(
            id: UUID(),
            date: Date(),
            title: displayWorkout.displayName,
            exercises: todayExercises,
            blocks: workoutBlocks ?? displayWorkout.blocks,
            estimatedDuration: estimatedDuration,
            fitnessGoal: workoutManager.effectiveFitnessGoal,
            difficulty: 2
        )
    }

    @ViewBuilder
    private var exerciseGroupsContent: some View {
        if supersetBlocks.isEmpty {
            exerciseGroupCard(entries: uniqueExerciseEntries)
        } else {
            if !nonGroupedEntries.isEmpty {
                exerciseGroupCard(entries: nonGroupedEntries)
            }

            ForEach(Array(supersetBlocks.enumerated()), id: \.element.id) { _, block in
                let entries = blockEntries(for: block)
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(blockLabel(for: block))
                            .font(.title3)
                            .foregroundColor(.primary)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)

                        exerciseGroupCard(entries: entries)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseGroupCard(entries: [(TodayWorkoutExercise, Int)]) -> some View {
        if entries.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.1) { idx, entry in
                    let exercise = entry.0
                    let globalIndex = entry.1
                    ExerciseWorkoutCard(
                        exercise: exercise,
                        allExercises: todayExercises,
                        exerciseIndex: globalIndex,
                        onExerciseReplaced: { _, newExercise in
                            replaceExercise(at: globalIndex, with: newExercise)
                        },
                        onOpen: {
                            openLogging(for: globalIndex)
                        },
                        useBackground: false
                    )

                    if idx != entries.count - 1 {
                        Divider()
                            .padding(.leading, 92)  // Align with text after thumbnail
                    }
                }
            }
        }
    }

    private var uniqueExerciseEntries: [(TodayWorkoutExercise, Int)] {
        var seen = Set<Int>()
        return todayExercises.enumerated().compactMap { index, exercise in
            guard seen.insert(exercise.exercise.id).inserted else { return nil }
            return (exercise, index)
        }
    }

    private var nonGroupedEntries: [(TodayWorkoutExercise, Int)] {
        var seen = Set<Int>()
        var results: [(TodayWorkoutExercise, Int)] = []

        for (index, exercise) in todayExercises.enumerated() {
            let id = exercise.exercise.id
            guard !groupedExerciseIds.contains(id) else { continue }
            if seen.insert(id).inserted {
                results.append((exercise, index))
            }
        }

        return results
    }

    private var currentBlocks: [WorkoutBlock] {
        if let workoutBlocks {
            return workoutBlocks
        }

        if let storedBlocks = displayWorkout.blocks {
            return storedBlocks
        }

        let fallbackWorkout = TodayWorkout(
            id: UUID(),
            date: Date(),
            title: displayWorkout.displayName,
            exercises: todayExercises,
            estimatedDuration: estimatedDuration,
            fitnessGoal: workoutManager.effectiveFitnessGoal,
            difficulty: 2
        )

        return fallbackWorkout.blockProgram
    }

    private var supersetBlocks: [WorkoutBlock] {
        currentBlocks.filter { ($0.type == .superset || $0.type == .circuit) && $0.exercises.count >= 2 }
    }

    private var groupedExerciseIds: Set<Int> {
        Set(supersetBlocks.flatMap { $0.exercises.map { $0.exercise.id } })
    }

    private var exerciseIndicesById: [Int: [Int]] {
        var mapping: [Int: [Int]] = [:]
        for (index, exercise) in todayExercises.enumerated() {
            mapping[exercise.exercise.id, default: []].append(index)
        }
        return mapping
    }

    private func blockEntries(for block: WorkoutBlock) -> [(TodayWorkoutExercise, Int)] {
        var occurrenceCursor: [Int: Int] = [:]
        var entries: [(TodayWorkoutExercise, Int)] = []

        for blockExercise in block.exercises {
            let id = blockExercise.exercise.id
            let occurrence = occurrenceCursor[id, default: 0]
            if let indices = exerciseIndicesById[id], occurrence < indices.count {
                let globalIndex = indices[occurrence]
                entries.append((todayExercises[globalIndex], globalIndex))
            }
            occurrenceCursor[id] = occurrence + 1
        }
        return entries
    }

    private func blockLabel(for block: WorkoutBlock) -> String {
        block.exercises.count >= 3 ? "Circuit" : "Superset"
    }

    private func openLogging(for index: Int) {
        guard todayExercises.indices.contains(index) else { return }
        loggingSelection = LoggingSelection(index: index, exercise: todayExercises[index])
    }

    private func startWorkout() {
        onDismiss()
        syncWorkoutExercises()
        onStart(displayWorkout)
    }

    private func presentRenameSheet() {
        renameText = displayWorkout.name
        renameError = nil
        showingRenameSheet = true
    }

    private func duplicateWorkout() {
        syncWorkoutExercises()
        HapticFeedback.generate()
        persistDuplication()
    }

    private func pinWorkout() {
        Task {
            HapticFeedback.generate()
            await workoutManager.pinCustomWorkout(displayWorkout)
            await MainActor.run {
                onRefreshWorkouts()
            }
        }
    }

    private func unpinWorkout() {
        Task {
            HapticFeedback.generate()
            await workoutManager.unpinCustomWorkout(displayWorkout)
            await MainActor.run {
                onRefreshWorkouts()
            }
        }
    }

    private func replaceExercise(at index: Int, with data: ExerciseData) {
        guard todayExercises.indices.contains(index) else { return }
        let previous = todayExercises[index]
        let replacement = makeReplacementExercise(from: data, base: previous)
        todayExercises[index] = replacement
        updateBlocksReplacing(oldId: previous.exercise.id, with: data)
        syncWorkoutExercises()
    }

    private func updateExercise(at index: Int, with updatedExercise: TodayWorkoutExercise) {
        guard todayExercises.indices.contains(index) else { return }
        todayExercises[index] = updatedExercise
        syncWorkoutExercises()
    }

    private func syncWorkoutExercises() {
        let existing = displayWorkout.exercises
        let converted = todayExercises.enumerated().map { index, exercise in
            convertToWorkoutExercise(exercise, existing: existing.indices.contains(index) ? existing[index] : nil)
        }
        displayWorkout = updatedWorkout(exercises: converted)
    }

    private func persistCurrentWorkout(showLoader: Bool = true) {
        let persistenceTask: () async throws -> Void = {
            _ = try await workoutManager.saveCustomWorkout(
                name: displayWorkout.name,
                exercises: displayWorkout.exercises,
                notes: displayWorkout.notes,
                workoutId: displayWorkout.id,
                blocks: workoutBlocks
            )
            await MainActor.run {
                onRefreshWorkouts()
            }
        }

        if showLoader {
            performAsyncAction(persistenceTask)
        } else {
            Task {
                do {
                    try await persistenceTask()
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            actionError = error.localizedDescription
                        }
                    }
                }
            }
        }
    }

    private func persistDuplication() {
        performAsyncAction {
            await workoutManager.duplicateCustomWorkout(from: displayWorkout)
        }
    }

    private func updatedWorkout(name: String? = nil, exercises: [WorkoutExercise]? = nil) -> Workout {
        Workout(
            id: displayWorkout.id,
            remoteId: displayWorkout.remoteId,
            name: name ?? displayWorkout.name,
            date: displayWorkout.date,
            duration: displayWorkout.duration,
            exercises: exercises ?? displayWorkout.exercises,
            notes: displayWorkout.notes,
            category: displayWorkout.category,
            isTemplate: displayWorkout.isTemplate,
            syncVersion: displayWorkout.syncVersion,
            createdAt: displayWorkout.createdAt,
            updatedAt: displayWorkout.updatedAt,
            blocks: workoutBlocks ?? displayWorkout.blocks
        )
    }

    private func convertToWorkoutExercise(_ exercise: TodayWorkoutExercise, existing: WorkoutExercise?) -> WorkoutExercise {
        let baseLegacy = existing?.exercise
        let legacy = makeLegacyExercise(from: exercise.exercise, fallback: baseLegacy)

        let durationValue: Int?
        if let tracking = exercise.trackingType,
           let duration = exercise.flexibleSets?.first?.duration,
           tracking == .timeOnly || tracking == .holdTime {
            durationValue = Int(duration)
        } else {
            durationValue = nil
        }

        let generatedSets: [WorkoutSet] = (0..<max(exercise.sets, 1)).map { index in
            let existingSet = existing?.sets.indices.contains(index) == true ? existing!.sets[index] : nil
            return WorkoutSet(
                id: existingSet?.id ?? (index + 1),
                reps: exercise.reps,
                weight: exercise.weight,
                duration: durationValue,
                distance: nil,
                restTime: exercise.restTime
            )
        }

        return WorkoutExercise(
            id: existing?.id ?? Int.random(in: 1000...9999),
            exercise: legacy,
            sets: generatedSets,
            notes: exercise.notes
        )
    }

    private func makeLegacyExercise(from data: ExerciseData, fallback: LegacyExercise?) -> LegacyExercise {
        if let fallback, fallback.id == data.id {
            return fallback
        }

        return LegacyExercise(
            id: data.id,
            name: data.name,
            category: data.category,
            description: data.synergist.isEmpty ? fallback?.description : data.synergist,
            instructions: data.instructions ?? fallback?.instructions
        )
    }

    private func updateBlocksReplacing(oldId: Int, with newExercise: ExerciseData) {
        guard var blocks = workoutBlocks else { return }
        var hasChanges = false

        for index in blocks.indices {
            var block = blocks[index]
            var blockChanged = false

            block.exercises = block.exercises.map { blockExercise in
                guard blockExercise.exercise.id == oldId else { return blockExercise }
                blockChanged = true
                return BlockExercise(
                    id: blockExercise.id,
                    exercise: newExercise,
                    schemeType: blockExercise.schemeType,
                    repScheme: blockExercise.repScheme,
                    intervalScheme: blockExercise.intervalScheme
                )
            }

            if blockChanged {
                blocks[index] = block
                hasChanges = true
            }
        }

        if hasChanges {
            workoutBlocks = blocks
        }
    }

    private func makeReplacementExercise(from data: ExerciseData, base: TodayWorkoutExercise) -> TodayWorkoutExercise {
        TodayWorkoutExercise(
            exercise: data,
            sets: base.sets,
            reps: base.reps,
            weight: base.weight,
            restTime: base.restTime,
            notes: base.notes,
            warmupSets: base.warmupSets,
            flexibleSets: base.flexibleSets,
            trackingType: base.trackingType
        )
    }

    private func performAsyncAction(_ action: @escaping () async throws -> Void) {
        guard !isPerformingAction else { return }
        actionError = nil
        isPerformingAction = true
        Task {
            defer {
                Task { @MainActor in isPerformingAction = false }
            }

            do {
                try await action()
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        actionError = error.localizedDescription
                    }
                }
            }
        }
    }

    private var renameSheet: some View {
        NavigationStack {
            Form {
                Section("Workout Name") {
                    TextField("Name", text: $renameText)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)

                    if let renameError {
                        Text(renameError)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .disabled(isRenaming)
            .overlay {
                if isRenaming {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        ProgressView()
                            .padding(20)
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                    }
                }
            }
            .navigationTitle("Rename Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingRenameSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        performRename()
                    }
                    .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRenaming)
                }
            }
        }
    }

    private func performRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            renameError = "Please enter a workout name."
            return
        }

        isRenaming = true
        Task {
            defer {
                Task { @MainActor in isRenaming = false }
            }

            do {
                syncWorkoutExercises()
                _ = try await workoutManager.saveCustomWorkout(
                    name: trimmed,
                    exercises: displayWorkout.exercises,
                    notes: displayWorkout.notes,
                    workoutId: displayWorkout.id,
                    blocks: workoutBlocks
                )

                await MainActor.run {
                    displayWorkout = updatedWorkout(name: trimmed)
                    showingRenameSheet = false
                    renameError = nil
                    onRefreshWorkouts()
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        renameError = error.localizedDescription
                    }
                }
            }
        }
    }

    private static func makeTodayExercises(from workout: Workout) -> [TodayWorkoutExercise] {
        workout.exercises.map { exercise in
            let firstSet = exercise.sets.first

            let exerciseData = ExerciseData(
                id: exercise.exercise.id,
                name: exercise.exercise.name,
                exerciseType: exercise.exercise.category,
                bodyPart: exercise.exercise.category,
                equipment: exercise.exercise.category,
                gender: "unisex",
                target: exercise.exercise.instructions ?? "",
                synergist: exercise.exercise.description ?? ""
            )

            return TodayWorkoutExercise(
                exercise: exerciseData,
                sets: max(exercise.sets.count, 1),
                reps: firstSet?.reps ?? 10,
                weight: firstSet?.weight,
                restTime: firstSet?.restTime ?? 90,
                notes: exercise.notes,
                warmupSets: nil,
                flexibleSets: nil,
                trackingType: nil
            )
        }
    }
}

private struct ConditionalSearchModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .searchable(
                    text: $text,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search workouts"
                )
        } else {
            content
        }
    }
}

private extension View {
    func applyConditionalSearch(isEnabled: Bool, text: Binding<String>) -> some View {
        modifier(ConditionalSearchModifier(isEnabled: isEnabled, text: text))
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
    @State private var showingReorderSheet = false
        @Binding var showAddExerciseSheet: Bool
        let onPresentLogSheet: (LogExerciseSheetContext) -> Void
        let onRefresh: () -> Void
        let onRenameWorkout: () -> Void
        let onSaveWorkout: () -> Void
        let canShowSupersetMenu: Bool
        let onShowSuperset: () -> Void
        
        init(workout: TodayWorkout,
             navigationPath: Binding<NavigationPath>,
             onExerciseReplacementCallbackSet: @escaping (((Int, ExerciseData) -> Void)?) -> Void,
             onExerciseUpdateCallbackSet: @escaping (((Int, TodayWorkoutExercise) -> Void)?) -> Void,
             showAddExerciseSheet: Binding<Bool>,
             onPresentLogSheet: @escaping (LogExerciseSheetContext) -> Void,
             onRefresh: @escaping () -> Void,
             onRenameWorkout: @escaping () -> Void,
            onSaveWorkout: @escaping () -> Void,
            canShowSupersetMenu: Bool,
            onShowSuperset: @escaping () -> Void) {
            self.workout = workout
            self._navigationPath = navigationPath
            self.onExerciseReplacementCallbackSet = onExerciseReplacementCallbackSet
            self.onExerciseUpdateCallbackSet = onExerciseUpdateCallbackSet
            self._exercises = State(initialValue: workout.exercises)
            self._showAddExerciseSheet = showAddExerciseSheet
            self.onPresentLogSheet = onPresentLogSheet
            self.onRefresh = onRefresh
            self.onRenameWorkout = onRenameWorkout
            self.onSaveWorkout = onSaveWorkout
            self.canShowSupersetMenu = canShowSupersetMenu
            self.onShowSuperset = onShowSuperset
        }

        @ViewBuilder
        private var workoutTitleSection: some View {
            Section {
                HStack(spacing: 12) {
                    Text(workout.title.isEmpty ? "Workout" : workout.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    Button(action: onRefresh) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color("thumbbg")))
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button(action: onRenameWorkout) {
                            Label("Rename Workout", systemImage: "pencil")
                        }

                    Button(action: onSaveWorkout) {
                        Label("Save Workout", systemImage: "bookmark")
                    }

                    Button(action: { showingReorderSheet = true }) {
                        Label("Reorder Exercises", systemImage: "arrow.up.arrow.down")
                    }

                    if canShowSupersetMenu {
                        Button(action: onShowSuperset) {
                            Label("Build superset/circuit", systemImage: "arrow.left.arrow.right")
                        }
                    }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color("thumbbg")))
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 12)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }

        // Precomputed grouping helpers to simplify the List body (prevents type-checker blowups)
        private var circuitOrSupersetBlocks: [WorkoutBlock] {
            // Only show grouped blocks when there are 2+ exercises
            (workout.blocks ?? []).filter { ($0.type == .circuit || $0.type == .superset) && $0.exercises.count >= 2 }
        }

        private var groupedExerciseIds: Set<Int> {
            Set(circuitOrSupersetBlocks.flatMap { $0.exercises.map { $0.exercise.id } })
        }

        private var nonGroupedExercisesList: [TodayWorkoutExercise] {
            var seen = Set<Int>()
            return exercises.filter {
                !groupedExerciseIds.contains($0.exercise.id) && seen.insert($0.exercise.id).inserted
            }
        }
    
    var body: some View {
        List {
            workoutTitleSection
            warmUpSection
            mainTitleSection
            mainExercisesSection
            coolDownSection
            addExerciseSection
        }
        .listStyle(PlainListStyle())
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(Color("primarybg"))
        .cornerRadius(24)
        .sheet(isPresented: $showingReorderSheet) {
            reorderSheet
        }
        .onAppear {
            // Register callbacks once
            onExerciseReplacementCallbackSet { index, newExercise in
                replaceExercise(at: index, with: newExercise)
            }
            onExerciseUpdateCallbackSet { index, updatedExercise in
                updateExercise(at: index, with: updatedExercise)
            }
        }
        .onChange(of: workout.exercises) { _, newExercises in
            exercises = newExercises
        }
    }

    // MARK: - Subsections split out for type-checker performance

    @ViewBuilder
    private var warmUpSection: some View {
        if let warmUpExercises = workout.warmUpExercises, !warmUpExercises.isEmpty {
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

            ForEach(Array(warmUpExercises.enumerated()), id: \.element.exercise.id) { index, exercise in
                ExerciseWorkoutCard(
                    exercise: exercise,
                    allExercises: warmUpExercises,
                    exerciseIndex: index,
                    onExerciseReplaced: { _, _ in },
                    onOpen: {
                        onPresentLogSheet(LogExerciseSheetContext(exercise: exercise, allExercises: warmUpExercises, index: index))
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
            }
        }
    }

    @ViewBuilder
    private var mainTitleSection: some View {
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
    }

    @ViewBuilder
    private var mainExercisesSection: some View {
        if circuitOrSupersetBlocks.isEmpty {
            // One section with draggable exercises
            Section {
                let uniqueExercises: [TodayWorkoutExercise] = {
                    var seen = Set<Int>()
                    return exercises.filter { seen.insert($0.exercise.id).inserted }
                }()

                ForEach(Array(uniqueExercises.enumerated()), id: \.element.exercise.id) { idx, exercise in
                    let originalIndex = exercises.firstIndex(where: { $0.exercise.id == exercise.exercise.id }) ?? idx
                    VStack(spacing: 0) {
                        ExerciseWorkoutCard(
                            exercise: exercise,
                            allExercises: exercises,
                            exerciseIndex: originalIndex,
                            onExerciseReplaced: { index, newEx in replaceExercise(at: index, with: newEx) },
                            onOpen: {
                                onPresentLogSheet(LogExerciseSheetContext(exercise: exercise, allExercises: exercises, index: originalIndex))
                            },
                            useBackground: false
                        )
                        if idx != uniqueExercises.count - 1 {
                            Divider()
                                .padding(.leading, 92)  // Align with text after thumbnail
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: idx == 0 ? 16 : 8, leading: 0, bottom: idx == uniqueExercises.count - 1 ? 8 : 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listSectionSeparator(.hidden)
        } else {
            nonGroupedCardView
            groupedBlocksView
        }
    }

    private func moveMainExercises(from offsets: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: offsets, toOffset: destination)
        workoutManager.reorderMainExercises(fromOffsets: offsets, toOffset: destination)
    }

    @ViewBuilder
    private var reorderSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(exercises.enumerated()), id: \.element.exercise.id) { _, exercise in
                    Text(exercise.exercise.name)
                        .padding(.vertical, 8)
                }
                .onMove(perform: moveMainExercises)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showingReorderSheet = false }
                }
            }
        }
    }

    @ViewBuilder
    private var groupedBlocksView: some View {
        ForEach(Array(circuitOrSupersetBlocks.enumerated()), id: \.offset) { _, block in
            VStack(alignment: .leading, spacing: 8) {
                // Label by size: 2 → Superset, 3+ → Circuit
                Text(block.exercises.count >= 3 ? "Circuit" : "Superset")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)

                // Single shared container for this block
                VStack(alignment: .leading, spacing: 0) {
                    let ordered = orderedExercises(for: block)
                    ForEach(Array(ordered.enumerated()), id: \.element.exercise.id) { idx, exercise in
                        if let globalIndex = exercises.firstIndex(where: { $0.exercise.id == exercise.exercise.id }) {
                            ExerciseWorkoutCard(
                                exercise: exercise,
                                allExercises: exercises,
                                exerciseIndex: globalIndex,
                                onExerciseReplaced: { index, newEx in replaceExercise(at: index, with: newEx) },
                                onOpen: {
                                    onPresentLogSheet(LogExerciseSheetContext(exercise: exercise, allExercises: exercises, index: globalIndex))
                                },
                                useBackground: false
                            )
                            if idx != ordered.count - 1 {
                                Divider()
                                    .padding(.leading, 92)  // Align with text after thumbnail
                            }
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 8, trailing: 0))
        }
    }

    @ViewBuilder
    private var nonGroupedCardView: some View {
        if !nonGroupedExercisesList.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(nonGroupedExercisesList.enumerated()), id: \.element.exercise.id) { _, exercise in
                    if let globalIndex = exercises.firstIndex(where: { $0.exercise.id == exercise.exercise.id }) {
                        ExerciseWorkoutCard(
                            exercise: exercise,
                            allExercises: exercises,
                            exerciseIndex: globalIndex,
                            onExerciseReplaced: { index, newEx in replaceExercise(at: index, with: newEx) },
                            onOpen: {
                                onPresentLogSheet(LogExerciseSheetContext(exercise: exercise, allExercises: exercises, index: globalIndex))
                            },
                            useBackground: false
                        )
                        if exercise.exercise.id != nonGroupedExercisesList.last?.exercise.id {
                            Divider()
                                .padding(.leading, 92)  // Align with text after thumbnail
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
        }
    }

    @ViewBuilder
    private var coolDownSection: some View {
        if let coolDownExercises = workout.coolDownExercises, !coolDownExercises.isEmpty {
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

            ForEach(Array(coolDownExercises.enumerated()), id: \.element.exercise.id) { index, exercise in
                ExerciseWorkoutCard(
                    exercise: exercise,
                    allExercises: coolDownExercises,
                    exerciseIndex: index,
                    onExerciseReplaced: { _, _ in },
                    onOpen: {
                        onPresentLogSheet(LogExerciseSheetContext(exercise: exercise, allExercises: coolDownExercises, index: index))
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
            }
        }
    }

    @ViewBuilder
    private var addExerciseSection: some View {
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

        // Spacer so the floating Start button never covers the last row
        Section {
            Color.clear
                .frame(height: 90)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }

    // Helper to preserve block order
    private func orderedExercises(for block: WorkoutBlock) -> [TodayWorkoutExercise] {
        let ids = block.exercises.map { $0.exercise.id }
        return exercises.filter { ids.contains($0.exercise.id) }
    }

    private func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }
    
    private func updateExercise(at index: Int, with updatedExercise: TodayWorkoutExercise) {
        guard index < exercises.count else {
            return
        }

        // Replace the exercise with the updated one (including warm-up sets and new set count)
        exercises[index] = updatedExercise

        // Persist to WorkoutManager (single source of truth) so other views see changes immediately
        workoutManager.updateExercise(at: index, with: updatedExercise)

        // Also save to UserDefaults for session persistence across app restarts
        if let userEmail = UserDefaults.standard.string(forKey: "userEmail") {
            let updatedWorkout = TodayWorkout(
                id: workout.id,
                date: workout.date,
                title: workout.title,
                exercises: exercises,
                blocks: workout.blocks,
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
            warmupSets: oldExercise.warmupSets, // Preserve existing warm-up sets
            flexibleSets: oldExercise.flexibleSets,
            trackingType: oldExercise.trackingType
        )
        
        exercises[index] = replacedExercise
        workoutManager.updateExercise(at: index, with: replacedExercise)
        
        // Save to UserDefaults if needed
        if let userEmail = UserDefaults.standard.string(forKey: "userEmail") {
            let updatedWorkout = TodayWorkout(
                id: workout.id,
                date: workout.date,
                title: workout.title,
                exercises: exercises,
                blocks: workout.blocks,
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

struct ExerciseWorkoutCard: View {
    let exercise: TodayWorkoutExercise
    let allExercises: [TodayWorkoutExercise]
    let exerciseIndex: Int
    let onExerciseReplaced: (Int, ExerciseData) -> Void
    let onOpen: () -> Void
    let isSelectable: Bool
    let isSelected: Bool
    let onSelectionToggle: (() -> Void)?
    let showsContextMenu: Bool
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var recommendMoreOften = false
    @State private var recommendLessOften = false
    @State private var cachedDynamicExercise: DynamicWorkoutExercise?
    @State private var showHistory = false
    @State private var showReplace = false
    @State private var tempExercise: TodayWorkoutExercise
    let useBackground: Bool
    
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
            fitnessGoal: workoutManager.effectiveFitnessGoal,
            baseExercise: staticExercise
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
    
    init(
        exercise: TodayWorkoutExercise,
        allExercises: [TodayWorkoutExercise],
        exerciseIndex: Int,
        onExerciseReplaced: @escaping (Int, ExerciseData) -> Void,
        onOpen: @escaping () -> Void,
        useBackground: Bool = true,
        isSelectable: Bool = false,
        isSelected: Bool = false,
        onSelectionToggle: (() -> Void)? = nil,
        showsContextMenu: Bool = true
    ) {
        self.exercise = exercise
        self.allExercises = allExercises
        self.exerciseIndex = exerciseIndex
        self.onExerciseReplaced = onExerciseReplaced
        self.onOpen = onOpen
        self.isSelectable = isSelectable
        self.isSelected = isSelected
        self.onSelectionToggle = onSelectionToggle
        self.showsContextMenu = showsContextMenu
        self._tempExercise = State(initialValue: exercise)
        self.useBackground = useBackground
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: {
                if isSelectable {
                    onSelectionToggle?()
                } else {
                    onOpen()
                }
            }) {
                let cornerRadius: CGFloat = useBackground ? 12 : 8
                HStack(spacing: 12) {
                    if isSelectable {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                    }

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

                    Spacer(minLength: showsContextMenu ? 32 : 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.horizontal, 16)
                .padding(.vertical, useBackground ? 12 : 8)
                .background(
                    Group {
                        if useBackground {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(Color("containerbg"))
                        }
                    }
                )
                .cornerRadius(useBackground ? cornerRadius : 0)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSelectable && onSelectionToggle == nil)

            if showsContextMenu {
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
                        withAnimation { _ = workoutManager.removeExerciseFromToday(exerciseId: exercise.exercise.id) }
                    }

                    Button("Delete from workout", role: .destructive) {
                        withAnimation { _ = workoutManager.removeExerciseFromToday(exerciseId: exercise.exercise.id) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .padding(.trailing, 20)
                }
            }
        }
        .background(
            NavigationLink(
                destination: ExerciseHistory(exercise: exercise),
                isActive: $showHistory,
                label: { EmptyView() }
            ).hidden()
        )
        .sheet(isPresented: $showReplace) {
            ReplaceExerciseSheet(
                currentExercise: tempExercise,
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

    // Removed chips per request
    
    // Update cached exercise to prevent recomputation
    private func updateCachedExercise() {
        guard let dynamicParams = workoutManager.dynamicParameters else {
            cachedDynamicExercise = nil
            return
        }
        
        cachedDynamicExercise = DynamicParameterService.shared.generateDynamicExercise(
            for: exercise.exercise,
            parameters: dynamicParams,
            fitnessGoal: workoutManager.effectiveFitnessGoal,
            baseExercise: exercise
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
        .cornerRadius(24)
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
    let onSetForWorkout: (WorkoutDuration) -> Void

    @State private var tempSelectedDuration: WorkoutDuration

    init(selectedDuration: Binding<WorkoutDuration>, onSetForWorkout: @escaping (WorkoutDuration) -> Void) {
        self._selectedDuration = selectedDuration
        self.onSetForWorkout = onSetForWorkout
        self._tempSelectedDuration = State(initialValue: selectedDuration.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 10)
            
            Spacer()
            
            actionButtons
        }
        // .background(Color(.systemBackground))
        // .background(Color("primarybg"))
        .cornerRadius(24)
        .presentationDetents([
            .medium
        ])

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
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 12)

            Button("Set for workout") {
                onSetForWorkout(tempSelectedDuration)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.primary)
            .cornerRadius(24)
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
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
    let onSetForWorkout: (FitnessGoal) -> Void

    @State private var tempSelectedGoal: FitnessGoal

    // Simplified 3-option picker matching Plan creation (MacroFactor-style)
    static let pickerGoals: [FitnessGoal] = [
        .hypertrophy,
        .strength,
        .balanced
    ]

    init(selectedFitnessGoal: Binding<FitnessGoal>, onSetForWorkout: @escaping (FitnessGoal) -> Void) {
        self._selectedFitnessGoal = selectedFitnessGoal
        self.onSetForWorkout = onSetForWorkout
        // Map legacy/advanced goals to closest simplified option
        let initial = selectedFitnessGoal.wrappedValue
        let mapped: FitnessGoal = switch initial {
        case .hypertrophy, .tone: .hypertrophy
        case .strength, .power, .powerlifting: .strength
        case .balanced: .balanced
        default: .balanced  // general, circuitTraining, olympicWeightlifting → balanced
        }
        self._tempSelectedGoal = State(initialValue: mapped)
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
                    .padding(.bottom, 20)

                // Fitness Goal List (simplified 3-option)
                VStack(spacing: 0) {
                    ForEach(FitnessGoalPickerView.pickerGoals, id: \.self) { goal in
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

                                    Text(goal.subtitle)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        if goal != FitnessGoalPickerView.pickerGoals.last {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 10)

            Spacer()

            actionButtons
        }
        .cornerRadius(24)
        .presentationDetents([.medium])
    }

    private var actionButtons: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 12)

            Button("Set for workout") {
                onSetForWorkout(tempSelectedGoal)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.primary)
            .cornerRadius(24)
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Fitness Level Picker View

struct FitnessLevelPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFitnessLevel: ExperienceLevel
    let onSetForWorkout: (ExperienceLevel) -> Void

    @State private var tempSelectedLevel: ExperienceLevel

    init(selectedFitnessLevel: Binding<ExperienceLevel>, onSetForWorkout: @escaping (ExperienceLevel) -> Void) {
        self._selectedFitnessLevel = selectedFitnessLevel
        self.onSetForWorkout = onSetForWorkout
        // Use the current selected level as initial value
        let initialLevel = selectedFitnessLevel.wrappedValue
        self._tempSelectedLevel = State(initialValue: initialLevel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
                  
                                // .background(Color("primarybg"))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if level != ExperienceLevel.allCases.last {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 10)
            
            Spacer()
            
            actionButtons
        }
        // .background(Color(.systemBackground))
        // .background(Color("primarybg"))
        .cornerRadius(24)
          .presentationDetents([
            .medium, .large
        ])
        // .presentationDetents([.fraction(0.4)])
        
    }
    
    private var actionButtons: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 12)

            Button("Set for workout") {
                onSetForWorkout(tempSelectedLevel)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.primary)
            .cornerRadius(24)
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
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
            onExerciseUpdateCallbackSet: { _ in },
            onPresentLogSheet: { _ in }
        )
    }
}

// MARK: - Modern Loading View Component

private struct WorkoutSkeletonPlaceholderView: View {
    @State private var shimmerOffset: CGFloat = -200
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                skeletonExerciseCard
            }
        }
        .padding(.horizontal, 24)
        .accessibilityHidden(true)
        .onAppear(perform: startAnimations)
    }

    private var skeletonExerciseCard: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .fill(shimmerGradient)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 80, height: 12)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 2, x: 0, y: 1)
        )
    }

    private var shimmerGradient: LinearGradient {
        let baseColor = colorScheme == .dark ? Color(.systemGray5).opacity(0.6) : Color(.systemGray5)
        let highlightColor = colorScheme == .dark ? Color(.systemGray3) : Color(.systemGray4)
        let offset = reduceMotion ? 0 : shimmerOffset / 200

        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: baseColor, location: 0),
                .init(color: highlightColor, location: 0.5),
                .init(color: baseColor, location: 1)
            ]),
            startPoint: .init(x: -0.3 + offset, y: 0),
            endPoint: .init(x: 0.3 + offset, y: 0)
        )
    }

    private func startAnimations() {
        guard !reduceMotion else { return }
        shimmerOffset = -200
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 200
        }
    }
}

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
                // Spacer ensures header controls (ellipsis, tabs) don't collide with nav bar
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
                ForEach([SessionPhase.strengthFocus, .volumeFocus], id: \.self) { phase in
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
        }
    }
    
    private var phaseColor: Color {
        switch sessionPhase {
        case .strengthFocus:
            return .red
        case .volumeFocus:
            return .blue
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
        }
    }
}

private extension LogWorkoutView {
    func requestWorkoutGeneration() {
        guard !workoutManager.isGeneratingWorkout else {
            return
        }
        Task {
            // Force regenerate because this is triggered by user action
            await workoutManager.generateTodayWorkout(forceRegenerate: true)
        }
    }
}

// MARK: - Today Equipment Picker Sheet

/// Equipment picker for the Today tab that shows:
/// 1. Gym profile selection at top (like SinglePlanView)
/// 2. Equipment grid for customization
/// 3. "Set for Profile" and "Set for Workout" buttons
struct TodayEquipmentPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    @EnvironmentObject private var workoutManager: WorkoutManager
    @AppStorage("userEmail") private var userEmail: String = ""

    let onSetForProfile: ([Equipment]) -> Void
    let onSetForWorkout: ([Equipment]) -> Void

    @State private var selectedEquipment: Set<Equipment> = []
    @State private var showManageProfiles = false
    @State private var showCreateProfile = false
    // Track selected profile ID locally for immediate UI feedback
    @State private var selectedProfileId: Int?

    // Initialize equipment from active profile
    init(
        onSetForProfile: @escaping ([Equipment]) -> Void,
        onSetForWorkout: @escaping ([Equipment]) -> Void
    ) {
        self.onSetForProfile = onSetForProfile
        self.onSetForWorkout = onSetForWorkout
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Gym Profiles Section
                Section {
                    ForEach(Array(userProfileService.workoutProfiles.enumerated()), id: \.offset) { index, profile in
                        Button {
                            selectProfile(profile)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.displayName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)

                                    Text("\(profile.availableEquipment.count) equipment items")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                // Use local selectedProfileId for immediate UI feedback
                                if profile.id == selectedProfileId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Select Gym Profile")
                }

                Section {
                    Button {
                        showManageProfiles = true
                    } label: {
                        Label("Manage Gym Profiles", systemImage: "gearshape")
                            .foregroundColor(.primary)
                    }
                }

                // MARK: - Available Equipment Section
                Section {
                    let allEquipment = Equipment.allCases.filter { $0 != .bodyWeight }
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(allEquipment, id: \.self) { equipment in
                            EquipmentSelectionButton(
                                equipment: equipment,
                                isSelected: selectedEquipment.contains(equipment),
                                onTap: {
                                    HapticFeedback.generate()
                                    if selectedEquipment.contains(equipment) {
                                        selectedEquipment.remove(equipment)
                                    } else {
                                        selectedEquipment.insert(equipment)
                                    }
                                    // Check if equipment still matches the selected profile
                                    updateProfileSelectionBasedOnEquipment()
                                }
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    HStack {
                        Text("Available Equipment")
                        Spacer()
                        Text("\(selectedEquipment.count) selected")
                            .textCase(.none)
                    }
                }
            }
            .navigationTitle("Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateProfile = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .navigationDestination(isPresented: $showManageProfiles) {
                TodayManageGymProfilesView(userEmail: userEmail)
            }
            .navigationDestination(isPresented: $showCreateProfile) {
                TodayCreateGymProfileView(userEmail: userEmail)
            }
            .safeAreaInset(edge: .bottom) {
                actionButtons
            }
            .onAppear {
                loadEquipmentFromActiveProfile()
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // Set for Profile button
                Button {
                    HapticFeedback.generate()
                    updateActiveProfileEquipment()
                    onSetForProfile(Array(selectedEquipment))
                    dismiss()
                } label: {
                    Text("Set for Profile")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("containerbg"))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())

                // Set for Workout button (primary)
                Button {
                    HapticFeedback.generate()
                    onSetForWorkout(Array(selectedEquipment))
                    dismiss()
                } label: {
                    Text("Set for Workout")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primary)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 30)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    // MARK: - Helper Methods

    private func loadEquipmentFromActiveProfile() {
        // Check if there's session-level equipment override (from "Set for Workout")
        if let sessionEquipment = workoutManager.customEquipment, !sessionEquipment.isEmpty {
            selectedEquipment = Set(sessionEquipment)
            print("[TodayEquipment] Loaded \(sessionEquipment.count) equipment from session override")

            // Check if session equipment matches any profile for checkmark
            updateProfileSelectionBasedOnEquipment()
            return
        }

        // No session override - load from active gym profile
        selectedProfileId = userProfileService.activeWorkoutProfileId

        if let activeProfile = userProfileService.activeWorkoutProfile {
            let equipment = activeProfile.availableEquipment.compactMap { Equipment.from(string: $0) }
            selectedEquipment = Set(equipment)
            print("[TodayEquipment] Loaded \(equipment.count) equipment from active profile: \(activeProfile.displayName), id: \(activeProfile.id ?? -1)")
        } else {
            // Fallback to UserProfileService's available equipment
            selectedEquipment = Set(userProfileService.availableEquipment)
            print("[TodayEquipment] Loaded \(selectedEquipment.count) equipment from UserProfileService")
        }
    }

    private func selectProfile(_ profile: WorkoutProfile) {
        guard let profileId = profile.id else {
            print("[TodayEquipment] ❌ Profile has no ID")
            return
        }

        // Immediately update local state for instant checkmark feedback
        selectedProfileId = profileId

        // Load equipment from the selected profile
        let equipment = profile.availableEquipment.compactMap { Equipment.from(string: $0) }
        selectedEquipment = Set(equipment)
        print("[TodayEquipment] Selected profile: \(profile.displayName) (id: \(profileId)) with \(equipment.count) equipment")

        // Also activate this profile in the service if it's different
        guard profileId != userProfileService.activeWorkoutProfileId else { return }

        Task {
            do {
                try await userProfileService.activateWorkoutProfile(profileId: profileId)
                print("[TodayEquipment] ✅ Activated profile: \(profile.displayName)")
            } catch {
                print("[TodayEquipment] ❌ Failed to activate profile: \(error.localizedDescription)")
            }
        }
    }

    /// Check if current equipment matches any profile, update selectedProfileId accordingly
    private func updateProfileSelectionBasedOnEquipment() {
        // Convert current selection to a comparable set of strings
        let currentEquipmentStrings = Set(selectedEquipment.map { $0.rawValue })

        // Check if any profile matches the current equipment
        for profile in userProfileService.workoutProfiles {
            let profileEquipmentStrings = Set(profile.availableEquipment)
            if currentEquipmentStrings == profileEquipmentStrings {
                // Found a matching profile
                selectedProfileId = profile.id
                print("[TodayEquipment] Equipment matches profile: \(profile.displayName)")
                return
            }
        }

        // No profile matches - clear selection (custom session setup)
        selectedProfileId = nil
        print("[TodayEquipment] Equipment doesn't match any profile - custom session setup")
    }

    private func updateActiveProfileEquipment() {
        // Use locally selected profile ID (or fall back to service's active ID)
        guard let profileId = selectedProfileId ?? userProfileService.activeWorkoutProfileId else {
            print("[TodayEquipment] No active profile to update")
            return
        }

        let equipmentStrings = selectedEquipment
            .filter { $0 != .bodyWeight }
            .map { $0.rawValue }

        // Update local profile
        if let index = userProfileService.workoutProfiles.firstIndex(where: { $0.id == profileId }) {
            var updated = userProfileService.workoutProfiles[index]
            updated.availableEquipment = equipmentStrings
            userProfileService.workoutProfiles[index] = updated
        }

        // Persist to backend
        let email = userEmail.isEmpty ? (UserDefaults.standard.string(forKey: "userEmail") ?? "") : userEmail
        guard !email.isEmpty else { return }

        NetworkManagerTwo.shared.updateWorkoutPreferences(
            email: email,
            workoutData: ["available_equipment": equipmentStrings],
            profileId: profileId
        ) { result in
            switch result {
            case .success:
                print("[TodayEquipment] ✅ Updated profile \(profileId) equipment on server")
            case .failure(let error):
                print("[TodayEquipment] ❌ Failed to update profile equipment: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Today Manage Gym Profiles View

private struct TodayManageGymProfilesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    let userEmail: String

    @State private var showCreateProfile = false

    var body: some View {
        List {
            ForEach(userProfileService.workoutProfiles, id: \.id) { profile in
                NavigationLink {
                    TodayGymProfileEquipmentView(profile: profile, userEmail: userEmail)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.displayName)
                                .font(.system(size: 16, weight: .medium))

                            Text("\(profile.availableEquipment.count) equipment items")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Manage Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateProfile = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .navigationDestination(isPresented: $showCreateProfile) {
            TodayCreateGymProfileView(userEmail: userEmail)
        }
    }
}

// MARK: - Today Gym Profile Equipment View

private struct TodayGymProfileEquipmentView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    let profile: WorkoutProfile
    let userEmail: String

    @State private var editedName: String
    @State private var selectedEquipment: Set<Equipment>
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    private var canDelete: Bool {
        userProfileService.workoutProfiles.count > 1
    }

    init(profile: WorkoutProfile, userEmail: String) {
        self.profile = profile
        self.userEmail = userEmail
        _editedName = State(initialValue: profile.name)
        let equipment = profile.availableEquipment.compactMap { Equipment.from(string: $0) }
        _selectedEquipment = State(initialValue: Set(equipment))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gym Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("Gym Name", text: $editedName)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color("containerbg"))
                        .cornerRadius(100)
                        .submitLabel(.done)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Equipment")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(selectedEquipment.count) selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    let allEquipment = Equipment.allCases.filter { $0 != .bodyWeight }
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(allEquipment, id: \.self) { equipment in
                            EquipmentSelectionButton(
                                equipment: equipment,
                                isSelected: selectedEquipment.contains(equipment),
                                onTap: { toggleEquipment(equipment) }
                            )
                        }
                    }
                }

                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color("primarybg").ignoresSafeArea())
        .navigationTitle("Gym Equipment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveChanges()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                }
                .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if canDelete {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    if isDeleting {
                        ProgressView().tint(.red)
                    } else {
                        Text("Delete Gym")
                    }
                }
                .font(.system(size: 17))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .foregroundColor(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .disabled(isDeleting)
            }
        }
        .confirmationDialog(
            "Delete \"\(profile.displayName)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Gym", role: .destructive) {
                Task { await deleteProfile() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This gym profile will be permanently deleted.")
        }
    }

    private func toggleEquipment(_ equipment: Equipment) {
        HapticFeedback.generate()
        if selectedEquipment.contains(equipment) {
            selectedEquipment.remove(equipment)
        } else {
            selectedEquipment.insert(equipment)
        }
    }

    private func saveChanges() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? profile.displayName : trimmedName
        let equipmentList = selectedEquipment
            .filter { $0 != .bodyWeight }
            .map { $0.rawValue }

        // Update local profile
        guard let profileId = profile.id else { return }
        if let index = userProfileService.workoutProfiles.firstIndex(where: { $0.id == profileId }) {
            var updated = userProfileService.workoutProfiles[index]
            updated.name = resolvedName
            updated.availableEquipment = equipmentList
            userProfileService.workoutProfiles[index] = updated
        }

        // Persist to backend
        let email = userEmail.isEmpty ? (UserDefaults.standard.string(forKey: "userEmail") ?? "") : userEmail
        guard !email.isEmpty else { return }

        NetworkManagerTwo.shared.updateWorkoutPreferences(
            email: email,
            workoutData: ["available_equipment": equipmentList],
            profileId: profileId
        ) { result in
            switch result {
            case .success:
                print("[TodayGymEquipment] Equipment updated for profile \(profileId)")
            case .failure(let error):
                print("[TodayGymEquipment] Failed: \(error.localizedDescription)")
            }
        }

        dismiss()
    }

    @MainActor
    private func deleteProfile() async {
        guard let profileId = profile.id, canDelete else { return }
        isDeleting = true
        do {
            try await userProfileService.deleteWorkoutProfile(profileId: profileId)
            dismiss()
        } catch {
            print("[TodayGymEquipment] Failed to delete: \(error.localizedDescription)")
            isDeleting = false
        }
    }
}

// MARK: - Today Create Gym Profile View

private struct TodayCreateGymProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    let userEmail: String

    @State private var profileName: String
    @State private var selectedOption: OnboardingViewModel.GymLocationOption
    @State private var selectedEquipment: Set<Equipment>
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(userEmail: String) {
        self.userEmail = userEmail
        let existingNames = UserProfileService.shared.workoutProfiles.map { $0.displayName }
        let defaultName = Self.defaultGymName(from: existingNames)
        _profileName = State(initialValue: defaultName)
        _selectedOption = State(initialValue: .largeGym)
        _selectedEquipment = State(initialValue: Self.equipmentDefaults(for: .largeGym))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gym Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("Gym Name", text: $profileName)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color("containerbg"))
                        .cornerRadius(100)
                        .submitLabel(.done)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Gym Type")
                        .font(.headline)
                        .foregroundColor(.primary)

                    ForEach(OnboardingViewModel.GymLocationOption.allCases) { option in
                        gymOptionRow(option)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Equipment")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(selectedEquipment.count) selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    let allEquipment = Equipment.allCases.filter { $0 != .bodyWeight }
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(allEquipment, id: \.self) { equipment in
                            EquipmentSelectionButton(
                                equipment: equipment,
                                isSelected: selectedEquipment.contains(equipment),
                                onTap: { toggleEquipment(equipment) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color("primarybg").ignoresSafeArea())
        .navigationTitle("New Gym Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await createProfile() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .disabled(isSaving || profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    @ViewBuilder
    private func gymOptionRow(_ option: OnboardingViewModel.GymLocationOption) -> some View {
        Button {
            HapticFeedback.generate()
            selectedOption = option
            if option != .custom {
                selectedEquipment = Self.equipmentDefaults(for: option)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text(option.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if selectedOption == option {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 20))
                }
            }
            .padding()
            .background(Color("containerbg"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedOption == option ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func toggleEquipment(_ equipment: Equipment) {
        HapticFeedback.generate()
        if selectedEquipment.contains(equipment) {
            selectedEquipment.remove(equipment)
        } else {
            selectedEquipment.insert(equipment)
        }
    }

    @MainActor
    private func createProfile() async {
        let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await userProfileService.createWorkoutProfile(named: trimmedName, makeActive: true)
            persistEquipmentSelection()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistEquipmentSelection() {
        let equipmentList = selectedEquipment
            .filter { $0 != .bodyWeight }
            .map { $0.rawValue }
        let locationValue = Self.workoutLocationValue(for: selectedOption)
        let email = userEmail.isEmpty ? (UserDefaults.standard.string(forKey: "userEmail") ?? "") : userEmail
        guard !email.isEmpty else { return }

        var payload: [String: Any] = [
            "available_equipment": equipmentList,
            "workout_location": locationValue
        ]

        if let profileId = userProfileService.activeWorkoutProfile?.id {
            payload["profile_id"] = profileId
        }

        NetworkManagerTwo.shared.updateWorkoutPreferences(email: email, workoutData: payload) { result in
            switch result {
            case .success:
                print("[GymProfiles] Updated equipment for new gym profile.")
            case .failure(let error):
                print("[GymProfiles] Failed to update equipment: \(error.localizedDescription)")
            }
        }
    }

    private static func defaultGymName(from existingNames: [String]) -> String {
        let baseName = "New Gym"
        let usedNames = Set(existingNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        if !usedNames.contains(baseName.lowercased()) {
            return baseName
        }
        var suffix = 1
        while usedNames.contains("\(baseName) \(suffix)".lowercased()) {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
    }

    private static func equipmentDefaults(for option: OnboardingViewModel.GymLocationOption) -> Set<Equipment> {
        switch option {
        case .largeGym:
            return Set(Equipment.allCases.filter { $0 != .bodyWeight })
        case .smallGym:
            return Set(EquipmentView.EquipmentType.smallGym.equipmentList)
        case .garageGym:
            return Set(EquipmentView.EquipmentType.garageGym.equipmentList)
        case .atHome:
            return Set(EquipmentView.EquipmentType.atHome.equipmentList)
        case .noEquipment:
            return []
        case .custom:
            return []
        }
    }

    private static func workoutLocationValue(for option: OnboardingViewModel.GymLocationOption) -> String {
        switch option {
        case .largeGym: return "large_gym"
        case .smallGym: return "small_gym"
        case .garageGym: return "garage_gym"
        case .atHome: return "home"
        case .noEquipment: return "bodyweight"
        case .custom: return "custom"
        }
    }
}
