import SwiftUI

struct ProgramOverviewView: View {
    @EnvironmentObject private var viewModel: OnboardingViewModel
    @State private var nutritionGoals: NutritionGoals?
    @State private var isLoading = true

    private let backgroundColor = Color(.systemGroupedBackground)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        headerSection
                        summaryCard
                        progressSection
                        nutritionSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 48)
                    .padding(.bottom, 140)
                }
                .background(backgroundColor.ignoresSafeArea())
                .opacity(isLoading ? 0 : 1)

                if !isLoading {
                    continueButton
                }

                if isLoading {
                    loadingPlaceholder
                }
            }
            .navigationTitle("Plan Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(backgroundColor, for: .navigationBar)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            isLoading = true
            handleAppear()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isLoading = false
                }
            }
        }
        .onDisappear { NavigationBarStyler.endOnboardingAppearance() }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.programTitleDisplay)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            Text("Review your program details. You can edit these later in the app.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgramInfoRow(title: "Training Style", value: viewModel.trainingStyleDisplay, icon: "figure.strengthtraining.traditional")
            ProgramInfoRow(title: "Muscle Split", value: viewModel.trainingSplitDisplay, icon: "rectangle.grid.2x2")
            ProgramInfoRow(title: "Equipment Profile", value: viewModel.equipmentProfileDisplay, icon: "dumbbell")
            ProgramInfoRow(title: "Exercise Difficulty", value: viewModel.exerciseDifficultyDisplay, icon: "aqi.medium")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Projection")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                if let summary = weightSummaryText {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let chartData = weightChartData {
                    WeightProgressCurve(
                        currentWeight: chartData.current,
                        goalWeight: chartData.goal,
                        isGainGoal: chartData.isGain,
                        width: 300
                    )
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                } else {
                    Text("We'll personalize your weight timeline once all measurements are set.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        }
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Nutrition Targets")
                .font(.headline)

            if let goals = nutritionGoals {
                VStack(spacing: 16) {
                    MacroRow(title: "Calories", value: Int(goals.calories), unit: "kcal", color: Color("brightOrange"), icon: "flame.fill")
                    MacroRow(title: "Protein", value: Int(goals.protein), unit: "g", color: .blue, icon: "fish")
                    MacroRow(title: "Carbs", value: Int(goals.carbs), unit: "g", color: Color("darkYellow"), icon: "laurel.leading")
                    MacroRow(title: "Fat", value: Int(goals.fat), unit: "g", color: .pink, icon: "drop")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
            } else {
                placeholderCard(text: "We'll generate tailored macro goals once you finish onboarding.")
            }
        }
    }

    private var continueButton: some View {
        Button {
            viewModel.newOnboardingStepIndex = viewModel.newOnboardingTotalSteps
            viewModel.currentStep = .signup
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
        .padding(.top, 16)
        .padding(.bottom, 32)
        .background(backgroundColor.ignoresSafeArea())
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 11)
                viewModel.currentStep = .aboutYou
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
    }

    private func handleAppear() {
        NavigationBarStyler.beginOnboardingAppearance()
        viewModel.newOnboardingStepIndex = viewModel.newOnboardingTotalSteps
        UserDefaults.standard.set("ProgramOverviewView", forKey: "currentOnboardingStep")
        UserDefaults.standard.set(true, forKey: "onboardingInProgress")
        UserDefaults.standard.synchronize()
        loadNutritionGoals()
    }

    private func loadNutritionGoals() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: "nutritionGoalsData"),
           let decoded = try? JSONDecoder().decode(NutritionGoals.self, from: data) {
            nutritionGoals = decoded
            return
        }

        if let preview = viewModel.nutritionPreviewGoals {
            nutritionGoals = preview
            persistPreviewGoals(preview, defaults: defaults)
            return
        }

        if let previewData = defaults.data(forKey: "nutritionGoalsPreviewData"),
           let decoded = try? JSONDecoder().decode(NutritionGoals.self, from: previewData) {
            nutritionGoals = decoded
            return
        }

        let fallback = UserGoalsManager.shared.dailyGoals
        nutritionGoals = NutritionGoals(
            calories: Double(fallback.calories),
            protein: Double(fallback.protein),
            carbs: Double(fallback.carbs),
            fat: Double(fallback.fat)
        )
    }

    private func persistPreviewGoals(_ goals: NutritionGoals, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        defaults.set(data, forKey: "nutritionGoalsPreviewData")
    }

    private var loadingPlaceholder: some View {
        ScrollView {
            VStack(spacing: 24) {
                loadingCard(height: 180)
                loadingCard(height: 220)
                loadingCard(height: 260)
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 140)
        }
        .background(backgroundColor.ignoresSafeArea())
    }

    private func loadingCard(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(.secondarySystemBackground))
            .frame(height: height)
            .overlay(
                ShimmerView()
                    .mask(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)
                    )
            )
    }

    private func placeholderCard(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(24)
    }

    private var weightChartData: (current: Double, goal: Double, isGain: Bool)? {
        let currentKg = viewModel.weightKg
        let goalKg = viewModel.desiredWeightKg
        guard currentKg > 0, goalKg > 0 else { return nil }
        let isImperial = viewModel.unitsSystem == .imperial
        let current = isImperial ? currentKg * 2.20462 : currentKg
        let goal = isImperial ? goalKg * 2.20462 : goalKg
        return (current, goal, goal > current)
    }

    private var weightSummaryText: String? {
        guard let projection = weightProjection else { return nil }
        let diffString = "\(Int(round(projection.difference))) \(projection.unit)"
        if let completion = formattedCompletionDate, !completion.isEmpty {
            return "\(diffString) by \(completion)"
        }
        return diffString
    }

    private var formattedCompletionDate: String? {
        guard let date = completionDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private var completionDate: Date? {
        if let dateString = UserDefaults.standard.string(forKey: "goalCompletionDate") {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let storedDate = formatter.date(from: dateString) {
                return storedDate
            }
        }
        return computeProjectedCompletionDate()
    }

    private var weightProjection: (difference: Double, unit: String, completion: Date?)? {
        guard let data = weightChartData else { return nil }
        let difference = abs(data.goal - data.current)
        guard difference > 0 else { return nil }
        let unit = viewModel.unitsSystem == .imperial ? "lbs" : "kg"
        return (difference, unit, completionDate)
    }

    private func computeProjectedCompletionDate() -> Date? {
        guard let data = weightChartData else { return nil }
        let differenceDisplayUnits = abs(data.goal - data.current)
        guard differenceDisplayUnits > 0 else { return nil }

        let differenceLbs: Double
        if viewModel.unitsSystem == .imperial {
            differenceLbs = differenceDisplayUnits
        } else {
            differenceLbs = differenceDisplayUnits * 2.20462262
        }

        guard differenceLbs > 0 else { return nil }

        let storedWeekly = max(UserDefaults.standard.double(forKey: "weeklyWeightChange"), 0)
        let weeklyChange = storedWeekly > 0 ? storedWeekly : 1.5
        guard weeklyChange > 0 else { return nil }

        let projectedWeeks = differenceLbs / weeklyChange
        let totalDays = Int(ceil(projectedWeeks * 7))
        return Calendar.current.date(byAdding: .day, value: totalDays, to: Date())
    }
}

private struct ProgramInfoRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 32, height: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }
}

private struct MacroRow: View {
    let title: String
    let value: Int
    let unit: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(value) \(unit)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }
}

struct ProgramOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramOverviewView()
            .environmentObject(OnboardingViewModel())
    }
}
