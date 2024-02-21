//
//  HomeView.swift
//  pods
//
//  Created by Dimi Nunez on 2/7/24.
//

import SwiftUI

struct HomeView: View {
    @StateObject var cameraModel = CameraViewModel()
    var body: some View {
        Button("Test Transcription") {
                   if let fileURL = Bundle.main.url(forResource: "space_oddity", withExtension: "wav") {
                       cameraModel.transcribeAudio(from: fileURL) { transcribedText in
                           print("Transcribed text: \(transcribedText ?? "Failed to transcribe")")
                       }
                   } else {
                       print("Audio file not found")
                   }
               }
    }
}

#Preview {
    HomeView()
}
