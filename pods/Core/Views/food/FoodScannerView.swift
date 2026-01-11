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
    static let stopCameraSession = Notification.Name("stopCameraSession")
    static let cameraSessionStopped = Notification.Name("cameraSessionStopped")
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
    // Pass existing PlateViewModel to preserve plate context when adding more items
    var plateViewModel: PlateViewModel? = nil
    
    // Removed navigationPath - using onFoodScanned callback instead
    
    // User preferences for scan preview - using @State to avoid UserDefaults threading issues
    @State private var photoScanPreviewEnabled: Bool = false
    @State private var foodLabelPreviewEnabled: Bool = true
    @State private var barcodePreviewEnabled: Bool = true
    @State private var galleryImportPreviewEnabled: Bool = false
    @State private var multiFoods: [Food] = []
    @State private var multiMealItems: [MealItem] = []
    @State private var selectedFoodMode: FoodScanMode = .auto

    enum ScanMode {
        case food, nutritionLabel, barcode, gallery
    }

    /// Mode for photo/gallery food scanning - affects AI coach message tone
    enum FoodScanMode: String, CaseIterable {
        case auto = "auto"
        case restaurant = "restaurant"
        case homeCooked = "home_cooked"
        case alcohol = "alcohol"
        case travel = "travel"

        var displayName: String {
            switch self {
            case .auto: return "Auto"
            case .restaurant: return "Restaurant"
            case .homeCooked: return "Home-cooked"
            case .alcohol: return "Alcohol"
            case .travel: return "Travel"
            }
        }

        var icon: String {
            switch self {
            case .auto: return "wand.and.stars"
            case .restaurant: return "fork.knife"
            case .homeCooked: return "house"
            case .alcohol: return "wineglass"
            case .travel: return "airplane"
            }
        }
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
                            guard let image = image else {
                                return
                            }

                            if selectedMode == .food {
                                // Check preference to decide between preview and one-tap logging
                                if photoScanPreviewEnabled {
                                    analyzeImageForPreview(image)
                                } else {
                                    analyzeImageDirectly(image)
                                }
                            } else if selectedMode == .nutritionLabel {
                                analyzeNutritionLabel(image)
                            }
                        },
                        onBarcodeDetected: { barcode in
                            guard selectedMode == .barcode else {
                                return
                            }

                            let sanitizedBarcode = sanitizeBarcode(barcode)
                            guard !sanitizedBarcode.isEmpty else { return }

                            guard isSupportedBarcodeValue(sanitizedBarcode) else {
                                foodManager.handleScanFailure(.unsupportedBarcode)
                                return
                            }

                            guard !isProcessingBarcode && sanitizedBarcode != lastProcessedBarcode else {
                                return
                            }
                            
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
                            
                            isProcessingBarcode = true
                            lastProcessedBarcode = sanitizedBarcode
                            
                            self.scannedBarcode = sanitizedBarcode
                            
                            processBarcodeDirectly(sanitizedBarcode)
                        }
                    )
                    .edgesIgnoringSafeArea(.all)
                }
                
                // UI Overlay
                VStack {
                    // Top controls
                    HStack(alignment: .top) {
                        // Left cluster: Close button + Flashlight (stacked vertically)
                        VStack(spacing: 12) {
                            // Close button
                            if #available(iOS 26.0, *) {
                                Button(action: {
                                    dismissScanner()
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive())
                                .clipShape(Circle())
                            } else {
                                Button(action: {
                                    dismissScanner()
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                            }

                            // Flash toggle button (moved under X)
                            if #available(iOS 26.0, *) {
                                Button(action: {
                                    toggleFlash()
                                }) {
                                    Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive())
                                .clipShape(Circle())
                            } else {
                                Button(action: {
                                    toggleFlash()
                                }) {
                                    Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .padding(12)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.leading)

                        Spacer()

                        // Right: Mode selector dropdown (only for .food and .gallery modes)
                        if selectedMode == .food || selectedMode == .gallery {
                            Menu {
                                ForEach(FoodScanMode.allCases, id: \.self) { mode in
                                    Button {
                                        selectedFoodMode = mode
                                    } label: {
                                        Label(mode.displayName, systemImage: mode.icon)
                                    }
                                }
                            } label: {
                                if #available(iOS 26.0, *) {
                                    HStack(spacing: 6) {
                                        Image(systemName: selectedFoodMode.icon)
                                            .font(.system(size: 14, weight: .medium))
                                        Text(selectedFoodMode.displayName)
                                            .font(.system(size: 14, weight: .medium))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .glassEffect(.regular.interactive())
                                    .clipShape(Capsule())
                                } else {
                                    HStack(spacing: 6) {
                                        Image(systemName: selectedFoodMode.icon)
                                            .font(.system(size: 14, weight: .medium))
                                        Text(selectedFoodMode.displayName)
                                            .font(.system(size: 14, weight: .medium))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.trailing)
                        }
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
                    VStack(spacing: 24) {
                        // Shutter row with gallery button on right
                        HStack(spacing: 24) {
                            // Empty spacer for balance (same size as gallery button)
                            Color.clear
                                .frame(width: 50, height: 50)

                            Spacer()

                            // Capture button (center)
                            Button {
                                takePhoto()
                            } label: {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 6)
                                            .frame(width: 80, height: 80)
                                    )
                            }

                            Spacer()

                            // Gallery button (right)
                            galleryButton
                        }
                        .padding(.horizontal, 32)

                        // Mode selection segmented picker
                        scanModeSegmentedPicker
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 30)
                }
            }
            .sheet(isPresented: $showPhotosPicker) {
                PhotosPickerView(selectedImages: $selectedImages,
                                 selectionLimit: 0)
                    .ignoresSafeArea()
            }
            // Note: Upgrade sheet is presented from MainContentView to avoid conflicts
            .onChange(of: selectedImages) { images in
                guard !images.isEmpty else { return }
                processSelectedImages(images)
            }
            .background(Color.black)
        .onAppear {
            // Initialize UserDefaults values safely on main thread
            loadUserDefaultsPreferences()

            // Check camera permissions when the view appears
            checkCameraPermissions()
        }
        .onDisappear {
            // CRITICAL FIX: Don't cancel any timers - let them complete naturally
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
        }
    }

    private func takePhoto() {
        NotificationCenter.default.post(name: .capturePhoto, object: nil)
    }
    
    private func toggleFlash() {
        flashEnabled.toggle()
        NotificationCenter.default.post(name: .toggleFlash, object: flashEnabled)
    }

    private func trackScanModeSelection(_ mode: ScanMode) {
        switch mode {
        case .food:
            AnalyticsManager.shared.trackFoodInputStarted(method: "food_scan")
        case .nutritionLabel:
            AnalyticsManager.shared.trackFoodInputStarted(method: "food_label")
        case .barcode:
            AnalyticsManager.shared.trackFoodInputStarted(method: "barcode")
        case .gallery:
            AnalyticsManager.shared.trackFoodInputStarted(method: "gallery")
        }
    }

    // MARK: - Bottom Control Views

    @ViewBuilder
    private var galleryButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                openGallery()
            } label: {
                Image(systemName: "photo.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(width: 50, height: 50)
            .glassEffect(.regular.interactive())
            .clipShape(Circle())
        } else {
            Button {
                openGallery()
            } label: {
                Image(systemName: "photo.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
        }
    }

    @ViewBuilder
    private var scanModeSegmentedPicker: some View {
        if #available(iOS 26.0, *) {
            Picker("", selection: $selectedMode) {
                Text("Food")
                    .tag(ScanMode.food)
                Text("Label")
                    .tag(ScanMode.nutritionLabel)
                Text("Barcode")
                    .tag(ScanMode.barcode)
            }
            .pickerStyle(.segmented)
            .controlSize(.large)
            .glassEffect(.regular.interactive())
            .onChange(of: selectedMode) { _, newMode in
                HapticFeedback.generateLigth()
                trackScanModeSelection(newMode)
            }
        } else {
            Picker("", selection: $selectedMode) {
                Text("Food")
                    .tag(ScanMode.food)
                Text("Label")
                    .tag(ScanMode.nutritionLabel)
                Text("Barcode")
                    .tag(ScanMode.barcode)
            }
            .pickerStyle(.segmented)
            .controlSize(.large)
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onChange(of: selectedMode) { _, newMode in
                HapticFeedback.generateLigth()
                trackScanModeSelection(newMode)
            }
        }
    }

private func analyzeImage(_ image: UIImage) {
    guard !isAnalyzing, let userEmail = currentUserEmail else { return }
    proFeatureGate.checkAccess(for: .foodScans,
                               userEmail: userEmail,
                               increment: true,
                               onAllowed: {
        Task { @MainActor in
            defer { self.isPresented = false }
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

    // Use on-device OCR for instant nutrition label scanning (~300ms)
    Task { @MainActor in
        // Dismiss scanner and show floating loader
        self.isPresented = false
        foodManager.startFoodScanning()
        foodManager.updateFoodScanningState(.preparing(image: image))
        foodManager.updateFoodScanningState(.analyzing)

        defer {
            self.isAnalyzing = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.foodManager.resetFoodScanningState()
            }
        }

        // Run on-device OCR (~300ms)
        let ocrData = await NutritionLabelOCRService.shared.extractNutrition(from: image)

        if ocrData.labelDetected {
            foodManager.updateFoodScanningState(.processing)

            // Convert OCR data to Food object
            let food = Food.from(ocrData: ocrData)

            // If callback is provided (e.g., from PlateView), use it instead of notification
            if let callback = onFoodScanned {
                callback(food, nil)
                return
            }

            if foodLabelPreviewEnabled {
                // Preview mode: show confirmation view for user to edit name and confirm
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowFoodConfirmation"),
                    object: nil,
                    userInfo: [
                        "food": food,
                        "foodLogId": NSNull(),
                        "isOCRResult": true,
                        "plateViewModel": plateViewModel as Any
                    ]
                )
            } else {
                // Direct mode: log immediately (user can still edit name in logs)
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowFoodConfirmation"),
                    object: nil,
                    userInfo: [
                        "food": food,
                        "foodLogId": NSNull(),
                        "isOCRResult": true,
                        "plateViewModel": plateViewModel as Any
                    ]
                )
            }

        } else {
            // No nutrition label detected - show toast
            // Post notification to show toast (DashboardView listens for this)
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowScanError"),
                object: nil,
                userInfo: ["message": "No nutrition label detected. Try repositioning the camera."]
            )
        }
    }
}

private func handleNutritionLabelError(_ error: Error) {
    // Check if this is the special "name required" error
    if let nsError = error as? NSError, nsError.code == 1001 {
        // Product name not found - let FoodManager handle this for DashboardView
        if let nutritionData = nsError.userInfo["nutrition_data"] as? [String: Any],
           let mealType = nsError.userInfo["meal_type"] as? String {

            // Store in FoodManager for DashboardView to access
            foodManager.pendingNutritionData = nutritionData
            foodManager.pendingMealType = mealType
            foodManager.showNutritionNameInput = true
        }
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
    Task { @MainActor in
        self.isPresented = false
        foodManager.startFoodScanning()
        foodManager.updateFoodScanningState(.preparing(image: image))
        foodManager.updateFoodScanningState(.uploading(progress: 0.4))
        foodManager.updateFoodScanningState(.analyzing)
        var handledByModernFlow = false
        defer {
            self.isAnalyzing = false
            if !handledByModernFlow {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.foodManager.resetFoodScanningState()
                }
            }
        }
        do {
            // Try ultra-fast path first (MacroFactor-style, 2-4 seconds)
            if let fastResult = try? await foodManager.analyzeFoodImageFast(
                image: image,
                userEmail: userEmail
            ) {
                foodManager.updateFoodScanningState(.processing)

                let embeddedItems = fastResult.foods.first?.mealItems ?? []
                let resolvedMealItems = !fastResult.mealItems.isEmpty ? fastResult.mealItems : embeddedItems
                if resolvedMealItems.count > 1 || fastResult.foods.count > 1 {
                    // If callback is provided (e.g., from PlateView), use it instead of notification
                    if let callback = onFoodScanned, let firstFood = fastResult.foods.first {
                        callback(firstFood, nil)
                        return
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowMultiFoodLog"),
                        object: nil,
                        userInfo: [
                            "foods": fastResult.foods,
                            "mealItems": resolvedMealItems,
                            "plateViewModel": plateViewModel as Any
                        ]
                    )
                    return
                } else if let firstFood = fastResult.foods.first {
                    // If callback is provided (e.g., from PlateView), use it instead of notification
                    if let callback = onFoodScanned {
                        callback(firstFood, nil)
                        return
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowFoodConfirmation"),
                        object: nil,
                        userInfo: [
                            "food": firstFood,
                            "foodLogId": NSNull(),
                            "plateViewModel": plateViewModel as Any
                        ]
                    )
                    return
                }
            }

            // Fallback to legacy agent path if fast scan fails
            if let agentResult = try? await foodManager.analyzeFoodImageWithAgent(
                image: image,
                userEmail: userEmail,
                mealType: selectedMeal
            ) {
                foodManager.updateFoodScanningState(.processing)
                let embeddedItems = agentResult.foods.first?.mealItems ?? []
                let resolvedMealItems = !agentResult.mealItems.isEmpty ? agentResult.mealItems : embeddedItems
                if resolvedMealItems.count > 1 || agentResult.foods.count > 1 {
                    // If callback is provided (e.g., from PlateView), use it instead of notification
                    if let callback = onFoodScanned, let firstFood = agentResult.foods.first {
                        callback(firstFood, nil)
                        return
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowMultiFoodLog"),
                        object: nil,
                        userInfo: [
                            "foods": agentResult.foods,
                            "mealItems": resolvedMealItems,
                            "plateViewModel": plateViewModel as Any
                        ]
                    )
                    return
                } else if let firstFood = agentResult.foods.first {
                    // If callback is provided (e.g., from PlateView), use it instead of notification
                    if let callback = onFoodScanned {
                        callback(firstFood, nil)
                        return
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowFoodConfirmation"),
                        object: nil,
                        userInfo: [
                            "food": firstFood,
                            "foodLogId": NSNull(),
                            "plateViewModel": plateViewModel as Any
                        ]
                    )
                    return
                }
            }

            handledByModernFlow = true
            let combinedLog = try await foodManager.analyzeFoodImageModern(
                image: image,
                userEmail: userEmail,
                mealType: selectedMeal,
                shouldLog: false,
                scanMode: selectedFoodMode.rawValue
            )
            if let food = combinedLog.food?.asFood {
                // If callback is provided (e.g., from PlateView), use it instead of notification
                if let callback = onFoodScanned {
                    callback(food, combinedLog.foodLogId)
                    return
                }
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowFoodConfirmation"),
                    object: nil,
                    userInfo: [
                        "food": food,
                        "foodLogId": combinedLog.foodLogId ?? NSNull(),
                        "plateViewModel": plateViewModel as Any
                    ]
                )
            }
        } catch {
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
    Task { @MainActor in
        self.isPresented = false
        foodManager.startFoodScanning()
        foodManager.updateFoodScanningState(.preparing(image: image))
        foodManager.updateFoodScanningState(.uploading(progress: 0.4))
        foodManager.updateFoodScanningState(.analyzing)
        var handledByModernFlow = false
        defer {
            self.isAnalyzing = false
            if !handledByModernFlow {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.foodManager.resetFoodScanningState()
                }
            }
        }
        do {
            // Try ultra-fast path first (MacroFactor-style, 2-4 seconds)
            if let fastResult = try? await foodManager.analyzeFoodImageFast(
                image: image,
                userEmail: userEmail
            ) {
                foodManager.updateFoodScanningState(.processing)

                let embeddedItems = fastResult.foods.first?.mealItems ?? []
                let resolvedMealItems = !fastResult.mealItems.isEmpty ? fastResult.mealItems : embeddedItems
                if resolvedMealItems.count > 1 || fastResult.foods.count > 1 {
                    // If callback is provided (e.g., from PlateView), use it instead of notification
                    if let callback = onFoodScanned, let firstFood = fastResult.foods.first {
                        callback(firstFood, nil)
                        return
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowMultiFoodLog"),
                        object: nil,
                        userInfo: [
                            "foods": fastResult.foods,
                            "mealItems": resolvedMealItems,
                            "plateViewModel": plateViewModel as Any
                        ]
                    )
                    return
                } else if let firstFood = fastResult.foods.first {
                    // If callback is provided (e.g., from PlateView), use it instead of notification
                    if let callback = onFoodScanned {
                        callback(firstFood, nil)
                        return
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowFoodConfirmation"),
                        object: nil,
                        userInfo: [
                            "food": firstFood,
                            "foodLogId": NSNull(),
                            "plateViewModel": plateViewModel as Any
                        ]
                    )
                    return
                }
            }

            // Fallback to legacy agent path if fast scan fails
            if let agentResult = try? await foodManager.analyzeFoodImageWithAgent(
                image: image,
                userEmail: userEmail,
                mealType: selectedMeal
            ) {
                foodManager.updateFoodScanningState(.processing)
                let embeddedItems = agentResult.foods.first?.mealItems ?? []
                let resolvedMealItems = !agentResult.mealItems.isEmpty ? agentResult.mealItems : embeddedItems
                if resolvedMealItems.count > 1 || agentResult.foods.count > 1 {
                    // If callback is provided (e.g., from PlateView), use it instead of notification
                    if let callback = onFoodScanned, let firstFood = agentResult.foods.first {
                        callback(firstFood, nil)
                        return
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowMultiFoodLog"),
                        object: nil,
                        userInfo: [
                            "foods": agentResult.foods,
                            "mealItems": resolvedMealItems,
                            "plateViewModel": plateViewModel as Any
                        ]
                    )
                    return
                } else if let firstFood = agentResult.foods.first {
                    // If callback is provided (e.g., from PlateView), use it instead of notification
                    if let callback = onFoodScanned {
                        callback(firstFood, nil)
                        return
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowFoodConfirmation"),
                        object: nil,
                        userInfo: [
                            "food": firstFood,
                            "foodLogId": NSNull(),
                            "plateViewModel": plateViewModel as Any
                        ]
                    )
                    return
                }
            }

            // Fallback: legacy auto-log flow
            handledByModernFlow = true
            let combinedLog = try await foodManager.analyzeFoodImageModern(
                image: image,
                userEmail: userEmail,
                mealType: selectedMeal,
                shouldLog: true,
                scanMode: selectedFoodMode.rawValue
            )
            // If callback is provided (e.g., from PlateView), use it instead of auto-logging
            if let callback = onFoodScanned, let food = combinedLog.food?.asFood {
                callback(food, combinedLog.foodLogId)
                return
            }
            dayLogsVM.addPending(combinedLog)
            if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                foodManager.combinedLogs.remove(at: idx)
            }
            foodManager.combinedLogs.insert(combinedLog, at: 0)
        } catch {
        }
    }
}



    private func processBarcodeDirectly(_ barcode: String) {
        guard !isAnalyzing, let userEmail = currentUserEmail else { return }
        isAnalyzing = true
        performProcessBarcode(barcode, userEmail: userEmail)
    }
    
    private func openGallery() {
        selectedImages.removeAll()
        selectedMode = .gallery
        AnalyticsManager.shared.trackFoodInputStarted(method: "gallery")
        showPhotosPicker = true
    }
    
    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Camera access is already granted
            cameraPermissionDenied = false
        case .notDetermined:
            // Request camera access
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.cameraPermissionDenied = !granted

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
        @unknown default:
            cameraPermissionDenied = true
        }
    }

    private func performProcessBarcode(_ barcode: String, userEmail: String) {

        foodManager.isAnalyzingFood = true
        foodManager.loadingMessage = "Looking up barcode..."
        foodManager.uploadProgress = 0.1

        if barcodePreviewEnabled {
            foodManager.lookupFoodByBarcodeEnhanced(
                barcode: barcode,
                userEmail: userEmail,
                mealType: selectedMeal
            ) { success, message in
                self.handleBarcodeLookupCompletion(success: success,
                                                   message: message,
                                                   barcode: barcode)
            }
        } else {
            foodManager.lookupFoodByBarcodeDirect(
                barcode: barcode,
                userEmail: userEmail,
                mealType: selectedMeal
            ) { success, message in
                self.handleBarcodeLookupCompletion(success: success,
                                                   message: message,
                                                   barcode: barcode)
            }
        }
    }

    private func handleBarcodeLookupCompletion(success: Bool,
                                                message: String?,
                                                barcode: String) {
        DispatchQueue.main.async {
            self.foodManager.isAnalyzingFood = false
            self.foodManager.loadingMessage = ""
            self.foodManager.uploadProgress = 0

            self.isAnalyzing = false
            self.isProcessingBarcode = false

            if success {
                // Stop camera session BEFORE dismissing to prevent race condition
                self.stopCameraSession {
                    self.isPresented = false
                }
            } else {
                self.lastProcessedBarcode = nil
            }
        }
    }

    private func stopCameraSession(completion: @escaping () -> Void) {
        // Track if completion has been called to prevent double-calling
        var completionCalled = false

        // Listen for when camera actually stops
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: .cameraSessionStopped,
            object: nil,
            queue: .main
        ) { _ in
            guard !completionCalled else { return }
            completionCalled = true
            if let obs = observer {
                NotificationCenter.default.removeObserver(obs)
            }
            completion()
        }

        // Request camera to stop
        NotificationCenter.default.post(name: .stopCameraSession, object: nil)

        // Fallback timeout in case notification never fires
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard !completionCalled else { return }
            completionCalled = true
            if let obs = observer {
                NotificationCenter.default.removeObserver(obs)
            }
            completion()
        }
    }

    private func dismissScanner() {
        // Immediately flip the binding so the sheet attempts to close
        isPresented = false

        // Stop camera to avoid capture assertions
        stopCameraSession {}

        // Reset transient flags to avoid guards blocking subsequent opens
        isProcessingBarcode = false
        isAnalyzing = false
        foodManager.isAnalyzingFood = false
        foodManager.loadingMessage = ""
        foodManager.uploadProgress = 0
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
        guard currentUserEmail != nil else { return }

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
    private let cornerRadius: CGFloat = 28

    private var buttonWidth: CGFloat {
        preferredWidth ?? defaultButtonWidth
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            glassButton
        } else {
            legacyButton
        }
    }

    @available(iOS 26.0, *)
    private var glassButton: some View {
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
        }
        .buttonStyle(.glass)
        .frame(width: buttonWidth, height: buttonHeight)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var legacyButton: some View {
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
    // captureSession moved to Coordinator to persist across struct recreations
    @Binding var selectedMode: FoodScannerView.ScanMode
    @Binding var flashEnabled: Bool
    var onCapture: (UIImage?) -> Void
    var onBarcodeDetected: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)

        // CRITICAL FIX: Disable touch events on camera view so SwiftUI buttons receive taps immediately
        view.isUserInteractionEnabled = false

        // Use coordinator's session (persists across view updates)
        let previewLayer = AVCaptureVideoPreviewLayer(session: context.coordinator.captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // IMPORTANT: Delay camera setup to allow UI to fully render first
        // This prevents blocking touch events during camera initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkCameraAuthorization {
                self.setupCaptureSession(with: context.coordinator)
            }
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
        // Track configuration state to prevent deadlock if stopRunning is called during config
        coordinator.isConfiguring = true

        // Run entire camera configuration on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            coordinator.captureSession.beginConfiguration()

            // For back camera with flash
            guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: backCamera),
                  coordinator.captureSession.canAddInput(videoInput) else {
                coordinator.captureSession.commitConfiguration()
                coordinator.isConfiguring = false
                return
            }

            // Save reference to device for flash control
            coordinator.device = backCamera

            // Configure flash settings
            do {
                try backCamera.lockForConfiguration()

                // Turn off torch during preview - we ONLY want flash during capture
                if backCamera.hasTorch {
                    backCamera.torchMode = .off
                }

                // Configure for optimal video performance
                if backCamera.isAutoFocusRangeRestrictionSupported {
                    backCamera.autoFocusRangeRestriction = .near
                }

                backCamera.unlockForConfiguration()
            } catch {
            }

            coordinator.captureSession.addInput(videoInput)

            // Add photo output with high resolution
            if coordinator.captureSession.canAddOutput(coordinator.photoOutput) {
                coordinator.captureSession.addOutput(coordinator.photoOutput)

                // Configure for high resolution (using proper API)
                coordinator.photoOutput.isHighResolutionCaptureEnabled = true
            }

            // Add metadata output for barcode scanning
            let metadataOutput = AVCaptureMetadataOutput()
            if coordinator.captureSession.canAddOutput(metadataOutput) {
                coordinator.captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(coordinator, queue: DispatchQueue.main)

                // Set the rect of interest to the center of the screen for better barcode detection
                // This ensures we're prioritizing the center area where users typically hold barcodes
                metadataOutput.rectOfInterest = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)

                // Check if UPC/EAN barcode formats are supported
                if metadataOutput.availableMetadataObjectTypes.contains(.ean13) {
                    metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce]
                    coordinator.metadataOutput = metadataOutput
                }

                // Improve real-time performance for barcode processing
                if let connection = metadataOutput.connection(with: .metadata) {
                    connection.isEnabled = true
                }

                // Initially enable or disable barcode scanning based on mode
                coordinator.updateBarcodeScanning(isBarcode: self.selectedMode == .barcode)
            }

            coordinator.captureSession.commitConfiguration()

            // Clear configuration flag before starting
            coordinator.isConfiguring = false

            // Start the camera session (already on background thread)
            coordinator.captureSession.startRunning()
        }
    }

    func dismantleUIView(_ uiView: UIView, context: Context) {
        // Use coordinator's safe stop method which checks configuration state
        context.coordinator.safeStopSession()
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
        let captureSession = AVCaptureSession()  // Owned by coordinator, persists across view updates
        var isConfiguring = false  // Track if beginConfiguration/commitConfiguration is in progress

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

            // Listen for stop camera session requests
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(stopSession),
                name: .stopCameraSession,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        /// Safely stop the capture session, avoiding deadlock if configuration is in progress
        func safeStopSession() {
            // Don't try to stop while configuring - it will deadlock waiting for the lock
            guard !isConfiguring else {
                // Retry after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.safeStopSession()
                }
                return
            }

            guard captureSession.isRunning else {
                // Already stopped, post completion notification immediately
                NotificationCenter.default.post(name: .cameraSessionStopped, object: nil)
                return
            }

            // Stop on background thread to avoid blocking UI
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()

                // Notify that stop is complete
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .cameraSessionStopped, object: nil)
                }
            }
        }

        @objc func stopSession() {
            safeStopSession()
        }
        
        // Toggle barcode scanning based on mode
        func updateBarcodeScanning(isBarcode: Bool) {
            if isBarcode {
                metadataOutput?.metadataObjectTypes = [.ean13, .ean8, .upce]
            } else {
                metadataOutput?.metadataObjectTypes = []
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
                        device.unlockForConfiguration()
                    } catch {
                    }
                }
                // Then set the photo settings flash mode
                settings.flashMode = .on
            } else {
                settings.flashMode = .off
            }

            do {
                photoOutput.capturePhoto(with: settings, delegate: self)
            } catch {
                // Notify failure
                parent.onCapture(nil)
            }
        }
        
        // Handle the captured photo
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            if let error = error {
                // Special handling for barcode mode - proceed even without photo
                if parent.selectedMode == .barcode {
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
