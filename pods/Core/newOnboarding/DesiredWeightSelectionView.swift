import SwiftUI

struct DesiredWeightSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedWeight: Double = 0
    @State private var currentUnits: UnitsSystem = .imperial
    @State private var previousUnits: UnitsSystem = .imperial
    private let backgroundColor = Color.onboardingBackground

    private let conversionFactor = 0.45359237
    private let imperialRange: ClosedRange<Double> = 0.0...500.0
    private var metricRange: ClosedRange<Double> {
        (imperialRange.lowerBound * conversionFactor)...(imperialRange.upperBound * conversionFactor)
    }

    private var unitLabel: String {
        currentUnits == .imperial ? "lbs" : "kg"
    }

    private var weightRange: ClosedRange<Double> {
        currentUnits == .imperial ? imperialRange : metricRange
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

                            WeightRulerView2(
                                selectedWeight: $selectedWeight,
                                range: weightRange,
                                step: 0.1
                            )
                            .frame(height: 80)
                            .id(currentUnits)
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
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            loadInitialWeight()
            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 12)
            UserDefaults.standard.set("DesiredWeightSelectionView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
        }
        .onChange(of: viewModel.unitsSystem) { newUnit in
            handleUnitChange(from: previousUnits, to: newUnit)
            previousUnits = newUnit
        }
    }

    private func loadInitialWeight() {
        let defaults = UserDefaults.standard
        let hasSelectedUnits = defaults.object(forKey: "hasSelectedUnits") as? Bool ?? false

        if hasSelectedUnits {
            currentUnits = viewModel.unitsSystem
        } else {
            currentUnits = .imperial
            viewModel.unitsSystem = .imperial
        }
        previousUnits = currentUnits

        let storedKg = viewModel.desiredWeightKg
        if storedKg > 0 {
            selectedWeight = currentUnits == .imperial ? storedKg / conversionFactor : storedKg
            viewModel.desiredWeight = selectedWeight
            viewModel.desiredWeightKg = storedKg
            return
        }

        if currentUnits == .imperial {
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
        selectedWeight = (selectedWeight * 10).rounded() / 10
        viewModel.desiredWeight = selectedWeight
        viewModel.desiredWeightKg = currentUnits == .imperial ? selectedWeight * conversionFactor : selectedWeight
    }

    private func saveDesiredWeight() {
        let defaults = UserDefaults.standard
        viewModel.desiredWeight = selectedWeight

        let weightInKg = currentUnits == .imperial ? selectedWeight * conversionFactor : selectedWeight
        let weightInPounds = weightInKg / conversionFactor

        defaults.set(weightInKg, forKey: "desiredWeightKilograms")
        defaults.set(weightInPounds, forKey: "desiredWeightPounds")
        viewModel.desiredWeightKg = weightInKg

        // Determine diet goal based on current and desired weights
        let storedWeightKg = defaults.double(forKey: "weightKilograms")
        let storedWeightPounds = defaults.double(forKey: "weightPounds")
        let currentWeightKg: Double
        if storedWeightKg > 0 {
            currentWeightKg = storedWeightKg
        } else if storedWeightPounds > 0 {
            currentWeightKg = storedWeightPounds * conversionFactor
        } else {
            currentWeightKg = weightInKg
        }

        let differenceKg = weightInKg - currentWeightKg
        let fitnessGoal: String
        let serverDietGoal: String
        if abs(differenceKg) < 0.45 { // roughly 1 lb
            fitnessGoal = "maintain"
            serverDietGoal = "maintain"
        } else if differenceKg < 0 {
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

        // Default weekly progress rate to 1.5 lbs per week when a change is needed
        let differenceLbs = abs(differenceKg) * 2.20462262
        let recommendedWeeklyChangeLbs = differenceLbs < 1.0 ? 0.0 : 1.5
        defaults.set(recommendedWeeklyChangeLbs, forKey: "weeklyWeightChange")
        viewModel.weeklyWeightChange = recommendedWeeklyChangeLbs

        let calendar = Calendar.current
        if recommendedWeeklyChangeLbs > 0 {
            let projectedWeeks = max(differenceLbs / recommendedWeeklyChangeLbs, 0)
            let roundedWeeks = Int(ceil(projectedWeeks))
            defaults.set(roundedWeeks, forKey: "goalTimeframeWeeks")
            viewModel.goalTimeframeWeeks = roundedWeeks

            let totalDays = Int(ceil(projectedWeeks * 7))
            if let completionDate = calendar.date(byAdding: .day, value: totalDays, to: Date()) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                defaults.set(formatter.string(from: completionDate), forKey: "goalCompletionDate")
            }
        } else {
            defaults.removeObject(forKey: "goalCompletionDate")
            defaults.set(0, forKey: "goalTimeframeWeeks")
            viewModel.goalTimeframeWeeks = 0
        }
    }

    private func handleUnitChange(from oldUnit: UnitsSystem, to newUnit: UnitsSystem) {
        guard oldUnit != newUnit else { return }
        let weightInKilograms = oldUnit == .imperial ? selectedWeight * conversionFactor : selectedWeight

        if newUnit == .imperial {
            selectedWeight = weightInKilograms / conversionFactor
        } else {
            selectedWeight = weightInKilograms
        }

        let range = newUnit == .imperial ? imperialRange : metricRange
        selectedWeight = min(max(selectedWeight, range.lowerBound), range.upperBound)
        selectedWeight = (selectedWeight * 10).rounded() / 10
        currentUnits = newUnit
        viewModel.desiredWeightKg = weightInKilograms
        viewModel.desiredWeight = selectedWeight
    }

    private var continueButton: some View {
        Button {
            saveDesiredWeight()
            viewModel.newOnboardingStepIndex = viewModel.newOnboardingTotalSteps
            viewModel.currentStep = .programOverview
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
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 12)
                viewModel.currentStep = .aboutYou
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
                viewModel.desiredWeightKg = 0
                viewModel.weeklyWeightChange = 0
                viewModel.goalTimeframeWeeks = 0

                let defaults = UserDefaults.standard
                defaults.set(0, forKey: "weeklyWeightChange")
                defaults.set(0, forKey: "goalTimeframeWeeks")
                defaults.removeObject(forKey: "goalCompletionDate")
                viewModel.currentStep = .programOverview
            }
            .font(.headline)
            .foregroundColor(.primary)
        }
    }
}

struct DesiredWeightSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        DesiredWeightSelectionView()
            .environmentObject(OnboardingViewModel())
    }
}
