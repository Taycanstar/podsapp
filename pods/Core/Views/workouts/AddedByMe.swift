//
//  AddedByMeView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/22/25.
//

import SwiftUI

struct AddedByMe: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var addedByMeExercises: [ExerciseData] = []
    
    var body: some View {
        contentView
            .background(Color(.systemBackground))
        .navigationTitle("Added by Me")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.accentColor)
            }
        }
        .searchable(text: $searchText, prompt: "Search your exercises")
        .onAppear {
            loadAddedByMeExercises()
        }
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(spacing: 0) {
            if addedByMeExercises.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image("dbbell")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 150, maxHeight: 150)
                    
                    Text("No custom exercises")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Exercises you create will appear here. Start building your custom exercise library.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
            } else {
                // Exercise list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredExercises, id: \.id) { exercise in
                            AddedByMeExerciseRow(exercise: exercise)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 16)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var filteredExercises: [ExerciseData] {
        if searchText.isEmpty {
            return addedByMeExercises
        } else {
            return addedByMeExercises.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.muscle.localizedCaseInsensitiveContains(searchText) ||
                exercise.category.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Methods
    private func loadAddedByMeExercises() {
        // TODO: Load user-created exercises from storage
        // For now, keep the array empty to show the empty state
        self.addedByMeExercises = []
        print("🏋️ AddedByMeView: Loaded \(self.addedByMeExercises.count) user-created exercises")
    }
}

// MARK: - Added By Me Exercise Row
struct AddedByMeExerciseRow: View {
    let exercise: ExerciseData
    
    var body: some View {
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
                    // Fallback icon
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
                
                Text(exercise.muscle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Custom exercise indicator and chevron
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.generate()
            // TODO: Handle exercise selection or detail view
            print("Tapped user-created exercise: \(exercise.name)")
        }
    }
}

#Preview {
    NavigationView {
        AddedByMe()
    }
} 
