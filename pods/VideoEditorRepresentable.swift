import SwiftUI
import AVKit

struct VideoEditorRepresentable: UIViewControllerRepresentable {
    var videoURL: URL
    // Update the closure type to accept VideoEditParameters
    var onConfirmEditing: ((VideoEditParameters) -> Void)?

    func makeUIViewController(context: Context) -> VideoEditorViewController {
        let editorVC = VideoEditorViewController()
        editorVC.videoURL = videoURL
        // Pass the editing parameters back to the SwiftUI view
        editorVC.onConfirmEditing = { editParameters in
            DispatchQueue.main.async {
                self.onConfirmEditing?(editParameters)
            }
        }
        return editorVC
    }

    func updateUIViewController(_ uiViewController: VideoEditorViewController, context: Context) {
        // Update the videoURL of the UIViewController if needed
        if uiViewController.videoURL != videoURL {
            uiViewController.videoURL = videoURL
        }
    }
}


