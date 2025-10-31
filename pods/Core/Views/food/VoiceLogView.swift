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
}

struct VoiceFluidView: View {
    let level: CGFloat
    let samples: [Float]
    let isActive: Bool
    
    var body: some View {
        GeometryReader { proxy in
            let dimension = min(proxy.size.width, proxy.size.height)
            let frame = CGSize(width: dimension, height: dimension)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color("chat").opacity(isActive ? 0.85 : 0.6),
                                Color.accentColor.opacity(isActive ? 0.75 : 0.4)
                            ]),
                            center: .center,
                            startRadius: dimension * 0.08,
                            endRadius: dimension * 0.55
                        )
                    )
                    .frame(width: frame.width, height: frame.height)
                    .shadow(color: Color.accentColor.opacity(isActive ? 0.45 : 0.2),
                            radius: 28,
                            x: 0,
                            y: 18)
                
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, canvasSize in
                        let circleRect = CGRect(
                            x: (canvasSize.width - frame.width) / 2,
                            y: (canvasSize.height - frame.height) / 2,
                            width: frame.width,
                            height: frame.height
                        )
                        
                        let circlePath = Path(ellipseIn: circleRect)
                        context.clip(to: circlePath)
                        
                        context.fill(circlePath,
                                     with: .linearGradient(
                                        Gradient(colors: [
                                            Color("chat").opacity(0.65),
                                            Color.accentColor.opacity(0.85)
                                        ]),
                                        startPoint: CGPoint(x: circleRect.midX, y: circleRect.minY),
                                        endPoint: CGPoint(x: circleRect.midX, y: circleRect.maxY)
                                     ))
                        
                        let envelope = isActive ? max(level, 0.08) : 0.04
                        let baseline = circleRect.maxY - circleRect.height * 0.22
                        let steps = max(Int(circleRect.width / 5), 40)
                        
                        func wavePath(phaseShift: CGFloat, speed: Double, depth: CGFloat) -> Path {
                            var path = Path()
                            path.move(to: CGPoint(x: circleRect.minX, y: circleRect.maxY))
                            
                            for step in 0...steps {
                                let progress = CGFloat(step) / CGFloat(steps)
                                let x = circleRect.minX + progress * circleRect.width
                                let sampleIdx = Int(progress * CGFloat(max(samples.count - 1, 0)))
                                let sample = samples.indices.contains(sampleIdx) ? CGFloat(samples[sampleIdx]) : 0
                                let energy = min(max(sample * 0.7 + envelope, 0.05), 1.0)
                                let amplitude = circleRect.height * (0.18 + envelope * depth)
                                let oscillation = sin(progress * 2.4 * .pi + CGFloat(time * speed) + phaseShift)
                                let y = baseline - oscillation * amplitude * energy
                                path.addLine(to: CGPoint(x: x, y: min(max(y, circleRect.minY), circleRect.maxY)))
                            }
                            
                            path.addLine(to: CGPoint(x: circleRect.maxX, y: circleRect.maxY))
                            path.closeSubpath()
                            return path
                        }
                        
                        let waveConfigs: [(CGFloat, Double, CGFloat, [Color])] = [
                            (0, 0.9, 0.38, [Color.accentColor.opacity(0.95), Color("chat").opacity(0.55)]),
                            (.pi / 2, 1.25, 0.3, [Color.accentColor.opacity(0.75), Color("chat").opacity(0.4)]),
                            (.pi, 1.55, 0.24, [Color.accentColor.opacity(0.55), Color("chat").opacity(0.25)])
                        ]
                        
                        for config in waveConfigs {
                            let path = wavePath(phaseShift: config.0,
                                                speed: config.1,
                                                depth: config.2)
                            
                            context.addFilter(.blur(radius: 14))
                            context.fill(path,
                                         with: .linearGradient(
                                            Gradient(colors: config.3),
                                            startPoint: CGPoint(x: circleRect.midX, y: circleRect.minY),
                                            endPoint: CGPoint(x: circleRect.midX, y: circleRect.maxY)
                                         ))
                            context.addFilter(.blur(radius: 0))
                        }
                        
                        context.stroke(circlePath,
                                       with: .color(Color.white.opacity(0.22)),
                                       lineWidth: 1.1)
                    }
                }
                .frame(width: frame.width, height: frame.height)
                
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .blur(radius: 12)
                    .frame(width: frame.width * 1.08, height: frame.height * 1.08)
                    .opacity(isActive ? 1 : 0.4)
            }
            .frame(width: frame.width, height: frame.height)
            .position(center)
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
