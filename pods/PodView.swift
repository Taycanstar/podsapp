//import SwiftUI
//import AVFoundation
//
//extension URL {
//    func generateThumbnail() -> UIImage? {
//        let asset = AVAsset(url: self)
//        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
//        assetImageGenerator.appliesPreferredTrackTransform = true
//        let timestamp = CMTime(seconds: 1, preferredTimescale: 60)
//
//        do {
//            let imageRef = try assetImageGenerator.copyCGImage(at: timestamp, actualTime: nil)
//            return UIImage(cgImage: imageRef)
//        } catch {
//            print("Error generating thumbnail: \(error.localizedDescription)")
//            return nil
//        }
//    }
//}
//
//
//struct PodView: View {
//    var pod: Pod
//    @Environment(\.presentationMode) var presentationMode
//    @State private var isEditing = false
//    @State private var currentIndex: Int = 0
//    @State private var reorderedItems: [PodItem] = []
//    @State private var deletedItemIDs: [Int] = []
//    var networkManager: NetworkManager = NetworkManager()
//    
//    var body: some View {
//            List {
//                ForEach(reorderedItems.indices, id: \.self) { index in
//
//                    NavigationLink(destination: PlayerContainerView(items: reorderedItems)) { 
//                        HStack {
//                            Text(reorderedItems[index].metadata)
//                            Spacer()
//                            // Use AsyncImage for thumbnails loaded from URLs
//                            if let thumbnailURL = reorderedItems[index].thumbnailURL {
//                                AsyncImage(url: thumbnailURL) { phase in
//                                    switch phase {
//                                    case .empty:
//                                        ProgressView()
//                                    case .success(let image):
//                                        image.resizable()
//                                             .aspectRatio(contentMode: .fill)
//                                             .frame(width: 35, height: 35)
//                                             .clipShape(RoundedRectangle(cornerRadius: 8))
//                                    case .failure(_):
//                                        Image(systemName: "photo") // Placeholder in case of failure
//                                             .resizable()
//                                             .aspectRatio(contentMode: .fill)
//                                             .frame(width: 35, height: 35)
//                                             .clipShape(RoundedRectangle(cornerRadius: 8))
//                                    @unknown default:
//                                        EmptyView()
//                                    }
//                                }
//                            } else {
//                                // Fallback content in case there's no thumbnail URL
//                                Image(systemName: "photo.on.rectangle.angled") // Placeholder image
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fill)
//                                    .frame(width: 35, height: 35)
//                                    .clipShape(RoundedRectangle(cornerRadius: 8))
//                            }
//                        }
//                        .padding(.vertical, 1)
//                    }
//                  
//                }
//                .onMove(perform: moveItem)
//                .onDelete(perform: deleteItem)
//            }
//            .navigationTitle(pod.title)
//            .navigationBarTitleDisplayMode(.inline)
//            .navigationBarItems(trailing: editButton)
//            .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
//            .onAppear {
//                        self.reorderedItems = self.pod.items // Initialize reorderedItems with the current items
//                for item in self.reorderedItems {
//                             print(item)
//                            }
//                    }
//        }
//    
//
//    private var backButton: some View {
//        Button(action: {
//            presentationMode.wrappedValue.dismiss()
//        }) {
//            Image(systemName: "chevron.left") // Customize according to your needs
//        }
//    }
//
//    private var editButton: some View {
//        Button(action: {
//            // Toggle the edit mode
//            isEditing.toggle()
//
//            // If exiting edit mode, apply changes
//            if !isEditing {
//                // Call API to delete items
//                deletedItemIDs.forEach { itemId in
//                    networkManager.deletePodItem(itemId: itemId) { success, errorMessage in
//                        if success {
//                            print("Item \(itemId) deleted successfully.")
//                        } else {
//                            print("Failed to delete item \(itemId): \(errorMessage ?? "Unknown error")")
//                        }
//                    }
//                }
//                
//                // Call API to reorder items
//                let itemIDs = reorderedItems.map { $0.id }
//                networkManager.reorderPodItems(podId: pod.id, itemIds: itemIDs) { success, errorMessage in
//                    if success {
//                        print("Items reordered successfully.")
//                    } else {
//                        print("Failed to reorder items: \(errorMessage ?? "Unknown error")")
//                    }
//                }
//
//                // Reset local changes
//                deletedItemIDs.removeAll()
//            }
//        }) {
//            Text(isEditing ? "Done" : "Edit")
//        }
//    }
//
//
//    func moveItem(from source: IndexSet, to destination: Int) {
//        reorderedItems.move(fromOffsets: source, toOffset: destination)
//    }
//
//    func deleteItem(at offsets: IndexSet) {
//        offsets.map { reorderedItems[$0].id }.forEach { deletedItemIDs.append($0) }
//        reorderedItems.remove(atOffsets: offsets)
//    }
//
//}


