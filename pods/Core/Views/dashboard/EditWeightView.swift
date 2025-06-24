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
    @State private var selectedPhoto: UIImage? = nil
    @State private var showingProgressCamera = false
    @State private var image: Image? = nil
    @State private var showImagePicker = false
    @State private var showCamera = false
    
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
                            .keyboardType(.numberPad)
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
                                Image(uiImage: photo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                // Delete button
                                Button(action: {
                                    selectedPhoto = nil
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                }
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
                    Button(action: {
                        showingProgressCamera = true
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
        .fullScreenCover(isPresented: $showingProgressCamera) {
            CameraProgressView(selectedPhoto: $selectedPhoto)
        }
        .sheet(isPresented: $showImagePicker) {
            CustomImagePicker(selectedPhoto: $selectedPhoto, sourceType: .photoLibrary) {
                // Photo selected, no additional action needed
            }
        }
        .sheet(isPresented: $showCamera) {
            CustomImagePicker(selectedPhoto: $selectedPhoto, sourceType: .camera) {
                // Photo selected, no additional action needed
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
        
        if let photo = selectedPhoto, let imageData = photo.jpegData(compressionQuality: 0.8) {
            let containerName = "your-container-name"
            let blobName = UUID().uuidString + ".jpg"
            NetworkManager().uploadFileToAzureBlob(containerName: containerName, blobName: blobName, fileData: imageData, contentType: "image/jpeg") { success, url in
                if success, let imageUrl = url {
                    print("Photo uploaded successfully: \(imageUrl)")
                    // Update the database with the imageUrl
                    NetworkManagerTwo.shared.updateWeightLogWithPhotoUrl(userEmail: email, weightKg: weightInKg, photoUrl: imageUrl) { result in
                        switch result {
                        case .success:
                            print("Weight log updated with photo URL")
                        case .failure(let error):
                            print("Failed to update weight log with photo URL: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("Failed to upload photo")
                }
            }
        }
    }
}

