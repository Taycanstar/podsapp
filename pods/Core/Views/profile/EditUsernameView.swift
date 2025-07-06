//
//  EditUsernameView.swift
//  Pods
//
//  Created by Dimi Nunez on 7/5/25.
//

import SwiftUI

struct EditUsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var onboarding: OnboardingViewModel
    
    @State private var username: String = ""
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Input field
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter your username", text: $username)
                    .font(.system(size: 17))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("tiktoknp"))
                    .cornerRadius(8)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .disabled(isLoading)
                
                Text("Your username can contain letters, numbers, underscores, and periods.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    Text("Your can change your username once every 30 days.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Username")
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
                    saveUsername()
                }
                .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .foregroundColor(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
            }
        }
        .onAppear {
            // Initialize with current username
            if let profileData = onboarding.profileData {
                username = profileData.username
            } else {
                username = onboarding.username
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
    
    private func saveUsername() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedUsername.isEmpty else {
            errorMessage = "Username cannot be empty"
            showError = true
            return
        }
        
        // Basic validation for username format
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard trimmedUsername.unicodeScalars.allSatisfy({ validCharacters.contains($0) }) else {
            errorMessage = "Username can only contain letters, numbers, underscores, and hyphens"
            showError = true
            return
        }
        
        isLoading = true
        
        // Call API to update username
        NetworkManagerTwo.shared.updateUsername(email: onboarding.email, username: trimmedUsername) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success:
                    // Update local data
                    onboarding.username = trimmedUsername
                    if var profileData = onboarding.profileData {
                        profileData.username = trimmedUsername
                        onboarding.profileData = profileData
                    }
                    
                    // Dismiss the view
                    dismiss()
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        EditUsernameView()
    }
}
