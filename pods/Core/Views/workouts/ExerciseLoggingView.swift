//
//  ExerciseLoggingView.swift
//  Pods
//
//  Created by Claude on 7/26/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct ExerciseLoggingView: View {
    let exercise: TodayWorkoutExercise
    @Environment(\.dismiss) private var dismiss
    @State private var currentSet = 1
    @State private var completedSets: [SetLog] = []
    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var isRestMode = false
    @State private var restTimeRemaining = 0
    @State private var restTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Video Header
            videoHeaderView
            
            // Exercise info section
            exerciseInfoSection
            
            // Sets logging section
            setsLoggingSection
            
            Spacer()
            
            // Action buttons
            actionButtonsSection
        }
        .navigationTitle(exercise.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupInitialValues()
        }
        .onDisappear {
            stopRestTimer()
        }
    }
    
    private var videoHeaderView: some View {
        Group {
            if let videoURL = videoURL {
                CustomExerciseVideoPlayer(videoURL: videoURL)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .padding([.horizontal], 16)
                    .padding([.top], 8)
            } else {
                // Fallback thumbnail view
                Group {
                    if let image = UIImage(named: thumbnailImageName) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "play.circle")
                                        .foregroundColor(.white)
                                        .font(.system(size: 32))
                                    Text("Video not available")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                }
                            )
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
    
    private var exerciseInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.exercise.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(exercise.sets) sets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !exercise.exercise.target.isEmpty {
                Text("Target: \(exercise.exercise.target)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !exercise.exercise.equipment.isEmpty {
                Text("Equipment: \(exercise.exercise.equipment)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var setsLoggingSection: some View {
        VStack(spacing: 16) {
            // Current set indicator
            if !isRestMode {
                Text("Set \(currentSet) of \(exercise.sets)")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top)
            }
            
            // Rest mode view
            if isRestMode {
                VStack(spacing: 16) {
                    Text("Rest Time")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(formatTime(restTimeRemaining))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                    
                    Button("Skip Rest") {
                        skipRest()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                }
                .padding()
                .background(Color("bg"))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Input fields for current set
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weight (lbs)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("0", text: $weight)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("\(exercise.reps)", text: $reps)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Completed sets list
            if !completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 4) {
                        ForEach(Array(completedSets.enumerated()), id: \.offset) { index, setLog in
                            HStack {
                                Text("Set \(index + 1)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(setLog.weight, specifier: "%.1f") lbs × \(setLog.reps) reps")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color("iosfit"))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if !isRestMode {
                // Complete set button
                Button(action: completeSet) {
                    Text("Complete Set")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(currentSetCanBeCompleted ? Color.accentColor : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!currentSetCanBeCompleted)
                .padding(.horizontal)
            }
            
            if completedSets.count == exercise.sets {
                // Finish exercise button
                Button(action: finishExercise) {
                    Text("Finish Exercise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
    }
    
    // MARK: - Computed Properties

    private var videoURL: URL? {
        let videoId = String(format: "%04d", exercise.exercise.id)
        return URL(string: "https://humulistoragecentral.blob.core.windows.net/videos/filtered_vids/\(videoId).mp4")
    }
    
    private var thumbnailImageName: String {
        return String(format: "%04d", exercise.exercise.id)
    }
    
    private var currentSetCanBeCompleted: Bool {
        return !reps.isEmpty && (exercise.exercise.equipment.lowercased() == "body weight" || !weight.isEmpty)
    }
    
    // MARK: - Methods
    
    private func setupInitialValues() {
        reps = "\(exercise.reps)"
        // Initialize weight based on exercise type
        if exercise.exercise.equipment.lowercased() != "body weight" {
            weight = "0"
        }
    }
    
    private func completeSet() {
        guard let repsCount = Int(reps) else { return }
        let weightValue = Double(weight) ?? 0.0
        
        let setLog = SetLog(
            setNumber: currentSet,
            weight: weightValue,
            reps: repsCount,
            completedAt: Date()
        )
        
        completedSets.append(setLog)
        
        if currentSet < exercise.sets {
            // Start rest period
            startRestPeriod()
        } else {
            // All sets completed
            finishExercise()
        }
    }
    
    private func startRestPeriod() {
        isRestMode = true
        restTimeRemaining = exercise.restTime
        
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                skipRest()
            }
        }
    }
    
    private func skipRest() {
        stopRestTimer()
        isRestMode = false
        currentSet += 1
        // Reset inputs for next set
        reps = "\(exercise.reps)"
    }
    
    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
    }
    
    private func finishExercise() {
        // TODO: Save exercise completion to database
        print("Exercise completed: \(exercise.exercise.name)")
        print("Completed sets: \(completedSets)")
        dismiss()
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Set Log Model

struct SetLog {
    let setNumber: Int
    let weight: Double
    let reps: Int
    let completedAt: Date
}

// MARK: - Custom Exercise Video Player

struct CustomExerciseVideoPlayer: UIViewControllerRepresentable {
    let videoURL: URL
    
    func makeUIViewController(context: Context) -> ExerciseVideoPlayerController {
        let controller = ExerciseVideoPlayerController()
        controller.videoURL = videoURL  // Store URL for later setup
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ExerciseVideoPlayerController, context: Context) {
        // Update if needed
        if uiViewController.videoURL != videoURL {
            uiViewController.videoURL = videoURL
            uiViewController.setupPlayerIfReady()
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: ExerciseVideoPlayerController, coordinator: ()) {
        uiViewController.cleanup()
    }
}

class ExerciseVideoPlayerController: UIViewController {
    private var playerView: UIView?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    var videoURL: URL?
    private var viewHasLoaded = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        viewHasLoaded = true
        setupPlayerIfReady()
    }
    
    private func setupViews() {
        playerView = UIView()
        playerView?.translatesAutoresizingMaskIntoConstraints = false
        playerView?.backgroundColor = .clear
        
        guard let playerView = playerView else { return }
        view.addSubview(playerView)
        
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func setupPlayerIfReady() {
        guard viewHasLoaded, let videoURL = videoURL, let playerView = playerView else {
            return
        }
        
        // Clean up existing player if any
        cleanup()
        
        // Create asset and composition for chroma key
        let asset = AVURLAsset(url: videoURL)
        let composition = AVMutableComposition()
        
        // Add video track
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            // Fallback to simple player without chroma key
            setupSimplePlayer(url: videoURL)
            return
        }
        
        do {
            try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
        } catch {
            setupSimplePlayer(url: videoURL)
            return
        }
        
        // Create video composition with chroma key filter
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoTrack.naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        
        // Create chroma key filter - use CIColorCube for custom green screen removal
        guard let chromaKeyFilter = createGreenScreenFilter() else {
            setupSimplePlayer(url: videoURL)
            return
        }
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        // Apply custom compositor for chroma key
        videoComposition.customVideoCompositorClass = ChromaKeyVideoCompositor.self
        
        // Create player item with composition
        let playerItem = AVPlayerItem(asset: composition)
        playerItem.videoComposition = videoComposition
        
        // Create player
        player = AVPlayer(playerItem: playerItem)
        
        // Create player layer
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.backgroundColor = UIColor.clear.cgColor
        
        // Add to view
        if let playerLayer = playerLayer {
            playerView.layer.addSublayer(playerLayer)
        }
        
        // Setup auto-loop
        setupAutoLoop()
        
        // Auto-play when ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.player?.play()
        }
    }
    
    private func setupSimplePlayer(url: URL) {
        // Fallback simple player without chroma key
        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.backgroundColor = UIColor.clear.cgColor
        
        if let playerLayer = playerLayer, let playerView = playerView {
            playerView.layer.addSublayer(playerLayer)
        }
        
        setupAutoLoop()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.player?.play()
        }
    }
    
    private func createGreenScreenFilter() -> CIFilter? {
        // Use CIColorCube to create a custom green screen removal filter
        let greenScreenFilter = CIFilter(name: "CIColorCube")
        
        // Create a color cube that makes green pixels transparent
        let size = 64
        let cubeData = generateGreenScreenCubeData(cubeSize: size)
        let data = Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size)
        
        greenScreenFilter?.setValue(data, forKey: "inputCubeData")
        greenScreenFilter?.setValue(size, forKey: "inputCubeDimension")
        
        return greenScreenFilter
    }
    
    private func generateGreenScreenCubeData(cubeSize: Int) -> [Float] {
        var cubeData = [Float]()
        
        for z in 0..<cubeSize {
            for y in 0..<cubeSize {
                for x in 0..<cubeSize {
                    let r = Float(x) / Float(cubeSize - 1)
                    let g = Float(y) / Float(cubeSize - 1)
                    let b = Float(z) / Float(cubeSize - 1)
                    
                    // Check if this is a green pixel (high green, low red/blue)
                    let isGreen = g > 0.6 && r < 0.4 && b < 0.4
                    
                    if isGreen {
                        // Make green pixels transparent by setting alpha to 0
                        cubeData.append(r)
                        cubeData.append(g)
                        cubeData.append(b)
                        cubeData.append(0.0) // Alpha = 0 (transparent)
                    } else {
                        // Keep non-green pixels as they are
                        cubeData.append(r)
                        cubeData.append(g)
                        cubeData.append(b)
                        cubeData.append(1.0) // Alpha = 1 (opaque)
                    }
                }
            }
        }
        
        return cubeData
    }
    
    private func setupAutoLoop() {
        guard let player = player else { return }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let playerView = playerView {
            playerLayer?.frame = playerView.bounds
        }
    }
    
    func cleanup() {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        NotificationCenter.default.removeObserver(self)
        player = nil
        playerLayer = nil
    }
}

// MARK: - Chroma Key Video Compositor
class ChromaKeyVideoCompositor: NSObject, AVVideoCompositing {
    var sourcePixelBufferAttributes: [String : Any]? = [
        String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
    ]
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
        String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
    ]
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // Handle render context changes if needed
    }
    
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        guard let trackID = asyncVideoCompositionRequest.sourceTrackIDs.first,
              let sourcePixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: trackID.int32Value) else {
            asyncVideoCompositionRequest.finish(with: NSError(domain: "ChromaKey", code: 1, userInfo: nil))
            return
        }
        
        let renderContext = asyncVideoCompositionRequest.renderContext
        guard let destinationPixelBuffer = renderContext.newPixelBuffer() else {
            asyncVideoCompositionRequest.finish(with: NSError(domain: "ChromaKey", code: 2, userInfo: nil))
            return
        }
        
        // Create CIImages
        let sourceImage = CIImage(cvPixelBuffer: sourcePixelBuffer)
        
        // Apply green screen removal using CIColorCube
        guard let colorCubeFilter = CIFilter(name: "CIColorCube") else {
            copyPixelBuffer(source: sourcePixelBuffer, destination: destinationPixelBuffer)
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: destinationPixelBuffer)
            return
        }
        
        // Create color cube data for green screen removal
        let cubeData = createGreenScreenCubeData()
        let data = Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size)
        
        colorCubeFilter.setValue(sourceImage, forKey: kCIInputImageKey)
        colorCubeFilter.setValue(data, forKey: "inputCubeData")
        colorCubeFilter.setValue(64, forKey: "inputCubeDimension")
        
        guard let outputImage = colorCubeFilter.outputImage else {
            copyPixelBuffer(source: sourcePixelBuffer, destination: destinationPixelBuffer)
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: destinationPixelBuffer)
            return
        }
        
        // Render to destination buffer
        let context = CIContext()
        context.render(outputImage, to: destinationPixelBuffer)
        
        asyncVideoCompositionRequest.finish(withComposedVideoFrame: destinationPixelBuffer)
    }
    
    private func copyPixelBuffer(source: CVPixelBuffer, destination: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(destination, [])
        
        let sourceData = CVPixelBufferGetBaseAddress(source)
        let destData = CVPixelBufferGetBaseAddress(destination)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(source)
        let height = CVPixelBufferGetHeight(source)
        
        memcpy(destData, sourceData, bytesPerRow * height)
        
        CVPixelBufferUnlockBaseAddress(destination, [])
        CVPixelBufferUnlockBaseAddress(source, .readOnly)
    }
    
    private func createGreenScreenCubeData() -> [Float] {
        var cubeData = [Float]()
        let cubeSize = 64
        
        for z in 0..<cubeSize {
            for y in 0..<cubeSize {
                for x in 0..<cubeSize {
                    let r = Float(x) / Float(cubeSize - 1)
                    let g = Float(y) / Float(cubeSize - 1)
                    let b = Float(z) / Float(cubeSize - 1)
                    
                    // Check if this is a green pixel (high green, low red/blue)
                    let isGreen = g > 0.6 && r < 0.4 && b < 0.4
                    
                    if isGreen {
                        // Make green pixels transparent by setting alpha to 0
                        cubeData.append(r)
                        cubeData.append(g)
                        cubeData.append(b)
                        cubeData.append(0.0) // Alpha = 0 (transparent)
                    } else {
                        // Keep non-green pixels as they are
                        cubeData.append(r)
                        cubeData.append(g)
                        cubeData.append(b)
                        cubeData.append(1.0) // Alpha = 1 (opaque)
                    }
                }
            }
        }
        
        return cubeData
    }
}

#Preview {
    // Create sample exercise data for preview
    let sampleExercise = ExerciseData(
        id: 1,
        name: "Bench Press",
        exerciseType: "Strength",
        bodyPart: "Chest",
        equipment: "Barbell",
        gender: "Both",
        target: "Pectorals",
        synergist: "Triceps, Anterior Deltoid"
    )
    
    let sampleTodayWorkoutExercise = TodayWorkoutExercise(
        exercise: sampleExercise,
        sets: 3,
        reps: 8,
        weight: nil,
        restTime: 90
    )
    
    NavigationView {
        ExerciseLoggingView(exercise: sampleTodayWorkoutExercise)
    }
}