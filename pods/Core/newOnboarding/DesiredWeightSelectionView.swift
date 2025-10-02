import SwiftUI

struct DesiredWeightSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedWeight: Double = 0
    @State private var unit: WeightUnit = .imperial
    @State private var previousUnit: WeightUnit = .imperial
    private let backgroundColor = Color.onboardingBackground

    private let conversionFactor = 0.45359237
    private let imperialRange: ClosedRange<Double> = 0.0...500.0
    private var metricRange: ClosedRange<Double> {
        (imperialRange.lowerBound * conversionFactor)...(imperialRange.upperBound * conversionFactor)
    }

    private var unitLabel: String {
        unit == .imperial ? "lbs" : "kg"
    }

    private var weightRange: ClosedRange<Double> {
        unit == .imperial ? imperialRange : metricRange
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack() {
                    Spacer()
                    
                    VStack(spacing: 24) {
                        Text("What's your desired weight?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 16) {
                            Text(String(format: "%.1f %@", selectedWeight, unitLabel))
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.bottom, 8)
                            
                            unitPicker

                            WeightRulerView2(
                                selectedWeight: $selectedWeight,
                                range: weightRange,
                                step: 0.1
                            )
                            .frame(height: 80)
                            .id(unit)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundColor.ignoresSafeArea())
                
                continueButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(backgroundColor, for: .navigationBar)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            NavigationBarStyler.beginOnboardingAppearance()
            loadInitialWeight()
            viewModel.newOnboardingStepIndex = 3
        }
        .onDisappear {
            NavigationBarStyler.endOnboardingAppearance()
        }
        .onChange(of: unit) { newUnit in
            handleUnitChange(from: previousUnit, to: newUnit)
            previousUnit = newUnit
        }
    }

    private func loadInitialWeight() {
        unit = viewModel.unitsSystem == .imperial || UserDefaults.standard.bool(forKey: "isImperial") ? .imperial : .metric
        previousUnit = unit
        let storedKg = viewModel.desiredWeightKg
        if storedKg > 0 {
            selectedWeight = unit == .imperial ? storedKg / conversionFactor : storedKg
            viewModel.desiredWeight = selectedWeight
            return
        }

        let defaults = UserDefaults.standard
        if unit == .imperial {
            let desired = defaults.double(forKey: "desiredWeightPounds")
            if desired > 0 {
                selectedWeight = desired
            } else {
                let current = defaults.double(forKey: "weightPounds")
                selectedWeight = current > 0 ? current : 170
            }
        } else {
            let desired = defaults.double(forKey: "desiredWeightKilograms")
            if desired > 0 {
                selectedWeight = desired
            } else {
                let current = defaults.double(forKey: "weightKilograms")
                selectedWeight = current > 0 ? current : 77
            }
        }
        selectedWeight = min(max(selectedWeight, weightRange.lowerBound), weightRange.upperBound)
        viewModel.desiredWeight = selectedWeight
    }

    private func saveDesiredWeight() {
        let defaults = UserDefaults.standard
        viewModel.desiredWeight = selectedWeight
        if unit == .imperial {
            defaults.set(selectedWeight, forKey: "desiredWeightPounds")
            let kilograms = selectedWeight * conversionFactor
            defaults.set(kilograms, forKey: "desiredWeightKilograms")
            viewModel.desiredWeightKg = kilograms
        } else {
            defaults.set(selectedWeight, forKey: "desiredWeightKilograms")
            let pounds = selectedWeight / conversionFactor
            defaults.set(pounds, forKey: "desiredWeightPounds")
            viewModel.desiredWeightKg = selectedWeight
        }

        // Determine diet goal based on current and desired weights
        let currentWeight = unit == .imperial ?
            defaults.double(forKey: "weightPounds") :
            defaults.double(forKey: "weightKilograms")
        let difference = selectedWeight - currentWeight
        let fitnessGoal: String
        let serverDietGoal: String
        if abs(difference) < 1.0 {
            fitnessGoal = "maintain"
            serverDietGoal = "maintain"
        } else if difference < 0 {
            fitnessGoal = "loseWeight"
            serverDietGoal = "lose"
        } else {
            fitnessGoal = "gainWeight"
            serverDietGoal = "gain"
        }
        defaults.set(fitnessGoal, forKey: "dietGoal")
        defaults.set(serverDietGoal, forKey: "serverDietGoal")
        viewModel.dietGoal = fitnessGoal
        viewModel.primaryWellnessGoal = fitnessGoal
    }

    private func handleUnitChange(from oldUnit: WeightUnit, to newUnit: WeightUnit) {
        guard oldUnit != newUnit else { return }
        let weightInKilograms: Double
        if oldUnit == .imperial {
            weightInKilograms = selectedWeight * conversionFactor
        } else {
            weightInKilograms = selectedWeight
        }

        if newUnit == .imperial {
            selectedWeight = weightInKilograms / conversionFactor
            viewModel.desiredWeightKg = weightInKilograms
        } else {
            selectedWeight = weightInKilograms
            viewModel.desiredWeightKg = selectedWeight
        }

        let range = newUnit == .imperial ? imperialRange : metricRange
        selectedWeight = min(max(selectedWeight, range.lowerBound), range.upperBound)
        selectedWeight = (selectedWeight * 10).rounded() / 10
        viewModel.unitsSystem = newUnit == .imperial ? .imperial : .metric
        UserDefaults.standard.set(viewModel.unitsSystem.rawValue, forKey: "unitsSystem")
        UserDefaults.standard.set(newUnit == .imperial, forKey: "isImperial")
        viewModel.desiredWeight = selectedWeight
    }

    private var continueButton: some View {
        Button {
            saveDesiredWeight()
            viewModel.newOnboardingStepIndex = 4
            viewModel.currentStep = .gymLocation
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
                viewModel.newOnboardingStepIndex = 2
                viewModel.currentStep = .strengthExperience
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
                viewModel.newOnboardingStepIndex = viewModel.newOnboardingTotalSteps
                viewModel.desiredWeight = nil
                viewModel.currentStep = .signup
            }
            .font(.headline)
            .foregroundColor(.primary)
        }
    }
}

private extension DesiredWeightSelectionView {
    enum WeightUnit: String, CaseIterable, Identifiable {
        case imperial
        case metric

        var id: String { rawValue }

        var title: String {
            switch self {
            case .imperial: return "Imperial"
            case .metric: return "Metric"
            }
        }
    }

    var unitPicker: some View {
        VStack(spacing: 8) {
            Text("Unit")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("Unit", selection: $unit) {
                ForEach(WeightUnit.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct DesiredWeightSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        DesiredWeightSelectionView()
            .environmentObject(OnboardingViewModel())
    }
}
