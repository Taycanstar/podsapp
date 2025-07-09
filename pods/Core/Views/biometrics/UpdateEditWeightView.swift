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
    @EnvironmentObject var viewModel: OnboardingViewModel
    
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
    
    // Computed properties for unit display
    private var weightUnit: String {
        switch viewModel.unitsSystem {
        case .imperial:
            return "lbs"
        case .metric:
            return "kg"
        }
    }
    
    init(weightLog: WeightLogResponse) {
        self.weightLog = weightLog
        
        // Initialize date from the log with robust parsing
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        print("📅 UpdateEditWeightView: Parsing date from log: \(weightLog.dateLogged)")
        
        var date: Date
        if let parsedDate = formatter.date(from: weightLog.dateLogged) {
            date = parsedDate
            print("📅 UpdateEditWeightView: Successfully parsed date: \(date)")
        } else {
            // Fallback: try without fractional seconds
            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]
            
            if let fallbackDate = fallbackFormatter.date(from: weightLog.dateLogged) {
                date = fallbackDate
                print("📅 UpdateEditWeightView: Parsed with fallback formatter: \(date)")
            } else {
                // Last resort: use current date
                date = Date()
                print("📅 UpdateEditWeightView: Failed to parse date, using current date: \(date)")
            }
        }
        
        _selectedDate = State(initialValue: date)
        
        // Initialize weight text based on user's unit preference
        let displayWeight: Double
        if UserDefaults.standard.bool(forKey: "isImperial") {
            displayWeight = weightLog.weightKg * 2.20462 // Convert to lbs
        } else {
            displayWeight = weightLog.weightKg // Keep in kg
        }
        _weightText = State(initialValue: String(format: "%.1f", displayWeight))
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
                        Text(weightUnit)
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
                        
                        if let newPhoto = selectedPhoto {
                            // Show newly selected photo (prioritized over existing)
                            HStack(spacing: 12) {
                                // Delete button for new photo
                                Button(action: {
                                    selectedPhoto = nil
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.red)
                                }
                                
                                // Newly selected photo with tap to retake
                                Button(action: {
                                    showingProgressCamera = true
                                }) {
                                    Image(uiImage: newPhoto)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        } else if let photoUrl = weightLog.photo, !photoUrl.isEmpty {
                            // Show existing photo with tap to replace
                            Button(action: {
                                showingProgressCamera = true
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
        guard let inputWeight = Double(weightText) else {
            print("Error: Invalid weight value")
            return
        }
        
        // Convert input to kg for storage based on user's unit preference
        let weightInKg: Double
        switch viewModel.unitsSystem {
        case .imperial:
            // Input is in lbs, convert to kg
            weightInKg = inputWeight / 2.20462
        case .metric:
            // Input is in kg, keep as kg
            weightInKg = inputWeight
        }
        
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("Error: No user email found")
            return
        }
        
        // If there's a newly selected photo, upload it first
        if let newPhoto = selectedPhoto, let imageData = newPhoto.jpegData(compressionQuality: 0.8) {
            guard let containerName = ConfigurationManager.shared.getValue(forKey: "BLOB_CONTAINER") as? String else {
                print("Error: BLOB_CONTAINER not configured")
                return
            }
            
            let blobName = UUID().uuidString + ".jpg"
            NetworkManager().uploadFileToAzureBlob(containerName: containerName, blobName: blobName, fileData: imageData, contentType: "image/jpeg") { success, url in
                if success, let imageUrl = url {
                    print("New photo uploaded successfully: \(imageUrl)")
                    self.updateWeightLogWithPhoto(email: email, weightInKg: weightInKg, photoUrl: imageUrl)
                } else {
                    print("Failed to upload new photo")
                    // Update without new photo (keep existing photo if any)
                    self.updateWeightLogWithoutPhoto(email: email, weightInKg: weightInKg)
                }
            }
        } else {
            // No new photo selected, update with existing photo URL
            updateWeightLogWithoutPhoto(email: email, weightInKg: weightInKg)
        }
    }
    
    private func updateWeightLogWithPhoto(email: String, weightInKg: Double, photoUrl: String) {
        NetworkManagerTwo.shared.updateWeightLog(
            logId: weightLog.id,
            userEmail: email,
            weightKg: weightInKg,
            dateLogged: selectedDate,
            notes: weightLog.notes,
            photoUrl: photoUrl
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("Weight log updated successfully with new photo: \(response.weightKg) kg")
                    // Post notification to refresh weight data
                    NotificationCenter.default.post(name: Notification.Name("WeightLogUpdatedNotification"), object: nil, userInfo: ["updatedLog": response])
                    self.dismiss()
                    
                case .failure(let error):
                    print("Error updating weight log with photo: \(error.localizedDescription)")
                    // TODO: Show error alert to user
                }
            }
        }
    }
    
    private func updateWeightLogWithoutPhoto(email: String, weightInKg: Double) {
        NetworkManagerTwo.shared.updateWeightLog(
            logId: weightLog.id,
            userEmail: email,
            weightKg: weightInKg,
            dateLogged: selectedDate,
            notes: weightLog.notes,
            photoUrl: weightLog.photo // Keep existing photo URL
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("Weight log updated successfully: \(response.weightKg) kg")
                    // Post notification to refresh weight data
                    NotificationCenter.default.post(name: Notification.Name("WeightLogUpdatedNotification"), object: nil, userInfo: ["updatedLog": response])
                    self.dismiss()
                    
                case .failure(let error):
                    print("Error updating weight log: \(error.localizedDescription)")
                    // TODO: Show error alert to user
                }
            }
        }
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
    let photoUrl: String?
    let preloadedImage: UIImage?
    
    init(photoUrl: String) {
        self.photoUrl = photoUrl
        self.preloadedImage = nil
    }
    
    init(preloadedImage: UIImage) {
        self.photoUrl = nil
        self.preloadedImage = preloadedImage
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let preloadedImage = preloadedImage {
                Image(uiImage: preloadedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let photoUrl = photoUrl {
                AsyncImage(url: URL(string: photoUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
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