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
    static let toggleFlash = Notification.Name("toggleFlash")
}

// Removed BarcodeFood struct - using onFoodScanned callback instead

struct FoodScannerView: View {
    @Binding var isPresented: Bool
    let selectedMeal: String
    @State private var selectedMode: ScanMode = .food
    @State private var showPhotosPicker = false
    @State private var selectedImage: UIImage?
    @State private var flashEnabled = false
    @State private var isAnalyzing = false
    @State private var scannedBarcode: String?
    @State private var cameraPermissionDenied = false
    @State private var isProcessingBarcode = false
    @State private var lastProcessedBarcode: String?
    @State private var isGalleryImageLoaded = false
    @State private var showScanFlow = false
    @State private var hasShownScanFlow = false
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    // Callback for when food is scanned via barcode
    var onFoodScanned: ((Food, Int?) -> Void)?
    
    // Removed navigationPath - using onFoodScanned callback instead
    
    // User preferences for scan preview
    private var photoScanPreviewEnabled: Bool {
        UserDefaults.standard.object(forKey: "scanPreview_photoScan") as? Bool ?? false
    }
    private var foodLabelPreviewEnabled: Bool {
        UserDefaults.standard.object(forKey: "scanPreview_foodLabel") as? Bool ?? true
    }
    private var barcodePreviewEnabled: Bool {
        UserDefaults.standard.object(forKey: "scanPreview_barcode") as? Bool ?? true
    }
    private var galleryImportPreviewEnabled: Bool {
        UserDefaults.standard.object(forKey: "scanPreview_galleryImport") as? Bool ?? false
    }
    
    enum ScanMode {
        case food, nutritionLabel, barcode, gallery
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
                            if selectedMode == .food {
                                print("Food scanned with captured image")
                                // Check preference to decide between preview and one-tap logging
                                if photoScanPreviewEnabled {
                                    print("📸 Photo scan preview enabled - showing ConfirmLogView")
                                    analyzeImageForPreview(image)
                                } else {
                                    print("📸 Photo scan preview disabled - one-tap logging")
                                    analyzeImageDirectly(image)
                                }
                            } else if selectedMode == .nutritionLabel {
                                print("Nutrition label scanned with captured image")
                                analyzeNutritionLabel(image)
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
                    
                    // Mode indicators
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
                    } else if selectedMode == .nutritionLabel {
                        VStack {
                            Text("Nutrition Label Scanner")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.bottom, 20)
                            
                            // Show a scanning area optimized for nutrition labels
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white, lineWidth: 3)
                                .frame(width: 320, height: 400)
                                .background(Color.clear)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    
                    Spacer()
                    
                    // Bottom controls
                    VStack(spacing: 30) {
                        // Mode selection buttons
                        HStack(spacing: 15) {
                            // Food Scan Button
                            ScanOptionButton(
                                icon: "text.viewfinder",
                                title: "Food",
                                isSelected: selectedMode == .food,
                                action: { selectedMode = .food }
                            )
                            
                            // Nutrition Label Button
                            ScanOptionButton(
                                icon: "tag",
                                title: "Label",
                                isSelected: selectedMode == .nutritionLabel,
                                action: { selectedMode = .nutritionLabel }
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
                                    openGallery()
                                }
                            )
                        }
                        
