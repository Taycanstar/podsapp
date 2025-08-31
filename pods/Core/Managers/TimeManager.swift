
import Foundation
import SwiftUI

/// Manages timer state for duration-based workout exercises
/// Handles countdown timing, state management, and completion callbacks
class TimerManager: ObservableObject {
    @Published var timeRemaining: TimeInterval = 0
    @Published var totalTime: TimeInterval = 0
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var isCompleted = false
    
    private var timer: Timer?
    private var completionHandler: (() -> Void)?
    
    enum TimerState {
        case idle
        case running
        case paused
        case completed
        case cancelled
    }
    
    var state: TimerState {
        if isCompleted { return .completed }
        if isRunning && !isPaused { return .running }
        if isPaused { return .paused }
        return .idle
    }
    
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return (totalTime - timeRemaining) / totalTime
    }
    
    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        
        if totalTime >= 3600 { // Show hours for long durations
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var isFinalCountdown: Bool {
        return timeRemaining <= 10 && timeRemaining > 0
    }
    
    // MARK: - Timer Control
    
    func startTimer(duration: TimeInterval, completion: @escaping () -> Void) {
        // Stop any existing timer first
        timer?.invalidate()
        timer = nil
        
        // Set all properties at once to avoid showing 0:00 flash
        totalTime = duration
        timeRemaining = duration
        isRunning = false
        isPaused = false
        isCompleted = false
        completionHandler = completion
        
        resumeTimer()
    }
    
    func pauseTimer() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }
    
    func resumeTimer() {
        guard timeRemaining > 0 else { return }
        
        isPaused = false
        isRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        // Don't call completion handler when manually stopped
    }
    
    func reset() {
        timer?.invalidate()
        timer = nil
        timeRemaining = 0
        totalTime = 0
        isRunning = false
        isPaused = false
        isCompleted = false
        completionHandler = nil
    }
    
    // MARK: - Private Methods
    
    private func tick() {
        guard timeRemaining > 0 else {
            completeTimer()
            return
        }
        
        timeRemaining -= 1
        
        // Haptic feedback for final countdown
        if isFinalCountdown {
            triggerHapticFeedback(.light)
        } else if Int(timeRemaining) % 30 == 0 && timeRemaining > 10 {
            // Every 30 seconds except final countdown
            triggerHapticFeedback(.light)
        }
    }
    
    private func completeTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        isCompleted = true
        
        // Success haptic feedback
        triggerHapticFeedback(.success)
        
        // Call completion handler after brief delay for animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.completionHandler?()
        }
    }
    
    private func triggerHapticFeedback(_ type: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: type)
        impactFeedback.impactOccurred()
    }
    
    private func triggerHapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(type)
    }
    
    deinit {
        timer?.invalidate()
    }
}