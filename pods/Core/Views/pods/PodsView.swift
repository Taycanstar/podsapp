//
//  PodsView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/26/25.
//

import SwiftUI

struct PodsView: View {
    @EnvironmentObject var podsViewModel: PodsViewModel
    @State private var searchText = ""
    
    var filteredPods: [Pod] {
        if searchText.isEmpty {
            return podsViewModel.pods
        } else {
            return podsViewModel.pods.filter { pod in
                pod.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        List(filteredPods) { pod in
            Text(pod.title)
                .font(.system(size: 16, weight: .semibold))
        }
        .navigationTitle("Pods")
        .searchable(text: $searchText, prompt: "Search")
    }
}
