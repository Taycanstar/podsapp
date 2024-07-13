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
    @State private var isAnyItemEditing: Bool = false
    @State private var showDoneButton = false
    @State private var isEditMode: Bool = false
    @State private var needsRefresh: Bool = false
    @State private var editingItemId: Int?

    
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
                    ForEach(editMode == .active ? editingPods.indices : homeViewModel.pods.indices, id: \.self) { index in
                        VStack {
                            PodTitleRow(pod: $homeViewModel.pods[index], isExpanded: expandedPods.contains(homeViewModel.pods[index].id), onExpandCollapseTapped: {
                                if editMode == .inactive {
                                    withAnimation {
                                        togglePodExpansion(for: homeViewModel.pods[index].id)
                                    }
                                }
                            }, needsRefresh: $needsRefresh)
                            .listRowInsets(EdgeInsets())
                            .buttonStyle(PlainButtonStyle())
                        }
                        .listRowInsets(EdgeInsets())

                        if expandedPods.contains(homeViewModel.pods[index].id) {
                            ForEach($homeViewModel.pods[index].items, id: \.id) { $item in
                                ItemRow(item: $item,
                                        isEditing: editMode == .active,
                                        onTapNavigate: {
                                            self.selection = (index, homeViewModel.pods[index].items.firstIndex(where: { $0.id == item.id }) ?? 0)
                                        },
                                        isAnyItemEditing: $isAnyItemEditing,
                                        showDoneButton: $showDoneButton,
                                        editingItemId: $editingItemId)
                                .contentShape(Rectangle())
                                .onTapGesture {} // This empty gesture prevents taps from propagating to the whole row
                            }
                            .onMove { indices, newOffset in
                                                          moveItem(at: indices, in: index, to: newOffset)
                                                      }
                            .onDelete { indexSet in
                                                           deletePodItem(at: indexSet, in: index)
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
//                    homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
//                        // No additional action needed
//                    }
                    DispatchQueue.global(qos: .background).async {
                        homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
                            // Additional actions after refresh if needed
                        }
                    }

                }
                .onAppear {
                    if !hasInitiallyFetched {
//                        homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
//                            hasInitiallyFetched = true
//                        }
                        DispatchQueue.global(qos: .background).async {
                            homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
                                hasInitiallyFetched = true
                            }
                        }

                    }
                    editingPods = homeViewModel.pods
                  
                }
                .onChange(of: needsRefresh) { _ in
                           if needsRefresh {
                               refreshPods()
                               needsRefresh = false
                           }
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
                .navigationBarItems(trailing:
                    HStack {
                        if isEditMode || showDoneButton {
                            Button("Done") {
                                if isEditMode {
                                    saveChangesAndExitEditMode()
                                } else {
                                    saveInputChanges()
                                }
                            }
                        }
                        if !isEditMode && !showDoneButton {
                            Menu {
                                Button("Edit") {
                                    isEditMode = true
                                    editMode = .active
                                    editingPods = homeViewModel.pods
                                    withAnimation {
                                        expandedPods.removeAll()
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                )
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

    private func saveChangesAndExitEditMode() {
        isEditMode = false
        editMode = .inactive
        if podsReordered {
            homeViewModel.pods = editingPods
            let orderedPodIds = homeViewModel.pods.map { $0.id }
//            networkManager.reorderPods(email: viewModel.email, podIds: orderedPodIds) { success, errorMessage in
//                DispatchQueue.main.async {
//                    if success {
//                        print("Pods reordered successfully on the backend.")
//                    } else {
//                        print("Failed to reorder pods on the backend: \(errorMessage ?? "Unknown error")")
//                    }
//                }
//            }
            DispatchQueue.global(qos: .background).async {
                networkManager.reorderPods(email: viewModel.email, podIds: orderedPodIds) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            print("Pods reordered successfully on the backend.")
                        } else {
                            print("Failed to reorder pods on the backend: \(errorMessage ?? "Unknown error")")
                        }
                    }
                }
            }

            podsReordered = false
        }
    }
    
    private func refreshPods() {
//        homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
//            // Additional actions after refresh if needed
//        }
        DispatchQueue.global(qos: .background).async {
            homeViewModel.fetchPodsForUser(email: viewModel.email, page: 1) {
                // Additional actions after refresh if needed
            }
        }

    }

    private func saveInputChanges() {
        print("Saving input changes")
        
        guard let itemId = editingItemId else {
            print("No item selected for editing")
            return
        }
        
        if let podIndex = homeViewModel.pods.firstIndex(where: { $0.items.contains(where: { $0.id == itemId }) }),
           let itemIndex = homeViewModel.pods[podIndex].items.firstIndex(where: { $0.id == itemId }) {
            let item = homeViewModel.pods[podIndex].items[itemIndex]
            
            print("Updating item:", item)
            
//            networkManager.updatePodItemLabelAndNotes(itemId: item.id, newLabel: item.metadata, newNotes: item.notes) { success, errorMessage in
//                if success {
//                    print("Pod item label and notes updated successfully.")
//                } else {
//                    print("Failed to update pod item label and notes: \(errorMessage ?? "Unknown error")")
//                }
//                DispatchQueue.main.async {
//                    self.showDoneButton = false
//                    self.isAnyItemEditing = false
//                    self.editingItemId = nil
//                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//                }
//            }
            DispatchQueue.global(qos: .background).async {
                networkManager.updatePodItemLabelAndNotes(itemId: item.id, newLabel: item.metadata, newNotes: item.notes) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            print("Pod item label and notes updated successfully.")
                        } else {
                            print("Failed to update pod item label and notes: \(errorMessage ?? "Unknown error")")
                        }
                        self.showDoneButton = false
                        self.isAnyItemEditing = false
                        self.editingItemId = nil
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }

        } else {
            print("Item not found for itemId \(itemId)")
        }
    }


    func movePod(from source: IndexSet, to destination: Int) {
        let podsToMove = source.map { homeViewModel.pods[$0] }
        
        // Perform the move operation
        homeViewModel.pods.move(fromOffsets: source, toOffset: destination)
        
        // Update editingPods if in edit mode
        if editMode == .active {
            editingPods.move(fromOffsets: source, toOffset: destination)
        }
        
        // Reorder in the backend
        let orderedPodIds = homeViewModel.pods.map { $0.id }
        networkManager.reorderPods(email: viewModel.email, podIds: orderedPodIds) { [self] success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    print("Pods reordered successfully in the backend.")
                    self.podsReordered = true
                    
                    // Trigger UI update
                    self.homeViewModel.objectWillChange.send()
                } else {
                    print("Failed to reorder pods in the backend: \(errorMessage ?? "Unknown error")")
                    // Revert the local order if the backend update fails
                    self.homeViewModel.pods = podsToMove
                    self.homeViewModel.objectWillChange.send()
                }
            }
        }
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
    
    
    private func moveItem(at source: IndexSet, in podIndex: Int, to destination: Int) {
        homeViewModel.pods[podIndex].items.move(fromOffsets: source, toOffset: destination)
        
        let itemIds = homeViewModel.pods[podIndex].items.map { $0.id }
        let podId = homeViewModel.pods[podIndex].id
        
//        networkManager.reorderPodItems(podId: podId, itemIds: itemIds) { success, errorMessage in
//            if success {
//                print("Pod items reordered successfully in the backend.")
//            } else {
//                print("Failed to reorder pod items in the backend: \(errorMessage ?? "Unknown error")")
//            }
//        }
        DispatchQueue.global(qos: .background).async {
                    networkManager.reorderPodItems(podId: podId, itemIds: itemIds) { success, errorMessage in
                DispatchQueue.main.async {
                    if success {
                        print("Pods reordered successfully on the backend.")
                    } else {
                        print("Failed to reorder pods on the backend: \(errorMessage ?? "Unknown error")")
                    }
                }
            }
        }

    }
    
    private func deletePodItem(at offsets: IndexSet, in podIndex: Int) {
        let indicesToDelete = Array(offsets)
        let sortedIndices = indicesToDelete.sorted().reversed()
        
        for index in sortedIndices {
            let itemId = homeViewModel.pods[podIndex].items[index].id
            networkManager.deletePodItem(itemId: itemId) { [self] success, errorMessage in
                DispatchQueue.main.async {
                    if success {
                        print("Pod item deleted successfully.")
                        self.homeViewModel.pods[podIndex].items.remove(at: index)
                        self.editingPods = self.homeViewModel.pods // Update editingPods to reflect the changes
                    } else {
                        print("Failed to delete pod item: \(errorMessage ?? "Unknown error")")
                    }
                }
            }
        }
    }
}

