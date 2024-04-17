//
//  podsApp.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//

import SwiftUI

@main
struct podsApp: App {
    @StateObject var sharedViewModel = SharedViewModel()
    @StateObject var onboardingViewModel = OnboardingViewModel()
    @StateObject var uploadViewModel = UploadViewModel()
    @StateObject var homeViewModel = HomeViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(onboardingViewModel)
                .environmentObject(sharedViewModel)
                .environmentObject(uploadViewModel)
                .environmentObject(homeViewModel)
        }
    }
}
