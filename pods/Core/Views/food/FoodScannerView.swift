//
//  FoodScannerView.swift
//  Pods
//
//  Created by Dimi Nunez on 4/12/25.
//

import SwiftUI
import AVFoundation
import PhotosUI
import Foundation



// Notification names - moved to file scope
extension Notification.Name {
    static let capturePhoto = Notification.Name("capturePhoto")
    static let toggleFlash = Notification.Name("toggleFlash")
}

// Removed BarcodeFood struct - using onFoodScanned callback instead

@MainActor
struct FoodScannerView: View {
    @Binding var isPresented: Bool
    let selectedMeal: String
    @State private var selectedMode: ScanMode = .food
    @State private var showPhotosPicker = false
    @State private var selectedImages: [UIImage] = []
    @State private var flashEnabled = false
    @State private var isAnalyzing = false
    @State private var scannedBarcode: String?
    @State private var cameraPermissionDenied = false
    @State private var isProcessingBarcode = false
    @State private var lastProcessedBarcode: String?
    @State private var isGalleryImageLoaded = false
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @EnvironmentObject var proFeatureGate: ProFeatureGate
    // Callback for when food is scanned via barcode
    var onFoodScanned: ((Food, Int?) -> Void)?
    
    // Removed navigationPath - using onFoodScanned callback instead
    
