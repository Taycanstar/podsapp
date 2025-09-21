import SwiftUI

// Local filter enum used by ManageExercisesView's Picker
enum FilterOption: String {
    case all
    case more
    case less
    case addedByMe
    case excluded
}

struct ManageExercisesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isTabBarVisible) var isTabBarVisible
    @ObservedObject private var ups = UserProfileService.shared
    @State private var searchText = ""
    @State private var selectedSegment = 0 // 0 = All, 1 = By Muscle
    @State private var selectedMuscle: String? = nil
    @State private var exercises: [ExerciseData] = []
    @State private var filter: FilterOption = .all
    @State private var navigateToHistory: Bool = false
    @State private var historyExercise: TodayWorkoutExercise? = nil

    private let segments = ["All", "By Muscle"]
    private let muscleGroups = [
        "Chest", "Abs", "Back", "Lower Back", "Trapezius", "Neck",
        "Shoulders", "Biceps", "Triceps", "Forearms", "Glutes",
        "Quadriceps", "Hamstrings", "Calves", "Abductors", "Adductors"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("Exercise Filter", selection: $selectedSegment) {
                ForEach(0..<segments.count, id: \.self) { index in
                    Text(segments[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .onChange(of: selectedSegment) { _, newValue in
                if newValue != 1 { selectedMuscle = nil }
            }

            // Muscle chips
            if selectedSegment == 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(muscleGroups, id: \.self) { muscle in
                            Button(action: {
                                if selectedMuscle == muscle { selectedMuscle = nil } else { selectedMuscle = muscle }
                            }) {
                                Text(muscle)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedMuscle == muscle ? Color(.systemBackground) : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedMuscle == muscle ? Color.primary : Color(.systemGray5))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
            }

            // Exercise list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sectionKeys, id: \.self) { sectionKey in
                        if let items = sections[sectionKey], !items.isEmpty {
                            Text(sectionKey)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                            ForEach(items, id: \.id) { ex in
                                ManageExerciseRow(exercise: ex,
                                                  onHistory: { openHistory(for: ex) },
                                                  onMoreOften: { setMoreOften(ex) },
                                                  onLessOften: { setLessOften(ex) },
                                                  onDoNotRecommend: { doNotRecommend(ex) })
                                .padding(.horizontal, 16)
                                .background(Color(.systemBackground))
                            }
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle("Manage Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Filter", selection: $filter) {
                        Text("All").tag(FilterOption.all)
                        Text("Recommend More").tag(FilterOption.more)
                        Text("Recommend Less").tag(FilterOption.less)
                        Text("Added by Me").tag(FilterOption.addedByMe)
                        Text("Excluded").tag(FilterOption.excluded)
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .onAppear {
            loadExercises()
            isTabBarVisible.wrappedValue = false
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
        }
        .background(
            NavigationLink(
                destination: destinationHistoryView,
                isActive: $navigateToHistory,
                label: { EmptyView() }
            ).hidden()
        )
    }

    // MARK: - Data
    private func loadExercises() {
        exercises = ExerciseDatabase.getAllExercises()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filtered: [ExerciseData] {
        var base = exercises
        let ups = self.ups
        switch filter {
        case .all:
            break
        case .more:
            base = base.filter { ups.getExercisePreferenceBias(exerciseId: $0.id) > 0 }
        case .less:
            base = base.filter { ups.getExercisePreferenceBias(exerciseId: $0.id) < 0 }
        case .excluded:
            let avoided = Set(ups.avoidedExercises)
            base = base.filter { avoided.contains($0.id) }
        case .addedByMe:
            // TODO: wire to real user-created list; keep empty placeholder for now
            base = []
        }
        if selectedSegment == 1, let muscle = selectedMuscle {
            let keys = getDatabaseBodyPart(for: muscle)
            base = base.filter { e in keys.contains(where: { e.bodyPart.localizedCaseInsensitiveContains($0) }) }
        }
        if !searchText.isEmpty {
            base = base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return base
    }

    private var sections: [String: [ExerciseData]] {
        Dictionary(grouping: filtered) { String($0.name.uppercased().prefix(1)) }
    }

    private var sectionKeys: [String] {
        sections.keys.sorted()
    }

    private func getDatabaseBodyPart(for displayMuscle: String) -> [String] {
        switch displayMuscle {
        case "Chest": return ["Chest"]
        case "Abs": return ["Waist"]
        case "Back": return ["Back"]
        case "Lower Back": return ["Hips"]
        case "Trapezius": return ["Back"]
        case "Neck": return ["Neck"]
        case "Shoulders": return ["Shoulders"]
        case "Biceps": return ["Upper Arms"]
        case "Triceps": return ["Upper Arms"]
        case "Forearms": return ["Forearms"]
        case "Glutes": return ["Hips"]
        case "Quadriceps": return ["Thighs"]
        case "Hamstrings": return ["Thighs"]
        case "Calves": return ["Calves"]
        case "Abductors": return ["Thighs"]
        case "Adductors": return ["Thighs"]
        default: return []
        }
    }

    // MARK: - Actions
    private func openHistory(for ex: ExerciseData) {
        // Wrap into TodayWorkoutExercise for ExerciseHistory view
        let tw = TodayWorkoutExercise(
            exercise: ex,
            sets: 3,
            reps: 10,
            weight: nil,
            restTime: 90
        )
        historyExercise = tw
        navigateToHistory = true
    }

    private func setMoreOften(_ ex: ExerciseData) { ups.setExercisePreferenceMoreOften(exerciseId: ex.id) }
    private func setLessOften(_ ex: ExerciseData) { ups.setExercisePreferenceLessOften(exerciseId: ex.id) }
    private func doNotRecommend(_ ex: ExerciseData) {
        withAnimation {
            if ups.avoidedExercises.contains(ex.id) { ups.removeFromAvoided(ex.id) }
            else { ups.addToAvoided(ex.id) }
        }
    }

    @ViewBuilder private var destinationHistoryView: some View {
        if let ex = historyExercise { ExerciseHistory(exercise: ex) } else { EmptyView() }
    }
}

private struct ManageExerciseRow: View {
    let exercise: ExerciseData
    let onHistory: () -> Void
    let onMoreOften: () -> Void
    let onLessOften: () -> Void
    let onDoNotRecommend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Thumb
            Group {
                let thumb = String(format: "%04d", exercise.id)
                if let ui = UIImage(named: thumb) { Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill) }
                else { Image(systemName: "dumbbell").foregroundColor(.secondary) }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))

            // Title
            Text(exercise.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()

            Menu {
                Button("Exercise History", action: onHistory)
                Button("Recommend more often", action: onMoreOften)
                Button("Recommend less often", action: onLessOften)
                if UserProfileService.shared.avoidedExercises.contains(exercise.id) {
                    Button("Allow again", action: onDoNotRecommend)
                } else {
                    Button("Don't recommend again", role: .destructive, action: onDoNotRecommend)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.vertical, 8)
    }
}
