import SwiftUI
import HealthKit

struct AboutYouView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    private let healthKitManager = HealthKitManager.shared
    private let backgroundColor = Color.onboardingBackground

    @State private var isShowingDatePicker = false
    @State private var isShowingSexPicker = false
    @State private var isShowingHeightPicker = false
    @State private var isShowingWeightPicker = false

    @State private var tempDateOfBirth = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var tempSex: SexOption = .male

    @State private var tempFeet = 5
    @State private var tempInches = 8
    @State private var tempCentimeters = 175

    @State private var tempPounds = 160
    @State private var tempKilograms = 73

    @State private var didPrefillFromHealthKit = false

    private let heightFeetRange = 3...7
    private let heightInchesRange = 0...11
    private let centimeterRange = 120...220

    private let poundsRange = 75...400
    private let kilogramsRange = 35...200

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    private var isImperial: Bool {
        viewModel.unitsSystem == .imperial
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 32) {
                        header

                        unitsControl

                        LazyVGrid(columns: columns, spacing: 16) {
                            infoCard(
                                icon: "calendar",
                                title: "DOB",
                                value: formattedDateOfBirth,
                                action: {
                                    prepareDateState()
                                    isShowingDatePicker = true
                                }
                            )

                            infoCard(
                                icon: "figure.stand",
                                title: "SEX",
                                value: selectedSexLabel,
                                action: {
                                    prepareSexState()
                                    isShowingSexPicker = true
                                }
                            )

                            infoCard(
                                icon: "scalemass.fill",
                                title: "WEIGHT",
                                value: formattedWeight,
                                action: {
                                    prepareWeightState()
                                    isShowingWeightPicker = true
                                }
                            )

                            infoCard(
                                icon: "ruler",
                                title: "HEIGHT",
                                value: formattedHeight,
                                action: {
                                    prepareHeightState()
                                    isShowingHeightPicker = true
                                }
                            )
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 140)
                    }
                    .padding(.top, 48)
                }
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
            setupInitialState()
            viewModel.newOnboardingStepIndex = viewModel.newOnboardingTotalSteps
            saveProgressMarker()
            prefillFromHealthKitIfNeeded()
        }
        .onDisappear {
            NavigationBarStyler.endOnboardingAppearance()
        }
        .sheet(isPresented: $isShowingDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "Date of Birth",
                        selection: $tempDateOfBirth,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    Spacer()
                }
                .navigationTitle("Date of Birth")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isShowingDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            viewModel.dateOfBirth = tempDateOfBirth
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            let calendar = Calendar.current
                            UserDefaults.standard.set(formatter.string(from: tempDateOfBirth), forKey: "dateOfBirth")
                            UserDefaults.standard.set(calendar.component(.month, from: tempDateOfBirth), forKey: "birthMonth")
                            UserDefaults.standard.set(calendar.component(.day, from: tempDateOfBirth), forKey: "birthDay")
                            UserDefaults.standard.set(calendar.component(.year, from: tempDateOfBirth), forKey: "birthYear")
                            let ageComponents = calendar.dateComponents([.year], from: tempDateOfBirth, to: Date())
                            if let age = ageComponents.year {
                                UserDefaults.standard.set(age, forKey: "age")
                            }
                            isShowingDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingSexPicker) {
            NavigationStack {
                List {
                    Section("Select sex") {
                        ForEach(SexOption.allCases) { option in
                            HStack {
                                Text(option.displayName)
                                Spacer()
                                if option == tempSex {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                tempSex = option
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Sex")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isShowingSexPicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            viewModel.gender = tempSex.rawValue
                            UserDefaults.standard.set(tempSex.rawValue, forKey: "gender")
                            isShowingSexPicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingHeightPicker) {
            NavigationStack {
                Form {
                    Section(header: Text("Units")) {
                        Picker("Units", selection: $viewModel.unitsSystem) {
                            ForEach(UnitsSystem.allCases, id: \.self) { system in
                                Text(system.displayName).tag(system)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(header: Text("Height")) {
                        if isImperial {
                            HStack(spacing: 0) {
                                Picker("Feet", selection: $tempFeet) {
                                    ForEach(heightFeetRange, id: \.self) { value in
                                        Text("\(value) ft").tag(value)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)

                                Picker("Inches", selection: $tempInches) {
                                    ForEach(heightInchesRange, id: \.self) { value in
                                        Text("\(value) in").tag(value)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                            }
                            .frame(height: 180)
                        } else {
                            Picker("Centimeters", selection: $tempCentimeters) {
                                ForEach(centimeterRange, id: \.self) { value in
                                    Text("\(value) cm").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 180)
                        }
                    }
                }
                .navigationTitle("Height")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isShowingHeightPicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            saveHeightSelection()
                            isShowingHeightPicker = false
                        }
                    }
                }
            }
            .presentationDetents([.fraction(0.6), .large])
        }
        .sheet(isPresented: $isShowingWeightPicker) {
            NavigationStack {
                Form {
                    Section(header: Text("Units")) {
                        Picker("Units", selection: $viewModel.unitsSystem) {
                            ForEach(UnitsSystem.allCases, id: \.self) { system in
                                Text(system.displayName).tag(system)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(header: Text("Weight")) {
                        if isImperial {
                            Picker("Pounds", selection: $tempPounds) {
                                ForEach(poundsRange, id: \.self) { value in
                                    Text("\(value) lb").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 180)
                        } else {
                            Picker("Kilograms", selection: $tempKilograms) {
                                ForEach(kilogramsRange, id: \.self) { value in
                                    Text("\(value) kg").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 180)
                        }
                    }
                }
                .navigationTitle("Weight")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isShowingWeightPicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            saveWeightSelection()
                            isShowingWeightPicker = false
                        }
                    }
                }
            }
            .presentationDetents([.fraction(0.6), .large])
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Tell us more about you")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("This information ensures Fitness and Health data are as accurate as possible for your personalized plan")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var unitsControl: some View {
        Picker("Units", selection: $viewModel.unitsSystem) {
            ForEach(UnitsSystem.allCases, id: \.self) { system in
                Text(system.displayName).tag(system)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
        .onChange(of: viewModel.unitsSystem) { _ in
            HapticFeedback.generate()
        }
    }

    private func infoCard(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                }

                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var continueButton: some View {
        Button {
            persistCurrentValues()
            viewModel.newOnboardingStepIndex = viewModel.newOnboardingTotalSteps
            viewModel.currentStep = .signup
        } label: {
            Text("Continue")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canContinue ? Color.primary : Color.primary.opacity(0.4))
                .foregroundColor(Color(.systemBackground))
                .cornerRadius(36)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .disabled(!canContinue)
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
                viewModel.currentStep = .allowHealth
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

    private var formattedDateOfBirth: String {
        guard let dob = viewModel.dateOfBirth else { return "Add" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dob)
    }

    private var selectedSexLabel: String {
        if let option = SexOption(rawValue: viewModel.gender.lowercased()) {
            return option.displayName
        }
        return "Select"
    }

    private var formattedHeight: String {
        guard viewModel.heightCm > 0 else { return "Add" }
        if isImperial {
            let totalInches = viewModel.heightCm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(round(totalInches.truncatingRemainder(dividingBy: 12)))
            return "\(feet)' \(inches)\""
        } else {
            return String(format: "%.0f cm", viewModel.heightCm)
        }
    }

    private var formattedWeight: String {
        guard viewModel.weightKg > 0 else { return "Add" }
        if isImperial {
            let pounds = viewModel.weightKg * 2.20462262
            return String(format: "%.0f lb", pounds)
        } else {
            return String(format: "%.0f kg", viewModel.weightKg)
        }
    }

    private var canContinue: Bool {
        viewModel.dateOfBirth != nil &&
        !viewModel.gender.isEmpty &&
        viewModel.heightCm > 0 &&
        viewModel.weightKg > 0
    }

    private func setupInitialState() {
        if let dob = viewModel.dateOfBirth {
            tempDateOfBirth = dob
        }

        if let option = SexOption(rawValue: viewModel.gender.lowercased()) {
            tempSex = option
        }

        prepareHeightState()
        prepareWeightState()
    }

    private func prepareDateState() {
        if let dob = viewModel.dateOfBirth {
            tempDateOfBirth = dob
        }
    }

    private func prepareSexState() {
        if let option = SexOption(rawValue: viewModel.gender.lowercased()) {
            tempSex = option
        }
    }

    private func prepareHeightState() {
        if viewModel.heightCm > 0 {
            let totalInches = viewModel.heightCm / 2.54
            tempFeet = max(heightFeetRange.lowerBound, min(heightFeetRange.upperBound, Int(totalInches / 12)))
            tempInches = max(heightInchesRange.lowerBound, min(heightInchesRange.upperBound, Int(round(totalInches.truncatingRemainder(dividingBy: 12)))))
            tempCentimeters = max(centimeterRange.lowerBound, min(centimeterRange.upperBound, Int(viewModel.heightCm.rounded())))
        }
    }

    private func prepareWeightState() {
        if viewModel.weightKg > 0 {
            tempKilograms = max(kilogramsRange.lowerBound, min(kilogramsRange.upperBound, Int(viewModel.weightKg.rounded())))
            tempPounds = max(poundsRange.lowerBound, min(poundsRange.upperBound, Int((viewModel.weightKg * 2.20462262).rounded())))
        }
    }

    private func saveHeightSelection() {
        if isImperial {
            let totalInches = (tempFeet * 12) + tempInches
            viewModel.heightCm = Double(totalInches) * 2.54
        } else {
            viewModel.heightCm = Double(tempCentimeters)
        }

        UserDefaults.standard.set(viewModel.heightCm, forKey: "heightCentimeters")
    }

    private func saveWeightSelection() {
        if isImperial {
            viewModel.weightKg = Double(tempPounds) * 0.45359237
        } else {
            viewModel.weightKg = Double(tempKilograms)
        }

        UserDefaults.standard.set(viewModel.weightKg, forKey: "weightKilograms")
    }

    private func saveProgressMarker() {
        UserDefaults.standard.set("AboutYouView", forKey: "currentOnboardingStep")
        UserDefaults.standard.set(true, forKey: "onboardingInProgress")
        UserDefaults.standard.synchronize()
    }

    private func prefillFromHealthKitIfNeeded() {
        guard !didPrefillFromHealthKit else { return }
        didPrefillFromHealthKit = true

        healthKitManager.fetchHeight { height, _ in
            if let height = height, height > 0, self.viewModel.heightCm <= 0 {
                DispatchQueue.main.async {
                    self.viewModel.heightCm = height
                    UserDefaults.standard.set(height, forKey: "heightCentimeters")
                }
            }
        }

        healthKitManager.fetchBodyWeight { weight, _ in
            if let weight = weight, weight > 0, self.viewModel.weightKg <= 0 {
                DispatchQueue.main.async {
                    self.viewModel.weightKg = weight
                    UserDefaults.standard.set(weight, forKey: "weightKilograms")
                }
            }
        }

        healthKitManager.fetchDateOfBirth { date, _ in
            if let date = date, self.viewModel.dateOfBirth == nil {
                DispatchQueue.main.async {
                    self.viewModel.dateOfBirth = date
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
        }

        healthKitManager.fetchBiologicalSex { sex, _ in
            if let sex = sex, self.viewModel.gender.isEmpty {
                DispatchQueue.main.async {
                    switch sex {
                    case .female:
                        self.viewModel.gender = SexOption.female.rawValue
                    case .male:
                        self.viewModel.gender = SexOption.male.rawValue
                    case .other:
                        fallthrough
                    case .notSet:
                        self.viewModel.gender = SexOption.other.rawValue
                    @unknown default:
                        self.viewModel.gender = SexOption.other.rawValue
                    }
                    UserDefaults.standard.set(self.viewModel.gender, forKey: "gender")
                }
            }
        }
    }

    private func persistCurrentValues() {
        if let dob = viewModel.dateOfBirth {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let calendar = Calendar.current
            UserDefaults.standard.set(formatter.string(from: dob), forKey: "dateOfBirth")
            UserDefaults.standard.set(calendar.component(.month, from: dob), forKey: "birthMonth")
            UserDefaults.standard.set(calendar.component(.day, from: dob), forKey: "birthDay")
            UserDefaults.standard.set(calendar.component(.year, from: dob), forKey: "birthYear")
            let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
            if let age = ageComponents.year {
                UserDefaults.standard.set(age, forKey: "age")
            }
        }

        if !viewModel.gender.isEmpty {
            UserDefaults.standard.set(viewModel.gender, forKey: "gender")
        }

        if viewModel.heightCm > 0 {
            UserDefaults.standard.set(viewModel.heightCm, forKey: "heightCentimeters")
        }

        if viewModel.weightKg > 0 {
            UserDefaults.standard.set(viewModel.weightKg, forKey: "weightKilograms")
        }
    }
}

private enum SexOption: String, CaseIterable, Identifiable {
    case male
    case female
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }
}

struct AboutYouView_Previews: PreviewProvider {
    static var previews: some View {
        AboutYouView()
            .environmentObject(OnboardingViewModel())
    }
}
