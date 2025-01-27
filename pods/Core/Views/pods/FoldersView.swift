//
//  FoldersView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/27/25.
//

import SwiftUI

struct FoldersView: View {
    @Binding var path: NavigationPath
    @State private var shouldNavigateToPodsOnAppear = true
    
    var body: some View {
        List {
            Section(header: Text("On My iPhone")) {
                NavigationLink("Pods", value: FolderDestination.pods)
            }
        }
        .navigationTitle("Folders")
        .onAppear {
            if shouldNavigateToPodsOnAppear {
                path.append(FolderDestination.pods)  // No more "Decodable" error
                shouldNavigateToPodsOnAppear = false
            }
        }
    }
}


struct PodsContainerView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            FoldersView(path: $path)
                // Move `.navigationDestination` up here:
                .navigationDestination(for: FolderDestination.self) { destination in
                    switch destination {
                    case .pods:
                        PodsView()
                    }
                }
        }
    }
}


enum FolderDestination: Hashable {
    case pods
}
