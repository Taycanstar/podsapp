//
//  PodsView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/26/25.
//

import SwiftUI

struct PodsView: View {
    @EnvironmentObject var podsViewModel: PodsViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    // We keep our local cache if needed (optional)
    @State private var loadedPods: [Int: Pod] = [:]
    @State private var showingOptionsMenu = false
    @State private var showQuickPodView = false
    @State private var selectedPodId: Int?
    @Binding var navigationPath: NavigationPath
    @State private var isEditMode: EditMode = .inactive
    
    let folder: Folder?
    let networkManager = NetworkManager()
    
    init(folder: Folder? = nil, navigationPath: Binding<NavigationPath>) {
        self.folder = folder
        _navigationPath = navigationPath
    }
    
    var filteredPods: [Pod] {
        let folderPods = folder == nil ?
            podsViewModel.pods :
            podsViewModel.pods.filter { $0.folderId == folder?.id }
        if searchText.isEmpty {
            return folderPods
        } else {
            return folderPods.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredPods) { pod in
                NavigationLink(value: AppNavigationDestination.podDetails(pod.id)) {
                    Text(pod.title)
                        .font(.system(size: 16, weight: .semibold))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    loadPodDetails(for: pod) // Only fetch when tapped
                })

            }
           
            .onDelete(perform: deletePod)
               
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    
                        Button(action: {
                            showQuickPodView = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(UIColor.secondarySystemFill))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
//                        Button(action: {
//                            showingOptionsMenu = true
//                        }) {
//                            ZStack {
//                                Circle()
//                                    .fill(Color(UIColor.secondarySystemFill))
//                                    .frame(width: 30, height: 30)
//                                Image(systemName: "ellipsis")
//                                    .font(.system(size: 11, weight: .bold))
//                                    .foregroundColor(.accentColor)
//                            }
//                        }
                   
                }
            }
        }
        .environment(\.editMode, $isEditMode)
        .sheet(isPresented: $showQuickPodView) {
                QuickPodView(isPresented: $showQuickPodView) { newPod in
                    loadPodDetails(for: newPod)
                    navigationPath.append(AppNavigationDestination.podDetails(newPod.id))
                }
            }
        .confirmationDialog("Options", isPresented: $showingOptionsMenu) {
                  Button("Edit") {
                      withAnimation {
                          isEditMode = .active
                      }
                  }
             
                  Button("Cancel", role: .cancel) { }
              }
        .navigationTitle(folder?.name ?? "Pods")
        .searchable(text: $searchText, prompt: "Search")
        .padding(.bottom, 49)
    }
    
    private func movePods(from source: IndexSet, to destination: Int) {
          var updatedPods = filteredPods
          updatedPods.move(fromOffsets: source, toOffset: destination)
          
          // Update the order in the view model
          let podIds = updatedPods.map { $0.id }
          podsViewModel.updatePodsOrder(podIds: podIds)
      }
    
    private func loadPodDetails(for pod: Pod) {
        networkManager.fetchFullPodDetails(email: viewModel.email, podId: pod.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fullPod):
                    // Update the local cache if desired:
                    loadedPods[pod.id] = fullPod
                    print("Fetched pod items count: \(fullPod.items.count)")
                    // And update the global pods array so that HomePodView can see full data.
                    if let index = podsViewModel.pods.firstIndex(where: { $0.id == pod.id }) {
                        if podsViewModel.pods[index] != fullPod { // Ensure there's an actual update
                            podsViewModel.pods[index] = fullPod
                        }
                    }

                case .failure(let error):
                    print("Failed to load pod details: \(error)")
                }
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
