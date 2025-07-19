//
//  MuscleGroupsView.swift
//  pods
//
//  Created by Dimi Nunez on 7/18/25.
//

import SwiftUI

struct MuscleGroupsView: View {
    @Binding var selectedMuscles: Set<String>
    let onBack: () -> Void
    let onSetForWorkout: () -> Void
    
    @State private var recoveryData: [MuscleRecoveryService.MuscleRecoveryData] = []
    
    // All available muscle groups
    private let allMuscleGroups = [
        "Abs", "Back", "Biceps", "Chest",
        "Glutes", "Hamstrings", "Quadriceps", "Shoulders",
        "Triceps", "Lower Back", "Calves", "Trapezius",
        "Abductors", "Adductors", "Forearms", "Neck"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    HapticFeedback.generate()
                    onBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Muscle Groups")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible button for balance
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                }
                .opacity(0)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Muscle groups grid - 3 per row
                    let rows = allMuscleGroups.chunked(into: 3)
                    
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { muscle in
                                MuscleGroupButton(
                                    muscleName: muscle,
                                    recoveryPercentage: getRecoveryPercentage(for: muscle),
                                    isSelected: selectedMuscles.contains(muscle),
                                    onTap: {
                                        HapticFeedback.generate()
                                        if selectedMuscles.contains(muscle) {
                                            selectedMuscles.remove(muscle)
                                        } else {
                                            selectedMuscles.insert(muscle)
                                        }
                                    }
                                )
                            }
                            
                            // Add empty spacers if row has fewer than 3 items
                            ForEach(0..<(3 - row.count), id: \.self) { _ in
                                Spacer()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            
            // Set for Workout Button
            VStack(spacing: 16) {
                Button(action: {
                    HapticFeedback.generate()
                    onSetForWorkout()
                }) {
                    Text("Set for workout")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedMuscles.isEmpty ? Color.gray : Color.primary)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(selectedMuscles.isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            loadRecoveryData()
        }
    }
    
    private func loadRecoveryData() {
        recoveryData = MuscleRecoveryService.shared.getMuscleRecoveryData()
    }
    
    private func getRecoveryPercentage(for muscleName: String) -> Double {
        if let data = recoveryData.first(where: { $0.muscleGroup.rawValue == muscleName }) {
            return data.recoveryPercentage
        }
        return 100.0 // Default to fully recovered if no data
    }
}

struct MuscleGroupButton: View {
    let muscleName: String
    let recoveryPercentage: Double
    let isSelected: Bool
    let onTap: () -> Void
    
    private var recoveryColor: Color {
        switch recoveryPercentage {
        case 0..<60:
            return .red
        case 60..<85:
            return .orange
        case 85..<100:
            return .yellow
        default:
            return .green
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Muscle name at top
                
                
                // HStack with label and progress circle
                HStack {
                    Text(muscleName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Recovery progress circle
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        
                        Circle()
                            .trim(from: 0, to: recoveryPercentage / 100.0)
                            .stroke(recoveryColor, lineWidth: 2)
                            .frame(width: 20, height: 20)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: recoveryPercentage)
                    }
                }
                
                // Percentage below, left-aligned
                Text("\(Int(recoveryPercentage))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(recoveryColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                isSelected ? 
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05)) : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}



#Preview {
    MuscleGroupsView(
        selectedMuscles: .constant(["Chest", "Triceps"]),
        onBack: { print("Back tapped") },
        onSetForWorkout: { print("Set for workout tapped") }
    )
}
