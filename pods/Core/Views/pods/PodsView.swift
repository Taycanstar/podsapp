//
//  PodsView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/26/25.
//

import SwiftUI

//struct PodsView: View {
//    @EnvironmentObject var podsViewModel: PodsViewModel
//    @State private var searchText = ""
//    @Environment(\.colorScheme) var colorScheme
//    let folder: Folder?
//    
//    init(folder: Folder? = nil) {
//           self.folder = folder
//       }
//    
//    var filteredPods: [Pod] {
//        if searchText.isEmpty {
//            return podsViewModel.pods
//        } else {
//            return podsViewModel.pods.filter { pod in
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
//        .navigationTitle("Pods")
//        .searchable(text: $searchText, prompt: "Search")
//        .padding(.bottom, 49) // Height of tab bar
//    }
//    
//    private func deletePod(at offsets: IndexSet) {
//        for index in offsets {
//            let pod = filteredPods[index]
//            podsViewModel.deletePod(podId: pod.id)
//        }
//    }
//}


struct PodsView: View {
    @EnvironmentObject var podsViewModel: PodsViewModel
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    let folder: Folder?
    
    init(folder: Folder? = nil) {
        self.folder = folder
    }
    
    var filteredPods: [Pod] {
        // Filter by folder first
        let folderPods = folder == nil ?
            podsViewModel.pods :  // If no folder (default "Pods" folder), show all pods
            podsViewModel.pods.filter { $0.folderId == folder?.id }
        
        // Then apply search filter
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
            }
            .onDelete(perform: deletePod)
        }
        .navigationTitle(folder?.name ?? "Pods")  // Show folder name in navigation title
        .searchable(text: $searchText, prompt: "Search")
        .padding(.bottom, 49)
    }
    
    private func deletePod(at offsets: IndexSet) {
        for index in offsets {
            let pod = filteredPods[index]
            podsViewModel.deletePod(podId: pod.id)
        }
    }
}
