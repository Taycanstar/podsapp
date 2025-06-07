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
    
    // Get user email from onboardingViewModel
    private var userEmail: String {
        onboardingViewModel.email
    }
    
    // Preset water amounts (in fluid ounces)
    let presets = [
        (label: "8 oz", value: 8),
        (label: "12 oz", value: 12),
        (label: "16 oz", value: 16),
        (label: "20 oz", value: 20),
        (label: "24 oz", value: 24),
        (label: "32 oz", value: 32),
    ]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                
                HStack(spacing: 16) {
                    Text("oz")
                        .font(.system(size: 17, weight: .regular))
                    
                    Spacer()
                    
                    TextField("0", text: $waterAmount)
                        .font(.system(size: 17, weight: .regular))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                        .onChange(of: waterAmount) { newValue in
                            // If the user manually changes the input, clear the preset selection
                            if let amount = Int(newValue), !presets.contains(where: { $0.value == amount }) {
                                selectedPreset = nil
                            }
                        }
                }
                .padding()
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
                        ForEach(0..<presets.count, id: \.self) { index in
                            Button(action: {
                                selectPreset(index)
                                HapticFeedback.generate()
                            }) {
                                Text(presets[index].label)
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
                // Automatically focus the input when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true
                }
            }
        }
    }
    
    private func selectPreset(_ index: Int) {
        selectedPreset = index
        waterAmount = "\(presets[index].value)"
        
        // Dismiss keyboard
        isInputFocused = false
    }
    
    private func logWater() {
        guard let amount = Double(waterAmount),
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
        
        // Log water to backend
        NetworkManagerTwo.shared.logWater(
            userEmail: userEmail,
            waterOz: amount,
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