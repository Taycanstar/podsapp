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
import UIKit
import CryptoKit

struct ExerciseLoggingView: View {
    let exercise: TodayWorkoutExercise
    let allExercises: [TodayWorkoutExercise]? // Pass all exercises for the workout
    let onSetLogged: (() -> Void)? // Callback to notify when a set is logged
    @Environment(\.dismiss) private var dismiss
    
    init(exercise: TodayWorkoutExercise, allExercises: [TodayWorkoutExercise]? = nil, onSetLogged: (() -> Void)? = nil) {
        self.exercise = exercise
        self.allExercises = allExercises
        self.onSetLogged = onSetLogged
    }
    @State private var sets: [SetData] = []
    @FocusState private var focusedField: FocusedField?
    @State private var showingFullscreenVideo = false
    @State private var isVideoHidden = false
    @State private var dragOffset: CGFloat = 0
    @State private var showKeyboardToolbar = false
    @State private var showingWorkoutInProgress = false
    @State private var workoutStarted = false
    @State private var currentSetIndex = 0
    @State private var showRIRSection = false
    @State private var rirValue: Double = 0 // RIR (Reps in Reserve) 0-4+
    @State private var isWorkoutComplete = false
    
    enum FocusedField: Hashable {
        case reps(Int)
        case weight(Int)
    }
    
    struct SetData: Identifiable {
        let id = UUID()
        var reps: String
        var weight: String
        var isCompleted: Bool = false
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
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // Exercise name with ellipsis
                        exerciseHeaderSection
                        
                        // Sets input section
                        setsInputSection
                        
                        // RIR Section (shown after Log All Sets)
                        if showRIRSection {
                            rirSection
                                .padding(.top, 20)
                        }
                        
