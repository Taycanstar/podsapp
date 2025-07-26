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
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    // Tab management
    @State private var selectedWorkoutTab: WorkoutTab = .today
    
    // Add WorkoutManager
    @StateObject private var workoutManager = WorkoutManager()
    
    // Add user email - you'll need to pass this in or get it from environment
    @State private var userEmail: String = UserDefaults.standard.string(forKey: "user_email") ?? ""
    
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
    
    // Computed property for the actual duration to use
    private var effectiveDuration: WorkoutDuration {
        return sessionDuration ?? selectedDuration
    }
    
    // Computed property for the actual fitness goal to use
    private var effectiveFitnessGoal: FitnessGoal {
        return sessionFitnessGoal ?? selectedFitnessGoal
    }
    
    // Keys for UserDefaults
    private let sessionDurationKey = "currentWorkoutSessionDuration"
    private let sessionDateKey = "currentWorkoutSessionDate"
    private let customMusclesKey = "currentWorkoutCustomMuscles"
    
    // Add fitness goal session keys
    private let sessionFitnessGoalKey = "currentWorkoutSessionFitnessGoal"
    
    enum WorkoutTab: Hashable {
        case today, workouts
        
        var title: String {
            switch self {
            case .today: return "Today"
            case .workouts: return "Workouts"
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
                .background(Color("iosbg2"))
                .zIndex(1) // Keep header on top
                
                // Main content
                mainContentView
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .navigationBarBackButtonHidden(true)
        .navigationTitle(selectedWorkoutTab == .workouts ? "Workouts" : "Log Workout")
        .navigationBarTitleDisplayMode(selectedWorkoutTab == .workouts ? .large : .inline)
        .if(selectedWorkoutTab == .workouts) { view in
            view.searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: selectedWorkoutTab.searchPrompt
            )
        }
        .onAppear {
            // Initialize WorkoutManager when view appears
            if !userEmail.isEmpty {
                workoutManager.initialize(userEmail: userEmail)
            }
            
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
    }
    
    private func regenerateWorkoutWithNewDuration() {
        // Trigger workout regeneration
        print("🔄 Regenerating workout with duration: \(effectiveDuration.minutes) minutes")
        shouldRegenerateWorkout = true
        // Reset the flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            shouldRegenerateWorkout = false
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
                if sessionDuration != nil || customTargetMuscles != nil || customEquipment != nil || sessionFitnessGoal != nil || sessionFitnessLevel != nil {
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
                        
                        regenerateWorkoutWithNewDuration()
                        print("🔄 Reset to default duration, muscle type, equipment, and fitness goal")
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
                
                // Duration Control with session modification styling
                Button(action: {
                    showingDurationPicker = true
                }) {
                    HStack(spacing: 4) {
                        Text(effectiveDuration.displayValue)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        // Always show chevron
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
                            .stroke(sessionDuration != nil ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        // Add primary color overlay when session duration is set
                        sessionDuration != nil ? 
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.primary.opacity(0.05)) : nil
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Type Control with custom muscle selection styling
                Button(action: {
                    showingTargetMusclesPicker = true
                }) {
                    HStack(spacing: 4) {
                        Text(selectedMuscleType)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        // Always show chevron
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
                            .stroke(customTargetMuscles != nil ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        // Add primary color overlay when custom muscles are set
                        customTargetMuscles != nil ? 
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.primary.opacity(0.05)) : nil
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Equipment Control with custom equipment selection styling
                Button(action: {
                    showingEquipmentPicker = true
                }) {
                    HStack(spacing: 4) {
                        Text("Equipment")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        // Always show chevron
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
                            .stroke(customEquipment != nil ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        // Add primary color overlay when custom equipment is set
                        customEquipment != nil ? 
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.primary.opacity(0.05)) : nil
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Fitness Goal Control with session modification styling
                Button(action: {
                    showingFitnessGoalPicker = true
                }) {
                    HStack(spacing: 4) {
                        Text(effectiveFitnessGoal.displayName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        // Always show chevron
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
                            .stroke(sessionFitnessGoal != nil ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        // Add primary color overlay when session fitness goal is set
                        sessionFitnessGoal != nil ? 
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.primary.opacity(0.05)) : nil
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Fitness Level Control with session modification styling
                Button(action: {
                    showingFitnessLevelPicker = true
                }) {
                    HStack(spacing: 4) {
                        Text(selectedFitnessLevel.displayName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        // Always show chevron
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
                            .stroke(sessionFitnessLevel != nil ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        // Add primary color overlay when session fitness level is set
                        sessionFitnessLevel != nil ? 
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.primary.opacity(0.05)) : nil
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 2) // Add vertical padding to prevent border cutoff
        }
    }
    
    private var mainContentView: some View {
        Group {
            switch selectedWorkoutTab {
            case .today:
                TodayWorkoutView(
                    searchText: searchText,
                    navigationPath: $navigationPath,
                    workoutManager: workoutManager,
                    userEmail: userEmail,
                    selectedDuration: effectiveDuration,
                    shouldRegenerate: shouldRegenerateWorkout,
                    customTargetMuscles: customTargetMuscles,
                    customEquipment: customEquipment,
                    effectiveFitnessGoal: effectiveFitnessGoal,
                    effectiveFitnessLevel: sessionFitnessLevel ?? selectedFitnessLevel
                )
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
                        .fill(selectedTab == tab 
                              ? (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.06))
                              : Color.clear)
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
    let selectedDuration: WorkoutDuration
    let shouldRegenerate: Bool
    let customTargetMuscles: [String]? // Added this parameter
    let customEquipment: [Equipment]? // Added this parameter
    let effectiveFitnessGoal: FitnessGoal // Added this parameter
    let effectiveFitnessLevel: ExperienceLevel // Added this parameter
    
    @State private var todayWorkout: TodayWorkout?
    @State private var isGeneratingWorkout = false
    @State private var userProfile = UserProfileService.shared
    
    var body: some View {
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
                TodayWorkoutExerciseList(
                    workout: workout,
                    navigationPath: $navigationPath
                )
                .padding(.horizontal)
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
        }
        .padding(.bottom, 16)
        .background(Color("iosbg2"))
        .onAppear {
            loadOrGenerateTodayWorkout()
        }
        .onChange(of: shouldRegenerate) { _, newValue in
            if newValue {
                // Reset the flag and regenerate workout
                generateTodayWorkout()
            }
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
            customEquipment: customEquipment
        )
        
        // Create dynamic title based on selected muscles
        let workoutTitle = muscleGroups.count >= 2 ? 
            "\(muscleGroups.prefix(2).joined(separator: " & ")) Focus" : 
            getWorkoutTitle(for: fitnessGoal)
        
        return TodayWorkout(
            id: UUID(),
            date: Date(),
            title: workoutTitle,
            exercises: workoutPlan.exercises,
            estimatedDuration: workoutPlan.actualDurationMinutes,
            fitnessGoal: fitnessGoal,
            difficulty: experienceLevel.workoutComplexity
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
                restBetweenSetsSeconds: 120...300,
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
                restBetweenSetsSeconds: 180...420,
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
            // Beginners: Lower intensity, fewer sets, longer rest
            return WorkoutParameters(
                percentageOneRM: adjustRange(params.percentageOneRM, by: -10...(-5)),
                repRange: adjustRange(params.repRange, by: 2...4),
                repDurationSeconds: params.repDurationSeconds,
                setsPerExercise: adjustRange(params.setsPerExercise, by: -1...0),
                restBetweenSetsSeconds: adjustRange(params.restBetweenSetsSeconds, by: 15...30),
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
        customEquipment: [Equipment]?
    ) -> WorkoutPlan {
        
        let targetDurationSeconds = targetDurationMinutes * 60
        
        // Calculate warmup and cooldown based on workout duration
        let warmupSeconds = getWarmupDuration(for: targetDurationMinutes)
        let cooldownSeconds = warmupSeconds // Same as warmup
        
        // Available time for exercises (without warmup/cooldown)
        let availableExerciseTime = targetDurationSeconds - warmupSeconds - cooldownSeconds
        
        var exercises: [TodayWorkoutExercise] = []
        var totalExerciseTime = 0
        
        // Start with 1 exercise per muscle group and build up
        var exercisesPerMuscle = 1
        let maxExercisesPerMuscle = 4
        
        while exercisesPerMuscle <= maxExercisesPerMuscle {
            let testExercises = generateExercises(
                muscleGroups: muscleGroups,
                exercisesPerMuscle: exercisesPerMuscle,
                parameters: parameters,
                recommendationService: recommendationService,
                customEquipment: customEquipment
            )
            
            let testTime = calculateTotalExerciseTime(exercises: testExercises, parameters: parameters)
            
            // Add 10-15% buffer for real-world variability
            let bufferedTime = Int(Double(testTime) * 1.125)
            
            if bufferedTime <= availableExerciseTime {
                exercises = testExercises
                totalExerciseTime = testTime
                exercisesPerMuscle += 1
            } else {
                break
            }
        }
        
        // If no exercises fit, try with minimal sets
        if exercises.isEmpty {
            exercises = generateMinimalExercises(
                muscleGroups: muscleGroups,
                parameters: parameters,
                recommendationService: recommendationService,
                customEquipment: customEquipment
            )
            totalExerciseTime = calculateTotalExerciseTime(exercises: exercises, parameters: parameters)
        }
        
        let bufferSeconds = Int(Double(totalExerciseTime) * 0.125)
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
    
    private func getWarmupDuration(for workoutMinutes: Int) -> Int {
        switch workoutMinutes {
        case 0..<30:   return 180  // 3 minutes for short workouts
        case 30..<90:  return 300  // 5 minutes for medium workouts
        default:       return 600  // 10 minutes for long workouts
        }
    }
    
    private func generateExercises(
        muscleGroups: [String],
        exercisesPerMuscle: Int,
        parameters: WorkoutParameters,
        recommendationService: WorkoutRecommendationService,
        customEquipment: [Equipment]?
    ) -> [TodayWorkoutExercise] {
        
        var exercises: [TodayWorkoutExercise] = []
        
        for muscleGroup in muscleGroups.prefix(4) { // Limit to 4 muscle groups
            let recommendedExercises = recommendationService.getRecommendedExercises(
                for: muscleGroup, 
                count: exercisesPerMuscle,
                customEquipment: customEquipment
            )
            
            for exercise in recommendedExercises {
                let sets = parameters.setsPerExercise.lowerBound + (exercisesPerMuscle > 2 ? 1 : 0)
                let reps = getOptimalReps(for: exercise, parameters: parameters)
                let restTime = getOptimalRestTime(for: exercise, parameters: parameters)
                
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
        customEquipment: [Equipment]?
    ) -> [TodayWorkoutExercise] {
        
        var exercises: [TodayWorkoutExercise] = []
        
        // Generate 1 compound exercise per muscle group with minimal sets
        for muscleGroup in muscleGroups.prefix(3) { // Limit to 3 muscle groups for time
            let recommendedExercises = recommendationService.getRecommendedExercises(
                for: muscleGroup, 
                count: 1,
                customEquipment: customEquipment
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
    
    private func getOptimalRestTime(for exercise: ExerciseData, parameters: WorkoutParameters) -> Int {
        // Compound exercises get longer rest, isolation exercises get shorter rest
        let isCompound = isCompoundExercise(exercise)
        
        if isCompound {
            return parameters.restBetweenSetsSeconds.upperBound
        } else {
            return parameters.restBetweenSetsSeconds.lowerBound + 
                   (parameters.restBetweenSetsSeconds.upperBound - parameters.restBetweenSetsSeconds.lowerBound) / 2
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
    
    var body: some View {
        VStack(spacing: 12) {
            // Exercise cards list
            ForEach(workout.exercises, id: \.exercise.id) { exercise in
                ExerciseWorkoutCard(
                    exercise: exercise,
                    navigationPath: $navigationPath
                )
            }
        }
        .padding(.horizontal, 16)
        .background(Color("bg"))
        .cornerRadius(12)
    }
}

// MARK: - Exercise Workout Card

private struct ExerciseWorkoutCard: View {
    let exercise: TodayWorkoutExercise
    @Binding var navigationPath: NavigationPath
    @State private var showingMenu = false
    @State private var recommendMoreOften = false
    @State private var recommendLessOften = false
    
    var body: some View {
        Button(action: {
            // Navigate to exercise logging view
            navigationPath.append(WorkoutNavigationDestination.logExercise(exercise))
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
                Button(action: {
                    showingMenu = true
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 12)
            .background(Color("iosfit"))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .confirmationDialog("Exercise Options", isPresented: $showingMenu, titleVisibility: .visible) {
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
            
            Button("Don't recommend again", role: .destructive) {
                // TODO: Add to avoided exercises
            }
            
            Button("Delete from workout", role: .destructive) {
                // TODO: Remove from current workout
            }
            
            Button("Cancel", role: .cancel) {}
        }
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

struct TodayWorkout: Codable, Hashable {
    let id: UUID
    let date: Date
    let title: String
    let exercises: [TodayWorkoutExercise]
    let estimatedDuration: Int
    let fitnessGoal: FitnessGoal
    let difficulty: Int
}

struct TodayWorkoutExercise: Codable, Hashable {
    let exercise: ExerciseData
    let sets: Int
    let reps: Int
    let weight: Double?
    let restTime: Int // in seconds
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
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
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

// MARK: - Exercise Logging View

struct ExerciseLoggingView: View {
    let exercise: TodayWorkoutExercise
    @Environment(\.dismiss) private var dismiss
    @State private var currentSet = 1
    @State private var completedSets: [SetLog] = []
    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var isRestMode = false
    @State private var restTimeRemaining = 0
    @State private var restTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Video Header
            videoHeaderView
            
            // Exercise info section
            exerciseInfoSection
            
            // Sets logging section
            setsLoggingSection
            
            Spacer()
            
            // Action buttons
            actionButtonsSection
        }
        .navigationTitle(exercise.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupInitialValues()
        }
        .onDisappear {
            stopRestTimer()
        }
    }
    
    private var videoHeaderView: some View {
        Group {
            if let videoURL = videoURL {
                CustomExerciseVideoPlayer(videoURL: videoURL)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .padding([.horizontal], 16)
                    .padding([.top], 8)
            } else {
                // Fallback thumbnail view
                Group {
                    if let image = UIImage(named: thumbnailImageName) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "play.circle")
                                        .foregroundColor(.white)
                                        .font(.system(size: 32))
                                    Text("Video not available")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                }
                            )
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
    
    private var exerciseInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.exercise.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(exercise.sets) sets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !exercise.exercise.target.isEmpty {
                Text("Target: \(exercise.exercise.target)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !exercise.exercise.equipment.isEmpty {
                Text("Equipment: \(exercise.exercise.equipment)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var setsLoggingSection: some View {
        VStack(spacing: 16) {
            // Current set indicator
            if !isRestMode {
                Text("Set \(currentSet) of \(exercise.sets)")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top)
            }
            
            // Rest mode view
            if isRestMode {
                VStack(spacing: 16) {
                    Text("Rest Time")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(formatTime(restTimeRemaining))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                    
                    Button("Skip Rest") {
                        skipRest()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                }
                .padding()
                .background(Color("bg"))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Input fields for current set
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weight (lbs)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("0", text: $weight)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("\(exercise.reps)", text: $reps)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Completed sets list
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 4) {
                        ForEach(Array(completedSets.enumerated()), id: \.offset) { index, setLog in
                            HStack {
                                Text("Set \(index + 1)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(setLog.weight, specifier: "%.1f") lbs × \(setLog.reps) reps")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color("iosfit"))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if !isRestMode {
                // Complete set button
                Button(action: completeSet) {
                    Text("Complete Set")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(currentSetCanBeCompleted ? Color.accentColor : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!currentSetCanBeCompleted)
                .padding(.horizontal)
            }
            
            if completedSets.count == exercise.sets {
                // Finish exercise button
                Button(action: finishExercise) {
                    Text("Finish Exercise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    // MARK: - Computed Properties
    
    private var videoURL: URL? {
        let videoId = String(format: "%04d", exercise.exercise.id)
        return URL(string: "https://humulistoragecentral.blob.core.windows.net/videos/filtered_vids/\(videoId).mp4")
    }
    
    private var thumbnailImageName: String {
        return String(format: "%04d", exercise.exercise.id)
    }
    
    private var currentSetCanBeCompleted: Bool {
        return !reps.isEmpty && (exercise.exercise.equipment.lowercased() == "body weight" || !weight.isEmpty)
    }
    
    // MARK: - Methods
    
    private func setupInitialValues() {
        reps = "\(exercise.reps)"
        // Initialize weight based on exercise type
        if exercise.exercise.equipment.lowercased() != "body weight" {
            weight = "0"
        }
    }
    
    private func completeSet() {
        guard let repsCount = Int(reps) else { return }
        let weightValue = Double(weight) ?? 0.0
        
        let setLog = SetLog(
            setNumber: currentSet,
            weight: weightValue,
            reps: repsCount,
            completedAt: Date()
        )
        
        completedSets.append(setLog)
        
        if currentSet < exercise.sets {
            // Start rest period
            startRestPeriod()
        } else {
            // All sets completed
            finishExercise()
        }
    }
    
    private func startRestPeriod() {
        isRestMode = true
        restTimeRemaining = exercise.restTime
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                skipRest()
            }
        }
    }
    
    private func skipRest() {
        stopRestTimer()
        isRestMode = false
        currentSet += 1
        // Reset inputs for next set
        reps = "\(exercise.reps)"
    }
    
    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
    }
    
    private func finishExercise() {
        // TODO: Save exercise completion to database
        print("Exercise completed: \(exercise.exercise.name)")
        print("Completed sets: \(completedSets)")
        dismiss()
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Set Log Model

struct SetLog {
    let setNumber: Int
    let weight: Double
    let reps: Int
    let completedAt: Date
}

// MARK: - Custom Exercise Video Player

struct CustomExerciseVideoPlayer: UIViewControllerRepresentable {
    let videoURL: URL
    
    func makeUIViewController(context: Context) -> ExerciseVideoPlayerController {
        let controller = ExerciseVideoPlayerController()
        controller.videoURL = videoURL  // Store URL for later setup
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ExerciseVideoPlayerController, context: Context) {
        // Update if needed
        if uiViewController.videoURL != videoURL {
            uiViewController.videoURL = videoURL
            uiViewController.setupPlayerIfReady()
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: ExerciseVideoPlayerController, coordinator: ()) {
        uiViewController.cleanup()
    }
}

class ExerciseVideoPlayerController: UIViewController {
    private var playerView: UIView?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    var videoURL: URL?
    private var viewHasLoaded = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        viewHasLoaded = true
        setupPlayerIfReady()
    }
    
    private func setupViews() {
        playerView = UIView()
        playerView?.translatesAutoresizingMaskIntoConstraints = false
        playerView?.backgroundColor = .clear
        
        guard let playerView = playerView else { return }
        view.addSubview(playerView)
        
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func setupPlayerIfReady() {
        guard viewHasLoaded, let videoURL = videoURL, let playerView = playerView else {
            return
        }
        
        // Clean up existing player if any
        cleanup()
        
        // Create asset and composition for chroma key
        let asset = AVURLAsset(url: videoURL)
        let composition = AVMutableComposition()
        
        // Add video track
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            // Fallback to simple player without chroma key
            setupSimplePlayer(url: videoURL)
            return
        }
        
        do {
            try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
        } catch {
            setupSimplePlayer(url: videoURL)
            return
        }
        
        // Create video composition with chroma key filter
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoTrack.naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        
        // Create chroma key filter - use CIColorCube for custom green screen removal
        guard let chromaKeyFilter = createGreenScreenFilter() else {
            setupSimplePlayer(url: videoURL)
            return
        }
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        // Apply custom compositor for chroma key
        videoComposition.customVideoCompositorClass = ChromaKeyVideoCompositor.self
        
        // Create player item with composition
        let playerItem = AVPlayerItem(asset: composition)
        playerItem.videoComposition = videoComposition
        
        // Create player
        player = AVPlayer(playerItem: playerItem)
        
        // Create player layer
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.backgroundColor = UIColor.clear.cgColor
        
        // Add to view
        if let playerLayer = playerLayer {
            playerView.layer.addSublayer(playerLayer)
        }
        
        // Setup auto-loop
        setupAutoLoop()
        
        // Auto-play when ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.player?.play()
        }
    }
    
    private func setupSimplePlayer(url: URL) {
        // Fallback simple player without chroma key
        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.backgroundColor = UIColor.clear.cgColor
        
        if let playerLayer = playerLayer, let playerView = playerView {
            playerView.layer.addSublayer(playerLayer)
        }
        
        setupAutoLoop()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.player?.play()
        }
    }
    
    private func createGreenScreenFilter() -> CIFilter? {
        // Use CIColorCube to create a custom green screen removal filter
        let greenScreenFilter = CIFilter(name: "CIColorCube")
        
        // Create a color cube that makes green pixels transparent
        let size = 64
        let cubeData = generateGreenScreenCubeData(cubeSize: size)
        let data = Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size)
        
        greenScreenFilter?.setValue(data, forKey: "inputCubeData")
        greenScreenFilter?.setValue(size, forKey: "inputCubeDimension")
        
        return greenScreenFilter
    }
    
    private func generateGreenScreenCubeData(cubeSize: Int) -> [Float] {
        var cubeData = [Float]()
        
        for z in 0..<cubeSize {
            for y in 0..<cubeSize {
                for x in 0..<cubeSize {
                    let r = Float(x) / Float(cubeSize - 1)
                    let g = Float(y) / Float(cubeSize - 1)
                    let b = Float(z) / Float(cubeSize - 1)
                    
                    // Check if this is a green pixel (high green, low red/blue)
                    let isGreen = g > 0.6 && r < 0.4 && b < 0.4
                    
                    if isGreen {
                        // Make green pixels transparent by setting alpha to 0
                        cubeData.append(r)
                        cubeData.append(g)
                        cubeData.append(b)
                        cubeData.append(0.0) // Alpha = 0 (transparent)
                    } else {
                        // Keep non-green pixels as they are
                        cubeData.append(r)
                        cubeData.append(g)
                        cubeData.append(b)
                        cubeData.append(1.0) // Alpha = 1 (opaque)
                    }
                }
            }
        }
        
        return cubeData
    }
    
    private func setupAutoLoop() {
        guard let player = player else { return }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let playerView = playerView {
            playerLayer?.frame = playerView.bounds
        }
    }
    
    func cleanup() {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        NotificationCenter.default.removeObserver(self)
        player = nil
        playerLayer = nil
    }
}

// MARK: - Chroma Key Video Compositor
class ChromaKeyVideoCompositor: NSObject, AVVideoCompositing {
    var sourcePixelBufferAttributes: [String : Any]? = [
        String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
    ]
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
        String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
    ]
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // Handle render context changes if needed
    }
    
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        guard let trackID = asyncVideoCompositionRequest.sourceTrackIDs.first,
              let sourcePixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: trackID.int32Value) else {
            asyncVideoCompositionRequest.finish(with: NSError(domain: "ChromaKey", code: 1, userInfo: nil))
            return
        }
        
        let renderContext = asyncVideoCompositionRequest.renderContext
        guard let destinationPixelBuffer = renderContext.newPixelBuffer() else {
            asyncVideoCompositionRequest.finish(with: NSError(domain: "ChromaKey", code: 2, userInfo: nil))
            return
        }
        
        // Create CIImages
        let sourceImage = CIImage(cvPixelBuffer: sourcePixelBuffer)
        
        // Apply green screen removal using CIColorCube
        guard let colorCubeFilter = CIFilter(name: "CIColorCube") else {
            copyPixelBuffer(source: sourcePixelBuffer, destination: destinationPixelBuffer)
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: destinationPixelBuffer)
            return
        }
        
        // Create color cube data for green screen removal
        let cubeData = createGreenScreenCubeData()
        let data = Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size)
        
        colorCubeFilter.setValue(sourceImage, forKey: kCIInputImageKey)
        colorCubeFilter.setValue(data, forKey: "inputCubeData")
        colorCubeFilter.setValue(64, forKey: "inputCubeDimension")
        
        guard let outputImage = colorCubeFilter.outputImage else {
            copyPixelBuffer(source: sourcePixelBuffer, destination: destinationPixelBuffer)
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: destinationPixelBuffer)
            return
        }
        
        // Render to destination buffer
        let context = CIContext()
        context.render(outputImage, to: destinationPixelBuffer)
        
        asyncVideoCompositionRequest.finish(withComposedVideoFrame: destinationPixelBuffer)
    }
    
    private func copyPixelBuffer(source: CVPixelBuffer, destination: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(destination, [])
        
        let sourceData = CVPixelBufferGetBaseAddress(source)
        let destData = CVPixelBufferGetBaseAddress(destination)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(source)
        let height = CVPixelBufferGetHeight(source)
        
        memcpy(destData, sourceData, bytesPerRow * height)
        
        CVPixelBufferUnlockBaseAddress(destination, [])
        CVPixelBufferUnlockBaseAddress(source, .readOnly)
    }
    
    private func createGreenScreenCubeData() -> [Float] {
        var cubeData = [Float]()
        let cubeSize = 64
        
        for z in 0..<cubeSize {
            for y in 0..<cubeSize {
                for x in 0..<cubeSize {
                    let r = Float(x) / Float(cubeSize - 1)
                    let g = Float(y) / Float(cubeSize - 1)
                    let b = Float(z) / Float(cubeSize - 1)
                    
                    // Check if this is a green pixel (high green, low red/blue)
                    let isGreen = g > 0.6 && r < 0.4 && b < 0.4
                    
                    if isGreen {
                        // Make green pixels transparent by setting alpha to 0
                        cubeData.append(r)
                        cubeData.append(g)
                        cubeData.append(b)
                        cubeData.append(0.0) // Alpha = 0 (transparent)
                    } else {
                        // Keep non-green pixels as they are
                        cubeData.append(r)
                        cubeData.append(g)
                        cubeData.append(b)
                        cubeData.append(1.0) // Alpha = 1 (opaque)
                    }
                }
            }
        }
        
        return cubeData
    }
}

#Preview {
    NavigationView {
        LogWorkoutView(selectedTab: .constant(0), navigationPath: .constant(NavigationPath()))
    }
}
