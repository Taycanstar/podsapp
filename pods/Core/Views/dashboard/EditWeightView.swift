//
//  EditWeightView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/16/25.
//

import SwiftUI

struct EditWeightView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var vm: DayLogsViewModel
    
    @State private var selectedDate = Date()
    @State private var weightText = ""
    @FocusState private var isWeightFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Date Row
                HStack {
                    Text("Date")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Weight Input Row
                HStack {
                    Text("lbs")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    TextField("", text: $weightText)
                        .keyboardType(.numberPad)
                        .focused($isWeightFieldFocused)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Add Photo Button
                Button(action: {
                    // TODO: Handle photo selection
                    print("Add Photo tapped")
                }) {
                    HStack {
                        Image(systemName: "camera")
                            .font(.system(size: 17))
                        
                        Text("Add Photo")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                Spacer()
            }
            .navigationBarTitle("Weight", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.accentColor),
                trailing: Button("Add") {
                    saveWeight()
                    dismiss()
                }
                .foregroundColor(.accentColor)
                .disabled(weightText.isEmpty)
            )
        }
        .onAppear {
            // Initialize with current weight if available
            if vm.weight > 0 {
                let weightLbs = vm.weight * 2.20462
                weightText = String(Int(weightLbs.rounded()))
            }
            
            // Automatically focus the weight field to show numpad
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isWeightFieldFocused = true
            }
        }
    }
    
    private func saveWeight() {
        guard let weightLbs = Double(weightText) else {
            print("Error: Invalid weight value")
            return
        }
        
        // Convert pounds to kg for storage
        let weightInKg = weightLbs / 2.20462
        
        // Save to UserDefaults
        UserDefaults.standard.set(weightLbs, forKey: "weightPounds")
        UserDefaults.standard.set(weightInKg, forKey: "weightKilograms")
        
        // Update the viewModel
        vm.weight = weightInKg
        
        // Call API to log weight using NetworkManagerTwo
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("Error: No user email found")
            return
        }
        
        NetworkManagerTwo.shared.logWeight(
            userEmail: email,
            weightKg: weightInKg,
            notes: "Logged from dashboard"
        ) { result in
            switch result {
            case .success(let response):
                print("Weight successfully logged: \(response.weightKg) kg")
                
                // Post notification to refresh health data
                NotificationCenter.default.post(name: Notification.Name("WeightLoggedNotification"), object: nil)
                
            case .failure(let error):
                print("Error logging weight: \(error.localizedDescription)")
            }
        }
    }
}