    // User preferences for scan preview - using @State to avoid UserDefaults threading issues
    @State private var photoScanPreviewEnabled: Bool = false
    @State private var foodLabelPreviewEnabled: Bool = true
    @State private var barcodePreviewEnabled: Bool = true
    @State private var galleryImportPreviewEnabled: Bool = false
    
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
                        flashEnabled: $flashEnabled, 
                        onCapture: { image in
                            print("🔍 CRASH_DEBUG: onCapture called")
                            guard let image = image else { 
                                print("❌ CRASH_DEBUG: Image is nil in onCapture")
                                return 
                            }
                            
                            // Log detailed image information
                            let imageSize = image.size
                            let imageSizeBytes = image.jpegData(compressionQuality: 1.0)?.count ?? 0
                            let imageSizeMB = Double(imageSizeBytes) / 1024.0 / 1024.0
                            print("🔍 CRASH_DEBUG: Image captured - Size: \(imageSize), File size: \(String(format: "%.2f", imageSizeMB))MB (\(imageSizeBytes) bytes)")
                            
                            // Log memory usage before processing
                            let memoryUsage = getMemoryUsage()
                            print("🔍 CRASH_DEBUG: Memory before processing - Used: \(String(format: "%.1f", memoryUsage.used))MB, Available: \(String(format: "%.1f", memoryUsage.available))MB")
                            
                            if selectedMode == .food {
                                print("🔍 CRASH_DEBUG: Food scan mode selected")
                                // Check preference to decide between preview and one-tap logging
                                if photoScanPreviewEnabled {
                                    print("🔍 CRASH_DEBUG: PREVIEW MODE - calling analyzeImageForPreview")
                                    print("🔍 PREVIEW MODE: Photo scan preview enabled - will NOT log automatically")
                                    print("🔍 PREVIEW MODE: Food will be created without logging (shouldLog: false)")
                                    print("🔍 PREVIEW MODE: User must tap 'Log' in ConfirmLogView to actually log")
                                    analyzeImageForPreview(image)
                                } else {
                                    print("🔍 CRASH_DEBUG: DIRECT MODE - calling analyzeImageDirectly")
                                    print("🔍 DIRECT MODE: Photo scan preview disabled - will log immediately")
                                    print("🔍 DIRECT MODE: Food will be created and logged in one step (shouldLog: true)")
                                    analyzeImageDirectly(image)
                                }
                            } else if selectedMode == .nutritionLabel {
                                print("🔍 CRASH_DEBUG: Nutrition label scan mode selected")
                                print("Nutrition label scanned with captured image")
                                analyzeNutritionLabel(image)
                            }
                        },
                        onBarcodeDetected: { barcode in
                            guard selectedMode == .barcode else { 
                                print("🚫 Barcode detected but ignored - not in barcode mode")
                                return 
                            }

                            let sanitizedBarcode = sanitizeBarcode(barcode)
                            guard !sanitizedBarcode.isEmpty else { return }

                            guard isSupportedBarcodeValue(sanitizedBarcode) else {
                                print("⚠️ Unsupported barcode detected: \(barcode)")
                                foodManager.handleScanFailure(.unsupportedBarcode)
                                return
                            }
                            
                            guard !isProcessingBarcode && sanitizedBarcode != lastProcessedBarcode else {
                                print("⏱️ Ignoring barcode - already being processed or same as last")
                                return
                            }
                            
                            print("🔍 BARCODE DETECTED IN UI: \(sanitizedBarcode) - preparing to process")
                            
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                            
                            isProcessingBarcode = true
                            lastProcessedBarcode = sanitizedBarcode
                            
                            self.scannedBarcode = sanitizedBarcode
                            
                            processBarcodeDirectly(sanitizedBarcode)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                print("📸 Auto-capturing photo for barcode: \(sanitizedBarcode)")
                                takePhoto()
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
                        GeometryReader { geometry in
                            let horizontalPadding: CGFloat = 20
                            let spacing: CGFloat = 12
                            let buttonCount: CGFloat = 4
                            let availableWidth = max(0, geometry.size.width - (horizontalPadding * 2) - (spacing * (buttonCount - 1)))
                            let buttonWidth = min(92, availableWidth / buttonCount)
                            
                            HStack(spacing: spacing) {
                                // Food Scan Button
                                ScanOptionButton(
                                    icon: "text.viewfinder",
                                    title: "Food",
                                    isSelected: selectedMode == .food,
                                    preferredWidth: buttonWidth,
                                    action: { selectedMode = .food }
                                )
                                
                                // Nutrition Label Button
                                ScanOptionButton(
                                    icon: "tag",
                                    title: "Label",
                                    isSelected: selectedMode == .nutritionLabel,
                                    preferredWidth: buttonWidth,
                                    action: { selectedMode = .nutritionLabel }
                                )
                                
                                // Barcode Button
                                ScanOptionButton(
                                    icon: "barcode.viewfinder",
                                    title: "Barcode",
                                    isSelected: selectedMode == .barcode,
                                    preferredWidth: buttonWidth,
                                    action: { selectedMode = .barcode }
                                )
                                
                                // Gallery Button
                                ScanOptionButton(
                                    icon: "photo",
                                    title: "Gallery",
                                    isSelected: selectedMode == .gallery,
                                    preferredWidth: buttonWidth,
                                    action: {
                                        openGallery()
                                    }
                                )
                            }
                            .padding(.horizontal, horizontalPadding)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(height: 72)
                        
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
                PhotosPickerView(selectedImages: $selectedImages,
                                 selectionLimit: proFeatureGate.hasActiveSubscription() ? 0 : 1)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: Binding(
                get: { proFeatureGate.showUpgradeSheet && proFeatureGate.blockedFeature == .foodScans },
                set: { if !$0 { proFeatureGate.dismissUpgradeSheet() } }
            )) {
                LogProUpgradeSheet(
                    usageSummary: proFeatureGate.usageSummary,
                    onDismiss: { proFeatureGate.dismissUpgradeSheet() }
                )
                .presentationDetents([.medium, .large])
            }
            .onChange(of: selectedImages) { images in
                guard !images.isEmpty else { return }
                processSelectedImages(images)
            }
            .background(Color.black)
        .onAppear {
            print("🔍 CRASH_DEBUG: FoodScannerView onAppear - START")
            let memoryUsage = getMemoryUsage()
            print("🔍 CRASH_DEBUG: Memory on appear - Used: \(String(format: "%.1f", memoryUsage.used))MB, Available: \(String(format: "%.1f", memoryUsage.available))MB")
            
            // Initialize UserDefaults values safely on main thread
            print("🔍 CRASH_DEBUG: Loading UserDefaults preferences")
            loadUserDefaultsPreferences()
            
            // Check camera permissions when the view appears
            print("🔍 CRASH_DEBUG: Checking camera permissions")
            checkCameraPermissions()
            print("📱 FoodScannerView appeared - Mode: \(selectedMode)")
            print("🔍 CRASH_DEBUG: FoodScannerView onAppear - END")
        }
        .onDisappear {
            print("🔍 CRASH_DEBUG: FoodScannerView onDisappear - Scanner being dismissed")
            let memoryUsage = getMemoryUsage()
            print("🔍 CRASH_DEBUG: Memory on disappear - Used: \(String(format: "%.1f", memoryUsage.used))MB, Available: \(String(format: "%.1f", memoryUsage.available))MB")
            
            // CRITICAL FIX: Don't cancel any timers - let them complete naturally
            print("🔍 CRASH_DEBUG: Scanner dismissed - timers will complete naturally with network operations")
            // No timer cancellation needed - they'll stop when network completes
        }
    }
    
    // MARK: - Functions
    
    private var currentUserEmail: String? {
        let email = UserDefaults.standard.string(forKey: "userEmail")
        return email?.isEmpty == false ? email : nil
    }
    
