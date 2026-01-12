//
//  SimpleCameraView.swift
//  pods
//
//  Created by Dimi Nunez on 1/11/26.
//


//
//  SimpleCameraView.swift
//  pods
//
//  Created by Claude on 1/11/26.
//

import SwiftUI
import AVFoundation
import UIKit

/// Simple camera view for capturing photos to attach to agent chat
struct SimpleCameraView: View {
    @Environment(\.dismiss) private var dismiss
    var onPhotoCaptured: (UIImage) -> Void

    @State private var capturedImage: UIImage?
    @State private var showPreview = false
    @State private var cameraPermissionDenied = false

    var body: some View {
        ZStack {
            if cameraPermissionDenied {
                permissionDeniedView
            } else if showPreview, let image = capturedImage {
                previewView(image: image)
            } else {
                cameraView
            }
        }
        .ignoresSafeArea()
        .onAppear {
            checkCameraPermission()
        }
    }

    private var cameraView: some View {
        ZStack {
            SimpleCameraPreview(onPhotoCaptured: { image in
                capturedImage = image
                showPreview = true
            })

            VStack {
                // Top bar with close button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 16)

                    Spacer()
                }
                .padding(.top, 60)

                Spacer()

                // Bottom capture button
                HStack {
                    Spacer()

                    Button {
                        NotificationCenter.default.post(name: .simpleCameraCapture, object: nil)
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                        }
                    }

                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color.black)
    }

    private func previewView(image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()

            VStack {
                Spacer()

                HStack(spacing: 40) {
                    // Retake button
                    Button {
                        capturedImage = nil
                        showPreview = false
                    } label: {
                        Text("Retake")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                    }

                    // Use photo button
                    Button {
                        onPhotoCaptured(image)
                        dismiss()
                    } label: {
                        Text("Use Photo")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .background(Color.black)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Camera Access Required")
                .font(.title2.weight(.semibold))

            Text("Please enable camera access in Settings to take photos.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.top, 10)

            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.secondary)
        }
        .background(Color(.systemBackground))
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if !granted {
                        cameraPermissionDenied = true
                    }
                }
            }
        default:
            cameraPermissionDenied = true
        }
    }
}

// MARK: - Camera Preview

private struct SimpleCameraPreview: UIViewControllerRepresentable {
    var onPhotoCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> SimpleCameraViewController {
        let controller = SimpleCameraViewController()
        controller.onPhotoCaptured = onPhotoCaptured
        return controller
    }

    func updateUIViewController(_ uiViewController: SimpleCameraViewController, context: Context) {}
}

private class SimpleCameraViewController: UIViewController {
    var onPhotoCaptured: ((UIImage) -> Void)?

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(capturePhoto),
            name: .simpleCameraCapture,
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        self.captureSession = session
        self.photoOutput = output
        self.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
}

extension SimpleCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }

        DispatchQueue.main.async {
            self.onPhotoCaptured?(image)
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let simpleCameraCapture = Notification.Name("simpleCameraCapture")
}
