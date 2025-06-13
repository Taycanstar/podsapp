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
                            self.analyzeImageForCreation(image)
                        }
                    }
                }
            }
        ))
        .onAppear {
            checkCameraPermission()
        }
        .navigationDestination(for: Food.self) { food in
            ConfirmFoodView(path: $navigationPath, food: food, isCreationMode: true)
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
        isAnalyzing = true
        
        // Use FoodManager to analyze the image and create food
        foodManager.analyzeFoodImage(
            image: image,
            userEmail: viewModel.email,
            mealType: "Lunch" // Default since we're creating, not logging
        ) { result in
            DispatchQueue.main.async {
                isAnalyzing = false
                
                switch result {
                case .success(let loggedFood):
                    print("✅ Successfully analyzed food from image for creation")
                    
                    // Convert LoggedFoodItem to Food and navigate to ConfirmFoodView
                    if let foodItem = loggedFood.food {
                        let food = foodItem.asFood
                        navigationPath.append(food)
                    }
                    
                case .failure(let error):
                    print("❌ Failed to analyze food from image: \(error)")
                    // Could show an alert here if needed
                }
            }
        }
    }
    
    func processBarcodeForCreation(_ barcode: String) {
        // Use FoodManager to lookup barcode and create food
        foodManager.lookupFoodByBarcodeEnhanced(
            barcode: barcode,
            userEmail: viewModel.email,
            mealType: "Lunch" // Default since we're creating, not logging
        ) { success, errorMessage in
            DispatchQueue.main.async {
                isProcessingBarcode = false
                
                if success {
                    print("✅ Successfully analyzed food from barcode for creation: \(barcode)")
                    
                    // The food should be available in foodManager.aiGeneratedFood
                    if let generatedFood = foodManager.aiGeneratedFood {
                        let food = generatedFood.asFood
                        navigationPath.append(food)
                    }
                } else {
                    print("❌ Failed to analyze food from barcode: \(errorMessage ?? "Unknown error")")
                    // Could show an alert here if needed
                }
            }
        }
    }
}

#Preview {
    CreateFoodWithScan()
}