    /// Safely load UserDefaults preferences on main thread to avoid threading race conditions
    private func loadUserDefaultsPreferences() {
        DispatchQueue.main.async {
            self.photoScanPreviewEnabled = UserDefaults.standard.object(forKey: "scanPreview_photoScan") as? Bool ?? false
            self.foodLabelPreviewEnabled = UserDefaults.standard.object(forKey: "scanPreview_foodLabel") as? Bool ?? true
            self.barcodePreviewEnabled = UserDefaults.standard.object(forKey: "scanPreview_barcode") as? Bool ?? true
            self.galleryImportPreviewEnabled = UserDefaults.standard.object(forKey: "scanPreview_galleryImport") as? Bool ?? false
            
            print("🔍 Loaded UserDefaults preferences: photoScan=\(self.photoScanPreviewEnabled), foodLabel=\(self.foodLabelPreviewEnabled), barcode=\(self.barcodePreviewEnabled), gallery=\(self.galleryImportPreviewEnabled)")
        }
    }
    
    private func takePhoto() {
        print("📸 Taking photo")
        NotificationCenter.default.post(name: .capturePhoto, object: nil)
    }
    
    private func toggleFlash() {
        flashEnabled.toggle()
        NotificationCenter.default.post(name: .toggleFlash, object: flashEnabled)
    }
    

private func analyzeImage(_ image: UIImage) {
    guard !isAnalyzing, let userEmail = currentUserEmail else { return }
    proFeatureGate.checkAccess(for: .foodScans,
                               userEmail: userEmail,
                               increment: true,
                               onAllowed: {
        self.isPresented = false
        Task { @MainActor in
            do {
                let combinedLog = try await foodManager.analyzeFoodImageModern(
                    image: image,
                    userEmail: userEmail,
                    mealType: selectedMeal,
                    shouldLog: false
                )
                if let food = combinedLog.food?.asFood {
                    self.onFoodScanned?(food, combinedLog.foodLogId)
                }
            } catch {
                print("❌ MODERN: Pure scan failed:", error.localizedDescription)
            }
        }
    },
                               onBlocked: nil)
}

private func analyzeNutritionLabel(_ image: UIImage) {
    guard !isAnalyzing, let userEmail = currentUserEmail else { return }
    proFeatureGate.checkAccess(for: .foodScans,
                               userEmail: userEmail,
                               increment: true,
                               onAllowed: {
        performAnalyzeNutritionLabel(image, userEmail: userEmail)
    },
                               onBlocked: nil)
}

private func performAnalyzeNutritionLabel(_ image: UIImage, userEmail: String) {
    isAnalyzing = true
    if foodLabelPreviewEnabled {
        performNutritionLabelPreview(image, userEmail: userEmail)
    } else {
        performNutritionLabelDirect(image, userEmail: userEmail)
    }
}

private func performNutritionLabelPreview(_ image: UIImage, userEmail: String) {
    isPresented = false
    foodManager.scannedImage = image
    foodManager.isScanningFood = true
    foodManager.loadingMessage = "Reading nutrition label..."
    foodManager.uploadProgress = 0.1
    foodManager.analyzeNutritionLabel(image: image,
                                      userEmail: userEmail,
                                      mealType: selectedMeal,
                                      shouldLog: false) { result in
        switch result {
        case .success(let combinedLog):
            if let food = combinedLog.food?.asFood {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowFoodConfirmation"),
                        object: nil,
                        userInfo: [
                            "food": food,
                            "foodLogId": combinedLog.foodLogId ?? NSNull()
                        ]
                    )
                }
            }
            self.isAnalyzing = false
        case .failure(let error):
            self.handleNutritionLabelError(error)
            self.isAnalyzing = false
        }
    }
}

private func performNutritionLabelDirect(_ image: UIImage, userEmail: String) {
    isPresented = false
    foodManager.scannedImage = image
    foodManager.isScanningFood = true
    foodManager.loadingMessage = "Reading nutrition label..."
    foodManager.uploadProgress = 0.1
    foodManager.analyzeNutritionLabel(image: image,
                                      userEmail: userEmail,
                                      mealType: selectedMeal) { result in
        switch result {
        case .success(let combinedLog):
            DispatchQueue.main.async {
                dayLogsVM.addPending(combinedLog)
                if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                    foodManager.combinedLogs.remove(at: idx)
                }
                foodManager.combinedLogs.insert(combinedLog, at: 0)
                self.isAnalyzing = false
            }
        case .failure(let error):
            self.handleNutritionLabelError(error)
            self.isAnalyzing = false
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
    guard !isAnalyzing, let userEmail = currentUserEmail else { return }
    proFeatureGate.checkAccess(for: .foodScans,
                               userEmail: userEmail,
                               increment: true,
                               onAllowed: {
        performAnalyzeImageForPreview(image, userEmail: userEmail)
    },
                               onBlocked: nil)
}

private func performAnalyzeImageForPreview(_ image: UIImage, userEmail: String) {
    isAnalyzing = true
    isPresented = false
    Task { @MainActor in
        defer { self.isAnalyzing = false }
        do {
            let combinedLog = try await foodManager.analyzeFoodImageModern(
                image: image,
                userEmail: userEmail,
                mealType: selectedMeal,
                shouldLog: false
            )
            if let food = combinedLog.food?.asFood {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowFoodConfirmation"),
                    object: nil,
                    userInfo: [
                        "food": food,
                        "foodLogId": combinedLog.foodLogId ?? NSNull()
                    ]
                )
            }
        } catch {
            print("❌ MODERN preview scan failed:", error.localizedDescription)
        }
    }
}

