//
//  ContentView.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//

import SwiftUI



struct ContentView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content views
            Group {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    CameraView(captureAction: {
                            // Define what should happen when the capture button is pressed
                            print("Capture button tapped")
                        })
                    .edgesIgnoringSafeArea(.all)
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
    }
}

#Preview {
    ContentView()
}
