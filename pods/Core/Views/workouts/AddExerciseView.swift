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
    
    // Segmented control options
    private let segments = ["All", "By Muscle", "Categories"]
    
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
            
            // Exercise List
            ScrollViewReader { (proxy: ScrollViewProxy) in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if selectedSegment == 0 {
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
                                    // Section Header
                                    Text(sectionKey)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        // .background(Color(.systemGray6))
                                            .background(Color(.systemGray6))
                                    
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
        
        // Apply segment filter and sort
        switch selectedSegment {
        case 0: // All
            return filtered // Sorting is handled in alphabeticalSections
        case 1: // By Muscle
            return filtered.sorted { exercise1, exercise2 in
                if exercise1.muscle == exercise2.muscle {
                    return exercise1.name < exercise2.name
                }
                return exercise1.muscle < exercise2.muscle
            }
        case 2: // Categories
            return filtered.sorted { exercise1, exercise2 in
                if exercise1.category == exercise2.category {
                    return exercise1.name < exercise2.name
                }
                return exercise1.category < exercise2.category
            }
        default:
            return filtered
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
