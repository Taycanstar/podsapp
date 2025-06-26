//
//  UpdateEditHeightView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/25/25.
//

import SwiftUI

struct UpdateEditHeightView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let heightLog: HeightLogResponse
    @State private var selectedDate: Date
    @State private var feetText: String
    @State private var inchesText: String
    @FocusState private var isFeetFieldFocused: Bool
    @FocusState private var isInchesFieldFocused: Bool
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    init(heightLog: HeightLogResponse) {
        self.heightLog = heightLog
        
        // Initialize date from the log
        let date = ISO8601DateFormatter().date(from: heightLog.dateLogged) ?? Date()
        _selectedDate = State(initialValue: date)
        
        // Convert height from cm to feet and inches
        let totalInches = heightLog.heightCm / 2.54
        let feet = Int(totalInches / 12)
        let inches = totalInches.truncatingRemainder(dividingBy: 12)
        
        _feetText = State(initialValue: String(feet))
        _inchesText = State(initialValue: String(format: "%.1f", inches))
    }
    
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
                    
                    // Height Input Row
                    HStack {
                        Text("Height")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            TextField("", text: $feetText)
                                .keyboardType(.numberPad)
                                .focused($isFeetFieldFocused)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                                .frame(width: 40)
                            
                            Text("ft")
                                .font(.system(size: 17))
                                .foregroundColor(.secondary)
                            
                            TextField("", text: $inchesText)
                                .keyboardType(.decimalPad)
                                .focused($isInchesFieldFocused)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                                .frame(width: 40)
                            
                            Text("in")
                                .font(.system(size: 17))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color("iosnp"))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Delete Log Button
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 17))
                        
                        Text("Delete Log")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color("iosnp"))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                Spacer()
            }
            .background(Color("iosbg"))
            .navigationBarTitle("Edit Height", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.accentColor),
                trailing: Button("Save") {
                    saveHeight()
                }
                .foregroundColor(.accentColor)
                .disabled(feetText.isEmpty || inchesText.isEmpty || isDeleting)
            )
        }
        .alert("Delete Height Log", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteHeightLog()
            }
        } message: {
            Text("Are you sure you want to delete this height log? This action cannot be undone.")
        }
    }
    
    private func saveHeight() {
        guard let feet = Int(feetText), let inches = Double(inchesText) else {
            print("Error: Invalid height values")
            return
        }
        
        // Convert to cm
        let totalInches = Double(feet * 12) + inches
        let heightInCm = totalInches * 2.54
        
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("Error: No user email found")
            return
        }
        
        // TODO: Implement update height log API call
        print("Updating height log with ID: \(heightLog.id)")
        print("New height: \(heightInCm) cm")
        print("New date: \(selectedDate)")
        
        dismiss()
    }
    
    private func deleteHeightLog() {
        isDeleting = true
        
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("Error: No user email found")
            isDeleting = false
            return
        }
        
        NetworkManagerTwo.shared.deleteHeightLog(logId: heightLog.id) { result in
            DispatchQueue.main.async {
                self.isDeleting = false
                
                switch result {
                case .success:
                    print("✅ Height log deleted successfully")
                    // Post notification to refresh the height data view
                    NotificationCenter.default.post(name: Notification.Name("HeightLogDeletedNotification"), object: nil)
                    self.dismiss()
                    
                case .failure(let error):
                    print("❌ Error deleting height log: \(error)")
                    // TODO: Show error alert to user
                }
            }
        }
    }
}

#Preview {
    UpdateEditHeightView(heightLog: HeightLogResponse(
        id: 1,
        heightCm: 175.0,
        dateLogged: "2024-01-15T10:30:00.000Z",
        notes: "Test note"
    ))
}
