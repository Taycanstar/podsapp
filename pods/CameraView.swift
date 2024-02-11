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

        setupCameraSession(in: view, coordinator: context.coordinator)

        
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

            NSLayoutConstraint.activate([
                backgroundView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -85),
                backgroundView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                backgroundView.widthAnchor.constraint(equalToConstant: 80), // Increased size for more space
                backgroundView.heightAnchor.constraint(equalToConstant: 80)  // Increased size for more space
            ])

            let button = UIButton(type: .custom)
            button.backgroundColor = UIColor(red: 255/255.0, green: 59/255.0, blue: 48/255.0, alpha: 1.0)
            button.layer.cornerRadius = 34 // Same as original
            button.addTarget(context.coordinator, action: #selector(Coordinator.captureTapped), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            backgroundView.addSubview(button)

            let gestureTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.captureTapped))
            button.addGestureRecognizer(gestureTap)

            let gestureLongPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress))
            button.addGestureRecognizer(gestureLongPress)

            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 68), // Same as original
                button.heightAnchor.constraint(equalToConstant: 68)  // Same as original
            ])
        }


        return view
    }
    
    

    private func setupCameraSession(in view: UIView, coordinator: Coordinator) {
        let captureSession = AVCaptureSession()
//        captureSession.sessionPreset = .photo
        captureSession.sessionPreset = .high

        // Find the front camera
//        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
//              let frontCameraInput = try? AVCaptureDeviceInput(device: frontCamera),
//              
//                
//              captureSession.canAddInput(frontCameraInput) else {
//            print("Failed to create front camera input")
//            return
//        }
        // Add the front camera input to the session
//        captureSession.addInput(frontCameraInput)
        
        // Find the front camera
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Failed to find front camera")
            return
        }
        
        print("Using camera with device type: \(frontCamera.deviceType.rawValue), position: \(frontCamera.position.rawValue)")

        do {
            let frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            // Adjust the zoom factor here
            try frontCamera.lockForConfiguration()
            frontCamera.videoZoomFactor = 1 // Adjust this value as needed
            frontCamera.unlockForConfiguration()

            print("Default videoZoomFactor: \(frontCamera.videoZoomFactor)")
            print("Field of View: \(frontCamera.activeFormat.videoFieldOfView)")

            // Add the front camera input to the session
            if captureSession.canAddInput(frontCameraInput) {
                captureSession.addInput(frontCameraInput)
            }
        } catch {
            print("Failed to create front camera input or adjust zoom: \(error)")
            return
        }




        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Setup video output
        let videoOutput = AVCaptureVideoDataOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(coordinator, queue: DispatchQueue(label: "cameraQueue"))
        } else {
            print("Could not add video output")
        }

        // Start the session
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
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
        // Add target for recordButton if needed

        // Switch Camera Button
        let switchCameraButton = UIButton(type: .system)
        switchCameraButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        switchCameraButton.tintColor = .white
        switchCameraButton.addTarget(coordinator, action: #selector(Coordinator.switchCamera), for: .touchUpInside)


        [flashButton, recordButton, switchCameraButton].forEach { button in
            controlBar.addArrangedSubview(button)
        }

        view.addSubview(controlBar)

        NSLayoutConstraint.activate([
            controlBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            controlBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            controlBar.widthAnchor.constraint(equalToConstant: 50)
        ])
    }


    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate, AVCapturePhotoCaptureDelegate  {
        func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
            if let error = error {
                // An error occurred while recording the video
                print("Error recording video: \(error.localizedDescription)")
                return
            }

            // Assuming you want to save the video to the Photos library
            UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)

            print("Video recording finished, file saved to: \(outputFileURL)")
        }
        weak var previewLayer: AVCaptureVideoPreviewLayer?
        var parent: CameraView
        var backFacingCamera: AVCaptureDevice?
        var frontFacingCamera: AVCaptureDevice?
        var captureSession: AVCaptureSession?
        var movieFileOutput: AVCaptureMovieFileOutput?
        var isRecording = false
        var photoOutput = AVCapturePhotoOutput()
        var flashButton: UIButton?
        var isFlashOn = false
        var timer: Timer?
        var totalTime = 60.0 // Total recording time in seconds
        var currentTime = 0.0


        init(_ parent: CameraView) {
            self.parent = parent
            super.init()
            self.captureSession = AVCaptureSession()
            findCameraDevices()
            setupCaptureSession()
            
        }

        
        func setupCaptureSession() {
            guard let captureSession = self.captureSession else {
                       print("Capture session could not be created")
                       return
                   }

            // Check and add the front camera as the initial input
            if let frontCamera = frontFacingCamera {
                do {
                    let input = try AVCaptureDeviceInput(device: frontCamera)
                    if captureSession.canAddInput(input) {
                        captureSession.addInput(input)
                    }
                } catch {
                    print("Error setting up front camera input: \(error)")
                }
            }

            // Add photo output
            if !captureSession.outputs.contains(where: { $0 is AVCapturePhotoOutput }) {
                if captureSession.canAddOutput(photoOutput) {
                    captureSession.addOutput(photoOutput)
                }
            }

            // Start the session
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
            
        
        }

        @objc func toggleRecord() {
                guard let captureSession = captureSession else {
                    print("Capture session is not initialized")
                    return
                }

                if movieFileOutput == nil {
                    // Initialize and add movieFileOutput to the capture session if not done already
                    movieFileOutput = AVCaptureMovieFileOutput()
                    if captureSession.canAddOutput(movieFileOutput!) {
                        captureSession.addOutput(movieFileOutput!)
                    }
                }

                if isRecording {
                    // Stop recording
                    movieFileOutput?.stopRecording()
                    isRecording = false
                } else {
                    // Start recording
                    let outputPath = NSTemporaryDirectory() + "output.mov"
                    let outputFileURL = URL(fileURLWithPath: outputPath)
                    movieFileOutput?.startRecording(to: outputFileURL, recordingDelegate: self)
                    isRecording = true
                }
            }
        
        
      
        @objc func toggleFlash() {
            isFlashOn.toggle() // Toggle the flash state

            // Update the flash button icon
            let iconName = isFlashOn ? "bolt.fill" : "bolt.slash.fill"
            DispatchQueue.main.async {
                self.flashButton?.setImage(UIImage(systemName: iconName), for: .normal)
            }
        }


     
        
       
        
        @objc func captureTapped() {
              let settings: AVCapturePhotoSettings
              if isFlashOn {
                  settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                  settings.flashMode = .on
              } else {
                  settings = AVCapturePhotoSettings()
                  settings.flashMode = .off
              }
              
              photoOutput.capturePhoto(with: settings, delegate: self)
          }
        
       func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard let imageData = photo.fileDataRepresentation() else { return }
            // Handle the captured image (e.g., show a preview, save to photo album)
        }
       
          @objc func handleLongPress(gesture: UILongPressGestureRecognizer) {
              if gesture.state == .began {
                  // Start recording
                  startRecording()
              } else if gesture.state == .ended {
                  // Stop recording
                  stopRecording()
              }
          }

        func startRecording() {
            timer?.invalidate()
                   currentTime = 0.0

            // Start the timer
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.currentTime += 1.0

                // Provide a default value for totalTime in case self is nil
                let totalTime = self?.totalTime ?? 60.0 // Default to 60 seconds

                if self?.currentTime ?? 0 >= totalTime {
                    self?.stopRecording()
                }

                // Update the progress
                DispatchQueue.main.async {
                    // Unwrap currentTime safely, defaulting to 0 if nil
                    let currentProgress = self?.currentTime ?? 0
                    self?.parent.recordingProgress = CGFloat(currentProgress / totalTime)
                }
            }


            guard let movieFileOutput = self.movieFileOutput else { return }

            let outputPath = NSTemporaryDirectory() + "output.mov"
            let outputFileURL = URL(fileURLWithPath: outputPath)
            movieFileOutput.startRecording(to: outputFileURL, recordingDelegate: self)

            parent.isRecording = true
            // Start a timer to update recordingProgress
            // Example timer (adjust according to your needs)
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                self.parent.recordingProgress += 0.01
                if self.parent.recordingProgress >= 1.0 {
                    timer.invalidate()
                    self.stopRecording()
                }
            }
        }

        func stopRecording() {
            timer?.invalidate()
            movieFileOutput?.stopRecording()
            parent.isRecording = false
            parent.recordingProgress = 0.0
            // Stop the timer if you have started one
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




        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // Handle frame capture
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

struct CameraViewContainer: View {
    @State private var isRecording = false
       @State private var recordingProgress: CGFloat = 0.0
    var body: some View {
           ZStack {
               CameraView(captureAction: { /* ... */ }, isRecording: $isRecording, recordingProgress: $recordingProgress)

               if isRecording {
                   CircularProgressView(progress: recordingProgress)
                       .frame(width: 100, height: 100)
                       .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
               }
           }
       }
}



struct CameraViewContainer_Previews: PreviewProvider {
    static var previews: some View {
        CameraViewContainer()
    }
}

struct CircularProgressView: View {
    var progress: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90)) // Start from top
                .animation(.linear, value: progress)
        }
    }
}
