//
//  FoodScannerView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/12/25.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct FoodScannerView: View {
    @Binding var isPresented: Bool
    @State private var selectedMode: ScanMode = .food
    @State private var showPhotosPicker = false
    @State private var selectedImage: UIImage?
    
    enum ScanMode {
        case food, barcode, gallery
    }
    
    var body: some View {
        ZStack {
            // Camera view
            CameraPreviewView()
                .edgesIgnoringSafeArea(.all)
            
            // Close button
            VStack {
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 16)
                    .padding(.top, 50)
                    
                    Spacer()
                }
                
                Spacer()
                
                // Bottom buttons
                HStack(spacing: 20) {
                    Spacer()
                    
                    // Scan Food Button
                    ScanButton(
                        icon: "text.viewfinder",
                        title: "Food",
                        isSelected: selectedMode == .food,
                        action: { selectedMode = .food }
                    )
                    
                    // Barcode Button
                    ScanButton(
                        icon: "barcode.viewfinder",
                        title: "Barcode",
                        isSelected: selectedMode == .barcode,
                        action: { selectedMode = .barcode }
                    )
                    
                    // Gallery Button
                    ScanButton(
                        icon: "photo",
                        title: "Gallery",
                        isSelected: selectedMode == .gallery,
                        action: {
                            selectedMode = .gallery
                            showPhotosPicker = true
                        }
                    )
                    
                    Spacer()
                }
                .padding(.bottom, 40)
                .background(
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.5)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(height: 120)
                        .edgesIgnoringSafeArea(.bottom)
                )
            }
        }
        .sheet(isPresented: $showPhotosPicker) {
            PhotosPicker(selection: $selectedImage) {
                Text("Select a photo")
            }
        }
    }
}

struct PhotosPicker: UIViewControllerRepresentable {
    @Binding var selection: UIImage?
    var content: () -> Text
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotosPicker
        
        init(_ parent: PhotosPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    self?.parent.selection = image
                }
            }
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let captureSession = AVCaptureSession()
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Configure camera
        checkCameraAuthorization {
            setupCaptureSession()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    private func checkCameraAuthorization(completion: @escaping () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
        default:
            break
        }
    }
    
    private func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else { return }
        
        captureSession.addInput(videoInput)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
}

struct ScanButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(isSelected ? Color.accentColor : Color.black.opacity(0.6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }
} 
