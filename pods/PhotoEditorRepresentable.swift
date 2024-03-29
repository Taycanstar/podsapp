import SwiftUI
import AVKit

struct PhotoEditorRepresentable: UIViewControllerRepresentable {
    var editingImage: UIImage?
    // Update the closure type to accept VideoEditParameters
    var onConfirmEditing: ((VideoEditParameters) -> Void)?

    func makeUIViewController(context: Context) -> PhotoEditorViewController {
        let editorVC = PhotoEditorViewController()
        editorVC.editingImage = editingImage
        editorVC.onConfirmEditing = { editParameters in
            DispatchQueue.main.async {
                self.onConfirmEditing?(editParameters)
            }
        }
        return editorVC
    }


    func updateUIViewController(_ uiViewController: PhotoEditorViewController, context: Context) {
        // Update the videoURL of the UIViewController if needed
        if uiViewController.editingImage != editingImage {
            uiViewController.editingImage = editingImage
        }
    }
    
    
}


