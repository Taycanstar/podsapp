//
//  ExerciseLoggingView.swift
//  Pods
//
//  Created by Claude on 7/26/25.
//

import SwiftUI
import AVKit

struct ExerciseLoggingView: View {
    let exercise: TodayWorkoutExercise
    @Environment(\.dismiss) private var dismiss
    @State private var currentSet = 1
    @State private var completedSets: [SetLog] = []
    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var isRestMode = false
    @State private var restTimeRemaining = 0
    @State private var restTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Video Header
            videoHeaderView
            
            // Exercise info section
            exerciseInfoSection
            
            // Sets logging section
            setsLoggingSection
            
            Spacer()
            
            // Action buttons
            actionButtonsSection
        }
        .navigationTitle(exercise.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupInitialValues()
        }
        .onDisappear {
            stopRestTimer()
        }
    }
    
    private var videoHeaderView: some View {
        Group {
            if let videoURL = videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)
            } else {
                // Fallback thumbnail view
                Group {
                    if let image = UIImage(named: thumbnailImageName) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "play.circle")
                                        .foregroundColor(.white)
                                        .font(.system(size: 32))
                                    Text("Video not available")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                }
                            )
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
    
    private var exerciseInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.exercise.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(exercise.sets) sets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !exercise.exercise.target.isEmpty {
                Text("Target: \(exercise.exercise.target)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !exercise.exercise.equipment.isEmpty {
                Text("Equipment: \(exercise.exercise.equipment)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var setsLoggingSection: some View {
        VStack(spacing: 16) {
            // Current set indicator
            if !isRestMode {
                Text("Set \(currentSet) of \(exercise.sets)")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top)
            }
            
            // Rest mode view
            if isRestMode {
                VStack(spacing: 16) {
                    Text("Rest Time")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(formatTime(restTimeRemaining))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                    
                    Button("Skip Rest") {
                        skipRest()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                }
                .padding()
                .background(Color("bg"))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Input fields for current set
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weight (lbs)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("0", text: $weight)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("\(exercise.reps)", text: $reps)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Completed sets list
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 4) {
                        ForEach(Array(completedSets.enumerated()), id: \.offset) { index, setLog in
                            HStack {
                                Text("Set \(index + 1)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(setLog.weight, specifier: "%.1f") lbs × \(setLog.reps) reps")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color("iosfit"))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if !isRestMode {
                // Complete set button
                Button(action: completeSet) {
                    Text("Complete Set")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(currentSetCanBeCompleted ? Color.accentColor : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!currentSetCanBeCompleted)
                .padding(.horizontal)
            }
            
            if completedSets.count == exercise.sets {
                // Finish exercise button
                Button(action: finishExercise) {
                    Text("Finish Exercise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    // MARK: - Computed Properties

    private var videoURL: URL? {
        let videoId = String(format: "%04d", exercise.exercise.id)
        return URL(string: "https://humulistoragecentral.blob.core.windows.net/videos/filtered_vids/\(videoId).mp4")
    }
    
    private var thumbnailImageName: String {
        return String(format: "%04d", exercise.exercise.id)
    }
    
    private var currentSetCanBeCompleted: Bool {
        return !reps.isEmpty && (exercise.exercise.equipment.lowercased() == "body weight" || !weight.isEmpty)
    }
    
    // MARK: - Methods
    
    private func setupInitialValues() {
        reps = "\(exercise.reps)"
        // Initialize weight based on exercise type
        if exercise.exercise.equipment.lowercased() != "body weight" {
            weight = "0"
        }
    }
    
    private func completeSet() {
        guard let repsCount = Int(reps) else { return }
        let weightValue = Double(weight) ?? 0.0
        
        let setLog = SetLog(
            setNumber: currentSet,
            weight: weightValue,
            reps: repsCount,
            completedAt: Date()
        )
        
        completedSets.append(setLog)
        
        if currentSet < exercise.sets {
            // Start rest period
            startRestPeriod()
        } else {
            // All sets completed
            finishExercise()
        }
    }
    
    private func startRestPeriod() {
        isRestMode = true
        restTimeRemaining = exercise.restTime
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                skipRest()
            }
        }
    }
    
    private func skipRest() {
        stopRestTimer()
        isRestMode = false
        currentSet += 1
        // Reset inputs for next set
        reps = "\(exercise.reps)"
    }
    
    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
    }
    
    private func finishExercise() {
        // TODO: Save exercise completion to database
        print("Exercise completed: \(exercise.exercise.name)")
        print("Completed sets: \(completedSets)")
        dismiss()
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Set Log Model

struct SetLog {
    let setNumber: Int
    let weight: Double
    let reps: Int
    let completedAt: Date
}

#Preview {
    // Create sample exercise data for preview
    let sampleExercise = ExerciseData(
        id: 1,
        name: "Bench Press",
        exerciseType: "Strength",
        bodyPart: "Chest",
        equipment: "Barbell",
        gender: "Both",
        target: "Pectorals",
        synergist: "Triceps, Anterior Deltoid"
    )
    
    let sampleTodayWorkoutExercise = TodayWorkoutExercise(
        exercise: sampleExercise,
        sets: 3,
        reps: 8,
        weight: nil,
        restTime: 90
    )
    
    NavigationView {
        ExerciseLoggingView(exercise: sampleTodayWorkoutExercise)
    }
}