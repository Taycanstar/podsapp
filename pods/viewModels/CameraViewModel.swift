
import SwiftUI
import AVFoundation
import CoreMedia

import MicrosoftCognitiveServicesSpeech

struct PodItem: Identifiable {
    var id: Int // Correctly declare the type of `id`
    var videoURL: URL?
    var image: UIImage?
    var metadata: String
    var thumbnail: UIImage? // For local UI usage
    var thumbnailURL: URL?  // For networking and referencing the image's location
    var imageURL: URL?
    var itemType: String
}

struct Pod: Identifiable {
    var id: Int // Correctly declare the type of `id`
    var items: [PodItem] = []
    var title: String
}



struct PodJSON: Codable {
    let id: Int
    let title: String
    let created_at: String
    let items: [PodItemJSON] // Add this line
}

struct PodItemJSON: Codable {
    let id: Int
    let videoURL: String?
    let label: String
    let thumbnail: String
    let image: String?
    let itemType: String
   
}


struct PodResponse: Codable {
    let pods: [PodJSON]
}

extension Pod {
    init(from podJSON: PodJSON) {
        self.id = podJSON.id
        self.title = podJSON.title
        self.items = podJSON.items.map { PodItem(from: $0) }
    }
}

extension PodItem {
    init(from itemJSON: PodItemJSON) {
        self.id = itemJSON.id
        self.itemType = itemJSON.itemType
        if let videoURLString = itemJSON.videoURL {
                    self.videoURL = URL(string: videoURLString)
                } else {
                    self.videoURL = nil // Assign nil if the string is nil
                } // Consider safer unwrapping
        self.metadata = itemJSON.label
        self.thumbnailURL = URL(string: itemJSON.thumbnail) // Consider safer unwrapping
        if let imageString = itemJSON.image {
                   self.imageURL = URL(string: imageString)
               } else {
                   self.imageURL = nil // Assign nil if the string is nil
               }
    }
}

enum CameraMode: String, CaseIterable {
    case fifteen = "15s"
    case thirty = "30s"
    case photo = "Photo"

    var label: String {
        return self.rawValue
    }

    var duration: Double {
        switch self {
        case .fifteen:
            return 15.0
        case .thirty:
            return 30.0
        case .photo:
            return 0.0 // Photo mode might not need a duration, but adjust as needed
        }
    }
}


// MARK: Camera View Model
class CameraViewModel: NSObject,ObservableObject,AVCaptureFileOutputRecordingDelegate, AVCapturePhotoCaptureDelegate{
    
    // Custom initializer
        override init() {
            super.init()
            configureSpeechService()
            checkPermission()
//            configureSessionFor(mode: selectedCameraMode)


            setupAudioRecorder()
        }
    
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCaptureMovieFileOutput()
    @Published var preview : AVCaptureVideoPreviewLayer!
    @Published var isFrontCameraUsed: Bool = false
    @Published var showCreatePodView = false
    @Published var isFlashOn: Bool = false
    var audioRecorder: AVAudioRecorder?
    @Published var isTranscribing: Bool = false
    static let shared = CameraViewModel()
    var savedAudioURL: URL?
    @Published var photoOutput = AVCapturePhotoOutput()
    // Define the selected mode property
    @Published var selectedCameraMode: CameraMode = .fifteen
    @Published var isFlashIntendedForPhoto: Bool = false



    let voiceCommands = ["start recording", "stop recording"]
    
    private var commandRecognizer: SPXSpeechRecognizer?
    var speechConfig: SPXSpeechConfiguration?
    @Published var selectedImage: UIImage?
    
    
    
    // MARK: Video Recorder Properties
    @Published var isRecording: Bool = false
//    @Published var recordedURLs: [URL] = []
    @Published var previewURL: URL?
    @Published var showPreview: Bool = false
    
    //MARK: Pod variables
    @Published var currentPod = Pod(id: -1,title: "")
    @Published var isPodRecording: Bool = false
    @Published var isPodFinalized = false

    
    // Top Progress Bar
    @Published var recordedDuration: CGFloat = 0
    @Published var maxDuration: CGFloat = 15.0
    @Published var isProcessingVideo = false
    var recordingTimer: Timer?

    
    var isWaveformEnabled = false
    var isVcEnabled = false
     var transcription = ""
    
    var speechRecognizer: SPXSpeechRecognizer?


//    func toggleWaveform() {
//        self.objectWillChange.send()
//        print("Toggling waveform...")
//        print("Current state before toggle: \(isWaveformEnabled)")
//        isWaveformEnabled.toggle()
//        if isWaveformEnabled {
//            print("Waveform enabled. Starting speech recognition.")
//            startSpeechRecognition()
//        } else {
//            print("Waveform disabled. Stopping speech recognition.")
//            stopSpeechRecognition()
//        }
//        print("Current state after toggle: \(isWaveformEnabled)")
//    }
    
