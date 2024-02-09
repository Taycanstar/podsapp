import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    var captureAction: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)

        setupCameraSession(in: view, coordinator: context.coordinator)
        setupFloatingControls(in: view, coordinator: context.coordinator)

        // Adding the capture button
        DispatchQueue.main.async {
            let backgroundView = UIView()
            backgroundView.backgroundColor = UIColor.clear
            backgroundView.layer.cornerRadius = 35
            backgroundView.layer.borderColor = UIColor.white.cgColor
            backgroundView.layer.borderWidth = 3
            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(backgroundView)

            NSLayoutConstraint.activate([
                backgroundView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -95),
                backgroundView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                backgroundView.widthAnchor.constraint(equalToConstant: 70),
                backgroundView.heightAnchor.constraint(equalToConstant: 70)
            ])

            let button = UIButton(type: .custom)
            button.backgroundColor = UIColor.white.withAlphaComponent(1)
            button.layer.cornerRadius = 30
            button.addTarget(context.coordinator, action: #selector(Coordinator.captureTapped), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            backgroundView.addSubview(button)

            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 60),
                button.heightAnchor.constraint(equalToConstant: 60)
            ])
        }

        return view
    }
    
    

    private func setupCameraSession(in view: UIView, coordinator: Coordinator) {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        
        

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            print("Failed to create video device/input")
            return
        }

        captureSession.addInput(videoInput)

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        let videoOutput = AVCaptureVideoDataOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(coordinator, queue: DispatchQueue(label: "cameraQueue"))
        } else {
            print("Could not add video output")
        }

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
        
        var parent: CameraView
        var backFacingCamera: AVCaptureDevice?
        var frontFacingCamera: AVCaptureDevice?
        var captureSession: AVCaptureSession?
        var movieFileOutput: AVCaptureMovieFileOutput?
          var isRecording = false
        var photoOutput = AVCapturePhotoOutput()
        var flashButton: UIButton?
          var isFlashOn = false
//        weak var flashButton: UIButton?

        init(_ parent: CameraView, captureSession: AVCaptureSession? = nil) {
            self.parent = parent
            self.captureSession = captureSession
            super.init() // Call super.init after all properties are initialized
                findCameraDevices()
            
            if let captureSession = captureSession, !captureSession.outputs.contains(where: { $0 is AVCapturePhotoOutput }) {
                       if captureSession.canAddOutput(photoOutput) {
                           captureSession.addOutput(photoOutput)
                       }
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
        
        // AVCapturePhotoCaptureDelegate methods
           func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
               guard photo.fileDataRepresentation() != nil else { return }
               // Use imageData (e.g., save to photo library, display in the app, etc.)
           }

        
        @objc func switchCamera() {
            guard let captureSession = self.captureSession else {
                print("Capture session is not initialized")
                return
            }

            guard let currentCameraInput = captureSession.inputs.first as? AVCaptureDeviceInput else { return }
            
            captureSession.beginConfiguration()
            captureSession.removeInput(currentCameraInput)

            let newCameraDevice: AVCaptureDevice?
            if currentCameraInput.device.position == .back {
                newCameraDevice = frontFacingCamera
            } else {
                newCameraDevice = backFacingCamera
            }

            guard let newCamera = newCameraDevice, let newVideoInput = try? AVCaptureDeviceInput(device: newCamera) else {
                print("Failed to create video input")
                captureSession.commitConfiguration()
                return
            }

            if captureSession.canAddInput(newVideoInput) {
                captureSession.addInput(newVideoInput)
            } else {
                print("Could not add video input")
            }

            captureSession.commitConfiguration()
        }

//
//        @objc func captureTapped() {
//            parent.captureAction()
//        }

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
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct CameraViewContainer: View {
    var body: some View {
        CameraView {
            print("Capture button tapped")
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct CameraViewContainer_Previews: PreviewProvider {
    static var previews: some View {
        CameraViewContainer()
    }
}

