import SwiftUI
import AVFoundation




struct CameraView: UIViewRepresentable {
    
    
   
    @Binding var isRecording: Bool  // Bind this variable to control recording status
   
//    let tabBarHeight: CGFloat = 85
    
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        // Adjust the view frame to exclude the tab bar area
//        view.frame.size.height -= tabBarHeight
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



    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
   
        weak var previewLayer: AVCaptureVideoPreviewLayer?
        var parent: CameraView
        var backFacingCamera: AVCaptureDevice?
        var frontFacingCamera: AVCaptureDevice?
        var captureSession: AVCaptureSession?
        var movieFileOutput: AVCaptureVideoDataOutput?
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
        @Published var alert = false
        var assetWriter: AVAssetWriter?
         var assetWriterInput: AVAssetWriterInput?
         var videoDataOutput: AVCaptureVideoDataOutput?


        init(_ parent: CameraView) {
            self.parent = parent
            super.init()
            findCameraDevices()
            setupCaptureSession()
            
        }
        
        func checkPermission(){
            
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                setupCaptureSession()
                return
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { (status) in
                    
                    if status{
                        self.setupCaptureSession()
                    }
                }
            case .denied:
                self.alert.toggle()
                return
            default:
                return
            }
        }

        func setupCaptureSession() {
            captureSession = AVCaptureSession()
            captureSession?.sessionPreset = AVCaptureSession.Preset.high  // Or use a specific preset like .hd1920x1080

            // Prepare for both front and back cameras
            setupCameraInput(position: .front)
            setupCameraInput(position: .back)

            // Setup Video Data Output
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

            var videoSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            // Additional keys for iOS 16 and later
            if #available(iOS 16.0, *) {
                videoSettings[AVVideoColorPropertiesKey] = [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
                ]
            }

            videoDataOutput.videoSettings = videoSettings

            if captureSession?.canAddOutput(videoDataOutput) ?? false {
                captureSession?.addOutput(videoDataOutput)
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }


        private func setupCameraInput(position: AVCaptureDevice.Position) {
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  captureSession?.canAddInput(input) ?? false else {
                print("Failed to get camera for position: \(position)")
                return
            }
            captureSession?.addInput(input)
        }

        func startRecording() {
            let uniqueFileName = "output_" + UUID().uuidString + ".mov"
            let outputPath = NSTemporaryDirectory() + uniqueFileName
            let outputURL = URL(fileURLWithPath: outputPath)

            do {
                assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

                // Make sure the settings match the video data being captured
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 1920,   // Adjust if necessary
                    AVVideoHeightKey: 1080   // Adjust if necessary
                ]

                assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                assetWriterInput?.expectsMediaDataInRealTime = true

                if assetWriter?.canAdd(assetWriterInput!) ?? false {
                    assetWriter?.add(assetWriterInput!)
                }

                assetWriter?.startWriting()
                assetWriter?.startSession(atSourceTime: CMTime.zero)
            } catch {
                print("Error setting up asset writer: \(error)")
            }
        }


        func stopRecording() {
            assetWriterInput?.markAsFinished()
            assetWriter?.finishWriting { [weak self] in
                guard let self = self else { return }
                
                if let error = self.assetWriter?.error {
                    print("Error finishing writing: \(error)")
                } else {
                    if let outputURL = self.assetWriter?.outputURL {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .didFinishRecordingVideo, object: outputURL)
                        }
                    } else {
                        print("Error: Output URL is nil")
                    }
                }
                self.assetWriter = nil
                self.assetWriterInput = nil
            }
        }





        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard isRecording,
                  let assetWriterInput = assetWriterInput,
                  assetWriterInput.isReadyForMoreMediaData,
                  CMSampleBufferDataIsReady(sampleBuffer) else {
                print("Recording not started or sample buffer not ready")
                return
            }

            if !assetWriterInput.append(sampleBuffer) {
                print("Failed to append sample buffer: \(String(describing: assetWriter?.error))")
            } else {
                print("Sample buffer appended successfully.")
            }
        }
        




        
        
        @objc func toggleRecord() {
            print("Toggle Record: Current state isRecording = \(isRecording)")

            if isRecording {
                print("Stopping recording...")
                stopRecording()
                isRecording = false
                updateButtonAppearance(isRecording: false)
                updateUIForRecordingState(isRecording: false)
            } else {
                print("Starting recording...")
                startRecording()
                isRecording = true
                updateButtonAppearance(isRecording: true)
                updateUIForRecordingState(isRecording: true)
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
    @State private var showVideoPreview = false
    @State private var recordedVideoURL: URL?

    var body: some View {
        ZStack {
            // In your CameraViewContainer or another visible SwiftUI view
       
     
            CameraView(isRecording: $isRecording)
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

