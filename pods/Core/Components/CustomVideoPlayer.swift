import SwiftUI
import AVKit

struct CustomVideoPlayer: UIViewControllerRepresentable {
    var player: AVPlayer
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller =  AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
//        controller.exitsFullScreenWhenPlaybackEnds = true
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.allowsPictureInPicturePlayback = true
        controller.videoGravity = .resizeAspectFill
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        
    }
}

//struct CustomVideoPlayer: UIViewControllerRepresentable {
//    var player: AVPlayer
//
//    func makeUIViewController(context: Context) -> AVPlayerViewController {
//        let controller = AVPlayerViewController()
//        controller.player = player
//        controller.showsPlaybackControls = false
//        controller.exitsFullScreenWhenPlaybackEnds = true
//        controller.allowsPictureInPicturePlayback = true
//        controller.videoGravity = .resizeAspectFill
//        return controller
//    }
//
//    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
//        if uiViewController.player != player {
//            uiViewController.player = player
//        }
//    }
//
//    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: ()) {
//        uiViewController.player?.pause()
//        uiViewController.player = nil
//    }
//}
