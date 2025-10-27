import SwiftUI
import UIKit

struct WorkoutProfileSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var profile = UserProfileService.shared
    @ObservedObject private var workoutManager = WorkoutManager.shared

    @State private var showDurationPicker = false
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 45
    @State private var showNewProfileSheet = false
    @State private var showSwitchProfileSheet = false
    @State private var newProfileName: String = ""
    @State private var isCreatingProfile = false
    @State private var isSwitchingProfile = false
    @FocusState private var isNewProfileFieldFocused: Bool
    @State private var showDeleteProfileAlert = false
    @State private var profilePendingDeletion: WorkoutProfile?
    @State private var isDeletingProfile = false
    @State private var deletionError: String?
    @State private var showEquipmentSheet = false
    @State private var equipmentSelection: Set<Equipment> = []
    @State private var equipmentSelectionBackup: Set<Equipment> = []

    private var rowBackground: Color { Color("altcard") }
    private var iconColor: Color { colorScheme == .dark ? .white : .primary }

    private var currentProfileTitle: String {
        profile.activeWorkoutProfile?.displayName ?? "Gym Profile"
    }

    private var canSwitchProfiles: Bool {
        profile.workoutProfiles.count > 1
    }

    private var canDeleteProfiles: Bool {
        profile.workoutProfiles.count > 1
    }

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
            Section(header: Text("Gym Equipment")) {
                Button {
                    let currentSelection = Set(profile.availableEquipment)
                    equipmentSelection = currentSelection
                    equipmentSelectionBackup = currentSelection
                    showEquipmentSheet = true
                } label: {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "dumbbell")
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(iconColor)
                            Text("Available Equipment")
                                .font(.system(size: 15))
                                .foregroundColor(iconColor)
                        }
                        Spacer()
                        Text(equipmentSelectionSummary)
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(rowBackground)

                Toggle(isOn: Binding(
                    get: { profile.bodyweightOnlyWorkouts },
                    set: { newValue in
                        profile.bodyweightOnlyWorkouts = newValue
                        sendPreferenceUpdate(["bodyweight_only_workout": newValue])
                        if newValue {
                            let bodyweightEquipment = EquipmentView.EquipmentType.bodyweightOnly.equipmentList
                            workoutManager.customEquipment = bodyweightEquipment
                        } else {
                            workoutManager.customEquipment = nil
                        }
                        Task { await workoutManager.generateTodayWorkout() }
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                        Text("Bodyweight Only Workout")
                            .font(.system(size: 15))
                            .foregroundColor(iconColor)
                    }
                }
                .tint(.accentColor)
                .listRowBackground(rowBackground)
            }

            Section(header: Text("Workout Settings")) {
                // Fitness Goal
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                        Text("Fitness Goal")
                            .font(.system(size: 15))
                            .foregroundColor(iconColor)
                    }
                    Spacer()
                    Menu {
                        ForEach(FitnessGoalPickerView.canonicalGoals, id: \.self) { goal in
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

                // Fitness Experience
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "aqi.medium")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                        Text("Fitness Experience")
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

                // Exercise Variability
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                        Text("Exercise Variability")
                            .font(.system(size: 15))
                            .foregroundColor(iconColor)
                    }
                    Spacer()
                    Menu {
                        ForEach(ExerciseVariabilityPreference.allCases, id: \.self) { pref in
                            Button(action: {
                                profile.exerciseVariability = pref
                                sendPreferenceUpdate(["exercise_variability": pref.rawValue])
                            }) {
                                HStack {
                                    Text(pref.displayName)

                                    if profile.exerciseVariability == pref { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(profile.exerciseVariability.displayName)
                                .foregroundColor(.secondary)
                                .font(.system(size: 15))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
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

                // Warm-up Sets
                Toggle(isOn: Binding(
                    get: { profile.warmupSetsEnabled },
                    set: { newVal in
                        profile.warmupSetsEnabled = newVal
                        if !newVal {
                            WorkoutManager.shared.clearWarmupSetsForCurrentWorkout()
                        }
                        // Per-exercise warm-up sets flag (distinct from warm-up section)
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

                // Workout Duration (inline picker on tap)
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
                            // Hours
                            Picker("Hours", selection: $durationHours.onChange { _ in updateDuration() }) {
                                ForEach(0...2, id: \.self) { Text("\($0) h").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            // Minutes
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
              

                // Training Splits
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "square.split.2x2")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                        Text("Training Splits")
                            .font(.system(size: 15))
                            .foregroundColor(iconColor)
                    }
                    Spacer()
                    Menu {
                        ForEach(TrainingSplitPreference.allCases, id: \.self) { split in
                            Button(action: {
                                profile.trainingSplit = split
                                sendPreferenceUpdate(["training_split": split.rawValue])

                                // Directly regenerate workout (no race condition)
                                Task {
                                    await workoutManager.generateTodayWorkout()
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

                // Muscle Recovery Percentage
                NavigationLink {
                    EditMuscleRecoveryView()
                } label: {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.heart")
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(iconColor)
                            Text("Muscle Recovery Percentage")
                                .font(.system(size: 15))
                                .foregroundColor(iconColor)
                        }
                        
                    }
                }
                .listRowBackground(rowBackground)
            }
        }
        .environment(\.defaultMinListRowHeight,52)
        .navigationTitle(currentProfileTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        presentNewProfileSheet()
                    } label: {
                        Label("New Profile", systemImage: "plus")
                    }
                    Button {
                        showSwitchProfileSheet = true
                    } label: {
                        Label("Switch Profile", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(!canSwitchProfiles)
                    if let activeProfile = profile.activeWorkoutProfile {
                        Button(role: .destructive) {
                            profilePendingDeletion = activeProfile
                            showDeleteProfileAlert = true
                        } label: {
                            Label("Delete Profile", systemImage: "trash")
                        }
                        .disabled(!canDeleteProfiles || isDeletingProfile)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showNewProfileSheet) { newProfileSheet() }
        .sheet(isPresented: $showSwitchProfileSheet) { switchProfileSheet() }
        .sheet(isPresented: $showEquipmentSheet) { equipmentSelectionSheet() }
        .alert("Delete Gym Profile?", isPresented: $showDeleteProfileAlert, presenting: profilePendingDeletion) { pending in
            Button("Delete", role: .destructive) {
                Task { await deleteProfile(pending) }
            }
            Button("Cancel", role: .cancel) {
                profilePendingDeletion = nil
            }
        } message: { pending in
            Text("This will remove \(pending.displayName). You cannot undo this action.")
        }
        .alert("Unable to Delete Profile", isPresented: deletionErrorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deletionError ?? "Please try again later.")
        }
        .task {
            if profile.workoutProfiles.isEmpty {
                await profile.refreshWorkoutProfiles()
            }
        }
        .onAppear { syncInitialDuration() }
        .scrollContentBackground(.hidden)
        .background(Color("altbg").ignoresSafeArea())
        .onChange(of: showDurationPicker) { newVal in
            if newVal == false { // picker closed → persist to server
                sendPreferenceUpdate(["preferred_workout_duration": profile.availableTime])
            }
        }
        .onChange(of: profile.activeWorkoutProfileId) { _ in
            syncInitialDuration()
        }
    }
}

extension WorkoutProfileSettingsView {
    private func presentNewProfileSheet() {
        newProfileName = ""
        showNewProfileSheet = true
    }

    @ViewBuilder
    private func newProfileSheet() -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $newProfileName)
                        .disabled(isCreatingProfile)
                        .submitLabel(.done)
                        .onSubmit { Task { await createProfile() } }
                        .focused($isNewProfileFieldFocused)
                }
            }
            .formStyle(.grouped)
            .padding(.top, -12)
            .navigationTitle("New Gym Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showNewProfileSheet = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(isCreatingProfile)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createProfile() }
                    } label: {
                        if isCreatingProfile {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .disabled(isCreatingProfile || newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    isNewProfileFieldFocused = true
                }
            }
            .onDisappear {
                isNewProfileFieldFocused = false
            }
        }
    }

    @ViewBuilder
    private func switchProfileSheet() -> some View {
        NavigationStack {
            List {
                ForEach(profile.workoutProfiles) { item in
                    Button {
                        Task { await switchProfile(to: item) }
                    } label: {
                        HStack {
                            Text(item.displayName)
                            .foregroundColor(.primary)
                            Spacer()
                            if item.id == profile.activeWorkoutProfile?.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .disabled(isSwitchingProfile || item.id == nil || item.id == profile.activeWorkoutProfile?.id)
                }
            }
            .navigationTitle("Switch Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showSwitchProfileSheet = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(isSwitchingProfile)
                }
            }
        }
    }

    private func persistEquipmentSelection(_ selection: Set<Equipment>) {
        let ordered = Equipment.allCases.filter { selection.contains($0) && $0 != .bodyWeight }
        equipmentSelection = Set(ordered)
        equipmentSelectionBackup = Set(ordered)
        profile.availableEquipment = ordered
        sendPreferenceUpdate(["available_equipment": ordered.map { $0.rawValue }])
        showEquipmentSheet = false
        Task {
            await workoutManager.generateTodayWorkout()
        }
    }

    @ViewBuilder
    private func equipmentSelectionSheet() -> some View {
        GymEquipmentSelectionSheet(
            selection: $equipmentSelection,
            onSave: { persistEquipmentSelection($0) },
            onCancel: {
                equipmentSelection = equipmentSelectionBackup
                showEquipmentSheet = false
            }
        )
    }

    @MainActor
    private func createProfile() async {
        let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isCreatingProfile = true
        defer { isCreatingProfile = false }
        do {
            try await profile.createWorkoutProfile(named: trimmed)
            newProfileName = ""
            showNewProfileSheet = false
        } catch {
            print("❌ Failed to create workout profile: \(error)")
        }
    }

    @MainActor
    private func switchProfile(to item: WorkoutProfile) async {
        guard let identifier = item.id else { return }
        isSwitchingProfile = true
        defer { isSwitchingProfile = false }
        do {
            try await profile.activateWorkoutProfile(profileId: identifier)
            showSwitchProfileSheet = false
        } catch {
            print("❌ Failed to switch workout profile: \(error)")
        }
    }

    @MainActor
    private func deleteProfile(_ workoutProfile: WorkoutProfile) async {
        guard let identifier = workoutProfile.id else { return }
        guard canDeleteProfiles else {
            deletionError = "You must keep at least one gym profile."
            showDeleteProfileAlert = false
            return
        }

        isDeletingProfile = true
        defer { isDeletingProfile = false }

        do {
            try await profile.deleteWorkoutProfile(profileId: identifier)
            profilePendingDeletion = nil
            showDeleteProfileAlert = false
        } catch {
            deletionError = error.localizedDescription
        }
    }

    private var deletionErrorBinding: Binding<Bool> {
        Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )
    }
}

private struct GymEquipmentSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Set<Equipment>
    let onSave: (Set<Equipment>) -> Void
    let onCancel: () -> Void

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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Pick the equipment available at your gym. We use this to tailor workouts to what you can actually use.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    ForEach(equipmentSections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundColor(.primary)

                            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(section.items, id: \.self) { equipment in
                                    EquipmentSelectionButton(
                                        equipment: equipment,
                                        isSelected: selection.contains(equipment),
                                        onTap: { toggleSelection(for: equipment) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color("altbg").ignoresSafeArea())
            .navigationTitle("Gym Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selection)
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggleSelection(for equipment: Equipment) {
        HapticFeedback.generate()
        UISelectionFeedbackGenerator().selectionChanged()
        if selection.contains(equipment) {
            selection.remove(equipment)
        } else {
            selection.insert(equipment)
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
