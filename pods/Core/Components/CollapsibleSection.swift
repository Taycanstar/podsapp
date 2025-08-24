//
//  CollapsibleSection.swift
//  Pods
//
//  Created by Claude on 8/24/25.
//

import SwiftUI

struct CollapsibleSection: View {
    let title: String
    let exercises: [TodayWorkoutExercise]
    @Binding var isExpanded: Bool
    let accentColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    // Section title with icon
                    HStack(spacing: 8) {
                        Image(systemName: iconName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(accentColor)
                        
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Exercise count badge
                    Text("\(exercises.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(accentColor)
                        .clipShape(Circle())
                    
                    // Expand/collapse chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(accentColor.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Collapsible content
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(Array(exercises.enumerated()), id: \.element.exercise.id) { index, exercise in
                        FlexibilityExerciseCard(
                            exercise: exercise,
                            accentColor: accentColor,
                            index: index
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
    
    private var iconName: String {
        switch title.lowercased() {
        case "warm-up":
            return "thermometer.sun"
        case "cool-down":
            return "moon.zzz"
        default:
            return "figure.flexibility"
        }
    }
}

struct FlexibilityExerciseCard: View {
    let exercise: TodayWorkoutExercise
    let accentColor: Color
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Exercise thumbnail
            AsyncImage(url: URL(string: getThumbnailURL(for: exercise.exercise.id))) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "figure.flexibility")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
            
            // Exercise details
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exercise.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    // Sets and reps or duration info
                    if exercise.reps > 1 {
                        Text("\(exercise.sets)×\(exercise.reps)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } else {
                        Text(exercise.notes ?? "Hold 20-30s")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Rest time
                    Text("\(exercise.restTime)s rest")
                        .font(.system(size: 13))
                        .foregroundColor(accentColor)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func getThumbnailURL(for exerciseId: Int) -> String {
        return "https://humulistoragecentral.blob.core.windows.net/exercise-thumbnails/\(String(format: "%04d", exerciseId)).jpg"
    }
}

#Preview {
    @State var isExpanded = true
    
    let sampleExercises = [
        TodayWorkoutExercise(
            exercise: ExerciseData(
                id: 1,
                name: "Dynamic Chest Stretch",
                exerciseType: "Stretching",
                bodyPart: "Chest",
                equipment: "Body weight",
                gender: "Male",
                target: "Pectoralis",
                synergist: "Shoulders"
            ),
            sets: 1,
            reps: 10,
            weight: nil,
            restTime: 30,
            notes: "Warm-up exercise"
        ),
        TodayWorkoutExercise(
            exercise: ExerciseData(
                id: 2,
                name: "Arm Circles",
                exerciseType: "Stretching",
                bodyPart: "Shoulders",
                equipment: "Body weight",
                gender: "Male",
                target: "Deltoids",
                synergist: "Rotator Cuff"
            ),
            sets: 1,
            reps: 15,
            weight: nil,
            restTime: 15,
            notes: "Dynamic movement"
        )
    ]
    
    return VStack {
        CollapsibleSection(
            title: "Warm-Up",
            exercises: sampleExercises,
            isExpanded: $isExpanded,
            accentColor: .orange
        )
        .padding()
        Spacer()
    }
}