                        // Add bottom padding to ensure content isn't hidden behind floating button
                        Color.clear
                            .frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, isVideoHidden ? 8 : 16)
                }
                .animation(.easeInOut(duration: 0.3), value: isVideoHidden)
            }
            
            // Floating Workout Buttons
            VStack {
                Spacer()
                
                if !workoutStarted {
                    startWorkoutButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, focusedField != nil ? 10 : 20)
                } else if isWorkoutComplete {
                    doneButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, focusedField != nil ? 10 : 20)
                } else {
                    workoutActionButtons
                        .padding(.horizontal, 16)
                        .padding(.bottom, focusedField != nil ? 10 : 20)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: focusedField != nil)
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
            
            // Keyboard toolbar items
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    HStack {
                        Button("Done") {
                            focusedField = nil
                        }
                        .font(.system(size: 16, weight: .medium))
                        
                        Spacer()
                        
                        Button("Next") {
                            moveToNextField()
                        }
                        .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
        .onAppear {
            setupInitialSets()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if newValue != nil && oldValue != newValue {
                // Generate haptic feedback when focus changes
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
            }
        }
        .fullScreenCover(isPresented: $showingFullscreenVideo) {
            if let videoURL = videoURL {
                FullscreenVideoView(videoURL: videoURL, isPresented: $showingFullscreenVideo)
            }
        }
        .fullScreenCover(isPresented: $showingWorkoutInProgress) {
            if let exercises = allExercises {
                WorkoutInProgressView(
                    isPresented: $showingWorkoutInProgress,
                    exercises: exercises
                )
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
                    // Set number with completion indicator
                    ZStack {
                        Circle()
                            .fill(sets[index].isCompleted ? Color.green : 
                                  (workoutStarted && index == currentSetIndex) ? Color.blue.opacity(0.2) : Color.clear)
                            .frame(width: 24, height: 24)
                        
                        if sets[index].isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(workoutStarted && index == currentSetIndex ? .blue : .primary)
                        }
                    }
                    .frame(width: 24, alignment: .leading)
                    
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
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
    
    private var workoutActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: logCurrentSet) {
                Text("Log Set")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            
            Button(action: logAllSets) {
                Text("Log All Sets")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    private var doneButton: some View {
        Button(action: completeWorkout) {
            Text("Done")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
    
    private var rirSection: some View {
        VStack(spacing: 16) {
            Text("Rate Last Set")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("How many more reps could you do?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Apple Fitness-style effort slider
            RIRSlider(value: $rirValue)
                .frame(height: 80)
        }
        .padding()
        .background(Color("tiktoknp"))
        .cornerRadius(12)
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
        workoutStarted = true
        currentSetIndex = 0
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func logCurrentSet() {
        guard currentSetIndex < sets.count else { return }
        
        // Mark current set as completed
        sets[currentSetIndex].isCompleted = true
        onSetLogged?()
        
        // Move to next set
        currentSetIndex += 1
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        print("🏋️ Logged set \(currentSetIndex) of \(sets.count)")
    }
    
    private func logAllSets() {
        // Mark all sets as completed
        for index in sets.indices {
            sets[index].isCompleted = true
        }
        
        // Show RIR section
        showRIRSection = true
        onSetLogged?()
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        print("🏋️ All sets logged, showing RIR section")
    }
    
    private func completeWorkout() {
        isWorkoutComplete = true
        
        // TODO: Save workout data with RIR value
        print("🏋️ Workout completed with RIR: \(rirValue)")
        
        // Show the workout in progress view if we have all exercises
        if let exercises = allExercises {
            print("🏋️ Starting workout with \(exercises.count) exercises")
            showingWorkoutInProgress = true
        }
        
        // Generate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    private func moveToNextField() {
        guard let currentField = focusedField else { return }
        
        // Generate haptic feedback for next button
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        switch currentField {
        case .reps(let index):
            // Move to weight field of same set
            focusedField = .weight(index)
        case .weight(let index):
            // Move to reps field of next set, or dismiss if last
            if index < sets.count - 1 {
                focusedField = .reps(index + 1)
            } else {
                focusedField = nil
            }
        }
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
        // Don't call setup here, let viewDidLoad handle it
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ExerciseVideoPlayerController, context: Context) {
        // Only update if URL actually changed and we need to load a different video
        if uiViewController.videoURL != videoURL {
            // Clean up old player before loading new video
            uiViewController.cleanup()
            uiViewController.videoURL = videoURL
            uiViewController.setupPlayerIfReady()
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: ExerciseVideoPlayerController, coordinator: ()) {
        uiViewController.cleanup()
    }
}

import AVFoundation
import AVKit
import UIKit

class ExerciseVideoPlayerController: UIViewController {
    // MARK: - Public
    var videoURL: URL?

    // MARK: - Private
    private var playerView: UIView!
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerItem: AVPlayerItem?
    private var timeControlObs: NSKeyValueObservation?
    private var fallbackWorkItem: DispatchWorkItem?
    private var loadingIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        DispatchQueue.main.async { [weak self] in
            self?.setupPlayerIfReady()
        }
    }

    // MARK: - UI
    private func setupViews() {
        view.backgroundColor = .clear

        playerView = UIView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.backgroundColor = .clear
        view.addSubview(playerView)

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = .gray
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Playback Setup
func setupPlayerIfReady() {
    guard let url = videoURL else { return }
    loadingIndicator?.startAnimating()

    Task.detached { [weak self] in
        guard let self else { return }
        do {
            // 20s hard timeout to avoid “infinite loader”
            let playableURL = try await withTimeout(seconds: 20) {
                try await VideoPrep.preparePlayableURL(from: url)
            }

            await MainActor.run {
                let item = AVPlayerItem(url: playableURL)
                item.preferredPeakBitRate = 0 // local file; no throttling
                self.setupPlayer(with: item)
                self.player?.playImmediately(atRate: 1.0)
                self.loadingIndicator?.stopAnimating()
            }
        } catch {
            // Clean fallback: try streaming (at least you see something)
            await MainActor.run {
                let asset = AVURLAsset(url: url, options: [AVURLAssetAllowsConstrainedNetworkAccessKey: true])
                let item = AVPlayerItem(asset: asset)
                item.preferredPeakBitRate = 4_000_000
                self.setupPlayer(with: item)
                self.player?.automaticallyWaitsToMinimizeStalling = true
                self.player?.play()
                self.loadingIndicator?.stopAnimating()
            }
        }
    }
}

// Utility: timeout wrapper
func withTimeout<T>(seconds: TimeInterval, _ op: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await op() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw NSError(domain: "VideoPrepTimeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Prep timed out"])
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}



    private func startStreaming(_ url: URL) {
        // Use AVURLAsset so we can tweak network behavior
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetAllowsConstrainedNetworkAccessKey: true
        ])
        let item = AVPlayerItem(asset: asset)
        item.preferredPeakBitRate = 4_000_000 // ~4 Mbps to avoid stalls

        setupPlayer(with: item)

        // Observe time control to know when we actually start playing
        timeControlObs = player?.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            guard let self = self else { return }
            switch player.timeControlStatus {
            case .playing:
                // Streaming started → cancel fallback
                self.loadingIndicator.stopAnimating()
                self.fallbackWorkItem?.cancel()
            case .waitingToPlayAtSpecifiedRate:
                // still buffering; keep spinner
                break
            case .paused:
                // If we're "ready" but paused, nudge
                if player.currentItem?.status == .readyToPlay {
                    player.playImmediately(atRate: 1.0)
                }
            @unknown default: break
            }
        }

        player?.playImmediately(atRate: 1.0)
    }

    private func setupPlayer(with item: AVPlayerItem) {
        playerItem = item

        let p = AVPlayer(playerItem: item)
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        player = p

        if playerLayer == nil {
            let layer = AVPlayerLayer(player: p)
            layer.videoGravity = .resizeAspect
            layer.backgroundColor = UIColor.clear.cgColor
            playerLayer = layer
            playerView.layer.addSublayer(layer)
        } else {
            playerLayer?.player = p
        }

        // Auto-loop
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(loopVideo),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        // Ensure layer has a valid frame before first frame render
        view.setNeedsLayout()
        view.layoutIfNeeded()
        playerLayer?.frame = playerView.bounds
    }

    // MARK: - Fallback: Download then play locally
    private func downloadAndPlay(_ url: URL) {
        loadingIndicator.startAnimating()

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, error in
            guard let self = self else { return }
            if let error = error {
                print("Download error: \(error)")
                DispatchQueue.main.async { self.loadingIndicator.stopAnimating() }
                return
            }
            guard let tempURL = tempURL else {
                DispatchQueue.main.async { self.loadingIndicator.stopAnimating() }
                return
            }
            // Move to a stable temp path
            let localURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString + ".mov")
            try? FileManager.default.removeItem(at: localURL)
            do {
                try FileManager.default.moveItem(at: tempURL, to: localURL)
            } catch {
                print("File move error: \(error)")
            }

            // Play local file (no streaming quirks)
            let item = AVPlayerItem(url: localURL)
            item.preferredPeakBitRate = 0 // unrestricted for local
            DispatchQueue.main.async {
                self.setupPlayer(with: item)
                self.player?.playImmediately(atRate: 1.0)
                self.loadingIndicator.stopAnimating()
            }
        }
        task.resume()
    }

    // MARK: - Layout & Cleanup
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = playerView.bounds

        // If we’re ready but paused (sometimes happens during layout), nudge
        if player?.currentItem?.status == .readyToPlay, player?.timeControlStatus != .playing {
            player?.playImmediately(atRate: 1.0)
        }
    }

    @objc private func loopVideo() {
        player?.seek(to: .zero) { [weak self] _ in
            self?.player?.play()
        }
    }

    func cleanup() {
        fallbackWorkItem?.cancel()
        timeControlObs = nil
        NotificationCenter.default.removeObserver(self)

        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerItem = nil

        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil
    }
}

