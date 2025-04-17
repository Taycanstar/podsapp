//
//  VoiceLogView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/15/25.
//

import SwiftUI
import AVFoundation

// Create a singleton to manage global audio session state
class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    var isActive = false
    
    private init() {}
    
    func activateSession() -> Bool {
        print("AudioSessionManager: activating audio session")
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            isActive = true
            print("AudioSessionManager: session activated successfully")
            return true
        } catch {
            print("AudioSessionManager: error activating session - \(error.localizedDescription)")
            isActive = false
            return false
        }
    }
    
    func deactivateSession() {
        print("AudioSessionManager: deactivating audio session")
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isActive = false
            print("AudioSessionManager: session deactivated successfully")
        } catch {
            print("AudioSessionManager: error deactivating session - \(error.localizedDescription)")
        }
    }
}

// A struct to represent a single dot in the orb
struct OrbDot: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
    var size: CGFloat
    var opacity: Double
    var baseX: CGFloat  // Store the original position
    var baseY: CGFloat
    var isBorder: Bool  // Whether this dot is on the border
    
    // Create a random dot within a spherical space
    static func random(radius: CGFloat) -> OrbDot {
        // Determine if this will be a border dot or an interior dot
        let isBorder = Bool.random() || Bool.random() // 75% chance for border dots
        
        // Generate a radius based on whether this is a border dot
        let r: CGFloat
        if isBorder {
            // Border dots - concentrated very close to the surface
            r = CGFloat.random(in: 0.92...1.0) * radius
        } else {
            // Interior dots - more sparse
            r = CGFloat.random(in: 0.5...0.85) * radius
        }
        
        // Random angle in 3D space
        let theta = CGFloat.random(in: 0...2 * .pi)
        let phi = CGFloat.random(in: 0...CGFloat.pi)
        
        // Convert to Cartesian coordinates
        let x = r * sin(phi) * cos(theta)
        let y = r * sin(phi) * sin(theta)
        let z = r * cos(phi)
        
        // Size varies - border dots are larger
        let size: CGFloat
        let opacity: Double
        
        if isBorder {
            // Border dots are larger and more opaque
            size = CGFloat.random(in: 1.6...2.4)
            opacity = 0.4
        } else {
            // Interior dots are smaller and more transparent
            size = CGFloat.random(in: 1.0...1.5)
            opacity = 0.25
        }
        
        return OrbDot(
            x: x, 
            y: y, 
            z: z, 
            size: size, 
            opacity: opacity,
            baseX: x,
            baseY: y,
            isBorder: isBorder
        )
    }
}

struct VoiceLogView: View {
    @Binding var isPresented: Bool
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var allowDismissal = false
    @EnvironmentObject var foodManager: FoodManager
    
    // Simplified body for cleaner look
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
                            Text(audioRecorder.isRecording ? "Recording..." : "Ready to record")
                                .font(.headline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(.bottom, 16)
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
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Color(UIColor.secondarySystemFill))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Checkmark button (right) - only enabled when food data is available
                        Button(action: {
                            print("Checkmark button tapped")
                            if audioRecorder.isRecording {
                                // Stop recording and process in FoodManager (this will show loading UI)
                                audioRecorder.stopRecording(cancel: false)
                                // Close immediately after stopping - FoodManager will continue processing
                                isPresented = false
                            } else if let food = audioRecorder.foodData {
                                // The processFoodAndSubmit method is removed to prevent double-processing
                                // FoodManager.processVoiceRecording already handles the entire workflow
                            } else {
                                // Just close if there's nothing to process
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Color(UIColor.secondarySystemFill))
                                .clipShape(Circle())
                        }
                        .disabled(audioRecorder.foodData == nil && audioRecorder.isProcessing)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 24 : 40)
                }
            }
        }
        .onAppear {
            print("VoiceLogView appeared")
            
            // Setup without showing a loading screen
            DispatchQueue.main.async {
                // Inject the FoodManager
                audioRecorder.foodManager = foodManager
                
                // Note: No longer using foodDataReady callback since FoodManager.processVoiceRecording
                // handles the entire process including logging
                
                // Pre-activate audio session
                if AudioSessionManager.shared.activateSession() {
                    print("Audio session pre-activated")
                    checkMicrophonePermission()
                }
                
                // Allow dismissal after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    allowDismissal = true
                    print("Dismissal now allowed")
                }
            }
        }
        .onDisappear {
            print("VoiceLogView disappeared")
            if audioRecorder.isRecording {
                _ = audioRecorder.stopRecording(cancel: true)
            }
            
            // Clean up audio session
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
}

// Waveform visualization component
struct WaveformView: View {
    let samples: [Float]
    let isRecording: Bool
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<min(samples.count, 60), id: \.self) { index in
                    WaveBar(
                        value: CGFloat(samples[samples.count - 1 - index]),
                        isRecording: isRecording,
                        index: index
                    )
                }
            }
            .frame(width: geometry.size.width)
        }
    }
}

// Individual bar in the waveform
struct WaveBar: View {
    let value: CGFloat
    let isRecording: Bool
    let index: Int
    
    var body: some View {
        let height = 5 + value * 95 // Scale to reasonable height
        
        Rectangle()
            .fill(Color.primary.opacity(isRecording ? 1.0 : 0.6))
            .frame(height: height)
            // Use more recent samples at full opacity, fade older ones
            .opacity(isRecording ? 1.0 - Double(index) / 60.0 * 0.5 : 1.0)
            // Round the edges a bit
            .cornerRadius(2)
    }
}

// AudioRecorder class to handle voice recording and amplitude tracking
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: CGFloat = 0
    @Published var audioSamples: [Float] = Array(repeating: 0.0, count: 60) // Store an array of samples
    @Published var transcribedText: String = ""
    @Published var isProcessing: Bool = false
    @Published var foodData: Food?
    
    // The FoodManager instance passed from VoiceLogView
    var foodManager: FoodManager? 
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var audioFileURL: URL?
    private let networkManager = NetworkManagerTwo.shared
    
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
            audioFileURL = documentsDirectory.appendingPathComponent("voiceLog_\(timestamp).m4a")
            
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
        
        do {
            // Read audio data
            let audioData = try Data(contentsOf: audioFileURL)
            
            // Pass the audio data to FoodManager to process instead of handling it ourselves
            // This ensures processing continues even after VoiceLogView is dismissed
            if let foodManager = foodManager {
                print("🎤 Passing audio data to FoodManager for processing")
                foodManager.processVoiceRecording(audioData: audioData)
            } else {
                print("⚠️ No FoodManager available to process audio")
            }
        } catch {
            print("Error reading audio file: \(error.localizedDescription)")
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
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorder: AVAudioRecorderDelegate {
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

#Preview {
    VoiceLogView(isPresented: .constant(false))
}

