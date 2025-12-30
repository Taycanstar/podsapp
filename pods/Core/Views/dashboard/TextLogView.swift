//
//  TextLogView.swift
//  Pods
//
//  Created by Dimi Nunez on [Current Date].
//

import SwiftUI
import Speech

struct TextLogView: View {
    @Binding var isPresented: Bool
    let selectedMeal: String
    @State private var mealDescription: String
    @FocusState private var isInputFocused: Bool
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    @EnvironmentObject var proFeatureGate: ProFeatureGate
    
    // State for presenting other views
    @State private var showFoodScanner = false
    @State private var showVoiceLog = false
    @State private var isListening = false
    
    
    // Speech recognition
    @StateObject private var speechRecognizer = SpeechRecognizer()
    
    // State for barcode confirmation (same as CustomTabBar)
    @State private var showConfirmFoodView = false
    @State private var scannedFood: Food?
    @State private var scannedFoodLogId: Int?
    
    // Animation state for pulsing effect
    @State private var pulseScale: CGFloat = 1.0
    
    // Upgrade retry handling
    @State private var pendingRetryDescription: String?
    @State private var pendingRetryMealType: String?
    var onFoodGenerated: ((Food) -> Void)? = nil
    var autoStartListening: Bool = false
    
    init(isPresented: Binding<Bool>, selectedMeal: String, initialDescription: String = "", onFoodGenerated: ((Food) -> Void)? = nil, autoStartListening: Bool = false) {
        _isPresented = isPresented
        self.selectedMeal = selectedMeal
        _mealDescription = State(initialValue: initialDescription)
        self.onFoodGenerated = onFoodGenerated
        self.autoStartListening = autoStartListening
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top input section
                VStack(spacing: 16) {
                    // Input field with bottom border only
                    VStack(spacing: 8) {
                        TextField("Describe your meal or activity", text: $mealDescription)
                            .font(.system(size: 17))
                            .padding(.vertical, 12)
                            .focused($isInputFocused)
                            .background(Color.clear)

                        // Bottom border
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color(.systemGray4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .background(Color(.systemBackground))

                Spacer()
                
                // Bottom action buttons
                HStack(spacing: 16) {
                    if isListening {
                        // When listening, show only the pulsing orange checkmark
                        Spacer()
                        
                        Button(action: {
                            HapticFeedback.generate()
                            toggleSpeechRecognition() // Stop listening
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Color(.systemBackground))
                                .frame(width: 30, height: 30)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .scaleEffect(pulseScale)
                                .animation(
                                    Animation.easeInOut(duration: 1.0)
                                        .repeatForever(autoreverses: true),
                                    value: pulseScale
                                )
                        }
                        
                      
                    } else {
                        // Normal state - show all three icons
                        // Barcode scanner button
                        Button(action: {
                            HapticFeedback.generate()
                            showFoodScanner = true
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 30, height: 30)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        }
                        
                        Spacer()
                        
                        // Microphone button (speech-to-text)
                        Button(action: {
                            HapticFeedback.generate()
                            toggleSpeechRecognition()
                        }) {
                            Image(systemName: "mic")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 30, height: 30)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        }
                        
                        
                        
                        // Waveform/Submit button - changes based on text input
                        Button(action: {
                            HapticFeedback.generate()
                            if !mealDescription.isEmpty {
                                // Submit the meal description
                                submitMealDescription()
                            } else {
                                // Show voice log view
                                showVoiceLog = true
                            }
                        }) {
                            Image(systemName: mealDescription.isEmpty ? "waveform" : "arrow.forward")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(mealDescription.isEmpty ? .primary : .white)
                                .frame(width: 30, height: 30)
                                .background(mealDescription.isEmpty ? Color(.systemBackground) : Color.accentColor)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(mealDescription.isEmpty ? Color(.systemGray4) : Color.clear, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(Color(.systemBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        // .presentationDetents([])
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showFoodScanner) {
            FoodScannerView(isPresented: $showFoodScanner, selectedMeal: selectedMeal, onFoodScanned: { food, foodLogId in
                // When a barcode is scanned and food is returned, show the confirmation view
                scannedFood = food
                scannedFoodLogId = foodLogId
                // Small delay to ensure transitions are smooth
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showConfirmFoodView = true
                }
            })
            .edgesIgnoringSafeArea(.all)
        }
        .fullScreenCover(isPresented: $showVoiceLog) {
            VoiceLogView(isPresented: $showVoiceLog, selectedMeal: selectedMeal)
        }
        .sheet(isPresented: $showConfirmFoodView, onDismiss: {
            // Reset scanned food data
            scannedFood = nil
            scannedFoodLogId = nil
        }) {
            if let food = scannedFood {
                NavigationView {
                    ConfirmLogView(
                        path: .constant(NavigationPath()),
                        food: food,
                        foodLogId: scannedFoodLogId
                    )
                }
            }
        }
        // Note: Upgrade sheet is presented from MainContentView to avoid conflicts
        .onChange(of: proFeatureGate.showUpgradeSheet) { _, newValue in
            if !newValue {
                if let pendingDescription = pendingRetryDescription,
                   let pendingMealType = pendingRetryMealType,
                   proFeatureGate.hasActiveSubscription() {
                    pendingRetryDescription = nil
                    pendingRetryMealType = nil
                    DispatchQueue.main.async {
                        prepareForAnalysisStates()
                        performAnalysis(description: pendingDescription, mealType: pendingMealType)
                    }
                } else {
                    pendingRetryDescription = nil
                    pendingRetryMealType = nil
                }
            }
        }
        .onAppear {
            // Auto-focus the input immediately when sheet appears
            isInputFocused = true
            if autoStartListening && !isListening {
                toggleSpeechRecognition()
            }
        }
        // Dismiss TextLogView whenever the scanner sheet closes
        .onChange(of: showFoodScanner) { _, newValue in
            if newValue == false {
                isPresented = false
            }
        }
        
        .onChange(of: speechRecognizer.transcript) { _, newTranscript in
            if !newTranscript.isEmpty {
                mealDescription = newTranscript
            }
        }
        .onChange(of: isListening) { _, newValue in
            if newValue {
                // Start pulsing animation when listening starts
                pulseScale = 1.2
            } else {
                // Reset scale when listening stops
                pulseScale = 1.0
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleSpeechRecognition() {
        if isListening {
            speechRecognizer.stopRecording()
            isListening = false
        } else {
            speechRecognizer.startRecording()
            isListening = true
        }
    }
    
    private func submitMealDescription() {
        guard !mealDescription.isEmpty else { return }
        let description = mealDescription
        let selectedMealType = selectedMeal
        pendingRetryDescription = nil
        pendingRetryMealType = nil

        DispatchQueue.main.async {
            self.mealDescription = ""
            self.isPresented = false
        }

        prepareForAnalysisStates()
        performAnalysis(description: description, mealType: selectedMealType)
    }

    private func prepareForAnalysisStates() {
        print("🆕 Starting MODERN text analysis with state system - OPTION 1")
        foodManager.isGeneratingMacros = true
        foodManager.isLoading = true
        foodManager.macroLoadingMessage = "Analyzing description..."
        foodManager.macroLoadingTitle = "Generating with AI"
        foodManager.updateFoodScanningState(.initializing)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            foodManager.updateFoodScanningState(.preparing(image: UIImage()))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            foodManager.updateFoodScanningState(.uploading(progress: 0.5))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            foodManager.updateFoodScanningState(.analyzing)
        }
    }

    private func performAnalysis(description: String, mealType: String) {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.timeZone = .current
        let dateString = formatter.string(from: dayLogsVM.selectedDate)
        NetworkManagerTwo.shared.analyzeMealOrActivity(
            description: description,
            mealType: mealType,
            date: dateString
        ) { result in
            switch result {
            case .success(let responseData):
                print("✅ Successfully analyzed meal or activity")

                self.pendingRetryDescription = nil
                self.pendingRetryMealType = nil

                DispatchQueue.main.async {
                    self.foodManager.updateFoodScanningState(.processing)
                }

                if let entryType = responseData["entry_type"] as? String {
                    DispatchQueue.main.async {
                        if entryType == "food" {
                            self.foodManager.macroLoadingTitle = "Generating Macros with AI"
                            self.foodManager.macroLoadingMessage = "Calculating nutritional data..."
                        } else if entryType == "activity" {
                            self.foodManager.macroLoadingTitle = "Logging Activity with AI"
                            self.foodManager.macroLoadingMessage = "Calculating calories burned..."
                        }
                    }

                    if entryType == "food" {
                        self.handleFoodResponse(responseData)
                    } else if entryType == "activity" {
                        self.handleActivityResponse(responseData)
                    }
                }

            case .failure(let error):
                print("❌ Failed to analyze meal or activity: \(error)")
                if let netError = error as? NetworkManagerTwo.NetworkError,
                   case .featureLimitExceeded(let message) = netError {
                    self.handleFeatureLimitExceeded(message: message,
                                                    description: description,
                                                    mealType: mealType)
                } else {
                    self.handleAnalysisFailure(error.localizedDescription)
                }
            }
        }
    }

    private func handleAnalysisFailure(_ message: String) {
        DispatchQueue.main.async {
            self.foodManager.handleScanFailure(.networkError(message))
            self.foodManager.isGeneratingMacros = false
            self.foodManager.isLoading = false
            self.foodManager.macroLoadingMessage = ""
            self.foodManager.macroLoadingTitle = "Generating with AI"
        }
    }

    private func handleFeatureLimitExceeded(message: String,
                                            description: String,
                                            mealType: String) {
        pendingRetryDescription = description
        pendingRetryMealType = mealType
        handleAnalysisFailure(message)
        presentFoodScansUpgradeSheet()
    }

    private func presentFoodScansUpgradeSheet() {
        let email = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        if !email.isEmpty {
            Task { await proFeatureGate.refreshUsageSummary(for: email) }
        }
        DispatchQueue.main.async {
            proFeatureGate.blockedFeature = .foodScans
            proFeatureGate.showUpgradeSheet = true
        }
    }

    private func handleFoodResponse(_ responseData: [String: Any]) {
        // FIXED: Use correct case mapping between backend (snake_case) and frontend
        guard let foodLogId = responseData["food_log_id"] as? Int,  // ✅ FIXED: snake_case
              let foodData = responseData["food"] as? [String: Any],
              let displayName = foodData["displayName"] as? String,  // Keep camelCase (food object uses camelCase)
              let calories = responseData["calories"] as? Int,
              let message = responseData["message"] as? String,
              let mealType = responseData["meal_type"] as? String else {  // ✅ FIXED: snake_case
            print("❌ Failed to parse food response data")
            print("❌ DEBUG: Available keys at top level: \(responseData.keys)")
            if let foodData = responseData["food"] as? [String: Any] {
                print("❌ DEBUG: Available keys in food object: \(foodData.keys)")
            }
            return
        }
        
        // Extract health analysis from the response
        // var healthAnalysisData: HealthAnalysis? = nil
        // if let healthData = foodData["health_analysis"] as? [String: Any] {
        //     // Parse the health analysis manually
        //     if let score = healthData["score"] as? Int,
        //        let color = healthData["color"] as? String,
        //        let positives = healthData["positives"] as? [String],
        //        let negatives = healthData["negatives"] as? [String],
        //        let additives = healthData["additives"] as? [[String: Any]],
        //        let nutriScoreData = healthData["nutri_score"] as? [String: Any],
        //        let nutriScorePoints = nutriScoreData["points"] as? Int,
        //        let nutriScoreLetter = nutriScoreData["letter"] as? String {
                
        //         // Parse additives array
        //         let parsedAdditives = additives.compactMap { additive -> HealthAdditive? in
        //             guard let code = additive["code"] as? String,
        //                   let risk = additive["risk"] as? String else { return nil }
        //             return HealthAdditive(code: code, risk: risk)
        //         }
                
        //         // Create health analysis object
        //         healthAnalysisData = HealthAnalysis(
        //             score: score,
        //             color: color,
        //             positives: positives,
        //             negatives: negatives,
        //             additives: parsedAdditives,
        //             nutriScore: HealthNutriScore(points: nutriScorePoints, letter: nutriScoreLetter),
        //             organicBonus: healthData["organic_bonus"] as? Int,
        //             additivePenalty: healthData["additive_penalty"] as? Int
        //         )
        //     }
        // }
        // Extract health analysis from the response
            var healthAnalysisData: HealthAnalysis? = nil
            if let healthDict = foodData["health_analysis"] as? [String: Any] {
                do {
                    let data = try JSONSerialization.data(withJSONObject: healthDict, options: [])
                    let decoder = JSONDecoder()
                    // We already mapped the snake_case keys via CodingKeys above, so no need for keyDecodingStrategy here.
                    healthAnalysisData = try decoder.decode(HealthAnalysis.self, from: data)
                } catch {
                    print("❌ Failed to decode HealthAnalysis: \(error)")
                }
            }

        
        // Extract foodNutrients array from response
        var foodNutrients: [Nutrient]? = nil
        if let nutrientsArray = foodData["foodNutrients"] as? [[String: Any]] {
            foodNutrients = nutrientsArray.compactMap { nutrientData in
                guard let name = nutrientData["nutrientName"] as? String,
                      let value = nutrientData["value"] as? Double,
                      let unit = nutrientData["unitName"] as? String else { return nil }
                return Nutrient(nutrientName: name, value: value, unitName: unit)
            }
        }
        let aiInsight = foodData["ai_insight"] as? String
        let nutritionScore: Double? = {
            if let value = foodData["nutrition_score"] as? Double { return value }
            if let value = foodData["nutrition_score"] as? NSNumber { return value.doubleValue }
            if let value = foodData["nutrition_score"] as? String, let double = Double(value) { return double }
            return nil
        }()
        
        // Create LoggedFoodItem from response
        let loggedFoodItem = LoggedFoodItem(
            foodLogId: foodLogId,
            fdcId: foodData["fdcId"] as? Int ?? 0,
            displayName: displayName,
            calories: foodData["calories"] as? Double ?? Double(calories),
            servingSizeText: foodData["servingSizeText"] as? String ?? "1 serving",
            numberOfServings: foodData["numberOfServings"] as? Double ?? 1.0,
            brandText: foodData["brandText"] as? String ?? "",
            protein: foodData["protein"] as? Double ?? 0.0,
            carbs: foodData["carbs"] as? Double ?? 0.0,
            fat: foodData["fat"] as? Double ?? 0.0,
            healthAnalysis: healthAnalysisData,
            foodNutrients: foodNutrients,
            aiInsight: aiInsight,
            nutritionScore: nutritionScore
        )

        if let onFoodGenerated {
            let generatedFood = Food.from(loggedItem: loggedFoodItem)
            DispatchQueue.main.async {
                onFoodGenerated(generatedFood)
            }
            return
        }

        // Create CombinedLog for dashboard display
        let combinedLog = CombinedLog(
            type: .food,
            status: responseData["status"] as? String ?? "success",
            calories: Double(calories),
            message: message,
            foodLogId: foodLogId,
            food: loggedFoodItem,
            mealType: mealType,
            mealLogId: nil, meal: nil, mealTime: nil,
            scheduledAt: dayLogsVM.selectedDate,
            recipeLogId: nil, recipe: nil, servingsConsumed: nil
        )
        
        DispatchQueue.main.async {
            // Add to dashboard
            self.dayLogsVM.addPending(combinedLog)
            
            // Update foodManager's combinedLogs
            if let idx = self.foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                self.foodManager.combinedLogs[idx] = combinedLog
            } else {
                self.foodManager.combinedLogs.insert(combinedLog, at: 0)
            }
            
            // Show success feedback
            self.foodManager.lastLoggedItem = (name: displayName, calories: Double(calories))
            self.foodManager.showLogSuccess = true
            
            // Trigger review manager for notification permission after 5 foods
            ReviewManager.shared.foodWasLogged()
            
            // Track meal timing for smart reminders
            MealReminderService.shared.mealWasLogged(mealType: mealType)
            
            // MODERN: Update state to completed
            self.foodManager.updateFoodScanningState(.completed(result: combinedLog))
            
            // Reset after brief delay to show 100% completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.foodManager.resetFoodScanningState()
                
                // Legacy cleanup after showing completion
                self.foodManager.isGeneratingMacros = false
                self.foodManager.isLoading = false
                self.foodManager.macroLoadingMessage = ""
                self.foodManager.macroLoadingTitle = "Generating Macros with AI"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.foodManager.showLogSuccess = false
            }
        }
    }
    
    private func handleActivityResponse(_ responseData: [String: Any]) {
        // Extract activity data
        guard let activityLogId = responseData["activity_log_id"] as? Int,
              let activityName = responseData["activity_name"] as? String,
              let caloriesBurned = responseData["calories_burned"] as? Int,
              let durationMinutes = responseData["duration_minutes"] as? Int,
              let message = responseData["message"] as? String else {
            print("❌ Failed to parse activity response data")
            return
        }
        
        print("🏃‍♂️ Activity logged: \(activityName) - \(caloriesBurned) calories burned")
        
        // Create ActivitySummary to match HealthKit structure
        let activitySummary = ActivitySummary(
            id: String(activityLogId),
            workoutActivityType: formatActivityType(responseData["activity_type"] as? String ?? "Other"),
            displayName: formatActivityName(activityName),
            duration: Double(durationMinutes * 60), // Convert to seconds
            totalEnergyBurned: Double(caloriesBurned),
            totalDistance: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        // Create CombinedLog for dashboard display (matching HealthKit activities format)
        let combinedLog = CombinedLog(
            type: .activity,
            status: "success",
            calories: Double(caloriesBurned), // Positive calories like HealthKit activities
            message: message,
            scheduledAt: Date(),
            activityId: String(activityLogId),
            activity: activitySummary,
            logDate: formatDateForLog(Date()),
            dayOfWeek: formatDayOfWeek(Date())
        )
        
        DispatchQueue.main.async {
            // Add to dashboard immediately (same as food logs)
            self.dayLogsVM.addPending(combinedLog)
            
            // Show success feedback for activity
            self.foodManager.lastLoggedItem = (name: activityName, calories: Double(caloriesBurned))
            self.foodManager.showLogSuccess = true
            
            // MODERN: Update state to completed for activities too
            self.foodManager.updateFoodScanningState(.completed(result: combinedLog))
            
            // Reset after brief delay to show 100% completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.foodManager.resetFoodScanningState()
                
                // Legacy cleanup after showing completion
                self.foodManager.isGeneratingMacros = false
                self.foodManager.isLoading = false
                self.foodManager.macroLoadingMessage = ""
                self.foodManager.macroLoadingTitle = "Generating Macros with AI"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.foodManager.showLogSuccess = false
            }
        }
    }
    
    // Helper methods to match DayLogsViewModel format
    private func formatDateForLog(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    // Helper methods for activity formatting
    private func formatActivityName(_ name: String) -> String {
        // Convert lowercase activity names to proper display names
        switch name.lowercased() {
        case "running":
            return "Running"
        case "walking":
            return "Walking"
        case "cycling", "biking":
            return "Cycling"
        case "swimming":
            return "Swimming"
        case "hiking":
            return "Hiking"
        case "yoga":
            return "Yoga"
        case "weightlifting", "weight lifting", "strength training":
            return "Strength Training"
        case "cardio":
            return "Cardio Workout"
        case "tennis":
            return "Tennis"
        case "basketball":
            return "Basketball"
        case "soccer", "football":
            return "Soccer"
        case "rowing":
            return "Rowing"
        case "elliptical":
            return "Elliptical"
        case "stairs", "stair climbing":
            return "Stair Climbing"
        default:
            // Capitalize first letter for unknown activities
            return name.prefix(1).uppercased() + name.dropFirst().lowercased()
        }
    }
    
    private func formatActivityType(_ type: String) -> String {
        // Map AI activity types to HealthKit-compatible types for consistent icons
        switch type.lowercased() {
        case "cardio":
            return "Running"  // Default cardio to running icon
        case "strength":
            return "StrengthTraining"
        case "sports":
            return "Other"
        default:
            return formatActivityName(type)  // Use the same formatting
        }
    }
}

// MARK: - Speech Recognizer

class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    func startRecording() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.beginRecording()
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition permission denied")
                @unknown default:
                    print("Unknown speech recognition permission status")
                }
            }
        }
    }
    
    private func beginRecording() {
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // Set up audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            print("Audio engine failed to start: \(error)")
            return
        }
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcript = result.bestTranscription.formattedString
                }
                
                if error != nil || result?.isFinal == true {
                    self?.stopRecording()
                }
            }
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}

#Preview {
    TextLogView(isPresented: .constant(true), selectedMeal: "Lunch")
        .environmentObject(FoodManager())
        .environmentObject(DayLogsViewModel())
        .environmentObject(ProFeatureGate())
} 