    func toggleVoiceCommands() {
        self.objectWillChange.send()
        print("Toggling voice commands...")
        print("Current state before toggle: \(isVcEnabled)")
        isVcEnabled.toggle()
        if isVcEnabled {
            print("Voice commands enabled. Starting speech recognition.")
            startSpeechRecognition()
        } else {
            print("Voice commands disabled. Stopping speech recognition.")
            stopSpeechRecognition()
        }
        print("Current state after toggle: \(isVcEnabled)")
    }

    
    func checkPermission(){
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (status) in
                
                if status{
                    self.setUp()
                }
            }
        case .denied:
            self.alert.toggle()
            return
        default:
            return
        }
    }
    
    
    private func getDocumentsDirectory() -> URL {
          FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      }
    
    func setupAudioRecorder() {
           let audioFilename = getDocumentsDirectory().appendingPathComponent("audioRecording.wav")
           let settings = [
               AVFormatIDKey: Int(kAudioFormatLinearPCM),
               AVSampleRateKey: 12000,
               AVNumberOfChannelsKey: 1,
               AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
           ]

           do {
               audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
               audioRecorder?.prepareToRecord()
           } catch {
               print("Audio recorder setup failed: \(error)")
           }
       }


//    func setUp() {
//        do {
//            
//            if session.canAddOutput(photoOutput) {
//                    session.addOutput(photoOutput)
//                    // Set photo settings for high resolution if needed
//                    photoOutput.isHighResolutionCaptureEnabled = true
//                }
////            // Set up the audio session for recording
//            let audioSession = AVAudioSession.sharedInstance()
////            try audioSession.setCategory(.playAndRecord, mode: .default)
//            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker, .allowBluetooth])
//            try audioSession.setActive(true)
//
//            session.beginConfiguration()
//
//            // Video Input Setup
//            if let cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
//               let videoInput = try? AVCaptureDeviceInput(device: cameraDevice),
//               session.canAddInput(videoInput) {
//                session.addInput(videoInput)
//            }
//
//            // Audio Input Setup
//            if let audioDevice = AVCaptureDevice.default(for: .audio),
//               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
//               session.canAddInput(audioInput) {
//                session.addInput(audioInput)
//            }
//
//            if session.canAddOutput(output) {
//                session.addOutput(output)
//            }
//            
//            
//
//            session.commitConfiguration()
//            
//        
//        } catch {
//            print("Error setting up video/audio input: \(error)")
//        }
//    }
    
    func setUp() {
        do {
            // Set up the audio session for recording
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)

            // Call configureSessionFor with the initial mode
            configureSessionFor(mode: selectedCameraMode)
        } catch {
            print("Error setting up video/audio input or audio session: \(error)")
        }
    }

 
    func configureSessionFor(mode: CameraMode) {
        if session.isRunning {
            session.stopRunning()
        }

        session.beginConfiguration()

        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)

        switch mode {
        case .photo:
            configureForPhotoMode()
        case .fifteen, .thirty:
            // Use the maxDuration property to configure the session if necessary
            configureForVideoMode()
            print("maxDuration is", maxDuration)
        }

        session.commitConfiguration()

        session.startRunning()
    }



    

    func configureForPhotoMode() {
        // Ensure there's a camera input for the current position
        let currentCameraPosition: AVCaptureDevice.Position = isFrontCameraUsed ? .front : .back
        addCameraInput(position: currentCameraPosition)
        
        if !session.outputs.contains(where: { $0 is AVCapturePhotoOutput }) {
             if session.canAddOutput(photoOutput) {
                 session.addOutput(photoOutput)
                 photoOutput.isHighResolutionCaptureEnabled = true // Enable high-resolution capture
             }
         }
        // No need to set maxPhotoDimensions here as it's not a standard API.
        // Just make sure to enable high resolution photos in your photo settings during capture.
    }



    
    private func configureForVideoMode() {
        // Determine the correct camera position
        let position: AVCaptureDevice.Position = isFrontCameraUsed ? .front : .back
        
        // Add camera and audio inputs
        addCameraInput(position: position) // Use the dynamically determined position
        addAudioInput()
        
        // Add video output
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        // No additional settings are directly applied here for maxDuration
        // maxDuration is used in the recording logic instead
    }

    
    private func addCameraInput(position: AVCaptureDevice.Position) {
        guard let cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let videoInput = try? AVCaptureDeviceInput(device: cameraDevice) else {
            print("Error setting up camera input.")
            return
        }

        // Clear existing video inputs before adding a new one
        let existingVideoInputs = session.inputs.filter { input in
            guard let input = input as? AVCaptureDeviceInput else { return false }
            return input.device.hasMediaType(.video)
        }
        existingVideoInputs.forEach(session.removeInput)

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            print("Cannot add video input.")
        }
    }


    private func addAudioInput() {
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
              session.canAddInput(audioInput) else {
            print("Error setting up audio input.")
            return
        }
        session.addInput(audioInput)
    }


    
    func startRecordingBasedOnMode() {
      
        
        switch selectedCameraMode {
        case .fifteen, .thirty:
            startVideoRecording()
        case .photo:
            takePhoto() // Handle photo taking
        }
    }

    func startVideoRecording() {
        guard !isRecording else { return }

        // Consider removing session stop and start logic if not needed every time
        // Ensure the session is correctly configured before starting a new recording
        
        setupAudioRecorder()
        audioRecorder?.record()

        let outputPath = NSTemporaryDirectory() + UUID().uuidString + ".mov"
        let outputFileURL = URL(fileURLWithPath: outputPath)

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.output.connection(with: .video) != nil else {
                print("Failed to start video recording: No active video connection.")
                return
            }

            self.output.startRecording(to: outputFileURL, recordingDelegate: self)
            self.isRecording = true
        }
        
        recordedDuration = 0

         // Start or restart the timer
         recordingTimer?.invalidate() // Invalidate any existing timer
         recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
             guard let self = self else { return }
             self.recordedDuration += 1
             if self.recordedDuration >= maxDuration {
                 self.stopRecording()
                 timer.invalidate() // Stop the timer
             }
         }
    }


    
    func takePhoto() {
        if !session.isRunning {
            session.startRunning()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Delay for 0.5 seconds
            guard let connection = self.photoOutput.connection(with: .video), connection.isActive else {
                print("No active video connection for photo capture.")
                return
            }

            if self.isFrontCameraUsed {
                connection.isVideoMirrored = true
                connection.videoOrientation = .portrait
            }

            let photoSettings = AVCapturePhotoSettings()
            photoSettings.isHighResolutionPhotoEnabled = true

            if self.isFlashIntendedForPhoto {
                photoSettings.flashMode = .on
            } else {
                photoSettings.flashMode = .off
            }

            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    func lockExposureAndWhiteBalanceForPhoto() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }

        do {
            try device.lockForConfiguration()
            
            let currentExposureTargetBias = device.exposureTargetBias
            device.setExposureTargetBias(currentExposureTargetBias, completionHandler: nil)
            
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }
            
            if device.isWhiteBalanceModeSupported(.locked) {
                device.whiteBalanceMode = .locked
            }

            device.unlockForConfiguration()
        } catch {
            print("Unable to lock device for configuration: \(error)")
        }
    }

    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(), let capturedImage = UIImage(data: imageData) else {
            print("Failed to convert photo to image.")
            return
        }

        // If the front camera was used, mirror the image
        let imageToDisplay: UIImage
        if isFrontCameraUsed {
            // Flip the image for the front camera
            if let cgImg = capturedImage.cgImage {
                imageToDisplay = UIImage(cgImage: cgImg, scale: capturedImage.scale, orientation: .leftMirrored)
            } else {
                imageToDisplay = capturedImage
            }
        } else {
            imageToDisplay = capturedImage
        }

        // Handle the image (similar to handling selected image from picker)
        DispatchQueue.main.async {
            self.selectedImage = imageToDisplay
            self.showPreview = true // Indicate to show preview
            self.isProcessingVideo = false // Update processing state if needed
            self.previewURL = nil
            print("Captured image set. Size: \(imageToDisplay.size)")
            // Trigger any UI updates to show the captured image
        }
    }


    // Speech Service Configuration
        func configureSpeechService() {
            guard let subscriptionKey = ProcessInfo.processInfo.environment["SPEECH_KEY"],
                  let serviceRegion = ProcessInfo.processInfo.environment["SPEECH_REGION"] else {
                print("Environment variables for SPEECH_KEY and SPEECH_REGION are not set.")
                return
            }
            do {
                self.speechConfig = try SPXSpeechConfiguration(subscription: subscriptionKey, region: serviceRegion)
                // Further configuration if needed
            } catch {
                print("Error configuring speech service: \(error)")
            }
        }
        
    
        // Start speech recognition for commands
    // Start speech recognition for commands
    func startSpeechRecognition() {
        guard let config = self.speechConfig else {
            print("Speech configuration not initialized.")
            return
        }
        
        do {
            let audioConfig = SPXAudioConfiguration()
            self.speechRecognizer = try SPXSpeechRecognizer(speechConfiguration: config, audioConfiguration: audioConfig)
            guard let recognizer = self.speechRecognizer else { return }
            
            // Adjusting the closure to match expected signature and safely unwrapping the result text
            recognizer.addRecognizedEventHandler { [weak self] (recognizer: SPXSpeechRecognizer, eventArgs: SPXSpeechRecognitionEventArgs) in
                DispatchQueue.main.async {
                    guard let strongSelf = self, let resultText = eventArgs.result.text, !resultText.isEmpty else { return }
                    strongSelf.handleRecognizedText(resultText)
                }
            }

            try recognizer.startContinuousRecognition()
        } catch {
            print("Failed to start speech recognition: \(error)")
        }
    }

        
        // Stop speech recognition
        func stopSpeechRecognition() {
            do {
                try self.speechRecognizer?.stopContinuousRecognition()
                // Additional cleanup if needed
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                 try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
                 try? AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to stop speech recognition: \(error)")
            }
        }
        
    