// MARK: - RIR Slider Component

struct RIRSlider: View {
    @Binding var value: Double
    @State private var lastHapticValue: Int = -1
    
    private let maxRIR: Double = 4
    private let barCount = 5 // 0, 1, 2, 3, 4+
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                // Triangular bars (like Apple Fitness)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<barCount, id: \.self) { index in
                        RIRTriangleBar(
                            height: barHeight(for: index),
                            isActive: Double(index) <= value,
                            isPartial: shouldShowPartial(for: index)
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Labels below bars
                HStack(spacing: 3) {
                    ForEach(0..<barCount, id: \.self) { index in
                        Text(barLabel(for: index))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Double(index) <= value ? .accentColor : .gray)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(
                // Invisible drag area
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let progress = gesture.location.x / geometry.size.width
                                let clampedProgress = max(0, min(1, progress))
                                value = clampedProgress * maxRIR
                                
                                // Subtle haptic feedback only when crossing integer values
                                let currentIntValue = Int(value)
                                if currentIntValue != lastHapticValue {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
                                    impactFeedback.prepare()
                                    impactFeedback.impactOccurred(intensity: 0.3)
                                    lastHapticValue = currentIntValue
                                }
                            }
                    )
            )
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 16
        let maxHeight: CGFloat = 50
        let heightIncrement = (maxHeight - baseHeight) / CGFloat(barCount - 1)
        return baseHeight + (heightIncrement * CGFloat(index))
    }
    
    private func shouldShowPartial(for index: Int) -> Bool {
        let indexValue = Double(index)
        return value > indexValue && value < indexValue + 1
    }
    
    private func barLabel(for index: Int) -> String {
        if index == barCount - 1 {
            return "4+"
        } else {
            return "\(index)"
        }
    }
}

