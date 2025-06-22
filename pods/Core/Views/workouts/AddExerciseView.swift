//
//  AddExerciseView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/14/25.
//

import SwiftUI

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedSegment = 0
    @State private var selectedExercises: Set<Int> = []
    @State private var exercises: [ExerciseData] = []
    @State private var selectedMuscle: String? = nil
    
    // Segmented control options
    private let segments = ["All", "By Muscle", "Categories"]
    
    // Muscle group options for the carousel
    private let muscleGroups = [
        "Chest", "Abs", "Back", "Lower Back", "Trapezius", "Neck", 
        "Shoulders", "Biceps", "Triceps", "Forearms", "Glutes", 
        "Quads", "Hamstrings", "Calves", "Abductors", "Adductors"
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
            VStack(spacing: 0) {
                // Background color
                Color(.systemBackground)
                    .ignoresSafeArea(.all)
                    .overlay(contentView)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        let selected = exercises.filter { selectedExercises.contains($0.id) }
                        onExercisesSelected(selected)
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .disabled(selectedExercises.isEmpty)
                }
            }
        }
        .onAppear {
            loadExercises()
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
                                    // TODO: Navigate to specific category view
                                    print("Tapped category: \(category.0)")
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
        // Only include keys that actually have exercises (no empty sections)
        return sortedSectionKeys.filter { key in
            if let exercises = alphabeticalSections[key] {
                return !exercises.isEmpty
            }
            return false
        }
    }
    
    private var alphabeticalSections: [String: [ExerciseData]] {
        let sortedExercises = filteredExercises.sorted { exercise1, exercise2 in
            // Sort alphabetically: symbols, numbers, then a-z
            let name1 = exercise1.name.lowercased()
            let name2 = exercise2.name.lowercased()
            
            let char1 = name1.first ?? Character(" ")
            let char2 = name2.first ?? Character(" ")
            
            let isAlpha1 = char1.isLetter
            let isAlpha2 = char2.isLetter
            let isNumber1 = char1.isNumber
            let isNumber2 = char2.isNumber
            
            if !isAlpha1 && !isNumber1 && (isAlpha2 || isNumber2) {
                return true // symbols first
            } else if (isAlpha1 || isNumber1) && !isAlpha2 && !isNumber2 {
                return false // symbols first
            } else if isNumber1 && isAlpha2 {
                return true // numbers before letters
            } else if isAlpha1 && isNumber2 {
                return false // numbers before letters
            } else {
                return name1 < name2 // alphabetical within same category
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
    
    private var sortedSectionKeys: [String] {
        // Only include keys that actually have exercises (no empty sections)
        let keys = Array(alphabeticalSections.keys)
        return keys.sorted { key1, key2 in
            // Sort order: symbols (•), numbers (#), then A-Z
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
    
    private var groupedExercises: [String: [ExerciseData]] {
        let groupKey: (ExerciseData) -> String = { exercise in
            switch selectedSegment {
            case 1: return exercise.muscle
            case 2: return exercise.category
            default: return ""
            }
        }
        
        return Dictionary(grouping: filteredExercises, by: groupKey)
    }
    
    private var filteredExercises: [ExerciseData] {
        let filtered: [ExerciseData]
        
        // Apply search filter
        if searchText.isEmpty {
            filtered = exercises
        } else {
            filtered = exercises.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.muscle.localizedCaseInsensitiveContains(searchText) ||
                exercise.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply muscle group filter when in "By Muscle" mode
        let muscleFiltered: [ExerciseData]
        if selectedSegment == 1, let selectedMuscle = selectedMuscle {
            let targetBodyParts = getDatabaseBodyPart(for: selectedMuscle)
            muscleFiltered = filtered.filter { exercise in
                // First check if bodyPart matches
                let bodyPartMatches = targetBodyParts.contains { bodyPart in
                    exercise.bodyPart.localizedCaseInsensitiveContains(bodyPart)
                }
                
                // For more specific filtering, also check target muscle
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
        
        // Apply segment filter and sort
        switch selectedSegment {
        case 0: // All
            return muscleFiltered // Sorting is handled in alphabeticalSections
        case 1: // By Muscle
            return muscleFiltered.sorted { exercise1, exercise2 in
                if exercise1.muscle == exercise2.muscle {
                    return exercise1.name < exercise2.name
                }
                return exercise1.muscle < exercise2.muscle
            }
        case 2: // Categories
            return muscleFiltered.sorted { exercise1, exercise2 in
                if exercise1.category == exercise2.category {
                    return exercise1.name < exercise2.name
                }
                return exercise1.category < exercise2.category
            }
        default:
            return muscleFiltered
        }
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
        self.exercises = ExerciseDatabase.getAllExercises()
        print("🏋️ AddExerciseView: Loaded \(self.exercises.count) exercises")
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

// MARK: - Exercise Data Model
struct ExerciseData: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let exerciseType: String
    let bodyPart: String
    let equipment: String
    let gender: String
    let target: String
    let synergist: String
    
    // Computed properties for compatibility
    var muscle: String { bodyPart }
    var category: String { equipment }
    var instructions: String? { target.isEmpty ? nil : target }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ExerciseData, rhs: ExerciseData) -> Bool {
        lhs.id == rhs.id
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
