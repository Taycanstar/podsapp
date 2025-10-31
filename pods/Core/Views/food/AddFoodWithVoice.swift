//
//  AddFoodWithVoice.swift
//  Pods
//
//  Created by Dimi Nunez on 6/28/25.
//

import SwiftUI
import AVFoundation

struct AddFoodWithVoice: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager
    
    // Completion closure to pass voice-created food back to parent
    var onFoodVoiceAdded: (Food) -> Void
    
    @StateObject private var audioRecorder = CreateFoodAudioRecorder()
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color("primarybg"),
                            Color("chat").opacity(0.25)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 24) {
                            VoiceFluidView(
                                level: audioRecorder.audioLevel,
                                samples: audioRecorder.audioSamples,
                                isActive: audioRecorder.isRecording || audioRecorder.isProcessing
                            )
                            .frame(width: min(geometry.size.width * 0.7, 260),
                                   height: min(geometry.size.width * 0.7, 260))
                            .padding(.top, 12)
                            
                            if audioRecorder.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                                    .scaleEffect(1.2)
                                    .padding(.top, 12)
                            }
                            
                            if !audioRecorder.transcribedText.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Preview")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                    
                                    ScrollView {
                                        Text(audioRecorder.transcribedText)
                                            .font(.system(size: 17, weight: .medium, design: .rounded))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(maxHeight: 140)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 20)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .padding(.top, 12)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                        
                        Spacer()
                        
                        // Bottom controls - X and checkmark only
                        HStack {
                            Button(action: {
                                print("X button tapped")
                                if audioRecorder.isRecording {
                                    audioRecorder.stopRecording(cancel: true)
                                }
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 22))
                                    .foregroundColor(.primary)
                                    .frame(width: 60, height: 60)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color(.systemGray3), lineWidth: 1)
                                    )
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                guard !foodManager.isGeneratingFood && !audioRecorder.isProcessing else {
                                    return
                                }
                                
                                if audioRecorder.isRecording {
                                    audioRecorder.stopRecording()
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        createFoodFromVoiceInBackground()
                                    }
                                } else if !audioRecorder.transcribedText.isEmpty {
                                    dismiss()
                                    createFoodFromVoiceInBackground()
                                }
                            }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 24))
                                    .foregroundColor(.primary)
                                    .frame(width: 60, height: 60)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color(.systemGray3), lineWidth: 1)
                                    )
                                    .opacity((foodManager.isGeneratingFood || audioRecorder.isProcessing) ? 0.5 : 1.0)
                            }
                            .disabled(foodManager.isGeneratingFood || audioRecorder.isProcessing)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 24 : 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            print("AddFoodWithVoice appeared")
            checkMicrophonePermission()
        }
        .onDisappear {
            // Clean up audio session
            if audioRecorder.isRecording {
                audioRecorder.stopRecording(cancel: true)
            }
            AudioSessionManager.shared.deactivateSession()
        }
    }
    
    private func checkMicrophonePermission() {
        let audioSession = AVAudioSession.sharedInstance()
        
        switch audioSession.recordPermission {
        case .granted:
            print("Microphone permission already granted")
            // Auto-start recording
            audioRecorder.startRecording()
            
        case .denied:
            print("Microphone permission denied")
            showPermissionAlert()
            
        case .undetermined:
            print("Requesting microphone permission")
            audioSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        audioRecorder.startRecording()
                    } else {
                        showPermissionAlert()
                    }
                }
            }
            
        @unknown default:
            print("Unknown microphone permission status")
            showPermissionAlert()
        }
    }
    
    private func showPermissionAlert() {
        print("Permission denied - would show alert")
    }
    
    private func createFoodFromVoiceInBackground() {
        // If we have transcribed text, use it immediately
        if !audioRecorder.transcribedText.isEmpty {
            generateFoodFromTranscriptionInBackground()
        } else {
            // If no transcribed text yet, wait for transcription to complete
            print("Waiting for transcription to complete...")
            // Set up a timer to check for transcription completion
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if !audioRecorder.transcribedText.isEmpty {
                    timer.invalidate()
                    generateFoodFromTranscriptionInBackground()
                } else if !audioRecorder.isProcessing && audioRecorder.transcribedText.isEmpty {
                    // If processing is done but still no text, something went wrong
                    timer.invalidate()
                    print("❌ Transcription failed or returned empty")
                }
            }
        }
    }
    
    private func generateFoodFromTranscriptionInBackground() {
        guard !audioRecorder.transcribedText.isEmpty else { return }
        
        // Set scanning state to show loader card
        foodManager.isScanningFood = true
        foodManager.isGeneratingFood = true
        foodManager.loadingMessage = "Generating food from voice..."
        foodManager.uploadProgress = 0.3
        
        // Use FoodManager to generate food with AI with skipConfirmation=true to prevent sheet
        foodManager.generateFoodWithAI(foodDescription: audioRecorder.transcribedText, skipConfirmation: true) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let generatedFood):
                    print("✅ Food generated successfully from voice: \(generatedFood.displayName)")
                    
                    // Now create the food in the database
                    self.foodManager.createManualFood(food: generatedFood, showPreview: false) { createResult in
                        DispatchQueue.main.async {
                            switch createResult {
                            case .success(let createdFood):
                                print("✅ Food created in database from voice: \(createdFood.displayName)")
                                
                                // Track as recently added
                                self.foodManager.trackRecentlyAdded(foodId: createdFood.fdcId)
                                
                                // Pass the created food to parent (view already dismissed)
                                // Parent will add it to generatedFoods and selectedFoodIds
                                onFoodVoiceAdded(createdFood)
                                
                                // Clear scanning states
                                self.foodManager.isScanningFood = false
                                self.foodManager.isGeneratingFood = false
                                
                            case .failure(let error):
                                print("❌ Failed to create food in database: \(error)")
                                
                                // Clear scanning states
                                self.foodManager.isScanningFood = false
                                self.foodManager.isGeneratingFood = false
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Failed to generate food from voice: \(error)")
                    
                    // Clear scanning states
                    self.foodManager.isScanningFood = false
                    self.foodManager.isGeneratingFood = false
                }
            }
        }
    }
    
    // Original method kept for compatibility but now dismisses immediately
    private func createFoodFromVoice() {
        // Dismiss immediately
        dismiss()
        
        // Process in background
        createFoodFromVoiceInBackground()
    }
}

#Preview {
    AddFoodWithVoice { food in
        print("Food voice added: \(food.displayName)")
    }
}
