import SwiftUI
import PhotosUI

struct CameraProgressView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPhoto: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        ZStack {
            // Black background for safe areas
            Color.black
                .ignoresSafeArea(.all)
            
            // Main camera view
            CustomImagePicker(selectedPhoto: $selectedPhoto, sourceType: .camera) {
                dismiss()
            }
            .ignoresSafeArea(.all)
            
            // Overlay with gallery button
            VStack {
                Spacer()
                
                HStack {
                    // Gallery button (positioned higher, above native cancel button)
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Image(systemName: "photo")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.leading, 30)
                    
                    Spacer()
                }
                .padding(.bottom, 120) // Higher position to sit above native controls
            }
        }
        .sheet(isPresented: $showImagePicker) {
            CustomImagePicker(selectedPhoto: $selectedPhoto, sourceType: .photoLibrary) {
                dismiss()
            }
        }
    }
}

/// UIImagePickerController subclass that flips the **frozen** preview image
/// (the one shown between capture and “Use Photo”) so it matches the live
/// front‑camera feed.
///
/// How it works:
/// ‑ We listen for the private notification
///   “_UIImagePickerControllerUserDidCaptureItem” which fires immediately
///   after the shutter animation.
/// ‑ When the current camera is `.front`, we walk the picker’s view hierarchy
///   and apply a horizontal flip (`scaleX: -1`) to every `UIImageView`.  
///   Those `UIImageView`s are exactly what Apple uses to show the frozen
///   preview frame.  Live preview layers remain untouched.
///
/// ⚠️  Apple doesn’t provide a public API to do this; dozens of apps ship
///     with the same workaround (see LEMirroredImagePicker).  As of iOS 17
///     this passes App Review because we only transform our own view tree.
final class UnmirroredFrontPicker: UIImagePickerController {

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
        guard cameraDevice == .front else { return }
        flipFrozenPreview(mirrored: false) // un‑mirror it
    }

    /// On “Retake” we reset transforms so the live preview is clean.
    @objc private func handleDidReject() {
        resetPreviewTransform()
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
    var onImageSelected: () -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UnmirroredFrontPicker()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        
        // Fix camera positioning and configuration
        if sourceType == .camera {
            picker.cameraDevice = .rear
            picker.cameraCaptureMode = .photo
            picker.cameraFlashMode = .auto
            picker.showsCameraControls = true
            picker.allowsEditing = false
            // Keep system‑provided cameraViewTransform to preserve correct orientation
            // picker.cameraViewTransform = CGAffineTransform.identity
            
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
            // Check if front camera was used
            self.isFrontCamera = (picker.cameraDevice == .front)
            
            // Dismiss the picker first
            picker.dismiss(animated: true) {
                // Then update the binding and call completion on main thread
                DispatchQueue.main.async {
                    if let uiImage = info[.originalImage] as? UIImage {
                        // Fix front camera mirroring issue only for front camera
                        let correctedImage = self.isFrontCamera ? self.flipImageHorizontally(uiImage) : uiImage
                        self.parent.selectedPhoto = correctedImage
                    }
                    self.parent.onImageSelected()
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
