//
//  FoldersView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/27/25.
//

import SwiftUI

struct FoldersView: View {
    @Binding var path: NavigationPath
    @State private var searchText = ""
    @EnvironmentObject var podsViewModel: PodsViewModel
    @State private var shouldNavigateToPodsOnAppear = true  // Add this back
    
    var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return podsViewModel.folders
        } else {
            return podsViewModel.folders.filter { folder in
                folder.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        List {
            Section {
                NavigationLink("Pods", value: FolderDestination.pods)
                ForEach(filteredFolders) { folder in
                    if folder.name != "Pods" {
                        Text(folder.name)
                    }
                }
            }
        }
        .navigationTitle("Folders")
        .searchable(text: $searchText, prompt: "Search")
        .onAppear {  // Add this back
            if shouldNavigateToPodsOnAppear {
                path.append(FolderDestination.pods)
                shouldNavigateToPodsOnAppear = false
            }
        }
    }
}


struct PodsContainerView: View {
    @StateObject var podsViewModel = PodsViewModel()
    @State private var path = NavigationPath()
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        NavigationStack(path: $path) {
            FoldersView(path: $path)
                .navigationDestination(for: FolderDestination.self) { destination in
                    switch destination {
                    case .pods:
                        PodsView()
                            .onAppear {
                                podsViewModel.initialize(email: viewModel.email)  // Removed if let
                            }
                    }
                }
        }
        .environmentObject(podsViewModel)
    }
}


enum FolderDestination: Hashable {
    case pods
}
