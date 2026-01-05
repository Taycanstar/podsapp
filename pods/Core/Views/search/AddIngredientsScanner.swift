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

    // Toast state
    @State private var ingredientAddedFromSheet = false
    @State private var showAddedToast = false
    @State private var toastMessage = ""

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
                // Top controls - Flash only (xmark is in parent nav)
                HStack(alignment: .top) {
                    flashButton

                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.top, 8)

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
                // bottom padding
                .padding(.bottom, 0)
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
        .sheet(isPresented: $showIngredientSummary, onDismiss: {
            // Show toast when ingredient was added
            if ingredientAddedFromSheet, let food = scannedFood {
                showToast("Added \(food.description) to recipe")
                ingredientAddedFromSheet = false
            }
        }) {
            if let food = scannedFood {
                IngredientSummaryView(food: food, onAddToRecipe: { updatedFood in
                    ingredientAddedFromSheet = true
                    onIngredientAdded(updatedFood)
                })
            }
        }
        .sheet(isPresented: $showIngredientPlateSummary, onDismiss: {
            // Show toast when ingredients were added
            if ingredientAddedFromSheet {
                let count = scannedFoods.count
                showToast("Added \(count) ingredient\(count == 1 ? "" : "s") to recipe")
                ingredientAddedFromSheet = false
            }
        }) {
            IngredientPlateSummaryView(
                foods: scannedFoods,
                mealItems: scannedMealItems,
                onAddToRecipe: { foods, mealItems in
                    ingredientAddedFromSheet = true
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
        .overlay(alignment: .top) {
            if showAddedToast {
                ingredientToastView
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private var flashButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                toggleFlash()
            } label: {
                Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(width: 44, height: 45)
            .glassEffect(.regular.interactive())
            .clipShape(Circle())
        } else {
            Button {
                toggleFlash()
            } label: {
                Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 45, height: 45)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
    }

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
                // Use fast pipeline (MacroFactor-style, 2-4 seconds) instead of legacy GPT-5
                let fastResult = try await foodManager.analyzeFoodImageFast(
                    image: image,
                    userEmail: userEmail
                )

                if fastResult.foods.count == 1, let food = fastResult.foods.first {
                    // Single food item - show summary sheet
                    scannedFood = food
                    showIngredientSummary = true
                } else if fastResult.foods.count > 1 {
                    // Multiple foods detected - show plate summary
                    scannedFoods = fastResult.foods
                    scannedMealItems = fastResult.mealItems
                    showIngredientPlateSummary = true
                } else {
                    print("[AddIngredientsScanner] No foods detected in image")
                    showToast("No food detected. Try repositioning the camera.")
                }
            } catch {
                print("[AddIngredientsScanner] Fast scan failed: \(error.localizedDescription)")
                showToast("Scan failed. Please try again.")
            }
        }
    }

    private func analyzeNutritionLabel(_ image: UIImage) {
        guard !isAnalyzing else { return }

        isAnalyzing = true

        Task { @MainActor in
            defer { isAnalyzing = false }

            // Use on-device OCR (fast path) instead of the backend label agent
            let ocrData = await NutritionLabelOCRService.shared.extractNutrition(from: image)

            if ocrData.labelDetected {
                let food = Food.from(ocrData: ocrData)
                scannedFood = food
                showIngredientSummary = true
                print("🏷️ [OCR] Label scanned successfully for ingredient flow")
            } else {
                print("🏷️ [OCR] No nutrition label detected in image")
                showToast("No nutrition label detected. Try repositioning the camera.")
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

        // Use NutritionixService directly to avoid global notification conflicts
        NutritionixService.shared.lookupFood(by: barcode, userEmail: userEmail) { [self] result in
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.isProcessingBarcode = false

                switch result {
                case .success(let food):
                    self.scannedFood = food
                    self.showIngredientSummary = true
                case .failure(let error):
                    print("Barcode lookup failed: \(error.localizedDescription)")
                    self.lastProcessedBarcode = nil
                }
            }
        }
    }

    private func processSelectedImages(_ images: [UIImage]) {
        guard let firstImage = images.first else { return }
        selectedImages = []
        analyzeImage(firstImage)
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showAddedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showAddedToast = false
            }
        }
    }

    @ViewBuilder
    private var ingredientToastView: some View {
        if #available(iOS 26.0, *) {
            Text(toastMessage)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .glassEffect(.regular.interactive())
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Text(toastMessage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    AddIngredientsScanner(onIngredientAdded: { _ in })
        .environmentObject(FoodManager())
}
