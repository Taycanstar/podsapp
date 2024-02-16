

import SwiftUI
import AVFoundation

struct PodItem {
    var videoURL: URL
    var metadata: String
}

struct Pod {
    var items: [PodItem] = []
}



// MARK: Camera View Model
class CameraViewModel: NSObject,ObservableObject,AVCaptureFileOutputRecordingDelegate{
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCaptureMovieFileOutput()
    @Published var preview : AVCaptureVideoPreviewLayer!
    
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
    }
    
    func stopRecording(){
        output.stopRecording()
        isRecording = false
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
    
    func confirmVideo(metadata: String = "Default Metadata") {
        if let url = previewURL {
            // Create a new Pod item with the recorded video URL and metadata
            let newItem = PodItem(videoURL: url, metadata: metadata)
            
            // Add the new item to the existing currentPod
            currentPod.items.append(newItem)
            print("Item confirmed. Current Pod: \(currentPod.items)")

            // Reset the preview URL for the next recording
            previewURL = nil
        }

        // Check if the Pod is now non-empty (this might be always true after adding the first item)
        isPodRecording = !currentPod.items.isEmpty

        // Optionally, if your app design requires to start recording the next item immediately,
        // you can call startRecordingNextItem() here.
        // startRecordingNextItem()
    }

    func confirmAndProceedToNextVideo() {
        // Confirm the current video
        confirmVideo()

        // Proceed to record the next item
        startRecordingNextItem()
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

    func confirmP(metadata: String = "Default Metadata") {
        if let url = previewURL {
            // Create a new Pod item with the recorded video URL and metadata
            let newItem = PodItem(videoURL: url, metadata: metadata)
            
            // Add the new item to the existing currentPod
            currentPod.items.append(newItem)
            print("Item confirmed. Current Pod: \(currentPod.items.count)")

            // Reset the preview URL
            previewURL = nil
            
            showPreview = false
            
            // Update the recording state
            isRecording = false
        }
    }




    

}


