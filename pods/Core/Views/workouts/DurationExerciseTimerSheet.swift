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
                    HStack(alignment: .center, spacing: 16) {
                        Text(formatTime(timeRemaining))
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .scaleEffect(showingCompletionAnimation ? 1.08 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: showingCompletionAnimation)
                            .minimumScaleFactor(0.6)

                        Spacer()

                        Button(action: toggleTimer) {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .shadow(color: .orange.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal, 16)
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 12)

            }
            .background(Color(.systemBackground))
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
  
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