//    private func handleRecognizedText(_ text: String) {
//        let command = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
//        
//        // Using a switch statement can prepare the structure for easier extension with new commands
//        switch command {
//        case let cmd where cmd.contains("start recording"):
//            DispatchQueue.main.async {
//                if !self.isRecording {
//                    self.startRecording()
//                }
//            }
//        case let cmd where cmd.contains("stop recording"):
//            DispatchQueue.main.async {
//                if self.isRecording {
//                    self.stopRecording()
//                }
//            }
//        default:
//            break
//        }
//    }
    
    private func handleRecognizedText(_ text: String) {
        let command = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Using a switch statement can prepare the structure for easier extension with new commands
        switch command {
        case let cmd where cmd.contains("start recording"):
            DispatchQueue.main.async {
                if !self.isRecording {
                    self.startRecordingBasedOnMode() // Ensure this starts recording based on the selected mode
                }
            }
        case let cmd where cmd.contains("stop recording"):
            DispatchQueue.main.async {
                if self.isRecording {
                    self.stopRecording()
                }
            }
        case let cmd where cmd.contains("take photo"):
            DispatchQueue.main.async {
                // Ensure this is called only when in Photo mode to prevent it from interrupting video recording
                if !self.isRecording && self.selectedCameraMode == .photo {
                    self.takePhoto()
                }
            }
        default:
            break
        }
    }


    // Helper function to append text to the transcription safely
    private func appendTranscription(_ text: String) {
        DispatchQueue.main.async {
            self.transcription += text + " "
        }
    }


      func stopRecording() {
          output.stopRecording()
          audioRecorder?.stop()
          isRecording = false
          recordedDuration = 0
          recordingTimer?.invalidate() // Stop the timer
        recordingTimer = nil
          
          if isVcEnabled {
              toggleVoiceCommands()
          }
          if isWaveformEnabled {
              isWaveformEnabled = false
          }
          print(transcription, "transcription after")
      }
