

import SwiftUI
import AVKit
import Combine
import AVFoundation


struct CustomVideoPlayer: UIViewControllerRepresentable {
    var player: AVPlayer
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.allowsPictureInPicturePlayback = true
        controller.videoGravity = .resizeAspectFill
        
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: ()) {
        guard let controller = uiViewController as? AVPlayerViewController else { return }
        controller.player?.pause()
        controller.player = nil
    }
}


//struct CustomVideoPlayer2: UIViewControllerRepresentable {
//    var url: URL
//    @Binding var player: AVPlayer?
//    var isCurrentVideo: Bool
//    
//    func makeUIViewController(context: Context) -> UIViewController {
//        let controller = AVPlayerViewController()
//        controller.showsPlaybackControls = false
//        controller.exitsFullScreenWhenPlaybackEnds = false
//        controller.allowsPictureInPicturePlayback = true
//        controller.videoGravity = .resizeAspectFill
//        
//        loadAsset(url: url, controller: controller)
//        
//        return controller
//    }
//    
//    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
//        if let player = player {
//            if isCurrentVideo && player.timeControlStatus != .playing {
//                player.play()
//            } else if !isCurrentVideo && player.timeControlStatus == .playing {
//                player.pause()
//            }
//        }
//    }
//    
//    private func loadAsset(url: URL, controller: AVPlayerViewController) {
//        let asset = AVAsset(url: url)
//        
//        Task {
//            do {
//                let (_, _, _) = try await asset.load(.tracks, .duration, .preferredTransform)
//                let playerItem = AVPlayerItem(asset: asset)
//                let player = AVPlayer(playerItem: playerItem)
//                
//                // Set up looping
//                player.actionAtItemEnd = .none
//                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
//                    player.seek(to: .zero)
//                    if self.isCurrentVideo {
//                        player.play()
//                    }
//                }
//                
//                await MainActor.run {
//                    controller.player = player
//                    self.player = player
//                    if self.isCurrentVideo {
//                        player.play()
//                    }
//                }
//            } catch {
//                print("Error loading asset: \(error.localizedDescription)")
//            }
//        }
//    }
//    
//    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: ()) {
//        guard let controller = uiViewController as? AVPlayerViewController else { return }
//        controller.player?.pause()
//        controller.player = nil
//        NotificationCenter.default.removeObserver(controller.player as Any)
//    }
//}
struct CustomVideoPlayer2: UIViewControllerRepresentable {
    var url: URL
    @Binding var player: AVPlayer?
    var isCurrentVideo: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.allowsPictureInPicturePlayback = true
        controller.videoGravity = .resizeAspect
        
        if player == nil {
            loadAsset(url: url, controller: controller)
        } else {
            controller.player = player
        }
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        controller.view.addGestureRecognizer(tapGesture)
        
        return controller
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if let player = player {
            uiViewController.player = player
            if isCurrentVideo {
                player.seek(to: .zero)
                player.play()
            } else {
                player.pause()
            }
        }
    }
    
    private func loadAsset(url: URL, controller: AVPlayerViewController) {
        let asset = AVAsset(url: url)
        
        Task {
            do {
                let playerItem = AVPlayerItem(asset: asset)
                let newPlayer = AVPlayer(playerItem: playerItem)
                
                // Set up looping
                newPlayer.actionAtItemEnd = .none
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
                    newPlayer.seek(to: .zero)
                    if self.isCurrentVideo {
                        newPlayer.play()
                    }
                }
                
                await MainActor.run {
                    controller.player = newPlayer
                    self.player = newPlayer
                    if self.isCurrentVideo {
                        newPlayer.play()
                    }
                }
            } catch {
                print("Error loading asset: \(error.localizedDescription)")
            }
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: ()) {
        uiViewController.player?.pause()
        uiViewController.player = nil
        NotificationCenter.default.removeObserver(uiViewController)
    }
    
    class Coordinator: NSObject {
        var parent: CustomVideoPlayer2
        
        init(_ parent: CustomVideoPlayer2) {
            self.parent = parent
        }
        
        @objc func handleTap() {
            if let player = parent.player {
                if player.timeControlStatus == .playing {
                    player.pause()
                } else {
                    player.play()
                }
            }
        }
    }
}



class VideoPreloader: ObservableObject {
    @Published var preloadedPlayers: [Int: AVPlayer] = [:]
    @Published var preloadProgress: [Int: Double] = [:]
    private var cancellables: Set<AnyCancellable> = []
    
    private let maxPreloadedVideos = 3
    
    func preloadVideos(for items: [PodItem]) {
        // Preload the first few videos
        for (index, item) in items.prefix(maxPreloadedVideos).enumerated() {
            preloadVideo(for: item, at: index)
        }
    }
    
    private func preloadVideo(for item: PodItem, at index: Int) {
        guard let videoURL = item.videoURL else { return }
        
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        
        // Preload only the first 15 seconds
        player.currentItem?.preferredForwardBufferDuration = 15
        
        // Monitor player status
        player.publisher(for: \.status)
            .filter { $0 == .readyToPlay }
            .first()
            .sink { [weak self] _ in
                self?.performPreroll(player: player, for: item)
            }
            .store(in: &cancellables)
        
        // Monitor loading progress
        monitorLoadingProgress(for: playerItem, itemId: item.id)
        
        // Store the player
        preloadedPlayers[item.id] = player
    }
    
    private func performPreroll(player: AVPlayer, for item: PodItem) {
        player.preroll(atRate: 1) { [weak self] finished in
            if finished {
                DispatchQueue.main.async {
                    self?.preloadProgress[item.id] = 1.0
                }
            }
        }
    }
    
    private func monitorLoadingProgress(for playerItem: AVPlayerItem, itemId: Int) {
        playerItem.publisher(for: \.loadedTimeRanges)
            .compactMap { $0.first as? CMTimeRange }
            .map { timeRange -> Double in
                let loadedDuration = CMTimeGetSeconds(timeRange.duration)
                let totalDuration = CMTimeGetSeconds(playerItem.duration)
                return totalDuration > 0 ? min(loadedDuration / totalDuration, 1.0) : 0
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.preloadProgress[itemId] = progress
            }
            .store(in: &cancellables)
    }
    
    func getPlayer(for itemId: Int) -> AVPlayer? {
        return preloadedPlayers[itemId]
    }
    
    func updatePreloadedVideos(currentIndex: Int, items: [PodItem]) {
        let startIndex = max(0, currentIndex - 1)
        let endIndex = min(items.count - 1, currentIndex + 1)
        
        for index in startIndex...endIndex {
            let item = items[index]
            if preloadedPlayers[item.id] == nil {
                preloadVideo(for: item, at: index)
            }
        }
        
        // Clean up videos that are no longer needed
        let keepRange = Set(startIndex...endIndex)
        preloadedPlayers = preloadedPlayers.filter { itemId, _ in
            keepRange.contains(items.firstIndex(where: { $0.id == itemId }) ?? -1)
        }
    }
    func setPlayer(for itemId: Int, player: AVPlayer?) {
        preloadedPlayers[itemId] = player
    }

}

