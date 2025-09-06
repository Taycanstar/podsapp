//
//  OptimisticExerciseCard.swift
//  pods
//
//  Created by Performance Architect on 8/26/25.
//

import SwiftUI

/// High-performance exercise card with optimistic UI updates
/// Implements instant feel through progressive enhancement and smart caching
struct OptimisticExerciseCard: View {
    let exercise: TodayWorkoutExercise
    let sessionPhase: SessionPhase?
    let fitnessGoal: FitnessGoal
    
    @State private var displayState = DisplayState.loading
    @State private var cachedRepRange: String?
    @State private var dynamicRepRange: ClosedRange<Int>?
    @State private var animationID = UUID()
    @EnvironmentObject var onboarding: OnboardingViewModel
    
    // MARK: - Services
    private let cacheService = RepRangeCacheService.shared
    private let performanceMonitor = PerformanceMonitoringService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Exercise thumbnail
            AsyncImage(url: exerciseThumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        if displayState == .loading {
                            ShimmerView()
                        }
                    }
            }
            .frame(width: 60, height: 60)
            .clipped()
            .cornerRadius(8)
            
            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                // Exercise name
                Text(exercise.exercise.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Dynamic rep range display
                repRangeView
                    .id(animationID)
                
                // Sets and weight info
                HStack(spacing: 16) {
                    Label("\(exercise.sets) sets", systemImage: "repeat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let weight = exercise.weight {
                        let unit = onboarding.unitsSystem == .imperial ? "lbs" : "kg"
                        Label("\(Int(weight)) \(unit)", systemImage: "scalemass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Session phase indicator (if dynamic)
            if let phase = sessionPhase {
                sessionPhaseIndicator(phase)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadRepRangeOptimistically()
        }
        .onChange(of: sessionPhase) { _, _ in
            refreshRepRange()
        }
    }
    
    // MARK: - Rep Range Display
    
    @ViewBuilder
    private var repRangeView: some View {
        switch displayState {
        case .loading:
            // Show shimmer while loading
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 20)
                .overlay {
                    ShimmerView()
                }
            
        case .cached(let range):
            // Show cached data immediately
            Text(range)
                .font(.subheadline)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.1))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            
        case .dynamic(let range, let isNew):
            // Show dynamic range with animation if updated
            Text(range)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                        )
                )
                .scaleEffect(isNew ? 1.05 : 1.0)
                .animation(.bouncy(duration: 0.3), value: isNew)
                .transition(.opacity.combined(with: .scale(scale: 1.1)))
        }
    }
    
    // MARK: - Session Phase Indicator
    
    @ViewBuilder
    private func sessionPhaseIndicator(_ phase: SessionPhase) -> some View {
        VStack(spacing: 2) {
            Text(phase.emoji)
                .font(.title2)
            
            Text(phase.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        )
    }
    
    // MARK: - Optimistic Loading Logic
    
    private func loadRepRangeOptimistically() {
        Task {
            // Step 1: Try to show cached data immediately
            await showCachedDataIfAvailable()
            
            // Step 2: Load fresh data in background
            await loadFreshDynamicData()
        }
    }
    
    private func showCachedDataIfAvailable() async {
        // Check if we have any cached representation
        if let cached = cachedRepRange {
            await MainActor.run {
                displayState = .cached(cached)
            }
            return
        }
        
        // Try to get from cache service
        let recoveryStatus = RecoveryStatus.moderate // Default assumption
        
        if let cachedRange = try? await cacheService.getRepRange(
            for: exercise.exercise,
            fitnessGoal: fitnessGoal,
            sessionPhase: sessionPhase ?? .volumeFocus,
            recoveryStatus: recoveryStatus
        ) {
            let rangeText = formatRepRange(cachedRange)
            await MainActor.run {
                cachedRepRange = rangeText
                displayState = .cached(rangeText)
            }
        }
    }
    
    private func loadFreshDynamicData() async {
        // Generate fresh dynamic data
        guard let phase = sessionPhase else { return }
        
        do {
            let freshRange = await performanceMonitor.timeRepRangeCalculation {
                try await cacheService.getRepRange(
                    for: exercise.exercise,
                    fitnessGoal: fitnessGoal,
                    sessionPhase: phase,
                    recoveryStatus: .moderate
                )
            }
            
            let rangeText = formatRepRange(freshRange)
            let isNewData = rangeText != cachedRepRange
            
            await MainActor.run {
                withAnimation(.smooth(duration: 0.3)) {
                    displayState = .dynamic(rangeText, isNew: isNewData)
                    dynamicRepRange = freshRange
                    
                    if isNewData {
                        // Trigger bounce animation
                        animationID = UUID()
                        
                        // Reset bounce after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if case .dynamic(let range, _) = displayState {
                                displayState = .dynamic(range, isNew: false)
                            }
                        }
                    }
                }
            }
            
        } catch {
            print("⚠️ Failed to load dynamic rep range: \(error)")
            // Keep showing cached data on error
        }
    }
    
    private func refreshRepRange() {
        // Animate transition and reload
        withAnimation(.easeInOut(duration: 0.2)) {
            displayState = .loading
            animationID = UUID()
        }
        
        // Small delay to show loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            loadRepRangeOptimistically()
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatRepRange(_ range: ClosedRange<Int>) -> String {
        if range.lowerBound == range.upperBound {
            return "\(range.lowerBound) reps"
        } else {
            return "\(range.lowerBound)-\(range.upperBound) reps"
        }
    }
    
    private var exerciseThumbnailURL: URL? {
        let videoId = String(format: "%04d", exercise.exercise.id)
        return URL(string: "https://humulistoragecentral.blob.core.windows.net/videos/thumbnails/\(videoId).jpg")
    }
    
    // MARK: - Display State
    
    enum DisplayState {
        case loading
        case cached(String)
        case dynamic(String, isNew: Bool)
    }
}

