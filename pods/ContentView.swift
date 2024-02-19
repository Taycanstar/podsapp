//
//  ContentView.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//
import AVFoundation
import SwiftUI

struct CurvedTopShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Draw a path with curved top corners
        path.move(to: CGPoint(x: 0, y: cornerRadius))
        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
        path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: Angle(degrees: 270), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}




struct ContentView: View {
    @State private var selectedTab: Int = 0
    @State private var isCameraActive: Bool = false
    @State private var isRecording = false
    @State private var showVideoPreview = false
    @State private var recordedVideoURL: URL?
    

    var body: some View {
        
        ZStack(alignment: .bottom) {
            // Content views
            Group {
                switch selectedTab {
                case 0:
                    HomeView()
                  
                case 1:

                    CameraContainerView()
                        .mask(CurvedTopShape(cornerRadius: 18))
                        .onAppear { isCameraActive = true }
                        .onDisappear { isCameraActive = false }
                        .background(Color.black.edgesIgnoringSafeArea(.top))
                        .padding(.bottom, 45)
                case 2:
                    ProfileView() // Assuming you have a ProfileView
                default:
                    Text("Content not available")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
                      CustomTabBar(selectedTab: $selectedTab)
                          .edgesIgnoringSafeArea(.bottom)
        }
        .environment(\.colorScheme, isCameraActive ? .dark : .light)
    }
}

#Preview {
    ContentView()
}
