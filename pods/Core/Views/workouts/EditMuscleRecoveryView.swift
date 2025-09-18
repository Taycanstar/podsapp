import SwiftUI

struct EditMuscleRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profile = UserProfileService.shared
    private let recoveryService = MuscleRecoveryService.shared

    private let mainMuscleGroups = [
        "Glutes", "Hamstrings", "Quadriceps", "Lower Back",
        "Triceps", "Chest", "Shoulders", "Abs", "Back", "Biceps"
    ]

    private let accessoryMuscleGroups = [
        "Calves", "Trapezius", "Abductors", "Adductors", "Neck", "Forearms"
    ]

    @State private var recoveryValues: [String: Double] = [:]
    @State private var initialValues: [String: Double] = [:]

    private var allMuscles: [String] {
        mainMuscleGroups + accessoryMuscleGroups
    }

    private var hasChanges: Bool {
        allMuscles.contains { muscle in
            let current = Int(round(recoveryValues[muscle] ?? 100))
            let original = Int(round(initialValues[muscle] ?? 100))
            return current != original
        }
    }

    var body: some View {
        List {
            Section("Main Muscle Groups") {
                ForEach(mainMuscleGroups, id: \.self) { muscle in
                    muscleRow(for: muscle)
                }
            }

            Section("Accessory Muscle Groups") {
                ForEach(accessoryMuscleGroups, id: \.self) { muscle in
                    muscleRow(for: muscle)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color("altbg").ignoresSafeArea())
        .navigationTitle("Muscle Recovery")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { loadRecoveryDefaults() }
    }

    private var toolbarContent: some ToolbarContent {
        Group {
     
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: saveChanges) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(hasChanges ? .white : .secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(hasChanges ? Color.accentColor : Color("thumbbg"))
                        )
                }
                .disabled(!hasChanges)
            }
        }
    }

    @ViewBuilder
    private func muscleRow(for muscle: String) -> some View {
        let value = recoveryValues[muscle] ?? 100

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(muscle)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(Int(round(value)))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 0) {
                Slider(value: binding(for: muscle), in: 0...100, step: 1)
                    .tint(.accentColor)
               
            }
        }
        .padding(.vertical, 6)
    }

    private func binding(for muscle: String) -> Binding<Double> {
        Binding(get: {
            recoveryValues[muscle] ?? 100
        }, set: { newValue in
            recoveryValues[muscle] = min(100, max(0, newValue))
        })
    }

    private func loadRecoveryDefaults() {
        guard recoveryValues.isEmpty else { return }

        let storedOverrides = profile.muscleRecoveryOverrides
        var seeded: [String: Double] = [:]

        for muscle in allMuscles {
            if let override = storedOverrides[muscle] {
                seeded[muscle] = min(100, max(0, override))
            } else {
                let computed = recoveryService.getMuscleRecoveryPercentage(for: muscle)
                seeded[muscle] = min(100, max(0, computed))
            }
        }

        recoveryValues = seeded
        initialValues = seeded
    }

    private func saveChanges() {
        var sanitized: [String: Double] = [:]

        for muscle in allMuscles {
            let value = min(100, max(0, recoveryValues[muscle] ?? 100))
            sanitized[muscle] = value
        }

        var overridesToPersist: [String: Double] = [:]
        for muscle in allMuscles {
            guard let newValue = sanitized[muscle], let original = initialValues[muscle] else { continue }
            if abs(newValue - original) >= 0.5 { // meaningful change
                overridesToPersist[muscle] = newValue
            }
        }

        profile.muscleRecoveryOverrides = overridesToPersist

        let targetPercent: Int? = sanitized.isEmpty
            ? nil
            : Int(round(sanitized.values.reduce(0, +) / Double(sanitized.count)))

        if let targetPercent {
            profile.muscleRecoveryTargetPercent = targetPercent
        }

        let email = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        if !email.isEmpty {
            var payload: [String: Any] = [
                "muscle_recovery_overrides": sanitized
            ]
            if let targetPercent {
                payload["muscle_recovery_target_percent"] = targetPercent
            }

            NetworkManagerTwo.shared.updateWorkoutPreferences(email: email, workoutData: payload) { result in
                switch result {
                case .success:
                    Task { await DataLayer.shared.updateProfileData(payload) }
                case .failure(let error):
                    print("❌ Failed to sync muscle recovery overrides: \(error)")
                }
            }
        }

        initialValues = sanitized
        recoveryValues = sanitized
        dismiss()
    }
}

#Preview {
    NavigationStack {
        EditMuscleRecoveryView()
    }
}
