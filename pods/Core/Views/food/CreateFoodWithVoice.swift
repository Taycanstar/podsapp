//
//  CreateFoodWithVoice.swift
//  Pods
//
//  Created by Dimi Nunez on 6/12/25.
//

import SwiftUI
import AVFoundation

// Separate class to handle audio recording for CreateFoodWithVoice
class CreateFoodAudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var audioLevel: CGFloat = 0
    @Published var audioSamples: [Float] = Array(repeating: 0.0, count: 60)
    @Published var transcribedText: String = ""
    @Published var isProcessing: Bool = false
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var audioFileURL: URL?
    
    func startRecording() {
        // Set up audio session
        do {
            try AudioSessionManager.shared.activateSession()
            print("AudioSessionManager: audio session activated successfully")
            
            // Define recording settings
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // Create a unique URL for the audio file
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let timestamp = Date().timeIntervalSince1970
            audioFileURL = documentsDirectory.appendingPathComponent("createFood_\(timestamp).m4a")
            
            guard let audioFileURL = audioFileURL else {
                print("Error: Could not create audio file URL")
                return
            }
            
            print("Recording audio to \(audioFileURL.path)")
            
            // Create and start the audio recorder
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            // Start monitoring audio levels
            startMonitoringAudio()
        } catch {
            print("Error setting up audio session: \(error.localizedDescription)")
        }
    }
    
    func stopRecording(cancel: Bool = false) {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        // Mark that we're no longer recording
        isRecording = false
        
        // Stop the recorder
        recorder.stop()
        timer?.invalidate()
        timer = nil
        
        print("Audio recording stopped")
        
        // Skip processing if canceling
        if cancel {
            print("Recording canceled - not processing audio")
            audioRecorder = nil
            return
        }
        
        // Check if we have a valid audio file
        guard let audioFileURL = audioFileURL else {
            print("Error: No audio file to process")
            return
        }
        
        // Set processing state
        isProcessing = true
        
        do {
            // Read audio data
            let audioData = try Data(contentsOf: audioFileURL)
            
            // Transcribe the audio directly using NetworkManagerTwo
            NetworkManagerTwo.shared.transcribeAudioForFoodLogging(from: audioData) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isProcessing = false
                    
                    switch result {
                    case .success(let text):
                        print("✅ Voice transcription successful: \(text)")
                        self.transcribedText = text
                        
                    case .failure(let error):
                        print("❌ Voice transcription failed: \(error)")
                        // Could show an alert here if needed
                    }
                }
            }
        } catch {
            print("Error reading audio file: \(error.localizedDescription)")
            isProcessing = false
        }
        
        // Clear references
        audioRecorder = nil
    }
    
    private func startMonitoringAudio() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            
            recorder.updateMeters()
            let averagePower = recorder.averagePower(forChannel: 0)
            let normalizedValue = self.normalizeAudioLevel(averagePower)
            
            DispatchQueue.main.async {
                self.audioLevel = normalizedValue
                
                // Update the audioSamples array for the waveform visualization
                self.audioSamples.removeFirst()
                self.audioSamples.append(Float(normalizedValue))
                
                // Set isRecording flag to true if it's not already
                if !self.isRecording {
                    self.isRecording = true
                }
            }
        }
    }
    
    private func normalizeAudioLevel(_ power: Float) -> CGFloat {
        // Convert from dB to a 0-1 scale (dB is typically negative)
        let minDb: Float = -60.0
        if power < minDb {
            return 0.05 // Minimum level for visual feedback
        }
        
        // Normalize between 0 and 1 with a more expressive curve
        let normalizedValue = CGFloat((power - minDb) / abs(minDb))
        return min(max(normalizedValue * 1.2, 0.05), 1.0) // Scale up slightly, with limits
    }
    
    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording error: \(error.localizedDescription)")
        }
    }
}

