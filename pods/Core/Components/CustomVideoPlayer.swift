

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
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.allowsPictureInPicturePlayback = true
        controller.videoGravity = .resizeAspect // Maintain aspect ratio without cropping
        
        loadAsset(url: url, controller: controller)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let player = player {
            if isCurrentVideo && player.timeControlStatus != .playing {
                player.play()
            } else if !isCurrentVideo && player.timeControlStatus == .playing {
                player.pause()
            }
        }
    }
    
    private func loadAsset(url: URL, controller: AVPlayerViewController) {
        let asset = AVAsset(url: url)
        
        Task {
            do {
                let (_, _, _) = try await asset.load(.tracks, .duration, .preferredTransform)
                let playerItem = AVPlayerItem(asset: asset)
                let player = AVPlayer(playerItem: playerItem)
                
                // Set up looping
                player.actionAtItemEnd = .none
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
                    player.seek(to: .zero)
                    if self.isCurrentVideo {
                        player.play()
                    }
                }
                
                await MainActor.run {
                    controller.player = player
                    self.player = player
                    if self.isCurrentVideo {
                        player.play()
                    }
                }
            } catch {
                print("Error loading asset: \(error.localizedDescription)")
            }
        }
    }
    
    static func dismantleUIViewController(uiViewController: UIViewController, coordinator: ()) {
        guard let controller = uiViewController as? AVPlayerViewController else { return }
        controller.player?.pause()
        controller.player = nil
        NotificationCenter.default.removeObserver(controller.player as Any)
    }
}
