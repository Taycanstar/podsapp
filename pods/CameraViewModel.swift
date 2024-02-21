

import SwiftUI
import AVFoundation

import MicrosoftCognitiveServicesSpeech

struct PodItem {
    var videoURL: URL
    var metadata: String
    var thumbnail: UIImage?
}

struct Pod {
    var items: [PodItem] = []
}



// MARK: Camera View Model
class CameraViewModel: NSObject,ObservableObject,AVCaptureFileOutputRecordingDelegate{
    
    // Custom initializer
        override init() {
            super.init()
            configureSpeechService()
            checkPermission()
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
    
    
    // MARK: Video Recorder Properties
    @Published var isRecording: Bool = false
    @Published var recordedURLs: [URL] = []
    @Published var previewURL: URL?
    @Published var showPreview: Bool = false
    
    //MARK: Pod variables
    @Published var currentPod = Pod()
    @Published var isPodRecording: Bool = false
    @Published var isPodFinalized = false

    
    // Top Progress Bar
    @Published var recordedDuration: CGFloat = 0
    // YOUR OWN TIMING
    @Published var maxDuration: CGFloat = 20
    
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
    
    func setUp(){
        
        do{
            self.session.beginConfiguration()
            let cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            let videoInput = try AVCaptureDeviceInput(device: cameraDevice!)
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioInput = try AVCaptureDeviceInput(device: audioDevice!)
            
            // MARK: Audio Input
            
            if self.session.canAddInput(videoInput) && self.session.canAddInput(audioInput){
                self.session.addInput(videoInput)
                self.session.addInput(audioInput)
            }

            if self.session.canAddOutput(self.output){
                self.session.addOutput(self.output)
            }
            
            self.session.commitConfiguration()
        }
        catch{
            print(error.localizedDescription)
        }
    }
    
    func startRecording(){
        // MARK: Temporary URL for recording Video
        let tempURL = NSTemporaryDirectory() + "\(Date()).mov"
        output.startRecording(to: URL(fileURLWithPath: tempURL), recordingDelegate: self)
        isRecording = true
        audioRecorder?.record()
    }
    
    func stopRecording(){
        output.stopRecording()
        isRecording = false
        audioRecorder?.stop()
    }
    
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
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Remove current input
        session.removeInput(currentInput)

        let newCameraPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back

        guard let newCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newCameraPosition),
              let newInput = try? AVCaptureDeviceInput(device: newCameraDevice) else {
            return
        }
        
        isFrontCameraUsed = (newCameraPosition == .front)

        if session.canAddInput(newInput) {
            session.addInput(newInput)
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

    func confirmVideo() {
        guard let videoURL = previewURL else {
            print("No video to confirm.")
            return
        }

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
                let metadata = transcribedText ?? "Transcription failed"
                print("Transcription result: \(metadata)")
                
                // Check if the last item in the Pod is the same as the current preview URL
                if self.currentPod.items.last?.videoURL != videoURL {
                    let thumbnail = self.generateThumbnail(for: videoURL, usingFrontCamera: self.isFrontCameraUsed)
                    let newItem = PodItem(videoURL: videoURL, metadata: metadata, thumbnail: thumbnail)
                    self.currentPod.items.append(newItem)
                    print("Item confirmed and added to Pod. Current Pod count: \(self.currentPod.items.count)")
                } else {
                    print("The item is already in the Pod.")
                }

                // Reset the preview URL and hide the preview
                self.previewURL = nil
                self.showPreview = false

                // Update the recording state
                self.isRecording = false
            }
        }
    }





    
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

 
    var speechConfig: SPXSpeechConfiguration?
    
    func configureSpeechService() {
        if let subscriptionKey = ProcessInfo.processInfo.environment["SPEECH_KEY"],
           let serviceRegion = ProcessInfo.processInfo.environment["SPEECH_REGION"] {
            do {
                speechConfig = try SPXSpeechConfiguration(subscription: subscriptionKey, region: serviceRegion)
                print("Speech service configured successfully with key: \(subscriptionKey) and region: \(serviceRegion)")
            } catch {
                print("Error initializing speech configuration: \(error)")
            }
        } else {
            print("Environment variables for SPEECH_KEY and SPEECH_REGION are not set.")
        }
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
    
    


    

}


