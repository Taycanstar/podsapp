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
    @State private var shouldNavigateToPodsOnAppear = true
    
    var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return podsViewModel.folders.filter { $0.name != "Pods" }  // Filter out Pods folder from deletion
        } else {
            return podsViewModel.folders.filter { folder in
                folder.name != "Pods" && folder.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        List {
            Section {
                NavigationLink("Pods", value: FolderDestination.pods)
                ForEach(filteredFolders) { folder in
                    Text(folder.name)
                }
                .onDelete(perform: deleteFolder)
            }
        }
        .navigationTitle("Folders")
        .searchable(text: $searchText, prompt: "Search")
        .padding(.bottom, 49)
        .onAppear {
            if shouldNavigateToPodsOnAppear {
                path.append(FolderDestination.pods)
                shouldNavigateToPodsOnAppear = false
            }
        }
    }
    
    private func deleteFolder(at offsets: IndexSet) {
        for index in offsets {
            let folder = filteredFolders[index]
            podsViewModel.deleteFolder(folderId: folder.id)
        }
    }
}


struct PodsContainerView: View {
    @EnvironmentObject var podsViewModel: PodsViewModel
    @State private var path = NavigationPath()
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        NavigationStack(path: $path) {
            FoldersView(path: $path)
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
