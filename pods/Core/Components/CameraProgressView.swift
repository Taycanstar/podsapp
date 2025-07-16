import SwiftUI
import PhotosUI

struct CameraProgressView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPhoto: UIImage?
    
    var body: some View {
        ZStack {
            // Black background for safe areas
            Color.black
                .ignoresSafeArea(.all)
            
            // Main camera view
            CustomImagePicker(selectedPhoto: $selectedPhoto, sourceType: .camera, showGalleryButton: .constant(false)) {
                dismiss()
            }
            .ignoresSafeArea(.all)
            
            // Overlay removed - photo selection now handled by dropdown in EditWeightView
        }
    }
}


final class UnmirroredFrontPicker: UIImagePickerController {
    var hideGalleryButton: (() -> Void)?
    var showGalleryButton: (() -> Void)?

    // MARK: – Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Observe capture / retake events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidCapture),
            name: NSNotification.Name(rawValue: "_UIImagePickerControllerUserDidCaptureItem"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidReject),
            name: NSNotification.Name(rawValue: "_UIImagePickerControllerUserDidRejectCapturedItem"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: – Private

    /// Flip preview after shutter for **front** camera only.
    @objc private func handleDidCapture() {
        // Only handle camera device when source type is camera
        guard sourceType == .camera && cameraDevice == .front else { 
            // Still hide gallery button even for back camera or photo library
            hideGalleryButton?()
            return 
        }
        flipFrozenPreview(mirrored: false) // un‑mirror it
        hideGalleryButton?() // Hide gallery button during preview
    }

    /// On "Retake" we reset transforms so the live preview is clean.
    @objc private func handleDidReject() {
        resetPreviewTransform()
        showGalleryButton?() // Show gallery button again
    }

    private func flipFrozenPreview(mirrored: Bool) {
        let scaleX: CGFloat = mirrored ? 1 : -1
        traverseAndTransform(view, scaleX: scaleX)
    }

    private func resetPreviewTransform() {
        traverseAndTransform(view, scaleX: 1)
    }

    private func traverseAndTransform(_ root: UIView, scaleX: CGFloat) {
        if root is UIImageView {
            root.transform = CGAffineTransform(scaleX: scaleX, y: 1)
        }
        for sub in root.subviews {
            traverseAndTransform(sub, scaleX: scaleX)
        }
    }
}

struct CustomImagePicker: UIViewControllerRepresentable {
    @Binding var selectedPhoto: UIImage?
    var sourceType: UIImagePickerController.SourceType
    var showGalleryButton: Binding<Bool>
    var onImageSelected: () -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UnmirroredFrontPicker()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        
        // Set up gallery button callbacks
        picker.hideGalleryButton = {
            DispatchQueue.main.async {
                self.showGalleryButton.wrappedValue = false
            }
        }
        picker.showGalleryButton = {
            DispatchQueue.main.async {
                self.showGalleryButton.wrappedValue = true
            }
        }
        
        // Fix camera positioning and configuration
        if sourceType == .camera {
            picker.cameraDevice = .rear
            picker.cameraCaptureMode = .photo
            picker.cameraFlashMode = .auto
            picker.showsCameraControls = true
            picker.allowsEditing = false
            // Keep camera view clean
            picker.cameraViewTransform = CGAffineTransform.identity
            
            // Store the camera device in coordinator for later use
            context.coordinator.cameraDevice = picker.cameraDevice
        }
        
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CustomImagePicker
        var cameraDevice: UIImagePickerController.CameraDevice?
        var isFrontCamera = false

        init(_ parent: CustomImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let usedFront = (picker.sourceType == .camera && picker.cameraDevice == .front)
            guard let raw = info[.originalImage] as? UIImage else { return }
            
            // 1️⃣ Update the binding *first*
            let final = usedFront ? flipImageHorizontally(raw) : raw
                DispatchQueue.main.async {
                self.parent.selectedPhoto = final 
            }

            // 2️⃣ Now close the picker, then close CameraProgressView
            picker.dismiss(animated: true) { [parent] in
                DispatchQueue.main.async { 
                    parent.onImageSelected() 
                }
            }
        }
        
        // Helper function to flip image horizontally (for front camera only)
        private func flipImageHorizontally(_ image: UIImage) -> UIImage {
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            
            let context = UIGraphicsGetCurrentContext()
            
            // Flip the image horizontally
            context?.translateBy(x: image.size.width, y: 0)
            context?.scaleBy(x: -1.0, y: 1.0)
            
            // Draw the image
            image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
            
            // Get the flipped image
            let flippedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return flippedImage ?? image
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                DispatchQueue.main.async {
                    self.parent.onImageSelected()
                }
            }
        }
    }
}