// MARK: - Shimmer Effect

/// Smooth shimmer loading effect for better perceived performance
struct ShimmerView: View {
    @State private var isAnimating = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.clear, location: 0.0),
                .init(color: Color.white.opacity(0.3), location: 0.5),
                .init(color: Color.clear, location: 1.0)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .rotationEffect(.degrees(30))
        .offset(x: isAnimating ? 300 : -300)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
        .clipped()
    }
}

// MARK: - Progressive Enhancement Wrapper

/// Wrapper that progressively enhances static exercise cards with dynamic features
struct ProgressiveExerciseCard: View {
    let exercise: TodayWorkoutExercise
    let sessionPhase: SessionPhase?
    let fitnessGoal: FitnessGoal
    
    @State private var useOptimizedVersion = false
    
    var body: some View {
        Group {
            if useOptimizedVersion && sessionPhase != nil {
                OptimisticExerciseCard(
                    exercise: exercise,
                    sessionPhase: sessionPhase,
                    fitnessGoal: fitnessGoal
                )
            } else {
                // Fallback to static display
                StaticExerciseCard(exercise: exercise)
            }
        }
        .onAppear {
            // Check if dynamic programming is available
            checkForOptimizedVersion()
        }
    }
    
    private func checkForOptimizedVersion() {
        // Enable optimized version after small delay for smoother transitions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                useOptimizedVersion = true
            }
        }
    }
}

// MARK: - Static Exercise Card (Fallback)

/// Simple static exercise card for fallback scenarios
struct StaticExerciseCard: View {
    let exercise: TodayWorkoutExercise
    @EnvironmentObject var onboarding: OnboardingViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Exercise thumbnail
            AsyncImage(url: exerciseThumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 60, height: 60)
            .clipped()
            .cornerRadius(8)
            
            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exercise.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Static rep display
                Text("\(exercise.reps) reps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Label("\(exercise.sets) sets", systemImage: "repeat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let weight = exercise.weight {
                        let unit = onboarding.unitsSystem == .imperial ? "lbs" : "kg"
                        Label("\(Int(weight)) \(unit)", systemImage: "scalemass")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var exerciseThumbnailURL: URL? {
        let videoId = String(format: "%04d", exercise.exercise.id)
        return URL(string: "https://humulistoragecentral.blob.core.windows.net/videos/thumbnails/\(videoId).jpg")
    }
}

// MARK: - Performance-Optimized List

/// Performance-optimized list for displaying multiple exercise cards
struct OptimizedExerciseList: View {
    let exercises: [TodayWorkoutExercise]
    let sessionPhase: SessionPhase?
    let fitnessGoal: FitnessGoal
    
    @State private var visibleRange = 0..<5 // Initially load first 5 items
    
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(exercises.enumerated()), id: \.element.exercise.id) { index, exercise in
                if visibleRange.contains(index) {
                    ProgressiveExerciseCard(
                        exercise: exercise,
                        sessionPhase: sessionPhase,
                        fitnessGoal: fitnessGoal
                    )
                    .onAppear {
                        expandVisibleRange(around: index)
                    }
                } else {
                    // Placeholder for off-screen items
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 76)
                        .onAppear {
                            expandVisibleRange(around: index)
                        }
                }
            }
        }
    }
    
    private func expandVisibleRange(around index: Int) {
        let bufferSize = 3
        let newStart = max(0, index - bufferSize)
        let newEnd = min(exercises.count, index + bufferSize + 1)
        
        let newRange = newStart..<newEnd
        if newRange != visibleRange {
            withAnimation(.easeInOut(duration: 0.2)) {
                visibleRange = newRange
            }
        }
    }
}

#Preview("Optimistic Exercise Card") {
    let sampleExercise = TodayWorkoutExercise(
        exercise: ExerciseData(
            id: 1,
            name: "Barbell Bench Press",
            target: "chest",
            equipment: "barbell",
            category: "strength",
            instructions: "Lie on bench and press barbell upward"
        ),
        sets: 3,
        reps: 8,
        weight: 185.0,
        restTime: 120
    )
    
    VStack(spacing: 20) {
        OptimisticExerciseCard(
            exercise: sampleExercise,
            sessionPhase: .strengthFocus,
            fitnessGoal: .strength
        )
        
        ProgressiveExerciseCard(
            exercise: sampleExercise,
            sessionPhase: .volumeFocus,
            fitnessGoal: .hypertrophy
        )
        
        StaticExerciseCard(exercise: sampleExercise)
    }
    .padding()
}
