import SwiftUI
import HealthKit

struct AllowHealthView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    private let healthKitManager = HealthKitManager.shared
    private let backgroundColor = Color.onboardingBackground
    @State private var isRequestingPermission = false
    @State private var hasExistingAuthorization = false
    @State private var healthKitUnavailable = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        Image("health")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)

                        Text("Allow Apple Health Integration")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Text("Your health data helps Metryc design your workouts, give accurate insights, and record your activity.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 24)
                .background(backgroundColor.ignoresSafeArea())

                actionButtons
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 10)
            UserDefaults.standard.set("AllowHealthView", forKey: "currentOnboardingStep")
            UserDefaults.standard.set(true, forKey: "onboardingInProgress")
            UserDefaults.standard.synchronize()
            hasExistingAuthorization = healthKitManager.isAuthorized
            healthKitUnavailable = !healthKitManager.isHealthDataAvailable
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            if healthKitUnavailable {
                Text("Apple Health is not available on this device. You can continue to enter your details manually.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            } else if hasExistingAuthorization {
                Text("Apple Health is already connected. Continue to review your details.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            Button("Not now") {
                HapticFeedback.generate()
                UserDefaults.standard.set(false, forKey: "healthKitEnabled")
                hasExistingAuthorization = false
                advanceToAboutYou()
            }
            .foregroundColor(.primary)

            Button {
                HapticFeedback.generate()
                requestHealthPermissions()
            } label: {
                ZStack {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .opacity(isRequestingPermission ? 0 : 1)

                    if isRequestingPermission {
                        ProgressView()
                            .tint(Color(.systemBackground))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .foregroundColor(Color(.systemBackground))
                .cornerRadius(36)
            }
            .disabled(isRequestingPermission)
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
                viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 9)
                viewModel.currentStep = .enableNotifications
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
            EmptyView()
        }
    }
}

struct AllowHealthView_Previews: PreviewProvider {
    static var previews: some View {
        AllowHealthView()
            .environmentObject(OnboardingViewModel())
    }
}

private extension AllowHealthView {
    func requestHealthPermissions() {
        guard !isRequestingPermission else { return }

        if !healthKitManager.isHealthDataAvailable {
            UserDefaults.standard.set(false, forKey: "healthKitEnabled")
            advanceToAboutYou()
            return
        }

        if healthKitManager.isAuthorized {
            hasExistingAuthorization = true
            fetchAndApplyHealthData {
                advanceToAboutYou()
            }
            return
        }

        isRequestingPermission = true
        healthKitManager.checkAndRequestHealthPermissions { success in
            DispatchQueue.main.async {
                self.isRequestingPermission = false
                self.hasExistingAuthorization = success
                if success {
                    self.fetchAndApplyHealthData {
                        advanceToAboutYou()
                    }
                } else {
                    UserDefaults.standard.set(false, forKey: "healthKitEnabled")
                    advanceToAboutYou()
                }
            }
        }
    }

    func advanceToAboutYou() {
        isRequestingPermission = false
        viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 11)
        viewModel.currentStep = .aboutYou
    }

    func fetchAndApplyHealthData(completion: @escaping () -> Void) {
        guard healthKitManager.isAuthorized else {
            completion()
            return
        }

        let dispatchGroup = DispatchGroup()

        var fetchedHeight: Double?
        var fetchedWeight: Double?
        var fetchedDateOfBirth: Date?
        var fetchedSex: HKBiologicalSex?

        dispatchGroup.enter()
        healthKitManager.fetchHeight { height, _ in
            if let height = height, height > 0 {
                fetchedHeight = height
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        healthKitManager.fetchBodyWeight { weight, _ in
            if let weight = weight, weight > 0 {
                fetchedWeight = weight
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        healthKitManager.fetchDateOfBirth { date, _ in
            if let date = date {
                fetchedDateOfBirth = date
            }
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        healthKitManager.fetchBiologicalSex { sex, _ in
            if let sex = sex {
                fetchedSex = sex
            }
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            let defaults = UserDefaults.standard

            if let height = fetchedHeight {
                viewModel.heightCm = height
                defaults.set(height, forKey: "heightCentimeters")
                defaults.set(height / 2.54, forKey: "heightInches")
            }

            if let weight = fetchedWeight {
                viewModel.weightKg = weight
                defaults.set(weight, forKey: "weightKilograms")
                defaults.set(weight * 2.20462262, forKey: "weightPounds")
            }

            if let date = fetchedDateOfBirth {
                viewModel.dateOfBirth = date
                storeDateOfBirth(date)
            }

            if let sex = fetchedSex {
                let genderString: String
                switch sex {
                case .female: genderString = "female"
                case .male: genderString = "male"
                case .other, .notSet: genderString = "other"
                @unknown default: genderString = "other"
                }
                viewModel.gender = genderString
                defaults.set(genderString, forKey: "gender")
            }

            completion()
        }
    }

    func storeDateOfBirth(_ date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        UserDefaults.standard.set(formatter.string(from: date), forKey: "dateOfBirth")
        UserDefaults.standard.set(calendar.component(.month, from: date), forKey: "birthMonth")
        UserDefaults.standard.set(calendar.component(.day, from: date), forKey: "birthDay")
        UserDefaults.standard.set(calendar.component(.year, from: date), forKey: "birthYear")
        let ageComponents = calendar.dateComponents([.year], from: date, to: Date())
        if let age = ageComponents.year {
            UserDefaults.standard.set(age, forKey: "age")
        }
    }
}
