import SwiftUI
import AVFoundation




struct CameraView: UIViewRepresentable {
    var captureAction: () -> Void
    @Binding var isRecording: Bool  // Bind this variable to control recording status
    @Binding var recordingProgress: CGFloat
    let tabBarHeight: CGFloat = 85
    
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        // Adjust the view frame to exclude the tab bar area
        view.frame.size.height -= tabBarHeight
        let coordinator = context.coordinator
      
            

           
        
        // Setup preview layer
        if let captureSession = coordinator.captureSession {
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            coordinator.previewLayer = previewLayer
        } else {
            print("Failed to get capture session from coordinator")
        }

        setupFloatingControls(in: view, coordinator: coordinator)

        // Adding the capture button
        DispatchQueue.main.async {
            let backgroundView = UIView()
            backgroundView.backgroundColor = UIColor.clear
            backgroundView.layer.cornerRadius = 40 // Adjust for larger background view
            backgroundView.layer.borderColor = UIColor.white.cgColor
            backgroundView.layer.borderWidth = 3 // Original thickness
            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(backgroundView)
            backgroundView.isUserInteractionEnabled = true

            NSLayoutConstraint.activate([
                backgroundView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -85),
                backgroundView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                backgroundView.widthAnchor.constraint(equalToConstant: 80), // Increased size for more space
                backgroundView.heightAnchor.constraint(equalToConstant: 80)  // Increased size for more space
            ])

            let button = UIButton(type: .custom)
            button.backgroundColor = UIColor(red: 255/255.0, green: 59/255.0, blue: 48/255.0, alpha: 1.0)
            button.layer.cornerRadius = 34 // Same as original
            button.translatesAutoresizingMaskIntoConstraints = false
            coordinator.captureButton = button
            backgroundView.addSubview(button)
            
            let transparentButton = UIButton(type: .custom)
             transparentButton.backgroundColor = .clear
             transparentButton.translatesAutoresizingMaskIntoConstraints = false
             backgroundView.addSubview(transparentButton)

