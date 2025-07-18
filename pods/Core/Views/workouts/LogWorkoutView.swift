//
//  LogWorkoutView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/5/25.
//

import SwiftUI

struct LogWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: Int
    @Binding var navigationPath: NavigationPath
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    // Tab management
    @State private var selectedWorkoutTab: WorkoutTab = .today
    
    // Add WorkoutManager
    @StateObject private var workoutManager = WorkoutManager()
    
    // Add user email - you'll need to pass this in or get it from environment
    @State private var userEmail: String = UserDefaults.standard.string(forKey: "user_email") ?? ""
    
    enum WorkoutTab: Hashable {
        case today, routines
        
        var title: String {
            switch self {
            case .today: return "Today"
            case .routines: return "Routines"
            }
        }
        
        var searchPrompt: String {
            switch self {
            case .today: return "Search today's workout"
            case .routines: return "Search routines"
            }
        }
    }
    
    let workoutTabs: [WorkoutTab] = [.today, .routines]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background color for the entire view
            Color("iosbg2").edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Fixed non-transparent header
                VStack(spacing: 0) {
                    tabHeaderView
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
                .background(Color("iosbg2"))
                .zIndex(1) // Keep header on top
                
                // Main content
                mainContentView
                
                Spacer()
            }
        }
        .searchable(
            text: $searchText,
            placement: .automatic,
            prompt: selectedWorkoutTab.searchPrompt
        )
        .focused($isSearchFieldFocused)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Initialize WorkoutManager when view appears
            if !userEmail.isEmpty {
                workoutManager.initialize(userEmail: userEmail)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var tabHeaderView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(workoutTabs, id: \.self) { tab in
                    TabButton(tab: tab, selectedTab: $selectedWorkoutTab)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 10)
    }
    
    private var mainContentView: some View {
        Group {
            switch selectedWorkoutTab {
            case .today:
                TodayWorkoutView(
                    searchText: searchText,
                    navigationPath: $navigationPath,
                    workoutManager: workoutManager,
                    userEmail: userEmail
                )
            case .routines:
                RoutinesWorkoutView(
                    searchText: searchText,
                    navigationPath: $navigationPath,
                    workoutManager: workoutManager,
                    userEmail: userEmail
                )
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    selectedTab = 0
                    dismiss()
                }
                .foregroundColor(.accentColor)
            }
            
            ToolbarItem(placement: .principal) {
                Text("Log Workout")
                    .font(.headline)
            }
        }
    }
}

// MARK: - Tab Button