                        // Capture button
                        if selectedMode != .gallery {
                            Button(action: {
                                takePhoto()
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 6)
                                            .frame(width: 80, height: 80)
                                    )
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showPhotosPicker) {
                PhotosPickerView(selectedImage: $selectedImage)
                    .ignoresSafeArea()
                    .onDisappear {
                        if let image = selectedImage {
                            // Check if preview is enabled for gallery import
                            if galleryImportPreviewEnabled {
                                print("🖼️ Gallery import preview enabled - will show confirmation screen after analysis")
                                selectedMode = .food
                                analyzeImageForPreview(image)
                            } else {
                                print("🖼️ Gallery import preview disabled - one-tap logging enabled")
                                selectedMode = .food
                                analyzeImageDirectly(image)
                            }
                        }
                    }
            }
            .sheet(isPresented: $showScanFlow) {
                ScanFlowContainerView()
                    .onDisappear {
                        hasShownScanFlow = true
                    }
            }
            .background(Color.black)
        .onAppear {
            // Check camera permissions when the view appears
            checkCameraPermissions()
            print("📱 FoodScannerView appeared - Mode: \(selectedMode)")
            print("🔍 hasShownScanFlow: \(hasShownScanFlow), hasSeenScanFlow: \(UserDefaults.standard.hasSeenScanFlow)")
            
            // Show scan flow on first appearance if user hasn't seen it yet
            if !hasShownScanFlow && !UserDefaults.standard.hasSeenScanFlow {
                print("🔍 Scheduling scan flow to show in 0.5 seconds")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔍 Showing scan flow now - showScanFlow: \(showScanFlow)")
                    showScanFlow = true
                }
            } else {
                print("🔍 Not showing scan flow - already shown or user has seen it")
            }
        }
    }
    
    // MARK: - Functions
    
    private func takePhoto() {
        print("📸 Taking photo")
        NotificationCenter.default.post(name: .capturePhoto, object: nil)
    }
    
    private func toggleFlash() {
        flashEnabled.toggle()
        NotificationCenter.default.post(name: .toggleFlash, object: flashEnabled)
    }
    

private func analyzeImage(_ image: UIImage) {
  guard !isAnalyzing,
        let userEmail = UserDefaults.standard.string(forKey: "userEmail")
  else { return }

  isPresented                  = false
  foodManager.scannedImage     = image
  foodManager.isScanningFood   = true
  foodManager.loadingMessage   = "Analyzing image..."
  foodManager.uploadProgress   = 0.1

  print("🔍 Starting pure food image analysis via server with meal: \(selectedMeal)")

  foodManager.analyzeFoodImage(image: image,
                               userEmail: userEmail,
                               mealType: selectedMeal) { result in
    switch result {
    case .success(let combinedLog):
        // Pure analysis function - always show preview (used by gallery when preview is enabled)
        print("📸 Pure image analysis complete - showing preview")
        if let food = combinedLog.food?.asFood {
          DispatchQueue.main.async {
            // Use the callback to trigger ConfirmLogView sheet in ContentView
            self.onFoodScanned?(food, combinedLog.foodLogId)
          }
        }

    case .failure(let error):
      print("❌ pure scan failed:", error.localizedDescription)
    }
  }
}

private func analyzeNutritionLabel(_ image: UIImage) {
    guard !isAnalyzing,
          let userEmail = UserDefaults.standard.string(forKey: "userEmail")
    else { return }

    // Check preference at the start and branch accordingly
    if foodLabelPreviewEnabled {
        print("🏷️ Food label preview enabled - will show ConfirmLogView after analysis")
        analyzeNutritionLabelForPreview(image)
    } else {
        print("🏷️ Food label preview disabled - one-tap logging")
        analyzeNutritionLabelDirectly(image)
    }
}

private func analyzeNutritionLabelForPreview(_ image: UIImage) {
    guard !isAnalyzing,
          let userEmail = UserDefaults.standard.string(forKey: "userEmail")
    else { return }

    isPresented                  = false
    foodManager.scannedImage     = image
    foodManager.isScanningFood   = true
    foodManager.loadingMessage   = "Reading nutrition label..."
    foodManager.uploadProgress   = 0.1

    print("🏷️ Starting nutrition label analysis for preview with meal: \(selectedMeal)")

    foodManager.analyzeNutritionLabel(image: image,
                                     userEmail: userEmail,
                                     mealType: selectedMeal) { result in
        switch result {
        case .success(let combinedLog):
            // Always show confirmation view for preview mode
            print("🏷️ Nutrition label scan complete - showing preview")
            if let food = combinedLog.food?.asFood {
                DispatchQueue.main.async {
                    // Use the same NotificationCenter mechanism as barcode scanning
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowFoodConfirmation"),
                        object: nil,
                        userInfo: [
                            "food": food,
                            "foodLogId": combinedLog.foodLogId ?? NSNull()
                        ]
                    )
                    print("🔍 DEBUG: Posted ShowFoodConfirmation notification for nutrition label: \(food.description)")
                }
            }

        case .failure(let error):
            self.handleNutritionLabelError(error)
        }
    }
}

