
import SwiftUI

struct HomeView: View {
    @ObservedObject var cameraModel = CameraViewModel()
    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var uploadViewModel: UploadViewModel
    var networkManager: NetworkManager = NetworkManager()
    
    @Environment(\.colorScheme) var colorScheme
    @State private var podsReordered = false

    @State private var expandedPods = Set<Int>()
    @State private var currentItemIndex = 0
    @State private var editMode: EditMode = .inactive
    @State private var isLoadingMore = false
    @State private var editingPods: [Pod] = []
    @State private var hasInitiallyFetched = false
    @State private var selection: (podIndex: Int, itemIndex: Int)?
    
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if uploadViewModel.isUploading {
                    UploadingSection()
                }
                if homeViewModel.pods.isEmpty {
                    Text("Your pods will display here, tap + to create one")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 45)
                        .padding(.vertical, 35)
                        .multilineTextAlignment(.center)
                }
                List {
//                    ForEach(homeViewModel.pods.indices, id: \.self) { index in
                    ForEach(editMode == .active ? editingPods.indices : homeViewModel.pods.indices, id: \.self) { index in
                        VStack {
                            PodTitleRow(pod: $homeViewModel.pods[index], isExpanded: expandedPods.contains(homeViewModel.pods[index].id), onExpandCollapseTapped: {
                                if editMode == .inactive {
                                    withAnimation {
                                        togglePodExpansion(for: homeViewModel.pods[index].id)
                                    }
                                }
                            })
                            .listRowInsets(EdgeInsets())
                            .buttonStyle(PlainButtonStyle())
                        }
                        .listRowInsets(EdgeInsets())
//                        if expandedPods.contains(homeViewModel.pods[index].id) {
//                            ForEach(homeViewModel.pods[index].items, id: \.id) { item in
//                                if let initialIndex = homeViewModel.pods[index].items.firstIndex(where: { $0.id == item.id }) {
//                                    NavigationLink(destination: PlayerContainerView(items: homeViewModel.pods[index].items, initialIndex: initialIndex)) {
//                                        ItemRow(item: item)
//                                            .listRowInsets(EdgeInsets())
//                                    
//                                    }
//                                }
//                            }
//                            .listRowInsets(EdgeInsets())
//                            .padding(.trailing, 15)
//                        }
                        if expandedPods.contains(homeViewModel.pods[index].id) {
                            ForEach(homeViewModel.pods[index].items, id: \.id) { item in
                                if let initialIndex = homeViewModel.pods[index].items.firstIndex(where: { $0.id == item.id }) {
                                    ItemRow(item: item) {
                                        self.selection = (index, initialIndex)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {} // This empty gesture prevents taps from propagating to the whole row
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .padding(.trailing, 15)
                        }
       
                    }
                    .onMove(perform: movePod)
                    .onDelete(perform: deletePod)
                    if shouldShowLoadMoreButton {
                                            HStack {
                                                Spacer()
                                                Button(action: {
                                                    if !isLoadingMore {
                                                        isLoadingMore = true
                                                        homeViewModel.fetchPodsForUser(email: viewModel.email, page: homeViewModel.currentPage + 1) {
                                                            isLoadingMore = false
                                                        }
                                                    }
                                                }) {
                                                    Text("Load More")
                                                        .foregroundColor(.blue)
                                                }
                                                Spacer()
                                            }
                                        }
                    
                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.bottom, 50)
                .refreshable {
                    homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
                        // No additional action needed
                    }
                }
                .onAppear {
//                    homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
//                        // No additional action needed
//                    }

                    if !hasInitiallyFetched {
                                  homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
                                      hasInitiallyFetched = true
                                  }
                              }
                    editingPods = homeViewModel.pods
                }
                .background(
                    NavigationLink(
                        destination: selection.map { index in
                            PlayerContainerView(
                                items: homeViewModel.pods[index.podIndex].items,
                                initialIndex: index.itemIndex
                            )
                        },
                        isActive: Binding(
                            get: { selection != nil },
                            set: { if !$0 { selection = nil } }
                        )
                    ) {
                        EmptyView()
                    }
                )
                .listStyle(InsetGroupedListStyle())
                .navigationTitle("Pods")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: editButton)
                .environment(\.editMode, $editMode)
                .background(colorScheme == .dark ? Color.black : Color.white)
            }
        }
        .background(colorScheme == .dark ? Color.black.edgesIgnoringSafeArea(.all) : Color.white.edgesIgnoringSafeArea(.all))
    }
    
    private var shouldShowLoadMoreButton: Bool {
            return homeViewModel.pods.count < homeViewModel.totalPods
        }
    

    private func togglePodExpansion(for id: Int) {
        withAnimation(.easeInOut) {
            if expandedPods.contains(id) {
                expandedPods.remove(id)
            } else {
                expandedPods.insert(id)
            }
        }
    }

    private var editButton: some View {
        Button(action: {
            if !expandedPods.isEmpty {
                withAnimation {
                    expandedPods.removeAll()
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if editMode == .active {
                    // Switching to inactive mode
                    editMode = .inactive
                    if podsReordered {
                        homeViewModel.pods = editingPods
                        let orderedPodIds = homeViewModel.pods.map { $0.id }
                        networkManager.reorderPods(email: viewModel.email, podIds: orderedPodIds) { success, errorMessage in
                            DispatchQueue.main.async {
                                if success {
                                    print("Pods reordered successfully on the backend.")
                                } else {
                                    print("Failed to reorder pods on the backend: \(errorMessage ?? "Unknown error")")
                                }
                            }
                        }
                        podsReordered = false
                    }
                } else {
                    // Switching to active mode
                    editMode = .active
                    editingPods = homeViewModel.pods
                }
            }
        }) {
            Text(editMode == .active ? "Done" : "Edit")
                .foregroundColor(.blue)
        }
    }

    func movePod(from source: IndexSet, to destination: Int) {
//        homeViewModel.pods.move(fromOffsets: source, toOffset: destination)
        editingPods.move(fromOffsets: source, toOffset: destination)
        podsReordered = true
    }
    func deletePod(at offsets: IndexSet) {
        let indicesToDelete = Array(offsets)
        let sortedIndices = indicesToDelete.sorted().reversed()
        
        for index in sortedIndices {
            let podId = homeViewModel.pods[index].id
            networkManager.deletePod(podId: podId) { [self] success, message in
                DispatchQueue.main.async {
                    if success {
                        print("Pod deleted successfully.")
                        self.homeViewModel.pods.remove(at: index)
                        if self.editMode == .active {
                            self.editingPods.remove(at: index)
                        }
                        self.expandedPods.remove(podId)
                        
                        // Decrease the total pod count
                        self.homeViewModel.totalPods -= 1
                    } else {
                        print("Failed to delete pod: \(message ?? "Unknown error")")
                    }
                }
            }
        }
    }

}


