//
//  CreateFoodWithScan.swift
//  Pods
//
//  Created by Dimi Nunez on 6/12/25.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct CreateFoodWithScan: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: FoodScannerView.ScanMode = .food
    @State private var showPhotosPicker = false
    @State private var selectedImage: UIImage?
    @State private var flashEnabled = false
    @State private var isAnalyzingPhoto = false
    @State private var isAnalyzingLabel = false
    @State private var isAnalyzingGallery = false
    @State private var scannedBarcode: String?
    @State private var cameraPermissionDenied = false
    @State private var isProcessingBarcode = false
    @State private var lastProcessedBarcode: String?
    @State private var isGalleryImageLoaded = false
    @State private var navigationPath = NavigationPath()
    @State private var nutritionProductName = ""
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    
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
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                            
                        Text("Please allow camera access in Settings to use scanning.")
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
                            print("Food scanned with captured image for creation")
                            // Start analysis first, then dismiss
                            analyzeImageForCreation(image)
                            dismiss()
                        } else if selectedMode == .nutritionLabel {
                            print("Nutrition label scanned with captured image for creation")
                            // Start analysis first, then dismiss
                            analyzeNutritionLabelForCreation(image)
                            dismiss()
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
                        
                        print("🔍 BARCODE DETECTED FOR CREATION: \(barcode)")
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                        
                        isProcessingBarcode = true
                        lastProcessedBarcode = barcode
                        self.scannedBarcode = barcode
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            print("📸 Auto-capturing photo for barcode creation: \(barcode)")
                            takePhoto()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                // Start processing first, then dismiss
                                processBarcodeForCreation(barcode)
                                dismiss()
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
                        dismiss()
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
                    HStack(spacing: 20) {
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
                                selectedMode = .gallery
                                showPhotosPicker = true
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
                .padding(.bottom, 50)
            }
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: Binding<PhotosPickerItem?>(
            get: { nil },
            set: { item in
                guard let item = item else { return }
                
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.selectedImage = image
                            self.isGalleryImageLoaded = true
                            // Start analysis first, then dismiss
                            self.analyzeImageForGallery(image)
                            self.dismiss()
                        }
                    }
                }
            }
        ))
        .onAppear {
            checkCameraPermission()
        }
        }
    }
    
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionDenied = false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionDenied = !granted
                }
            }
        case .denied, .restricted:
            cameraPermissionDenied = true
        @unknown default:
            cameraPermissionDenied = true
        }
    }
    
    func toggleFlash() {
        flashEnabled.toggle()
        NotificationCenter.default.post(name: .toggleFlash, object: nil)
    }
    
    func takePhoto() {
        NotificationCenter.default.post(name: .capturePhoto, object: nil)
    }
    
    func analyzeImageForCreation(_ image: UIImage) {
        // Guard against duplicate processing
        guard !isAnalyzingPhoto else {
            print("⚠️ Already analyzing photo, ignoring duplicate call")
            return
        }
        
        isAnalyzingPhoto = true
        
        // Set scanning state to show loader card in LogFood
        foodManager.isScanningFood = true
        foodManager.isGeneratingFood = true
        foodManager.scannedImage = image
        foodManager.loadingMessage = "Analyzing food image..."
        foodManager.uploadProgress = 0.1
        
        // Use FoodManager to analyze the image for creation (without logging)
        foodManager.analyzeFoodImageForCreation(
            image: image,
            userEmail: viewModel.email
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let food):
                    print("✅ Successfully analyzed food from image for creation")
                    
                    // Use the food directly (no need to extract from combinedLog)
                    // Check preference for photo scan
                    if photoScanPreviewEnabled {
                        // Show confirmation sheet by setting lastGeneratedFood
                        print("📸 Photo scan preview enabled - showing confirmation")
                        self.foodManager.lastGeneratedFood = food
                    } else {
                        // Create food directly without confirmation
                        print("📸 Photo scan preview disabled - creating food directly")
                        
                        // Food already created by analyzeFoodImageForCreation - just handle success
                        print("✅ Food already created by photo scan analysis: \(food.displayName)")
                        
                        // Add the food to userFoods so it appears in MyFoods tab immediately
                        if !self.foodManager.userFoods.contains(where: { $0.fdcId == food.fdcId }) {
                            self.foodManager.userFoods.insert(food, at: 0) // Add to beginning of list
                        }
                        
                        // Clear the userFoods cache to force refresh from server next time
                        self.foodManager.clearUserFoodsCache()
                        
                        // Track as recently added
                        self.foodManager.trackRecentlyAdded(foodId: food.fdcId)
                        
                        // Show success toast
                        self.foodManager.showFoodGenerationSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.foodManager.showFoodGenerationSuccess = false
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from image: \(error)")
                    // Show user-friendly error message
                    self.foodManager.showScanFailure(
                        type: "No Food Detected",
                        message: "Try scanning again."
                    )
                }
                
                // Reset scanning states
                self.foodManager.isScanningFood = false
                self.foodManager.isGeneratingFood = false
                self.foodManager.scannedImage = nil
                // Reset analyzing flag
                self.isAnalyzingPhoto = false
            }
        }
    }
    
    func analyzeNutritionLabelForCreation(_ image: UIImage) {
        // Guard against duplicate processing
        guard !isAnalyzingLabel else {
            print("⚠️ Already analyzing nutrition label, ignoring duplicate call")
            return
        }
        
        isAnalyzingLabel = true
        
        // Set scanning state to show loader card in LogFood
        foodManager.isScanningFood = true
        foodManager.isGeneratingFood = true
        foodManager.scannedImage = image
        foodManager.loadingMessage = "Reading nutrition label..."
        foodManager.uploadProgress = 0.1
        
        // Use FoodManager to analyze the nutrition label for creation (without logging)
        foodManager.analyzeNutritionLabelForCreation(
            image: image,
            userEmail: viewModel.email
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let food):
                    print("✅ Successfully analyzed nutrition label for creation")
                    
                    // Use the food directly (no need to extract from combinedLog)
                    // Check preference for food label scan
                    if foodLabelPreviewEnabled {
                        // Show confirmation sheet by setting lastGeneratedFood
                        print("🏷️ Food label preview enabled - showing confirmation")
                        self.foodManager.lastGeneratedFood = food
                    } else {
                        // Create food directly without confirmation
                        print("🏷️ Food label preview disabled - creating food directly")
                        
                        // Food already created by analyzeFoodImageForCreation - just handle success
                        print("✅ Food already created by nutrition label analysis: \(food.displayName)")
                        
                        // Add the food to userFoods so it appears in MyFoods tab immediately
                        if !self.foodManager.userFoods.contains(where: { $0.fdcId == food.fdcId }) {
                            self.foodManager.userFoods.insert(food, at: 0) // Add to beginning of list
                        }
                        
                        // Clear the userFoods cache to force refresh from server next time
                        self.foodManager.clearUserFoodsCache()
                        
                        // Track as recently added
                        self.foodManager.trackRecentlyAdded(foodId: food.fdcId)
                        
                        // Show success toast
                        self.foodManager.showFoodGenerationSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.foodManager.showFoodGenerationSuccess = false
                        }
                    }
                    
                case .failure(let error):
                    // Check if this is the special "name required" error
                    if let nsError = error as? NSError, nsError.code == 1001 {
                        print("🏷️ Product name not found for creation, setting up for name input in LogFood")
                        if let nutritionData = nsError.userInfo["nutrition_data"] as? [String: Any],
                           let mealType = nsError.userInfo["meal_type"] as? String,
                           let isCreationFlow = nsError.userInfo["is_creation_flow"] as? Bool, isCreationFlow {
                            
                            // Store in FoodManager for LogFood alert to use (creation-specific properties)
                            self.foodManager.pendingNutritionDataForCreation = nutritionData
                            self.foodManager.pendingMealTypeForCreation = mealType
                            self.foodManager.showNutritionNameInputForCreation = true
                            
                            // Add a small delay before dismissing to ensure LogFood can react
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                            return // Don't dismiss immediately
                        }
                    } else {
                        print("❌ Failed to analyze nutrition label: \(error)")
                        // Show user-friendly error message for other nutrition label failures
                        self.foodManager.showScanFailure(
                            type: "No Nutrition Label Detected",
                            message: "Try scanning again."
                        )
                    }
                    // Always dismiss the scanner for other cases
                    dismiss()
                }
                
                // Reset scanning states
                self.foodManager.isScanningFood = false
                self.foodManager.isGeneratingFood = false
                self.foodManager.scannedImage = nil
                // Reset analyzing flag
                self.isAnalyzingLabel = false
            }
        }
    }
    
    func processBarcodeForCreation(_ barcode: String) {
        // Set scanning state to show loader card in LogFood
        foodManager.isScanningFood = true
        foodManager.isGeneratingFood = true
        foodManager.loadingMessage = "Looking up barcode..."
        foodManager.uploadProgress = 0.2
        
        // Use NetworkManagerTwo to lookup barcode for creation (not logging)
        NetworkManagerTwo.shared.lookupFoodByBarcode(
            barcode: barcode,
            userEmail: viewModel.email,
            mealType: "Lunch",
            shouldLog: false
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Successfully analyzed food from barcode for creation: \(barcode)")
                    
                    // Check preference for barcode scan
                    if barcodePreviewEnabled {
                        // Show confirmation sheet by setting lastGeneratedFood
                        print("📊 Barcode preview enabled - showing confirmation")
                        self.foodManager.lastGeneratedFood = response.food
                    } else {
                        // Create food directly without confirmation
                        print("📊 Barcode preview disabled - creating food directly")
                        let createdFood = response.food
                        
                        self.foodManager.createManualFood(food: createdFood, showPreview: false) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let savedFood):
                                    print("✅ Successfully created food from barcode: \(savedFood.displayName)")
                                    
                                    // Track as recently added
                                    self.foodManager.trackRecentlyAdded(foodId: savedFood.fdcId)
                                    
                                    // Show success toast
                                    self.foodManager.showFoodGenerationSuccess = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        self.foodManager.showFoodGenerationSuccess = false
                                    }
                                    
                                case .failure(let error):
                                    print("❌ Failed to create food from barcode: \(error)")
                                }
                            }
                        }
                    }
                    
                    // Reset scanning states
                    self.foodManager.isScanningFood = false
                    self.foodManager.isGeneratingFood = false
                    // Reset barcode processing flag
                    self.isProcessingBarcode = false
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from barcode: \(error)")
                    // Show user-friendly error message
                    self.foodManager.showScanFailure(
                        type: "Barcode Scan",
                        message: "We couldn't find this product in our database. Try scanning again or enter the food manually."
                    )
                    // Reset barcode processing flag
                    self.isProcessingBarcode = false
                }
            }
        }
    }
    
    func analyzeImageForGallery(_ image: UIImage) {
        // Guard against duplicate processing
        guard !isAnalyzingGallery else {
            print("⚠️ Already analyzing gallery image, ignoring duplicate call")
            return
        }
        
        isAnalyzingGallery = true
        
        // Set scanning state to show loader card in LogFood
        foodManager.isScanningFood = true
        foodManager.isGeneratingFood = true
        foodManager.scannedImage = image
        foodManager.loadingMessage = "Analyzing image from gallery..."
        foodManager.uploadProgress = 0.1
        
        // Use FoodManager to analyze the image for creation (without logging)
        foodManager.analyzeFoodImageForCreation(
            image: image,
            userEmail: viewModel.email
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let food):
                    print("✅ Successfully analyzed food from gallery for creation")
                    
                    // Use the food directly (no need to extract from combinedLog)
                    // Check preference for gallery import
                    if galleryImportPreviewEnabled {
                        // Show confirmation sheet by setting lastGeneratedFood
                        print("🖼️ Gallery import preview enabled - showing confirmation")
                        self.foodManager.lastGeneratedFood = food
                    } else {
                        // Create food directly without confirmation
                        print("🖼️ Gallery import preview disabled - creating food directly")
                        
                        // Food already created by analyzeFoodImageForCreation - just handle success
                        print("✅ Food already created by gallery image analysis: \(food.displayName)")
                        
                        // Add the food to userFoods so it appears in MyFoods tab immediately
                        if !self.foodManager.userFoods.contains(where: { $0.fdcId == food.fdcId }) {
                            self.foodManager.userFoods.insert(food, at: 0) // Add to beginning of list
                        }
                        
                        // Clear the userFoods cache to force refresh from server next time
                        self.foodManager.clearUserFoodsCache()
                        
                        // Track as recently added
                        self.foodManager.trackRecentlyAdded(foodId: food.fdcId)
                        
                        // Show success toast
                        self.foodManager.showFoodGenerationSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.foodManager.showFoodGenerationSuccess = false
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from gallery: \(error)")
                    // Show user-friendly error message
                    self.foodManager.showScanFailure(
                        type: "Gallery Image",
                        message: "We couldn't recognize the food in this image. Try selecting a clearer photo or enter the food manually."
                    )
                }
                
                // Reset scanning states
                self.foodManager.isScanningFood = false
                self.foodManager.isGeneratingFood = false
                self.foodManager.scannedImage = nil
                // Reset analyzing flag
                self.isAnalyzingGallery = false
            }
        }
    }
}

#Preview {
    CreateFoodWithScan()
}
