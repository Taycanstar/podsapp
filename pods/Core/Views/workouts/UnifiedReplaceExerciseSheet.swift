//
//  UnifiedReplaceExerciseSheet.swift
//  Pods
//
//  Created by Claude on 1/30/26.
//

import SwiftUI

// MARK: - Context Enum

enum ReplaceExerciseContext {
    case todayWorkout(TodayWorkoutExercise)
    case programExercise(exercise: ProgramExercise, exerciseInstanceId: Int)

    var exerciseId: Int {
        switch self {
        case .todayWorkout(let ex): return ex.exercise.id
        case .programExercise(let ex, _): return ex.exerciseId
        }
    }

    var exerciseName: String {
        switch self {
        case .todayWorkout(let ex): return ex.exercise.name
        case .programExercise(let ex, _): return ex.exerciseName
        }
    }

    var exerciseData: ExerciseData? {
        switch self {
        case .todayWorkout(let ex):
            return ex.exercise
        case .programExercise(let ex, _):
            return ExerciseDatabase.findExercise(byId: ex.exerciseId)
        }
    }

    var exerciseInstanceId: Int? {
        switch self {
        case .todayWorkout: return nil
        case .programExercise(_, let id): return id
        }
    }
}

// MARK: - Unified Replace Exercise Sheet

struct UnifiedReplaceExerciseSheet: View {
    let context: ReplaceExerciseContext
    let onExerciseReplaced: (ExerciseData) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedSegment = 0  // 0: All, 1: By Muscle, 2: Categories
    @State private var selectedMuscle: String? = nil
    @State private var exercises: [ExerciseData] = []

    // Category sheet states
    @State private var showingByEquipment = false
    @State private var showingWeightedExercises = false
    @State private var showingBodyweightExercises = false
    @State private var showingBodyweightWithEquipment = false
    @State private var showingCardioExercises = false
    @State private var showingStretchMobility = false

    // Performance: Debounced filtering
    @State private var cachedBestMatches: [ExerciseData] = []
    @State private var cachedAlphabeticalSections: [String: [ExerciseData]] = [:]
    @State private var cachedSortedSectionKeys: [String] = []
    @State private var cachedMuscleFiltered: [ExerciseData] = []
    @State private var processingWorkItem: DispatchWorkItem?
    @State private var isProcessing = false

    private let segments = ["All", "By Muscle", "Categories"]

    private let muscleGroups = [
        "Chest", "Abs", "Back", "Lower Back", "Trapezius", "Neck",
        "Shoulders", "Biceps", "Triceps", "Forearms", "Glutes",
        "Quadriceps", "Hamstrings", "Calves", "Abductors", "Adductors"
    ]

