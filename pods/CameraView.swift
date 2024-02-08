import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    var captureAction: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            print("Failed to create video device/input")
            return view
        }

        captureSession.addInput(videoInput)

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        previewLayer.frame = UIScreen.main.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        let videoOutput = AVCaptureVideoDataOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(context.coordinator as? AVCaptureVideoDataOutputSampleBufferDelegate, queue: DispatchQueue(label: "cameraQueue"))
        } else {
            print("Could not add video output")
        }

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }

        // Adding the capture button
        DispatchQueue.main.async {
            let backgroundView = UIView()
            backgroundView.backgroundColor = UIColor.clear // Clear background for the ring
            backgroundView.layer.cornerRadius = 35 // Half of width and height
            backgroundView.layer.borderColor = UIColor.white.cgColor // White ring color
            backgroundView.layer.borderWidth = 3 // Thickness of the ring
            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(backgroundView)

            NSLayoutConstraint.activate([
                backgroundView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -95),
                backgroundView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                backgroundView.widthAnchor.constraint(equalToConstant: 70), // Total diameter of the ring
                backgroundView.heightAnchor.constraint(equalToConstant: 70)
            ])

            let button = UIButton(type: .custom)
            button.backgroundColor = UIColor.white.withAlphaComponent(1) // Solid white button
            button.layer.cornerRadius = 30 // Making the button slightly smaller than the ring
            button.addTarget(context.coordinator, action: #selector(Coordinator.captureTapped), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            backgroundView.addSubview(button)

            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 60), // Slightly smaller than the background ring
                button.heightAnchor.constraint(equalToConstant: 60)
            ])
        }
        return view
    }

    class Coordinator: NSObject {
        var parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        @objc func captureTapped() {
            parent.captureAction()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct CameraViewContainer: View {
    var body: some View {
        GeometryReader { geometry in
                   CameraView {
                       // Implement capture functionality here
                       print("Capture button tapped")
                   }
                   .frame(width: geometry.size.width, height: geometry.size.height)
                   .edgesIgnoringSafeArea(.all)
               }
     
    }
}

struct CameraViewContainer_Previews: PreviewProvider {
    static var previews: some View {
        CameraViewContainer()
    }
}
