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
    let selectedMeal: String
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var allowDismissal = false
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    
    // Simplified body for cleaner look
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background that adapts to dark/light mode
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
                            ProgressView("Analyzing your voice log")
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
                                .frame(width: 60, height: 60)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray3), lineWidth: 1)
                                )
                        }
                        
                        Spacer()
                        
                        // Checkmark button (right) - only enabled when food data is available
                        Button(action: {
                            // Guard against double-taps during processing
                            guard !foodManager.isGeneratingMacros && !foodManager.isLoading else {
                                return
                            }
                            
                            // First stop the recording if active
                            if audioRecorder.isRecording {
                                audioRecorder.stopRecording()
                                // Wait a short moment for the recording to finish
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isPresented = false
                                }
                            } else {
                                // If not recording, just dismiss
                                isPresented = false
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
                                .opacity(foodManager.isGeneratingMacros || foodManager.isLoading ? 0.5 : 1.0) // Visual feedback for disabled state
                        }
                        .disabled(foodManager.isGeneratingMacros || foodManager.isLoading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 24 : 40)
                }
            }
        }
        .onAppear {
            print("VoiceLogView appeared")
            print("🍽️ VoiceLogView received selectedMeal: \(selectedMeal)")
            
            // Setup without showing a loading screen
            DispatchQueue.main.async {
                // Inject the FoodManager, DayLogsViewModel, and selectedMeal
                audioRecorder.foodManager = foodManager
                audioRecorder.dayLogsVM = dayLogsVM
                audioRecorder.selectedMeal = selectedMeal
                print("🍽️ AudioRecorder.selectedMeal set to: \(audioRecorder.selectedMeal)")
                
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
    
    private func statusTitle() -> String {
        if audioRecorder.isProcessing {
            return "Processing your voice log"
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
            return "Hang tight—Humuli is generating nutrition details from your recording."
        }
        
        if audioRecorder.isRecording {
            return "Describe your meal or activity naturally. We’ll structure everything for you."
        }
        
        if !audioRecorder.transcribedText.isEmpty {
            return "Review the preview below, then confirm to log it."
        }
        
        return "Tap the microphone to start logging with your voice."
    }
}

struct VoiceAuraView: View {
    let level: CGFloat
    let samples: [Float]
    let isRecording: Bool
    
    private var ringSamples: [CGFloat] {
        let ringCount = 32
        guard !samples.isEmpty else {
            return Array(repeating: 0.08, count: ringCount)
        }
        
        return (0..<ringCount).map { index in
            let sampleIndex = max(samples.count - 1 - index * 2, 0)
            let value = CGFloat(samples[sampleIndex])
            return max(0.08, min(value, 1.0))
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let baseDiameter = size * 0.58
            let expansion = 1 + level * 0.35
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.accentColor.opacity(isRecording ? 0.55 : 0.25),
                                Color("chat").opacity(0.05),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: baseDiameter * 1.4
                        )
                    )
                    .frame(width: baseDiameter * 1.9, height: baseDiameter * 1.9)
                    .scaleEffect(expansion)
                    .animation(.easeOut(duration: 0.28), value: level)
                
                ForEach(Array(ringSamples.enumerated()), id: \.offset) { idx, sample in
                    Capsule()
                        .fill(Color.accentColor.opacity(isRecording ? Double(0.25 + sample * 0.65) : 0.18))
                        .frame(width: size * 0.03, height: size * (0.16 + sample * 0.4))
                        .offset(y: -size * 0.34)
                        .rotationEffect(.degrees(Double(idx) / Double(ringSamples.count) * 360))
                        .animation(.easeOut(duration: 0.25), value: sample)
                }
                
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color("chat").opacity(isRecording ? 0.95 : 0.6),
                                Color.accentColor.opacity(isRecording ? 0.85 : 0.5)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: baseDiameter, height: baseDiameter)
                    .scaleEffect(expansion)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 24, x: 0, y: 18)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: baseDiameter * 0.34, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 10)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
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
    
    // The FoodManager and DayLogsViewModel instances passed from VoiceLogView
    var foodManager: FoodManager?
    var dayLogsVM: DayLogsViewModel?
    var selectedMeal: String = "Lunch" 
    
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
            if let foodManager = foodManager, let dayLogsVM = dayLogsVM {
                print("🎤 Passing audio data to FoodManager for processing with meal: \(selectedMeal)")
                print("🍽️ AudioRecorder.selectedMeal value: \(selectedMeal)")
                Task { @MainActor in
                    foodManager.processVoiceRecording(audioData: audioData, mealType: selectedMeal, dayLogsVM: dayLogsVM)
                }
            } else {
                print("⚠️ No FoodManager or DayLogsViewModel available to process audio")
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
    VoiceLogView(isPresented: .constant(false), selectedMeal: "Lunch")
}
