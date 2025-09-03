//
//  ExerciseLoggingView.swift
//  pods
//
//  Created by Dimi Nunez on 7/27/25.
//

//
//  ExerciseLoggingView.swift
//  Pods
//
//  Created by Claude on 7/26/25.
//

import SwiftUI
import AVKit
import AVFoundation
import UIKit
import CryptoKit


struct ExerciseLoggingView: View {
    let exercise: TodayWorkoutExercise
    @State private var allExercises: [TodayWorkoutExercise]? // Make it @State so we can update it
    let onSetLogged: ((Int, Double?) -> Void)? // Callback to notify when sets are logged with count and optional RIR
    let isFromWorkoutInProgress: Bool // Track if we came from WorkoutInProgressView
    let initialCompletedSetsCount: Int? // Pass previously completed sets count
    let initialRIRValue: Double? // Pass previously set RIR value
    let onExerciseReplaced: ((ExerciseData) -> Void)? // Callback to notify when exercise is replaced
    let onWarmupSetsChanged: (([WarmupSetData]) -> Void)? // Callback to notify when warm-up sets change
    let onExerciseUpdated: ((TodayWorkoutExercise) -> Void)? // Callback to notify when exercise is updated (sets added/removed)
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusedField?
    @State private var showingFullscreenVideo = false
    @State private var isVideoHidden = false
    @State private var showKeyboardToolbar = false
    @State private var showingWorkoutInProgress = false
    @State private var workoutStarted: Bool
    @State private var currentSetIndex = 0
    @State private var showRIRSection = false
    @State private var rirValue: Double = 0 // RIR (Reps in Reserve) 0-4+
    @State private var isWorkoutComplete = false
    @State private var videoPlayerID = UUID() // Force video player refresh when needed
    @State private var showingExerciseOptions = false
    @State private var selectedUnit: WeightUnit = .lbs
    @State private var exerciseNotes: String = ""
    @State private var recommendMoreOften = false
    @State private var recommendLessOften = false
    @State private var currentExercise: TodayWorkoutExercise
    @State private var showingNotes = false
    
    // Enhanced tracking system state
    @State private var trackingType: ExerciseTrackingType = .repsWeight
    @State private var flexibleSets: [FlexibleSetData] = []
    
    @State private var showTimerSheet = false
    @State private var timerDuration: TimeInterval = 60 // Duration for the current timer session
    // Removed complex focus tracking - not needed for basic duration functionality
    
    
    init(exercise: TodayWorkoutExercise, allExercises: [TodayWorkoutExercise]? = nil, onSetLogged: ((Int, Double?) -> Void)? = nil, isFromWorkoutInProgress: Bool = false, initialCompletedSetsCount: Int? = nil, initialRIRValue: Double? = nil, onExerciseReplaced: ((ExerciseData) -> Void)? = nil, onWarmupSetsChanged: (([WarmupSetData]) -> Void)? = nil, onExerciseUpdated: ((TodayWorkoutExercise) -> Void)? = nil) {
        self.exercise = exercise
        self._allExercises = State(initialValue: allExercises)
        self.onSetLogged = onSetLogged
        self.isFromWorkoutInProgress = isFromWorkoutInProgress
        self.initialCompletedSetsCount = initialCompletedSetsCount
        self.initialRIRValue = initialRIRValue
        self.onExerciseReplaced = onExerciseReplaced
        self.onWarmupSetsChanged = onWarmupSetsChanged
        self.onExerciseUpdated = onExerciseUpdated
        
        // If coming from WorkoutInProgressView, workout is already started
        self._workoutStarted = State(initialValue: isFromWorkoutInProgress)
        self._currentExercise = State(initialValue: exercise)
        
        // Initialize enhanced tracking system
        let detectedTrackingType = ExerciseClassificationService.determineTrackingType(for: exercise.exercise)
        self._trackingType = State(initialValue: detectedTrackingType)
        
        // DEBUG: Print exercise details
        print("🔴 DEBUG: ExerciseLoggingView initialized for exercise:")
        print("🔴 Name: \(exercise.exercise.name)")
        print("🔴 ID: \(exercise.exercise.id)")
        print("🔴 Type: \(exercise.exercise.exerciseType)")
        print("🔴 Equipment: \(exercise.exercise.equipment)")
        print("🔴 Detected Tracking Type: \(detectedTrackingType)")
        print("🔴 Sets: \(exercise.sets), Reps: \(exercise.reps), Weight: \(exercise.weight ?? 0)")
    }
    
    enum FocusedField: Hashable {
        case reps(UUID)
        case weight(UUID)
    }
    
    
    private var bottomPadding: CGFloat {
        return focusedField != nil ? 10 : 20
    }
    
    // MARK: - Computed Views
    
