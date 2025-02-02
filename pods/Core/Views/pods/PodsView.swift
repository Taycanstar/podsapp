//
//  PodsView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/26/25.
//

import SwiftUI


//
//struct PodsView: View {
//    @EnvironmentObject var podsViewModel: PodsViewModel
//    @State private var searchText = ""
//    @Environment(\.colorScheme) var colorScheme
//    let folder: Folder?
//    
//    init(folder: Folder? = nil) {
//        self.folder = folder
//    }
//    
//    var filteredPods: [Pod] {
//        // Filter by folder first
//        let folderPods = folder == nil ?
//            podsViewModel.pods :  // If no folder (default "Pods" folder), show all pods
//            podsViewModel.pods.filter { $0.folderId == folder?.id }
//        
//        // Then apply search filter
//        if searchText.isEmpty {
//            return folderPods
//        } else {
//            return folderPods.filter { pod in
//                pod.title.localizedCaseInsensitiveContains(searchText)
//            }
//        }
//    }
//    
//    var body: some View {
//        List {
//            ForEach(filteredPods) { pod in
//                Text(pod.title)
//                    .font(.system(size: 16, weight: .semibold))
//            }
//            .onDelete(perform: deletePod)
//        }
//        .navigationTitle(folder?.name ?? "Pods")  // Show folder name in navigation title
//        .searchable(text: $searchText, prompt: "Search")
//        .padding(.bottom, 49)
//    }
//    
//    private func deletePod(at offsets: IndexSet) {
//        for index in offsets {
//            let pod = filteredPods[index]
//            podsViewModel.deletePod(podId: pod.id)
//        }
//    }
//    
//    
//}

struct PodsView: View {
    @EnvironmentObject var podsViewModel: PodsViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel // Add this
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedPod: Pod? // Add this
    @State private var showingPodView = false // Add this
    let folder: Folder?
    let networkManager = NetworkManager() // Add this
    
    init(folder: Folder? = nil) {  // <-- Add this back
         self.folder = folder
     }
     
    
    var filteredPods: [Pod] {
        let folderPods = folder == nil ?
            podsViewModel.pods :
            podsViewModel.pods.filter { $0.folderId == folder?.id }
        
        if searchText.isEmpty {
            return folderPods
        } else {
            return folderPods.filter { pod in
                pod.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredPods) { pod in
                Text(pod.title)
                    .font(.system(size: 16, weight: .semibold))
                    .onTapGesture {
                        loadPodDetails(pod)
                    }
            }
            .onDelete(perform: deletePod)
        }
        .navigationTitle(folder?.name ?? "Pods")
        .searchable(text: $searchText, prompt: "Search")
        .padding(.bottom, 49)
        .sheet(isPresented: $showingPodView) {
            if let pod = selectedPod {
                PodView(pod: .constant(pod), needsRefresh: .constant(false))
            }
        }
    }
    
    private func loadPodDetails(_ pod: Pod) {
        networkManager.fetchFullPodDetails(email: viewModel.email, podId: pod.id) { result in
            switch result {
            case .success(let fullPod):
                selectedPod = fullPod
                showingPodView = true
            case .failure(let error):
                print("Failed to load pod details: \(error)")
            }
        }
    }
    
    private func deletePod(at offsets: IndexSet) {
        for index in offsets {
            let pod = filteredPods[index]
            podsViewModel.deletePod(podId: pod.id)
        }
    }
}
