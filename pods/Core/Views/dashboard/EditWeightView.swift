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
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    @State private var selectedDate = Date()
    @State private var weightText = ""
    @FocusState private var isWeightFieldFocused: Bool
    @State private var selectedPhoto: UIImage? = nil
    @State private var showingProgressCamera = false
    @State private var showImagePicker = false
    
    // Completion handler to navigate after saving
    var onWeightSaved: (() -> Void)?
    
    // Apple Health sync awareness
    @StateObject private var weightSyncService = WeightSyncService.shared
    @State private var showAppleHealthTip = false
    
    // Computed properties for unit display
    private var weightUnit: String {
        switch viewModel.unitsSystem {
        case .imperial:
            return "lbs"
        case .metric:
            return "kg"
        }
    }
    
    private var weightPlaceholder: String {
        switch viewModel.unitsSystem {
        case .imperial:
            return "Enter weight in lbs"
        case .metric:
            return "Enter weight in kg"
        }
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
                    
                    // Photo Row (only show if photo is selected)
                    if let photo = selectedPhoto {
                        Divider()
                            .padding(.horizontal, 16)
                        
                        HStack {
                            Text("Photo")
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                // Delete button (minus circle to the left)
                                Button(action: {
                                    selectedPhoto = nil
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.red)
                                }
                                
                                Image(uiImage: photo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    // 👉 Let the user retake / choose a new photo
                                    .onTapGesture { showingProgressCamera = true }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .background(Color("iosnp"))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Add Photo Button (only show if no photo is selected)
                if selectedPhoto == nil {
                    Menu {
                        Button(action: {
                            showingProgressCamera = true
                        }) {
                            HStack {
                                Text("Camera")
                                Spacer()
                                Image(systemName: "camera")
                            }
                        }
                        
                        Button(action: {
                            showImagePicker = true
                        }) {
                            HStack {
                                Text("Photos")
                                Spacer()
                                Image(systemName: "photo")
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "camera")
                                .font(.system(size: 17))
                            
                            Text("Add Photo")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("iosnp"))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                
                Spacer()
            }
            .background(Color("iosbg"))
            .navigationBarTitle("Weight", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.accentColor),
                trailing: Button("Add") {
                    saveWeight()
                    dismiss()
                    onWeightSaved?()
                }
                .foregroundColor(.accentColor)
                .disabled(weightText.isEmpty)
            )
        }
        .safeAreaInset(edge: .bottom) {
            // Apple Health sync tip
            if HealthKitManager.shared.isHealthDataAvailable && showAppleHealthTip {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.text.square")
                            .foregroundColor(.pink)
                            .font(.system(size: 16))
                        
                        Text("Weight data from your scale automatically syncs from Apple Health")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Button("Dismiss") {
                            showAppleHealthTip = false
                            UserDefaults.standard.set(true, forKey: "hasSeenAppleHealthWeightTip")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("iosnp"))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .background(Color("iosbg"))
            }
        }
        .onAppear {
            // Initialize with current weight if available
            if vm.weight > 0 {
                switch viewModel.unitsSystem {
                case .imperial:
                    let weightLbs = vm.weight * 2.20462
                    weightText = String(format: "%.1f", weightLbs)
                case .metric:
                    weightText = String(format: "%.1f", vm.weight)
                }
            }
            
            // Automatically focus the weight field to show numpad
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isWeightFieldFocused = true
            }
            
            // Show Apple Health tip if user hasn't seen it and HealthKit is available
            if HealthKitManager.shared.isHealthDataAvailable && 
               !UserDefaults.standard.bool(forKey: "hasSeenAppleHealthWeightTip") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showAppleHealthTip = true
                }
            }
        }
        .fullScreenCover(isPresented: $showingProgressCamera) {
            CameraProgressView(selectedPhoto: $selectedPhoto)
        }
        .sheet(isPresented: $showImagePicker) {
            CustomImagePicker(selectedPhoto: $selectedPhoto, sourceType: .photoLibrary, showGalleryButton: .constant(true)) {
                // Photo selected, no additional action needed
            }
        }
    }
    
    private func saveWeight() {
        guard let inputWeight = Double(weightText) else {
            print("Error: Invalid weight value")
            return
        }
        
        // Convert input to kg for storage (backend always stores in kg)
        let weightInKg: Double
        let weightInLbs: Double
        
        switch viewModel.unitsSystem {
        case .imperial:
            // Input is in lbs, convert to kg
            weightInKg = inputWeight / 2.20462
            weightInLbs = inputWeight
        case .metric:
            // Input is in kg, convert to lbs for storage
            weightInKg = inputWeight
            weightInLbs = inputWeight * 2.20462
        }
        
        // Save both units to UserDefaults
        UserDefaults.standard.set(weightInLbs, forKey: "weightPounds")
        UserDefaults.standard.set(weightInKg, forKey: "weightKilograms")
        
        // Update the viewModel (always stored in kg)
        vm.weight = weightInKg
        
        guard let email = UserDefaults.standard.string(forKey: "userEmail") else {
            print("Error: No user email found")
            return
        }
        
        // If there's a photo, upload it first, then create weight log with photo URL
        if let photo = selectedPhoto, let imageData = photo.jpegData(compressionQuality: 0.8) {
            guard let containerName = ConfigurationManager.shared.getValue(forKey: "BLOB_CONTAINER") as? String else {
                print("Error: BLOB_CONTAINER not configured")
                return
            }
            
            let blobName = UUID().uuidString + ".jpg"
            NetworkManager().uploadFileToAzureBlob(containerName: containerName, blobName: blobName, fileData: imageData, contentType: "image/jpeg") { success, url in
                if success, let imageUrl = url {
                    print("Photo uploaded successfully: \(imageUrl)")
                    
                    // Now create the weight log with the photo URL
                    self.createWeightLogWithPhoto(email: email, weightInKg: weightInKg, photoUrl: imageUrl)
                } else {
                    print("Failed to upload photo")
                    // Still create weight log without photo
                    self.createWeightLogWithoutPhoto(email: email, weightInKg: weightInKg)
                }
            }
        } else {
            // No photo, create weight log directly
            createWeightLogWithoutPhoto(email: email, weightInKg: weightInKg)
        }
    }
    
    private func createWeightLogWithPhoto(email: String, weightInKg: Double, photoUrl: String) {
        // Use the updated logWeight function that accepts photo URL
        NetworkManagerTwo.shared.logWeight(
            userEmail: email,
            weightKg: weightInKg,
            notes: "Logged from dashboard",
            photoUrl: photoUrl
        ) { result in
            switch result {
            case .success(let response):
                print("Weight successfully logged with photo: \(response.weightKg) kg")
                
                // Post notification to refresh health data
                NotificationCenter.default.post(name: Notification.Name("WeightLoggedNotification"), object: nil)
                
            case .failure(let error):
                print("Error logging weight with photo: \(error.localizedDescription)")
            }
        }
    }
    
    private func createWeightLogWithoutPhoto(email: String, weightInKg: Double) {
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

