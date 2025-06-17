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
                                .frame(width: 44, height: 44)
                                .background(Color(UIColor.secondarySystemFill))
                                .clipShape(Circle())
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
                                // Wait a short moment for the recording to finish, then dismiss and start generation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    dismiss() // Dismiss immediately
                                    createFoodFromVoice()
                                }
                            } else if !audioRecorder.transcribedText.isEmpty {
                                // If not recording but have transcription, dismiss and create food
                                dismiss() // Dismiss immediately
                                createFoodFromVoice()
                            }
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.green)
                                .clipShape(Circle())
                                .opacity((foodManager.isGeneratingFood || audioRecorder.isProcessing) ? 0.5 : 1.0)
                        }
                        .disabled(foodManager.isGeneratingFood || audioRecorder.isProcessing)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 24 : 40)
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

        .navigationDestination(for: Food.self) { food in
                            ConfirmFoodView(path: $navigationPath)
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
        
        // Use FoodManager to generate food with AI (NOT generateMacrosWithAI)
        foodManager.generateFoodWithAI(foodDescription: audioRecorder.transcribedText) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let food):
                    print("✅ Successfully analyzed food from voice for creation: \(food.displayName)")
                    // Navigate to ConfirmFoodView instead of directly adding to userFoods
                    navigationPath.append(food)
                case .failure(let error):
                    print("❌ Failed to analyze food from voice: \(error)")
                    // Could show an alert here if needed
                }
            }
        }
    }
}

#Preview {
    CreateFoodWithVoice()
}