    private let categories = [
        ("By Equipment", "dumbbell"),
        ("Weighted Exercises", "scalemass"),
        ("Bodyweight", "figure.strengthtraining.functional"),
        ("Bodyweight with Equipment", "figure.play"),
        ("Cardio", "figure.run"),
        ("Stretching and Mobility", "figure.flexibility")
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented Control
                Picker("Exercise Filter", selection: $selectedSegment) {
                    ForEach(0..<segments.count, id: \.self) { index in
                        Text(segments[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .onChange(of: selectedSegment) { _, newValue in
                    if newValue != 1 {
                        selectedMuscle = nil
                    }
                    processExercises()
                }

                // Muscle Group Carousel (only show when "By Muscle" is selected)
                if selectedSegment == 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(muscleGroups, id: \.self) { muscle in
                                Button(action: {
                                    HapticFeedback.generate()
                                    if selectedMuscle == muscle {
                                        selectedMuscle = nil
                                    } else {
                                        selectedMuscle = muscle
                                    }
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

                // Content based on selected segment
                contentView
            }
            .background(Color(.systemBackground))
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            loadExercises()
        }
        .onChange(of: searchText) { _, _ in
            processExercises()
        }
        .onChange(of: selectedMuscle) { _, _ in
            processExercises()
        }
        .sheet(isPresented: $showingByEquipment) {
            NavigationView {
                ByEquipmentView(onExercisesSelected: handleExerciseSelection)
            }
        }
        .sheet(isPresented: $showingWeightedExercises) {
            NavigationView {
                WeightedExercisesView(onExercisesSelected: handleExerciseSelection)
            }
        }
        .sheet(isPresented: $showingBodyweightExercises) {
            NavigationView {
                BodyweightExercisesView(onExercisesSelected: handleExerciseSelection)
            }
        }
        .sheet(isPresented: $showingBodyweightWithEquipment) {
            NavigationView {
                BodyweightWithEquipment(onExercisesSelected: handleExerciseSelection)
            }
        }
        .sheet(isPresented: $showingCardioExercises) {
            NavigationView {
                CardioExercisesView(onExercisesSelected: handleExerciseSelection)
            }
        }
        .sheet(isPresented: $showingStretchMobility) {
            NavigationView {
                StretchMobilityView(onExercisesSelected: handleExerciseSelection)
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if selectedSegment == 2 {
            categoriesView
        } else if selectedSegment == 1 {
            muscleFilteredView
        } else {
            allExercisesView
        }
    }

    // MARK: - All Exercises View (with Best Match section first)

    private var allExercisesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isProcessing && exercises.isEmpty {
                    ProgressView("Loading exercises...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 100)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Best Match Section (first)
                        if !cachedBestMatches.isEmpty && searchText.isEmpty {
                            Text("Best Match")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                .id("BestMatch")

                            ForEach(cachedBestMatches.prefix(10), id: \.id) { exercise in
                                ReplaceExerciseRow(
                                    exercise: exercise,
                                    onSelect: { selectExercise(exercise) }
                                )
                            }
                        }

                        // Alphabetical Sections
                        ForEach(cachedSortedSectionKeys, id: \.self) { sectionKey in
                            if let sectionExercises = cachedAlphabeticalSections[sectionKey], !sectionExercises.isEmpty {
                                Text(sectionKey)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemBackground))
                                    .id(sectionKey)

                                ForEach(sectionExercises, id: \.id) { exercise in
                                    ReplaceExerciseRow(
                                        exercise: exercise,
                                        onSelect: { selectExercise(exercise) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .overlay(
                Group {
                    if !cachedSortedSectionKeys.isEmpty {
                        let allKeys = (searchText.isEmpty && !cachedBestMatches.isEmpty ? ["BestMatch"] : []) + cachedSortedSectionKeys
                        SectionIndexTitles(
                            proxy: proxy,
                            titles: allKeys
                        )
                    }
                }
            )
        }
    }

    // MARK: - Muscle Filtered View

    private var muscleFilteredView: some View {
        ScrollView {
            if cachedMuscleFiltered.isEmpty && selectedMuscle != nil {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No exercises found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try selecting a different muscle group")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 100)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(cachedMuscleFiltered, id: \.id) { exercise in
                        ReplaceExerciseRow(
                            exercise: exercise,
                            onSelect: { selectExercise(exercise) }
                        )
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Categories View

    private var categoriesView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                    Button(action: {
                        HapticFeedback.generate()
                        handleCategoryTap(category.0)
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: category.1)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 30)

                            Text(category.0)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    if index < categories.count - 1 {
                        Divider()
                            .padding(.leading, 62)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Data Loading

    private func loadExercises() {
        exercises = ExerciseDatabase.getAllExercises()
            .filter { $0.id != context.exerciseId }
        processExercises()
    }

    private func processExercises() {
        processingWorkItem?.cancel()

        let currentSearch = searchText
        let currentSegment = selectedSegment
        let currentMuscle = selectedMuscle
        let currentExerciseData = context.exerciseData
        let baseExercises = exercises

        guard !baseExercises.isEmpty else {
            cachedBestMatches = []
            cachedAlphabeticalSections = [:]
            cachedSortedSectionKeys = []
            cachedMuscleFiltered = []
            isProcessing = false
            return
        }

        isProcessing = true

        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem {
            var bestMatches: [ExerciseData] = []
            var alphabeticalSections: [String: [ExerciseData]] = [:]
            var sortedKeys: [String] = []
            var muscleFiltered: [ExerciseData] = []

            // Filter by search if needed
            var filtered = baseExercises
            if !currentSearch.isEmpty {
                filtered = filtered.filter {
                    $0.name.localizedCaseInsensitiveContains(currentSearch) ||
                    $0.bodyPart.localizedCaseInsensitiveContains(currentSearch) ||
                    $0.target.localizedCaseInsensitiveContains(currentSearch)
                }
            }

            if currentSegment == 0 {
                // All view: Best matches + alphabetical
                if let current = currentExerciseData {
                    let relevant = self.getLogicallyRelevantExercises(from: filtered, current: current)
                    bestMatches = relevant.sorted {
                        self.calculateMatchScore(for: $0, current: current) > self.calculateMatchScore(for: $1, current: current)
                    }
                }

                // Build alphabetical sections
                for exercise in filtered.sorted(by: { $0.name < $1.name }) {
                    let firstChar = String(exercise.name.prefix(1)).uppercased()
                    alphabeticalSections[firstChar, default: []].append(exercise)
                }
                sortedKeys = alphabeticalSections.keys.sorted()

            } else if currentSegment == 1 {
                // By Muscle view
                if let muscle = currentMuscle {
                    let bodyParts = self.getDatabaseBodyPart(for: muscle)
                    muscleFiltered = filtered.filter { exercise in
                        bodyParts.contains(exercise.bodyPart) ||
                        exercise.target.localizedCaseInsensitiveContains(muscle)
                    }.sorted { $0.name < $1.name }
                } else {
                    muscleFiltered = filtered.sorted { $0.name < $1.name }
                }
            }

            DispatchQueue.main.async {
                guard let workItem, !workItem.isCancelled else { return }
                self.cachedBestMatches = bestMatches
                self.cachedAlphabeticalSections = alphabeticalSections
                self.cachedSortedSectionKeys = sortedKeys
                self.cachedMuscleFiltered = muscleFiltered
                self.isProcessing = false
                self.processingWorkItem = nil
            }
        }

        guard let workItem else { return }
        processingWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    // MARK: - Helper Functions

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

    private func getLogicallyRelevantExercises(from exercises: [ExerciseData], current: ExerciseData) -> [ExerciseData] {
        let currentBodyPart = current.bodyPart
        let currentTarget = current.target
        let currentSynergists = Set(current.synergist.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })

        return exercises.filter { exercise in
            if exercise.bodyPart == currentBodyPart { return true }
            if exercise.target == currentTarget { return true }

            let exerciseSynergists = Set(exercise.synergist.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            if currentSynergists.intersection(exerciseSynergists).count >= 2 { return true }

            if isCompoundMovementMatch(current: current, candidate: exercise) { return true }

            return false
        }
    }

    private func isCompoundMovementMatch(current: ExerciseData, candidate: ExerciseData) -> Bool {
        let currentName = current.name.lowercased()
        let candidateName = candidate.name.lowercased()

        if (currentName.contains("press") || currentName.contains("push")) &&
           (candidateName.contains("press") || candidateName.contains("push")) {
            return true
        }

        if (currentName.contains("pull") || currentName.contains("row") || currentName.contains("chin")) &&
           (candidateName.contains("pull") || candidateName.contains("row") || candidateName.contains("chin")) {
            return true
        }

        if (currentName.contains("squat") || currentName.contains("lunge")) &&
           (candidateName.contains("squat") || candidateName.contains("lunge")) {
            return true
        }

        if (currentName.contains("deadlift") || currentName.contains("romanian") || currentName.contains("rdl")) &&
           (candidateName.contains("deadlift") || candidateName.contains("romanian") || candidateName.contains("rdl")) {
            return true
        }

        if currentName.contains("curl") && candidateName.contains("curl") {
            return true
        }

        return false
    }

    private func calculateMatchScore(for exercise: ExerciseData, current: ExerciseData) -> Double {
        var score = 0.0

        if exercise.bodyPart == current.bodyPart { score += 100.0 }
        if exercise.target == current.target { score += 80.0 }
        if isCompoundMovementMatch(current: current, candidate: exercise) { score += 60.0 }

        let currentSynergists = Set(current.synergist.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        let exerciseSynergists = Set(exercise.synergist.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        score += Double(currentSynergists.intersection(exerciseSynergists).count) * 10.0

        if exercise.equipment == current.equipment { score += 25.0 }

        return score
    }

    // MARK: - Actions

    private func handleCategoryTap(_ category: String) {
        switch category {
        case "By Equipment":
            showingByEquipment = true
        case "Weighted Exercises":
            showingWeightedExercises = true
        case "Bodyweight":
            showingBodyweightExercises = true
        case "Bodyweight with Equipment":
            showingBodyweightWithEquipment = true
        case "Cardio":
            showingCardioExercises = true
        case "Stretching and Mobility":
            showingStretchMobility = true
        default:
            break
        }
    }

    private func handleExerciseSelection(_ exercises: [ExerciseData]) {
        if let first = exercises.first {
            selectExercise(first)
        }
    }

    private func selectExercise(_ exercise: ExerciseData) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()

        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onExerciseReplaced(exercise)
        }
    }
}

// MARK: - Exercise Row

private struct ReplaceExerciseRow: View {
    let exercise: ExerciseData
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                let thumbnailName = String(format: "%04d", exercise.id)
                if let image = UIImage(named: thumbnailName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
