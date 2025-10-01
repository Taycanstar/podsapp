import SwiftUI
import UIKit

struct ReviewEquipmentView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    private var equipmentSections: [(title: String, items: [Equipment])] {
        let allEquipment = Set(Equipment.allCases)

        func filtered(_ equipments: [Equipment]) -> [Equipment] {
            equipments
                .filter { allEquipment.contains($0) && $0 != .bodyWeight }
                .sorted { $0.rawValue < $1.rawValue }
        }

        return [
            ("Small Weights", filtered([.dumbbells, .kettlebells])),
            ("Bars & Plates", filtered([.barbells, .ezBar])),
            ("Benches & Racks", filtered([.flatBench, .inclineBench, .declineBench, .squatRack, .preacherCurlBench])),
            ("Cable Machines", filtered([.cable, .latPulldownCable, .rowMachine])),
            ("Resistance Bands", filtered([.resistanceBands])),
            ("Exercise Balls & More", filtered([.stabilityBall, .medicineBalls, .bosuBalanceTrainer, .box, .pvc])),
            ("Plated Machines", filtered([.hammerstrengthMachine, .legPress, .hackSquatMachine, .sled])),
            ("Weight Machines", filtered([
                .smithMachine, .legExtensionMachine, .legCurlMachine, .calfRaiseMachine,
                .shoulderPressMachine, .tricepsExtensionMachine, .bicepsCurlMachine,
                .abCrunchMachine, .preacherCurlMachine
            ])),
            ("Specialties", filtered([
                .pullupBar, .dipBar, .battleRopes, .rings, .platforms
            ]))
        ]
        .filter { !$0.items.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 12) {
                            Text("Review your equipment")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            Text("It's tailored to your training environment, and you're free to edit it now or later.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }

                        VStack(spacing: 24) {
                            ForEach(equipmentSections, id: \.title) { section in
                                equipmentSection(title: section.title, items: section.items)
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 140)
                    }
                    .padding(.top, 48)
                    .padding(.bottom, 0)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())

                continueButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        }
        .onAppear {
            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 5)
        }
    }

    private func equipmentSection(title: String, items: [Equipment]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items, id: \.self) { equipment in
                        EquipmentSelectionButton(
                            equipment: equipment,
                            isSelected: viewModel.equipmentInventory.contains(equipment),
                            onTap: {
                                toggleSelection(for: equipment)
                        }
                    )
                }
            }
        }
    }

    private func toggleSelection(for equipment: Equipment) {
        HapticFeedback.generate()
        UISelectionFeedbackGenerator().selectionChanged()
        if viewModel.equipmentInventory.contains(equipment) {
            viewModel.equipmentInventory.remove(equipment)
        } else {
            viewModel.equipmentInventory.insert(equipment)
        }
    }

    private var continueButton: some View {
        Button {
            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 6)
            viewModel.currentStep = .workoutSchedule
        } label: {
            Text("Continue")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .foregroundColor(Color(.systemBackground))
                .cornerRadius(36)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private var progressView: some View {
        ProgressView(value: viewModel.newOnboardingProgress)
            .progressViewStyle(.linear)
            .frame(width: 160)
            .tint(.primary)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 4)
                viewModel.currentStep = .gymLocation
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }

        ToolbarItem(placement: .principal) {
            progressView
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Skip") {
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 6)
                viewModel.currentStep = .workoutSchedule
            }
            .font(.headline)
            .foregroundColor(.primary)
        }
    }
}

struct ReviewEquipmentView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = OnboardingViewModel()
        viewModel.selectedGymLocation = .largeGym
        return ReviewEquipmentView()
            .environmentObject(viewModel)
    }
}
