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
    
    let onSetForWorkout: ([String], MuscleSplitType) -> Void
    let onSetAsDefault: ([String], MuscleSplitType) -> Void
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

        var iconName: String {
            switch self {
            case .recoveredMuscles:
                return "bolt.heart"
            case .pushMuscles:
                return "arrow.up.right.circle.fill"
            case .pullMuscles:
                return "arrow.down.left.circle.fill"
            case .upperBody:
                return "figure.strengthtraining.traditional"
            case .lowerBody:
                return "figure.step.training"
            case .fullBody:
                return "figure.mixed.cardio"
            case .customMuscleGroup:
                return "slider.horizontal.3"
            }
        }

        var subtitle: String? {
            switch self {
            case .recoveredMuscles:
                return nil
            case .customMuscleGroup:
                return "Pick exact muscles"
            case .pushMuscles, .pullMuscles, .upperBody, .lowerBody, .fullBody:
                return nil
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
                            guard !selectedMuscles.isEmpty else { return }
                            self.onSetForWorkout(Array(selectedMuscles), .customMuscleGroup)
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
        .presentationDetents([.large])
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
                VStack(spacing: 24) {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(MuscleSplitType.allCases.filter { $0 != .customMuscleGroup }, id: \.self) { split in
                            MuscleSplitButton(
                                split: split,
                                isSelected: selectedSplit == split,
                                onTap: {
                                    HapticFeedback.generate()
                                    selectedSplit = split
                                    selectedMuscles = Set(split.muscleGroups)
                                }
                            )
                        }
                    }

                    customSelectionCard

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            actionButtons
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }

    private var customSelectionCard: some View {
        let isSelected = selectedSplit == .customMuscleGroup

        return Button(action: {
            HapticFeedback.generate()
            selectedSplit = .customMuscleGroup
            if selectedMuscles.isEmpty, let current = currentCustomMuscles {
                selectedMuscles = Set(current)
            }
            showingMuscleGroups = true
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: MuscleSplitType.customMuscleGroup.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Select Muscle Groups")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    if let subtitle = MuscleSplitType.customMuscleGroup.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("primarybg"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                isSelected ?
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.05)) : nil
            )
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 12)

            HStack(spacing: 0) {
                Button("Set as default") {
                    HapticFeedback.generate()
                    onSetAsDefault(Array(selectedMuscles), selectedSplit)
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(canSetDefault ? .primary : .primary.opacity(0.4))
                .disabled(!canSetDefault)

                Spacer(minLength: 12)

                Button("Set for workout") {
                    HapticFeedback.generate()
                    onSetForWorkout(Array(selectedMuscles), selectedSplit)
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.systemBackground))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(canSetForWorkout ? Color.primary : Color.gray.opacity(0.4))
                .cornerRadius(24)
                .disabled(!canSetForWorkout)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }

    private var canSetForWorkout: Bool {
        if selectedSplit == .customMuscleGroup {
            return !selectedMuscles.isEmpty
        }
        return true
    }

    private var canSetDefault: Bool {
        if selectedSplit == .customMuscleGroup {
            return !selectedMuscles.isEmpty
        }
        return true
    }
}

struct MuscleSplitButton: View {
    let split: TargetMusclesView.MuscleSplitType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: split.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Text(split.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                if let subtitle = split.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("primarybg"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.primary : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                isSelected ?
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.05)) : nil
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TargetMusclesView(
        onSetForWorkout: { muscles, split in
            print("Set for workout: \(muscles) - \(split.rawValue)")
        },
        onSetAsDefault: { muscles, split in
            print("Set default: \(muscles) - \(split.rawValue)")
        },
        currentCustomMuscles: ["Chest", "Triceps"],
        currentMuscleType: "Recovered Muscles"
    )
}
