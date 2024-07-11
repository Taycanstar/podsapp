import SwiftUI
import AVFoundation

struct PodView: View {
    @Binding var pod: Pod
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var reorderedItems: [PodItem] = []
    @State private var deletedItemIDs: [Int] = []
    @State private var showMenu = false
    @State private var showAddItemView = false
    @State private var isAnyItemEditing: Bool = false
    @State private var showDoneButton = false
    @State private var editingItemId: Int?
    @State private var selection: (podIndex: Int, itemIndex: Int)?
    var networkManager: NetworkManager = NetworkManager()
    @EnvironmentObject var uploadViewModel: UploadViewModel
    
    @FocusState private var focusedField: String?
    
    var body: some View {
        List {
            ForEach(reorderedItems.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            TextField("", text: $reorderedItems[index].metadata)
                                .focused($focusedField, equals: "metadata_\(reorderedItems[index].id)")
                                .font(.body)
                                .onTapGesture {
                                    if !isEditing {
                                        focusedField = "metadata_\(reorderedItems[index].id)"
                                        showDoneButton = true
                                        isAnyItemEditing = true
                                        editingItemId = reorderedItems[index].id
                                    }
                                }
                            
                            Spacer()
                            
                            HStack(spacing: 5) {
                                if let thumbnailURL = reorderedItems[index].thumbnailURL {
                                    AsyncImage(url: thumbnailURL) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image.resizable()
                                        case .failure(_):
                                            Image(systemName: "photo")
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 30, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                if !isEditing {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                }
                            }
                        }

                        TextField(reorderedItems[index].notes.isEmpty ? "Add note" : "", text: $reorderedItems[index].notes)
                            .focused($focusedField, equals: "notes_\(reorderedItems[index].id)")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .onTapGesture {
                                if !isEditing {
                                    focusedField = "notes_\(reorderedItems[index].id)"
                                    showDoneButton = true
                                    isAnyItemEditing = true
                                    editingItemId = reorderedItems[index].id
                                }
                            }
                    }
                    .padding(.vertical, 10)
                    
                    if index < reorderedItems.count - 1 {
                        Divider()
                    }
                }
                .padding(.horizontal, 15)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isEditing && !isAnyItemEditing {
                        self.selection = (0, index)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            .onMove(perform: moveItem)
            .onDelete(perform: deleteItem)
        }
        .padding(5)
        .scrollIndicators(.hidden)
        .listStyle(PlainListStyle())
        .environment(\.defaultMinListRowHeight, 1)
        .navigationTitle(pod.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: trailingNavigationBarItem)
        .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
        .onAppear {
            self.reorderedItems = self.pod.items
            uploadViewModel.addItemCompletion = {
                refreshPodItems()
            }
        }
        .background(
            NavigationLink(
                destination: selection.map { index in
                    PlayerContainerView(
                        items: reorderedItems,
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
        .actionSheet(isPresented: $showMenu) {
            ActionSheet(title: Text("Options"), buttons: [
                .default(Text("Edit")) {
                    isEditing.toggle()
                },
                .cancel()
            ])
        }
        .fullScreenCover(isPresented: $showAddItemView) {
            AddItemContainerView(showAddItemView: $showAddItemView, podId: pod.id)
        }
    }
    
    private var trailingNavigationBarItem: some View {
        Group {
            if isEditing || showDoneButton {
                Button("Done") {
                    if isEditing {
                        saveChangesAndExitEditMode()
                    } else {
                        saveInputChanges()
                    }
                }
            } else {
                Menu {
                    Button("Edit") {
                        isEditing = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private func refreshPodItems() {
        networkManager.fetchItemsForPod(podId: pod.id) { items, error in
            if let items = items {
                self.reorderedItems = items
                self.pod.items = items
            } else {
                print("Failed to fetch items for pod: \(error ?? "Unknown error")")
            }
        }
    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        reorderedItems.move(fromOffsets: source, toOffset: destination)
        
        // Reorder in the backend
        let itemIDs = reorderedItems.map { $0.id }
        networkManager.reorderPodItems(podId: pod.id, itemIds: itemIDs) { success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    print("Items reordered successfully in the backend.")
                    // Update the pod's items to reflect the new order
                    self.pod.items = self.reorderedItems
                } else {
                    print("Failed to reorder items in the backend: \(errorMessage ?? "Unknown error")")
                    // Optionally, revert the local order if the backend update fails
                    // self.reorderedItems = self.pod.items
                }
            }
        }
    }

    func deleteItem(at offsets: IndexSet) {
        offsets.forEach { index in
            let itemId = reorderedItems[index].id
            networkManager.deletePodItem(itemId: itemId) { success, errorMessage in
                if success {
                    print("Item \(itemId) deleted successfully.")
                    reorderedItems.remove(at: index)
                } else {
                    print("Failed to delete item \(itemId): \(errorMessage ?? "Unknown error")")
                }
            }
        }
    }

    
    private func saveChangesAndExitEditMode() {
        isEditing = false
        reorderedItems.forEach { item in
            updateMetadata(item: item)
        }
        
        deletedItemIDs.forEach { itemId in
            networkManager.deletePodItem(itemId: itemId) { success, errorMessage in
                if success {
                    print("Item \(itemId) deleted successfully.")
                } else {
                    print("Failed to delete item \(itemId): \(errorMessage ?? "Unknown error")")
                }
            }
        }
        
        let itemIDs = reorderedItems.map { $0.id }
        networkManager.reorderPodItems(podId: pod.id, itemIds: itemIDs) { success, errorMessage in
            if success {
                print("Items reordered successfully.")
            } else {
                print("Failed to reorder items: \(errorMessage ?? "Unknown error")")
            }
        }

        deletedItemIDs.removeAll()
    }

    private func saveInputChanges() {
        guard let itemId = editingItemId,
              let itemIndex = reorderedItems.firstIndex(where: { $0.id == itemId }) else {
            print("No item selected for editing or item not found")
            return
        }
        
        let item = reorderedItems[itemIndex]
        
        networkManager.updatePodItemLabelAndNotes(itemId: item.id, newLabel: item.metadata, newNotes: item.notes) { success, errorMessage in
            if success {
                print("Pod item label and notes updated successfully.")
            } else {
                print("Failed to update pod item label and notes: \(errorMessage ?? "Unknown error")")
            }
            DispatchQueue.main.async {
                self.showDoneButton = false
                self.isAnyItemEditing = false
                self.editingItemId = nil
                self.focusedField = nil
            }
        }
    }
    
    private func updateMetadata(item: PodItem) {
        networkManager.updatePodItemLabelAndNotes(itemId: item.id, newLabel: item.metadata, newNotes: item.notes) { success, errorMessage in
            if success {
                print("Item \(item.id) label and notes updated successfully.")
            } else {
                print("Failed to update item \(item.id) label and notes: \(errorMessage ?? "Unknown error")")
            }
        }
    }
    
    private func calculateHeight(for text: String) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .footnote)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).boundingRect(
            with: CGSize(width: UIScreen.main.bounds.width - 80, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).size
        
        return size.height + 10 // Add some padding
    }
}


//
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
//struct PodView: View {
//    @Binding var pod: Pod
//    @Environment(\.presentationMode) var presentationMode
//    @State private var isEditing = false
//    @State private var currentIndex: Int = 0
//    @State private var reorderedItems: [PodItem] = []
//    @State private var deletedItemIDs: [Int] = []
//    @State private var showMenu = false
//    var networkManager: NetworkManager = NetworkManager()
//    @State private var showAddItemView = false
//    @EnvironmentObject var uploadViewModel: UploadViewModel
//    
//    var body: some View {
//        List {
//            ForEach(reorderedItems.indices, id: \.self) { index in
//                if isEditing {
//                    HStack {
//                        TextField("Metadata", text: $reorderedItems[index].metadata)
//                            .textFieldStyle(PlainTextFieldStyle()) // Match existing styling
//                            .onSubmit {
//                                updateMetadata(item: reorderedItems[index])
//                            }
//                        
//                        Spacer()
//                        
//                        if let thumbnailURL = reorderedItems[index].thumbnailURL {
//                            AsyncImage(url: thumbnailURL) { phase in
//                                switch phase {
//                                case .empty:
//                                    ProgressView()
//                                case .success(let image):
//                                    image.resizable()
//                                        .aspectRatio(contentMode: .fill)
//                                        .frame(width: 35, height: 35)
//                                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                                case .failure(_):
//                                    Image(systemName: "photo")
//                                        .resizable()
//                                        .aspectRatio(contentMode: .fill)
//                                        .frame(width: 35, height: 35)
//                                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                                @unknown default:
//                                    EmptyView()
//                                }
//                            }
//                        } else {
//                            Image(systemName: "photo.on.rectangle.angled")
//                                .resizable()
//                                .aspectRatio(contentMode: .fill)
//                                .frame(width: 35, height: 35)
//                                .clipShape(RoundedRectangle(cornerRadius: 8))
//                        }
//                    }
//                } else {
//                    NavigationLink(destination: PlayerContainerView(items: reorderedItems, initialIndex: index)) {
//                        HStack {
//                            Text(reorderedItems[index].metadata)
//                            Spacer()
//                            if let thumbnailURL = reorderedItems[index].thumbnailURL {
//                                AsyncImage(url: thumbnailURL) { phase in
//                                    switch phase {
//                                    case .empty:
//                                        ProgressView()
//                                    case .success(let image):
//                                        image.resizable()
//                                            .aspectRatio(contentMode: .fill)
//                                            .frame(width: 35, height: 35)
//                                            .clipShape(RoundedRectangle(cornerRadius: 8))
//                                    case .failure(_):
//                                        Image(systemName: "photo")
//                                            .resizable()
//                                            .aspectRatio(contentMode: .fill)
//                                            .frame(width: 35, height: 35)
//                                            .clipShape(RoundedRectangle(cornerRadius: 8))
//                                    @unknown default:
//                                        EmptyView()
//                                    }
//                                }
//                            } else {
//                                Image(systemName: "photo.on.rectangle.angled")
//                                    .resizable()
//                                    .aspectRatio(contentMode: .fill)
//                                    .frame(width: 35, height: 35)
//                                    .clipShape(RoundedRectangle(cornerRadius: 8))
//                            }
//                        }
//                        .padding(.vertical, 1)
//                    }
//                }
//            }
//            .onMove(perform: moveItem)
//            .onDelete(perform: deleteItem)
//        }
//        .scrollIndicators(.hidden)
//        .padding(.bottom, 45)
//        .navigationTitle(pod.title)
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarItems(trailing: trailingNavigationBarItem)
//        .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
//        .onAppear {
//            self.reorderedItems = self.pod.items // Initialize reorderedItems with the current items
//            uploadViewModel.addItemCompletion = {
//                refreshPodItems()
//            }
//        }
//        .actionSheet(isPresented: $showMenu) {
//            ActionSheet(title: Text("Options"), buttons: [
//                .default(Text("Edit")) {
//                    isEditing.toggle()
//                    
//                },
////                .default(Text("Add Item")) {
////                    showAddItemView.toggle()
////                },
//                .cancel()
//            ])
//        }
//        .fullScreenCover(isPresented: $showAddItemView) {
//            AddItemContainerView(showAddItemView: $showAddItemView, podId: pod.id)
//        }
//    }
//    
//    private func refreshPodItems() {
//        networkManager.fetchItemsForPod(podId: pod.id) { items, error in
//            if let items = items {
//                self.reorderedItems = items
//                self.pod.items = items
//            } else {
//                print("Failed to fetch items for pod: \(error ?? "Unknown error")")
//            }
//        }
//    }
//    
//    private var trailingNavigationBarItem: some View {
//        Group {
//            if isEditing {
//                Button(action: {
//                    // Call API to update items metadata
//                    reorderedItems.forEach { item in
//                        updateMetadata(item: item)
//                    }
//                    
//                    isEditing.toggle()
//                    if !isEditing {
//                        // Call API to delete items
//                        deletedItemIDs.forEach { itemId in
//                            networkManager.deletePodItem(itemId: itemId) { success, errorMessage in
//                                if success {
//                                    print("Item \(itemId) deleted successfully.")
//                                } else {
//                                    print("Failed to delete item \(itemId): \(errorMessage ?? "Unknown error")")
//                                }
//                            }
//                        }
//                        
//                        // Call API to reorder items
//                        let itemIDs = reorderedItems.map { $0.id }
//                        networkManager.reorderPodItems(podId: pod.id, itemIds: itemIDs) { success, errorMessage in
//                            if success {
//                                print("Items reordered successfully.")
//                            } else {
//                                print("Failed to reorder items: \(errorMessage ?? "Unknown error")")
//                            }
//                        }
//
//                        // Reset local changes
//                        deletedItemIDs.removeAll()
//                    }
//                }) {
//                    Text("Done")
//                }
//            } else {
//                Button(action: {
//                    showMenu.toggle()
//                }) {
//                    Image(systemName: "ellipsis.circle")
//                        .foregroundColor(.primary)
//                }
//            }
//        }
//    }
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
//    private func updateMetadata(item: PodItem) {
//        networkManager.updatePodItemLabel(itemId: item.id, newLabel: item.metadata) { success, errorMessage in
//            if success {
//                print("Item \(item.id) label updated successfully.")
//            } else {
//                print("Failed to update item \(item.id) label: \(errorMessage ?? "Unknown error")")
//            }
//        }
//    }
//}
