//
//  FoodScannerView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/12/25.
//

import SwiftUI
import AVFoundation
import PhotosUI

// Notification names - moved to file scope
extension Notification.Name {
    static let capturePhoto = Notification.Name("capturePhoto")
}

struct FoodScannerView: View {
    @Binding var isPresented: Bool
    @State private var selectedMode: ScanMode = .food
    @State private var showPhotosPicker = false
    @State private var selectedImage: UIImage?
    @State private var flashEnabled = false
    @State private var isAnalyzing = false
    @State private var scannedBarcode: String?
    @State private var cameraPermissionDenied = false
    @State private var isProcessingBarcode = false
    @State private var lastProcessedBarcode: String?
    @EnvironmentObject var foodManager: FoodManager
    
    enum ScanMode {
        case food, barcode, gallery
    }
    
    var body: some View {
        ZStack {
            // Camera view (or error overlay)
            if cameraPermissionDenied {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        Image(systemName: "camera.slash.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            
                        Text("Camera Access Required")
                            .font(.headline)
                            .foregroundColor(.white)
                            
                        Text("Please allow camera access in Settings to use barcode scanning.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal)
                            
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Open Settings")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                }
            } else {
                CameraPreviewView(
                    selectedMode: $selectedMode,
                    flashEnabled: flashEnabled, 
                    onCapture: { image in
                        guard let image = image else { return }
                        print("Food scanned with captured image")
                        if selectedMode == .food {
                            analyzeImage(image)
                        }
                    },
                    onBarcodeDetected: { barcode in
                        guard selectedMode == .barcode else { 
                            print("🚫 Barcode detected but ignored - not in barcode mode")
                            return 
                        }
                        
                        guard !isProcessingBarcode && barcode != lastProcessedBarcode else {
                            print("⏱️ Ignoring barcode - already being processed or same as last")
                            return
                        }
                        
                        print("🔍 BARCODE DETECTED IN UI: \(barcode) - preparing to process")
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                        
                        isProcessingBarcode = true
                        lastProcessedBarcode = barcode
                        
                        self.scannedBarcode = barcode
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            print("📸 Auto-capturing photo for barcode: \(barcode)")
                            takePhoto()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                processBarcodeDirectly(barcode)
                            }
                        }
                    }
                )
                .edgesIgnoringSafeArea(.all)
            }
            
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
                
                // Barcode indicator (when in barcode mode)
                if selectedMode == .barcode {
                    VStack {
                        Text("Barcode Scanner")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                        
                        // Just show a clearly defined border for the scanning area
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white, lineWidth: 3)
                            .frame(width: 280, height: 160)
                            .background(Color.clear)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                
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
                    
                    // Shutter button - hidden when in barcode mode
                    if selectedMode != .barcode {
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
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: selectedMode)
                    } else {
                        // Empty spacer with the same size to maintain layout
                        Color.clear
                            .frame(width: 80, height: 80)
                            .padding(.bottom, 40)
                    }
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
            PhotosPickerView(selectedImage: $selectedImage)
                .onDisappear {
                    if let image = selectedImage {
                        analyzeImage(image)
                    } else {
                        // Reset to Food mode if no image was selected
                        selectedMode = .food
                    }
                }
        }
        .onAppear {
            // Check camera permissions when the view appears
            checkCameraPermissions()
            print("📱 FoodScannerView appeared - Mode: \(selectedMode)")
        }
    }
    
    // MARK: - Functions
    
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
        
        // If we have a barcode and are in barcode mode, use barcode lookup instead of image analysis
        if selectedMode == .barcode, let barcode = scannedBarcode {
            // Process barcode scanning
            print("🔍 Processing barcode scan: \(barcode)")
            
            isAnalyzing = true  // Show loading indicator
            
            // Call the barcode lookup function in FoodManager
            foodManager.lookupFoodByBarcode(
                barcode: barcode, 
                image: image,
                userEmail: userEmail
            ) { success, message in
                self.isAnalyzing = false
                self.isProcessingBarcode = false
                
                if !success {
                    print("❌ Barcode lookup failed: \(message ?? "Unknown error")")
                } else {
                    print("✅ Barcode lookup success for: \(barcode)")
                }
            }
        } else {
            // Regular food image analysis
            isAnalyzing = true
            foodManager.analyzeFoodImage(image: image, userEmail: userEmail) { success, message in
                self.isAnalyzing = false
                
                if !success {
                    print("❌ Food analysis failed: \(message ?? "Unknown error")")
                }
            }
        }
    }
    
    private func toggleFlash() {
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
    
    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Camera access is already granted
            cameraPermissionDenied = false
            print("✅ Camera permission already granted")
        case .notDetermined:
            // Request camera access
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.cameraPermissionDenied = !granted
                    print(granted ? "✅ Camera permission granted" : "❌ Camera permission denied")
                    
                    // If permission was granted, allow a moment before setting up the session
                    if granted {
                        // Trigger camera setup refresh
                        self.selectedMode = .food // Just to trigger a state change
                    }
                }
            }
        case .denied, .restricted:
            // Camera access was previously denied
            cameraPermissionDenied = true
            print("❌ Camera permission previously denied or restricted")
        @unknown default:
            cameraPermissionDenied = true
            print("❓ Unknown camera permission status")
        }
    }
    
    private func processBarcodeDirectly(_ barcode: String) {
        guard !isAnalyzing, let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            return
        }
        
        // Close the scanner view
        isPresented = false
        isAnalyzing = true
        
        print("🧩 Processing barcode directly (without photo): \(barcode)")
        
        // Call the barcode lookup function in FoodManager (without image)
        foodManager.lookupFoodByBarcode(
            barcode: barcode,
            image: nil,
            userEmail: userEmail
        ) { success, message in
            self.isAnalyzing = false
            self.isProcessingBarcode = false
            
            if !success {
                print("❌ Barcode direct lookup failed: \(message ?? "Unknown error")")
            } else {
                print("✅ Barcode direct lookup success for: \(barcode)")
            }
        }
    }
}

