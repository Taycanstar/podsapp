//import SwiftUI
//import AVFoundation
//
//struct PodView: View {
//    @Binding var pod: Pod
//    @Environment(\.presentationMode) var presentationMode
//    @State private var isEditing = false
//    @State private var reorderedItems: [PodItem] = []
//    @State private var deletedItemIDs: [Int] = []
//    @State private var showMenu = false
//    @State private var showAddItemView = false
//    @State private var isAnyItemEditing: Bool = false
//    @State private var showDoneButton = false
//    @State private var editingItemId: Int?
//    @State private var selection: (podIndex: Int, itemIndex: Int)?
//    var networkManager: NetworkManager = NetworkManager()
//    @EnvironmentObject var uploadViewModel: UploadViewModel
//    
//    @FocusState private var focusedField: String?
//    @State private var showNotesPlaceholder: [Int: Bool] = [:]
//    
//    @Binding var needsRefresh: Bool
//    @State private var showPodOptionsSheet = false
//    @EnvironmentObject var homeViewModel: HomeViewModel
//    
//    @Environment(\.isTabBarVisible) var isTabBarVisible
//    
//    @State private var isCreatingNewItem = false
//       @State private var newItemText = ""
//       @FocusState private var isNewItemFocused: Bool
//
//    var body: some View {
//        ZStack {
//            VStack {
//                PodViewHeaderSection()
//                List {
//                    ForEach(reorderedItems.indices, id: \.self) { index in
//                        VStack(alignment: .leading, spacing: 0) {
//                            HStack {
//                                TextField("", text: $reorderedItems[index].metadata)
//                                    .focused($focusedField, equals: "metadata_\(reorderedItems[index].id)")
//                                    .font(.body)
//                                    .onTapGesture {
//                                        if !isEditing {
//                                            withAnimation(.easeInOut(duration: 0.3)) {
//                                                focusedField = "metadata_\(reorderedItems[index].id)"
//                                                showDoneButton = true
//                                                isAnyItemEditing = true
//                                                editingItemId = reorderedItems[index].id
//                                                showNotesPlaceholder[reorderedItems[index].id] = true
//                                            }
//                                        }
//                                    }
//                                
//                                Spacer()
//                                
//                                HStack(spacing: 5) {
//                                    if let thumbnailURL = reorderedItems[index].thumbnailURL {
//                                        AsyncImage(url: thumbnailURL) { phase in
//                                            switch phase {
//                                            case .empty:
//                                                ProgressView()
//                                            case .success(let image):
//                                                image.resizable()
//                                            case .failure(_):
//                                                Image(systemName: "photo")
//                                            @unknown default:
//                                                EmptyView()
//                                            }
//                                        }
//                                        .aspectRatio(contentMode: .fill)
//                                        .frame(width: 30, height: 30)
//                                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                                    }
//                                    if !isEditing {
//                                        Image(systemName: "chevron.right")
//                                            .foregroundColor(.gray)
//                                            .font(.system(size: 14))
//                                    }
//                                }
//                                .onTapGesture {
//                                    if !isEditing {
//                                        self.selection = (0, index)
//                                    }
//                                }
//                            }
//
//                            if !reorderedItems[index].notes.isEmpty || showNotesPlaceholder[reorderedItems[index].id] == true {
//                                ZStack(alignment: .topLeading) {
//                                    TextEditor(text: $reorderedItems[index].notes)
//                                        .focused($focusedField, equals: "notes_\(reorderedItems[index].id)")
//                                        .font(.footnote)
//                                        .foregroundColor(.gray)
//                                        .frame(height: max(20, calculateHeight(for: reorderedItems[index].notes)))
//                                        .background(Color.clear)
//                                        .opacity(reorderedItems[index].notes.isEmpty ? 0.6 : 1)
//                                        .onTapGesture {
//                                            if !isEditing {
//                                                withAnimation(.easeInOut(duration: 0.3)) {
//                                                    focusedField = "notes_\(reorderedItems[index].id)"
//                                                    showDoneButton = true
//                                                    isAnyItemEditing = true
//                                                    editingItemId = reorderedItems[index].id
//                                                }
//                                            }
//                                        }
//                                    
//                                    if reorderedItems[index].notes.isEmpty {
//                                        Text("Add note")
//                                            .font(.footnote)
//                                            .foregroundColor(.gray)
//                                            .padding(.top, 7)
//                                            .padding(.leading, 5)
//                                            .allowsHitTesting(false)
//                                    }
//                                }
//                                .padding(.top, 0)
//                                .padding(.leading, -5)
//                                .transition(.opacity.combined(with: .move(edge: .top)))
//                            }
//                          
//                        }
//
//                        .padding(.vertical, 3)
//                        .padding(.horizontal, 15)
//                        .contentShape(Rectangle())
//                        .listRowInsets(EdgeInsets())
//                        .listRowSeparator(.hidden)
//                        if index < reorderedItems.count - 1 {
//                                        Divider()
//                                            .padding(.leading, 0) // Adjust padding as needed
//                                            .padding(.vertical, 0)
//                                            .padding(.trailing, -25)
//                                    }
//                    }
//                    .onMove(perform: moveItem)
//                    .onDelete(perform: deleteItem)
//                    // Conditional rendering of the input field
//                    if isCreatingNewItem {
//                        HStack {
//                            TextField("Add item", text: $newItemText)
//                                .font(.system(size: 14))
//                                .padding(.vertical, 8)
//                                .padding(.horizontal, 5)
//                                .background(Color(.systemBackground))
//                                .focused($isNewItemFocused)
//                             
//                            Button(action: {
//                                // Handle adding the new item
//                                if !newItemText.isEmpty {
//                                    // Add the new item logic here
//                                    // Reset the state
//                                    isCreatingNewItem = false
//                                    newItemText = ""
//                                }
//                            }) {
//                                Text("Add")
//                                    .fontWeight(.regular)
//                                    .font(.system(size: 14))
//                                    .padding(.horizontal, 12)
//                                    .padding(.vertical, 8)
//                                    .background(Color.accentColor)
//                                    .foregroundColor(.white)
//                                    .cornerRadius(6)
//                            }
//                            .disabled(newItemText.isEmpty)
//                        }
//                        .padding(8)
//                        .background(Color(.systemBackground))
//                        .cornerRadius(12)
//                        .padding(.vertical, 10)
//                        .padding(.horizontal, 10)
//                        .listRowInsets(EdgeInsets())
//                        .listRowSeparator(.hidden)
//                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
//                      
//                    } else {
//
//                        Button(action: {
//                                                isCreatingNewItem = true
//                                                isNewItemFocused = true
//                                            }) {
//                                                HStack(spacing: 5) {
//                                                    Image(systemName: "plus")
//                                                        .font(.system(size: 14, weight: .regular))
//                                                    Text("Add item")
//                                                        .font(.system(size: 14, weight: .regular))
//                                                }
//                                                .padding()
//                                                .frame(maxWidth: .infinity)
//                                                .background(Color(.systemBackground))
//                                                .foregroundColor(.accentColor)
//                                                .cornerRadius(10)
//                                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
//                                            }
//                                            .buttonStyle(PlainButtonStyle()) // This prevents the button from having a tap effect beyond its bounds
//                                            .listRowInsets(EdgeInsets()) // This removes default row insets
//                                            .listRowSeparator(.hidden)
//                                            .padding(.vertical, 20)
//                                            .padding(.horizontal, 15)
//                                 
//                    }
//
//                }
//              
//                .padding(.horizontal, 5)
//                .padding(.vertical, 20)
//                .scrollIndicators(.hidden)
//                .listStyle(PlainListStyle())
//                .environment(\.defaultMinListRowHeight, 1)
//                .navigationTitle(pod.title)
//                .navigationBarTitleDisplayMode(.inline)
//                .navigationBarItems(trailing: trailingNavigationBarItem)
//                .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
//                .onAppear {
//                    self.reorderedItems = self.pod.items
//                    uploadViewModel.addItemCompletion = {
//                        refreshPodItems()
//                    }
//                    homeViewModel.updatePodLastVisited(podId: pod.id)
//                    isTabBarVisible.wrappedValue = false
//                }
//                .onDisappear{
//                    isTabBarVisible.wrappedValue = true
//                }
//                .sheet(isPresented: $showPodOptionsSheet) {
//                    PodOptionsView(showPodOptionsSheet: $showPodOptionsSheet, onDeletePod: deletePod, podName: pod.title)
//                }
//                .background(
//                    NavigationLink(
//                        destination: selection.map { index in
//                            PlayerContainerView(
//                                items: reorderedItems,
//                                initialIndex: index.itemIndex
//                            )
//                        },
//                        isActive: Binding(
//                            get: { selection != nil },
//                            set: { if !$0 { selection = nil } }
//                        )
//                    ) {
//                        EmptyView()
//                    }
//                )
//                .actionSheet(isPresented: $showMenu) {
//                    ActionSheet(title: Text("Options"), buttons: [
//                        .default(Text("Edit")) {
//                            isEditing.toggle()
//                        },
//                        .cancel()
//                    ])
//                }
//                .fullScreenCover(isPresented: $showAddItemView) {
//                    AddItemContainerView(showAddItemView: $showAddItemView, podId: pod.id)
//                }
//                .onChange(of: focusedField) { newValue in
//                    if newValue == nil {
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            for (id, _) in showNotesPlaceholder {
//                                if let index = reorderedItems.firstIndex(where: { $0.id == id }),
//                                   reorderedItems[index].notes.isEmpty {
//                                    showNotesPlaceholder[id] = false
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//            
//            // Floating button
//            VStack {
//                Spacer()
//                HStack {
//                    Spacer()
//                    Button(action: {
//                        showAddItemView = true
//                    }) {
//                        HStack {
//                            Image(systemName: "plus")
//                            Text("Add Item")
//                                .fontWeight(.medium)
//                        }
//                        .padding()
//                        .background(Color.accentColor)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
//                    }
//                    .padding(.bottom, 40)
//                    .padding(.trailing, 15)
//                }
//            }
//        }
//        .edgesIgnoringSafeArea(.bottom)
//    }
//
//    private func deletePod() {
//        networkManager.deletePod(podId: pod.id) { success, message in
//            DispatchQueue.main.async {
//                if success {
//                    print("Pod deleted successfully.")
//                    if let index = homeViewModel.pods.firstIndex(where: { $0.id == pod.id }) {
//                        homeViewModel.pods.remove(at: index)
//                        homeViewModel.totalPods -= 1
//                    }
//                    presentationMode.wrappedValue.dismiss()
//                } else {
//                    print("Failed to delete pod: \(message ?? "Unknown error")")
//                }
//            }
//        }
//    }
//    
//    private var trailingNavigationBarItem: some View {
//
//            Button(action: {
//                        showPodOptionsSheet = true
//                    }) {
//                        Image(systemName: "ellipsis.circle")
//                            .foregroundColor(.primary)
//                    }
//    }
//    
//    private func refreshPodItems() {
//
//        DispatchQueue.global(qos: .background).async {
//            networkManager.fetchItemsForPod(podId: pod.id) { items, error in
//                DispatchQueue.main.async {
//                    if let items = items {
//                        self.reorderedItems = items
//                        self.pod.items = items
//                    } else {
//                        print("Failed to fetch items for pod: \(error ?? "Unknown error")")
//                    }
//                }
//            }
//        }
//
//    }
//    
//    func moveItem(from source: IndexSet, to destination: Int) {
//        reorderedItems.move(fromOffsets: source, toOffset: destination)
//        
//        // Reorder in the backend
//        let itemIDs = reorderedItems.map { $0.id }
//
//        DispatchQueue.global(qos: .background).async {
//            networkManager.reorderPodItems(podId: pod.id, itemIds: itemIDs) { success, errorMessage in
//                DispatchQueue.main.async {
//                    if success {
//                        print("Items reordered successfully in the backend.")
//                        self.pod.items = self.reorderedItems
//                    } else {
//                        print("Failed to reorder items in the backend: \(errorMessage ?? "Unknown error")")
//                    }
//                }
//            }
//        }
//
//    }
//
//    func deleteItem(at offsets: IndexSet) {
//        offsets.forEach { index in
//            let itemId = reorderedItems[index].id
//
//            DispatchQueue.global(qos: .background).async {
//                networkManager.deletePodItem(itemId: itemId) { success, errorMessage in
//                    DispatchQueue.main.async {
//                        if success {
//                            print("Item \(itemId) deleted successfully.")
//                            reorderedItems.remove(at: index)
//                        } else {
//                            print("Failed to delete item \(itemId): \(errorMessage ?? "Unknown error")")
//                        }
//                    }
//                }
//            }
//
//        }
//    }
//    
//    private func saveChangesAndExitEditMode() {
//        isEditing = false
//        reorderedItems.forEach { item in
//            updateMetadata(item: item)
//        }
//        
//        deletedItemIDs.forEach { itemId in
//            networkManager.deletePodItem(itemId: itemId) { success, errorMessage in
//                if success {
//                    print("Item \(itemId) deleted successfully.")
//                } else {
//                    print("Failed to delete item \(itemId): \(errorMessage ?? "Unknown error")")
//                }
//            }
//        }
//        
//        let itemIDs = reorderedItems.map { $0.id }
//        networkManager.reorderPodItems(podId: pod.id, itemIds: itemIDs) { success, errorMessage in
//            if success {
//                print("Items reordered successfully.")
//            } else {
//                print("Failed to reorder items: \(errorMessage ?? "Unknown error")")
//            }
//        }
//
//        deletedItemIDs.removeAll()
//        needsRefresh = true
//    }
//
//    private func saveInputChanges() {
//        guard let itemId = editingItemId,
//              let itemIndex = reorderedItems.firstIndex(where: { $0.id == itemId }) else {
//            print("No item selected for editing or item not found")
//            return
//        }
//        
//        let item = reorderedItems[itemIndex]
//        
//        networkManager.updatePodItemLabelAndNotes(itemId: item.id, newLabel: item.metadata, newNotes: item.notes) { success, errorMessage in
//            if success {
//                print("Pod item label and notes updated successfully.")
//            } else {
//                print("Failed to update pod item label and notes: \(errorMessage ?? "Unknown error")")
//            }
//            DispatchQueue.main.async {
//                self.showDoneButton = false
//                self.isAnyItemEditing = false
//                self.editingItemId = nil
//                self.focusedField = nil
//                self.needsRefresh = true
//            }
//        }
//    }
//    
//    private func updateMetadata(item: PodItem) {
//        networkManager.updatePodItemLabelAndNotes(itemId: item.id, newLabel: item.metadata, newNotes: item.notes) { success, errorMessage in
//            if success {
//                print("Item \(item.id) label and notes updated successfully.")
//            } else {
//                print("Failed to update item \(item.id) label and notes: \(errorMessage ?? "Unknown error")")
//            }
//        }
//    }
//    
//    private func calculateHeight(for text: String) -> CGFloat {
//        let font = UIFont.preferredFont(forTextStyle: .footnote)
//        let attributes = [NSAttributedString.Key.font: font]
//        let size = (text as NSString).boundingRect(
//            with: CGSize(width: UIScreen.main.bounds.width - 80, height: .greatestFiniteMagnitude),
//            options: [.usesLineFragmentOrigin, .usesFontLeading],
//            attributes: attributes,
//            context: nil
//        ).size
//        
//        return size.height + 10 // Add some padding
//    }
//}
//
//
//
//struct PodViewHeaderSection: View {
//    @State private var selectedView: String = "Table"
//    
//    var body: some View {
//        HStack(spacing: 10) {
//            // View Options Section
//            viewSection
//            
//            // Filter Section
//            filterSection
//            Spacer()
//            // Search Section
//            searchSection
//        }
//        .padding(.horizontal)
//        .padding(.top,15)
//        .padding(.bottom, -10)
//    }
//    
//    private var viewSection: some View {
//        HStack {
//            Image(systemName: "square.grid.2x2")
//            Text(selectedView)
//            Image(systemName: "chevron.down")
//        }
//        .padding(10)
//        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))
//    }
//    
//    private var filterSection: some View {
//        HStack {
//            Image(systemName: "line.3.horizontal.decrease")
//            Text("Filter")
//        }
//        .padding(10)
//        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))
//    }
//    
//    private var searchSection: some View {
//        Image(systemName: "magnifyingglass")
//            .padding(10)
//            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))
//    }
//}
//
//
//struct AddItemButton: View {
//    @Environment(\.colorScheme) var colorScheme
//    var accentColor: Color = .blue  // Set your accent color here
//    var action: () -> Void
//
//    var body: some View {
//        Button(action: action) {
//            HStack {
//                Image(systemName: "plus")
//                Text("Add Item")
//                    .fontWeight(.bold)
//            }
//            .padding()
//            .frame(maxWidth: .infinity)
//            .background(colorScheme == .light ? Color.white : Color.black)
//            .foregroundColor(accentColor)
//            .cornerRadius(10)
//            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
//        }
//        .padding(.horizontal)
//    }
//}
import SwiftUI
import AVFoundation

struct PodView: View {
    @Binding var pod: Pod
    @Binding var needsRefresh: Bool
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
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
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.isTabBarVisible) var isTabBarVisible
    
    @FocusState private var focusedField: String?
    @State private var showNotesPlaceholder: [Int: Bool] = [:]
    @State private var showPodOptionsSheet = false
    
    @State private var isCreatingNewItem = false
    @State private var newItemText = ""
    @FocusState private var isNewItemFocused: Bool
    
    @State private var selectedView: ViewType = .list
    
    @State private var keyboardOffset: CGFloat = 0
    
    @State private var selectedColumnForEdit: (index: Int, name: String)?
    @State private var showColumnEditSheet = false
    @State private var showCardSheet = false
    @State private var showBubbleSheet = false
    @State private var selectedItemIndex: Int?

    
    enum ViewType: String, CaseIterable {
        case list = "List"
        case table = "Table"
        case calendar = "Calendar"
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(rgb: 14,14,14) : .white)
                            .edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                PodViewHeaderSection(selectedView: $selectedView)
               
                    ScrollView {
                        VStack(spacing: 12) {
                            switch selectedView {
                            case .list:
                                listView
                            case .table:
                                Text("Table View")
                            case .calendar:
                                Text("Calendar View")
                            }
                            
                            if isCreatingNewItem {
                                newItemInputView
                       
                                    .padding(.bottom, 45)
                            } else {
                                addItemButton
                                    .padding(.bottom, 45)
                            }
                        }
               
                    }
                    
                    .padding(.bottom, keyboardOffset)
            
                
            }
            .navigationTitle(pod.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: trailingNavigationBarItem)
            
            // Floating button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        isCreatingNewItem = true
                        isNewItemFocused = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Item")
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
                    }
                    .padding(.bottom, 40)
                    .padding(.trailing, 15)
                }
            }
        }
     
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            self.reorderedItems = self.pod.items
            uploadViewModel.addItemCompletion = {
                refreshPodItems()
            }
            homeViewModel.updatePodLastVisited(podId: pod.id)
            isTabBarVisible.wrappedValue = false
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { (notification) in
                 if let keyboardSize = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                     let keyboardHeight = keyboardSize.height
                    
                     withAnimation {
                         keyboardOffset = keyboardHeight  /*(UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0)*/
                     }
                 }
             }
     
             NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                 withAnimation {
                     keyboardOffset = 0
                 }
             }

        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
            
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
        .sheet(isPresented: $showPodOptionsSheet) {
            PodOptionsView(showPodOptionsSheet: $showPodOptionsSheet, onDeletePod: deletePod, podName: pod.title)
        }
        .fullScreenCover(isPresented: $showAddItemView) {
            AddItemContainerView(showAddItemView: $showAddItemView, podId: pod.id)
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

        .sheet(isPresented: $showColumnEditSheet) {
            if let selectedColumn = selectedColumnForEdit,
               let itemIndex = selectedItemIndex,
               itemIndex < reorderedItems.count {
                let item = reorderedItems[itemIndex]
                
                ColumnEditView(
                    itemId: item.id,
                    columnName: selectedColumn.name,
                    columnType: pod.columns[selectedColumn.index].type,
                    value: Binding(
                        get: { item.columnValues?[selectedColumn.name] ?? .null },
                        set: { newValue in
                            updateColumnValue(itemIndex: itemIndex,
                                              columnName: selectedColumn.name,
                                              newValue: newValue)
                        }
                    ),
                    onSave: { _ in /* This closure is now empty as we handle the update in the binding */ },
                    networkManager: networkManager
                )
                .presentationDetents([.height(UIScreen.main.bounds.height / 4)])
            }
        }
       
               .sheet(isPresented: $showCardSheet) {
                   if let index = selectedItemIndex {
                       CardDetailView(item: reorderedItems[index])
                           .presentationDetents([.height(UIScreen.main.bounds.height / 1.5)])
                   }
               }
          
               .sheet(isPresented: $showBubbleSheet) {
                   if let index = selectedItemIndex {
                       BubbleActionView(item: reorderedItems[index])
                           .presentationDetents([.height(UIScreen.main.bounds.height / 2)])
                   }
               }
              
    }

    private func updateColumnValue(itemIndex: Int, columnName: String, newValue: ColumnValue) {
        guard itemIndex < reorderedItems.count else { return }
        
        if reorderedItems[itemIndex].columnValues == nil {
            reorderedItems[itemIndex].columnValues = [:]
        }
        reorderedItems[itemIndex].columnValues?[columnName] = newValue
        
        // Update the pod binding
        pod.items = reorderedItems
        
        // Trigger a refresh
        needsRefresh = true
    }

        private func addNewItem(_ item: PodItem) {
            reorderedItems.append(item)
            pod.items = reorderedItems
            needsRefresh = true
        }

    private var listView: some View {
            ForEach(reorderedItems.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reorderedItems[index].metadata)
                            .font(.system(size: 14))
                            .fontWeight(.regular)
                            .padding(.bottom, 4)
                        
                        HStack {
                            ForEach(Array(pod.columns.enumerated()), id: \.element.name) { columnIndex, column in
                                columnView(name: column.name, value: reorderedItems[index].columnValues?[column.name] ?? nil)
                                    .onTapGesture {
                                        selectedColumnForEdit = (columnIndex, column.name)
                                        selectedItemIndex = index
                                        showColumnEditSheet = true
                                    }
                            }
                        }
                    }
                    .padding()
                    .onTapGesture {
                        selectedItemIndex = index
                        showCardSheet = true
                    }
                    
                    Spacer()
                    
                    VStack {
                        iconView(for: reorderedItems[index])
                            .onTapGesture {
                                if reorderedItems[index].videoURL != nil || reorderedItems[index].imageURL != nil {
                                    self.selection = (0, index)
                                }
                            }
                        Spacer()
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 20))
                            .foregroundColor(colorScheme == .dark ? Color(rgb: 107,107,107) : Color(rgb:196, 198, 207))
                            .onTapGesture {
                                selectedItemIndex = index
                                showBubbleSheet = true
                            }
                    }
                    .padding(10)
                }