//
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
         if let error = error {
             print(error.localizedDescription)
             return
         }

         DispatchQueue.main.async {
             self.previewURL = outputFileURL
             self.showPreview = true
         }
     }
    
    
//    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
//        if let error = error {
//            print("Recording error: \(error)")
//            return
//        }
//
//        let compressedURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
//        
//        compressVideo(inputURL: outputFileURL, outputURL: compressedURL) { [weak self] (success, compressedURL) in
//            guard let self = self, success, let compressedURL = compressedURL else {
//                print("Compression failed.")
//                return
//            }
//            
//            DispatchQueue.main.async {
//                self.previewURL = compressedURL
//                self.showPreview = true
//
//            }
//        }
//    }
    
    func compressVideo(inputURL: URL, outputURL: URL, handler: @escaping (Bool, URL?) -> Void) {
        let asset = AVURLAsset(url: inputURL, options: nil)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            print("Cannot create export session.")
            handler(false, nil)
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        let start = CMTimeMake(value: 0, timescale: 600)
        let range = CMTimeRangeMake(start: start, duration: asset.duration)
        exportSession.timeRange = range

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    print("Video compression succeeded.")
                    handler(true, outputURL)
                case .failed:
                    print("Video compression failed: \(String(describing: exportSession.error))")
                    handler(false, nil)
                case .cancelled:
                    print("Video compression cancelled.")
                    handler(false, nil)
                default:
                    print("Unknown error during video compression")
                    handler(false, nil)
                }
            }
        }
    }

    

       func reRecordVideo() {
           previewURL = nil
           showPreview = false
           

           if currentPod.items.isEmpty {
               isPodRecording = false
           }
       }

    func finalizePod() {
            isPodFinalized = true
        }
    
    func toggleFlashForPhotoMode() {
           isFlashIntendedForPhoto.toggle()
       }

  
    func toggleFlash() {
        guard !isFrontCameraUsed, // Add this check
              let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), // Force back camera
              device.hasTorch else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            device.torchMode = device.torchMode == .on ? .off : .on
            isFlashOn = device.torchMode == .on
            
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error)")
        }
    }


    func switchCamera() {
        guard let currentCameraInput = session.inputs.first(where: { input in
            guard let input = input as? AVCaptureDeviceInput else { return false }
            return input.device.hasMediaType(.video)
        }) as? AVCaptureDeviceInput else {
            print("Failed to get current camera input")
            return
        }

        session.beginConfiguration()
        session.removeInput(currentCameraInput)

        let newCameraPosition: AVCaptureDevice.Position = currentCameraInput.device.position == .front ? .back : .front
        guard let newCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newCameraPosition),
              let newCameraInput = try? AVCaptureDeviceInput(device: newCameraDevice) else {
            print("Failed to create new camera input")
            session.commitConfiguration()
            return
        }

        if session.canAddInput(newCameraInput) {
            session.addInput(newCameraInput)
            isFrontCameraUsed.toggle() // Update the flag indicating which camera is being used
        } else {
            print("Cannot add new camera input")
        }

        // After switching the camera, ensure the photo output is correctly configured.
        // This may involve adjusting the connection settings for the photo output.
        if let photoConnection = photoOutput.connection(with: .video) {
            // Check and adjust the photoConnection settings as needed, for example:
            if photoConnection.isVideoOrientationSupported {
                photoConnection.videoOrientation = AVCaptureVideoOrientation.portrait
            }
        }

        session.commitConfiguration()
        
        // If the session was stopped, start it again.
        if !session.isRunning {
            session.startRunning()
        }
    }



    private func reconfigureAudioInput() {
        if let currentAudioInput = session.inputs.first(where: { $0 is AVCaptureDeviceInput && ($0 as! AVCaptureDeviceInput).device.hasMediaType(.audio) }) {
            session.removeInput(currentAudioInput)
        }

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }
    }
