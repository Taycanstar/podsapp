//
//  ContentView.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//
import AVFoundation
import SwiftUI

//// For an iOS app in Swift
import MicrosoftCognitiveServicesSpeech



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
    @State private var isRecording = false
    @State private var showVideoPreview = false
    @State private var recordedVideoURL: URL?
    @State private var isAuthenticated = false // Track authentication status
    
    var body: some View {
        Group {
            if isAuthenticated {
                // User is authenticated, show main content
                ZStack(alignment: .bottom) {
                    // Content views
                    Group {
                        switch selectedTab {
                        case 0:
                            HomeView()
                        case 1:
                            CameraContainerView()
                                .background(Color.black.edgesIgnoringSafeArea(.top))
                                .padding(.bottom, 46)
                                .environment(\.colorScheme, .dark)
                        case 2:
                            ProfileView() // Assuming you have a ProfileView
                        default:
                            Text("Content not available")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Custom tab bar
                    CustomTabBar(selectedTab: $selectedTab)
                }
            } else {
                // User is not authenticated, show the landing/authentication view
                LandingView(isAuthenticated: $isAuthenticated)
            }
        }
    }
}

#Preview {
    ContentView()
}
