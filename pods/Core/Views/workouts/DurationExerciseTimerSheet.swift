//
//  DurationExerciseTimerSheet.swift
//  pods
//
//  Created by Claude on 8/30/25.
//

import SwiftUI

/// Simplified timer sheet with direct duration initialization - no race conditions
struct DurationExerciseTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let exerciseName: String
    let duration: TimeInterval
    let onTimerComplete: () -> Void
    
    @State private var timeRemaining: TimeInterval
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var showingCompletionAnimation = false
    
    init(exerciseName: String, duration: TimeInterval, onTimerComplete: @escaping () -> Void) {
        self.exerciseName = exerciseName
        self.duration = duration
        self.onTimerComplete = onTimerComplete
        self._timeRemaining = State(initialValue: duration) // Initialize immediately - no 0:00
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with dismiss button and exercise name
                headerView
                
                // Main timer display area
                VStack(spacing: 12) {
                    // Clean, minimal countdown text - shows correct time immediately
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 48, weight: .bold, design: .default))
                        // .fontDesign(.monospaced)
                        .foregroundColor(.primary)
                        .scaleEffect(showingCompletionAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: showingCompletionAnimation)
                    
                
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 20)
                
                // Control buttons at bottom
                if timeRemaining > 0 {
                    HStack {
                        Spacer()
                        Button(action: toggleTimer) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                Image(systemName: isRunning ? "pause" : "play.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .background(Color(.systemBackground))
        }
        .presentationDetents([.medium])
  
        .onAppear {
            startTimer() // Start immediately with correct duration
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            // Dismiss button (X mark)
            Button(action: {
                stopTimer()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .padding(.leading, 20)
            
            Spacer()
            
            // Exercise name
            Text(exerciseName)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // Invisible spacer for symmetry
            Color.clear
                .frame(width: 24, height: 24)
                .padding(.trailing, 20)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Simple Timer Actions
    
    private func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                
                // Haptic feedback for final countdown
                if timeRemaining <= 10 && timeRemaining > 0 {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            } else {
                completeTimer()
            }
        }
    }
    
    private func toggleTimer() {
        isRunning.toggle()
        if isRunning {
            startTimer()
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        dismiss()
    }
    
    private func completeTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        
        // Success haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        // Show completion animation
        withAnimation(.easeInOut(duration: 0.3)) {
            showingCompletionAnimation = true
        }
        
        // Call completion handler and dismiss
        onTimerComplete()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }
}

#Preview("Timer Sheet") {
    VStack {
        Text("Background Content")
            .font(.title)
            .foregroundColor(.secondary)
        
        Spacer()
    }
    .sheet(isPresented: .constant(true)) {
        DurationExerciseTimerSheet(
            exerciseName: "Plank Hold",
            duration: 90, // 1:30
            onTimerComplete: {
                print("Timer completed!")
            }
        )
    }
}