//            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? Color(rgb: 14,14,14) : .white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0.5)
            )
            .onTapGesture {
                selectedItemIndex = index
                showCardSheet = true
            }
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        }
        .padding(.horizontal, 15)
    }

    private func iconView(for item: PodItem) -> some View {
        Group {
            if item.videoURL != nil || item.imageURL != nil {
                Image(systemName: "play")
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? Color(rgb: 107,107,107) : Color(rgb:196, 198, 207))
            } else {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? Color(rgb: 107,107,107) : Color(rgb:196, 198, 207))
            }
        }
    }


    private func columnView(name: String, value: ColumnValue?) -> some View {
        VStack {
            if let value = value {
                switch value {
                case .string(let stringValue):
                    Text("\(stringValue) \(name)")
                        .font(.system(size: 14))
                case .number(let numberValue):
                    Text("\(numberValue) \(name)")
                        .font(.system(size: 14))
                case .null:
                    Text(name)
                        .font(.system(size: 14))
                }
            } else {
                Text(name)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal,6)
        .padding(.vertical,4)
        .cornerRadius(4)
        .background(colorScheme == .dark ? Color(rgb:44,44,44) : Color(rgb:244, 246, 247))
        .cornerRadius(4)
    }

    
    private func getColumnValues(for item: PodItem) -> [String: Any?]? {
        return item.columnValues
    }
    
    
    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 44, 44, 44) : Color(rgb: 230, 230, 230)
    }
    
    private var newItemInputView: some View {
        HStack {
            TextField("Add item", text: $newItemText)
                .id("NewItemTextField")
                .font(.system(size: 14))
                .padding(.vertical, 8)
                .padding(.horizontal, 5)
                .background(colorScheme == .dark ? Color(rgb: 14, 14, 14) : .white)
                .focused($isNewItemFocused)
                .onSubmit {
                    if !newItemText.isEmpty {
                        createNewPodItem()
                    }
                }
             
            Button(action: {
                if !newItemText.isEmpty {
                               createNewPodItem()
                           }
            }) {
                Text("Add")
                    .fontWeight(.regular)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .disabled(newItemText.isEmpty)
        }

        .padding(.vertical, 10)
        .padding(.horizontal, 5)
        
        .background(colorScheme == .dark ? Color(rgb: 14, 14, 14) : .white)
//        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 1)
        )
      
        .padding(.horizontal, 15)
        .padding(.bottom, 20)
        .padding(.top, 10)


    }
    
    private func createNewPodItem() {
        let newItemColumnValues: [String: ColumnValue] = pod.columns.reduce(into: [:]) { result, column in
            result[column.name] = .null  // Initialize all columns with null values
        }
        
        networkManager.createPodItem(
            podId: pod.id,
            label: newItemText,
            itemType: nil,  // We're not setting an item type for now
            notes: "",
            columnValues: newItemColumnValues
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newItem):
                    self.reorderedItems.append(newItem)
                    self.pod.items.append(newItem)
                    self.newItemText = ""
                    self.isCreatingNewItem = false
                    self.needsRefresh = true
                case .failure(let error):
                    print("Failed to create new pod item: \(error)")
                    // You might want to show an alert to the user here
                }
            }
        }
    }
    
    private var addItemButton: some View {
        Button(action: {
            isCreatingNewItem = true
            isNewItemFocused = true
        }) {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .regular))
                Text("Add item")
                    .font(.system(size: 14, weight: .regular))
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background( colorScheme == .dark ? Color(rgb: 14, 14, 14) : .white)
            .foregroundColor(.accentColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
    }
    
    private var trailingNavigationBarItem: some View {
        Button(action: {
            showPodOptionsSheet = true
        }) {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.primary)
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

struct PodViewHeaderSection: View {
    @Binding var selectedView: PodView.ViewType
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 10) {
            viewSection
            filterSection
            Spacer()
            searchSection
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 15)
    }
    
    private var viewSection: some View {
        Menu {
            ForEach(PodView.ViewType.allCases, id: \.self) { viewType in
                Button(viewType.rawValue) {
                    selectedView = viewType
                }
            }
        } label: {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .foregroundColor(.primary)
                Text(selectedView.rawValue)
                    .foregroundColor(.primary)
                Image(systemName: "chevron.down")
                    .foregroundColor(.primary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(colorScheme == .dark ? Color(rgb:44,44,44) : Color(rgb:244, 246, 247)))
        }
    }
    
    private var filterSection: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease")
            Text("Filter")
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(colorScheme == .dark ? Color(rgb:44,44,44) : Color(rgb:244, 246, 247)))
    }
    
    private var searchSection: some View {
        Image(systemName: "magnifyingglass")
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(colorScheme == .dark ? Color(rgb:44,44,44) : Color(rgb:244, 246, 247)))
    }
}

