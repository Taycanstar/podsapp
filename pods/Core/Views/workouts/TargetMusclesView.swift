//
//  TargetMusclesView.swift
//  pods
//
//  Created by Dimi Nunez on 7/18/25.
//

import SwiftUI

struct TargetMusclesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSplit: MuscleSplitType = .recoveredMuscles
    @State private var showingMuscleGroups = false
    @State private var selectedMuscles: Set<String> = []
    
    let onSelectionChanged: ([String], String) -> Void // Updated to include muscle type
    let currentCustomMuscles: [String]? // Current custom muscle selection
    let currentMuscleType: String // Current muscle type
    
    enum MuscleSplitType: String, CaseIterable {
        case recoveredMuscles = "Recovered Muscles"
        case pushMuscles = "Push Muscles"
        case pullMuscles = "Pull Muscles"
        case upperBody = "Upper Body"
        case lowerBody = "Lower Body"
        case fullBody = "Full Body"
        case customMuscleGroup = "Custom Muscle Group"
        
        var muscleGroups: [String] {
            switch self {
            case .recoveredMuscles:
                // Get dynamically from recovery service
                return MuscleRecoveryService.shared.getRecoveryBasedWorkoutRecommendation()
            case .pushMuscles:
                return ["Chest", "Shoulders", "Triceps"]
            case .pullMuscles:
                return ["Back", "Biceps"]
            case .upperBody:
                return ["Chest", "Back", "Shoulders", "Biceps", "Triceps"]
            case .lowerBody:
                return ["Quadriceps", "Hamstrings", "Glutes", "Calves"]
            case .fullBody:
                return ["Chest", "Back", "Shoulders", "Quadriceps", "Hamstrings", "Glutes"]
            case .customMuscleGroup:
                // Custom muscles are handled separately - return empty array here
                return []
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showingMuscleGroups {
                    // Show MuscleGroupsView
                    // HStack {
                    //     Spacer()
                        
                    //     Button(action: {
                    //         HapticFeedback.generate()
                    //         dismiss()
                    //     }) {
                    //         Image(systemName: "xmark")
                    //             .font(.system(size: 16, weight: .medium))
                    //             .foregroundColor(.primary)
                    //             .frame(width: 30, height: 30)
                    //     }
                    // }
                    // .padding(.horizontal)
                    // // .padding(.top, 16)
                    // // .padding(.bottom, 16)
                    
                    // Text("Muscle Groups")
                    //     .font(.title2)
                    //     .fontWeight(.semibold)
                    //     .frame(maxWidth: .infinity, alignment: .leading)
                    //     .padding(.horizontal)
                    //     .padding(.bottom, 22)
                    
                    MuscleGroupsView(
                        selectedMuscles: $selectedMuscles,
                        onBack: {
                            showingMuscleGroups = false
                        },
                        onSetForWorkout: {
                            onSelectionChanged(Array(selectedMuscles), selectedSplit.rawValue)
                            dismiss()
                        }
                    )
                } else {
                    // Show muscle splits selection
                    muscleSplitsView
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            // Determine current selection based on current muscle type
            if let splitType = MuscleSplitType(rawValue: currentMuscleType) {
                selectedSplit = splitType
                if splitType == .customMuscleGroup, let customMuscles = currentCustomMuscles {
                    // Restore custom muscle selection
                    selectedMuscles = Set(customMuscles)
                } else {
                    // Use predefined split muscles
                    selectedMuscles = Set(selectedSplit.muscleGroups)
                }
            } else {
                // Fallback to recovered muscles
                selectedSplit = .recoveredMuscles
                selectedMuscles = Set(selectedSplit.muscleGroups)
            }
        }
    }
    
    private var muscleSplitsView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()

                Button(action: {
                    HapticFeedback.generate()
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Text("Muscle Splits")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        MuscleSplitButton(
                            split: .recoveredMuscles,
                            isSelected: selectedSplit == .recoveredMuscles,
                            onTap: {
                                HapticFeedback.generate()
                                selectedSplit = .recoveredMuscles
                                selectedMuscles = Set(selectedSplit.muscleGroups)
                            }
                        )
                        
                        MuscleSplitButton(
                            split: .pushMuscles,
                            isSelected: selectedSplit == .pushMuscles,
                            onTap: {
                                HapticFeedback.generate()
                                selectedSplit = .pushMuscles
                                selectedMuscles = Set(selectedSplit.muscleGroups)
                            }
                        )
                        
                        MuscleSplitButton(
                            split: .pullMuscles,
                            isSelected: selectedSplit == .pullMuscles,
                            onTap: {
                                HapticFeedback.generate()
                                selectedSplit = .pullMuscles
                                selectedMuscles = Set(selectedSplit.muscleGroups)
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Second Row
                    HStack(spacing: 12) {
                        MuscleSplitButton(
                            split: .upperBody,
                            isSelected: selectedSplit == .upperBody,
                            onTap: {
                                HapticFeedback.generate()
                                selectedSplit = .upperBody
                                selectedMuscles = Set(selectedSplit.muscleGroups)
                            }
                        )
                        
                        MuscleSplitButton(
                            split: .lowerBody,
                            isSelected: selectedSplit == .lowerBody,
                            onTap: {
                                HapticFeedback.generate()
                                selectedSplit = .lowerBody
                                selectedMuscles = Set(selectedSplit.muscleGroups)
                            }
                        )
                        
                        MuscleSplitButton(
                            split: .fullBody,
                            isSelected: selectedSplit == .fullBody,
                            onTap: {
                                HapticFeedback.generate()
                                selectedSplit = .fullBody
                                selectedMuscles = Set(selectedSplit.muscleGroups)
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Select Muscle Groups Navigation
                    Button(action: {
                        HapticFeedback.generate()
                        selectedSplit = .customMuscleGroup
                        showingMuscleGroups = true
                    }) {
                        HStack {
                            Text("Select Muscle Groups")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Spacer(minLength: 80)
                }
                .padding(.top, 20)
            }
            
            // Set for Workout Button
            VStack(spacing: 16) {
                Button(action: {
                    HapticFeedback.generate()
                    onSelectionChanged(Array(selectedMuscles), selectedSplit.rawValue)
                    dismiss()
                }) {
                    Text("Set for workout")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primary)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
}

struct MuscleSplitButton: View {
    let split: TargetMusclesView.MuscleSplitType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(split.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
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
    TargetMusclesView(
        onSelectionChanged: { muscles, type in
            print("Selected muscles: \(muscles), type: \(type)")
        },
        currentCustomMuscles: nil,
        currentMuscleType: "Recovered Muscles"
    )
}

