//
//  EditHeightView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/16/25.
//

import SwiftUI

struct EditHeightView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var vm: DayLogsViewModel
    
    @State private var selectedDate = Date()
    @State private var selectedFeet = 5
    @State private var selectedInches = 9
    @State private var showingHeightPicker = false
    
    // Available ranges
    let feetRange = 2...8
    let inchesRange = 0...11
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Combined Date and Height Card
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
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Height Button Row
                    Button(action: {
                        showingHeightPicker = true
                    }) {
                        HStack {
                            Text("ft")
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(selectedFeet)' \(selectedInches)\"")
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(Color("iosnp"))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
            }
            .background(Color("iosbg"))
            .navigationBarTitle("Height", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.accentColor),
                trailing: Button("Add") {
                    saveHeight()
                    dismiss()
                }
                .foregroundColor(.accentColor)
            )
        }
        .sheet(isPresented: $showingHeightPicker) {
            HeightPickerView(
                selectedFeet: $selectedFeet,
                selectedInches: $selectedInches,
                feetRange: feetRange,
                inchesRange: inchesRange
            )
        }
        .onAppear {
            // Initialize with current height if available
            if vm.height > 0 {
                // Calculate imperial values
                let totalInches = vm.height / 2.54
                selectedFeet = Int(totalInches / 12)
                selectedInches = Int(totalInches.truncatingRemainder(dividingBy: 12).rounded())
            }
        }
    }
    
    private func saveHeight() {
        // Convert imperial to metric
        let totalInches = (selectedFeet * 12) + selectedInches
        let heightInCm = Double(totalInches) * 2.54
        
        // Save to UserDefaults
        UserDefaults.standard.set(selectedFeet, forKey: "heightFeet")
        UserDefaults.standard.set(selectedInches, forKey: "heightInches")
        UserDefaults.standard.set(heightInCm, forKey: "heightCentimeters")
        
        // Update the viewModel
        vm.height = heightInCm
        
        // Call API to log height using NetworkManagerTwo
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("Error: No user email found")
            return
        }
        
        NetworkManagerTwo.shared.logHeight(
            userEmail: email,
            heightCm: heightInCm,
            notes: "Logged from dashboard"
        ) { result in
            switch result {
            case .success(let response):
                print("Height successfully logged: \(response.heightCm) cm")
                
                // Post notification to refresh health data
                NotificationCenter.default.post(name: Notification.Name("HeightLoggedNotification"), object: nil)
                
            case .failure(let error):
                print("Error logging height: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Height Picker View
struct HeightPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedFeet: Int
    @Binding var selectedInches: Int
    let feetRange: ClosedRange<Int>
    let inchesRange: ClosedRange<Int>
    
    var body: some View {
        NavigationView {
            VStack {
                HStack(spacing: 0) {
                    // Feet Picker
                    Picker("Feet", selection: $selectedFeet) {
                        ForEach(feetRange, id: \.self) { feet in
                            Text("\(feet) ft").tag(feet)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(maxWidth: .infinity)
                    
                    // Inches Picker
                    Picker("Inches", selection: $selectedInches) {
                        ForEach(inchesRange, id: \.self) { inches in
                            Text("\(inches) in").tag(inches)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(maxWidth: .infinity)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Height")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.accentColor),
                trailing: Button("Done") {
                    dismiss()
                }
                .foregroundColor(.accentColor)
            )
        }
    }
}
