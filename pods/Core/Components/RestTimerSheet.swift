//
//  RestTimerSheet.swift
//  pods
//
//  Created by Codex on 2025-09-06.
//

import SwiftUI

/// Rest timer sheet with quick adjust buttons (-10 / +10 seconds)
struct RestTimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseName: String
    let duration: TimeInterval

    @State private var timeRemaining: TimeInterval
    @State private var timer: Timer?
    @State private var isRunning = false

    init(exerciseName: String, duration: TimeInterval) {
        self.exerciseName = exerciseName
        self.duration = duration
        self._timeRemaining = State(initialValue: duration)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView

                VStack(spacing: 16) {
                    HStack(spacing: 0) {
                        adjustButton(label: "−10", color: .gray.opacity(0.15)) {
                            adjust(by: -10)
                        }
                        Spacer(minLength: 24)
                        Text(formatTime(timeRemaining))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(minWidth: 140) // keep center width stable
                        Spacer(minLength: 24)
                        adjustButton(label: "+10", color: Color.accentColor.opacity(0.15)) {
                            adjust(by: 10)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 20)

                if timeRemaining > 0 {
                    HStack(spacing: 0) {
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
        .presentationDetents([.fraction(0.25)])
        .presentationDragIndicator(.visible)
        .onAppear { startTimer() }
    }

    private func adjustButton(label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 56, height: 56)
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var headerView: some View {
        HStack {
            Button(action: { stopTimer() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .padding(.leading, 20)

            Spacer()

            Text("Rest: \(exerciseName)")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Color.clear
                .frame(width: 24, height: 24)
                .padding(.trailing, 20)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private func startTimer() {
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
                if timeRemaining <= 10 && timeRemaining > 0 {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            } else {
                completeTimer()
            }
        }
    }

    private func toggleTimer() {
        isRunning.toggle()
        if isRunning { startTimer() } else { timer?.invalidate(); timer = nil }
    }

    private func stopTimer() {
        timer?.invalidate(); timer = nil; dismiss()
    }

    private func completeTimer() {
        timer?.invalidate(); timer = nil; isRunning = false
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        dismiss()
    }

    private func adjust(by delta: Int) {
        let newValue = max(0, Int(timeRemaining) + delta)
        timeRemaining = TimeInterval(newValue)
        if newValue == 0 { completeTimer() }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }
}
