//
//  CreateFoodWithVoice.swift
//  Pods
//
//  Created by Dimi Nunez on 6/12/25.
//

import SwiftUI
import AVFoundation

struct CreateFoodWithVoice: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioRecorder = AudioRecorder()
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background that adapts to dark/light mode
                Color(UIColor.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    
                    // Recording visualization
                    VStack(spacing: 24) {
                        // Status text with processing state
                        if audioRecorder.isProcessing {
                            Text("Processing...")
                                .font(.headline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.bottom, 8)
                        } else if !audioRecorder.transcribedText.isEmpty {
                            Text("Transcription:")
                                .font(.headline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.bottom, 4)
                            
                            Text(audioRecorder.transcribedText)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                        } else {
                            Text(audioRecorder.isRecording ? "Recording..." : "Describe the food you want to create")
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
                    
                    // Bottom controls - X and checkmark only (matching VoiceLogView)
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
                                .frame(width: 44, height: 44)
                                .background(Color(UIColor.secondarySystemFill))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Checkmark button (right) - only enabled when transcription is available
                        Button(action: {
                            // Guard against double-taps during processing
                            guard !foodManager.isGeneratingFood && !audioRecorder.isProcessing else {
                                return
                            }
                            
                            // First stop the recording if active
                            if audioRecorder.isRecording {
                                audioRecorder.stopRecording()
                                // Wait a short moment for the recording to finish
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    createFoodFromVoice()
                                }
                            } else if !audioRecorder.transcribedText.isEmpty {
                                // If not recording but have transcription, create food
                                createFoodFromVoice()
                            }
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.green)
                                .clipShape(Circle())
                                .opacity((foodManager.isGeneratingFood || audioRecorder.isProcessing || audioRecorder.transcribedText.isEmpty) ? 0.5 : 1.0)
                        }
                        .disabled(foodManager.isGeneratingFood || audioRecorder.isProcessing || audioRecorder.transcribedText.isEmpty)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 24 : 40)
                }
            }
        }
        .onAppear {
            print("CreateFoodWithVoice appeared")
            
            // Setup without showing a loading screen
            DispatchQueue.main.async {
                // Inject the FoodManager
                audioRecorder.foodManager = foodManager
                
                // Pre-activate audio session
                if AudioSessionManager.shared.activateSession() {
                    print("Audio session pre-activated")
                    checkMicrophonePermission()
                }
            }
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
            // Show alert or handle denied permission
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
        // In a real app, you would show an alert here
        print("Permission denied - would show alert")
    }
    
    private func createFoodFromVoice() {
        guard !audioRecorder.transcribedText.isEmpty else { return }
        
        // Use FoodManager to generate food with AI
        foodManager.generateFoodWithAI(foodDescription: audioRecorder.transcribedText) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let food):
                    print("✅ Successfully created food: \(food.displayName)")
                    // Add to user foods if not already present
                    if !foodManager.userFoods.contains(where: { $0.fdcId == food.fdcId }) {
                        foodManager.userFoods.insert(food, at: 0)
                    }
                    dismiss()
                case .failure(let error):
                    print("❌ Failed to create food: \(error)")
                    // Could show an alert here if needed
                }
            }
        }
    }
}


#Preview {
    CreateFoodWithVoice()
}
