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
    @State private var isAnalyzing = false
    @State private var scannedBarcode: String?
    @State private var cameraPermissionDenied = false
    @State private var isProcessingBarcode = false
    @State private var lastProcessedBarcode: String?
    @State private var isGalleryImageLoaded = false
    @State private var navigationPath = NavigationPath()
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var viewModel: OnboardingViewModel
    
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
                        print("Food scanned with captured image for creation")
                        if selectedMode == .food {
                            // Dismiss immediately and start analysis
                            dismiss()
                            analyzeImageForCreation(image)
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
                                // Dismiss immediately and start processing
                                dismiss()
                                processBarcodeForCreation(barcode)
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
                            self.analyzeImageForCreation(image)
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
        // Set scanning state to show loader card in LogFood
        foodManager.isScanningFood = true
        foodManager.isGeneratingFood = true
        foodManager.scannedImage = image
        foodManager.loadingMessage = "Analyzing food image..."
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
                    print("✅ Successfully analyzed food from image for creation")
                    
                    // Extract the food from the combined log and store in lastGeneratedFood
                    if let food = combinedLog.food {
                        self.foodManager.lastGeneratedFood = food.asFood
                    }
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from image: \(error)")
                }
                
                // Reset scanning states
                self.foodManager.isScanningFood = false
                self.foodManager.isGeneratingFood = false
                self.foodManager.scannedImage = nil
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
                    
                    // Store the food in lastGeneratedFood to trigger ConfirmFoodView
                    self.foodManager.lastGeneratedFood = response.food
                    
                    // Reset scanning states
                    self.foodManager.isScanningFood = false
                    self.foodManager.isGeneratingFood = false
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from barcode: \(error)")
                    // Reset states on failure
                    self.foodManager.isScanningFood = false
                    self.foodManager.isGeneratingFood = false
                }
            }
        }
    }
}

#Preview {
    CreateFoodWithScan()
}