struct CreateFoodWithVoice: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager
    @State private var navigationPath = NavigationPath()
    @StateObject private var audioRecorder = CreateFoodAudioRecorder()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                        
                        VStack(spacing: 28) {
                            RoundedRectangle(cornerRadius: 999)
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 48, height: 4)
                                .opacity(audioRecorder.isRecording ? 1.0 : 0.6)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: audioRecorder.isRecording)
                            
                            VStack(spacing: 10) {
                                Text(statusTitle())
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                if let subtitle = statusSubtitle() {
                                    Text(subtitle)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                }
                            }
                            
                            VoiceAuraView(
                                level: audioRecorder.audioLevel,
                                samples: audioRecorder.audioSamples,
                                isRecording: audioRecorder.isRecording || audioRecorder.isProcessing
                            )
                            .frame(width: min(geometry.size.width * 0.7, 260),
                                   height: min(geometry.size.width * 0.7, 260))
                            .padding(.top, 12)
                            
                            if audioRecorder.isProcessing {
                                ProgressView("Creating your food")
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.accentColor))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                    .padding(.top, 4)
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
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        dismiss()
                                        createFoodFromVoice()
                                    }
                                } else if !audioRecorder.transcribedText.isEmpty {
                                    dismiss()
                                    createFoodFromVoice()
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
        }
        .onAppear {
            print("CreateFoodWithVoice appeared")
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
    
    private func statusTitle() -> String {
        if audioRecorder.isProcessing {
            return "Generating your food"
        }
        if audioRecorder.isRecording {
            return "Listening..."
        }
        if !audioRecorder.transcribedText.isEmpty {
            return "Captured summary"
        }
        return "Ready for voice mode"
    }
    
    private func statusSubtitle() -> String? {
        if audioRecorder.isProcessing {
            return "Hang tight—Humuli is crafting the nutrition details for you."
        }
        if audioRecorder.isRecording {
            return "Tell us about ingredients, portions, or how you prepared it."
        }
        if !audioRecorder.transcribedText.isEmpty {
            return "Review the preview below, then confirm to add it."
        }
        return "Tap the microphone to describe the food you want to create."
    }
    
    private func createFoodFromVoice() {
        // If we have transcribed text, use it immediately
        if !audioRecorder.transcribedText.isEmpty {
            generateFoodFromTranscription()
        } else {
            // If no transcribed text yet, wait for transcription to complete
            print("Waiting for transcription to complete...")
            // Set up a timer to check for transcription completion
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if !audioRecorder.transcribedText.isEmpty {
                    timer.invalidate()
                    generateFoodFromTranscription()
                } else if !audioRecorder.isProcessing && audioRecorder.transcribedText.isEmpty {
                    // If processing is done but still no text, something went wrong
                    timer.invalidate()
                    print("❌ Transcription failed or returned empty")
                }
            }
        }
    }
    
    private func generateFoodFromTranscription() {
        guard !audioRecorder.transcribedText.isEmpty else { return }
        
        // UNIFIED: Start with proper 0% progress, then animate with smooth transitions
        foodManager.updateFoodScanningState(.initializing)  // Start at 0% with animation
        
        // Animate to food generation state after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            foodManager.updateFoodScanningState(.generatingFood)  // Smooth animate to 60%
        }
        
        // Use FoodManager to generate food with AI with skipConfirmation=true to prevent sheet
        foodManager.generateFoodWithAI(foodDescription: audioRecorder.transcribedText, skipConfirmation: true) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let food):
                    print("✅ Successfully analyzed food from voice for creation: \(food.displayName)")
                    
                    // UNIFIED: createManualFood now detects active scanning flow and won't interfere
                    
                    // Create food directly without confirmation (like barcode with preview disabled)
                    self.foodManager.createManualFood(food: food, showPreview: false) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let savedFood):
                                print("✅ Successfully created food from voice: \(savedFood.displayName)")
                                
                                // Track as recently added
                                self.foodManager.trackRecentlyAdded(foodId: savedFood.fdcId)
                                
                                // UNIFIED: Show completion with proper animation and auto-reset
                                let completionLog = CombinedLog(
                                    type: .food,
                                    status: "success",
                                    calories: savedFood.calories ?? 0,
                                    message: "Created \(savedFood.displayName)",
                                    foodLogId: nil
                                )
                                self.foodManager.updateFoodScanningState(.completed(result: completionLog))
                                
                                // Show success toast
                                self.foodManager.lastLoggedItem = (name: savedFood.displayName, calories: savedFood.calories ?? 0)
                                self.foodManager.showLogSuccess = true
                                
                                // Auto-hide success message after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    self.foodManager.showLogSuccess = false
                                }
                                
                            case .failure(let error):
                                print("❌ Failed to create food from voice: \(error)")
                                
                                // UNIFIED: Show error state then reset
                                self.foodManager.updateFoodScanningState(.failed(error: .networkError(error.localizedDescription)))
                                
                                // Reset after showing error for a moment
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    self.foodManager.resetFoodScanningState()
                                }
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from voice: \(error)")
                    
                    // UNIFIED: Show error state then reset
                    self.foodManager.updateFoodScanningState(.failed(error: .networkError(error.localizedDescription)))
                    
                    // Reset after showing error for a moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.foodManager.resetFoodScanningState()
                    }
                }
            }
        }
    }
}

#Preview {
    CreateFoodWithVoice()
}