             NSLayoutConstraint.activate([
                 transparentButton.topAnchor.constraint(equalTo: backgroundView.topAnchor),
                 transparentButton.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),
                 transparentButton.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
                 transparentButton.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor)
             ])

            

            
            
            let gestureTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.toggleRecord))
     
            transparentButton.addGestureRecognizer(gestureTap)

            let gestureLongPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress))
            transparentButton.addGestureRecognizer(gestureLongPress)
           
            
            

            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 68), // Same as original
                button.heightAnchor.constraint(equalToConstant: 68)  // Same as original
            ])
        }


        return view
    }
    
 

    

    




    private func setupFloatingControls(in view: UIView, coordinator: Coordinator) {
        let controlBar = UIStackView()
        controlBar.axis = .vertical
        controlBar.spacing = 15 // Space between icons
        controlBar.distribution = .equalSpacing
        controlBar.isLayoutMarginsRelativeArrangement = true
        controlBar.layoutMargins = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0) // Set padding
        controlBar.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        controlBar.layer.cornerRadius = 25 // Fully rounded corners
        controlBar.translatesAutoresizingMaskIntoConstraints = false
        
        coordinator.controlBar = controlBar
        

        // Flash Button
         let flashButton = UIButton(type: .system)
         flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
         flashButton.tintColor = .white
         flashButton.addTarget(coordinator, action: #selector(Coordinator.toggleFlash), for: .touchUpInside)
         coordinator.flashButton = flashButton

        // Record Button
        let recordButton = UIButton(type: .system)
        recordButton.setImage(UIImage(systemName: "record.circle"), for: .normal)
        recordButton.tintColor = .white
        coordinator.recordButton = recordButton
        // Add target for recordButton if needed

        // Switch Camera Button
        let switchCameraButton = UIButton(type: .system)
        switchCameraButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        switchCameraButton.tintColor = .white
        switchCameraButton.addTarget(coordinator, action: #selector(Coordinator.switchCamera), for: .touchUpInside)
        coordinator.switchCameraButton = switchCameraButton

        [switchCameraButton,flashButton, recordButton].forEach { button in
            controlBar.addArrangedSubview(button)
        }

        view.addSubview(controlBar)

        NSLayoutConstraint.activate([
            controlBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            controlBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            controlBar.widthAnchor.constraint(equalToConstant: 50)
        ])
    }



    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate {
   
        weak var previewLayer: AVCaptureVideoPreviewLayer?
        var parent: CameraView
        var backFacingCamera: AVCaptureDevice?
        var frontFacingCamera: AVCaptureDevice?
        var captureSession: AVCaptureSession?
        var movieFileOutput: AVCaptureMovieFileOutput?
        var isRecording = false
        var flashButton: UIButton?
        var recordButton: UIButton?
        var isFlashOn = false
        var timer: Timer?
        var totalTime = 60.0 // Total recording time in seconds
        var currentTime = 0.0
        var captureButton: UIButton?
        weak var controlBar: UIStackView?
        var switchCameraButton: UIButton?

        init(_ parent: CameraView) {
            self.parent = parent
            super.init()
            findCameraDevices()
            setupCaptureSession()
            
        }

        func setupCaptureSession() {
            captureSession = AVCaptureSession()
            captureSession?.sessionPreset = .high  // Suitable for video recording
            

            guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: frontCamera) else {
                print("Failed to get front camera.")
                return
            }

            if captureSession?.canAddInput(input) ?? false {
                captureSession?.addInput(input)
            }

            movieFileOutput = AVCaptureMovieFileOutput()
            if captureSession?.canAddOutput(movieFileOutput!) ?? false {
                captureSession?.addOutput(movieFileOutput!)
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
        

        @objc func toggleRecord() {
            print("Tap gesture recognized")
            guard let movieFileOutput = self.movieFileOutput else {
                print("Movie file output not initialized")
                return
            }

            if isRecording {
                // Stop recording
                movieFileOutput.stopRecording()
                isRecording = false
                updateButtonAppearance(isRecording: false)
                updateUIForRecordingState(isRecording: false)
            } else {
                // Generate a unique file name using UUID
                let uniqueFileName = "output_" + UUID().uuidString + ".mov"
                let outputPath = NSTemporaryDirectory() + uniqueFileName
                let savePathUrl = URL(fileURLWithPath: outputPath)

                // Delete old video if it exists
                do {
                    if FileManager.default.fileExists(atPath: savePathUrl.path) {
                        try FileManager.default.removeItem(at: savePathUrl)
                    }
                } catch {
                    print("Error deleting existing file: \(error.localizedDescription)")
                }

                // Start recording
                movieFileOutput.startRecording(to: savePathUrl, recordingDelegate: self)
                isRecording = true
                updateButtonAppearance(isRecording: true)
                updateUIForRecordingState(isRecording: true)
            }
        }

//        func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
//            if let error = error {
//                print("Error recording video: \(error.localizedDescription)")
//                print("Error recording video: \(error)")
//            } else {
//                // Post notification or call a method to update UI for video preview
//                NotificationCenter.default.post(name: .didFinishRecordingVideo, object: outputFileURL)
//                // Optionally, preview the video immediately or perform other actions
//                print("success")
//            }
//        }

        func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
            if let error = error {
                print("Error recording video: \(error.localizedDescription)")
                print("Error recording video: \(error)")
            } else {
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let uniqueFileName = "output_" + UUID().uuidString + ".mov"
                let finalURL = documentsDirectory.appendingPathComponent(uniqueFileName)

                // Delete old video if it exists at the final URL
                if fileManager.fileExists(atPath: finalURL.path) {
                    do {
                        try fileManager.removeItem(at: finalURL)
                    } catch {
                        print("Could not delete old recording: \(error.localizedDescription)")
                    }
                }

                // Move recorded video to the final URL
                do {
                    try fileManager.moveItem(at: outputFileURL, to: finalURL)
                    NotificationCenter.default.post(name: .didFinishRecordingVideo, object: finalURL)
                } catch {
                    print("Error moving recorded video: \(error.localizedDescription)")
                }
            }
        }



        
        private func updateUIForRecordingState(isRecording: Bool) {
            flashButton?.isHidden = isRecording
            recordButton?.isHidden = isRecording
            controlBar?.backgroundColor = isRecording ?  UIColor.black.withAlphaComponent(0) : UIColor.black.withAlphaComponent(0.15)
            // The switch camera button stays visible
            switchCameraButton?.isHidden = false
        }



        
        
        @objc func toggleFlash() {
            guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
            
            if device.hasTorch {
                do {
                    try device.lockForConfiguration()
                    
                    if isFlashOn {
                        // If the flash is currently on, turn it off
                        device.torchMode = .off
                        isFlashOn = false
                    } else {
                        // If the flash is currently off, turn it on
                        try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                        isFlashOn = true
                    }

                    device.unlockForConfiguration()
                } catch {
                    print("Torch could not be used: \(error)")
                }
            } else {
                print("Torch is not available")
            }

            // Update the flash button icon
            let iconName = isFlashOn ? "bolt.fill" : "bolt.slash.fill"
            DispatchQueue.main.async {
                self.flashButton?.setImage(UIImage(systemName: iconName), for: .normal)
            }
        }
       
         

        
        @objc func handleLongPress(gesture: UILongPressGestureRecognizer) {
            print("Long press state: \(gesture.state.rawValue)") // Log the gesture state
            switch gesture.state {
            case .began:
                print("Long press began, starting recording")
                toggleRecord()
            case .ended:
                print("Long press ended, stopping recording")
                toggleRecord()
            default:
                break
            }
        }


        private func updateButtonAppearance(isRecording: Bool) {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3, animations: {
                    if isRecording {
                        self.captureButton?.layer.cornerRadius = 15 // Rounded corners for smaller square
                        self.captureButton?.backgroundColor = UIColor(red: 255/255.0, green: 59/255.0, blue: 48/255.0, alpha: 1.0) // Original color
                        self.captureButton?.transform = CGAffineTransform(scaleX: 0.5, y: 0.5) // Shrink the button
                    } else {
                        self.captureButton?.layer.cornerRadius = 34 // Original corner radius
                        self.captureButton?.backgroundColor = UIColor(red: 255/255.0, green: 59/255.0, blue: 48/255.0, alpha: 1.0) // Original color
                        self.captureButton?.transform = CGAffineTransform.identity // Reset to original size
                    }
                })
            }
        }



        
       

        @objc func switchCamera(_ uiView: UIView) {
            print("Switch camera tapped")

            guard let captureSession = self.captureSession else {
                print("Capture session is not initialized")
                return
            }

            guard let backFacingCamera = backFacingCamera, let frontFacingCamera = frontFacingCamera else {
                print("One or both cameras are unavailable")
                return
            }

            captureSession.beginConfiguration()

            guard let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else {
                print("No current input to remove")
                captureSession.commitConfiguration()
                return
            }

            print("Current camera: \(currentInput.device.position == .front ? "Front" : "Back")")

            captureSession.removeInput(currentInput)

            let newCameraDevice = (currentInput.device.position == .front) ? backFacingCamera : frontFacingCamera
            do {
                let newInput = try AVCaptureDeviceInput(device: newCameraDevice)
                if captureSession.canAddInput(newInput) {
                    captureSession.addInput(newInput)
                    print("Switched camera to: \(newCameraDevice.position == .front ? "Front" : "Back")")
                } else {
                    print("Could not add input for new camera")
                    captureSession.commitConfiguration()
                    return
                }
            } catch {
                print("Failed to create input for new camera: \(error)")
                captureSession.commitConfiguration()
                return
            }

            captureSession.commitConfiguration()

            DispatchQueue.main.async {
                self.previewLayer?.session = captureSession
                
            }

            DispatchQueue.global(qos: .userInitiated).async {
                if !captureSession.isRunning {
                    captureSession.startRunning()
                }
            }

        }

        func findCameraDevices() {
            let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                           mediaType: .video,
                                                           position: .unspecified).devices

            for device in devices {
                if device.position == .back {
                    backFacingCamera = device
                } else if device.position == .front {
                    frontFacingCamera = device
                }
            }

            // Ensure that both cameras are found
            if backFacingCamera == nil || frontFacingCamera == nil {
                print("Failed to find one or both cameras.")
                return
            }
        }


    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
//        if let previewLayer = context.coordinator.previewLayer {
//            previewLayer.frame = uiView.bounds
//        }
    }

}

extension Notification.Name {
    static let didFinishRecordingVideo = Notification.Name("didFinishRecordingVideo")
}


struct CameraViewContainer: View {
    @State private var isRecording = false
       @State private var recordingProgress: CGFloat = 0.0
    @State private var showVideoPreview = false
    @State private var recordedVideoURL: URL?
    var body: some View {
           ZStack {
               CameraView(captureAction: { /* ... */ }, isRecording: $isRecording, recordingProgress: $recordingProgress)
                   .onReceive(NotificationCenter.default.publisher(for: .didFinishRecordingVideo)) { notification in
                                  if let url = notification.object as? URL {
                                      self.recordedVideoURL = url
                                      self.showVideoPreview = true
                                  }
                              }

                          if showVideoPreview, let videoURL = recordedVideoURL {
                              VideoPreviewView(videoURL: videoURL, showPreview: $showVideoPreview)
                          }

           }
       }
}



struct CameraViewContainer_Previews: PreviewProvider {
    static var previews: some View {
        CameraViewContainer()
    }
}

