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
    @State private var showingFullscreenVideo = false
    @State private var isVideoHidden = false
    @State private var dragOffset: CGFloat = 0
    
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
        ZStack {
            VStack(spacing: 0) {
                // Video Header
                if !isVideoHidden {
                    videoHeaderView
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                
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
                .padding(.top, isVideoHidden ? 8 : 16)
                .animation(.easeInOut(duration: 0.3), value: isVideoHidden)
            }
            
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Track gesture for potential header hiding
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    let velocity = value.predictedEndLocation.y - value.location.y
                    let translation = value.translation.height
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // Hide if swiping up with sufficient velocity or distance
                        if (velocity < -300) || (translation < -50 && velocity < 0) {
                            isVideoHidden = true
                        }
                        // Show if swiping down with sufficient velocity or distance
                        else if (velocity > 300) || (translation > 50 && velocity > 0) {
                            isVideoHidden = false
                        }
                        
                        dragOffset = 0
                    }
                }
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            setupInitialSets()
        }
        .fullScreenCover(isPresented: $showingFullscreenVideo) {
            if let videoURL = videoURL {
                FullscreenVideoView(videoURL: videoURL, isPresented: $showingFullscreenVideo)
            }
        }
    }
    
    private var videoHeaderView: some View {
        Group {
            if let videoURL = videoURL {
                CustomExerciseVideoPlayer(videoURL: videoURL)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .onTapGesture {
                        showingFullscreenVideo = true
                    }
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
        // Videos were encoded as ProRes 4444 and stored as .mov in Azure
        let videoId = String(format: "%04d", exercise.exercise.id)
        return URL(string:
            "https://humulistoragecentral.blob.core.windows.net/videos/alpha_vids/\(videoId).mov"
        )
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
        
        // Create simple player
        player = AVPlayer(url: videoURL)
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
        player?.replaceCurrentItem(with: nil)  // Properly release video memory
        playerLayer?.removeFromSuperlayer()
        NotificationCenter.default.removeObserver(self)
        player = nil
        playerLayer = nil
    }
}

// MARK: - Fullscreen Video View

struct FullscreenVideoView: View {
    let videoURL: URL
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Video player
            CustomExerciseVideoPlayer(videoURL: videoURL)
                .ignoresSafeArea()
            
            // Close button overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                Spacer()
            }
        }
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