    @ViewBuilder
    private var mainScrollContent: some View {
        VStack(spacing: 16) {
            // Video Header - now scrolls with content
            if !isVideoHidden {
                videoHeaderView
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            
            // Exercise name with ellipsis
            exerciseHeaderSection
            
            // Sets input section
            setsInputSection
            
            // RIR Section (shown after Log All Sets)
            if showRIRSection {
                rirSection
                    .padding(.top, 20)
            }
            
            // Add bottom padding to ensure content isn't hidden behind floating button
            Color.clear
                .frame(height: 100)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    @ViewBuilder
    private var floatingButtonStack: some View {
        VStack {
            Spacer()
            floatingButtonContent
        }
    }
    
    @ViewBuilder
    private var floatingButtonContent: some View {
        Group {
            if !workoutStarted {
                startWorkoutButton
            } else if showRIRSection {
                doneButton
            } else if isDurationBasedExercise && isFromWorkoutInProgress {
                // Duration exercises from workout in progress get timer functionality
                if allFlexibleSetsCompleted {
                    doneButton
                } else {
                    durationExerciseButtons
                }
            } else {
                // Regular reps/weight exercises use standard buttons
                workoutActionButtons
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, bottomPadding)
        .animation(.easeInOut(duration: 0.25), value: focusedField != nil)
    }
    
    @ViewBuilder
    private var scrollViewWithAnimation: some View {
        ScrollView {
            mainScrollContent
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.easeInOut(duration: 0.3), value: isVideoHidden)
    }

    // New: Single List to avoid nested List-in-ScrollView while preserving swipe actions
    @ViewBuilder
    private var mainListView: some View {
        List {
            if !isVideoHidden {
                videoHeaderView
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }

            exerciseHeaderSection
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

            // Inline sets section
            setsListRows

            if showRIRSection {
                rirSection
                    .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 0, trailing: 16))
            }

            // Bottom spacer so content isn't hidden behind floating buttons
            Color.clear
                .frame(height: 80)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .animation(.easeInOut(duration: 0.3), value: isVideoHidden)
    }

    // Inline sets rows for the List
    @ViewBuilder
    private var setsListRows: some View {
        let _ = print("🔴 DEBUG setsListRows: trackingType = \(trackingType), flexibleSets.count = \(flexibleSets.count)")

        ForEach(Array(flexibleSets.enumerated()), id: \.element.id) { index, _ in
            DynamicSetRowView(
                set: $flexibleSets[index],
                setNumber: index + 1,
                workoutExercise: currentExercise,
                onDurationChanged: { duration in
                    print("🔧 DEBUG: Duration updated to: \(duration) for set #\(index + 1)")
                    saveDurationToPersistence(duration)
                    saveFlexibleSetsToExercise()
                },
                isActive: index == currentSetIndex,
                onFocusChanged: { focused in
                    if focused { currentSetIndex = index }
                },
                onSetChanged: {
                    saveFlexibleSetsToExercise()
                },
                onPickerStateChanged: { _ in }
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    deleteFlexibleSet(at: index)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }

        Button(action: {
            print("🔧 DEBUG: Add button tapped in setsListRows")
            addNewSet()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text(trackingType == .repsWeight ? "Add Set" : "Add Interval")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    var body: some View {
        ZStack {
            mainListView
            floatingButtonStack
        }
        // Make background tap dismiss the keyboard without stealing button taps
        // .onTapGesture {
        .simultaneousGesture(TapGesture().onEnded {
            hideKeyboard()
        })
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showTimerSheet) {
            DurationExerciseTimerSheet(
                exerciseName: currentExercise.exercise.name,
                duration: timerDuration, // Use set-specific timer duration
                onTimerComplete: {
                    // Simple set completion
                    onSetLogged?(1, nil)
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            
            // Keyboard toolbar items
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    HStack {
                        Button("Done") {
                            focusedField = nil
                        }
                        .font(.system(size: 16, weight: .medium))
                        
                        Spacer()
                        
                        Button("Next") {
                            moveToNextField()
                        }
                        .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
        .onAppear {
            // Load existing notes for this exercise
            Task {
                exerciseNotes = await ExerciseNotesService.shared.loadNotes(for: currentExercise.exercise.id)
            }
            // Ensure sets are initialized for inline List
            initializeFlexibleSetsIfNeeded()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if newValue != nil && oldValue != newValue {
                // Generate haptic feedback when focus changes
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
            }
        }
        .onChange(of: isVideoHidden) { oldValue, newValue in
            // When video becomes visible again, refresh the video player
            if oldValue == true && newValue == false {
                print("🎬 Video becoming visible again, refreshing player")
                videoPlayerID = UUID()
            }
        }
        .onChange(of: currentExercise.exercise.id) { oldId, newId in
            // When exercise is replaced, refresh the video player to load the new exercise video
            if oldId != newId {
                print("🎬 Exercise replaced (ID: \(oldId) → \(newId)), refreshing video player")
                videoPlayerID = UUID()
            }
        }
        .fullScreenCover(isPresented: $showingFullscreenVideo) {
            if let videoURL = videoURL {
                FullscreenVideoView(videoURL: videoURL, isPresented: $showingFullscreenVideo)
            }
        }
        .fullScreenCover(isPresented: $showingWorkoutInProgress) {
            if let exercises = allExercises {
                // Create a sample workout for the progress view
                let sampleWorkout = TodayWorkout(
                    id: UUID(),
                    date: Date(),
                    title: "Current Workout",
                    exercises: exercises,
                    estimatedDuration: exercises.count * 10, // Rough estimate
                    fitnessGoal: .general,
                    difficulty: 3,
                    warmUpExercises: nil,
                    coolDownExercises: nil
                )
                WorkoutInProgressView(
                    isPresented: $showingWorkoutInProgress,
                    workout: sampleWorkout
                )
            }
        }
        .sheet(isPresented: $showingExerciseOptions) {
            ExerciseOptionsSheet(
                exercise: $currentExercise,
                selectedUnit: $selectedUnit,
                exerciseNotes: $exerciseNotes,
                recommendMoreOften: $recommendMoreOften,
                recommendLessOften: $recommendLessOften,
                rirValue: rirValue,
                onExerciseReplaced: onExerciseReplaced,
                onNotesRequested: {
                    // Dismiss ExerciseOptionsSheet first, then present NotesSheet
                    showingExerciseOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingNotes = true
                    }
                },
                onWarmupSetRequested: {
                    // Dismiss ExerciseOptionsSheet first, then add warmup set
                    showingExerciseOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        addNewWarmupSet()
                    }
                }
            )
            // .presentationDetents([.fraction(0.75)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingNotes) {
            // Determine which sheet to show based on notes length
            if exerciseNotes.count > 100 {
                // Full sheet for extensive notes
                ExerciseNotesSheet(
                    notes: $exerciseNotes,
                    exerciseId: currentExercise.exercise.id,
                    exerciseName: currentExercise.exercise.name
                )
            } else {
                // Quick capture modal for brief notes
                QuickNotesCaptureView(
                    notes: $exerciseNotes,
                    exerciseId: currentExercise.exercise.id,
                    exerciseName: currentExercise.exercise.name
                )
            }
        }
        .onAppear {
            // Load existing notes for the exercise
            if let notes = currentExercise.notes {
                exerciseNotes = notes
            } else {
                // Load from service if available
                Task {
                    exerciseNotes = await ExerciseNotesService.shared.loadNotes(for: currentExercise.exercise.id)
                }
            }
        }
        .onChange(of: exerciseNotes) { _, newValue in
            // Save notes when changed
            Task {
                await ExerciseNotesService.shared.saveNotes(newValue, for: currentExercise.exercise.id)
            }
        }
    }
    
    private var videoHeaderView: some View {
        Group {
            if let videoURL = videoURL {
                CustomExerciseVideoPlayer(videoURL: videoURL)
                    .id(videoPlayerID) // Use ID to force refresh when needed
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .onTapGesture {
                        showingFullscreenVideo = true
                    }
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var exerciseHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Primary header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentExercise.exercise.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Airplay button (video visibility toggle)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isVideoHidden.toggle()
                        }
                        
                        // Generate haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                    }) {
                        Image(systemName: "airplayvideo")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isVideoHidden ? .accentColor : .white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(isVideoHidden ? Color(.systemGray5) : Color.accentColor)
                            )
                    }
                    .accessibilityLabel(isVideoHidden ? "Show video" : "Hide video")
                    .accessibilityHint(isVideoHidden ? "Tap to show exercise video" : "Tap to hide exercise video")
                    
                    // Ellipsis button (exercise options)
                    Button(action: {
                        showingExerciseOptions = true
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.accentColor)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color(.systemGray5))
                            )
                    }
                    .accessibilityLabel("Exercise options")
                }
            }
            
            // Always display notes when they exist
            if !exerciseNotes.isEmpty {
                Text(exerciseNotes)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onTapGesture {
                        showingNotes = true
                    }
            }
        }
    }
    
    private var setsInputSection: some View {
        VStack(spacing: 12) {
            
            // DEBUG: Print which branch we're taking
            let _ = print("🔴 DEBUG setsInputSection: isDurationBasedExercise = \(isDurationBasedExercise)")
            let _ = print("🔴 DEBUG setsInputSection: trackingType = \(trackingType)")
            let _ = print("🔴 DEBUG setsInputSection: flexibleSets.count = \(flexibleSets.count)")
            
            // SIMPLIFIED: For duration-based exercises, use existing perfect style with direct binding
            if isDurationBasedExercise {
                // Keep the existing perfect duration input style with set-specific durations
                let _ = print("🔍 DEBUG UI: Using DURATION-BASED system (isDurationBasedExercise=true, trackingType=\(trackingType), flexibleSets.count=\(flexibleSets.count))")
                DynamicSetsInputView(
                    sets: $flexibleSets,
                    workoutExercise: currentExercise,
                    trackingType: trackingType,
                    onSetCompleted: { setIndex in
                        handleFlexibleSetCompletion(at: setIndex)
                    },
                    onAddSet: {
                        addNewSet()
                    },
                    onRemoveSet: { setIndex in
                        // Handle set removal if needed  
                    },
                    onDurationChanged: { duration in
                        // Set-specific duration update - no global variable
                        print("🔧 DEBUG: Duration updated to: \(duration) for current set")
                        saveDurationToPersistence(duration)
                        saveFlexibleSetsToExercise() // ✅ SAVE TO WORKOUT MODEL
                    },
                    onSetDataChanged: {
                        saveFlexibleSetsToExercise() // Save when any set data changes
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
            // For non-duration exercises, always use flexible tracking system
            else {
                // Flexible tracking system for all exercises
                DynamicSetsInputView(
                    sets: $flexibleSets,
                    workoutExercise: currentExercise,
                    trackingType: trackingType,
                    onSetCompleted: { setIndex in
                        handleFlexibleSetCompletion(at: setIndex)
                    },
                    onAddSet: {
                        addNewSet()
                    },
                    onRemoveSet: { setIndex in
                        // Handle set removal if needed  
                    },
                    onDurationChanged: { duration in
                        // Set-specific duration update - no global variable
                        print("🔧 DEBUG: Duration changed to: \(duration) for current set")
                        saveDurationToPersistence(duration)
                        saveFlexibleSetsToExercise() // ✅ SAVE TO WORKOUT MODEL
                    },
                    onSetDataChanged: {
                        saveFlexibleSetsToExercise() // Save when any set data changes
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            initializeFlexibleSetsIfNeeded()
        }
    }
    
    
    private var startWorkoutButton: some View {
        Button(action: startWorkout) {
            Text("Start Workout")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
    
    private var workoutActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: logCurrentSet) {
                Text("Log Set")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            
            Button(action: logAllSets) {
                Text("Log All Sets")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("tiktoknp"))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    private var doneButton: some View {
        Button(action: completeWorkout) {
            Text("Done")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .background(Color.accentColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
    }
    
    // MARK: - Duration Exercise Timer Buttons
    
    private var durationExerciseButtons: some View {
        HStack(spacing: 12) {
            // Start Timer button (matching Log Set button height)
            Button(action: startTimer) {
                Text("Start Timer")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Log Set button (consistent styling)
            Button(action: logCurrentSet) {
                Text("Log Set")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
    
    private var rirSection: some View {
        VStack(spacing: 16) {
            Text("Rate Last Set")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("How many more reps could you do?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Apple Fitness-style effort slider
            RIRSlider(value: $rirValue)
                .frame(height: 80)
                .onChange(of: rirValue) { oldValue, newValue in
                    // Notify parent whenever RIR value changes for real-time saving
                    onSetLogged?(completedSetsCount, newValue)
                }
        }
        .padding()
        .background(Color("tiktoknp"))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties

    private var videoURL: URL? {
        // Videos were encoded as ProRes 4444 and stored as .mov in Azure
        let videoId = String(format: "%04d", currentExercise.exercise.id)
        return URL(string:
            "https://humulistoragecentral.blob.core.windows.net/videos/hevc/filtered_vids_alpha_hevc/\(videoId).mov"
        )
    }
    
    private var thumbnailImageName: String {
        return String(format: "%04d", currentExercise.exercise.id)
    }
    
    // MARK: - Computed Properties
    
    private var completedSetsCount: Int {
        return flexibleSets.filter { $0.isCompleted }.count
    }
    
    private var isExerciseFullyCompleted: Bool {
        return !flexibleSets.isEmpty && flexibleSets.allSatisfy { $0.isCompleted }
    }
    
    private var isDurationBasedExercise: Bool {
        return trackingType == .timeDistance || trackingType == .timeOnly || 
               trackingType == .holdTime || trackingType == .rounds
    }
    
    private var allFlexibleSetsCompleted: Bool {
        !flexibleSets.isEmpty && flexibleSets.allSatisfy { $0.isCompleted }
    }
    
    // MARK: - Timer Functions
    
    // FIXED: Use current active set's duration, not first set
    private func startTimer() {
        // Get the current active set's duration
        let currentSet = flexibleSets.indices.contains(currentSetIndex) ? flexibleSets[currentSetIndex] : nil
        let setDuration = currentSet?.duration ?? defaultDurationForExerciseType()
        
        guard setDuration > 0 else { 
            print("🔧 ERROR: Cannot start timer with duration: \(setDuration)")
            return 
        }
        
        timerDuration = setDuration
        print("🔧 DEBUG: Starting timer for set \(currentSetIndex + 1) with duration: \(setDuration)s")
        showTimerSheet = true
    }

    // MARK: - Set Helpers (List Inline)

    private func deleteFlexibleSet(at index: Int) {
        guard index >= 0 && index < flexibleSets.count else { return }
        guard flexibleSets.count > 1 else { return }
        flexibleSets.remove(at: index)
        saveFlexibleSetsToExercise()
    }
    
    private func defaultDurationForExerciseType() -> TimeInterval {
        switch trackingType {
        case .timeOnly, .holdTime:
            return 60 // 1 minute default
        case .timeDistance:
            return 600 // 10 minutes default
        case .rounds:
            return 180 // 3 minutes default
        default:
            return 60
        }
    }
    
    private func autoLogSetFromTimer() {
        // Find the first incomplete set and mark it as completed
        if let index = flexibleSets.firstIndex(where: { !$0.isCompleted }) {
            flexibleSets[index].isCompleted = true
            
            // Save the timer duration to this set - use the duration from the set itself
            if let setDuration = flexibleSets[index].duration {
                flexibleSets[index].durationString = formatDuration(setDuration)
            }
            
            // Update parent exercise if callback exists
            saveFlexibleSetsToExercise()
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    
    // MARK: - Set Organization
    
    
    
    // MARK: - Methods
    
    
    
    
    private func saveWarmupSetsToExercise() {
        // Extract warmup sets from flexible sets
        let warmupFlexibleSets = flexibleSets.filter { $0.isWarmupSet }
        let warmupSetData = warmupFlexibleSets.compactMap { flexibleSet -> WarmupSetData? in
            guard let reps = flexibleSet.reps, let weight = flexibleSet.weight else { return nil }
            return WarmupSetData(reps: reps, weight: weight)
        }
        
        // Count the actual number of regular sets (non-warmup)
        let regularSetCount = flexibleSets.filter { !$0.isWarmupSet }.count
        
        // Create updated exercise with warm-up sets and updated regular set count
        let updatedExercise = TodayWorkoutExercise(
            exercise: currentExercise.exercise,
            sets: regularSetCount,
            reps: currentExercise.reps,
            weight: currentExercise.weight,
            restTime: currentExercise.restTime,
            notes: currentExercise.notes,
            warmupSets: warmupSetData.isEmpty ? nil : warmupSetData
        )
        
        // Update the current exercise reference
        currentExercise = updatedExercise
        
        // Update the allExercises array if it exists (for WorkoutInProgressView)
        if var exercises = allExercises,
           let currentIndex = exercises.firstIndex(where: { $0.exercise.id == currentExercise.exercise.id }) {
            exercises[currentIndex] = updatedExercise
            allExercises = exercises
        }
        
        // Save to parent via callback if available
        onExerciseUpdated?(updatedExercise)
        
        // Call the callback for compatibility
        onWarmupSetsChanged?(warmupSetData)
    }
    
    
    private func startWorkout() {
        // Show the workout in progress view immediately
        if let exercises = allExercises {
            print("🏋️ Starting workout with \(exercises.count) exercises")
            showingWorkoutInProgress = true
        }
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func logCurrentSet() {
        guard currentSetIndex < flexibleSets.count else { 
            print("❌ ERROR: currentSetIndex \(currentSetIndex) >= flexibleSets.count \(flexibleSets.count)")
            return 
        }
        
        // Mark current flexible set as completed
        flexibleSets[currentSetIndex].isCompleted = true
        
        // Move to next set
        let previousSetIndex = currentSetIndex
        currentSetIndex += 1
        
        // Handle completion callback for flexible system
        handleFlexibleSetCompletion(at: previousSetIndex)
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func logAllSets() {
        // Mark all flexible sets as completed
        for index in flexibleSets.indices {
            flexibleSets[index].isCompleted = true
        }
        
        // Show RIR section
        showRIRSection = true
        
        // Notify parent with completed sets count
        onSetLogged?(completedSetsCount, nil)
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func completeWorkout() {
        // Notify parent with final completed sets count and RIR value
        onSetLogged?(completedSetsCount, rirValue)
        
        print("🏋️ Exercise completed with RIR: \(rirValue)")
        
        // Dismiss this view to go back to WorkoutInProgressView
        dismiss()
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func addNewSet() {
        print("🔧 DEBUG: addNewSet() called - Current flexibleSets count: \(flexibleSets.count)")
        let newSet = FlexibleSetData(trackingType: trackingType)
        flexibleSets.append(newSet)
        print("🔧 DEBUG: After adding new set - flexibleSets count: \(flexibleSets.count)")
        
        // Save to parent exercise data
        saveFlexibleSetsToExercise()
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func addNewWarmupSet() {
        var newWarmupSet = FlexibleSetData(trackingType: trackingType)
        newWarmupSet.isWarmupSet = true
        
        // For warmup sets, use lighter weights if applicable
        if trackingType == .repsWeight {
            newWarmupSet.reps = "\(currentExercise.reps)"
            newWarmupSet.weight = currentExercise.exercise.equipment.lowercased() == "body weight" ? nil : "50"
        }
        
        // Insert at the beginning (warmup sets come first)
        let warmupCount = flexibleSets.filter { $0.isWarmupSet }.count
        flexibleSets.insert(newWarmupSet, at: warmupCount)
        
        // Save to parent exercise data
        saveWarmupSetsToExercise()
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func moveToNextField() {
        guard let currentField = focusedField else { return }
        
        // Generate haptic feedback for next button
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        switch currentField {
        case .reps(let setId):
            // Move to weight field of same set
            focusedField = .weight(setId)
        case .weight(let setId):
            // Find current set in flexible sets and move to next set's reps field, or dismiss if last
            if let currentIndex = flexibleSets.firstIndex(where: { $0.id.uuidString == setId.uuidString }) {
                if currentIndex < flexibleSets.count - 1 {
                    let nextSet = flexibleSets[currentIndex + 1]
                    focusedField = .reps(nextSet.id)
                } else {
                    focusedField = nil
                }
            } else {
                focusedField = nil
            }
        }
    }
    
    // MARK: - Enhanced Tracking System Helpers
    
    /// Initialize flexible sets for enhanced tracking
    private func initializeFlexibleSetsIfNeeded() {
        if flexibleSets.isEmpty {
            // PRIORITY 1: Restore from TodayWorkoutExercise if available
            if let savedFlexibleSets = currentExercise.flexibleSets, !savedFlexibleSets.isEmpty {
                flexibleSets = savedFlexibleSets
                
                // Update timerDuration from first duration-based set
                if let durationSet = savedFlexibleSets.first(where: { $0.duration != nil }),
                   let duration = durationSet.duration {
                    timerDuration = duration
                }
                return
            }
            
            // PRIORITY 2: Create flexible sets based on workout's recommended sets
            let setCount = currentExercise.sets
            for _ in 0..<setCount {
                var newSet = FlexibleSetData(trackingType: trackingType)
                // Pre-populate with workout's recommended values
                if trackingType == .repsWeight {
                    newSet.reps = "\(currentExercise.reps)"
                    if let weight = currentExercise.weight, weight > 0 {
                        newSet.weight = "\(Int(weight))"
                    }
                } else if trackingType == .repsOnly {
                    newSet.reps = "\(currentExercise.reps)"
                }
                flexibleSets.append(newSet)
            }
            
            // PRIORITY 3: Apply persisted durations AFTER flexible sets are created
            loadPersistedDurationSettings()
        }
    }
    
    /// Handle completion of a flexible set
    private func handleFlexibleSetCompletion(at setIndex: Int) {
        guard setIndex < flexibleSets.count else { return }
        
        // Update current set index if needed
        if workoutStarted && setIndex >= currentSetIndex {
            currentSetIndex = min(setIndex + 1, flexibleSets.count - 1)
        }
        
        // Check if all sets are completed
        let completedSetsCount = flexibleSets.filter { $0.isCompleted }.count
        
        // Notify parent about set completion
        onSetLogged?(completedSetsCount, rirValue > 0 ? rirValue : nil)
        
        // Show RIR section if all sets are completed
        if completedSetsCount == flexibleSets.count {
            showRIRSection = true
        }
    }
    
    /// Get default set count based on tracking type
    private func defaultSetCount(for type: ExerciseTrackingType) -> Int {
        switch type {
        case .repsWeight:
            return 3 // Traditional 3 sets for strength
        case .timeDistance, .timeOnly:
            return 1 // Usually one session for cardio/aerobic
        // Handle legacy types that might still exist in saved data
        case .repsOnly:
            return 3 // Treat as strength exercise
        case .holdTime:
            return 1 // Treat as duration exercise
        case .rounds:
            return 1 // Treat as duration exercise
        }
    }
    
    // MARK: - Duration Persistence Helper Functions
    
    /// Load persisted duration settings from UserDefaults and apply to flexible sets
    private func loadPersistedDurationSettings() {
        let exerciseId = currentExercise.exercise.id
        let persistenceKey = "exercise_duration_\(exerciseId)"
        
        if let durationSeconds = UserDefaults.standard.object(forKey: persistenceKey) as? TimeInterval,
           durationSeconds > 0 {
            print("📱 ExerciseLogging: Restored persisted duration for exercise \(exerciseId): \(durationSeconds)s")
            
            // Apply the duration to all flexible sets immediately
            for index in self.flexibleSets.indices {
                if self.isDurationBasedTrackingType(self.flexibleSets[index].trackingType) {
                    self.flexibleSets[index].duration = durationSeconds
                    self.flexibleSets[index].durationString = self.formatDuration(durationSeconds)
                }
            }
        }
    }
    
    /// Save duration changes to UserDefaults for persistence
    private func saveDurationToPersistence(_ duration: TimeInterval) {
        let exerciseId = currentExercise.exercise.id
        let persistenceKey = "exercise_duration_\(exerciseId)"
        
        if duration > 0 {
            UserDefaults.standard.set(duration, forKey: persistenceKey)
            print("📱 ExerciseLogging: Persisted duration for exercise \(exerciseId): \(duration)s")
        } else {
            UserDefaults.standard.removeObject(forKey: persistenceKey)
            print("📱 ExerciseLogging: Cleared persisted duration for exercise \(exerciseId)")
        }
        
        UserDefaults.standard.synchronize()
    }
    
    /// Save flexible sets to workout model - CRITICAL for duration persistence
    private func saveFlexibleSetsToExercise() {
        print("🔧 DEBUG: saveFlexibleSetsToExercise() called with \(flexibleSets.count) flexible sets")
        let updatedExercise = TodayWorkoutExercise(
            exercise: currentExercise.exercise,
            sets: currentExercise.sets,
            reps: currentExercise.reps,
            weight: currentExercise.weight,
            restTime: currentExercise.restTime,
            notes: currentExercise.notes,
            warmupSets: currentExercise.warmupSets,
            flexibleSets: flexibleSets.isEmpty ? nil : flexibleSets, // ✅ SAVE DURATION
            trackingType: trackingType // ✅ SAVE TRACKING TYPE
        )
        
        currentExercise = updatedExercise
        print("🔧 DEBUG: Updated currentExercise with \(flexibleSets.count) flexible sets")
        
        // Update parent workout if needed
        print("🔧 DEBUG: Calling onExerciseUpdated callback for exercise: \(updatedExercise.exercise.name)")
        onExerciseUpdated?(updatedExercise)
    }
    
    /// Check if the tracking type is duration-based
    private func isDurationBasedTrackingType(_ trackingType: ExerciseTrackingType) -> Bool {
        return trackingType == .timeOnly || trackingType == .timeDistance || trackingType == .holdTime
    }
    
    /// Hide keyboard when tapping outside input fields
    private func hideKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle2: TextFieldStyle {
    let isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.blue : Color(.systemGray4), lineWidth: isFocused ? 2 : 1)
            )
            .foregroundColor(isFocused ? .blue : .primary)
            .font(.system(size: 16, weight: .medium))
    }
}

// MARK: - Custom Exercise Video Player

struct CustomExerciseVideoPlayer: UIViewControllerRepresentable {
    let videoURL: URL
    
    func makeUIViewController(context: Context) -> ExerciseVideoPlayerController {
        let controller = ExerciseVideoPlayerController()
        controller.videoURL = videoURL  // Store URL for later setup
        // Don't call setup here, let viewDidLoad handle it
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ExerciseVideoPlayerController, context: Context) {
        // Only update if URL actually changed and we need to load a different video
        if uiViewController.videoURL != videoURL {
            // Clean up old player before loading new video
            uiViewController.cleanup()
            uiViewController.videoURL = videoURL
            uiViewController.setupPlayerIfReady()
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: ExerciseVideoPlayerController, coordinator: ()) {
        uiViewController.cleanup()
    }
}

import AVFoundation
import AVKit
import UIKit

class ExerciseVideoPlayerController: UIViewController {
    // MARK: - Public
    var videoURL: URL?

    // MARK: - Private
    private var playerView: UIView!
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerItem: AVPlayerItem?
    private var timeControlObs: NSKeyValueObservation?
    private var fallbackWorkItem: DispatchWorkItem?
    private var loadingIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        DispatchQueue.main.async { [weak self] in
            self?.setupPlayerIfReady()
        }
    }

    // MARK: - UI
    private func setupViews() {
        view.backgroundColor = .clear

        playerView = UIView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.backgroundColor = .clear
        view.addSubview(playerView)

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = .gray
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Playback Setup
func setupPlayerIfReady() {
    guard let url = videoURL else { return }

    // Stream the MOV directly (HEVC w/ alpha is hardware-decoded on iOS 13+)
    let item = AVPlayerItem(url: url)
    let p = AVPlayer(playerItem: item)
    p.isMuted = true
    p.automaticallyWaitsToMinimizeStalling = true
    self.player = p

    if playerLayer == nil {
        let layer = AVPlayerLayer(player: p)
        layer.videoGravity = .resizeAspect
        layer.isOpaque = false                          // <-- critical
        layer.backgroundColor = UIColor.clear.cgColor   // <-- critical
        self.playerLayer = layer
        self.playerView.layer.addSublayer(layer)
    } else {
        self.playerLayer?.player = p
    }

    // Make sure every container is transparent too
    self.view.backgroundColor = .clear
    self.playerView.backgroundColor = .clear

    view.setNeedsLayout()
    view.layoutIfNeeded()
    playerLayer?.frame = playerView.bounds

    // Loop
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(loopVideo),
        name: .AVPlayerItemDidPlayToEndTime,
        object: item
    )

    p.play()
}


// Utility: timeout wrapper
func withTimeout<T>(seconds: TimeInterval, _ op: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await op() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw NSError(domain: "VideoPrepTimeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Prep timed out"])
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}



    private func startStreaming(_ url: URL) {
        // Use AVURLAsset so we can tweak network behavior
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetAllowsConstrainedNetworkAccessKey: true
        ])
        let item = AVPlayerItem(asset: asset)
        item.preferredPeakBitRate = 4_000_000 // ~4 Mbps to avoid stalls

        setupPlayer(with: item)

        // Observe time control to know when we actually start playing
        timeControlObs = player?.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            guard let self = self else { return }
            switch player.timeControlStatus {
            case .playing:
                // Streaming started → cancel fallback
                self.loadingIndicator.stopAnimating()
                self.fallbackWorkItem?.cancel()
            case .waitingToPlayAtSpecifiedRate:
                // still buffering; keep spinner
                break
            case .paused:
                // If we're "ready" but paused, nudge
                if player.currentItem?.status == .readyToPlay {
                    player.playImmediately(atRate: 1.0)
                }
            @unknown default: break
            }
        }

        player?.playImmediately(atRate: 1.0)
    }

    private func setupPlayer(with item: AVPlayerItem) {
        playerItem = item

        let p = AVPlayer(playerItem: item)
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        player = p

        if playerLayer == nil {
            let layer = AVPlayerLayer(player: p)
            layer.videoGravity = .resizeAspect
            layer.backgroundColor = UIColor.clear.cgColor
            playerLayer = layer
            playerView.layer.addSublayer(layer)
        } else {
            playerLayer?.player = p
        }

        // Auto-loop
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loopVideo),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        // Ensure layer has a valid frame before first frame render
        view.setNeedsLayout()
        view.layoutIfNeeded()
        playerLayer?.frame = playerView.bounds
    }

    // MARK: - Fallback: Download then play locally
    private func downloadAndPlay(_ url: URL) {
        loadingIndicator.startAnimating()

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, error in
            guard let self = self else { return }
            if let error = error {
                print("Download error: \(error)")
                DispatchQueue.main.async { self.loadingIndicator.stopAnimating() }
                return
            }
            guard let tempURL = tempURL else {
                DispatchQueue.main.async { self.loadingIndicator.stopAnimating() }
                return
            }
            // Move to a stable temp path
            let localURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString + ".mov")
            try? FileManager.default.removeItem(at: localURL)
            do {
                try FileManager.default.moveItem(at: tempURL, to: localURL)
            } catch {
                print("File move error: \(error)")
            }

            // Play local file (no streaming quirks)
            let item = AVPlayerItem(url: localURL)
            item.preferredPeakBitRate = 0 // unrestricted for local
            DispatchQueue.main.async {
                self.setupPlayer(with: item)
                self.player?.playImmediately(atRate: 1.0)
                self.loadingIndicator.stopAnimating()
            }
        }
        task.resume()
    }

    // MARK: - Layout & Cleanup
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = playerView.bounds

        // If we’re ready but paused (sometimes happens during layout), nudge
        if player?.currentItem?.status == .readyToPlay, player?.timeControlStatus != .playing {
            player?.playImmediately(atRate: 1.0)
        }
    }

    @objc private func loopVideo() {
        player?.seek(to: .zero) { [weak self] _ in
            self?.player?.play()
        }
    }

    func cleanup() {
        fallbackWorkItem?.cancel()
        timeControlObs = nil
        NotificationCenter.default.removeObserver(self)

        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerItem = nil

        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil
    }
}

// MARK: - RIR Slider Component

struct RIRSlider: View {
    @Binding var value: Double
    @State private var lastHapticValue: Int = -1
    
    private let maxRIR: Double = 4
    private let barCount = 5 // 0, 1, 2, 3, 4+
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                // Triangular bars (like Apple Fitness)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<barCount, id: \.self) { index in
                        RIRTriangleBar(
                            height: barHeight(for: index),
                            isActive: Double(index) <= value
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Labels below bars
                HStack(spacing: 3) {
                    ForEach(0..<barCount, id: \.self) { index in
                        Text(barLabel(for: index))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Double(index) <= value ? .accentColor : .gray)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(
                // Invisible drag area
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let progress = gesture.location.x / geometry.size.width
                                let clampedProgress = max(0, min(1, progress))
                                value = clampedProgress * maxRIR
                                
                                // Subtle haptic feedback only when crossing integer values
                                let currentIntValue = Int(value)
                                if currentIntValue != lastHapticValue {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred(intensity: 0.3)
                                    lastHapticValue = currentIntValue
                                }
                            }
                    )
            )
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 16
        let maxHeight: CGFloat = 50
        let heightIncrement = (maxHeight - baseHeight) / CGFloat(barCount - 1)
        return baseHeight + (heightIncrement * CGFloat(index))
    }
    
    
    private func barLabel(for index: Int) -> String {
        if index == barCount - 1 {
            return "4+"
        } else {
            return "\(index)"
        }
    }
}

struct RIRTriangleBar: View {
    let height: CGFloat
    let isActive: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background bar (inactive state)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(height: height)
            
            // Active bar with smooth gradient fill
            if isActive {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.8), .accentColor],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: height)
                    .animation(.easeInOut(duration: 0.15), value: isActive)
            }
        }
    }
}

enum VideoPrepError: Error { case badDownload, exportFailed }

struct VideoPrep {
    /// Returns a local, device-friendly MP4 for the remote MOV (downloads + transcodes once, then caches).
    static func preparePlayableURL(from remoteURL: URL) async throws -> URL {
        // Cache path based on URL hash
        let cacheDir = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ExerciseVideos", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let key = sha256(remoteURL.absoluteString)
        let cachedMP4 = cacheDir.appendingPathComponent("\(key).mp4")

        if FileManager.default.fileExists(atPath: cachedMP4.path) {
            return cachedMP4
        }

        // 1) Download the .mov
        let (tempMOV, _) = try await URLSession.shared.download(from: remoteURL)
        let localMOV = cacheDir.appendingPathComponent("\(key).mov")
        try? FileManager.default.removeItem(at: localMOV)
        try FileManager.default.moveItem(at: tempMOV, to: localMOV)

        // 2) Decide whether we need to transcode (we do, because MOV often heavy),
        //    but keep it resilient: if export fails, fall back to just returning the .mov.
        let asset = AVURLAsset(url: localMOV)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080) ??
                           AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            // If we can't create an exporter, use the original file as last resort
            return localMOV
        }

        export.outputURL = cachedMP4
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true
        try? FileManager.default.removeItem(at: cachedMP4)

        // 3) Export (transcode) to H.264 MP4 (system chooses H.264 for .mp4)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            export.exportAsynchronously {
                switch export.status {
                case .completed:
                    cont.resume()
                case .failed, .cancelled:
                    cont.resume(throwing: export.error ?? VideoPrepError.exportFailed)
                default:
                    break
                }
            }
        }

        return cachedMP4
    }

    private static func sha256(_ s: String) -> String {
        let data = Data(s.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Fullscreen Video View

struct FullscreenVideoView: View {
    let videoURL: URL
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Video player
            CustomExerciseVideoPlayer(videoURL: videoURL)
                .ignoresSafeArea()
            
            // Close button overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Exercise Options Sheet

struct ExerciseOptionsSheet: View {
    @Binding var exercise: TodayWorkoutExercise
    @Binding var selectedUnit: WeightUnit
    @Binding var exerciseNotes: String
    @Binding var recommendMoreOften: Bool
    @Binding var recommendLessOften: Bool
    let rirValue: Double
    let onExerciseReplaced: ((ExerciseData) -> Void)?
    let onNotesRequested: () -> Void
    let onWarmupSetRequested: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingReplaceExercise = false
    @State private var showingDeleteConfirmation = false
    @State private var restTimerEnabled = false
    @State private var workingSetsTime = 60 // Default 1 minute in seconds
    @State private var warmupSetsTime = 60 // Default 1 minute in seconds
    @State private var showingWorkingSetsPicker = false
    @State private var showingWarmupSetsPicker = false
    
    var body: some View {
        NavigationView {
            List {
                // History - Navigate to ExerciseHistory view
                NavigationLink(destination: ExerciseHistory(exercise: exercise)) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 28)
                        Text("History")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                .padding(.vertical, 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden, edges: .top)
                
                // Rest Timer
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 28)
                    Text("Rest Timer")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: $restTimerEnabled)
                }
                .padding(.vertical, 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                // Working Sets (shown only when Rest Timer is enabled)
                if restTimerEnabled {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingWorkingSetsPicker.toggle()
                        }
                    }) {
                        HStack {
                            // Empty space for indentation (no icon)
                            Spacer()
                                .frame(width: 28)
                            Text("Working Sets")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(formatTime(workingSetsTime))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                            Image(systemName: showingWorkingSetsPicker ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 16)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    
                    // Working Sets Inline Picker
                    if showingWorkingSetsPicker {
                        HStack {
                            Spacer()
                            
                            HStack(spacing: 0) {
                                // Minutes picker
                                Picker("Minutes", selection: Binding(
                                    get: { workingSetsTime / 60 },
                                    set: { workingSetsTime = $0 * 60 + (workingSetsTime % 60) }
                                )) {
                                    ForEach(0...10, id: \.self) { minute in
                                        Text("\(minute)")
                                            .tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel) 
                                .frame(width: 80)
                                .clipped()
                                
                                Text("min")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                
                                // Seconds picker
                                Picker("Seconds", selection: Binding(
                                    get: { workingSetsTime % 60 },
                                    set: { workingSetsTime = (workingSetsTime / 60) * 60 + $0 }
                                )) {
                                    ForEach(Array(stride(from: 0, through: 59, by: 5)), id: \.self) { second in
                                        Text("\(second)")
                                            .tag(second)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80)
                                .clipped()
                                
                                Text("sec")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .listRowInsets(EdgeInsets())
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Warm-up Sets (shown only when Rest Timer is enabled)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingWarmupSetsPicker.toggle()
                        }
                    }) {
                        HStack {
                            // Empty space for indentation (no icon)
                            Spacer()
                                .frame(width: 28)
                            Text("Warm-up Sets")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(formatTime(warmupSetsTime))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                            Image(systemName: showingWarmupSetsPicker ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 16)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    
                    // Warm-up Sets Inline Picker
                    if showingWarmupSetsPicker {
                        HStack {
                            Spacer()
                            
                            HStack(spacing: 0) {
                                // Minutes picker
                                Picker("Minutes", selection: Binding(
                                    get: { warmupSetsTime / 60 },
                                    set: { warmupSetsTime = $0 * 60 + (warmupSetsTime % 60) }
                                )) {
                                    ForEach(0...10, id: \.self) { minute in
                                        Text("\(minute)")
                                            .tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80)
                                .clipped()
                                
                                Text("min")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                
                                // Seconds picker
                                Picker("Seconds", selection: Binding(
                                    get: { warmupSetsTime % 60 },
                                    set: { warmupSetsTime = (warmupSetsTime / 60) * 60 + $0 }
                                )) {
                                    ForEach(Array(stride(from: 0, through: 59, by: 5)), id: \.self) { second in
                                        Text("\(second)")
                                            .tag(second)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80)
                                .clipped()
                                
                                Text("sec")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .listRowInsets(EdgeInsets())
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                // Replace
                Button(action: {
                    showingReplaceExercise = true
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 28)
                        Text("Replace")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                .padding(.vertical, 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                // Notes with visual indicator
                Button(action: {
                    onNotesRequested()
                }) {
                    HStack {
                        Image(systemName: exerciseNotes.isEmpty ? "note.text" : "note.text.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 28)
                        
                        Text("Notes")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Subtle character count indicator instead of blue dot
                        if !exerciseNotes.isEmpty {
                            Text("\(exerciseNotes.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.vertical, 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                // Add Warm-up set
                Button(action: {
                    onWarmupSetRequested()
                }) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 28)
                        Text("Add warm-up set")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                .padding(.vertical, 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                // Units
                HStack {
                    Image(systemName: "scalemass")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 28)
                    Text("Units")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)
                    Spacer()
                    Picker("Units", selection: $selectedUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 100)
                }
                .padding(.vertical, 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                // Recommend more often
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 28)
                    Text("Recommend more often")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    Spacer()
                    Toggle("", isOn: $recommendMoreOften)
                        .onChange(of: recommendMoreOften) { _, newValue in
                            if newValue {
                                recommendLessOften = false
                            }
                        }
                }
                .padding(.vertical, 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                // Recommend less often
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 28)
                    Text("Recommend less often")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    Spacer()
                    Toggle("", isOn: $recommendLessOften)
                        .onChange(of: recommendLessOften) { _, newValue in
                            if newValue {
                                recommendMoreOften = false
                            }
                        }
                }
                .padding(.vertical, 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                // Don't recommend again
                Button(action: {
                    // Handle don't recommend again
                    print("Don't recommend \(exercise.exercise.name) again")
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "nosign")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 28)
                        Text("Don't recommend again")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                .padding(.vertical, 14)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                
                
                // Delete from workout
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                            .frame(width: 28)
                        Text("Delete from workout")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .padding(.vertical, 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden, edges: .bottom)
            }
            .listStyle(PlainListStyle())
            .navigationTitle(exercise.exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .alert("Delete Exercise", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Handle delete exercise from workout
                print("Deleting \(exercise.exercise.name) from workout")
                dismiss()
            }
        } message: {
            Text("Are you sure you want to remove \(exercise.exercise.name) from this workout?")
        }
        .sheet(isPresented: $showingReplaceExercise) {
            ReplaceExerciseSheet(
                currentExercise: $exercise,
                onExerciseReplaced: onExerciseReplaced
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes)m"
            } else {
                return "\(minutes)m \(remainingSeconds)s"
            }
        }
    }
}


// MARK: - Replace Exercise Sheet

struct ReplaceExerciseSheet: View {
    @Binding var currentExercise: TodayWorkoutExercise
    let onExerciseReplaced: ((ExerciseData) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var equipmentFilter: EquipmentFilter = .userEquipment
    @State private var sortOption: SortOption = .best
    @State private var userEquipment: Set<String> = []
    @State private var exerciseHistory: [Int: ExerciseHistoryInfo] = [:]
    @State private var isLoadingHistory = false
    
    // Filter and Sort Options
    enum EquipmentFilter: String, CaseIterable {
        case userEquipment = "Your Equipment"
        case noEquipment = "No Equipment"
        case sameEquipment = "Same Equipment"
        case differentEquipment = "Different Equipment"
    }
    
    enum SortOption: String, CaseIterable {
        case best = "Best Replacement"
        case mostLogged = "Your Most Logged"
        case leastLogged = "Your Least Logged"
        case neverLogged = "Never Logged"
    }
    
    struct ExerciseHistoryInfo {
        let timesLogged: Int
        let lastLoggedDate: Date?
        let averageWeight: Double?
    }
    
    init(currentExercise: Binding<TodayWorkoutExercise>, onExerciseReplaced: ((ExerciseData) -> Void)? = nil) {
        self._currentExercise = currentExercise
        self.onExerciseReplaced = onExerciseReplaced
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Large Title that scrolls with content

                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search exercises", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // Current Exercise Card
                    HStack(spacing: 12) {
                        // Exercise thumbnail
                        let thumbnailName = String(format: "%04d", currentExercise.exercise.id)
                        if let image = UIImage(named: thumbnailName) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "dumbbell")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 20))
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Exercise")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(currentExercise.exercise.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Filter Controls
                    HStack {
                        Spacer()
                        
                        // Filter Menu
                        Menu {
                            ForEach(EquipmentFilter.allCases, id: \.self) { filter in
                                Button(action: { equipmentFilter = filter }) {
                                    HStack {
                                        Text(filter.rawValue)
                                        if equipmentFilter == filter {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 28, height: 28)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        // Sort Menu
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: { sortOption = option }) {
                                    HStack {
                                        Text(option.rawValue)
                                        if sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 28, height: 28)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    
                    // Exercise List
                    if isLoadingHistory {
                        ProgressView("Loading exercise history...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 100)
                    } else if filteredExercises.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No exercises found")
                                .font(.headline)
                            Text("Try adjusting your filters or search terms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 100)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredExercises.enumerated()), id: \.element.id) { index, exercise in
                                if index > 0 {
                                    Divider()
                                        .padding(.leading, 88)
                                }
                                ExerciseReplacementRow(
                                    exercise: exercise,
                                    matchScore: calculateMatchScore(for: exercise),
                                    userHistory: exerciseHistory[exercise.id],
                                    onSelect: { replaceExercise(with: exercise) }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadUserEquipment()
            await loadExerciseHistory()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredExercises: [ExerciseData] {
        let allExercises = ExerciseDatabase.getAllExercises()
            .filter { $0.id != currentExercise.exercise.id } // Exclude current
        
        // First, filter by logical replaceability (muscle groups and movement patterns)
        let logicallyRelevant = getLogicallyRelevantExercises(from: allExercises)
        
        // Apply search filter
        let searchFiltered = searchText.isEmpty ? logicallyRelevant :
            logicallyRelevant.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        
        // Apply equipment filter
        let equipmentFiltered = applyEquipmentFilter(to: searchFiltered)
        
        // Apply sorting
        return applySorting(to: equipmentFiltered)
    }
    
    private func getLogicallyRelevantExercises(from exercises: [ExerciseData]) -> [ExerciseData] {
        let currentBodyPart = currentExercise.exercise.bodyPart
        let currentTarget = currentExercise.exercise.target
        let currentSynergists = Set(currentExercise.exercise.synergist.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        
        return exercises.filter { exercise in
            // Primary criteria: Same body part
            if exercise.bodyPart == currentBodyPart {
                return true
            }
            
            // Secondary criteria: Same target muscle
            if exercise.target == currentTarget {
                return true
            }
            
            // Tertiary criteria: Significant synergist overlap (at least 2 common muscles)
            let exerciseSynergists = Set(exercise.synergist.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            let commonSynergists = currentSynergists.intersection(exerciseSynergists)
            if commonSynergists.count >= 2 {
                return true
            }
            
            // Special case: Compound movements that work similar patterns
            if isCompoundMovementMatch(current: currentExercise.exercise, candidate: exercise) {
                return true
            }
            
            return false
        }
    }
    
    private func isCompoundMovementMatch(current: ExerciseData, candidate: ExerciseData) -> Bool {
        let currentName = current.name.lowercased()
        let candidateName = candidate.name.lowercased()
        
        // Pressing movements
        if (currentName.contains("press") || currentName.contains("push")) &&
           (candidateName.contains("press") || candidateName.contains("push")) {
            return true
        }
        
        // Pulling movements
        if (currentName.contains("pull") || currentName.contains("row") || currentName.contains("chin")) &&
           (candidateName.contains("pull") || candidateName.contains("row") || candidateName.contains("chin")) {
            return true
        }
        
        // Squatting movements
        if (currentName.contains("squat") || currentName.contains("lunge")) &&
           (candidateName.contains("squat") || candidateName.contains("lunge")) {
            return true
        }
        
        // Deadlifting/hinge movements
        if (currentName.contains("deadlift") || currentName.contains("romanian") || currentName.contains("rdl")) &&
           (candidateName.contains("deadlift") || candidateName.contains("romanian") || candidateName.contains("rdl")) {
            return true
        }
        
        // Curling movements
        if currentName.contains("curl") && candidateName.contains("curl") {
            return true
        }
        
        return false
    }
    
    // MARK: - Methods
    
    private func calculateMatchScore(for exercise: ExerciseData) -> Double {
        var score = 0.0
        
        // Same body part (highest priority for logical replacement)
        if exercise.bodyPart == currentExercise.exercise.bodyPart {
            score += 100.0
        }
        
        // Same target muscle (very high priority)
        if exercise.target == currentExercise.exercise.target {
            score += 80.0
        }
        
        // Compound movement pattern match
        if isCompoundMovementMatch(current: currentExercise.exercise, candidate: exercise) {
            score += 60.0
        }
        
        // Synergist muscle overlap (good indicator of similar muscle activation)
        let currentSynergists = Set(currentExercise.exercise.synergist.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        let exerciseSynergists = Set(exercise.synergist.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        let overlap = currentSynergists.intersection(exerciseSynergists)
        score += Double(overlap.count) * 10.0
        
        // Equipment compatibility bonus
        if equipmentFilter == .userEquipment && userEquipment.contains(exercise.equipment) {
            score += 15.0
        }
        
        // Same equipment type preference
        if exercise.equipment == currentExercise.exercise.equipment {
            score += 25.0
        }
        
        // User history bonus (familiarity)
        if let history = exerciseHistory[exercise.id] {
            score += min(Double(history.timesLogged) * 3.0, 30.0)
        }
        
        return score
    }
    
    private func applyEquipmentFilter(to exercises: [ExerciseData]) -> [ExerciseData] {
        switch equipmentFilter {
        case .userEquipment:
            return exercises.filter { userEquipment.contains($0.equipment) }
        case .noEquipment:
            return exercises.filter { $0.equipment == "Body weight" }
        case .sameEquipment:
            return exercises.filter { $0.equipment == currentExercise.exercise.equipment }
        case .differentEquipment:
            return exercises.filter { $0.equipment != currentExercise.exercise.equipment }
        }
    }
    
    private func applySorting(to exercises: [ExerciseData]) -> [ExerciseData] {
        switch sortOption {
        case .best:
            return exercises.sorted {
                calculateMatchScore(for: $0) > calculateMatchScore(for: $1)
            }
        case .mostLogged:
            return exercises.sorted {
                (exerciseHistory[$0.id]?.timesLogged ?? 0) >
                (exerciseHistory[$1.id]?.timesLogged ?? 0)
            }
        case .leastLogged:
            return exercises.sorted {
                (exerciseHistory[$0.id]?.timesLogged ?? 0) <
                (exerciseHistory[$1.id]?.timesLogged ?? 0)
            }
        case .neverLogged:
            return exercises.filter { exerciseHistory[$0.id] == nil }
        }
    }
    
    private func loadUserEquipment() async {
        // Load from UserDefaults or user profile
        // For now, use common equipment as default
        userEquipment = ["Dumbbell", "Barbell", "Cable", "Body weight", "Pull up Bar", "Flat Bench", "Incline Bench"]
    }
    
    private func loadExerciseHistory() async {
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        
        // For now, simulate with empty history
        // TODO: Integrate with ExerciseHistoryDataService
        exerciseHistory = [:]
    }
    
    private func replaceExercise(with newExercise: ExerciseData) {
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Preserve existing notes when replacing exercise
        let preservedNotes = currentExercise.notes
        
        // Update the current exercise with preserved notes
        currentExercise = TodayWorkoutExercise(
            exercise: newExercise,
            sets: currentExercise.sets,
            reps: currentExercise.reps,
            weight: currentExercise.weight,
            restTime: currentExercise.restTime,
            notes: preservedNotes
        )
        
        // Pass the new exercise back to parent view
        onExerciseReplaced?(newExercise)
        
        // Dismiss the sheet
        dismiss()
    }
}


// MARK: - Exercise Replacement Row

struct ExerciseReplacementRow: View {
    let exercise: ExerciseData
    let matchScore: Double
    let userHistory: ReplaceExerciseSheet.ExerciseHistoryInfo?
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Exercise thumbnail
                let thumbnailName = String(format: "%04d", exercise.id)
                if let image = UIImage(named: thumbnailName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "dumbbell")
                                .foregroundColor(.gray)
                                .font(.system(size: 20))
                        )
                }
                
                // Exercise name only
                Text(exercise.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
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
        ExerciseLoggingView(
            exercise: sampleTodayWorkoutExercise
        )
    }
}
