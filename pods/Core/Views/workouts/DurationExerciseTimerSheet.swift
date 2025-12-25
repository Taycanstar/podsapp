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
        self._timeRemaining = State(initialValue: duration) // Initialize immediately
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button {
                    stopTimer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            .padding(.horizontal, 12)
            
            HStack(alignment: .center, spacing: 16) {
                Text(formatTime(timeRemaining))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .scaleEffect(showingCompletionAnimation ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: showingCompletionAnimation)
                    .minimumScaleFactor(0.6)

                Spacer()

                Button(action: toggleTimer) {
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 60, height: 60)
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .presentationDetents([.height(170)])
        .presentationDragIndicator(.visible)
        .onAppear {
            startTimer()
        }
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
