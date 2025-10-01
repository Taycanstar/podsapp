import SwiftUI
import UIKit

struct ScheduleSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    private enum Mode: String, CaseIterable, Identifiable {
        case perWeek
        case specific

        var id: String { rawValue }

        var title: String {
            switch self {
            case .perWeek: return "Days Per Week"
            case .specific: return "Specific Days"
            }
        }
    }

    @State private var mode: Mode = .perWeek

    private let frequencyOptions: [Int] = [1, 2, 3, 4, 5, 6, 7]
    private let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 32) {
                        header
                        modePicker
                        if mode == .perWeek {
                            frequencyPickerCard
                        } else {
                            specificDaysCard
                        }
                        Spacer(minLength: 140)
                    }
                    .padding(.top, 48)
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
            viewModel.ensureDefaultSchedule()
            viewModel.newOnboardingStepIndex = viewModel.newOnboardingTotalSteps
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Set workout schedule")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("Pick how often you train and lock in the days that work best for you.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var modePicker: some View {
        Picker("Schedule mode", selection: $mode) {
            ForEach(Mode.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
    }

    private var frequencyPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
     
            HStack {
                Text("Frequency")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                Spacer()
                Menu {
                    Picker("Days per week", selection: Binding(
                        get: { viewModel.trainingDaysPerWeek },
                        set: { newValue in
                            HapticFeedback.generate()
                            viewModel.setTrainingDaysPerWeek(newValue, autoSelectDays: true)
                        }
                    )) {
                        ForEach(frequencyOptions, id: \.self) { option in
                            Text(label(for: option)).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(label(for: viewModel.trainingDaysPerWeek))
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            }
            // .padding(.horizontal, 16)
            // .padding(.vertical, 10)
            .cornerRadius(16)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 24)
    }

    private var specificDaysCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Specific days")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Tap the days you plan to train")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            LazyVGrid(columns: dayColumns, spacing: 12) {
                ForEach(OnboardingViewModel.Weekday.allCases, id: \.self) { day in
                    dayButton(for: day)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 24)
    }

    private func dayButton(for day: OnboardingViewModel.Weekday) -> some View {
        let isSelected = viewModel.selectedTrainingDays.contains(day)
        return Button {
            HapticFeedback.generate()
            viewModel.toggleTrainingDay(day)
        } label: {
            Text(day.shortLabel)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.primary : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? Color(.systemBackground) : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private var continueButton: some View {
        Button {
            viewModel.syncWorkoutSchedule()
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
        .padding(.bottom, 32)
        .disabled(mode == .specific && viewModel.selectedTrainingDays.isEmpty)
        .opacity(mode == .specific && viewModel.selectedTrainingDays.isEmpty ? 0.5 : 1.0)
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
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 5)
                if viewModel.selectedGymLocation == .noEquipment || viewModel.selectedGymLocation == nil {
                    viewModel.currentStep = .gymLocation
                } else {
                    viewModel.currentStep = .reviewEquipment
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }

qq        ToolbarItem(placement: .principal) {
            progressView
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Skip") {
                viewModel.syncWorkoutSchedule()
                viewModel.currentStep = .signup
            }
            .font(.headline)
            .foregroundColor(.primary)
        }
    }

    private func label(for days: Int) -> String {
        if days == 7 { return "Every day" }
        return days == 1 ? "1 day a week" : "\(days) days a week"
    }

}

struct ScheduleSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = OnboardingViewModel()
        viewModel.setTrainingDaysPerWeek(4)
        return ScheduleSelectionView()
            .environmentObject(viewModel)
    }
}
