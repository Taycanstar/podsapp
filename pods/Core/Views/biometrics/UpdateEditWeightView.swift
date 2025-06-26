//
//  UpdateEditWeightView.swift
//  Pods
//
//  Created by Dimi Nunez on 6/25/25.
//

import SwiftUI

struct UpdateEditWeightView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let weightLog: WeightLogResponse
    @State private var selectedDate: Date
    @State private var weightText: String
    @FocusState private var isWeightFieldFocused: Bool
    @State private var selectedPhoto: UIImage? = nil
    @State private var showingProgressCamera = false
    @State private var showingFullScreenPhoto = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    init(weightLog: WeightLogResponse) {
        self.weightLog = weightLog
        
        // Initialize date from the log
        let date = ISO8601DateFormatter().date(from: weightLog.dateLogged) ?? Date()
        _selectedDate = State(initialValue: date)
        
        // Initialize weight text (convert kg to lbs)
        let weightLbs = weightLog.weightKg * 2.20462
        _weightText = State(initialValue: String(format: "%.1f", weightLbs))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Combined Date and Weight Card
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
                    
                    // Weight Input Row
                    HStack {
                        Text("lbs")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        TextField("", text: $weightText)
                            .keyboardType(.decimalPad)
                            .focused($isWeightFieldFocused)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    // Photo Row
                    Divider()
                        .padding(.horizontal, 16)
                    
                    HStack {
                        Text("Photo")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if let photoUrl = weightLog.photo, !photoUrl.isEmpty {
                            // Show existing photo
                            Button(action: {
                                showingFullScreenPhoto = true
                            }) {
                                AsyncImage(url: URL(string: photoUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        )
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        } else {
                            // Show camera button for adding photo
                            Button(action: {
                                showingProgressCamera = true
                            }) {
                                Image(systemName: "camera")
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, height: 50)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
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
            .navigationBarTitle("Edit Weight", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.accentColor),
                trailing: Button("Save") {
                    saveWeight()
                }
                .foregroundColor(.accentColor)
                .disabled(weightText.isEmpty || isDeleting)
            )
        }
        .fullScreenCover(isPresented: $showingProgressCamera) {
            CameraProgressView(selectedPhoto: $selectedPhoto)
        }
        .fullScreenCover(isPresented: $showingFullScreenPhoto) {
            if let photoUrl = weightLog.photo, !photoUrl.isEmpty {
                FullScreenPhotoView(photoUrl: photoUrl)
            }
        }
        .alert("Delete Weight Log", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteWeightLog()
            }
        } message: {
            Text("Are you sure you want to delete this weight log? This action cannot be undone.")
        }
    }
    
    private func saveWeight() {
        guard let weightLbs = Double(weightText) else {
            print("Error: Invalid weight value")
            return
        }
        
        // Convert pounds to kg for storage
        let weightInKg = weightLbs / 2.20462
        
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("Error: No user email found")
            return
        }
        
        // TODO: Implement update weight log API call
        print("Updating weight log with ID: \(weightLog.id)")
        print("New weight: \(weightInKg) kg")
        print("New date: \(selectedDate)")
        
        dismiss()
    }
    
    private func deleteWeightLog() {
        isDeleting = true
        
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("Error: No user email found")
            isDeleting = false
            return
        }
        
        NetworkManagerTwo.shared.deleteWeightLog(logId: weightLog.id) { result in
            DispatchQueue.main.async {
                self.isDeleting = false
                
                switch result {
                case .success:
                    print("✅ Weight log deleted successfully")
                    // Post notification to refresh the weight data view
                    NotificationCenter.default.post(name: Notification.Name("WeightLogDeletedNotification"), object: nil)
                    self.dismiss()
                    
                case .failure(let error):
                    print("❌ Error deleting weight log: \(error)")
                    // TODO: Show error alert to user
                }
            }
        }
    }
}

struct FullScreenPhotoView: View {
    @Environment(\.dismiss) var dismiss
    let photoUrl: String
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: URL(string: photoUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                Spacer()
            }
        }
    }
}

#Preview {
    UpdateEditWeightView(weightLog: WeightLogResponse(
        id: 1,
        weightKg: 70.0,
        dateLogged: "2024-01-15T10:30:00.000Z",
        notes: "Test note",
        photo: "https://example.com/photo.jpg"
    ))
}
