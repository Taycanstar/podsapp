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
                VStack(spacing: 0) {
                    // Top section with status and waveform
                    VStack(spacing: 24) {
                        // Status text with processing state
                        if audioRecorder.isProcessing {
                            Text("Processing...")
                                .font(.headline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.bottom, 8)
                        } else if !audioRecorder.transcribedText.isEmpty {
                            Text(audioRecorder.transcribedText)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                        } else {
                            Text(audioRecorder.isRecording ? "Describe your food" : "Describe the food you want to add")
                                .font(.headline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.bottom, 16)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Centered Waveform visualization with fixed width
                        WaveformView(samples: audioRecorder.audioSamples, isRecording: audioRecorder.isRecording)
                            .frame(width: geometry.size.width * 0.7, height: 100)
                            .padding(.horizontal)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.6)
                    
                    Spacer()
                    
                    // Bottom controls - X and checkmark only
                    HStack {
                        // X button (left)
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
                        
                        // Checkmark button (right) - enabled when recording or when transcription is available
                        Button(action: {
                            // Guard against double-taps during processing
                            guard !foodManager.isGeneratingFood && !audioRecorder.isProcessing else {
                                return
                            }
                            
                            // First stop the recording if active
                            if audioRecorder.isRecording {
                                audioRecorder.stopRecording()
                                // Dismiss immediately when recording stops
                                dismiss()
                                // Start processing in background
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    createFoodFromVoiceInBackground()
                                }
                            } else if !audioRecorder.transcribedText.isEmpty {
                                // If not recording but have transcription, dismiss and create food
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
        
        // Clear lastGeneratedFood BEFORE calling generateFoodWithAI to prevent triggering ConfirmFoodView sheet
        foodManager.lastGeneratedFood = nil
        
        // Use FoodManager to generate food with AI (NOT generateMacrosWithAI)
        foodManager.generateFoodWithAI(foodDescription: audioRecorder.transcribedText) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let createdFood):
                    print("✅ Food created successfully from voice for recipe: \(createdFood.displayName)")
                    
                    // Clear lastGeneratedFood to prevent triggering other sheets
                    foodManager.lastGeneratedFood = nil
                    
                    // Pass the food to parent (view already dismissed)
                    // Note: Don't cleanup scanning states here - let parent handle it
                    onFoodVoiceAdded(createdFood)
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from voice: \(error)")
                    // Clear lastGeneratedFood on error
                    foodManager.lastGeneratedFood = nil
                    // Note: Don't cleanup scanning states here - let parent handle it
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
