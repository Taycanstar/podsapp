import SwiftUI

struct LogWaterView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var waterAmount: String = ""
    @State private var selectedPreset: Int?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLogging = false
    @FocusState private var isInputFocused: Bool
    @AppStorage(WaterUnit.storageKey) private var storedWaterUnitRawValue: String = WaterUnit.defaultUnit.rawValue
    @State private var selectedUnit: WaterUnit = WaterUnit.defaultUnit
    
    // Get user email from onboardingViewModel
    private var userEmail: String {
        onboardingViewModel.email
    }
    
    private var currentPresets: [Double] {
        selectedUnit.presets
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                
                VStack(spacing: 0) {
                    HStack {
                        Text("Unit")
                            .font(.system(size: 17, weight: .regular))
                        Spacer()
                        Menu {
                            ForEach(WaterUnit.allCases) { unit in
                                Button {
                                    updateSelectedUnit(unit)
                                } label: {
                                    if unit == selectedUnit {
                                        Label(unit.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(unit.displayName)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedUnit.displayName)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .font(.system(size: 17, weight: .regular))
                        }
                        .menuStyle(.borderlessButton)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider()

                    HStack(spacing: 16) {
                        Text(selectedUnit.abbreviation)
                            .font(.system(size: 17, weight: .regular))
                        
                        Spacer()
                        
                        TextField("0", text: $waterAmount)
                            .font(.system(size: 17, weight: .regular))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                            .onChange(of: waterAmount) { newValue in
                                handleManualInputChange(newValue)
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color("iosnp"))
                .cornerRadius(12)
                .padding(.horizontal)

                // Preset buttons
                VStack(alignment: .leading, spacing: 16) {
                    // Grid of preset buttons
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Array(currentPresets.enumerated()), id: \.offset) { index, preset in
                            Button(action: {
                                selectPreset(index)
                                HapticFeedback.generate()
                            }) {
                                Text(selectedUnit.presetLabel(for: preset))
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 35)
                                    .padding(.horizontal, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedPreset == index ? Color.accentColor : Color("iosnp"))
                                    )
                                    .foregroundColor(selectedPreset == index ? .white : .primary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .background(Color("iosbg2").ignoresSafeArea())
            .navigationTitle("Add Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .regular))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        logWater()
                    }) {
                        if isLogging {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Log")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .disabled(waterAmount.isEmpty || isLogging)
                }
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                selectedUnit = persistedWaterUnit
                if let amount = parsedAmount(from: waterAmount) {
                    updatePresetSelection(for: amount)
                } else {
                    selectedPreset = nil
                }
                // Automatically focus the input when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true
                }
            }
        }
    }
    
    private var persistedWaterUnit: WaterUnit {
        WaterUnit(rawValue: storedWaterUnitRawValue) ?? .defaultUnit
    }

    private func handleManualInputChange(_ newValue: String) {
        guard let amount = parsedAmount(from: newValue) else {
            selectedPreset = nil
            return
        }
        updatePresetSelection(for: amount)
    }

    private func updatePresetSelection(for amount: Double) {
        let presets = currentPresets
        guard !presets.isEmpty else {
            selectedPreset = nil
            return
        }

        let tolerance = presetTolerance(for: selectedUnit)
        if let matchIndex = presets.firstIndex(where: { abs($0 - amount) <= tolerance }) {
            selectedPreset = matchIndex
        } else {
            selectedPreset = nil
        }
    }

    private func presetTolerance(for unit: WaterUnit) -> Double {
        switch unit {
        case .milliliters:
            return 0.5
        case .liters:
            return 0.005
        default:
            return 0.01
        }
    }

    private func parsedAmount(from string: String) -> Double? {
        let normalized = string
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized)
    }

    private func updateSelectedUnit(_ unit: WaterUnit) {
        guard unit != selectedUnit else { return }

        let previousUnit = selectedUnit
        let currentValue = parsedAmount(from: waterAmount)
        let valueInUSOunces = currentValue.map { previousUnit.convertToUSFluidOunces($0) }

        selectedUnit = unit
        storedWaterUnitRawValue = unit.rawValue

        guard let usOunces = valueInUSOunces else {
            selectedPreset = nil
            return
        }

        let converted = unit.convertFromUSFluidOunces(usOunces)
        waterAmount = unit.format(converted)
        updatePresetSelection(for: converted)
    }

    private func selectPreset(_ index: Int) {
        let presets = currentPresets
        guard presets.indices.contains(index) else { return }

        selectedPreset = index
        waterAmount = selectedUnit.format(presets[index])
        
        // Dismiss keyboard
        isInputFocused = false
    }
    
    private func logWater() {
        guard let amount = parsedAmount(from: waterAmount),
              amount > 0 else {
            alertMessage = "Please enter a valid amount"
            showAlert = true
            return
        }
        
        guard !userEmail.isEmpty else {
            alertMessage = "User email not found"
            showAlert = true
            return
        }
        
        isLogging = true
        
        let waterOz = selectedUnit.convertToUSFluidOunces(amount)

        // Log water to backend
        NetworkManagerTwo.shared.logWater(
            userEmail: userEmail,
            waterOz: waterOz,
            originalAmount: amount,
            unit: selectedUnit.rawValue,
            notes: ""
        ) { [self] result in
            DispatchQueue.main.async {
                isLogging = false
                
                switch result {
                case .success:
                    // Post notification to update UI
                    NotificationCenter.default.post(
                        name: NSNotification.Name("WaterLoggedNotification"), 
                        object: nil
                    )
                    dismiss()
                    
                case .failure(let error):
                    alertMessage = "Failed to log water: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
} 
