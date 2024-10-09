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
            
            VStack {
                Spacer()
                Text(item.notes ?? "")
                    .foregroundColor(.white)
                    .padding()
            }
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
    
    func loadVideo(for item: PodItem) {
        guard let url = item.videoURL else { return }
        
        isLoading = true
        error = nil
        
        let asset = AVURLAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
            DispatchQueue.main.async {
                self?.prepareToPlay(asset: asset)
            }
        }
    }
    
    private func prepareToPlay(asset: AVURLAsset) {
        do {
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVQueuePlayer(playerItem: playerItem)
            
            // Enable adaptive bitrate streaming
            player.currentItem?.preferredPeakBitRate = 1_500_000 // 1.5 Mbps, adjust as needed
            
            // Configure AVPlayerItem for better performance on cellular
            playerItem.preferredForwardBufferDuration = 5 // Buffer 5 seconds ahead
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            
            self.looper = AVPlayerLooper(player: player, templateItem: playerItem)
            
            // Observe buffering state
            player.currentItem?.publisher(for: \.isPlaybackLikelyToKeepUp)
                .sink { [weak self] isLikelyToKeepUp in
                    self?.isLoading = !isLikelyToKeepUp
                }
                .store(in: &cancellables)
            
            self.currentPlayer = player
            player.play()
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
    }
}

