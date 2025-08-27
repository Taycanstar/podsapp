//
//  DynamicRepRangeView.swift
//  pods
//
//  Created by Dimi Nunez on 8/26/25.
//

import SwiftUI

/// Simple UI component to display dynamic rep ranges instead of static numbers
struct DynamicRepRangeView: View {
    let dynamicExercise: DynamicWorkoutExercise
    let compact: Bool
    let fitnessGoal: FitnessGoal? // For contextual session phase names
    
    init(_ dynamicExercise: DynamicWorkoutExercise, compact: Bool = false, fitnessGoal: FitnessGoal? = nil) {
        self.dynamicExercise = dynamicExercise
        self.compact = compact
        self.fitnessGoal = fitnessGoal
    }
    
    private var contextualSessionPhaseName: String {
        if let goal = fitnessGoal {
            return dynamicExercise.sessionPhase.contextualDisplayName(for: goal)
        } else {
            return dynamicExercise.sessionPhase.displayName
        }
    }
    
    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }
    
    // MARK: - Compact View (for list items)
    
    private var compactView: some View {
        HStack(spacing: 4) {
            Text("\(dynamicExercise.setCount) ×")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            if dynamicExercise.repRange.lowerBound == dynamicExercise.repRange.upperBound {
                // Static reps (legacy compatibility)
                Text("\(dynamicExercise.repRange.upperBound)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            } else {
                // Dynamic rep range
                HStack(spacing: 2) {
                    Text("\(dynamicExercise.repRange.lowerBound)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(dynamicExercise.targetIntensity.color)
                    
                    Text("-")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(dynamicExercise.repRange.upperBound)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(dynamicExercise.targetIntensity.color)
                }
            }
            
            // Session phase indicator
            if !compact {
                sessionPhaseIndicator
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(dynamicExercise.targetIntensity.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Full View (for detailed display)
    
    private var fullView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Sets and reps display
            HStack {
                compactView
                Spacer()
                sessionPhaseIndicator
            }
            
            // Target suggestion (only show for ranges)
            if dynamicExercise.repRange.lowerBound != dynamicExercise.repRange.upperBound {
                Text("💡 \(dynamicExercise.targetRepSuggestion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Rest time
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Rest: \(dynamicExercise.restTime)s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Session Phase Indicator
    
    private var sessionPhaseIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: dynamicExercise.sessionPhase.iconName)
                .font(.caption2)
                .foregroundColor(dynamicExercise.sessionPhase.color)
            
            Text(contextualSessionPhaseName)
                .font(.caption2.weight(.medium))
                .foregroundColor(dynamicExercise.sessionPhase.color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(dynamicExercise.sessionPhase.color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Extensions for UI Colors & Icons

extension IntensityZone {
    var color: Color {
        switch self {
        case .strength: return .red
        case .hypertrophy: return .orange  
        case .endurance: return .blue
        }
    }
}

extension SessionPhase {
    var color: Color {
        switch self {
        case .strengthFocus: return .red
        case .volumeFocus: return .orange
        case .conditioningFocus: return .blue
        }
    }
    
    var iconName: String {
        switch self {
        case .strengthFocus: return "dumbbell.fill"
        case .volumeFocus: return "chart.bar.fill"
        case .conditioningFocus: return "heart.fill"
        }
    }
}

// MARK: - Legacy Compatibility

/// Extension to create dynamic view from static exercise (migration helper)
extension DynamicRepRangeView {
    init(staticExercise: TodayWorkoutExercise, sessionPhase: SessionPhase = .volumeFocus, compact: Bool = false) {
        let dynamicExercise = DynamicWorkoutExercise(
            exercise: staticExercise.exercise,
            setCount: staticExercise.sets,
            repRange: staticExercise.reps...staticExercise.reps, // Fixed range
            targetIntensity: .hypertrophy, // Default
            suggestedWeight: staticExercise.weight,
            restTime: staticExercise.restTime,
            sessionPhase: sessionPhase,
            notes: staticExercise.notes,
            warmupSets: staticExercise.warmupSets
        )
        
        self.init(dynamicExercise, compact: compact)
    }
}

// MARK: - Preview

struct DynamicRepRangeView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleExercise = ExerciseData(
            id: 1,
            name: "Bench Press",
            bodyPart: "chest",
            equipment: "barbell",
            target: "pectorals",
            category: "strength",
            exerciseType: "compound"
        )
        
        let dynamicExercise = DynamicWorkoutExercise(
            exercise: sampleExercise,
            setCount: 3,
            repRange: 8...12,
            targetIntensity: .hypertrophy,
            restTime: 90,
            sessionPhase: .volumeFocus
        )
        
        VStack(spacing: 16) {
            DynamicRepRangeView(dynamicExercise, compact: true)
            DynamicRepRangeView(dynamicExercise, compact: false)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}