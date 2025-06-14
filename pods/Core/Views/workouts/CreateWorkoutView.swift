//
//  CreateWorkoutView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/14/25.
//

import SwiftUI

struct CreateWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workoutTitle: String = ""
    @State private var exercises: [WorkoutExercise] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Background color for the entire view
                Color("iosbg2")
                    .ignoresSafeArea(.all)
                    .overlay(
                        VStack(spacing: 20) {
                            // Title input field
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Title", text: $workoutTitle)
                                    .font(.system(size: 17))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            
                            // Show dbbell image and text when no exercises
                            if exercises.isEmpty {
                                VStack(spacing: 16) {
                            
                                    
                                    Image("dbbell")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 150, maxHeight: 150)
                                    
                                    Text("Add exercises to get started")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    // Add Exercise button
                                    Button(action: {
                                        print("Tapped Add Exercise")
                                        HapticFeedback.generate()
                                        // TODO: Navigate to exercise selection
                                    }) {
                                        HStack(spacing: 6) {
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                            Text("Add Exercise")
                                                .font(.system(size: 17))
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        // .background(Color("iosfit"))
                                             .background(.accentColor)
                                        .cornerRadius(12)
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 20)
                                    
                                    Spacer()
                                }
                            } else {
                                // TODO: Show exercise list when exercises are added
                                VStack {
                                    Text("Exercises will be displayed here")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                            }
                            
                            Spacer()
                        }
                    )
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveWorkout()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .disabled(workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveWorkout() {
        // TODO: Implement workout saving logic
        print("Saving workout: \(workoutTitle)")
        HapticFeedback.generate()
        dismiss()
    }
}

#Preview {
    CreateWorkoutView()
}
