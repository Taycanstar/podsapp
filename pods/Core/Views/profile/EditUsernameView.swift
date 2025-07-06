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
    @State private var canChangeUsername: Bool = true
    @State private var daysRemaining: Int = 0
    @State private var isCheckingEligibility: Bool = false
    @State private var isUsernameAvailable: Bool? = nil
    @State private var usernameAvailabilityError: String = ""
    @State private var isCheckingAvailability: Bool = false
    @State private var originalUsername: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Input field with availability indicator
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Enter your username", text: $username)
                        .font(.system(size: 17))
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .disabled(isLoading)
                        .onChange(of: username) { _, newValue in
                            checkUsernameAvailability(newValue)
                        }
                    
                    // Availability indicator
                    if isCheckingAvailability {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if username.trimmingCharacters(in: .whitespacesAndNewlines) != originalUsername && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let isAvailable = isUsernameAvailable {
                            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isAvailable ? .green : .red)
                                .font(.system(size: 20))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color("tiktoknp"))
                .cornerRadius(8)
                
                                Text("Your username can contain letters, numbers, underscores, and periods.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !canChangeUsername && daysRemaining > 0 {
                    Text("You can change your username again in \(daysRemaining) day\(daysRemaining == 1 ? "" : "s").")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("You can change your username once every 30 days.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Username availability error
                if !usernameAvailabilityError.isEmpty && username.trimmingCharacters(in: .whitespacesAndNewlines) != originalUsername {
                    Text(usernameAvailabilityError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
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
                .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || !canChangeUsername || isUsernameAvailable == false)
                .foregroundColor((username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canChangeUsername || isUsernameAvailable == false) ? .secondary : .accentColor)
            }
        }
        .onAppear {
            // Initialize with current username
            if let profileData = onboarding.profileData {
                username = profileData.username
                originalUsername = profileData.username
            } else {
                username = onboarding.username
                originalUsername = onboarding.username
            }
            
            // Check username eligibility
            checkUsernameEligibility()
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
    
    private func checkUsernameEligibility() {
        isCheckingEligibility = true
        
        NetworkManagerTwo.shared.checkUsernameEligibility(email: onboarding.email) { result in
            DispatchQueue.main.async {
                isCheckingEligibility = false
                
                switch result {
                case .success(let eligibility):
                    canChangeUsername = eligibility.canChangeUsername
                    daysRemaining = eligibility.daysRemaining
                    
                case .failure(let error):
                    print("Failed to check username eligibility: \(error)")
                    // Default to allowing change if we can't check
                    canChangeUsername = true
                    daysRemaining = 0
                }
            }
        }
    }
    
    private func checkUsernameAvailability(_ newUsername: String) {
        let trimmedUsername = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Reset state if username is empty or same as original
        if trimmedUsername.isEmpty || trimmedUsername == originalUsername {
            isUsernameAvailable = nil
            usernameAvailabilityError = ""
            isCheckingAvailability = false
            return
        }
        
        // Don't check if username is too short (less than 3 characters)
        if trimmedUsername.count < 3 {
            isUsernameAvailable = false
            usernameAvailabilityError = "Username must be at least 3 characters long"
            isCheckingAvailability = false
            return
        }
        
        // Debounce the API call
        isCheckingAvailability = true
        usernameAvailabilityError = ""
        isUsernameAvailable = nil
        
        // Cancel previous request and start new one after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Only proceed if the username hasn't changed
            if trimmedUsername == self.username.trimmingCharacters(in: .whitespacesAndNewlines) {
                self.performUsernameCheck(trimmedUsername)
            }
        }
    }
    
    private func performUsernameCheck(_ username: String) {
        NetworkManagerTwo.shared.checkUsernameAvailability(username: username, email: onboarding.email) { result in
            DispatchQueue.main.async {
                // Only update if this is still the current username
                if username == self.username.trimmingCharacters(in: .whitespacesAndNewlines) {
                    self.isCheckingAvailability = false
                    
                    switch result {
                    case .success(let response):
                        self.isUsernameAvailable = response.available
                        self.usernameAvailabilityError = response.error ?? ""
                        
                    case .failure(let error):
                        print("❌ Error checking username availability: \(error)")
                        self.isUsernameAvailable = false
                        if let networkError = error as? NetworkError,
                           case .serverError(let message) = networkError {
                            self.usernameAvailabilityError = message
                        } else {
                            self.usernameAvailabilityError = "Error checking username availability"
                        }
                    }
                }
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
        
        guard canChangeUsername else {
            errorMessage = "You can only change your username once every 30 days. Please wait \(daysRemaining) more day\(daysRemaining == 1 ? "" : "s")."
            showError = true
            return
        }
        
        // Basic validation for username format - updated to allow periods
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_."))
        guard trimmedUsername.unicodeScalars.allSatisfy({ validCharacters.contains($0) }) else {
            errorMessage = "Username can only contain letters, numbers, underscores, and periods"
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
