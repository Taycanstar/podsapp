//
//  podsApp.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//

import SwiftUI

@main
struct podsApp: App {
    @StateObject var onboardingViewModel = OnboardingViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(onboardingViewModel)
        }
    }
}
