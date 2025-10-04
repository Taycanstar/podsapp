import SwiftUI
import HealthKit

struct AboutYouView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    private let healthKitManager = HealthKitManager.shared
    private let backgroundColor = Color.onboardingBackground

    @State private var isShowingDatePicker = false
    @State private var isShowingHeightPicker = false
    @State private var isShowingWeightPicker = false

    @State private var dobInput: String = ""
    @FocusState private var isDobFieldFocused: Bool
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

                            sexSelectionMenu

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
            viewModel.newOnboardingStepIndex = min(viewModel.newOnboardingTotalSteps, 9)
            saveProgressMarker()
            prefillFromHealthKitIfNeeded()
        }
        .onDisappear {
            NavigationBarStyler.endOnboardingAppearance()
        }
        .sheet(isPresented: $isShowingDatePicker) {
            NavigationStack {
                VStack(spacing: 24) {
                    TextField("mm/dd/yyyy", text: Binding(
                        get: { formattedDobInput(dobInput) },
                        set: { newValue in dobInput = sanitizedDobInput(newValue) }
                    ))
                    .keyboardType(.numbersAndPunctuation)
                    .focused($isDobFieldFocused)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.title2)
                    .fontWeight(.regular)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                    if dobInput.count == 8 && dateFromDobInput(dobInput) == nil {
                        Text("Enter a valid calendar date")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("Date of Birth")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            isShowingDatePicker = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            guard let date = dateFromDobInput(dobInput) else { return }
                            viewModel.dateOfBirth = date
                            storeDateOfBirth(date)
                            isShowingDatePicker = false
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .disabled(dateFromDobInput(dobInput) == nil)
                    }
                }
                .onAppear {
                    isDobFieldFocused = true
                }
            }
            .presentationDetents([.fraction(0.35)])
        }
        .sheet(isPresented: $isShowingHeightPicker) {
            NavigationStack {
                VStack {
                    if isImperial {
                        HStack(spacing: 0) {
                            Picker("Feet", selection: $tempFeet) {
                                ForEach(heightFeetRange, id: \.self) { value in
                                    Text("\(value) ft").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)

                            Picker("Inches", selection: $tempInches) {
                                ForEach(heightInchesRange, id: \.self) { value in
                                    Text("\(value) in").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()
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
                        .labelsHidden()
                        .frame(height: 180)
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("Height")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            isShowingHeightPicker = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveHeightSelection()
                            isShowingHeightPicker = false
                        } label: {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            .presentationDetents([.fraction(0.6), .large])
        }
        .sheet(isPresented: $isShowingWeightPicker) {
            NavigationStack {
                VStack {
                    if isImperial {
                        Picker("Pounds", selection: $tempPounds) {
                            ForEach(poundsRange, id: \.self) { value in
                                Text("\(value) lb").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 180)
                    } else {
                        Picker("Kilograms", selection: $tempKilograms) {
                            ForEach(kilogramsRange, id: \.self) { value in
                                Text("\(value) kg").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 180)
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("Weight")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            isShowingWeightPicker = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveWeightSelection()
                            isShowingWeightPicker = false
                        } label: {
                            Image(systemName: "checkmark")
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
            UserDefaults.standard.set(true, forKey: "hasSelectedUnits")
        }
    }

    private func infoCard(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            cardContainer {
                cardLabel(icon: icon, title: title, value: value)
            }
        }
        .buttonStyle(.plain)
    }

    private var sexSelectionMenu: some View {
        Menu {
            ForEach(SexOption.allCases) { option in
                Button {
                    tempSex = option
                    viewModel.gender = option.rawValue
                    UserDefaults.standard.set(option.rawValue, forKey: "gender")
                } label: {
                    HStack {
                        Text(option.displayName)
                        if option == tempSex {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            cardContainer {
                cardLabel(icon: "figure.stand", title: "SEX", value: selectedSexLabel)
            }
        }
    }

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    private func cardLabel(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.primary)
                Spacer()
            }

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.regular)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private var continueButton: some View {
        Button {
            persistCurrentValues()
            viewModel.newOnboardingStepIndex = viewModel.newOnboardingTotalSteps
            viewModel.currentStep = .desiredWeight
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
        formatter.dateFormat = "MM/dd/yyyy"
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
            dobInput = digitsString(from: dob)
        } else {
            dobInput = ""
        }

        if let option = SexOption(rawValue: viewModel.gender.lowercased()) {
            tempSex = option
        }

        prepareHeightState()
        prepareWeightState()
    }

    private func prepareDateState() {
        if let dob = viewModel.dateOfBirth {
            dobInput = digitsString(from: dob)
        } else {
            dobInput = ""
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
            UserDefaults.standard.set(Double(totalInches), forKey: "heightInches")
        } else {
            viewModel.heightCm = Double(tempCentimeters)
            UserDefaults.standard.set(Double(tempCentimeters) / 2.54, forKey: "heightInches")
        }

        UserDefaults.standard.set(viewModel.heightCm, forKey: "heightCentimeters")
    }

    private func saveWeightSelection() {
        if isImperial {
            viewModel.weightKg = Double(tempPounds) * 0.45359237
            UserDefaults.standard.set(Double(tempPounds), forKey: "weightPounds")
        } else {
            viewModel.weightKg = Double(tempKilograms)
            UserDefaults.standard.set(Double(tempKilograms) * 2.20462262, forKey: "weightPounds")
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
                    UserDefaults.standard.set(height / 2.54, forKey: "heightInches")
                }
            }
        }

        healthKitManager.fetchBodyWeight { weight, _ in
            if let weight = weight, weight > 0, self.viewModel.weightKg <= 0 {
                DispatchQueue.main.async {
                    self.viewModel.weightKg = weight
                    UserDefaults.standard.set(weight, forKey: "weightKilograms")
                    UserDefaults.standard.set(weight * 2.20462262, forKey: "weightPounds")
                }
            }
        }

        healthKitManager.fetchDateOfBirth { date, _ in
            if let date = date, self.viewModel.dateOfBirth == nil {
                DispatchQueue.main.async {
                    self.viewModel.dateOfBirth = date
                    dobInput = digitsString(from: date)
                    storeDateOfBirth(date)
                }
            }
        }

        healthKitManager.fetchBiologicalSex { sex, _ in
            if let sex = sex, self.viewModel.gender.isEmpty {
                DispatchQueue.main.async {
                    switch sex {
                    case .female:
                        self.viewModel.gender = SexOption.female.rawValue
                        self.tempSex = .female
                    case .male:
                        self.viewModel.gender = SexOption.male.rawValue
                        self.tempSex = .male
                    case .other, .notSet:
                        self.viewModel.gender = SexOption.other.rawValue
                        self.tempSex = .other
                    @unknown default:
                        self.viewModel.gender = SexOption.other.rawValue
                        self.tempSex = .other
                    }
                    UserDefaults.standard.set(self.viewModel.gender, forKey: "gender")
                }
            }
        }
    }

    private func persistCurrentValues() {
        if let dob = viewModel.dateOfBirth {
            storeDateOfBirth(dob)
        }

        if !viewModel.gender.isEmpty {
            UserDefaults.standard.set(viewModel.gender, forKey: "gender")
        }

        let defaults = UserDefaults.standard

        if viewModel.heightCm > 0 {
            defaults.set(viewModel.heightCm, forKey: "heightCentimeters")
            let totalInches = viewModel.heightCm / 2.54
            defaults.set(totalInches, forKey: "heightInches")
        }

        if viewModel.weightKg > 0 {
            defaults.set(viewModel.weightKg, forKey: "weightKilograms")
            defaults.set(viewModel.weightKg * 2.20462262, forKey: "weightPounds")
        }
    }

    private func sanitizedDobInput(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        if digits.count <= 8 {
            return digits
        }
        return String(digits.prefix(8))
    }

    private func formattedDobInput(_ digits: String) -> String {
        var result = ""
        for (index, char) in digits.enumerated() {
            if index == 2 || index == 4 {
                result.append("/")
            }
            result.append(char)
        }
        return result
    }

    private func dateFromDobInput(_ digits: String) -> Date? {
        guard digits.count == 8 else { return nil }
        let monthString = String(digits.prefix(2))
        let dayString = String(digits.dropFirst(2).prefix(2))
        let yearString = String(digits.suffix(4))

        guard let month = Int(monthString), let day = Int(dayString), let year = Int(yearString) else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        let calendar = Calendar.current
        return calendar.date(from: components)
    }

    private func digitsString(from date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let year = calendar.component(.year, from: date)
        return String(format: "%02d%02d%04d", month, day, year)
    }

    private func storeDateOfBirth(_ date: Date) {
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
