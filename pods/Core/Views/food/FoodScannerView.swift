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
    @State private var flashEnabled = false
    @State private var isAnalyzing = false
    @EnvironmentObject var foodManager: FoodManager
    
    enum ScanMode {
        case food, barcode, gallery
    }
    
    var body: some View {
        ZStack {
            // Camera view
            CameraPreviewView(flashEnabled: flashEnabled, onCapture: { image in
                guard let image = image else { return }
                print("Food scanned with captured image")
                if selectedMode == .food {
                    analyzeImage(image)
                }
            })
            .edgesIgnoringSafeArea(.all)
            
            // UI Overlay
            VStack {
                // Top controls
                HStack {
                    // Close button
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.leading)

                    Spacer()

                    // Flash toggle button
                    Button(action: {
                        toggleFlash()
                    }) {
                        Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 30) {
                    // Mode selection buttons
                    HStack(spacing: 20) {
                        // Food Scan Button
                        ScanOptionButton(
                            icon: "text.viewfinder",
                            title: "Food",
                            isSelected: selectedMode == .food,
                            action: { selectedMode = .food }
                        )
                        
                        // Barcode Button
                        ScanOptionButton(
                            icon: "barcode.viewfinder",
                            title: "Barcode",
                            isSelected: selectedMode == .barcode,
                            action: { selectedMode = .barcode }
                        )
                        
                        // Gallery Button
                        ScanOptionButton(
                            icon: "photo",
                            title: "Gallery",
                            isSelected: selectedMode == .gallery,
                            action: {
                                selectedMode = .gallery
                                showPhotosPicker = true
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Shutter button
                    Button(action: {
                        takePhoto()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                            
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            
            // Loading overlay
            if isAnalyzing {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text(foodManager.loadingMessage.isEmpty ? "Analyzing food..." : foodManager.loadingMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
            }
        }
        .sheet(isPresented: $showPhotosPicker) {
            PhotosPicker(selection: $selectedImage) {
                Text("Select a photo")
            }
            .onChange(of: selectedImage) { newImage in
                if let image = newImage {
                    analyzeImage(image)
                }
            }
        }
    }
    
    private func takePhoto() {
        // Trigger photo capture - flash will be handled by AVFoundation
        NotificationCenter.default.post(name: .capturePhoto, object: nil)
    }
    
    private func analyzeImage(_ image: UIImage) {
        guard let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            print("User email not found")
            return
        }
        
        // Close the scanner view immediately
        isPresented = false
        
        // Then start the analysis process in the background
        foodManager.analyzeFoodImage(image: image, userEmail: userEmail) { _, _ in
            // No need to handle callbacks here - DashboardView will show results and errors
        }
    }
    
    // Add this function to properly control the flash
    func toggleFlash() {
        // Access the camera device directly
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              backCamera.hasFlash else {
            print("No back camera with flash available")
            return
        }
        
        // Toggle the state
        flashEnabled.toggle()
        print("🔦 Flash toggled to: \(flashEnabled ? "ON" : "OFF")")
        
        // Configure camera hardware
        do {
            try backCamera.lockForConfiguration()
            
            // Always keep the torch off during preview - we don't want continuous light
            if backCamera.hasTorch {
                backCamera.torchMode = .off
                print("Torch kept OFF during preview")
            }
            
            backCamera.unlockForConfiguration()
        } catch {
            print("❌ Error configuring flash: \(error)")
        }
    }
}

struct ScanOptionButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    // Fixed dimensions for consistent sizing
    private let buttonWidth: CGFloat = 90
    private let buttonHeight: CGFloat = 60
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color.black : Color.white)
                
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? Color.black : Color.white)
            }
            .frame(width: buttonWidth, height: buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.3) : Color.black.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: 1)
            )
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
    var flashEnabled: Bool
    var onCapture: (UIImage?) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Configure camera
        checkCameraAuthorization {
            setupCaptureSession(with: context.coordinator)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Nothing to update here - flash is controlled in capturePhoto
    }
    
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
    
    private func setupCaptureSession(with coordinator: Coordinator) {
        captureSession.beginConfiguration()
        
        // For back camera with flash
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: backCamera),
              captureSession.canAddInput(videoInput) else {
            print("Failed to set up back camera")
            return
        }
        
        // Save reference to device for flash control
        coordinator.device = backCamera
        
        // Print flash capability info
        print("Device hasFlash: \(backCamera.hasFlash)")
        print("Device hasTorch: \(backCamera.hasTorch)")
        
        // Configure flash settings
        do {
            try backCamera.lockForConfiguration()
            
            // Turn off torch during preview - we ONLY want flash during capture
            if backCamera.hasTorch {
                backCamera.torchMode = .off
                print("Torch mode turned OFF for preview")
            }
            
            // Check flash capability
            if backCamera.hasFlash {
                // Just confirm flash availability
                print("Flash is available and will be used during capture")
            }
            
            backCamera.unlockForConfiguration()
        } catch {
            print("Error configuring camera: \(error)")
        }
        
        captureSession.addInput(videoInput)
        
        // Add photo output with high resolution
        if captureSession.canAddOutput(coordinator.photoOutput) {
            captureSession.addOutput(coordinator.photoOutput)
            
            // Configure for high resolution (using proper API)
            coordinator.photoOutput.isHighResolutionCaptureEnabled = true
            print("Photo output added to session with high resolution enabled")
        } else {
            print("Cannot add photo output to session")
        }
        
        captureSession.commitConfiguration()
        
        // Start the camera session
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
            print("Camera session started successfully")
        }
    }
    
    // Create a coordinator to handle capture
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        let parent: CameraPreviewView
        var photoOutput = AVCapturePhotoOutput()
        var device: AVCaptureDevice?
        
        init(_ parent: CameraPreviewView) {
            self.parent = parent
            super.init()
            
            // Listen for capture requests
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(capturePhoto),
                name: .capturePhoto,
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func capturePhoto() {
            print("📸 Capturing photo with flash: \(parent.flashEnabled ? "ENABLED" : "DISABLED")")
            
            // CRITICAL: Create settings with the correct format and enable high resolution
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            settings.isHighResolutionPhotoEnabled = true
            
            // Set flash mode based on the toggle - this is the key part
            if parent.flashEnabled {
                // For flash during capture, directly configure the device first
                if let device = device, device.hasFlash {
                    do {
                        try device.lockForConfiguration()
                        // Force flash mode to on for the hardware
                        device.flashMode = .on
                        print("📸 Flash hardware ENABLED for capture")
                        device.unlockForConfiguration()
                    } catch {
                        print("Error configuring flash hardware: \(error)")
                    }
                }
                // Then set the photo settings flash mode
                settings.flashMode = .on
            } else {
                settings.flashMode = .off
                print("Flash OFF for capture")
            }
            
            print("📸 Initiating capture with settings: \(settings.flashMode == .on ? "FLASH ON" : "FLASH OFF")")
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
        
        // Handle the captured photo
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            if let error = error {
                print("Error capturing photo: \(error)")
                parent.onCapture(nil)
                return
            }
            
            // Convert the captured data to a UIImage
            if let imageData = photo.fileDataRepresentation(),
               let image = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    self.parent.onCapture(image)
                }
            } else {
                parent.onCapture(nil)
            }
        }
    }
}

// Notification names
extension Notification.Name {
    static let capturePhoto = Notification.Name("capturePhoto")
} 
