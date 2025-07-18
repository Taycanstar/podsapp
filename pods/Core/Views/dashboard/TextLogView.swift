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
    @State private var mealDescription = ""
    @FocusState private var isInputFocused: Bool
    @EnvironmentObject var foodManager: FoodManager
    @EnvironmentObject var dayLogsVM: DayLogsViewModel
    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top input section
                VStack(spacing: 16) {
                    // Input field with bottom border only
                    VStack(spacing: 8) {
                        TextField("Describe your meal", text: $mealDescription)
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
        .onAppear {
            // Auto-focus the input immediately when sheet appears
            isInputFocused = true
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
        
        // Use FoodManager to process the text description with completion handler (same pattern as LogFood.swift)
        foodManager.generateMacrosWithAI(
            foodDescription: mealDescription,
            mealType: selectedMeal
        ) { result in
            switch result {
            case .success(let loggedFood):
                // Success is handled by FoodManager (shows toast, updates lists)
                print("Successfully generated macros with AI")
                
                let combinedLog = CombinedLog(
                    type: .food,
                    status: loggedFood.status,
                    calories: loggedFood.calories,
                    message: loggedFood.message,
                    foodLogId: loggedFood.foodLogId,
                    food: loggedFood.food,
                    mealType: loggedFood.mealType,
                    mealLogId: nil, meal: nil, mealTime: nil,
                    scheduledAt: dayLogsVM.selectedDate,
                    recipeLogId: nil, recipe: nil, servingsConsumed: nil
                )
                
                DispatchQueue.main.async {
                    dayLogsVM.addPending(combinedLog)
                    
                    // Update foodManager's combinedLogs
                    if let idx = foodManager.combinedLogs.firstIndex(where: { $0.foodLogId == combinedLog.foodLogId }) {
                        foodManager.combinedLogs.remove(at: idx)
                    }
                    foodManager.combinedLogs.insert(combinedLog, at: 0)
                }
                
            case .failure(let error):
                // Handle error
                print("Failed to generate macros with AI: \(error.localizedDescription)")
            }
        }
        
        // Dismiss the view
        isPresented = false
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
} 