private struct TabButton: View {
    let tab: LogWorkoutView.WorkoutTab
    @Binding var selectedTab: LogWorkoutView.WorkoutTab
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                selectedTab = tab
            }
        }) {
            Text(tab.title)
                .font(.system(size: 15))
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selectedTab == tab 
                              ? (colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.06))
                              : Color.clear)
                )
                .foregroundColor(selectedTab == tab ? .primary : Color.gray.opacity(0.8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Today Workout View

private struct TodayWorkoutView: View {
    let searchText: String
    @Binding var navigationPath: NavigationPath
    @ObservedObject var workoutManager: WorkoutManager
    let userEmail: String
    
    @State private var todayWorkout: TodayWorkout?
    @State private var isGeneratingWorkout = false
    @State private var userProfile = UserProfileService.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // Add invisible spacing at the top to prevent overlap with header
            Color.clear.frame(height: 4)
            
            // Show generation loading
            if isGeneratingWorkout {
                WorkoutGenerationCard()
                    .padding(.horizontal)
                    .transition(.opacity)
            }
            
            // Show today's workout if available
            if let workout = todayWorkout {
                TodayWorkoutCard(
                    workout: workout,
                    navigationPath: $navigationPath,
                    onStartWorkout: {
                        // Navigate to workout execution
                        navigationPath.append(WorkoutNavigationDestination.startWorkout(workout))
                    }
                )
                .padding(.horizontal)
            }
            
            // Empty state when no workout and not generating
            if todayWorkout == nil && !isGeneratingWorkout {
                VStack(spacing: 16) {
                    Image("blackex")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 200)
                    
                    Text("Preparing your workout...")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("We're creating a personalized workout based on your goals and preferences.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 45)
                }
                .padding(.top, 40)
            }
        }
        .padding(.bottom, 16)
        .background(Color("iosbg2"))
        .onAppear {
            loadOrGenerateTodayWorkout()
        }
    }
    
    private func loadOrGenerateTodayWorkout() {
        // Check if we have a workout for today
        if let data = UserDefaults.standard.data(forKey: "todayWorkout_\(userEmail)"),
           let workout = try? JSONDecoder().decode(TodayWorkout.self, from: data) {
            
            // Check if the workout is from today
            if Calendar.current.isDateInToday(workout.date) {
                todayWorkout = workout
                return
            }
        }
        
        // No workout for today, generate one automatically
        generateTodayWorkout()
    }
    
    private func generateTodayWorkout() {
        isGeneratingWorkout = true
        
        // Simulate AI workout generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let generatedWorkout = createIntelligentWorkout()
            todayWorkout = generatedWorkout
            isGeneratingWorkout = false
            
            // Save today's workout
            saveTodayWorkout(generatedWorkout)
        }
    }
    
    private func createIntelligentWorkout() -> TodayWorkout {
        let recommendationService = WorkoutRecommendationService.shared
        
        // Get user's fitness goal and preferences
        let fitnessGoal = userProfile.fitnessGoal
        let availableTime = userProfile.availableTime
        let experienceLevel = userProfile.experienceLevel
        
        // Define muscle groups based on goal
        let muscleGroups: [String]
        switch fitnessGoal {
        case .strength, .powerlifting:
            muscleGroups = ["Chest", "Back", "Shoulders", "Thighs", "Hips"]
        case .hypertrophy:
            muscleGroups = ["Chest", "Back", "Shoulders", "Upper Arms", "Thighs"]
        case .endurance:
            muscleGroups = ["Chest", "Back", "Thighs", "Cardio"]
        default:
            muscleGroups = ["Chest", "Back", "Shoulders", "Thighs"]
        }
        
        var exercises: [TodayWorkoutExercise] = []
        
        // Generate exercises for each muscle group
        for muscleGroup in muscleGroups.prefix(4) { // Limit to 4 muscle groups
            let recommendedExercises = recommendationService.getRecommendedExercises(for: muscleGroup, count: 1)
            
            for exercise in recommendedExercises {
                let recommendation = recommendationService.getSmartRecommendation(for: exercise)
                
                exercises.append(TodayWorkoutExercise(
                    exercise: exercise,
                    sets: recommendation.sets,
                    reps: recommendation.reps,
                    weight: recommendation.weight,
                    restTime: getRestTime(for: fitnessGoal)
                ))
            }
        }
        
        return TodayWorkout(
            id: UUID(),
            date: Date(),
            title: getWorkoutTitle(for: fitnessGoal),
            exercises: exercises,
            estimatedDuration: availableTime,
            fitnessGoal: fitnessGoal,
            difficulty: experienceLevel.workoutComplexity
        )
    }
    
    private func getWorkoutTitle(for goal: FitnessGoal) -> String {
        switch goal {
        case .strength:
            return "Strength Training"
        case .hypertrophy:
            return "Muscle Building"
        case .endurance:
            return "Endurance Training"
        case .powerlifting:
            return "Powerlifting Session"
        default:
            return "Full Body Workout"
        }
    }
    
    private func getRestTime(for goal: FitnessGoal) -> Int {
        switch goal {
        case .strength, .powerlifting:
            return 180 // 3 minutes
        case .hypertrophy:
            return 120 // 2 minutes
        case .endurance:
            return 60 // 1 minute
        default:
            return 90 // 1.5 minutes
        }
    }
    
    private func saveTodayWorkout(_ workout: TodayWorkout) {
        if let data = try? JSONEncoder().encode(workout) {
            UserDefaults.standard.set(data, forKey: "todayWorkout_\(userEmail)")
        }
    }
}

