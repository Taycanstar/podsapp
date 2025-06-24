import SwiftUI
import PhotosUI

struct CameraProgressView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPhoto: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        ZStack {
            // Main camera view
            CustomImagePicker(selectedPhoto: $selectedPhoto, sourceType: .camera) {
                dismiss()
            }
            
            // Overlay with gallery button
            VStack {
                HStack {
                    Spacer()
                    
                    // Close button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                
                Spacer()
                
                HStack {
                    // Gallery button
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.leading, 30)
                    
                    Spacer()
                }
                .padding(.bottom, 100)
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

