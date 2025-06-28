//
//  AddFoodWithScan.swift
//  Pods
//
//  Created by Dimi Nunez on 6/28/25.
//

import SwiftUI
import PhotosUI

struct AddFoodWithScan: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var foodManager: FoodManager
    @EnvironmentObject private var viewModel: OnboardingViewModel
    
    // Completion closure to pass scanned food back to parent
    var onFoodScanned: (Food) -> Void
    
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
        NavigationView {
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
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
                            cleanupScanningStates()
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
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.bottom, 40)
                }
            }
            .onAppear {
                // Set FoodManager scanning states
                foodManager.isScanningFood = true
                foodManager.scannedImage = nil
                
                // Check camera permission
                checkCameraPermission()
            }
            .onDisappear {
                // Clean up when view disappears
                cleanupScanningStates()
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
                                self.analyzeImageForRecipe(image)
                            }
                        }
                    }
                }
            ))
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Helper Functions
    
    private func toggleFlash() {
        flashEnabled.toggle()
        NotificationCenter.default.post(name: .toggleFlash, object: nil)
    }
    
    private func takePhoto() {
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
        // Set the scanned image in FoodManager
        foodManager.scannedImage = image
        foodManager.isGeneratingFood = true
        foodManager.isScanningFood = true
        
        // Update loading message
        foodManager.loadingMessage = "Analyzing image for recipe..."
        foodManager.uploadProgress = 0.1
        
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
                        
                        // Pass the food to parent and dismiss
                        onFoodScanned(createdFood)
                        cleanupScanningStates()
                        dismiss()
                    } else {
                        print("❌ No food found in analysis result")
                        cleanupScanningStates()
                    }
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from image: \(error)")
                    cleanupScanningStates()
                }
            }
        }
    }
    
    private func processBarcodeForRecipe(_ barcode: String) {
        foodManager.isGeneratingFood = true
        foodManager.isScanningFood = true
        foodManager.loadingMessage = "Processing barcode for recipe..."
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
                    print("✅ Successfully analyzed food from barcode for recipe: \(barcode)")
                    
                    // Extract the food from the response
                    let createdFood = response.food
                    
                    // Clear lastGeneratedFood to prevent triggering other sheets
                    foodManager.lastGeneratedFood = nil
                    
                    // Pass the food to parent and dismiss
                    onFoodScanned(createdFood)
                    cleanupScanningStates()
                    dismiss()
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from barcode: \(error)")
                    cleanupScanningStates()
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
    }
}

#Preview {
    AddFoodWithScan { food in
        print("Food scanned: \(food.displayName)")
    }
}
