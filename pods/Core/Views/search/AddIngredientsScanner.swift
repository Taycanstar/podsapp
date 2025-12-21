//
//  AddIngredientScanner.swift
//  pods
//
//  Created by Dimi Nunez on 12/20/25.
//

import SwiftUI
import AVFoundation
import PhotosUI

@MainActor
struct AddIngredientsScanner: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodManager: FoodManager

    var onIngredientAdded: (Food) -> Void

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

    // Sheet for ingredient summary
    @State private var scannedFood: Food?
    @State private var showIngredientSummary = false

    // Multi-food from scan
    @State private var scannedFoods: [Food] = []
    @State private var scannedMealItems: [MealItem] = []
    @State private var showIngredientPlateSummary = false

    enum ScanMode {
        case food, nutritionLabel, barcode, gallery
    }

    var body: some View {
        ZStack {
            // Camera view (or error overlay)
            if cameraPermissionDenied {
                cameraPermissionDeniedView
            } else {
                CameraPreviewView(
                    selectedMode: Binding(
                        get: { convertToFoodScannerMode(selectedMode) },
                        set: { _ in }
                    ),
                    flashEnabled: $flashEnabled,
                    onCapture: { image in
                        guard let image = image else { return }
                        if selectedMode == .food {
                            analyzeImage(image)
                        } else if selectedMode == .nutritionLabel {
                            analyzeNutritionLabel(image)
                        }
                    },
                    onBarcodeDetected: { barcode in
                        guard selectedMode == .barcode else { return }
                        handleBarcodeDetected(barcode)
                    }
                )
                .edgesIgnoringSafeArea(.all)
            }

            // UI Overlay
            VStack {
                // Top controls
                HStack(alignment: .top) {
                    // Left cluster: Close button + Flashlight
                    VStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }

                        Button {
                            toggleFlash()
                        } label: {
                            Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.leading)

                    Spacer()
                }
                .padding(.top, 50)

                Spacer()

                // Mode indicators
                if selectedMode == .barcode {
                    barcodeScanningOverlay
                } else if selectedMode == .nutritionLabel {
                    nutritionLabelScanningOverlay
                }

                Spacer()

                // Bottom controls
                VStack(spacing: 24) {
                    // Mode selection buttons
                    GeometryReader { geometry in
                        let horizontalPadding: CGFloat = 20
                        let spacing: CGFloat = 12
                        let buttonCount: CGFloat = 4
                        let availableWidth = max(0, geometry.size.width - (horizontalPadding * 2) - (spacing * (buttonCount - 1)))
                        let buttonWidth = min(92, availableWidth / buttonCount)

                        HStack(spacing: spacing) {
                            ScanOptionButton(
                                icon: "text.viewfinder",
                                title: "Food",
                                isSelected: selectedMode == .food,
                                preferredWidth: buttonWidth,
                                action: { selectedMode = .food }
                            )

                            ScanOptionButton(
                                icon: "tag",
                                title: "Label",
                                isSelected: selectedMode == .nutritionLabel,
                                preferredWidth: buttonWidth,
                                action: { selectedMode = .nutritionLabel }
                            )

                            ScanOptionButton(
                                icon: "barcode.viewfinder",
                                title: "Barcode",
                                isSelected: selectedMode == .barcode,
                                preferredWidth: buttonWidth,
                                action: { selectedMode = .barcode }
                            )

                            ScanOptionButton(
                                icon: "photo",
                                title: "Gallery",
                                isSelected: selectedMode == .gallery,
                                preferredWidth: buttonWidth,
                                action: { openGallery() }
                            )
                        }
                        .padding(.horizontal, horizontalPadding)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(height: 72)

                    // Capture button
                    if selectedMode != .gallery {
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
                    }
                }
                .padding(.bottom, 60)
            }

            // Loading overlay
            if isAnalyzing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView("Analyzing...")
                    .tint(.white)
                    .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showPhotosPicker) {
            PhotosPickerView(selectedImages: $selectedImages, selectionLimit: 0)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showIngredientSummary) {
            if let food = scannedFood {
                IngredientSummaryView(food: food, onAddToRecipe: { updatedFood in
                    onIngredientAdded(updatedFood)
                })
            }
        }
        .sheet(isPresented: $showIngredientPlateSummary) {
            IngredientPlateSummaryView(
                foods: scannedFoods,
                mealItems: scannedMealItems,
                onAddToRecipe: { foods, mealItems in
                    // Add all foods as ingredients
                    for food in foods {
                        onIngredientAdded(food)
                    }
                }
            )
        }
        .onChange(of: selectedImages) { _, images in
            guard !images.isEmpty else { return }
            processSelectedImages(images)
        }
        .background(Color.black)
        .onAppear {
            checkCameraPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowFoodConfirmation"))) { notification in
            // Handle barcode lookup result
            if let userInfo = notification.userInfo,
               let food = userInfo["food"] as? Food {
                scannedFood = food
                showIngredientSummary = true
            }
        }
    }

    // MARK: - Helper Views

    private var cameraPermissionDeniedView: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack(spacing: 20) {
                Image(systemName: "camera.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)

                Text("Camera Access Required")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Please allow camera access in Settings to scan ingredients.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
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
    }

    private var barcodeScanningOverlay: some View {
        VStack {
            Text("Barcode Scanner")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.bottom, 20)

            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white, lineWidth: 3)
                .frame(width: 280, height: 160)
                .background(Color.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var nutritionLabelScanningOverlay: some View {
        VStack {
            Text("Nutrition Label Scanner")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.bottom, 20)

            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white, lineWidth: 3)
                .frame(width: 320, height: 400)
                .background(Color.clear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Functions

    private func convertToFoodScannerMode(_ mode: ScanMode) -> FoodScannerView.ScanMode {
        switch mode {
        case .food: return .food
        case .nutritionLabel: return .nutritionLabel
        case .barcode: return .barcode
        case .gallery: return .gallery
        }
    }

    private var currentUserEmail: String? {
        let email = UserDefaults.standard.string(forKey: "userEmail")
        return email?.isEmpty == false ? email : nil
    }

    private func takePhoto() {
        NotificationCenter.default.post(name: .capturePhoto, object: nil)
    }

    private func toggleFlash() {
        flashEnabled.toggle()
        NotificationCenter.default.post(name: .toggleFlash, object: flashEnabled)
    }

    private func openGallery() {
        showPhotosPicker = true
    }

    private func checkCameraPermissions() {
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

    private func analyzeImage(_ image: UIImage) {
        guard !isAnalyzing, let userEmail = currentUserEmail else { return }

        isAnalyzing = true

        Task { @MainActor in
            defer { isAnalyzing = false }
            do {
                let combinedLog = try await foodManager.analyzeFoodImageModern(
                    image: image,
                    userEmail: userEmail,
                    mealType: "Ingredient",
                    shouldLog: false
                )
                if let food = combinedLog.food?.asFood {
                    scannedFood = food
                    showIngredientSummary = true
                }
            } catch {
                print("Ingredient scan failed: \(error.localizedDescription)")
            }
        }
    }

    private func analyzeNutritionLabel(_ image: UIImage) {
        guard !isAnalyzing, let userEmail = currentUserEmail else { return }

        isAnalyzing = true

        Task { @MainActor in
            defer { isAnalyzing = false }
            do {
                let combinedLog = try await foodManager.analyzeFoodImageModern(
                    image: image,
                    userEmail: userEmail,
                    mealType: "Ingredient",
                    shouldLog: false
                )
                if let food = combinedLog.food?.asFood {
                    scannedFood = food
                    showIngredientSummary = true
                }
            } catch {
                print("Nutrition label scan failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleBarcodeDetected(_ barcode: String) {
        guard !isProcessingBarcode && barcode != lastProcessedBarcode else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()

        isProcessingBarcode = true
        lastProcessedBarcode = barcode
        isAnalyzing = true

        let userEmail = currentUserEmail ?? ""

        // Use the enhanced barcode lookup with callback
        foodManager.lookupFoodByBarcodeEnhanced(
            barcode: barcode,
            userEmail: userEmail,
            mealType: "Ingredient"
        ) { success, message in
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.isProcessingBarcode = false

                if !success {
                    print("Barcode lookup failed: \(message ?? "Unknown error")")
                    self.lastProcessedBarcode = nil
                }
                // On success, the food confirmation is handled via notification
                // We'll listen for it separately
            }
        }
    }

    private func processSelectedImages(_ images: [UIImage]) {
        guard let firstImage = images.first else { return }
        selectedImages = []
        analyzeImage(firstImage)
    }
}

#Preview {
    AddIngredientsScanner(onIngredientAdded: { _ in })
        .environmentObject(FoodManager())
}
