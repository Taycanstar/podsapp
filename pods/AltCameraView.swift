//
//  AltCameraView.swift
//  pods
//
//  Created by Dimi Nunez on 2/14/24.
//

import SwiftUI
import AVFoundation
import UIKit

struct AltCameraView: View {
    @EnvironmentObject var cameraModel: CameraViewModel

    
    var body: some View{
        
        GeometryReader{proxy in
            let size = proxy.size
//            ZStack {
                CameraPreview(size: size)
                
                    .environmentObject(cameraModel)
                    .frame(width: size.width, height: size.height * 0.75)
//            }
            


        }
        .onAppear(perform: cameraModel.checkPermission)
        .alert(isPresented: $cameraModel.alert) {
            Alert(title: Text("Camera and microphone are required to record videos"))
        }

    }
}

//struct CameraPreview: UIViewRepresentable {
//    
//    @EnvironmentObject var cameraModel : CameraViewModel
//    var size: CGSize
//    
//    func makeUIView(context: Context) ->  UIView {
////     
//        let view = UIView()
//        
//        cameraModel.preview = AVCaptureVideoPreviewLayer(session: cameraModel.session)
//        cameraModel.preview.frame.size = size
//        
//        cameraModel.preview.videoGravity = .resizeAspectFill
//        view.layer.addSublayer(cameraModel.preview)
//        
//        cameraModel.session.startRunning()
//        
//        return view
//    }
//    
//    func updateUIView(_ uiView: UIView, context: Context) {
//        
//    }
//}





//
struct CameraPreview: UIViewRepresentable {
    
    @EnvironmentObject var cameraModel: CameraViewModel
    var size: CGSize
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        // Set up the preview layer
        cameraModel.preview = AVCaptureVideoPreviewLayer(session: cameraModel.session)
        cameraModel.preview.frame.size = size
        cameraModel.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(cameraModel.preview)
        
        // Add pinch gesture recognizer
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinchGestureRecognizer)
        
        cameraModel.session.startRunning()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        cameraModel.preview.frame = CGRect(origin: .zero, size: size) 
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: CameraPreview
        
        init(_ parent: CameraPreview) {
            self.parent = parent
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .changed:
                parent.cameraModel.zoom(factor: gesture.scale)
            case .ended:
                parent.cameraModel.finalizeZoom(factor: gesture.scale)
            default:
                break
            }
        }
    }
}



#Preview {
    AltCameraView()
}
