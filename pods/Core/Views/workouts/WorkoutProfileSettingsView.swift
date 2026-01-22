import SwiftUI
import UIKit

struct WorkoutProfileSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var profile = UserProfileService.shared
    @ObservedObject private var workoutManager = WorkoutManager.shared
    @AppStorage("userEmail") private var userEmail: String = ""

    @State private var showDurationPicker = false
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 45
    @State private var showGymProfilesSheet = false

    private var rowBackground: Color { Color("altcard") }
    private var iconColor: Color { colorScheme == .dark ? .white : .primary }

    // Limited training splits as per requirements
    private static let allowedSplits: [TrainingSplitPreference] = [
        .fullBody,
        .pushPullLower,
        .upperLower
    ]

    private var formattedDuration: String {
        let total = profile.availableTime
        let h = total / 60
        let m = total % 60
        if h > 0 && m > 0 { return String(format: "%dh %02dm", h, m) }
        if h > 0 { return String(format: "%dh", h) }
        return String(format: "%dm", m)
    }

    private var equipmentSelectionSummary: String {
        if profile.bodyweightOnlyWorkouts {
            return "Bodyweight only"
        }
        let count = profile.availableEquipment.count
        return count == 0 ? "Select" : "\(count) selected"
    }

    private func syncInitialDuration() {
        let total = max(15, profile.availableTime)
        durationHours = total / 60
        durationMinutes = total % 60
        // snap minutes to 0/15/30/45
        let options = [0,15,30,45]
        durationMinutes = options.min(by: { abs($0 - durationMinutes) < abs($1 - durationMinutes) }) ?? 45
    }

    private func updateDuration() {
        let clampedH = min(max(durationHours, 0), 2)
        let allowedMins = [0,15,30,45]
        let snappedM = allowedMins.contains(durationMinutes) ? durationMinutes : 45
        profile.availableTime = max(15, clampedH * 60 + snappedM)
    }

    private func sendPreferenceUpdate(_ data: [String: Any]) {
        let email = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        guard !email.isEmpty else { return }
        var payload = data
        if let profileId = profile.activeWorkoutProfile?.id {
            payload["profile_id"] = profileId
        }
        NetworkManagerTwo.shared.updateWorkoutPreferences(email: email, workoutData: payload) { result in
            switch result {
            case .success:
                // CRITICAL FIX: Use Task { @MainActor in } to ensure DataLayer runs on main thread
                // This prevents "Publishing changes from background threads" violations
                Task { @MainActor in
                    await DataLayer.shared.updateProfileData(payload)
                }
            case .failure(let err):
                print("❌ Failed to update workout prefs: \(err)")
            }
        }
    }

    var body: some View {
        Form {
            // MARK: - Gym Equipment Section
            Section(header: Text("Gym Equipment")) {
                // Gym Profile selector - tap to manage profiles
                Button {
                    showGymProfilesSheet = true
                } label: {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "dumbbell")
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(iconColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gym Profile")
                                    .font(.system(size: 15))
                                    .foregroundColor(iconColor)
                                Text(profile.activeWorkoutProfile?.displayName ?? "Default")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(equipmentSelectionSummary)
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(rowBackground)
            }

            // MARK: - Workout Settings Section
            Section(header: Text("Workout Settings")) {
                // Training Split
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "square.split.2x2")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                        Text("Training Split")
                            .font(.system(size: 15))
                            .foregroundColor(iconColor)
                    }
                    Spacer()
                    Menu {
                        ForEach(Self.allowedSplits, id: \.self) { split in
                            Button(action: {
                                profile.trainingSplit = split
                                sendPreferenceUpdate(["training_split": split.rawValue])

                                Task {
                                    await workoutManager.generateTodayWorkout(forceRegenerate: true)
                                }
                            }) {
                                HStack {
                                    Text(split.displayName)
                                    if profile.trainingSplit == split { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(profile.trainingSplit.displayName)
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(rowBackground)

                // Workout Duration
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(iconColor)
                            Text("Workout Duration")
                                .font(.system(size: 15))
                                .foregroundColor(iconColor)
                        }
                        Spacer()
                        Button(action: { withAnimation { showDurationPicker.toggle() } }) {
                            Text(formattedDuration)
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                        }
                        .buttonStyle(.plain)
                    }

                    if showDurationPicker {
                        HStack {
                            Picker("Hours", selection: $durationHours.onChange { _ in updateDuration() }) {
                                ForEach(0...2, id: \.self) { Text("\($0) h").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Minutes", selection: $durationMinutes.onChange { _ in updateDuration() }) {
                                ForEach([0,15,30,45], id: \.self) { Text("\($0) m").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: 120)
                    }
                }
                .listRowBackground(rowBackground)

                // Experience Level
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "aqi.medium")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                        Text("Experience Level")
                            .font(.system(size: 15))
                            .foregroundColor(iconColor)
                    }
                    Spacer()
                    Menu {
                        ForEach(ExperienceLevel.allCases, id: \.self) { lvl in
                            Button(action: {
                                profile.experienceLevel = lvl
                                sendPreferenceUpdate(["experience_level": lvl.rawValue])
                            }) {
                                HStack {
                                    Text(lvl.displayName)
                                    if profile.experienceLevel == lvl { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(profile.experienceLevel.displayName)
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(rowBackground)

                // Training Goal
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                        Text("Training Goal")
                            .font(.system(size: 15))
                            .foregroundColor(iconColor)
                    }
                    Spacer()
                    Menu {
                        ForEach(FitnessGoalPickerView.pickerGoals, id: \.self) { goal in
                            Button(action: {
                                profile.fitnessGoal = goal
                                sendPreferenceUpdate(["preferred_fitness_goal": goal.rawValue])
                            }) {
                                HStack {
                                    Text(goal.displayName)
                                    if profile.fitnessGoal.normalized == goal.normalized { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(profile.fitnessGoal.displayName)
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(rowBackground)

                // Warm-up Sets
                Toggle(isOn: Binding(
                    get: { profile.warmupSetsEnabled },
                    set: { newVal in
                        profile.warmupSetsEnabled = newVal
                        if !newVal {
                            WorkoutManager.shared.clearWarmupSetsForCurrentWorkout()
                        }
                        sendPreferenceUpdate(["enable_warmup_sets": newVal])
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "flame")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                        Text("Warm-up Sets")
                            .font(.system(size: 15))
                            .foregroundColor(iconColor)
                    }
                }
                .tint(.accentColor)
                .listRowBackground(rowBackground)

                // Circuits and Supersets
                Toggle(isOn: Binding(
                    get: { profile.circuitsAndSupersetsEnabled },
                    set: { newVal in
                        profile.circuitsAndSupersetsEnabled = newVal
                        sendPreferenceUpdate(["enable_circuits_and_supersets": newVal])
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                        Text("Circuits and Supersets")
                            .font(.system(size: 15))
                            .foregroundColor(iconColor)
                    }
                }
                .tint(.accentColor)
                .listRowBackground(rowBackground)
            }
        }
        .environment(\.defaultMinListRowHeight, 52)
        .navigationTitle("Workout Settings")
        .sheet(isPresented: $showGymProfilesSheet) {
            GymProfilesSheet(userEmail: userEmail)
        }
        .onAppear { syncInitialDuration() }
        .scrollContentBackground(.hidden)
        .background(Color("altbg").ignoresSafeArea())
        .onChange(of: showDurationPicker) { newVal in
            if newVal == false {
                sendPreferenceUpdate(["preferred_workout_duration": profile.availableTime])
            }
        }
        .onChange(of: profile.activeWorkoutProfileId) { _ in
            syncInitialDuration()
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
                        .onChange(of: editedName) { newValue in
                            saveProfileName(newValue)
                        }
                }

                // Equipment selection
                EquipmentGridView(selectedEquipment: $selectedEquipment)
                    .onChange(of: selectedEquipment) { newValue in
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
