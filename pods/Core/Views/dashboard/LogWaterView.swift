import SwiftUI
import HealthKit

struct LogWaterView: View {
    @Environment(\.dismiss) var dismiss
    @State private var waterAmount: String = ""
    @State private var isLogging: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @FocusState private var isInputFocused: Bool
    
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
                }
                .padding()
                .background(Color("iosnp"))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 16)
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
    
    private func logWater() {
        guard let amount = Double(waterAmount),
              amount > 0 else {
            alertMessage = "Please enter a valid amount"
            showAlert = true
            return
        }
        
        isLogging = true
        
        // Convert from ounces to liters (1 oz = 0.0295735 liters)
        let liters = amount * 0.0295735
        
        // Log to HealthKit if available
        if HKHealthStore.isHealthDataAvailable() {
            let healthStore = HKHealthStore()
            
            // Check if we have permission to write water data
            let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
            
            healthStore.requestAuthorization(toShare: [waterType], read: [waterType]) { success, error in
                if success {
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
                                // Save successful, post notification and dismiss
                                NotificationCenter.default.post(name: NSNotification.Name("WaterLoggedNotification"), object: nil)
                                dismiss()
                            } else {
                                // Show error
                                alertMessage = error?.localizedDescription ?? "Failed to log water"
                                showAlert = true
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        isLogging = false
                        alertMessage = "Health permission denied. Please enable in Settings."
                        showAlert = true
                    }
                }
            }
        } else {
            isLogging = false
            alertMessage = "HealthKit is not available on this device"
            showAlert = true
        }
    }
}
