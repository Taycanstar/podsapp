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
    @State private var showingActionSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Profile picture section - pushed to top
            VStack(spacing: 16) {
                // Profile Picture
                Button(action: {
                    showingActionSheet = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                        
                        if let profileData = onboarding.profileData {
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
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Edit photo or avatar button
                Button(action: {
                    showingActionSheet = true
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
                        // Handle name editing
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
                        // Handle username editing
                    }
                }
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            // Initialize with current values
            if let profileData = onboarding.profileData {
                name = profileData.username // Using username as name for now
                username = profileData.username
            } else {
                name = onboarding.username
                username = onboarding.username
            }
        }
        .confirmationDialog("Change Profile Picture", isPresented: $showingActionSheet, titleVisibility: .visible) {
            Button("Take Photo") {
                // Handle camera action
                print("Take Photo selected")
            }
            
            Button("Upload Photo") {
                // Handle photo library action
                print("Upload Photo selected")
            }
            
            Button("Cancel", role: .cancel) {
                // Cancel action
            }
        }
    }
}

#Preview {
    EditMyProfileView(isAuthenticated: .constant(true))
}
