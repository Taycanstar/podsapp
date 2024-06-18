//import SwiftUI
//
//
//
//
//struct HomeView: View {
//
//    @ObservedObject var cameraModel = CameraViewModel()
//    @EnvironmentObject var homeViewModel: HomeViewModel
//    @EnvironmentObject var viewModel: OnboardingViewModel
//    @EnvironmentObject var uploadViewModel: UploadViewModel
//    var networkManager: NetworkManager = NetworkManager()
//    
//    @Environment(\.colorScheme) var colorScheme
//    @State private var podsReordered = false
//
//    @State private var expandedPods = Set<String>()
//    @State private var currentItemIndex = 0
//    @State private var editMode: EditMode = .inactive
//  
//    var body: some View {
//      
//        NavigationView {
//            VStack(spacing: 0){
//
//                if uploadViewModel.isUploading {
//                                   UploadingSection()
//                               }
//                List {
//                    ForEach(homeViewModel.pods.indices, id: \.self) { index in
//                        VStack {
//                         
//                            PodTitleRow(pod: $homeViewModel.pods[index], isExpanded: expandedPods.contains(homeViewModel.pods[index].title), onExpandCollapseTapped: {
//                                if editMode == .inactive {
//                                                                           withAnimation {
//                                                                               togglePodExpansion(for: homeViewModel.pods[index].title)
//                                                                           }
//                                                                       }
//                                    })
//                                        .listRowInsets(EdgeInsets())
//                                        .buttonStyle(PlainButtonStyle())
//                        }
//                        .listRowInsets(EdgeInsets())
//     
//                        if(expandedPods.contains(homeViewModel.pods[index].title)) {
//                            ForEach(homeViewModel.pods[index].items, id: \.id) { item in
//                                if let initialIndex = homeViewModel.pods[index].items.firstIndex(where: { $0.id == item.id }) {
//
//                                    NavigationLink(destination: PlayerContainerView(items: homeViewModel.pods[index].items, initialIndex: initialIndex))
//                                    {
//                                        ItemRow(item: item)
//                                            .listRowInsets(EdgeInsets())
//                                    }
//                                }
//                            }
//                                .listRowInsets(EdgeInsets())
//                                .padding(.trailing, 15)
//                            }
//                        
//                        
//                        }
//
//                    .onMove(perform: movePod)
//                    .onDelete(perform: deletePod)
//                  
//                        
//                }
//                .scrollIndicators(.hidden)  // This hides the vertical scroll indicators
//                                .padding(.bottom, 50)
//                .refreshable {
//                       homeViewModel.fetchPodsForUser(email: viewModel.email)
//                   }
//                
//                .onAppear {
//                 
//                    homeViewModel.fetchPodsForUser(email: viewModel.email) // Use the actual user email
//                    uploadViewModel.uploadCompletion = {
//                                           homeViewModel.fetchPodsForUser(email: viewModel.email)
//                                       }
//                           }
//                
//                .listStyle(InsetGroupedListStyle())
//                               .navigationTitle("Pods")
//                               .navigationBarTitleDisplayMode(.inline)
//                               .navigationBarItems(trailing: editButton)
//                               .environment(\.editMode, $editMode)
////                               .preferredColorScheme(.light)
//                               .background(colorScheme == .dark ? Color.black : Color.white)
//                
////                if uploadViewModel.postSuccess {
////                                 Text("Your pod was posted")
////                        .fontWeight(.semibold)
////                                     .padding()
////                                     .background(Color.black.opacity(0.75))
////                                     .foregroundColor(.white)
////                                     .cornerRadius(8)
//////                                     .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
////                                     .transition(.move(edge: .top).combined(with: .opacity))
////                                     .animation(.easeInOut,  value: uploadViewModel.postSuccess)
//////                                     .onAppear {
//////                                         print("Post success message appeared")
//////                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { // Change delay to 5 seconds
//////                                                                uploadViewModel.postSuccess = false  // Automatically reset after 5 seconds
//////                                            
//////                                                        print("Post success message dismissed")
//////                                                        }
//////                                     }
////                               
////                                     .zIndex(1)  // Ensure the popup is above other content
////                             }
//                
//                // Overlay the UploadProgressView
////                               if uploadViewModel.isUploading {
////                                   UploadProgressView()
////                                       .environmentObject(uploadViewModel) // Make sure to pass the environment object
////                                       .position(x: UIScreen.main.bounds.width * 0.1, y: 30)// Adjust position as necessary
////                               }
//            }
//       
//    
//        }
//        .background(colorScheme == .dark ? Color.black.edgesIgnoringSafeArea(.all) : Color.white.edgesIgnoringSafeArea(.all))
//
////        .background(backgroundColor.edgesIgnoringSafeArea(.all))
//    }
//
//    private func togglePodExpansion(for title: String) {
//        withAnimation(.easeInOut) {
//            if expandedPods.contains(title) {
//                expandedPods.remove(title)
//            } else {
//                expandedPods.insert(title)
//            }
//        }
//    }
//
//    private var editButton: some View {
//        Button(action: {
//            // Collapse all expanded pods before toggling edit mode
//            if !expandedPods.isEmpty {
//                withAnimation {
//                    expandedPods.removeAll()
//                }
//            }
//
//            // Delay the toggle of edit mode to allow animation to complete
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                // Toggle edit mode
//                editMode = editMode == .active ? .inactive : .active
//                
//                // If exiting edit mode and pods have been reordered, send the new order to the backend
//                if editMode == .inactive && podsReordered {
//                    let orderedPodIds = homeViewModel.pods.map { $0.id }
//                    
//                    // Send the new order to the backend
//                    networkManager.reorderPods(email: viewModel.email, podIds: orderedPodIds) { success, errorMessage in
//                        DispatchQueue.main.async {
//                            if success {
//                                print("Pods reordered successfully on the backend.")
//                            } else {
//                                print("Failed to reorder pods on the backend: \(errorMessage ?? "Unknown error")")
//                            }
//                        }
//                    }
//                    podsReordered = false // Reset the reorder flag
//                }
//            }
//        }) {
//            Text(editMode == .active ? "Done" : "Edit")
//        }
//    }
//    
//
//
////    private var backgroundColor: Color {
////        colorScheme == .dark ? Color.black : Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
////    }
//    
//        func movePod(from source: IndexSet, to destination: Int) {
//            // Move the pods in the local data source to reflect the new order
//            homeViewModel.pods.move(fromOffsets: source, toOffset: destination)
//            podsReordered = true
//        }
//    
//    
//        func deletePod(at offsets: IndexSet) {
//            offsets.forEach { index in
//                 let podId = homeViewModel.pods[index].id // Assuming each Pod has an 'id' property
//    
//                 // Call the network manager to delete the pod from the backend
//                 networkManager.deletePod(podId: podId) { success, message in
//                     DispatchQueue.main.async {
//                         if success {
//                             print("Pod deleted successfully.")
//                             // Remove the pod from the local array to update the UI
//                             self.homeViewModel.pods.remove(atOffsets: offsets)
//                         } else {
//                             // Handle error, e.g., show an alert to the user
//                             print("Failed to delete pod: \(message ?? "Unknown error")")
//                         }
//                     }
//                 }
//             }
//        }
//    
//}
import SwiftUI

