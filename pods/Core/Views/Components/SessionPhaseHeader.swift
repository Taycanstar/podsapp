//
//  SessionPhaseHeader.swift
//  pods
//
//  Created by Claude on 8/26/25.
//

import SwiftUI

struct SessionPhaseHeader: View {
    let sessionPhase: SessionPhase
    let workoutCount: Int // Number in current phase cycle
    let fitnessGoal: FitnessGoal? // For contextual display names
    
    private var contextualDisplayName: String {
        if let goal = fitnessGoal {
            return sessionPhase.contextualDisplayName(for: goal)
        } else {
            return sessionPhase.displayName
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Phase icon and name
            HStack(spacing: 8) {
                Image(systemName: sessionPhase.iconName)
                    .font(.title2)
                    .foregroundColor(sessionPhase.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contextualDisplayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(sessionPhase.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Phase indicator dots
            PhaseProgressDots(currentPhase: sessionPhase, workoutCount: workoutCount)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(sessionPhase.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(sessionPhase.color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct PhaseProgressDots: View {
    let currentPhase: SessionPhase
    let workoutCount: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(SessionPhase.allCases, id: \.self) { phase in
                Circle()
                    .fill(phase == currentPhase ? phase.color : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentPhase)
            }
        }
    }
}

// MARK: - SessionPhase Extensions

extension SessionPhase {
    var iconName: String {
        switch self {
        case .strengthFocus:
            return "dumbbell.fill"
        case .volumeFocus:
            return "chart.bar.fill"
        case .conditioningFocus:
            return "figure.run"
        }
    }
    
    var color: Color {
        switch self {
        case .strengthFocus:
            return .red
        case .volumeFocus:
            return .blue
        case .conditioningFocus:
            return .green
        }
    }
    
    var description: String {
        switch self {
        case .strengthFocus:
            return "Building maximal strength"
        case .volumeFocus:
            return "Increasing muscle size"
        case .conditioningFocus:
            return "Improving endurance"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SessionPhaseHeader(sessionPhase: .strengthFocus, workoutCount: 1, fitnessGoal: .strength)
        SessionPhaseHeader(sessionPhase: .volumeFocus, workoutCount: 2, fitnessGoal: .hypertrophy)
        SessionPhaseHeader(sessionPhase: .conditioningFocus, workoutCount: 3, fitnessGoal: .tone)
    }
    .padding()
}