//
//  WorkoutScheduleSettingsView.swift
//  Pods
//
//  Created by Codex on 9/7/25.
//

import SwiftUI

struct WorkoutScheduleSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isTabBarVisible) private var isTabBarVisible
    @EnvironmentObject private var viewModel: OnboardingViewModel

    // Persisted settings
    @AppStorage("workoutDaysPerWeek") private var daysPerWeek: Int = 4
    // Store selected workout days as JSON Data of [Int] (0=Sun ... 6=Sat)
    @AppStorage("preferredWorkoutDays") private var preferredDaysData: Data = {
        let defaultDays = [1, 3, 5] // Mon/Wed/Fri
        return (try? JSONEncoder().encode(defaultDays)) ?? Data()
    }()

    // Local UI state
    @State private var selectedDays: Set<Int> = []
    private let weekDays: [String] = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private let frequencyOptions: [Int] = [7, 6, 5, 4, 3, 2, 1]

    var body: some View {
        ZStack {
            formBackgroundColor.edgesIgnoringSafeArea(.all)
            Form {
                Section(header: Text("Frequency")) {
                    ForEach(frequencyOptions, id: \.self) { count in
                        Button(action: { selectFrequency(count) }) {
                            HStack {
                                Text(frequencyTitle(for: count))
                                    .foregroundColor(textColor)
                                Spacer()
                                if daysPerWeek == count { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                            }
                        }
                    }
                }
                .listRowBackground(colorScheme == .dark ? Color(rgb:44,44,44) : .white)

                Section(header: Text("Select Specific Days")) {
                    ForEach(0..<7, id: \.self) { index in
                        Button(action: { toggleDay(index) }) {
                            HStack {
                                Text(weekDays[index])
                                    .foregroundColor(textColor)
                                Spacer()
                                if selectedDays.contains(index) { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                            }
                        }
                    }
                }
                .listRowBackground(colorScheme == .dark ? Color(rgb:44,44,44) : .white)

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it works")
                            .font(.footnote).bold()
                            .foregroundColor(textColor)
                        Text("Choose a weekly frequency or directly select which days you prefer to train. Your selection saves automatically.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(colorScheme == .dark ? Color(rgb:44,44,44) : .white)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Workout Schedule")
        .onAppear {
            isTabBarVisible.wrappedValue = false
            loadSelectedDays()
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
            saveSelections() // Ensure persistence when leaving
        }
    }

    // MARK: - Actions
    private func selectFrequency(_ count: Int) {
        daysPerWeek = count
        if selectedDays.count != count {
            selectedDays = defaultDays(for: count)
        }
        saveSelections()
        HapticFeedback.generate()
    }

    private func toggleDay(_ index: Int) {
        if selectedDays.contains(index) { selectedDays.remove(index) } else { selectedDays.insert(index) }
        daysPerWeek = selectedDays.count
        saveSelections()
        HapticFeedback.generate()
    }

    // MARK: - Persistence
    private func loadSelectedDays() {
        if let decoded = try? JSONDecoder().decode([Int].self, from: preferredDaysData) {
            selectedDays = Set(decoded)
        }
        if selectedDays.isEmpty {
            selectedDays = defaultDays(for: daysPerWeek)
        }
    }

    private func saveSelections() {
        let arr = Array(selectedDays).sorted()
        if let data = try? JSONEncoder().encode(arr) { preferredDaysData = data }

        // Also update onboarding model for consistency with backend payload shape
        viewModel.workoutDaysPerWeek = daysPerWeek
        let rest = restDays(from: selectedDays)
        viewModel.restDays = rest
        UserDefaults.standard.set(daysPerWeek, forKey: "workout_days_per_week")
        UserDefaults.standard.set(rest, forKey: "rest_days")
    }

    // MARK: - Helpers
    private func frequencyTitle(for count: Int) -> String {
        if count == 7 { return "Every Day" }
        return "\(count) day\(count == 1 ? "" : "s") a week"
    }

    private func defaultDays(for count: Int) -> Set<Int> {
        switch count {
        case 7: return Set(0...6) // All
        case 6: return Set(1...6) // Mon-Sat
        case 5: return Set(1...5) // Mon-Fri
        case 4: return Set([1,2,4,5]) // Mon, Tue, Thu, Fri
        case 3: return Set([1,3,5]) // Mon, Wed, Fri
        case 2: return Set([2,4])   // Tue, Thu
        case 1: return Set([3])     // Wed
        default: return []
        }
    }

    private func restDays(from workoutDays: Set<Int>) -> [String] {
        let all = Set(0...6)
        let rest = all.subtracting(workoutDays).sorted()
        return rest.map { weekDays[$0] }
    }

    private var formBackgroundColor: Color {
        colorScheme == .dark ? Color(rgb: 14, 14, 14) : Color(rgb: 242, 242, 242)
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

#Preview {
    NavigationView {
        WorkoutScheduleSettingsView()
            .environmentObject(OnboardingViewModel())
    }
}

