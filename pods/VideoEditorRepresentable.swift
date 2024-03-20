import SwiftUI
import AVKit

struct VideoEditorRepresentable: UIViewControllerRepresentable {
    var videoURL: URL

    func makeUIViewController(context: Context) -> VideoEditorViewController {
        let editorVC = VideoEditorViewController()
        editorVC.videoURL = videoURL
        return editorVC
    }
    
    func updateUIViewController(_ uiViewController: VideoEditorViewController, context: Context) {
        // Update the view controller if needed.
    }
}
