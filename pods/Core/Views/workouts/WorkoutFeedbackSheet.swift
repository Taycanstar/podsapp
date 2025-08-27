//
//  WorkoutFeedbackSheet.swift
//  pods
//
//  Created by Dimi Nunez on 8/26/25.
//

import SwiftUI

struct WorkoutFeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workout: TodayWorkout
    let onFeedbackSubmitted: (WorkoutSessionFeedback) -> Void
    let onSkipped: () -> Void
    
    @State private var selectedDifficulty: WorkoutSessionFeedback.DifficultyRating = .justRight
    @State private var overallRPE: Double = 6.5
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("How was your workout?")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Your feedback helps us create better workouts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Difficulty Rating
                VStack(spacing: 16) {
                    Text("Overall difficulty:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(WorkoutSessionFeedback.DifficultyRating.allCases, id: \.self) { difficulty in
                            DifficultyButton(
                                difficulty: difficulty,
                                isSelected: selectedDifficulty == difficulty,
                                action: {
                                    selectedDifficulty = difficulty
                                    overallRPE = difficulty.estimatedRPE
                                    
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            )
                        }
                    }
                }
                
                // RPE Slider (optional refinement)
                VStack(spacing: 12) {
                    HStack {
                        Text("Effort level (1-10):")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f", overallRPE))
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Slider(value: $overallRPE, in: 1.0...10.0, step: 0.5)
                        .accentColor(.orange)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: submitFeedback) {
                        Text("Submit Feedback")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        onSkipped()
                        dismiss()
                    }) {
                        Text("Skip for now")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        submitFeedback()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func submitFeedback() {
        let feedback = WorkoutSessionFeedback(
            workoutId: workout.id,
            overallRPE: overallRPE,
            difficultyRating: selectedDifficulty,
            completionRate: 1.0, // Assume completion if they're providing feedback
            exerciseFeedback: [:],
            timestamp: Date()
        )
        
        onFeedbackSubmitted(feedback)
        dismiss()
    }
}

struct DifficultyButton: View {
    let difficulty: WorkoutSessionFeedback.DifficultyRating
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(difficulty.emoji)
                    .font(.system(size: 32))
                
                Text(difficulty.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    WorkoutFeedbackSheet(
        workout: TodayWorkout(
            title: "Upper Body Strength",
            exercises: [],
            estimatedDuration: 45,
            fitnessGoal: .strength,
            difficulty: 7
        ),
        onFeedbackSubmitted: { _ in },
        onSkipped: { }
    )
}