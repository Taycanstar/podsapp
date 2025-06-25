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

struct CustomImagePicker: UIViewControllerRepresentable {
    @Binding var selectedPhoto: UIImage?
    var sourceType: UIImagePickerController.SourceType
    var onImageSelected: () -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        
        // Fix camera positioning and configuration
        if sourceType == .camera {
            picker.cameraDevice = .rear
            picker.cameraCaptureMode = .photo
            picker.cameraFlashMode = .auto
            picker.showsCameraControls = true
            picker.allowsEditing = false
            // Allow different aspect ratios
            picker.cameraViewTransform = CGAffineTransform.identity
        }
        
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CustomImagePicker

        init(_ parent: CustomImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Dismiss the picker first
            picker.dismiss(animated: true) {
                // Then update the binding and call completion on main thread
                DispatchQueue.main.async {
                    if let uiImage = info[.originalImage] as? UIImage {
                        self.parent.selectedPhoto = uiImage
                    }
                    self.parent.onImageSelected()
                }
            }
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