// PhotosPickerView replacement for the PhotosPicker
struct PhotosPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
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
        let parent: PhotosPickerView
        
        init(_ parent: PhotosPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    self?.parent.selectedImage = image
                }
            }
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

struct CameraPreviewView: UIViewRepresentable {
    let captureSession = AVCaptureSession()
    @Binding var selectedMode: FoodScannerView.ScanMode
    var flashEnabled: Bool
    var onCapture: (UIImage?) -> Void
    var onBarcodeDetected: (String) -> Void
    
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
        // Update barcode scanning based on mode change
        context.coordinator.updateBarcodeScanning(isBarcode: selectedMode == .barcode)
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
            
            // Configure for optimal video performance
            if backCamera.isAutoFocusRangeRestrictionSupported {
                backCamera.autoFocusRangeRestriction = .near
                print("🔍 Set autoFocusRangeRestriction to NEAR for better barcode scanning")
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
        
        // Add metadata output for barcode scanning
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(coordinator, queue: DispatchQueue.main)
            
            // Set the rect of interest to the center of the screen for better barcode detection
            // This ensures we're prioritizing the center area where users typically hold barcodes
            metadataOutput.rectOfInterest = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
            
            print("Available metadata types: \(metadataOutput.availableMetadataObjectTypes)")
            
            // Check if EAN-13 barcode format is supported
            if metadataOutput.availableMetadataObjectTypes.contains(.ean13) {
                // Set all supported barcode types
                metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .code93, .qr, .pdf417, .aztec]
                print("Barcode scanning ready with supported formats")
                coordinator.metadataOutput = metadataOutput
            }
            
            // Improve real-time performance for barcode processing
            if let connection = metadataOutput.connection(with: .metadata) {
                connection.isEnabled = true
                print("✅ Metadata connection enabled for better barcode detection")
            }
            
            // Initially enable or disable barcode scanning based on mode
            coordinator.updateBarcodeScanning(isBarcode: selectedMode == .barcode)
        } else {
            print("Cannot add metadata output for barcode scanning")
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
    
    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureMetadataOutputObjectsDelegate {
        let parent: CameraPreviewView
        var photoOutput = AVCapturePhotoOutput()
        var metadataOutput: AVCaptureMetadataOutput?
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
        
        // Toggle barcode scanning based on mode
        func updateBarcodeScanning(isBarcode: Bool) {
            if isBarcode {
                // Enable all supported barcode formats when in barcode mode
                metadataOutput?.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .code93, .qr, .pdf417, .aztec]
                print("Barcode scanning ENABLED with all supported formats")
            } else {
                // Disable barcode scanning when not in barcode mode
                metadataOutput?.metadataObjectTypes = []
                print("Barcode scanning DISABLED")
            }
        }
        
        // Handle detected barcodes
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            // Skip if parent isn't in barcode mode
            guard parent.selectedMode == .barcode else {
                return
            }
            
            // Find the first barcode
            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let barcodeValue = metadataObject.stringValue {
                print("📣 BARCODE DETECTED: \(barcodeValue) (type: \(metadataObject.type.rawValue))")
                
                // Process the barcode through our delegate
                DispatchQueue.main.async {
                    self.parent.onBarcodeDetected(barcodeValue)
                }
            }
        }
        
        @objc func capturePhoto() {
            // If we're already processing a barcode, don't try to capture
            if let barcode = parent.onBarcodeDetected as? (String) -> Void,
               parent.selectedMode == .barcode {
                // We'll use the processBarcodeDirectly flow instead
                return
            }
            
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
            
            do {
                print("📸 Initiating capture with settings: \(settings.flashMode == .on ? "FLASH ON" : "FLASH OFF")")
                photoOutput.capturePhoto(with: settings, delegate: self)
            } catch {
                print("❌ Failed to start capture: \(error)")
                // Notify failure
                parent.onCapture(nil)
            }
        }
        
        // Handle the captured photo
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            if let error = error {
                print("Error capturing photo: \(error)")
                
                // Special handling for barcode mode - proceed even without photo
                if parent.selectedMode == .barcode {
                    print("📷 Photo capture failed in barcode mode - proceeding with barcode only")
                    // No need to call onCapture(nil) here as we'll use processBarcodeDirectly instead
                } else {
                    parent.onCapture(nil)
                }
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