import SwiftUI
import AVFoundation

extension URL {
    func generateThumbnail() -> UIImage? {
        let asset = AVAsset(url: self)
        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImageGenerator.appliesPreferredTrackTransform = true
        let timestamp = CMTime(seconds: 1, preferredTimescale: 60)

        do {
            let imageRef = try assetImageGenerator.copyCGImage(at: timestamp, actualTime: nil)
            return UIImage(cgImage: imageRef)
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
}

struct PodView: View {
    var pod: Pod
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var currentIndex: Int = 0
    @State private var reorderedItems: [PodItem] = []
    @State private var deletedItemIDs: [Int] = []
    @State private var showMenu = false
    var networkManager: NetworkManager = NetworkManager()
    
    var body: some View {
        List {
            ForEach(reorderedItems.indices, id: \.self) { index in

                NavigationLink(destination: PlayerContainerView(items: reorderedItems)) {
                    HStack {
                        Text(reorderedItems[index].metadata)
                        Spacer()
                        // Use AsyncImage for thumbnails loaded from URLs
                        if let thumbnailURL = reorderedItems[index].thumbnailURL {
                            AsyncImage(url: thumbnailURL) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image.resizable()
                                         .aspectRatio(contentMode: .fill)
                                         .frame(width: 35, height: 35)
                                         .clipShape(RoundedRectangle(cornerRadius: 8))
                                case .failure(_):
                                    Image(systemName: "photo") // Placeholder in case of failure
                                         .resizable()
                                         .aspectRatio(contentMode: .fill)
                                         .frame(width: 35, height: 35)
                                         .clipShape(RoundedRectangle(cornerRadius: 8))
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            // Fallback content in case there's no thumbnail URL
                            Image(systemName: "photo.on.rectangle.angled") // Placeholder image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 35, height: 35)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.vertical, 1)
                }
              
            }
            .onMove(perform: moveItem)
            .onDelete(perform: deleteItem)
        }
        .navigationTitle(pod.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: trailingNavigationBarItem)
        .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
        .onAppear {
            self.reorderedItems = self.pod.items // Initialize reorderedItems with the current items
            for item in self.reorderedItems {
                print(item)
            }
        }
        .actionSheet(isPresented: $showMenu) {
            ActionSheet(title: Text("Options"), buttons: [
                .default(Text("Edit")) {
                    isEditing.toggle()
                },
                .default(Text("Add Item")) {
                    // Add new item action
                    // Implement the functionality to add a new item
                },
                .cancel()
            ])
        }
    }
    
    private var trailingNavigationBarItem: some View {
        Group {
            if isEditing {
                Button(action: {
                    isEditing.toggle()
                    if !isEditing {
                        // Call API to delete items
                        deletedItemIDs.forEach { itemId in
                            networkManager.deletePodItem(itemId: itemId) { success, errorMessage in
                                if success {
                                    print("Item \(itemId) deleted successfully.")
                                } else {
                                    print("Failed to delete item \(itemId): \(errorMessage ?? "Unknown error")")
                                }
                            }
                        }
                        
                        // Call API to reorder items
                        let itemIDs = reorderedItems.map { $0.id }
                        networkManager.reorderPodItems(podId: pod.id, itemIds: itemIDs) { success, errorMessage in
                            if success {
                                print("Items reordered successfully.")
                            } else {
                                print("Failed to reorder items: \(errorMessage ?? "Unknown error")")
                            }
                        }

                        // Reset local changes
                        deletedItemIDs.removeAll()
                    }
                }) {
                    Text("Done")
                }
            } else {
                Button(action: {
                    showMenu.toggle()
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.primary)
                  
                }
            }
        }
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        reorderedItems.move(fromOffsets: source, toOffset: destination)
    }

    func deleteItem(at offsets: IndexSet) {
        offsets.map { reorderedItems[$0].id }.forEach { deletedItemIDs.append($0) }
        reorderedItems.remove(atOffsets: offsets)
    }
}