//    func startRecordingNextItem() {
//        // Reset the preview URL for the new recording
//        self.previewURL = nil
//
//        // Check if the session is already running; if not, start it
//        if !session.isRunning {
//            session.startRunning()
//        }
//
//        // Generate a unique URL for the new recording
//        let tempURL = NSTemporaryDirectory() + "item_\(Date().timeIntervalSince1970).mov"
//        let outputFileURL = URL(fileURLWithPath: tempURL)
//
//        // Start recording to the new file URL
//        output.startRecording(to: outputFileURL, recordingDelegate: self)
//
//    }

   
    
    func reRecordCurrentItem() {
        // If the user is re-recording before confirming the video,
        // we just reset the necessary states for a new recording

        // Reset the preview URL for the new recording
        previewURL = nil

        // Indicate that we are not currently recording
        isRecording = false

        recordedDuration = 0

        // setupCameraForRecording()
    }
    
    func filterCommands(from transcription: String) -> String {
        let commandsToFilter = ["stop recording"] // Add any other commands you want to filter out
        var filteredTranscription = transcription
        for command in commandsToFilter {
            filteredTranscription = filteredTranscription.replacingOccurrences(of: command, with: "")
        }
        return filteredTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    
//    func confirmVideo() {
//        guard let videoURL = previewURL else {
//            print("No video to confirm.")
//            return
//        }
//        isTranscribing = true
//
//        // Get the URL of the recorded audio
//        let audioFilename = getDocumentsDirectory().appendingPathComponent("audioRecording.wav")
//        print("Audio file path: \(audioFilename.path)")
//
//        // Check if audio file exists
//        if !FileManager.default.fileExists(atPath: audioFilename.path) {
//            print("Audio file does not exist.")
//        } else {
//            print("Audio file found, proceeding with transcription.")
//        }
//        let nextId = currentPod.items.count + 1
//        DispatchQueue.main.async {
//            // Transcribe the audio and then confirm the video
//            self.transcribeAudio(from: audioFilename) { [weak self] transcribedText in
//                guard let self = self else { return }
//                DispatchQueue.main.async {
//                    var metadata = transcribedText ?? "Item \(nextId)"
//                    metadata = metadata.replacingOccurrences(of: "stop recording", with: "", options: .caseInsensitive)
//                    print("Transcription result: \(metadata)")
//
//                    // Check if the last item in the Pod is the same as the current preview URL
//                    if self.currentPod.items.last?.videoURL != videoURL {
//                        let thumbnail = self.generateThumbnail(for: videoURL, usingFrontCamera: self.isFrontCameraUsed)
//                        let newItem = PodItem(id: nextId, videoURL: videoURL, metadata: metadata, thumbnail: thumbnail, itemType: "video")
//                        self.currentPod.items.append(newItem)
//    //                    print("Item confirmed and added to Pod. Current Pod count: \(self.currentPod.items.count)")
//                    } else {
//                        print("The item is already in the Pod.")
//                    }
//
//                    // Reset the preview URL and hide the preview
//                    self.isTranscribing = false
//                    self.showPreview = false
//                    self.recordedDuration = 0
//                    // Update the recording state
//                    self.isRecording = false
//
//
//                }
//            }
//        }
//
//
//    }
    
    func confirmVideo() {
        guard let videoURL = previewURL else {
            print("No video to confirm.")
            return
        }

        let nextId = currentPod.items.count + 1
        let defaultMetadata = "Item \(nextId)"
        
        if isWaveformEnabled {
            isTranscribing = true

            // Get the URL of the recorded audio
            let audioFilename = getDocumentsDirectory().appendingPathComponent("audioRecording.wav")
            print("Audio file path: \(audioFilename.path)")

            // Check if audio file exists
            if FileManager.default.fileExists(atPath: audioFilename.path) {
                print("Audio file found, proceeding with transcription.")
                // Transcribe the audio and then confirm the video
                transcribeAudio(from: audioFilename) { [weak self] transcribedText in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        let metadata = transcribedText?.replacingOccurrences(of: "stop recording", with: "", options: .caseInsensitive) ?? defaultMetadata
                        self.completeVideoConfirmation(with: videoURL, metadata: metadata)
                    }
                }
            } else {
                print("Audio file does not exist, proceeding without transcription.")
                completeVideoConfirmation(with: videoURL, metadata: defaultMetadata)
            }
        } else {
            // If isWaveformEnabled is false, skip transcription and use default metadata
            completeVideoConfirmation(with: videoURL, metadata: defaultMetadata)
        }
    }

    private func completeVideoConfirmation(with videoURL: URL, metadata: String) {
        // Check if the last item in the Pod is the same as the current preview URL
        if currentPod.items.last?.videoURL != videoURL {
            let thumbnail = generateThumbnail(for: videoURL, usingFrontCamera: isFrontCameraUsed)
            let newItem = PodItem(id: currentPod.items.count + 1, videoURL: videoURL, metadata: metadata, thumbnail: thumbnail, itemType: "video")
            currentPod.items.append(newItem)
            print("Item confirmed and added to Pod. Current Pod count: \(currentPod.items.count)")
        } else {
            print("The item is already in the Pod.")
        }

        // Reset the preview URL and hide the preview
        isTranscribing = false
        showPreview = false
        recordedDuration = 0
        // Update the recording state
        isRecording = false
    }

