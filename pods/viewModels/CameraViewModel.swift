
import SwiftUI
import AVFoundation

import MicrosoftCognitiveServicesSpeech

struct PodItem: Identifiable {
    var id: Int // Correctly declare the type of `id`
    var videoURL: URL
    var image: UIImage?
    var metadata: String
    var thumbnail: UIImage? // For local UI usage
    var thumbnailURL: URL?  // For networking and referencing the image's location
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
    let videoURL: String
    let label: String
    let thumbnail: String
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
        self.videoURL = URL(string: itemJSON.videoURL)! // Consider safer unwrapping
        self.metadata = itemJSON.label
        self.thumbnailURL = URL(string: itemJSON.thumbnail) // Consider safer unwrapping
    }
}





// MARK: Camera View Model
class CameraViewModel: NSObject,ObservableObject,AVCaptureFileOutputRecordingDelegate{
    
    // Custom initializer
        override init() {
            super.init()
            configureSpeechService()
            checkPermission()
          
//            setupAudioRecorder()
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
    @Published var maxDuration: CGFloat = 20
    
    @Published var isProcessingVideo = false
    
    var isWaveformEnabled = false
     var transcription = ""
    
    var speechRecognizer: SPXSpeechRecognizer?


    func toggleWaveform() {
        self.objectWillChange.send()
        print("Toggling waveform...")
        print("Current state before toggle: \(isWaveformEnabled)")
        isWaveformEnabled.toggle()
        if isWaveformEnabled {
            print("Waveform enabled. Starting speech recognition.")
            startSpeechRecognition()
        } else {
            print("Waveform disabled. Stopping speech recognition.")
            stopSpeechRecognition()
        }
        print("Current state after toggle: \(isWaveformEnabled)")
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


    func setUp() {
        do {
//            // Set up the audio session for recording
            let audioSession = AVAudioSession.sharedInstance()
//            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)

            session.beginConfiguration()

            // Video Input Setup
            if let cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let videoInput = try? AVCaptureDeviceInput(device: cameraDevice),
               session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }

            // Audio Input Setup
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            

            session.commitConfiguration()
            
        
        } catch {
            print("Error setting up video/audio input: \(error)")
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
        
        // Toggle waveform recognition
        func toggleWaveformRecognition() {
            isWaveformEnabled.toggle()
            if isWaveformEnabled {
                startSpeechRecognition()
            } else {
                stopSpeechRecognition()
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
            } catch {
                print("Failed to stop speech recognition: \(error)")
            }
        }
        
//    private func handleRecognizedText(_ text: String) {
//        let command = text.lowercased()
//        if command.contains("start recording") {
//            if !self.isRecording {
//                DispatchQueue.main.async {
//                    self.startRecording()
//                }
//            }
//        } else if command.contains("stop recording") {
//            if self.isRecording {
//                DispatchQueue.main.async {
//                    self.stopRecording()
//                }
//            }
//        } else {
//            DispatchQueue.main.async {
//                if !self.voiceCommands.contains(where: { command.contains($0) }) {
//                    self.transcription += text + " "
//                }
//            }
//        }
//    }
    
    private func handleRecognizedText(_ text: String) {
        let command = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Using a switch statement can prepare the structure for easier extension with new commands
        switch command {
        case let cmd where cmd.contains("start recording"):
            DispatchQueue.main.async {
                if !self.isRecording {
                    self.startRecording()
                }
            }
        case let cmd where cmd.contains("stop recording"):
            DispatchQueue.main.async {
                if self.isRecording {
                    self.stopRecording()
                }
            }
        default:
            break
//            // Handle transcription updates outside the main thread if not necessary,
//            // then update the UI or state on the main thread if needed.
//            if !self.voiceCommands.contains(where: { command.contains($0) }) {
//                // Consider adding a mechanism to update transcription less frequently
//                // if updates are very frequent. This is just an example, adjust as needed.
//                self.appendTranscription(text)
//            }
        }
    }

    // Helper function to append text to the transcription safely
    private func appendTranscription(_ text: String) {
        DispatchQueue.main.async {
            self.transcription += text + " "
        }
    }

    

    func startRecording() {
          let videoFilename = NSTemporaryDirectory() + "\(Date()).mov"
          let videoFileURL = URL(fileURLWithPath: videoFilename)
          output.startRecording(to: videoFileURL, recordingDelegate: self)
        print(transcription, "transcription before")

        // Start audio recording
           setupAudioRecorder()
           audioRecorder?.record()
        
          isRecording = true
      }





      func stopRecording() {
          output.stopRecording()
          audioRecorder?.stop()
          isRecording = false
          if self.isWaveformEnabled {
              self.toggleWaveformRecognition() // Assuming this method toggles the state and stops recognition
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
    
    func toggleFlash() {
        guard let currentCameraInput = session.inputs.first as? AVCaptureDeviceInput else {
            print("Unable to identify current camera input")
            return
        }

        let currentCamera = currentCameraInput.device

        guard currentCamera.hasTorch else {
            print("Current camera does not have a torch")
            return
        }

        do {
            try currentCamera.lockForConfiguration()

            if currentCamera.torchMode == .on {
                currentCamera.torchMode = .off
            } else {
                try currentCamera.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            }

            // Update the isFlashOn state based on the current torch mode
            isFlashOn = currentCamera.torchMode == .on

            currentCamera.unlockForConfiguration()
        } catch {
            print("Error toggling flash: \(error)")
            currentCamera.unlockForConfiguration()
        }
    }

    func switchCamera() {
        guard let currentVideoInput = session.inputs.first(where: { $0 is AVCaptureDeviceInput && ($0 as! AVCaptureDeviceInput).device.hasMediaType(.video) }) as? AVCaptureDeviceInput else {
            return
        }

        session.beginConfiguration()
        session.removeInput(currentVideoInput)

        let newCameraPosition: AVCaptureDevice.Position = currentVideoInput.device.position == .back ? .front : .back
        guard let newCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newCameraPosition),
              let newVideoInput = try? AVCaptureDeviceInput(device: newCameraDevice) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(newVideoInput) {
            session.addInput(newVideoInput)
            isFrontCameraUsed = (newCameraPosition == .front)
        }

        // Reconfigure audio input as needed
        reconfigureAudioInput()

        session.commitConfiguration()
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
    func startRecordingNextItem() {
        // Reset the preview URL for the new recording
        self.previewURL = nil

        // Check if the session is already running; if not, start it
        if !session.isRunning {
            session.startRunning()
        }

        // Generate a unique URL for the new recording
        let tempURL = NSTemporaryDirectory() + "item_\(Date().timeIntervalSince1970).mov"
        let outputFileURL = URL(fileURLWithPath: tempURL)

        // Start recording to the new file URL
        output.startRecording(to: outputFileURL, recordingDelegate: self)

    }

   
    
    func reRecordCurrentItem() {
        // If the user is re-recording before confirming the video,
        // we just reset the necessary states for a new recording

        // Reset the preview URL for the new recording
        previewURL = nil

        // Indicate that we are not currently recording
        isRecording = false
        
        print("Preparing to re-record. Current Pod: \(currentPod.items)")

        // Depending on your app's flow, you might need to reset other states as well,
        // such as any flags or timers related to the recording process

        // Optionally, if you want to start the camera for a new recording immediately,
        // you can call a function to start the camera.
        // For instance, if you have a function to setup the camera for recording:
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

    func confirmVideo() {
        guard let videoURL = previewURL else {
            print("No video to confirm.")
            return
        }
        isTranscribing = true

        // Get the URL of the recorded audio
        let audioFilename = getDocumentsDirectory().appendingPathComponent("audioRecording.wav")
        print("Audio file path: \(audioFilename.path)")

        // Check if audio file exists
        if !FileManager.default.fileExists(atPath: audioFilename.path) {
            print("Audio file does not exist.")
        } else {
            print("Audio file found, proceeding with transcription.")
        }

        // Transcribe the audio and then confirm the video
        transcribeAudio(from: audioFilename) { [weak self] transcribedText in
            guard let self = self else { return }
            DispatchQueue.main.async {
                var metadata = transcribedText ?? ""
                metadata = metadata.replacingOccurrences(of: "stop recording", with: "", options: .caseInsensitive)
                print("Transcription result: \(metadata)")

                // Check if the last item in the Pod is the same as the current preview URL
                if self.currentPod.items.last?.videoURL != videoURL {
                    let thumbnail = self.generateThumbnail(for: videoURL, usingFrontCamera: self.isFrontCameraUsed)
                    let newItem = PodItem(id: -1, videoURL: videoURL, metadata: metadata, thumbnail: thumbnail)
                    self.currentPod.items.append(newItem)
//                    print("Item confirmed and added to Pod. Current Pod count: \(self.currentPod.items.count)")
                } else {
                    print("The item is already in the Pod.")
                }

                // Reset the preview URL and hide the preview
                self.isTranscribing = false
                self.showPreview = false
                self.recordedDuration = 0
                // Update the recording state
                self.isRecording = false


            }
        }
    }
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

    func confirmAndNavigateToCreatePod() {
            confirmVideo()
            showCreatePodView = true
        }


    func transcribeAudio(from url: URL, completion: @escaping (String?) -> Void) {
        guard let speechConfig = speechConfig else {
            print("Speech configuration not set up.")
            completion(nil)
            return
        }
        
        do {
            let audioConfig =  SPXAudioConfiguration(wavFileInput: url.path)
            guard let audioConfigUnwrapped = audioConfig else {
                print("Audio configuration could not be created.")
                completion(nil)
                return
            }

            let speechRecognizer = try SPXSpeechRecognizer(speechConfiguration: speechConfig, audioConfiguration: audioConfigUnwrapped)

            try speechRecognizer.recognizeOnceAsync { result in
                if let text = result.text, !text.isEmpty {
                    completion(text)
                } else {
                    completion(nil)
                }
            }
        } catch {
            print("Error setting up speech recognizer: \(error)")
            completion(nil)
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


