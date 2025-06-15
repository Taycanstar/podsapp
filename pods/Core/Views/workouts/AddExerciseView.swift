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
    @State private var isLoading = true
    
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
                Color("iosbg2")
                    .ignoresSafeArea(.all)
                    .overlay(
                        VStack(spacing: 0) {
                            // Segmented Control
                            Picker("Exercise Filter", selection: $selectedSegment) {
                                ForEach(0..<segments.count, id: \.self) { index in
                                    Text(segments[index]).tag(index)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            
                            // Exercise List
                            if isLoading {
                                VStack {
                                    Spacer()
                                    ProgressView("Loading exercises...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            } else {
                                List {
                                    if selectedSegment == 0 {
                                        // All exercises - no sections
                                        ForEach(filteredExercises, id: \.id) { exercise in
                                            ExerciseRow(
                                                exercise: exercise,
                                                isSelected: selectedExercises.contains(exercise.id)
                                            ) {
                                                toggleExerciseSelection(exercise.id)
                                            }
                                            .listRowBackground(Color("iosbg2"))
                                            .listRowSeparator(.hidden)
                                        }
                                    } else {
                                        // Grouped exercises with sections
                                        ForEach(groupedExercises.keys.sorted(), id: \.self) { sectionKey in
                                            Section(header: Text(sectionKey)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                                .padding(.vertical, 4)
                                            ) {
                                                ForEach(groupedExercises[sectionKey] ?? [], id: \.id) { exercise in
                                                    ExerciseRow(
                                                        exercise: exercise,
                                                        isSelected: selectedExercises.contains(exercise.id)
                                                    ) {
                                                        toggleExerciseSelection(exercise.id)
                                                    }
                                                    .listRowBackground(Color("iosbg2"))
                                                    .listRowSeparator(.hidden)
                                                }
                                            }
                                        }
                                    }
                                }
                                .listStyle(PlainListStyle())
                                .searchable(text: $searchText, prompt: "Search exercises")
                            }
                        }
                    )
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
    
    // MARK: - Computed Properties
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
            return filtered.sorted { exercise1, exercise2 in
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
    private func toggleExerciseSelection(_ exerciseId: Int) {
        HapticFeedback.generate()
        if selectedExercises.contains(exerciseId) {
            selectedExercises.remove(exerciseId)
        } else {
            selectedExercises.insert(exerciseId)
        }
    }
    
    private func loadExercises() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.exercises = ExerciseDataLoader.loadExercises()
            self.isLoading = false
            
            // Debug info
            print("🏋️ AddExerciseView: Loaded \(self.exercises.count) exercises")
            if !self.exercises.isEmpty {
                print("🏋️ First exercise: \(self.exercises[0].name) (ID: \(self.exercises[0].id))")
                print("🏋️ Sample exercises: \(self.exercises.prefix(3).map { "\($0.name) (\($0.id))" }.joined(separator: ", "))")
            }
        }
    }
}

// MARK: - Exercise Row View
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
                            .onAppear {
                                // Debug: Image found
                                print("✅ Image found for exercise \(exercise.id): \(imageId)")
                            }
                    } else {
                        // Default exercise icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                        .onAppear {
                            // Debug: Image not found
                            print("⚠️ Image NOT found for exercise \(exercise.id): \(imageId)")
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
                    
                    HStack {
                        Text(exercise.muscle)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text(exercise.category)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
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

// MARK: - Exercise Data Loader (Deprecated - Use ExerciseDatabase instead)
struct ExerciseDataLoader {
    static func loadExercises() -> [ExerciseData] {
        print("⚠️ ExerciseDataLoader is deprecated, using ExerciseDatabase instead")
        return ExerciseDatabase.getAllExercises()
    }
}

#Preview {
    AddExerciseView { exercises in
        print("Selected exercises: \(exercises.map { $0.name })")
    }
}
