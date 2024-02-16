//
//  CreatePodView.swift
//  pods
//
//  Created by Dimi Nunez on 2/15/24.
//

import SwiftUI

struct CreatePodView: View {
    var pod: Pod

    var body: some View {
        VStack {
            Text("Create Pod")
            ForEach(pod.items, id: \.videoURL) { item in
                Text(item.videoURL.absoluteString) // Display video URLs
                Text(item.metadata) // Display metadata
            }
            // Add UI elements for editing metadata or adding more information
            // ...
            Button("Post Pod") {
                // Handle posting the Pod
            }
        }
    }
}
