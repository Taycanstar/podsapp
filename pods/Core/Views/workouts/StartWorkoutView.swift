//
//  StartWorkoutView.swift
//  pods
//
//  Created by Dimi Nunez on 7/12/25.
//

//
//  StartWorkoutView.swift
//  Pods
//
//  Created by Dimi Nunez on 7/12/25.
//

import SwiftUI

@MainActor
struct StartWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    let todayWorkout: TodayWorkout
    @EnvironmentObject var proFeatureGate: ProFeatureGate
    
    @State private var currentExerciseIndex = 0
    @State private var isWorkoutStarted = false
    @State private var workoutStartTime: Date?
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingWorkoutComplete = false
    
    var currentExercise: TodayWorkoutExercise? {
        guard currentExerciseIndex < todayWorkout.exercises.count else { return nil }
        return todayWorkout.exercises[currentExerciseIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Background color
            Color("iosbg2")
                .ignoresSafeArea(.all)
                .overlay(contentView)
        }
        .navigationTitle(todayWorkout.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    stopTimer()
                    dismiss()
                }
                .foregroundColor(.accentColor)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if isWorkoutStarted {
                    Text(formatTime(elapsedTime))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .onDisappear {
            stopTimer()
        }
        .alert("Workout Complete!", isPresented: $showingWorkoutComplete) {
            Button("Finish") {
                completeWorkout()
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("Great job! You've completed your workout in \(formatTime(elapsedTime)).")
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 20) {
            if !isWorkoutStarted {
                // Pre-workout overview
                workoutOverview
            } else {
                // Active workout
                activeWorkout
            }
        }
        .padding()
    }
    
    private var workoutOverview: some View {
        VStack(spacing: 24) {
            // Workout summary
            VStack(spacing: 16) {
                Text("Ready to start?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text("\(todayWorkout.estimatedDuration) minutes")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: "dumbbell")
                            .foregroundColor(.secondary)
                        Text("\(todayWorkout.exercises.count) exercises")
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 15))
                }
            }
            
            // Exercise list
            VStack(spacing: 12) {
                ForEach(Array(todayWorkout.exercises.enumerated()), id: \.offset) { index, exercise in
                    HStack {
                        Text("\(index + 1).")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 24, alignment: .leading)
                        
                        Text(exercise.exercise.name)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(exercise.sets) × \(exercise.reps)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("iosfit"))
                    .cornerRadius(10)
                }
            }
            
            Spacer()
            
            // Start workout button
            Button(action: {
                startWorkout()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                    Text("Start Workout")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .cornerRadius(12)
            }
        }
    }
    
    private var activeWorkout: some View {
        VStack(spacing: 24) {
            // Progress indicator
            VStack(spacing: 8) {
                HStack {
                    Text("Exercise \(currentExerciseIndex + 1) of \(todayWorkout.exercises.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                ProgressView(value: Double(currentExerciseIndex), total: Double(todayWorkout.exercises.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
            }
            
            // Current exercise
            if let exercise = currentExercise {
                VStack(spacing: 16) {
                    // Exercise name
                    Text(exercise.exercise.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    // Exercise details
                    VStack(spacing: 12) {
                        HStack(spacing: 24) {
                            VStack {
                                Text("\(exercise.sets)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("Sets")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(exercise.reps)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("Reps")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let weight = exercise.weight {
                                let unit = (UserDefaults.standard.string(forKey: "unitsSystem") == UnitsSystem.metric.rawValue) ? "kg" : "lbs"
                                VStack {
                                    Text("\(Int(weight))")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Text(unit)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Rest time
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("Rest: \(exercise.restTime / 60) min")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(20)
                    .background(Color("iosfit"))
                    .cornerRadius(12)
                }
            }
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 16) {
                if currentExerciseIndex > 0 {
                    Button(action: {
                        previousExercise()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14))
                            Text("Previous")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("iosfit"))
                        .cornerRadius(12)
                    }
                }
                
                Button(action: {
                    nextExercise()
                }) {
                    HStack(spacing: 8) {
                        Text(currentExerciseIndex < todayWorkout.exercises.count - 1 ? "Next" : "Finish")
                            .font(.system(size: 16, weight: .semibold))
                        if currentExerciseIndex < todayWorkout.exercises.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func startWorkout() {
        guard !isWorkoutStarted else { return }
        guard let email = currentUserEmail else {
            beginWorkoutSession()
            return
        }
        ensureUserDefaultsEmail(email)
        proFeatureGate.checkAccess(for: .workouts,
                                   userEmail: email,
                                   onAllowed: {
                                       WorkoutDataManager.shared.clearRateLimitCooldown(trigger: "pro_user_start")
                                       Task { await proFeatureGate.refreshUsageSummary(for: email) }
                                       beginWorkoutSession()
                                   },
                                   onBlocked: nil)
    }

    private func ensureUserDefaultsEmail(_ email: String) {
        let current = UserDefaults.standard.string(forKey: "userEmail")
        if current != email {
            UserDefaults.standard.set(email, forKey: "userEmail")
        }
    }
    
    private func beginWorkoutSession() {
        isWorkoutStarted = true
        workoutStartTime = Date()
        startTimer()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = workoutStartTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func nextExercise() {
        if currentExerciseIndex < todayWorkout.exercises.count - 1 {
            currentExerciseIndex += 1
        } else {
            // Workout complete
            showingWorkoutComplete = true
        }
    }
    
    private func previousExercise() {
        if currentExerciseIndex > 0 {
            currentExerciseIndex -= 1
        }
    }
    
    private var currentUserEmail: String? {
        let email = UserDefaults.standard.string(forKey: "userEmail")
        return email?.isEmpty == false ? email : nil
    }
    
    private func completeWorkout() {
        stopTimer()
        
        // Save workout to history - break down complex expression
        let completedExercises = todayWorkout.exercises.map { exercise in
            let completedSets = Array(1...exercise.sets).map { _ in
                CompletedSet(
                    reps: exercise.reps,
                    weight: exercise.weight ?? 0,
                    restTime: TimeInterval(exercise.restTime),
                    completed: true
                )
            }
            
            return CompletedExercise(
                exerciseId: exercise.exercise.id,
                exerciseName: exercise.exercise.name,
                sets: completedSets
            )
        }
        
        // Convert to WorkoutExercise for compatibility - break down expression
        let workoutExercises: [WorkoutExercise] = completedExercises.compactMap { completedExercise in
            guard let todayExercise = todayWorkout.exercises.first(where: { $0.exercise.id == completedExercise.exerciseId }) else {
                return nil
            }
            
            let workoutSets = completedExercise.sets.map { completedSet in
                WorkoutSet(
                    id: Int.random(in: 1000...9999),
                    reps: completedSet.reps,
                    weight: completedSet.weight,
                    duration: nil,
                    distance: nil,
                    restTime: nil
                )
            }
            
            return WorkoutExercise(
                id: Int.random(in: 1000...9999),
                exercise: LegacyExercise(
                    id: todayExercise.exercise.id,
                    name: todayExercise.exercise.name,
                    category: todayExercise.exercise.category,
                    description: nil,
                    instructions: todayExercise.exercise.instructions
                ),
                sets: workoutSets,
                notes: nil
            )
        }
        
        WorkoutHistoryService.shared.completeFullWorkout(
            workoutExercises,
            duration: elapsedTime,
            notes: "Today's AI-generated workout"
        )
        
        // Clear the session duration since the workout is completed
        LogWorkoutView.clearWorkoutSessionDuration()
        
        dismiss()
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationView {
        StartWorkoutView(todayWorkout: TodayWorkout(
            id: UUID(),
            date: Date(),
            title: "Strength Training",
            exercises: [
                TodayWorkoutExercise(
                    exercise: ExerciseData(
                        id: 1,
                        name: "Bench Press",
                        exerciseType: "strength",
                        bodyPart: "Chest",
                        equipment: "Barbell",
                        gender: "male",
                        target: "Pectorals",
                        synergist: "Triceps"
                    ),
                    sets: 3,
                    reps: 8,
                    weight: 135,
                    restTime: 180
                )
            ],
            estimatedDuration: 45,
            fitnessGoal: .strength,
            difficulty: 2
        ))
    }
}