struct ColumnEditView: View {
    let itemId: Int
    let columnName: String
    let columnType: String
    @Binding var value: ColumnValue
    let onSave: (ColumnValue) -> Void
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFocused: Bool
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var textValue: String = ""
    
    let networkManager: NetworkManager

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack {
                    if columnType == "text" {
                        CustomTextEditorWrapper(text: $textValue, isFocused: $isFocused, backgroundColor: backgroundColor)
                            .padding(.horizontal)
                            .focused($isFocused)
                    } else {
                        TextField("", text: $textValue)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.accentColor, lineWidth: 2)
                            )
                            .padding(.horizontal)
                            .focused($isFocused)
                    }
                    Spacer()
                }
                .background(backgroundColor)
                .navigationBarTitle("\(columnName)", displayMode: .inline)
                .navigationBarItems(
                    leading: Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    },
                    trailing: Button("Save") {
                        saveValue()
                    }
                )
            }
        }
        .onAppear {
            isFocused = true
            textValue = stringValue(from: value)
        }
        .alert(isPresented: $showingError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onSubmit {
            saveValue()
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(rgb: 44,44,44) : .white
    }

    private func saveValue() {
        let newValue: ColumnValue
        if columnType == "text" {
            newValue = .string(textValue)
        } else if let numberValue = Int(textValue) {
            newValue = .number(numberValue)
        } else {
            newValue = .null
        }
        
        networkManager.updatePodItemColumnValue(itemId: itemId, columnName: columnName, value: newValue) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.value = newValue  // Update the binding
                    self.onSave(newValue)
                    self.presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    self.showError("Failed to update column value: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func stringValue(from columnValue: ColumnValue) -> String {
        switch columnValue {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .null:
            return ""
        }
    }
}


struct CustomTextEditorWrapper: UIViewRepresentable {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let backgroundColor: Color

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = UIColor(backgroundColor)
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        uiView.backgroundColor = UIColor(backgroundColor)
        
        if isFocused && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditorWrapper

        init(_ parent: CustomTextEditorWrapper) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }
    }
}
struct CardDetailView: View {
    let item: PodItem

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    Text("Metadata: \(item.metadata)")
              
                    // Add more details as needed
                }
            }
            .navigationBarTitle("Item Details", displayMode: .inline)
        }
    }
}

struct BubbleActionView: View {
    let item: PodItem

    var body: some View {
        NavigationView {
            List {
                Button("Edit") {
                    // Implement edit action
                }
                Button("Delete") {
                    // Implement delete action
                }
                // Add more actions as needed
            }
            .navigationBarTitle("Actions", displayMode: .inline)
        }
    }
}
