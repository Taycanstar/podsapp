//
//  SimpleDurationPicker.swift
//  pods
//
//  Created by Claude on 8/31/25.
//

import SwiftUI

/// Simple duration picker with direct binding - replaces complex FlexibleExerciseInputs
struct SimpleDurationPicker: View {
    @Binding var duration: TimeInterval
    @State private var showingPicker = false
    
    var body: some View {
        VStack {
            // Duration display button
            Button(action: { showingPicker.toggle() }) {
                Text(formatTime(duration))
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1))
            }
            
            // Inline time picker
            if showingPicker {
                HStack {
                    Picker("Minutes", selection: Binding(
                        get: { Int(duration / 60) },
                        set: { 
                            let newMinutes = $0
                            let currentSeconds = Int(duration.truncatingRemainder(dividingBy: 60))
                            duration = TimeInterval(newMinutes * 60 + currentSeconds)
                        }
                    )) {
                        ForEach(0...60, id: \.self) { minute in
                            Text("\(minute) min").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    
                    Picker("Seconds", selection: Binding(
                        get: { Int(duration.truncatingRemainder(dividingBy: 60)) },
                        set: { 
                            let newSeconds = $0
                            let currentMinutes = Int(duration / 60)
                            duration = TimeInterval(currentMinutes * 60 + newSeconds)
                        }
                    )) {
                        ForEach(0...59, id: \.self) { second in
                            Text("\(second) sec").tag(second)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 120)
            }
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }
}

#Preview {
    VStack(spacing: 20) {
        SimpleDurationPicker(duration: .constant(90)) // 1:30
        SimpleDurationPicker(duration: .constant(300)) // 5:00
    }
    .padding()
}