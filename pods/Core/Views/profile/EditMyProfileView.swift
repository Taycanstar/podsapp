//
//  EditMyProfileView.swift
//  Pods
//
//  Created by Dimi Nunez on 7/5/25.
//

import SwiftUI

struct EditMyProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var onboarding: OnboardingViewModel
    @Binding var isAuthenticated: Bool
    
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var showEditName = false
    @State private var showEditUsername = false
    @State private var showingPhotoActionSheet = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var selectedPhoto: UIImage?
    @State private var isUploadingPhoto = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Profile picture section - pushed to top
            VStack(spacing: 16) {
                // Profile Picture
                Button(action: {
                    showingPhotoActionSheet = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                        
                        // Show selected photo if available
                        if let selectedPhoto = selectedPhoto {
                            Image(uiImage: selectedPhoto)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else if let profileData = onboarding.profileData {
                            if profileData.profilePhoto == "pfp" {
                                // Use asset image
                                Image("pfp")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            } else if !profileData.profilePhoto.isEmpty {
                                // Use URL image
                                AsyncImage(url: URL(string: profileData.profilePhoto)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    // Default profile icon while loading
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray.opacity(0.6))
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                            } else {
                                // Default profile icon
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                        } else {
                            // Default profile icon
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        
                        // Loading overlay
                        if isUploadingPhoto {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 120, height: 120)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Edit photo or avatar button
                Button(action: {
                    showingPhotoActionSheet = true
                }) {
                    Text("Edit photo or avatar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                .padding(.bottom, 32)
            }
            .padding(.top, 20)
            
            // About you section
            VStack(alignment: .leading, spacing: 0) {
                // Name field
                VStack(spacing: 0) {
                    HStack {
                        Text("Name")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(name.isEmpty ? "Enter name" : name)
                            .font(.system(size: 17))
                            .foregroundColor(name.isEmpty ? .secondary : .primary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .onTapGesture {
                        showEditName = true
                    }
                    
                    Divider()
                        .padding(.leading, 20)
                }
                
                // Username field
                VStack(spacing: 0) {
                    HStack {
                        Text("Username")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(username.isEmpty ? "Enter username" : username)
                            .font(.system(size: 17))
                            .foregroundColor(username.isEmpty ? .secondary : .primary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .onTapGesture {
                        showEditUsername = true
                    }
                }
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize with current values
            if let profileData = onboarding.profileData {
                name = profileData.name
                username = profileData.username
            } else {
                name = onboarding.name ?? ""
                username = onboarding.username
            }
        }
        .actionSheet(isPresented: $showingPhotoActionSheet) {
            ActionSheet(
                title: Text("Change Profile Photo"),
                buttons: [
                    .default(Text("Take Photo")) {
                        showingCamera = true
                    },
                    .default(Text("Upload Photo")) {
                        showingPhotoLibrary = true
                    },
                    .cancel()
                ]
            )
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ProfileImagePicker(selectedImage: $selectedPhoto, sourceType: .camera)
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            ProfileImagePicker(selectedImage: $selectedPhoto, sourceType: .photoLibrary)
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            if let photo = newPhoto {
                uploadPhoto(photo)
            }
        }

        .background(
            VStack {
                NavigationLink(
                    destination: EditNameView(),
                    isActive: $showEditName,
                    label: { EmptyView() }
                )
                
                NavigationLink(
                    destination: EditUsernameView(),
                    isActive: $showEditUsername,
                    label: { EmptyView() }
                )
                

            }
            .hidden()
        )
    }
    
    private func uploadPhoto(_ photo: UIImage) {
        guard let imageData = photo.jpegData(compressionQuality: 0.8) else {
            print("Failed to process the selected photo")
            return
        }
        
        isUploadingPhoto = true
        
        // Upload photo and update profile
        NetworkManagerTwo.shared.uploadAndUpdateProfilePhoto(
            email: onboarding.email,
            imageData: imageData
        ) { result in
            DispatchQueue.main.async {
                isUploadingPhoto = false
                
                switch result {
                case .success(let photoUrl):
                    // Update local profile data
                    if var profileData = onboarding.profileData {
                        profileData.profilePhoto = photoUrl
                        onboarding.profileData = profileData
                    }
                    print("✅ Profile photo updated successfully: \(photoUrl)")
                    
                    // Clear the selected photo since it's now saved
                    selectedPhoto = nil
                    
                case .failure(let error):
                    print("❌ Failed to update profile photo: \(error)")
                    // Keep the selected photo visible on error so user can retry
                }
            }
        }
    }
}

// MARK: - Profile Image Picker (specific to this view)
struct ProfileImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.modalPresentationStyle = .fullScreen
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ProfileImagePicker
        
        init(_ parent: ProfileImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    EditMyProfileView(isAuthenticated: .constant(true))
}
