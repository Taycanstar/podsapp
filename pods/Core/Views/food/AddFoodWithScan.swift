//
//  AddFoodWithScan.swift
//  Pods
//
//  Created by Dimi Nunez on 6/28/25.
//

import SwiftUI
import PhotosUI

enum ScanType {
    case barcode
    case photo
    case gallery
}

struct AddFoodWithScan: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var viewModel: OnboardingViewModel
    
    // Completion closure to pass scanned food and scan type back to parent
    var onFoodScanned: (Food, ScanType) -> Void
    
    @State private var selectedMode: FoodScannerView.ScanMode = .food
    @State private var showPhotosPicker = false
    @State private var selectedImage: UIImage?
    @State private var flashEnabled = false
    @State private var isAnalyzing = false
    @State private var scannedBarcode: String?
    @State private var cameraPermissionDenied = false
    @State private var isProcessingBarcode = false
    @State private var lastProcessedBarcode: String?
    @State private var isGalleryImageLoaded = false
    
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
                        print("Food scanned with captured image for recipe")
                        if selectedMode == .food {
                            // Dismiss immediately and start analysis
                            dismiss()
                            analyzeImageForRecipe(image)
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
                        
                        print("🔍 BARCODE DETECTED FOR RECIPE: \(barcode)")
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                        
                        isProcessingBarcode = true
                        lastProcessedBarcode = barcode
                        self.scannedBarcode = barcode
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            print("📸 Auto-capturing photo for barcode recipe: \(barcode)")
                            takePhoto()
                            
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // Dismiss immediately and start processing (same as CreateFoodWithScan)
                            dismiss()
                            processBarcodeForRecipe(barcode)
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
        .onAppear {
            // Set FoodManager scanning states
            foodManager.isScanningFood = true
            foodManager.scannedImage = nil
            
            // Reset processing states
            isProcessingBarcode = false
            lastProcessedBarcode = nil
            
            // Check camera permission
            checkCameraPermission()
        }
        .onDisappear {
            // Reset local processing states only (not foodManager scanning states)
            isProcessingBarcode = false
            lastProcessedBarcode = nil
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
                        // Dismiss immediately and start analysis
                            self.dismiss()
                            self.analyzeImageForGallery(image)
                        }
                    }
                }
            }
        ))
        .navigationBarHidden(true)
    }
    
    // MARK: - Helper Functions
    
    private func toggleFlash() {
        flashEnabled.toggle()
        NotificationCenter.default.post(name: .toggleFlash, object: nil)
    }
    
    private func takePhoto() {
        // Post notification to actually capture the photo
        NotificationCenter.default.post(name: .capturePhoto, object: nil)
    }
    
    private func checkCameraPermission() {
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
    
    private func analyzeImageForRecipe(_ image: UIImage) {
        // Set scanning state to show loader card
        foodManager.isScanningFood = true
        foodManager.isGeneratingFood = true
        foodManager.scannedImage = image
        foodManager.loadingMessage = "Analyzing image for recipe..."
        foodManager.uploadProgress = 0.1
        
        // Clear lastGeneratedFood BEFORE calling analyzeFoodImage to prevent triggering ConfirmFoodView sheet
        foodManager.lastGeneratedFood = nil
        
        // Use FoodManager to analyze the image (same as FoodScannerView)
        foodManager.analyzeFoodImage(
            image: image,
            userEmail: viewModel.email,
            mealType: "Lunch"
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let combinedLog):
                    print("✅ Successfully analyzed food from image for recipe")
                    
                    // Extract the food from the combined log
                    if let food = combinedLog.food {
                        let createdFood = food.asFood
                        
                        // Clear lastGeneratedFood to prevent triggering other sheets
                        foodManager.lastGeneratedFood = nil
                        
                        // Pass the food to parent (view already dismissed)
                        // Note: Don't cleanup scanning states here - let parent handle it
                        onFoodScanned(createdFood, .photo)
                    } else {
                        print("❌ No food found in analysis result")
                        // Note: Don't cleanup here - parent will handle it
                    }
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from image: \(error)")
                    // Note: Don't cleanup here - parent will handle it
                }
            }
        }
    }
    
    private func analyzeImageForGallery(_ image: UIImage) {
        // Set scanning state to show loader card
        foodManager.isScanningFood = true
        foodManager.isGeneratingFood = true
        foodManager.scannedImage = image
        foodManager.loadingMessage = "Analyzing image from gallery..."
        foodManager.uploadProgress = 0.1
        
        // Clear lastGeneratedFood BEFORE calling analyzeFoodImage to prevent triggering ConfirmFoodView sheet
        foodManager.lastGeneratedFood = nil
        
        // Use FoodManager to analyze the image (same as FoodScannerView)
        foodManager.analyzeFoodImage(
            image: image,
            userEmail: viewModel.email,
            mealType: "Lunch"
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let combinedLog):
                    print("✅ Successfully analyzed food from gallery image for recipe")
                    
                    // Extract the food from the combined log
                    if let food = combinedLog.food {
                        let createdFood = food.asFood
                        
                        // Clear lastGeneratedFood to prevent triggering other sheets
                        foodManager.lastGeneratedFood = nil
                        
                        // Pass the food to parent (view already dismissed)
                        // Note: Don't cleanup scanning states here - let parent handle it
                        onFoodScanned(createdFood, .gallery)
                    } else {
                        print("❌ No food found in gallery analysis result")
                        // Note: Don't cleanup here - parent will handle it
                    }
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from gallery image: \(error)")
                    // Note: Don't cleanup here - parent will handle it
                }
            }
        }
    }
    
    private func processBarcodeForRecipe(_ barcode: String) {
        // Set scanning state to show loader card
        foodManager.isScanningFood = true
        foodManager.isGeneratingFood = true
        foodManager.loadingMessage = "Processing barcode for recipe..."
        foodManager.uploadProgress = 0.2
        
        // Clear lastGeneratedFood BEFORE calling lookupFoodByBarcode to prevent triggering ConfirmFoodView sheet
        foodManager.lastGeneratedFood = nil
        
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
                    print("✅ Successfully analyzed food from barcode for recipe: \(barcode)")
                    
                    // Extract the food from the response
                    let createdFood = response.food
                    
                    // Clear lastGeneratedFood to prevent triggering other sheets
                    foodManager.lastGeneratedFood = nil
                    
                    // CRITICAL: Reset isProcessingBarcode to allow future scans
                    isProcessingBarcode = false
                    
                    // Pass food to parent for confirmation (view already dismissed)
                    // Note: Don't cleanup scanning states here - let parent handle it
                    onFoodScanned(createdFood, .barcode)
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from barcode: \(error)")
                    // CRITICAL: Reset isProcessingBarcode on error too
                    isProcessingBarcode = false
                    // Note: Don't cleanup scanning states here - parent will handle it
                }
            }
        }
    }
    
    private func cleanupScanningStates() {
        foodManager.isScanningFood = false
        foodManager.isGeneratingFood = false
        foodManager.scannedImage = nil
        foodManager.loadingMessage = ""
        foodManager.uploadProgress = 0.0
        
        // Reset barcode processing states
        isProcessingBarcode = false
        lastProcessedBarcode = nil
    }
}

#Preview {
    AddFoodWithScan { food, scanType in
        print("Food scanned: \(food.displayName), scanType: \(scanType)")
    }
}
