//
//  EquipmentView.swift
//  pods
//
//  Created by Dimi Nunez on 7/19/25.
//

import SwiftUI

struct EquipmentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEquipmentType: EquipmentType = EquipmentType.getDefaultFromWorkoutLocation()
    @State private var selectedEquipment: Set<Equipment> = []
    
    let onSelectionChanged: ([Equipment], String) -> Void
    
    enum EquipmentType: String, CaseIterable {
        case largeGym = "Large Gym"
        case smallGym = "Small Gym"
        case garageGym = "Garage Gym"
        case atHome = "At Home"
        case bodyweightOnly = "Bodyweight Only"
        case custom = "Custom"
        
        var equipmentList: [Equipment] {
            switch self {
            case .largeGym:
                return [
                    .dumbbells, .barbells, .cable, .smithMachine, .hammerstrengthMachine,
                    .kettlebells, .ezBar, .flatBench, .inclineBench, .declineBench,
                    .latPulldownCable, .legPress, .legExtensionMachine, .legCurlMachine,
                    .calfRaiseMachine, .rowMachine, .pullupBar, .dipBar, .squatRack,
                    .hackSquatMachine, .shoulderPressMachine, .tricepsExtensionMachine,
                    .bicepsCurlMachine, .abCrunchMachine, .preacherCurlBench, .resistanceBands,
                    .stabilityBall, .medicineBalls, .battleRopes, .box, .platforms, .pvc,
                    .bosuBalanceTrainer, .sled, .preacherCurlMachine, .rings, .suspensionTrainer
                ]
            case .smallGym:
                return [
                    .dumbbells, .barbells, .flatBench, .inclineBench, .pullupBar,
                    .cable, .legPress, .squatRack, .resistanceBands,
                    .stabilityBall, .medicineBalls, .kettlebells, .ezBar, .pvc,
                    .bosuBalanceTrainer, .smithMachine, .latPulldownCable, 
                    .legExtensionMachine, .legCurlMachine
                ]
            case .garageGym:
                return [
                    .dumbbells, .barbells, .squatRack, .flatBench, .inclineBench,
                    .pullupBar, .dipBar, .kettlebells, .resistanceBands, .box,
                    .medicineBalls, .ezBar, .pvc, .rings, .suspensionTrainer
                ]
            case .atHome:
                return [
                    .dumbbells, .resistanceBands, .stabilityBall, .medicineBalls,
                    .pullupBar, .flatBench, .kettlebells, .box, .pvc, .suspensionTrainer
                ]
            case .bodyweightOnly:
                return [
                    .bodyWeight, .pullupBar, .dipBar, .box, .resistanceBands, .pvc
                ]
            case .custom:
                return []
            }
        }
        
        static func getDefaultFromWorkoutLocation() -> EquipmentType {
            let userProfile = UserProfileService.shared
            let workoutLocation = userProfile.workoutLocationDisplay
            
            switch workoutLocation {
            case "Large Gym":
                return .largeGym
            case "Small Gym":
                return .smallGym
            case "Garage Gym":
                return .garageGym
            case "At Home":
                return .atHome
            case "Bodyweight Only":
                return .bodyweightOnly
            default:
                return .largeGym
            }
        }
    }
    
    var body: some View {
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
            
            Text("Equipment")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 16)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Equipment type options - First Row
                    HStack(spacing: 12) {
                        EquipmentTypeButton(
                            type: .largeGym,
                            isSelected: selectedEquipmentType == .largeGym,
                            onTap: {
                                HapticFeedback.generate()
                                selectedEquipmentType = .largeGym
                                selectedEquipment = Set(selectedEquipmentType.equipmentList)
                            }
                        )
                        
                        EquipmentTypeButton(
                            type: .smallGym,
                            isSelected: selectedEquipmentType == .smallGym,
                            onTap: {
                                HapticFeedback.generate()
                                selectedEquipmentType = .smallGym
                                selectedEquipment = Set(selectedEquipmentType.equipmentList)
                            }
                        )
                        
                        EquipmentTypeButton(
                            type: .garageGym,
                            isSelected: selectedEquipmentType == .garageGym,
                            onTap: {
                                HapticFeedback.generate()
                                selectedEquipmentType = .garageGym
                                selectedEquipment = Set(selectedEquipmentType.equipmentList)
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Second Row
                    HStack(spacing: 12) {
                        EquipmentTypeButton(
                            type: .atHome,
                            isSelected: selectedEquipmentType == .atHome,
                            onTap: {
                                HapticFeedback.generate()
                                selectedEquipmentType = .atHome
                                selectedEquipment = Set(selectedEquipmentType.equipmentList)
                            }
                        )
                        
                        EquipmentTypeButton(
                            type: .bodyweightOnly,
                            isSelected: selectedEquipmentType == .bodyweightOnly,
                            onTap: {
                                HapticFeedback.generate()
                                selectedEquipmentType = .bodyweightOnly
                                selectedEquipment = Set(selectedEquipmentType.equipmentList)
                            }
                        )
                        
                        EquipmentTypeButton(
                            type: .custom,
                            isSelected: selectedEquipmentType == .custom,
                            onTap: {
                                HapticFeedback.generate()
                                selectedEquipmentType = .custom
                                selectedEquipment = [] // Start with empty selection for custom
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Equipment selection (show for all except bodyweight only, unless custom)
                    if selectedEquipmentType != .bodyweightOnly || selectedEquipmentType == .custom {
                        equipmentSelectionGrid
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            
            // Action buttons
            actionButtons
        }
        .onAppear {
            // Initialize selection based on current equipment type or workout location
            let typeKey = UserProfileService.shared.scopedDefaultsKey("currentWorkoutEquipmentType")
            let equipmentKey = UserProfileService.shared.scopedDefaultsKey("currentWorkoutCustomEquipment")

            if let savedEquipmentType = UserDefaults.standard.string(forKey: typeKey),
               let equipmentType = EquipmentType(rawValue: savedEquipmentType) {
                selectedEquipmentType = equipmentType
            } else {
                // Default to user's workout location
                selectedEquipmentType = EquipmentType.getDefaultFromWorkoutLocation()
            }
            
            // Load saved custom equipment selection if it exists
            if let savedEquipmentStrings = UserDefaults.standard.array(forKey: equipmentKey) as? [String] {
                let savedEquipment = savedEquipmentStrings.compactMap { Equipment(rawValue: $0) }
                selectedEquipment = Set(savedEquipment)
                print("🔄 Loaded saved equipment: \(savedEquipment.map { $0.rawValue })")
            } else {
                // Set equipment based on type - initialize with appropriate equipment
                selectedEquipment = Set(selectedEquipmentType.equipmentList)
                print("🔄 Using default equipment for \(selectedEquipmentType.rawValue): \(selectedEquipmentType.equipmentList.map { $0.rawValue })")
            }
        }
    }
    
    private var equipmentSelectionGrid: some View {
        VStack(spacing: 16) {
            Text("Available Equipment")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            // Equipment grid - 3 per row using LazyVGrid
            let allEquipment = Equipment.allCases.filter { $0 != .bodyWeight } // Exclude bodyweight from selection
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(allEquipment, id: \.self) { equipment in
                    EquipmentSelectionButton(
                        equipment: equipment,
                        isSelected: selectedEquipment.contains(equipment),
                        onTap: {
                            HapticFeedback.generate()
                            if selectedEquipment.contains(equipment) {
                                selectedEquipment.remove(equipment)
                            } else {
                                selectedEquipment.insert(equipment)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 0) {
            // Divider
            Divider()
            
            // Buttons with proper spacing
            HStack(spacing: 0) {
                Button("Set as default") {
                    HapticFeedback.generate()
                    
                    // Update user's default equipment and workout location
                    UserProfileService.shared.availableEquipment = Array(selectedEquipment)
                    
                    // Map equipment type to workout location format for server
                    let workoutLocation: String
                    switch selectedEquipmentType {
                    case .largeGym:
                        workoutLocation = "large_gym"
                    case .smallGym:
                        workoutLocation = "small_gym"
                    case .garageGym:
                        workoutLocation = "garage_gym"
                    case .atHome:
                        workoutLocation = "home"
                    case .bodyweightOnly:
                        workoutLocation = "bodyweight"
                    case .custom:
                        workoutLocation = "custom"
                    }
                    
                    // Update local workout location in UserDefaults (bypassing enum restriction)
                    UserDefaults.standard.set(workoutLocation, forKey: "workoutLocation")
                    
                    // Update server
                    if let email = UserDefaults.standard.string(forKey: "userEmail") {
                        updateServerWorkoutPreferences(
                            email: email, 
                            equipment: Array(selectedEquipment),
                            workoutLocation: workoutLocation
                        )
                    }
                    
                    onSelectionChanged(Array(selectedEquipment), selectedEquipmentType.rawValue)
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                
                Spacer()
                
                Button("Set for this workout") {
                    HapticFeedback.generate()
                    onSelectionChanged(Array(selectedEquipment), selectedEquipmentType.rawValue)
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.systemBackground))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.primary)
                .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
    }
    
    private func updateServerEquipment(email: String, equipment: [Equipment]) {
        print("🔄 Updating server equipment for \(email)")
        
        let equipmentStrings = equipment.map { $0.rawValue }
        let updateData: [String: Any] = [
            "available_equipment": equipmentStrings
        ]
        
        NetworkManagerTwo.shared.updateWorkoutPreferences(
            email: email,
            workoutData: updateData
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Successfully updated equipment on server")
                case .failure(let error):
                    print("❌ Failed to update equipment on server: \(error.localizedDescription)")
                }
            }
        }
    }

    private func updateServerWorkoutPreferences(email: String, equipment: [Equipment], workoutLocation: String) {
        print("🔄 Updating server workout preferences for \(email) with equipment: \(equipment.map { $0.rawValue }), location: \(workoutLocation)")
        
        let updateData: [String: Any] = [
            "available_equipment": equipment.map { $0.rawValue },
            "workout_location": workoutLocation
        ]
        
        NetworkManagerTwo.shared.updateWorkoutPreferences(
            email: email,
            workoutData: updateData
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ Successfully updated workout preferences on server")
                case .failure(let error):
                    print("❌ Failed to update workout preferences on server: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct EquipmentTypeButton: View {
    let type: EquipmentView.EquipmentType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(type.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity)
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

struct EquipmentSelectionButton: View {
    let equipment: Equipment
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Equipment image
                Group {
                    if let image = UIImage(named: equipment.imageAssetName) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        // Fallback SF Symbol
                        Image(systemName: "dumbbell")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                .frame(width: 45, height: 45)
                
                // Equipment name
                Text(equipment.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 85) // Ensure uniform card height across grid
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(Color.onboardingCardBackground)
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
    EquipmentView { equipment, type in
        print("Selected equipment: \(equipment.map { $0.rawValue }), type: \(type)")
    }
}
