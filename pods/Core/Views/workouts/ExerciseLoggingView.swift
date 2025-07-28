//
//  ExerciseLoggingView.swift
//  pods
//
//  Created by Dimi Nunez on 7/27/25.
//

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
    @State private var sets: [SetData] = []
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField: Hashable {
        case reps(Int)
        case weight(Int)
    }
    
    struct SetData: Identifiable {
        let id = UUID()
        var reps: String
        var weight: String
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Video Header
            videoHeaderView
            
            VStack(spacing: 16) {
                // Exercise name with ellipsis
   
                exerciseHeaderSection
                
                // Sets input section
                setsInputSection
                
                Spacer()
                
                // Start Workout button
                startWorkoutButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .navigationBarHidden(true)
        .onAppear {
            setupInitialSets()
        }
    }
    
    private var videoHeaderView: some View {
        Group {
            if let videoURL = videoURL {
                CustomExerciseVideoPlayer(videoURL: videoURL)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var exerciseHeaderSection: some View {
        HStack {
            Text(exercise.exercise.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.primary)
                    .font(.title2)
            }
        }
    }
    
    private var setsInputSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 20, alignment: .leading)
                    
                    TextField("8 reps", text: Binding(
                        get: { sets[index].reps },
                        set: { sets[index].reps = $0 }
                    ))
                    .focused($focusedField, equals: .reps(index))
                    .textFieldStyle(CustomTextFieldStyle2(isFocused: focusedField == .reps(index)))
                    .keyboardType(.numberPad)
                    
                    TextField("150 lbs", text: Binding(
                        get: { sets[index].weight },
                        set: { sets[index].weight = $0 }
                    ))
                    .focused($focusedField, equals: .weight(index))
                    .textFieldStyle(CustomTextFieldStyle2(isFocused: focusedField == .weight(index)))
                    .keyboardType(.decimalPad)
                }
            }
            
            Button(action: addSet) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                    Text("Add Set")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.primary)
                .padding(.top, 8)
            }
        }
    }
    
    private var startWorkoutButton: some View {
        Button(action: startWorkout) {
            Text("Start Workout")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Computed Properties

    private var videoURL: URL? {
        let videoId = String(format: "%04d", exercise.exercise.id)
        return URL(string: "https://humulistoragecentral.blob.core.windows.net/videos/filtered_vids/\(videoId).mp4")
    }
    
    private var thumbnailImageName: String {
        return String(format: "%04d", exercise.exercise.id)
    }
    
    // MARK: - Methods
    
    private func setupInitialSets() {
        sets = Array(1...exercise.sets).map { _ in
            SetData(
                reps: "\(exercise.reps)",
                weight: exercise.exercise.equipment.lowercased() == "body weight" ? "" : "150"
            )
        }
    }
    
    private func addSet() {
        let newSet = SetData(
            reps: "\(exercise.reps)",
            weight: exercise.exercise.equipment.lowercased() == "body weight" ? "" : "150"
        )
        sets.append(newSet)
    }
    
    private func startWorkout() {
        // TODO: Start workout logic
        dismiss()
    }
    
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle2: TextFieldStyle {
    let isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.blue : Color(.systemGray4), lineWidth: isFocused ? 2 : 1)
            )
            .foregroundColor(isFocused ? .blue : .primary)
            .font(.system(size: 16, weight: .medium))
    }
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