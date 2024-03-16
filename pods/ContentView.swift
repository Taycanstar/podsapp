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



//struct CurvedTopShape: Shape {
//    var cornerRadius: CGFloat
//
//    func path(in rect: CGRect) -> Path {
//        var path = Path()
//
//        // Draw a path with curved top corners
//        path.move(to: CGPoint(x: 0, y: cornerRadius))
//        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
//        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
//        path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: Angle(degrees: 270), endAngle: Angle(degrees: 0), clockwise: false)
//        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
//        path.addLine(to: CGPoint(x: 0, y: rect.height))
//        path.closeSubpath()
//
//        return path
//    }
//}




//
//struct ContentView: View {
//    @State private var selectedTab: Int = 0
//    @State private var isRecording = false
//    @State private var showVideoPreview = false
//    @State private var recordedVideoURL: URL?
//    @State private var isAuthenticated = true // Track authentication status
//    @State private var shouldNavigateToHome = false
//
//    
//    var body: some View {
//        Group {
//            if isAuthenticated {
//                // User is authenticated, show main content
//                ZStack(alignment: .bottom) {
//                    // Content views
//                    Group {
//                        switch selectedTab {
//                        case 0:
//                            HomeView()
//                        case 1:
//                            CameraContainerView(shouldNavigateToHome: $shouldNavigateToHome)
////                                .background(Color.black.edgesIgnoringSafeArea(.top))
//                               
////                                .padding(.bottom, 46)
////                                .edgesIgnoringSafeArea(.all)
//                                .environment(\.colorScheme, .dark)
//                        case 2:
//                            ProfileView() // Assuming you have a ProfileView
//                        default:
//                            Text("Content not available")
//                        }
//                            
//
//                    }
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .onChange(of: shouldNavigateToHome) { [shouldNavigateToHome] in
//                        if shouldNavigateToHome {
//                            selectedTab = 0 // Assuming HomeView is at index 0
//                            self.shouldNavigateToHome = false // Reset the flag
//                        }
//                    }
//
//                    // Custom tab bar
//                    CustomTabBar(selectedTab: $selectedTab)
//                }
//            } else {
//                // User is not authenticated, show the landing/authentication view
//                MainOnboardingView(isAuthenticated:$isAuthenticated)
////                EmptyView()
//                    
//            }
//        }
//    }
//}
//
//#Preview {
//    ContentView()
//}


struct ContentView: View {
    @State private var selectedTab = 0
    @State private var isAuthenticated = true
    @Environment(\.colorScheme) var colorScheme
    @State private var shouldNavigateToHome = false

    var body: some View {
        Group {
            if isAuthenticated {
                TabView(selection: $selectedTab) {
                    HomeView()
//                        .preferredColorScheme(determineAccentColor())
                        .tag(0)
                        .tabItem {
                            Image(systemName: "house")
                             
                            
                               
                        }
                        
                    CameraContainerView(shouldNavigateToHome: $shouldNavigateToHome)
                        .preferredColorScheme(selectedTab == 1 ? .dark : nil)
                                                /* .background(Color.black.edgesIgnoringSafeArea(.top))*/ // Assume necessary properties are passed
                        .tag(1)
                        .tabItem {
                            Image(systemName: "camera")
                             
                        }
                        
                    ProfileView() // Assume ProfileView exists
                        .tag(2)
                        .tabItem {
                            Image(systemName: "person")
                               
                        }
                }
                .accentColor(determineAccentColor())
                // More UI adjustments can be done here if needed
            } else {
                // Show authentication view if not authenticated
                MainOnboardingView(isAuthenticated: $isAuthenticated)
            }
        }
    }
    
    private func determineAccentColor() -> Color {
          colorScheme == .dark ? .white : .blue
      }
}