struct PodTitleRow: View {
    @Binding var pod: Pod
    let isExpanded: Bool
    var onExpandCollapseTapped: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            ZStack{
                NavigationLink(destination: PodView(pod: $pod)){ EmptyView() }.opacity(0.0)
                    .padding(.trailing, -5).frame(width:0, height:0)
                Text(pod.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .padding(.leading, 0) // Apply padding to the text element itself
                    .foregroundColor(colorScheme == .dark ? .white : .black)

            }
            
            Spacer()
            Button(action: onExpandCollapseTapped) {
                HStack{
                    Text("\(pod.items.count)")
                        .foregroundColor(.gray)
                        .padding(.trailing, 4) // Adjust as necessary for alignment
                      
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")

                        .foregroundColor(.gray)
                        .padding(.trailing, 0)
                    
                }
             
        
            }
          
        }
//        .background(colorScheme == .dark ? Color(red: 30/255, green: 30/255, blue: 30/255) : Color.white)
//        .background(colorScheme == .dark ? Color(red: 30/255, green: 30/255, blue: 30/255) : Color.white)

        .cornerRadius(10)
        .padding(.vertical, 17)
        .padding(.horizontal, 15)
    }
    

    
}


//struct ItemRow: View {
//    let item: PodItem
//
//    var body: some View {
//        HStack {
//            Text(item.metadata)
//           
//
//            Spacer()
//
//            if let thumbnailURL = item.thumbnailURL {
//                       AsyncImage(url: thumbnailURL) { image in
//                           image.resizable()
//                       } placeholder: {
//                           ProgressView() // Show a placeholder or a default image until the image loads
//                       }
//                       .aspectRatio(contentMode: .fill)
//                       .frame(width: 35, height: 35)
//                       .clipShape(RoundedRectangle(cornerRadius: 8))
//
//                   }
//            
//        }
//        .padding(.leading, 30)
//
//        .padding(.bottom, 10)
//        .padding(.top, 10)
//
//    }
//}

struct ItemRow: View {
    let item: PodItem
    let onTapNavigate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.metadata)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 5) {
                    if let thumbnailURL = item.thumbnailURL {
                        AsyncImage(url: thumbnailURL) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 35, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .onTapGesture {
                    onTapNavigate()
                }
            }
            
            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
            }
        }
        .padding(.vertical, 10)
        .padding(.leading, 25)
    }
}