// MARK: - Routines Workout View

private struct RoutinesWorkoutView: View {
    let searchText: String
    @Binding var navigationPath: NavigationPath
    @ObservedObject var workoutManager: WorkoutManager
    let userEmail: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Add invisible spacing at the top to prevent overlap with header
            Color.clear.frame(height: 4)
            
            // Show "blackex" image when no workouts exist
            if !workoutManager.hasWorkouts && !workoutManager.isLoadingWorkouts {
                VStack(spacing: 16) {
                    Image("blackex")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 250, maxHeight: 250)
                    
                    Text("Build your perfect workout")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Create routines, track progress, and stay consistent. Once you add workouts, they'll show up here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 45)
                }
                .padding(.top, 40)
            }

            // New Workout button
            Button(action: {
                print("Tapped New Workout")
                HapticFeedback.generate()
                navigationPath.append(WorkoutNavigationDestination.createWorkout)
            }) {
                HStack(spacing: 6) {
                    Spacer()
                    Text("New Workout")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundColor(Color("bg"))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(Color.primary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 142)
            .padding(.top, 10)
            
            // Show loading indicator when loading workouts
            if workoutManager.isLoadingWorkouts {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Loading workouts...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
            }
            
            // TODO: Show workout list when workouts exist
            if workoutManager.hasWorkouts {
                // This will be implemented later when we have workout data
                Text("Workouts will be displayed here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 40)
            }
            
            Spacer()
        }
        .padding(.bottom, 16)
        .background(Color("iosbg2"))
    }
}

// MARK: - Today Workout Card

private struct TodayWorkoutCard: View {
    let workout: TodayWorkout
    @Binding var navigationPath: NavigationPath
    let onStartWorkout: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("\(workout.estimatedDuration) min")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "dumbbell")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("\(workout.exercises.count) exercises")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Difficulty indicator
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index < workout.difficulty ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            // Exercise list preview
            VStack(spacing: 8) {
                ForEach(workout.exercises.prefix(3), id: \.exercise.id) { exercise in
                    HStack {
                        Text(exercise.exercise.name)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(exercise.sets) × \(exercise.reps)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color("iosfit"))
                    .cornerRadius(8)
                }
                
                if workout.exercises.count > 3 {
                    Text("+ \(workout.exercises.count - 3) more exercises")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            
            // Start workout button
            Button(action: onStartWorkout) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                    Text("Start Workout")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color("bg"))
        .cornerRadius(12)
    }
}

// MARK: - Workout Generation Card

private struct WorkoutGenerationCard: View {
    @State private var animateProgress = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Generating your workout...")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 12) {
                ProgressBarWorkout(width: animateProgress ? 0.9 : 0.3, delay: 0)
                ProgressBarWorkout(width: animateProgress ? 0.7 : 0.5, delay: 0.2)
                ProgressBarWorkout(width: animateProgress ? 0.8 : 0.4, delay: 0.4)
            }

            Text("Analyzing your goals and preferences...")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Reset animation state
        animateProgress = false
        
        // Animate with delay
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            animateProgress = true
        }
    }
}

// MARK: - Progress Bar

private struct ProgressBarWorkout: View {
    let width: CGFloat
    let delay: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * width, height: 4)
                    .cornerRadius(2)
            }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: 1.5).delay(delay).repeatForever(autoreverses: true), value: width)
    }
}

// MARK: - Data Models

struct TodayWorkout: Codable, Hashable {
    let id: UUID
    let date: Date
    let title: String
    let exercises: [TodayWorkoutExercise]
    let estimatedDuration: Int
    let fitnessGoal: FitnessGoal
    let difficulty: Int
}

struct TodayWorkoutExercise: Codable, Hashable {
    let exercise: ExerciseData
    let sets: Int
    let reps: Int
    let weight: Double?
    let restTime: Int // in seconds
}

#Preview {
    NavigationView {
        LogWorkoutView(selectedTab: .constant(0), navigationPath: .constant(NavigationPath()))
    }
}