//    func confirmVideo() {
//        guard let videoURL = previewURL else {
//            print("No video to confirm.")
//            return
//        }
//        isTranscribing = true
//
//        // Get the URL of the recorded audio
//        let audioFilename = getDocumentsDirectory().appendingPathComponent("audioRecording.wav")
//        print("Audio file path: \(audioFilename.path)")
//
//        // Check if audio file exists
//        if !FileManager.default.fileExists(atPath: audioFilename.path) {
//            print("Audio file does not exist.")
//        } else {
//            print("Audio file found, proceeding with transcription.")
//        }
//        let nextId = currentPod.items.count + 1
//        if isWaveformEnabled {
//            print("hi")
//            transcribeAudio(from: audioFilename) { [weak self] transcribedText in
//                guard let self = self else { return }
//                DispatchQueue.main.async {
//                    var metadata = transcribedText ?? "Item \(nextId)"
//                    metadata = metadata.replacingOccurrences(of: "stop recording", with: "", options: .caseInsensitive)
//                    print("Transcription result: \(metadata)")
//
//                    // Check if the last item in the Pod is the same as the current preview URL
//                    if self.currentPod.items.last?.videoURL != videoURL {
//                        let thumbnail = self.generateThumbnail(for: videoURL, usingFrontCamera: self.isFrontCameraUsed)
//                        let newItem = PodItem(id: nextId, videoURL: videoURL, metadata: metadata, thumbnail: thumbnail)
//                        self.currentPod.items.append(newItem)
//    //                    print("Item confirmed and added to Pod. Current Pod count: \(self.currentPod.items.count)")
//                    } else {
//                        print("The item is already in the Pod.")
//                    }
//
//                    // Reset the preview URL and hide the preview
//                    self.isTranscribing = false
//                    self.showPreview = false
//                    self.recordedDuration = 0
//                    // Update the recording state
//                    self.isRecording = false
//
//                    self.setUp()
//                }
//            }
//        } else {
//            if self.currentPod.items.last?.videoURL != videoURL {
//                let thumbnail = self.generateThumbnail(for: videoURL, usingFrontCamera: self.isFrontCameraUsed)
//                let newItem = PodItem(id: nextId, videoURL: videoURL, metadata: "Item \(nextId)", thumbnail: thumbnail)
//                self.currentPod.items.append(newItem)
////                    print("Item confirmed and added to Pod. Current Pod count: \(self.currentPod.items.count)")
//            } else {
//                print("The item is already in the Pod.")
//            }
//
//            // Reset the preview URL and hide the preview
//            self.isTranscribing = false
//            self.showPreview = false
//            self.recordedDuration = 0
//            // Update the recording state
//            self.isRecording = false
//
//        }
//       
//       
// 
//    }
    
    
    func confirmPhoto() {
        guard let selectedImage = selectedImage else {
            print("No photo to confirm.")
            return
        }
        let nextId = currentPod.items.count + 1

        // Check for duplicate image
        if let lastItem = currentPod.items.last,
           let lastImage = lastItem.image,
           lastImage === selectedImage {
            print("Duplicate image detected. Skipping addition.")
            DispatchQueue.main.async {
               
                self.showPreview = false // Adjust as needed for consistent UI flow
            }
        } else {
            // No duplicate detected, proceed to append the new item
            let newItem = PodItem(id: nextId, videoURL: nil, image: selectedImage, metadata: "Item \(nextId)", thumbnail: selectedImage, thumbnailURL: nil, itemType: "image")

            DispatchQueue.main.async {
                self.currentPod.items.append(newItem)
                // Consider when and how `selectedImage` should be reset
                // self.selectedImage might be reset here or elsewhere depending on your app's flow
                self.showPreview = false // Adjust as needed for consistent UI flow
            }
        }

    }