struct ItemRow: View {
    @Binding var item: PodItem
    let isEditing: Bool
    let onTapNavigate: () -> Void
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Binding var isAnyItemEditing: Bool
    @Binding var showDoneButton: Bool
    @Binding var editingItemId: Int?

    @FocusState private var isMetadataFocused: Bool
    @FocusState private var isNotesFocused: Bool
    @State private var showNotesPlaceholder: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("", text: $item.metadata)
                    .focused($isMetadataFocused)
                    .font(.body)
                    .onTapGesture {
                        if !isEditing {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isMetadataFocused = true
                                showDoneButton = true
                                isAnyItemEditing = true
                                editingItemId = item.id
                                showNotesPlaceholder = true
                            }
                        }
                    }
                
                Spacer()
                
                HStack(spacing: 5) {
                    if let thumbnailURL = item.thumbnailURL {
                        AsyncImage(url: thumbnailURL) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .onTapGesture(perform: onTapNavigate)
            }

            if !item.notes.isEmpty || showNotesPlaceholder {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $item.notes)
                        .focused($isNotesFocused)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .frame(height: max(20, calculateHeight(for: item.notes)))
                        .background(Color.clear)
                        .opacity(item.notes.isEmpty ? 0.6 : 1)
                        .onTapGesture {
                            if !isEditing {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isNotesFocused = true
                                    showDoneButton = true
                                    isAnyItemEditing = true
                                    editingItemId = item.id
                                }
                            }
                        }
                    
                    if item.notes.isEmpty {
                        Text("Add note")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.top, 7)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.leading, -5)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .contentShape(Rectangle())
        .disabled(isEditing)
        .onChange(of: isMetadataFocused) { focused in
            if !focused && item.notes.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showNotesPlaceholder = false
                }
            }
        }
        .onChange(of: isNotesFocused) { focused in
            if focused {
                showNotesPlaceholder = true
            } else if !focused && item.notes.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showNotesPlaceholder = false
                }
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
struct PodTitleRow: View {
    @Binding var pod: Pod
    let isExpanded: Bool
    var onExpandCollapseTapped: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @Binding var needsRefresh: Bool

    var body: some View {
        HStack {
            ZStack{
                NavigationLink(destination: PodView(pod: $pod, needsRefresh: $needsRefresh)){ EmptyView() }.opacity(0.0)
                    .padding(.trailing, -5).frame(width:0, height:0)
                Text(pod.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .padding(.leading, 0) // Apply padding to the text element itself
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            Spacer()
            Button(action: onExpandCollapseTapped) {
                HStack {
                    Text("\(pod.items.count)")
                        .foregroundColor(.gray)
                        .padding(.trailing, 4) // Adjust as necessary for alignment
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.gray)
                        .padding(.trailing, 0)
                }
            }
        }
        .cornerRadius(10)
        .padding(.vertical, 17)
        .padding(.horizontal, 15)
    }
}




