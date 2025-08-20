//
//  EditProfilePhotoView.swift
//  Pods
//
//  Created by Dimi Nunez on 7/6/25.
//

import SwiftUI
import PhotosUI

struct EditProfilePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var onboarding: OnboardingViewModel
    
    @State private var selectedPhoto: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showActionSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Current photo display
            VStack(spacing: 20) {
                // Profile photo display
                ZStack {
                    if let selectedPhoto = selectedPhoto {
                        Image(uiImage: selectedPhoto)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else if let profileData = onboarding.profileData, 
                              !profileData.profilePhoto.isEmpty,
                              profileData.profilePhoto != "pfp" {
                        AsyncImage(url: URL(string: profileData.profilePhoto)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 40))
                                )
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 40))
                            )
                    }
                    
                    // Loading overlay
                    if isLoading {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 120, height: 120)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
                
                // Change photo button
                Button(action: {
                    showActionSheet = true
                }) {
                    Text("Change Photo")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color("iosfit"))
                        .cornerRadius(8)
                }
                .disabled(isLoading)
                
                if selectedPhoto != nil {
                    Text("Tap Save to update your profile photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.top, 40)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Profile Photo")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    savePhoto()
                }
                .disabled(selectedPhoto == nil || isLoading)
                .foregroundColor(selectedPhoto == nil ? .secondary : .accentColor)
            }
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("Change Profile Photo"),
                buttons: [
                    .default(Text("Take Photo")) {
                        showingCamera = true
                    },
                    .default(Text("Choose from Library")) {
                        showingPhotoLibrary = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingCamera) {
            ProfileImagePicker(selectedImage: $selectedPhoto, sourceType: .camera)
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            ProfileImagePicker(selectedImage: $selectedPhoto, sourceType: .photoLibrary)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func savePhoto() {
        guard let photo = selectedPhoto,
              let imageData = photo.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process the selected photo"
            showError = true
            return
        }
        
        isLoading = true
        
        // Upload photo and update profile
        NetworkManagerTwo.shared.uploadAndUpdateProfilePhoto(
            email: onboarding.email,
            imageData: imageData
        ) { result in
            Task { @MainActor in
                isLoading = false
                
                switch result {
                case .success(let photoUrl):
                    // Update local profile data
                    if var profileData = onboarding.profileData {
                        profileData.profilePhoto = photoUrl
                        onboarding.profileData = profileData
                    }
                    
                    // Dismiss the view
                    dismiss()
                    
                case .failure(let error):
                    if let networkError = error as? NetworkError,
                       case .serverError(let message) = networkError {
                        errorMessage = message
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showError = true
                }
            }
        }
    }
}



#Preview {
    NavigationView {
        EditProfilePhotoView()
            .environmentObject(OnboardingViewModel())
    }
}