//    func confirmPhoto() {
//        guard let selectedImage = selectedImage else {
//            print("No photo to confirm.")
//            return
//        }
//        let nextId = currentPod.items.count + 1
//        let thumbnail = selectedImage // Directly use the image or resize as needed
//        let newItem = PodItem(id:nextId, videoURL: nil, image: selectedImage, metadata: "Some metadata", thumbnail: thumbnail, thumbnailURL: nil)
//
//        DispatchQueue.main.async {
//            self.currentPod.items.append(newItem)
////            self.selectedImage = nil 
//            self.showPreview = false // Hide preview
//        }
//    }


//
//    func confirmVideo() {
//        guard let videoURL = previewURL else {
//            print("No video to confirm.")
//            return
//        }
//
//        DispatchQueue.main.async {
//            // Here, create and append a new PodItem with the metadata
//            let metadata = self.transcription.trimmingCharacters(in: .whitespacesAndNewlines)
//            let thumbnail = self.generateThumbnail(for: videoURL, usingFrontCamera: self.isFrontCameraUsed)
//           
//            let newItem = PodItem(id: UUID().hashValue, videoURL: videoURL, metadata: metadata, thumbnail: thumbnail)
//            self.currentPod.items.append(newItem)
//            
//            
//            print("Metadata added to new item and appended to Pod.")
//            
//
//              // Prepare the session for the next recording
//            self.recordedDuration = 0
//          
////            self.recordedURLs.removeAll()
//            // Reset states as necessary
////            self.previewURL = nil
//            self.showPreview = false
//            self.isRecording = false
//            self.transcription = ""
//
//        }
//    }


    
    func generateThumbnail(for url: URL, usingFrontCamera: Bool) -> UIImage? {
        let asset = AVAsset(url: url)
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        let time = CMTimeMakeWithSeconds(1.0, preferredTimescale: 600)
        
        do {
            let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            var thumbnail = UIImage(cgImage: img)
            
            // Flip the thumbnail if it was taken with the front camera
            if usingFrontCamera {
                if let cgImage = thumbnail.cgImage {
                    thumbnail = UIImage(cgImage: cgImage, scale: thumbnail.scale, orientation: .upMirrored)
                }
            }

            return thumbnail
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }

    func confirmVideoAndNavigateToCreatePod() {
            confirmVideo()
            showCreatePodView = true
        }
    
    func confirmPhotoAndNavigateToCreatePod() {
            confirmPhoto()
            showCreatePodView = true
        }

    func transcribeAudio(from url: URL, completion: @escaping (String?) -> Void) {
        guard let speechConfig = self.speechConfig else {
            print("Speech configuration not set up.")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        guard let audioConfig = SPXAudioConfiguration(wavFileInput: url.path) else {
            print("Audio configuration could not be created.")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        do {
            let speechRecognizer = try SPXSpeechRecognizer(speechConfiguration: speechConfig, audioConfiguration: audioConfig)
            try speechRecognizer.recognizeOnceAsync { result in
                DispatchQueue.main.async {
                    if let text = result.text, !text.isEmpty {
                        completion(text)
                    } else {
                        print("Transcription failed or was empty.")
                        completion(nil)
                    }
                }
            }
        } catch {
            print("Error setting up speech recognizer: \(error)")
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }



//
//    func handleSelectedVideo(_ url: URL) {
////        self.isProcessingVideo = true // Notify that processing starts
//        print("Selected video URL: \(url)")
//
//        // Your video processing logic here...
//        extractAudioFromVideo(videoURL: url) { [weak self] success in
//            guard let self = self else { return }
//
//            DispatchQueue.main.async {
//                if success {
//                    // Processing succeeded, update accordingly
//                    self.previewURL = url
//                    self.showPreview = true
//                } else {
//                    // Processing failed, log or handle error
//                    print("Failed to extract and convert audio from the selected video.")
//                }
//             self.isProcessingVideo = false // Notify that processing ends
//            }
//        }
//    }
    
    func handleSelectedVideo(_ url: URL) {
        print("Selected video URL: \(url)")

        // Immediately proceed without extracting audio
        DispatchQueue.main.async {
            // Assuming the rest of the processing does not depend on the audio extraction outcome,
            // you can directly set the preview and show it.
            self.previewURL = url
            self.showPreview = true
            self.isProcessingVideo = false // Notify that processing ends
        }
    }
    
    func handleSelectedImage(_ image: UIImage) {
        DispatchQueue.main.async {
            self.selectedImage = image
            print("Selected image set in CameraViewModel. Size: \(image.size)")
            self.showPreview = true // Triggering preview
            self.isProcessingVideo = false
            self.previewURL = nil
        }
    }

    
//    func handleSelectedVideo(_ url: URL) {
//        print("Selected video URL: \(url)")
//
//        // Specify the output path for the compressed video
//        let compressedURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
//        
//        // Call the compression function
//        compressVideo(inputURL: url, outputURL: compressedURL) { [weak self] (success, compressedURL) in
//            guard let self = self, success, let compressedURL = compressedURL else {
//                print("Compression failed.")
//                // Ensure to stop the loading indicator in case of failure
//                return
//            }
//            
//            DispatchQueue.main.async {
//                // Use the compressed video URL
//                self.previewURL = compressedURL
//                self.showPreview = true
//                self.isProcessingVideo = false // Notify that processing ends
//                // Now you can proceed with uploading compressedURL
//                // Remember to clean up temporary files when done
//            }
//        }
//    }


    

    func extractAudioFromVideo(videoURL: URL, completion: @escaping (Bool) -> Void) {
        let asset = AVAsset(url: videoURL)
        guard let assetTrack = asset.tracks(withMediaType: .audio).first else {
            print("No audio track found in the video file.")
            completion(false)
            return
        }

        let audioFilename = getDocumentsDirectory().appendingPathComponent("audioRecording.wav")
        do {
            if FileManager.default.fileExists(atPath: audioFilename.path) {
                try FileManager.default.removeItem(at: audioFilename)
            }
        } catch {
            print("Error deleting existing audio file: \(error)")
            completion(false)
            return
        }

        guard let assetReader = try? AVAssetReader(asset: asset),
              let assetWriter = try? AVAssetWriter(url: audioFilename, fileType: .wav) else {
            print("Could not create asset reader/writer.")
            completion(false)
            return
        }

        let readerOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let writerOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let assetReaderOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: readerOutputSettings)
        let assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerOutputSettings)

        if assetReader.canAdd(assetReaderOutput) {
            assetReader.add(assetReaderOutput)
        } else {
            print("Cannot add reader output.")
            completion(false)
            return
        }

        if assetWriter.canAdd(assetWriterInput) {
            assetWriter.add(assetWriterInput)
        } else {
            print("Cannot add writer input.")
            completion(false)
            return
        }

        assetReader.startReading()
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)

        let processingQueue = DispatchQueue(label: "audioProcessingQueue")
        assetWriterInput.requestMediaDataWhenReady(on: processingQueue) {
            while assetWriterInput.isReadyForMoreMediaData {
                if let sampleBuffer = assetReaderOutput.copyNextSampleBuffer() {
                    assetWriterInput.append(sampleBuffer)
                } else {
                    assetWriterInput.markAsFinished()
                    assetWriter.finishWriting {
                        if assetWriter.status == .completed {
                            completion(true)
                        } else {
                            print("Failed to write audio file: \(String(describing: assetWriter.error))")
                            completion(false)
                        }
                    }
                    assetReader.cancelReading()
                    break
                }
            }
        }
    }


}





