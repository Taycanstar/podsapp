//
//  AltCameraView.swift
//  pods
//
//  Created by Dimi Nunez on 2/14/24.
//

import SwiftUI
import AVFoundation

struct AltCameraView: View {
    @EnvironmentObject var cameraModel: CameraViewModel
    var body: some View{
        
        GeometryReader{proxy in
            let size = proxy.size
            
            CameraPreview(size: size)
                .environmentObject(cameraModel)
                .frame(width: size.width, height: size.width * 9 / 16)

        }
        .onAppear(perform: cameraModel.checkPermission)
        .alert(isPresented: $cameraModel.alert) {
            Alert(title: Text("Camera and microphone are required to record videos"))
        }
//        .onReceive(Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()) { _ in
//               if cameraModel.recordedDuration <= cameraModel.maxDuration && cameraModel.isRecording{
//                   cameraModel.recordedDuration += 0.01
//               }
//               
//               if cameraModel.recordedDuration >= cameraModel.maxDuration && cameraModel.isRecording{
//                   // Stopping the Recording
//                   cameraModel.stopRecording()
//                   cameraModel.isRecording = false
//               }
//           }
    }
}

struct CameraPreview: UIViewRepresentable {
    
    @EnvironmentObject var cameraModel : CameraViewModel
    var size: CGSize
    
    func makeUIView(context: Context) ->  UIView {
//     
        let view = UIView()
        
        cameraModel.preview = AVCaptureVideoPreviewLayer(session: cameraModel.session)
        cameraModel.preview.frame.size = size
        
        cameraModel.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(cameraModel.preview)
        
        cameraModel.session.startRunning()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}


#Preview {
    AltCameraView()
}
