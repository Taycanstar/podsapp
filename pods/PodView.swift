import SwiftUI


struct PodView: View {
    var pod: Pod
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var currentIndex: Int = 0
    @State private var reorderedItems: [PodItem] = []
    @State private var deletedItemIDs: [Int] = []
    var networkManager: NetworkManager = NetworkManager()
    
    var body: some View {
            List {
                ForEach(reorderedItems.indices, id: \.self) { index in
                    NavigationLink(destination: ItemView(items: reorderedItems)) {
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
            .navigationBarItems(trailing: editButton)
            .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
            .onAppear {
                        self.reorderedItems = self.pod.items // Initialize reorderedItems with the current items
                    }
        }
    

    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left") // Customize according to your needs
        }
    }

    private var editButton: some View {
        Button(action: {
            // Toggle the edit mode
            isEditing.toggle()

            // If exiting edit mode, apply changes
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
            Text(isEditing ? "Done" : "Edit")
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




