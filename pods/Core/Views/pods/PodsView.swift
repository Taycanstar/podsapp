//
//  PodsView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/26/25.
//

import SwiftUI

struct PodsView: View {
    @EnvironmentObject var podsViewModel: PodsViewModel
    
    var body: some View {
        List(podsViewModel.pods) { pod in
            Text(pod.title)
                .font(.system(size: 17, weight: .semibold))
        }
        .navigationTitle("Pods") // The back button will say "Folders" automatically
    }
}
