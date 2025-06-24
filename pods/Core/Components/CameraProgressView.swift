import SwiftUI
import PhotosUI

struct CameraProgressView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPhoto: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    
    var body: some View {
        VStack {
            Spacer()
            
            // Camera Button
            Button(action: {
                showCamera = true
            }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 20)
            
            // Gallery Button
            Button(action: {
                showImagePicker = true
            }) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showImagePicker) {
            CustomImagePicker(selectedPhoto: $selectedPhoto, sourceType: .photoLibrary) {
                dismiss()
            }
        }
        .sheet(isPresented: $showCamera) {
            CustomImagePicker(selectedPhoto: $selectedPhoto, sourceType: .camera) {
                dismiss()
            }
        }
    }
}

struct CustomImagePicker: UIViewControllerRepresentable {
    @Binding var selectedPhoto: UIImage?
    var sourceType: UIImagePickerController.SourceType
    var onImageSelected: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
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
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedPhoto = uiImage
                parent.onImageSelected()
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

