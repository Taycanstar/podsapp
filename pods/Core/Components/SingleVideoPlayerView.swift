//
//  SingleVideoPlayerView.swift
//  Podstack
//
//  Created by Dimi Nunez on 10/9/24.
//

import SwiftUI
import AVKit
import AVFoundation
import Combine
import Network

struct SingleVideoPlayerView: View {
    let item: PodItem
    @StateObject private var playerManager = PlayerManager()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let player = playerManager.currentPlayer {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        playerManager.togglePlayPause()
                    }
            } else if playerManager.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
            } else if playerManager.error != nil {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                        .font(.largeTitle)
                    Text("Failed to load video")
                        .foregroundColor(.white)
                    Button("Retry") {
                        playerManager.loadVideo(for: item)
                    }
                    .foregroundColor(.blue)
                    .padding()
                }
            }
            
//            VStack {
//                Spacer()
//                Text(item.notes ?? "")
//                    .foregroundColor(.white)
//                    .padding()
//            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
            }
            ToolbarItem(placement: .principal) {
                Text(item.metadata)
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
        .onAppear {
            playerManager.loadVideo(for: item)
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }
}




class PlayerManager: ObservableObject {
    @Published var currentPlayer: AVPlayer?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var looper: AVPlayerLooper?
    private var cancellables = Set<AnyCancellable>()
    private let monitor = NWPathMonitor()
    private var currentItemObserver: NSKeyValueObservation?
    
    init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.adjustSettingsForNetwork(path: path)
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    private func adjustSettingsForNetwork(path: NWPath) {
        guard let player = currentPlayer, let playerItem = player.currentItem else { return }
        
        if path.usesInterfaceType(.cellular) {
            playerItem.preferredPeakBitRate = 300_000 // Lower bit rate for cellular
            playerItem.preferredForwardBufferDuration = 10 // Increase buffer duration
        } else if path.usesInterfaceType(.wifi) {
            playerItem.preferredPeakBitRate = 1_500_000 // Higher bit rate for Wi-Fi
            playerItem.preferredForwardBufferDuration = 5 // Default buffer duration
        }
        
        // Ensure playback starts or resumes after network change
        if player.timeControlStatus != .playing {
            player.play()
        }
    }
    
    func loadVideo(for item: PodItem) {
        guard let url = item.videoURL else {
            self.error = NSError(domain: "InvalidURL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
            return
        }
        
        isLoading = true
        error = nil
        
        let asset = AVURLAsset(url: url)
        
        if #available(iOS 16.0, *) {
            Task {
                do {
                    try await asset.load(.isPlayable)
                    await MainActor.run {
                        self.prepareToPlay(asset: asset)
                    }
                } catch {
                    await MainActor.run {
                        self.error = error
                        self.isLoading = false
                    }
                }
            }
        } else {
            asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
                DispatchQueue.main.async {
                    self?.prepareToPlay(asset: asset)
                }
            }
        }
    }
    
    private func prepareToPlay(asset: AVURLAsset) {
        do {
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVQueuePlayer(playerItem: playerItem)
            
            // Set initial network-friendly settings
            playerItem.preferredPeakBitRate = 1_500_000
            playerItem.preferredForwardBufferDuration = 5
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            
            self.looper = AVPlayerLooper(player: player, templateItem: playerItem)
            
            // Observe buffering state
            currentItemObserver = player.observe(\.currentItem?.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.isLoading = !(player.currentItem?.isPlaybackLikelyToKeepUp ?? false)
                }
            }
            
            self.currentPlayer = player
            player.play()
            
            // Adjust settings based on current network condition
            adjustSettingsForNetwork(path: monitor.currentPath)
        } catch {
            self.error = error
        }
        
        self.isLoading = false
    }
    
    func togglePlayPause() {
        if let player = currentPlayer {
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
        }
    }
    
    func cleanup() {
        currentPlayer?.pause()
        currentPlayer = nil
        looper = nil
        cancellables.removeAll()
        currentItemObserver?.invalidate()
    }
    
    deinit {
        monitor.cancel()
    }
}

