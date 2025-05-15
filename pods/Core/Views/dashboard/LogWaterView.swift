import SwiftUI
import HealthKit

struct LogWaterView: View {
    @Environment(\.dismiss) var dismiss
    @State private var waterAmount: String = ""
    @State private var isLogging: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var selectedPreset: Int? = nil
    @FocusState private var isInputFocused: Bool
    
    // Preset water amounts in ounces
    private let presets: [(label: String, value: Int)] = [
        ("8 oz", 8),
        ("12 oz", 12),
        ("16 oz", 16),
        ("24 oz", 24),
        ("32 oz", 32),
        ("40 oz", 40),
        ("64 oz", 64),
        ("1 Gallon", 128)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Main input form
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
                                    .frame(height: 35) // Reduced height to make them less tall
                                    .padding(.horizontal, 3) // Added horizontal padding to make them wider
                                    .background(
                                        RoundedRectangle(cornerRadius: 20) // Use RoundedRectangle with large corner radius
                                            .fill(selectedPreset == index ? Color.accentColor : Color("iosnp"))
                                    )
                                    .foregroundColor(selectedPreset == index ? .white : .primary)
                            }
                            .padding(.vertical, 2) // Added some vertical spacing between rows
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            // .padding(.top, 16)
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
                        Text("Log")
                            .font(.system(size: 17, weight: .semibold))
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
        
        isLogging = true
        
        // Store water amount in UserDefaults as backup
        logWaterLocally(ounces: amount)
        
        // Notify that water was logged (will update the UI regardless of HealthKit access)
        NotificationCenter.default.post(name: NSNotification.Name("WaterLoggedNotification"), object: nil)
        
        // Only try HealthKit if available
        if HKHealthStore.isHealthDataAvailable() {
            do {
                let healthStore = HKHealthStore()
                let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
                
                
                // Check authorization status first before requesting authorization
                let status = healthStore.authorizationStatus(for: waterType)
                
                if status == .sharingAuthorized {
                    // Already authorized, save directly
                    saveWaterToHealthKit(amount: amount, healthStore: healthStore, waterType: waterType)
                } else {
                    // Try to request authorization first
                    healthStore.requestAuthorization(toShare: [waterType], read: [waterType]) { success, error in
                        if success {
                            // Authorization granted, proceed with saving
                            DispatchQueue.main.async {
                                saveWaterToHealthKit(amount: amount, healthStore: healthStore, waterType: waterType)
                            }
                        } else {
                            // Handle authorization failure gracefully
                            DispatchQueue.main.async {
                                isLogging = false
                                // We already logged locally, so we can still dismiss
                                dismiss()
                            }
                        }
                    }
                }
            } catch {
                // Handle any exceptions gracefully
                isLogging = false
                dismiss()
            }
        } else {
            // HealthKit not available, but we still logged locally
            isLogging = false
            dismiss()
        }
    }
    
    // Helper to save water data to HealthKit
    private func saveWaterToHealthKit(amount: Double, healthStore: HKHealthStore, waterType: HKQuantityType) {
        // Convert from ounces to liters (1 oz = 0.0295735 liters)
        let liters = amount * 0.0295735
        
        // Create a water sample
        let waterQuantity = HKQuantity(unit: HKUnit.liter(), doubleValue: liters)
        let waterSample = HKQuantitySample(type: waterType, 
                                           quantity: waterQuantity,
                                           start: Date(),
                                           end: Date())
        
        // Save to HealthKit
        healthStore.save(waterSample) { success, error in
            DispatchQueue.main.async {
                isLogging = false
                
                if success {
                    // Successful, dismiss
                    dismiss()
                } else {
                    // Failed to save to HealthKit, but we already logged locally
                    dismiss()
                }
            }
        }
    }
    
    // Log water locally (as backup when HealthKit is not available)
    private func logWaterLocally(ounces: Double) {
        let userDefaults = UserDefaults.standard
        
        // Get the current water log history (if any)
        var waterLogs = userDefaults.array(forKey: "WaterLogs") as? [[String: Any]] ?? []
        
        // Add the new water log
        let newLog: [String: Any] = [
            "ounces": ounces,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        waterLogs.append(newLog)
        
        // Save the updated array
        userDefaults.set(waterLogs, forKey: "WaterLogs")
    }
} 