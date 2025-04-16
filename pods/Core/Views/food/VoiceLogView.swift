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
    @State private var recognizedText: String = ""
    @State private var allowDismissal = false
    
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
                        // Status text - updated to indicate automatic recording
                        Text(audioRecorder.isRecording ? "Recording..." : "Ready to record")
                            .font(.headline)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .padding(.bottom, 16)
                        
                        // Centered Waveform visualization with fixed width
                        WaveformView(samples: audioRecorder.samples, isRecording: audioRecorder.isRecording)
                            .frame(width: geometry.size.width * 0.7, height: 100)
                            .padding(.horizontal)
                        
                        // Timer display 
                        Text(formatDuration(seconds: 0))
                            .font(.system(.title, design: .monospaced))
                            .foregroundColor(Color(UIColor.label))
                            .padding(.top, 16)
                        
                        // Transcribed text display
                        if !recognizedText.isEmpty {
                            Text(recognizedText)
                                .font(.body)
                                .foregroundColor(Color(UIColor.label))
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                                .transition(.opacity)
                                .animation(.easeInOut, value: recognizedText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: geometry.size.width * 0.9)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.6)
                    
                    Spacer()
                    
                    // Bottom controls - X and checkmark only
                    HStack {
                        // X button (left)
                        Button(action: {
                            print("X button tapped")
                            if audioRecorder.isRecording {
                                audioRecorder.stopRecording()
                            }
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 22))
                                .foregroundColor(Color(UIColor.systemGray))
                                .frame(width: 44, height: 44)
                                .background(Color(UIColor.secondarySystemFill))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Checkmark button (right)
                        Button(action: {
                            print("tapped checkmark")
                            if audioRecorder.isRecording {
                                audioRecorder.stopRecording()
                                simulateTranscription()
                            }
                            isPresented = false
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 22))
                                .foregroundColor(Color.green)
                                .frame(width: 44, height: 44)
                                .background(Color(UIColor.secondarySystemFill))
                                .clipShape(Circle())
                        }
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
                audioRecorder.stopRecording()
            }
            
            // Clean up audio session
            AudioSessionManager.shared.deactivateSession()
        }
    }
    
    // Helper to format duration as mm:ss
    private func formatDuration(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
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
    
    private func simulateTranscription() {
        print("Simulating transcription...")
        // In a real app, you would send the audio file to a speech recognition service
        // For this example, we'll simulate a response after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            recognizedText = "I had a chicken salad with grilled vegetables for lunch today."
            print("Transcription complete")
        }
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
class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var samples: [Float] = Array(repeating: 0.01, count: 60) // Keep 60 samples for waveform
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    
    override init() {
        super.init()
        print("AudioRecorder initialized")
    }
    
    deinit {
        print("AudioRecorder deinit called")
        stopRecording()
    }
    
    func startRecording() {
        print("Starting recording...")
        
        // Stop any existing recording session
        if isRecording {
            stopRecording()
        }
        
        do {
            // Use the shared audio session manager instead of configuring directly
            if !AudioSessionManager.shared.isActive {
                if !AudioSessionManager.shared.activateSession() {
                    print("Failed to activate audio session")
                    return
                }
            }
            
            // Create URL for the recording
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentPath.appendingPathComponent("recording.m4a")
            
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: audioFilename.path) {
                try FileManager.default.removeItem(at: audioFilename)
                print("Removed existing audio file")
            }
            
            // Configure recording settings
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // Create and start recorder
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            if audioRecorder?.record() == true {
                isRecording = true
                print("Recording started successfully")
                startMonitoring()
            } else {
                print("Failed to start recording")
            }
        } catch {
            print("Recording setup error: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        print("Stopping recording...")
        
        if let recorder = audioRecorder {
            recorder.stop()
            print("Recording stopped")
        }
        
        timer?.invalidate()
        timer = nil
        
        // Don't deactivate the audio session here - let the manager handle it
        
        isRecording = false
    }
    
    private func startMonitoring() {
        print("Starting audio level monitoring")
        
        timer?.invalidate()
        // Update slower for a more gradual waveform movement
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.updateSamples()
        }
    }
    
    private func updateSamples() {
        guard let recorder = audioRecorder, isRecording else {
            return
        }
        
        recorder.updateMeters()
        
        // Get the current audio level (in decibels)
        let currentLevel = recorder.averagePower(forChannel: 0)
        
        // Convert decibels to a linear scale (between 0.0 and 1.0)
        // Audio levels are typically between -160 and 0 dB
        // We'll normalize to a 0-1 scale for visualization
        let normalizedLevel = Float(max(0.05, min(1, (currentLevel + 60) / 60)))
        
        // Add the new sample and maintain only the most recent samples
        samples.append(normalizedLevel)
        if samples.count > 60 { // Keep 60 samples for waveform
            samples.removeFirst()
        }
    }
}

#Preview {
    VoiceLogView(isPresented: .constant(false))
}

