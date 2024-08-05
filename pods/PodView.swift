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
    @State private var showNotesPlaceholder: [Int: Bool] = [:]
    
    @Binding var needsRefresh: Bool
    @State private var showPodOptionsSheet = false
    @EnvironmentObject var homeViewModel: HomeViewModel


    
    var body: some View {
        List {
            ForEach(reorderedItems.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        TextField("", text: $reorderedItems[index].metadata)
                            .focused($focusedField, equals: "metadata_\(reorderedItems[index].id)")
                            .font(.body)
                            .onTapGesture {
                                if !isEditing {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        focusedField = "metadata_\(reorderedItems[index].id)"
                                        showDoneButton = true
                                        isAnyItemEditing = true
                                        editingItemId = reorderedItems[index].id
                                        showNotesPlaceholder[reorderedItems[index].id] = true
                                    }
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
                        .onTapGesture {
                            if !isEditing {
                                self.selection = (0, index)
                            }
                        }
                    }

                    if !reorderedItems[index].notes.isEmpty || showNotesPlaceholder[reorderedItems[index].id] == true {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $reorderedItems[index].notes)
                                .focused($focusedField, equals: "notes_\(reorderedItems[index].id)")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .frame(height: max(20, calculateHeight(for: reorderedItems[index].notes)))
                                .background(Color.clear)
                                .opacity(reorderedItems[index].notes.isEmpty ? 0.6 : 1)
                                .onTapGesture {
                                    if !isEditing {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            focusedField = "notes_\(reorderedItems[index].id)"
                                            showDoneButton = true
                                            isAnyItemEditing = true
                                            editingItemId = reorderedItems[index].id
                                        }
                                    }
                                }
                            
                            if reorderedItems[index].notes.isEmpty {
                                Text("Add note")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .padding(.top, 7)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(.top, 0)
                        .padding(.leading, -5)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                  
                }

                .padding(.vertical, 3)
                .padding(.horizontal, 15)
                .contentShape(Rectangle())
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                if index < reorderedItems.count - 1 {
                                Divider()
                                    .padding(.leading, 0) // Adjust padding as needed
                                    .padding(.vertical, 0)
                                    .padding(.trailing, -25)
                            }
            }
            .onMove(perform: moveItem)
            .onDelete(perform: deleteItem)
        }
      
        .padding(.horizontal, 5)
        
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
        .sheet(isPresented: $showPodOptionsSheet) {
            PodOptionsView(showPodOptionsSheet: $showPodOptionsSheet, onDeletePod: deletePod, podName: pod.title)
           }
        .padding(.top, 15)
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
        .onChange(of: focusedField) { newValue in
            if newValue == nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    for (id, _) in showNotesPlaceholder {
                        if let index = reorderedItems.firstIndex(where: { $0.id == id }),
                           reorderedItems[index].notes.isEmpty {
                            showNotesPlaceholder[id] = false
                        }
                    }
                }
            }
        }
        
       
    }
    
    private func deletePod() {
        networkManager.deletePod(podId: pod.id) { success, message in
            DispatchQueue.main.async {
                if success {
                    print("Pod deleted successfully.")
                    if let index = homeViewModel.pods.firstIndex(where: { $0.id == pod.id }) {
                        homeViewModel.pods.remove(at: index)
                        homeViewModel.totalPods -= 1
                    }
                    presentationMode.wrappedValue.dismiss()
                } else {
                    print("Failed to delete pod: \(message ?? "Unknown error")")
                }
            }
        }
    }
    
    private var trailingNavigationBarItem: some View {

            Button(action: {
                        showPodOptionsSheet = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
                    }
    }
    
    private func refreshPodItems() {

        DispatchQueue.global(qos: .background).async {
            networkManager.fetchItemsForPod(podId: pod.id) { items, error in
                DispatchQueue.main.async {
                    if let items = items {
                        self.reorderedItems = items
                        self.pod.items = items
                    } else {
                        print("Failed to fetch items for pod: \(error ?? "Unknown error")")
                    }
                }
            }
        }

    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        reorderedItems.move(fromOffsets: source, toOffset: destination)
        
        // Reorder in the backend
        let itemIDs = reorderedItems.map { $0.id }

        DispatchQueue.global(qos: .background).async {
            networkManager.reorderPodItems(podId: pod.id, itemIds: itemIDs) { success, errorMessage in
                DispatchQueue.main.async {
                    if success {
                        print("Items reordered successfully in the backend.")
                        self.pod.items = self.reorderedItems
                    } else {
                        print("Failed to reorder items in the backend: \(errorMessage ?? "Unknown error")")
                    }
                }
            }
        }

    }

    func deleteItem(at offsets: IndexSet) {
        offsets.forEach { index in
            let itemId = reorderedItems[index].id

            DispatchQueue.global(qos: .background).async {
                networkManager.deletePodItem(itemId: itemId) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            print("Item \(itemId) deleted successfully.")
                            reorderedItems.remove(at: index)
                        } else {
                            print("Failed to delete item \(itemId): \(errorMessage ?? "Unknown error")")
                        }
                    }
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
        needsRefresh = true
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
                self.needsRefresh = true
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