private func analyzeNutritionLabelDirectly(_ image: UIImage) {
    guard !isAnalyzing,
          let userEmail = UserDefaults.standard.string(forKey: "userEmail")
    else { return }

    isPresented                  = false
    foodManager.scannedImage     = image
    foodManager.isScanningFood   = true
    foodManager.loadingMessage   = "Reading nutrition label..."
    foodManager.uploadProgress   = 0.1

    print("🏷️ Starting nutrition label analysis for one-tap with meal: \(selectedMeal)")

    foodManager.analyzeNutritionLabel(image: image,
                                     userEmail: userEmail,
                                     mealType: selectedMeal) { result in
        switch result {
        case .success(let combinedLog):
            // Always do instant optimistic insert for direct analysis (one-tap logging)
            print("🏷️ Nutrition label scan complete - one-tap logging")
            dayLogsVM.addPending(combinedLog)

            DispatchQueue.main.async {
                // 1) see if there's an existing entry with that foodLogId
                if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                    foodManager.combinedLogs.remove(at: idx)
                }
                // 2) prepend the fresh log
                foodManager.combinedLogs.insert(combinedLog, at: 0)
            }

        case .failure(let error):
            self.handleNutritionLabelError(error)
        }
    }
}

private func handleNutritionLabelError(_ error: Error) {
    // Check if this is the special "name required" error
    if let nsError = error as? NSError, nsError.code == 1001 {
        // Product name not found - let FoodManager handle this for DashboardView
        print("🏷️ Product name not found, storing data for dashboard popup")
        if let nutritionData = nsError.userInfo["nutrition_data"] as? [String: Any],
           let mealType = nsError.userInfo["meal_type"] as? String {
            
            // Store in FoodManager for DashboardView to access
            foodManager.pendingNutritionData = nutritionData
            foodManager.pendingMealType = mealType
            foodManager.showNutritionNameInput = true
        }
    } else {
        print("❌ nutrition label scan failed:", error.localizedDescription)
    }
}

private func analyzeImageForPreview(_ image: UIImage) {
  guard !isAnalyzing,
        let userEmail = UserDefaults.standard.string(forKey: "userEmail")
  else { return }

  isPresented                  = false
  foodManager.scannedImage     = image
  foodManager.isScanningFood   = true
  foodManager.loadingMessage   = "Analyzing image..."
  foodManager.uploadProgress   = 0.1

  print("🔍 Starting food image analysis for preview with meal: \(selectedMeal)")

  foodManager.analyzeFoodImage(image: image,
                               userEmail: userEmail,
                               mealType: selectedMeal) { result in
    switch result {
    case .success(let combinedLog):
        // Always show confirmation view for preview mode
        print("📸 Image analysis complete - showing preview")
        print("🔍 DEBUG: combinedLog.food = \(String(describing: combinedLog.food))")
        if let food = combinedLog.food?.asFood {
          print("🔍 DEBUG: Converted to Food object: \(food.description), fdcId: \(food.fdcId)")
          print("🔍 DEBUG: Using NotificationCenter instead of callback (like barcode scanning)")
          DispatchQueue.main.async {
            // Use the same NotificationCenter mechanism as barcode scanning
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowFoodConfirmation"),
                object: nil,
                userInfo: [
                    "food": food,
                    "foodLogId": combinedLog.foodLogId ?? NSNull()
                ]
            )
            print("🔍 DEBUG: Posted ShowFoodConfirmation notification for food: \(food.description)")
          }
        } else {
          print("❌ DEBUG: Failed to convert combinedLog.food to Food object")
          print("❌ DEBUG: combinedLog.food is nil: \(combinedLog.food == nil)")
        }

    case .failure(let error):
      print("❌ preview scan failed:", error.localizedDescription)
      // Show user-friendly error message for photo scan failures
      foodManager.showScanFailure(
        type: "No Food Detected",
        message: "Try scanning again."
      )
    }
  }
}