private func analyzeImageDirectly(_ image: UIImage) {
    guard !isAnalyzing, let userEmail = currentUserEmail else { return }
    proFeatureGate.checkAccess(for: .foodScans,
                               userEmail: userEmail,
                               increment: true,
                               onAllowed: {
        performAnalyzeImageDirectly(image, userEmail: userEmail)
    },
                               onBlocked: nil)
}

private func performAnalyzeImageDirectly(_ image: UIImage, userEmail: String) {
    isAnalyzing = true
    isPresented = false
    Task { @MainActor in
        defer { self.isAnalyzing = false }
        do {
            let combinedLog = try await foodManager.analyzeFoodImageModern(
                image: image,
                userEmail: userEmail,
                mealType: selectedMeal,
                shouldLog: true
            )
            dayLogsVM.addPending(combinedLog)
            if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                foodManager.combinedLogs.remove(at: idx)
            }
            foodManager.combinedLogs.insert(combinedLog, at: 0)
        } catch {
            print("❌ MODERN direct scan failed:", error.localizedDescription)
        }
    }
}



    private func processBarcodeDirectly(_ barcode: String) {
        guard !isAnalyzing, let userEmail = currentUserEmail else { return }
        performProcessBarcode(barcode, userEmail: userEmail)
    }
    
    private func openGallery() {
        selectedImages.removeAll()
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

    private func performProcessBarcode(_ barcode: String, userEmail: String) {
        print("🧩 Processing barcode directly (without photo): \(barcode)")
        print("📊 Barcode preview enabled: \(barcodePreviewEnabled)")

        foodManager.isAnalyzingFood = true
        foodManager.loadingMessage = "Looking up barcode..."
        foodManager.uploadProgress = 0.1

        isPresented = false
        isAnalyzing = false
        isProcessingBarcode = false

        if barcodePreviewEnabled {
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

    private func sanitizeBarcode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isSupportedBarcodeValue(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil,
              (8...18).contains(value.count) else {
            return false
        }
        return true
    }

    private func processSelectedImages(_ images: [UIImage]) {
        guard let email = currentUserEmail else { return }
        let isPro = proFeatureGate.hasActiveSubscription()
        if images.count > 1 && !isPro {
            proFeatureGate.requirePro(for: .bulkLogging, userEmail: email) {}
            selectedImages.removeAll()
            return
        }

        selectedImages.removeAll()
        selectedMode = .food

        Task { @MainActor in
            for image in images {
                if galleryImportPreviewEnabled {
                    analyzeImageForPreview(image)
                } else {
                    analyzeImageDirectly(image)
                }
            }
        }
    }
}

// PhotosPickerView replacement for the PhotosPicker
struct PhotosPickerView: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    let selectionLimit: Int
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = selectionLimit
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
            guard !results.isEmpty else {
                picker.dismiss(animated: true)
                return
            }
            let dispatchGroup = DispatchGroup()
            var images: [UIImage] = []
            for result in results {
                dispatchGroup.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        images.append(image)
                    }
                    dispatchGroup.leave()
                }
            }
            dispatchGroup.notify(queue: .main) {
                self.parent.selectedImages = images
                picker.dismiss(animated: true)
            }
        }
    }
}

struct ScanOptionButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var preferredWidth: CGFloat? = nil
    let action: () -> Void
    
    private let defaultButtonWidth: CGFloat = 90
    private let buttonHeight: CGFloat = 60
    private let cornerRadius: CGFloat = 12
    
    private var buttonWidth: CGFloat {
        preferredWidth ?? defaultButtonWidth
    }
    
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
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isSelected ? Color.white.opacity(0.3) : Color.black.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .frame(width: buttonWidth, height: buttonHeight)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let captureSession = AVCaptureSession()
    @Binding var selectedMode: FoodScannerView.ScanMode
    @Binding var flashEnabled: Bool
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
        // Keep coordinator in sync with latest SwiftUI state
        context.coordinator.parent = self
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
            
            // Check if UPC/EAN barcode formats are supported
            if metadataOutput.availableMetadataObjectTypes.contains(.ean13) {
                metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce]
                print("Barcode scanning ready with UPC/EAN formats")
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
        var parent: CameraPreviewView
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
                metadataOutput?.metadataObjectTypes = [.ean13, .ean8, .upce]
                print("Barcode scanning ENABLED for UPC/EAN formats")
            } else {
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