struct RIRTriangleBar: View {
    let height: CGFloat
    let isActive: Bool
    let isPartial: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background bar (inactive state)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(height: height)
            
            // Active bar with smooth gradient fill
            if isActive || isPartial {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.8), .accentColor],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: height * (isPartial ? 0.5 : 1.0))
                    .animation(.easeInOut(duration: 0.15), value: isActive)
                    .animation(.easeInOut(duration: 0.15), value: isPartial)
            }
        }
    }
}

enum VideoPrepError: Error { case badDownload, exportFailed }

struct VideoPrep {
    /// Returns a local, device-friendly MP4 for the remote MOV (downloads + transcodes once, then caches).
    static func preparePlayableURL(from remoteURL: URL) async throws -> URL {
        // Cache path based on URL hash
        let cacheDir = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ExerciseVideos", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let key = sha256(remoteURL.absoluteString)
        let cachedMP4 = cacheDir.appendingPathComponent("\(key).mp4")

        if FileManager.default.fileExists(atPath: cachedMP4.path) {
            return cachedMP4
        }

        // 1) Download the .mov
        let (tempMOV, _) = try await URLSession.shared.download(from: remoteURL)
        let localMOV = cacheDir.appendingPathComponent("\(key).mov")
        try? FileManager.default.removeItem(at: localMOV)
        try FileManager.default.moveItem(at: tempMOV, to: localMOV)

        // 2) Decide whether we need to transcode (we do, because MOV often heavy),
        //    but keep it resilient: if export fails, fall back to just returning the .mov.
        let asset = AVURLAsset(url: localMOV)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080) ??
                           AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            // If we can't create an exporter, use the original file as last resort
            return localMOV
        }

        export.outputURL = cachedMP4
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true
        try? FileManager.default.removeItem(at: cachedMP4)

        // 3) Export (transcode) to H.264 MP4 (system chooses H.264 for .mp4)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            export.exportAsynchronously {
                switch export.status {
                case .completed:
                    cont.resume()
                case .failed, .cancelled:
                    cont.resume(throwing: export.error ?? VideoPrepError.exportFailed)
                default:
                    break
                }
            }
        }

        return cachedMP4
    }

    private static func sha256(_ s: String) -> String {
        let data = Data(s.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
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
        ExerciseLoggingView(exercise: sampleTodayWorkoutExercise, allExercises: nil)
    }
}
