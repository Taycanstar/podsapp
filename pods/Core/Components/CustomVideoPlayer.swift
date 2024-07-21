

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

