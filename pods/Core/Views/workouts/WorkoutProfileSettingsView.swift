import SwiftUI
import UIKit

// MARK: - Plan Settings View

struct WorkoutProfileSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var profile = UserProfileService.shared
    @ObservedObject private var programService = ProgramService.shared
    @AppStorage("userEmail") private var userEmail: String = ""

    // Sheet states
    @State private var showGymProfilesSheet = false
    @State private var showAllPlansSheet = false
    @State private var showFitnessGoalSheet = false

    // Regeneration states
    @State private var showRegenerationAlert = false
    @State private var isRegenerating = false

    // Local state (current values being edited)
    @State private var selectedGoal: ProgramFitnessGoal = .hypertrophy
    @State private var selectedExperience: ProgramExperienceLevel = .intermediate
    @State private var daysPerWeek: Int = 4
    @State private var sessionDuration: Int = 45
    @State private var totalWeeks: Int = 8
    @State private var trainingSplit: ProgramType = .fullBody
    @State private var warmupSetsEnabled: Bool = false
    @State private var circuitsEnabled: Bool = false
    @State private var deloadEnabled: Bool = true
    @State private var periodizationEnabled: Bool = true
    @State private var cardioEnabled: Bool = false
    @State private var warmupEnabled: Bool = true
    @State private var cooldownEnabled: Bool = true

    // Original state (values when view appeared, for change detection)
    @State private var originalGoal: ProgramFitnessGoal = .hypertrophy
    @State private var originalExperience: ProgramExperienceLevel = .intermediate
    @State private var originalDaysPerWeek: Int = 4
    @State private var originalSessionDuration: Int = 45
    @State private var originalTotalWeeks: Int = 8
    @State private var originalTrainingSplit: ProgramType = .fullBody
    @State private var originalWarmupSetsEnabled: Bool = false
    @State private var originalCircuitsEnabled: Bool = false
    @State private var originalDeloadEnabled: Bool = true
    @State private var originalPeriodizationEnabled: Bool = true
    @State private var originalCardioEnabled: Bool = false
    @State private var originalWarmupEnabled: Bool = true
    @State private var originalCooldownEnabled: Bool = true

    // Computed property: has any setting changed?
    private var hasUnsavedChanges: Bool {
        selectedGoal != originalGoal ||
        selectedExperience != originalExperience ||
        daysPerWeek != originalDaysPerWeek ||
        sessionDuration != originalSessionDuration ||
        totalWeeks != originalTotalWeeks ||
        trainingSplit != originalTrainingSplit ||
        warmupSetsEnabled != originalWarmupSetsEnabled ||
        circuitsEnabled != originalCircuitsEnabled ||
        deloadEnabled != originalDeloadEnabled ||
        periodizationEnabled != originalPeriodizationEnabled ||
        cardioEnabled != originalCardioEnabled ||
        warmupEnabled != originalWarmupEnabled ||
        cooldownEnabled != originalCooldownEnabled
    }

    // Computed property: do any changes require plan regeneration?
    private var hasRegeneratingChanges: Bool {
        selectedGoal != originalGoal ||
        selectedExperience != originalExperience ||
        daysPerWeek != originalDaysPerWeek ||
        sessionDuration != originalSessionDuration ||
        trainingSplit != originalTrainingSplit ||
        warmupSetsEnabled != originalWarmupSetsEnabled ||
        circuitsEnabled != originalCircuitsEnabled
    }


    private var rowBackground: Color { Color("altcard") }
    private var iconColor: Color { colorScheme == .dark ? .white : .primary }

    private var equipmentSelectionSummary: String {
        if profile.bodyweightOnlyWorkouts {
            return "Bodyweight only"
        }
        let count = profile.availableEquipment.count
        return count == 0 ? "Select" : "\(count) selected"
    }

    var body: some View {
        Form {
            // MARK: - Section 1: Equipment
            Section(header: Text("Equipment")) {
                Button {
                    showGymProfilesSheet = true
                } label: {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "dumbbell")
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(iconColor)
                            Text("Gym Profile")
                                .font(.system(size: 15))
                                .foregroundColor(iconColor)
                        }
                        Spacer()
                        Text(profile.activeWorkoutProfile?.displayName ?? "Default")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(rowBackground)
            }

            // MARK: - Section 2: Active Plan
            Section {
                Button {
                    showAllPlansSheet = true
                } label: {
                    HStack {
                        Text("Active Plan")
                            .font(.system(size: 15))
                            .foregroundColor(iconColor)
                        Spacer()
                        Text(programService.activeProgram?.name ?? "None")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(rowBackground)
            }

            // MARK: - Section 3: Fitness Goal
            Section {
                Button {
                    showFitnessGoalSheet = true
                } label: {
                    HStack {
                        Text("Fitness Goal")
                            .font(.system(size: 15))
                            .foregroundColor(iconColor)
                        Spacer()
                        Text(selectedGoal.displayName)
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(rowBackground)
            }

            // MARK: - Section 4: Experience
            Section {
                HStack {
                    Text("Fitness Experience")
                        .font(.system(size: 15))
                        .foregroundColor(iconColor)
                    Spacer()
                    Menu {
                        ForEach(ProgramExperienceLevel.allCases, id: \.self) { level in
                            Button {
                                selectedExperience = level
                            } label: {
                                HStack {
                                    Text(level.displayName)
                                    if selectedExperience == level {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedExperience.displayName)
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(rowBackground)
            }

            // MARK: - Section 5: Schedule
            Section(header: Text("Schedule")) {
                // Days per Week (regenerating)
                Stepper("\(daysPerWeek) days per week", value: $daysPerWeek, in: trainingSplit.daysPerWeekRange)
                    .listRowBackground(rowBackground)

                // Min per Session (regenerating)
                Stepper("\(sessionDuration) min per session", value: $sessionDuration, in: 30...120, step: 15)
                    .listRowBackground(rowBackground)

                // # of Weeks (non-regenerating)
                Stepper("\(totalWeeks) weeks", value: $totalWeeks, in: 1...16)
                    .listRowBackground(rowBackground)
            }

            // MARK: - Section 6: Workout Setup
            Section(header: Text("Workout Setup")) {
                // Training Split
                HStack {
                    Text("Training Split")
                        .font(.system(size: 15))
                        .foregroundColor(iconColor)
                    Spacer()
                    Menu {
                        ForEach(ProgramType.allCases, id: \.self) { split in
                            Button {
                                trainingSplit = split
                            } label: {
                                HStack {
                                    Text(split.displayName)
                                    if trainingSplit == split {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(trainingSplit.displayName)
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(rowBackground)

                // Warm-up Sets Toggle (regenerating)
                Toggle("Warm-up Sets", isOn: $warmupSetsEnabled)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
                    .tint(.accentColor)
                    .listRowBackground(rowBackground)

                // Circuits & Supersets Toggle (regenerating)
                Toggle("Circuits & Supersets", isOn: $circuitsEnabled)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
                    .tint(.accentColor)
                    .listRowBackground(rowBackground)
            }

            // MARK: - Section 7: Preferences
            Section {
                // Deload (non-regenerating)
                Toggle("Deload", isOn: $deloadEnabled)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
                    .tint(.accentColor)
                    .listRowBackground(rowBackground)

                // Cardio (placeholder for future)
                Toggle("Cardio", isOn: $cardioEnabled)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
                    .tint(.accentColor)
                    .listRowBackground(rowBackground)

                // Warm-Up (non-regenerating)
                Toggle("Warm-Up", isOn: $warmupEnabled)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
                    .tint(.accentColor)
                    .listRowBackground(rowBackground)

                // Cool-Down (non-regenerating)
                Toggle("Cool-Down", isOn: $cooldownEnabled)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
                    .tint(.accentColor)
                    .listRowBackground(rowBackground)

                // Periodization (non-regenerating) - last with footer
                Toggle("Periodization", isOn: $periodizationEnabled)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
                    .tint(.accentColor)
                    .listRowBackground(rowBackground)
            } header: {
                Text("Preferences")
            } footer: {
                Text("Progressively increase intensity and volume over time")
            }
        }
        .environment(\.defaultMinListRowHeight, 52)
        .navigationTitle("Plan Settings")
        .scrollContentBackground(.hidden)
        .background(Color("altbg").ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if hasUnsavedChanges {
                    Button {
                        saveChanges()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(.accentColor.opacity(0.8))
                }
            }
        }
        .sheet(isPresented: $showGymProfilesSheet) {
            GymProfilesSheet(userEmail: userEmail)
        }
        .sheet(isPresented: $showAllPlansSheet) {
            AllPlansView()
        }
        .sheet(isPresented: $showFitnessGoalSheet) {
            FitnessGoalSelectionSheet(
                selectedGoal: $selectedGoal,
                onSelect: { goal in
                    selectedGoal = goal
                }
            )
        }
        .alert("Regenerate Plan?", isPresented: $showRegenerationAlert) {
            Button("Cancel", role: .cancel) {
                // Revert to original values
                revertToOriginalValues()
            }
            Button("Regenerate", role: .destructive) {
                Task { await applyAllChanges() }
            }
        } message: {
            Text("Some changes require regenerating your training plan. Your completed workouts will be preserved, but upcoming workouts will change.")
        }
        .overlay {
            if isRegenerating {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Regenerating Plan...")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            syncFromActiveProgram()
        }
        .onChange(of: programService.activeProgram?.id) { _, _ in
            syncFromActiveProgram()
        }
    }

    // MARK: - Save Logic

    private func saveChanges() {
        if hasRegeneratingChanges {
            // Show confirmation alert before applying regenerating changes
            showRegenerationAlert = true
        } else {
            // Apply non-regenerating changes directly
            Task { await applyNonRegeneratingChanges() }
        }
    }

    private func revertToOriginalValues() {
        selectedGoal = originalGoal
        selectedExperience = originalExperience
        daysPerWeek = originalDaysPerWeek
        sessionDuration = originalSessionDuration
        totalWeeks = originalTotalWeeks
        trainingSplit = originalTrainingSplit
        warmupSetsEnabled = originalWarmupSetsEnabled
        circuitsEnabled = originalCircuitsEnabled
        deloadEnabled = originalDeloadEnabled
        periodizationEnabled = originalPeriodizationEnabled
        cardioEnabled = originalCardioEnabled
        warmupEnabled = originalWarmupEnabled
        cooldownEnabled = originalCooldownEnabled
    }

    // MARK: - Apply Changes Logic

    /// Apply all changes including regeneration
    private func applyAllChanges() async {
        guard programService.activeProgram != nil else { return }

        isRegenerating = true

        do {
            // Get equipment from profile and convert to string array
            let equipment = profile.availableEquipment.map { $0.rawValue }

            _ = try await programService.generateProgram(
                userEmail: userEmail,
                programType: trainingSplit,
                fitnessGoal: selectedGoal,
                experienceLevel: selectedExperience,
                daysPerWeek: daysPerWeek,
                sessionDurationMinutes: sessionDuration,
                startDate: Date(),
                totalWeeks: totalWeeks,
                includeDeload: deloadEnabled,
                availableEquipment: equipment,
                excludedExercises: nil,
                defaultWarmupEnabled: warmupEnabled,
                defaultCooldownEnabled: cooldownEnabled
            )

            // Sync local state from new program (updates original values too)
            syncFromActiveProgram()

            // Also update the UserProfileService settings to stay in sync
            profile.warmupSetsEnabled = warmupSetsEnabled
            profile.circuitsAndSupersetsEnabled = circuitsEnabled

        } catch {
            print("❌ Failed to regenerate program: \(error)")
        }

        isRegenerating = false
    }

    /// Apply only non-regenerating changes (no plan regeneration needed)
    private func applyNonRegeneratingChanges() async {
        guard let program = programService.activeProgram else { return }

        // Apply totalWeeks, deload, periodization changes
        if totalWeeks != originalTotalWeeks ||
           deloadEnabled != originalDeloadEnabled ||
           periodizationEnabled != originalPeriodizationEnabled {
            _ = try? await programService.updatePlanSettings(
                programId: program.id,
                userEmail: userEmail,
                totalWeeks: totalWeeks != originalTotalWeeks ? totalWeeks : nil,
                includeDeload: deloadEnabled != originalDeloadEnabled ? deloadEnabled : nil,
                periodizationEnabled: periodizationEnabled != originalPeriodizationEnabled ? periodizationEnabled : nil
            )
        }

        // Apply warmup/cooldown preference changes
        if warmupEnabled != originalWarmupEnabled ||
           cooldownEnabled != originalCooldownEnabled {
            try? await programService.updatePlanPreference(
                userEmail: userEmail,
                warmupEnabled: warmupEnabled != originalWarmupEnabled ? warmupEnabled : nil,
                cooldownEnabled: cooldownEnabled != originalCooldownEnabled ? cooldownEnabled : nil
            )
        }

        // Update original values to match current (changes are now saved)
        updateOriginalValues()
    }

    // MARK: - Sync Methods

    private func syncFromActiveProgram() {
        guard let program = programService.activeProgram else { return }

        // Set current values
        selectedGoal = program.fitnessGoalEnum ?? .hypertrophy
        selectedExperience = program.experienceLevelEnum ?? .intermediate
        daysPerWeek = program.daysPerWeek
        sessionDuration = program.sessionDurationMinutes
        totalWeeks = program.totalWeeks
        trainingSplit = program.programTypeEnum ?? .fullBody
        deloadEnabled = program.includeDeload
        periodizationEnabled = program.periodizationEnabled ?? true
        warmupEnabled = program.defaultWarmupEnabled ?? true
        cooldownEnabled = program.defaultCooldownEnabled ?? true

        // Sync from profile for settings not stored in program
        warmupSetsEnabled = profile.warmupSetsEnabled
        circuitsEnabled = profile.circuitsAndSupersetsEnabled

        // Set original values (for change detection)
        updateOriginalValues()
    }

    private func updateOriginalValues() {
        originalGoal = selectedGoal
        originalExperience = selectedExperience
        originalDaysPerWeek = daysPerWeek
        originalSessionDuration = sessionDuration
        originalTotalWeeks = totalWeeks
        originalTrainingSplit = trainingSplit
        originalWarmupSetsEnabled = warmupSetsEnabled
        originalCircuitsEnabled = circuitsEnabled
        originalDeloadEnabled = deloadEnabled
        originalPeriodizationEnabled = periodizationEnabled
        originalCardioEnabled = cardioEnabled
        originalWarmupEnabled = warmupEnabled
        originalCooldownEnabled = cooldownEnabled
    }
}

// MARK: - Fitness Goal Selection Sheet

private struct FitnessGoalSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedGoal: ProgramFitnessGoal
    let onSelect: (ProgramFitnessGoal) -> Void

    private var rowBackground: Color { Color("altcard") }

    var body: some View {
        NavigationStack {
            List {
                ForEach(ProgramFitnessGoal.allCases, id: \.self) { goal in
                    Button {
                        onSelect(goal)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Text(goal.description)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedGoal == goal {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(rowBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("altbg").ignoresSafeArea())
            .navigationTitle("Fitness Goal")
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
            }
        }
    }
}

// MARK: - Gym Profiles Sheet

private struct GymProfilesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    let userEmail: String

    @State private var showManageProfiles = false
    @State private var showCreateProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(userProfileService.workoutProfiles, id: \.id) { profile in
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
                                if profile.id == userProfileService.activeWorkoutProfileId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
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
            }
            .navigationTitle("Gym Profiles")
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateProfile = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .navigationDestination(isPresented: $showManageProfiles) {
                ManageGymProfilesSheet(userEmail: userEmail)
            }
            .navigationDestination(isPresented: $showCreateProfile) {
                CreateGymProfileSheet(userEmail: userEmail)
            }
        }
    }

    private func selectProfile(_ profile: WorkoutProfile) {
        guard let profileId = profile.id else {
            dismiss()
            return
        }

        guard profileId != userProfileService.activeWorkoutProfileId else {
            dismiss()
            return
        }

        Task {
            do {
                try await userProfileService.activateWorkoutProfile(profileId: profileId)
            } catch {
                print("❌ Failed to activate profile: \(error.localizedDescription)")
            }
        }

        dismiss()
    }
}

// MARK: - Manage Gym Profiles Sheet

private struct ManageGymProfilesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    let userEmail: String

    @State private var showCreateProfile = false

    var body: some View {
        List {
            ForEach(userProfileService.workoutProfiles, id: \.id) { profile in
                NavigationLink {
                    GymProfileEquipmentSheet(profile: profile, userEmail: userEmail)
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

                        if profile.id == userProfileService.activeWorkoutProfileId {
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateProfile = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .navigationDestination(isPresented: $showCreateProfile) {
            CreateGymProfileSheet(userEmail: userEmail)
        }
    }
}

// MARK: - Create Gym Profile Sheet

private struct CreateGymProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    let userEmail: String

    @State private var profileName: String = ""
    @State private var selectedOption: OnboardingViewModel.GymLocationOption = .largeGym
    @State private var selectedEquipment: Set<Equipment> = Set(Equipment.allCases.filter { $0 != .bodyWeight })
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Get default equipment for a gym location option
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Profile name
                VStack(alignment: .leading, spacing: 12) {
                    Text("Profile Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("Gym Name", text: $profileName)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color("containerbg"))
                        .cornerRadius(100)
                        .submitLabel(.done)
                }

                // Gym type
                VStack(alignment: .leading, spacing: 12) {
                    Text("Gym Type")
                        .font(.headline)
                        .foregroundColor(.primary)

                    ForEach(OnboardingViewModel.GymLocationOption.allCases) { option in
                        Button {
                            selectedOption = option
                            if option != .custom {
                                selectedEquipment = Self.equipmentDefaults(for: option)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(option.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(option.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedOption == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                            }
                            .padding()
                            .background(Color("containerbg"))
                            .cornerRadius(12)
                        }
                    }
                }

                // Equipment selection
                EquipmentGridView(selectedEquipment: $selectedEquipment)
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
                .disabled(isSaving || trimmedProfileName.isEmpty)
            }
        }
        .alert("Unable to Create Gym Profile", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var trimmedProfileName: String {
        profileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func createProfile() async {
        guard !trimmedProfileName.isEmpty else { return }
        isSaving = true

        do {
            try await userProfileService.createWorkoutProfile(named: trimmedProfileName)

            // Update equipment for the newly created profile
            if let newProfile = userProfileService.workoutProfiles.first(where: { $0.displayName == trimmedProfileName }),
               let profileId = newProfile.id {
                let orderedEquipment = Equipment.allCases.filter { selectedEquipment.contains($0) && $0 != .bodyWeight }

                NetworkManagerTwo.shared.updateWorkoutPreferences(
                    email: userEmail,
                    workoutData: [
                        "profile_id": profileId,
                        "available_equipment": orderedEquipment.map { $0.rawValue }
                    ]
                ) { _ in }
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

// MARK: - Gym Profile Equipment Sheet

private struct GymProfileEquipmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userProfileService = UserProfileService.shared
    let profile: WorkoutProfile
    let userEmail: String

    @State private var editedName: String
    @State private var selectedEquipment: Set<Equipment>
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    init(profile: WorkoutProfile, userEmail: String) {
        self.profile = profile
        self.userEmail = userEmail
        _editedName = State(initialValue: profile.displayName)
        // Convert String array to Set<Equipment>
        let equipmentSet = Set(profile.availableEquipment.compactMap { Equipment(rawValue: $0) })
        _selectedEquipment = State(initialValue: equipmentSet)
    }

    private var canDelete: Bool {
        userProfileService.workoutProfiles.count > 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Profile name
                VStack(alignment: .leading, spacing: 12) {
                    Text("Profile Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    TextField("Name", text: $editedName)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color("containerbg"))
                        .cornerRadius(100)
                        .submitLabel(.done)
                        .onChange(of: editedName) { _, newValue in
                            saveProfileName(newValue)
                        }
                }

                // Equipment selection
                EquipmentGridView(selectedEquipment: $selectedEquipment)
                    .onChange(of: selectedEquipment) { _, newValue in
                        saveEquipment(newValue)
                    }

                // Delete button
                if canDelete {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if isDeleting {
                                ProgressView()
                            } else {
                                Label("Delete Profile", systemImage: "trash")
                            }
                            Spacer()
                        }
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(isDeleting)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color("primarybg").ignoresSafeArea())
        .navigationTitle(profile.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete Profile?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await deleteProfile() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This gym profile will be permanently deleted. This action cannot be undone.")
        }
    }

    private func saveProfileName(_ name: String) {
        guard let profileId = profile.id else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        NetworkManagerTwo.shared.updateWorkoutPreferences(
            email: userEmail,
            workoutData: [
                "profile_id": profileId,
                "profile_name": trimmed
            ]
        ) { _ in }
    }

    private func saveEquipment(_ equipment: Set<Equipment>) {
        guard let profileId = profile.id else { return }
        let orderedEquipment = Equipment.allCases.filter { equipment.contains($0) && $0 != .bodyWeight }

        NetworkManagerTwo.shared.updateWorkoutPreferences(
            email: userEmail,
            workoutData: [
                "profile_id": profileId,
                "available_equipment": orderedEquipment.map { $0.rawValue }
            ]
        ) { _ in }
    }

    @MainActor
    private func deleteProfile() async {
        guard let profileId = profile.id, canDelete else { return }
        isDeleting = true

        do {
            try await userProfileService.deleteWorkoutProfile(profileId: profileId)
            dismiss()
        } catch {
            print("❌ Failed to delete profile: \(error.localizedDescription)")
            isDeleting = false
        }
    }
}

// MARK: - Equipment Grid View

private struct EquipmentGridView: View {
    @Binding var selectedEquipment: Set<Equipment>

    private var equipmentSections: [(title: String, items: [Equipment])] {
        let allEquipment = Set(Equipment.allCases)

        func filtered(_ equipments: [Equipment]) -> [Equipment] {
            equipments
                .filter { allEquipment.contains($0) && $0 != .bodyWeight }
                .sorted { $0.rawValue < $1.rawValue }
        }

        return [
            ("Small Weights", filtered([.dumbbells, .kettlebells])),
            ("Bars & Plates", filtered([.barbells, .ezBar])),
            ("Benches & Racks", filtered([.flatBench, .inclineBench, .declineBench, .squatRack, .preacherCurlBench])),
            ("Cable Machines", filtered([.cable, .latPulldownCable, .rowMachine])),
            ("Resistance Bands", filtered([.resistanceBands])),
            ("Exercise Balls & More", filtered([.stabilityBall, .medicineBalls, .bosuBalanceTrainer, .box, .pvc])),
            ("Plated Machines", filtered([.hammerstrengthMachine, .legPress, .hackSquatMachine, .sled])),
            ("Weight Machines", filtered([
                .smithMachine, .legExtensionMachine, .legCurlMachine, .calfRaiseMachine,
                .shoulderPressMachine, .tricepsExtensionMachine, .bicepsCurlMachine,
                .abCrunchMachine, .preacherCurlMachine
            ])),
            ("Specialties", filtered([
                .pullupBar, .dipBar, .battleRopes, .rings, .platforms
            ]))
        ]
        .filter { !$0.items.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Available Equipment")
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(equipmentSections, id: \.title) { section in
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(section.items, id: \.self) { equipment in
                            EquipmentSelectionButton(
                                equipment: equipment,
                                isSelected: selectedEquipment.contains(equipment),
                                onTap: { toggleSelection(for: equipment) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func toggleSelection(for equipment: Equipment) {
        HapticFeedback.generate()
        if selectedEquipment.contains(equipment) {
            selectedEquipment.remove(equipment)
        } else {
            selectedEquipment.insert(equipment)
        }
    }
}

// Helper to detect changes on binding
extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}
