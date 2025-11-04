//
//  AddExerciseView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/14/25.
//

import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedSegment = 0
    @State private var selectedExercises: Set<Int> = []
    @State private var exercises: [ExerciseData] = []
    @State private var selectedMuscle: String? = nil
    @State private var showingRecentlyAdded = false
    @State private var showingAddedByMe = false
    @State private var showingByEquipment = false
    @State private var showingWeightedExercises = false
    @State private var showingBodyweightExercises = false
    @State private var showingBodyweightWithEquipment = false
    @State private var showingCardioExercises = false
    @State private var showingStretchMobility = false
    @State private var isLoadingExercises = false
    @State private var isProcessingExercises = false
    @State private var cachedFilteredExercises: [ExerciseData] = []
    @State private var cachedAlphabeticalSections: [String: [ExerciseData]] = [:]
    @State private var cachedSortedSectionKeys: [String] = []
    @State private var cachedGroupedExercises: [String: [ExerciseData]] = [:]
    @State private var processingWorkItem: DispatchWorkItem?

    
    // Segmented control options
    private let segments = ["All", "By Muscle", "Categories"]
    
    // Muscle group options for the carousel
    private let muscleGroups = [
        "Chest", "Abs", "Back", "Lower Back", "Trapezius", "Neck", 
        "Shoulders", "Biceps", "Triceps", "Forearms", "Glutes", 
        "Quadriceps", "Hamstrings", "Calves", "Abductors", "Adductors"
    ]
    
    // Mapping from display names to actual database bodyPart values
    private func getDatabaseBodyPart(for displayMuscle: String) -> [String] {
        switch displayMuscle {
        case "Chest":
            return ["Chest"]
        case "Abs":
            return ["Waist"]  // Core/abs exercises are listed as "Waist" in the database
        case "Back":
            return ["Back"]
        case "Lower Back":
            return ["Hips"]  // Lower back exercises are often categorized as "Hips" 
        case "Trapezius":
            return ["Back"]  // Trapezius exercises are in the "Back" category
        case "Neck":
            return ["Neck"]
        case "Shoulders":
            return ["Shoulders"]
        case "Biceps":
            return ["Upper Arms"]  // Biceps exercises are in "Upper Arms"
        case "Triceps":
            return ["Upper Arms"]  // Triceps exercises are in "Upper Arms"
        case "Forearms":
            return ["Forearms"]
        case "Glutes":
            return ["Hips"]  // Glute exercises are categorized as "Hips"
        case "Quads":
            return ["Thighs"]  // Quad exercises are in "Thighs"
        case "Hamstrings":
            return ["Thighs"]  // Hamstring exercises are in "Thighs"
        case "Calves":
            return ["Calves"]
        case "Abductors":
            return ["Thighs"]  // Abductor exercises are in "Thighs"
        case "Adductors":
            return ["Thighs"]  // Adductor exercises are in "Thighs"
        default:
            return []
        }
    }
    
    // Callback to pass selected exercises back
    let onExercisesSelected: ([ExerciseData]) -> Void
    
    init(onExercisesSelected: @escaping ([ExerciseData]) -> Void) {
        self.onExercisesSelected = onExercisesSelected
    }
    
    var body: some View {
        NavigationView {
            contentView
                .background(Color(.systemBackground))
                .overlay(alignment: .center) {
                    if (isLoadingExercises || isProcessingExercises) && cachedFilteredExercises.isEmpty {
                        ProgressView("Loading exercises…")
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 6)
                            )
                    }
                }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let selected = exercises.filter { selectedExercises.contains($0.id) }
                        if !selected.isEmpty {
                            onExercisesSelected(selected)
                            dismiss()
                        }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .disabled(selectedExercises.isEmpty)
                }
            }
        }
        .onAppear {
            loadExercises()
        }
        .sheet(isPresented: $showingRecentlyAdded) {
            NavigationView {
                RecentlyAddedView()
            }
        }
        .sheet(isPresented: $showingAddedByMe) {
            NavigationView {
                AddedByMe()
            }
        }
        .sheet(isPresented: $showingByEquipment) {
            NavigationView {
                ByEquipmentView(onExercisesSelected: onExercisesSelected)
            }
        }
        .sheet(isPresented: $showingWeightedExercises) {
            NavigationView {
                WeightedExercisesView(onExercisesSelected: onExercisesSelected)
            }
        }
        .sheet(isPresented: $showingBodyweightExercises) {
            NavigationView {
                BodyweightExercisesView(onExercisesSelected: onExercisesSelected)
            }
        }
        .sheet(isPresented: $showingBodyweightWithEquipment) {
            NavigationView {
                BodyweightWithEquipment(onExercisesSelected: onExercisesSelected)
            }
        }
        .sheet(isPresented: $showingCardioExercises) {
            NavigationView {
                CardioExercisesView(onExercisesSelected: onExercisesSelected)
            }
        }
        .sheet(isPresented: $showingStretchMobility) {
            NavigationView {
                StretchMobilityView(onExercisesSelected: onExercisesSelected)
            }
        }
        .onChange(of: searchText) { _, _ in
            processExercises()
        }
        .onChange(of: selectedMuscle) { _, _ in
            processExercises()
        }

    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("Exercise Filter", selection: $selectedSegment) {
                ForEach(0..<segments.count, id: \.self) { index in
                    Text(segments[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 12)
            .onChange(of: selectedSegment) { _, newValue in
                // Reset muscle selection when switching segments
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
                                    selectedMuscle = nil // Deselect if already selected
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
            
            // Exercise List
            ScrollViewReader { (proxy: ScrollViewProxy) in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if selectedSegment == 2 {
                            // Categories View
                            let categories = [
                                ("Recently Added", "calendar"),
                                ("Added by Me", "person"),
                                ("By Equipment", "dumbbell"),
                                ("Weighted Exercises", "scalemass"),
                                ("Bodyweight", "figure.strengthtraining.functional"),
                                ("Bodyweight with Equipment", "figure.play"),
                                ("Cardio", "figure.run"),
                                ("Stretching and Mobility", "figure.flexibility")
                            ]
                            
                            ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                                Button(action: {
                                    HapticFeedback.generate()
                                    
                                    switch category.0 {
                                    case "Recently Added":
                                        showingRecentlyAdded = true
                                    case "Added by Me":
                                        showingAddedByMe = true
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
                                        // TODO: Navigate to other category views
                                        print("Tapped category: \(category.0)")
                                    }
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
                        } else if selectedSegment == 0 {
                            // All exercises - with alphabetical sections
                            ForEach(validSectionKeys, id: \.self) { sectionKey in
                                if let exercises = alphabeticalSections[sectionKey], !exercises.isEmpty {
                                    // Section Header (now just a normal view, never "pinned" or re-used)
                                    Text(sectionKey)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background( Color(.systemBackground))
                                        .id(sectionKey) // Used by letter index for scrolling
                                    
                                    // Section Content
                                    ForEach(exercises, id: \.id) { exercise in
                                        ExerciseRow(
                                            exercise: exercise,
                                            isSelected: selectedExercises.contains(exercise.id)
                                        ) {
                                            toggleExerciseSelection(exercise)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.trailing, 40) // Add trailing padding for letter wheel
                                        .background(Color(.systemBackground))
                                    }
                                }
                            }
                        } else {
                            // Grouped exercises with sections
                            ForEach(groupedExercises.keys.sorted(), id: \.self) { sectionKey in
                                if let exercises = groupedExercises[sectionKey], !exercises.isEmpty {
                                    // Section Header - only show if not in "By Muscle" mode
                                    if selectedSegment != 1 {
                                        Text(sectionKey)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color(.systemGray6))
                                    }
                                    
                                    // Section Content
                                    ForEach(exercises, id: \.id) { exercise in
                                        ExerciseRow(
                                            exercise: exercise,
                                            isSelected: selectedExercises.contains(exercise.id)
                                        ) {
                                            toggleExerciseSelection(exercise)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.trailing, 40) // Add trailing padding for letter wheel
                                        .background(Color(.systemBackground))
                                    }
                                }
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .searchable(text: $searchText, prompt: "Search exercises")
                .overlay(
                    // Only show section index for "All" view and when we have exercises
                    Group {
                        if selectedSegment == 0 && !exercises.isEmpty {
                            SectionIndexTitles(
                                proxy: proxy,
                                titles: validSectionKeys
                            )
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    private var validSectionKeys: [String] {
        cachedSortedSectionKeys.filter { key in
            guard let exercises = cachedAlphabeticalSections[key] else { return false }
            return !exercises.isEmpty
        }
    }
    
    private var alphabeticalSections: [String: [ExerciseData]] {
        cachedAlphabeticalSections
    }
    
    private var sortedSectionKeys: [String] {
        cachedSortedSectionKeys
    }
    
    private var groupedExercises: [String: [ExerciseData]] {
        cachedGroupedExercises
    }
    
    private var filteredExercises: [ExerciseData] {
        cachedFilteredExercises
    }

    private func computeFilteredExercises(
        _ base: [ExerciseData],
        searchText: String,
        segment: Int,
        selectedMuscle: String?
    ) -> [ExerciseData] {
        let filtered: [ExerciseData]
        if searchText.isEmpty {
            filtered = base
        } else {
            filtered = base.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.muscle.localizedCaseInsensitiveContains(searchText) ||
                exercise.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        let muscleFiltered: [ExerciseData]
        if segment == 1, let selectedMuscle {
            let targetBodyParts = getDatabaseBodyPart(for: selectedMuscle)
            muscleFiltered = filtered.filter { exercise in
                let bodyPartMatches = targetBodyParts.contains { bodyPart in
                    exercise.bodyPart.localizedCaseInsensitiveContains(bodyPart)
                }

                let targetMatches: Bool
                switch selectedMuscle {
                case "Biceps":
                    targetMatches = exercise.target.localizedCaseInsensitiveContains("Biceps")
                case "Triceps":
                    targetMatches = exercise.target.localizedCaseInsensitiveContains("Triceps")
                case "Abs":
                    targetMatches = exercise.target.localizedCaseInsensitiveContains("Rectus Abdominis") ||
                                   exercise.target.localizedCaseInsensitiveContains("Obliques")
                case "Glutes":
                    targetMatches = exercise.target.localizedCaseInsensitiveContains("Gluteus")
                case "Quads":
                    targetMatches = exercise.target.localizedCaseInsensitiveContains("Quadriceps")
                case "Hamstrings":
                    targetMatches = exercise.target.localizedCaseInsensitiveContains("Hamstrings")
                case "Trapezius":
                    targetMatches = exercise.target.localizedCaseInsensitiveContains("Trapezius")
                case "Lower Back":
                    targetMatches = exercise.target.localizedCaseInsensitiveContains("Erector Spinae") ||
                                   exercise.target.localizedCaseInsensitiveContains("Gluteus Maximus")
                case "Abductors":
                    targetMatches = exercise.target.localizedCaseInsensitiveContains("Abductor") ||
                                   exercise.target.localizedCaseInsensitiveContains("Gluteus Medius")
                case "Adductors":
                    targetMatches = exercise.target.localizedCaseInsensitiveContains("Adductor")
                default:
                    targetMatches = bodyPartMatches
                }

                return bodyPartMatches || targetMatches
            }
        } else {
            muscleFiltered = filtered
        }

        switch segment {
        case 1:
            return muscleFiltered.sorted { lhs, rhs in
                if lhs.muscle == rhs.muscle {
                    return lhs.name < rhs.name
                }
                return lhs.muscle < rhs.muscle
            }
        case 2:
            return muscleFiltered.sorted { lhs, rhs in
                if lhs.category == rhs.category {
                    return lhs.name < rhs.name
                }
                return lhs.category < rhs.category
            }
        default:
            return muscleFiltered
        }
    }

    private func buildAlphabeticalSections(from exercises: [ExerciseData]) -> [String: [ExerciseData]] {
        let sortedExercises = exercises.sorted { exercise1, exercise2 in
            let name1 = exercise1.name.lowercased()
            let name2 = exercise2.name.lowercased()

            let firstChar1 = exercise1.name.first
            let firstChar2 = exercise2.name.first
            let isLetter1 = firstChar1?.isLetter ?? false
            let isLetter2 = firstChar2?.isLetter ?? false
            let isNumber1 = firstChar1?.isNumber ?? false
            let isNumber2 = firstChar2?.isNumber ?? false

            if !isLetter1 && isLetter2 {
                return true
            } else if isLetter1 && !isLetter2 {
                return false
            } else if isNumber1 && !isNumber2 {
                return true
            } else if isLetter1 && isNumber2 {
                return false
            } else {
                return name1 < name2
            }
        }

        return Dictionary(grouping: sortedExercises) { exercise in
            let firstChar = exercise.name.first ?? Character(" ")
            if firstChar.isLetter {
                return String(firstChar.uppercased())
            } else if firstChar.isNumber {
                return "#"
            } else {
                return "•"
            }
        }
    }

    private func buildSortedSectionKeys(from sections: [String: [ExerciseData]]) -> [String] {
        let keys = Array(sections.keys)
        return keys.sorted { key1, key2 in
            if key1 == "•" && key2 != "•" {
                return true
            } else if key1 != "•" && key2 == "•" {
                return false
            } else if key1 == "#" && key2 != "#" && key2 != "•" {
                return true
            } else if key1 != "#" && key1 != "•" && key2 == "#" {
                return false
            } else {
                return key1 < key2
            }
        }
    }

    private func buildGroupedExercises(from exercises: [ExerciseData], segment: Int) -> [String: [ExerciseData]] {
        let groupKey: (ExerciseData) -> String = { exercise in
            switch segment {
            case 1: return exercise.muscle
            case 2: return exercise.category
            default: return ""
            }
        }
        return Dictionary(grouping: exercises, by: groupKey)
    }

    
    // MARK: - Methods
    private func toggleExerciseSelection(_ exercise: ExerciseData) {
        HapticFeedback.generate()
        if selectedExercises.contains(exercise.id) {
            selectedExercises.remove(exercise.id)
        } else {
            selectedExercises.insert(exercise.id)
        }
    }
    
    private func loadExercises() {
        if let cached = ExerciseDatabase.cachedSnapshot() {
            self.exercises = cached
            print("🏋️ AddExerciseView: Loaded cached \(cached.count) exercises")
            processExercises()
            return
        }

        guard !isLoadingExercises else { return }
        isLoadingExercises = true
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedExercises = ExerciseDatabase.getAllExercises()
            DispatchQueue.main.async {
                self.exercises = loadedExercises
                self.isLoadingExercises = false
                print("🏋️ AddExerciseView: Loaded \(loadedExercises.count) exercises")
                self.processExercises()
            }
        }
    }

    private func processExercises() {
        processingWorkItem?.cancel()
        let baseExercises = exercises
        guard !baseExercises.isEmpty else {
            cachedFilteredExercises = []
            cachedAlphabeticalSections = [:]
            cachedSortedSectionKeys = []
            cachedGroupedExercises = [:]
            isProcessingExercises = false
            return
        }

        let currentSearch = searchText
        let currentSegment = selectedSegment
        let currentMuscle = selectedMuscle

        isProcessingExercises = true

        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem {
            let filtered = computeFilteredExercises(baseExercises, searchText: currentSearch, segment: currentSegment, selectedMuscle: currentMuscle)
            let alphabetical = buildAlphabeticalSections(from: filtered)
            let sortedKeys = buildSortedSectionKeys(from: alphabetical)
            let grouped = buildGroupedExercises(from: filtered, segment: currentSegment)
            DispatchQueue.main.async {
                guard let workItem, !workItem.isCancelled else { return }
                self.cachedFilteredExercises = filtered
                self.cachedAlphabeticalSections = alphabetical
                self.cachedSortedSectionKeys = sortedKeys
                self.cachedGroupedExercises = grouped
                self.isProcessingExercises = false
                self.processingWorkItem = nil
            }
        }
        guard let workItem else { return }
        processingWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
}

struct ExerciseRow: View {
    let exercise: ExerciseData
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Exercise thumbnail
                Group {
                    // Use 4-digit padded format for exercise images (e.g., "0001", "0025")
                    let imageId = String(format: "%04d", exercise.id)
                    if let image = UIImage(named: imageId) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        // Fallback icon (should rarely be used now)
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                
                // Exercise details
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}



// MARK: - Section Index Titles (Letter Wheel)
struct SectionIndexTitles: View {
    let proxy: ScrollViewProxy
    let titles: [String]
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var currentIndex: Int = -1
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(currentIndex == index ? .white : .primary)
                        .frame(width: 20, height: 16)
                        .background(
                            Circle()
                                .fill(currentIndex == index ? Color("iosfit") : Color("iosfit").opacity(0.3))
                                .scaleEffect(currentIndex == index ? 1.2 : 1.0)
                        )
                        .onTapGesture {
                            scrollToSection(title, index: index)
                        }
                }
            }
            .padding(.trailing, 8)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("iosfit").opacity(0.1))
                    .blur(radius: 0.5)
            )
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        isDragging = true
                        dragLocation = value.location
                        
                        // Calculate which section we're over based on the VStack layout
                        let itemHeight: CGFloat = 18 // 16 height + 2 spacing
                        let startY: CGFloat = 20 // top padding
                        let adjustedY = dragLocation.y - startY
                        let index = Int(adjustedY / itemHeight)
                        
                        if index >= 0 && index < titles.count && index != currentIndex {
                            currentIndex = index
                            let title = titles[index]
                            scrollToSection(title, index: index)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        // Reset current index after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            currentIndex = -1
                        }
                    }
            )
        }
    }
    
    private func scrollToSection(_ title: String, index: Int) {
        currentIndex = index
        HapticFeedback.generate()
        
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(title, anchor: UnitPoint.top)
        }
        
        // Reset highlight after scrolling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !isDragging {
                currentIndex = -1
            }
        }
    }
}

#Preview {
    AddExerciseView { exercises in
        print("Selected exercises: \(exercises.map { $0.name })")
    }
}
