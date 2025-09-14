import SwiftUI

struct WorkoutProfileSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var profile = UserProfileService.shared

    @State private var showDurationPicker = false
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 45

    private var rowBackground: Color { Color("primarybg") }
    private var iconColor: Color { colorScheme == .dark ? .white : .primary }

    private var formattedDuration: String {
        let total = profile.availableTime
        let h = total / 60
        let m = total % 60
        if h > 0 && m > 0 { return String(format: "%dh %02dm", h, m) }
        if h > 0 { return String(format: "%dh", h) }
        return String(format: "%dm", m)
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
        NetworkManagerTwo.shared.updateWorkoutPreferences(email: email, workoutData: data) { result in
            switch result {
            case .success:
                Task { await DataLayer.shared.updateProfileData(data) }
            case .failure(let err):
                print("❌ Failed to update workout prefs: \(err)")
            }
        }
    }

    var body: some View {
        Form {
            Section {
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
                            Button(action: { profile.exerciseVariability = pref }) {
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
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(rowBackground)

                // Timed Intervals
                Toggle(isOn: Binding(
                    get: { profile.timedIntervalsEnabled },
                    set: { newVal in
                        profile.timedIntervalsEnabled = newVal
                        sendPreferenceUpdate(["enable_timed_intervals": newVal])
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "stopwatch")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                        Text("Timed Intervals")
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

                // Warm-up Sets
                Toggle(isOn: Binding(
                    get: { profile.warmupSetsEnabled },
                    set: { newVal in
                        profile.warmupSetsEnabled = newVal
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
                            Button(action: { profile.trainingSplit = split }) {
                                HStack {
                                    Text(split.displayName)
                                    if profile.trainingSplit == split { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(profile.trainingSplit.displayName)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                
                        }
                    }
                }
                .listRowBackground(rowBackground)

                // Muscle Recovery Percentage (display-only for now)
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
                    Spacer()
                    Text("\(profile.muscleRecoveryTargetPercent)%")
                        .foregroundColor(.secondary)
                }
                .listRowBackground(rowBackground)
            }
        }
        .environment(\.defaultMinListRowHeight,52)
        .navigationTitle("Workout Settings")
        .onAppear { syncInitialDuration() }
        .scrollContentBackground(.hidden)
        .background(Color("containerbg").ignoresSafeArea())
        .onChange(of: showDurationPicker) { newVal in
            if newVal == false { // picker closed → persist to server
                sendPreferenceUpdate(["preferred_workout_duration": profile.availableTime])
            }
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