private func analyzeImageDirectly(_ image: UIImage) {
  guard !isAnalyzing,
        let userEmail = UserDefaults.standard.string(forKey: "userEmail")
  else { return }

  isPresented                  = false
  foodManager.scannedImage     = image
  foodManager.isScanningFood   = true
  foodManager.loadingMessage   = "Analyzing image..."
  foodManager.uploadProgress   = 0.1

  print("🔍 Starting direct food image analysis (one-tap) with meal: \(selectedMeal)")

  foodManager.analyzeFoodImage(image: image,
                               userEmail: userEmail,
                               mealType: selectedMeal) { result in
    switch result {
    case .success(let combinedLog):
        // Always do instant optimistic insert for direct analysis (one-tap logging)
        print("📸 Image analysis complete - one-tap logging")
        dayLogsVM.addPending(combinedLog)

        DispatchQueue.main.async {
            // 1) see if there's an existing entry with that foodLogId
            if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                foodManager.combinedLogs.remove(at: idx)
            }
            // 2) prepend the fresh log
            foodManager.combinedLogs.insert(combinedLog, at: 0)
        }

    case .failure(let error):
      print("❌ direct scan failed:", error.localizedDescription)
    }
  }
}



    private func processBarcodeDirectly(_ barcode: String) {
        guard !isAnalyzing, let userEmail = UserDefaults.standard.string(forKey: "userEmail") else {
            return
        }
        
        print("🧩 Processing barcode directly (without photo): \(barcode)")
        print("📊 Barcode preview enabled: \(barcodePreviewEnabled)")
        
        // ENHANCED: Close scanner immediately and show loading in DashboardView
        // Set the loading state in FoodManager to show the loading card
        foodManager.isAnalyzingFood = true  // This triggers FoodAnalysisCard in DashboardView
        foodManager.loadingMessage = "Looking up barcode..."
        foodManager.uploadProgress = 0.1
        
        // Close the scanner immediately for better UX
        isPresented = false
        
        // Reset local state
        isAnalyzing = false
        isProcessingBarcode = false
        
        // Check preference to decide between preview and direct logging
        if barcodePreviewEnabled {
            print("📊 Barcode preview enabled - will show confirmation sheet")
            // Start the enhanced barcode lookup process (shows confirmation)
            foodManager.lookupFoodByBarcodeEnhanced(
                barcode: barcode,
                userEmail: userEmail,
                mealType: selectedMeal
            ) { success, message in
                if success {
                    print("✅ Enhanced barcode lookup success for: \(barcode)")
                } else {
                    print("❌ Enhanced barcode lookup failed: \(message ?? "Unknown error")")
                }
            }
        } else {
            print("📊 Barcode preview disabled - direct logging")
            // Use direct logging (no confirmation sheet)
            foodManager.lookupFoodByBarcodeDirect(
                barcode: barcode,
                userEmail: userEmail,
                mealType: selectedMeal
            ) { success, message in
                if success {
                    print("✅ Direct barcode lookup success for: \(barcode)")
                } else {
                    print("❌ Direct barcode lookup failed: \(message ?? "Unknown error")")
                }
            }
        }
    }
    
    private func openGallery() {
        // Reset selection state to prevent using old images
        selectedImage = nil
        selectedMode = .gallery
        showPhotosPicker = true
        print("🖼️ Gallery opened - awaiting image selection")
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
            guard let result = results.first else {
                // No image selected, dismiss immediately
                picker.dismiss(animated: true)
                return
            }
            
            // Load the image before dismissing
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let image = object as? UIImage else {
                    // Failed to load image, dismiss on main thread
                    DispatchQueue.main.async {
                        picker.dismiss(animated: true)
                    }
                    return
                }
                
                // Successfully loaded image, update binding and dismiss
                DispatchQueue.main.async {
                    self?.parent.selectedImage = image
                    picker.dismiss(animated: true)
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