struct HomeView: View {
    @ObservedObject var cameraModel = CameraViewModel()
    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var uploadViewModel: UploadViewModel
    var networkManager: NetworkManager = NetworkManager()
    
    @Environment(\.colorScheme) var colorScheme
    @State private var podsReordered = false

    @State private var expandedPods = Set<String>()
    @State private var currentItemIndex = 0
    @State private var editMode: EditMode = .inactive
    @State private var isLoadingMore = false
  
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if uploadViewModel.isUploading {
                    UploadingSection()
                }
                List {
                    ForEach(homeViewModel.pods.indices, id: \.self) { index in
                        VStack {
                            PodTitleRow(pod: $homeViewModel.pods[index], isExpanded: expandedPods.contains(homeViewModel.pods[index].title), onExpandCollapseTapped: {
                                if editMode == .inactive {
                                    withAnimation {
                                        togglePodExpansion(for: homeViewModel.pods[index].title)
                                    }
                                }
                            })
                            .listRowInsets(EdgeInsets())
                            .buttonStyle(PlainButtonStyle())
                        }
                        .listRowInsets(EdgeInsets())
                        if expandedPods.contains(homeViewModel.pods[index].title) {
                            ForEach(homeViewModel.pods[index].items, id: \.id) { item in
                                if let initialIndex = homeViewModel.pods[index].items.firstIndex(where: { $0.id == item.id }) {
                                    NavigationLink(destination: PlayerContainerView(items: homeViewModel.pods[index].items, initialIndex: initialIndex)) {
                                        ItemRow(item: item)
                                            .listRowInsets(EdgeInsets())
                                    }
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .padding(.trailing, 15)
                        }
                    }
                    .onMove(perform: movePod)
                    .onDelete(perform: deletePod)
                    
//                    if homeViewModel.currentPage < homeViewModel.totalPages {
//                        HStack {
//                            Spacer()
//                            Button(action: {
//                                if !isLoadingMore {
//                                    isLoadingMore = true
//                                    homeViewModel.fetchPodsForUser(email: viewModel.email, page: homeViewModel.currentPage + 1) {
//                                        isLoadingMore = false
//                                    }
//                                }
//                            }) {
//                                Text("Load More")
//                                    .foregroundColor(.blue)
////                                    .padding()
//                            }
//                            Spacer()
//                        }
//                    }
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
                    homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
                        // No additional action needed
                    }
                    uploadViewModel.uploadCompletion = {
                        homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
                            // No additional action needed
                        }
                    }
                }
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


    private func togglePodExpansion(for title: String) {
        withAnimation(.easeInOut) {
            if expandedPods.contains(title) {
                expandedPods.remove(title)
            } else {
                expandedPods.insert(title)
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
                editMode = editMode == .active ? .inactive : .active
                
                if editMode == .inactive && podsReordered {
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
            }
        }) {
            Text(editMode == .active ? "Done" : "Edit")
                .foregroundColor(.blue)
        }
    }

    func movePod(from source: IndexSet, to destination: Int) {
        homeViewModel.pods.move(fromOffsets: source, toOffset: destination)
        podsReordered = true
    }

    func deletePod(at offsets: IndexSet) {
        offsets.forEach { index in
            let podId = homeViewModel.pods[index].id
            networkManager.deletePod(podId: podId) { success, message in
                DispatchQueue.main.async {
                    if success {
                        print("Pod deleted successfully.")
                        self.homeViewModel.pods.remove(atOffsets: offsets)
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


struct ItemRow: View {
    let item: PodItem

    var body: some View {
        HStack {
            Text(item.metadata)
           

            Spacer()

            if let thumbnailURL = item.thumbnailURL {
                       AsyncImage(url: thumbnailURL) { image in
                           image.resizable()
                       } placeholder: {
                           ProgressView() // Show a placeholder or a default image until the image loads
                       }
                       .aspectRatio(contentMode: .fill)
                       .frame(width: 35, height: 35)
                       .clipShape(RoundedRectangle(cornerRadius: 8))

                   }
            
        }
        .padding(.leading, 30)

        .padding(.bottom, 10)
        .padding(.top, 10)

    }
}

